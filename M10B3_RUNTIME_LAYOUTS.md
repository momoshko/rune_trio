# M10B3 Runtime Layouts

## Bank schema and version

`approved_layout_bank_v1.json` is immutable bank version 1 with approval ruleset version 1. Each entry stores a stable `layout_id`, enemy and recipe identity/version, generator version, approved seed, and expected canonical layout hash. It contains 10 Cave Wisp and 5 Stone Brute entries from the M10B2 APPROVED shortlist only.

## Selection

`RuntimeLayoutProvider` derives a SHA-256 value from length-prefixed `runtime_layout`, run seed, bank version, encounter slot, and enemy ID. The enemy pool is sorted by stable `layout_id`; modular byte accumulation chooses an entry without global RNG or JavaScript-unsafe large integer conversion. Reward RNG state is never read or consumed.

## RunState contract

After encounter selection, `RunState.resolved_layouts` records the slot, enemy, bank version, stable layout ID, expected hash, recipe/generator versions, and fallback status. A repeated request reconstructs that saved ID and never rerolls from the pool.

## Reconstruction and fallback

The provider performs one bounded `LayoutBuilder.build(recipe, approved_seed)`, verifies generator/recipe versions and the expected hash, then returns a normal `LevelDefinition`. Missing entries, recipes, unsupported versions, build failures, and hash mismatches log a warning and use the encounter's curated fixed level. That fallback decision is stored in RunState so reentry cannot select a replacement.

## Enabled scope

Only `cave_wisp` and `stone_brute` use the approved pilot pools. Moss Slime, all elites, chapters 2–3, and all bosses continue to use their existing fixed `EncounterDefinition.level` resources.

## M10B4

First-run/tutorial persistence, additional enemy recipes and banks, content rollout, and a canonical ruleset hash remain out of scope for this pilot. The shared deterministic builder remains at its current path for this milestone; approval/validator code is not referenced by the runtime provider.
