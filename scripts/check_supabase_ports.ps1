# Supabase 포트 확인 스크립트
# 사용법: .\scripts\check_supabase_ports.ps1

Write-Host "=== Supabase 포트 상태 확인 ===" -ForegroundColor Cyan
Write-Host ""

# Supabase 포트 정의
$supabasePorts = @{
    "API"        = 54500
    "Database"   = 54501
    "Studio"     = 54503
    "Mailpit"    = 54504
    "Analytics"  = 54505
}

$allAvailable = $true
$issues = @()

# 각 포트 확인
foreach ($service in $supabasePorts.Keys) {
    $port = $supabasePorts[$service]
    $inUse = netstat -ano | findstr ":$port "
    
    if ($inUse) {
        Write-Host "[$service] 포트 $port : 사용 중 ❌" -ForegroundColor Red
        $allAvailable = $false
        $issues += "$service (포트 $port)"
    } else {
        Write-Host "[$service] 포트 $port : 사용 가능 ✅" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Windows 포트 예약 범위 확인 ===" -ForegroundColor Cyan
Write-Host ""

# Windows 포트 예약 범위 확인
try {
    $reservedRanges = netsh interface ipv4 show excludedportrange protocol=tcp 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host $reservedRanges
    } else {
        Write-Host "포트 예약 범위 확인 실패 (관리자 권한 필요할 수 있음)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "포트 예약 범위 확인 중 오류 발생: $_" -ForegroundColor Yellow
}

Write-Host ""

# 결과 요약
if ($allAvailable) {
    Write-Host "✅ 모든 Supabase 포트가 사용 가능합니다." -ForegroundColor Green
    Write-Host "   Supabase를 시작할 수 있습니다." -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ 다음 포트가 사용 중입니다:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "   - $issue" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "해결 방법:" -ForegroundColor Yellow
    Write-Host "1. 해당 포트를 사용하는 프로세스 확인: netstat -ano | findstr ':<포트번호>'" -ForegroundColor Yellow
    Write-Host "2. Supabase 중지: npx supabase stop" -ForegroundColor Yellow
    Write-Host "3. Docker Desktop 재시작 (필요 시)" -ForegroundColor Yellow
    Write-Host "4. 포트가 Windows 예약 범위에 포함된 경우 supabase/config.toml에서 포트 변경" -ForegroundColor Yellow
    exit 1
}

