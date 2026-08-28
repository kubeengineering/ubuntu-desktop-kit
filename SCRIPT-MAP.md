# Карта desktop-kit.sh

Всего 7817 строк, 303 КБ, примерно 103 тыс. токенов целиком.

**Не читай файл целиком.** Найди место здесь или через `grep -n`, потом
`Read` с `offset`/`limit` на 40–80 строк и `Edit` по найденному фрагменту.

Пересобрать карту после правок: `bash tools/make-map.sh > SCRIPT-MAP.md`

## Рецепты: что где править

| Задача | Куда смотреть |
|---|---|
| Размер, цвет, подсветка кнопок заголовка | `cmd_buttons` — строка 889, разбор ключей в начале, CSS ниже |
| Значки заголовка: откуда берутся | `install_fluent_glyphs` — строка 1195, адрес в $FLUENT_ICONS |
| Почему значков не видно | `diagnose_buttons` — строка 758 |
| Скругление окон и меню | `cmd_corners` — строка 1725 |
| Тема окон, схема, переключение светлая/тёмная | `cmd_theme` — строка 2507 |
| Разбор имени темы на варианты | `theme_variant_of` — строка 2200, рядом theme_base_of, theme_swap_variant |
| Поиск парного варианта темы | `theme_find_variant` — строка 2282 |
| Добавить тему в банк | `theme_repo_for` — строка 1835, плюс themes_bank ниже |
| Список и установка тем банка | `cmd_themes` — строка 1912 |
| Проверка темы на совместимость с кнопками | `themes_check` — строка 2027 |
| Тема значков и цвет папок | `cmd_icons` — строка 2845 |
| Шрифты интерфейса | `cmd_font` — строка 2972 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 3067 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 3284 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 3454, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 3411 |
| Смена обоев по порядку | `cmd_wall` — строка 4181 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 3852 |
| Чистка банка обоев | `prune_wallpapers` — строка 4112 |
| Горячие клавиши | `cmd_keys` — строка 5275 |
| Панель Dash to Panel | `cmd_panel` — строка 5333 |
| Своя тема для приложения | `cmd_app` — строка 4303 |
| Локальная апка по http | `cmd_serve` — строка 4450 |
| Откат: общая логика | `cmd_revert` — строка 4860 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 4844 |
| Что показывает status | `cmd_status` — строка 4563 |
| Полный перечень изменяемого | `help_settings` — строка 7622 |
| Общий текст справки | `usage` — строка 7576 |
| Диспетчер команд (добавить новую) | ищи `случай) cmd_` в самом конце файла: `grep -n 'cmd_status "$@"' desktop-kit.sh` |
| Правила предшественника look.sh | `strip_legacy_css` — строка 516 |
| Резервные копии и откат файлов | `backup_once` 313, `restore_backup` 343 |
| Блоки правил в gtk.css | `css_append` 580, `css_strip` 482 |
| Запомнить значение для отката | `remember` 448 / `recall` 464 |
| Наши текущие настройки | `state_set` 418 / `state_get` 433 |

## Команды

| Команда | Реализация | Справка | Тесты |
|---|---|---|---|
| `buttons` | 889 | 714 | 6549 |
| `corners` | 1725 | 1287 | 6694 |
| `theme` | 2507 | 1790 | 6721 |
| `themes` | 1912 | 1866 | 7296 |
| `icons` | 2845 | 2810 | 6869 |
| `font` | 2972 | 2959 | 6903 |
| `widget` | 3067 | 3042 | 6935 |
| `terminal` | 3284 | 3257 | 6980 |
| `newtab` | 3454 | 3433 | 7009 |
| `wallpapers` | 3852 | 3811 | 7086 |
| `wall` | 4181 | 4156 | 7052 |
| `serve` | 4450 | 4430 | 7218 |
| `app` | 4303 | 4285 | 7200 |
| `keys` | 5275 | 5087 | 7128 |
| `panel` | 5333 | 5313 | 7172 |
| `audit` | 5409 | — | — |
| `status` | 4563 | — | — |
| `selftest` | 6007 | 5425 | — |
| `revert` | 4860 | 4656 | 7239 |

## Секции файла

    3  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
    5  Одна команда на каждую подсистему, единый откат, единый лог,
    6  самопроверка прямо на рабочей машине.
    15  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
    144  Вопросы пользователю
    711  buttons — кнопки заголовка окна
    1284  corners — скругление окон
    1302  tune — настройка вопросами
    1787  theme — тема GTK
    1856  themes — банк готовых тем
    2807  icons — тема значков и цвет папок
    2956  font — шрифт интерфейса
    3039  widget — виджет conky
    3254  terminal — GNOME Terminal
    3406  newtab — страница новой вкладки Chrome
    3763  wallpapers / wall — банк обоев и смена
    4282  app — тема отдельного приложения
    4427  serve — локальная апка по http
    4560  status — что применено
    4653  revert — откат
    5084  keys — горячие клавиши
    5310  panel — Dash to Panel
    5406  audit — снимок системы
    5422  selftest — проверка на живой машине
    5465  Каркас самопроверки: песочница с подставными внешними программами
    7573  help и диспетчер

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
    152  ASK_ANSWER=""
    416  KIT_STATE="$STATE_DIR/state.env"
    501  LEGACY_CSS_MARK="look-begin"
    502  LEGACY_ICON_SUFFIX="-Fluent-Titlebar"
    2100  THEME_INSTALLED=""
    2102  THEME_VARIANT_PICKED=""
    2107  THEME_DARK_SUFFIXES="-Darker -darker -Dark -dark -DARK -Black -black"
    2108  THEME_LIGHT_SUFFIXES="-Lighter -lighter -Light -light -LIGHT -White -white"
    2150  THEME_DARK_WORDS="darker dark black"

## Где генерируется CSS

    992  css_append buttons "$CSS3" "$(cat <<EOF
    1008  css_append buttons "$CSS4" "$(cat <<EOF
    1030  css_append buttons "$CSS3" "$(cat <<EOF
    1098  css_append buttons "$CSS4" "$(cat <<EOF
    1748  css_append corners "$CSS3" "$(cat <<EOF
    1766  css_append corners "$CSS4" "$(cat <<EOF

Селекторы, которые чаще всего правятся:
    994  headerbar button.titlebutton,
    996  button.titlebutton {
    1001  headerbar button.titlebutton image,
    1003  button.titlebutton image {
    1010  windowcontrols > button,
    1016  windowcontrols > button > image {
    1033  headerbar button.titlebutton,
    1035  button.titlebutton {
    1043  headerbar button.titlebutton image,
    1045  button.titlebutton image {
    1054  headerbar button.titlebutton:hover,
    1056  button.titlebutton:hover {
    1062  headerbar button.titlebutton:hover image,
    1063  button.titlebutton:hover image {

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

    группы:      core buttons corners theme icons font widget terminal newtab wall wallpapers keys panel app serve revert themes refresh tune report help
    каркас:      sandbox_new 5491, sandbox_run 5741
    утверждения: t_eq 5816, t_has 5843, t_out_has 5893, t_rc 5907
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
      155  ask_possible
      167  ask_head
      176  ask_num
      213  ask_pick
      259  ask_str
      277  ask_yes
      289  would
      299  gi_get
      300  gi_set
      307  have
      313  backup_once
      343  restore_backup
      418  state_set
      433  state_get
      448  remember
      464  recall
      482  css_strip
      504  has_legacy_css
      516  strip_legacy_css
      568  icon_base_of
      580  css_append
      599  css_has
      605  untangle_css
      629  untangle_gtk4
      633  untangle_gtk3
      639  restart_gtk_apps
      654  restart_conky
      677  need_args
      686  is_number
      690  is_decimal
      694  is_hex_colour
      698  require_tools
      714  help_buttons
      758  diagnose_buttons
      873  buttons_args
      889  cmd_buttons
      1182 darken_hex
      1195 install_fluent_glyphs
      1287 help_corners
      1305 help_tune
      1325 tune_recap
      1331 cmd_tune
      1380 tune_corners
      1408 tune_buttons
      1468 tune_widget
      1534 tune_newtab
      1598 tune_terminal
      1627 tune_theme
      1640 tune_font
      1649 help_refresh
      1666 cmd_refresh
      1725 cmd_corners
      1790 help_theme
      1835 theme_repo_for
      1866 help_themes
      1896 themes_bank
      1912 cmd_themes
      1948 themes_list
      1968 themes_install
      2027 themes_check
      2087 list_themes
      2113 theme_exists
      2124 lower
      2126 theme_real_name
      2138 theme_exists_ci
      2157 theme_tokens
      2168 theme_token
      2172 theme_variant_pos
      2200 theme_variant_of
      2222 theme_rebuild
      2256 theme_base_of
      2270 theme_swap_variant
      2282 theme_find_variant
      2355 theme_light_by_sibling
      2374 theme_has_dark_sibling
      2386 theme_list_variants
      2414 theme_switch_variant
      2507 cmd_theme
      2719 install_theme_check_symlink
      2727 install_theme
      2810 help_icons
      2833 list_icon_themes
      2845 cmd_icons
      2959 help_font
      2972 cmd_font
      3042 help_widget
      3067 cmd_widget
      3229 conf_value
      3241 hex_brightness
      3257 help_terminal
      3275 term_profile
      3284 cmd_terminal
      3380 apply_wal_palette
      3411 newtab_tiles_plain
      3433 help_newtab
      3454 cmd_newtab
      3538 rebuild_newtab
      3749 tick
      3766 find_wallpaper_dir
      3781 current_wallpaper
      3799 detect_resolution
      3811 help_wallpapers
      3834 week_themes
      3843 wallpaper_urls
      3852 cmd_wallpapers
      4044 install_wallpaper_timer
      4112 prune_wallpapers
      4156 help_wall
      4181 cmd_wall
      4285 help_app
      4303 cmd_app
      4430 help_serve
      4450 cmd_serve
      4563 cmd_status
      4656 help_revert
      4692 revert_terminal
      4730 revert_panel
      4753 revert_app
      4787 revert_keys
      4823 revert_serve
      4844 revert_gi_keys
      4860 cmd_revert
      5087 help_keys
      5113 keys_list_paths
      5118 keys_show
      5142 keys_add
      5228 keys_remove
      5275 cmd_keys
      5313 help_panel
      5333 cmd_panel
      5409 cmd_audit
      5425 help_selftest
      5484 sb_write_stub
      5491 sandbox_new
      5714 sb_set
      5725 sb_get
      5733 sb_dconf
      5741 sandbox_run
      5767 sandbox_verify
      5791 sandbox_run_no
      5799 sandbox_drop
      5816 t_eq
      5830 t_ne
      5843 t_has
      5863 t_hasnt
      5881 t_hasnt_out
      5893 t_out_has
      5907 t_rc
      5921 t_rc_not
      5947 t_file
      5959 t_nofile
      5978 t_group
      5987 t_ok
      5989 t_fail
      5994 t_skip
      5999 t_detail
      6007 cmd_selftest
      6393 selftest_full
      6436 st_core
      6549 st_buttons
      6694 st_corners
      6721 st_theme
      6869 st_icons
      6903 st_font
      6935 st_widget
      6980 st_terminal
      7009 st_newtab
      7052 st_wall
      7086 st_wallpapers
      7128 st_keys
      7172 st_panel
      7200 st_app
      7218 st_serve
      7239 st_revert
      7296 st_themes
      7338 st_refresh
      7386 st_tune
      7467 st_report
      7521 st_help
      7576 usage
      7622 help_settings
      7695 cmd_help
