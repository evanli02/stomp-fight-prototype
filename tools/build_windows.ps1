# Build the Windows .exe for playtesting (docs/PLAYTEST.md).
#
# Runs the four headless harnesses first and refuses to build if any of them
# fail. A build that ships a broken stomp loop to five friends costs an evening;
# the harnesses cost fifteen seconds.
#
#   powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1
#   powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1 -SkipTests

param(
    [string]$Godot = "$env:USERPROFILE\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe",
    [string]$Out = "build\Overstomp.exe",
    [switch]$SkipTests,
    [switch]$Debug
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

if (-not (Test-Path $Godot)) {
    Write-Host "Godot not found at: $Godot" -ForegroundColor Red
    Write-Host "Pass the right path with -Godot <path to Godot console exe>."
    exit 1
}

# Export templates are a separate ~1GB download and are NOT in the repo. Without
# them the export silently produces nothing useful, so check first.
# Checked for the WINDOWS x86_64 release template specifically: the templates
# folder existing proves nothing, since a partial download leaves it there with
# the other platforms in it and the export then fails on the one file it needs.
$templates = Join-Path $env:APPDATA "Godot\export_templates"
$needed = Join-Path $templates "4.7.1.stable\windows_release_x86_64.exe"
$haveTemplates = Test-Path $needed
if (-not $haveTemplates) {
    Write-Host "Windows export template missing:" -ForegroundColor Red
    Write-Host "  $needed"
    Write-Host "Open Godot -> Editor -> Manage Export Templates -> Download and Install."
    exit 1
}

if (-not $SkipTests) {
    Write-Host "Running harnesses..." -ForegroundColor Cyan
    foreach ($h in @("movement", "combat", "match", "terrain")) {
        # No `2>&1` on a native exe: Windows PowerShell 5.1 wraps each stderr line
        # in an ErrorRecord and sets $? to false even on exit code 0, which with
        # ErrorActionPreference=Stop aborts the build over nothing. The harnesses
        # print their verdict on stdout, which is all this needs.
        $output = (& $Godot --headless --path . "tests/${h}_harness.tscn") | Out-String
        $passes = ([regex]::Matches($output, "(?m)^PASS")).Count
        $bad = ([regex]::Matches($output, "(?m)^FAIL|SCRIPT ERROR")).Count
        if ($bad -gt 0) {
            Write-Host "  $h : $passes pass, $bad FAILED" -ForegroundColor Red
            $output -split "`n" | Where-Object { $_ -match "^FAIL|SCRIPT ERROR" } | ForEach-Object { Write-Host ("    " + $_.Trim()) }
            Write-Host "Not building. Fix the failures or pass -SkipTests." -ForegroundColor Red
            exit 1
        }
        Write-Host "  $h : $passes pass" -ForegroundColor Green
    }
}

# Re-import first: a fresh clone (or a new class_name / PNG) has no .godot cache,
# and exporting without one produces a build missing its own assets.
Write-Host "Importing resources..." -ForegroundColor Cyan
& $Godot --headless --path . --import | Out-Null

# Godot reports export problems on stdout and still exits 0 in some cases, so the
# check that matters is whether a file appeared - see below.

New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
# Remove any previous build first: without this a failed export leaves the old
# exe in place and the size check below happily reports success.
if (Test-Path $Out) { Remove-Item $Out -Force }
$mode = if ($Debug) { "--export-debug" } else { "--export-release" }
Write-Host "Exporting ($mode) to $Out ..." -ForegroundColor Cyan
& $Godot --headless --path . $mode "Windows Desktop" $Out

if (-not (Test-Path $Out)) {
    Write-Host "Export produced no file. Check the output above." -ForegroundColor Red
    exit 1
}
$size = [math]::Round((Get-Item $Out).Length / 1MB, 1)
Write-Host "Built $Out ($size MB)" -ForegroundColor Green
Write-Host "Next: docs/PLAYTEST.md - add it to Steam as a non-Steam game, then Remote Play Together."
