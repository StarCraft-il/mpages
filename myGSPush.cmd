<# : batch
@echo off
setlocal EnableExtensions
chcp 65001 >nul

REM Hybrid Batch -> PowerShell: run the PowerShell part embedded below (no .ps1 needed)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ps = (Get-Content -Raw -LiteralPath '%~f0') -replace '(?s)^.*?#>\r?\n',''; & ([scriptblock]::Create($ps)) @args" %*
set "RC=%ERRORLEVEL%"
exit /b %RC%
#>

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$CommitMessageParts
)

$ErrorActionPreference = 'Stop'

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Ensure-Git() {
    $git = (Get-Command git -ErrorAction SilentlyContinue)
    if (-not $git) { Fail 'git not found in PATH' }
}
function Ensure-Repo() {
    $inside = git rev-parse --is-inside-work-tree 2>&1
    if ($LASTEXITCODE -ne 0 -or $inside -ne 'true') { Fail 'Not inside a Git repository' }
}

# ===== Customizable UI text =====
$BannerTitle      = 'Git Commit Message'
$InstructionsText = 'Use ↑/↓ to move, Enter to select, Esc to cancel.'
$ArgMenuAutoApproveSeconds = 7
$GitStatusApprovalAutoApproveSeconds = 10

# ===== Selection UI with your formatting =====
function Select-CommitMessage($items, [int]$defaultIndex = 0, [int]$autoSelectSeconds = 0) {
    if (-not $Host.UI.RawUI) { return $null }

    $index = [Math]::Min([Math]::Max(0, $defaultIndex), [Math]::Max(0, $items.Count - 1))
    $lastShownSeconds = if ($autoSelectSeconds -gt 0) { $autoSelectSeconds } else { -1 }
    $defaultForegroundColor = [Console]::ForegroundColor
    $defaultBackgroundColor = [Console]::BackgroundColor
    $menuTop = 0
    $menuLineCount = $items.Count + 8
    if ($autoSelectSeconds -gt 0) {
        $menuLineCount++
    }

    function Get-PaddedMenuText([string]$text) {
        $bufferWidth = [Math]::Max(20, [Console]::BufferWidth - 1)
        $lineText = if ($null -eq $text) { '' } else { $text }
        if ($lineText.Length -gt $bufferWidth) {
            $lineText = $lineText.Substring(0, $bufferWidth)
        }

        return $lineText.PadRight($bufferWidth)
    }

    function Set-MenuCursorPosition([int]$top) {
        $safeTop = [Math]::Max(0, [Math]::Min($top, [Console]::BufferHeight - 1))
        [Console]::SetCursorPosition(0, $safeTop)
    }

    function New-MenuLine([string]$text, [string]$foregroundColor, [string]$backgroundColor = $null) {
        return [pscustomobject]@{
            Text = $text
            ForegroundColor = $foregroundColor
            BackgroundColor = $backgroundColor
        }
    }

    function Get-MenuLines([int]$secondsToShow) {
        $lines = [System.Collections.Generic.List[object]]::new()

        [void]$lines.Add((New-MenuLine '===============================' 'Cyan'))
        [void]$lines.Add((New-MenuLine ('  ' + $BannerTitle) 'Cyan'))
        [void]$lines.Add((New-MenuLine '===============================' 'Cyan'))
        [void]$lines.Add((New-MenuLine '' $defaultForegroundColor))
        [void]$lines.Add((New-MenuLine $InstructionsText 'DarkGray'))
        [void]$lines.Add((New-MenuLine '' $defaultForegroundColor))

        for ($i = 0; $i -lt $items.Count; $i++) {
            $prefix = ('{0,2}. ' -f ($i + 1))
            if ($i -eq $index) {
                $text = ([char]0x25B6 + ' ' + $prefix + $items[$i])
                [void]$lines.Add((New-MenuLine $text 'Yellow' 'DarkGreen'))
                continue
            }

            $text = '  ' + $prefix + $items[$i]
            [void]$lines.Add((New-MenuLine $text 'Gray'))
        }

        [void]$lines.Add((New-MenuLine '' $defaultForegroundColor))
        [void]$lines.Add((New-MenuLine ("[Total items: {0}]" -f $items.Count) 'DarkGray'))

        if ($autoSelectSeconds -gt 0) {
            $timerText = ''
            if ($secondsToShow -ge 0) {
                $timerText = ("[Auto select current option in: {0}s]" -f $secondsToShow)
            }

            [void]$lines.Add((New-MenuLine $timerText 'Red'))
        }

        return $lines
    }

    function Write-MenuLineAt([int]$top, $lineInfo) {
        Set-MenuCursorPosition $top
        [Console]::ForegroundColor = $lineInfo.ForegroundColor
        if ($null -ne $lineInfo.BackgroundColor -and -not [string]::IsNullOrWhiteSpace([string]$lineInfo.BackgroundColor)) {
            [Console]::BackgroundColor = $lineInfo.BackgroundColor
        } else {
            [Console]::BackgroundColor = $defaultBackgroundColor
        }

        [Console]::Write((Get-PaddedMenuText $lineInfo.Text))
        [Console]::ForegroundColor = $defaultForegroundColor
        [Console]::BackgroundColor = $defaultBackgroundColor
    }

    function Draw-MenuInitially([int]$secondsToShow) {
        try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

        $lines = Get-MenuLines $secondsToShow
        foreach ($lineInfo in $lines) {
            if ($null -ne $lineInfo.BackgroundColor -and -not [string]::IsNullOrWhiteSpace([string]$lineInfo.BackgroundColor)) {
                Write-Host $lineInfo.Text -ForegroundColor $lineInfo.ForegroundColor -BackgroundColor $lineInfo.BackgroundColor
                continue
            }

            Write-Host $lineInfo.Text -ForegroundColor $lineInfo.ForegroundColor
        }

        $script:SelectCommitMessageMenuTop = [Math]::Max(0, [Console]::CursorTop - $lines.Count)
    }

    function Redraw-Menu([int]$secondsToShow) {
        $lines = Get-MenuLines $secondsToShow
        for ($i = 0; $i -lt $lines.Count; $i++) {
            Write-MenuLineAt ($menuTop + $i) $lines[$i]
        }

        Set-MenuCursorPosition ($menuTop + $lines.Count)
    }

    function Complete-Menu() {
        [Console]::ForegroundColor = $defaultForegroundColor
        [Console]::BackgroundColor = $defaultBackgroundColor
        Set-MenuCursorPosition ($menuTop + $menuLineCount)
        Write-Host ''
    }

    Draw-MenuInitially $lastShownSeconds
    $menuTop = $script:SelectCommitMessageMenuTop
    $endTime = if ($autoSelectSeconds -gt 0) { [DateTime]::Now.AddSeconds($autoSelectSeconds) } else { $null }
    while ($true) {
        if ($autoSelectSeconds -gt 0) {
            $remainingSeconds = [Math]::Ceiling(([TimeSpan]($endTime - [DateTime]::Now)).TotalSeconds)
            if ($remainingSeconds -le 0) {
                Complete-Menu
                return $items[$index]
            }

            if ($remainingSeconds -ne $lastShownSeconds) {
                $lastShownSeconds = $remainingSeconds
                Redraw-Menu $lastShownSeconds
            }

            if (-not [Console]::KeyAvailable) {
                Start-Sleep -Milliseconds 150
                continue
            }
        }

        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        switch ($key.VirtualKeyCode) {
            38 {
                if ($index -gt 0) { $index-- } else { $index = $items.Count - 1 }
                Redraw-Menu $lastShownSeconds
                continue
            } # Up
            40 {
                if ($index -lt $items.Count - 1) { $index++ } else { $index = 0 }
                Redraw-Menu $lastShownSeconds
                continue
            } # Down
            13 {
                Complete-Menu
                return $items[$index]
            }   # Enter
            27 {
                Complete-Menu
                Write-Host 'Aborted.' -ForegroundColor DarkGray
                return $null
            } # Esc
            default {
                $ch = $key.Character
                if ($ch -match '^[1-9]$') {
                    $n = [int]$ch
                    if ($n -ge 1 -and $n -le $items.Count) {
                        Complete-Menu
                        return $items[$n - 1]
                    }
                }
            }
        }
    }
}

# ===== Focused TopMost WinForms InputBox =====
function Show-InputBox([string]$title, [string]$prompt, [string]$default='') {
    try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop } catch { return $null }
    try { Add-Type -AssemblyName System.Drawing -ErrorAction Stop } catch {}

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.Width = 440; $form.Height = 170

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.AutoSize = $true
    $lbl.Text = $prompt
    $lbl.Left = 12; $lbl.Top = 12

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Left = 12; $tb.Top = 40
    $tb.Width = 400
    $tb.Text = $default

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Left = 226; $ok.Top = 80
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Left = 318; $cancel.Top = 80
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $form.AcceptButton = $ok
    $form.CancelButton = $cancel
    $form.Controls.AddRange(@($lbl,$tb,$ok,$cancel))
    $form.Add_Shown({ $form.Activate(); $form.BringToFront(); $tb.Select(); $tb.Focus(); $tb.SelectionStart = $tb.Text.Length })

    $result = $form.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { return $tb.Text } else { return $null }
}

function Get-RepoStatusLines() {
    $lines = @(git status --short 2>$null)
    return @($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Normalize-StatusPath([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return '' }

    $clean = $path.Replace('/', '\').Trim()
    if ($clean -like '* -> *') {
        $clean = ($clean -split ' -> ')[-1].Trim()
    }

    return $clean
}

function Get-StatusEntries([string[]]$statusLines) {
    $entries = [System.Collections.Generic.List[object]]::new()

    foreach ($line in $statusLines) {
        $status = if ($line.Length -ge 2) { $line.Substring(0, 2) } else { '' }
        $path = if ($line.Length -gt 3) { $line.Substring(3).Trim() } else { '' }
        $cleanPath = Normalize-StatusPath $path
        if ([string]::IsNullOrWhiteSpace($cleanPath)) { continue }

        $folderPath = Split-Path -Path $cleanPath -Parent
        if ($folderPath -eq '.') { $folderPath = '' }

        $entries.Add([pscustomobject]@{
            Status = $status
            Path = $cleanPath
            FolderPath = $folderPath
        })
    }

    return $entries
}

function Join-QuotedValues([string[]]$values) {
    if (-not $values -or $values.Count -eq 0) { return '' }
    $quotedValues = @($values | ForEach-Object { "'$_'" })
    return [string]::Join(', ', $quotedValues)
}

function Get-FolderDisplayName([string]$folderPath) {
    if ([string]::IsNullOrWhiteSpace($folderPath)) { return 'repository root' }
    return $folderPath
}

function Get-CommitActionWord([bool]$hasAddedFiles, [bool]$hasUpdatedFiles, [int]$pathCount) {
    if ($hasAddedFiles -and -not $hasUpdatedFiles) { return 'Add' }
    return 'Update'
}

function Get-FallbackCommitMessage() {
    $statusLines = Get-RepoStatusLines
    if ($statusLines.Count -eq 0) { return $null }

    $entries = Get-StatusEntries $statusLines
    if ($entries.Count -eq 0) { return $null }

    $hasAddedFiles = $false
    $hasUpdatedFiles = $false
    $uniquePaths = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in $entries) {
        if ($entry.Status -match '\?\?' -or $entry.Status.Contains('A')) { $hasAddedFiles = $true }
        if ($entry.Status -match '[MDRCUT]') { $hasUpdatedFiles = $true }

        if (-not $uniquePaths.Contains($entry.Path)) {
            [void]$uniquePaths.Add($entry.Path)
        }
    }

    $actionWord = Get-CommitActionWord -hasAddedFiles $hasAddedFiles -hasUpdatedFiles $hasUpdatedFiles -pathCount $uniquePaths.Count

    if ($uniquePaths.Count -eq 1) {
        return "$actionWord '$($uniquePaths[0])'"
    }

    $folderPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $entries) {
        $folderDisplayName = Get-FolderDisplayName $entry.FolderPath
        if ($folderPaths.Contains($folderDisplayName)) { continue }
        [void]$folderPaths.Add($folderDisplayName)
    }

    if ($folderPaths.Count -eq 1) {
        if ($folderPaths[0] -eq 'repository root') {
            return "$actionWord files in repository root"
        }

        return "$actionWord files in: '$($folderPaths[0])' folder"
    }

    $quotedFolders = Join-QuotedValues $folderPaths.ToArray()
    return "$actionWord files in folders: $quotedFolders"
}

function Show-EditableCommitMessageApproval([string]$windowTitle, [string]$commitMessage, [int]$autoApproveSeconds = 0) {
    try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop } catch { return $null }
    try { Add-Type -AssemblyName System.Drawing -ErrorAction Stop } catch {}

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $windowTitle
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.Width = 760
    $form.Height = 250

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Dock = 'Top'
    $tb.Height = 130
    $tb.Multiline = $true
    $tb.ScrollBars = 'Vertical'
    $tb.BackColor = [System.Drawing.Color]::White
    $tb.ForeColor = [System.Drawing.Color]::Navy
    $tb.Font = New-Object System.Drawing.Font('Segoe UI', 22)
    $tb.Text = $commitMessage

    $buttonsPanel = New-Object System.Windows.Forms.Panel
    $buttonsPanel.Dock = 'Bottom'
    $buttonsPanel.Height = 116

    $countdownLabel = New-Object System.Windows.Forms.Label
    $countdownLabel.Dock = 'Top'
    $countdownLabel.Height = 34
    $countdownLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $countdownLabel.ForeColor = [System.Drawing.Color]::DarkRed
    $countdownLabel.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $countdownLabel.Text = ''

    $buttonsRowPanel = New-Object System.Windows.Forms.Panel
    $buttonsRowPanel.Dock = 'Fill'

    $approve = New-Object System.Windows.Forms.Button
    $approve.Text = 'Approve'
    $approve.Dock = 'Left'
    $approve.Width = 360
    $approve.BackColor = [System.Drawing.Color]::Navy
    $approve.ForeColor = [System.Drawing.Color]::White
    $approve.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $approve.FlatStyle = 'Flat'
    $approve.Add_Click({
        $form.Tag = 'Approve'
        $form.Close()
    })

    $close = New-Object System.Windows.Forms.Button
    $close.Text = 'Close window'
    $close.Dock = 'Right'
    $close.Width = 360
    $close.BackColor = [System.Drawing.Color]::Maroon
    $close.ForeColor = [System.Drawing.Color]::White
    $close.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $close.FlatStyle = 'Flat'
    $close.Add_Click({
        $form.Tag = 'Close'
        $form.Close()
    })

    $countdownState = @{
        SecondsLeft = $autoApproveSeconds
    }

    function Update-ApprovalCountdownUi() {
        if ($countdownState.SecondsLeft -gt 0) {
            $approve.Text = ('Approve ({0})' -f $countdownState.SecondsLeft)
            $countdownLabel.Text = ('Auto approve in {0} seconds' -f $countdownState.SecondsLeft)
            return
        }

        $approve.Text = 'Approve'
        $countdownLabel.Text = ''
    }

    $timer = $null
    if ($autoApproveSeconds -gt 0) {
        Update-ApprovalCountdownUi

        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 1000
        $timer.Add_Tick({
            $countdownState.SecondsLeft--
            if ($countdownState.SecondsLeft -le 0) {
                $timer.Stop()
                $form.Tag = 'Approve'
                $form.Close()
                return
            }

            Update-ApprovalCountdownUi
        })
    }

    $form.AcceptButton = $approve
    $form.CancelButton = $close
    $buttonsRowPanel.Controls.Add($approve)
    $buttonsRowPanel.Controls.Add($close)
    $buttonsPanel.Controls.Add($buttonsRowPanel)
    $buttonsPanel.Controls.Add($countdownLabel)
    $form.Controls.Add($tb)
    $form.Controls.Add($buttonsPanel)
    $form.Add_Shown({
        $form.Activate()
        $form.BringToFront()
        $tb.Select()
        $tb.Focus()
        $tb.SelectionStart = $tb.Text.Length
        if ($timer) { $timer.Start() }
    })
    $form.Add_FormClosed({
        if ($timer) { $timer.Stop() }
    })

    [void]$form.ShowDialog()
    if ($form.Tag -ne 'Approve') { return $null }
    return $tb.Text
}

function Show-GitStatusCommitMessageApproval([string]$commitMessage, [int]$autoApproveSeconds = 0) {
    return (Show-EditableCommitMessageApproval -windowTitle 'Approve git status commit message' -commitMessage $commitMessage -autoApproveSeconds $autoApproveSeconds)
}

function git-status-commit-message() {
    $statusLines = Get-RepoStatusLines
    if ($statusLines.Count -eq 0) {
        Write-Host 'No repository changes detected.' -ForegroundColor DarkYellow
        return $null
    }
    Write-Host 'Generating commit message by git status...' -ForegroundColor Cyan
    return (Get-FallbackCommitMessage)
}

# ===== Templates you can edit =====
$templates = @(
    'Updates, for saving code...'
	'Updates BL And Models'
	'Updates BL And more...'
    'Minor update'
    'Add feature'
    'Bug fix'
    'Update docs'
    'Refactor, Formatting'
    'Refactor, Code cleanup'
    'Perf, Improve performance'
    'Adding tests'
    'Maintenance changes'
    'Adding appsettings files'
    'Update appsettings files'
    "Adding DevOps-'yml' files"
    "Update DevOps-'yml' files"
) | Select-Object -Unique
# ==================================

Ensure-Git
Ensure-Repo

# Build menu items: templates -> (Use arg) ... (if provided) -> Custom message…
$items = [System.Collections.Generic.List[string]]::new()
$templates | ForEach-Object { [void]$items.Add($_) }

# Commit message from arguments: join all parts so quotes are optional
$CommitMessage = if ($CommitMessageParts) { [string]::Join(' ', $CommitMessageParts) } else { $null }

$argIndex = -1
$customLabel = 'Custom message… (open dialog)'
$gitStatusLabel = 'By Git Status'

if (-not [string]::IsNullOrWhiteSpace($CommitMessage)) {
    if ($CommitMessage -match '^"(.*)"$') { $CommitMessage = $Matches[1] }
    $argLabel = "(Use arg) $CommitMessage"
    [void]$items.Add($argLabel)
    $argIndex = $items.Count - 1
}
[void]$items.Add($customLabel)
[void]$items.Add($gitStatusLabel)

# Default selection: the arg (if present) otherwise first template
$defaultIndex = if ($argIndex -ge 0) { $argIndex } else { 0 }
$menuAutoSelectSeconds = if ($argIndex -ge 0) { $ArgMenuAutoApproveSeconds } else { 0 }

if (-not $Host.UI.RawUI) {
    if ([string]::IsNullOrWhiteSpace($CommitMessage)) { Fail 'Interactive menu not available and no commit message provided' }
} else {
    while ($true) {
        $picked = Select-CommitMessage $items $defaultIndex $menuAutoSelectSeconds
        if ([string]::IsNullOrWhiteSpace($picked)) { exit 1 } # Esc -> abort
        if ($picked -eq $customLabel) {
            $prefill = if ([string]::IsNullOrWhiteSpace($CommitMessage)) { '' } else { $CommitMessage }
            $c = Show-InputBox -title 'Commit Message' -prompt 'Enter custom commit message:' -default $prefill
            if ([string]::IsNullOrWhiteSpace($c)) { continue } # back to menu if canceled/empty
            $CommitMessage = $c
            break
        } elseif ($picked -eq $gitStatusLabel) {
            $c = git-status-commit-message
            if ([string]::IsNullOrWhiteSpace($c)) { continue }
            $approvedMessage = Show-GitStatusCommitMessageApproval -commitMessage $c -autoApproveSeconds $GitStatusApprovalAutoApproveSeconds
            if ([string]::IsNullOrWhiteSpace($approvedMessage)) { continue }
            $CommitMessage = $approvedMessage
            break
        } elseif ($argIndex -ge 0 -and $picked -eq $items[$argIndex]) {
            break # use provided arg from the menu
        } else {
            $CommitMessage = $picked
            break
        }
    }
}

Write-Host 'Adding files...' -ForegroundColor Cyan
git add --all
if ($LASTEXITCODE -ne 0) { Fail 'git add failed' }
Start-Sleep -Milliseconds 300

Write-Host 'Committing...' -ForegroundColor Cyan
git commit -m "$CommitMessage"
if ($LASTEXITCODE -ne 0) { Fail 'git commit failed (maybe nothing to commit?)' }
Start-Sleep -Milliseconds 300

Write-Host 'Pushing...' -ForegroundColor Cyan
git push
if ($LASTEXITCODE -ne 0) { Fail 'git push failed' }

Write-Host "`nDone.`n" -ForegroundColor Green
