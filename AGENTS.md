# RUNE TRIO

Godot 4.7 / GDScript Prototype v0.1. Core loop: select an uncovered tile, move it into the seven-slot Tray, remove triples, then win on a cleared board or lose on a resolved full Tray.

## Structure

- `scripts/board`: `BoardModel`, `TileDefinition`, placements and level data.
- `scripts/tray`: deterministic grouping and triple resolution.
- `scripts/core`: `GameController` and small balance data.
- `scripts/ui`: rendering, pointer input and lightweight animation only.
- `resources`: replaceable tile visuals, balance and hand-authored levels.
- `tests`: headless critical-logic tests.

Keep gameplay logic separate from visuals; do not hardcode balance in UI. Placeholder textures/colors must remain replaceable through Resources. Before work, read this file and only directly related files. Avoid unrelated refactoring; record out-of-scope ideas in `TODO.md`.

Run: `C:\godot\Godot_v4.7-stable_win64_console.exe --path . --editor`

Validate: `powershell -ExecutionPolicy Bypass -File tools/check_project.ps1`
