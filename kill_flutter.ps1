# Flutter/Dart 프로세스 완전 종료 스크립트
Write-Host "Flutter/Dart 프로세스 종료 중..." -ForegroundColor Yellow

# Flutter 관련 프로세스들
$processes = @(
    "flutter",
    "dart", 
    "dartaotruntime",
    "adb",
    "java",
    "chrome",
    "code"
)

foreach ($process in $processes) {
    try {
        $runningProcesses = Get-Process -Name $process -ErrorAction SilentlyContinue
        if ($runningProcesses) {
            Write-Host "종료 중: $process" -ForegroundColor Red
            Stop-Process -Name $process -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Host "$process 프로세스를 찾을 수 없습니다." -ForegroundColor Gray
    }
}

# 포트 사용 중인 프로세스도 확인 (Flutter 기본 포트들)
$ports = @(8080, 3000, 5000, 8000, 9000)
foreach ($port in $ports) {
    try {
        $process = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess
        if ($process) {
            Write-Host "포트 $port 사용 중인 프로세스 종료: PID $process" -ForegroundColor Red
            Stop-Process -Id $process -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        # 포트가 사용되지 않음
    }
}

Write-Host "모든 Flutter/Dart 프로세스가 종료되었습니다." -ForegroundColor Green
Read-Host "Press Enter to continue"

