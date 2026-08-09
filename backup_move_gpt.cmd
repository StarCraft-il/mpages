@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem ==========================================================
rem Hybrid Batch + PowerShell launcher
rem The PowerShell implementation is stored below this marker.
rem ==========================================================

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p = '%~f0'; $c = Get-Content -LiteralPath $p; $m = ':POWERSHELL'; $i = [Array]::IndexOf($c, $m); if($i -lt 0){ Write-Error 'PowerShell marker not found.'; exit 1 }; $s = $c[($i + 1)..($c.Length - 1)] -join [Environment]::NewLine; $env:SCRIPT_DIR = '%~dp0'; & ([scriptblock]::Create($s))"

exit /b %errorlevel%

:POWERSHELL
param()

# ==========================================================
# PowerShell implementation
# - Copies the content tree first
# - Moves the remaining root items afterward
# - Logs every major action and continues after errors
# ==========================================================

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ----------------------------
# Paths and log initialization
# ----------------------------
$scriptDir = $env:SCRIPT_DIR
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    $scriptDir = (Get-Location).Path
}

$logStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = Join-Path $scriptDir ("backup_move_{0}.log" -f $logStamp)

New-Item -Path $logFile -ItemType File -Force | Out-Null

# ----------------------------
# Summary counters
# ----------------------------
$script:CopiedFileCount = 0
$script:MovedFileCount = 0
$script:CreatedDirectoryCount = 0
$script:WarningCount = 0
$script:ErrorCount = 0

# ----------------------------
# Logging helpers
# ----------------------------
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '{0} [{1}] {2}' -f $timestamp, $Level, $Message

    Add-Content -LiteralPath $logFile -Value $line

    switch ($Level) {
        'INFO'  { Write-Host $line }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'ERROR' { Write-Host $line -ForegroundColor Red }
    }
}

function Add-Warning {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:WarningCount++
    Write-Log -Level 'WARN' -Message $Message
}

function Add-Error {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:ErrorCount++
    Write-Log -Level 'ERROR' -Message $Message
}

# ----------------------------
# Directory helper
# ----------------------------
function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            $script:CreatedDirectoryCount++
            Write-Log -Level 'INFO' -Message ("Created directory: {0}" -f $Path)
        }
    }
    catch {
        Add-Error -Message ("Failed to create directory '{0}': {1}" -f $Path, $_.Exception.Message)
        throw
    }
}

# ----------------------------
# Copy the content folder tree
# ----------------------------
function Copy-ContentTree {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceContent,

        [Parameter(Mandatory = $true)]
        [string]$DestinationContent
    )

    if (-not (Test-Path -LiteralPath $SourceContent -PathType Container)) {
        Add-Warning -Message ("Source content folder not found: {0}" -f $SourceContent)
        return
    }

    Write-Log -Level 'INFO' -Message ("Copy step started: {0} -> {1}" -f $SourceContent, $DestinationContent)
    Ensure-Directory -Path $DestinationContent

    $directories = @(Get-ChildItem -LiteralPath $SourceContent -Directory -Recurse -Force)
    $files = @(Get-ChildItem -LiteralPath $SourceContent -File -Recurse -Force)
    $total = $directories.Count + $files.Count
    $current = 0

    foreach ($dir in $directories) {
        $current++
        $relativeDir = $dir.FullName.Substring($SourceContent.Length).TrimStart('\')
        $targetDir = Join-Path $DestinationContent $relativeDir

        try {
            Ensure-Directory -Path $targetDir
            Write-Log -Level 'INFO' -Message ("Created/copied directory: {0} -> {1}" -f $dir.FullName, $targetDir)
        }
        catch {
            Add-Error -Message ("Directory copy failed for '{0}': {1}" -f $dir.FullName, $_.Exception.Message)
        }

        if ($total -gt 0) {
            $percent = [int](($current / $total) * 100)
            Write-Progress -Activity 'Copying content tree' -Status $dir.FullName -PercentComplete $percent
        }
    }

    foreach ($file in $files) {
        $current++
        $relativeFile = $file.FullName.Substring($SourceContent.Length).TrimStart('\')
        $targetFile = Join-Path $DestinationContent $relativeFile
        $targetDir = Split-Path -Parent $targetFile

        try {
            Ensure-Directory -Path $targetDir
            Copy-Item -LiteralPath $file.FullName -Destination $targetFile -Force -ErrorAction Stop
            $script:CopiedFileCount++
            Write-Log -Level 'INFO' -Message ("Copied file: {0} -> {1}" -f $file.FullName, $targetFile)
        }
        catch {
            Add-Error -Message ("File copy failed for '{0}': {1}" -f $file.FullName, $_.Exception.Message)
        }

        if ($total -gt 0) {
            $percent = [int](($current / $total) * 100)
            Write-Progress -Activity 'Copying content tree' -Status $file.FullName -PercentComplete $percent
        }
    }

    Write-Progress -Activity 'Copying content tree' -Completed
    Write-Log -Level 'INFO' -Message ("Copy step completed: {0}" -f $SourceContent)
}

# ----------------------------
# Move all root items except content
# ----------------------------
function Move-RootItemsExcludingContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot
    )

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        Add-Error -Message ("Source folder not found: {0}" -f $SourceRoot)
        return
    }

    Ensure-Directory -Path $DestinationRoot

    $items = @(Get-ChildItem -LiteralPath $SourceRoot -Force | Where-Object { $_.Name -ne 'content' })
    $total = $items.Count
    $current = 0

    Write-Log -Level 'INFO' -Message ("Move step started: {0} -> {1} (excluding content)" -f $SourceRoot, $DestinationRoot)

    foreach ($item in $items) {
        $current++
        $targetPath = Join-Path $DestinationRoot $item.Name

        try {
            if (Test-Path -LiteralPath $targetPath) {
                Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction Stop
                Add-Warning -Message ("Overwriting existing destination item: {0}" -f $targetPath)
            }

            $fileCount = 0
            if ($item.PSIsContainer) {
                $fileCount = @(Get-ChildItem -LiteralPath $item.FullName -File -Recurse -Force).Count
            }
            else {
                $fileCount = 1
            }

            Move-Item -LiteralPath $item.FullName -Destination $targetPath -Force -ErrorAction Stop
            $script:MovedFileCount += $fileCount

            if ($item.PSIsContainer) {
                Write-Log -Level 'INFO' -Message ("Moved folder: {0} -> {1} (files: {2})" -f $item.FullName, $targetPath, $fileCount)
            }
            else {
                Write-Log -Level 'INFO' -Message ("Moved file: {0} -> {1}" -f $item.FullName, $targetPath)
            }
        }
        catch {
            Add-Error -Message ("Move failed for '{0}': {1}" -f $item.FullName, $_.Exception.Message)
        }

        if ($total -gt 0) {
            $percent = [int](($current / $total) * 100)
            Write-Progress -Activity 'Moving root items' -Status $item.FullName -PercentComplete $percent
        }
    }

    Write-Progress -Activity 'Moving root items' -Completed
    Write-Log -Level 'INFO' -Message ("Move step completed: {0}" -f $SourceRoot)
}

# ----------------------------
# Main execution
# ----------------------------
try {
    $startTime = Get-Date
    Write-Log -Level 'INFO' -Message ("Start time: {0}" -f $startTime.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Log -Level 'INFO' -Message ("Log file: {0}" -f $logFile)
    Write-Log -Level 'INFO' -Message ("Script directory: {0}" -f $scriptDir)

    $folderSets = @(
        [pscustomobject]@{
            Name            = 'Folder Set #1'
            SourceRoot      = 'C:\Git!myRepos\mpages\m1t2'
            SourceContent   = 'C:\Git!myRepos\mpages\m1t2\content'
            DestinationRoot = 'C:\Git!myRepos\mpages\old\m1t2'
            DestinationContent = 'C:\Git!myRepos\mpages\old\m1t2\content'
        },
        [pscustomobject]@{
            Name            = 'Folder Set #2'
            SourceRoot      = 'C:\Git!myRepos\mpages\pdf\_scroll'
            SourceContent   = 'C:\Git!myRepos\mpages\pdf\_scroll\content'
            DestinationRoot = 'C:\Git!myRepos\mpages\old\pdf\_scroll'
            DestinationContent = 'C:\Git!myRepos\mpages\old\pdf\_scroll\content'
        }
    )

    foreach ($set in $folderSets) {
        Write-Log -Level 'INFO' -Message ("Processing {0}" -f $set.Name)

        try {
            Copy-ContentTree -SourceContent $set.SourceContent -DestinationContent $set.DestinationContent
        }
        catch {
            Add-Error -Message ("Unexpected copy-stage failure in {0}: {1}" -f $set.Name, $_.Exception.Message)
        }

        try {
            Move-RootItemsExcludingContent -SourceRoot $set.SourceRoot -DestinationRoot $set.DestinationRoot
        }
        catch {
            Add-Error -Message ("Unexpected move-stage failure in {0}: {1}" -f $set.Name, $_.Exception.Message)
        }

        Write-Log -Level 'INFO' -Message ("Finished {0}" -f $set.Name)
    }

    $endTime = Get-Date
    Write-Log -Level 'INFO' -Message ("End time: {0}" -f $endTime.ToString('yyyy-MM-dd HH:mm:ss'))

    Write-Host ''
    Write-Host '================ SUMMARY ================'
    Write-Host ('Files copied      : {0}' -f $script:CopiedFileCount)
    Write-Host ('Files moved       : {0}' -f $script:MovedFileCount)
    Write-Host ('Directories created: {0}' -f $script:CreatedDirectoryCount)
    Write-Host ('Warnings          : {0}' -f $script:WarningCount)
    Write-Host ('Errors encountered: {0}' -f $script:ErrorCount)
    Write-Host ('Log file location : {0}' -f $logFile)
    Write-Host '========================================='

    Write-Log -Level 'INFO' -Message ('Summary: files copied={0}, files moved={1}, directories created={2}, warnings={3}, errors={4}' -f $script:CopiedFileCount, $script:MovedFileCount, $script:CreatedDirectoryCount, $script:WarningCount, $script:ErrorCount)
}
catch {
    Add-Error -Message ("Fatal error: {0}" -f $_.Exception.Message)
}
finally {
    Write-Progress -Activity 'Copying content tree' -Completed
    Write-Progress -Activity 'Moving root items' -Completed
}

if ($script:ErrorCount -gt 0) {
    exit 1
}

exit 0
