[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Service,

    [string]$Project,
    [string]$Region,
    [ValidateSet('managed')]
    [string]$Platform = 'managed',
    [string]$Image,
    [string]$Source,
    [string]$RevisionSuffix,
    [string]$ServiceAccountKeyFile,
    [switch]$AllowUnauthenticated,
    [switch]$NoAllowUnauthenticated,
    [switch]$LoginIfNeeded,
    [switch]$Quiet,
    [string[]]$DeployArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$reservedDeployFlags = @(
    '--project',
    '--region',
    '--platform',
    '--image',
    '--source'
)

function Get-GCloudExecutable {
    $gcloudCmdCommand = Get-Command 'gcloud.cmd' -ErrorAction SilentlyContinue
    if ($null -ne $gcloudCmdCommand) {
        return $gcloudCmdCommand.Source
    }

    $gcloudCommand = Get-Command 'gcloud' -ErrorAction SilentlyContinue
    if ($null -ne $gcloudCommand) {
        return $gcloudCommand.Source
    }

    $candidatePaths = @(
        (Join-Path ${env:ProgramFiles} 'Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd'),
        (Join-Path ${env:LOCALAPPDATA} 'Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd'),
        (Join-Path ${env:ProgramFiles} 'Google\Cloud SDK\google-cloud-sdk\bin\gcloud.ps1'),
        (Join-Path ${env:LOCALAPPDATA} 'Google\Cloud SDK\google-cloud-sdk\bin\gcloud.ps1')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            return $candidatePath
        }
    }

    throw 'Unable to locate gcloud. Install the Google Cloud CLI and ensure it is available on PATH.'
}

function Invoke-GCloud {
    param(
        [string]$GCloudExecutable,
        [string[]]$Arguments,
        [switch]$IgnoreExitCode
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $hadNativeCommandPreference = Test-Path Variable:\PSNativeCommandUseErrorActionPreference
    if ($hadNativeCommandPreference) {
        $previousNativeCommandPreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    $ErrorActionPreference = 'Continue'

    try {
        $output = & $GCloudExecutable @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if ($hadNativeCommandPreference) {
            $PSNativeCommandUseErrorActionPreference = $previousNativeCommandPreference
        }
    }

    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        $message = ($output | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = 'gcloud returned a non-zero exit code without output.'
        }

        throw "gcloud command failed: $message"
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output   = ($output | Out-String).Trim()
    }
}

function Get-ActiveGCloudAccount {
    param([string]$GCloudExecutable)

    $result = Invoke-GCloud -GCloudExecutable $GCloudExecutable -Arguments @('auth', 'list', '--filter=status:ACTIVE', '--format=value(account)') -IgnoreExitCode
    if ($result.ExitCode -ne 0) {
        return $null
    }

    $account = $result.Output
    if ([string]::IsNullOrWhiteSpace($account)) {
        return $null
    }

    return $account.Trim()
}

function Test-DeployArgFlag {
    param(
        [string[]]$Arguments,
        [string]$Flag
    )

    if ($null -eq $Arguments -or $Arguments.Count -eq 0) {
        return $false
    }

    foreach ($argument in $Arguments) {
        if (-not [string]::IsNullOrWhiteSpace($argument) -and $argument -imatch ('^{0}(=|$)' -f [regex]::Escape($Flag))) {
            return $true
        }
    }

    return $false
}

function Assert-DeployArgsAreValid {
    param([string[]]$Arguments)

    if ($null -eq $Arguments -or $Arguments.Count -eq 0) {
        return
    }

    foreach ($reservedDeployFlag in $reservedDeployFlags) {
        if (Test-DeployArgFlag -Arguments $Arguments -Flag $reservedDeployFlag) {
            throw ("Do not pass {0} in -DeployArgs. Use the dedicated script parameter instead." -f $reservedDeployFlag)
        }
    }

    if ((Test-DeployArgFlag -Arguments $Arguments -Flag '--allow-unauthenticated') -and (Test-DeployArgFlag -Arguments $Arguments -Flag '--no-allow-unauthenticated')) {
        throw 'Do not pass both --allow-unauthenticated and --no-allow-unauthenticated in -DeployArgs.'
    }
}

function Resolve-KeyFilePath {
    param([string]$KeyFile)

    if ([string]::IsNullOrWhiteSpace($KeyFile)) {
        return $null
    }

    $resolvedPath = Resolve-Path -LiteralPath $KeyFile -ErrorAction Stop
    return $resolvedPath.Path
}

function Connect-GCloudServiceAccount {
    param(
        [string]$GCloudExecutable,
        [string]$KeyFile
    )

    $resolvedKeyFile = Resolve-KeyFilePath -KeyFile $KeyFile
    if ([string]::IsNullOrWhiteSpace($resolvedKeyFile)) {
        return $null
    }

    Write-Host ("Activating gcloud service account from key file: {0}" -f $resolvedKeyFile)
    Invoke-GCloud -GCloudExecutable $GCloudExecutable -Arguments @('auth', 'activate-service-account', '--key-file', $resolvedKeyFile) | Out-Null

    $activeAccount = Get-ActiveGCloudAccount -GCloudExecutable $GCloudExecutable
    if ([string]::IsNullOrWhiteSpace($activeAccount)) {
        throw 'Service account activation completed, but no active gcloud account is configured.'
    }

    return $activeAccount
}

function Connect-GCloudLogin {
    param(
        [string]$GCloudExecutable,
        [bool]$ShouldLogin
    )

    $activeAccount = Get-ActiveGCloudAccount -GCloudExecutable $GCloudExecutable
    if (-not [string]::IsNullOrWhiteSpace($activeAccount)) {
        return $activeAccount
    }

    if (-not $ShouldLogin) {
        throw 'No active gcloud account found. Run `gcloud auth login` first or rerun this script with -LoginIfNeeded.'
    }

    Write-Host 'No active gcloud account found. Starting interactive login.'
    & $GCloudExecutable auth login
    if ($LASTEXITCODE -ne 0) {
        throw 'gcloud auth login failed.'
    }

    $activeAccount = Get-ActiveGCloudAccount -GCloudExecutable $GCloudExecutable
    if ([string]::IsNullOrWhiteSpace($activeAccount)) {
        throw 'gcloud auth login completed, but no active account is configured.'
    }

    return $activeAccount
}

function Get-GCloudConfigValue {
    param(
        [string]$GCloudExecutable,
        [string]$Key
    )

    $result = Invoke-GCloud -GCloudExecutable $GCloudExecutable -Arguments @('config', 'get-value', $Key, '--quiet') -IgnoreExitCode
    if ($result.ExitCode -ne 0) {
        return $null
    }

    $value = $result.Output
    if ([string]::IsNullOrWhiteSpace($value) -or $value -eq '(unset)') {
        return $null
    }

    return $value.Trim()
}

function Resolve-Project {
    param(
        [string]$GCloudExecutable,
        [string]$ProjectName
    )

    if (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
        return $ProjectName.Trim()
    }

    $configuredProject = Get-GCloudConfigValue -GCloudExecutable $GCloudExecutable -Key 'project'
    if (-not [string]::IsNullOrWhiteSpace($configuredProject)) {
        return $configuredProject
    }

    throw 'No Google Cloud project was provided and no default project is configured. Pass -Project or run `gcloud config set project YOUR_PROJECT_ID`.'
}

function Resolve-Region {
    param(
        [string]$GCloudExecutable,
        [string]$RegionName
    )

    if (-not [string]::IsNullOrWhiteSpace($RegionName)) {
        return $RegionName.Trim()
    }

    $configuredRunRegion = Get-GCloudConfigValue -GCloudExecutable $GCloudExecutable -Key 'run/region'
    if (-not [string]::IsNullOrWhiteSpace($configuredRunRegion)) {
        return $configuredRunRegion
    }

    $configuredComputeRegion = Get-GCloudConfigValue -GCloudExecutable $GCloudExecutable -Key 'compute/region'
    if (-not [string]::IsNullOrWhiteSpace($configuredComputeRegion)) {
        return $configuredComputeRegion
    }

    throw 'No Cloud Run region was provided and no default region is configured. Pass -Region or run `gcloud config set run/region YOUR_REGION`.'
}

function Get-ResolvedSourcePath {
    param([string]$SourcePath)

    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        return $null
    }

    $resolvedPath = Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop
    return $resolvedPath.Path
}

if ($AllowUnauthenticated.IsPresent -and $NoAllowUnauthenticated.IsPresent) {
    throw 'Use either -AllowUnauthenticated or -NoAllowUnauthenticated, not both.'
}

if ([string]::IsNullOrWhiteSpace($Image) -and [string]::IsNullOrWhiteSpace($Source)) {
    throw 'Provide either -Image or -Source so the deployment target is explicit.'
}

if (-not [string]::IsNullOrWhiteSpace($Image) -and -not [string]::IsNullOrWhiteSpace($Source)) {
    throw 'Provide only one deployment target: -Image or -Source.'
}

Assert-DeployArgsAreValid -Arguments $DeployArgs

$deployArgsAllowUnauthenticated = Test-DeployArgFlag -Arguments $DeployArgs -Flag '--allow-unauthenticated'
$deployArgsNoAllowUnauthenticated = Test-DeployArgFlag -Arguments $DeployArgs -Flag '--no-allow-unauthenticated'
$hasMinInstancesArg = Test-DeployArgFlag -Arguments $DeployArgs -Flag '--min-instances'

if ($AllowUnauthenticated.IsPresent -and $deployArgsNoAllowUnauthenticated) {
    throw 'Do not combine -AllowUnauthenticated with --no-allow-unauthenticated in -DeployArgs.'
}

if ($NoAllowUnauthenticated.IsPresent -and $deployArgsAllowUnauthenticated) {
    throw 'Do not combine -NoAllowUnauthenticated with --allow-unauthenticated in -DeployArgs.'
}

$gcloudExecutable = Get-GCloudExecutable
$activeAccount = Connect-GCloudServiceAccount -GCloudExecutable $gcloudExecutable -KeyFile $ServiceAccountKeyFile
if ([string]::IsNullOrWhiteSpace($activeAccount)) {
    $activeAccount = Connect-GCloudLogin -GCloudExecutable $gcloudExecutable -ShouldLogin $LoginIfNeeded.IsPresent
}
$resolvedProject = Resolve-Project -GCloudExecutable $gcloudExecutable -ProjectName $Project
$resolvedRegion = Resolve-Region -GCloudExecutable $gcloudExecutable -RegionName $Region
$resolvedSource = Get-ResolvedSourcePath -SourcePath $Source

$arguments = New-Object System.Collections.Generic.List[string]
$arguments.Add('run')
$arguments.Add('deploy')
$arguments.Add($Service)
$arguments.Add('--platform')
$arguments.Add($Platform)
$arguments.Add('--project')
$arguments.Add($resolvedProject)
$arguments.Add('--region')
$arguments.Add($resolvedRegion)

if (-not [string]::IsNullOrWhiteSpace($Image)) {
    $arguments.Add('--image')
    $arguments.Add($Image.Trim())
}
else {
    $arguments.Add('--source')
    $arguments.Add($resolvedSource)
}

if (-not [string]::IsNullOrWhiteSpace($RevisionSuffix)) {
    $arguments.Add('--revision-suffix')
    $arguments.Add($RevisionSuffix.Trim())
}

if ($AllowUnauthenticated.IsPresent -and -not $deployArgsAllowUnauthenticated) {
    $arguments.Add('--allow-unauthenticated')
}

if ($NoAllowUnauthenticated.IsPresent -and -not $deployArgsNoAllowUnauthenticated) {
    $arguments.Add('--no-allow-unauthenticated')
}

if ($Quiet.IsPresent) {
    $arguments.Add('--quiet')
}

if ($null -ne $DeployArgs -and $DeployArgs.Count -gt 0) {
    foreach ($deployArg in $DeployArgs) {
        $arguments.Add($deployArg)
    }
}

if (-not $hasMinInstancesArg) {
    $arguments.Add('--min-instances')
    $arguments.Add('0')
}

Write-Host ("Active gcloud account: {0}" -f $activeAccount)
if (-not [string]::IsNullOrWhiteSpace($ServiceAccountKeyFile)) {
    Write-Host 'Authentication mode: service account key file'
}
elseif ($LoginIfNeeded.IsPresent) {
    Write-Host 'Authentication mode: active account or interactive login'
}
else {
    Write-Host 'Authentication mode: existing active gcloud account'
}
Write-Host ("Deploying service '{0}' to project '{1}' in region '{2}'" -f $Service, $resolvedProject, $resolvedRegion)

if (-not [string]::IsNullOrWhiteSpace($Image)) {
    Write-Host ("Deployment target: image {0}" -f $Image)
}
else {
    Write-Host ("Deployment target: source {0}" -f $resolvedSource)
}

if ($hasMinInstancesArg) {
    Write-Host 'Minimum instances: caller-specified'
}
else {
    Write-Host 'Minimum instances: 0 (default)'
}

$argumentArray = $arguments.ToArray()
& $gcloudExecutable @argumentArray
exit $LASTEXITCODE