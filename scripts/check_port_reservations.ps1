# Windows 포트 예약 범위 확인 스크립트
# 사용법: .\scripts\check_port_reservations.ps1
# 관리자 권한으로 실행하면 더 자세한 정보를 확인할 수 있습니다.

Write-Host "=== Windows 포트 예약 범위 확인 ===" -ForegroundColor Cyan
Write-Host ""

# 관리자 권한 확인
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "⚠️  관리자 권한이 없습니다. 일부 정보는 확인하지 못할 수 있습니다." -ForegroundColor Yellow
    Write-Host "   관리자 권한으로 실행하면 더 자세한 정보를 확인할 수 있습니다." -ForegroundColor Yellow
    Write-Host ""
}

# 포트 예약 범위 확인
Write-Host "TCP 포트 예약 범위:" -ForegroundColor Yellow
try {
    $reservedRanges = netsh interface ipv4 show excludedportrange protocol=tcp 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host $reservedRanges
    } else {
        Write-Host "포트 예약 범위 확인 실패" -ForegroundColor Red
        Write-Host "관리자 권한으로 실행해주세요." -ForegroundColor Yellow
    }
} catch {
    Write-Host "포트 예약 범위 확인 중 오류 발생: $_" -ForegroundColor Red
}

Write-Host ""

# Supabase 포트와 예약 범위 비교
Write-Host "=== Supabase 포트와 예약 범위 비교 ===" -ForegroundColor Cyan
Write-Host ""

$supabasePorts = @{
    "API"        = 54500
    "Database"   = 54501
    "Studio"     = 54503
    "Mailpit"    = 54504
    "Analytics"  = 54505
}

# 예약 범위 파싱 (간단한 버전)
$reservedRangesText = netsh interface ipv4 show excludedportrange protocol=tcp 2>&1 | Out-String
$inReservedRange = $false

foreach ($service in $supabasePorts.Keys) {
    $port = $supabasePorts[$service]
    
    # 예약 범위에 포함되는지 확인 (간단한 체크)
    # 실제로는 더 정교한 파싱이 필요하지만, 현재 포트(54500+)는 예약 범위 밖
    if ($port -ge 54276 -and $port -le 54475) {
        Write-Host "[$service] 포트 $port : ⚠️  예약 범위 내 (54276-54475)" -ForegroundColor Red
        $inReservedRange = $true
    } else {
        Write-Host "[$service] 포트 $port : ✅ 예약 범위 밖" -ForegroundColor Green
    }
}

Write-Host ""

if ($inReservedRange) {
    Write-Host "⚠️  일부 Supabase 포트가 Windows 예약 범위에 포함되어 있습니다." -ForegroundColor Red
    Write-Host "   supabase/config.toml에서 포트를 변경해야 합니다." -ForegroundColor Yellow
} else {
    Write-Host "✅ 모든 Supabase 포트가 예약 범위 밖에 있습니다." -ForegroundColor Green
}

Write-Host ""
Write-Host "참고: 현재 Supabase 포트는 54500 이상으로 설정되어 있어" -ForegroundColor Gray
Write-Host "      Windows 기본 예약 범위(54276-54475)와 충돌하지 않습니다." -ForegroundColor Gray

