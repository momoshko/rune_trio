# ART-01C — Godot Control Slice Integration

Статус: IMPLEMENTED — готово к пользовательскому визуальному review.
Дата: 2026-09-10. Проект: C:/dev/rune_trio. Godot 4.7 stable, Compatibility renderer.

## 1. IMPLEMENTED
В живую игру подключены ровно три утверждённых ассета: Stone Ruins background, Cave Wisp combat sprite, Fire Rune full painted tile.
Изменения ограничены визуальным Resource, отрисовкой GameView, импортом PNG и двумя целевыми тестами.
Gameplay, RunController, enemy stats/mechanics, эффекты рун, rewards, relics, procedural bank и M10B3 не менялись.
Предыдущие изменения в рабочем дереве сохранены. По SHA-256 проверены 50 существовавших изменённых/неотслеживаемых файлов; исходное содержимое GameView восстанавливается точным обратным применением только правок ART-01C.

## 2. ART FILES IMPORTED
Оригиналы скопированы, не перемещены. Копии побайтно совпадают с master PNG по SHA-256.

| Ассет | Файл проекта | Размер |
|---|---|---|
| Background | assets/art/backgrounds/stone_ruins_bg.png | 941 x 1672 RGB |
| Cave Wisp | assets/art/enemies/stone_ruins/cave_wisp.png | 1254 x 1254 RGBA |
| Fire Rune | assets/art/runes/fire.png | 1254 x 1254 RGBA |

Оригиналы остаются в C:/Users/AKNATE/.codex/visualizations/2026/09/10/01a08bb9-f11f-70d2-ac1b-1b023798a29c/rune_trio_art/generated/stone_ruins/masters/.
Импорт: Lossless (compress/mode=0), fix_alpha_border=true, premult_alpha=false, mipmaps=false. GameView явно использует Linear, texture repeat отключён.
Прозрачные поля Wisp и Fire обрезаются только через AtlasTexture.region в визуальном Resource, без изменения PNG:
- Wisp: Rect2(180,110,900,990).
- Fire: квадрат Rect2(80,86,1096,1096).

## 3. STONE RUINS BACKGROUND
Новый background выбирается только по presentation ID stone_ruins и рисуется под всем игровым экраном.
Используется cover/crop с сохранением пропорций, центрированным source rect и без tiling.
Frozen Grove и Eclipse Lands получают прежние placeholders; Stone Ruins art на них не распространяется.
При загруженном фоне Stone Ruins:
- battle panel opacity = 0.38, существующий border сохранён;
- Board backplate opacity = 0.08;
- под HUD сохраняется отдельное затемнение opacity = 0.76;
- background modulate = Color(0.9,0.92,0.92,1).
Эти параметры лежат в VisualLibrary и не затрагивают размеры layout.

## 4. CAVE WISP
Mapping действует только для enemy_id cave_wisp. Остальные враги сохраняют прежние visuals.
Спрайт центрируется и равномерно вписывается в существующую правую область боя.
На фактическом viewport 720 x 1280:
- battle rect: position (0,194), size (720,180);
- texture rect Wisp: position (548.58,242), size (83.64,92);
- видимая высота с учётом alpha-полей: приблизительно 89 px.
Подпись только для mapped sprite поднята на 6 px и использует 13px font, чтобы вместить обычного врага между текстом и HP bar. Geometry HUD/Board/Row не переносилась.
Normal status, boss_scale и боевые характеристики не менялись.

## 5. FIRE RUNE
Реализован вариант A: mapped full-tile PNG рисуется вместо двух программных панелей и декоративной рамки тела руны.
Старая тень прямоугольной карточки не рисуется под full-tile изображением. Каменный край является частью PNG.
Остальные пять типов используют прежнюю ветку отрисовки.
Сохранены hitbox, Top-only input, fan offsets, selection/flight/reveal logic, disabled dim, lock overlay и slot indicators Rune Row.
На фактической раскладке smoke:
- stack hitbox: 94.04 x 110.4;
- квадратная текстура Fire внутри него: 94.04 x 94.04;
- квадратная текстура Fire в Rune Row: 68.08 x 68.08.
Размер 1254 PNG не влияет на gameplay geometry.

## 6. VISUAL MAPPING
Минимальные настройки в resources/visuals/visual_library.tres:
- background_paths: biome -> optional texture path;
- enemy_paths: enemy_id -> optional texture path;
- rune_tile_paths: rune_type -> full painted tile path;
- texture_regions: path -> source region для прозрачных полей.
Реализация — scripts/ui/visual_library.gd. Texture2D загружается по требованию и кэшируется.
Пути необязательны: отсутствующая текстура возвращает null и не становится обязательной ext_resource-зависимостью главной сцены. GameView сохраняет старый placeholder fallback.
Доступные ранее поля Texture2D для backgrounds/Core и EnemyDefinition/TileDefinition не удалены. Большой Skin/Theme framework не создавался.

## 7. OVERLAY RESULT
Reward overlay и Current Build используют ту же сцену и тот же background Texture2D.
Реальная победа Cave Wisp открыла существующий reward UI. Board сохранился, HUD/стопки остались под затемнением, модальное окно блокирует игровой ввод.
Отдельных копий фона для overlays нет. Код reward/RunController не менялся.
Существующее сильное затемнение reward overlay оставлено: окружение видно, но главным остаётся выбор награды.

## 8. SCREENSHOTS / MANUAL CHECK
Скриншоты сняты с реального viewport Godot, не являются mockup:
1. [Cave Wisp — начало боя](C:/dev/rune_trio/test-results/art-01c/01-cave-wisp-start.png).
2. [Fire в stack и Rune Row](C:/dev/rune_trio/test-results/art-01c/02-fire-stack-and-row.png).
3. [Награда после победы](C:/dev/rune_trio/test-results/art-01c/03-stone-ruins-reward.png).

Сценарий: seed=101, первый normal encounter chapter_1_cave_wisp, неизменённая approved раскладка cave_wisp_v1_006.
Победа получена через обычные события мыши и Top selection: stack IDs [4,1,4,1,1,0,0], типы [fire,ice,ice,fire,fire,wind,ice].
Никакого injected victory, подмены board или изменения HP/stat не было. Итог: enemy HP=0, Core HP=37, в Rune Row остался wind.
Фактические координаты записаны в test-results/art-01c/metrics.json.

## 9. VISUAL QUESTIONS

| Вопрос | Оценка по реальным кадрам |
|---|---|
| A. Wisp слишком большой? | Нет. Около 89 px видимой высоты; выглядит Normal, без масштаба и атрибутов Elite/Boss. |
| B. Отделяется от background? | Да. Светлые каменные плоскости и нефритовые глаза читаются на затемнённой панели; подпись и HP не перекрыты. |
| C. Fire слишком яркая/глянцевая? | Это самый насыщенный акцент нового арта. Он заметно теплее Wisp, но поверхность остаётся матовой и painted. Яркость стоит подтвердить пользователю. |
| D. Background слишком подробный/контрастный? | Низ спокойный. Колонны за верхними стопками заметны и местами конкурируют с ними; это основной вопрос для visual review. |
| E. Есть double-frame у Fire? | Нет у тела плитки. Рамка слота Rune Row остаётся как отдельный игровой индикатор. |
| F. Fire читается в фактическом размере? | Да: приблизительно 94px в stack и 68px в Row. В закрытых слоях видны части символа и каменный край, disabled dim сохранён. |
| G. HUD readability? | Текст читается; верхний HUD имеет свою тёмную подложку, остальные подписи остаются на полупрозрачной панели. |

Ассеты по субъективным замечаниям автоматически не переделывались.

## 10. FILES CHANGED
Изменены:
- scripts/ui/game_view.gd — локальная отрисовка cover/background panels, mapped Wisp и full Fire tile.
- scripts/ui/visual_library.gd — optional data-driven mapping, loading/cache, визуальные параметры.
- resources/visuals/visual_library.tres — три пути и две области прозрачных полей.

Добавлены:
- assets/art/backgrounds/stone_ruins_bg.png и .import;
- assets/art/enemies/stone_ruins/cave_wisp.png и .import;
- assets/art/runes/fire.png и .import;
- tests/art_control_slice_tests.gd и .uid;
- tests/art_control_slice_smoke.gd и .uid;
- ART-01C_CONTROL_SLICE_REPORT.md.

Скриншоты, метрики и логи находятся в test-results/art-01c, который уже исключён из Git существующим .gitignore.
main.tscn, RunController, gameplay resources, layouts и validation tools в этой задаче не редактировались.

## 11. TESTS
- Targeted resource/presentation tests: 19 checks, 0 failures.
- Rendered Cave Wisp visual smoke: 17 checks, 0 failures, 3 screenshots.
- Финальный project import: PASS.
- Обычный startup главной сцены: PASS.
- git diff --check: PASS.
- Проверка исходных изменений и SHA-256 копий PNG: PASS.
- Финальный visual-smoke-errors.log пуст; раннее предупреждение MP3 при выходе устранено остановкой pending music tween только в cleanup теста. Аудиокод игры не менялся.

Команды:
```powershell
& 'C:\godot\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tests/art_control_slice_tests.gd
& 'C:\godot\Godot_v4.7-stable_win64_console.exe' --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/art_control_slice_smoke.gd -- C:/dev/rune_trio/test-results/art-01c
```

CombatValidator, generator batch, M10B approval pipeline, full regression и check_project.ps1 не запускались.
Runtime reconstruction уже утверждённой раскладки выполнен существующим RunController как часть обычного старта боя; новые кандидаты не создавались.

## 12. LIMITATIONS
Визуальные кадры проверены на Windows / OpenGL Compatibility при 720 x 1280. Математика cover дополнительно проверена для 540 x 960 и 1280 x 720; отдельного visual sweep этих размеров не было.
Web export и физическое мобильное устройство не проверялись. Это control slice, не финальная оптимизация или полный арт-пак.
Smoke закреплён за seed=101 и approved layout cave_wisp_v1_006; если банк позже изменится, fixture потребует отдельного обновления.
Другие руны, враги, Core и остальной UI остаются текущими placeholders.

## 13. NEXT: USER VISUAL REVIEW
Следующий шаг — пользовательская оценка трёх реальных кадров и вопросов A–G.
Остальные ассеты, полный Chapter 1 art pack и M10B4 не начинались.
