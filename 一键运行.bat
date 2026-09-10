@echo off
chcp 65001 >nul
title 碧蓝航线跨服资源极速复用工具 - AzurLane-CrossServer-Sync
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\sync_assets.ps1"
pause
