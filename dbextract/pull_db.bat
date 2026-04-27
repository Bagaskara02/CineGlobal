@echo off
C:\Android\sdk\platform-tools\adb.exe exec-out run-as com.example.cineglobal cat databases/cineglobal.db > "%~dp0cineglobal.db"
echo Done! File saved to: %~dp0cineglobal.db
pause
