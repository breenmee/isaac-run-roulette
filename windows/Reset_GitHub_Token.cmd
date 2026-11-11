@echo off
if exist "%LOCALAPPDATA%\IsaacRunRoulette\github-token.dpapi" del "%LOCALAPPDATA%\IsaacRunRoulette\github-token.dpapi"
echo Saved token reset. Next sync will ask for a new one.
pause
