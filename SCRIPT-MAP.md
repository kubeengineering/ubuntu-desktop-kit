# Карта desktop-kit.sh

Всего 9945 строк, 396 КБ, примерно 135 тыс. токенов целиком.

**Не читай файл целиком.** Найди место здесь или через `grep -n`, потом
`Read` с `offset`/`limit` на 40–80 строк и `Edit` по найденному фрагменту.

Пересобрать карту после правок: `bash tools/make-map.sh > SCRIPT-MAP.md`

## Рецепты: что где править

| Задача | Куда смотреть |
|---|---|
| Размер, цвет, подсветка кнопок заголовка | `cmd_buttons` — строка 2067, разбор ключей в начале, CSS ниже |
| Значки заголовка: откуда берутся | `install_fluent_glyphs` — строка 2383, адрес в $FLUENT_ICONS |
| Почему значков не видно | `diagnose_buttons` — строка 1936 |
| Скругление окон и меню | `cmd_corners` — строка 2918 |
| Тема окон, схема, переключение светлая/тёмная | `cmd_theme` — строка 3765 |
| Разбор имени темы на варианты | `theme_variant_of` — строка 3458, рядом theme_base_of, theme_swap_variant |
| Поиск парного варианта темы | `theme_find_variant` — строка 3540 |
| Добавить тему в банк | `theme_repo_for` — строка 3047, плюс themes_bank ниже |
| Список и установка тем банка | `cmd_themes` — строка 3158 |
| Проверка темы на совместимость с кнопками | `themes_check` — строка 3285 |
| Тема значков и цвет папок | `cmd_icons` — строка 4262 |
| Шрифты интерфейса | `cmd_font` — строка 4402 |
| Виджет conky: подложка, цвет, плотность | `cmd_widget` — строка 4704 |
| Прозрачность и палитра терминала | `cmd_terminal` — строка 4971 |
| Страница новой вкладки Chrome | `cmd_newtab` — строка 5173, разметка в heredoc ниже по функции |
| Плитки без python3 | `newtab_tiles_plain` — строка 5107 |
| Смена обоев по порядку | `cmd_wall` — строка 5912 |
| Докачка обоев и расписание | `cmd_wallpapers` — строка 5583 |
| Чистка банка обоев | `prune_wallpapers` — строка 5843 |
| Горячие клавиши | `cmd_keys` — строка 7022 |
| Панель Dash to Panel | `cmd_panel` — строка 7106 |
| Своя тема для приложения | `cmd_app` — строка 6034 |
| Локальная апка по http | `cmd_serve` — строка 6181 |
| Откат: общая логика | `cmd_revert` — строка 6605 |
| Откат конкретных ключей GNOME | `revert_gi_keys` — строка 6589 |
| Что показывает status | `cmd_status` — строка 6294 |
| Полный перечень изменяемого | `help_settings` — строка 9746 |
| Общий текст справки | `usage` — строка 9686 |
| Диспетчер команд (добавить новую) | ищи `случай) cmd_` в самом конце файла: `grep -n 'cmd_status "$@"' desktop-kit.sh` |
| Правила предшественника look.sh | `strip_legacy_css` — строка 1686 |
| Резервные копии и откат файлов | `backup_once` 1483, `restore_backup` 1513 |
| Блоки правил в gtk.css | `css_append` 1750, `css_strip` 1652 |
| Запомнить значение для отката | `remember` 1618 / `recall` 1634 |
| Наши текущие настройки | `state_set` 1588 / `state_get` 1603 |

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
| `buttons` | 2067 | 1884 | 8356 |
| `corners` | 2918 | 2475 | 8501 |
| `theme` | 3765 | 2993 | 8528 |
| `themes` | 3158 | 3089 | 9177 |
| `icons` | 4262 | 4200 | 8702 |
| `font` | 4402 | 4389 | 8775 |
| `widget` | 4704 | 4472 | 8807 |
| `terminal` | 4971 | 4944 | 8852 |
| `newtab` | 5173 | 5129 | 8881 |
| `wallpapers` | 5583 | 5542 | 8965 |
| `wall` | 5912 | 5887 | 8931 |
| `serve` | 6181 | 6161 | 9099 |
| `app` | 6034 | 6016 | 9081 |
| `keys` | 7022 | 6834 | 9007 |
| `panel` | 7106 | 7060 | 9051 |
| `audit` | 7216 | — | — |
| `status` | 6294 | — | — |
| `selftest` | 7814 | 7232 | — |
| `revert` | 6605 | 6389 | 9120 |

## Секции файла

    3  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
    5  Одна команда на каждую подсистему, единый откат, единый лог,
    6  самопроверка прямо на рабочей машине.
    15  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
    144  Обзор команды: что сейчас, что можно
    266  look — готовые образы рабочего стола
    451  profile — снимок оформления целиком
    811  Банк тем значков
    1148  Тема для GTK4-приложений
    1231  Пресеты: именованные наборы параметров
    1314  Вопросы пользователю
    1881  buttons — кнопки заголовка окна
    2472  corners — скругление окон
    2495  tune — настройка вопросами
    2990  theme — тема GTK
    3079  themes — банк готовых тем
    4197  icons — тема значков и цвет папок
    4386  font — шрифт интерфейса
    4469  widget — виджет conky
    4941  terminal — GNOME Terminal
    5102  newtab — страница новой вкладки Chrome
    5494  wallpapers / wall — банк обоев и смена
    6013  app — тема отдельного приложения
    6158  serve — локальная апка по http
    6291  status — что применено
    6386  revert — откат
    6831  keys — горячие клавиши
    7057  panel — Dash to Panel
    7213  audit — снимок системы
    7229  selftest — проверка на живой машине
    7272  Каркас самопроверки: песочница с подставными внешними программами
    9683  help и диспетчер

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
    464  PROFILE_DIR="$STATE_DIR/profiles"
    1310  PRESET_ARGS=""
    1311  PRESET_USED=""
    1322  ASK_ANSWER=""
    1586  KIT_STATE="$STATE_DIR/state.env"
    1671  LEGACY_CSS_MARK="look-begin"
    1672  LEGACY_ICON_SUFFIX="-Fluent-Titlebar"
    3358  THEME_INSTALLED=""
    3360  THEME_VARIANT_PICKED=""

## Где генерируется CSS

    2180  css_append buttons "$CSS3" "$(cat <<EOF
    2196  css_append buttons "$CSS4" "$(cat <<EOF
    2218  css_append buttons "$CSS3" "$(cat <<EOF
    2286  css_append buttons "$CSS4" "$(cat <<EOF
    2951  css_append corners "$CSS3" "$(cat <<EOF
    2969  css_append corners "$CSS4" "$(cat <<EOF

Селекторы, которые чаще всего правятся:
    2182  headerbar button.titlebutton,
    2184  button.titlebutton {
    2189  headerbar button.titlebutton image,
    2191  button.titlebutton image {
    2198  windowcontrols > button,
    2204  windowcontrols > button > image {
    2221  headerbar button.titlebutton,
    2223  button.titlebutton {
    2231  headerbar button.titlebutton image,
    2233  button.titlebutton image {
    2242  headerbar button.titlebutton:hover,
    2244  button.titlebutton:hover {
    2250  headerbar button.titlebutton:hover image,
    2251  button.titlebutton:hover image {

## Ключи состояния

Для отката (пишутся один раз, файл before.env):
    remember COLOR_SCHEME
    remember DTP_ANCHORS
    remember DTP_CUSTOM
    remember DTP_LENGTHS
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
    state_set WEATHER_CITY

## Самопроверка

    группы:      core buttons corners theme icons font widget terminal newtab wall wallpapers keys panel app serve revert themes look profile refresh tune report presets overview help
    каркас:      sandbox_new 7298, sandbox_run 7548
    утверждения: t_eq 7623, t_has 7650, t_out_has 7700, t_rc 7714
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
      284  look_table
      292  look_names
      296  help_look
      321  look_list
      334  look_show
      356  look_apply
      425  cmd_look
      469  profile_keys
      495  profile_files
      504  help_profile
      535  profile_autoname
      539  profile_list_names
      551  profile_save
      619  profile_load
      709  profile_show
      737  profile_drop
      758  profile_list
      781  cmd_profile
      823  icons_bank
      848  icons_repo_for
      852  icons_bank_list
      888  icons_clean
      913  git_clone_retry
      985  disk_room_warn
      1016 icons_copy_theme
      1031 icons_get
      1165 theme_gtk4_css
      1179 gtk4_theme_unlink
      1194 gtk4_theme_apply
      1240 presets_table
      1267 preset_args
      1275 presets_names
      1280 presets_list
      1289 preset_expand
      1325 ask_possible
      1337 ask_head
      1346 ask_num
      1383 ask_pick
      1429 ask_str
      1447 ask_yes
      1459 would
      1469 gi_get
      1470 gi_set
      1477 have
      1483 backup_once
      1513 restore_backup
      1588 state_set
      1603 state_get
      1618 remember
      1634 recall
      1652 css_strip
      1674 has_legacy_css
      1686 strip_legacy_css
      1738 icon_base_of
      1750 css_append
      1769 css_has
      1775 untangle_css
      1799 untangle_gtk4
      1803 untangle_gtk3
      1809 restart_gtk_apps
      1824 restart_conky
      1847 need_args
      1856 is_number
      1860 is_decimal
      1864 is_hex_colour
      1868 require_tools
      1884 help_buttons
      1936 diagnose_buttons
      2051 buttons_args
      2067 cmd_buttons
      2370 darken_hex
      2383 install_fluent_glyphs
      2475 help_corners
      2498 help_tune
      2518 tune_recap
      2524 cmd_tune
      2573 tune_corners
      2601 tune_buttons
      2661 tune_widget
      2727 tune_newtab
      2791 tune_terminal
      2820 tune_theme
      2833 tune_font
      2842 help_refresh
      2859 cmd_refresh
      2918 cmd_corners
      2993 help_theme
      3047 theme_repo_for
      3089 help_themes
      3132 themes_bank
      3158 cmd_themes
      3194 themes_list
      3214 themes_install
      3285 themes_check
      3345 list_themes
      3371 theme_exists
      3382 lower
      3384 theme_real_name
      3396 theme_exists_ci
      3415 theme_tokens
      3426 theme_token
      3430 theme_variant_pos
      3458 theme_variant_of
      3480 theme_rebuild
      3514 theme_base_of
      3528 theme_swap_variant
      3540 theme_find_variant
      3613 theme_light_by_sibling
      3632 theme_has_dark_sibling
      3644 theme_list_variants
      3672 theme_switch_variant
      3765 cmd_theme
      4001 install_theme_check_symlink
      4023 theme_build
      4086 theme_copy_dir
      4099 install_theme
      4200 help_icons
      4238 list_user_icon_themes
      4250 list_icon_themes
      4262 cmd_icons
      4389 help_font
      4402 cmd_font
      4472 help_widget
      4509 weather_line_path
      4513 weather_line_install
      4551 widget_modules_table
      4564 widget_add_module
      4621 widget_init
      4704 cmd_widget
      4916 conf_value
      4928 hex_brightness
      4944 help_terminal
      4962 term_profile
      4971 cmd_terminal
      5076 apply_wal_palette
      5107 newtab_tiles_plain
      5129 help_newtab
      5151 overview_newtab
      5173 cmd_newtab
      5269 rebuild_newtab
      5480 tick
      5497 find_wallpaper_dir
      5512 current_wallpaper
      5530 detect_resolution
      5542 help_wallpapers
      5565 week_themes
      5574 wallpaper_urls
      5583 cmd_wallpapers
      5775 install_wallpaper_timer
      5843 prune_wallpapers
      5887 help_wall
      5912 cmd_wall
      6016 help_app
      6034 cmd_app
      6161 help_serve
      6181 cmd_serve
      6294 cmd_status
      6389 help_revert
      6425 revert_terminal
      6463 revert_panel
      6498 revert_app
      6532 revert_keys
      6568 revert_serve
      6589 revert_gi_keys
      6605 cmd_revert
      6834 help_keys
      6860 keys_list_paths
      6865 keys_show
      6889 keys_add
      6975 keys_remove
      7022 cmd_keys
      7060 help_panel
      7089 panel_json_set
      7106 cmd_panel
      7216 cmd_audit
      7232 help_selftest
      7291 sb_write_stub
      7298 sandbox_new
      7521 sb_set
      7532 sb_get
      7540 sb_dconf
      7548 sandbox_run
      7574 sandbox_verify
      7598 sandbox_run_no
      7606 sandbox_drop
      7623 t_eq
      7637 t_ne
      7650 t_has
      7670 t_hasnt
      7688 t_hasnt_out
      7700 t_out_has
      7714 t_rc
      7728 t_rc_not
      7754 t_file
      7766 t_nofile
      7785 t_group
      7794 t_ok
      7796 t_fail
      7801 t_skip
      7806 t_detail
      7814 cmd_selftest
      8200 selftest_full
      8243 st_core
      8356 st_buttons
      8501 st_corners
      8528 st_theme
      8702 st_icons
      8775 st_font
      8807 st_widget
      8852 st_terminal
      8881 st_newtab
      8931 st_wall
      8965 st_wallpapers
      9007 st_keys
      9051 st_panel
      9081 st_app
      9099 st_serve
      9120 st_revert
      9177 st_themes
      9219 st_look
      9295 st_profile
      9370 st_refresh
      9418 st_tune
      9499 st_report
      9553 st_overview
      9590 st_presets
      9627 st_help
      9686 usage
      9746 help_settings
      9819 cmd_help
