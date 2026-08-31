# Карта desktop-kit.sh

Всего 9700 строк, 385 КБ, примерно 131 тыс. токенов целиком.

**Не читай файл целиком.** Найди место здесь или через `grep -n`, потом
`Read` с `offset`/`limit` на 40–80 строк и `Edit` по найденному фрагменту.

Пересобрать карту после правок: `bash tools/make-map.sh > SCRIPT-MAP.md`

## Рецепты: что где править

| Задача | Куда смотреть |
|---|---|
| Размер, цвет, подсветка кнопок заголовка | `cmd_buttons` — строка 2067, разбор ключей в начале, CSS ниже |
| Значки заголовка: откуда берутся | `install_fluent_glyphs` — строка 2383, адрес в $FLUENT_ICONS |
| Почему значков не видно | `diagnose_buttons` — строка 1936 |
| Скругление окон и меню | `cmd_corners` — строка 2918 |
| Тема окон, схема, переключение светлая/тёмная | `cmd_theme` — строка 3765 |
| Разбор имени темы на варианты | `theme_variant_of` — строка 3458, рядом theme_base_of, theme_swap_variant |
| Поиск парного варианта темы | `theme_find_variant` — строка 3540 |
| Добавить тему в банк | `theme_repo_for` — строка 3047, плюс themes_bank ниже |
| Список и установка тем банка | `cmd_themes` — строка 3158 |
| Проверка темы на совместимость с кнопками | `themes_check` — строка 3285 |
| Тема значков и цвет папок | `cmd_icons` — строка 4262 |
| Шрифты интерфейса | `cmd_font` — строка 4402 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 4557 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 4802 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 5004, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 4938 |
| Смена обоев по порядку | `cmd_wall` — строка 5743 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 5414 |
| Чистка банка обоев | `prune_wallpapers` — строка 5674 |
| Горячие клавиши | `cmd_keys` — строка 6839 |
| Панель Dash to Panel | `cmd_panel` — строка 6897 |
| Своя тема для приложения | `cmd_app` — строка 5865 |
| Локальная апка по http | `cmd_serve` — строка 6012 |
| Откат: общая логика | `cmd_revert` — строка 6422 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 6406 |
| Что показывает status | `cmd_status` — строка 6125 |
| Полный перечень изменяемого | `help_settings` — строка 9501 |
| Общий текст справки | `usage` — строка 9443 |
| Диспетчер команд (добавить новую) | ищи `случай) cmd_` в самом конце файла: `grep -n 'cmd_status "$@"' desktop-kit.sh` |
| Правила предшественника look.sh | `strip_legacy_css` — строка 1686 |
| Резервные копии и откат файлов | `backup_once` 1483, `restore_backup` 1513 |
| Блоки правил в gtk.css | `css_append` 1750, `css_strip` 1652 |
| Запомнить значение для отката | `remember` 1618 / `recall` 1634 |
| Наши текущие настройки | `state_set` 1588 / `state_get` 1603 |

## Правишь -> гоняй (вместо полного прогона)

Полный selftest --full нужен только перед выкладкой. После точечной
правки достаточно её группы плюс зависимых:

```
bash tools/check.sh "ГРУППА [ГРУППА]"
```

| Правишь | Гоняй группы | Почему ещё и вторые |
|---|---|---|
| cmd_buttons, install_fluent_glyphs, CSS кнопок | buttons refresh presets | refresh переприменяет кнопки, presets их разворачивает |
| cmd_corners, CSS углов | corners presets overview | overview показывает наборы углов |
| theme_* (разбор имён, варианты) | theme | — |
| cmd_theme | theme revert | revert theme читает те же ключи |
| theme_repo_for, themes_bank, cmd_themes | themes | — |
| cmd_icons | icons buttons | buttons строит наследника поверх темы значков |
| cmd_font, apply_font | font | — |
| cmd_widget, widget_modules | widget tune | tune widget зовёт cmd_widget |
| cmd_terminal, apply_wal_palette | terminal revert | откат терминала читает те же ключи |
| cmd_newtab, генерация страницы | newtab wall | wall пересобирает страницу |
| cmd_wall | wall | — |
| cmd_wallpapers, prune | wallpapers | — |
| cmd_keys / cmd_panel / cmd_app / cmd_serve | keys / panel / app / serve | — |
| cmd_revert, restore_backup, revert_* | revert refresh | refresh тоже читает состояние |
| remember/recall, state_*, backup_once, css_* | core revert | это фундамент отката |
| preset_* | presets overview | обзор печатает наборы |
| ask_*, tune_* | tune | — |
| cmd_refresh | refresh | — |
| отчёт selftest, упаковка архива | report | — |
| usage, help_* | help | — |

Правило: правка в ДВУХ местах из таблицы — гоняй обе строки.
Перед git push: полный прогон плюс tests/test_kit.sh и tests/test_variants.sh.

## Команды

| Команда | Реализация | Справка | Тесты |
|---|---|---|---|
| `buttons` | 2067 | 1884 | 8113 |
| `corners` | 2918 | 2475 | 8258 |
| `theme` | 3765 | 2993 | 8285 |
| `themes` | 3158 | 3089 | 8934 |
| `icons` | 4262 | 4200 | 8459 |
| `font` | 4402 | 4389 | 8532 |
| `widget` | 4557 | 4472 | 8564 |
| `terminal` | 4802 | 4775 | 8609 |
| `newtab` | 5004 | 4960 | 8638 |
| `wallpapers` | 5414 | 5373 | 8722 |
| `wall` | 5743 | 5718 | 8688 |
| `serve` | 6012 | 5992 | 8856 |
| `app` | 5865 | 5847 | 8838 |
| `keys` | 6839 | 6651 | 8764 |
| `panel` | 6897 | 6877 | 8808 |
| `audit` | 6973 | — | — |
| `status` | 6125 | — | — |
| `selftest` | 7571 | 6989 | — |
| `revert` | 6422 | 6218 | 8877 |

## Секции файла

    3  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
    5  Одна команда на каждую подсистему, единый откат, единый лог,
    6  самопроверка прямо на рабочей машине.
    15  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
    144  Обзор команды: что сейчас, что можно
    266  look — готовые образы рабочего стола
    451  profile — снимок оформления целиком
    811  Банк тем значков
    1148  Тема для GTK4-приложений
    1231  Пресеты: именованные наборы параметров
    1314  Вопросы пользователю
    1881  buttons — кнопки заголовка окна
    2472  corners — скругление окон
    2495  tune — настройка вопросами
    2990  theme — тема GTK
    3079  themes — банк готовых тем
    4197  icons — тема значков и цвет папок
    4386  font — шрифт интерфейса
    4469  widget — виджет conky
    4772  terminal — GNOME Terminal
    4933  newtab — страница новой вкладки Chrome
    5325  wallpapers / wall — банк обоев и смена
    5844  app — тема отдельного приложения
    5989  serve — локальная апка по http
    6122  status — что применено
    6215  revert — откат
    6648  keys — горячие клавиши
    6874  panel — Dash to Panel
    6970  audit — снимок системы
    6986  selftest — проверка на живой машине
    7029  Каркас самопроверки: песочница с подставными внешними программами
    9440  help и диспетчер

## Пути и константы

    38  VERSION="1.0"
    39  SELF=$(readlink -f "$0")
    60  STATE_DIR="$HOME/.local/state/desktop-kit"
    61  BACKUP_DIR="$STATE_DIR/backups"
    62  LOG_FILE="$STATE_DIR/desktop-kit.log"
    63  BEFORE="$STATE_DIR/before.env"
    67  CONKY_DIR="$HOME/.config/conky"
    68  CONKY_CONF="$CONKY_DIR/main.conf"
    69  CONKY_LUA="$CONKY_DIR/desktop-kit-bg.lua"
    70  NEWTAB_DIR="$HOME/.local/share/newtab"
    71  NEWTAB_LINKS="$NEWTAB_DIR/links.txt"
    72  BIN_DIR="$HOME/bin"
    76  APP_MARK="# создано desktop-kit"
    79  SYS_THEMES="${DK_SYS_THEMES:-/usr/share/themes}"
    80  SYS_ICONS="${DK_SYS_ICONS:-/usr/share/icons}"
    81  SYS_APPS="${DK_SYS_APPS:-/usr/share/applications}"
    83  FLUENT_ICONS="https://raw.githubusercontent.com/vinceliuice/Fluent-icon-theme/master/src/symbolic/actions"
    84  WALLHAVEN="https://wallhaven.cc/api/v1/search"
    88  DRY_RUN=0
    89  ASSUME_YES=0
    90  QUIET=0
    464  PROFILE_DIR="$STATE_DIR/profiles"
    1310  PRESET_ARGS=""
    1311  PRESET_USED=""
    1322  ASK_ANSWER=""
    1586  KIT_STATE="$STATE_DIR/state.env"
    1671  LEGACY_CSS_MARK="look-begin"
    1672  LEGACY_ICON_SUFFIX="-Fluent-Titlebar"
    3358  THEME_INSTALLED=""
    3360  THEME_VARIANT_PICKED=""

## Где генерируется CSS

    2180  css_append buttons "$CSS3" "$(cat <<EOF
    2196  css_append buttons "$CSS4" "$(cat <<EOF
    2218  css_append buttons "$CSS3" "$(cat <<EOF
    2286  css_append buttons "$CSS4" "$(cat <<EOF
    2951  css_append corners "$CSS3" "$(cat <<EOF
    2969  css_append corners "$CSS4" "$(cat <<EOF

Селекторы, которые чаще всего правятся:
    2182  headerbar button.titlebutton,
    2184  button.titlebutton {
    2189  headerbar button.titlebutton image,
    2191  button.titlebutton image {
    2198  windowcontrols > button,
    2204  windowcontrols > button > image {
    2221  headerbar button.titlebutton,
    2223  button.titlebutton {
    2231  headerbar button.titlebutton image,
    2233  button.titlebutton image {
    2242  headerbar button.titlebutton:hover,
    2244  button.titlebutton:hover {
    2250  headerbar button.titlebutton:hover image,
    2251  button.titlebutton:hover image {

## Ключи состояния

Для отката (пишутся один раз, файл before.env):
    remember COLOR_SCHEME
    remember DTP_CUSTOM
    remember DTP_OPACITY
    remember DTP_SIZES
    remember FOLDER_COLOUR
    remember GTK_THEME
    remember ICON_THEME
    remember SHELL_THEME
    remember TERM_BG
    remember TERM_FG
    remember TERM_FONT
    remember TERM_OPACITY
    remember TERM_PALETTE
    remember TERM_SYSFONT
    remember TERM_THEMECOLORS
    remember TERM_TRANSPARENT

Наши текущие настройки (перезаписываются, файл state.env):
    state_set BTN_ARGS
    state_set BTN_CLOSE
    state_set BTN_H
    state_set BTN_ICON
    state_set BTN_PREV_ICON
    state_set BTN_RADIUS
    state_set BTN_W
    state_set CONKY_ALPHA
    state_set CONKY_INK
    state_set CONKY_RADIUS
    state_set CORNERS_ARGS
    state_set CORNERS_RADIUS
    state_set KEYS_OURS
    state_set NEWTAB_CLOCK
    state_set NEWTAB_TILE

## Самопроверка

    группы:      core buttons corners theme icons font widget terminal newtab wall wallpapers keys panel app serve revert themes look profile refresh tune report presets overview help
    каркас:      sandbox_new 7055, sandbox_run 7305
    утверждения: t_eq 7380, t_has 7407, t_out_has 7457, t_rc 7471
    заглушки:    13 штук, ищи sb_write_stub

Запуск одной группы: `bash desktop-kit.sh selftest --only theme`

## Все функции

      92   ok
      93   bad
      94   note
      96   blank
      99   dump
      107  hint
      108  head1
      110  log
      115  die
      121  confirm
      157  overview_head
      162  overview_presets
      169  overview_tail
      176  overview_buttons
      202  overview_corners
      219  overview_widget
      245  overview_terminal
      284  look_table
      292  look_names
      296  help_look
      321  look_list
      334  look_show
      356  look_apply
      425  cmd_look
      469  profile_keys
      495  profile_files
      504  help_profile
      535  profile_autoname
      539  profile_list_names
      551  profile_save
      619  profile_load
      709  profile_show
      737  profile_drop
      758  profile_list
      781  cmd_profile
      823  icons_bank
      848  icons_repo_for
      852  icons_bank_list
      888  icons_clean
      913  git_clone_retry
      985  disk_room_warn
      1016 icons_copy_theme
      1031 icons_get
      1165 theme_gtk4_css
      1179 gtk4_theme_unlink
      1194 gtk4_theme_apply
      1240 presets_table
      1267 preset_args
      1275 presets_names
      1280 presets_list
      1289 preset_expand
      1325 ask_possible
      1337 ask_head
      1346 ask_num
      1383 ask_pick
      1429 ask_str
      1447 ask_yes
      1459 would
      1469 gi_get
      1470 gi_set
      1477 have
      1483 backup_once
      1513 restore_backup
      1588 state_set
      1603 state_get
      1618 remember
      1634 recall
      1652 css_strip
      1674 has_legacy_css
      1686 strip_legacy_css
      1738 icon_base_of
      1750 css_append
      1769 css_has
      1775 untangle_css
      1799 untangle_gtk4
      1803 untangle_gtk3
      1809 restart_gtk_apps
      1824 restart_conky
      1847 need_args
      1856 is_number
      1860 is_decimal
      1864 is_hex_colour
      1868 require_tools
      1884 help_buttons
      1936 diagnose_buttons
      2051 buttons_args
      2067 cmd_buttons
      2370 darken_hex
      2383 install_fluent_glyphs
      2475 help_corners
      2498 help_tune
      2518 tune_recap
      2524 cmd_tune
      2573 tune_corners
      2601 tune_buttons
      2661 tune_widget
      2727 tune_newtab
      2791 tune_terminal
      2820 tune_theme
      2833 tune_font
      2842 help_refresh
      2859 cmd_refresh
      2918 cmd_corners
      2993 help_theme
      3047 theme_repo_for
      3089 help_themes
      3132 themes_bank
      3158 cmd_themes
      3194 themes_list
      3214 themes_install
      3285 themes_check
      3345 list_themes
      3371 theme_exists
      3382 lower
      3384 theme_real_name
      3396 theme_exists_ci
      3415 theme_tokens
      3426 theme_token
      3430 theme_variant_pos
      3458 theme_variant_of
      3480 theme_rebuild
      3514 theme_base_of
      3528 theme_swap_variant
      3540 theme_find_variant
      3613 theme_light_by_sibling
      3632 theme_has_dark_sibling
      3644 theme_list_variants
      3672 theme_switch_variant
      3765 cmd_theme
      4001 install_theme_check_symlink
      4023 theme_build
      4086 theme_copy_dir
      4099 install_theme
      4200 help_icons
      4238 list_user_icon_themes
      4250 list_icon_themes
      4262 cmd_icons
      4389 help_font
      4402 cmd_font
      4472 help_widget
      4501 widget_modules_table
      4513 widget_add_module
      4557 cmd_widget
      4747 conf_value
      4759 hex_brightness
      4775 help_terminal
      4793 term_profile
      4802 cmd_terminal
      4907 apply_wal_palette
      4938 newtab_tiles_plain
      4960 help_newtab
      4982 overview_newtab
      5004 cmd_newtab
      5100 rebuild_newtab
      5311 tick
      5328 find_wallpaper_dir
      5343 current_wallpaper
      5361 detect_resolution
      5373 help_wallpapers
      5396 week_themes
      5405 wallpaper_urls
      5414 cmd_wallpapers
      5606 install_wallpaper_timer
      5674 prune_wallpapers
      5718 help_wall
      5743 cmd_wall
      5847 help_app
      5865 cmd_app
      5992 help_serve
      6012 cmd_serve
      6125 cmd_status
      6218 help_revert
      6254 revert_terminal
      6292 revert_panel
      6315 revert_app
      6349 revert_keys
      6385 revert_serve
      6406 revert_gi_keys
      6422 cmd_revert
      6651 help_keys
      6677 keys_list_paths
      6682 keys_show
      6706 keys_add
      6792 keys_remove
      6839 cmd_keys
      6877 help_panel
      6897 cmd_panel
      6973 cmd_audit
      6989 help_selftest
      7048 sb_write_stub
      7055 sandbox_new
      7278 sb_set
      7289 sb_get
      7297 sb_dconf
      7305 sandbox_run
      7331 sandbox_verify
      7355 sandbox_run_no
      7363 sandbox_drop
      7380 t_eq
      7394 t_ne
      7407 t_has
      7427 t_hasnt
      7445 t_hasnt_out
      7457 t_out_has
      7471 t_rc
      7485 t_rc_not
      7511 t_file
      7523 t_nofile
      7542 t_group
      7551 t_ok
      7553 t_fail
      7558 t_skip
      7563 t_detail
      7571 cmd_selftest
      7957 selftest_full
      8000 st_core
      8113 st_buttons
      8258 st_corners
      8285 st_theme
      8459 st_icons
      8532 st_font
      8564 st_widget
      8609 st_terminal
      8638 st_newtab
      8688 st_wall
      8722 st_wallpapers
      8764 st_keys
      8808 st_panel
      8838 st_app
      8856 st_serve
      8877 st_revert
      8934 st_themes
      8976 st_look
      9052 st_profile
      9127 st_refresh
      9175 st_tune
      9256 st_report
      9310 st_overview
      9347 st_presets
      9384 st_help
      9443 usage
      9501 help_settings
      9574 cmd_help
