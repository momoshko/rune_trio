# ART-03C — Stone Ruins Enemy Integration Report

## 1. IMPLEMENTED

Five approved Stone Ruins enemy sprites are integrated through the existing optional `VisualLibrary` layer. Battle gameplay, enemy resources, combat values, layouts, generator, and progression data were not changed. The battle view keeps its existing fallback path when an enemy has no mapped art.

## 2. MOSS SLIME

- Source art: `moss_slime.png`.
- Visual role: smallest grounded normal enemy.
- Runtime crop: `Rect2(107, 359, 1056, 604)`.
- Battle target size: `158 × 90` px.
- Reads as a low, broad, soft green mass and remains distinct from the floating Cave Wisp.

## 3. CAVE WISP

- Existing approved mapping and source file remain unchanged.
- Battle target size: `88 × 96` px.
- Continues to provide the lightest, most airborne silhouette in the Chapter 1 family.

## 4. STONE BRUTE

- Source art: `stone_brute.png`.
- Visual role: strongest normal enemy without elite or boss signals.
- Runtime crop: `Rect2(96, 148, 1064, 998)`.
- Battle target size: `111 × 104` px.
- Broad stone armor and increased mass establish progression while the absence of bright runes and a core keeps it below Guardian and Golem.

## 5. STONE GUARDIAN

- Source art: `stone_guardian.png`, mapped to the existing enemy id `stone_guard`.
- Visual role: Chapter 1 elite.
- Runtime crop: `Rect2(150, 51, 961, 1154)`.
- Battle target size: `92 × 110` px; data-driven horizontal offset `(-82, 0)`.
- Upright sentinel silhouette, heavy stone structure, and restrained cyan markings read above the normal enemies without covering HUD information.

## 6. STONE GOLEM PHASE I

- Source art: `stone_golem_phase1.png`.
- Visual role: Chapter 1 boss, intact state.
- Runtime crop: `Rect2(22, 151, 1209, 981)`.
- Battle target size: `141 × 114` px; data-driven horizontal offset `(-110, 0)`.
- The widest silhouette, central core, and major rune structures make it the family apex while preserving the existing battle layout.

## 7. STONE GOLEM PHASE II

- Source art: `stone_golem_phase2.png`.
- Selected from the existing `BattleModel.current_phase_index`; no HP-derived UI rule was introduced.
- Uses the exact same crop, target size, offset, and `Control` geometry as Phase I.
- Brighter exposed core and energized cracks create a clear danger increase without a scale or position jump.

## 8. ENCOUNTER PORTRAITS

Encounter Choice cards now request the same mapped textures from `VisualLibrary` and keep the existing enemy-resource portrait as fallback. The current `TextureRect` aspect-fit behavior uses the same source art without separate portrait files. The rendered check shows Moss Slime and Stone Brute together in the existing cards.

## 9. FAMILY HIERARCHY

Final visible heights progress as `90 / 96 / 104 / 110 / 114` px for Slime, Wisp, Brute, Guardian, and Golem. Golem also has the largest width at 141 px. Hierarchy is carried by silhouette, mass, rune brightness, material complexity, and the boss core rather than height alone.

## 10. SCREENSHOTS

All captures were rendered from the real main scene in Godot 4.7 at 720 × 1280 using the Compatibility renderer.

- `test-results/art-03c/01-moss-slime-battle.png`
- `test-results/art-03c/02-cave-wisp-battle.png`
- `test-results/art-03c/03-stone-brute-battle.png`
- `test-results/art-03c/04-stone-guardian-elite.png`
- `test-results/art-03c/05-stone-golem-phase-1.png`
- `test-results/art-03c/06-stone-golem-phase-2.png`
- `test-results/art-03c/07-encounter-choice-slime-brute.png`
- Contact sheet: `test-results/art-03c/00-family-smoke-contact-sheet.png`

## 11. VISUAL REVIEW QUESTIONS

- **A — Slime vs Wisp:** yes; grounded, low, green and soft versus floating, angular and cyan.
- **B — Brute as normal enemy:** yes; it has more mass but no boss core, major runes, or elite glow.
- **C — Guardian above normals:** yes; the upright sentinel pose, carved cyan runes, and heavier arm establish elite status.
- **D — Golem above Guardian:** yes; it is the broadest silhouette and the only enemy with the dominant chest core.
- **E — Golem size:** the final 114 px height does not overwhelm the scene. A 140 px trial overlapped the existing name and combat stats and was rejected.
- **F — Guardian vs Golem:** distinct; Guardian is narrow and upright, Golem is broad and core-led.
- **G — Guardian runes:** readable against Stone Ruins at battle size without becoming a competing focal point.
- **H — Phase difference:** readable at runtime size through the brighter exposed core and cracks.
- **I — Phase continuity:** Phase II reads as the same character in a more dangerous state; geometry is exactly stable.
- **J — HUD competition:** final sprites leave enemy name, HP, Armor, tray, and board information readable.

## 12. FILES CHANGED

- `assets/art/enemies/stone_ruins/moss_slime.png`
- `assets/art/enemies/stone_ruins/stone_brute.png`
- `assets/art/enemies/stone_ruins/stone_guardian.png`
- `assets/art/enemies/stone_ruins/stone_golem_phase1.png`
- `assets/art/enemies/stone_ruins/stone_golem_phase2.png`
- Corresponding five Godot `.png.import` files.
- `resources/visuals/visual_library.tres`
- `scripts/ui/visual_library.gd`
- `scripts/ui/game_view.gd`
- `scripts/ui/run_offer_view.gd`
- `scenes/main/main.tscn`
- `tests/art_control_slice_tests.gd`
- `tests/art_03c_visual_tests.gd` and generated `.uid`
- `tests/art_03c_visual_smoke.gd` and generated `.uid`
- `test-results/art-03c/` screenshot outputs.

## 13. TESTS

- Godot headless import: passed; all five PNGs imported as Lossless, mipmaps off, Fix Alpha Border on, premultiplied alpha off.
- `tests/art_03c_visual_tests.gd`: **28 passed, 0 failed**.
- `tests/art_03c_visual_smoke.gd`: **17 passed, 0 failed**, seven real viewport captures.
- `tests/art_control_slice_tests.gd`: **21 passed, 0 failed**.
- `tests/m9a_stone_golem_tests.gd`: **5 scenarios passed**; boss phase and combat values remain unchanged.
- `tests/elite_enemy_tests.gd`: **6 scenarios passed**; Guardian mechanics remain unchanged.
- Headless project startup: exit code 0.
- `git diff --check`: passed; only existing line-ending warnings were printed.

## 14. LIMITATIONS

- The attachment's suggested Guardian/Golem heights of approximately 115–125 and 135–145 px do not fit the actual 180 px battle space without colliding with enemy name, HP, or Armor. The final 110/114 px heights follow the task requirement that the live layout is the source of truth.
- Phase art swaps immediately when the existing phase state changes; no new transition animation was added.
- The rendered visual review covers the 720 × 1280 portrait viewport. Existing compact scaling remains data-driven but was not captured as a separate screenshot set.
- Godot startup still prints the pre-existing shutdown warning about two leaked `ObjectDB` instances and one resource in use; startup succeeds and ART-03C tests pass.
- Full validation, solver, generator, autonomous gameplay testing, and unrelated milestone pipelines were intentionally not run for this visual-only stage.

## 15. NEXT: USER VISUAL REVIEW

Review the contact sheet and individual screenshots inside the live UI. The next decision is whether the final relative scale, Guardian rune intensity, and Phase I/II contrast are approved. No Chapter 2 or M10B4 work has been started.
