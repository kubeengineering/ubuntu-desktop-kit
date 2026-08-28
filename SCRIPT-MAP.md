# Карта desktop-kit.sh

Всего 6939 строк, 270 КБ, примерно 92 тыс. токенов целиком.

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
| Тема окон, схема, переключение светлая/тёмная | `cmd_theme` — строка 1859 |
| Разбор имени темы на варианты | `theme_variant_of` — строка 1570, рядом theme_base_of, theme_swap_variant |
| Поиск парного варианта темы | `theme_find_variant` — строка 1652 |
| Добавить тему в банк | `theme_repo_for` — строка 1240, плюс themes_bank ниже |
| Список и установка тем банка | `cmd_themes` — строка 1317 |
| Проверка темы на совместимость с кнопками | `themes_check` — строка 1408 |
| Тема значков и цвет папок | `cmd_icons` — строка 2197 |
| Шрифты интерфейса | `cmd_font` — строка 2324 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 2419 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 2636 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 2806, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 2763 |
| Смена обоев по порядку | `cmd_wall` — строка 3533 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 3204 |
| Чистка банка обоев | `prune_wallpapers` — строка 3464 |
| Горячие клавиши | `cmd_keys` — строка 4627 |
| Панель Dash to Panel | `cmd_panel` — строка 4685 |
| Своя тема для приложения | `cmd_app` — строка 3655 |
| Локальная апка по http | `cmd_serve` — строка 3802 |
| Откат: общая логика | `cmd_revert` — строка 4212 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 4196 |
| Что показывает status | `cmd_status` — строка 3915 |
| Полный перечень изменяемого | `help_settings` — строка 6750 |
| Общий текст справки | `usage` — строка 6706 |
| Диспетчер команд (добавить новую) | ищи `случай) cmd_` в самом конце файла: `grep -n 'cmd_status "$@"' desktop-kit.sh` |
| Правила предшественника look.sh | `strip_legacy_css` — строка 370 |
| Резервные копии и откат файлов | `backup_once` 167, `restore_backup` 197 |
| Блоки правил в gtk.css | `css_append` 434, `css_strip` 336 |
| Запомнить значение для отката | `remember` 302 / `recall` 318 |
| Наши текущие настройки | `state_set` 272 / `state_get` 287 |

## Команды

| Команда | Реализация | Справка | Тесты |
|---|---|---|---|
| `buttons` | 724 | 568 | 5868 |
| `corners` | 1131 | 1117 | 6013 |
| `theme` | 1859 | 1195 | 6040 |
| `themes` | 1317 | 1271 | 6615 |
| `icons` | 2197 | 2162 | 6188 |
| `font` | 2324 | 2311 | 6222 |
| `widget` | 2419 | 2394 | 6254 |
| `terminal` | 2636 | 2609 | 6299 |
| `newtab` | 2806 | 2785 | 6328 |
| `wallpapers` | 3204 | 3163 | 6405 |
| `wall` | 3533 | 3508 | 6371 |
| `serve` | 3802 | 3782 | 6537 |
| `app` | 3655 | 3637 | 6519 |
| `keys` | 4627 | 4439 | 6447 |
| `panel` | 4685 | 4665 | 6491 |
| `audit` | 4761 | — | — |
| `status` | 3915 | — | — |
| `selftest` | 5345 | 4777 | — |
| `revert` | 4212 | 4008 | 6558 |

## Секции файла

    3  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
    5  Одна команда на каждую подсистему, единый откат, единый лог,
    6  самопроверка прямо на рабочей машине.
    15  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
    565  buttons — кнопки заголовка окна
    1114  corners — скругление окон
    1192  theme — тема GTK
    1261  themes — банк готовых тем
    2159  icons — тема значков и цвет папок
    2308  font — шрифт интерфейса
    2391  widget — виджет conky
    2606  terminal — GNOME Terminal
    2758  newtab — страница новой вкладки Chrome
    3115  wallpapers / wall — банк обоев и смена
    3634  app — тема отдельного приложения
    3779  serve — локальная апка по http
    3912  status — что применено
    4005  revert — откат
    4436  keys — горячие клавиши
    4662  panel — Dash to Panel
    4758  audit — снимок системы
    4774  selftest — проверка на живой машине
    4815  Каркас самопроверки: песочница с подставными внешними программами
    6703  help и диспетчер

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
    каркас:      sandbox_new 4841, sandbox_run 5091
    утверждения: t_eq 5166, t_has 5193, t_out_has 5231, t_rc 5245
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
      1859 cmd_theme
      2071 install_theme_check_symlink
      2079 install_theme
      2162 help_icons
      2185 list_icon_themes
      2197 cmd_icons
      2311 help_font
      2324 cmd_font
      2394 help_widget
      2419 cmd_widget
      2581 conf_value
      2593 hex_brightness
      2609 help_terminal
      2627 term_profile
      2636 cmd_terminal
      2732 apply_wal_palette
      2763 newtab_tiles_plain
      2785 help_newtab
      2806 cmd_newtab
      2890 rebuild_newtab
      3101 tick
      3118 find_wallpaper_dir
      3133 current_wallpaper
      3151 detect_resolution
      3163 help_wallpapers
      3186 week_themes
      3195 wallpaper_urls
      3204 cmd_wallpapers
      3396 install_wallpaper_timer
      3464 prune_wallpapers
      3508 help_wall
      3533 cmd_wall
      3637 help_app
      3655 cmd_app
      3782 help_serve
      3802 cmd_serve
      3915 cmd_status
      4008 help_revert
      4044 revert_terminal
      4082 revert_panel
      4105 revert_app
      4139 revert_keys
      4175 revert_serve
      4196 revert_gi_keys
      4212 cmd_revert
      4439 help_keys
      4465 keys_list_paths
      4470 keys_show
      4494 keys_add
      4580 keys_remove
      4627 cmd_keys
      4665 help_panel
      4685 cmd_panel
      4761 cmd_audit
      4777 help_selftest
      4834 sb_write_stub
      4841 sandbox_new
      5064 sb_set
      5075 sb_get
      5083 sb_dconf
      5091 sandbox_run
      5117 sandbox_verify
      5141 sandbox_run_no
      5149 sandbox_drop
      5166 t_eq
      5180 t_ne
      5193 t_has
      5213 t_hasnt
      5231 t_out_has
      5245 t_rc
      5259 t_rc_not
      5285 t_file
      5297 t_nofile
      5316 t_group
      5325 t_ok
      5327 t_fail
      5332 t_skip
      5337 t_detail
      5345 cmd_selftest
      5712 selftest_full
      5755 st_core
      5868 st_buttons
      6013 st_corners
      6040 st_theme
      6188 st_icons
      6222 st_font
      6254 st_widget
      6299 st_terminal
      6328 st_newtab
      6371 st_wall
      6405 st_wallpapers
      6447 st_keys
      6491 st_panel
      6519 st_app
      6537 st_serve
      6558 st_revert
      6615 st_themes
      6651 st_help
      6706 usage
      6750 help_settings
      6823 cmd_help
