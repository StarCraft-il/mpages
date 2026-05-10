@echo off
setlocal
set "SELF_PATH=%~f0"
set "PS_MARKER=:__PS_SCRIPT_BELOW__"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$selfPath = [System.Environment]::GetEnvironmentVariable('SELF_PATH');" ^
  "$marker = [System.Environment]::GetEnvironmentVariable('PS_MARKER');" ^
  "$content = Get-Content -LiteralPath $selfPath -Raw;" ^
  "$markerIndex = $content.LastIndexOf($marker);" ^
  "if ($markerIndex -lt 0) { throw 'PowerShell marker not found.' };" ^
  "$scriptContent = $content.Substring($markerIndex + $marker.Length);" ^
  "$tempPath = Join-Path $env:TEMP ('update.check.pages.' + [System.Guid]::NewGuid().ToString('N') + '.ps1');" ^
  "Set-Content -LiteralPath $tempPath -Value $scriptContent -Encoding UTF8;" ^
  "try { & $tempPath; exit $LASTEXITCODE } finally { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }"

set "EXIT_CODE=%errorlevel%"
if not defined CHECK_PAGES_NO_PAUSE pause
exit /b %EXIT_CODE%
:__PS_SCRIPT_BELOW__

enum LogLevel {
    Info
    Warning
    Error
}

$script:ExitCode = 0
$script:RootPath = Split-Path -Parent $env:SELF_PATH
$script:LogFileName = 'res.{0}.log' -f (Get-Date -Format 'yyyyMMddHHmmss')
$script:LogFilePath = Join-Path -Path $script:RootPath -ChildPath $script:LogFileName

function Write-Log {
    param(
        [LogLevel]$Level,
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message
    Add-Content -LiteralPath $script:LogFilePath -Value $line

    switch ($Level) {
        ([LogLevel]::Info) {
            Write-Host $line -ForegroundColor Cyan
        }
        ([LogLevel]::Warning) {
            Write-Host $line -ForegroundColor Yellow
        }
        ([LogLevel]::Error) {
            Write-Host $line -ForegroundColor Red
        }
    }
}

function Get-FolderRank {
    param(
        [string]$FolderPath
    )

    if ($FolderPath -eq 'm1t2') {
        return 0
    }

    if ($FolderPath.StartsWith('m1t2/')) {
        return 0
    }

    if ($FolderPath -eq '.') {
        return 1
    }

    return 2
}

function Get-FileRank {
    param(
        [string]$RelativePath
    )

    if ($RelativePath -eq 'm1t2') {
        return 0
    }

    if ($RelativePath.StartsWith('m1t2/')) {
        return 0
    }

    return 1
}

function Get-HtmlFiles {
    $rootPrefix = $script:RootPath.TrimEnd('\') + '\'

    $items = Get-ChildItem -Path $script:RootPath -Recurse -File -Filter *.html |
        Where-Object { $_.FullName -notmatch '\\.git(\\|$)' } |
        ForEach-Object {
            $relativePath = $_.FullName.Substring($rootPrefix.Length).Replace('\', '/')
            [PSCustomObject]@{
                RelativePath = $relativePath
                Rank = Get-FileRank -RelativePath $relativePath
            }
        } |
        Sort-Object Rank, RelativePath

    return @($items | ForEach-Object { $_.RelativePath })
}

function Get-CheckPagesTemplate {
@'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate, max-age=0" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>mPages - Check Pages</title>
    <style>
        :root {
            --bg: #08111f;
            --surface: #121c2d;
            --line: rgba(255, 255, 255, 0.08);
            --text: #edf4ff;
            --muted: #9eb0ca;
            --accent: #38bdf8;
        }

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            min-height: 100vh;
            background: linear-gradient(180deg, #09111f 0%, #0d1728 55%, #09101b 100%);
            color: var(--text);
            font-family: Arial, Helvetica, sans-serif;
        }

        a {
            color: inherit;
        }

        .page {
            width: min(100%, 1120px);
            margin: 0 auto;
            padding: 18px 14px 28px;
        }

        .hero,
        .panel {
            padding: 18px;
            border-radius: 20px;
            background: linear-gradient(180deg, rgba(56, 189, 248, 0.12), rgba(255, 255, 255, 0.03));
            border: 1px solid rgba(56, 189, 248, 0.18);
            box-shadow: 0 18px 36px rgba(0, 0, 0, 0.18);
        }

        .panel {
            margin-top: 16px;
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid var(--line);
            box-shadow: none;
        }

        .hero h1,
        .panel h2 {
            margin: 0 0 10px;
            line-height: 1.2;
        }

        .hero h1 {
            font-size: 28px;
        }

        .hero p {
            margin: 0;
            color: var(--muted);
            font-size: 15px;
            line-height: 1.7;
        }

        .badge {
            display: inline-block;
            margin-bottom: 8px;
            padding: 6px 10px;
            border-radius: 999px;
            background: rgba(56, 189, 248, 0.14);
            color: #d8f4ff;
            font-size: 12px;
            font-weight: bold;
        }

        .toolbar {
            display: grid;
            gap: 12px;
            margin-top: 16px;
        }

        .toolbar-row {
            display: grid;
            gap: 12px;
        }

        .toolbar-actions {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
        }

        .button-link,
        .button-action {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-height: 44px;
            padding: 12px 16px;
            border-radius: 14px;
            border: 1px solid rgba(255, 255, 255, 0.08);
            background: linear-gradient(180deg, rgba(24, 38, 61, 0.96), rgba(18, 28, 45, 0.96));
            color: inherit;
            text-decoration: none;
            font-size: 14px;
            font-weight: bold;
            cursor: pointer;
        }

        .button-action.blue {
            border-color: rgba(56, 189, 248, 0.34);
        }

        .search-box {
            width: 100%;
            min-height: 46px;
            padding: 12px 14px;
            border-radius: 14px;
            border: 1px solid rgba(255, 255, 255, 0.12);
            background: rgba(8, 17, 31, 0.9);
            color: var(--text);
            font-size: 15px;
        }

        .stats {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 14px;
        }

        .stat-card {
            padding: 10px 12px;
            border-radius: 14px;
            background: rgba(255, 255, 255, 0.04);
            border: 1px solid var(--line);
            color: var(--muted);
            font-size: 13px;
        }

        .stat-card strong {
            color: var(--text);
        }

        .status {
            margin-top: 12px;
            padding: 12px 14px;
            border-radius: 14px;
            background: rgba(255, 255, 255, 0.04);
            border: 1px solid var(--line);
            color: var(--muted);
            font-size: 14px;
            line-height: 1.7;
        }

        .folder-list {
            display: grid;
            gap: 14px;
        }

        .folder-card {
            border: 1px solid var(--line);
            border-radius: 18px;
            overflow: hidden;
            background: rgba(18, 28, 45, 0.6);
        }

        .folder-header {
            display: flex;
            flex-wrap: wrap;
            gap: 8px 12px;
            align-items: center;
            justify-content: space-between;
            padding: 14px 16px;
            background: rgba(255, 255, 255, 0.04);
            border-bottom: 1px solid var(--line);
        }

        .folder-title {
            font-size: 17px;
            font-weight: bold;
            word-break: break-word;
        }

        .folder-count {
            color: var(--muted);
            font-size: 13px;
        }

        .file-links {
            display: grid;
            gap: 10px;
            padding: 14px;
        }

        .file-link {
            display: block;
            padding: 12px 14px;
            border-radius: 14px;
            text-decoration: none;
            background: rgba(8, 17, 31, 0.72);
            border: 1px solid rgba(255, 255, 255, 0.08);
        }

        .file-name {
            display: block;
            color: var(--text);
            font-size: 15px;
            font-weight: bold;
            line-height: 1.5;
            word-break: break-word;
        }

        .file-path {
            display: block;
            margin-top: 4px;
            color: var(--muted);
            font-size: 12px;
            line-height: 1.6;
            word-break: break-word;
        }

        .empty-message {
            padding: 18px;
            border-radius: 16px;
            background: rgba(255, 255, 255, 0.04);
            border: 1px dashed rgba(255, 255, 255, 0.16);
            color: var(--muted);
            text-align: center;
        }

        @media (min-width: 760px) {
            .page {
                padding: 26px 20px 40px;
            }

            .toolbar-row {
                grid-template-columns: minmax(0, 1fr) auto;
                align-items: center;
            }

            .hero h1 {
                font-size: 34px;
            }
        }
    </style>
</head>
<body>
    <main class="page">
        <section class="hero">
            <span class="badge">Static generated html page list</span>
            <h1>Check Pages</h1>
            <p>This page was generated by <strong>update.check.pages.cmd</strong>. Folder <strong>m1t2</strong> is shown first.</p>
            <div class="stats">
                <div class="stat-card">Generated on: <strong>__GENERATED_ON__</strong></div>
                <div class="stat-card">Html pages: <strong id="fileCount">__FILE_COUNT__</strong></div>
                <div class="stat-card">Folders: <strong id="folderCount">0</strong></div>
                <div class="stat-card">Log file: <strong>__LOG_FILE_NAME__</strong></div>
            </div>
        </section>

        <section class="panel">
            <h2>Controls</h2>
            <div class="toolbar">
                <div class="toolbar-row">
                    <input id="txtFilter" class="search-box" type="text" placeholder="Filter html pages by file name or path..." />
                    <div class="toolbar-actions">
                        <button id="btnReloadPage" class="button-action blue" type="button">Reload page</button>
                        <a class="button-link" href="./index.html">Back to index</a>
                    </div>
                </div>
            </div>
            <div class="status">This list is static until update.check.pages.cmd is run again.</div>
        </section>

        <section class="panel">
            <h2>Html Pages</h2>
            <div id="filesContainer" class="folder-list"></div>
        </section>
    </main>

    <script>
        (function () {
            const allFiles = __FILE_LIST_JSON__;
            const txtFilter = document.getElementById('txtFilter');
            const btnReloadPage = document.getElementById('btnReloadPage');
            const filesContainer = document.getElementById('filesContainer');
            const fileCountElement = document.getElementById('fileCount');
            const folderCountElement = document.getElementById('folderCount');

            function escapeHtml(value) {
                return String(value)
                    .replace(/&/g, '&amp;')
                    .replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;')
                    .replace(/\"/g, '&quot;')
                    .replace(/'/g, '&#39;');
            }

            function getFolderPath(path) {
                const lastSlashIndex = path.lastIndexOf('/');

                if (lastSlashIndex < 0) {
                    return '.';
                }

                return path.substring(0, lastSlashIndex);
            }

            function getFileName(path) {
                const lastSlashIndex = path.lastIndexOf('/');

                if (lastSlashIndex < 0) {
                    return path;
                }

                return path.substring(lastSlashIndex + 1);
            }

            function buildFileHref(path) {
                const encodedPath = path.split('/').map(function (segment) {
                    return encodeURIComponent(segment);
                }).join('/');

                return './' + encodedPath;
            }

            function getFolderRank(folderPath) {
                if (folderPath === 'm1t2' || folderPath.startsWith('m1t2/')) {
                    return 0;
                }

                if (folderPath === '.') {
                    return 1;
                }

                return 2;
            }

            function groupFiles(files) {
                const groups = new Map();

                files.forEach(function (filePath) {
                    const folderPath = getFolderPath(filePath);

                    if (!groups.has(folderPath)) {
                        groups.set(folderPath, []);
                    }

                    groups.get(folderPath).push(filePath);
                });

                const groupedResult = Array.from(groups.entries()).map(function (entry) {
                    return {
                        folderPath: entry[0],
                        files: entry[1].slice().sort(function (left, right) {
                            return left.localeCompare(right, undefined, { sensitivity: 'base' });
                        })
                    };
                });

                groupedResult.sort(function (left, right) {
                    const leftRank = getFolderRank(left.folderPath);
                    const rightRank = getFolderRank(right.folderPath);

                    if (leftRank !== rightRank) {
                        return leftRank - rightRank;
                    }

                    return left.folderPath.localeCompare(right.folderPath, undefined, { sensitivity: 'base' });
                });

                return groupedResult;
            }

            function renderFiles() {
                const rawFilter = txtFilter.value.trim().toLowerCase();
                const filteredFiles = allFiles.filter(function (filePath) {
                    if (rawFilter.length === 0) {
                        return true;
                    }

                    return filePath.toLowerCase().includes(rawFilter);
                });
                const groupedFiles = groupFiles(filteredFiles);

                fileCountElement.textContent = String(filteredFiles.length);
                folderCountElement.textContent = String(groupedFiles.length);

                if (filteredFiles.length === 0) {
                    filesContainer.innerHTML = '<div class="empty-message">No html pages matched the current filter.</div>';
                    return;
                }

                const html = groupedFiles.map(function (group) {
                    const fileLinksHtml = group.files.map(function (filePath) {
                        return [
                            '<a class="file-link" href="',
                            buildFileHref(filePath),
                            '">',
                            '<span class="file-name">',
                            escapeHtml(getFileName(filePath)),
                            '</span>',
                            '<span class="file-path">',
                            escapeHtml(filePath),
                            '</span>',
                            '</a>'
                        ].join('');
                    }).join('');

                    return [
                        '<section class="folder-card">',
                        '<div class="folder-header">',
                        '<div class="folder-title">',
                        escapeHtml(group.folderPath),
                        '</div>',
                        '<div class="folder-count">',
                        String(group.files.length),
                        ' html page(s)</div>',
                        '</div>',
                        '<div class="file-links">',
                        fileLinksHtml,
                        '</div>',
                        '</section>'
                    ].join('');
                }).join('');

                filesContainer.innerHTML = html;
            }

            txtFilter.addEventListener('input', function () {
                renderFiles();
            });

            btnReloadPage.addEventListener('click', function () {
                window.location.reload();
            });

            renderFiles();
        })();
    </script>
</body>
</html>
'@
}

function Update-CheckPagesFile {
    $htmlFiles = Get-HtmlFiles
    $jsonFiles = $htmlFiles | ConvertTo-Json -Depth 3
    $template = Get-CheckPagesTemplate
    $generatedOn = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $outputPath = Join-Path -Path $script:RootPath -ChildPath 'check.pages.html'

    $content = $template.
        Replace('__FILE_LIST_JSON__', $jsonFiles).
        Replace('__GENERATED_ON__', $generatedOn).
        Replace('__FILE_COUNT__', [string]$htmlFiles.Count).
        Replace('__LOG_FILE_NAME__', $script:LogFileName)

    Set-Content -LiteralPath $outputPath -Value $content -Encoding UTF8
    Write-Log -Level ([LogLevel]::Info) -Message ("Updated check.pages.html with {0} html page(s)." -f $htmlFiles.Count)
}

try {
    New-Item -ItemType File -Path $script:LogFilePath -Force | Out-Null
    Write-Log -Level ([LogLevel]::Info) -Message ('Started update.check.pages.cmd in root: ' + $script:RootPath)
    Update-CheckPagesFile
    Write-Log -Level ([LogLevel]::Info) -Message ('Finished successfully.')
}
catch {
    $script:ExitCode = 1
    Write-Log -Level ([LogLevel]::Error) -Message $_.Exception.Message
}

exit $script:ExitCode
