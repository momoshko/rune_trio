# RUNE TRIO

Godot 4.7 / GDScript Prototype v0.7 Visual Alpha. The campaign contains twenty fixed levels across Stone Ruins and Frozen Grove, milestone enemies at 5/10/15/20, collectible relics and local unlock progress. Development-only solver, analyzer and controlled generator validate layouts. The approved puzzle core remains unchanged: visible mixed stacks, Top-only selection, seven-slot Tray and automatic Triple combat. In stack data, `tile_types[0]` is always the Top tile.

## Structure

- `scripts/board`: `BoardModel`, `TileDefinition`, ordered stack definitions and level data.
- `scripts/tray`: deterministic grouping and triple resolution.
- `scripts/core`: `GameController` and small balance data.
- `scripts/battle`: data-driven enemy definitions plus one-active-enemy combat state, Triple effects, Core HP and Shield.
- `scripts/ui`: rendering, pointer input and lightweight animation only.
- `resources`: replaceable tile visuals, balance, enemies, relics and twenty deterministic levels.
- `scripts/dev` and `tools`: headless puzzle solver, difficulty metrics and candidate generation; never runtime shuffle.
- `tests`: headless critical-logic tests.

Keep gameplay logic separate from visuals; do not hardcode balance in UI. Placeholder textures/colors must remain replaceable through Resources. Before work, read this file and only directly related files. Avoid unrelated refactoring; record out-of-scope ideas in `TODO.md`.

Run: `C:\godot\Godot_v4.7-stable_win64_console.exe --path . --editor`

Validate: `powershell -ExecutionPolicy Bypass -File tools/check_project.ps1`

## Execution policy

Work on one explicit stage only; use targeted tests by default. Do not perform autonomous gameplay testing or unrelated refactors. Run solver/generator only when explicitly requested, and full validation only at a milestone. Report the requested result and stop.
