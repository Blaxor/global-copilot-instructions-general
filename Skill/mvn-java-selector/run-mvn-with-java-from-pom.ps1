[CmdletBinding()]
param(
    [string]$PomPath = ".\pom.xml",
    [string]$JavaBasePath = "C:\Program Files\Java",
    [bool]$CreateStableLink = $true,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$MavenArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-XmlNamespaceManager {
    param([xml]$XmlDocument)

    $namespaceManager = New-Object System.Xml.XmlNamespaceManager($XmlDocument.NameTable)
    $projectNamespace = $XmlDocument.DocumentElement.NamespaceURI

    if (-not [string]::IsNullOrWhiteSpace($projectNamespace)) {
        $namespaceManager.AddNamespace('m', $projectNamespace)
    }

    return $namespaceManager
}

function ConvertTo-XPathForDocument {
    param(
        [xml]$XmlDocument,
        [string]$XPath
    )

    if ([string]::IsNullOrWhiteSpace($XmlDocument.DocumentElement.NamespaceURI)) {
        return ($XPath -replace 'm:', '')
    }

    return $XPath
}

function Get-NodeText {
    param(
        [xml]$XmlDocument,
        [System.Xml.XmlNamespaceManager]$NamespaceManager,
        [string]$XPath
    )

    $resolvedXPath = ConvertTo-XPathForDocument -XmlDocument $XmlDocument -XPath $XPath
    if ([string]::IsNullOrWhiteSpace($XmlDocument.DocumentElement.NamespaceURI)) {
        $node = $XmlDocument.SelectSingleNode($resolvedXPath)
    }
    else {
        $node = $XmlDocument.SelectSingleNode($resolvedXPath, $NamespaceManager)
    }

    if ($null -eq $node) {
        return $null
    }

    $value = $node.InnerText
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return $value.Trim()
}

function Get-PomProperties {
    param(
        [xml]$XmlDocument,
        [System.Xml.XmlNamespaceManager]$NamespaceManager
    )

    $properties = @{}
    $propertyXPath = ConvertTo-XPathForDocument -XmlDocument $XmlDocument -XPath '/m:project/m:properties/*'
    if ([string]::IsNullOrWhiteSpace($XmlDocument.DocumentElement.NamespaceURI)) {
        $propertyNodes = $XmlDocument.SelectNodes($propertyXPath)
    }
    else {
        $propertyNodes = $XmlDocument.SelectNodes($propertyXPath, $NamespaceManager)
    }

    if ($null -eq $propertyNodes) {
        return $properties
    }

    foreach ($propertyNode in $propertyNodes) {
        $key = $propertyNode.LocalName
        $value = $propertyNode.InnerText
        if (-not [string]::IsNullOrWhiteSpace($key) -and -not [string]::IsNullOrWhiteSpace($value)) {
            $properties[$key] = $value.Trim()
        }
    }

    return $properties
}

function Resolve-PropertyValue {
    param(
        [string]$Value,
        [hashtable]$Properties
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $resolvedValue = $Value.Trim()
    $visited = New-Object 'System.Collections.Generic.HashSet[string]'

    while ($resolvedValue -match '^\$\{(?<name>[^}]+)\}$') {
        $propertyName = $matches['name']
        if (-not $visited.Add($propertyName)) {
            throw "Circular Maven property reference detected for '$propertyName'."
        }

        if (-not $Properties.ContainsKey($propertyName)) {
            return $resolvedValue
        }

        $resolvedValue = [string]$Properties[$propertyName]
    }

    return $resolvedValue
}

function ConvertTo-JavaMajorVersion {
    param([string]$VersionText)

    if ([string]::IsNullOrWhiteSpace($VersionText)) {
        return $null
    }

    $trimmedVersion = $VersionText.Trim()

    if ($trimmedVersion -match '^1\.(?<legacy>\d+)') {
        return [int]$matches['legacy']
    }

    if ($trimmedVersion -match '^(?<major>\d+)') {
        return [int]$matches['major']
    }

    throw "Unable to convert Java version '$VersionText' to a major version."
}

function Get-JavaVersionFromPom {
    param([string]$ResolvedPomPath)

    if (-not (Test-Path -LiteralPath $ResolvedPomPath -PathType Leaf)) {
        throw "The pom.xml file was not found at '$ResolvedPomPath'."
    }

    [xml]$pomXml = Get-Content -LiteralPath $ResolvedPomPath -Raw
    $namespaceManager = Get-XmlNamespaceManager -XmlDocument $pomXml
    $properties = Get-PomProperties -XmlDocument $pomXml -NamespaceManager $namespaceManager

    $candidateValues = @(
        Get-NodeText -XmlDocument $pomXml -NamespaceManager $namespaceManager -XPath '/m:project/m:properties/m:maven.compiler.release',
        Get-NodeText -XmlDocument $pomXml -NamespaceManager $namespaceManager -XPath '/m:project/m:properties/m:java.version',
        Get-NodeText -XmlDocument $pomXml -NamespaceManager $namespaceManager -XPath '/m:project/m:properties/m:maven.compiler.target',
        Get-NodeText -XmlDocument $pomXml -NamespaceManager $namespaceManager -XPath '/m:project/m:build/m:plugins/m:plugin[m:artifactId="maven-compiler-plugin"]/m:configuration/m:release',
        Get-NodeText -XmlDocument $pomXml -NamespaceManager $namespaceManager -XPath '/m:project/m:build/m:plugins/m:plugin[m:artifactId="maven-compiler-plugin"]/m:configuration/m:target',
        Get-NodeText -XmlDocument $pomXml -NamespaceManager $namespaceManager -XPath '/m:project/m:build/m:plugins/m:plugin[m:artifactId="maven-compiler-plugin"]/m:configuration/m:source',
        Get-NodeText -XmlDocument $pomXml -NamespaceManager $namespaceManager -XPath '/m:project/m:build/m:pluginManagement/m:plugins/m:plugin[m:artifactId="maven-compiler-plugin"]/m:configuration/m:release',
        Get-NodeText -XmlDocument $pomXml -NamespaceManager $namespaceManager -XPath '/m:project/m:build/m:pluginManagement/m:plugins/m:plugin[m:artifactId="maven-compiler-plugin"]/m:configuration/m:target',
        Get-NodeText -XmlDocument $pomXml -NamespaceManager $namespaceManager -XPath '/m:project/m:build/m:pluginManagement/m:plugins/m:plugin[m:artifactId="maven-compiler-plugin"]/m:configuration/m:source'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidateValue in $candidateValues) {
        $resolvedValue = Resolve-PropertyValue -Value $candidateValue -Properties $properties
        if (-not [string]::IsNullOrWhiteSpace($resolvedValue)) {
            return ConvertTo-JavaMajorVersion -VersionText $resolvedValue
        }
    }

    throw "Unable to determine the Java version from '$ResolvedPomPath'."
}

function Get-JavaCandidate {
    param([string]$JavaHomePath)

    $javaExecutable = Join-Path $JavaHomePath 'bin\java.exe'
    if (-not (Test-Path -LiteralPath $javaExecutable -PathType Leaf)) {
        return $null
    }

    $javacExecutable = Join-Path $JavaHomePath 'bin\javac.exe'
    $versionOutput = & $javaExecutable -version 2>&1 | Out-String

    if ($versionOutput -notmatch '"(?<version>[^"]+)"') {
        return $null
    }

    return [PSCustomObject]@{
        JavaHome = $JavaHomePath
        MajorVersion = ConvertTo-JavaMajorVersion -VersionText $matches['version']
        IsJdk = Test-Path -LiteralPath $javacExecutable -PathType Leaf
        Name = Split-Path -Path $JavaHomePath -Leaf
    }
}

function Resolve-JavaHome {
    param(
        [string]$BasePath,
        [int]$RequiredMajorVersion,
        [bool]$ShouldCreateStableLink
    )

    if (-not (Test-Path -LiteralPath $BasePath)) {
        New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
    }

    $stableAliasPath = Join-Path $BasePath ("jdk-{0}" -f $RequiredMajorVersion)
    $stableAliasCandidate = $null

    if (Test-Path -LiteralPath $stableAliasPath -PathType Container) {
        $stableAliasCandidate = Get-JavaCandidate -JavaHomePath $stableAliasPath
        if ($null -ne $stableAliasCandidate -and $stableAliasCandidate.MajorVersion -eq $RequiredMajorVersion) {
            return $stableAliasCandidate.JavaHome
        }
    }

    $matchingCandidates = New-Object System.Collections.Generic.List[object]
    $candidateDirectories = Get-ChildItem -LiteralPath $BasePath -Directory -ErrorAction SilentlyContinue

    foreach ($candidateDirectory in $candidateDirectories) {
        $candidate = Get-JavaCandidate -JavaHomePath $candidateDirectory.FullName
        if ($null -eq $candidate) {
            continue
        }

        if ($candidate.MajorVersion -eq $RequiredMajorVersion) {
            [void]$matchingCandidates.Add($candidate)
        }
    }

    if ($matchingCandidates.Count -eq 0) {
        throw "Java $RequiredMajorVersion was not found under '$BasePath'. Install a matching JDK under that path and try again."
    }

    $selectedCandidate = $matchingCandidates |
        Sort-Object -Property @(
            @{ Expression = { if ($_.Name -ieq ("jdk-{0}" -f $RequiredMajorVersion)) { 1 } else { 0 } }; Descending = $true },
            @{ Expression = { if ($_.IsJdk) { 1 } else { 0 } }; Descending = $true },
            @{ Expression = { $_.Name }; Descending = $true }
        ) |
        Select-Object -First 1

    if ($ShouldCreateStableLink -and -not (Test-Path -LiteralPath $stableAliasPath)) {
        try {
            New-Item -ItemType Junction -Path $stableAliasPath -Target $selectedCandidate.JavaHome -Force | Out-Null
            return $stableAliasPath
        }
        catch {
            Write-Warning "Unable to create stable alias '$stableAliasPath'. Using '$($selectedCandidate.JavaHome)' directly. $($_.Exception.Message)"
        }
    }

    return $selectedCandidate.JavaHome
}

function Get-MavenExecutable {
    param([string]$ProjectRoot)

    $wrapperPath = Join-Path $ProjectRoot 'mvnw.cmd'
    if (Test-Path -LiteralPath $wrapperPath -PathType Leaf) {
        return $wrapperPath
    }

    $mavenCommand = Get-Command 'mvn.cmd' -ErrorAction SilentlyContinue
    if ($null -ne $mavenCommand) {
        return $mavenCommand.Source
    }

    $mavenWithoutExtension = Get-Command 'mvn' -ErrorAction SilentlyContinue
    if ($null -ne $mavenWithoutExtension) {
        return $mavenWithoutExtension.Source
    }

    throw 'Unable to locate Maven. Add Maven to PATH or use a project that provides mvnw.cmd.'
}

if ($null -eq $MavenArgs -or $MavenArgs.Count -eq 0) {
    throw 'Provide Maven arguments, for example: clean verify'
}

$resolvedPomPath = (Resolve-Path -LiteralPath $PomPath).Path
$projectRoot = Split-Path -Path $resolvedPomPath -Parent
$requiredJavaVersion = Get-JavaVersionFromPom -ResolvedPomPath $resolvedPomPath
$resolvedJavaHome = Resolve-JavaHome -BasePath $JavaBasePath -RequiredMajorVersion $requiredJavaVersion -ShouldCreateStableLink $CreateStableLink
$mavenExecutable = Get-MavenExecutable -ProjectRoot $projectRoot

Write-Host ("Using Java {0} from {1}" -f $requiredJavaVersion, $resolvedJavaHome)
Write-Host ("Running Maven with {0}" -f $mavenExecutable)

$previousJavaHome = $env:JAVA_HOME
$previousPath = $env:PATH
$exitCode = 0

try {
    $env:JAVA_HOME = $resolvedJavaHome
    $env:PATH = (Join-Path $resolvedJavaHome 'bin') + ';' + $previousPath

    & $mavenExecutable @MavenArgs
    $exitCode = $LASTEXITCODE
}
finally {
    $env:JAVA_HOME = $previousJavaHome
    $env:PATH = $previousPath
}

exit $exitCode
