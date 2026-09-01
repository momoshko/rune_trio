$ErrorActionPreference = "Continue"
$Godot = "C:\godot\Godot_v4.7-stable_win64_console.exe"
if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot 4.7 console executable not found: $Godot" }

$parse = & $Godot --headless --path . --editor --quit-after 3 2>&1
$parse | Write-Output
if ($LASTEXITCODE -ne 0 -or ($parse -match "SCRIPT ERROR|Parse Error")) { throw "FAIL: project parse/import" }

$tests = & $Godot --headless --path . --script res://tests/run_tests_v02.gd 2>&1
$tests | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($tests -match "ALL TESTS PASSED")) { throw "FAIL: tests" }

$layout = & $Godot --headless --path . --script res://tests/layout_tests.gd 2>&1
$layout | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($layout -match "ALL LAYOUT TESTS PASSED")) { throw "FAIL: layout tests" }

$battle = & $Godot --headless --path . --script res://tests/battle_tests.gd 2>&1
$battle | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($battle -match "ALL BATTLE TESTS PASSED")) { throw "FAIL: battle tests" }

$encounter = & $Godot --headless --path . --script res://tests/encounter_tests.gd 2>&1
$encounter | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($encounter -match "ALL ENCOUNTER TESTS PASSED")) { throw "FAIL: encounter tests" }

$chapter = & $Godot --headless --path . --script res://tests/chapter_tests.gd 2>&1
$chapter | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($chapter -match "ALL CHAPTER TESTS PASSED")) { throw "FAIL: chapter tests" }

$boss = & $Godot --headless --path . --script res://tests/boss_tests.gd 2>&1
$boss | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($boss -match "ALL BOSS TESTS PASSED")) { throw "FAIL: boss tests" }

$menuPause = & $Godot --headless --path . --script res://tests/menu_pause_tests.gd 2>&1
$menuPause | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($menuPause -match "ALL MENU PAUSE TESTS PASSED")) { throw "FAIL: menu/pause tests" }

$solverGenerator = & $Godot --headless --path . --script res://tests/solver_generator_tests.gd 2>&1
$solverGenerator | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($solverGenerator -match "ALL SOLVER GENERATOR TESTS PASSED")) { throw "FAIL: solver/generator tests" }

$campaign = & $Godot --headless --path . --script res://tests/campaign_tests.gd 2>&1
$campaign | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($campaign -match "ALL CAMPAIGN TESTS PASSED")) { throw "FAIL: campaign tests" }

$campaignBoss = & $Godot --headless --path . --script res://tests/campaign_boss_tests.gd 2>&1
$campaignBoss | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($campaignBoss -match "ALL CAMPAIGN BOSS TESTS PASSED")) { throw "FAIL: campaign boss tests" }

$save = & $Godot --headless --path . --script res://tests/save_tests.gd 2>&1
$save | Write-Output
if ($LASTEXITCODE -ne 0 -or -not ($save -match "ALL SAVE TESTS PASSED")) { throw "FAIL: save tests" }

$smoke = & $Godot --headless --path . --quit-after 3 2>&1
$smoke | Write-Output
if ($LASTEXITCODE -ne 0 -or ($smoke -match "SCRIPT ERROR|Parse Error")) { throw "FAIL: smoke test" }

Write-Output "PASS: parse, tests, and smoke test"
