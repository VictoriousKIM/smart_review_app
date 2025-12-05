# 프로덕션 DB 리셋 및 마이그레이션 적용 스크립트

Write-Host "⚠️  주의: 프로덕션 DB의 모든 데이터가 삭제됩니다!" -ForegroundColor Yellow
Write-Host ""
Write-Host "1단계: Supabase 대시보드에서 SQL Editor를 열고 다음 SQL을 실행하세요:"
Write-Host "   https://app.supabase.com/project/ythmnhadeyfusmfhcgdr/sql/new" -ForegroundColor Cyan
Write-Host ""
Get-Content supabase/reset_production.sql
Write-Host ""
Write-Host "2단계: SQL 실행이 완료되면 Enter 키를 누르세요..." -ForegroundColor Green
Read-Host

Write-Host "마이그레이션 적용 중..." -ForegroundColor Green
npx supabase db push --linked --include-seed






















