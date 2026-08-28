# Карта desktop-kit.sh

Всего 8296 строк, 322 КБ, примерно 110 тыс. токенов целиком.

**Не читай файл целиком.** Найди место здесь или через `grep -n`, потом
`Read` с `offset`/`limit` на 40–80 строк и `Edit` по найденному фрагменту.

Пересобрать карту после правок: `bash tools/make-map.sh > SCRIPT-MAP.md`

## Рецепты: что где править

| Задача | Куда смотреть |
|---|---|
| Размер, цвет, подсветка кнопок заголовка | `cmd_buttons` — строка 1102, разбор ключей в начале, CSS ниже |
| Значки заголовка: откуда берутся | `install_fluent_glyphs` — строка 1418, адрес в $FLUENT_ICONS |
| Почему значков не видно | `diagnose_buttons` — строка 971 |
| Скругление окон и меню | `cmd_corners` — строка 1953 |
| Тема окон, схема, переключение светлая/тёмная | `cmd_theme` — строка 2745 |
| Разбор имени темы на варианты | `theme_variant_of` — строка 2438, рядом theme_base_of, theme_swap_variant |
| Поиск парного варианта темы | `theme_find_variant` — строка 2520 |
| Добавить тему в банк | `theme_repo_for` — строка 2073, плюс themes_bank ниже |
| Список и установка тем банка | `cmd_themes` — строка 2150 |
| Проверка темы на совместимость с кнопками | `themes_check` — строка 2265 |
| Тема значков и цвет папок | `cmd_icons` — строка 3100 |
| Шрифты интерфейса | `cmd_font` — строка 3227 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 3382 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 3627 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 3829, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 3763 |
| Смена обоев по порядку | `cmd_wall` — строка 4568 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 4239 |
| Чистка банка обоев | `prune_wallpapers` — строка 4499 |
| Горячие клавиши | `cmd_keys` — строка 5662 |
| Панель Dash to Panel | `cmd_panel` — строка 5720 |
| Своя тема для приложения | `cmd_app` — строка 4690 |
| Локальная апка по http | `cmd_serve` — строка 4837 |
| Откат: общая логика | `cmd_revert` — строка 5247 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 5231 |
| Что показывает status | `cmd_status` — строка 4950 |
| Полный перечень изменяемого | `help_settings` — строка 8101 |
| Общий текст справки | `usage` — строка 8046 |
| Диспетчер команд (добавить новую) | ищи `случай) cmd_` в самом конце файла: `grep -n 'cmd_status "$@"' desktop-kit.sh` |
| Правила предшественника look.sh | `strip_legacy_css` — строка 721 |
| Резервные копии и откат файлов | `backup_once` 518, `restore_backup` 548 |
| Блоки правил в gtk.css | `css_append` 785, `css_strip` 687 |
| Запомнить значение для отката | `remember` 653 / `recall` 669 |
| Наши текущие настройки | `state_set` 623 / `state_get` 638 |

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
| `buttons` | 1102 | 919 | 6936 |
| `corners` | 1953 | 1510 | 7081 |
| `theme` | 2745 | 2028 | 7108 |
| `themes` | 2150 | 2104 | 7692 |
| `icons` | 3100 | 3065 | 7256 |
| `font` | 3227 | 3214 | 7290 |
| `widget` | 3382 | 3297 | 7322 |
| `terminal` | 3627 | 3600 | 7367 |
| `newtab` | 3829 | 3785 | 7396 |
| `wallpapers` | 4239 | 4198 | 7480 |
| `wall` | 4568 | 4543 | 7446 |
| `serve` | 4837 | 4817 | 7614 |
| `app` | 4690 | 4672 | 7596 |
| `keys` | 5662 | 5474 | 7522 |
| `panel` | 5720 | 5700 | 7566 |
| `audit` | 5796 | — | — |
| `status` | 4950 | — | — |
| `selftest` | 6394 | 5812 | — |
| `revert` | 5247 | 5043 | 7635 |

## Секции файла

    3  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
    5  Одна команда на каждую подсистему, единый откат, единый лог,
    6  самопроверка прямо на рабочей машине.
    15  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
    144  Обзор команды: что сейчас, что можно
    266  Пресеты: именованные наборы параметров
    349  Вопросы пользователю
    916  buttons — кнопки заголовка окна
    1507  corners — скругление окон
    1530  tune — настройка вопросами
    2025  theme — тема GTK
    2094  themes — банк готовых тем
    3062  icons — тема значков и цвет папок
    3211  font — шрифт интерфейса
    3294  widget — виджет conky
    3597  terminal — GNOME Terminal
    3758  newtab — страница новой вкладки Chrome
    4150  wallpapers / wall — банк обоев и смена
    4669  app — тема отдельного приложения
    4814  serve — локальная апка по http
    4947  status — что применено
    5040  revert — откат
    5471  keys — горячие клавиши
    5697  panel — Dash to Panel
    5793  audit — снимок системы
    5809  selftest — проверка на живой машине
    5852  Каркас самопроверки: песочница с подставными внешними программами
    8043  help и диспетчер

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
    345  PRESET_ARGS=""
    346  PRESET_USED=""
    357  ASK_ANSWER=""
    621  KIT_STATE="$STATE_DIR/state.env"
    706  LEGACY_CSS_MARK="look-begin"
    707  LEGACY_ICON_SUFFIX="-Fluent-Titlebar"
    2338  THEME_INSTALLED=""
    2340  THEME_VARIANT_PICKED=""
    2345  THEME_DARK_SUFFIXES="-Darker -darker -Dark -dark -DARK -Black -black"

## Где генерируется CSS

    1215  css_append buttons "$CSS3" "$(cat <<EOF
    1231  css_append buttons "$CSS4" "$(cat <<EOF
    1253  css_append buttons "$CSS3" "$(cat <<EOF
    1321  css_append buttons "$CSS4" "$(cat <<EOF
    1986  css_append corners "$CSS3" "$(cat <<EOF
    2004  css_append corners "$CSS4" "$(cat <<EOF

Селекторы, которые чаще всего правятся:
    1217  headerbar button.titlebutton,
    1219  button.titlebutton {
    1224  headerbar button.titlebutton image,
    1226  button.titlebutton image {
    1233  windowcontrols > button,
    1239  windowcontrols > button > image {
    1256  headerbar button.titlebutton,
    1258  button.titlebutton {
    1266  headerbar button.titlebutton image,
    1268  button.titlebutton image {
    1277  headerbar button.titlebutton:hover,
    1279  button.titlebutton:hover {
    1285  headerbar button.titlebutton:hover image,
    1286  button.titlebutton:hover image {

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
    каркас:      sandbox_new 5878, sandbox_run 6128
    утверждения: t_eq 6203, t_has 6230, t_out_has 6280, t_rc 6294
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
      275  presets_table
      302  preset_args
      310  presets_names
      315  presets_list
      324  preset_expand
      360  ask_possible
      372  ask_head
      381  ask_num
      418  ask_pick
      464  ask_str
      482  ask_yes
      494  would
      504  gi_get
      505  gi_set
      512  have
      518  backup_once
      548  restore_backup
      623  state_set
      638  state_get
      653  remember
      669  recall
      687  css_strip
      709  has_legacy_css
      721  strip_legacy_css
      773  icon_base_of
      785  css_append
      804  css_has
      810  untangle_css
      834  untangle_gtk4
      838  untangle_gtk3
      844  restart_gtk_apps
      859  restart_conky
      882  need_args
      891  is_number
      895  is_decimal
      899  is_hex_colour
      903  require_tools
      919  help_buttons
      971  diagnose_buttons
      1086 buttons_args
      1102 cmd_buttons
      1405 darken_hex
      1418 install_fluent_glyphs
      1510 help_corners
      1533 help_tune
      1553 tune_recap
      1559 cmd_tune
      1608 tune_corners
      1636 tune_buttons
      1696 tune_widget
      1762 tune_newtab
      1826 tune_terminal
      1855 tune_theme
      1868 tune_font
      1877 help_refresh
      1894 cmd_refresh
      1953 cmd_corners
      2028 help_theme
      2073 theme_repo_for
      2104 help_themes
      2134 themes_bank
      2150 cmd_themes
      2186 themes_list
      2206 themes_install
      2265 themes_check
      2325 list_themes
      2351 theme_exists
      2362 lower
      2364 theme_real_name
      2376 theme_exists_ci
      2395 theme_tokens
      2406 theme_token
      2410 theme_variant_pos
      2438 theme_variant_of
      2460 theme_rebuild
      2494 theme_base_of
      2508 theme_swap_variant
      2520 theme_find_variant
      2593 theme_light_by_sibling
      2612 theme_has_dark_sibling
      2624 theme_list_variants
      2652 theme_switch_variant
      2745 cmd_theme
      2957 install_theme_check_symlink
      2965 install_theme
      3065 help_icons
      3088 list_icon_themes
      3100 cmd_icons
      3214 help_font
      3227 cmd_font
      3297 help_widget
      3326 widget_modules_table
      3338 widget_add_module
      3382 cmd_widget
      3572 conf_value
      3584 hex_brightness
      3600 help_terminal
      3618 term_profile
      3627 cmd_terminal
      3732 apply_wal_palette
      3763 newtab_tiles_plain
      3785 help_newtab
      3807 overview_newtab
      3829 cmd_newtab
      3925 rebuild_newtab
      4136 tick
      4153 find_wallpaper_dir
      4168 current_wallpaper
      4186 detect_resolution
      4198 help_wallpapers
      4221 week_themes
      4230 wallpaper_urls
      4239 cmd_wallpapers
      4431 install_wallpaper_timer
      4499 prune_wallpapers
      4543 help_wall
      4568 cmd_wall
      4672 help_app
      4690 cmd_app
      4817 help_serve
      4837 cmd_serve
      4950 cmd_status
      5043 help_revert
      5079 revert_terminal
      5117 revert_panel
      5140 revert_app
      5174 revert_keys
      5210 revert_serve
      5231 revert_gi_keys
      5247 cmd_revert
      5474 help_keys
      5500 keys_list_paths
      5505 keys_show
      5529 keys_add
      5615 keys_remove
      5662 cmd_keys
      5700 help_panel
      5720 cmd_panel
      5796 cmd_audit
      5812 help_selftest
      5871 sb_write_stub
      5878 sandbox_new
      6101 sb_set
      6112 sb_get
      6120 sb_dconf
      6128 sandbox_run
      6154 sandbox_verify
      6178 sandbox_run_no
      6186 sandbox_drop
      6203 t_eq
      6217 t_ne
      6230 t_has
      6250 t_hasnt
      6268 t_hasnt_out
      6280 t_out_has
      6294 t_rc
      6308 t_rc_not
      6334 t_file
      6346 t_nofile
      6365 t_group
      6374 t_ok
      6376 t_fail
      6381 t_skip
      6386 t_detail
      6394 cmd_selftest
      6780 selftest_full
      6823 st_core
      6936 st_buttons
      7081 st_corners
      7108 st_theme
      7256 st_icons
      7290 st_font
      7322 st_widget
      7367 st_terminal
      7396 st_newtab
      7446 st_wall
      7480 st_wallpapers
      7522 st_keys
      7566 st_panel
      7596 st_app
      7614 st_serve
      7635 st_revert
      7692 st_themes
      7734 st_refresh
      7782 st_tune
      7863 st_report
      7917 st_overview
      7954 st_presets
      7991 st_help
      8046 usage
      8101 help_settings
      8174 cmd_help
