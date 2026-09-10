# M10B1 Layout Builder

## Contract

`LayoutRecipe + GENERATOR_VERSION + String seed` produces one deterministic `GeneratedLayout` or an explicit bounded failure. `GeneratedLayout.to_level()` converts the result to the existing `LevelDefinition`/`StackDefinition` representation. Every stack stores Runes from Top to bottom, so `tile_types[0]` remains Top.

The builder handles structure only. It has no dependency on combat, enemies, Relics, validation, rewards or run flow.

## Version and seed

- Generator version: `1`.
- Seed representation: non-empty UTF-8 `String`.
- Random decisions use a private counter stream: SHA-256 of a length-prefixed generator/recipe/seed identity plus the counter. Global RNG, time and OS randomness are not used.
- A recipe version change changes both the random stream identity and final layout identity.

## Canonical hash

The SHA-256 layout hash includes, in explicit order:

1. generator version;
2. length-prefixed recipe ID;
3. recipe version;
4. length-prefixed seed;
5. stack count;
6. each stack length and every length-prefixed Rune ID from Top to bottom.

No `Dictionary` iteration or object hash participates in the canonical form.

## Recipe fields

`LayoutRecipe` contains its ID/version, stack and total Rune ranges, stack-length range, per-Rune minimum/maximum/weight, early-access constraints, and maximum same-type in-stack streak.

An early-access entry means `required_count` copies of one Rune must be placed at depths `0..max_depth`. This is a structural guarantee; it does not prove that a gameplay Triple is reachable.

## Generation

The builder validates the recipe, selects a feasible stack count and total, allocates Rune counts, allocates exact stack lengths, reserves early-access cells, then fills remaining cells from the remaining multiset. Placement is bounded to 24 deterministic attempts. It never shuffles after early-access placement.

Invalid ranges, Rune IDs, counts, early constraints, empty seeds and exhausted bounded placement return readable errors. Invalid input is not silently clamped.

## Pilot recipes

- `cave_wisp_pilot` v1: 5–6 stacks, 24–30 Runes, Fire alternative and at least three Ice at depth 0–1.
- `stone_brute_pilot` v1: 5–7 stacks, 30–38 Runes, Fire route and at least three Lightning at depth 0–1.

These recipes are construction pilots and are not approved gameplay content.

## Golden fixtures

- `cave_wisp_pilot` / `wisp-test-001`: `18186bb3ebd046884753654a74ba78e7d9e1b9d481569cc1525752b6ebc07bda`; the complete ordered structure is fixed in the targeted test.
- `cave_wisp_pilot` / `wisp-test-002`: `ab49f973d2723266119914a61e89a9d06c89555c6aa6a56d4302db6678a6a874`.
- `stone_brute_pilot` / `brute-test-001`: `befc57aba914e290ee360fc054fbffeb41a7ade62dea6b1edd24a56513d38838`.

## Deliberately absent

M10B1 does not run `CombatValidator`, score quality, generate batches, approve seeds, integrate with `RunController`, change runtime layouts, generate bosses or modify save data. Web parity uses the same canonical code and golden hashes but still needs verification in a later Web export check.
