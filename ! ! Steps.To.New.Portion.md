# Steps to do for new Portion 2 Mikra 1 Taj

## What to run

- After running Portion files generate with: `TwoMikraOneTaj.exe` app in folder: `c:\Git\allproj\_OneFile\OpenServers_content\`
- Move file to `old` folder by running file: `move.Portion.to.Old.folders.v1.cmd`
- Update file: `copy.new.Portion.from.Content.WinForms.v5.cmd`,
	Setting Portion Name, line 40: `$Portion = 'NEW_PORTION_NAME'`
- Copy new Portion files from folder: `c:\Git\allproj\_OneFile\OpenServers_content\` by running file: `copy.new.Portion.from.Content.WinForms.v5.cmd`
- Run script file: `update.check.pages.v4.cmd` to generate new `check.pages.html` file

## In short:
1. Run `TwoMikraOneTaj.exe`
2. Run `move.Portion.to.Old.folders.v1.cmd`
3. Update 'NEW_PORTION_NAME' in file: `copy.new.Portion.from.Content.WinForms.v5.cmd`
4. Run `copy.new.Portion.from.Content.WinForms.v5.cmd`
5. Run `update.check.pages.v4.cmd`