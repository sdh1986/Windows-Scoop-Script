@echo off
powershell -Command Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
powershell -Command %~dpn0.ps1