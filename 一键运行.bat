@echo off
chcp 65001 >nul
title 模拟器碧蓝航线换服工具 - AzurLane-Server-Switcher
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\sync_assets.ps1"
pause
