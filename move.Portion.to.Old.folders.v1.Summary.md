# move.Portion.to.Old.folders.v1.cmd

## Summary

`move.Portion.to.Old.folders.v1.cmd` is a Windows `.cmd` script
containing embedded PowerShell. It is designed to run as a single file:
the Batch portion starts PowerShell, and the PowerShell portion performs
the main workflow.

## What the Script Does

-   Works with timestamp/newest-set logic present in the script to
    select the relevant generated files.
-   Displays progress in the console with `Write-Progress`.
-   Includes logging logic and records execution information to a log
    file.
-   Uses `try/catch` blocks for error handling.
-   Keeps the console available at the end through the Batch `pause`
    behavior.

## User Interface

No `System.Windows.Forms` reference was detected in the script.

## File Operations

-   The script contains explicit overwrite/override handling for
    destination files that already exist.
-   Source files are enumerated with `Get-ChildItem`.

## Logging

The script contains log-file handling.

## Error Handling

The PowerShell workflow uses `try/catch` exception handling. Failures
can therefore be reported separately from successful operations rather
than terminating silently. The script also contains exit-code handling
so callers can distinguish success from failure.

## Important Configuration

Configuration values are defined in PowerShell variables near the start
of the embedded script.

## Windows Paths Referenced

-   `C:\Git\!myRepos\mpages\m1t2`
-   `C:\Git\!myRepos\mpages\old\m1t2`
-   `C:\Git\!myRepos\mpages\pdf_scroll`
-   `C:\Git\!myRepos\mpages\old\pdf_scroll`

## Main PowerShell Functions

-   `Get-ConsoleColor`
-   `Write-TDLog`
-   `Register-Warning`
-   `Register-Error`
-   `Ensure-Directory`
-   `Get-RelativeItemPath`
-   `Test-IsExcludedContentPath`
-   `Copy-ContentTree`
-   `Move-NonContentTree`
-   `Remove-EmptyNonContentDirectories`
-   `Invoke-FolderSet`

## Running the Script

Run the `.cmd` file on Windows. The Batch launcher invokes the
PowerShell code embedded in the same file. Review any confirmation UI
before approving file operations, then check the console and generated
log for the final result.

## Notes

This document summarizes the behavior found directly in the supplied
script. It does not execute the script or assume behavior that is not
represented in its code.
