@echo off
powershell -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" -Compress %*
