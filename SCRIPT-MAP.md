# Карта desktop-kit.sh

Всего 7983 строк, 309 КБ, примерно 105 тыс. токенов целиком.

**Не читай файл целиком.** Найди место здесь или через `grep -n`, потом
`Read` с `offset`/`limit` на 40–80 строк и `Edit` по найденному фрагменту.

Пересобрать карту после правок: `bash tools/make-map.sh > SCRIPT-MAP.md`

## Рецепты: что где править

| Задача | Куда смотреть |
|---|---|
| Размер, цвет, подсветка кнопок заголовка | `cmd_buttons` — строка 980, разбор ключей в начале, CSS ниже |
| Значки заголовка: откуда берутся | `install_fluent_glyphs` — строка 1291, адрес в $FLUENT_ICONS |
| Почему значков не видно | `diagnose_buttons` — строка 849 |
| Скругление окон и меню | `cmd_corners` — строка 1825 |
| Тема окон, схема, переключение светлая/тёмная | `cmd_theme` — строка 2612 |
| Разбор имени темы на варианты | `theme_variant_of` — строка 2305, рядом theme_base_of, theme_swap_variant |
| Поиск парного варианта темы | `theme_find_variant` — строка 2387 |
| Добавить тему в банк | `theme_repo_for` — строка 1940, плюс themes_bank ниже |
| Список и установка тем банка | `cmd_themes` — строка 2017 |
| Проверка темы на совместимость с кнопками | `themes_check` — строка 2132 |
| Тема значков и цвет папок | `cmd_icons` — строка 2950 |
| Шрифты интерфейса | `cmd_font` — строка 3077 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 3172 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 3394 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 3569, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 3526 |
| Смена обоев по порядку | `cmd_wall` — строка 4301 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 3972 |
| Чистка банка обоев | `prune_wallpapers` — строка 4232 |
| Горячие клавиши | `cmd_keys` — строка 5395 |
| Панель Dash to Panel | `cmd_panel` — строка 5453 |
| Своя тема для приложения | `cmd_app` — строка 4423 |
| Локальная апка по http | `cmd_serve` — строка 4570 |
| Откат: общая логика | `cmd_revert` — строка 4980 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 4964 |
| Что показывает status | `cmd_status` — строка 4683 |
| Полный перечень изменяемого | `help_settings` — строка 7788 |
| Общий текст справки | `usage` — строка 7733 |
| Диспетчер команд (добавить новую) | ищи `случай) cmd_` в самом конце файла: `grep -n 'cmd_status "$@"' desktop-kit.sh` |
| Правила предшественника look.sh | `strip_legacy_css` — строка 599 |
| Резервные копии и откат файлов | `backup_once` 396, `restore_backup` 426 |
| Блоки правил в gtk.css | `css_append` 663, `css_strip` 565 |
| Запомнить значение для отката | `remember` 531 / `recall` 547 |
| Наши текущие настройки | `state_set` 501 / `state_get` 516 |

## Команды

| Команда | Реализация | Справка | Тесты |
|---|---|---|---|
| `buttons` | 980 | 797 | 6669 |
| `corners` | 1825 | 1383 | 6814 |
| `theme` | 2612 | 1895 | 6841 |
| `themes` | 2017 | 1971 | 7416 |
| `icons` | 2950 | 2915 | 6989 |
| `font` | 3077 | 3064 | 7023 |
| `widget` | 3172 | 3147 | 7055 |
| `terminal` | 3394 | 3367 | 7100 |
| `newtab` | 3569 | 3548 | 7129 |
| `wallpapers` | 3972 | 3931 | 7206 |
| `wall` | 4301 | 4276 | 7172 |
| `serve` | 4570 | 4550 | 7338 |
| `app` | 4423 | 4405 | 7320 |
| `keys` | 5395 | 5207 | 7248 |
| `panel` | 5453 | 5433 | 7292 |
| `audit` | 5529 | — | — |
| `status` | 4683 | — | — |
| `selftest` | 6127 | 5545 | — |
| `revert` | 4980 | 4776 | 7359 |

## Секции файла

    3  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
    5  Одна команда на каждую подсистему, единый откат, единый лог,
    6  самопроверка прямо на рабочей машине.
    15  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
    144  Пресеты: именованные наборы параметров
    227  Вопросы пользователю
    794  buttons — кнопки заголовка окна
    1380  corners — скругление окон
    1402  tune — настройка вопросами
    1892  theme — тема GTK
    1961  themes — банк готовых тем
    2912  icons — тема значков и цвет папок
    3061  font — шрифт интерфейса
    3144  widget — виджет conky
    3364  terminal — GNOME Terminal
    3521  newtab — страница новой вкладки Chrome
    3883  wallpapers / wall — банк обоев и смена
    4402  app — тема отдельного приложения
    4547  serve — локальная апка по http
    4680  status — что применено
    4773  revert — откат
    5204  keys — горячие клавиши
    5430  panel — Dash to Panel
    5526  audit — снимок системы
    5542  selftest — проверка на живой машине
    5585  Каркас самопроверки: песочница с подставными внешними программами
    7730  help и диспетчер

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
    223  PRESET_ARGS=""
    224  PRESET_USED=""
    235  ASK_ANSWER=""
    499  KIT_STATE="$STATE_DIR/state.env"
    584  LEGACY_CSS_MARK="look-begin"
    585  LEGACY_ICON_SUFFIX="-Fluent-Titlebar"
    2205  THEME_INSTALLED=""
    2207  THEME_VARIANT_PICKED=""
    2212  THEME_DARK_SUFFIXES="-Darker -darker -Dark -dark -DARK -Black -black"

## Где генерируется CSS

    1088  css_append buttons "$CSS3" "$(cat <<EOF
    1104  css_append buttons "$CSS4" "$(cat <<EOF
    1126  css_append buttons "$CSS3" "$(cat <<EOF
    1194  css_append buttons "$CSS4" "$(cat <<EOF
    1853  css_append corners "$CSS3" "$(cat <<EOF
    1871  css_append corners "$CSS4" "$(cat <<EOF

Селекторы, которые чаще всего правятся:
    1090  headerbar button.titlebutton,
    1092  button.titlebutton {
    1097  headerbar button.titlebutton image,
    1099  button.titlebutton image {
    1106  windowcontrols > button,
    1112  windowcontrols > button > image {
    1129  headerbar button.titlebutton,
    1131  button.titlebutton {
    1139  headerbar button.titlebutton image,
    1141  button.titlebutton image {
    1150  headerbar button.titlebutton:hover,
    1152  button.titlebutton:hover {
    1158  headerbar button.titlebutton:hover image,
    1159  button.titlebutton:hover image {

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

    группы:      core buttons corners theme icons font widget terminal newtab wall wallpapers keys panel app serve revert themes refresh tune report presets help
    каркас:      sandbox_new 5611, sandbox_run 5861
    утверждения: t_eq 5936, t_has 5963, t_out_has 6013, t_rc 6027
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
      153  presets_table
      180  preset_args
      188  presets_names
      193  presets_list
      202  preset_expand
      238  ask_possible
      250  ask_head
      259  ask_num
      296  ask_pick
      342  ask_str
      360  ask_yes
      372  would
      382  gi_get
      383  gi_set
      390  have
      396  backup_once
      426  restore_backup
      501  state_set
      516  state_get
      531  remember
      547  recall
      565  css_strip
      587  has_legacy_css
      599  strip_legacy_css
      651  icon_base_of
      663  css_append
      682  css_has
      688  untangle_css
      712  untangle_gtk4
      716  untangle_gtk3
      722  restart_gtk_apps
      737  restart_conky
      760  need_args
      769  is_number
      773  is_decimal
      777  is_hex_colour
      781  require_tools
      797  help_buttons
      849  diagnose_buttons
      964  buttons_args
      980  cmd_buttons
      1278 darken_hex
      1291 install_fluent_glyphs
      1383 help_corners
      1405 help_tune
      1425 tune_recap
      1431 cmd_tune
      1480 tune_corners
      1508 tune_buttons
      1568 tune_widget
      1634 tune_newtab
      1698 tune_terminal
      1727 tune_theme
      1740 tune_font
      1749 help_refresh
      1766 cmd_refresh
      1825 cmd_corners
      1895 help_theme
      1940 theme_repo_for
      1971 help_themes
      2001 themes_bank
      2017 cmd_themes
      2053 themes_list
      2073 themes_install
      2132 themes_check
      2192 list_themes
      2218 theme_exists
      2229 lower
      2231 theme_real_name
      2243 theme_exists_ci
      2262 theme_tokens
      2273 theme_token
      2277 theme_variant_pos
      2305 theme_variant_of
      2327 theme_rebuild
      2361 theme_base_of
      2375 theme_swap_variant
      2387 theme_find_variant
      2460 theme_light_by_sibling
      2479 theme_has_dark_sibling
      2491 theme_list_variants
      2519 theme_switch_variant
      2612 cmd_theme
      2824 install_theme_check_symlink
      2832 install_theme
      2915 help_icons
      2938 list_icon_themes
      2950 cmd_icons
      3064 help_font
      3077 cmd_font
      3147 help_widget
      3172 cmd_widget
      3339 conf_value
      3351 hex_brightness
      3367 help_terminal
      3385 term_profile
      3394 cmd_terminal
      3495 apply_wal_palette
      3526 newtab_tiles_plain
      3548 help_newtab
      3569 cmd_newtab
      3658 rebuild_newtab
      3869 tick
      3886 find_wallpaper_dir
      3901 current_wallpaper
      3919 detect_resolution
      3931 help_wallpapers
      3954 week_themes
      3963 wallpaper_urls
      3972 cmd_wallpapers
      4164 install_wallpaper_timer
      4232 prune_wallpapers
      4276 help_wall
      4301 cmd_wall
      4405 help_app
      4423 cmd_app
      4550 help_serve
      4570 cmd_serve
      4683 cmd_status
      4776 help_revert
      4812 revert_terminal
      4850 revert_panel
      4873 revert_app
      4907 revert_keys
      4943 revert_serve
      4964 revert_gi_keys
      4980 cmd_revert
      5207 help_keys
      5233 keys_list_paths
      5238 keys_show
      5262 keys_add
      5348 keys_remove
      5395 cmd_keys
      5433 help_panel
      5453 cmd_panel
      5529 cmd_audit
      5545 help_selftest
      5604 sb_write_stub
      5611 sandbox_new
      5834 sb_set
      5845 sb_get
      5853 sb_dconf
      5861 sandbox_run
      5887 sandbox_verify
      5911 sandbox_run_no
      5919 sandbox_drop
      5936 t_eq
      5950 t_ne
      5963 t_has
      5983 t_hasnt
      6001 t_hasnt_out
      6013 t_out_has
      6027 t_rc
      6041 t_rc_not
      6067 t_file
      6079 t_nofile
      6098 t_group
      6107 t_ok
      6109 t_fail
      6114 t_skip
      6119 t_detail
      6127 cmd_selftest
      6513 selftest_full
      6556 st_core
      6669 st_buttons
      6814 st_corners
      6841 st_theme
      6989 st_icons
      7023 st_font
      7055 st_widget
      7100 st_terminal
      7129 st_newtab
      7172 st_wall
      7206 st_wallpapers
      7248 st_keys
      7292 st_panel
      7320 st_app
      7338 st_serve
      7359 st_revert
      7416 st_themes
      7458 st_refresh
      7506 st_tune
      7587 st_report
      7641 st_presets
      7678 st_help
      7733 usage
      7788 help_settings
      7861 cmd_help
