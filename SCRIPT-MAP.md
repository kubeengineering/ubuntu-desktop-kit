# Карта desktop-kit.sh

Всего 6957 строк, 271 КБ, примерно 92 тыс. токенов целиком.

**Не читай файл целиком.** Найди место здесь или через `grep -n`, потом
`Read` с `offset`/`limit` на 40–80 строк и `Edit` по найденному фрагменту.

Пересобрать карту после правок: `bash tools/make-map.sh > SCRIPT-MAP.md`

## Рецепты: что где править

| Задача | Куда смотреть |
|---|---|
| Размер, цвет, подсветка кнопок заголовка | `cmd_buttons` — строка 724, разбор ключей в начале, CSS ниже |
| Значки заголовка: откуда берутся | `install_fluent_glyphs` — строка 1025, адрес в $FLUENT_ICONS |
| Почему значков не видно | `diagnose_buttons` — строка 612 |
| Скругление окон и меню | `cmd_corners` — строка 1131 |
| Тема окон, схема, переключение светлая/тёмная | `cmd_theme` — строка 1877 |
| Разбор имени темы на варианты | `theme_variant_of` — строка 1570, рядом theme_base_of, theme_swap_variant |
| Поиск парного варианта темы | `theme_find_variant` — строка 1652 |
| Добавить тему в банк | `theme_repo_for` — строка 1240, плюс themes_bank ниже |
| Список и установка тем банка | `cmd_themes` — строка 1317 |
| Проверка темы на совместимость с кнопками | `themes_check` — строка 1408 |
| Тема значков и цвет папок | `cmd_icons` — строка 2215 |
| Шрифты интерфейса | `cmd_font` — строка 2342 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 2437 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 2654 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 2824, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 2781 |
| Смена обоев по порядку | `cmd_wall` — строка 3551 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 3222 |
| Чистка банка обоев | `prune_wallpapers` — строка 3482 |
| Горячие клавиши | `cmd_keys` — строка 4645 |
| Панель Dash to Panel | `cmd_panel` — строка 4703 |
| Своя тема для приложения | `cmd_app` — строка 3673 |
| Локальная апка по http | `cmd_serve` — строка 3820 |
| Откат: общая логика | `cmd_revert` — строка 4230 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 4214 |
| Что показывает status | `cmd_status` — строка 3933 |
| Полный перечень изменяемого | `help_settings` — строка 6768 |
| Общий текст справки | `usage` — строка 6724 |
| Диспетчер команд (добавить новую) | ищи `случай) cmd_` в самом конце файла: `grep -n 'cmd_status "$@"' desktop-kit.sh` |
| Правила предшественника look.sh | `strip_legacy_css` — строка 370 |
| Резервные копии и откат файлов | `backup_once` 167, `restore_backup` 197 |
| Блоки правил в gtk.css | `css_append` 434, `css_strip` 336 |
| Запомнить значение для отката | `remember` 302 / `recall` 318 |
| Наши текущие настройки | `state_set` 272 / `state_get` 287 |

## Команды

| Команда | Реализация | Справка | Тесты |
|---|---|---|---|
| `buttons` | 724 | 568 | 5886 |
| `corners` | 1131 | 1117 | 6031 |
| `theme` | 1877 | 1195 | 6058 |
| `themes` | 1317 | 1271 | 6633 |
| `icons` | 2215 | 2180 | 6206 |
| `font` | 2342 | 2329 | 6240 |
| `widget` | 2437 | 2412 | 6272 |
| `terminal` | 2654 | 2627 | 6317 |
| `newtab` | 2824 | 2803 | 6346 |
| `wallpapers` | 3222 | 3181 | 6423 |
| `wall` | 3551 | 3526 | 6389 |
| `serve` | 3820 | 3800 | 6555 |
| `app` | 3673 | 3655 | 6537 |
| `keys` | 4645 | 4457 | 6465 |
| `panel` | 4703 | 4683 | 6509 |
| `audit` | 4779 | — | — |
| `status` | 3933 | — | — |
| `selftest` | 5363 | 4795 | — |
| `revert` | 4230 | 4026 | 6576 |

## Секции файла

    3  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
    5  Одна команда на каждую подсистему, единый откат, единый лог,
    6  самопроверка прямо на рабочей машине.
    15  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
    565  buttons — кнопки заголовка окна
    1114  corners — скругление окон
    1192  theme — тема GTK
    1261  themes — банк готовых тем
    2177  icons — тема значков и цвет папок
    2326  font — шрифт интерфейса
    2409  widget — виджет conky
    2624  terminal — GNOME Terminal
    2776  newtab — страница новой вкладки Chrome
    3133  wallpapers / wall — банк обоев и смена
    3652  app — тема отдельного приложения
    3797  serve — локальная апка по http
    3930  status — что применено
    4023  revert — откат
    4454  keys — горячие клавиши
    4680  panel — Dash to Panel
    4776  audit — снимок системы
    4792  selftest — проверка на живой машине
    4833  Каркас самопроверки: песочница с подставными внешними программами
    6721  help и диспетчер

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
    270  KIT_STATE="$STATE_DIR/state.env"
    355  LEGACY_CSS_MARK="look-begin"
    356  LEGACY_ICON_SUFFIX="-Fluent-Titlebar"
    1470  THEME_INSTALLED=""
    1472  THEME_VARIANT_PICKED=""
    1477  THEME_DARK_SUFFIXES="-Darker -darker -Dark -dark -DARK -Black -black"
    1478  THEME_LIGHT_SUFFIXES="-Lighter -lighter -Light -light -LIGHT -White -white"
    1520  THEME_DARK_WORDS="darker dark black"
    1521  THEME_LIGHT_WORDS="lighter light white"

## Где генерируется CSS

    827  css_append buttons "$CSS3" "$(cat <<EOF
    843  css_append buttons "$CSS4" "$(cat <<EOF
    864  css_append buttons "$CSS3" "$(cat <<EOF
    932  css_append buttons "$CSS4" "$(cat <<EOF
    1154  css_append corners "$CSS3" "$(cat <<EOF
    1172  css_append corners "$CSS4" "$(cat <<EOF

Селекторы, которые чаще всего правятся:
    829  headerbar button.titlebutton,
    831  button.titlebutton {
    836  headerbar button.titlebutton image,
    838  button.titlebutton image {
    845  windowcontrols > button,
    851  windowcontrols > button > image {
    867  headerbar button.titlebutton,
    869  button.titlebutton {
    877  headerbar button.titlebutton image,
    879  button.titlebutton image {
    888  headerbar button.titlebutton:hover,
    890  button.titlebutton:hover {
    896  headerbar button.titlebutton:hover image,
    897  button.titlebutton:hover image {

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
    state_set BTN_PREV_ICON
    state_set CONKY_ALPHA
    state_set CONKY_INK
    state_set KEYS_OURS

## Самопроверка

    группы:      core buttons corners theme icons font widget terminal newtab wall wallpapers keys panel app serve revert themes help
    каркас:      sandbox_new 4859, sandbox_run 5109
    утверждения: t_eq 5184, t_has 5211, t_out_has 5249, t_rc 5263
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
      143  would
      153  gi_get
      154  gi_set
      161  have
      167  backup_once
      197  restore_backup
      272  state_set
      287  state_get
      302  remember
      318  recall
      336  css_strip
      358  has_legacy_css
      370  strip_legacy_css
      422  icon_base_of
      434  css_append
      453  css_has
      459  untangle_css
      483  untangle_gtk4
      487  untangle_gtk3
      493  restart_gtk_apps
      508  restart_conky
      531  need_args
      540  is_number
      544  is_decimal
      548  is_hex_colour
      552  require_tools
      568  help_buttons
      612  diagnose_buttons
      724  cmd_buttons
      1012 darken_hex
      1025 install_fluent_glyphs
      1117 help_corners
      1131 cmd_corners
      1195 help_theme
      1240 theme_repo_for
      1271 help_themes
      1301 themes_bank
      1317 cmd_themes
      1353 themes_list
      1373 themes_install
      1408 themes_check
      1457 list_themes
      1483 theme_exists
      1494 lower
      1496 theme_real_name
      1508 theme_exists_ci
      1527 theme_tokens
      1538 theme_token
      1542 theme_variant_pos
      1570 theme_variant_of
      1592 theme_rebuild
      1626 theme_base_of
      1640 theme_swap_variant
      1652 theme_find_variant
      1725 theme_light_by_sibling
      1744 theme_has_dark_sibling
      1756 theme_list_variants
      1784 theme_switch_variant
      1877 cmd_theme
      2089 install_theme_check_symlink
      2097 install_theme
      2180 help_icons
      2203 list_icon_themes
      2215 cmd_icons
      2329 help_font
      2342 cmd_font
      2412 help_widget
      2437 cmd_widget
      2599 conf_value
      2611 hex_brightness
      2627 help_terminal
      2645 term_profile
      2654 cmd_terminal
      2750 apply_wal_palette
      2781 newtab_tiles_plain
      2803 help_newtab
      2824 cmd_newtab
      2908 rebuild_newtab
      3119 tick
      3136 find_wallpaper_dir
      3151 current_wallpaper
      3169 detect_resolution
      3181 help_wallpapers
      3204 week_themes
      3213 wallpaper_urls
      3222 cmd_wallpapers
      3414 install_wallpaper_timer
      3482 prune_wallpapers
      3526 help_wall
      3551 cmd_wall
      3655 help_app
      3673 cmd_app
      3800 help_serve
      3820 cmd_serve
      3933 cmd_status
      4026 help_revert
      4062 revert_terminal
      4100 revert_panel
      4123 revert_app
      4157 revert_keys
      4193 revert_serve
      4214 revert_gi_keys
      4230 cmd_revert
      4457 help_keys
      4483 keys_list_paths
      4488 keys_show
      4512 keys_add
      4598 keys_remove
      4645 cmd_keys
      4683 help_panel
      4703 cmd_panel
      4779 cmd_audit
      4795 help_selftest
      4852 sb_write_stub
      4859 sandbox_new
      5082 sb_set
      5093 sb_get
      5101 sb_dconf
      5109 sandbox_run
      5135 sandbox_verify
      5159 sandbox_run_no
      5167 sandbox_drop
      5184 t_eq
      5198 t_ne
      5211 t_has
      5231 t_hasnt
      5249 t_out_has
      5263 t_rc
      5277 t_rc_not
      5303 t_file
      5315 t_nofile
      5334 t_group
      5343 t_ok
      5345 t_fail
      5350 t_skip
      5355 t_detail
      5363 cmd_selftest
      5730 selftest_full
      5773 st_core
      5886 st_buttons
      6031 st_corners
      6058 st_theme
      6206 st_icons
      6240 st_font
      6272 st_widget
      6317 st_terminal
      6346 st_newtab
      6389 st_wall
      6423 st_wallpapers
      6465 st_keys
      6509 st_panel
      6537 st_app
      6555 st_serve
      6576 st_revert
      6633 st_themes
      6669 st_help
      6724 usage
      6768 help_settings
      6841 cmd_help
