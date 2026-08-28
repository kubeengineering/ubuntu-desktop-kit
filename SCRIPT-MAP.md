# Карта desktop-kit.sh

Всего 6939 строк, 270 КБ, ~92 тыс. токенов при чтении целиком.
Читать целиком не надо — ниже номера строк, бери точечно.

## Функции

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
    2354 apply_font
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
    3098 tick
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

## Секции и заголовки

    5    Одна команда на каждую подсистему, еди
    14   ----------------------------------------------------------------------
    15   ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил о�
    21   на Nautilus и Настройки влияет только ~/.confi
    31   под set -u подключение валит скрипт.
    33   который их проглатывает.
    34   ----------------------------------------------------------------------
    41   --------------------------------------------------------------- пут
    44   писать конфиги и, что хуже, удалять их �
    73   Маркер авторства для своих .desktop. Без н�
    77   Системные каталоги вынесены в перемен
    86   --------------------------------------------------------------- выв
    97   Многострочный вывод (списки тем, содер
    106  подсказка рядом с ошибкой: её нельзя т�
    125  Без терминала спрашивать некого: под sy
    127  Один такой вопрос уже подвесил самопр�
    151  --------------------------------------------------------- gsettings
    163  ------------------------------------------------------------ бэка�
    165  Копия делается ОДИН раз и только с фай�
    166  иначе повторный запуск сохранит уже и�
    208  Умное сравнение годится только для фа�
    210  для него полная подмена и есть верное �
    219  Подмена файла целиком стёрла бы правк�
    221  нет — подменяем; иначе оставляем файл 
    231  больше, чем должен: подменять файл в эт
    266  запомнить исходное значение настройк�
    267  BEFORE хранит «как было ДО нас» и не перез
    269  обновляться при каждом запуске. Для ни
    332  --------------------------------------------------------- css-блок
    334  Блоки помечаются по имени подсистемы: 
    335  Так одна команда не затирает правки др
    354  окажутся два набора правил для одних и
    393  маркеры парные и идут в правильном пор
    421  Базовая тема значков: снимаем и наш су�
    441  Ведущий перевод строки писать нельзя: 
    457  GTK4-файл часто оказывается симлинком в�
    462  Раньше здесь безусловно делались rm и to
    491  ------------------------------------------------------- перезап
    526  ------------------------------------------------------------ пров�
    529  Без set -e разбор пошёл бы по кругу с тем �

## Команды верхнего уровня (case)

    1343 install
    2828 list
    2833 edit
    2837 add
    2857 remove
    3234 status
    3255 urls
    3262 timer
    3266 prune
    3566 show
    3579 random
    3582 set
    3589 next|prev
    4326 buttons|corners
    4356 widget
    4371 theme
    4383 icons
    4398 font
    4404 terminal
    4407 panel
    4410 app
    4413 keys
    4416 serve
    4419 newtab
    4647 defaults
