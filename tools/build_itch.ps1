# Build both itch.io uploads: the Windows zip and the browser zip.
# See docs/ITCH.md for the page setup and the butler push commands.
#
# Runs every harness first (including the two-process net harness) and refuses
# to build if any fail - shipping a broken build to strangers costs more than
# shipping one to friends.
#
#   powershell -ExecutionPolicy Bypass -File tools/build_itch.ps1
#   powershell -ExecutionPolicy Bypass -File tools/build_itch.ps1 -SkipTests

param(
    [string]$Godot = "$env:USERPROFILE\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe",
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

if (-not (Test-Path $Godot)) {
    Write-Host "Godot not found at: $Godot" -ForegroundColor Red
    exit 1
}
$templates = Join-Path $env:APPDATA "Godot\export_templates\4.7.1.stable"
foreach ($needed in @("windows_release_x86_64.exe", "web_nothreads_release.zip")) {
    if (-not (Test-Path (Join-Path $templates $needed))) {
        Write-Host "Export template missing: $needed" -ForegroundColor Red
        Write-Host "Open Godot -> Editor -> Manage Export Templates -> Download and Install."
        exit 1
    }
}

if (-not $SkipTests) {
    Write-Host "Running harnesses..." -ForegroundColor Cyan
    foreach ($h in @("movement", "combat", "match", "terrain", "net")) {
        # No 2>&1 on a native exe: PowerShell 5.1 wraps stderr lines in
        # ErrorRecords and fails the run over engine chatter.
        $output = (& $Godot --headless --path . "tests/${h}_harness.tscn") | Out-String
        $passes = ([regex]::Matches($output, "(?m)^PASS")).Count
        $bad = ([regex]::Matches($output, "(?m)^FAIL|SCRIPT ERROR")).Count
        if ($bad -gt 0) {
            Write-Host "  $h : $passes pass, $bad FAILED - not building." -ForegroundColor Red
            $output -split "`n" | Where-Object { $_ -match "^FAIL|SCRIPT ERROR" } | ForEach-Object { Write-Host ("    " + $_.Trim()) }
            exit 1
        }
        Write-Host "  $h : $passes pass" -ForegroundColor Green
    }
}

Write-Host "Importing resources..." -ForegroundColor Cyan
& $Godot --headless --path . --import | Out-Null

New-Item -ItemType Directory -Force "build\itch" | Out-Null

# --- Windows ---
if (Test-Path "build\Overstomp.exe") { Remove-Item "build\Overstomp.exe" -Force }
Write-Host "Exporting Windows..." -ForegroundColor Cyan
& $Godot --headless --path . --export-release "Windows Desktop" "build\Overstomp.exe"
if (-not (Test-Path "build\Overstomp.exe")) {
    Write-Host "Windows export produced no file." -ForegroundColor Red
    exit 1
}
if (Test-Path "build\itch\overstomp-windows.zip") { Remove-Item "build\itch\overstomp-windows.zip" -Force }
Compress-Archive -Path "build\Overstomp.exe" -DestinationPath "build\itch\overstomp-windows.zip"

# --- Web ---
if (Test-Path "build\web") { Remove-Item "build\web" -Recurse -Force }
New-Item -ItemType Directory -Force "build\web" | Out-Null
Write-Host "Exporting Web..." -ForegroundColor Cyan
& $Godot --headless --path . --export-release "Web" "build\web\index.html"
if (-not (Test-Path "build\web\index.html")) {
    Write-Host "Web export produced no file." -ForegroundColor Red
    exit 1
}
if (Test-Path "build\itch\overstomp-web.zip") { Remove-Item "build\itch\overstomp-web.zip" -Force }
# itch requires index.html at the ZIP ROOT, so zip the folder's contents.
Compress-Archive -Path "build\web\*" -DestinationPath "build\itch\overstomp-web.zip"

$w = [math]::Round((Get-Item "build\itch\overstomp-windows.zip").Length / 1MB, 1)
$b = [math]::Round((Get-Item "build\itch\overstomp-web.zip").Length / 1MB, 1)
Write-Host "Built build\itch\overstomp-windows.zip ($w MB) and overstomp-web.zip ($b MB)" -ForegroundColor Green
Write-Host "Next: docs/ITCH.md - butler push, or upload the zips on the itch dashboard."
