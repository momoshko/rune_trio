# ART-02C — Godot Rune Set + Core Integration

Статус: IMPLEMENTED — готово к пользовательскому visual review.
Дата: 2026-09-10. Проект: C:/dev/rune_trio. Godot 4.7 stable, Compatibility renderer.

## 1. IMPLEMENTED

В существующий ART-01C visual layer подключены пять новых painted Rune и production Core.
Fire, Stone Ruins background и Cave Wisp сохранены. Изменения ограничены копиями PNG,
существующим VisualLibrary, локальной отрисовкой Core и visual integration tests.

Gameplay, Rune/Enemy mechanics, combat logic, balance, relics, layouts, approved layout bank,
generator и run flow не менялись. UI architecture не переделывалась.

## 2. RUNE SET

Все шесть типов теперь возвращают production painted tile через один существующий mapping:

| Rune | res:// path | Atlas region |
|---|---|---|
| Fire | assets/art/runes/fire.png | Rect2(80, 86, 1096, 1096) |
| Ice | assets/art/runes/ice.png | Rect2(80, 86, 1096, 1096) |
| Lightning | assets/art/runes/lightning.png | Rect2(80, 86, 1096, 1096) |
| Wind | assets/art/runes/wind.png | Rect2(80, 86, 1096, 1096) |
| Life | assets/art/runes/life.png | Rect2(80, 86, 1096, 1096) |
| Shield | assets/art/runes/shield.png | Rect2(80, 86, 1096, 1096) |

Общий crop сохраняет одинаковые экранный размер, padding и положение символов.
Painted rim заменяет старые body fill/border для всех mapped Rune. Hover/glow, disabled dim,
lock overlay, selection и Rune Row slots остаются отдельными feedback layers.

Fire не заменялась: SHA-256 проекта и approved master совпадает:
79E0B74A30760B892E34C2D899AF138AFA51CC311C8F5161780B679608128081.

## 3. CORE

Core подключён как assets/art/core/core.png через optional res:// path.
Atlas region Rect2(124, 128, 1007, 1007) убирает прозрачный canvas без изменения master PNG.

Production Core равномерно вписывается в квадрат 88 × 88 px со сдвигом на 4 px вверх.
Оценочная видимая высота по alpha — 85.73 px на viewport 720 × 1280. Старые программные
круги рисуются только как fallback при отсутствии texture. Дополнительная круглая заливка
за production sprite отсутствует.

Core HP/Shield text, HP bar, shield indicator, combat feedback и pulse сохранены.
Новые damaged/shielded variants и animations не добавлялись.

## 4. VISUAL LIBRARY

Существующий rune_tile_paths расширен до шести типов. Добавлен один optional core_path и
core_visual_texture(), который сначала загружает production Core через общий lazy loader/cache,
а при отсутствии пути сохраняет прежний core_texture fallback.

Отсутствующий или ошибочный Rune/Core path возвращает null и не ломает сцену.
Абсолютных Windows paths в runtime нет.

## 5. STACK RESULT

Gameplay hitbox не изменён: 94.04445 × 110.4 px. Квадратный painted tile внутри stack:
94.04445 × 94.04445 px. Top-only selection, offsets, overlap и disabled state используют
прежнюю геометрию.

Approved cave_wisp_v1_001 одновременно показывает все шесть типов. В первом кадре Wind,
Life, Ice и Lightning находятся сверху, Fire и Shield читаются по открытым нижним слоям.
Тёплые типы и Shield распознаются уверенно; различение Ice/Wind в самых узких полосах
сильнее зависит от оттенка, чем от формы символа.

## 6. RUNE ROW RESULT

Размер painted tile в Rune Row остаётся 68.08 × 68.08 px. Все шесть texture используют
один fit и не растягиваются. Во втором кадре обычными pointer events собран ряд из Wind,
Life, Fire и Ice. Символы читаются, slot geometry и общий размер Rune Row не менялись.

Существующие шесть буквенных Rune info buttons остаются видимыми, имеют tooltip и открывают
описание Rune. Их визуальный redesign не выполнялся.

## 7. FULL BATTLE SCREEN

На реальном 720 × 1280 кадре одновременно присутствуют Stone Ruins, Cave Wisp, новый Core
и все шесть painted Rune. Core не перекрывает Core HP/Shield text или HP bar. Его светлый
центр делает объект заметнее Normal Wisp при сопоставимом физическом размере, но Core
не забирает главный фокус у Board.

Поле стало заметно богаче по цвету, однако общий slate stone и спокойный нижний фон удерживают
семейство вместе. Белых/серых halo, checkerboard pixels и double-frame на кадрах не видно.

## 8. VISUAL REVIEW QUESTIONS

| Вопрос | Оценка по реальным кадрам |
|---|---|
| A. Все ли 6 Rune выглядят одной семьёй? | Да: общий камень, crop, свет, painted volume и масштаб связывают набор. |
| B. Не выбивается ли Shield? | Символ немного глаже и более gem-like остальных. В gameplay size не ломает набор, но это главный кандидат на art review. |
| C. Не слишком ли medical Life? | Четырёхлучевая форма неизбежно напоминает крест. Зелёная энергия и древний камень удерживают fantasy context, но семантический риск остаётся. |
| D. Читается ли Wind? | Да при 94 px и 68 px; широкая спираль остаётся узнаваемой. В очень узком открытом слое тип читается прежде всего по бирюзовому цвету. |
| E. Не слишком ли яркая Lightning? | Она имеет самый резкий локальный контраст, но не перекрывает Fire и не перенасыщает весь экран. |
| F. Не сливается ли Core с Wind/Life? | Палитры родственны, но круглый светящийся центр, каменная чаша и отдельная battle position дают ясное различие. |
| G. Достаточно ли заметен Core? | Да. Видимая высота около 86 px против примерно 89 px у Wisp, при этом Core шире и ярче. |
| H. Не слишком ли насыщено поле? | Богаче прежнего, но управляемо: крупные символы, единый камень и тёмный фон сохраняют иерархию. |
| I. Читаются ли нижние Rune? | Цветовой класс виден хорошо. Точный знак не всегда виден в самых узких полосах; Ice/Wind — наиболее близкая пара. |

PNG субъективно не редактировались.

## 9. SCREENSHOTS

1. test-results/art-02c/01-full-rune-family-core-wisp.png — все шесть Rune, Cave Wisp и Core.
2. test-results/art-02c/02-mixed-painted-rune-row.png — четыре разных painted Rune в Row.
3. test-results/art-02c/03-reward-overlay-full-visual-layer.png — реальный Reward overlay.

Все три PNG имеют размер 720 × 1280 и сняты из Godot/OpenGL Compatibility, не из mockup.
Review battle: run seed 15, approved cave_wisp_v1_001.
Reward battle: run seed 101, unchanged approved cave_wisp_v1_006.

## 10. FILES CHANGED

Изменены:

- scripts/ui/visual_library.gd
- resources/visuals/visual_library.tres
- scripts/ui/game_view.gd
- tests/art_control_slice_tests.gd

Добавлены:

- assets/art/runes/ice.png и .import
- assets/art/runes/lightning.png и .import
- assets/art/runes/wind.png и .import
- assets/art/runes/life.png и .import
- assets/art/runes/shield.png и .import
- assets/art/core/core.png и .import
- tests/art_02c_visual_smoke.gd и .uid
- ART-02C_RUNE_SET_CORE_REPORT.md

Существующие несвязанные изменения M1–M10B3 и ART-01C сохранены.

## 11. TESTS

- Godot import: PASS; шесть PNG импортированы как Texture2D.
- Import settings: Lossless, Linear through CanvasItem, mipmaps off, Fix Alpha Border on,
  premult alpha off — PASS для всех шести новых PNG.
- Targeted resource/presentation tests: 21 checks, 0 failures.
- Headless normal-battle smoke: 21 checks, 0 failures.
- Rendered visual smoke: 24 checks, 0 failures, 3 screenshots.
- Normal Fire pointer selection и Fire/Ice Triple victory: PASS.
- Rune/Core missing-path fallback and unchanged stack/Row geometry: PASS.
- Main-scene startup: exit code 0.
- git diff --check: PASS.

Не запускались CombatValidator, generator batches, approval pipeline, full regression и
tools/check_project.ps1.

## 12. LIMITATIONS

Визуальный review выполнен на Windows/OpenGL Compatibility при 720 × 1280. Web export и
физическое мобильное устройство не проверялись. Core shield overlay не получал новый art
variant; существующий программный индикатор сохранён.

Forced headless startup завершился с exit code 0, но при выходе сообщил существующее
предупреждение о двух ObjectDB instances и одном resource still in use. Targeted и rendered
ART-02C smoke завершаются успешно.

## 13. NEXT: USER VISUAL REVIEW / STONE RUINS ENEMY FAMILY

ART-02C завершён. Следующий шаг — пользовательская оценка кадров и вопросов A–I.
Enemy Art Pack и M10B4 не начинались.
