$ErrorActionPreference = "Continue"
$Godot = "C:\godot\Godot_v4.7-stable_win64_console.exe"
if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot 4.7 console executable not found: $Godot" }

$parse = & $Godot --headless --path . --editor --quit-after 3 2>&1
$parse | Write-Output
if ($LASTEXITCODE -ne 0 -or ($parse -match "SCRIPT ERROR|Parse Error")) { throw "FAIL: project parse/import" }

$tests = & $Godot --headless --path . --script res://tests/run_tests.gd 2>&1
$tests | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($tests -match "ALL TESTS PASSED")) { throw "FAIL: tests" }

$smoke = & $Godot --headless --path . --quit-after 3 2>&1
$smoke | Write-Output
if ($LASTEXITCODE -ne 0 -or ($smoke -match "SCRIPT ERROR|Parse Error")) { throw "FAIL: smoke test" }

Write-Output "PASS: parse, tests, and smoke test"
