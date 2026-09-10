# Executive Summary

One deterministic offline pilot batch processed 12 Cave Wisp and 12 Stone Brute candidates. This artifact is not a runtime bank.

Yield was 1 APPROVED per 1.2 generated Wisp candidates, 1 per 2.4 Brute candidates, and 1 per 1.6 candidates overall. The most frequent hold reason was `HIGH_ROW_PRESSURE` (6). Wisp's recipe looks normal at this scale; Brute's looks broad/noisy rather than structurally narrow.

# Approval Policy

Construction remains in LayoutRecipe/LayoutBuilder. Approval uses independent hard gates plus advisory flags; there is no aggregate difficulty score.

# Validator Budgets

Fast: 2000 states / 2000 ms. Slow: 10000 states / 10000 ms, one retry, at most 10 candidates per enemy. Alternative routes: at most two searches, each 2000 states / 2000 ms.

# Cave Wisp Batch

Generated 12; build rejected 0; structural rejected 0; fast solvable/unknown/unsolvable 12/0/0; slow queue 0; replay failures 0; approved/review/rejected 10/2/0; exact/near duplicates 0/0.

# Stone Brute Batch

Generated 12; build rejected 0; structural rejected 0; fast solvable/unknown/unsolvable 11/1/0; slow queue 1; replay failures 0; approved/review/rejected 5/7/0; exact/near duplicates 0/0.

# Structural Rejections

All generated candidates were checked for identity/version, canonical hash, deterministic rebuild, Rune IDs, stack/total/count bounds, streaks, early access, and pilot enemy stock constraints. Rejections: Wisp 0, Brute 0.

# Solvability Results

Wisp fast S/U/X: 12/0/0. Brute fast S/U/X: 11/1/0. Solver state count is tooling diagnostics, not human difficulty.

# Witness Quality

Solvable candidates require exact BattleModel witness replay. Quality is expressed as independent consumption, HP, row-pressure, mechanic, and route-diversity flags. Solved-but-filtered candidates: 9.

All 24 candidates were solver victories after the one bounded slow retry. Quality filtering correctly withheld 9 from APPROVED (sent to REVIEW rather than falsely rejected): six for row pressure and one each for high consumption, missing mechanic participation, and unverified route diversity.

# Route Diversity

Confirmed for 23/24 solved candidates (95.8%). Budget exhaustion is reported only as ROUTE_DIVERSITY_UNVERIFIED, never as a forced-solution claim.

# Row Pressure Findings

23/24 replayed wins reached transient pre-clear occupancy 7; 23 ended at occupancy 6 at least once. The new post-clear metrics separate normal Triple-clearing transients from sustained danger.

The old M10A “almost every route reaches 7” alarm was therefore mostly a normal transient signal, but not entirely harmless: six candidates crossed the configured sustained post-action pressure threshold and were held for REVIEW.

# Mechanic Participation

Cave Wisp special Ice interaction confirmed in 11 candidates. Stone Brute Lightning counter access confirmed in 12 candidates. Early key-Rune guarantees provided the intended access structurally; confirmation still depends on a winning route.

This 23/24 mechanic-confirmation result is evidence that the early key-Rune guarantees help route availability, though it does not by itself prove human-perceived quality.

# Low-HP Probe

Advisory Core HP 24 results: {"LOW_HP_SOLVABLE":23,"LOW_HP_UNKNOWN":1}. No candidate is required to win this probe.

# Duplicate / Diversity Filtering

Mechanical exact fingerprints rejected 0 column-permutation duplicates; opening fingerprints flagged 0 near duplicates deterministically.

# Approved Wisp Seeds

`m10b2:cave_wisp-001`, `m10b2:cave_wisp-002`, `m10b2:cave_wisp-004`, `m10b2:cave_wisp-006`, `m10b2:cave_wisp-007`, `m10b2:cave_wisp-008`, `m10b2:cave_wisp-009`, `m10b2:cave_wisp-010`, `m10b2:cave_wisp-011`, `m10b2:cave_wisp-012`

# Approved Brute Seeds

`m10b2:stone_brute-004`, `m10b2:stone_brute-005`, `m10b2:stone_brute-006`, `m10b2:stone_brute-007`, `m10b2:stone_brute-010`

# Review Candidates

Wisp: `m10b2:cave_wisp-003`, `m10b2:cave_wisp-005`

Brute: `m10b2:stone_brute-001`, `m10b2:stone_brute-002`, `m10b2:stone_brute-003`, `m10b2:stone_brute-008`, `m10b2:stone_brute-009`, `m10b2:stone_brute-011`, `m10b2:stone_brute-012`

# Main Rejection Reasons

HIGH_CONSUMPTION=1, HIGH_ROW_PRESSURE=6, MECHANIC_NOT_SEEN=1, ROUTE_DIVERSITY_UNVERIFIED=1

# Recipe Problems Found

Wisp yield is normal for this pilot; Brute yield is broad/noisy. A recipe is treated as too narrow only when structural/build rejection dominates, and too broad when many structurally valid candidates fail combat or quality; this small pilot does not auto-tune either recipe.

# Recommendations for M10B3

Do not integrate REVIEW/UNKNOWN candidates. Preserve recipe and generator versions in any future bank. Review the pilot yield and mechanic/diversity flags before deciding whether recipe tuning is warranted.
