# Карта desktop-kit.sh

Всего 8279 строк, 321 КБ, примерно 109 тыс. токенов целиком.

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
| Тема значков и цвет папок | `cmd_icons` — строка 3083 |
| Шрифты интерфейса | `cmd_font` — строка 3210 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 3365 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 3610 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 3812, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 3746 |
| Смена обоев по порядку | `cmd_wall` — строка 4551 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 4222 |
| Чистка банка обоев | `prune_wallpapers` — строка 4482 |
| Горячие клавиши | `cmd_keys` — строка 5645 |
| Панель Dash to Panel | `cmd_panel` — строка 5703 |
| Своя тема для приложения | `cmd_app` — строка 4673 |
| Локальная апка по http | `cmd_serve` — строка 4820 |
| Откат: общая логика | `cmd_revert` — строка 5230 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 5214 |
| Что показывает status | `cmd_status` — строка 4933 |
| Полный перечень изменяемого | `help_settings` — строка 8084 |
| Общий текст справки | `usage` — строка 8029 |
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
| `buttons` | 1102 | 919 | 6919 |
| `corners` | 1953 | 1510 | 7064 |
| `theme` | 2745 | 2028 | 7091 |
| `themes` | 2150 | 2104 | 7675 |
| `icons` | 3083 | 3048 | 7239 |
| `font` | 3210 | 3197 | 7273 |
| `widget` | 3365 | 3280 | 7305 |
| `terminal` | 3610 | 3583 | 7350 |
| `newtab` | 3812 | 3768 | 7379 |
| `wallpapers` | 4222 | 4181 | 7463 |
| `wall` | 4551 | 4526 | 7429 |
| `serve` | 4820 | 4800 | 7597 |
| `app` | 4673 | 4655 | 7579 |
| `keys` | 5645 | 5457 | 7505 |
| `panel` | 5703 | 5683 | 7549 |
| `audit` | 5779 | — | — |
| `status` | 4933 | — | — |
| `selftest` | 6377 | 5795 | — |
| `revert` | 5230 | 5026 | 7618 |

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
    3045  icons — тема значков и цвет папок
    3194  font — шрифт интерфейса
    3277  widget — виджет conky
    3580  terminal — GNOME Terminal
    3741  newtab — страница новой вкладки Chrome
    4133  wallpapers / wall — банк обоев и смена
    4652  app — тема отдельного приложения
    4797  serve — локальная апка по http
    4930  status — что применено
    5023  revert — откат
    5454  keys — горячие клавиши
    5680  panel — Dash to Panel
    5776  audit — снимок системы
    5792  selftest — проверка на живой машине
    5835  Каркас самопроверки: песочница с подставными внешними программами
    8026  help и диспетчер

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
    каркас:      sandbox_new 5861, sandbox_run 6111
    утверждения: t_eq 6186, t_has 6213, t_out_has 6263, t_rc 6277
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
      3048 help_icons
      3071 list_icon_themes
      3083 cmd_icons
      3197 help_font
      3210 cmd_font
      3280 help_widget
      3309 widget_modules_table
      3321 widget_add_module
      3365 cmd_widget
      3555 conf_value
      3567 hex_brightness
      3583 help_terminal
      3601 term_profile
      3610 cmd_terminal
      3715 apply_wal_palette
      3746 newtab_tiles_plain
      3768 help_newtab
      3790 overview_newtab
      3812 cmd_newtab
      3908 rebuild_newtab
      4119 tick
      4136 find_wallpaper_dir
      4151 current_wallpaper
      4169 detect_resolution
      4181 help_wallpapers
      4204 week_themes
      4213 wallpaper_urls
      4222 cmd_wallpapers
      4414 install_wallpaper_timer
      4482 prune_wallpapers
      4526 help_wall
      4551 cmd_wall
      4655 help_app
      4673 cmd_app
      4800 help_serve
      4820 cmd_serve
      4933 cmd_status
      5026 help_revert
      5062 revert_terminal
      5100 revert_panel
      5123 revert_app
      5157 revert_keys
      5193 revert_serve
      5214 revert_gi_keys
      5230 cmd_revert
      5457 help_keys
      5483 keys_list_paths
      5488 keys_show
      5512 keys_add
      5598 keys_remove
      5645 cmd_keys
      5683 help_panel
      5703 cmd_panel
      5779 cmd_audit
      5795 help_selftest
      5854 sb_write_stub
      5861 sandbox_new
      6084 sb_set
      6095 sb_get
      6103 sb_dconf
      6111 sandbox_run
      6137 sandbox_verify
      6161 sandbox_run_no
      6169 sandbox_drop
      6186 t_eq
      6200 t_ne
      6213 t_has
      6233 t_hasnt
      6251 t_hasnt_out
      6263 t_out_has
      6277 t_rc
      6291 t_rc_not
      6317 t_file
      6329 t_nofile
      6348 t_group
      6357 t_ok
      6359 t_fail
      6364 t_skip
      6369 t_detail
      6377 cmd_selftest
      6763 selftest_full
      6806 st_core
      6919 st_buttons
      7064 st_corners
      7091 st_theme
      7239 st_icons
      7273 st_font
      7305 st_widget
      7350 st_terminal
      7379 st_newtab
      7429 st_wall
      7463 st_wallpapers
      7505 st_keys
      7549 st_panel
      7579 st_app
      7597 st_serve
      7618 st_revert
      7675 st_themes
      7717 st_refresh
      7765 st_tune
      7846 st_report
      7900 st_overview
      7937 st_presets
      7974 st_help
      8029 usage
      8084 help_settings
      8157 cmd_help
