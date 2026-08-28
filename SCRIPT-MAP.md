# Карта desktop-kit.sh

Всего 7659 строк, 296 КБ, примерно 101 тыс. токенов целиком.

**Не читай файл целиком.** Найди место здесь или через `grep -n`, потом
`Read` с `offset`/`limit` на 40–80 строк и `Edit` по найденному фрагменту.

Пересобрать карту после правок: `bash tools/make-map.sh > SCRIPT-MAP.md`

## Рецепты: что где править

| Задача | Куда смотреть |
|---|---|
| Размер, цвет, подсветка кнопок заголовка | `cmd_buttons` — строка 870, разбор ключей в начале, CSS ниже |
| Значки заголовка: откуда берутся | `install_fluent_glyphs` — строка 1176, адрес в $FLUENT_ICONS |
| Почему значков не видно | `diagnose_buttons` — строка 758 |
| Скругление окон и меню | `cmd_corners` — строка 1697 |
| Тема окон, схема, переключение светлая/тёмная | `cmd_theme` — строка 2468 |
| Разбор имени темы на варианты | `theme_variant_of` — строка 2161, рядом theme_base_of, theme_swap_variant |
| Поиск парного варианта темы | `theme_find_variant` — строка 2243 |
| Добавить тему в банк | `theme_repo_for` — строка 1807, плюс themes_bank ниже |
| Список и установка тем банка | `cmd_themes` — строка 1884 |
| Проверка темы на совместимость с кнопками | `themes_check` — строка 1999 |
| Тема значков и цвет папок | `cmd_icons` — строка 2806 |
| Шрифты интерфейса | `cmd_font` — строка 2933 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 3028 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 3245 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 3415, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 3372 |
| Смена обоев по порядку | `cmd_wall` — строка 4142 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 3813 |
| Чистка банка обоев | `prune_wallpapers` — строка 4073 |
| Горячие клавиши | `cmd_keys` — строка 5236 |
| Панель Dash to Panel | `cmd_panel` — строка 5294 |
| Своя тема для приложения | `cmd_app` — строка 4264 |
| Локальная апка по http | `cmd_serve` — строка 4411 |
| Откат: общая логика | `cmd_revert` — строка 4821 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 4805 |
| Что показывает status | `cmd_status` — строка 4524 |
| Полный перечень изменяемого | `help_settings` — строка 7464 |
| Общий текст справки | `usage` — строка 7418 |
| Диспетчер команд (добавить новую) | ищи `случай) cmd_` в самом конце файла: `grep -n 'cmd_status "$@"' desktop-kit.sh` |
| Правила предшественника look.sh | `strip_legacy_css` — строка 516 |
| Резервные копии и откат файлов | `backup_once` 313, `restore_backup` 343 |
| Блоки правил в gtk.css | `css_append` 580, `css_strip` 482 |
| Запомнить значение для отката | `remember` 448 / `recall` 464 |
| Наши текущие настройки | `state_set` 418 / `state_get` 433 |

## Команды

| Команда | Реализация | Справка | Тесты |
|---|---|---|---|
| `buttons` | 870 | 714 | 6477 |
| `corners` | 1697 | 1268 | 6622 |
| `theme` | 2468 | 1762 | 6649 |
| `themes` | 1884 | 1838 | 7224 |
| `icons` | 2806 | 2771 | 6797 |
| `font` | 2933 | 2920 | 6831 |
| `widget` | 3028 | 3003 | 6863 |
| `terminal` | 3245 | 3218 | 6908 |
| `newtab` | 3415 | 3394 | 6937 |
| `wallpapers` | 3813 | 3772 | 7014 |
| `wall` | 4142 | 4117 | 6980 |
| `serve` | 4411 | 4391 | 7146 |
| `app` | 4264 | 4246 | 7128 |
| `keys` | 5236 | 5048 | 7056 |
| `panel` | 5294 | 5274 | 7100 |
| `audit` | 5370 | — | — |
| `status` | 4524 | — | — |
| `selftest` | 5954 | 5386 | — |
| `revert` | 4821 | 4617 | 7167 |

## Секции файла

    3  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
    5  Одна команда на каждую подсистему, единый откат, единый лог,
    6  самопроверка прямо на рабочей машине.
    15  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
    144  Вопросы пользователю
    711  buttons — кнопки заголовка окна
    1265  corners — скругление окон
    1283  tune — настройка вопросами
    1759  theme — тема GTK
    1828  themes — банк готовых тем
    2768  icons — тема значков и цвет папок
    2917  font — шрифт интерфейса
    3000  widget — виджет conky
    3215  terminal — GNOME Terminal
    3367  newtab — страница новой вкладки Chrome
    3724  wallpapers / wall — банк обоев и смена
    4243  app — тема отдельного приложения
    4388  serve — локальная апка по http
    4521  status — что применено
    4614  revert — откат
    5045  keys — горячие клавиши
    5271  panel — Dash to Panel
    5367  audit — снимок системы
    5383  selftest — проверка на живой машине
    5424  Каркас самопроверки: песочница с подставными внешними программами
    7415  help и диспетчер

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
    2061  THEME_INSTALLED=""
    2063  THEME_VARIANT_PICKED=""
    2068  THEME_DARK_SUFFIXES="-Darker -darker -Dark -dark -DARK -Black -black"
    2069  THEME_LIGHT_SUFFIXES="-Lighter -lighter -Light -light -LIGHT -White -white"
    2111  THEME_DARK_WORDS="darker dark black"

## Где генерируется CSS

    973  css_append buttons "$CSS3" "$(cat <<EOF
    989  css_append buttons "$CSS4" "$(cat <<EOF
    1011  css_append buttons "$CSS3" "$(cat <<EOF
    1079  css_append buttons "$CSS4" "$(cat <<EOF
    1720  css_append corners "$CSS3" "$(cat <<EOF
    1738  css_append corners "$CSS4" "$(cat <<EOF

Селекторы, которые чаще всего правятся:
    975  headerbar button.titlebutton,
    977  button.titlebutton {
    982  headerbar button.titlebutton image,
    984  button.titlebutton image {
    991  windowcontrols > button,
    997  windowcontrols > button > image {
    1014  headerbar button.titlebutton,
    1016  button.titlebutton {
    1024  headerbar button.titlebutton image,
    1026  button.titlebutton image {
    1035  headerbar button.titlebutton:hover,
    1037  button.titlebutton:hover {
    1043  headerbar button.titlebutton:hover image,
    1044  button.titlebutton:hover image {

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

    группы:      core buttons corners theme icons font widget terminal newtab wall wallpapers keys panel app serve revert themes refresh tune help
    каркас:      sandbox_new 5450, sandbox_run 5700
    утверждения: t_eq 5775, t_has 5802, t_out_has 5840, t_rc 5854
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
      870  cmd_buttons
      1163 darken_hex
      1176 install_fluent_glyphs
      1268 help_corners
      1286 help_tune
      1306 tune_recap
      1312 cmd_tune
      1361 tune_corners
      1389 tune_buttons
      1449 tune_widget
      1515 tune_newtab
      1579 tune_terminal
      1608 tune_theme
      1621 tune_font
      1630 help_refresh
      1647 cmd_refresh
      1697 cmd_corners
      1762 help_theme
      1807 theme_repo_for
      1838 help_themes
      1868 themes_bank
      1884 cmd_themes
      1920 themes_list
      1940 themes_install
      1999 themes_check
      2048 list_themes
      2074 theme_exists
      2085 lower
      2087 theme_real_name
      2099 theme_exists_ci
      2118 theme_tokens
      2129 theme_token
      2133 theme_variant_pos
      2161 theme_variant_of
      2183 theme_rebuild
      2217 theme_base_of
      2231 theme_swap_variant
      2243 theme_find_variant
      2316 theme_light_by_sibling
      2335 theme_has_dark_sibling
      2347 theme_list_variants
      2375 theme_switch_variant
      2468 cmd_theme
      2680 install_theme_check_symlink
      2688 install_theme
      2771 help_icons
      2794 list_icon_themes
      2806 cmd_icons
      2920 help_font
      2933 cmd_font
      3003 help_widget
      3028 cmd_widget
      3190 conf_value
      3202 hex_brightness
      3218 help_terminal
      3236 term_profile
      3245 cmd_terminal
      3341 apply_wal_palette
      3372 newtab_tiles_plain
      3394 help_newtab
      3415 cmd_newtab
      3499 rebuild_newtab
      3710 tick
      3727 find_wallpaper_dir
      3742 current_wallpaper
      3760 detect_resolution
      3772 help_wallpapers
      3795 week_themes
      3804 wallpaper_urls
      3813 cmd_wallpapers
      4005 install_wallpaper_timer
      4073 prune_wallpapers
      4117 help_wall
      4142 cmd_wall
      4246 help_app
      4264 cmd_app
      4391 help_serve
      4411 cmd_serve
      4524 cmd_status
      4617 help_revert
      4653 revert_terminal
      4691 revert_panel
      4714 revert_app
      4748 revert_keys
      4784 revert_serve
      4805 revert_gi_keys
      4821 cmd_revert
      5048 help_keys
      5074 keys_list_paths
      5079 keys_show
      5103 keys_add
      5189 keys_remove
      5236 cmd_keys
      5274 help_panel
      5294 cmd_panel
      5370 cmd_audit
      5386 help_selftest
      5443 sb_write_stub
      5450 sandbox_new
      5673 sb_set
      5684 sb_get
      5692 sb_dconf
      5700 sandbox_run
      5726 sandbox_verify
      5750 sandbox_run_no
      5758 sandbox_drop
      5775 t_eq
      5789 t_ne
      5802 t_has
      5822 t_hasnt
      5840 t_out_has
      5854 t_rc
      5868 t_rc_not
      5894 t_file
      5906 t_nofile
      5925 t_group
      5934 t_ok
      5936 t_fail
      5941 t_skip
      5946 t_detail
      5954 cmd_selftest
      6321 selftest_full
      6364 st_core
      6477 st_buttons
      6622 st_corners
      6649 st_theme
      6797 st_icons
      6831 st_font
      6863 st_widget
      6908 st_terminal
      6937 st_newtab
      6980 st_wall
      7014 st_wallpapers
      7056 st_keys
      7100 st_panel
      7128 st_app
      7146 st_serve
      7167 st_revert
      7224 st_themes
      7260 st_refresh
      7302 st_tune
      7363 st_help
      7418 usage
      7464 help_settings
      7537 cmd_help
