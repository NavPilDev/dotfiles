@echo off
REM Thin wrapper so you can double-click a batch file on Windows.
REM All real setup logic lives in install.ps1 (symlinks + winget need PowerShell).
REM Right-click this file and "Run as administrator" for symlinks to succeed
REM without needing Developer Mode enabled.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
