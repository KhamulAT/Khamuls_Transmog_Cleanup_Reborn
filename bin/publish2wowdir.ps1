# -------------------------
# Config
# -------------------------

# Debounce window (ms): wait this long without new triggers before deploying
$DebounceMs = 750

# Lock behavior
$LockWaitMs       = 15000  # max time to wait for an existing deploy to finish
$LockPollInterval = 200    # poll interval while waiting for lock

# -------------------------
# Resolve paths (repo root + env)
# -------------------------

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceRoot = Resolve-Path (Join-Path $ScriptDir "..") | Select-Object -ExpandProperty Path

# Prefer .env next to script; allow override via -EnvPath if you want later
$EnvPath = Join-Path $ScriptDir ".env"
if (-not (Test-Path $EnvPath)) {
    throw "Missing .env file at: $EnvPath"
}

function Import-DotEnv {
    param([Parameter(Mandatory)][string]$Path)

    $result = @{}

    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) { return }
        if ($line.StartsWith("#")) { return }

        # allow "export KEY=VALUE"
        if ($line.StartsWith("export ")) { $line = $line.Substring(7).Trim() }

        $idx = $line.IndexOf("=")
        if ($idx -lt 1) { return }

        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()

        # remove optional surrounding quotes
        if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
            $val = $val.Substring(1, $val.Length - 2)
        }

        if ($key) { $result[$key] = $val }
    }

    return $result
}

function Get-EnvList {
    param(
        [hashtable]$Env,
        [Parameter(Mandatory)][string]$Key
    )

    if (-not $Env.ContainsKey($Key) -or [string]::IsNullOrWhiteSpace($Env[$Key])) {
        return @()
    }

    return $Env[$Key].Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}

$envVars = Import-DotEnv -Path $EnvPath

$WoWRootFolder    = $envVars["WoWRootFolder"]
$AddonFolder      = $envVars["AddonFolder"]
$WoWClientsFolder = Get-EnvList -Env $envVars -Key "WoWClientsFolder"

if ([string]::IsNullOrWhiteSpace($WoWRootFolder)) { throw "WoWRootFolder is missing in .env" }
if ([string]::IsNullOrWhiteSpace($AddonFolder))   { throw "AddonFolder is missing in .env" }
if ($WoWClientsFolder.Count -lt 1)                { throw "WoWClientsFolder is missing/empty in .env" }

$ExcludeDirs  = Get-EnvList -Env $envVars -Key "ExcludedDirs"
$ExcludeFiles = Get-EnvList -Env $envVars -Key "ExcludedFiles"

# Provide sane defaults if not specified
if ($ExcludeDirs.Count -eq 0) {
    $ExcludeDirs = @(".git", ".vscode", "bin", "Release_Archive", "Resources")
}
if ($ExcludeFiles.Count -eq 0) {
    $ExcludeFiles = @(".gitignore")
}

# -------------------------
# Build target roots
# -------------------------

$TargetRoots = foreach ($client in $WoWClientsFolder) {
    Join-Path $WoWRootFolder (Join-Path $client (Join-Path "Interface\AddOns" $AddonFolder))
}

Write-Host "Source: $SourceRoot"
Write-Host "Targets:"
$TargetRoots | ForEach-Object { Write-Host "  - $_" }

# -------------------------
# Safety guard (recommended)
# -------------------------

foreach ($t in $TargetRoots) {
    if ($t -notmatch '\\Interface\\AddOns\\') {
        throw "Safety guard triggered: TargetRoot does not look like a WoW AddOns path: $t"
    }
}

Write-Host "Excluded directories: $($ExcludeDirs -join ', ')"
Write-Host "Excluded files: $($ExcludeFiles -join ', ')"

# -------------------------
# Lock + Debounce helpers
# -------------------------

function Acquire-Lock {
    param(
        [string]$Path,
        [int]$WaitMs,
        [int]$PollMs
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($WaitMs)

    while ($true) {
        try {
            $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            $writer = New-Object System.IO.StreamWriter($fs)
            $writer.WriteLine("pid=$PID")
            $writer.WriteLine("time_utc=$([DateTime]::UtcNow.ToString('o'))")
            $writer.Flush()
            $writer.Dispose()
            $fs.Dispose()
            return
        }
        catch {
            if ([DateTime]::UtcNow -ge $deadline) {
                throw "Timeout waiting for deploy lock: $Path"
            }
            Start-Sleep -Milliseconds $PollMs
        }
    }
}

function Release-Lock {
    param([string]$Path)
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
    }
}

function Touch-File {
    param([string]$Path)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
    Set-Content -Path $Path -Value "$([DateTime]::UtcNow.ToString('o'))" -Encoding ASCII
}

function Deploy-ToTarget {
    param(
        [Parameter(Mandatory)][string]$TargetRoot
    )

    $LockPath     = Join-Path $TargetRoot ".deploy.lock"
    $DebouncePath = Join-Path $TargetRoot ".deploy.debounce"

    # Ensure target exists (needed for lock/debounce files)
    if (-not (Test-Path $TargetRoot)) {
        New-Item -ItemType Directory -Path $TargetRoot | Out-Null
    }

    # -------------------------
    # Debounce: coalesce rapid triggers
    # -------------------------

    Touch-File -Path $DebouncePath

    while ($true) {
        $t1 = (Get-Item $DebouncePath).LastWriteTimeUtc
        Start-Sleep -Milliseconds $DebounceMs
        $t2 = (Get-Item $DebouncePath).LastWriteTimeUtc

        if ($t1 -eq $t2) { break }
    }

    Acquire-Lock -Path $LockPath -WaitMs $LockWaitMs -PollMs $LockPollInterval

    try {
        # Re-check debounce after lock
        $tBefore = (Get-Item $DebouncePath).LastWriteTimeUtc
        Start-Sleep -Milliseconds $DebounceMs
        $tAfter = (Get-Item $DebouncePath).LastWriteTimeUtc
        if ($tBefore -ne $tAfter) {
            Write-Host "[$TargetRoot] New save detected while waiting for lock; restarting debounce..."
            Release-Lock -Path $LockPath
            Deploy-ToTarget -TargetRoot $TargetRoot
            return
        }

        Write-Host "[$TargetRoot] Cleaning target directory..."
        Get-ChildItem -Path $TargetRoot -Force | Where-Object {
            $_.Name -notin @(".deploy.lock", ".deploy.debounce")
        } | ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction Stop
        }

        $null = robocopy `
            $SourceRoot `
            $TargetRoot `
            /E `
            /COPY:DAT /DCOPY:DAT `
            /XD @($ExcludeDirs) `
            /XF @($ExcludeFiles) `
            /R:2 /W:1 `
            /NFL /NDL /NJH /NJS /NP

        if ($LASTEXITCODE -ge 8) {
            throw "[$TargetRoot] Robocopy failed with exit code $LASTEXITCODE"
        }

        Write-Host "[$TargetRoot] Deployed successfully. (Robocopy exit code: $LASTEXITCODE)"
    }
    finally {
        Release-Lock -Path $LockPath
    }
}

# -------------------------
# Deploy to all targets
# -------------------------

foreach ($t in $TargetRoots) {
    Deploy-ToTarget -TargetRoot $t
}