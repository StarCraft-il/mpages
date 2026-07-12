@echo off

echo.Adding files...

git add --all

@echo off
ping -n 2 localhost >nul

echo.Commit files...

git commit -m %1

@echo off
ping -n 4 localhost >nul

echo.Push Commit...
@echo off

git push

@echo off
echo.
echo.Done.
echo.
rem To use: > my-push "commit message"