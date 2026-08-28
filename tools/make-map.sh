#!/usr/bin/env bash
# Карта desktop-kit.sh для быстрых правок.
#
# Смысл: скрипт слишком велик, чтобы читать его целиком (270 КБ, около
# 90 тысяч токенов, и они потом едут в каждом следующем запросе). Карта
# занимает пару тысяч и отвечает на главный вопрос — В КАКИЕ СТРОКИ
# смотреть, чтобы внести конкретную правку.
#
# Поэтому карта не просто перечисляет функции, а даёт:
#   * рецепты: «поменять цвет закрытия» -> имя функции и строка;
#   * связку команда -> реализация -> справка -> тесты;
#   * якоря: уникальные строки, по которым правится файл без чтения;
#   * места, где генерируется CSS и где пишется состояние.
#
# Запуск:
#   bash tools/make-map.sh > SCRIPT-MAP.md

set -u
F="${1:-desktop-kit.sh}"
if [ ! -f "$F" ]; then
    echo "нет файла: $F" >&2
    exit 1
fi

total=$(wc -l < "$F" | tr -d ' ')
bytes=$(wc -c < "$F" | tr -d ' ')

# Номер строки, где определена функция
line_of() {
    grep -nE "^$1\(\)" "$F" | head -1 | cut -d: -f1
}

echo "# Карта $(basename "$F")"
echo
echo "Всего $total строк, $((bytes / 1024)) КБ, примерно $((bytes / 3000)) тыс. токенов целиком."
echo
echo '**Не читай файл целиком.** Найди место здесь или через `grep -n`, потом'
echo '`Read` с `offset`/`limit` на 40–80 строк и `Edit` по найденному фрагменту.'
echo
echo "Пересобрать карту после правок: \`bash tools/make-map.sh > SCRIPT-MAP.md\`"
echo

# ---------------------------------------------------------------- рецепты
echo "## Рецепты: что где править"
echo
echo "| Задача | Куда смотреть |"
echo "|---|---|"

recipe() {
    local what="$1"
    local fn="$2"
    local extra="${3:-}"
    local ln
    ln=$(line_of "$fn")
    if [ -z "$ln" ]; then
        return 0
    fi
    if [ -n "$extra" ]; then
        echo "| $what | \`$fn\` — строка $ln, $extra |"
    else
        echo "| $what | \`$fn\` — строка $ln |"
    fi
}

recipe "Размер, цвет, подсветка кнопок заголовка" cmd_buttons "разбор ключей в начале, CSS ниже"
recipe "Значки заголовка: откуда берутся" install_fluent_glyphs "адрес в \$FLUENT_ICONS"
recipe "Почему значков не видно" diagnose_buttons
recipe "Скругление окон и меню" cmd_corners
recipe "Тема окон, схема, переключение светлая/тёмная" cmd_theme
recipe "Разбор имени темы на варианты" theme_variant_of "рядом theme_base_of, theme_swap_variant"
recipe "Поиск парного варианта темы" theme_find_variant
recipe "Добавить тему в банк" theme_repo_for "плюс themes_bank ниже"
recipe "Список и установка тем банка" cmd_themes
recipe "Проверка темы на совместимость с кнопками" themes_check
recipe "Тема значков и цвет папок" cmd_icons
recipe "Шрифты интерфейса" cmd_font
recipe "Виджет conky: подложка, цвет, плотность" cmd_widget
recipe "Прозрачность и палитра терминала" cmd_terminal
recipe "Страница новой вкладки Chrome" cmd_newtab "разметка в heredoc ниже по функции"
recipe "Плитки без python3" newtab_tiles_plain
recipe "Смена обоев по порядку" cmd_wall
recipe "Докачка обоев и расписание" cmd_wallpapers
recipe "Чистка банка обоев" prune_wallpapers
recipe "Горячие клавиши" cmd_keys
recipe "Панель Dash to Panel" cmd_panel
recipe "Своя тема для приложения" cmd_app
recipe "Локальная апка по http" cmd_serve
recipe "Откат: общая логика" cmd_revert
recipe "Откат конкретных ключей GNOME" revert_gi_keys
recipe "Что показывает status" cmd_status
recipe "Полный перечень изменяемого" help_settings
recipe "Общий текст справки" usage
recipe "Диспетчер команд" "" ""

echo "| Диспетчер команд (добавить новую) | ищи \`случай) cmd_\` в самом конце файла: \`grep -n 'cmd_status \"\$@\"' $F\` |"
echo "| Правила предшественника look.sh | \`strip_legacy_css\` — строка $(line_of strip_legacy_css) |"
echo "| Резервные копии и откат файлов | \`backup_once\` $(line_of backup_once), \`restore_backup\` $(line_of restore_backup) |"
echo "| Блоки правил в gtk.css | \`css_append\` $(line_of css_append), \`css_strip\` $(line_of css_strip) |"
echo "| Запомнить значение для отката | \`remember\` $(line_of remember) / \`recall\` $(line_of recall) |"
echo "| Наши текущие настройки | \`state_set\` $(line_of state_set) / \`state_get\` $(line_of state_get) |"
echo

# --------------------------------------------------- правишь -> гоняй
echo "## Правишь -> гоняй (вместо полного прогона)"
echo
echo "Полный selftest --full нужен только перед выкладкой. После точечной"
echo "правки достаточно её группы плюс зависимых:"
echo
echo '```'
echo "bash tools/check.sh \"ГРУППА [ГРУППА]\""
echo '```'
echo
echo "| Правишь | Гоняй группы | Почему ещё и вторые |"
echo "|---|---|---|"
echo "| cmd_buttons, install_fluent_glyphs, CSS кнопок | buttons refresh presets | refresh переприменяет кнопки, presets их разворачивает |"
echo "| cmd_corners, CSS углов | corners presets overview | overview показывает наборы углов |"
echo "| theme_* (разбор имён, варианты) | theme | — |"
echo "| cmd_theme | theme revert | revert theme читает те же ключи |"
echo "| theme_repo_for, themes_bank, cmd_themes | themes | — |"
echo "| cmd_icons | icons buttons | buttons строит наследника поверх темы значков |"
echo "| cmd_font, apply_font | font | — |"
echo "| cmd_widget, widget_modules | widget tune | tune widget зовёт cmd_widget |"
echo "| cmd_terminal, apply_wal_palette | terminal revert | откат терминала читает те же ключи |"
echo "| cmd_newtab, генерация страницы | newtab wall | wall пересобирает страницу |"
echo "| cmd_wall | wall | — |"
echo "| cmd_wallpapers, prune | wallpapers | — |"
echo "| cmd_keys / cmd_panel / cmd_app / cmd_serve | keys / panel / app / serve | — |"
echo "| cmd_revert, restore_backup, revert_* | revert refresh | refresh тоже читает состояние |"
echo "| remember/recall, state_*, backup_once, css_* | core revert | это фундамент отката |"
echo "| preset_* | presets overview | обзор печатает наборы |"
echo "| ask_*, tune_* | tune | — |"
echo "| cmd_refresh | refresh | — |"
echo "| отчёт selftest, упаковка архива | report | — |"
echo "| usage, help_* | help | — |"
echo
echo "Правило: правка в ДВУХ местах из таблицы — гоняй обе строки."
echo "Перед git push: полный прогон плюс tests/test_kit.sh и tests/test_variants.sh."
echo

# ---------------------------------------------------------------- команды
echo "## Команды"
echo
echo "| Команда | Реализация | Справка | Тесты |"
echo "|---|---|---|---|"
for c in buttons corners theme themes icons font widget terminal newtab \
         wallpapers wall serve app keys panel audit status selftest revert; do
    impl=$(line_of "cmd_$c")
    hlp=$(line_of "help_$c")
    tst=$(line_of "st_$c")
    if [ -z "$impl" ]; then impl="—"; fi
    if [ -z "$hlp" ]; then hlp="—"; fi
    if [ -z "$tst" ]; then tst="—"; fi
    echo "| \`$c\` | $impl | $hlp | $tst |"
done
echo

# ---------------------------------------------------------------- секции
echo "## Секции файла"
echo
grep -nE '^#  [a-zа-я]' "$F" \
    | sed -E 's/^([0-9]+):#  (.*)$/    \1  \2/' \
    | head -40
echo

# ------------------------------------------------------------- константы
echo "## Пути и константы"
echo
grep -nE '^[A-Z_]+=' "$F" | head -30 | sed -E 's/^([0-9]+):(.*)$/    \1  \2/'
echo

# ------------------------------------------------------------- генерация CSS
echo "## Где генерируется CSS"
echo
grep -n 'css_append ' "$F" | sed -E 's/^([0-9]+):[[:space:]]*(.*)$/    \1  \2/'
echo
echo "Селекторы, которые чаще всего правятся:"
grep -nE '^(windowcontrols|headerbar button|button\.titlebutton|decoration|window\.csd)' "$F" \
    | head -14 | sed -E 's/^([0-9]+):(.*)$/    \1  \2/'
echo

# ------------------------------------------------------------- состояние
echo "## Ключи состояния"
echo
echo "Для отката (пишутся один раз, файл before.env):"
grep -oE 'remember [A-Z_]+' "$F" | sort -u | sed 's/^/    /'
echo
echo "Наши текущие настройки (перезаписываются, файл state.env):"
grep -oE 'state_set [A-Z_]+' "$F" | sort -u | sed 's/^/    /'
echo

# ------------------------------------------------------------- самопроверка
echo "## Самопроверка"
echo
echo "    группы:      $(grep -m1 '^SELFTEST_GROUPS=' "$F" | cut -d'"' -f2)"
echo "    каркас:      sandbox_new $(line_of sandbox_new), sandbox_run $(line_of sandbox_run)"
echo "    утверждения: t_eq $(line_of t_eq), t_has $(line_of t_has), t_out_has $(line_of t_out_has), t_rc $(line_of t_rc)"
echo "    заглушки:    $(grep -c 'sb_write_stub' "$F") штук, ищи sb_write_stub"
echo
echo "Запуск одной группы: \`bash $F selftest --only theme\`"
echo

# ------------------------------------------------------------- функции
echo "## Все функции"
echo
grep -nE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$F" \
    | sed -E 's/^([0-9]+):([a-zA-Z_][a-zA-Z0-9_]*)\(\).*/  \1\t\2/' \
    | awk -F'\t' '{printf "    %-6s %s\n", $1, $2}'
