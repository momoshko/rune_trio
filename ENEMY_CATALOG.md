# Rune Trio — current enemy catalog

Актуально после M9C. Значения взяты из текущих `EnemyDefinition` и `m4_run.tres`. `Interval` указан в Тройках; `Shield` — стартовое значение с cap в скобках.

| ID | Stats | Mechanic | Current RU text |
|---|---|---|---|
| `moss_slime` | HP 14 · ATK 4 · Interval 3 · Armor 0 · Shield 0 | `HEAL_ON_HP_HIT` · amount 3 | **Мшистый слайм** — «Если ранит Ядро, восстанавливает 3 HP.» |
| `cave_wisp` | HP 12 · ATK 3 · Interval 1 · Armor 0 · Shield 0 | `RUNE_VULNERABILITY` · Ice +3 | **Пещерный огонёк** — «Уязвим к Льду: получает +3 урона.» |
| `stone_brute` | HP 18 · ATK 6 · Interval 3 · Armor 2 · Shield 0 | `NONE` · постоянная Броня 2 | **Каменный громила** — «Броня 2. Молния её пробивает.» |
| `stone_guard` | HP 28 · ATK 8/12 · Interval 3 · Armor 0 · Shield 0 | `attack_damage_sequence = [8, 12]` | **Каменный страж** — «Каждый второй удар — тяжёлый: 12 урона.» |
| `stone_golem` | HP 32 · ATK 8 → 10 · Interval 3 · Armor 1 → 0 при HP ≤ 16 · Shield 0 | `boss phases` · подготовленная атака сохраняется при переходе | **Каменный голем** — «В первой фазе защищён Бронёй. При половине HP теряет Броню, но начинает бить сильнее.» |
| `crystal_shell` | HP 20 · ATK 6 · Interval 3 · Armor 0 · Shield 8 (cap 8) | `SHIELD_AFTER_ATTACK` · amount 4 | **Кристальный панцирь** — «После удара восстанавливает 4 Щита.» |
| `ice_seer` | HP 22 · ATK 6 · Interval 3 · Armor 0 · Shield 0 (cap 6) | `SHIELD_ON_REPEAT` · amount 3 | **Ледяной провидец** — «Две одинаковые Тройки подряд дают ему 3 Щита.» |
| `snow_leech` | HP 22 · ATK 6 · Interval 3 · Armor 0 · Shield 0 | `HIT_UNSHIELDED` · amount 2 | **Снежный пиявец** — «Если у Ядра 0 Щита, его удар наносит +2 урона.» |
| `frost_beast` | HP 34 · ATK 7 · Interval 3 · Armor 0 · Shield 0 (cap 6) | `SHIELD_AFTER_ATTACK` · amount 6 · `shield_break_rune = ice` | **Ледяной зверь** — «После удара получает 6 Щита. Лёд полностью снимает Щит.» |
| `frost_witch` | HP 34 · Shield 4 · Armor 0 · Phase I: Arrow 6/3, Spear 10/4 · Phase II at HP ≤17: Arrow 8/2, Spear 12/3 | `boss phases + attack sequence` · sequence не сбрасывается при переходе | **Ледяная ведьма** — «Чередует быструю Стрелу и тяжёлое Копьё. При половине HP атаки усиливаются и ускоряются.» |
| `ash_knight` | HP 26 · ATK 7 (+0…4) · Interval 3 · Armor 0 · Shield 0 | `BOOST_ATTACK_ON_REPEAT` · amount 2 · cap 4 | **Пепельный рыцарь** — «Две одинаковые Тройки подряд усиливают следующий удар на 2, максимум на 4.» |
| `grave_sentinel` | HP 28 · ATK 7 · Interval 3 · Armor 2 · Shield 0 | `OPEN_ARMOR_ON_DEFENSE` | **Могильный часовой** — «После Жизни или Щита следующая атакующая Тройка пробивает Броню.» |
| `eclipse_acolyte` | HP 24 · ATK 6 · Interval 3 → 2 при HP ≤ 12 · Armor 0 · Shield 0 | `FAST_AT_HALF_HP` · threshold 12 · fast interval 2 | **Служитель затмения** — «При 12 HP или меньше атакует через 2 Тройки.» |
| `storm_revenant` | HP 32 · ATK 7 · Interval 3 · Armor 0 · Shield 0 | `EXTRA_TIMELINE_ON_REPEAT` · amount 1 | **Грозовой ревенант** — «Две одинаковые Тройки подряд приближают его атаку ещё на 1.» |

## Catalog placement

| Chapter | Normal | Elite | Boss |
|---|---|---|---|
| Stone Ruins | `moss_slime`, `cave_wisp`, `stone_brute` | `stone_guard` | `stone_golem` |
| Frozen Grove | `crystal_shell`, `ice_seer`, `snow_leech` | `frost_beast` | `frost_witch` |
| Eclipse Lands | `ash_knight`, `grave_sentinel`, `eclipse_acolyte` | `storm_revenant` | `eclipse_weaver` |

## Final boss

| ID | Stats | Mechanic | Current RU text |
|---|---|---|---|
| `eclipse_weaver` | HP 42 · Armor 0 · Shield 0 · Phase I ATK 8/3 · Phase II at HP ≤21 ATK 10/2 | Fire → Ice → Lightning vulnerability +3; periods 3 → 2 Triples | **Ткач затмения** — «Уязвимость меняется между Огнём, Льдом и Молнией. Подходящая Руна наносит +3 урона.» |

Примечание: `stone_golem` и `frost_witch` используют финальную data-driven phase architecture M9A–M9B; legacy stack lock больше не используется боссами.
