@echo off
setlocal
set "HYBRID_SCRIPT=%~f0"
where pwsh.exe >nul 2>&1
if errorlevel 1 (echo ERROR: PowerShell 7 ^(pwsh.exe^) was not found. & pause & exit /b 9009)
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& { param([string]$scriptPath) $scriptText = (Get-Content -LiteralPath $scriptPath | Select-Object -Skip 10) -join [Environment]::NewLine; & ([ScriptBlock]::Create($scriptText)) }" "%~f0"
set "HYBRID_EXIT_CODE=%ERRORLEVEL%"
echo.
pause
exit /b %HYBRID_EXIT_CODE%
#requires -Version 7.0

<#+
.SYNOPSIS
    Copies each content folder, then moves all remaining items while excluding content.
.DESCRIPTION
    This is the PowerShell portion of a self-contained Hybrid Batch + PowerShell script.
    Double-click the .cmd file to run it. No command-line parameters are required.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
# Logging types and shared execution state
# -----------------------------------------------------------------------------
enum TDLogLevel {
    Info
    Success
    Warning
    Error
}

$script:Statistics = [ordered]@{
    FilesCopied       = 0
    FilesMoved        = 0
    DirectoriesCreated = 0
    Warnings           = 0
    Errors             = 0
}

$script:LogWriter = $null
$script:StartTime = [DateTime]::Now
$script:ScriptDirectory = Split-Path -Parent $env:HYBRID_SCRIPT
$script:LogFilePath = Join-Path $script:ScriptDirectory ("backup_move_{0}.log" -f $script:StartTime.ToString('yyyyMMdd_HHmmss'))

function Get-ConsoleColor {
    param([TDLogLevel]$Level)

    switch ($Level) {
        ([TDLogLevel]::Success) { return [System.ConsoleColor]::Green }
        ([TDLogLevel]::Warning) { return [System.ConsoleColor]::Yellow }
        ([TDLogLevel]::Error)   { return [System.ConsoleColor]::Red }
        default                 { return [System.ConsoleColor]::Cyan }
    }
}

function Write-TDLog {
    param(
        [Parameter(Mandatory)]
        [TDLogLevel]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff')
    $entry = '[{0}] [{1}] {2}' -f $timestamp, $Level.ToString().ToUpperInvariant(), $Message

    Write-Host $entry -ForegroundColor (Get-ConsoleColor -Level $Level)

    if ($null -eq $script:LogWriter) {
        return
    }

    try {
        # Uses the asynchronous StreamWriter API without timers or background polling.
        #$script:LogWriter.WriteLineAsync($entry).GetAwaiter().GetResult()
		
		$null = $script:LogWriter.WriteLineAsync($entry).GetAwaiter().GetResult()
    }
    catch {
        Write-Host "LOGGING ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $script:Statistics.Errors++
    }
}

function Register-Warning {
    param([Parameter(Mandatory)][string]$Message)

    $script:Statistics.Warnings++
    Write-TDLog -Level Warning -Message $Message
}

function Register-Error {
    param(
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $script:Statistics.Errors++
    $message = '{0} failed for "{1}". {2}' -f $Operation, $Path, $ErrorRecord.Exception.Message
    Write-TDLog -Level Error -Message $message
}

# -----------------------------------------------------------------------------
# Directory and path helpers
# -----------------------------------------------------------------------------
function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)

    if ([System.IO.Directory]::Exists($Path)) {
        return $true
    }

    try {
        [System.IO.Directory]::CreateDirectory($Path) | Out-Null
        $script:Statistics.DirectoriesCreated++
        Write-TDLog -Level Success -Message "Created directory: $Path"
        return $true
    }
    catch {
        Register-Error -Operation 'Create directory' -Path $Path -ErrorRecord $_
        return $false
    }
}

function Get-RelativeItemPath {
    param(
        [Parameter(Mandatory)][string]$BasePath,
        [Parameter(Mandatory)][string]$ItemPath
    )

    return [System.IO.Path]::GetRelativePath($BasePath, $ItemPath)
}

function Test-IsExcludedContentPath {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$ItemPath
    )

    $relativePath = Get-RelativeItemPath -BasePath $SourceRoot -ItemPath $ItemPath
    $firstSegment = $relativePath.Split([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar), [System.StringSplitOptions]::RemoveEmptyEntries)[0]
    return [string]::Equals($firstSegment, 'content', [System.StringComparison]::OrdinalIgnoreCase)
}

# -----------------------------------------------------------------------------
# Step 1: Copy the complete content tree and overwrite destination files
# -----------------------------------------------------------------------------
function Copy-ContentTree {
    param(
        [Parameter(Mandatory)][string]$SourceContent,
        [Parameter(Mandatory)][string]$DestinationContent
    )

    Write-TDLog -Level Info -Message "COPY PHASE: $SourceContent -> $DestinationContent"

    if (-not [System.IO.Directory]::Exists($SourceContent)) {
        Register-Warning -Message "Copy source directory does not exist; phase skipped: $SourceContent"
        return
    }

    if (-not (Ensure-Directory -Path $DestinationContent)) {
        return
    }

    try {
        $directories = @(Get-ChildItem -LiteralPath $SourceContent -Directory -Recurse -Force -ErrorAction Stop)
    }
    catch {
        Register-Error -Operation 'Enumerate copy directories' -Path $SourceContent -ErrorRecord $_
        $directories = @()
    }

    foreach ($directory in $directories) {
        $relativePath = Get-RelativeItemPath -BasePath $SourceContent -ItemPath $directory.FullName
        $destinationDirectory = Join-Path $DestinationContent $relativePath
        Ensure-Directory -Path $destinationDirectory | Out-Null
    }

    try {
        $files = @(Get-ChildItem -LiteralPath $SourceContent -File -Recurse -Force -ErrorAction Stop)
    }
    catch {
        Register-Error -Operation 'Enumerate copy files' -Path $SourceContent -ErrorRecord $_
        return
    }

    $fileIndex = 0
    foreach ($file in $files) {
        $fileIndex++
        $percent = if ($files.Count -gt 0) { [int](($fileIndex / $files.Count) * 100) } else { 100 }
        Write-Progress -Activity 'Copying content files' -Status "$fileIndex of $($files.Count): $($file.Name)" -PercentComplete $percent

        $relativePath = Get-RelativeItemPath -BasePath $SourceContent -ItemPath $file.FullName
        $destinationFile = Join-Path $DestinationContent $relativePath
        $destinationParent = Split-Path -Parent $destinationFile

        if (-not (Ensure-Directory -Path $destinationParent)) {
            continue
        }

        try {
            [System.IO.File]::Copy($file.FullName, $destinationFile, $true)
            $script:Statistics.FilesCopied++
            Write-TDLog -Level Success -Message "Copied: $($file.FullName) -> $destinationFile"
        }
        catch {
            Register-Error -Operation 'Copy file' -Path $file.FullName -ErrorRecord $_
        }
    }

    Write-Progress -Activity 'Copying content files' -Completed
}

# -----------------------------------------------------------------------------
# Step 2: Move all non-content files, merging into and overwriting destination
# -----------------------------------------------------------------------------
function Move-NonContentTree {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$DestinationRoot
    )

    Write-TDLog -Level Info -Message "MOVE PHASE: $SourceRoot -> $DestinationRoot (excluding content)"

    if (-not [System.IO.Directory]::Exists($SourceRoot)) {
        Register-Warning -Message "Move source directory does not exist; phase skipped: $SourceRoot"
        return
    }

    if (-not (Ensure-Directory -Path $DestinationRoot)) {
        return
    }

    try {
        $directories = @(Get-ChildItem -LiteralPath $SourceRoot -Directory -Recurse -Force -ErrorAction Stop |
            Where-Object { -not (Test-IsExcludedContentPath -SourceRoot $SourceRoot -ItemPath $_.FullName) })
    }
    catch {
        Register-Error -Operation 'Enumerate move directories' -Path $SourceRoot -ErrorRecord $_
        $directories = @()
    }

    foreach ($directory in $directories) {
        $relativePath = Get-RelativeItemPath -BasePath $SourceRoot -ItemPath $directory.FullName
        $destinationDirectory = Join-Path $DestinationRoot $relativePath
        Ensure-Directory -Path $destinationDirectory | Out-Null
    }

    try {
        $files = @(Get-ChildItem -LiteralPath $SourceRoot -File -Recurse -Force -ErrorAction Stop |
            Where-Object { -not (Test-IsExcludedContentPath -SourceRoot $SourceRoot -ItemPath $_.FullName) })
    }
    catch {
        Register-Error -Operation 'Enumerate move files' -Path $SourceRoot -ErrorRecord $_
        return
    }

    $fileIndex = 0
    foreach ($file in $files) {
        $fileIndex++
        $percent = if ($files.Count -gt 0) { [int](($fileIndex / $files.Count) * 100) } else { 100 }
        Write-Progress -Activity 'Moving non-content files' -Status "$fileIndex of $($files.Count): $($file.Name)" -PercentComplete $percent

        $relativePath = Get-RelativeItemPath -BasePath $SourceRoot -ItemPath $file.FullName
        $destinationFile = Join-Path $DestinationRoot $relativePath
        $destinationParent = Split-Path -Parent $destinationFile

        if (-not (Ensure-Directory -Path $destinationParent)) {
            continue
        }

        try {
            if ([System.IO.File]::Exists($destinationFile)) {
                [System.IO.File]::Delete($destinationFile)
                Write-TDLog -Level Info -Message "Removed existing destination file before overwrite: $destinationFile"
            }

            [System.IO.File]::Move($file.FullName, $destinationFile)
            $script:Statistics.FilesMoved++
            Write-TDLog -Level Success -Message "Moved: $($file.FullName) -> $destinationFile"
        }
        catch {
            Register-Error -Operation 'Move file' -Path $file.FullName -ErrorRecord $_
        }
    }

    Write-Progress -Activity 'Moving non-content files' -Completed
    Remove-EmptyNonContentDirectories -SourceRoot $SourceRoot
}

function Remove-EmptyNonContentDirectories {
    param([Parameter(Mandatory)][string]$SourceRoot)

    try {
        $directories = @(Get-ChildItem -LiteralPath $SourceRoot -Directory -Recurse -Force -ErrorAction Stop |
            Where-Object { -not (Test-IsExcludedContentPath -SourceRoot $SourceRoot -ItemPath $_.FullName) } |
            Sort-Object { $_.FullName.Length } -Descending)
    }
    catch {
        Register-Error -Operation 'Enumerate source directories for cleanup' -Path $SourceRoot -ErrorRecord $_
        return
    }

    foreach ($directory in $directories) {
        try {
            $remainingItems = @(Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction Stop)
            if ($remainingItems.Count -gt 0) {
                Register-Warning -Message "Source directory retained because it is not empty: $($directory.FullName)"
                continue
            }

            [System.IO.Directory]::Delete($directory.FullName, $false)
            Write-TDLog -Level Success -Message "Moved directory structure (removed empty source): $($directory.FullName)"
        }
        catch {
            Register-Error -Operation 'Remove empty source directory after move' -Path $directory.FullName -ErrorRecord $_
        }
    }
}

function Invoke-FolderSet {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$DestinationRoot
    )

    Write-TDLog -Level Info -Message ('=' * 78)
    Write-TDLog -Level Info -Message "Processing folder set: $Name"

    $sourceContent = Join-Path $SourceRoot 'content'
    $destinationContent = Join-Path $DestinationRoot 'content'

    Copy-ContentTree -SourceContent $sourceContent -DestinationContent $destinationContent
    Move-NonContentTree -SourceRoot $SourceRoot -DestinationRoot $DestinationRoot
}

# -----------------------------------------------------------------------------
# Main execution and final summary
# -----------------------------------------------------------------------------
try {
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    $script:LogWriter = [System.IO.StreamWriter]::new($script:LogFilePath, $false, $utf8WithoutBom)
    $script:LogWriter.AutoFlush = $true
}
catch {
    Write-Host "FATAL ERROR: Cannot create log file '$script:LogFilePath'. $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

try {
    Write-TDLog -Level Info -Message "Start time: $($script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-TDLog -Level Info -Message "Log file: $script:LogFilePath"

    $folderSets = @(
        [pscustomobject]@{
            Name = 'Folder Set #1 - m1t2'
            Source = 'C:\Git\!myRepos\mpages\m1t2'
            Destination = 'C:\Git\!myRepos\mpages\old\m1t2'
        },
        [pscustomobject]@{
            Name = 'Folder Set #2 - pdf_scroll'
            Source = 'C:\Git\!myRepos\mpages\pdf_scroll'
            Destination = 'C:\Git\!myRepos\mpages\old\pdf_scroll'
        }
    )

    foreach ($folderSet in $folderSets) {
        try {
            Invoke-FolderSet -Name $folderSet.Name -SourceRoot $folderSet.Source -DestinationRoot $folderSet.Destination
        }
        catch {
            Register-Error -Operation "Process $($folderSet.Name)" -Path $folderSet.Source -ErrorRecord $_
        }
    }
}
catch {
    Register-Error -Operation 'Unexpected main execution error' -Path $env:HYBRID_SCRIPT -ErrorRecord $_
}
finally {
    $endTime = [DateTime]::Now
    $duration = $endTime - $script:StartTime

    Write-TDLog -Level Info -Message ('=' * 78)
    Write-TDLog -Level Info -Message "End time: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-TDLog -Level Info -Message ("Duration: {0:hh\:mm\:ss}" -f $duration)
    Write-TDLog -Level Info -Message "Files copied: $($script:Statistics.FilesCopied)"
    Write-TDLog -Level Info -Message "Files moved: $($script:Statistics.FilesMoved)"
    Write-TDLog -Level Info -Message "Directories created: $($script:Statistics.DirectoriesCreated)"
    Write-TDLog -Level Info -Message "Warnings: $($script:Statistics.Warnings)"
    Write-TDLog -Level Info -Message "Errors encountered: $($script:Statistics.Errors)"
    Write-TDLog -Level Info -Message "Log file location: $script:LogFilePath"

    if ($null -ne $script:LogWriter) {
        $script:LogWriter.Flush()
        $script:LogWriter.Dispose()
        $script:LogWriter = $null
    }
}

Write-Host ''
Write-Host 'FINAL SUMMARY' -ForegroundColor White
Write-Host "Files copied      : $($script:Statistics.FilesCopied)" -ForegroundColor Cyan
Write-Host "Files moved       : $($script:Statistics.FilesMoved)" -ForegroundColor Cyan
Write-Host "Errors encountered: $($script:Statistics.Errors)" -ForegroundColor $(if ($script:Statistics.Errors -gt 0) { 'Red' } else { 'Green' })
Write-Host "Log file location : $script:LogFilePath" -ForegroundColor Cyan

if ($script:Statistics.Errors -gt 0) {
    exit 1
}

exit 0
