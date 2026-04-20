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

# ===== Selection UI with your formatting =====
function Select-CommitMessage($items, [int]$defaultIndex = 0, [int]$autoSelectSeconds = 0) {
    if (-not $Host.UI.RawUI) { return $null }

    $index = [Math]::Min([Math]::Max(0, $defaultIndex), [Math]::Max(0, $items.Count - 1))
    $lastShownSeconds = -1

    function Draw {
        [Console]::Clear()
        try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

        # Title banner (Cyan)
        Write-Host '===============================' -ForegroundColor Cyan
        Write-Host ('  ' + $BannerTitle)             -ForegroundColor Cyan
        Write-Host '===============================' -ForegroundColor Cyan

        # Instructions (DarkGray) + spacing
        Write-Host ''
        Write-Host $InstructionsText                  -ForegroundColor DarkGray
        Write-Host ''

        # List items: selected = DarkGreen/Yellow + ▶, unselected = Gray
        for ($i = 0; $i -lt $items.Count; $i++) {
            $prefix = ('{0,2}. ' -f ($i + 1))
            if ($i -eq $index) {
                $selMarker = [char]0x25B6 + ' '    # ▶
                Write-Host ($selMarker + $prefix + $items[$i]) `
                    -BackgroundColor DarkGreen -ForegroundColor Yellow
            } else {
                Write-Host ('  ' + $prefix + $items[$i]) -ForegroundColor Gray
            }
        }

        # Footer (DarkGray) + spacing
        Write-Host ''
        Write-Host ("[Total items: {0}]" -f $items.Count) -ForegroundColor DarkGray
        if ($autoSelectSeconds -gt 0 -and $lastShownSeconds -ge 0) {
            Write-Host ("[Auto select current option in: {0}s]" -f $lastShownSeconds) -ForegroundColor Red
        }
    }

    Draw
    $endTime = if ($autoSelectSeconds -gt 0) { [DateTime]::Now.AddSeconds($autoSelectSeconds) } else { $null }
    while ($true) {
        if ($autoSelectSeconds -gt 0) {
            $remainingSeconds = [Math]::Ceiling(([TimeSpan]($endTime - [DateTime]::Now)).TotalSeconds)
            if ($remainingSeconds -le 0) { return $items[$index] }
            if ($remainingSeconds -ne $lastShownSeconds) {
                $lastShownSeconds = $remainingSeconds
                Draw
            }

            if (-not [Console]::KeyAvailable) {
                Start-Sleep -Milliseconds 150
                continue
            }
        }

        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        switch ($key.VirtualKeyCode) {
            38 { if ($index -gt 0) { $index-- } else { $index = $items.Count - 1 }; Draw; continue } # Up
            40 { if ($index -lt $items.Count - 1) { $index++ } else { $index = 0 }; Draw; continue } # Down
            13 { return $items[$index] }   # Enter
            27 { Write-Host 'Aborted.' -ForegroundColor DarkGray; return $null } # Esc
            default {
                $ch = $key.Character
                if ($ch -match '^[1-9]$') {
                    $n = [int]$ch
                    if ($n -ge 1 -and $n -le $items.Count) { return $items[$n - 1] }
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

function Get-ChangeTargetLabel([string[]]$paths) {
    $names = [System.Collections.Generic.List[string]]::new()

    foreach ($path in $paths) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }

        $clean = Normalize-StatusPath $path
        if ([string]::IsNullOrWhiteSpace($clean)) { continue }

        $parts = @($clean -split '\\')
        $name = $null

        if ($parts.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace($parts[0])) {
            $name = $parts[0].Trim()
        } else {
            $name = [System.IO.Path]::GetFileNameWithoutExtension($clean)
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = [System.IO.Path]::GetFileName($clean)
            }
        }

        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($names.Contains($name)) { continue }

        [void]$names.Add($name)
        if ($names.Count -ge 3) { break }
    }

    switch ($names.Count) {
        0 { return 'repository changes' }
        1 { return $names[0] }
        2 { return ('{0} and {1}' -f $names[0], $names[1]) }
        default { return ('{0}, {1} and {2}' -f $names[0], $names[1], $names[2]) }
    }
}

function Get-CommitActionWord([bool]$hasAddedFiles, [bool]$hasUpdatedFiles, [int]$pathCount) {
    if ($hasAddedFiles -and -not $hasUpdatedFiles -and $pathCount -le 3) { return 'Add' }
    return 'Update'
}

function Get-BusinessLogicUpdateMessage([string[]]$fileNames) {
    if (-not $fileNames -or $fileNames.Count -eq 0) { return $null }

    $quotedNames = @($fileNames | ForEach-Object { "'$_'" })
    return ('Business Logic updated in: {0}' -f ([string]::Join(', ', $quotedNames)))
}

function Get-FallbackCommitMessage() {
    $statusLines = Get-RepoStatusLines
    if ($statusLines.Count -eq 0) { return $null }

    $paths = [System.Collections.Generic.List[string]]::new()
    $updatedServiceFiles = [System.Collections.Generic.List[string]]::new()
    $hasDocs = $false
    $hasTests = $false
    $hasSettings = $false
    $hasDevOps = $false
    $hasAddedFiles = $false
    $hasUpdatedFiles = $false

    foreach ($line in $statusLines) {
        $status = if ($line.Length -ge 2) { $line.Substring(0, 2) } else { '' }
        if ($status -match '\?\?' -or $status.Contains('A')) { $hasAddedFiles = $true }
        if ($status -match '[MDRCUT]') { $hasUpdatedFiles = $true }

        $path = if ($line.Length -gt 3) { $line.Substring(3).Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($path)) { continue }

        $cleanPath = Normalize-StatusPath $path
        if ([string]::IsNullOrWhiteSpace($cleanPath)) { continue }

        [void]$paths.Add($cleanPath)

        if ($cleanPath -match '(^|[\\/])(docs?|README)([\\/]|$)|\.md$') { $hasDocs = $true }
        if ($cleanPath -match '(^|[\\/])(test|tests)([\\/]|$)') { $hasTests = $true }
        if ($cleanPath -match 'appsettings|\.json$|\.config$') { $hasSettings = $true }
        if ($cleanPath -match '(^|[\\/])(.github|devops)([\\/]|$)|\.ya?ml$') { $hasDevOps = $true }

        if ($status -match '[MDRCUT]') {
            $parts = @($cleanPath -split '\\')
            if ($parts.Count -ge 2 -and ($parts[0] -ieq 'Service' -or $parts[0] -ieq 'Services')) {
                $fileName = [System.IO.Path]::GetFileName($cleanPath)
                if (-not [string]::IsNullOrWhiteSpace($fileName) -and -not $updatedServiceFiles.Contains($fileName)) {
                    [void]$updatedServiceFiles.Add($fileName)
                }
            }
        }
    }

    if ($hasDocs -and $paths.Count -le 3) { return 'Update documentation' }
    if ($hasTests -and $paths.Count -le 3) {
        if ($hasAddedFiles -and -not $hasUpdatedFiles) { return 'Add tests' }
        return 'Update tests'
    }
    $businessLogicMessage = Get-BusinessLogicUpdateMessage $updatedServiceFiles.ToArray()
    if (-not [string]::IsNullOrWhiteSpace($businessLogicMessage)) { return $businessLogicMessage }
    if ($hasSettings) { return 'Update configuration files' }
    if ($hasDevOps) { return 'Update DevOps files' }

    $target = Get-ChangeTargetLabel $paths.ToArray()
    $actionWord = Get-CommitActionWord -hasAddedFiles $hasAddedFiles -hasUpdatedFiles $hasUpdatedFiles -pathCount $paths.Count
    return "$actionWord $target"
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
    $buttonsPanel.Height = 82

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

    $timer = $null
    if ($autoApproveSeconds -gt 0) {
        $secondsLeft = $autoApproveSeconds
        $approve.Text = ('Approve ({0})' -f $secondsLeft)

        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 1000
        $timer.Add_Tick({
            $secondsLeft--
            if ($secondsLeft -le 0) {
                $timer.Stop()
                $form.Tag = 'Approve'
                $form.Close()
                return
            }

            $approve.Text = ('Approve ({0})' -f $secondsLeft)
        })
    }

    $form.AcceptButton = $approve
    $form.CancelButton = $close
    $buttonsPanel.Controls.Add($approve)
    $buttonsPanel.Controls.Add($close)
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

function Show-GitStatusCommitMessageApproval([string]$commitMessage) {
    return (Show-EditableCommitMessageApproval -windowTitle 'Approve git status commit message' -commitMessage $commitMessage)
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
            $approvedMessage = Show-GitStatusCommitMessageApproval -commitMessage $c
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
