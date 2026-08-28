# Карта desktop-kit.sh

Всего 8160 строк, 315 КБ, примерно 107 тыс. токенов целиком.

**Не читай файл целиком.** Найди место здесь или через `grep -n`, потом
`Read` с `offset`/`limit` на 40–80 строк и `Edit` по найденному фрагменту.

Пересобрать карту после правок: `bash tools/make-map.sh > SCRIPT-MAP.md`

## Рецепты: что где править

| Задача | Куда смотреть |
|---|---|
| Размер, цвет, подсветка кнопок заголовка | `cmd_buttons` — строка 1101, разбор ключей в начале, CSS ниже |
| Значки заголовка: откуда берутся | `install_fluent_glyphs` — строка 1417, адрес в $FLUENT_ICONS |
| Почему значков не видно | `diagnose_buttons` — строка 970 |
| Скругление окон и меню | `cmd_corners` — строка 1952 |
| Тема окон, схема, переключение светлая/тёмная | `cmd_theme` — строка 2744 |
| Разбор имени темы на варианты | `theme_variant_of` — строка 2437, рядом theme_base_of, theme_swap_variant |
| Поиск парного варианта темы | `theme_find_variant` — строка 2519 |
| Добавить тему в банк | `theme_repo_for` — строка 2072, плюс themes_bank ниже |
| Список и установка тем банка | `cmd_themes` — строка 2149 |
| Проверка темы на совместимость с кнопками | `themes_check` — строка 2264 |
| Тема значков и цвет папок | `cmd_icons` — строка 3082 |
| Шрифты интерфейса | `cmd_font` — строка 3209 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 3304 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 3530 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 3709, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 3666 |
| Смена обоев по порядку | `cmd_wall` — строка 4441 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 4112 |
| Чистка банка обоев | `prune_wallpapers` — строка 4372 |
| Горячие клавиши | `cmd_keys` — строка 5535 |
| Панель Dash to Panel | `cmd_panel` — строка 5593 |
| Своя тема для приложения | `cmd_app` — строка 4563 |
| Локальная апка по http | `cmd_serve` — строка 4710 |
| Откат: общая логика | `cmd_revert` — строка 5120 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 5104 |
| Что показывает status | `cmd_status` — строка 4823 |
| Полный перечень изменяемого | `help_settings` — строка 7965 |
| Общий текст справки | `usage` — строка 7910 |
| Диспетчер команд (добавить новую) | ищи `случай) cmd_` в самом конце файла: `grep -n 'cmd_status "$@"' desktop-kit.sh` |
| Правила предшественника look.sh | `strip_legacy_css` — строка 720 |
| Резервные копии и откат файлов | `backup_once` 517, `restore_backup` 547 |
| Блоки правил в gtk.css | `css_append` 784, `css_strip` 686 |
| Запомнить значение для отката | `remember` 652 / `recall` 668 |
| Наши текущие настройки | `state_set` 622 / `state_get` 637 |

## Команды

| Команда | Реализация | Справка | Тесты |
|---|---|---|---|
| `buttons` | 1101 | 918 | 6809 |
| `corners` | 1952 | 1509 | 6954 |
| `theme` | 2744 | 2027 | 6981 |
| `themes` | 2149 | 2103 | 7556 |
| `icons` | 3082 | 3047 | 7129 |
| `font` | 3209 | 3196 | 7163 |
| `widget` | 3304 | 3279 | 7195 |
| `terminal` | 3530 | 3503 | 7240 |
| `newtab` | 3709 | 3688 | 7269 |
| `wallpapers` | 4112 | 4071 | 7346 |
| `wall` | 4441 | 4416 | 7312 |
| `serve` | 4710 | 4690 | 7478 |
| `app` | 4563 | 4545 | 7460 |
| `keys` | 5535 | 5347 | 7388 |
| `panel` | 5593 | 5573 | 7432 |
| `audit` | 5669 | — | — |
| `status` | 4823 | — | — |
| `selftest` | 6267 | 5685 | — |
| `revert` | 5120 | 4916 | 7499 |

## Секции файла

    3  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
    5  Одна команда на каждую подсистему, единый откат, единый лог,
    6  самопроверка прямо на рабочей машине.
    15  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
    144  Обзор команды: что сейчас, что можно
    265  Пресеты: именованные наборы параметров
    348  Вопросы пользователю
    915  buttons — кнопки заголовка окна
    1506  corners — скругление окон
    1529  tune — настройка вопросами
    2024  theme — тема GTK
    2093  themes — банк готовых тем
    3044  icons — тема значков и цвет папок
    3193  font — шрифт интерфейса
    3276  widget — виджет conky
    3500  terminal — GNOME Terminal
    3661  newtab — страница новой вкладки Chrome
    4023  wallpapers / wall — банк обоев и смена
    4542  app — тема отдельного приложения
    4687  serve — локальная апка по http
    4820  status — что применено
    4913  revert — откат
    5344  keys — горячие клавиши
    5570  panel — Dash to Panel
    5666  audit — снимок системы
    5682  selftest — проверка на живой машине
    5725  Каркас самопроверки: песочница с подставными внешними программами
    7907  help и диспетчер

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
    344  PRESET_ARGS=""
    345  PRESET_USED=""
    356  ASK_ANSWER=""
    620  KIT_STATE="$STATE_DIR/state.env"
    705  LEGACY_CSS_MARK="look-begin"
    706  LEGACY_ICON_SUFFIX="-Fluent-Titlebar"
    2337  THEME_INSTALLED=""
    2339  THEME_VARIANT_PICKED=""
    2344  THEME_DARK_SUFFIXES="-Darker -darker -Dark -dark -DARK -Black -black"

## Где генерируется CSS

    1214  css_append buttons "$CSS3" "$(cat <<EOF
    1230  css_append buttons "$CSS4" "$(cat <<EOF
    1252  css_append buttons "$CSS3" "$(cat <<EOF
    1320  css_append buttons "$CSS4" "$(cat <<EOF
    1985  css_append corners "$CSS3" "$(cat <<EOF
    2003  css_append corners "$CSS4" "$(cat <<EOF

Селекторы, которые чаще всего правятся:
    1216  headerbar button.titlebutton,
    1218  button.titlebutton {
    1223  headerbar button.titlebutton image,
    1225  button.titlebutton image {
    1232  windowcontrols > button,
    1238  windowcontrols > button > image {
    1255  headerbar button.titlebutton,
    1257  button.titlebutton {
    1265  headerbar button.titlebutton image,
    1267  button.titlebutton image {
    1276  headerbar button.titlebutton:hover,
    1278  button.titlebutton:hover {
    1284  headerbar button.titlebutton:hover image,
    1285  button.titlebutton:hover image {

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

    группы:      core buttons corners theme icons font widget terminal newtab wall wallpapers keys panel app serve revert themes refresh tune report presets overview help
    каркас:      sandbox_new 5751, sandbox_run 6001
    утверждения: t_eq 6076, t_has 6103, t_out_has 6153, t_rc 6167
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
      244  overview_terminal
      274  presets_table
      301  preset_args
      309  presets_names
      314  presets_list
      323  preset_expand
      359  ask_possible
      371  ask_head
      380  ask_num
      417  ask_pick
      463  ask_str
      481  ask_yes
      493  would
      503  gi_get
      504  gi_set
      511  have
      517  backup_once
      547  restore_backup
      622  state_set
      637  state_get
      652  remember
      668  recall
      686  css_strip
      708  has_legacy_css
      720  strip_legacy_css
      772  icon_base_of
      784  css_append
      803  css_has
      809  untangle_css
      833  untangle_gtk4
      837  untangle_gtk3
      843  restart_gtk_apps
      858  restart_conky
      881  need_args
      890  is_number
      894  is_decimal
      898  is_hex_colour
      902  require_tools
      918  help_buttons
      970  diagnose_buttons
      1085 buttons_args
      1101 cmd_buttons
      1404 darken_hex
      1417 install_fluent_glyphs
      1509 help_corners
      1532 help_tune
      1552 tune_recap
      1558 cmd_tune
      1607 tune_corners
      1635 tune_buttons
      1695 tune_widget
      1761 tune_newtab
      1825 tune_terminal
      1854 tune_theme
      1867 tune_font
      1876 help_refresh
      1893 cmd_refresh
      1952 cmd_corners
      2027 help_theme
      2072 theme_repo_for
      2103 help_themes
      2133 themes_bank
      2149 cmd_themes
      2185 themes_list
      2205 themes_install
      2264 themes_check
      2324 list_themes
      2350 theme_exists
      2361 lower
      2363 theme_real_name
      2375 theme_exists_ci
      2394 theme_tokens
      2405 theme_token
      2409 theme_variant_pos
      2437 theme_variant_of
      2459 theme_rebuild
      2493 theme_base_of
      2507 theme_swap_variant
      2519 theme_find_variant
      2592 theme_light_by_sibling
      2611 theme_has_dark_sibling
      2623 theme_list_variants
      2651 theme_switch_variant
      2744 cmd_theme
      2956 install_theme_check_symlink
      2964 install_theme
      3047 help_icons
      3070 list_icon_themes
      3082 cmd_icons
      3196 help_font
      3209 cmd_font
      3279 help_widget
      3304 cmd_widget
      3475 conf_value
      3487 hex_brightness
      3503 help_terminal
      3521 term_profile
      3530 cmd_terminal
      3635 apply_wal_palette
      3666 newtab_tiles_plain
      3688 help_newtab
      3709 cmd_newtab
      3798 rebuild_newtab
      4009 tick
      4026 find_wallpaper_dir
      4041 current_wallpaper
      4059 detect_resolution
      4071 help_wallpapers
      4094 week_themes
      4103 wallpaper_urls
      4112 cmd_wallpapers
      4304 install_wallpaper_timer
      4372 prune_wallpapers
      4416 help_wall
      4441 cmd_wall
      4545 help_app
      4563 cmd_app
      4690 help_serve
      4710 cmd_serve
      4823 cmd_status
      4916 help_revert
      4952 revert_terminal
      4990 revert_panel
      5013 revert_app
      5047 revert_keys
      5083 revert_serve
      5104 revert_gi_keys
      5120 cmd_revert
      5347 help_keys
      5373 keys_list_paths
      5378 keys_show
      5402 keys_add
      5488 keys_remove
      5535 cmd_keys
      5573 help_panel
      5593 cmd_panel
      5669 cmd_audit
      5685 help_selftest
      5744 sb_write_stub
      5751 sandbox_new
      5974 sb_set
      5985 sb_get
      5993 sb_dconf
      6001 sandbox_run
      6027 sandbox_verify
      6051 sandbox_run_no
      6059 sandbox_drop
      6076 t_eq
      6090 t_ne
      6103 t_has
      6123 t_hasnt
      6141 t_hasnt_out
      6153 t_out_has
      6167 t_rc
      6181 t_rc_not
      6207 t_file
      6219 t_nofile
      6238 t_group
      6247 t_ok
      6249 t_fail
      6254 t_skip
      6259 t_detail
      6267 cmd_selftest
      6653 selftest_full
      6696 st_core
      6809 st_buttons
      6954 st_corners
      6981 st_theme
      7129 st_icons
      7163 st_font
      7195 st_widget
      7240 st_terminal
      7269 st_newtab
      7312 st_wall
      7346 st_wallpapers
      7388 st_keys
      7432 st_panel
      7460 st_app
      7478 st_serve
      7499 st_revert
      7556 st_themes
      7598 st_refresh
      7646 st_tune
      7727 st_report
      7781 st_overview
      7818 st_presets
      7855 st_help
      7910 usage
      7965 help_settings
      8038 cmd_help
