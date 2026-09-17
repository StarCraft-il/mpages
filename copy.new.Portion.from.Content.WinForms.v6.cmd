@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem ============================================================================
rem Hybrid Batch + PowerShell launcher
rem Double-click this .cmd file. The PowerShell code is embedded below.
rem ============================================================================

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$scriptPath = '%~f0'; $scriptDirectory = Split-Path -Parent $scriptPath;" ^
  "$marker = ':__POWERSHELL__';" ^
  "$content = Get-Content -LiteralPath $scriptPath -Raw;" ^
  "$index = $content.LastIndexOf($marker);" ^
  "if ($index -lt 0) { Write-Host 'Embedded PowerShell marker not found.' -ForegroundColor Red; exit 90 };" ^
  "$ps = $content.Substring($index + $marker.Length);" ^
  "Invoke-Expression $ps;" ^
  "exit $LASTEXITCODE"

set "EXITCODE=%ERRORLEVEL%"
echo.
echo Script finished with exit code %EXITCODE%.
echo Press any key to close this window...
pause >nul
exit /b %EXITCODE%

:__POWERSHELL__
# ============================================================================
# Configuration
# ============================================================================
# Version: WinForms portion selector and confirmation dialog v6 - log beside script

enum LogLevel {
    Info
    Success
    Warning
    Override
    Error
}

$portionsList = @("Bereshit", "Noach", "Lech_Lecha", "Vayera", "Chayei_Sara", "Toldot", "Vayetzei", "Vayishlach", "Vayeshev", "Miketz", "Vayigash", "Vayechi", "Shemot", "Vaera", "Bo", "Beshalach", "Yitro", "Mishpatim", "Terumah", "Tetzaveh", "Ki_Tisa", "Vayakhel", "Pekudei", "Vayakhel_Pekudei", "Vayikra", "Tzav", "Shmini", "Tazria", "Metzora", "Achrei_Mot", "Kedoshim", "Emor", "Behar", "Bechukotai", "Tazria_Metzora", "Achrei_Mos_Kedoshim", "Behar_Bechukotai", "Bamidbar", "Nasso", "Beha'alotcha", "Sh'lach", "Korach", "Chukat", "Balak", "Pinchas", "Matot", "Masei", "Chukas_Balak", "Matot_Masei", "Devarim", "Vaetchanan", "Eikev", "Re'eh", "Shoftim", "Ki_Teitzei", "Ki_Tavo", "Nitzavim", "Vayeilech", "Ha'Azinu", "Vezot_Haberakhah", "Nitzavim_Vayeilech")

$Portion = $null

$SourceDirectory = 'C:\Git\allproj\_OneFile\OpenServers_content'
$M1T2Directory = 'C:\Git\!myRepos\mpages\m1t2'
$PdfScrollDirectory = 'C:\Git\!myRepos\mpages\pdf_scroll'
$LogDirectory = $scriptDirectory

$FilesCopied = 0
$FilesMoved = 0
$ErrorsEncountered = 0
$ExitCode = 0
$LogFile = $null

# ============================================================================
# Reusable helpers
# ============================================================================

function Write-ConsoleLog {
    param(
        [Parameter(Mandatory = $true)]
        [LogLevel]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message

    switch ($Level) {
        ([LogLevel]::Info) {
            Write-Host $line -ForegroundColor Cyan
            break
        }
        ([LogLevel]::Success) {
            Write-Host $line -ForegroundColor Green
            break
        }
        ([LogLevel]::Warning) {
            Write-Host $line -ForegroundColor Yellow
            break
        }
        ([LogLevel]::Override) {
            Write-Host $line -ForegroundColor Red
            break
        }
        ([LogLevel]::Error) {
            Write-Host $line -ForegroundColor Red
            break
        }
        default {
            Write-Host $line
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($LogFile)) {
        return
    }

    try {
        Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    }
    catch {
        Write-Host ('Unable to write to log file: {0}' -f $_.Exception.Message) -ForegroundColor Red
    }
}

function Initialize-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        New-Item -ItemType Directory -Path $Directory -Force -ErrorAction Stop | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
    $path = Join-Path $Directory ('res.{0}.log' -f $timestamp)
    Set-Content -LiteralPath $path -Value ('Log started: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Encoding UTF8 -ErrorAction Stop
    return $path
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path -PathType Container) {
        return
    }

    Write-ConsoleLog -Level Info -Message ('Creating directory: {0}' -f $Path)
    New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
}

function Test-FileContainsPortion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [Parameter(Mandatory = $true)]
        [string]$PortionName
    )

    $escapedPortion = [regex]::Escape($PortionName)
    return $FileName -match ('(?:^|\.)' + $escapedPortion + '(?=\.|$)')
}

function Get-ExportTimestamp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    $timestampPattern = '\.(?<Date>\d{8})\.(?<Time>\d{6})(?=\.)'
    $match = [regex]::Match($FileName, $timestampPattern)

    if (-not $match.Success) {
        return $null
    }

    $timestampText = $match.Groups['Date'].Value + $match.Groups['Time'].Value
    $timestamp = [datetime]::MinValue
    $parsed = [datetime]::TryParseExact(
        $timestampText,
        'yyyyMMddHHmmss',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$timestamp
    )

    if (-not $parsed) {
        return $null
    }

    return $timestamp
}

function Get-RecentPortions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [string[]]$PortionNames,

        [Parameter(Mandatory = $true)]
        [datetime]$Since
    )

    $latestTimestampByPortion = @{}
    $files = Get-ChildItem -LiteralPath $Directory -File -ErrorAction Stop

    foreach ($file in $files) {
        $timestamp = Get-ExportTimestamp -FileName $file.Name

        if ($null -eq $timestamp -or $timestamp -lt $Since) {
            continue
        }

        foreach ($portionName in $PortionNames) {
            if (-not (Test-FileContainsPortion -FileName $file.Name -PortionName $portionName)) {
                continue
            }

            if (-not $latestTimestampByPortion.ContainsKey($portionName) -or
                $timestamp -gt $latestTimestampByPortion[$portionName]) {
                $latestTimestampByPortion[$portionName] = $timestamp
            }

            break
        }
    }

    $recentPortions = foreach ($portionName in $latestTimestampByPortion.Keys) {
        [pscustomobject]@{
            Portion = $portionName
            Timestamp = $latestTimestampByPortion[$portionName]
        }
    }

    return @($recentPortions | Sort-Object Timestamp -Descending)
}

function Show-PortionSelectionDialog {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$RecentPortions,

        [Parameter(Mandatory = $true)]
        [datetime]$Since
    )

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Select Portion'
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.ClientSize = New-Object System.Drawing.Size(480, 145)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(15, 15)
    $label.Text = 'Select a portion exported since {0}:' -f $Since.ToString('yyyy-MM-dd')

    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboBox.Location = New-Object System.Drawing.Point(18, 43)
    $comboBox.Size = New-Object System.Drawing.Size(444, 28)

    foreach ($recentPortion in $RecentPortions) {
        $displayText = '{0}  -  {1}' -f `
            $recentPortion.Portion,
            $recentPortion.Timestamp.ToString('yyyy-MM-dd HH:mm:ss')

        [void]$comboBox.Items.Add($displayText)
    }

    $comboBox.SelectedIndex = 0

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $okButton.Location = New-Object System.Drawing.Point(280, 94)
    $okButton.Size = New-Object System.Drawing.Size(85, 30)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelButton.Location = New-Object System.Drawing.Point(377, 94)
    $cancelButton.Size = New-Object System.Drawing.Size(85, 30)

    [void]$form.Controls.Add($label)
    [void]$form.Controls.Add($comboBox)
    [void]$form.Controls.Add($okButton)
    [void]$form.Controls.Add($cancelButton)
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    $selectedPortion = $null

    try {
        $result = $form.ShowDialog()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $selectedPortion = $RecentPortions[$comboBox.SelectedIndex].Portion
        }
    }
    finally {
        $label.Dispose()
        $comboBox.Dispose()
        $okButton.Dispose()
        $cancelButton.Dispose()
        $form.Dispose()
    }

    return $selectedPortion
}

function Get-NewestPortionTimestamp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [string]$PortionName
    )

    $timestampPattern = '\.(?<Date>\d{8})\.(?<Time>\d{6})\.'
    $candidates = New-Object System.Collections.Generic.List[object]

    $files = Get-ChildItem -LiteralPath $Directory -File -ErrorAction Stop |
        Where-Object { Test-FileContainsPortion -FileName $_.Name -PortionName $PortionName }

    foreach ($file in $files) {
        $match = [regex]::Match($file.Name, $timestampPattern)

        if (-not $match.Success) {
            continue
        }

        $timestampText = $match.Groups['Date'].Value + $match.Groups['Time'].Value
        $timestamp = [datetime]::MinValue
        $parsed = [datetime]::TryParseExact(
            $timestampText,
            'yyyyMMddHHmmss',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$timestamp
        )

        if (-not $parsed) {
            continue
        }

        $candidates.Add([pscustomobject]@{
            Timestamp = $timestamp
            Stamp = $match.Groups['Date'].Value + '.' + $match.Groups['Time'].Value
        })
    }

    if ($candidates.Count -eq 0) {
        throw ('No timestamped files were found for Portion "{0}" in "{1}".' -f $PortionName, $Directory)
    }

    return ($candidates | Sort-Object Timestamp -Descending | Select-Object -First 1).Stamp
}

function Get-DestinationFileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFileName,

        [Parameter(Mandatory = $true)]
        [string]$Timestamp
    )

    $escapedTimestamp = [regex]::Escape($Timestamp)

    # Special generated HTML names:
    #   Shoftim.mobile.zoom.v1.html.20260809.151256.html
    # become:
    #   Shoftim.mobile.zoom.v1.html
    if ($SourceFileName -match ('^(?<Base>.+\.html)\.' + $escapedTimestamp + '\.html$')) {
        return $Matches['Base']
    }

    return $SourceFileName
}

function Get-PortionFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [string]$PortionName,

        [Parameter(Mandatory = $true)]
        [string]$Timestamp
    )

    $escapedTimestamp = [regex]::Escape($Timestamp)

    $files = Get-ChildItem -LiteralPath $Directory -File -ErrorAction Stop |
        Where-Object {
            (Test-FileContainsPortion -FileName $_.Name -PortionName $PortionName) -and
            $_.Name -match $escapedTimestamp
        } |
        Sort-Object Name

    return @($files)
}

function Test-IsM1T2File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationFileName,

        [Parameter(Mandatory = $true)]
        [string]$PortionName
    )

    $allowedNames = @(
        ('{0}.mobile.zoom.step-scroll.v1.html' -f $PortionName),
        ('{0}.mobile.zoom.v1.html' -f $PortionName),
        ('p.f2.{0}.html' -f $PortionName)
    )

    return $allowedNames -contains $DestinationFileName
}

function Copy-OneFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
        Write-ConsoleLog -Level Override -Message ('OVERRIDE existing file: {0}' -f $DestinationPath)
    }

    Write-ConsoleLog -Level Info -Message ('Copy: "{0}" -> "{1}"' -f $SourcePath, $DestinationPath)
    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
    Write-ConsoleLog -Level Success -Message ('Copied: {0}' -f $DestinationPath)
}

function Show-ConfirmationDialog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,

        [Parameter(Mandatory = $true)]
        [string[]]$DestinationFolders,

        [Parameter(Mandatory = $true)]
        [string]$SelectedTimestamp,

        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$Files,

        [Parameter(Mandatory = $true)]
        [object[]]$Operations,

        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Source folder:')
    $lines.Add($SourceFolder)
    $lines.Add('')
    $lines.Add('Destination folders:')

    foreach ($destinationFolder in $DestinationFolders) {
        $lines.Add($destinationFolder)
    }

    $lines.Add('')
    $lines.Add(('Selected timestamp: {0}' -f $SelectedTimestamp))
    $lines.Add(('Total file count: {0}' -f $Files.Count))
    $lines.Add(('Log file: {0}' -f $LogFilePath))
    $lines.Add('')
    $lines.Add('Full file list:')
    $lines.Add('')

    foreach ($file in $Files) {
        $lines.Add($file.FullName)
    }

    $lines.Add('')
    $lines.Add('Destination operations:')
    $lines.Add('')

    foreach ($operation in $Operations) {
        $prefix = '[NEW]'

        if (Test-Path -LiteralPath $operation.Destination -PathType Leaf) {
            $prefix = '[OVERRIDE]'
        }

        $lines.Add(('{0} {1}' -f $prefix, $operation.Destination))
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Confirm File Copy'
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.Size = New-Object System.Drawing.Size(1000, 700)
    $form.MinimumSize = New-Object System.Drawing.Size(700, 450)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $form.MaximizeBox = $true
    $form.MinimizeBox = $true

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline = $true
    $textBox.ReadOnly = $true
    $textBox.WordWrap = $false
    $textBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    $textBox.Font = New-Object System.Drawing.Font('Consolas', 10)
    $textBox.Location = New-Object System.Drawing.Point(12, 12)
    $textBox.Size = New-Object System.Drawing.Size(960, 600)
    $textBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor `
        [System.Windows.Forms.AnchorStyles]::Bottom -bor `
        [System.Windows.Forms.AnchorStyles]::Left -bor `
        [System.Windows.Forms.AnchorStyles]::Right
    $textBox.Text = $lines -join [Environment]::NewLine

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $okButton.Size = New-Object System.Drawing.Size(100, 32)
    $okButton.Location = New-Object System.Drawing.Point(760, 620)
    $okButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor `
        [System.Windows.Forms.AnchorStyles]::Right

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelButton.Size = New-Object System.Drawing.Size(100, 32)
    $cancelButton.Location = New-Object System.Drawing.Point(872, 620)
    $cancelButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor `
        [System.Windows.Forms.AnchorStyles]::Right

    $form.Controls.Add($textBox)
    $form.Controls.Add($okButton)
    $form.Controls.Add($cancelButton)
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    try {
        return $form.ShowDialog()
    }
    finally {
        $textBox.Dispose()
        $okButton.Dispose()
        $cancelButton.Dispose()
        $form.Dispose()
    }
}

function Write-Summary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Status
    )

    Write-Host ''
    Write-Host '==================== SUMMARY ====================' -ForegroundColor White
    Write-Host ('Status             : {0}' -f $Status)
    Write-Host ('Files copied       : {0}' -f $script:FilesCopied)
    Write-Host ('Files moved        : {0}' -f $script:FilesMoved)
    Write-Host ('Errors encountered : {0}' -f $script:ErrorsEncountered)
    Write-Host ('Log file           : {0}' -f $script:LogFile)
    Write-Host '=================================================' -ForegroundColor White

    if (-not [string]::IsNullOrWhiteSpace($script:LogFile)) {
        Write-ConsoleLog -Level Info -Message ('Summary: Status={0}; FilesCopied={1}; FilesMoved={2}; Errors={3}; LogFile={4}' -f `
            $Status,
            $script:FilesCopied,
            $script:FilesMoved,
            $script:ErrorsEncountered,
            $script:LogFile)
    }
}

# ============================================================================
# Main
# ============================================================================

try {
    if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
        throw ('Source directory does not exist: {0}' -f $SourceDirectory)
    }

    $LogFile = Initialize-Log -Directory $LogDirectory

    $recentFilesStartDate = (Get-Date).Date.AddDays(-7)
    $recentPortions = Get-RecentPortions `
        -Directory $SourceDirectory `
        -PortionNames $portionsList `
        -Since $recentFilesStartDate

    if ($recentPortions.Count -eq 0) {
        throw ('No portion export files dated on or after {0} were found in "{1}".' -f `
            $recentFilesStartDate.ToString('yyyy-MM-dd'),
            $SourceDirectory)
    }

    $Portion = Show-PortionSelectionDialog `
        -RecentPortions $recentPortions `
        -Since $recentFilesStartDate

    if ([string]::IsNullOrWhiteSpace($Portion)) {
        Write-ConsoleLog -Level Warning -Message 'User cancelled portion selection. No files were copied or moved.'
        Write-Summary -Status 'Cancelled - nothing was done'
        exit 0
    }

    Write-ConsoleLog -Level Info -Message ('Starting Portion deployment for "{0}".' -f $Portion)
    Write-ConsoleLog -Level Info -Message ('Source directory: {0}' -f $SourceDirectory)
    Write-ConsoleLog -Level Info -Message ('Log file: {0}' -f $LogFile)

    $newestTimestamp = Get-NewestPortionTimestamp -Directory $SourceDirectory -PortionName $Portion
    Write-ConsoleLog -Level Info -Message ('Newest generated set timestamp: {0}' -f $newestTimestamp)

    $portionFiles = Get-PortionFiles `
        -Directory $SourceDirectory `
        -PortionName $Portion `
        -Timestamp $newestTimestamp

    if ($portionFiles.Count -eq 0) {
        throw ('No files found for Portion "{0}" with timestamp "{1}".' -f $Portion, $newestTimestamp)
    }

    $operations = New-Object System.Collections.Generic.List[object]

    foreach ($file in $portionFiles) {
        $destinationName = Get-DestinationFileName `
            -SourceFileName $file.Name `
            -Timestamp $newestTimestamp

        # Every file in the newest set goes to pdf_scroll.
        $operations.Add([pscustomobject]@{
            Source = $file.FullName
            Destination = Join-Path $PdfScrollDirectory $destinationName
            Target = 'pdf_scroll'
        })

        # Only the three clean HTML entry files also go to m1t2.
        if (Test-IsM1T2File -DestinationFileName $destinationName -PortionName $Portion) {
            $operations.Add([pscustomobject]@{
                Source = $file.FullName
                Destination = Join-Path $M1T2Directory $destinationName
                Target = 'm1t2'
            })
        }
    }

    $confirmation = Show-ConfirmationDialog `
        -SourceFolder $SourceDirectory `
        -DestinationFolders @($M1T2Directory, $PdfScrollDirectory) `
        -SelectedTimestamp $newestTimestamp `
        -Files $portionFiles `
        -Operations $operations `
        -LogFilePath $LogFile

    if ($confirmation -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-ConsoleLog -Level Warning -Message 'User cancelled. No files were copied or moved.'
        Write-Summary -Status 'Cancelled - nothing was done'
        exit 0
    }

    Ensure-Directory -Path $M1T2Directory
    Ensure-Directory -Path $PdfScrollDirectory

    $operationNumber = 0

    foreach ($operation in $operations) {
        $operationNumber++
        $percent = [math]::Round(($operationNumber / $operations.Count) * 100, 0)

        Write-Progress `
            -Activity ('Deploying Portion "{0}"' -f $Portion) `
            -Status ('{0}/{1}: {2}' -f $operationNumber, $operations.Count, [System.IO.Path]::GetFileName($operation.Destination)) `
            -PercentComplete $percent

        Write-Host ('[{0}/{1}] {2}' -f $operationNumber, $operations.Count, $operation.Destination) -ForegroundColor Gray

        try {
            Copy-OneFile `
                -SourcePath $operation.Source `
                -DestinationPath $operation.Destination

            $FilesCopied++
        }
        catch {
            $ErrorsEncountered++
            $ExitCode = 1
            Write-ConsoleLog -Level Error -Message ('Copy failed: "{0}" -> "{1}". {2}' -f `
                $operation.Source,
                $operation.Destination,
                $_.Exception.Message)
        }
    }

    Write-Progress -Activity ('Deploying Portion "{0}"' -f $Portion) -Completed

    if ($ErrorsEncountered -gt 0) {
        Write-Summary -Status 'Completed with errors'
        exit $ExitCode
    }

    Write-ConsoleLog -Level Success -Message 'All copy operations completed successfully.'
    Write-Summary -Status 'Completed successfully'
    exit 0
}
catch {
    $ErrorsEncountered++
    $ExitCode = 2

    if ([string]::IsNullOrWhiteSpace($LogFile)) {
        Write-Host ('FATAL: {0}' -f $_.Exception.Message) -ForegroundColor Red
    }
    else {
        Write-ConsoleLog -Level Error -Message ('Fatal error: {0}' -f $_.Exception.Message)
    }

    Write-Summary -Status 'Failed'
    exit $ExitCode
}
