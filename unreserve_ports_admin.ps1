# 관리자 권한으로 실행 필요!
# PowerShell을 "관리자 권한으로 실행" 후 이 스크립트 실행

Write-Host "포트 예약 해제 시도..." -ForegroundColor Yellow

# WSL2가 예약한 포트 범위 확인
$excludedRanges = netsh int ipv4 show excludedportrange protocol=tcp

if ($excludedRanges -match "54276.*54375") {
    Write-Host "`nWSL2가 예약한 포트 범위를 발견했습니다: 54276-54375" -ForegroundColor Yellow
    Write-Host "이 범위는 WSL2/Docker Desktop이 동적으로 예약합니다." -ForegroundColor Yellow
    Write-Host "`n해결 방법:" -ForegroundColor Green
    Write-Host "1. Docker Desktop 재시작 (포트 예약이 재설정될 수 있음)" -ForegroundColor Cyan
    Write-Host "2. 또는 Supabase 포트를 54500 이상으로 변경" -ForegroundColor Cyan
    Write-Host "`n포트 예약을 수동으로 해제하려면:" -ForegroundColor Yellow
    Write-Host "netsh int ipv4 delete excludedportrange protocol=tcp startport=54276 numberofports=100" -ForegroundColor White
    Write-Host "`n주의: 이 작업은 시스템 설정을 변경합니다!" -ForegroundColor Red
} else {
    Write-Host "포트 예약이 없습니다." -ForegroundColor Green
}

