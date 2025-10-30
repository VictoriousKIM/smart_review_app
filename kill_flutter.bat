@echo off
echo Flutter/Dart 프로세스 종료 중...

:: Flutter 프로세스 종료
taskkill /f /im flutter.exe 2>nul
taskkill /f /im dart.exe 2>nul
taskkill /f /im dartaotruntime.exe 2>nul

:: Android 관련 프로세스도 종료 (선택사항)
taskkill /f /im adb.exe 2>nul
taskkill /f /im java.exe 2>nul

:: Chrome 관련 프로세스 종료 (Flutter web 개발 시)
taskkill /f /im chrome.exe 2>nul

:: VS Code 관련 프로세스 종료 (선택사항)
taskkill /f /im code.exe 2>nul

echo 모든 Flutter/Dart 프로세스가 종료되었습니다.
pause

