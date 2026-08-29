# Карта desktop-kit.sh

Всего 8440 строк, 329 КБ, примерно 112 тыс. токенов целиком.

**Не читай файл целиком.** Найди место здесь или через `grep -n`, потом
`Read` с `offset`/`limit` на 40–80 строк и `Edit` по найденному фрагменту.

Пересобрать карту после правок: `bash tools/make-map.sh > SCRIPT-MAP.md`

## Рецепты: что где править

| Задача | Куда смотреть |
|---|---|
| Размер, цвет, подсветка кнопок заголовка | `cmd_buttons` — строка 1185, разбор ключей в начале, CSS ниже |
| Значки заголовка: откуда берутся | `install_fluent_glyphs` — строка 1501, адрес в $FLUENT_ICONS |
| Почему значков не видно | `diagnose_buttons` — строка 1054 |
| Скругление окон и меню | `cmd_corners` — строка 2036 |
| Тема окон, схема, переключение светлая/тёмная | `cmd_theme` — строка 2837 |
| Разбор имени темы на варианты | `theme_variant_of` — строка 2530, рядом theme_base_of, theme_swap_variant |
| Поиск парного варианта темы | `theme_find_variant` — строка 2612 |
| Добавить тему в банк | `theme_repo_for` — строка 2165, плюс themes_bank ниже |
| Список и установка тем банка | `cmd_themes` — строка 2242 |
| Проверка темы на совместимость с кнопками | `themes_check` — строка 2357 |
| Тема значков и цвет папок | `cmd_icons` — строка 3216 |
| Шрифты интерфейса | `cmd_font` — строка 3343 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 3498 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 3743 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 3945, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 3879 |
| Смена обоев по порядку | `cmd_wall` — строка 4684 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 4355 |
| Чистка банка обоев | `prune_wallpapers` — строка 4615 |
| Горячие клавиши | `cmd_keys` — строка 5780 |
| Панель Dash to Panel | `cmd_panel` — строка 5838 |
| Своя тема для приложения | `cmd_app` — строка 4806 |
| Локальная апка по http | `cmd_serve` — строка 4953 |
| Откат: общая логика | `cmd_revert` — строка 5363 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 5347 |
| Что показывает status | `cmd_status` — строка 5066 |
| Полный перечень изменяемого | `help_settings` — строка 8245 |
| Общий текст справки | `usage` — строка 8190 |
| Диспетчер команд (добавить новую) | ищи `случай) cmd_` в самом конце файла: `grep -n 'cmd_status "$@"' desktop-kit.sh` |
| Правила предшественника look.sh | `strip_legacy_css` — строка 804 |
| Резервные копии и откат файлов | `backup_once` 601, `restore_backup` 631 |
| Блоки правил в gtk.css | `css_append` 868, `css_strip` 770 |
| Запомнить значение для отката | `remember` 736 / `recall` 752 |
| Наши текущие настройки | `state_set` 706 / `state_get` 721 |

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
| `buttons` | 1185 | 1002 | 7054 |
| `corners` | 2036 | 1593 | 7199 |
| `theme` | 2837 | 2111 | 7226 |
| `themes` | 2242 | 2196 | 7836 |
| `icons` | 3216 | 3181 | 7400 |
| `font` | 3343 | 3330 | 7434 |
| `widget` | 3498 | 3413 | 7466 |
| `terminal` | 3743 | 3716 | 7511 |
| `newtab` | 3945 | 3901 | 7540 |
| `wallpapers` | 4355 | 4314 | 7624 |
| `wall` | 4684 | 4659 | 7590 |
| `serve` | 4953 | 4933 | 7758 |
| `app` | 4806 | 4788 | 7740 |
| `keys` | 5780 | 5592 | 7666 |
| `panel` | 5838 | 5818 | 7710 |
| `audit` | 5914 | — | — |
| `status` | 5066 | — | — |
| `selftest` | 6512 | 5930 | — |
| `revert` | 5363 | 5159 | 7779 |

## Секции файла

    3  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
    5  Одна команда на каждую подсистему, единый откат, единый лог,
    6  самопроверка прямо на рабочей машине.
    15  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
    144  Обзор команды: что сейчас, что можно
    266  Тема для GTK4-приложений
    349  Пресеты: именованные наборы параметров
    432  Вопросы пользователю
    999  buttons — кнопки заголовка окна
    1590  corners — скругление окон
    1613  tune — настройка вопросами
    2108  theme — тема GTK
    2186  themes — банк готовых тем
    3178  icons — тема значков и цвет папок
    3327  font — шрифт интерфейса
    3410  widget — виджет conky
    3713  terminal — GNOME Terminal
    3874  newtab — страница новой вкладки Chrome
    4266  wallpapers / wall — банк обоев и смена
    4785  app — тема отдельного приложения
    4930  serve — локальная апка по http
    5063  status — что применено
    5156  revert — откат
    5589  keys — горячие клавиши
    5815  panel — Dash to Panel
    5911  audit — снимок системы
    5927  selftest — проверка на живой машине
    5970  Каркас самопроверки: песочница с подставными внешними программами
    8187  help и диспетчер

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
    428  PRESET_ARGS=""
    429  PRESET_USED=""
    440  ASK_ANSWER=""
    704  KIT_STATE="$STATE_DIR/state.env"
    789  LEGACY_CSS_MARK="look-begin"
    790  LEGACY_ICON_SUFFIX="-Fluent-Titlebar"
    2430  THEME_INSTALLED=""
    2432  THEME_VARIANT_PICKED=""
    2437  THEME_DARK_SUFFIXES="-Darker -darker -Dark -dark -DARK -Black -black"

## Где генерируется CSS

    1298  css_append buttons "$CSS3" "$(cat <<EOF
    1314  css_append buttons "$CSS4" "$(cat <<EOF
    1336  css_append buttons "$CSS3" "$(cat <<EOF
    1404  css_append buttons "$CSS4" "$(cat <<EOF
    2069  css_append corners "$CSS3" "$(cat <<EOF
    2087  css_append corners "$CSS4" "$(cat <<EOF

Селекторы, которые чаще всего правятся:
    1300  headerbar button.titlebutton,
    1302  button.titlebutton {
    1307  headerbar button.titlebutton image,
    1309  button.titlebutton image {
    1316  windowcontrols > button,
    1322  windowcontrols > button > image {
    1339  headerbar button.titlebutton,
    1341  button.titlebutton {
    1349  headerbar button.titlebutton image,
    1351  button.titlebutton image {
    1360  headerbar button.titlebutton:hover,
    1362  button.titlebutton:hover {
    1368  headerbar button.titlebutton:hover image,
    1369  button.titlebutton:hover image {

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
    каркас:      sandbox_new 5996, sandbox_run 6246
    утверждения: t_eq 6321, t_has 6348, t_out_has 6398, t_rc 6412
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
      283  theme_gtk4_css
      297  gtk4_theme_unlink
      312  gtk4_theme_apply
      358  presets_table
      385  preset_args
      393  presets_names
      398  presets_list
      407  preset_expand
      443  ask_possible
      455  ask_head
      464  ask_num
      501  ask_pick
      547  ask_str
      565  ask_yes
      577  would
      587  gi_get
      588  gi_set
      595  have
      601  backup_once
      631  restore_backup
      706  state_set
      721  state_get
      736  remember
      752  recall
      770  css_strip
      792  has_legacy_css
      804  strip_legacy_css
      856  icon_base_of
      868  css_append
      887  css_has
      893  untangle_css
      917  untangle_gtk4
      921  untangle_gtk3
      927  restart_gtk_apps
      942  restart_conky
      965  need_args
      974  is_number
      978  is_decimal
      982  is_hex_colour
      986  require_tools
      1002 help_buttons
      1054 diagnose_buttons
      1169 buttons_args
      1185 cmd_buttons
      1488 darken_hex
      1501 install_fluent_glyphs
      1593 help_corners
      1616 help_tune
      1636 tune_recap
      1642 cmd_tune
      1691 tune_corners
      1719 tune_buttons
      1779 tune_widget
      1845 tune_newtab
      1909 tune_terminal
      1938 tune_theme
      1951 tune_font
      1960 help_refresh
      1977 cmd_refresh
      2036 cmd_corners
      2111 help_theme
      2165 theme_repo_for
      2196 help_themes
      2226 themes_bank
      2242 cmd_themes
      2278 themes_list
      2298 themes_install
      2357 themes_check
      2417 list_themes
      2443 theme_exists
      2454 lower
      2456 theme_real_name
      2468 theme_exists_ci
      2487 theme_tokens
      2498 theme_token
      2502 theme_variant_pos
      2530 theme_variant_of
      2552 theme_rebuild
      2586 theme_base_of
      2600 theme_swap_variant
      2612 theme_find_variant
      2685 theme_light_by_sibling
      2704 theme_has_dark_sibling
      2716 theme_list_variants
      2744 theme_switch_variant
      2837 cmd_theme
      3073 install_theme_check_symlink
      3081 install_theme
      3181 help_icons
      3204 list_icon_themes
      3216 cmd_icons
      3330 help_font
      3343 cmd_font
      3413 help_widget
      3442 widget_modules_table
      3454 widget_add_module
      3498 cmd_widget
      3688 conf_value
      3700 hex_brightness
      3716 help_terminal
      3734 term_profile
      3743 cmd_terminal
      3848 apply_wal_palette
      3879 newtab_tiles_plain
      3901 help_newtab
      3923 overview_newtab
      3945 cmd_newtab
      4041 rebuild_newtab
      4252 tick
      4269 find_wallpaper_dir
      4284 current_wallpaper
      4302 detect_resolution
      4314 help_wallpapers
      4337 week_themes
      4346 wallpaper_urls
      4355 cmd_wallpapers
      4547 install_wallpaper_timer
      4615 prune_wallpapers
      4659 help_wall
      4684 cmd_wall
      4788 help_app
      4806 cmd_app
      4933 help_serve
      4953 cmd_serve
      5066 cmd_status
      5159 help_revert
      5195 revert_terminal
      5233 revert_panel
      5256 revert_app
      5290 revert_keys
      5326 revert_serve
      5347 revert_gi_keys
      5363 cmd_revert
      5592 help_keys
      5618 keys_list_paths
      5623 keys_show
      5647 keys_add
      5733 keys_remove
      5780 cmd_keys
      5818 help_panel
      5838 cmd_panel
      5914 cmd_audit
      5930 help_selftest
      5989 sb_write_stub
      5996 sandbox_new
      6219 sb_set
      6230 sb_get
      6238 sb_dconf
      6246 sandbox_run
      6272 sandbox_verify
      6296 sandbox_run_no
      6304 sandbox_drop
      6321 t_eq
      6335 t_ne
      6348 t_has
      6368 t_hasnt
      6386 t_hasnt_out
      6398 t_out_has
      6412 t_rc
      6426 t_rc_not
      6452 t_file
      6464 t_nofile
      6483 t_group
      6492 t_ok
      6494 t_fail
      6499 t_skip
      6504 t_detail
      6512 cmd_selftest
      6898 selftest_full
      6941 st_core
      7054 st_buttons
      7199 st_corners
      7226 st_theme
      7400 st_icons
      7434 st_font
      7466 st_widget
      7511 st_terminal
      7540 st_newtab
      7590 st_wall
      7624 st_wallpapers
      7666 st_keys
      7710 st_panel
      7740 st_app
      7758 st_serve
      7779 st_revert
      7836 st_themes
      7878 st_refresh
      7926 st_tune
      8007 st_report
      8061 st_overview
      8098 st_presets
      8135 st_help
      8190 usage
      8245 help_settings
      8318 cmd_help
