<#
.SYNOPSIS
This script sets up shared GitHub Copilot skills for a project.

.DESCRIPTION
- Clones or updates the skills repo: https://github.com/Blaxor/global-copilot-instructions-general.git
- Creates symlinks to the "Skill" folder for:
    • VS Code: .github\skills
    • IntelliJ IDEA: docs\copilot\skills
- Automatically updates existing links if needed
- Safe to run multiple times

.NOTES
- If symlink creation fails, it falls back to using a junction
- Run PowerShell as Administrator for proper symlink permissions
- Designed to be reusable across multiple projects
#>

$ErrorActionPreference = "Stop"

$REPO_URL = "https://github.com/Blaxor/global-copilot-instructions-general.git"
$BASE_DIR = ".copilot-shared\global"
$SKILL_SOURCE = "$BASE_DIR\Skill"

$VS_LINK = ".github\skills"
$IJ_LINK = "docs\skills"

Write-Host "🚀 Setting up shared Copilot skills..."

# Clone or update repo
if (!(Test-Path "$BASE_DIR\.git")) {
    Write-Host "[INFO] Cloning repository..."
    New-Item -ItemType Directory -Force -Path ".copilot-shared" | Out-Null
    git clone $REPO_URL $BASE_DIR
}
else {
    Write-Host "[INFO] Updating repository..."
    git -C $BASE_DIR pull --rebase
}
# Ensure folders exist
New-Item -ItemType Directory -Force -Path ".github" | Out-Null
New-Item -ItemType Directory -Force -Path "docs" | Out-Null

function Update-Link($linkPath, $targetPath) {
    if (Test-Path $linkPath) {
        $item = Get-Item $linkPath -Force

        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $currentTarget = (Get-Item $linkPath).Target

            if ($currentTarget -eq $targetPath) {
                Write-Host "[OK] Link OK: $linkPath"
                return
            }
            else {
                Write-Host "[FIX] Fixing wrong link: $linkPath"
                Remove-Item $linkPath -Force
            }
        }
        else {
            Write-Host "[WARN] Exists but not a symlink, replacing: $linkPath"
            Remove-Item $linkPath -Recurse -Force
        }
    }

    Write-Host "[LINK] Creating link: $linkPath"
    try {
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath | Out-Null
    }
    catch {
        Write-Host "[JUNC] Symlink failed, using junction instead..."
        cmd /c mklink /J $linkPath $targetPath | Out-Null
    }
}

# Create/fix links
Update-Link $VS_LINK $SKILL_SOURCE
Update-Link $IJ_LINK $SKILL_SOURCE

Write-Host "✅ Copilot skills setup complete!"