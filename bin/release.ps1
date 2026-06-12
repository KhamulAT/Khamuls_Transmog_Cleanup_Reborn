# Packages the addon for release.
#
# Builds Release_Archive\<VERSION>.zip (version read from the retail TOC),
# containing a single top-level folder named after the addon with only the
# files required at runtime (allowlist below).
#
# Usage:
#   .\release.ps1                # package for all supported clients
#   .\release.ps1 -RetailOnly    # omit the Mists TOC (retail-only release)

param(
    [switch]$RetailOnly
)

$ErrorActionPreference = "Stop"

# -------------------------
# Config
# -------------------------

$AddonName = "Khamuls_Transmog_Cleanup_Reborn"

# Only these items end up in the package.
$IncludeFiles = @(
    "$AddonName.toc",
    "$AddonName`_Mists.toc",
    "LICENSE",
    "README.md"
)
$IncludeDirs = @(
    "Libs",
    "Locales",
    "Source"
)

# -------------------------
# Resolve paths
# -------------------------

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceRoot = Resolve-Path (Join-Path $ScriptDir "..") | Select-Object -ExpandProperty Path
$ReleaseDir = Join-Path $SourceRoot "Release_Archive"

# -------------------------
# Read version from the retail TOC
# -------------------------

$TocPath = Join-Path $SourceRoot "$AddonName.toc"
if (-not (Test-Path $TocPath)) {
    throw "TOC not found: $TocPath"
}

$versionMatch = Select-String -LiteralPath $TocPath -Pattern '^## Version:\s*(.+?)\s*$' | Select-Object -First 1
if (-not $versionMatch) {
    throw "No '## Version:' line found in $TocPath"
}
$Version = $versionMatch.Matches[0].Groups[1].Value

Write-Host "Addon:   $AddonName"
Write-Host "Version: $Version"
if ($RetailOnly) { Write-Host "Mode:    retail only (Mists TOC excluded)" }

# -------------------------
# Stage files
# -------------------------

$StagingRoot = Join-Path $env:TEMP "ktcr_release_$PID"
$StagingDir  = Join-Path $StagingRoot $AddonName

if (Test-Path $StagingRoot) {
    Remove-Item -LiteralPath $StagingRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $StagingDir | Out-Null

foreach ($file in $IncludeFiles) {
    if ($RetailOnly -and $file -like "*_Mists.toc") { continue }
    $src = Join-Path $SourceRoot $file
    if (Test-Path $src) {
        Copy-Item -LiteralPath $src -Destination $StagingDir
    } else {
        Write-Warning "Skipping missing file: $file"
    }
}

foreach ($dir in $IncludeDirs) {
    $src = Join-Path $SourceRoot $dir
    if (-not (Test-Path $src)) {
        throw "Required directory missing: $dir"
    }
    Copy-Item -LiteralPath $src -Destination $StagingDir -Recurse
}

# Strip development leftovers that may live inside included directories.
Get-ChildItem -Path $StagingDir -Recurse -Force -Directory |
    Where-Object { $_.Name -in @(".git", ".vscode") } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
Get-ChildItem -Path $StagingDir -Recurse -Force -File |
    Where-Object { $_.Name -in @(".gitignore", ".gitattributes") } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }

# -------------------------
# Create the zip
# -------------------------

if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

$ZipPath = Join-Path $ReleaseDir "$Version.zip"
if (Test-Path $ZipPath) {
    Write-Warning "Overwriting existing $ZipPath"
    Remove-Item -LiteralPath $ZipPath -Force
}

Compress-Archive -Path $StagingDir -DestinationPath $ZipPath

Remove-Item -LiteralPath $StagingRoot -Recurse -Force

Write-Host "Created: $ZipPath"
