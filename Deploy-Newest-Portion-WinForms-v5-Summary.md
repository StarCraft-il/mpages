# Deploy-Newest-Portion-WinForms-v5.cmd

## Summary

`Deploy-Newest-Portion-WinForms-v5.cmd` is a Windows hybrid Batch +
PowerShell deployment script for copying the newest generated file set
for a configured Portion (currently `Shoftim`) from the
`OpenServers_content` source directory into the appropriate `mpages`
destination directories.

The Batch section launches the PowerShell code embedded in the same
`.cmd` file, so the script can be run directly by double-clicking it.

## What the Script Does

1.  Uses the configured Portion name (`Shoftim`).
2.  Scans the source directory:
    `C:\Git\allproj\_OneFile\OpenServers_content`
3.  Finds timestamped files belonging to that Portion.
4.  Determines the newest generated timestamp, such as:
    `20260809.151256`
5.  Selects the files belonging to that newest Portion/timestamp set.
6.  Applies the required destination filename cleanup to generated HTML
    files. For example:
    `Shoftim.mobile.zoom.v1.html.20260809.151256.html` becomes:
    `Shoftim.mobile.zoom.v1.html`
7.  Builds the copy operations for the destination folders:
    -   `C:\Git\!myRepos\mpages\pdf_scroll`
    -   `C:\Git\!myRepos\mpages\m1t2`
8.  Displays a resizable PowerShell WinForms confirmation window before
    changing any files.
9.  Copies the files only after the user clicks **OK**.
10. If the user clicks **Cancel**, exits without copying anything.
11. Displays progress and operation messages in the console.
12. Produces a final summary and returns a non-zero exit code when an
    operation fails.

## Confirmation Window

Before copying, the script displays a WinForms window titled:

**Confirm File Copy**

The window is approximately 1000 x 700 and is resizable.

It contains a read-only multiline text area using the Consolas font,
with both vertical and horizontal scrollbars.

The confirmation screen displays:

-   Source folder
-   Destination folders
-   Selected timestamp
-   Total selected file count
-   Log file location
-   Full file/copy-operation list
-   **OK** button
-   **Cancel** button

This allows the complete deployment set to be reviewed before files are
written.

## Destination Rules

### `pdf_scroll`

The newest generated Portion set is copied to:

`C:\Git\!myRepos\mpages\pdf_scroll`

The timestamped PDF, viewer, loader, and relevant HTML files retain
their appropriate generated names, except for the special HTML cleanup
described below.

### `m1t2`

The clean HTML entry files are additionally copied to:

`C:\Git\!myRepos\mpages\m1t2`

These include:

-   `Shoftim.mobile.zoom.step-scroll.v1.html`
-   `Shoftim.mobile.zoom.v1.html`
-   `p.f2.Shoftim.html`

## Special HTML Filename Handling

Some source HTML files contain the generated timestamp after `.html`.

For example:

``` text
Shoftim.mobile.zoom.step-scroll.v1.html.20260809.151256.html
Shoftim.mobile.zoom.v1.html.20260809.151256.html
p.f2.Shoftim.html.20260809.151256.html
```

The destination filenames are cleaned to:

``` text
Shoftim.mobile.zoom.step-scroll.v1.html
Shoftim.mobile.zoom.v1.html
p.f2.Shoftim.html
```

The source files themselves are not renamed.

## Existing File / Override Handling

Before copying, the script checks whether each destination file already
exists.

The confirmation screen distinguishes operations using markers such as:

``` text
[NEW]
[OVERRIDE]
```

When an existing file is replaced, the console displays a special red
override message.

The log also records the operation as an `Override` event.

An override is intentional and is **not counted as an error**.

## Logging

A log file is created for every run.

The log is stored in the **same directory as the running `.cmd`
script**, not in the source or destination directories.

The filename format is:

``` text
res.yyyyMMddHHmmss.log
```

Example:

``` text
res.20260809182345.log
```

The log records information such as:

-   Script startup
-   Selected Portion
-   Selected newest timestamp
-   Copy operations
-   Successful copies
-   Existing-file overrides
-   Warnings
-   Errors
-   Cancellation
-   Final execution summary

The exact log path is displayed in the confirmation window and final
summary.

## Console Output

The script uses different console colors for log levels.

In particular:

-   Normal informational messages are displayed normally/by their
    configured level.
-   Successful operations are highlighted.
-   Warnings are highlighted.
-   Errors are displayed in red.
-   Existing destination-file overrides are displayed as special red
    `OVERRIDE` messages.

A progress indicator is also displayed while files are being copied.

## Final Summary

At the end of execution, the console displays a summary containing:

-   Execution status
-   Files copied
-   Files moved
-   Errors encountered
-   Log file location

`Files moved` will normally remain `0`, because the current workflow
copies files rather than moving the source files.

## Error Handling

The PowerShell implementation uses `try/catch` error handling around the
main workflow and individual copy operations.

If an operation fails:

-   The error is written to the console.
-   The error is written to the log.
-   The error counter is incremented.
-   The script finishes with a non-zero exit code.

This makes failures visible both interactively and to other processes
that may execute the `.cmd` file.

## Running the Script

Run the `.cmd` file directly from Windows, for example by
double-clicking it.

The script launches its embedded PowerShell implementation
automatically.

Review the **Confirm File Copy** window carefully and click:

-   **OK** --- perform the copy operations.
-   **Cancel** --- exit without copying files.

The console remains open at the end so the final result can be reviewed.
