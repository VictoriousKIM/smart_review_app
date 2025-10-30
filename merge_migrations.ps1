# Merge migration files into one unified schema
$basePath = "supabase\migrations"
$outputFile = "$basePath\000001_unified_schema.sql"

# Read files
$part1 = Get-Content "$basePath\001_initial_schema.sql" -Raw -Encoding UTF8
$part2 = Get-Content "$basePath\20251024044655_create_business_registration_table.sql" -Raw -Encoding UTF8

# Find where extensions start in part2
$extStart = $part2.IndexOf("CREATE EXTENSION")
$part2Clean = $part2.Substring($extStart)

# Create header
$header = "-- Unified Schema Migration`r`n"
$header += "-- Generated: 2025-01-30`r`n"
$header += "-- Consolidates: 001_initial_schema.sql, 20251024044655_create_business_registration_table.sql`r`n"
$header += "-- Note: business_registrations and reviews tables are removed (not used)`r`n`r`n"

# Combine
$unified = $header + $part1.TrimEnd() + "`r`n`r`n-- Additional schema components`r`n" + $part2Clean

# Write output
[System.IO.File]::WriteAllText($outputFile, $unified, [System.Text.Encoding]::UTF8)
Write-Host "Created unified schema file: $outputFile"

