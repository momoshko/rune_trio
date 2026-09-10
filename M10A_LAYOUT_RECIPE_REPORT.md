# Executive Summary

M10A validated the 15 current runtime enemy/layout pairs through the existing `CombatValidator`, with full Core HP 40, zero Shield, no Relics, all Rune/enemy mechanics and boss phases enabled. This is a bounded design experiment, not a balance certification: 11 pairs were `SOLVABLE`, 4 were `UNKNOWN` because the two-second budget expired, and none were proven `UNSOLVABLE`. Every reported solution was replayed through the real `GameController`/`BattleModel` path.

The strongest finding is that solvability alone is insufficient as a generation rule. Most successful witnesses reached pre-removal Row occupancy 7, several old layouts hide a key Rune at depth 4, and two mechanical pairs reuse exactly the same layout. Future candidates need structural gates, bounded combat validation, mechanic-opportunity checks, and playtest calibration.

# Validator Configuration

- Baseline: Core HP 40, Core Shield 0, empty Rune Row, no Relics.
- Combat: current Rune effects, enemy reactions, Armor, Shield and data-driven boss phases.
- Search: deterministic DFS, `max_states = 2000`, `time_budget_ms = 2000` per pair; no automatic budget increase.
- Verdicts: `SOLVABLE`, `UNSOLVABLE`, `UNKNOWN`.
- Reuse: `RunLayoutValidation.validate_pair(enemy, level, balance, limits)` accepts arbitrary definitions and is not tied to levels 1–20.
- Witness rule: a found victory is accepted only after a fresh replay through the actual combat models. A mismatch becomes `UNKNOWN`/invalid witness.
- Metrics: layout structure plus Triple count, selected Rune count, ending HP/Shield, maximum pre-removal Row occupancy, remaining Runes, attacks executed and Frozen skips.

# Current Runtime Pair Results

The source of truth was `m4_run.tres`. `level_1` below is the ID stored by `level_1_mixed.tres`.

| Enemy | Runtime layout | Verdict | States | Triples / picks | End HP / Shield | Max Row | Left | Attacks / Frozen |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| Moss Slime | level_1 | SOLVABLE | 14 | 4 / 12 | 40 / 0 | 7 | 12 | 0 / 0 |
| Cave Wisp | level_2 | SOLVABLE | 10 | 2 / 9 | 37 / 0 | 6 | 21 | 1 / 0 |
| Stone Brute | level_3 | SOLVABLE | 86 | 11 / 35 | 40 / 10 | 7 | 1 | 1 / 1 |
| Stone Guardian | level_5 | SOLVABLE | 56 | 9 / 29 | 36 / 0 | 7 | 19 | 2 / 0 |
| Stone Golem | level_10 | UNKNOWN | 90 | — | — | — | — | — |
| Crystal Shell | level_11 | SOLVABLE | 87 | 10 / 34 | 40 / 10 | 7 | 14 | 1 / 1 |
| Ice Seer | level_16 | SOLVABLE | 72 | 10 / 34 | 40 / 10 | 7 | 14 | 1 / 1 |
| Snow Leech | level_12 | UNKNOWN | 72 | — | — | — | — | — |
| Ice Beast | level_15 | UNKNOWN | 81 | — | — | — | — | — |
| Ice Witch | level_20 | UNKNOWN | 81 | — | — | — | — | — |
| Ash Knight | level_17 | SOLVABLE | 60 | 9 / 31 | 34 / 8 | 7 | 17 | 2 / 0 |
| Grave Sentinel | level_19 | SOLVABLE | 68 | 12 / 40 | 40 / 9 | 7 | 8 | 1 / 2 |
| Eclipse Acolyte | level_18 | SOLVABLE | 49 | 7 / 25 | 40 / 0 | 7 | 23 | 0 / 2 |
| Storm Revenant | level_5 | SOLVABLE | 76 | 12 / 40 | 35 / 0 | 7 | 8 | 3 / 0 |
| Eclipse Weaver | level_20 | SOLVABLE | 74 | 12 / 40 | 38 / 0 | 7 | 8 | 2 / 1 |

`UNKNOWN` means only that no conclusion was reached within the fixed budget. It must not be treated as failure or success.

# Layout Structural Metrics

Depth uses `0 = Top`; `—` means the Rune is absent. Distribution order is Fire / Ice / Lightning / Wind / Life / Shield. `Triples` is the theoretical count `floor(type count / 3)`, not a guarantee that those Triples are reachable.

| Layout | Stacks | Runes | Distribution | Theoretical Triples | First depths F/I/L/W/Life/S | Initial tops | Longest in-stack repeat |
|---|---:|---:|---|---|---|---|---:|
| level_1_mixed | 5 | 24 | 6/6/6/6/0/0 | 2/2/2/2/0/0 | 0/0/1/1/—/— | F,F,F,I,I | 1 |
| level_2 | 6 | 30 | 6/6/6/6/0/6 | 2/2/2/2/0/2 | 0/0/0/1/—/1 | F,I,L,F,I,L | 2 |
| level_3 | 8 | 36 | 6/6/6/6/6/6 | 2 each | 0/0/0/1/1/1 | F,I,L,F,I,L,F,I | 1 |
| level_5 | 6 | 48 | 9/9/9/6/6/9 | 3/3/3/2/2/3 | 0/2/0/0/0/1 | Life,W,L,Life,F,L | 1 |
| level_10 | 6 | 48 | 9/9/6/6/9/9 | 3/3/2/2/3/3 | 0/1/0/0/0/1 | Life,F,L,Life,W,F | 1 |
| level_11 | 8 | 48 | 9/9/9/6/6/9 | 3/3/3/2/2/3 | 0/0/1/0/0/0 | Life,W,I,S,F,W,I,Life | 1 |
| level_12 | 6 | 48 | 9/9/9/9/6/6 | 3/3/3/3/2/2 | 0/1/0/1/0/0 | Life,F,S,L,F,L | 1 |
| level_15 | 5 | 48 | 9/6/6/9/9/9 | 3/2/2/3/3/3 | 0/4/0/0/1/1 | L,L,W,W,F | 1 |
| level_16 | 6 | 48 | 9/9/6/6/9/9 | 3/3/2/2/3/3 | 0/1/0/0/0/1 | Life,F,L,Life,W,F | 1 |
| level_17 | 6 | 48 | 9/9/9/6/6/9 | 3/3/3/2/2/3 | 1/0/1/0/0/0 | I,W,S,Life,I,S | 1 |
| level_18 | 5 | 48 | 15/9/9/9/3/3 | 5/3/3/3/1/1 | 0/1/1/0/4/0 | F,W,S,S,F | 2 |
| level_19 | 6 | 48 | 6/9/9/9/9/6 | 2/3/3/3/3/2 | 0/0/1/0/1/0 | I,F,W,I,W,S | 1 |
| level_20 | 5 | 48 | 6/6/9/9/9/9 | 2/2/3/3/3/3 | 4/0/0/1/1/0 | I,I,L,L,S | 1 |

The witnesses often reach Row 7 immediately before automatic Triple removal. This is legal, but it means these layouts are poor evidence for a comfortable Row-pressure target. The current solver finds a winning route, not a representative or human-readable route.

# Chapter 1 Analysis

- **Moss Slime:** level_1_mixed is short, readable and opens Fire/Ice immediately. It supports a clean pre-attack kill and is the strongest tutorial reference, although it cannot teach Life or Shield.
- **Cave Wisp:** level_2 exposes Ice and Fire at Top and remains solvable without requiring a Frozen skip. That preserves Fire as an alternative, but the very fast two-Triple witness makes the vulnerability lesson easy to miss.
- **Stone Brute:** level_3 exposes Lightning at Top and all defensive/control types at depth 1. It is solvable, but the witness consumes 35 of 36 Runes and reaches Row 7, so the layout is too close to exhaustion to be considered a proven good reference.
- **Stone Guardian:** level_5 allows two attacks, so the heavy second hit actually appears. Ice begins at depth 2 while Wind/Life/Lightning are immediately accessible. It is useful mechanical training data despite high Row pressure.
- **Stone Golem:** level_10 returned `UNKNOWN`. Its balanced 48-Rune structure is plausible, but M10A cannot prove that both phases receive several meaningful player actions.

# Chapter 2 Analysis

- **Crystal Shell:** level_11 has Lightning only at depth 1 and multiple ordinary routes. The witness sees an attack and a Frozen skip; Shield restoration can occur, making it a useful reference pending playtest.
- **Ice Seer:** level_16 offers varied tops and no in-stack repeats, so it does not force repeat play. Its structure is identical to level_10's counts/depth profile, but the mechanical response differs.
- **Snow Leech:** level_12 exposes Shield at Top and has only two theoretical Shield Triples. It returned `UNKNOWN`; the obvious initial Shield may weaken the intended timing decision.
- **Ice Beast:** level_15 hides the first Ice at depth 4 in every useful route represented by this metric, while the mechanic specifically needs repeated Ice windows. It returned `UNKNOWN` and is a bad reference for this lesson.
- **Ice Witch:** level_20 offers Ice and Shield immediately, Wind at depth 1, and burst Lightning at Top, but Fire is depth 4. The pair returned `UNKNOWN`; Arrow/Spear preparation quality remains unproven.

# Chapter 3 Analysis

- **Ash Knight:** varied defensive/control tops create later attack choices and the witness survives two attacks. The layout tempts choices without long forced repeats; it is a promising generator reference.
- **Grave Sentinel:** level_19 exposes Shield at Top and Life at depth 1, with Lightning at depth 1. The witness begins with a non-attacking Triple and demonstrates defensive preparation; it is mechanically aligned, though long and Row-tight.
- **Eclipse Acolyte:** the Fire-heavy layout wins with zero executed attacks and 23 Runes left. The accelerated half-HP phase therefore has little evidence of mattering. This is a bad lesson reference even though it is solvable.
- **Storm Revenant:** reusing level_5 produces a valid long fight with three attacks, but it was authored around Guardian's heavy second strike, not repeat temptation. It needs a future split.
- **Eclipse Weaver:** level_20 is solvable and long enough to execute two attacks, but its initial Fire vulnerability is hidden at depth 4 while Ice/Lightning are Top. This biases the opening cycle and shares the Witch layout; it needs a future split.

# Enemy Recipe Drafts

These ranges are hypotheses for M10B candidate generation, not final balance values.

## Moss Slime Recipe Draft

- Purpose: teach prevention of HP damage. Key: early Fire, or Ice/Wind/Shield. Helpful: Life.
- Target: 4–5 stacks, 21–27 Runes, difficulty 1/10.
- Required: one legible pre-attack kill, freeze, delay or shield route within the first few reveals.
- Avoid: all prevention tools buried; early Row traps; a single opaque sequence.

## Cave Wisp Recipe Draft

- Purpose: demonstrate Ice damage bonus and Frozen. Key: Ice; helpful: Fire, Wind.
- Target: 5–6 stacks, 24–32 Runes, difficulty 2/10.
- Required: at least two theoretical Ice Triples, first Ice depth 0–1, and a viable non-Ice attack route.
- Avoid: Ice-only victory or a trivial kill that never exposes the lesson.

## Stone Brute Recipe Draft

- Purpose: teach Armor and Lightning bypass. Key: Lightning; helpful: Fire, Ice, Shield.
- Target: 6–8 stacks, 30–38 Runes, difficulty 4/10.
- Required: at least two Lightning Triples, first Lightning depth 0–1, slower ordinary-damage route.
- Avoid: Lightning only at the bottom, unavoidable Row 6–7 pressure throughout, one forced route.

## Stone Guardian Recipe Draft

- Purpose: prepare for the 12-damage second attack. Key: Ice, Wind, Shield; helpful: burst and Life.
- Target: 6–7 stacks, 36–48 Runes, difficulty 4/10.
- Required: the enemy survives long enough for the heavy hit to be relevant; at least two different survival/race opportunities.
- Avoid: automatic kill before the mechanic or defense buried after the second attack window.

## Stone Golem Recipe Draft

- Purpose: sustain decisions across two phases. Key: mixed attack/control; helpful: Shield/Life.
- Target: 6–8 stacks, 42–52 Runes, difficulty 5/10.
- Required: Phase II begins with enough enemy HP and board options for several actions; Lightning and Fire both practical.
- Avoid: Phase II as only a final hit, all control front-loaded, late Row collapse.

## Crystal Shell Recipe Draft

- Purpose: manage regenerating enemy Shield. Key: Lightning; helpful: Ice and ordinary burst.
- Target: 6–8 stacks, 36–48 Runes, difficulty 3/10.
- Required: two or more Lightning opportunities across the fight and a viable ordinary route.
- Avoid: all Lightning at Top or all Lightning buried; victory before Shield restoration can matter.

## Ice Seer Recipe Draft

- Purpose: choose between repeating and alternating types. Key: multiple attack types; helpful: Ice/Wind.
- Target: 6–7 stacks, 38–48 Runes, difficulty 4/10.
- Required: adjacent opportunities for both a repeat and an alternative type.
- Avoid: layouts that mechanically force one type repeatedly or never tempt a repeat.

## Snow Leech Recipe Draft

- Purpose: time Core Shield before an unshielded hit. Key: Shield; helpful: Ice/Wind/Life.
- Target: 6–7 stacks, 38–48 Runes, difficulty 6/10.
- Required: a Shield Triple reachable before a dangerous attack, but not guaranteed directly from three obvious Top Runes.
- Avoid: Shield entirely buried or permanently trivial at the surface.

## Ice Beast Recipe Draft

- Purpose: use Ice against regenerated Shield while retaining other routes. Key: Ice; helpful: Lightning/burst.
- Target: 6–8 stacks, 42–52 Runes, difficulty 6/10.
- Required: several Ice windows distributed across fight depth; at least one viable non-Ice response.
- Avoid: first Ice near depth 4 in every stack, all Ice in one layer, “always take Ice” sequencing.

## Ice Witch Recipe Draft

- Purpose: prepare differently for Arrow and Spear. Key: Ice, Wind, Shield; helpful: Life and burst.
- Target: 6–8 stacks, 44–54 Runes, difficulty 7/10.
- Required: multiple preparation methods in both phases and enough fight length for Arrow/Spear alternation.
- Avoid: control exhausted before Phase II, deterministic single counter sequence, phase transition at the final hit.

## Ash Knight Recipe Draft

- Purpose: make repeated types tempting but risky. Key: varied attack types; helpful: Ice/Shield.
- Target: 6–7 stacks, 40–50 Runes, difficulty 5/10.
- Required: some repeat opportunities plus accessible alternatives before attacks.
- Avoid: forced repeat chains or perfectly alternating surface layers with no temptation.

## Grave Sentinel Recipe Draft

- Purpose: defense into offense. Key: Life/Shield followed by ordinary attack; helpful: Lightning bypass.
- Target: 6–7 stacks, 42–50 Runes, difficulty 6/10.
- Required: at least two defense-to-attack opportunities and a practical Lightning alternative.
- Avoid: defense isolated after all ordinary attacks, or Lightning so abundant that Armor opening is irrelevant.

## Eclipse Acolyte Recipe Draft

- Purpose: burst planning around the 12-HP acceleration threshold. Key: timed attack burst; helpful: control/Shield.
- Target: 6–8 stacks, 42–52 Runes, difficulty 7/10.
- Required: at least one full accelerated attack window after threshold and options to race or defend.
- Avoid: Fire-heavy early kill with zero attacks, crossing threshold only on the finishing hit.

## Storm Revenant Recipe Draft

- Purpose: make repeated types speed the timeline. Key: varied types and repeat temptations; helpful: Ice/Wind.
- Target: 6–8 stacks, 44–54 Runes, difficulty 7/10.
- Required: meaningful repeated-type choices and alternate routes at several depths.
- Avoid: reusing Guardian's layout, forced repeats, or zero repeat opportunities.

## Eclipse Weaver Recipe Draft

- Purpose: react to rotating Fire → Ice → Lightning vulnerability without forcing it.
- Target: 6–8 stacks, 48–56 Runes, difficulty 8/10.
- Required: initial Fire usable at approximate depth 0–2; later Ice/Lightning windows; viable routes that ignore the bonus; several Phase II actions.
- Avoid: Fire hidden at depth 4, forced F→I→L ordering, or reuse of Witch's preparation layout.

# Global Generator Constraint Draft

- Prefer 5–8 stacks and roughly 24–56 Runes, narrowed per enemy recipe.
- Require at least three copies of every mechanically required Rune; most key Runes should have 6+ copies when several windows are intended.
- Bound first key-Rune depth, normally 0–2; depth 3–4 needs explicit encounter justification.
- Reject long same-Rune runs inside a stack; provisional maximum is 2.
- Require at least two plausible attack routes, not merely one solver witness.
- Reject candidates with obvious early dead patterns or unavoidable Row overflow under all bounded routes.
- Treat repeated witness occupancy 7 as a risk flag; seek at least one verified route whose maximum is 5–6 for early encounters and no more than 6 for most later encounters.
- Validate baseline solvability, witness replay, mechanic opportunity, ending HP and remaining-board margins separately.
- Flag low-HP victories (draft: ending HP ≤10) and heavy unavoidable damage for carry-over review.
- Keep generation deterministic and offline/authoring-time; runtime consumes only approved identifiers/seeds.

# Fixed First-Run Candidates

- Keep Moss Slime on level_1_mixed fixed for the first tutorial fight.
- Keep Cave Wisp curated early, but playtest whether its Ice lesson is visible before committing level_2 unchanged.
- Keep the first Stone Brute encounter curated while replacing its near-exhaustion route with a future validated revision.
- Bosses should remain curated until phase-participation metrics exist; do not expose first-run players to unproven generated Golem/Witch/Weaver layouts.
- Variety can begin with later normal encounters, then elites, after their recipes have approved seed pools.

# Generator Reference Layouts

- **Good references:** level_1_mixed for readable short openings; level_17 for varied choice surfaces; level_19 for defense-to-offense sequencing.
- **Promising but needs playtest:** level_2, level_5 with Stone Guardian, level_11, level_16.
- These are references for properties, not templates to clone wholesale.

# Bad / Legacy Layouts

- level_15 is a bad Ice Beast reference because Ice first appears at depth 4.
- level_18 is a bad Eclipse Acolyte lesson reference because the bounded witness wins before any attack executes.
- level_3 is solvable but its witness consumes 35/36 Runes and reaches Row 7; it is not yet a good difficulty reference.
- level_20 is a poor Weaver reference because Fire begins at depth 4 and the layout was shared with a different boss lesson.
- All 48-Rune layouts whose only found witness reaches Row 7 remain `NEEDS PLAYTEST`, even when `SOLVABLE`.

# Duplicate Layout Problems

- **Stone Guardian vs Storm Revenant:** both use level_5. Guardian needs preparation for a scheduled heavy second hit; Revenant needs repeated-type temptation. Create separate candidates in M10B/M10C and validate different mechanic-opportunity criteria.
- **Ice Witch vs Eclipse Weaver:** both use level_20. Witch needs Arrow/Spear preparation tools; Weaver needs timely rotating vulnerabilities beginning with Fire. They must be split; no replacement is created in M10A.

# Low-HP Risks

No verified witness ended at or below the draft low-HP threshold of 10. The lowest verified results were Ash Knight 34, Storm Revenant 35, Stone Guardian 36 and Cave Wisp 37. This does not prove low carry-over risk: the solver optimizes for finding any victory, starts every isolated pair at 40 HP, and does not characterize unavoidable damage. Stone Golem, Snow Leech, Ice Beast and Ice Witch remain unknown and therefore unclassified for low-HP risk.

# Future Generation Model Comparison

| Model | Runtime cost | Reproducibility/debugging | Storage | Fairness/variety | Yandex Games fit |
|---|---|---|---|---|---|
| A. Runtime shuffle + validator | High and unpredictable | Seed helps, but device/time budgets change outcomes | Low | Broad variety, weakest guarantees | Poor |
| B. Offline generator → approved full layouts | None beyond loading | Excellent | Highest | Strong fairness, finite variety | Strong |
| C. Deterministic recipe + approved seeds | None if seeds are approved offline | Excellent with recipe version + seed | Low | Strong variety per stored seed pool | Strongest balance |

The present architecture favors **C with a B-style approval artifact**: generate offline from a versioned deterministic recipe, validate and replay offline, then ship either compact approved seeds plus recipe version or materialized layouts where exact stability is more valuable.

# Recommended M10B Architecture Questions

1. What deterministic recipe version and RNG contract makes a seed stable across Godot/platform updates?
2. Should approved output store seeds only, full stack arrays, or both for auditability?
3. Which mechanic-opportunity predicates can be checked structurally before expensive validation?
4. Should candidate approval require one low-Row witness, several distinct winning routes, or both?
5. How will phase participation be measured for Golem, Witch, Acolyte and Weaver?
6. What ending-HP margin is acceptable for each slot when real run carry-over is considered?
7. How large should each enemy's approved seed pool be before runtime variety is enabled?
8. Which first-run encounters remain pinned to curated materialized layouts regardless of seed?
