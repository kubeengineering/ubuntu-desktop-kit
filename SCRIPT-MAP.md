# Карта desktop-kit.sh

Всего 7101 строк, 277 КБ, примерно 94 тыс. токенов целиком.

**Не читай файл целиком.** Найди место здесь или через `grep -n`, потом
`Read` с `offset`/`limit` на 40–80 строк и `Edit` по найденному фрагменту.

Пересобрать карту после правок: `bash tools/make-map.sh > SCRIPT-MAP.md`

## Рецепты: что где править

| Задача | Куда смотреть |
|---|---|
| Размер, цвет, подсветка кнопок заголовка | `cmd_buttons` — строка 724, разбор ключей в начале, CSS ниже |
| Значки заголовка: откуда берутся | `install_fluent_glyphs` — строка 1030, адрес в $FLUENT_ICONS |
| Почему значков не видно | `diagnose_buttons` — строка 612 |
| Скругление окон и меню | `cmd_corners` — строка 1203 |
| Тема окон, схема, переключение светлая/тёмная | `cmd_theme` — строка 1974 |
| Разбор имени темы на варианты | `theme_variant_of` — строка 1667, рядом theme_base_of, theme_swap_variant |
| Поиск парного варианта темы | `theme_find_variant` — строка 1749 |
| Добавить тему в банк | `theme_repo_for` — строка 1313, плюс themes_bank ниже |
| Список и установка тем банка | `cmd_themes` — строка 1390 |
| Проверка темы на совместимость с кнопками | `themes_check` — строка 1505 |
| Тема значков и цвет папок | `cmd_icons` — строка 2312 |
| Шрифты интерфейса | `cmd_font` — строка 2439 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 2534 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 2751 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 2921, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 2878 |
| Смена обоев по порядку | `cmd_wall` — строка 3648 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 3319 |
| Чистка банка обоев | `prune_wallpapers` — строка 3579 |
| Горячие клавиши | `cmd_keys` — строка 4742 |
| Панель Dash to Panel | `cmd_panel` — строка 4800 |
| Своя тема для приложения | `cmd_app` — строка 3770 |
| Локальная апка по http | `cmd_serve` — строка 3917 |
| Откат: общая логика | `cmd_revert` — строка 4327 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 4311 |
| Что показывает status | `cmd_status` — строка 4030 |
| Полный перечень изменяемого | `help_settings` — строка 6908 |
| Общий текст справки | `usage` — строка 6863 |
| Диспетчер команд (добавить новую) | ищи `случай) cmd_` в самом конце файла: `grep -n 'cmd_status "$@"' desktop-kit.sh` |
| Правила предшественника look.sh | `strip_legacy_css` — строка 370 |
| Резервные копии и откат файлов | `backup_once` 167, `restore_backup` 197 |
| Блоки правил в gtk.css | `css_append` 434, `css_strip` 336 |
| Запомнить значение для отката | `remember` 302 / `recall` 318 |
| Наши текущие настройки | `state_set` 272 / `state_get` 287 |

## Команды

| Команда | Реализация | Справка | Тесты |
|---|---|---|---|
| `buttons` | 724 | 568 | 5983 |
| `corners` | 1203 | 1122 | 6128 |
| `theme` | 1974 | 1268 | 6155 |
| `themes` | 1390 | 1344 | 6730 |
| `icons` | 2312 | 2277 | 6303 |
| `font` | 2439 | 2426 | 6337 |
| `widget` | 2534 | 2509 | 6369 |
| `terminal` | 2751 | 2724 | 6414 |
| `newtab` | 2921 | 2900 | 6443 |
| `wallpapers` | 3319 | 3278 | 6520 |
| `wall` | 3648 | 3623 | 6486 |
| `serve` | 3917 | 3897 | 6652 |
| `app` | 3770 | 3752 | 6634 |
| `keys` | 4742 | 4554 | 6562 |
| `panel` | 4800 | 4780 | 6606 |
| `audit` | 4876 | — | — |
| `status` | 4030 | — | — |
| `selftest` | 5460 | 4892 | — |
| `revert` | 4327 | 4123 | 6673 |

## Секции файла

    3  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
    5  Одна команда на каждую подсистему, единый откат, единый лог,
    6  самопроверка прямо на рабочей машине.
    15  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
    565  buttons — кнопки заголовка окна
    1119  corners — скругление окон
    1265  theme — тема GTK
    1334  themes — банк готовых тем
    2274  icons — тема значков и цвет папок
    2423  font — шрифт интерфейса
    2506  widget — виджет conky
    2721  terminal — GNOME Terminal
    2873  newtab — страница новой вкладки Chrome
    3230  wallpapers / wall — банк обоев и смена
    3749  app — тема отдельного приложения
    3894  serve — локальная апка по http
    4027  status — что применено
    4120  revert — откат
    4551  keys — горячие клавиши
    4777  panel — Dash to Panel
    4873  audit — снимок системы
    4889  selftest — проверка на живой машине
    4930  Каркас самопроверки: песочница с подставными внешними программами
    6860  help и диспетчер

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
    1567  THEME_INSTALLED=""
    1569  THEME_VARIANT_PICKED=""
    1574  THEME_DARK_SUFFIXES="-Darker -darker -Dark -dark -DARK -Black -black"
    1575  THEME_LIGHT_SUFFIXES="-Lighter -lighter -Light -light -LIGHT -White -white"
    1617  THEME_DARK_WORDS="darker dark black"
    1618  THEME_LIGHT_WORDS="lighter light white"

## Где генерируется CSS

    827  css_append buttons "$CSS3" "$(cat <<EOF
    843  css_append buttons "$CSS4" "$(cat <<EOF
    865  css_append buttons "$CSS3" "$(cat <<EOF
    933  css_append buttons "$CSS4" "$(cat <<EOF
    1226  css_append corners "$CSS3" "$(cat <<EOF
    1244  css_append corners "$CSS4" "$(cat <<EOF

Селекторы, которые чаще всего правятся:
    829  headerbar button.titlebutton,
    831  button.titlebutton {
    836  headerbar button.titlebutton image,
    838  button.titlebutton image {
    845  windowcontrols > button,
    851  windowcontrols > button > image {
    868  headerbar button.titlebutton,
    870  button.titlebutton {
    878  headerbar button.titlebutton image,
    880  button.titlebutton image {
    889  headerbar button.titlebutton:hover,
    891  button.titlebutton:hover {
    897  headerbar button.titlebutton:hover image,
    898  button.titlebutton:hover image {

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
    state_set BTN_PREV_ICON
    state_set CONKY_ALPHA
    state_set CONKY_INK
    state_set CORNERS_ARGS
    state_set KEYS_OURS

## Самопроверка

    группы:      core buttons corners theme icons font widget terminal newtab wall wallpapers keys panel app serve revert themes refresh help
    каркас:      sandbox_new 4956, sandbox_run 5206
    утверждения: t_eq 5281, t_has 5308, t_out_has 5346, t_rc 5360
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
      1017 darken_hex
      1030 install_fluent_glyphs
      1122 help_corners
      1136 help_refresh
      1153 cmd_refresh
      1203 cmd_corners
      1268 help_theme
      1313 theme_repo_for
      1344 help_themes
      1374 themes_bank
      1390 cmd_themes
      1426 themes_list
      1446 themes_install
      1505 themes_check
      1554 list_themes
      1580 theme_exists
      1591 lower
      1593 theme_real_name
      1605 theme_exists_ci
      1624 theme_tokens
      1635 theme_token
      1639 theme_variant_pos
      1667 theme_variant_of
      1689 theme_rebuild
      1723 theme_base_of
      1737 theme_swap_variant
      1749 theme_find_variant
      1822 theme_light_by_sibling
      1841 theme_has_dark_sibling
      1853 theme_list_variants
      1881 theme_switch_variant
      1974 cmd_theme
      2186 install_theme_check_symlink
      2194 install_theme
      2277 help_icons
      2300 list_icon_themes
      2312 cmd_icons
      2426 help_font
      2439 cmd_font
      2509 help_widget
      2534 cmd_widget
      2696 conf_value
      2708 hex_brightness
      2724 help_terminal
      2742 term_profile
      2751 cmd_terminal
      2847 apply_wal_palette
      2878 newtab_tiles_plain
      2900 help_newtab
      2921 cmd_newtab
      3005 rebuild_newtab
      3216 tick
      3233 find_wallpaper_dir
      3248 current_wallpaper
      3266 detect_resolution
      3278 help_wallpapers
      3301 week_themes
      3310 wallpaper_urls
      3319 cmd_wallpapers
      3511 install_wallpaper_timer
      3579 prune_wallpapers
      3623 help_wall
      3648 cmd_wall
      3752 help_app
      3770 cmd_app
      3897 help_serve
      3917 cmd_serve
      4030 cmd_status
      4123 help_revert
      4159 revert_terminal
      4197 revert_panel
      4220 revert_app
      4254 revert_keys
      4290 revert_serve
      4311 revert_gi_keys
      4327 cmd_revert
      4554 help_keys
      4580 keys_list_paths
      4585 keys_show
      4609 keys_add
      4695 keys_remove
      4742 cmd_keys
      4780 help_panel
      4800 cmd_panel
      4876 cmd_audit
      4892 help_selftest
      4949 sb_write_stub
      4956 sandbox_new
      5179 sb_set
      5190 sb_get
      5198 sb_dconf
      5206 sandbox_run
      5232 sandbox_verify
      5256 sandbox_run_no
      5264 sandbox_drop
      5281 t_eq
      5295 t_ne
      5308 t_has
      5328 t_hasnt
      5346 t_out_has
      5360 t_rc
      5374 t_rc_not
      5400 t_file
      5412 t_nofile
      5431 t_group
      5440 t_ok
      5442 t_fail
      5447 t_skip
      5452 t_detail
      5460 cmd_selftest
      5827 selftest_full
      5870 st_core
      5983 st_buttons
      6128 st_corners
      6155 st_theme
      6303 st_icons
      6337 st_font
      6369 st_widget
      6414 st_terminal
      6443 st_newtab
      6486 st_wall
      6520 st_wallpapers
      6562 st_keys
      6606 st_panel
      6634 st_app
      6652 st_serve
      6673 st_revert
      6730 st_themes
      6766 st_refresh
      6808 st_help
      6863 usage
      6908 help_settings
      6981 cmd_help
