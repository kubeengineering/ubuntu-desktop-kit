#!/usr/bin/env bash
#
#  desktop-kit — единый инструмент настройки десктопа Ubuntu 24.04 / GNOME 46
#
#  Одна команда на каждую подсистему, единый откат, единый лог,
#  самопроверка прямо на рабочей машине.
#
#  ./desktop-kit.sh <команда> [параметры]
#  ./desktop-kit.sh help <команда>     подробности по одной команде
#  ./desktop-kit.sh status             что сейчас применено
#  ./desktop-kit.sh selftest           проверить себя и собрать архив с логами
#  ./desktop-kit.sh revert [команда]   откатить всё или одну подсистему
#
#  ------------------------------------------------------------------------
#  ЧТО ЗДЕСЬ УЧТЕНО (каждый пункт стоил отдельного круга отладки)
#
#  * GTK НЕ ПОНИМАЕТ !important — считает мусором и выбрасывает правило
#    целиком: "Junk at end of value for min-width". Он и не нужен:
#    ~/.config/gtk-*/gtk.css грузится с приоритетом USER, темы — с THEME.
#  * libadwaita ИГНОРИРУЕТ темы (gtk-theme-name прибит к Adwaita-empty):
#    на Nautilus и Настройки влияет только ~/.config/gtk-4.0/gtk.css.
#  * Круг у кнопки заголовка рисует не кнопка, а её дочерний image.
#    В GTK3 наоборот — сама кнопка. Цели разные.
#  * -gtk-icon-size есть только в GTK4. В GTK3 значок растеризуется в 16px
#    и растягивается трансформацией: выше ~1.3 видны пиксели.
#  * ~/.config/gtk-4.0/gtk.css у тем с флагом -l это СИМЛИНК внутрь темы.
#  * gnome-terminal-server переживает закрытие всех окон и держит старую
#    тему, пока его не убить.
#  * grep -vF "" выбрасывает ВСЕ строки: пустой фильтр опаснее отсутствия.
#  * pywal дописывает в colors.sh ссылки на несуществующие переменные —
#    под set -u подключение валит скрипт.
#  * Скрипт не содержит || и && : юзер переносит команды через мессенджер,
#    который их проглатывает.
#  ------------------------------------------------------------------------

set -uo pipefail

VERSION="1.0"
SELF=$(readlink -f "$0")

# --------------------------------------------------------------- пути

# Все пути строятся от $HOME. Если он пуст или равен корню, скрипт начнёт
# писать конфиги и, что хуже, удалять их в /. Проверяем до первой операции.
if [ -z "${HOME:-}" ]; then
    echo "desktop-kit: переменная HOME пуста — отказываюсь работать" >&2
    exit 1
fi
if [ "$HOME" = "/" ]; then
    echo "desktop-kit: HOME=/ — так настраивают корень файловой системы," >&2
    echo "а не рабочий стол. Запусти от обычного пользователя." >&2
    exit 1
fi
if [ "$(id -u 2>/dev/null)" = "0" ]; then
    echo "desktop-kit: запущен от root." >&2
    echo "Настройки применятся руту, а не тебе. Запусти без sudo." >&2
    exit 1
fi

STATE_DIR="$HOME/.local/state/desktop-kit"
BACKUP_DIR="$STATE_DIR/backups"
LOG_FILE="$STATE_DIR/desktop-kit.log"
BEFORE="$STATE_DIR/before.env"

CSS3="$HOME/.config/gtk-3.0/gtk.css"
CSS4="$HOME/.config/gtk-4.0/gtk.css"
CONKY_DIR="$HOME/.config/conky"
CONKY_CONF="$CONKY_DIR/main.conf"
CONKY_LUA="$CONKY_DIR/desktop-kit-bg.lua"
NEWTAB_DIR="$HOME/.local/share/newtab"
NEWTAB_LINKS="$NEWTAB_DIR/links.txt"
BIN_DIR="$HOME/bin"
# Маркер авторства для своих .desktop. Без него откат не отличал наш ярлык
# от такого же по виду, но написанного человеком или прежним
# evolution-light.sh, и сносил чужой файл вместе со своим.
APP_MARK="# создано desktop-kit"
# Системные каталоги вынесены в переменные ради самопроверки: иначе тест
# в песочнице видел бы настоящие темы и ярлыки машины и был бы неповторим.
SYS_THEMES="${DK_SYS_THEMES:-/usr/share/themes}"
SYS_ICONS="${DK_SYS_ICONS:-/usr/share/icons}"
SYS_APPS="${DK_SYS_APPS:-/usr/share/applications}"

FLUENT_ICONS="https://raw.githubusercontent.com/vinceliuice/Fluent-icon-theme/master/src/symbolic/actions"
WALLHAVEN="https://wallhaven.cc/api/v1/search"

# --------------------------------------------------------------- вывод

DRY_RUN=0
ASSUME_YES=0
QUIET=0

ok()   { if [ "$QUIET" = "0" ]; then echo "  ✓ $*"; fi; log "OK   $*"; }
bad()  { echo "  ✗ $*" >&2; log "FAIL $*"; }
note() { if [ "$QUIET" = "0" ]; then echo "    $*"; fi; log "     $*"; }
# Пустая строка тоже вывод: голый echo пробивал --quiet.
blank() { if [ "$QUIET" = "0" ]; then echo; fi; }
# Многострочный вывод (списки тем, содержимое before.env) — тоже вывод,
# и в тихом режиме его быть не должно.
dump() {
    if [ "$QUIET" = "0" ]; then
        sed "s/^/      /"
    else
        cat > /dev/null
    fi
}
# подсказка рядом с ошибкой: её нельзя терять даже в тихом режиме
hint() { echo "    $*" >&2; log "     $*"; }
head1() { if [ "$QUIET" = "0" ]; then echo "==> $*"; fi; log "=== $*"; }

log() {
    mkdir -p "$STATE_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

die() {
    bad "$*"
    exit 1
}

# спросить подтверждение; --yes пропускает
confirm() {
    if [ "$ASSUME_YES" = "1" ]; then
        return 0
    fi
    # Без терминала спрашивать некого: под systemd, в конвейере или когда
    # вывод перенаправлен, приглашение уходит в никуда, а read ждёт вечно.
    # Один такой вопрос уже подвесил самопроверку у человека.
    if [ ! -t 0 ]; then
        note "вопрос «$1» задать некому — ввода нет, считаю ответ отрицательным"
        note "чтобы согласиться заранее, добавь --yes"
        return 1
    fi
    printf '    %s [y/N] ' "$1"
    local answer
    read -r answer
    if [ "$answer" = "y" ]; then
        return 0
    fi
    return 1
}


# =====================================================================
#  Пресеты: именованные наборы параметров
# =====================================================================
#
# Числа помнить незачем. `buttons thin` понятнее, чем
# `buttons --size 46 34 --icon 20 --radius 0`, и делает то же самое.
# Имена английские, потому что это часть команды.
#
# Таблица: команда|имя|аргументы|что это

presets_table() {
    cat <<'EOF'
buttons|thin|--size 46 34 --icon 20 --radius 0|large and thin, square highlight
buttons|default|--size 32 32 --icon 16 --radius 999|as GNOME ships them
buttons|big|--size 52 38 --icon 24 --radius 0|even larger, for high resolution
buttons|square|--radius 0|square highlight, sizes untouched
buttons|round|--radius 999|round highlight, sizes untouched
buttons|keep|--glyphs keep --hover none|leave glyph and background to the theme
corners|sharp|--radius 0|sharp, like Tabby and Windows
corners|soft|--radius 6|barely rounded
corners|round|--radius 12|rounded, GNOME default
corners|extra|--radius 20|heavily rounded
widget|dark|--colour 1e1e2e --text ffffff|dark backdrop, light text
widget|light|--colour f2f2f2 --text 1e1e2e|light backdrop, dark text
widget|flat|--radius 0|sharp corners
widget|round|--radius 12|rounded corners
widget|glass|--opacity 120|semi transparent backdrop
widget|solid|--opacity 255|opaque backdrop
terminal|opaque|--opacity 0|no transparency
terminal|glass|--opacity 15|slightly see-through
terminal|clear|--opacity 30|noticeably see-through
newtab|big|--clock 140 --tile 150|large clock and tiles
newtab|compact|--clock 80 --tile 110|small clock and tiles
EOF
}

# Аргументы пресета. Пусто, если такого нет.
preset_args() {
    local cmd="$1"
    local name="$2"
    presets_table | awk -F'|' -v c="$cmd" -v n="$name" \
        '$1 == c && $2 == n { print $3 }'
}

# Имена пресетов команды одной строкой — для общего списка команд
presets_names() {
    presets_table | awk -F'|' -v c="$1" '$1 == c { printf "%s ", $2 }'
}

# Список пресетов команды для справки
presets_list() {
    local cmd="$1"
    presets_table | awk -F'|' -v c="$cmd" \
        '$1 == c { printf "  %-9s %s\n", $2, $4 }'
}

# Развернуть первый аргумент, если это имя пресета. Вызывается в начале
# команды: `buttons thin --icon 22` превращается в полный набор флагов,
# и явные флаги после имени всё так же перекрывают пресет.
preset_expand() {
    PRESET_ARGS=""
    PRESET_USED=""
    local cmd="$1"
    local first="${2:-}"
    if [ -z "$first" ]; then
        return 1
    fi
    case "$first" in
        -*) return 1 ;;
    esac
    local args
    args=$(preset_args "$cmd" "$first")
    if [ -z "$args" ]; then
        return 1
    fi
    PRESET_ARGS="$args"
    PRESET_USED="$first"
    return 0
}

PRESET_ARGS=""
PRESET_USED=""

# =====================================================================
#  Вопросы пользователю
# =====================================================================
#
# Команды с флагами хороши, когда знаешь, какие флаги бывают. Здесь
# наоборот: скрипт показывает, что сейчас стоит, какие есть варианты,
# и спрашивает. Ответ пустой означает «оставить как есть» — поэтому
# можно проходить мастер, нажимая Enter, и ничего не сломается.

ASK_ANSWER=""

# Есть ли кому отвечать. Без терминала спрашивать нельзя: read повиснет.
ask_possible() {
    # DK_ASK_FORCE=1 нужен самопроверке: она подаёт ответы из файла и
    # терминала у неё нет, а логику мастера проверить надо.
    if [ "${DK_ASK_FORCE:-0}" = "1" ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        return 1
    fi
    return 0
}

ask_head() {
    echo
    echo "  == $1"
    if [ -n "${2:-}" ]; then
        echo "     $2"
    fi
}

# Число в диапазоне. ask_num "что" "сейчас" мин макс "пояснение"
ask_num() {
    local what="$1"
    local now="$2"
    local lo="$3"
    local hi="$4"
    local hint="${5:-}"
    local answer
    ASK_ANSWER="$now"
    while true; do
        if [ -n "$hint" ]; then
            echo "     $hint"
        fi
        printf '     %s [%s..%s, сейчас %s]: ' "$what" "$lo" "$hi" "$now"
        read -r answer
        if [ -z "$answer" ]; then
            ASK_ANSWER="$now"
            return 0
        fi
        if ! is_number "$answer"; then
            echo "     нужно целое число"
            continue
        fi
        if [ "$answer" -lt "$lo" ]; then
            echo "     меньше $lo нельзя"
            continue
        fi
        if [ "$answer" -gt "$hi" ]; then
            echo "     больше $hi нельзя"
            continue
        fi
        ASK_ANSWER="$answer"
        return 0
    done
}

# Выбор из списка. Варианты передаются парами: значение и подпись.
# ask_pick "что" "сейчас" "0" "острые углы" "12" "скруглённые"
ask_pick() {
    local what="$1"
    local now="$2"
    shift 2
    local vals=""
    local i=0
    local v
    local label
    echo "     $what"
    while [ $# -gt 1 ]; do
        v="$1"
        label="$2"
        shift 2
        i=$((i + 1))
        vals="$vals$v
"
        if [ "$v" = "$now" ]; then
            printf '       %s) %-22s %s  (сейчас)\n' "$i" "$v" "$label"
        else
            printf '       %s) %-22s %s\n' "$i" "$v" "$label"
        fi
    done
    local answer
    ASK_ANSWER="$now"
    while true; do
        printf '     номер или своё значение [Enter — оставить %s]: ' "$now"
        read -r answer
        if [ -z "$answer" ]; then
            ASK_ANSWER="$now"
            return 0
        fi
        if is_number "$answer"; then
            if [ "$answer" -ge 1 ]; then
                if [ "$answer" -le "$i" ]; then
                    ASK_ANSWER=$(printf '%s' "$vals" | sed -n "${answer}p")
                    return 0
                fi
            fi
        fi
        # не номер из списка — принимаем как есть, это может быть свой цвет
        ASK_ANSWER="$answer"
        return 0
    done
}

# Свободная строка
ask_str() {
    local what="$1"
    local now="${2:-}"
    local answer
    if [ -n "$now" ]; then
        printf '     %s [сейчас %s]: ' "$what" "$now"
    else
        printf '     %s: ' "$what"
    fi
    read -r answer
    if [ -z "$answer" ]; then
        ASK_ANSWER="$now"
    else
        ASK_ANSWER="$answer"
    fi
    return 0
}

ask_yes() {
    local what="$1"
    local answer
    printf '     %s [y/N]: ' "$what"
    read -r answer
    if [ "$answer" = "y" ]; then
        return 0
    fi
    return 1
}

# в режиме проверки ничего не пишем, только рассказываем
would() {
    if [ "$DRY_RUN" = "1" ]; then
        note "(проверка) $*"
        return 0
    fi
    return 1
}

# --------------------------------------------------------- gsettings

gi_get() { gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | tr -d "'"; }
gi_set() {
    if would "gsettings interface $1 = $2"; then
        return 0
    fi
    gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null
}

have() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------ бэкапы

# Копия делается ОДИН раз и только с файла, где ещё нет наших правок:
# иначе повторный запуск сохранит уже изменённый файл, и откат вернёт его.
backup_once() {
    local src="$1"
    local name="$2"
    local dst="$BACKUP_DIR/$name"
    # В режиме проверки не создаём даже каталог: обещали не трогать диск.
    if [ "$DRY_RUN" = "1" ]; then
        return 0
    fi
    mkdir -p "$BACKUP_DIR"
    if [ -e "$dst" ]; then
        return 0
    fi
    if [ -L "$dst" ]; then
        return 0
    fi
    if [ -L "$src" ]; then
        cp -P "$src" "$dst"
        ok "сохранён симлинк: $name"
        return 0
    fi
    if [ -f "$src" ]; then
        if grep -q 'dk:' "$src"; then
            return 0
        fi
        cp "$src" "$dst"
        ok "сохранён исходный файл: $name"
    fi
    return 0
}

restore_backup() {
    local src="$1"
    local name="$2"
    local dst="$BACKUP_DIR/$name"
    local found=0
    if [ -e "$dst" ]; then found=1; fi
    if [ -L "$dst" ]; then found=1; fi
    if [ "$found" = "0" ]; then
        return 1
    fi

    # Умное сравнение годится только для файлов с нашими блоками-маркерами
    # (gtk.css). Конфиг conky правится целиком, там сравнивать нечего —
    # для него полная подмена и есть верное поведение.
    local mode="${3:-whole}"
    if [ "$mode" != "blocks" ]; then
        rm -f "$src"
        mv "$dst" "$src"
        ok "восстановлен $src"
        return 0
    fi

    # Подмена файла целиком стёрла бы правки, сделанные пользователем ПОСЛЕ
    # снятия копии. Поэтому сравниваем: если различий, кроме наших блоков,
    # нет — подменяем; иначе оставляем файл как есть, сняв только своё.
    if [ -f "$src" ]; then
        local cleaned
        cleaned=$(mktemp)
        if [ -z "$cleaned" ]; then
            bad "не удалось создать временный файл — откат $src отменён"
            return 1
        fi
        sed '/dk:[a-z]*-begin/,/dk:[a-z]*-end/d' "$src" > "$cleaned"
        # Пустой результат при непустом исходнике означает, что sed съел
        # больше, чем должен: подменять файл в этом случае нельзя.
        if [ -s "$src" ]; then
            if [ ! -s "$cleaned" ]; then
                if grep -q 'dk:' "$src"; then
                    : # файл целиком состоял из наших блоков, это нормально
                else
                    bad "после снятия наших правил от $src ничего не осталось"
                    note "файл не трогаю, разберись руками"
                    rm -f "$cleaned"
                    return 1
                fi
            fi
        fi
        # пустые строки на стыке блоков разницей не считаем
        if diff -q -B "$cleaned" "$dst" >/dev/null 2>&1; then
            rm -f "$cleaned"
            rm -f "$src"
            mv "$dst" "$src"
            ok "восстановлен $src"
            return 0
        fi
        cat "$cleaned" > "$src"
        rm -f "$cleaned"
        rm -f "$dst"
        ok "наши правила убраны из $src"
        note "файл менялся после установки — остальное содержимое сохранено"
        return 0
    fi

    rm -f "$src"
    mv "$dst" "$src"
    ok "восстановлен $src"
    return 0
}

# запомнить исходное значение настройки — только при первом изменении
# BEFORE хранит «как было ДО нас» и не перезаписывается — на этом стоит
# откат. Но часть значений это НАШИ последние настройки, они должны
# обновляться при каждом запуске. Для них отдельный файл.
KIT_STATE="$STATE_DIR/state.env"

state_set() {
    local key="$1"
    local value="$2"
    if [ "$DRY_RUN" = "1" ]; then
        return 0
    fi
    mkdir -p "$STATE_DIR"
    touch "$KIT_STATE"
    local tmp
    tmp=$(mktemp)
    grep -v "^$key=" "$KIT_STATE" > "$tmp" 2>/dev/null
    mv "$tmp" "$KIT_STATE"
    echo "$key='$value'" >> "$KIT_STATE"
}

state_get() {
    local key="$1"
    if [ ! -f "$KIT_STATE" ]; then
        return 1
    fi
    local line
    line=$(grep "^$key=" "$KIT_STATE" | tail -1)
    if [ -z "$line" ]; then
        return 1
    fi
    local value="${line#*=}"
    echo "$value" | sed "s/^'//; s/'$//"
    return 0
}

remember() {
    local key="$1"
    local value="$2"
    # В режиме проверки не пишем ничего: иначе первый же --dry-run создавал
    # бы снимок «как было», и настоящий запуск потом запоминал бы не то.
    if [ "$DRY_RUN" = "1" ]; then
        return 0
    fi
    mkdir -p "$STATE_DIR"
    touch "$BEFORE"
    if grep -q "^$key=" "$BEFORE"; then
        return 0
    fi
    echo "$key='$value'" >> "$BEFORE"
}

recall() {
    local key="$1"
    if [ ! -f "$BEFORE" ]; then
        return 1
    fi
    local line=$(grep "^$key=" "$BEFORE" | tail -1)
    if [ -z "$line" ]; then
        return 1
    fi
    local value="${line#*=}"
    echo "$value" | sed "s/^'//; s/'$//"
    return 0
}

# --------------------------------------------------------- css-блоки

# Блоки помечаются по имени подсистемы: dk:buttons, dk:corners и т.д.
# Так одна команда не затирает правки другой.
css_strip() {
    local tag="$1"
    local file="$2"
    # sed -i по симлинку подменяет саму ссылку обычным файлом. Для gtk.css
    # это значит, что правки уедут внутрь каталога темы.
    if [ -L "$file" ]; then
        bad "$file — симлинк, правила из него не снимаю"
        note "цель: $(readlink -f "$file")"
        return 1
    fi
    if [ -f "$file" ]; then
        sed -i "/dk:$tag-begin/,/dk:$tag-end/d" "$file"
    fi
}

# Предшественники этого скрипта (look.sh, titlebuttons.sh) писали свои
# правила блоком look-begin/look-end и заводили тему значков с суффиксом
# -Fluent-Titlebar. Их надо уметь распознать: иначе в одном gtk.css
# окажутся два набора правил для одних и тех же кнопок.
LEGACY_CSS_MARK="look-begin"
LEGACY_ICON_SUFFIX="-Fluent-Titlebar"

has_legacy_css() {
    local f
    for f in "$CSS3" "$CSS4"; do
        if [ -f "$f" ]; then
            if grep -q "$LEGACY_CSS_MARK" "$f" 2>/dev/null; then
                return 0
            fi
        fi
    done
    return 1
}

strip_legacy_css() {
    # В режиме проверки не трогаем ничего: раньше --dry-run вырезал блоки
    # предшественника по-настоящему, да ещё и без резервной копии.
    if [ "$DRY_RUN" = "1" ]; then
        note "(проверка) убрали бы правила старого look.sh"
        return 0
    fi
    local f
    local n=0
    local nb
    local ne
    local lb
    local le
    for f in "$CSS3" "$CSS4"; do
        if [ ! -f "$f" ]; then
            continue
        fi
        if ! grep -q "$LEGACY_CSS_MARK" "$f" 2>/dev/null; then
            continue
        fi

        # sed с диапазоном при отсутствии закрывающего маркера удаляет файл
        # от начала блока И ДО КОНЦА. Поэтому сначала убеждаемся, что
        # маркеры парные и идут в правильном порядке.
        nb=$(grep -c 'look-begin' "$f")
        ne=$(grep -c 'look-end' "$f")
        if [ "$nb" != "$ne" ]; then
            bad "в $f маркеры look-begin и look-end не парные ($nb и $ne)"
            note "не трогаю: вырезание съело бы файл до конца"
            note "поправь блок руками, потом повтори команду"
            continue
        fi
        lb=$(grep -n 'look-begin' "$f" | head -1 | cut -d: -f1)
        le=$(grep -n 'look-end' "$f" | head -1 | cut -d: -f1)
        if [ "$lb" -gt "$le" ]; then
            bad "в $f look-end встречается раньше look-begin"
            note "не трогаю, поправь руками"
            continue
        fi

        backup_once "$f" "$(basename "$(dirname "$f")")-gtk.css"
        sed -i '/look-begin/,/look-end/d' "$f"
        ok "убран блок старого look.sh из $f"
        n=$((n + 1))
    done
    if [ "$n" = "0" ]; then
        return 1
    fi
    return 0
}

# Базовая тема значков: снимаем и наш суффикс, и суффикс предшественника.
icon_base_of() {
    local name="$1"
    case "$name" in
        *-dk-glyphs)          printf '%s
' "${name%-dk-glyphs}" ;;
        *"$LEGACY_ICON_SUFFIX") printf '%s
' "${name%$LEGACY_ICON_SUFFIX}" ;;
        *)                    printf '%s
' "$name" ;;
    esac
}

css_append() {
    local tag="$1"
    local file="$2"
    local body="$3"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    css_strip "$tag" "$file"
    # Ведущий перевод строки писать нельзя: после снятия блока в файле
    # оставалась лишняя пустая строка, и сравнение с резервной копией при
    # откате никогда не совпадало. Вместо этого дописываем перевод строки
    # в конец файла, если его там нет.
    if [ -s "$file" ]; then
        if [ -n "$(tail -c 1 "$file")" ]; then
            printf '\n' >> "$file"
        fi
    fi
    printf '/* dk:%s-begin */\n%s\n/* dk:%s-end */\n' "$tag" "$body" "$tag" >> "$file"
}

css_has() {
    grep -q "dk:$1-begin" "$2" 2>/dev/null
}

# GTK4-файл часто оказывается симлинком внутрь темы. Писать туда нельзя:
# правки уедут в тему и пропадут при её переустановке.
untangle_css() {
    local file="$1"
    local label="$2"
    # Раньше здесь безусловно делались rm и touch — из-за этого --dry-run
    # создавал пустой gtk.css и сносил симлинк темы, ничего не спросив.
    if [ "$DRY_RUN" = "1" ]; then
        if [ -L "$file" ]; then
            note "(проверка) сняли бы симлинк $file"
        fi
        return 0
    fi
    if [ -L "$file" ]; then
        local target
        target=$(readlink -f "$file")
        backup_once "$file" "$label"
        rm -f "$file"
        touch "$file"
        note "симлинк на тему снят (тема лежала в $target)"
        note "правки в симлинк уехали бы внутрь темы и пропали при её обновлении"
    fi
    mkdir -p "$(dirname "$file")"
    touch "$file"
}

untangle_gtk4() {
    untangle_css "$CSS4" "gtk-4.0-gtk.css"
}

untangle_gtk3() {
    untangle_css "$CSS3" "gtk-3.0-gtk.css"
}

# ------------------------------------------------------- перезапуски

restart_gtk_apps() {
    if have nautilus; then
        if would "закрыть Nautilus"; then
            :
        else
            nautilus -q >/dev/null 2>&1
            ok "Nautilus закрыт — откроется с новым видом"
        fi
    fi
    if pgrep -x gnome-terminal-server >/dev/null 2>&1; then
        note "gnome-terminal-server работает: терминал держит старый вид"
        note "закрыть (все вкладки закроются): pkill -x gnome-terminal-server"
    fi
}

restart_conky() {
    if ! have conky; then
        return 0
    fi
    if would "перезапустить conky"; then
        return 0
    fi
    pkill -x conky >/dev/null 2>&1
    sleep 1
    nohup conky -c "$CONKY_CONF" >/dev/null 2>&1 &
    sleep 1
    if pgrep -x conky >/dev/null 2>&1; then
        ok "conky перезапущен"
    else
        bad "conky не поднялся — проверь: conky -c $CONKY_CONF"
    fi
}

# ------------------------------------------------------------ проверки

# shift N при нехватке аргументов НЕ сдвигает ничего и возвращает ошибку.
# Без set -e разбор пошёл бы по кругу с тем же $1 — бесконечный цикл.
# Поэтому сдвигаем ровно столько, сколько есть, и говорим об этом вслух.
need_args() {
    local flag="$1"
    local want="$2"
    local have_n="$3"
    if [ "$have_n" -lt "$want" ]; then
        die "$flag: нужно значений — $want, передано $have_n"
    fi
}

is_number() {
    echo "$1" | grep -qE '^[0-9]+$'
}

is_decimal() {
    echo "$1" | grep -qE '^[0-9]+(\.[0-9]+)?$'
}

is_hex_colour() {
    echo "$1" | grep -qE '^#[0-9a-fA-F]{6}$'
}

require_tools() {
    local missing=""
    for t in "$@"; do
        if ! have "$t"; then
            missing="$missing $t"
        fi
    done
    if [ -n "$missing" ]; then
        die "не хватает:$missing — sudo apt install -y$missing"
    fi
}

# =====================================================================
#  buttons — кнопки заголовка окна
# =====================================================================

help_buttons() {
    cat <<'EOF'
buttons — кнопки заголовка: размер, значки, подсветка

  desktop-kit buttons [параметры]

  --size W H            размер кнопки, по умолчанию 46 34
  --icon N              размер значка в GTK4, по умолчанию 20
  --gtk3-scale S        масштаб значка в GTK3, по умолчанию 1.0
                        (выше 1.3 значок пикселит: GTK3 растягивает готовый растр)
  --hover COLOR         подсветка при наведении, по умолчанию из цвета текста
  --hover none          НЕ трогать фон кнопки: только размеры. Нужно темам,
                        которые рисуют кнопки заголовка сами — WhiteSur и
                        прочие macOS-подобные. Наши обычные правила гасят
                        их фон, и кнопка становится пустой.
  --close COLOR         цвет кнопки закрытия, по умолчанию #e81123
  --radius N            скругление подсветки, по умолчанию 0 (квадрат)
  --glyphs fluent|keep  откуда брать значки, по умолчанию fluent
  --diagnose            разобрать, почему значков не видно

  ГОТОВЫЕ НАБОРЫ (имя вместо флагов):
    desktop-kit buttons thin
EOF
    presets_list buttons
    cat <<'EOF'

  Флаги после имени набора перекрывают его: buttons thin --icon 24.

  Значки Fluent ставятся темой-наследником: текущая тема иконок
  наследуется целиком, подменяются ровно четыре значка. Папки и
  приложения остаются прежними.

  ЧТО КОМАНДА ДЕЛАЕТ ПОМИМО ОЧЕВИДНОГО:
    * качает 4 значка с GitHub — нужны curl и сеть;
    * создаёт тему <текущая>-dk-glyphs и переключает систему на неё,
      поэтому в настройках тема значков будет называться иначе;
    * если ~/.config/gtk-4.0/gtk.css был симлинком в тему — снимает
      ссылку, иначе наши правила уехали бы внутрь темы;
    * revert buttons возвращает базовую тему значков и удаляет наследника,
      а тему, выбранную командой icons ПОСЛЕ, не трогает.

  --hover с явным цветом перестаёт подстраиваться под тему: по умолчанию
  подсветка задана как alpha(currentColor), и она следует за схемой сама.

  Не подействует на Chrome, Tabby, Telegram — это Electron, они рисуют
  кнопки сами. И на Kate — она Qt, у неё свой движок тем.
EOF
}

# Разбор проблемы «значков не видно». Кнопку заголовка рисуют ТРИ
# независимых источника: тема GTK (фон и размер), тема значков (форма
# глифа) и наши правила. Команда показывает состояние всех трёх.
diagnose_buttons() {
    head1 "разбор кнопок заголовка"

    local gtk_theme
    local icon_theme
    local base
    gtk_theme=$(gi_get gtk-theme)
    icon_theme=$(gi_get icon-theme)
    base=$(icon_base_of "$icon_theme")
    note "тема окон:    $gtk_theme"
    note "тема значков: $icon_theme"
    note "схема:        $(gi_get color-scheme)"

    # 1. Наш наследник и его глифы
    blank
    local dir="$HOME/.local/share/icons/$icon_theme"
    case "$icon_theme" in
        *-dk-glyphs|*-Fluent-Titlebar)
            if [ -d "$dir" ]; then
                ok "каталог наследника есть: $dir"
                local n
                n=$(find "$dir" -name 'window-*-symbolic.svg' 2>/dev/null | wc -l)
                note "значков заголовка в нём: $n из 4"
                # Зашитый светлый цвет — самая частая причина «пропажи»
                # на светлой теме: белый глиф на белом заголовке.
                local svg
                svg=$(find "$dir" -name 'window-close-symbolic.svg' 2>/dev/null | head -1)
                if [ -n "$svg" ]; then
                    local fills
                    fills=$(grep -o 'fill="[^"]*"' "$svg" 2>/dev/null | sort -u | tr '
' ' ')
                    if [ -z "$fills" ]; then
                        note "цвет в SVG не зашит — глиф перекрашивается темой"
                    else
                        note "цвета в SVG: $fills"
                        case "$fills" in
                            *'#fff'*|*'#FFF'*|*white*)
                                bad "в глифе зашит белый цвет"
                                note "на светлой теме он не виден — отсюда «значков нет»"
                                note "лечится так: $0 buttons --glyphs keep"
                                ;;
                        esac
                    fi
                fi
                if [ ! -d "$HOME/.local/share/icons/$base" ]; then
                    if [ ! -d "$SYS_ICONS/$base" ]; then
                        bad "базовая тема '$base' не найдена — наследовать не от чего"
                        note "остальные значки будут запасными из Adwaita"
                    fi
                fi
            else
                bad "тема значков '$icon_theme' выбрана, а каталога нет"
                note "именно так выглядят «пустые» кнопки: глиф взять неоткуда"
                note "почини так: $0 buttons"
            fi
            ;;
        *)
            note "наш наследник не активен — глифы даёт сама тема значков"
            ;;
    esac

    # 2. Наши правила
    blank
    local f
    for f in "$CSS3" "$CSS4"; do
        local label
        label=$(basename "$(dirname "$f")")
        if [ -f "$f" ]; then
            if grep -q 'dk:buttons-begin' "$f"; then
                ok "$label: наши правила есть"
            else
                note "$label: наших правил нет"
            fi
        else
            note "$label: файла нет"
        fi
    done

    # 3. Что про кнопки говорит сама тема GTK
    blank
    local tdir=""
    for d in "$HOME/.themes/$gtk_theme" "$HOME/.local/share/themes/$gtk_theme"              "$SYS_THEMES/$gtk_theme"; do
        if [ -d "$d" ]; then
            tdir="$d"
        fi
    done
    if [ -z "$tdir" ]; then
        bad "каталог темы '$gtk_theme' не найден"
    else
        note "каталог темы: $tdir"
        local t3="$tdir/gtk-3.0/gtk.css"
        if [ -f "$t3" ]; then
            local own
            own=$(grep -c 'titlebutton' "$t3" 2>/dev/null)
            note "упоминаний titlebutton в теме (GTK3): $own"
            if grep -q 'titlebutton.*background-image\|background-image.*titlebutton' "$t3" 2>/dev/null; then
                bad "тема рисует кнопки картинкой (background-image)"
                note "наши правила её гасят — кнопка становится пустой"
                note "для такой темы лучше: $0 buttons --glyphs keep --hover none"
            fi
        fi
    fi

    blank
    note "если значки видно только под курсором — глиф сливается с фоном:"
    note "  цвет глифа задаёт ТЕМА ЗНАЧКОВ, а фон заголовка — тема окон"
    note "быстрые проверки:"
    note "  $0 buttons --glyphs keep      родные значки темы, наша геометрия"
    note "  $0 revert buttons             вернуть всё как было"
    return 0
}

# Аргументы, которыми можно повторить текущее применение кнопок.
# Собираются из переменных самой команды: полагаться на строку аргументов
# запуска нельзя — при вызове из tune там лежит слово "buttons".
buttons_args() {
    local a="--size $btn_w $btn_h --icon $btn_icon"
    a="$a --gtk3-scale $gtk3_scale --radius $radius --close $close_colour"
    if [ "$glyphs" != "fluent" ]; then
        a="$a --glyphs $glyphs"
    fi
    if [ "$minimal" = "1" ]; then
        a="$a --hover none"
    else
        if [ -n "$hover_colour" ]; then
            a="$a --hover $hover_colour"
        fi
    fi
    printf '%s' "$a"
}

cmd_buttons() {
    if preset_expand buttons "${1:-}"; then
        shift
        set -- $PRESET_ARGS "$@"
        note "набор '$PRESET_USED': $PRESET_ARGS"
    fi
    local btn_w=46
    local btn_h=34
    local btn_icon=20
    local gtk3_scale="1.0"
    local hover_colour=""
    local close_colour="#e81123"
    local radius=0
    local glyphs="fluent"

    while [ $# -gt 0 ]; do
        case "$1" in
            --size) need_args "--size" 3 "$#"; btn_w="$2"; btn_h="$3"; shift 3 ;;
            --icon) need_args "--icon" 2 "$#"; btn_icon="${2:-20}"; shift 2 ;;
            --gtk3-scale) need_args "--gtk3-scale" 2 "$#"; gtk3_scale="${2:-1.0}"; shift 2 ;;
            --hover) need_args "--hover" 2 "$#"; hover_colour="${2:-}"; shift 2 ;;
            --close) need_args "--close" 2 "$#"; close_colour="${2:-#e81123}"; shift 2 ;;
            --radius) need_args "--radius" 2 "$#"; radius="${2:-0}"; shift 2 ;;
            --glyphs) need_args "--glyphs" 2 "$#"; glyphs="${2:-fluent}"; shift 2 ;;
            --diagnose)   diagnose_buttons; return $? ;;
            -h|--help)    help_buttons; return 0 ;;
            *) die "buttons: неизвестный параметр $1" ;;
        esac
    done

    for v in "$btn_w" "$btn_h" "$btn_icon" "$radius"; do
        if ! is_number "$v"; then
            die "buttons: размеры и радиус — целые числа"
        fi
    done
    if ! is_decimal "$gtk3_scale"; then
        die "buttons: масштаб — число, например 1.0 или 1.25"
    fi
    # «none» — режим минимального вмешательства: только размеры. Нужен
    # темам, которые рисуют кнопки заголовка сами (WhiteSur и прочие
    # macOS-подобные): наши правила гасят их фон, и кнопка пустеет.
    local minimal=0
    if [ "$hover_colour" = "none" ]; then
        minimal=1
        hover_colour=""
    fi
    if [ -n "$hover_colour" ]; then
        if ! is_hex_colour "$hover_colour"; then
            die "buttons: цвет в виде #rrggbb или none"
        fi
    fi
    if ! is_hex_colour "$close_colour"; then
        die "buttons: цвет закрытия в виде #rrggbb"
    fi

    head1 "кнопки заголовка"

    # Что именно мы гасим у кнопки. В минимальном режиме — ничего:
    # тема сама рисует и фон, и глиф.
    local bg_reset="  background-image: none;
  box-shadow: none;
  border: none;
"
    if [ "$minimal" = "1" ]; then
        bg_reset=""
    fi
    local hover_value="alpha(currentColor, 0.14)"
    local active_value="alpha(currentColor, 0.24)"
    if [ -n "$hover_colour" ]; then
        hover_value="$hover_colour"
        active_value="$hover_colour"
    fi
    local close_active=$(darken_hex "$close_colour")

    local glyphs_ok=1
    if [ "$glyphs" = "fluent" ]; then
        if ! install_fluent_glyphs; then
            glyphs_ok=0
        fi
    fi

    # Пока в файле лежат правила предшественника, наши будут спорить с ними
    # за те же селекторы — снимаем их до записи.
    if has_legacy_css; then
        note "в gtk.css найдены правила старого look.sh"
        if [ "$DRY_RUN" = "1" ]; then
            note "(проверка) спросил бы, убирать ли их"
        else
            if confirm "убрать их? (иначе два набора правил будут спорить)"; then
                strip_legacy_css
            else
                note "оставляю; учти, что вид может получиться смешанным"
            fi
        fi
    fi

    untangle_gtk3
    backup_once "$CSS3" "gtk-3.0-gtk.css"
    untangle_gtk4
    backup_once "$CSS4" "gtk-4.0-gtk.css"

    if would "записать правила кнопок"; then
        return 0
    fi

    # Минимальный режим: тема рисует кнопки сама, мы только задаём размер.
    # Никаких сбросов фона и своей подсветки — иначе кнопка пустеет.
    if [ "$minimal" = "1" ]; then
        css_append buttons "$CSS3" "$(cat <<EOF
/* только размеры: фон и глиф оставлены теме */
headerbar button.titlebutton,
.titlebar button.titlebutton,
button.titlebutton {
  min-width: ${btn_w}px;
  min-height: ${btn_h}px;
}

headerbar button.titlebutton image,
.titlebar button.titlebutton image,
button.titlebutton image {
  -gtk-icon-transform: scale(${gtk3_scale});
}
EOF
)"
        css_append buttons "$CSS4" "$(cat <<EOF
/* только размеры: фон и глиф оставлены теме */
windowcontrols > button,
headerbar windowcontrols > button {
  min-width: ${btn_w}px;
  min-height: ${btn_h}px;
}

windowcontrols > button > image {
  -gtk-icon-size: ${btn_icon}px;
}
EOF
)"
        state_set BTN_ARGS "$(buttons_args)"
        ok "кнопка ${btn_w}x${btn_h}, значок ${btn_icon} — остальное оставлено теме"
        if [ "$glyphs_ok" = "0" ]; then
            note "значки Fluent не ставились"
        fi
        restart_gtk_apps
        return 0
    fi

    css_append buttons "$CSS3" "$(cat <<EOF
/* GTK3: круг рисует сама кнопка (%circular-button в темах).
   -gtk-icon-size здесь не существует, размер значка — только масштабом. */
headerbar button.titlebutton,
.titlebar button.titlebutton,
button.titlebutton {
  min-width: ${btn_w}px;
  min-height: ${btn_h}px;
  padding: 0;
  margin: 0;
${bg_reset}  border-radius: ${radius}px;
}

headerbar button.titlebutton image,
.titlebar button.titlebutton image,
button.titlebutton image {
  -gtk-icon-transform: scale(${gtk3_scale});
  background-color: transparent;
  background-image: none;
  border-radius: 0;
  padding: 0;
  box-shadow: none;
}

headerbar button.titlebutton:hover,
.titlebar button.titlebutton:hover,
button.titlebutton:hover {
  background-color: ${hover_value};
  background-image: none;
  border-radius: ${radius}px;
}

headerbar button.titlebutton:hover image,
button.titlebutton:hover image {
  background-color: transparent;
  border-radius: 0;
}

headerbar button.titlebutton:active,
button.titlebutton:active {
  background-color: ${active_value};
  border-radius: ${radius}px;
}

headerbar button.titlebutton.close:hover,
.titlebar button.titlebutton.close:hover,
button.titlebutton.close:hover {
  background-color: ${close_colour};
  background-image: none;
  color: #ffffff;
  border-radius: ${radius}px;
}

headerbar button.titlebutton.close:hover image,
button.titlebutton.close:hover image {
  background-color: transparent;
  color: #ffffff;
}

headerbar button.titlebutton.close:active,
button.titlebutton.close:active {
  background-color: ${close_active};
  color: #ffffff;
  border-radius: ${radius}px;
}
EOF
)"

    css_append buttons "$CSS4" "$(cat <<EOF
/* GTK4/libadwaita: фон и круг рисует ДОЧЕРНИЙ image, а не кнопка.
   Сама кнопка всегда background: none, поэтому чистим image. */
windowcontrols > button,
headerbar windowcontrols > button {
  min-width: ${btn_w}px;
  min-height: ${btn_h}px;
  padding: 0;
  margin: 0;
  background-image: none;
  box-shadow: none;
  border: none;
  border-radius: ${radius}px;
}

windowcontrols > button > image {
  background-color: transparent;
  background-image: none;
  border-radius: 0;
  padding: 0;
  margin: 0;
  box-shadow: none;
  -gtk-icon-size: ${btn_icon}px;
}

windowcontrols > button:hover {
  background-color: ${hover_value};
  background-image: none;
  border-radius: ${radius}px;
}

windowcontrols > button:hover > image {
  background-color: transparent;
  border-radius: 0;
}

windowcontrols > button:active {
  background-color: ${active_value};
  border-radius: ${radius}px;
}

windowcontrols > button:active > image {
  background-color: transparent;
  border-radius: 0;
}

windowcontrols > button.close:hover {
  background-color: ${close_colour};
  background-image: none;
  border-radius: ${radius}px;
}

windowcontrols > button.close:hover > image {
  background-color: transparent;
  color: #ffffff;
  border-radius: 0;
}

windowcontrols > button.close:active {
  background-color: ${close_active};
  border-radius: ${radius}px;
}

windowcontrols > button.close:active > image {
  background-color: transparent;
  color: #ffffff;
}
EOF
)"

    # Запоминаем, чем именно применяли: установщики тем любят перезаписать
    # ~/.config/gtk-4.0/gtk.css целиком, и тогда правила надо вернуть теми же
    # параметрами, а не по умолчанию.
    state_set BTN_ARGS "$(buttons_args)"
    ok "кнопка ${btn_w}x${btn_h}, значок ${btn_icon} (GTK4), масштаб ${gtk3_scale} (GTK3)"
    ok "подсветка: радиус ${radius}px, закрытие ${close_colour}"
    if [ "$glyphs_ok" = "0" ]; then
        bad "значки Fluent НЕ установлены — применена только геометрия"
        note "форма значков осталась родной; повтори команду, когда будет сеть"
    fi
    restart_gtk_apps
}

# затемнить цвет для состояния нажатия
darken_hex() {
    local hex="${1#\#}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    r=$((r * 78 / 100))
    g=$((g * 78 / 100))
    b=$((b * 78 / 100))
    printf '#%02x%02x%02x' "$r" "$g" "$b"
}

# Papirus не содержит window-*-symbolic — GNOME подставляет Adwaita.
# Поэтому значки кладём в тему-наследник поверх текущей.
install_fluent_glyphs() {
    local cur
    cur=$(gi_get icon-theme)
    local base
    base=$(icon_base_of "$cur")
    if [ -z "$base" ]; then
        base="Adwaita"
    fi
    local theme="$base-dk-glyphs"
    local dir="$HOME/.local/share/icons/$theme"

    src=""
    for d in "$HOME/.local/share/icons/$base" "$HOME/.icons/$base" "$SYS_ICONS/$base"; do
        if [ -d "$d" ]; then
            src="$d"
        fi
    done
    if [ -z "$src" ]; then
        bad "тема иконок $base не найдена — значки оставляю прежними"
        return 1
    fi

    if would "поставить значки Fluent поверх $base"; then
        return 0
    fi

    require_tools curl
    # Каталог собирается во временном месте и подменяется целиком только
    # после успешного скачивания: иначе повторный запуск при обрыве сети
    # оставил бы пользователя без активной темы значков.
    local staging
    staging=$(mktemp -d)
    mkdir -p "$staging/symbolic/actions"
    local got=0
    for n in close maximize minimize restore; do
        local f="$staging/symbolic/actions/window-$n-symbolic.svg"
        local code=$(curl -sf -L --max-time 30 -o "$f" -w '%{http_code}' \
               "$FLUENT_ICONS/window-$n-symbolic.svg" 2>/dev/null)
        if [ "$code" = "200" ]; then
            if head -c 200 "$f" 2>/dev/null | grep -q '<svg'; then
                got=$((got + 1))
            else
                rm -f "$f"
            fi
        else
            rm -f "$f"
        fi
    done

    if [ "$got" -ne 4 ]; then
        bad "скачалось значков $got из 4 — оставляю прежние"
        rm -rf "$staging"
        return 1
    fi

    cat > "$staging/index.theme" <<EOF
[Icon Theme]
Name=$theme
Comment=$base со значками заголовка из Fluent
Inherits=$base,Adwaita,hicolor
Directories=symbolic/actions

[symbolic/actions]
Size=16
MinSize=8
MaxSize=512
Context=Actions
Type=Scalable
EOF
    rm -rf "$dir"
    mkdir -p "$(dirname "$dir")"
    mv "$staging" "$dir"
    if have gtk-update-icon-cache; then
        gtk-update-icon-cache -f "$dir" >/dev/null 2>&1
    fi
    # ICON_THEME принадлежит команде icons. Кнопки помнят СВОЁ: точное имя
    # темы, которая стояла до них. Выводить его из имени наследника нельзя —
    # у темы предшественника (X-Fluent-Titlebar) база X, и откат вернул бы
    # не то, что было.
    case "$cur" in
        *-dk-glyphs) : ;;
        *) state_set BTN_PREV_ICON "$cur" ;;
    esac
    gi_set icon-theme "$theme"
    ok "значки Fluent поверх $base"
    return 0
}

# =====================================================================
#  corners — скругление окон
# =====================================================================

help_corners() {
    cat <<'EOF'
corners — скругление углов окон, меню и подсказок

  desktop-kit corners [--radius N]
  desktop-kit corners ИМЯ-НАБОРА
EOF
    presets_list corners
    cat <<'EOF' 

  --radius N    радиус в пикселях, по умолчанию 0 (строго прямые углы)

  Мутер скругление окон не настраивает — форму задаёт только тема,
  поэтому правится через css. В bspwm то же самое делает picom своим
  corner-radius, но в GNOME такого рычага нет.
EOF
}

# =====================================================================
#  tune — настройка вопросами
# =====================================================================

help_tune() {
    cat <<'EOF'
tune — настроить, отвечая на вопросы

  desktop-kit tune             пройти по всем разделам
  desktop-kit tune РАЗДЕЛ      только один раздел

  Разделы: corners buttons widget newtab terminal theme font

  Отличие от обычных команд: ничего не применяется молча. По каждой
  настройке видно, что стоит сейчас, какие есть варианты и что каждый
  из них значит. Пустой ответ оставляет как есть, так что можно пройти
  весь мастер на Enter и ничего не изменить.

  В конце раздела показывается команда с флагами, которая делает то же
  самое — чтобы в следующий раз можно было без вопросов.
EOF
}

# Показать, какой командой можно повторить сделанное без вопросов
tune_recap() {
    blank
    note "то же самое одной командой:"
    note "  $0 $*"
}

cmd_tune() {
    local part="${1:-all}"
    case "$part" in
        -h|--help) help_tune; return 0 ;;
    esac

    # Имя раздела проверяем ДО терминала: на опечатку надо отвечать
    # списком разделов, а не рассказом про отсутствие ввода.
    case "$part" in
        all|corners|buttons|widget|newtab|terminal|theme|font) : ;;
        *)
            bad "нет раздела '$part'"
            note "есть: corners buttons widget newtab terminal theme font"
            return 1
            ;;
    esac

    if ! ask_possible; then
        bad "нечем спрашивать: нет терминала"
        note "запусти вручную, без перенаправления ввода"
        return 1
    fi

    case "$part" in
        all)
            head1 "настройка вопросами"
            note "пустой ответ = оставить как есть, можно жать Enter"
            tune_corners
            tune_buttons
            tune_widget
            tune_newtab
            tune_terminal
            blank
            ok "готово"
            note "посмотреть, что вышло: $0 status"
            ;;
        corners)  tune_corners ;;
        buttons)  tune_buttons ;;
        widget)   tune_widget ;;
        newtab)   tune_newtab ;;
        terminal) tune_terminal ;;
        theme)    tune_theme ;;
        font)     tune_font ;;
    esac
    return 0
}

# --------------------------------------------------------------- углы

tune_corners() {
    ask_head "Форма углов окон" "касается окон, меню и подсказок"

    local now
    now=$(state_get CORNERS_RADIUS)
    if [ -z "$now" ]; then
        now=0
    fi

    ask_pick "какие углы нужны?" "$now" \
        0 "острые, как в Tabby и Windows" \
        6 "едва скруглённые" \
        12 "заметно скруглённые, как в GNOME по умолчанию" \
        20 "сильно скруглённые"
    local radius="$ASK_ANSWER"

    if ! is_number "$radius"; then
        bad "радиус — целое число, пропускаю раздел"
        return 1
    fi

    cmd_corners --radius "$radius"
    state_set CORNERS_RADIUS "$radius"
    tune_recap "corners --radius $radius"
}

# ------------------------------------------------------------- кнопки

tune_buttons() {
    ask_head "Кнопки заголовка" "крестик, свернуть, развернуть"

    local w
    local h
    local ic
    local rad
    local close
    w=$(state_get BTN_W)
    h=$(state_get BTN_H)
    ic=$(state_get BTN_ICON)
    rad=$(state_get BTN_RADIUS)
    close=$(state_get BTN_CLOSE)
    if [ -z "$w" ]; then w=46; fi
    if [ -z "$h" ]; then h=34; fi
    if [ -z "$ic" ]; then ic=20; fi
    if [ -z "$rad" ]; then rad=0; fi
    if [ -z "$close" ]; then close="#e81123"; fi

    ask_num "ширина кнопки" "$w" 20 80
    w="$ASK_ANSWER"
    ask_num "высота кнопки" "$h" 16 60
    h="$ASK_ANSWER"
    ask_num "размер значка" "$ic" 10 40 "в GTK4; в GTK3 значок растягивается и выше 26 пикселит"
    ic="$ASK_ANSWER"

    ask_pick "форма подсветки под курсором" "$rad" \
        0 "квадрат" \
        4 "чуть скруглённый квадрат" \
        999 "круг"
    rad="$ASK_ANSWER"

    ask_pick "цвет кнопки закрытия" "$close" \
        "#e81123" "красный, как в Windows" \
        "#c42b1c" "приглушённый красный" \
        "none" "не красить, оставить теме"
    close="$ASK_ANSWER"

    local args="--size $w $h --icon $ic --radius $rad"
    if [ "$close" != "none" ]; then
        args="$args --close $close"
    fi

    blank
    if ask_yes "тема сама рисует кнопки (WhiteSur и подобные)?"; then
        args="$args --glyphs keep --hover none"
        note "тогда меняем только размеры, остальное отдаём теме"
    fi

    cmd_buttons $args
    state_set BTN_W "$w"
    state_set BTN_H "$h"
    state_set BTN_ICON "$ic"
    state_set BTN_RADIUS "$rad"
    state_set BTN_CLOSE "$close"
    tune_recap "buttons $args"
}

# ------------------------------------------------------------- виджет

tune_widget() {
    if [ ! -f "$CONKY_CONF" ]; then
        note "конфига conky нет, раздел пропускаю"
        return 0
    fi

    ask_head "Виджет на рабочем столе" "conky: подложка и текст"

    local colour
    local ink
    local alpha
    local radius
    colour=$(conf_value own_window_colour "$CONKY_CONF")
    ink=$(conf_value default_color "$CONKY_CONF")
    alpha=$(state_get CONKY_ALPHA)
    radius=$(state_get CONKY_RADIUS)
    if [ -z "$colour" ]; then colour="1e1e2e"; fi
    if [ -z "$ink" ]; then ink="ffffff"; fi
    if [ -z "$alpha" ]; then alpha=225; fi
    if [ -z "$radius" ]; then radius=12; fi

    ask_pick "форма подложки" "$radius" \
        0 "прямые углы" \
        12 "скруглённые" \
        24 "сильно скруглённые"
    radius="$ASK_ANSWER"

    ask_num "плотность подложки" "$alpha" 0 255 "0 — насквозь прозрачная, 255 — сплошная"
    alpha="$ASK_ANSWER"

    ask_pick "цвет подложки" "$colour" \
        "1e1e2e" "тёмный, под тёмную тему" \
        "f2f2f2" "светлый, под светлую тему" \
        "000000" "чёрный"
    colour="$ASK_ANSWER"

    ask_pick "цвет текста" "$ink" \
        "ffffff" "белый, для тёмной подложки" \
        "1e1e2e" "тёмный, для светлой подложки"
    ink="$ASK_ANSWER"

    local args="--radius $radius --opacity $alpha --colour $colour --text $ink"
    cmd_widget $args
    state_set CONKY_RADIUS "$radius"
    tune_recap "widget $args"

    blank
    note "что показывает виджет — это его конфиг: $CONKY_CONF"
    note "секция conky.text внизу файла, каждая строка — одна строка виджета"
    if ask_yes "показать, из чего он сейчас состоит?"; then
        blank
        sed -n '/conky.text/,$p' "$CONKY_CONF" | head -25 | dump
        blank
        note "полезные переменные conky:"
        note "  \${time %H:%M}         часы"
        note "  \${cpu}%               загрузка процессора"
        note "  \${memperc}%           память"
        note "  \${fs_used_perc /}%    диск"
        note "  \${downspeedf wlp0s20f3}  скорость приёма"
        note "  \${execi 600 команда}  вывод своей команды раз в 600 секунд"
        note "правится обычным редактором, потом: pkill conky; conky -c $CONKY_CONF &"
    fi
}

# ------------------------------------------------- страница новой вкладки

tune_newtab() {
    ask_head "Страница новой вкладки" "часы, ярлыки, фон"

    local n=0
    if [ -f "$NEWTAB_LINKS" ]; then
        n=$(grep -c '|' "$NEWTAB_LINKS" 2>/dev/null)
    fi
    note "сейчас ярлыков: $n"

    while true; do
        blank
        if ! ask_yes "добавить ярлык?"; then
            break
        fi
        ask_str "название (коротко, до 22 знаков)"
        local nm="$ASK_ANSWER"
        if [ -z "$nm" ]; then
            note "без названия пропускаю"
            continue
        fi
        ask_str "адрес (можно без https://)"
        local url="$ASK_ANSWER"
        if [ -z "$url" ]; then
            note "без адреса пропускаю"
            continue
        fi
        case "$url" in
            http://*|https://*|file://*) : ;;
            *) url="https://$url" ;;
        esac
        cmd_newtab --add "$nm|$url"
    done

    if [ "$n" -gt 0 ]; then
        blank
        if ask_yes "убрать какой-нибудь ярлык?"; then
            cmd_newtab --list
            ask_str "название, которое убрать"
            if [ -n "$ASK_ANSWER" ]; then
                cmd_newtab --remove "$ASK_ANSWER"
            fi
        fi
    fi

    blank
    local clock
    local tile
    clock=$(state_get NEWTAB_CLOCK)
    tile=$(state_get NEWTAB_TILE)
    if [ -z "$clock" ]; then clock=110; fi
    if [ -z "$tile" ]; then tile=130; fi
    ask_num "размер часов" "$clock" 40 260
    clock="$ASK_ANSWER"
    ask_num "ширина плитки ярлыка" "$tile" 80 220
    tile="$ASK_ANSWER"

    cmd_newtab --clock "$clock" --tile "$tile"
    state_set NEWTAB_CLOCK "$clock"
    state_set NEWTAB_TILE "$tile"
    tune_recap "newtab --clock $clock --tile $tile"
}

# ----------------------------------------------------------- терминал

tune_terminal() {
    ask_head "Терминал" "прозрачность и шрифт GNOME Terminal"

    local prof
    prof=$(term_profile)
    if [ -z "$prof" ]; then
        note "профиль GNOME Terminal не найден, раздел пропускаю"
        return 0
    fi

    local op
    op=$(gsettings get "$prof" background-transparency-percent 2>/dev/null)
    if [ -z "$op" ]; then op=0; fi

    ask_num "прозрачность фона" "$op" 0 100 "0 — непрозрачный, 30 уже заметно"
    local newop="$ASK_ANSWER"

    local args="--opacity $newop"
    blank
    if ask_yes "взять цвета из текущих обоев (pywal)?"; then
        args="$args --palette wal"
    fi

    cmd_terminal $args
    tune_recap "terminal $args"
}

# --------------------------------------------------------------- тема

tune_theme() {
    ask_head "Тема оформления" "список установленных"
    list_themes | dump
    blank
    ask_str "имя темы (Enter — не менять)"
    if [ -n "$ASK_ANSWER" ]; then
        cmd_theme "$ASK_ANSWER"
        tune_recap "theme $ASK_ANSWER"
    fi
}

# -------------------------------------------------------------- шрифт

tune_font() {
    ask_head "Шрифт интерфейса" "сейчас: $(gi_get font-name)"
    ask_str "шрифт и размер, например Cantarell 11"
    if [ -n "$ASK_ANSWER" ]; then
        cmd_font "$ASK_ANSWER"
        tune_recap "font \"$ASK_ANSWER\""
    fi
}

help_refresh() {
    cat <<'EOF'
refresh — вернуть свои правила на место

  desktop-kit refresh

  Установщики тем нередко перезаписывают ~/.config/gtk-4.0/gtk.css целиком
  или делают его симлинком внутрь темы. Наши блоки при этом пропадают:
  в GTK4-приложениях возвращаются круглые подсветки кнопок и акцент темы,
  а в GTK3 всё остаётся как было — отсюда ощущение, что «сломался только
  файловый менеджер».

  Команда проверяет оба gtk.css и заново применяет buttons и corners
  ровно с теми параметрами, с какими они применялись в прошлый раз.
EOF
}

cmd_refresh() {
    head1 "проверка своих правил"

    # Симлинк в тему — правки уехали бы внутрь каталога темы
    local f
    for f in "$CSS3" "$CSS4"; do
        if [ -L "$f" ]; then
            bad "$f — симлинк на $(readlink -f "$f")"
            note "его сделал установщик темы; снимаю, чтобы правила остались у тебя"
            rm -f "$f"
        fi
    done

    local need=0
    if ! css_has buttons "$CSS4"; then
        need=1
    fi
    if ! css_has corners "$CSS4"; then
        need=1
    fi
    if ! css_has buttons "$CSS3"; then
        need=1
    fi

    local btn_args
    local cor_args
    btn_args=$(state_get BTN_ARGS)
    cor_args=$(state_get CORNERS_ARGS)

    if [ "$need" = "0" ]; then
        ok "правила на месте, возвращать нечего"
        return 0
    fi

    # Пусто не потому, что кто-то снёс, а потому, что ещё не настраивали.
    if [ -z "$btn_args" ]; then
        if [ -z "$cor_args" ]; then
            note "кнопки и углы ещё не настраивались — возвращать нечего"
            note "настроить: $0 tune"
            return 0
        fi
    fi

    note "часть правил пропала — скорее всего их снёс установщик темы"
    if [ -n "$btn_args" ]; then
        note "возвращаю кнопки: $btn_args"
        cmd_buttons $btn_args
    else
        note "кнопки раньше не настраивались, пропускаю"
    fi
    if [ -n "$cor_args" ]; then
        note "возвращаю углы: $cor_args"
        cmd_corners $cor_args
    else
        note "углы раньше не настраивались, пропускаю"
    fi
    return 0
}

cmd_corners() {
    if preset_expand corners "${1:-}"; then
        shift
        set -- $PRESET_ARGS "$@"
        note "набор '$PRESET_USED': $PRESET_ARGS"
    fi
    local radius=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --radius) need_args "--radius" 2 "$#"; radius="${2:-0}"; shift 2 ;;
            -h|--help) help_corners; return 0 ;;
            *) die "corners: неизвестный параметр $1" ;;
        esac
    done
    if ! is_number "$radius"; then
        die "corners: радиус — целое число"
    fi

    head1 "углы окон (радиус ${radius}px)"
    untangle_gtk3
    backup_once "$CSS3" "gtk-3.0-gtk.css"
    untangle_gtk4
    backup_once "$CSS4" "gtk-4.0-gtk.css"

    if would "записать правила углов"; then
        return 0
    fi

    css_append corners "$CSS3" "$(cat <<EOF
decoration,
decoration:backdrop,
window.csd,
window.background,
.titlebar,
headerbar,
menu,
.menu,
.context-menu,
popover.background,
tooltip,
tooltip.background {
  border-radius: ${radius}px;
}
EOF
)"

    css_append corners "$CSS4" "$(cat <<EOF
window,
window.csd,
window.background,
headerbar,
.titlebar,
popover > contents,
tooltip,
.card,
.toolbar {
  border-radius: ${radius}px;
}
EOF
)"

    state_set CORNERS_ARGS "--radius $radius"
    ok "радиус окон, меню и подсказок: ${radius}px"
    restart_gtk_apps
}

# =====================================================================
#  theme — тема GTK
# =====================================================================

help_theme() {
    cat <<'EOF'
theme — тема оформления окон

  desktop-kit theme               показать текущую и доступные
  desktop-kit theme ИМЯ           применить тему
  desktop-kit theme --list        только список доступных
  desktop-kit theme --install ИМЯ собрать и поставить известную тему
  desktop-kit theme --dark        тёмная цветовая схема
  desktop-kit theme --light       светлая цветовая схема

  Если названной темы нет, скрипт предложит собрать её из исходников —
  для известных ему тем (Graphite, Orchis, Colloid, Fluent, WhiteSur,
  Qogir, Jasper).

  desktop-kit theme --light       ТЕКУЩАЯ тема, но светлая
  desktop-kit theme --dark        ТЕКУЩАЯ тема, но тёмная
  desktop-kit theme --light --scheme-only   только схема, тему не трогать

  Про --light без имени темы: скрипт сам находит парный вариант той темы,
  что стоит сейчас — Graphite-Dark становится Graphite-Light, Yaru-dark
  становится Yaru. Знать название темы для этого не нужно. Если парного
  варианта в системе нет, скрипт не меняет НИЧЕГО и показывает список
  установленных светлых тем: смена одной лишь схемы дала бы светлый
  Nautilus при тёмном терминале.

  Тема и цветовая схема меняются ВМЕСТЕ. Рассинхрон однажды уже дал
  нечитаемый вид: тёмная тема при светлой схеме — половина окон серая.

  Тему значков команда НЕ трогает: они переживают смену темы окон.
  За темой сами не идут терминал, виджет conky и страница новой вкладки —
  скрипт напомнит об этом в конце.

  Ещё эта команда меняет тему оболочки GNOME (dconf user-theme), если у
  выбранной темы есть каталог gnome-shell.

  --install клонирует репозиторий вендора и запускает его install.sh.
  Это чужой код, выполняемый от твоего пользователя.

  На GTK4-приложения (Nautilus, Настройки) тема НЕ влияет: libadwaita
  её игнорирует. Их вид задаётся цветовой схемой и правилами из
  ~/.config/gtk-4.0/gtk.css.
EOF
}

theme_repo_for() {
    case "$1" in
        Graphite*) echo "https://github.com/vinceliuice/Graphite-gtk-theme.git" ;;
        Orchis*)   echo "https://github.com/vinceliuice/Orchis-theme.git" ;;
        Colloid*)  echo "https://github.com/vinceliuice/Colloid-gtk-theme.git" ;;
        Fluent*)   echo "https://github.com/vinceliuice/Fluent-gtk-theme.git" ;;
        WhiteSur*) echo "https://github.com/vinceliuice/WhiteSur-gtk-theme.git" ;;
        Qogir*)    echo "https://github.com/vinceliuice/Qogir-theme.git" ;;
        Jasper*)   echo "https://github.com/vinceliuice/Jasper-gtk-theme.git" ;;
        Lavanda*)  echo "https://github.com/vinceliuice/Lavanda-gtk-theme.git" ;;
        ChromeOS*) echo "https://github.com/vinceliuice/ChromeOS-theme.git" ;;
        Win11*)    echo "https://github.com/vinceliuice/Win11-gtk-theme.git" ;;
        Orianin*)  echo "https://github.com/vinceliuice/Orianin-gtk-theme.git" ;;
        Magnetic*) echo "https://github.com/vinceliuice/Magnetic-gtk-theme.git" ;;
        Vimix*)    echo "https://github.com/vinceliuice/Vimix-gtk-themes.git" ;;
        Layan*)    echo "https://github.com/vinceliuice/Layan-gtk-theme.git" ;;
        *) echo "" ;;
    esac
}

# =====================================================================
#  themes — банк готовых тем
# =====================================================================
#
# Отбор не по красоте, а по одному техническому признаку: рисует ли тема
# кнопки заголовка САМА. Такая тема задаёт кнопке собственную картинку, и
# наши значки в ней просто не видны — ровно то, что вышло с WhiteSur.
# Совместимость каждой темы проверена по её исходникам: искали
# background-image и -gtk-icon-source в правилах button.titlebutton
# (GTK3) и windowcontrols > button (GTK4).

help_themes() {
    cat <<'EOF'
themes — банк готовых тем оформления

  desktop-kit themes                     список тем банка
  desktop-kit themes --install ИМЯ       скачать и собрать одну
  desktop-kit themes --install ИМЯ ИМЯ   сразу несколько
  desktop-kit themes --all               поставить весь банк
  desktop-kit themes --check ИМЯ         проверить установленную тему

  В банке только темы, которые НЕ рисуют кнопки заголовка сами, то есть
  такие, где наши значки остаются на месте. Проверено по исходникам
  каждой темы, а не по описанию на её странице.

  Не вошли и почему:
    WhiteSur   рисует кнопки в стиле macOS собственной картинкой
    Layan      то же самое
    Colloid    по умолчанию рисует кружки macOS
    Toffee     рисует кнопки сама
  Поставить их можно обычным theme --install, но кнопки будут теминые.
  Если тема нравится: buttons --glyphs keep --hover none.

  Сборка требует git и sassc. Флаг -l у установщиков вендора трогать не
  надо: он делает ~/.config/gtk-4.0/gtk.css симлинком внутрь темы, и наши
  правила уехали бы туда же.

  После установки посмотреть имена: desktop-kit theme --list
EOF
}

themes_bank() {
    cat <<'EOF'
Graphite|строгая чёрно-белая, минимализм
Fluent|как Windows 11: мягкие тени, скруглённые панели
Qogir|спокойная и округлая, ближе к духу GNOME
Orchis|Material Design, сочные акценты
Jasper|плоская и яркая, крупные элементы
Lavanda|пастельная лавандовая, мягкие переходы
ChromeOS|светлая и чистая, в духе ChromeOS
Win11|подражание Windows 11, отдельная от Fluent
Orianin|современная тёмная с неоновым акцентом
Magnetic|контрастная, крупная типографика
Vimix|плоская с цветными акцентами, много расцветок
EOF
}

cmd_themes() {
    local action="list"
    local names=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --install)
                need_args "--install" 2 "$#"
                action="install"
                shift
                while [ $# -gt 0 ]; do
                    case "$1" in
                        -*) break ;;
                        *) names="$names $1"; shift ;;
                    esac
                done
                ;;
            --all)     action="all"; shift ;;
            --check)   need_args "--check" 2 "$#"; action="check"; names="$2"; shift 2 ;;
            -h|--help) help_themes; return 0 ;;
            *) die "themes: неизвестный параметр $1" ;;
        esac
    done

    case "$action" in
        list)      themes_list ;;
        all)       themes_install $(themes_bank | cut -d"|" -f1) ;;
        install)
            if [ -z "$names" ]; then
                die "themes: назови тему, например: $0 themes --install Graphite"
            fi
            themes_install $names
            ;;
        check)     themes_check "$names" ;;
    esac
}

themes_list() {
    head1 "банк тем"
    note "все совместимы с нашими значками заголовка"
    blank
    local nm
    local st
    local mark
    themes_bank | while IFS="|" read -r nm st; do
        mark=""
        if list_themes | grep -q "^$nm"; then
            mark="уже есть"
        fi
        printf "  %-10s %-44s %s\n" "$nm" "$st" "$mark"
    done
    blank
    note "поставить:  $0 themes --install Graphite Fluent Qogir"
    note "весь банк:  $0 themes --all   (каждая собирается из исходников)"
    note "примерить:  $0 theme ИМЯ-Dark   потом  $0 theme --light"
}

themes_install() {
    local nm
    local ok_n=0
    local bad_n=0
    head1 "установка тем"
    require_tools git sassc
    # Установщики вендоров кладут тему в ~/.themes только если каталог уже
    # существует, иначе выбирают другой путь. Создаём заранее.
    mkdir -p "$HOME/.themes"
    for nm in "$@"; do
        blank
        note "--- $nm ---"
        if [ -z "$(theme_repo_for "$nm")" ]; then
            bad "темы '$nm' в банке нет"
            note "список: $0 themes"
            bad_n=$((bad_n + 1))
            continue
        fi
        if install_theme "$nm"; then
            ok_n=$((ok_n + 1))
        else
            bad_n=$((bad_n + 1))
        fi
    done
    blank
    ok "поставлено: $ok_n, не вышло: $bad_n"

    # Установщики тем перезаписывают ~/.config/gtk-4.0/gtk.css, и наши
    # правила исчезают вместе с ним. Проверяем сразу, а не когда человек
    # заметит круглые кнопки в файловом менеджере.
    local lost=0
    if [ -L "$CSS4" ]; then
        lost=1
    fi
    if [ -n "$(state_get BTN_ARGS)" ]; then
        if ! css_has buttons "$CSS4"; then
            lost=1
        fi
    fi
    if [ "$lost" = "1" ]; then
        blank
        bad "установка темы затронула ~/.config/gtk-4.0/gtk.css"
        note "наши правила оттуда пропали — в GTK4-приложениях вернётся вид темы"
        if confirm "вернуть их на место?"; then
            cmd_refresh
        else
            note "потом вручную: $0 refresh"
        fi
    fi

    note "все имена:  $0 theme --list"
    note "примерить:  $0 theme ИМЯ"
    if [ "$bad_n" -gt 0 ]; then
        return 1
    fi
    return 0
}

# Проверка установленной темы на совместимость с нашими значками.
themes_check() {
    local nm="$1"
    local dir=""
    local d
    for d in "$HOME/.themes/$nm" "$HOME/.local/share/themes/$nm" "$SYS_THEMES/$nm"; do
        if [ -d "$d" ]; then
            dir="$d"
        fi
    done
    if [ -z "$dir" ]; then
        bad "темы '$nm' на диске нет"
        note "список установленных: $0 theme --list"
        return 1
    fi
    head1 "проверка темы $nm"
    note "каталог: $dir"

    local f
    local risky=0
    local hits
    local label
    local looked=0
    for f in "$dir/gtk-3.0/gtk.css" "$dir/gtk-4.0/gtk.css"; do
        if [ ! -f "$f" ]; then
            continue
        fi
        looked=$((looked + 1))
        label=$(basename "$(dirname "$f")")
        # Ищем правила кнопок, где тема подставляет собственную картинку.
        hits=$(grep "titlebutton\|windowcontrols" "$f" 2>/dev/null \
               | grep -c "background-image\|icon-source\|icontheme")
        if [ "$hits" -gt 0 ]; then
            bad "$label: кнопки рисуются картинкой ($hits мест)"
            risky=1
        else
            ok "$label: кнопки отданы теме значков"
        fi
    done

    # Ни одного gtk.css — проверять было нечего, и объявлять тему
    # совместимой нельзя: это разные вещи.
    if [ "$looked" = "0" ]; then
        blank
        bad "в теме нет ни gtk-3.0/gtk.css, ни gtk-4.0/gtk.css"
        note "проверять нечего — возможно, каталог темы неполный"
        return 1
    fi

    if [ "$risky" = "1" ]; then
        blank
        note "наши значки в этой теме видно не будет"
        note "если тема всё равно нравится:"
        note "  $0 buttons --glyphs keep --hover none"
        return 1
    fi
    blank
    ok "тема совместима — наши кнопки в ней работают"
    return 0
}

list_themes() {
    for d in "$HOME/.themes" "$HOME/.local/share/themes" "$SYS_THEMES"; do
        if [ -d "$d" ]; then
            for t in "$d"/*; do
                if [ -d "$t/gtk-3.0" ]; then
                    basename "$t"
                fi
            done
        fi
    done | sort -u
}

# имя каталога темы, как её назвал установщик вендора
THEME_INSTALLED=""
# имя темы, выбранной переключателем яркости
THEME_VARIANT_PICKED=""

# Суффиксы вариантов, которые реально встречаются в именах каталогов тем.
# Порядок важен: длинные идут первыми, иначе -Dark отрежет хвост у -Darker
# и базой станет "Graphite-Dar".
THEME_DARK_SUFFIXES="-Darker -darker -Dark -dark -DARK -Black -black"
THEME_LIGHT_SUFFIXES="-Lighter -lighter -Light -light -LIGHT -White -white"

# Регистр важен: каталог темы — это путь на диске. Но если совпадение
# нашлось только без учёта регистра, полезнее подсказать точное имя,
# чем сказать «темы нет».
theme_exists() {
    if [ -z "$1" ]; then
        return 1
    fi
    # -F обязателен: имя темы это данные. Без него 'DKT.Dark' совпал бы
    # с 'DKTxDark', и в настройки уехала бы несуществующая тема.
    list_themes | grep -qxF -- "$1"
}

# Сочетание -i -x -F у grep ненадёжно (на части сборок процесс падает
# с Aborted), поэтому регистр приводим сами, а сравниваем точно.
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

theme_real_name() {
    local want
    want=$(lower "$1")
    local th
    list_themes | while read -r th; do
        if [ "$(lower "$th")" = "$want" ]; then
            printf '%s
' "$th"
        fi
    done | head -1
}

theme_exists_ci() {
    local found
    found=$(theme_real_name "$1")
    if [ -n "$found" ]; then
        return 0
    fi
    return 1
}

# Слово-вариант может стоять НЕ в конце имени: у vinceliuice это
# Graphite-Dark-Square, Graphite-Light-nord, Colloid-Dark-Catppuccin.
# Поэтому имя разбираем по дефисам и ищем вариантное слово где угодно.
THEME_DARK_WORDS="darker dark black"
THEME_LIGHT_WORDS="lighter light white"

# Номер токена со словом варианта (считая с 1), пусто — слова нет.
# Разбираем через cut, а не через IFS='-': смена IFS меняет разбиение
# ВСЕГО внутри блока, и список слов "darker dark black" тогда становится
# одним словом. На этом уже обожглись.
theme_tokens() {
    # awk на пустом вводе не печатает ничего, и дальше сравнение с числом
    # валится с "integer expression expected". Пустое имя тут реально:
    # gi_get вернёт пустоту, если GNOME не отвечает.
    if [ -z "$1" ]; then
        echo 0
        return 0
    fi
    printf '%s' "$1" | awk -F- '{print NF}'
}

theme_token() {
    printf '%s' "$1" | cut -d- -f"$2"
}

theme_variant_pos() {
    local name="$1"
    if [ -z "$name" ]; then
        return 1
    fi
    local n
    n=$(theme_tokens "$name")
    if [ -z "$n" ]; then
        return 1
    fi
    local i=1
    local low
    local w
    while [ "$i" -le "$n" ]; do
        low=$(lower "$(theme_token "$name" "$i")")
        for w in $THEME_DARK_WORDS $THEME_LIGHT_WORDS; do
            if [ "$low" = "$w" ]; then
                printf '%s
' "$i"
                return 0
            fi
        done
        i=$((i + 1))
    done
    return 1
}

# Светлая тема, тёмная или по имени не понять.
theme_variant_of() {
    local name="$1"
    local pos
    pos=$(theme_variant_pos "$name")
    if [ -z "$pos" ]; then
        echo "unknown"
        return 0
    fi
    local tok
    tok=$(lower "$(theme_token "$name" "$pos")")
    local w
    for w in $THEME_DARK_WORDS; do
        if [ "$tok" = "$w" ]; then
            echo "dark"
            return 0
        fi
    done
    echo "light"
}

# Собрать имя обратно, заменив или выбросив токен номер $2.
# $3 — новое слово; пустое означает «выбросить токен».
theme_rebuild() {
    local name="$1"
    local pos="$2"
    local word="${3:-}"
    local n
    n=$(theme_tokens "$name")
    if [ -z "$n" ]; then
        return 1
    fi
    local i=1
    local out=""
    local tok
    while [ "$i" -le "$n" ]; do
        tok=$(theme_token "$name" "$i")
        if [ "$i" = "$pos" ]; then
            if [ -z "$word" ]; then
                i=$((i + 1))
                continue
            fi
            tok="$word"
        fi
        if [ -z "$out" ]; then
            out="$tok"
        else
            out="$out-$tok"
        fi
        i=$((i + 1))
    done
    printf '%s
' "$out"
}

# Имя без слова варианта: Graphite-Dark-Square -> Graphite-Square,
# Graphite-teal-Dark -> Graphite-teal, Yaru-dark -> Yaru.
theme_base_of() {
    local name="$1"
    local pos
    pos=$(theme_variant_pos "$name")
    if [ -z "$pos" ]; then
        printf '%s
' "$name"
        return 0
    fi
    theme_rebuild "$name" "$pos" ""
}

# Подставить другое слово варианта, сохранив всё остальное:
# Graphite-Dark-Square + Light -> Graphite-Light-Square
theme_swap_variant() {
    local name="$1"
    local word="$2"
    local pos
    pos=$(theme_variant_pos "$name")
    if [ -z "$pos" ]; then
        return 1
    fi
    theme_rebuild "$name" "$pos" "$word"
}

# Найти среди УСТАНОВЛЕННЫХ тем вариант нужной яркости.
theme_find_variant() {
    local name="$1"
    local want="$2"
    if [ -z "$name" ]; then
        return 1
    fi
    # Всё, что не dark и не light, раньше молча считалось светлым.
    case "$want" in
        dark|light) : ;;
        *) return 1 ;;
    esac
    local words
    local w
    local cand
    if [ "$want" = "dark" ]; then
        words="Dark dark DARK Darker darker Black black"
    else
        words="Light light LIGHT Lighter lighter White white"
    fi

    # 1. Имя со словом варианта: меняем слово на месте, где бы оно ни было.
    if theme_variant_pos "$name" >/dev/null 2>&1; then
        for w in $words; do
            cand=$(theme_swap_variant "$name" "$w")
            if theme_exists "$cand"; then
                printf '%s
' "$cand"
                return 0
            fi
        done
        # 2. Светлый вариант часто зовётся просто базой: Yaru-dark -> Yaru.
        #    Но база сама может оказаться тёмной темой без подписи, поэтому
        #    засчитываем её, только если у неё есть тёмный собрат.
        if [ "$want" = "light" ]; then
            cand=$(theme_base_of "$name")
            if theme_exists "$cand"; then
                if theme_has_dark_sibling "$cand"; then
                    printf '%s
' "$cand"
                    return 0
                fi
            fi
        fi
        return 1
    fi

    # 3. Слова варианта в имени нет — дописываем суффикс к самому имени.
    for w in $words; do
        cand="$name-$w"
        if theme_exists "$cand"; then
            printf '%s
' "$cand"
            return 0
        fi
    done

    # 4. Имя без слова варианта, у которого есть тёмный собрат, само и
    #    есть светлый вариант: Yaru против Yaru-dark, Adwaita против
    #    Adwaita-dark. Тогда переключать нечего, но схему сменить надо.
    if [ "$want" = "light" ]; then
        if theme_has_dark_sibling "$name"; then
            printf '%s
' "$name"
            return 0
        fi
    fi
    return 1
}

# Есть ли у темы с таким именем тёмный собрат — то есть является ли она
# сама светлой половиной пары.
# «да», если тема без слова варианта в имени доказуемо светлая: у неё есть
# тёмный собрат. Вынесено в функцию, чтобы не писать цепочку из && .
theme_light_by_sibling() {
    local have="$1"
    local want="$2"
    local name="$3"
    if [ "$have" != "unknown" ]; then
        echo "нет"
        return 0
    fi
    if [ "$want" != "light" ]; then
        echo "нет"
        return 0
    fi
    if theme_has_dark_sibling "$name"; then
        echo "да"
        return 0
    fi
    echo "нет"
}

theme_has_dark_sibling() {
    local name="$1"
    local w
    for w in Dark dark DARK Darker darker Black black; do
        if theme_exists "$name-$w"; then
            return 0
        fi
    done
    return 1
}

# Установленные темы нужной яркости — для подсказки, когда пары не нашлось.
theme_list_variants() {
    local want="$1"
    local skip="${2:-}"
    local t
    local v
    list_themes | while read -r t; do
        if [ "$t" = "$skip" ]; then
            continue
        fi
        v=$(theme_variant_of "$t")
        if [ "$v" = "$want" ]; then
            echo "$t"
            continue
        fi
        # Имя без суффикса считаем светлым только если у него есть тёмный
        # собрат: иначе в список светлых попадут все тёмные темы без суффикса.
        if [ "$want" = "light" ]; then
            if [ "$v" = "unknown" ]; then
                if theme_find_variant "$t" dark >/dev/null 2>&1; then
                    echo "$t"
                fi
            fi
        fi
    done
}

# Переключить ТЕКУЩУЮ тему на её вариант другой яркости, не зная её имени.
# Результат кладётся в THEME_VARIANT_PICKED; ничего не применяет само.
theme_switch_variant() {
    local want="$1"
    local cur
    local base
    local have
    local found
    local word
    local repo
    local suffix
    local flag

    THEME_VARIANT_PICKED=""
    if [ "$want" = "light" ]; then
        word="светлого"
        suffix="-Light"
        flag="--light"
    else
        word="тёмного"
        suffix="-Dark"
        flag="--dark"
    fi

    cur=$(gi_get gtk-theme)
    if [ -z "$cur" ]; then
        bad "не прочитал текущую тему окон"
        return 1
    fi
    have=$(theme_variant_of "$cur")
    base=$(theme_base_of "$cur")

    found=$(theme_find_variant "$cur" "$want")
    if [ -n "$found" ]; then
        # Найденное имя может совпасть с текущим только если тема уже
        # нужной яркости. Совпадение при ДРУГОЙ яркости — признак того,
        # что слово варианта в имени не распознано: молчать тут нельзя.
        if [ "$found" = "$cur" ]; then
            if [ "$have" = "$want" ]; then
                note "$cur уже подходит — это и есть вариант нужной яркости"
            elif [ "$(theme_light_by_sibling "$have" "$want" "$cur")" = "да" ]; then
                # Стоковая Ubuntu: тема называется Yaru, а тёмная — Yaru-dark.
                # Слова варианта в имени нет, но тёмный собрат доказывает,
                # что текущая тема и есть светлая. Менять тему нечего, схему
                # надо. Раньше этот путь заканчивался отказом, то есть
                # theme --light на стоковой системе не работал вообще.
                note "$cur и есть светлый вариант — тёмный лежит отдельно"
            else
                bad "парного варианта для '$cur' не нашлось"
                note "в имени темы не распознано слово light или dark"
                note "выбери руками из установленных:"
                theme_list_variants "$want" "$cur" | dump
                return 1
            fi
        else
            note "$cur -> $found"
        fi
        THEME_VARIANT_PICKED="$found"
        return 0
    fi

    bad "$word варианта темы '$cur' в системе нет"
    if [ "$have" = "unknown" ]; then
        note "в имени '$cur' нет суффикса варианта, парную тему искать негде"
    fi

    # Точной пары нет, но рядом может лежать вариант того же семейства:
    # у Graphite-Dark-Square это Graphite-Light. Не подставляем молча —
    # хвост имени обычно значит другую форму кнопок или отступы — но
    # показать такую тему полезнее, чем весь список установленных.
    local family
    family=$(theme_token "$cur" 1)
    local near
    near=$(theme_list_variants "$want" "$cur" | grep "^$family" | head -4)
    if [ -n "$near" ]; then
        note "того же семейства ($family) и нужной яркости:"
        printf '%s\n' "$near" | dump
        note "применить: $0 theme $(printf '%s' "$near" | head -1)"
        note "если нужно поменять только схему для GTK4-приложений:"
        note "  $0 theme $flag --scheme-only"
        return 1
    fi

    repo=$(theme_repo_for "$base")
    if [ -n "$repo" ]; then
        note "эту тему знаю, вариант можно собрать:"
        note "  $0 theme --install $base$suffix"
    fi
    note "или возьми любую из установленных:"
    theme_list_variants "$want" "$cur" | dump
    note "если нужно поменять только схему для GTK4-приложений:"
    note "  $0 theme $flag --scheme-only"
    return 1
}

cmd_theme() {
    local wanted=""
    local scheme=""
    local do_install=""
    local only_list=0
    local scheme_only=0
    local head_done=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --list)    only_list=1; shift ;;
            --install) need_args "--install" 2 "$#"; do_install="${2:-}"; shift 2 ;;
            --dark)    scheme="prefer-dark"; shift ;;
            --light)   scheme="prefer-light"; shift ;;
            --scheme-only) scheme_only=1; shift ;;
            -h|--help) help_theme; return 0 ;;
            -*) die "theme: неизвестный параметр $1" ;;
            *) wanted="$1"; shift ;;
        esac
    done

    if [ "$only_list" = "1" ]; then
        head1 "доступные темы"
        list_themes | dump
        return 0
    fi

    if [ -n "$do_install" ]; then
        # --install Graphite вместе с --light должен собрать светлый вариант,
        # а не тёмный по умолчанию.
        case "$(theme_variant_of "$do_install")" in
            unknown)
                if [ "$scheme" = "prefer-light" ]; then
                    do_install="$do_install-Light"
                    note "собираю светлый вариант: $do_install"
                fi
                if [ "$scheme" = "prefer-dark" ]; then
                    do_install="$do_install-Dark"
                    note "собираю тёмный вариант: $do_install"
                fi
                ;;
        esac
        THEME_INSTALLED=""
        if ! install_theme "$do_install"; then
            # без этого выхода дальше пойдёт подсказка «собери тему»,
            # которая уже только что не сработала — кольцо
            return 1
        fi
        if [ -n "$THEME_INSTALLED" ]; then
            wanted="$THEME_INSTALLED"
        else
            wanted="$do_install"
        fi
    fi

    if [ -z "$wanted" ]; then
        if [ -z "$scheme" ]; then
            head1 "тема окон"
            note "сейчас: $(gi_get gtk-theme), схема $(gi_get color-scheme)"
            note "доступные:"
            list_themes | dump
            note "применить: $0 theme ИМЯ"
            return 0
        fi
    fi

    # «Сделай светлой» без имени темы: ищем парный вариант ТЕКУЩЕЙ темы.
    # Менять одну лишь цветовую схему тут нельзя — GTK3-приложения её не
    # слушают, окно осталось бы тёмным при светлом Nautilus.
    if [ -z "$wanted" ]; then
        if [ -n "$scheme" ]; then
            if [ "$scheme_only" = "0" ]; then
                head1 "тема окон"
                head_done=1
                if ! theme_switch_variant "${scheme#prefer-}"; then
                    return 1
                fi
                wanted="$THEME_VARIANT_PICKED"
            fi
        fi
    fi

    if [ -n "$wanted" ]; then
        if ! theme_exists "$wanted"; then
            local real
            real=$(theme_real_name "$wanted")
            if [ -n "$real" ]; then
                note "имя каталога пишется иначе: $real"
                wanted="$real"
            fi
        fi
        if ! theme_exists "$wanted"; then
            bad "темы '$wanted' в системе нет"
            local repo=$(theme_repo_for "$wanted")
            if [ -n "$repo" ]; then
                note "её можно собрать из исходников:"
                note "  $0 theme --install $wanted"
            else
                note "доступные темы:"
                list_themes | dump
            fi
            return 1
        fi

        if [ "$head_done" = "0" ]; then
            head1 "тема окон"
            head_done=1
        fi
        remember GTK_THEME "$(gi_get gtk-theme)"
        remember SHELL_THEME "$(dconf read /org/gnome/shell/extensions/user-theme/name 2>/dev/null | tr -d "'")"
        gi_set gtk-theme "$wanted"
        ok "тема: $wanted"

        # тема оболочки — только если такая существует. Каталог может лежать
        # и в системном /usr/share/themes, а не только в домашнем.
        local shell_dir=""
        for d in "$HOME/.themes/$wanted" "$HOME/.local/share/themes/$wanted" \
                 "$SYS_THEMES/$wanted"; do
            if [ -d "$d/gnome-shell" ]; then
                shell_dir="$d"
            fi
        done
        if [ -n "$shell_dir" ]; then
            if would "тема оболочки $wanted"; then
                :
            else
                dconf write /org/gnome/shell/extensions/user-theme/name "'$wanted'" 2>/dev/null
                ok "тема оболочки: $wanted"
            fi
        else
            # У темы нет каталога gnome-shell. Если оболочка при этом одета
            # в ДРУГУЮ тему, она останется прежней яркости — верхняя панель
            # будет тёмной при светлых окнах, и это выглядит как поломка.
            local shell_now
            shell_now=$(dconf read /org/gnome/shell/extensions/user-theme/name 2>/dev/null | tr -d "'")
            if [ -n "$shell_now" ]; then
                if [ "$shell_now" != "$wanted" ]; then
                    local shell_variant
                    shell_variant=$(theme_variant_of "$shell_now")
                    local want_variant
                    want_variant=$(theme_variant_of "$wanted")
                    local both_known=1
                    if [ "$shell_variant" = "unknown" ]; then
                        both_known=0
                    fi
                    if [ "$want_variant" = "unknown" ]; then
                        both_known=0
                    fi
                    if [ "$shell_variant" = "$want_variant" ]; then
                        both_known=0
                    fi
                    if [ "$both_known" = "1" ]; then
                        bad "оболочка одета в '$shell_now' — другой яркости"
                        note "у темы '$wanted' нет каталога gnome-shell, менять нечего"
                        local shell_pair
                        shell_pair=$(theme_find_variant "$shell_now" "$want_variant")
                        if [ -n "$shell_pair" ]; then
                            local q
                            q=$(printf "\047")
                            note "поправить вручную:"
                            note "  dconf write /org/gnome/shell/extensions/user-theme/name \"$q$shell_pair$q\""
                        fi
                    fi
                fi
            fi
        fi

        # Схему выводим из имени, если явно не задана. Тема без суффикса
        # (Yaru, Adwaita) — светлая, но только если у неё есть тёмный собрат:
        # иначе в светлые попадут тёмные темы, которые просто не подписаны.
        if [ -z "$scheme" ]; then
            local vguess
            vguess=$(theme_variant_of "$wanted")
            case "$vguess" in
                light) scheme="prefer-light" ;;
                dark)  scheme="prefer-dark" ;;
                *)
                    if theme_find_variant "$wanted" dark >/dev/null 2>&1; then
                        scheme="prefer-light"
                    else
                        note "по имени '$wanted' светлая она или тёмная не понять"
                        note "схему задай сам: $0 theme $wanted --light"
                    fi
                    ;;
            esac
        fi
    fi

    if [ -n "$scheme" ]; then
        remember COLOR_SCHEME "$(gi_get color-scheme)"
        gi_set color-scheme "$scheme"
        ok "цветовая схема: $scheme"
    fi

    # Что за темой НЕ идёт: человек должен узнать это здесь, а не потом
    # по нечитаемому терминалу.
    if [ -n "$wanted" ]; then
        blank
        note "тема значков не менялась: $(gi_get icon-theme)"
        note "за темой сами НЕ идут:"
        note "  терминал   — $0 terminal --palette wal"
        note "  виджет     — $0 widget --colour RRGGBB"
        note "  новая вкладка — $0 newtab"
        note "  кнопки заголовка переживают смену темы, править не нужно"
    fi

    restart_gtk_apps
}

# Установщики vinceliuice с ключом -l делают ~/.config/gtk-4.0/gtk.css
# симлинком внутрь темы. Наши блоки после этого уехали бы в каталог темы
# и пропали при её следующей пересборке.
install_theme_check_symlink() {
    if [ -L "$CSS4" ]; then
        bad "после сборки ~/.config/gtk-4.0/gtk.css стал симлинком в тему"
        note "наши правила туда писать нельзя — сниму ссылку при первом же"
        note "вызове buttons или corners, вид от этого не пострадает"
    fi
}

install_theme() {
    local name="$1"
    local repo
    local src
    local before
    local after
    local appeared
    repo=$(theme_repo_for "$name")
    if [ -z "$repo" ]; then
        die "не знаю, откуда брать тему '$name'"
    fi
    require_tools git sassc

    local variant="dark"
    case "$name" in
        *-Light|*-light) variant="light" ;;
    esac

    head1 "сборка темы $name"
    if would "склонировать $repo и собрать вариант $variant"; then
        return 0
    fi

    before=$(list_themes)
    src="$HOME/.cache/desktop-kit/themes/$(basename "$repo" .git)"
    mkdir -p "$(dirname "$src")"
    if [ ! -d "$src/.git" ]; then
        rm -rf "$src"
        git clone --depth 1 "$repo" "$src" >>"$LOG_FILE" 2>&1
    fi
    if [ ! -x "$src/install.sh" ]; then
        die "в репозитории нет install.sh — смотри $LOG_FILE"
    fi

    ( cd "$src"; ./install.sh -c "$variant" >>"$LOG_FILE" 2>&1 )

    if theme_exists "$name"; then
        ok "тема собрана: $name"
        THEME_INSTALLED="$name"
        install_theme_check_symlink
        return 0
    fi

    # Установщики вендоров называют каталоги по-своему: попросили Graphite-Light,
    # на диске может оказаться Graphite-light или Graphite-Light-nord. Поэтому
    # сравниваем список тем до и после сборки и берём то, что реально появилось.
    after=$(list_themes)
    appeared=$(comm -13 <(printf '%s
' "$before") <(printf '%s
' "$after"))

    if [ -z "$appeared" ]; then
        bad "после сборки новых тем не появилось"
        note "подробности сборки: $LOG_FILE"
        return 1
    fi

    local picked
    picked=$(printf '%s
' "$appeared" | grep -ix "$name" | head -1)
    if [ -z "$picked" ]; then
        picked=$(printf '%s
' "$appeared" | grep -i -- "-$variant" | head -1)
    fi
    if [ -z "$picked" ]; then
        picked=$(printf '%s
' "$appeared" | head -1)
    fi

    install_theme_check_symlink
    ok "тема собрана под именем: $picked"
    note "просили $name — установщик назвал каталог иначе, это нормально"
    note "появилось всего: $(printf '%s
' "$appeared" | tr '
' ' ')"
    THEME_INSTALLED="$picked"
    return 0
}

# =====================================================================
#  icons — тема значков и цвет папок
# =====================================================================

help_icons() {
    cat <<'EOF'
icons — тема значков и цвет папок

  desktop-kit icons                показать текущую и доступные
  desktop-kit icons ИМЯ            применить тему значков
  desktop-kit icons --folders ЦВЕТ перекрасить папки Papirus
  desktop-kit icons --list         список доступных

  Цвета папок: adwaita black blue bluegrey breeze brown cyan green grey
  indigo magenta nordic orange pink red teal violet white yaru yellow

  Перекраска работает через papirus-folders и меняет саму тему Papirus
  НА ДИСКЕ, поэтому наследники её подхватывают автоматически. Отсюда два
  следствия: тема часто лежит в /usr/share/icons и тогда нужен sudo, а
  обновление пакета papirus-icon-theme через apt сбросит цвет — команду
  придётся повторить. Откатить цвет можно только другой перекраской.

  Смена темы значков не ломает кнопки заголовка: если активен наследник
  <база>-dk-glyphs от команды buttons, он пересобирается поверх новой темы.
EOF
}

list_icon_themes() {
    for d in "$HOME/.local/share/icons" "$HOME/.icons" "$SYS_ICONS"; do
        if [ -d "$d" ]; then
            for t in "$d"/*; do
                if [ -f "$t/index.theme" ]; then
                    basename "$t"
                fi
            done
        fi
    done | sort -u
}

cmd_icons() {
    local icons_rc=0
    local wanted=""
    local folders=""
    local only_list=0
    local base=""
    local code=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --folders) need_args "--folders" 2 "$#"; folders="${2:-}"; shift 2 ;;
            --list)    only_list=1; shift ;;
            -h|--help) help_icons; return 0 ;;
            -*) die "icons: неизвестный параметр $1" ;;
            *) wanted="$1"; shift ;;
        esac
    done

    if [ "$only_list" = "1" ]; then
        head1 "доступные темы значков"
        list_icon_themes | dump
        return 0
    fi

    if [ -n "$folders" ]; then
        head1 "цвет папок"
        if ! have papirus-folders; then
            bad "papirus-folders не установлен"
            note "sudo apt install papirus-folders"
            return 1
        fi
        base=$(icon_base_of "$(gi_get icon-theme)")
        case "$base" in
            Papirus*) : ;;
            *)
                bad "papirus-folders умеет красить только темы Papirus"
                note "сейчас активна '$base' — сначала: $0 icons Papirus-Dark"
                return 1
                ;;
        esac
        if would "перекрасить папки $base в $folders"; then
            return 0
        fi
        # `local out=$(...)` вернул бы код самого local, то есть всегда 0 —
        # объявление и присваивание нужно разделять.
        local out
        out=$(papirus-folders -C "$folders" --theme "$base" 2>&1)
        code=$?
        if [ "$code" = "0" ]; then
            remember FOLDER_COLOUR "$folders"
            ok "папки перекрашены в $folders"
            note "цвет живёт в самой теме Papirus — обновление пакета его сбросит"
        else
            bad "не вышло, возможно нужен sudo:"
            hint "sudo papirus-folders -C $folders --theme $base"
            hint "$out"
        fi
    fi

    if [ -n "$wanted" ]; then
        if ! list_icon_themes | grep -qx "$wanted"; then
            bad "темы значков '$wanted' нет"
            note "доступные:"
            list_icon_themes | dump
            return 1
        fi
        head1 "тема значков"
        # Значки заголовка от buttons живут в теме-наследнике <база>-dk-glyphs.
        # Простая смена icon-theme снесла бы их молча, поэтому наследника
        # пересобираем поверх новой базы.
        local had_glyphs=0
        local cur_icon_theme
        cur_icon_theme=$(gi_get icon-theme)
        case "$cur_icon_theme" in
            *-dk-glyphs|*-Fluent-Titlebar)
                had_glyphs=1
                # Запоминать наследника нельзя: откат вернул бы тему, каталог
                # которой к тому моменту уже удалён. Помним его базу.
                cur_icon_theme=$(icon_base_of "$cur_icon_theme")
                ;;
        esac

        remember ICON_THEME "$cur_icon_theme"
        gi_set icon-theme "$wanted"
        ok "тема значков: $wanted"

        if [ "$had_glyphs" = "1" ]; then
            note "были свои значки заголовка — пересобираю поверх $wanted"
            if install_fluent_glyphs; then
                ok "значки заголовка сохранены"
            else
                bad "пересобрать не вышло — значки заголовка сейчас родные"
                note "повтори позже: $0 buttons"
                icons_rc=1
            fi
        else
            note "если нужны свои значки заголовка — $0 buttons"
        fi
    fi

    if [ -z "$wanted" ]; then
        if [ -z "$folders" ]; then
            head1 "значки"
            note "сейчас: $(gi_get icon-theme)"
            note "доступные:"
            list_icon_themes | dump
        fi
    fi
    return $icons_rc
}

# =====================================================================
#  font — шрифт интерфейса
# =====================================================================

help_font() {
    cat <<'EOF'
font — шрифт интерфейса

  desktop-kit font                 показать текущий
  desktop-kit font "Имя Размер"    применить, например "Cantarell 11"
  desktop-kit font --list          семейства, установленные в системе
  desktop-kit font --mono "Имя Размер"   моноширинный (терминал, редакторы)

  Имя проверяется по fc-list: несуществующий шрифт не применяется.
EOF
}

cmd_font() {
    wanted=""
    local mono=""
    only_list=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --list)    only_list=1; shift ;;
            --mono) need_args "--mono" 2 "$#"; mono="${2:-}"; shift 2 ;;
            -h|--help) help_font; return 0 ;;
            -*) die "font: неизвестный параметр $1" ;;
            *) wanted="$1"; shift ;;
        esac
    done

    if [ "$only_list" = "1" ]; then
        head1 "семейства шрифтов"
        fc-list --format='%{family[0]}\n' 2>/dev/null | sort -u | dump
        return 0
    fi

    if [ -z "$wanted" ]; then
        if [ -z "$mono" ]; then
            head1 "шрифты"
            note "интерфейс:    $(gi_get font-name)"
            note "моноширинный: $(gi_get monospace-font-name)"
            note "документы:    $(gi_get document-font-name)"
            return 0
        fi
    fi

    apply_font() {
        key="$1"
        value="$2"
        local family
        family=$(echo "$value" | sed 's/ [0-9]*$//')
        # Сравниваем с полем "семейство" из fc-list, а не ищем подстроку
        # где угодно в строке: иначе 'DejaV 11' сойдёт за существующий шрифт.
        local want_family
        want_family=$(lower "$family")
        if ! fc-list : family 2>/dev/null | tr ',' '
'              | tr '[:upper:]' '[:lower:]' | grep -qxF -- "$want_family"; then
            bad "шрифта '$family' в системе нет"
            note "посмотреть доступные: $0 font --list"
            return 1
        fi
        remember "$(echo "$key" | tr 'a-z-' 'A-Z_')" "$(gi_get "$key")"
        gi_set "$key" "$value"
        ok "$key: $value"
        return 0
    }

    head1 "шрифт интерфейса"
    local rc=0
    if [ -n "$wanted" ]; then
        if ! apply_font font-name "$wanted"; then
            rc=1
        fi
    fi
    if [ -n "$mono" ]; then
        if ! apply_font monospace-font-name "$mono"; then
            rc=1
        fi
    fi
    return $rc
}

# =====================================================================
#  widget — виджет conky
# =====================================================================

help_widget() {
    cat <<'EOF'
widget — виджет conky на рабочем столе

  desktop-kit widget [параметры]

  --radius N     скругление углов, по умолчанию 12
  --opacity N    плотность подложки 0..255, по умолчанию берётся из конфига
  --colour HEX   цвет подложки, по умолчанию из конфига
  --text HEX     цвет текста виджета
  --light        светлая подложка с тёмным текстом
  --dark         тёмная подложка со светлым текстом
  --square       без скругления (то же, что --radius 0)

  Про --light: при переходе системы на светлую тему conky за ней НЕ идёт.
  Тёмная подложка так и останется тёмной, а если поменять только её —
  получится белый текст на белом. Поэтому цвет текста правится отдельно,
  и скрипт предупреждает, когда подложка и текст оказались одной яркости.

  У conky нет своего border-radius ни в одной версии, поэтому подложку
  рисует Lua через Cairo, а собственное окно conky делается прозрачным.
  Исходный конфиг сохраняется перед первой правкой.
EOF
}

cmd_widget() {
    if preset_expand widget "${1:-}"; then
        shift
        set -- $PRESET_ARGS "$@"
        note "набор '$PRESET_USED': $PRESET_ARGS"
    fi
    local radius=12
    local opacity=""
    local colour=""
    local ink=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --radius) need_args "--radius" 2 "$#"; radius="${2:-12}"; shift 2 ;;
            --opacity) need_args "--opacity" 2 "$#"; opacity="${2:-}"; shift 2 ;;
            --color|--colour) need_args "$1" 2 "$#"; colour="${2:-}"; shift 2 ;;
            --text|--text-colour) need_args "$1" 2 "$#"; ink="${2:-}"; shift 2 ;;
            --square)  radius=0; shift ;;
            --light)   colour="f2f2f2"; ink="1e1e2e"; shift ;;
            --dark)    colour="1e1e2e"; ink="ffffff"; shift ;;
            -h|--help) help_widget; return 0 ;;
            *) die "widget: неизвестный параметр $1" ;;
        esac
    done

    if ! is_number "$radius"; then
        die "widget: радиус — целое число"
    fi
    if [ ! -f "$CONKY_CONF" ]; then
        die "конфига conky нет: $CONKY_CONF"
    fi

    head1 "виджет conky (радиус ${radius}px)"

    if [ -z "$colour" ]; then
        colour=$(conf_value own_window_colour "$CONKY_CONF")
    fi
    colour="${colour#\#}"
    if [ -z "$colour" ]; then
        colour="1e1e2e"
    fi

    if [ -z "$opacity" ]; then
        opacity=$(conf_value own_window_argb_value "$CONKY_CONF")
    fi
    if [ -z "$opacity" ]; then
        opacity=225
    fi
    # ноль означает, что мы уже применяли: берём прежнюю плотность
    if [ "$opacity" = "0" ]; then
        local saved
        saved=$(state_get CONKY_ALPHA)
        if [ -n "$saved" ]; then
            opacity="$saved"
        else
            opacity=225
        fi
    fi
    state_set CONKY_ALPHA "$opacity"

    r=$(awk "BEGIN{printf \"%.3f\", $((16#${colour:0:2}))/255}")
    g=$(awk "BEGIN{printf \"%.3f\", $((16#${colour:2:2}))/255}")
    b=$(awk "BEGIN{printf \"%.3f\", $((16#${colour:4:2}))/255}")
    local a=$(awk "BEGIN{printf \"%.3f\", $opacity/255}")

    if would "нарисовать подложку радиусом $radius, цвет #$colour, плотность $opacity"; then
        return 0
    fi

    backup_once "$CONKY_CONF" "conky-main.conf"
    # sed -i подменяет симлинк обычным файлом вместо правки цели
    if [ -L "$CONKY_CONF" ]; then
        local ctarget
        ctarget=$(readlink -f "$CONKY_CONF")
        bad "конфиг conky это симлинк на $ctarget"
        note "правь его напрямую, иначе ссылка будет заменена файлом"
        return 1
    fi

    cat > "$CONKY_LUA" <<LUAEOF
-- Подложка виджета: своего border-radius у conky нет ни в одной версии,
-- поэтому рисуем сами, а окно conky делаем прозрачным.
require 'cairo'

local RADIUS = $radius
local R, G, B, A = $r, $g, $b, $a

function conky_draw_bg()
    if conky_window == nil then
        return
    end

    local w = conky_window.width
    local h = conky_window.height
    local rr = RADIUS
    if rr * 2 > w then rr = w / 2 end
    if rr * 2 > h then rr = h / 2 end

    local surface = cairo_xlib_surface_create(conky_window.display,
        conky_window.drawable, conky_window.visual, w, h)
    local cr = cairo_create(surface)

    cairo_new_path(cr)
    cairo_move_to(cr, rr, 0)
    cairo_line_to(cr, w - rr, 0)
    cairo_arc(cr, w - rr, rr, rr, -math.pi / 2, 0)
    cairo_line_to(cr, w, h - rr)
    cairo_arc(cr, w - rr, h - rr, rr, 0, math.pi / 2)
    cairo_line_to(cr, rr, h)
    cairo_arc(cr, rr, h - rr, rr, math.pi / 2, math.pi)
    cairo_line_to(cr, 0, rr)
    cairo_arc(cr, rr, rr, rr, math.pi, 3 * math.pi / 2)
    cairo_close_path(cr)

    cairo_set_source_rgba(cr, R, G, B, A)
    cairo_fill(cr)

    cairo_destroy(cr)
    cairo_surface_destroy(surface)
end
LUAEOF

    sed -i "s|own_window_argb_value = [0-9]*|own_window_argb_value = 0|" "$CONKY_CONF"
    if grep -q 'lua_load' "$CONKY_CONF"; then
        sed -i "s|lua_load = '[^']*'|lua_load = '$CONKY_LUA'|" "$CONKY_CONF"
    else
        sed -i "0,/conky.config = {/s|conky.config = {|conky.config = {\n    lua_load = '$CONKY_LUA',|" "$CONKY_CONF"
    fi
    if ! grep -q 'lua_draw_hook_pre' "$CONKY_CONF"; then
        sed -i "s|lua_load = '$CONKY_LUA',|lua_load = '$CONKY_LUA',\n    lua_draw_hook_pre = 'draw_bg',|" "$CONKY_CONF"
    fi

    # Цвет текста живёт отдельно от подложки: светлая подложка с белым
    # текстом даёт белое на белом, и виджет просто исчезает.
    if [ -n "$ink" ]; then
        ink="${ink#\#}"
        backup_once "$CONKY_CONF" "conky-main.conf"
        if grep -q 'default_color' "$CONKY_CONF"; then
            sed -i "s|default_color *= *'[^']*'|default_color = '$ink'|" "$CONKY_CONF"
        else
            sed -i "0,/conky.config = {/s|conky.config = {|conky.config = {\n    default_color = '$ink',|" "$CONKY_CONF"
        fi
        state_set CONKY_INK "$ink"
        ok "цвет текста: #$ink"
    fi

    ok "подложка: радиус ${radius}px, цвет #${colour}, плотность ${opacity}"

    # Предупредить о белом на белом, пока человек не увидел это глазами.
    local bright
    bright=$(hex_brightness "$colour")
    if [ "$bright" -gt 140 ]; then
        local cur_ink
        cur_ink=$(conf_value default_color "$CONKY_CONF")
        if [ -n "$cur_ink" ]; then
            if [ "$(hex_brightness "$cur_ink")" -gt 140 ]; then
                bad "подложка светлая, текст тоже — виджет будет не виден"
                note "почини так: $0 widget --text 1e1e2e"
            fi
        fi
    fi

    restart_conky
}

# Значение ключа из конфига conky. Через sed, а не grep -P: у grep
# перловые выражения отваливаются в не-UTF-8 локали ("-P supports only
# unibyte and UTF-8 locales"), а таймер systemd запускается с C.
conf_value() {
    local key="$1"
    local file="$2"
    if [ ! -f "$file" ]; then
        return 0
    fi
    grep -m1 -- "$key" "$file" \
        | tr -d " ',"  \
        | cut -d= -f2
}

# Яркость по восприятию: зелёный весит больше синего.
hex_brightness() {
    local hex="${1#\#}"
    if [ ${#hex} -ne 6 ]; then
        echo 0
        return 0
    fi
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    echo $(((r * 299 + g * 587 + b * 114) / 1000))
}

# =====================================================================
#  terminal — GNOME Terminal
# =====================================================================

help_terminal() {
    cat <<'EOF'
terminal — GNOME Terminal: прозрачность, шрифт, палитра

  desktop-kit terminal [параметры]

  --opacity N    прозрачность фона 0..100, где 0 — непрозрачный
  --font "Имя Размер"
  --palette wal  взять цвета из текущей палитры pywal
  --show         показать текущие настройки

  ВАЖНО: gnome-terminal-server переживает закрытие всех окон и держит
  старые настройки. После правки: pkill -x gnome-terminal-server

  Tabby настраивается не здесь — у него свой конфиг, см. modules/tabby.md
EOF
}

term_profile() {
    local id=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    if [ -z "$id" ]; then
        echo ""
        return 1
    fi
    echo "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$id/"
}

cmd_terminal() {
    if preset_expand terminal "${1:-}"; then
        shift
        set -- $PRESET_ARGS "$@"
        note "набор '$PRESET_USED': $PRESET_ARGS"
    fi
    local opacity=""
    local font=""
    local palette=""
    local show=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --opacity) need_args "--opacity" 2 "$#"; opacity="${2:-}"; shift 2 ;;
            --font) need_args "--font" 2 "$#"; font="${2:-}"; shift 2 ;;
            --palette) need_args "--palette" 2 "$#"; palette="${2:-}"; shift 2 ;;
            --show)    show=1; shift ;;
            -h|--help) help_terminal; return 0 ;;
            *) die "terminal: неизвестный параметр $1" ;;
        esac
    done

    local prof=$(term_profile)
    if [ -z "$prof" ]; then
        die "не нашёл профиль GNOME Terminal"
    fi

    if [ "$show" = "1" ]; then
        head1 "GNOME Terminal"
        note "прозрачность:  $(gsettings get "$prof" background-transparency-percent 2>/dev/null)"
        note "своя палитра:  $(gsettings get "$prof" use-theme-colors 2>/dev/null)"
        note "шрифт:         $(gsettings get "$prof" font 2>/dev/null)"
        return 0
    fi

    # голый вызов должен что-то показывать, а не молчать
    if [ -z "$opacity" ]; then
        if [ -z "$font" ]; then
            if [ -z "$palette" ]; then
                show=1
            fi
        fi
    fi
    if [ "$show" = "1" ]; then
        head1 "GNOME Terminal"
        note "прозрачность:  $(gsettings get "$prof" background-transparency-percent 2>/dev/null)"
        note "своя палитра:  $(gsettings get "$prof" use-theme-colors 2>/dev/null)"
        note "шрифт:         $(gsettings get "$prof" font 2>/dev/null)"
        note "меняется так:  $0 terminal --opacity 15"
        return 0
    fi

    head1 "GNOME Terminal"

    if [ -n "$opacity" ]; then
        if ! is_number "$opacity"; then
            die "terminal: прозрачность — целое число 0..100"
        fi
        if [ "$opacity" -gt 100 ]; then
            die "terminal: прозрачность не больше 100"
        fi
        if would "прозрачность $opacity%"; then
            :
        else
            remember TERM_TRANSPARENT "$(gsettings get "$prof" use-transparent-background 2>/dev/null)"
            remember TERM_OPACITY "$(gsettings get "$prof" background-transparency-percent 2>/dev/null)"
            gsettings set "$prof" use-transparent-background true 2>/dev/null
            gsettings set "$prof" background-transparency-percent "$opacity" 2>/dev/null
            ok "прозрачность: ${opacity}%"
        fi
    fi

    if [ -n "$font" ]; then
        local family
        family=$(echo "$font" | sed 's/ [0-9]*$//')
        if ! fc-list 2>/dev/null | grep -qi "$family"; then
            bad "шрифта '$family' нет"
        else
            if would "шрифт терминала $font"; then
                :
            else
                remember TERM_SYSFONT "$(gsettings get "$prof" use-system-font 2>/dev/null)"
                remember TERM_FONT "$(gsettings get "$prof" font 2>/dev/null)"
                gsettings set "$prof" use-system-font false 2>/dev/null
                gsettings set "$prof" font "$font" 2>/dev/null
                ok "шрифт: $font"
            fi
        fi
    fi

    if [ "$palette" = "wal" ]; then
        apply_wal_palette "$prof"
    fi

    if pgrep -x gnome-terminal-server >/dev/null 2>&1; then
        note "перезапусти сервер, иначе изменений не увидишь:"
        note "  pkill -x gnome-terminal-server"
    fi
}

# pywal дописывает в colors.sh строки со ссылками на несуществующие
# переменные — под set -u подключение валит скрипт целиком.
apply_wal_palette() {
    local prof="$1"
    local colors="$HOME/.cache/wal/colors.sh"
    if [ ! -f "$colors" ]; then
        bad "палитры pywal нет: $colors"
        return 1
    fi
    if would "применить палитру pywal к терминалу"; then
        return 0
    fi
    set +u
    . "$colors"
    set -u
    remember TERM_THEMECOLORS "$(gsettings get "$prof" use-theme-colors 2>/dev/null)"
    remember TERM_BG "$(gsettings get "$prof" background-color 2>/dev/null)"
    remember TERM_FG "$(gsettings get "$prof" foreground-color 2>/dev/null)"
    remember TERM_PALETTE "$(gsettings get "$prof" palette 2>/dev/null)"
    local pal="['$color0', '$color1', '$color2', '$color3', '$color4', '$color5', '$color6', '$color7', '$color8', '$color9', '$color10', '$color11', '$color12', '$color13', '$color14', '$color15']"
    gsettings set "$prof" use-theme-colors false 2>/dev/null
    gsettings set "$prof" background-color "$background" 2>/dev/null
    gsettings set "$prof" foreground-color "$foreground" 2>/dev/null
    gsettings set "$prof" palette "$pal" 2>/dev/null
    ok "палитра pywal применена"
}

# =====================================================================
#  newtab — страница новой вкладки Chrome
# =====================================================================

# Запасной сборщик плиток, когда python3 недоступен. Значков из кэша
# Chrome тут нет — только буква, зато страница не остаётся пустой.
newtab_tiles_plain() {
    local line
    local name
    local url
    local letter
    while IFS= read -r line; do
        case "$line" in
            ""|"#"*) continue ;;
            *"|"*) : ;;
            *) continue ;;
        esac
        name="${line%%|*}"
        url="${line#*|}"
        # Минимальное экранирование: эти четыре символа ломают разметку
        name=$(printf '%s' "$name" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
        url=$(printf '%s' "$url" | sed 's/&/\&amp;/g; s/"/\&quot;/g')
        letter=$(printf '%s' "$name" | cut -c1 | tr '[:lower:]' '[:upper:]')
        printf '<a class="tile" href="%s"><span class="ico">%s</span><span class="cap">%s</span></a>
'             "$url" "$letter" "$name"
    done < "$NEWTAB_LINKS"
}

help_newtab() {
    cat <<'EOF'
newtab — своя страница новой вкладки в Chrome

  desktop-kit newtab                     пересобрать страницу
  desktop-kit newtab --add "Имя|URL"     добавить ярлык
  desktop-kit newtab --remove Имя        убрать ярлык
  desktop-kit newtab --list              показать ярлыки
  desktop-kit newtab --edit              открыть список в редакторе
  desktop-kit newtab --clock N           размер часов, по умолчанию 110
  desktop-kit newtab --tile N            ширина плитки, по умолчанию 130

  Значки берутся из локального кэша Chrome (Default/Favicons), поэтому
  внутренние адреса получают настоящие иконки. Найденный значок
  запоминается в icons.json и не теряется, даже если база потом промолчит.

  Подключение к новой вкладке требует расширения — Chrome иначе не даёт.
  Подробности: modules/chrome.md
EOF
}

cmd_newtab() {
    if preset_expand newtab "${1:-}"; then
        shift
        set -- $PRESET_ARGS "$@"
        note "набор '$PRESET_USED': $PRESET_ARGS"
    fi
    local action="rebuild"
    value=""
    local clock=110
    local tile=130
    while [ $# -gt 0 ]; do
        case "$1" in
            --add)     need_args "--add" 2 "$#"; action="add"; value="$2"; shift 2 ;;
            --remove)  need_args "--remove" 2 "$#"; action="remove"; value="$2"; shift 2 ;;
            --list)    action="list"; shift ;;
            --edit)    action="edit"; shift ;;
            --clock) need_args "--clock" 2 "$#"; clock="${2:-110}"; shift 2 ;;
            --tile) need_args "--tile" 2 "$#"; tile="${2:-130}"; shift 2 ;;
            -h|--help) help_newtab; return 0 ;;
            *) die "newtab: неизвестный параметр $1" ;;
        esac
    done

    mkdir -p "$NEWTAB_DIR"
    touch "$NEWTAB_LINKS"

    case "$action" in
        list)
            head1 "ярлыки новой вкладки"
            grep -v '^#' "$NEWTAB_LINKS" | grep '|' | dump
            return 0
            ;;
        edit)
            local editor="${EDITOR:-nano}"
            "$editor" "$NEWTAB_LINKS"
            ;;
        add)
            if [ -z "$value" ]; then
                die "newtab: нужен формат \"Имя|https://адрес\""
            fi
            case "$value" in
                *\|*) : ;;
                *) die "newtab: нужен разделитель, формат \"Имя|https://адрес\"" ;;
            esac
            name="${value%%|*}"
            if grep -qF -- "$name|" "$NEWTAB_LINKS"; then
                bad "ярлык '$name' уже есть"
                return 1
            fi
            if would "добавить ярлык $value"; then
                return 0
            fi
            backup_once "$NEWTAB_LINKS" "newtab-links.txt"
            echo "$value" >> "$NEWTAB_LINKS"
            ok "добавлен: $value"
            ;;
        remove)
            if [ -z "$value" ]; then
                die "newtab: назови ярлык"
            fi
            if ! grep -qF -- "$value|" "$NEWTAB_LINKS"; then
                bad "ярлыка '$value' нет"
                return 1
            fi
            if would "убрать ярлык $value"; then
                return 0
            fi
            backup_once "$NEWTAB_LINKS" "newtab-links.txt"
            # имя ярлыка — данные пользователя, в регулярку его пускать нельзя:
            # точка, звёздочка или скобка удалили бы не ту строку
            local tmp
            tmp=$(mktemp)
            while IFS= read -r line; do
                case "$line" in
                    "$value|"*) : ;;
                    *) printf '%s\n' "$line" >> "$tmp" ;;
                esac
            done < "$NEWTAB_LINKS"
            mv "$tmp" "$NEWTAB_LINKS"
            ok "убран: $value"
            ;;
    esac

    if would "пересобрать страницу новой вкладки"; then
        return 0
    fi
    rebuild_newtab "$clock" "$tile"
}

rebuild_newtab() {
    clock="$1"
    tile="$2"
    head1 "сборка страницы"

    local walldir=$(find_wallpaper_dir)
    local current=$(current_wallpaper)
    local curname=""
    if [ -n "$current" ]; then
        curname=$(basename "$current")
    fi

    local bg="#1a1b26"
    colors="$HOME/.cache/wal/colors.sh"
    if [ -f "$colors" ]; then
        set +u
        . "$colors"
        if [ -n "${background:-}" ]; then
            bg="$background"
        fi
        set -u
    fi

    # Пустой фильтр выбросил бы ВСЕ строки: grep -vF "" совпадает с любой.
    local list=$(find "$walldir" -maxdepth 1 -type f \
           -iregex '.*\.\(jpg\|jpeg\|png\|webp\)' 2>/dev/null | sort)
    if [ -n "$curname" ]; then
        list=$(printf '%s\n' "$list" | grep -vF "$curname")
    fi
    local imgs=$(printf '%s\n' "$list" | sed 's|.*|    "file://&",|')

    # значки из кэша Chrome вместе с журналом: без -wal свежие не видны
    local favsrc="$HOME/.config/google-chrome/Default/Favicons"
    local favdb="/tmp/desktop-kit-favicons"
    rm -f "$favdb" "$favdb-wal" "$favdb-shm" "$favdb-journal"
    if [ -f "$favsrc" ]; then
        cp "$favsrc" "$favdb" 2>/dev/null
        for ext in "-wal" "-shm" "-journal"; do
            if [ -f "$favsrc$ext" ]; then
                cp "$favsrc$ext" "$favdb$ext" 2>/dev/null
            fi
        done
    fi

    # Без python3 значки из кэша Chrome не достать. Раньше страница в этом
    # случае молча собиралась ВООБЩЕ без плиток — то есть пустой. Теперь
    # плитки строятся простыми средствами, с буквой вместо значка.
    local tiles=""
    if ! have python3; then
        bad "python3 нет — значки из кэша Chrome недоступны"
        note "плитки соберу без значков; поставить: sudo apt install python3"
        tiles=$(newtab_tiles_plain)
    else
    tiles=$(python3 - "$NEWTAB_LINKS" "$favdb" "$NEWTAB_DIR/icons.json" <<'PY'
import sys, html, os, base64, sqlite3, json

links, favdb, cache_path = sys.argv[1], sys.argv[2], sys.argv[3]

cur = None
if os.path.exists(favdb):
    try:
        cur = sqlite3.connect(favdb).cursor()
    except Exception:
        cur = None

cache = {}
if os.path.exists(cache_path):
    try:
        cache = json.load(open(cache_path, encoding='utf-8'))
    except Exception:
        cache = {}

def from_chrome(host):
    if cur is None:
        return ''
    try:
        row = cur.execute(
            'SELECT b.image_data FROM icon_mapping m '
            'JOIN favicon_bitmaps b ON b.icon_id = m.icon_id '
            'WHERE m.page_url LIKE ? AND length(b.image_data) > 0 '
            'ORDER BY b.width DESC LIMIT 1', ('%' + host + '%',)).fetchone()
    except Exception:
        return ''
    if not row or not row[0]:
        return ''
    return 'data:image/png;base64,' + base64.b64encode(row[0]).decode()

def icon_for(host):
    got = from_chrome(host)
    if got:
        cache[host] = got
        return got
    return cache.get(host, '')

rows = []
for line in open(links, encoding='utf-8'):
    line = line.strip()
    if not line or line.startswith('#') or '|' not in line:
        continue
    name, url = line.split('|', 1)
    name = html.escape(name.strip()[:22])
    url = html.escape(url.strip())
    letter = html.escape(name[:1].upper()) if name else '?'
    host = url.split('/')[2] if '://' in url else url

    chain = []
    if host:
        chain = [icon_for(host),
                 'https://%s/favicon.ico' % host,
                 'https://www.google.com/s2/favicons?sz=64&domain=%s' % host]
    chain = [c for c in chain if c]

    if chain:
        src, alts = chain[0], '|'.join(chain[1:])
        ico = ('<img src="%s" data-alt="%s" data-letter="%s" onerror="nextIcon(this)">'
               % (src, html.escape(alts), letter))
    else:
        ico = letter

    rows.append('<a class="tile" href="%s"><span class="ico">%s</span>'
                '<span class="cap">%s</span></a>' % (url, ico, name))

try:
    json.dump(cache, open(cache_path, 'w', encoding='utf-8'))
except Exception:
    pass

sys.stderr.write('    значки: из Chrome и кэша %d\n' % len(cache))
print('\n'.join(rows))
PY
)
    fi

    cat > "$NEWTAB_DIR/index.html" <<EOF
<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><title>New Tab</title>
<style>
  html,body{margin:0;height:100%;font-family:"JetBrainsMono Nerd Font",monospace;}
  body{background:$bg center/cover no-repeat fixed;display:flex;align-items:center;
       justify-content:center;flex-direction:column;gap:34px;}
  .box{padding:30px 56px;border-radius:22px;background:rgba(0,0,0,.32);
       backdrop-filter:blur(14px);text-align:center;}
  .clock{font-size:${clock}px;font-weight:600;color:#fff;letter-spacing:2px;line-height:1;
         text-shadow:0 2px 12px rgba(0,0,0,.55);}
  .date{font-size:24px;font-weight:600;color:#fff;opacity:.9;margin-top:8px;}
  .tiles{display:flex;flex-wrap:wrap;gap:14px;justify-content:center;max-width:900px;}
  .tile{width:${tile}px;padding:22px 10px;border-radius:16px;background:rgba(0,0,0,.32);
        backdrop-filter:blur(10px);text-decoration:none;display:flex;flex-direction:column;
        align-items:center;gap:11px;transition:.15s;}
  .tile:hover{background:rgba(255,255,255,.18);transform:translateY(-2px);}
  .ico{width:52px;height:52px;border-radius:13px;background:rgba(255,255,255,.14);
       display:flex;align-items:center;justify-content:center;color:#fff;font-size:22px;font-weight:700;}
  .ico img{width:34px;height:34px;}
  .cap{font-size:16px;font-weight:700;color:#fff;max-width:116px;overflow:hidden;
       text-overflow:ellipsis;white-space:nowrap;text-shadow:0 1px 6px rgba(0,0,0,.6);}
  /* Подсказка раньше была почти прозрачной и на светлой картинке исчезала. */
  .hint{position:fixed;bottom:16px;right:20px;font-size:12px;color:#fff;opacity:.75;
        background:rgba(0,0,0,.35);padding:4px 9px;border-radius:7px;}
  .toast{position:fixed;bottom:16px;left:20px;font-size:13px;color:#fff;opacity:0;
         background:rgba(0,0,0,.45);padding:7px 13px;border-radius:9px;transition:opacity .25s;}
</style></head>
<body>
  <div class="box"><div class="clock" id="c"></div><div class="date" id="d"></div></div>
  <div class="tiles">
$tiles
  </div>
  <div class="hint">← → смена фона</div>
  <div class="toast" id="t"></div>
<script>
function nextIcon(img){
  var rest=img.dataset.alt;
  if(!rest){rest='';}
  var list=rest.split('|').filter(Boolean);
  if(list.length){
    img.src=list.shift();
    img.dataset.alt=list.join('|');
    return;
  }
  var letter=img.dataset.letter;
  if(!letter){letter='?';}
  img.replaceWith(document.createTextNode(letter));
}
const imgs=[
$imgs
];
const KEY='ntbg';
let idx=parseInt(localStorage.getItem(KEY),10);
if(isNaN(idx)){idx=-1;}
if(idx<0){idx=Math.floor(Math.random()*imgs.length);}
if(idx>=imgs.length){idx=Math.floor(Math.random()*imgs.length);}
function show(i,say){
  if(!imgs.length)return;
  idx=(i%imgs.length+imgs.length)%imgs.length;
  localStorage.setItem(KEY,idx);
  document.body.style.backgroundImage='url("'+imgs[idx]+'")';
  if(say){
    const t=document.getElementById('t');
    t.textContent=(idx+1)+' / '+imgs.length;
    t.style.opacity='1';
    clearTimeout(window._tm);
    window._tm=setTimeout(function(){t.style.opacity='0';},1400);
  }
}
show(idx,false);
document.addEventListener('keydown',function(e){
  if(e.key==='ArrowRight'){show(idx+1,true);e.preventDefault();}
  if(e.key==='ArrowLeft'){show(idx-1,true);e.preventDefault();}
});
function tick(){const n=new Date();
  document.getElementById('c').textContent=String(n.getHours()).padStart(2,'0')+':'+String(n.getMinutes()).padStart(2,'0');
  document.getElementById('d').textContent=n.toLocaleDateString('ru-RU',{weekday:'long',day:'numeric',month:'long'});}
tick();setInterval(tick,10000);
</script>
</body></html>
EOF

    rm -f "$favdb" "$favdb-wal" "$favdb-shm" "$favdb-journal"

    ok "страница: $NEWTAB_DIR/index.html"
    note "ярлыков: $(grep -c 'class=\"tile\"' "$NEWTAB_DIR/index.html")"
    note "со значками: $(grep -o 'src=\"data:image' "$NEWTAB_DIR/index.html" | wc -l)"
    note "картинок фона: $(printf '%s\n' "$imgs" | grep -c 'file://')"
}

# =====================================================================
#  wallpapers / wall — банк обоев и смена
# =====================================================================

find_wallpaper_dir() {
    for d in "$HOME/Pictures/wallpapers-uw" "$HOME/Изображения/wallpapers-uw" \
             "$HOME/Pictures/wallpapers" "$HOME/Изображения/wallpapers"; do
        if [ -d "$d" ]; then
            echo "$d"
            return 0
        fi
    done
    local p=$(xdg-user-dir PICTURES 2>/dev/null)
    if [ -z "$p" ]; then
        p="$HOME/Pictures"
    fi
    echo "$p/wallpapers-uw"
}

current_wallpaper() {
    saved="$STATE_DIR/current-wallpaper"
    if [ -s "$saved" ]; then
        local c=$(cat "$saved")
        if [ -f "$c" ]; then
            echo "$c"
            return 0
        fi
    fi
    g=$(gsettings get org.gnome.desktop.background picture-uri-dark 2>/dev/null | tr -d "'" | sed 's#^file://##')
    if [ ! -f "$g" ]; then
        g=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'" | sed 's#^file://##')
    fi
    if [ -f "$g" ]; then
        echo "$g"
    fi
}

detect_resolution() {
    r=$(cat /sys/class/drm/card*-*/modes 2>/dev/null \
        | grep -oE '^[0-9]+x[0-9]+$' | sort -t x -k1,1nr -k2,2nr | head -1)
    if [ -z "$r" ]; then
        r=$(xrandr 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | head -1)
    fi
    if [ -z "$r" ]; then
        r="1920x1080"
    fi
    echo "$r"
}

help_wallpapers() {
    cat <<'EOF'
wallpapers — банк обоев

  desktop-kit wallpapers                добрать 10 картинок
  desktop-kit wallpapers --count 25     добрать 25
  desktop-kit wallpapers --init         первая заливка (250)
  desktop-kit wallpapers --status       банк, расписание, последние запуски
  desktop-kit wallpapers --timer Wed 13:00   пополнять по расписанию
  desktop-kit wallpapers --timer off    снять расписание
  desktop-kit wallpapers --prune 900    оставить 900 самых свежих
  desktop-kit wallpapers --urls         показать, какие запросы уйдут

  Качает рисованное под родное разрешение монитора. Набор тем и seed
  привязаны к номеру недели: внутри недели выдача повторяется, следующая
  неделя приносит другое.

  Расписание ставит копию скрипта в ~/bin и ссылается туда, поэтому
  скачанный файл можно потом удалить. День будний не случайно: рабочий
  ноутбук по выходным выключен, а Persistent лишь отложил бы запуск.
EOF
}

week_themes() {
    local all="digital+art artwork illustration scenery landscape fantasy space \
mountains forest sunset ocean neon city abstract minimal aurora clouds \
mist canyon lake nordic"
    local seed=$(date +%V)
    echo "$all" | tr ' ' '\n' | grep -v '^$' \
        | shuf --random-source=<(yes "$seed") | head -6 | tr '\n' ' '
}

wallpaper_urls() {
    local res="$1"
    seed=$(date +%GW%V | tr -d 'W-' | cut -c1-6)
    for q in $(week_themes); do
        echo "$WALLHAVEN?q=$q&atleast=$res&categories=100&purity=100&sorting=random&seed=$seed&page=1"
        echo "$WALLHAVEN?q=$q&atleast=$res&categories=100&purity=100&sorting=toplist&topRange=1y&page=1"
    done
}

cmd_wallpapers() {
    local count=10
    action="add"
    local day=""
    local at=""
    local keep=900
    while [ $# -gt 0 ]; do
        case "$1" in
            --count) need_args "--count" 2 "$#"; count="${2:-10}"; shift 2 ;;
            --init)   action="init"; count=250; shift ;;
            --status) action="status"; shift ;;
            --timer)
                # off указывается одним словом: --timer off
                if [ "${2:-}" = "off" ]; then
                    action="timer"; day="off"; at=""; shift 2
                else
                    need_args "--timer" 3 "$#"
                    action="timer"; day="$2"; at="$3"; shift 3
                fi
                ;;
            --prune)  need_args "--prune" 2 "$#"; action="prune"; keep="$2"; shift 2 ;;
            --urls)   action="urls"; shift ;;
            -h|--help) help_wallpapers; return 0 ;;
            *) die "wallpapers: неизвестный параметр $1" ;;
        esac
    done

    walldir=$(find_wallpaper_dir)

    case "$action" in
        status)
            head1 "банк обоев"
            if [ -d "$walldir" ]; then
                local n=$(find "$walldir" -maxdepth 1 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\)' 2>/dev/null | wc -l)
                local size=$(du -sh "$walldir" 2>/dev/null | cut -f1)
                note "каталог:    $walldir"
                note "картинок:   $n"
                note "размер:     $size"
            else
                note "каталога нет: $walldir"
            fi
            note "разрешение: $(detect_resolution)"
            local unit="$HOME/.config/systemd/user/desktop-kit-wallpapers.timer"
            if [ -f "$unit" ]; then
                note "расписание: $(grep '^OnCalendar' "$unit" | cut -d= -f2)"
                systemctl --user list-timers desktop-kit-wallpapers.timer --no-pager 2>/dev/null | sed -n '2p' | dump
            else
                note "расписание: не настроено"
            fi
            return 0
            ;;
        urls)
            head1 "запросы недели"
            note "разрешение: $(detect_resolution)"
            note "темы: $(week_themes)"
            wallpaper_urls "$(detect_resolution)" | dump
            return 0
            ;;
        timer)
            install_wallpaper_timer "$day" "$at"
            return $?
            ;;
        prune)
            prune_wallpapers "$walldir" "$keep"
            return $?
            ;;
    esac

    if ! is_number "$count"; then
        die "wallpapers: количество — целое число"
    fi
    require_tools curl jq file
    mkdir -p "$walldir"
    res=$(detect_resolution)
    local have_now=$(find "$walldir" -maxdepth 1 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\)' 2>/dev/null | wc -l)
    head1 "пополнение банка"
    note "каталог $walldir: $have_now шт., разрешение $res, добираю $count"

    if would "скачать до $count картинок"; then
        return 0
    fi

    local pool=$(mktemp)
    local fresh=$(mktemp)
    local take=$(mktemp)
    local failed=0
    for u in $(wallpaper_urls "$res"); do
        r=$(curl -sf --max-time 25 "$u" 2>/dev/null)
        if [ -z "$r" ]; then
            failed=$((failed + 1))
            continue
        fi
        echo "$r" | jq -r '.data[]?.path' 2>/dev/null >> "$pool"
        sleep 2
    done

    if [ ! -s "$pool" ]; then
        rm -f "$pool" "$fresh" "$take"
        bad "wallhaven не ответил ни на один запрос"
        return 1
    fi
    if [ "$failed" -gt 0 ]; then
        note "запросов без ответа: $failed"
    fi

    grep '\.jpg$' "$pool" | sort -u | shuf > "$pool.all"
    : > "$fresh"
    while read -r url; do
        name=$(basename "$url")
        if [ ! -f "$walldir/$name" ]; then
            echo "$url" >> "$fresh"
        fi
    done < "$pool.all"

    head -n "$count" "$fresh" > "$take"
    n=$(wc -l < "$take")
    note "новых к загрузке: $n"
    if [ "$n" -eq 0 ]; then
        rm -f "$pool" "$pool.all" "$fresh" "$take"
        ok "всё, что нашлось, уже в банке"
        return 0
    fi

    local dl_rc=0
    if ( cd "$walldir"; xargs -r -n1 -P3 curl -sf --retry 2 --retry-delay 2 \
        --max-time 120 --remove-on-error -O ) < "$take"; then
        dl_rc=0
    else
        dl_rc=$?
    fi
    if [ "$dl_rc" != "0" ]; then
        note "часть ссылок не отдалась (код $dl_rc)"
    fi

    local missed=0
    while read -r url; do
        if [ ! -f "$walldir/$(basename "$url")" ]; then
            missed=$((missed + 1))
        fi
    done < "$take"
    if [ "$missed" -gt 0 ]; then
        note "не скачалось: $missed из $n"
    fi

    # Проверяем ТОЛЬКО что скачали. Проход по всему каталогу удалил бы
    # чужие файлы: заметки, README, картинки других форматов.
    local bad_files=0
    local heavy=0
    while read -r url; do
        local f="$walldir/$(basename "$url")"
        if [ ! -f "$f" ]; then
            continue
        fi
        if ! file --brief --mime-type "$f" | grep -q '^image/'; then
            rm -f "$f"
            bad_files=$((bad_files + 1))
            continue
        fi
        if [ "$(stat -c%s "$f" 2>/dev/null)" -gt 12582912 ]; then
            rm -f "$f"
            heavy=$((heavy + 1))
        fi
    done < "$take"

    local now
    now=$(find "$walldir" -maxdepth 1 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\)' 2>/dev/null | wc -l)
    if [ "$now" -le "$have_now" ]; then
        bad "ни одна картинка не скачалась"
        note "проверь сеть и доступность w.wallhaven.cc"
        rm -f "$pool" "$pool.all" "$fresh" "$take"
        return 1
    fi
    if [ "$bad_files" -gt 0 ]; then
        note "выброшено битых: $bad_files"
    fi
    if [ "$heavy" -gt 0 ]; then
        note "выброшено тяжелее 12 МБ: $heavy"
    fi
    ok "добавлено $((now - have_now)), всего в банке $now"

    if [ -x "$BIN_DIR/desktop-kit" ]; then
        "$BIN_DIR/desktop-kit" newtab >/dev/null 2>&1
        ok "страница новой вкладки пересобрана"
    fi

    if have notify-send; then
        notify-send -a "Обои" "Банк пополнен" "добавлено $((now - have_now)), всего $now" 2>/dev/null
    fi

    rm -f "$pool" "$pool.all" "$fresh" "$take"
}

install_wallpaper_timer() {
    day="$1"
    at="$2"
    local unit_dir="$HOME/.config/systemd/user"
    name="desktop-kit-wallpapers"

    if [ "$day" = "off" ]; then
        if would "снять расписание"; then
            return 0
        fi
        systemctl --user disable --now "$name.timer" >/dev/null 2>&1
        rm -f "$unit_dir/$name.timer" "$unit_dir/$name.service"
        systemctl --user daemon-reload 2>/dev/null
        ok "расписание снято, банк и скрипт на месте"
        return 0
    fi

    if ! echo "$day" | grep -qE '^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)(,(Mon|Tue|Wed|Thu|Fri|Sat|Sun))*$'; then
        die "день: Mon Tue Wed Thu Fri Sat Sun, можно через запятую"
    fi
    if ! echo "$at" | grep -qE '^([01][0-9]|2[0-3]):[0-5][0-9]$'; then
        die "время в формате ЧЧ:ММ, часы 00-23"
    fi

    if would "поставить расписание $day $at"; then
        return 0
    fi

    # копия в постоянном месте: иначе уборка ~/Desktop сломает расписание
    mkdir -p "$BIN_DIR"
    target="$BIN_DIR/desktop-kit"
    if [ "$SELF" != "$target" ]; then
        cp "$SELF" "$target"
        chmod +x "$target"
        ok "скрипт установлен: $target"
    fi

    mkdir -p "$unit_dir"
    cat > "$unit_dir/$name.service" <<EOF
[Unit]
Description=Пополнение банка обоев
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$target wallpapers --count 10
EOF

    cat > "$unit_dir/$name.timer" <<EOF
[Unit]
Description=Пополнение банка обоев по расписанию

[Timer]
OnCalendar=$day $at
RandomizedDelaySec=2h
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload 2>/dev/null
    systemctl --user enable --now "$name.timer" >/dev/null 2>&1
    ok "расписание: $day в $at, по 10 картинок"
    systemctl --user list-timers "$name.timer" --no-pager 2>/dev/null | sed -n '1,2p' | dump
}

prune_wallpapers() {
    local walldir="$1"
    local keep="$2"
    if ! is_number "$keep"; then
        die "prune: число"
    fi
    # Только картинки: в каталоге обоев могут лежать заметки автора,
    # список источников или что угодно ещё, и это не наш мусор.
    local imgs
    imgs=$(mktemp)
    find "$walldir" -maxdepth 1 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\)' \
        -printf '%T@ %p\n' 2>/dev/null | sort -rn > "$imgs"
    local have_now
    have_now=$(wc -l < "$imgs")
    if [ "$have_now" -le "$keep" ]; then
        ok "в банке $have_now, удалять нечего"
        return 0
    fi
    local drop=$((have_now - keep))
    head1 "чистка банка"
    local cur_wall
    cur_wall=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'" | sed 's#^file://##')
    note "в банке $have_now, удалить $drop самых старых"
    if would "удалить $drop картинок"; then
        return 0
    fi
    if ! confirm "продолжить?"; then
        note "отменено"
        rm -f "$imgs"
        return 0
    fi
    if [ -n "$cur_wall" ]; then
        if tail -n "$drop" "$imgs" | cut -d' ' -f2- | grep -qxF "$cur_wall"; then
            note "среди удаляемых текущие обои — ставлю следующие"
            cmd_wall >/dev/null 2>&1
        fi
    fi
    tail -n "$drop" "$imgs" | cut -d' ' -f2- | while read -r f; do
        rm -f "$f"
    done
    rm -f "$imgs"
    ok "удалено $drop, осталось $(find "$walldir" -maxdepth 1 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\)' 2>/dev/null | wc -l)"
}

help_wall() {
    cat <<'EOF'
wall — смена обоев по списку каталога

  desktop-kit wall            следующая по порядку
  desktop-kit wall --prev     предыдущая
  desktop-kit wall --random   случайная
  desktop-kit wall --set ФАЙЛ конкретная
  desktop-kit wall --show     какая стоит и её номер

  Листает каталог по порядку, а не по истории показов. Позиция
  запоминается ИМЕНЕМ файла: банк пополняется, и номер бы съезжал.

  Заодно обновляет палитру pywal и пересобирает страницу новой вкладки,
  чтобы её фон не совпал с рабочим столом.

  ЧТО МЕНЯЕТСЯ ПОМИМО ОБОЕВ РАБОЧЕГО СТОЛА:
    * обои экрана блокировки (screensaver picture-uri);
    * режим вписывания picture-options становится zoom;
    * цвета профиля GNOME Terminal — палитра идёт за картинкой, так что
      настройки из terminal --palette будут перезаписаны;
    * страница новой вкладки пересобирается с параметрами по умолчанию.
EOF
}

cmd_wall() {
    action="next"
    target=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --prev)    action="prev"; shift ;;
            --random)  action="random"; shift ;;
            --set)     need_args "--set" 2 "$#"; action="set"; target="$2"; shift 2 ;;
            --show)    action="show"; shift ;;
            -h|--help) help_wall; return 0 ;;
            *) die "wall: неизвестный параметр $1" ;;
        esac
    done

    walldir=$(find_wallpaper_dir)
    local tmp=$(mktemp)
    find "$walldir" -maxdepth 1 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\)' 2>/dev/null | sort > "$tmp"
    local total=$(wc -l < "$tmp")
    if [ "$total" -eq 0 ]; then
        rm -f "$tmp"
        die "в каталоге нет картинок: $walldir"
    fi

    cur=$(current_wallpaper)
    local pos=0
    if [ -n "$cur" ]; then
        line=$(grep -n -x -F "$cur" "$tmp" | head -1 | cut -d: -f1)
        if [ -n "$line" ]; then
            pos="$line"
        fi
    fi

    case "$action" in
        show)
            head1 "обои"
            note "каталог:  $walldir"
            note "картинок: $total"
            if [ "$pos" = "0" ]; then
                note "позиция:  вне списка"
            else
                note "позиция:  $pos"
            fi
            note "файл:     $cur"
            rm -f "$tmp"
            return 0
            ;;
        random)
            file=$(shuf -n1 "$tmp")
            ;;
        set)
            if [ ! -f "$target" ]; then
                rm -f "$tmp"
                die "нет такого файла: $target"
            fi
            file=$(readlink -f "$target")
            ;;
        next|prev)
            local delta=1
            if [ "$action" = "prev" ]; then
                delta=-1
            fi
            if [ "$pos" -eq 0 ]; then
                local nextpos=1
            else
                nextpos=$(( (pos - 1 + delta + total) % total + 1 ))
            fi
            file=$(sed -n "${nextpos}p" "$tmp")
            ;;
    esac
    rm -f "$tmp"

    if would "поставить обои $file"; then
        return 0
    fi

    mkdir -p "$STATE_DIR"
    echo "$file" > "$STATE_DIR/current-wallpaper"
    gsettings set org.gnome.desktop.background picture-uri "file://$file" 2>/dev/null
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$file" 2>/dev/null
    gsettings set org.gnome.desktop.background picture-options 'zoom' 2>/dev/null
    gsettings set org.gnome.desktop.screensaver picture-uri "file://$file" 2>/dev/null

    if have wal; then
        wal -i "$file" -n -q >/dev/null 2>&1
        prof=$(term_profile)
        if [ -n "$prof" ]; then
            apply_wal_palette "$prof" >/dev/null 2>&1
        fi
    fi

    if [ -x "$BIN_DIR/desktop-kit" ]; then
        ( "$BIN_DIR/desktop-kit" newtab >/dev/null 2>&1 & )
    fi

    ok "$(basename "$file")"
    if have notify-send; then
        notify-send -a "Обои" -t 1500 "$(basename "$file")" 2>/dev/null
    fi
}

# =====================================================================
#  app — тема отдельного приложения
# =====================================================================

help_app() {
    cat <<'EOF'
app — своя тема для одного приложения

  desktop-kit app evolution --theme Yaru
  desktop-kit app ИМЯ --theme ТЕМА
  desktop-kit app ИМЯ --reset

  Приложению подставляется GTK_THEME через его же ярлык в
  ~/.local/share/applications. Правятся ВСЕ строки Exec, включая
  пункты контекстного меню дока — иначе "Написать письмо" откроется
  в прежней теме.

  Работает только для GTK-приложений. Kate и прочие Qt настраиваются
  через qt6ct или Kvantum.
EOF
}

cmd_app() {
    local app=""
    theme=""
    local reset=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --theme) need_args "--theme" 2 "$#"; theme="${2:-}"; shift 2 ;;
            --reset)   reset=1; shift ;;
            -h|--help) help_app; return 0 ;;
            -*) die "app: неизвестный параметр $1" ;;
            *) app="$1"; shift ;;
        esac
    done

    if [ -z "$app" ]; then
        die "app: назови приложение, например evolution"
    fi

    src=""
    for f in "$SYS_APPS/org.gnome.$(echo "$app" | sed 's/^./\U&/').desktop" \
             "$SYS_APPS/$app.desktop"; do
        if [ -f "$f" ]; then
            src="$f"
        fi
    done
    if [ -z "$src" ]; then
        found=$(ls "$SYS_APPS/" 2>/dev/null | grep -i "$app" | head -3)
        bad "ярлык приложения '$app' не найден"
        if [ -n "$found" ]; then
            note "похожие: $found"
        fi
        return 1
    fi

    dst="$HOME/.local/share/applications/$(basename "$src")"

    if [ "$reset" = "1" ]; then
        if would "убрать свой ярлык $dst"; then
            return 0
        fi
        # ярлык мог быть написан пользователем до нас — тогда это не наш мусор
        if [ -f "$dst" ]; then
            if ! grep -qF -- "$APP_MARK" "$dst"; then
                if ! grep -q 'GTK_THEME=' "$dst"; then
                    bad "$dst не похож на ярлык с подменой темы"
                    note "убери вручную, если это действительно лишний файл"
                    return 1
                fi
                bad "$dst подменяет тему, но метки desktop-kit в нём нет"
                note "похоже, его сделал ты сам или прежний evolution-light.sh"
                if ! confirm "всё равно удалить?"; then
                    note "оставляю как есть"
                    return 1
                fi
            fi
        fi
        rm -f "$dst"
        if have update-desktop-database; then
            update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
        fi
        ok "свой ярлык убран, приложение вернулось к системной теме"
        return 0
    fi

    if [ -z "$theme" ]; then
        die "app: нужна тема, например --theme Yaru"
    fi
    if ! theme_exists "$theme"; then
        bad "темы '$theme' нет"
        note "доступные: $(list_themes | tr '\n' ' ')"
        return 1
    fi

    head1 "тема для $app"
    if would "подставить GTK_THEME=$theme в $dst"; then
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    # если пользователь уже правил этот ярлык — сохраняем его версию
    if [ -f "$dst" ]; then
        if ! grep -q 'GTK_THEME=' "$dst"; then
            backup_once "$dst" "app-$(basename "$dst")"
        fi
    fi
    cp "$src" "$dst"

    # каждый Exec, включая Actions: иначе часть пунктов останется прежней
    n=0
    tmp=$(mktemp)
    while IFS= read -r line; do
        case "$line" in
            Exec=*)
                local cmd="${line#Exec=}"
                case "$cmd" in
                    env\ *)
                        local rest="${cmd#env }"
                        while true; do
                            local word="${rest%% *}"
                            case "$word" in
                                *=*) rest="${rest#* }" ;;
                                *) break ;;
                            esac
                        done
                        cmd="$rest"
                        ;;
                esac
                line="Exec=env GTK_THEME=$theme $cmd"
                n=$((n + 1))
                ;;
        esac
        printf '%s\n' "$line" >> "$tmp"
    done < "$dst"
    printf '%s\n' "$APP_MARK" >> "$tmp"
    mv "$tmp" "$dst"

    if have update-desktop-database; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
    fi
    ok "$app будет запускаться с темой $theme (строк запуска: $n)"
    note "проверить: GTK_THEME=$theme $app"
}

# =====================================================================
#  serve — локальная апка по http
# =====================================================================

help_serve() {
    cat <<'EOF'
serve — отдать локальную страницу по http://localhost

  desktop-kit serve ПУТЬ [--port N]
  desktop-kit serve --stop ИМЯ
  desktop-kit serve --list

  Плитка с адресом file:// на странице новой вкладки молча не
  открывается: страница живёт в контексте расширения, а Chrome
  запрещает уходить оттуда к локальным файлам. По http ограничения нет.

  Слушает только 127.0.0.1 — из сети апка недоступна.

  Служба ПОСТОЯННАЯ: это systemd-юнит с автозапуском при входе, а не
  временный сервер на время сессии. Снять — serve --stop ИМЯ или
  revert serve.
EOF
}

cmd_serve() {
    local path=""
    local port=8800
    action="start"
    name=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --port) need_args "--port" 2 "$#"; port="${2:-8800}"; shift 2 ;;
            --stop)    need_args "--stop" 2 "$#"; action="stop"; name="$2"; shift 2 ;;
            --list)    action="list"; shift ;;
            -h|--help) help_serve; return 0 ;;
            -*) die "serve: неизвестный параметр $1" ;;
            *) path="$1"; shift ;;
        esac
    done

    unit_dir="$HOME/.config/systemd/user"

    if [ "$action" = "list" ]; then
        head1 "локальные апки"
        ls "$unit_dir"/desktop-kit-serve-*.service 2>/dev/null | while read -r f; do
            n=$(basename "$f" .service)
            note "$n — $(grep '^ExecStart' "$f" | sed 's/.*--directory //')"
        done
        return 0
    fi

    if [ "$action" = "stop" ]; then
        if [ -z "$name" ]; then
            die "serve: назови апку, список: $0 serve --list"
        fi
        unit="desktop-kit-serve-$name"
        if would "остановить $unit"; then
            return 0
        fi
        systemctl --user disable --now "$unit.service" >/dev/null 2>&1
        rm -f "$unit_dir/$unit.service"
        systemctl --user daemon-reload 2>/dev/null
        ok "остановлено: $name"
        return 0
    fi

    if [ -z "$path" ]; then
        die "serve: укажи каталог с index.html"
    fi
    if [ ! -d "$path" ]; then
        die "каталога нет: $path"
    fi
    if [ ! -f "$path/index.html" ]; then
        bad "в каталоге нет index.html"
        note "что там лежит:"
        ls "$path" | dump
        return 1
    fi
    if ! is_number "$port"; then
        die "serve: порт — число"
    fi

    path=$(cd "$path"; pwd)
    name=$(basename "$path")
    unit="desktop-kit-serve-$name"

    head1 "апка $name на порту $port"

    if ss -ltn 2>/dev/null | grep -q ":$port "; then
        if systemctl --user is-active --quiet "$unit.service"; then
            note "порт занят нашей же службой — перезапускаю"
            systemctl --user stop "$unit.service" 2>/dev/null
        else
            bad "порт $port занят чужим процессом"
            ss -ltnp 2>/dev/null | grep ":$port " | dump
            note "возьми другой: $0 serve \"$path\" --port 8801"
            return 1
        fi
    fi

    if would "поднять службу $unit"; then
        return 0
    fi

    mkdir -p "$unit_dir"
    cat > "$unit_dir/$unit.service" <<EOF
[Unit]
Description=Локальная апка $name
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server $port --bind 127.0.0.1 --directory $path
Restart=on-failure

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload 2>/dev/null
    systemctl --user enable --now "$unit.service" >/dev/null 2>&1
    sleep 1

    code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$port/" 2>/dev/null)
    if [ "$code" = "200" ]; then
        ok "отвечает: http://localhost:$port"
        note "добавить на новую вкладку: $0 newtab --add \"$name|http://localhost:$port\""
    else
        bad "не отвечает (код '$code')"
        note "журнал: journalctl --user -u $unit -n 20"
        return 1
    fi
}

# =====================================================================
#  status — что применено
# =====================================================================

cmd_status() {
    head1 "состояние"
    note "тема окон:     $(gi_get gtk-theme)"
    note "тема значков:  $(gi_get icon-theme)"
    note "схема:         $(gi_get color-scheme)"
    note "шрифт:         $(gi_get font-name)"
    note "моноширинный:  $(gi_get monospace-font-name)"

    blank
    for f in "$CSS3" "$CSS4"; do
        local label=$(basename "$(dirname "$f")")
        if [ -L "$f" ]; then
            bad "$label: СИМЛИНК на $(readlink -f "$f") — наши правки туда писать нельзя"
            continue
        fi
        if [ ! -f "$f" ]; then
            note "$label: файла нет"
            continue
        fi
        local blocks=$(grep -o 'dk:[a-z]*-begin' "$f" 2>/dev/null | sed 's/dk://; s/-begin//' | tr '\n' ' ')
        if [ -n "$blocks" ]; then
            ok "$label: $blocks"
        else
            note "$label: наших правил нет"
        fi
        if grep -q '!important' "$f" 2>/dev/null; then
            bad "$label: содержит !important — GTK отбросит эти правила целиком"
            grep -n '!important' "$f" | head -3 | dump
        fi
        if grep -q "$LEGACY_CSS_MARK" "$f" 2>/dev/null; then
            bad "$label: остались правила старого look.sh"
            note "они будут спорить с нашими; снимутся при следующем buttons"
        fi
    done

    blank
    walldir=$(find_wallpaper_dir)
    if [ -d "$walldir" ]; then
        n=$(find "$walldir" -maxdepth 1 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\)' 2>/dev/null | wc -l)
        note "банк обоев:    $n шт. в $walldir"
    fi
    if [ -f "$HOME/.config/systemd/user/desktop-kit-wallpapers.timer" ]; then
        note "пополнение:    $(grep '^OnCalendar' "$HOME/.config/systemd/user/desktop-kit-wallpapers.timer" | cut -d= -f2)"
    fi
    if [ -f "$NEWTAB_DIR/index.html" ]; then
        note "новая вкладка: $(grep -c 'class="tile"' "$NEWTAB_DIR/index.html") ярлыков"
    fi
    if [ -f "$CONKY_LUA" ]; then
        note "виджет:        $(grep -m1 'local RADIUS' "$CONKY_LUA" | tr -d ' ')"
    fi

    # Подсистемы, которых в срезе раньше не было вовсе
    blank
    local prof
    prof=$(term_profile)
    if [ -n "$prof" ]; then
        note "терминал:      прозрачность $(gsettings get "$prof" background-transparency-percent 2>/dev/null), своя палитра $(gsettings get "$prof" use-theme-colors 2>/dev/null)"
    fi
    if have dconf; then
        note "тема оболочки: $(dconf read /org/gnome/shell/extensions/user-theme/name 2>/dev/null)"
        note "панель:        прозрачность $(dconf read $DTP/trans-panel-opacity 2>/dev/null), размеры $(dconf read $DTP/panel-sizes 2>/dev/null)"
    fi
    local nkeys
    nkeys=$(keys_list_paths | grep -c . 2>/dev/null)
    note "свои клавиши:  $nkeys шт."
    local nserve
    nserve=$(ls "$HOME/.config/systemd/user"/desktop-kit-serve-*.service 2>/dev/null | grep -c . )
    note "локальные апки: $nserve служб"
    local napps
    napps=$(grep -l 'GTK_THEME=' "$HOME/.local/share/applications"/*.desktop 2>/dev/null | grep -c . )
    note "свои ярлыки:   $napps шт."

    blank
    if [ -f "$KIT_STATE" ]; then
        note "наши последние настройки:"
        dump < "$KIT_STATE"
    fi
    if [ -f "$BEFORE" ]; then
        note "что запомнено для отката:"
        dump < "$BEFORE"
    else
        note "снимка исходных настроек нет — откатывать нечего"
    fi
    if [ -d "$BACKUP_DIR" ]; then
        n=$(ls "$BACKUP_DIR" 2>/dev/null | wc -l)
        note "резервных копий файлов: $n"
    fi
}

# =====================================================================
#  revert — откат
# =====================================================================

help_revert() {
    cat <<'EOF'
revert — вернуть как было

  desktop-kit revert              откатить всё
  desktop-kit revert --list       что вообще можно откатить и что запомнено

  По подсистемам:
    app        свои ярлыки приложений — ТОЛЬКО помеченные нами; ярлык,
               который ты сделал сам или прежний evolution-light.sh,
               откат не трогает
    keys       горячие клавиши, заведённые этим скриптом
    serve      службы локальных апок
    buttons    значки заголовка и их подсветка
    corners    скругление окон
    theme      тему окон, цветовую схему, тему оболочки
    icons      тему значков (и снимает наследника со значками заголовка)
    font       шрифт интерфейса, моноширинный, документов
    widget     конфиг conky
    terminal   прозрачность, шрифт и палитру GNOME Terminal
    panel      прозрачность и высоту Dash to Panel
    newtab     список ярлыков новой вкладки

  Подсистемы независимы: revert theme НЕ трогает значки и шрифт, для них
  свои подкоманды. Раньше было иначе, и откат темы уносил заодно значки.

  Возвращаются те значения, что были ДО первого изменения, а не
  умолчания системы: они записываются при первом запуске каждой команды.

  Обои, банк картинок и расписание не откатываются никогда — это данные,
  а не настройки вида.
EOF
}

# Откат терминала. Вынесен в функцию, чтобы полный откат и отдельная
# подкоманда не разъезжались: раньше revert all про панель просто забыл.
revert_terminal() {
    local prof
    prof=$(term_profile)
    if [ -z "$prof" ]; then
        bad "профиль GNOME Terminal не найден"
        return 1
    fi
    local tpair
    local tkey
    local tset
    local tval
    local tn=0
    for tpair in "TERM_TRANSPARENT:use-transparent-background" \
                 "TERM_OPACITY:background-transparency-percent" \
                 "TERM_SYSFONT:use-system-font" \
                 "TERM_FONT:font" \
                 "TERM_THEMECOLORS:use-theme-colors" \
                 "TERM_BG:background-color" \
                 "TERM_FG:foreground-color" \
                 "TERM_PALETTE:palette"; do
        tkey="${tpair%%:*}"
        tset="${tpair##*:}"
        tval=$(recall "$tkey")
        if [ -n "$tval" ]; then
            gsettings set "$prof" "$tset" "$tval" 2>/dev/null
            ok "$tset: $tval"
            tn=$((tn + 1))
        fi
    done
    if [ "$tn" = "0" ]; then
        return 0
    fi
    if pgrep -x gnome-terminal-server >/dev/null 2>&1; then
        note "перезапусти сервер: pkill -x gnome-terminal-server"
    fi
    return 0
}

revert_panel() {
    local dtp_o
    local dtp_s
    local dtp_c
    dtp_c=$(recall DTP_CUSTOM)
    if [ -n "$dtp_c" ]; then
        dconf write $DTP/trans-use-custom-opacity "$dtp_c" 2>/dev/null
        ok "своя прозрачность панели: $dtp_c"
    fi
    dtp_o=$(recall DTP_OPACITY)
    if [ -n "$dtp_o" ]; then
        dconf write $DTP/trans-panel-opacity "$dtp_o" 2>/dev/null
        ok "прозрачность панели: $dtp_o"
    fi
    dtp_s=$(recall DTP_SIZES)
    if [ -n "$dtp_s" ]; then
        dconf write $DTP/panel-sizes "'$dtp_s'" 2>/dev/null
        ok "размеры панели восстановлены"
    fi
    return 0
}

# Свои ярлыки приложений: снимаем только те, где стоит наш GTK_THEME=.
revert_app() {
    local dir="$HOME/.local/share/applications"
    local f
    local n=0
    if [ ! -d "$dir" ]; then
        return 0
    fi
    for f in "$dir"/*.desktop; do
        if [ ! -f "$f" ]; then
            continue
        fi
        # Удаляем ТОЛЬКО помеченные нами. Ярлык с GTK_THEME= мог написать
        # сам человек или прежний evolution-light.sh — это его файл.
        if ! grep -qF -- "$APP_MARK" "$f"; then
            if grep -q 'GTK_THEME=' "$f"; then
                note "$(basename "$f") подменяет тему, но создан не нами — оставляю"
            fi
            continue
        fi
        if grep -q 'GTK_THEME=' "$f"; then
            rm -f "$f"
            ok "убран свой ярлык: $(basename "$f")"
            n=$((n + 1))
        fi
    done
    if [ "$n" -gt 0 ]; then
        if have update-desktop-database; then
            update-desktop-database "$dir" >/dev/null 2>&1
        fi
    fi
    return 0
}

# Горячие клавиши: снимаем ровно те пути, что заводили сами.
revert_keys() {
    local ours
    ours=$(state_get KEYS_OURS)
    if [ -z "$ours" ]; then
        return 0
    fi
    local all
    local keep=""
    local p
    local mine
    all=$(keys_list_paths)
    for p in $all; do
        mine=0
        for o in $ours; do
            if [ "$o" = "$p" ]; then
                mine=1
            fi
        done
        if [ "$mine" = "1" ]; then
            dconf reset -f "$p" 2>/dev/null
            continue
        fi
        keep="$keep'$p', "
    done
    keep=$(echo "$keep" | sed 's/, $//')
    if [ -z "$keep" ]; then
        gsettings set "$KEYS_SCHEMA" custom-keybindings "[]" 2>/dev/null
    else
        gsettings set "$KEYS_SCHEMA" custom-keybindings "[$keep]" 2>/dev/null
    fi
    state_set KEYS_OURS ""
    ok "свои горячие клавиши сняты"
    return 0
}

# Локальные апки: юниты живут в systemd и переживают любой откат файлов.
revert_serve() {
    local unit_dir="$HOME/.config/systemd/user"
    local f
    local n
    if [ ! -d "$unit_dir" ]; then
        return 0
    fi
    for f in "$unit_dir"/desktop-kit-serve-*.service; do
        if [ ! -f "$f" ]; then
            continue
        fi
        n=$(basename "$f" .service)
        systemctl --user disable --now "$n" >/dev/null 2>&1
        rm -f "$f"
        ok "служба остановлена: $n"
    done
    systemctl --user daemon-reload >/dev/null 2>&1
    return 0
}

# Откат нескольких ключей org.gnome.desktop.interface разом.
revert_gi_keys() {
    local pair
    local key
    local setting
    local value
    for pair in "$@"; do
        key="${pair%%:*}"
        setting="${pair##*:}"
        value=$(recall "$key")
        if [ -n "$value" ]; then
            gi_set "$setting" "$value"
            ok "$setting: $value"
        fi
    done
}

cmd_revert() {
    local what="${1:-all}"
    case "$what" in
        -h|--help) help_revert; return 0 ;;
        --list)
            head1 "что можно откатить"
            note "подсистемы: buttons corners theme icons font widget terminal"
            note "            panel newtab app keys serve"
            echo
            if [ -f "$BEFORE" ]; then
                note "запомнено на сейчас:"
                dump < "$BEFORE"
            else
                note "ничего не запомнено — команды ещё не запускались"
            fi
            echo
            if [ -d "$BACKUP_DIR" ]; then
                note "резервные копии файлов:"
                ls "$BACKUP_DIR" 2>/dev/null | dump
            fi
            return 0
            ;;
    esac

    head1 "откат: $what"

    if [ "$DRY_RUN" = "1" ]; then
        note "(проверка) было бы возвращено:"
        if [ -f "$BEFORE" ]; then
            dump < "$BEFORE"
        else
            note "      снимка исходных настроек нет"
        fi
        note "      блоки правил из gtk.css: $(grep -o 'dk:[a-z]*-begin' "$CSS3" "$CSS4" 2>/dev/null | sed 's/.*dk://; s/-begin//' | sort -u | tr '\n' ' ')"
        if [ -d "$BACKUP_DIR" ]; then
            note "      файлы из резервных копий: $(ls "$BACKUP_DIR" 2>/dev/null | tr '\n' ' ')"
        fi
        return 0
    fi

    if [ "$what" = "all" ]; then
        if [ ! -f "$BEFORE" ]; then
            note "снимка исходных настроек нет — команды ещё не запускались"
            note "верну только то, что видно по файлам: блоки правил и копии"
        fi
        for tag in buttons corners; do
            css_strip "$tag" "$CSS3"
            css_strip "$tag" "$CSS4"
        done
        ok "правила из gtk.css убраны"

        restore_backup "$CSS3" "gtk-3.0-gtk.css" blocks
        restore_backup "$CSS4" "gtk-4.0-gtk.css" blocks

        local cur_icon
        cur_icon=$(gi_get icon-theme)
        case "$cur_icon" in
            *-dk-glyphs)
                local back_icon
                back_icon=$(state_get BTN_PREV_ICON)
                if [ -z "$back_icon" ]; then
                    back_icon=$(icon_base_of "$cur_icon")
                fi
                gi_set icon-theme "$back_icon"
                rm -rf "$HOME/.local/share/icons/$cur_icon"
                ok "наследник со значками заголовка удалён"
                ;;
            *-Fluent-Titlebar)
                # Этот каталог создал предшественник, не мы. Возвращаем
                # базовую тему, но чужое с диска не сносим.
                gi_set icon-theme "$(icon_base_of "$cur_icon")"
                note "каталог '$cur_icon' от старого скрипта оставлен на диске"
                note "убрать при желании: rm -rf ~/.local/share/icons/$cur_icon"
                ;;
        esac
        # Правила предшественника снимает только buttons, и только спросив.
        # Откат чужое не трогает: человек мог ответить «нет» и жить с ними.
        if has_legacy_css; then
            note "правила старого look.sh остались — их снимает buttons"
        fi

        revert_gi_keys "GTK_THEME:gtk-theme" "ICON_THEME:icon-theme" \
                       "COLOR_SCHEME:color-scheme" "FONT_NAME:font-name" \
                       "MONOSPACE_FONT_NAME:monospace-font-name" \
                       "DOCUMENT_FONT_NAME:document-font-name"

        local shell_theme=$(recall SHELL_THEME)
        if [ -n "$shell_theme" ]; then
            dconf write /org/gnome/shell/extensions/user-theme/name "'$shell_theme'" 2>/dev/null
            ok "тема оболочки: $shell_theme"
        fi

        revert_terminal
        revert_panel
        revert_app
        revert_keys
        revert_serve

        if restore_backup "$CONKY_CONF" "conky-main.conf"; then
            rm -f "$CONKY_LUA"
            restart_conky
        fi

        restore_backup "$NEWTAB_LINKS" "newtab-links.txt"

        rm -f "$BEFORE"
        restart_gtk_apps
        blank
        note "обои, банк картинок и расписание не трогались"
        note "тема, собранная через theme --install, осталась в ~/.themes"
        return 0
    fi

    case "$what" in
        buttons|corners)
            css_strip "$what" "$CSS3"
            css_strip "$what" "$CSS4"
            ok "правила '$what' убраны"
            if [ "$what" = "buttons" ]; then
                local cur_icon
                cur_icon=$(gi_get icon-theme)
                case "$cur_icon" in
                    *-dk-glyphs)
                        # Возвращаем ровно то, что стояло до кнопок: у темы
                        # предшественника база не совпадает с её именем.
                        local back
                        back=$(state_get BTN_PREV_ICON)
                        if [ -z "$back" ]; then
                            back=$(icon_base_of "$cur_icon")
                        fi
                        gi_set icon-theme "$back"
                        rm -rf "$HOME/.local/share/icons/$cur_icon"
                        ok "тема значков: $back"
                        state_set BTN_PREV_ICON ""
                        ;;
                    *-Fluent-Titlebar)
                        gi_set icon-theme "$(icon_base_of "$cur_icon")"
                        ok "тема значков: $(icon_base_of "$cur_icon")"
                        note "каталог '$cur_icon' от старого скрипта не тронут"
                        ;;
                esac
            fi
            restart_gtk_apps
            ;;
        widget)
            # Конфиг conky правится целиком, маркеров в нём нет, поэтому
            # откат подменяет файл копией «до первой правки». Всё, что
            # человек дописал сам, при этом пропадёт — сохраним рядом.
            if [ -f "$CONKY_CONF" ]; then
                cp "$CONKY_CONF" "$CONKY_CONF.before-revert" 2>/dev/null
                note "текущий конфиг сохранён: $CONKY_CONF.before-revert"
            fi
            if restore_backup "$CONKY_CONF" "conky-main.conf"; then
                rm -f "$CONKY_LUA"
                restart_conky
            else
                bad "резервной копии конфига conky нет"
            fi
            ;;
        theme)
            # Только оформление окон. Значки и шрифт — свои подкоманды:
            # человек, откатывающий тему, не просил трогать остальное.
            revert_gi_keys "GTK_THEME:gtk-theme" "COLOR_SCHEME:color-scheme"
            local shell_back
            shell_back=$(recall SHELL_THEME)
            if [ -n "$shell_back" ]; then
                dconf write /org/gnome/shell/extensions/user-theme/name "'$shell_back'" 2>/dev/null
                ok "тема оболочки: $shell_back"
            fi
            restart_gtk_apps
            ;;
        icons)
            local cur_ico
            cur_ico=$(gi_get icon-theme)
            case "$cur_ico" in
                *-dk-glyphs)
                    rm -rf "$HOME/.local/share/icons/$cur_ico"
                    ok "наследник со значками заголовка удалён"
                    ;;
                *-Fluent-Titlebar)
                    note "каталог '$cur_ico' создан старым скриптом — не трогаю"
                    ;;
            esac
            revert_gi_keys "ICON_THEME:icon-theme"
            restart_gtk_apps
            ;;
        font)
            revert_gi_keys "FONT_NAME:font-name" \
                           "MONOSPACE_FONT_NAME:monospace-font-name" \
                           "DOCUMENT_FONT_NAME:document-font-name"
            restart_gtk_apps
            ;;
        terminal)
            revert_terminal
            ;;
        panel)
            revert_panel
            ;;
        app)
            revert_app
            ;;
        keys)
            revert_keys
            ;;
        serve)
            revert_serve
            ;;
        newtab)
            if restore_backup "$NEWTAB_LINKS" "newtab-links.txt"; then
                note "страницу пересобрать: $0 newtab"
            else
                bad "резервной копии списка ярлыков нет"
            fi
            ;;
        *)
            bad "revert: не знаю подсистемы '$what'"
            note "есть: buttons corners theme icons font widget terminal panel newtab"
            note "или без аргумента — откатить всё"
            return 1
            ;;
    esac
}

# =====================================================================
#  keys — горячие клавиши
# =====================================================================

help_keys() {
    cat <<'EOF'
keys — свои горячие клавиши

  desktop-kit keys                          показать все свои сочетания
  desktop-kit keys --add "Имя|Команда|Клавиши"
  desktop-kit keys --remove Имя
  desktop-kit keys --defaults               набор из этого проекта

  Клавиши пишутся в формате GNOME: <Control>q, <Super>space,
  <Control>KP_Multiply (это серая звёздочка на цифровом блоке),
  <Control>KP_Divide (серая косая черта).

  Набор --defaults:
    <Control>q               скриншот с выделением области
    <Control>KP_Multiply     следующие обои
    <Control>KP_Divide       предыдущие обои

  Занятые системой сочетания GNOME не отдаст: если ничего не произошло,
  посмотри Настройки → Клавиатура → Комбинации клавиш.
EOF
}

KEYS_ROOT="/org/gnome/settings-daemon/plugins/media-keys"
KEYS_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"

keys_list_paths() {
    gsettings get "$KEYS_SCHEMA" custom-keybindings 2>/dev/null \
        | grep -o "'[^']*'" | tr -d "'"
}

keys_show() {
    local paths
    local base
    local name
    local cmd
    local bind
    paths=$(keys_list_paths)
    if [ -z "$paths" ]; then
        note "своих сочетаний нет"
        return 0
    fi
    for p in $paths; do
        base="$KEYS_SCHEMA.custom-keybinding:$p"
        name=$(gsettings get "$base" name 2>/dev/null | tr -d "'")
        cmd=$(gsettings get "$base" command 2>/dev/null | tr -d "'")
        bind=$(gsettings get "$base" binding 2>/dev/null | tr -d "'")
        if [ -z "$bind" ]; then
            bind="(не назначено)"
        fi
        note "$bind  —  $name"
        note "        $cmd"
    done
}

keys_add() {
    local spec="$1"
    local name
    local cmd
    local bind
    local rest
    local paths
    local n
    local newpath
    local base
    local all

    case "$spec" in
        *\|*\|*) : ;;
        *) die "keys: формат \"Имя|Команда|Клавиши\"" ;;
    esac

    name="${spec%%|*}"
    rest="${spec#*|}"
    cmd="${rest%%|*}"
    bind="${rest#*|}"

    if [ -z "$name" ]; then
        die "keys: пустое имя"
    fi
    if [ -z "$cmd" ]; then
        die "keys: пустая команда"
    fi
    if [ -z "$bind" ]; then
        die "keys: пустое сочетание"
    fi

    # Повторный keys --defaults не должен плодить копии тех же сочетаний.
    local exists
    exists=""
    for p in $(keys_list_paths); do
        if [ "$(gsettings get "$KEYS_SCHEMA.custom-keybinding:$p" name 2>/dev/null | tr -d "'")" = "$name" ]; then
            exists="$p"
        fi
    done
    if [ -n "$exists" ]; then
        note "сочетание '$name' уже есть — обновляю на месте"
        if would "обновить сочетание $name"; then
            return 0
        fi
        gsettings set "$KEYS_SCHEMA.custom-keybinding:$exists" command "$cmd" 2>/dev/null
        gsettings set "$KEYS_SCHEMA.custom-keybinding:$exists" binding "$bind" 2>/dev/null
        ok "$bind — $name"
        return 0
    fi

    if would "добавить сочетание $bind -> $cmd"; then
        return 0
    fi

    # ищем свободный номер, чтобы не затереть чужое
    paths=$(keys_list_paths)
    n=0
    while true; do
        newpath="$KEYS_ROOT/custom-keybindings/custom$n/"
        if ! echo "$paths" | grep -qx "$newpath"; then
            break
        fi
        n=$((n + 1))
    done

    base="$KEYS_SCHEMA.custom-keybinding:$newpath"
    # Помним, что добавили именно мы: иначе откат не отличит наши сочетания
    # от тех, что человек завёл руками.
    local ours
    ours=$(state_get KEYS_OURS)
    state_set KEYS_OURS "$ours $newpath"
    gsettings set "$base" name "$name" 2>/dev/null
    gsettings set "$base" command "$cmd" 2>/dev/null
    gsettings set "$base" binding "$bind" 2>/dev/null

    all=""
    for p in $paths; do
        all="$all'$p', "
    done
    all="[$all'$newpath']"
    gsettings set "$KEYS_SCHEMA" custom-keybindings "$all" 2>/dev/null

    ok "$bind — $name"
}

keys_remove() {
    local target="$1"
    local paths
    local base
    local name
    local keep
    local found

    paths=$(keys_list_paths)
    keep=""
    found=0
    for p in $paths; do
        base="$KEYS_SCHEMA.custom-keybinding:$p"
        name=$(gsettings get "$base" name 2>/dev/null | tr -d "'")
        if [ "$name" = "$target" ]; then
            found=1
            continue
        fi
        keep="$keep'$p', "
    done

    if [ "$found" = "0" ]; then
        bad "сочетания с именем '$target' нет"
        keys_show
        return 1
    fi

    if would "убрать сочетание $target"; then
        return 0
    fi

    keep=$(echo "$keep" | sed 's/, $//')
    if [ -z "$keep" ]; then
        gsettings set "$KEYS_SCHEMA" custom-keybindings "[]" 2>/dev/null
    else
        gsettings set "$KEYS_SCHEMA" custom-keybindings "[$keep]" 2>/dev/null
    fi
    # Убрать путь из списка мало: значения по нему остаются в dconf и
    # всплывут, когда номер custom<N> переиспользуется.
    for p in $paths; do
        if [ "$(gsettings get "$KEYS_SCHEMA.custom-keybinding:$p" name 2>/dev/null | tr -d "'")" = "$target" ]; then
            dconf reset -f "$p" 2>/dev/null
        fi
    done
    ok "убрано: $target"
}

cmd_keys() {
    local action="show"
    local value=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --add)      need_args "--add" 2 "$#"; action="add"; value="$2"; shift 2 ;;
            --remove)   need_args "--remove" 2 "$#"; action="remove"; value="$2"; shift 2 ;;
            --defaults) action="defaults"; shift ;;
            -h|--help)  help_keys; return 0 ;;
            *) die "keys: неизвестный параметр $1" ;;
        esac
    done

    head1 "горячие клавиши"

    case "$action" in
        show)     keys_show ;;
        add)      keys_add "$value" ;;
        remove)   keys_remove "$value" ;;
        defaults)
            local kit
            kit="$BIN_DIR/desktop-kit"
            if [ ! -x "$kit" ]; then
                kit="$SELF"
            fi
            keys_add "Скриншот|flameshot gui|<Control>q"
            keys_add "Следующие обои|$kit wall|<Control>KP_Multiply"
            keys_add "Предыдущие обои|$kit wall --prev|<Control>KP_Divide"
            note "серая звёздочка и косая черта — на цифровом блоке"
            ;;
    esac
}

# =====================================================================
#  panel — Dash to Panel
# =====================================================================

help_panel() {
    cat <<'EOF'
panel — панель задач Dash to Panel

  desktop-kit panel                    показать текущие настройки
  desktop-kit panel --opacity N        прозрачность подложки 0..100
  desktop-kit panel --size N           высота панели в пикселях
  desktop-kit panel --transparent      полностью прозрачная подложка

  Прозрачность в Dash to Panel задаётся ОДНА на все мониторы: отдельной
  настройки для каждого экрана нет, сколько ни выбирай монитор в его
  собственных настройках.

  Значения сбрасываются при смене темы оболочки — это особенность
  расширения, не скрипта.
EOF
}

DTP="/org/gnome/shell/extensions/dash-to-panel"

cmd_panel() {
    local opacity=""
    local size=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --opacity)     need_args "--opacity" 2 "$#"; opacity="$2"; shift 2 ;;
            --size)        need_args "--size" 2 "$#"; size="$2"; shift 2 ;;
            --transparent) opacity=0; shift ;;
            -h|--help)     help_panel; return 0 ;;
            *) die "panel: неизвестный параметр $1" ;;
        esac
    done

    if ! have dconf; then
        die "нет dconf — настройки расширения не прочитать"
    fi

    head1 "панель задач"

    if [ -z "$opacity" ]; then
        if [ -z "$size" ]; then
            note "прозрачность: $(dconf read $DTP/trans-panel-opacity 2>/dev/null)"
            note "своя прозрачность: $(dconf read $DTP/trans-use-custom-opacity 2>/dev/null)"
            note "размеры: $(dconf read $DTP/panel-sizes 2>/dev/null)"
            return 0
        fi
    fi

    if [ -n "$opacity" ]; then
        if ! is_number "$opacity"; then
            die "panel: прозрачность — целое число 0..100"
        fi
        if [ "$opacity" -gt 100 ]; then
            die "panel: прозрачность не больше 100"
        fi
        if would "прозрачность панели $opacity%"; then
            :
        else
            local value
            value=$(awk "BEGIN{printf \"%.2f\", $opacity/100}")
            remember DTP_OPACITY "$(dconf read $DTP/trans-panel-opacity 2>/dev/null)"
            remember DTP_CUSTOM "$(dconf read $DTP/trans-use-custom-opacity 2>/dev/null)"
            dconf write $DTP/trans-use-custom-opacity true 2>/dev/null
            dconf write $DTP/trans-panel-opacity "$value" 2>/dev/null
            ok "прозрачность панели: ${opacity}%"
            note "настройка общая для всех мониторов — так устроено расширение"
        fi
    fi

    if [ -n "$size" ]; then
        if ! is_number "$size"; then
            die "panel: высота — целое число"
        fi
        if would "высота панели $size"; then
            :
        else
            local monitors
            monitors=$(dconf read $DTP/panel-sizes 2>/dev/null | tr -d "'")
            if [ -z "$monitors" ]; then
                bad "не прочитал текущие размеры панели"
            else
                remember DTP_SIZES "$monitors"
                local updated
                updated=$(echo "$monitors" | sed "s/:[0-9]\+/:$size/g")
                dconf write $DTP/panel-sizes "'$updated'" 2>/dev/null
                ok "высота панели: $size"
            fi
        fi
    fi
}

# =====================================================================
#  audit — снимок системы
# =====================================================================

cmd_audit() {
    out="${1:-$HOME/desktop-audit-$(date +%F).md}"
    local tools="$(dirname "$SELF")/tools/desktop-audit.sh"
    if [ -f "$tools" ]; then
        bash "$tools" "$out"
        return $?
    fi
    bad "не нашёл tools/desktop-audit.sh рядом со скриптом"
    note "он собирает полный снимок системы; возьми его из репозитория"
    return 1
}

# =====================================================================
#  selftest — проверка на живой машине
# =====================================================================

help_selftest() {
    cat <<'EOF'
selftest — проверить себя прямо на этой машине

  desktop-kit selftest            безопасные проверки, ничего не меняет
  desktop-kit selftest --full     плюс применение и откат каждой команды
  desktop-kit selftest --only ИМЯ прогнать одну группу
  desktop-kit selftest --list     список групп

  Безопасный режим (около 40 проверок): окружение и внешние программы,
  разбор аргументов, состояние gtk.css (симлинк, !important), банк обоев,
  разбор имён тем, наличие светлого и тёмного варианта ТЕКУЩЕЙ темы,
  доступность wallhaven и GitHub, читаемость кэша значков Chrome.

  Полный режим (около 190 проверок) прогоняет КАЖДУЮ команду и смотрит
  на результат: содержимое CSS, значения ключей, созданные файлы и юниты,
  коды возврата, тексты отказов. Занимает пару минут.

  Почему это безопасно. Подмены HOME недостаточно: gsettings и dconf
  ходят в базу пользователя через D-Bus мимо любого HOME, и прогон
  «в песочнице» менял бы живые настройки. Поэтому все внешние программы,
  которые что-то меняют — gsettings, dconf, systemctl, curl, conky,
  papirus-folders, pkill — подменяются заглушками, и скрипт видит только
  их. Ни одна настройка машины при этом не трогается, сеть не нужна.

  Группы: core buttons corners theme icons font widget terminal newtab
  wall wallpapers keys panel app serve revert help

  В конце в домашнем каталоге появляется ОДИН файл: архив
  desktop-kit-selftest.zip (или .tar.gz, если zip не установлен).
  Внутри без лишних папок: отчёт с причиной каждого провала (что
  ожидалось, что получено), список внешних программ, снимок состояния,
  обе gtk.css и лог. Никаких каталогов рядом не остаётся.

  DK_KEEP_SANDBOX=1 оставляет каталоги песочниц после прогона, если надо
  посмотреть, что именно получилось.
EOF
}

# =====================================================================
#  Каркас самопроверки: песочница с подставными внешними программами
# =====================================================================
#
# Подмены HOME НЕДОСТАТОЧНО. gsettings и dconf пишут в базу пользователя
# через D-Bus, и служба dconf была запущена с настоящим HOME — то есть
# «проверка в песочнице» меняла бы живые настройки. Хуже того: buttons
# ставит тему значков, каталог которой лежит в песочнице, а песочница
# после теста удаляется — у человека осталась бы тема, указывающая в
# никуда.
#
# Поэтому все внешние программы, которые что-то МЕНЯЮТ, подменяются
# заглушками в отдельном каталоге, и он ставится первым в PATH.

SB=""
SB_BIN=""
SB_STORE=""
SB_OUT=""
SB_RC=0

sb_write_stub() {
    local name="$1"
    local body="$2"
    printf '#!/usr/bin/env bash\n%s\n' "$body" > "$SB_BIN/$name"
    chmod +x "$SB_BIN/$name"
}

sandbox_new() {
    SB=$(mktemp -d)
    SB_BIN="$SB/stub-bin"
    SB_STORE="$SB/stub-store"
    SB_OUT="$SB/last-output.txt"
    mkdir -p "$SB_BIN" "$SB_STORE" "$SB/.config" "$SB/.local/share" \
             "$SB/.local/state" "$SB/.cache" \
             "$SB/sys/themes" "$SB/sys/icons" "$SB/sys/applications"

    # --- gsettings: ключи хранятся как "схема|ключ=значение" ----------
    sb_write_stub gsettings '
S="$DK_STUB_STORE/gsettings"
Q=$(printf "\047")
touch "$S"
if [ "$1" = "set" ]; then
    K="$2|$3"
    shift 3
    grep -v "^$K=" "$S" > "$S.t" 2>/dev/null
    mv "$S.t" "$S"
    printf "%s=%s\n" "$K" "$*" >> "$S"
    exit 0
fi
if [ "$1" = "get" ]; then
    K="$2|$3"
    V=$(grep "^$K=" "$S" | tail -1 | cut -d= -f2-)
    if [ -z "$V" ]; then
        exit 0
    fi
    case "$V" in
        \[*)        printf "%s\n" "$V" ;;
        true|false) printf "%s\n" "$V" ;;
        "$Q"*)     printf "%s\n" "$V" ;;
        *[!0-9]*)   printf "%s%s%s\n" "$Q" "$V" "$Q" ;;
        *)          printf "%s\n" "$V" ;;
    esac
    exit 0
fi
if [ "$1" = "reset" ]; then
    K="$2|$3"
    grep -v "^$K=" "$S" > "$S.t" 2>/dev/null
    mv "$S.t" "$S"
fi
exit 0'

    # --- dconf: строки "путь значение" --------------------------------
    sb_write_stub dconf '
D="$DK_STUB_STORE/dconf"
touch "$D"
if [ "$1" = "write" ]; then
    grep -v "^$2 " "$D" > "$D.t" 2>/dev/null
    mv "$D.t" "$D"
    printf "%s %s\n" "$2" "$3" >> "$D"
    exit 0
fi
if [ "$1" = "read" ]; then
    grep "^$2 " "$D" | tail -1 | cut -d" " -f2-
    exit 0
fi
if [ "$1" = "reset" ]; then
    P="$3"
    if [ "$2" != "-f" ]; then
        P="$2"
    fi
    grep -v "^$P" "$D" > "$D.t" 2>/dev/null
    mv "$D.t" "$D"
fi
exit 0'

    # --- curl: отдаёт то, что просят, никуда не ходя ------------------
    # Разбирает -o ФАЙЛ, -O, -w ФОРМАТ и URL. Значки отдаёт валидным SVG,
    # wallhaven — правдоподобным JSON, картинки — телом JPEG.
    sb_write_stub curl '
OUT=""
USE_O=0
FMT=""
URL=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o) OUT="$2"; shift 2 ;;
        -O) USE_O=1; shift ;;
        -w) FMT="$2"; shift 2 ;;
        http://*|https://*) URL="$1"; shift ;;
        *) shift ;;
    esac
done
echo "$URL" >> "$DK_STUB_STORE/curl.log"
BODY=""
case "$URL" in
    *window-*-symbolic.svg)
        BODY="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"></svg>" ;;
    *wallhaven*)
        BODY="{\"data\":[{\"path\":\"https://w.example/full/aa/wallhaven-t1.jpg\"},{\"path\":\"https://w.example/full/bb/wallhaven-t2.jpg\"},{\"path\":\"https://w.example/full/cc/wallhaven-t3.jpg\"}]}" ;;
    *.jpg|*.jpeg|*.png|*.webp)
        BODY="$(printf "\377\330\377\340JFIF-заглушка")" ;;
    http://localhost*|http://127.0.0.1*)
        BODY="ok" ;;
    *)
        BODY="ok" ;;
esac
if [ "$USE_O" = "1" ]; then
    printf "%s" "$BODY" > "$(basename "$URL")"
else
    if [ -n "$OUT" ]; then
        printf "%s" "$BODY" > "$OUT"
    else
        printf "%s" "$BODY"
    fi
fi
if [ -n "$FMT" ]; then
    printf "200"
fi
exit 0'

    # --- file: тип по расширению --------------------------------------
    sb_write_stub file '
F=""
for a in "$@"; do
    case "$a" in -*) : ;; *) F="$a" ;; esac
done
case "$F" in
    *.jpg|*.jpeg) echo "image/jpeg" ;;
    *.png)        echo "image/png" ;;
    *.webp)       echo "image/webp" ;;
    *)            echo "text/plain" ;;
esac
exit 0'

    # --- systemd: только записываем, что просили -----------------------
    sb_write_stub systemctl '
echo "$*" >> "$DK_STUB_STORE/systemctl.log"
case "$*" in
    *is-system-running*) echo running ;;
    *is-active*)         exit 3 ;;
esac
exit 0'

    sb_write_stub pgrep 'exit 1'
    sb_write_stub pkill 'exit 0'
    for prog in nautilus conky notify-send gtk-update-icon-cache \
                update-desktop-database xdg-open gnome-terminal; do
        sb_write_stub "$prog" 'exit 0'
    done
    sb_write_stub papirus-folders '
echo "$*" >> "$DK_STUB_STORE/papirus.log"
exit 0'
    sb_write_stub fc-list '
case "$*" in
    *family*)
        echo "Cantarell"
        echo "JetBrainsMono Nerd Font,JetBrainsMono NF"
        echo "Monospace"
        ;;
    *)
        echo "/usr/share/fonts/Cantarell:Cantarell:style=Regular"
        echo "/usr/share/fonts/JetBrains:JetBrainsMono Nerd Font:style=Regular"
        ;;
esac
exit 0'
    sb_write_stub git '
echo "$*" >> "$DK_STUB_STORE/git.log"
exit 0'
    sb_write_stub sassc 'exit 0'

    # --- заготовки окружения ------------------------------------------
    mkdir -p "$SB/.config/gtk-3.0" "$SB/.config/conky" "$SB/.themes" \
             "$SB/.local/share/icons" "$SB/.local/share/newtab" \
             "$SB/.local/share/applications" "$SB/Pictures/wallpapers" \
             "$SB/.cache/wal" "$SB/bin"

    printf '/* чужое правило */\nwindow { color: red; }\n' > "$SB/.config/gtk-3.0/gtk.css"
    printf "conky.config = {\n    own_window_argb_value = 225,\n    own_window_colour = '1e1e2e',\n    default_color = 'ffffff',\n}\nconky.text = [[\${time %%H:%%M}]]\n" \
        > "$SB/.config/conky/main.conf"
    printf 'Тест|https://example.com\n' > "$SB/.local/share/newtab/links.txt"

    local i
    for i in 1 2 3 4 5; do
        printf '\377\330\377\340JFIF' > "$SB/Pictures/wallpapers/w$i.jpg"
    done
    printf 'заметка автора, не картинка\n' > "$SB/Pictures/wallpapers/sources.txt"

    # темы: пара вариантов и одиночка
    local th
    for th in Graphite-Dark Graphite-Light Yaru Yaru-dark Loner-Dark \
              Graphite-Dark-Square Graphite-Light-Square; do
        mkdir -p "$SB/.themes/$th/gtk-3.0"
    done
    mkdir -p "$SB/.themes/Graphite-Light/gnome-shell"

    # темы значков
    for th in Adwaita Papirus Papirus-Dark; do
        mkdir -p "$SB/.local/share/icons/$th"
        printf '[Icon Theme]\nName=%s\n' "$th" > "$SB/.local/share/icons/$th/index.theme"
    done

    # палитра pywal
    printf "background='#101014'\nforeground='#e8e8e8'\n" > "$SB/.cache/wal/colors.sh"
    for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        printf "color%s='#1%s1%s1%s'\n" "$i" "$i" "$i" "$i" >> "$SB/.cache/wal/colors.sh"
    done

    # чужой ярлык приложения — его трогать нельзя
    printf '[Desktop Entry]\nName=Чужое\nExec=chuzhoe %%U\nType=Application\n' \
        > "$SB/.local/share/applications/chuzhoe.desktop"
    # Ярлык, который человек сделал сам (или прежний evolution-light.sh):
    # подменяет тему, но нашей метки в нём нет — удалять его нельзя.
    printf '[Desktop Entry]\nName=Своё\nExec=env GTK_THEME=Yaru mymail %%U\nType=Application\n' \
        > "$SB/.local/share/applications/chuzhoe-theme.desktop"

    # исходные значения настроек
    sb_set org.gnome.desktop.interface gtk-theme "Graphite-Dark"
    sb_set org.gnome.desktop.interface icon-theme "Adwaita"
    sb_set org.gnome.desktop.interface color-scheme "prefer-dark"
    sb_set org.gnome.desktop.interface font-name "Cantarell 11"
    sb_set org.gnome.desktop.interface monospace-font-name "Monospace 10"
    sb_set org.gnome.Terminal.ProfilesList default "b1-профиль"
    sb_set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1-профиль/" background-transparency-percent "0"
    sb_set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1-профиль/" use-system-font "true"
    sb_set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1-профиль/" font "'Monospace 12'"
    sb_set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1-профиль/" use-theme-colors "true"
    sb_set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "@as []"
}

# записать значение в хранилище заглушки напрямую
sb_set() {
    local key="$1|$2"
    shift 2
    mkdir -p "$SB_STORE"
    touch "$SB_STORE/gsettings"
    grep -v "^$key=" "$SB_STORE/gsettings" > "$SB_STORE/gsettings.t" 2>/dev/null
    mv "$SB_STORE/gsettings.t" "$SB_STORE/gsettings"
    printf '%s=%s\n' "$key" "$*" >> "$SB_STORE/gsettings"
}

# прочитать значение из хранилища заглушки
sb_get() {
    local key="$1|$2"
    if [ ! -f "$SB_STORE/gsettings" ]; then
        return 0
    fi
    grep "^$key=" "$SB_STORE/gsettings" | tail -1 | cut -d= -f2- | tr -d "'"
}

sb_dconf() {
    if [ ! -f "$SB_STORE/dconf" ]; then
        return 0
    fi
    grep "^$1 " "$SB_STORE/dconf" | tail -1 | cut -d' ' -f2- | tr -d "'"
}

# запустить скрипт внутри песочницы; вывод в $SB_OUT, код в $SB_RC
sandbox_run() {
    SB_RC=0
    env -i \
        HOME="$SB" \
        USER="${USER:-tester}" \
        PATH="$SB_BIN:/usr/local/bin:/usr/bin:/bin" \
        LANG="${LANG:-C.UTF-8}" \
        TERM="${TERM:-dumb}" \
        DK_STUB_STORE="$SB_STORE" \
        XDG_CONFIG_HOME="$SB/.config" \
        XDG_DATA_HOME="$SB/.local/share" \
        XDG_STATE_HOME="$SB/.local/state" \
        XDG_CACHE_HOME="$SB/.cache" \
        DCONF_PROFILE="$SB/dconf-profile" \
        DK_SYS_THEMES="$SB/sys/themes" \
        DK_SYS_ICONS="$SB/sys/icons" \
        DK_SYS_APPS="$SB/sys/applications" \
        DBUS_SESSION_BUS_ADDRESS="disabled:" \
        bash "$SELF" --yes "$@" > "$SB_OUT" 2>&1 < /dev/null
    SB_RC=$?
    return 0
}

# Песочница обязана быть проверена, а не предполагаться. Если заглушки
# не встали первыми в PATH, тест пошёл бы по живой системе и при этом
# отрапортовал бы об успехе.
sandbox_verify() {
    local seen
    seen=$(env -i PATH="$SB_BIN:/usr/local/bin:/usr/bin:/bin"         HOME="$SB" DK_STUB_STORE="$SB_STORE"         bash -c 'command -v gsettings')
    if [ "$seen" != "$SB_BIN/gsettings" ]; then
        t_fail "песочница не перехватывает gsettings"
        t_detail "ожидался $SB_BIN/gsettings, найден: ${seen:-ничего}"
        t_detail "дальнейшие проверки трогали бы живую систему — прерываю"
        return 1
    fi
    seen=$(env -i PATH="$SB_BIN:/usr/local/bin:/usr/bin:/bin"         HOME="$SB" DK_STUB_STORE="$SB_STORE"         bash -c 'command -v curl')
    if [ "$seen" != "$SB_BIN/curl" ]; then
        t_fail "песочница не перехватывает curl"
        t_detail "ожидался $SB_BIN/curl, найден: ${seen:-ничего}"
        return 1
    fi
    if [ ! -d "$SB" ]; then
        t_fail "каталог песочницы не создан"
        return 1
    fi
    return 0
}

# Запуск без --yes и с ответом «нет» на любой вопрос: иначе ни одна
# ветка confirm() никогда не проверяется.
sandbox_run_no() {
    SB_RC=0
    printf 'n
' | env -i         HOME="$SB"         USER="${USER:-tester}"         PATH="$SB_BIN:/usr/local/bin:/usr/bin:/bin"         LANG="${LANG:-C.UTF-8}"         TERM="${TERM:-dumb}"         DK_STUB_STORE="$SB_STORE"         XDG_CONFIG_HOME="$SB/.config"         XDG_DATA_HOME="$SB/.local/share"         XDG_STATE_HOME="$SB/.local/state"         XDG_CACHE_HOME="$SB/.cache"         DK_SYS_THEMES="$SB/sys/themes"         DK_SYS_ICONS="$SB/sys/icons"         DK_SYS_APPS="$SB/sys/applications"         bash "$SELF" "$@" > "$SB_OUT" 2>&1
    SB_RC=$?
    return 0
}

sandbox_drop() {
    if [ -n "$SB" ]; then
        # DK_KEEP_SANDBOX=1 оставляет каталог для вскрытия после провала
        if [ "${DK_KEEP_SANDBOX:-0}" = "1" ]; then
            note "песочница оставлена: $SB"
        else
            rm -rf "$SB"
        fi
    fi
    SB=""
}

# --------------------------------------------------------- утверждения

# Каждое утверждение при провале печатает, что ожидалось и что получено:
# иначе по логу с чужой машины дефект не воспроизвести.

t_eq() {
    local name="$1"
    local want="$2"
    local got="$3"
    if [ "$want" = "$got" ]; then
        t_ok "$name"
        return 0
    fi
    t_fail "$name"
    t_detail "ожидалось: [$want]"
    t_detail "получено:  [$got]"
    return 1
}

t_ne() {
    local name="$1"
    local bad_value="$2"
    local got="$3"
    if [ "$bad_value" != "$got" ]; then
        t_ok "$name"
        return 0
    fi
    t_fail "$name"
    t_detail "значение не должно было остаться: [$got]"
    return 1
}

t_has() {
    local name="$1"
    local file="$2"
    local needle="$3"
    if [ ! -f "$file" ]; then
        t_fail "$name"
        t_detail "файла нет: $file"
        return 1
    fi
    if grep -qF -- "$needle" "$file"; then
        t_ok "$name"
        return 0
    fi
    t_fail "$name"
    t_detail "в $file не найдено: [$needle]"
    t_detail "первые строки файла:"
    head -5 "$file" | sed 's/^/        /' >> "$TEST_DETAIL_FILE"
    return 1
}

t_hasnt() {
    local name="$1"
    local file="$2"
    local needle="$3"
    if [ ! -f "$file" ]; then
        t_ok "$name"
        return 0
    fi
    if grep -qF -- "$needle" "$file"; then
        t_fail "$name"
        t_detail "в $file обнаружено лишнее: [$needle]"
        grep -nF -- "$needle" "$file" | head -3 | sed 's/^/        /' >> "$TEST_DETAIL_FILE"
        return 1
    fi
    t_ok "$name"
    return 0
}

t_hasnt_out() {
    local name="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$SB_OUT"; then
        t_fail "$name"
        t_detail "в выводе есть лишнее: [$needle]"
        return 1
    fi
    t_ok "$name"
    return 0
}

t_out_has() {
    local name="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$SB_OUT"; then
        t_ok "$name"
        return 0
    fi
    t_fail "$name"
    t_detail "в выводе команды нет: [$needle]"
    t_detail "вывод был:"
    sed 's/^/        /' "$SB_OUT" | head -12 >> "$TEST_DETAIL_FILE"
    return 1
}

t_rc() {
    local name="$1"
    local want="$2"
    if [ "$SB_RC" = "$want" ]; then
        t_ok "$name"
        return 0
    fi
    t_fail "$name"
    t_detail "код возврата $SB_RC, ожидался $want"
    t_detail "вывод команды:"
    sed 's/^/        /' "$SB_OUT" | head -12 >> "$TEST_DETAIL_FILE"
    return 1
}

t_rc_not() {
    local name="$1"
    # Падение скрипта — не «правильный отказ». Отличаем по коду и по
    # характерным сообщениям самого bash.
    if [ "$SB_RC" -ge 126 ]; then
        t_fail "$name"
        t_detail "скрипт не запустился (код $SB_RC), это не отказ по проверке"
        sed 's/^/        /' "$SB_OUT" | head -6 >> "$TEST_DETAIL_FILE"
        return 1
    fi
    if grep -qE 'syntax error|unbound variable|command not found|No such file or directory' "$SB_OUT" 2>/dev/null; then
        t_fail "$name"
        t_detail "в выводе следы поломки, а не осмысленного отказа:"
        grep -nE 'syntax error|unbound variable|command not found|No such file or directory' "$SB_OUT"             | head -3 | sed 's/^/        /' >> "$TEST_DETAIL_FILE"
        return 1
    fi
    if [ "$SB_RC" != "0" ]; then
        t_ok "$name"
        return 0
    fi
    t_fail "$name"
    t_detail "команда вернула успех, а должна была отказать"
    sed 's/^/        /' "$SB_OUT" | head -12 >> "$TEST_DETAIL_FILE"
    return 1
}

t_file() {
    local name="$1"
    local file="$2"
    if [ -f "$file" ]; then
        t_ok "$name"
        return 0
    fi
    t_fail "$name"
    t_detail "файл не создан: $file"
    return 1
}

t_nofile() {
    local name="$1"
    local file="$2"
    if [ ! -e "$file" ]; then
        t_ok "$name"
        return 0
    fi
    t_fail "$name"
    t_detail "файл должен был исчезнуть: $file"
    return 1
}

TEST_PASS=0
TEST_FAIL=0
TEST_SKIP=0
TEST_LOG=""
TEST_GROUP=""
TEST_DETAIL_FILE="/dev/null"

t_group() {
    TEST_GROUP="$1"
    blank
    echo "  -- $1"
    TEST_LOG="$TEST_LOG

-- $1"
}

t_ok()   { TEST_PASS=$((TEST_PASS + 1)); echo "  OK   $*"; TEST_LOG="$TEST_LOG
OK   $*"; }
t_fail() { TEST_FAIL=$((TEST_FAIL + 1)); echo "  FAIL $*"; TEST_LOG="$TEST_LOG
FAIL $*"
    printf 'FAIL [%s] %s
' "$TEST_GROUP" "$*" >> "$TEST_DETAIL_FILE"
}
t_skip() { TEST_SKIP=$((TEST_SKIP + 1)); echo "  --   $* (пропущено)"; TEST_LOG="$TEST_LOG
SKIP $*"; }

# Подробность к упавшей проверке: без неё лог с чужой машины бесполезен —
# видно ЧТО упало, но не видно ПОЧЕМУ.
t_detail() {
    echo "       $*"
    TEST_LOG="$TEST_LOG
       $*"
    printf '       %s
' "$*" >> "$TEST_DETAIL_FILE"
}

cmd_selftest() {
    local full=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --full)    full=1; shift ;;
            --only)    need_args "--only" 2 "$#"; full=1; SELFTEST_ONLY="$2"; shift 2 ;;
            --list)    echo "$SELFTEST_GROUPS" | tr ' ' '
'; return 0 ;;
            -h|--help) help_selftest; return 0 ;;
            *) die "selftest: неизвестный параметр $1" ;;
        esac
    done

    local started=$(date '+%Y-%m-%d %H:%M:%S')
    # Отчёт собирается во временном каталоге и уезжает в архив целиком.
    # Раньше рядом с архивом оставалась ещё и папка в $HOME — лишний мусор,
    # который человек потом убирал руками.
    local report_dir
    report_dir=$(mktemp -d)
    if [ -z "$report_dir" ]; then
        die "не удалось создать временный каталог для отчёта"
    fi
    # Имя латиницей: кириллицу в именах внутри архива Windows часто
    # показывает кракозябрами. Содержимое при этом по-русски.
    TEST_DETAIL_FILE="$report_dir/failures.txt"
    : > "$TEST_DETAIL_FILE"

    head1 "самопроверка (безопасная часть)"

    # --- окружение ---
    if [ "$(uname -s)" = "Linux" ]; then
        t_ok "система Linux"
    else
        t_fail "не Linux"
    fi
    # diff нужен откату (сравнение с резервной копией), comm — разбору
    # результата сборки темы, tar — упаковке отчёта. Без них не упадёт
    # сразу, но сломается в неочевидном месте.
    for t in bash sed grep awk find curl diff comm tar cut tr; do
        if have "$t"; then
            t_ok "есть $t"
        else
            t_fail "нет $t — часть команд не сработает"
        fi
    done
    for t in jq file python3 gsettings dconf conky notify-send papirus-folders wal; do
        if have "$t"; then
            t_ok "есть $t"
        else
            t_skip "нет $t"
        fi
    done

    # --- разбор аргументов: мусор должен отвергаться ---
    if bash "$SELF" buttons --wat >/dev/null 2>&1; then
        t_fail "buttons проглотил неизвестный параметр"
    else
        t_ok "неизвестный параметр отвергается"
    fi
    if bash "$SELF" buttons --size abc def >/dev/null 2>&1; then
        t_fail "buttons принял нечисловой размер"
    else
        t_ok "нечисловой размер отвергается"
    fi
    if bash "$SELF" corners --radius abc >/dev/null 2>&1; then
        t_fail "corners принял нечисловой радиус"
    else
        t_ok "нечисловой радиус отвергается"
    fi
    if bash "$SELF" wallpapers --timer Funday 13:00 >/dev/null 2>&1; then
        t_fail "wallpapers принял несуществующий день"
    else
        t_ok "кривой день расписания отвергается"
    fi

    # --- режим проверки ничего не меняет ---
    local before_sum=""
    if [ -f "$CSS3" ]; then
        before_sum=$(md5sum "$CSS3" | cut -d' ' -f1)
    fi
    bash "$SELF" --dry-run buttons >/dev/null 2>&1 < /dev/null
    local after_sum=""
    if [ -f "$CSS3" ]; then
        after_sum=$(md5sum "$CSS3" | cut -d' ' -f1)
    fi
    if [ "$before_sum" = "$after_sum" ]; then
        t_ok "--dry-run не трогает файлы"
    else
        t_fail "--dry-run изменил gtk-3.0/gtk.css"
    fi

    # --- состояние файлов ---
    if [ -L "$CSS4" ]; then
        t_fail "~/.config/gtk-4.0/gtk.css это симлинк темы — правки уедут в тему"
    else
        t_ok "gtk-4.0/gtk.css не симлинк"
    fi
    for f in "$CSS3" "$CSS4"; do
        if grep -q '!important' "$f" 2>/dev/null; then
            t_fail "$(basename "$(dirname "$f")") содержит !important — GTK отбросит правила"
        fi
    done
    t_ok "проверка на !important выполнена"

    if has_legacy_css; then
        t_fail "в gtk.css остались правила старого look.sh"
        t_detail "они спорят с правилами desktop-kit за те же селекторы"
        t_detail "снимутся при следующем запуске buttons (спросит подтверждение)"
    else
        t_ok "правил предшественника в gtk.css нет"
    fi

    # --- разбор имён тем: чистая логика, ничего не меняет ---
    local vcase
    local vgot
    local vbad=0
    for vcase in "Graphite-Dark:dark:Graphite" \
                 "Graphite-Light:light:Graphite" \
                 "Yaru-dark:dark:Yaru" \
                 "Graphite-teal-Dark:dark:Graphite-teal" \
                 "Adwaita:unknown:Adwaita" \
                 "WhiteSur-Darker:dark:WhiteSur"; do
        local nm="${vcase%%:*}"
        local rest="${vcase#*:}"
        local want_v="${rest%%:*}"
        local want_b="${rest##*:}"
        vgot=$(theme_variant_of "$nm")
        if [ "$vgot" != "$want_v" ]; then
            t_fail "разбор '$nm': вариант '$vgot', ожидался '$want_v'"
            vbad=1
        fi
        vgot=$(theme_base_of "$nm")
        if [ "$vgot" != "$want_b" ]; then
            t_fail "разбор '$nm': база '$vgot', ожидалась '$want_b'"
            vbad=1
        fi
    done
    if [ "$vbad" = "0" ]; then
        t_ok "имена тем разбираются верно (6 случаев)"
    fi

    # --- смогу ли я переключить эту систему на светлую ---
    local cur_theme
    local cur_variant
    local pair_light
    local pair_dark
    cur_theme=$(gi_get gtk-theme)
    cur_variant=$(theme_variant_of "$cur_theme")
    pair_light=$(theme_find_variant "$cur_theme" light)
    pair_dark=$(theme_find_variant "$cur_theme" dark)
    t_ok "тема сейчас: $cur_theme (по имени — $cur_variant)"
    if [ -n "$pair_light" ]; then
        t_ok "светлый вариант есть: $pair_light  ->  $0 theme --light"
    else
        t_skip "светлого варианта нет — theme --light предложит список"
    fi
    if [ -n "$pair_dark" ]; then
        t_ok "тёмный вариант есть: $pair_dark  ->  $0 theme --dark"
    else
        t_skip "тёмного варианта нет"
    fi

    # --- справка покрывает все команды ---
    local help_out
    help_out=$(cmd_help --settings 2>/dev/null)
    if [ -n "$help_out" ]; then
        t_ok "help --settings отдаёт перечень настроек"
    else
        t_fail "help --settings пуст"
    fi

    # --- обои ---
    walldir=$(find_wallpaper_dir)
    if [ -d "$walldir" ]; then
        n=$(find "$walldir" -maxdepth 1 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\)' 2>/dev/null | wc -l)
        if [ "$n" -gt 0 ]; then
            t_ok "банк обоев: $n картинок"
        else
            t_fail "банк пуст: $walldir"
        fi
    else
        t_skip "каталога обоев нет"
    fi
    res=$(detect_resolution)
    if echo "$res" | grep -qE '^[0-9]+x[0-9]+$'; then
        t_ok "разрешение определено: $res"
    else
        t_fail "разрешение не определилось"
    fi

    # --- сеть ---
    if have curl; then
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
               "$WALLHAVEN?q=nature&categories=100&purity=100" 2>/dev/null)
        if [ "$code" = "200" ]; then
            t_ok "wallhaven отвечает"
        else
            t_skip "wallhaven недоступен (код $code) — пополнение банка не сработает"
        fi
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
               "$FLUENT_ICONS/window-close-symbolic.svg" 2>/dev/null)
        if [ "$code" = "200" ]; then
            t_ok "значки Fluent доступны"
        else
            t_skip "значки Fluent недоступны (код $code)"
        fi
    fi

    # --- кэш значков Chrome ---
    favsrc="$HOME/.config/google-chrome/Default/Favicons"
    if [ -f "$favsrc" ]; then
        if have python3; then
            n=$(python3 - "$favsrc" <<'PY' 2>/dev/null
import sys, sqlite3, shutil, tempfile, os
src = sys.argv[1]
tmp = os.path.join(tempfile.gettempdir(), 'dk-fav-test')
try:
    shutil.copy(src, tmp)
    cur = sqlite3.connect(tmp).cursor()
    print(cur.execute('SELECT count(*) FROM favicon_bitmaps').fetchone()[0])
except Exception:
    print(0)
PY
)
            if [ "${n:-0}" -gt 0 ]; then
                t_ok "кэш значков Chrome читается: $n записей"
            else
                t_fail "кэш значков Chrome не читается"
            fi
        else
            t_skip "python3 нет — кэш значков не проверить"
        fi
    else
        t_skip "профиль Chrome не найден"
    fi

    # --- новая вкладка ---
    if [ -f "$NEWTAB_LINKS" ]; then
        local broken=$(grep -v '^#' "$NEWTAB_LINKS" | grep -v '^$' | grep -vc '|')
        if [ "$broken" = "0" ]; then
            t_ok "links.txt без битых строк"
        else
            t_fail "в links.txt строк без разделителя: $broken"
        fi
    else
        t_skip "links.txt ещё нет"
    fi

    # --- systemd ---
    if have systemctl; then
        if systemctl --user is-system-running >/dev/null 2>&1; then
            t_ok "пользовательский systemd работает"
        else
            t_skip "systemd --user не отвечает — расписание не поставить"
        fi
    fi

    # --- полный режим ---
    if [ "$full" = "1" ]; then
        blank
        head1 "самопроверка (полная: применение и откат)"
        selftest_full
    fi

    # --- отчёт ---
    # Внутри этого блока пишем echo, а не blank: он формирует ФАЙЛ отчёта,
    # и в тихом режиме файл не должен становиться пустым.
    blank
    head1 "отчёт"
    local finished
    finished=$(date '+%Y-%m-%d %H:%M:%S')

    {
        echo "# Самопроверка desktop-kit"
        echo
        echo "- версия скрипта: $VERSION"
        echo "- начато:    $started"
        echo "- закончено: $finished"
        echo "- прошло:    $TEST_PASS"
        echo "- провалено: $TEST_FAIL"
        echo "- пропущено: $TEST_SKIP"
        if [ "$full" = "1" ]; then
            echo "- режим: полный (применение и откат в песочнице)"
        else
            echo "- режим: безопасный (ничего не менялось)"
        fi
        echo
        if [ "$TEST_FAIL" -gt 0 ]; then
            echo '## Что упало и почему'
            echo
            echo '```'
            cat "$TEST_DETAIL_FILE"
            echo '```'
            echo
        fi
        echo '## Все проверки по порядку'
        echo
        echo '```'
        printf '%s
' "$TEST_LOG"
        echo '```'
        echo
        echo '## Окружение'
        echo
        echo '```'
        echo "система:   $(uname -srm 2>/dev/null)"
        if [ -r /etc/os-release ]; then
            grep '^PRETTY_NAME' /etc/os-release 2>/dev/null
        fi
        echo "оболочка:  $BASH_VERSION"
        echo "локаль:    ${LANG:-не задана}"
        echo "сессия:    ${XDG_SESSION_TYPE:-неизвестно}"
        echo "рабочий стол: ${XDG_CURRENT_DESKTOP:-неизвестно}"
        echo
        echo "внешние программы:"
        local p
        for p in gsettings dconf systemctl curl jq file python3 conky                  papirus-folders wal fc-list notify-send gnome-terminal; do
            if have "$p"; then
                echo "  есть      $p"
            else
                echo "  НЕТ       $p"
            fi
        done
        echo '```'
        echo
        echo '## Состояние системы'
        echo
        echo '```'
        bash "$SELF" status 2>&1
        echo '```'
        echo
        echo '## Что менял скрипт (последние строки лога)'
        echo
        echo '```'
        tail -40 "$LOG_FILE" 2>/dev/null
        echo '```'
    } > "$report_dir/selftest.md"

    if [ -f "$LOG_FILE" ]; then
        tail -300 "$LOG_FILE" > "$report_dir/desktop-kit.log"
    fi
    for f in "$CSS3" "$CSS4"; do
        if [ -f "$f" ]; then
            cp "$f" "$report_dir/$(basename "$(dirname "$f")")-gtk.css" 2>/dev/null
        fi
    done
    if [ -f "$BEFORE" ]; then
        cp "$BEFORE" "$report_dir/before.env"
    fi
    if [ -f "$KIT_STATE" ]; then
        cp "$KIT_STATE" "$report_dir/state.env"
    fi
    if [ -f "$CONKY_CONF" ]; then
        cp "$CONKY_CONF" "$report_dir/conky-main.conf" 2>/dev/null
    fi

    # Пакуем СОДЕРЖИМОЕ, а не каталог: иначе внутри архива лишний уровень.
    # zip предпочтительнее tar.gz — браузеры на пути к получателю разжимают
    # gzip и превращают .tar.gz в .tar, из-за чего выглядит как «архив
    # внутри архива».
    local archive
    if have zip; then
        archive="$HOME/desktop-kit-selftest.zip"
        rm -f "$archive"
        ( cd "$report_dir"; zip -q -r "$archive" . )
    else
        archive="$HOME/desktop-kit-selftest.tar.gz"
        rm -f "$archive"
        tar -czf "$archive" -C "$report_dir" . 2>/dev/null
    fi

    rm -rf "$report_dir"

    ok "проверок пройдено: $TEST_PASS, провалено: $TEST_FAIL"
    ok "архив: $archive"
    note "пришли его целиком — внутри отчёт, логи, конфиги и снимок состояния"

    if [ "$TEST_FAIL" -gt 0 ]; then
        return 1
    fi
    return 0
}

SELFTEST_ONLY=""
SELFTEST_GROUPS="core buttons corners theme icons font widget terminal newtab wall wallpapers keys panel app serve revert themes refresh tune report presets help"

selftest_full() {
    note "песочница с подставными gsettings, dconf, curl и systemd"
    note "живые настройки не трогаются вообще: скрипт видит только заглушки"

    # Один раз убеждаемся, что изоляция настоящая
    sandbox_new
    if ! sandbox_verify; then
        sandbox_drop
        bad "изоляция не подтверждена — полные проверки не запускаю"
        return 1
    fi
    t_ok "изоляция подтверждена: заглушки перехватывают внешние программы"
    sandbox_drop

    local only="${SELFTEST_ONLY:-}"
    local g
    local o
    # Опечатка в имени группы раньше давала «всё прошло», не запустив
    # вообще ничего.
    for o in $only; do
        case " $SELFTEST_GROUPS " in
            *" $o "*) : ;;
            *)
                bad "нет группы проверок '$o'"
                note "есть: $SELFTEST_GROUPS"
                TEST_FAIL=$((TEST_FAIL + 1))
                return 1
                ;;
        esac
    done
    for g in $SELFTEST_GROUPS; do
        if [ -n "$only" ]; then
            case " $only " in
                *" $g "*) : ;;
                *) continue ;;
            esac
        fi
        "st_$g"
    done
}

# --------------------------------------------------------------- ядро

st_core() {
    t_group "ядро: флаги, состояние, откат файлов"
    sandbox_new

    local c3="$SB/.config/gtk-3.0/gtk.css"
    local c4="$SB/.config/gtk-4.0/gtk.css"
    local before_sum
    before_sum=$(md5sum "$c3" | cut -d' ' -f1)

    # --dry-run обязан быть read-only для КАЖДОЙ команды, а не только там,
    # где об этом вспомнили
    local cmd
    for cmd in "buttons" "corners --radius 4" "theme Graphite-Light" \
               "icons Papirus" "font Cantarell 12" "widget --radius 4" \
               "newtab" "wall" "keys --defaults"; do
        sandbox_run --dry-run $cmd
    done
    t_eq "--dry-run не тронул gtk-3.0/gtk.css" "$before_sum" "$(md5sum "$c3" | cut -d' ' -f1)"
    t_nofile "--dry-run не создал gtk-4.0/gtk.css" "$c4"
    t_eq "--dry-run не тронул тему окон" "Graphite-Dark" "$(sb_get org.gnome.desktop.interface gtk-theme)"
    t_eq "--dry-run не тронул тему значков" "Adwaita" "$(sb_get org.gnome.desktop.interface icon-theme)"
    t_eq "--dry-run не тронул шрифт" "Cantarell 11" "$(sb_get org.gnome.desktop.interface font-name)"
    t_nofile "--dry-run не создал снимок исходных значений"         "$SB/.local/state/desktop-kit/before.env"
    t_nofile "--dry-run не создал резервных копий" "$SB/.local/state/desktop-kit/backups"
    t_nofile "--dry-run не создал страницу новой вкладки" "$SB/.local/share/newtab/index.html"

    # кривые аргументы должны отвергаться, а не проглатываться
    sandbox_run buttons --size
    t_rc_not "buttons --size без значений отвергнут"
    sandbox_run buttons --size abc def
    t_rc_not "buttons: нечисловой размер отвергнут"
    sandbox_run corners --radius -5x
    t_rc_not "corners: мусорный радиус отвергнут"
    sandbox_run widget --radius abc
    t_rc_not "widget: нечисловой радиус отвергнут"
    sandbox_run panel --opacity 300
    t_rc_not "panel: прозрачность больше 100 отвергнута"
    sandbox_run terminal --opacity 200
    t_rc_not "terminal: прозрачность больше 100 отвергнута"
    sandbox_run nosuchcommand
    t_rc_not "неизвестная команда отвергнута"
    sandbox_run buttons --нетакогофлага
    t_rc_not "неизвестный флаг отвергнут"

    # значения со спецсимволами должны переживать запись и чтение состояния
    sb_set org.gnome.desktop.interface font-name "Ubuntu Nerd Font Propo 11"
    sandbox_run font "Cantarell 13"
    sandbox_run revert font
    t_eq "шрифт с пробелами вернулся дословно" \
        "Ubuntu Nerd Font Propo 11" "$(sb_get org.gnome.desktop.interface font-name)"

    # Все пути строятся от HOME. Пустой или корневой HOME — прямой путь
    # к записи и удалению файлов в /.
    local guard_out
    guard_out=$(env -i PATH="/usr/local/bin:/usr/bin:/bin" bash "$SELF" status 2>&1)
    case "$guard_out" in
        *"HOME пуста"*) t_ok "пустой HOME отвергается" ;;
        *) t_fail "пустой HOME не отвергнут"; t_detail "вывод: $(printf '%s' "$guard_out" | head -2)" ;;
    esac
    guard_out=$(env -i HOME=/ PATH="/usr/local/bin:/usr/bin:/bin" bash "$SELF" status 2>&1)
    case "$guard_out" in
        *"HOME=/"*) t_ok "HOME=/ отвергается" ;;
        *) t_fail "HOME=/ не отвергнут"; t_detail "вывод: $(printf '%s' "$guard_out" | head -2)" ;;
    esac

    # Вопрос, заданный без терминала, однажды подвесил прогон намертво:
    # приглашение ушло в /dev/null, а read ждал ответа.
    printf '/* look-begin */
button { min-width: 46px; }
/* look-end */
'         > "$SB/.config/gtk-3.0/gtk.css"
    local hang_rc=0
    timeout 30 env -i HOME="$SB" USER="${USER:-tester}"         PATH="$SB_BIN:/usr/local/bin:/usr/bin:/bin" LANG="${LANG:-C.UTF-8}"         DK_STUB_STORE="$SB_STORE" DK_SYS_THEMES="$SB/sys/themes"         DK_SYS_ICONS="$SB/sys/icons" DK_SYS_APPS="$SB/sys/applications"         bash "$SELF" buttons --glyphs keep > "$SB_OUT" 2>&1 < /dev/null
    hang_rc=$?
    if [ "$hang_rc" = "124" ]; then
        t_fail "команда зависла на вопросе без терминала"
        t_detail "так прогон и вставал: приглашение не видно, ввода нет"
    else
        t_ok "вопрос без терминала не подвешивает команду"
    fi
    t_out_has "сказано, что спросить некого" "задать некому"
    # вернуть чистый файл, иначе следующая проверка увидит наши правила
    printf '/* чужое правило */
window { color: red; }
' > "$SB/.config/gtk-3.0/gtk.css"

    # лог обязан вестись
    t_file "лог пишется" "$SB/.local/state/desktop-kit/desktop-kit.log"
    t_has "в логе видны запуски" "$SB/.local/state/desktop-kit/desktop-kit.log" "запуск:"

    # --quiet глушит обычный вывод, но не ошибки. Предыдущая проверка
    # оставила в gtk.css блок предшественника, а про него status обязан
    # ругаться даже в тихом режиме — сначала возвращаем чистый файл.
    printf '/* чужое правило */\nwindow { color: red; }\n' > "$SB/.config/gtk-3.0/gtk.css"
    sandbox_run --quiet status
    if [ -s "$SB_OUT" ]; then
        t_fail "--quiet: status всё равно печатает"
        t_detail "вывод: $(head -3 "$SB_OUT" | tr '\n' ' ')"
    else
        t_ok "--quiet: обычный вывод подавлен"
    fi

    # А вот ошибку тихий режим глушить не имеет права
    printf '/* look-begin */\nbutton { min-width: 1px; }\n/* look-end */\n' \
        >> "$SB/.config/gtk-3.0/gtk.css"
    sandbox_run --quiet status
    t_out_has "--quiet не скрывает предупреждения" "look.sh"

    sandbox_drop
}

# ------------------------------------------------------------ buttons

st_buttons() {
    t_group "buttons: кнопки заголовка"
    sandbox_new

    local c3="$SB/.config/gtk-3.0/gtk.css"
    local c4="$SB/.config/gtk-4.0/gtk.css"

    # --glyphs keep не должен ни ходить в сеть, ни трогать тему значков
    sandbox_run buttons --glyphs keep
    t_eq "с --glyphs keep тема значков не тронута" "Adwaita"         "$(sb_get org.gnome.desktop.interface icon-theme)"
    if [ -f "$SB_STORE/curl.log" ]; then
        t_fail "с --glyphs keep всё равно была попытка скачивания"
    else
        t_ok "с --glyphs keep обошлось без сети"
    fi

    sandbox_run buttons --size 40 30 --icon 18 --radius 0 --close "#ff0000"
    t_rc "команда отработала" 0
    t_has "блок для GTK3 записан" "$c3" "dk:buttons-begin"
    t_has "блок для GTK4 записан" "$c4" "dk:buttons-begin"
    t_has "ширина кнопки применилась" "$c4" "min-width: 40px"
    t_has "высота кнопки применилась" "$c4" "min-height: 30px"
    t_has "размер значка применился" "$c4" "-gtk-icon-size: 18px"
    t_has "цвет закрытия применился" "$c4" "#ff0000"

    # главные грабли проекта — они не должны вернуться
    t_hasnt "нет !important (GTK выбрасывает такое правило целиком)" "$c4" "!important"
    t_hasnt "нет !important в GTK3" "$c3" "!important"
    t_has "круг гасится на image, а не на кнопке" "$c4" "windowcontrols > button > image"
    t_hasnt "в GTK3 нет свойства -gtk-icon-size (его там не существует)" "$c3" "-gtk-icon-size:"

    # чужие правила обязаны уцелеть
    t_has "чужое правило в gtk.css уцелело" "$c3" "чужое правило"

    # тема значков: наследник поверх текущей
    t_eq "тема значков стала наследником" "Adwaita-dk-glyphs" \
        "$(sb_get org.gnome.desktop.interface icon-theme)"
    t_file "каталог наследника создан" "$SB/.local/share/icons/Adwaita-dk-glyphs/index.theme"
    t_has "наследник наследует базу" "$SB/.local/share/icons/Adwaita-dk-glyphs/index.theme" "Inherits=Adwaita"
    t_file "значок закрытия на месте" \
        "$SB/.local/share/icons/Adwaita-dk-glyphs/symbolic/actions/window-close-symbolic.svg"

    # повторный запуск не должен плодить блоки
    sandbox_run buttons --size 46 34
    local n
    n=$(grep -c 'dk:buttons-begin' "$c4")
    t_eq "повторный запуск не удвоил блок" "1" "$n"
    t_has "новый размер применился" "$c4" "min-width: 46px"
    t_hasnt "старый размер убран" "$c4" "min-width: 40px"

    # база наследника не должна накручиваться сама на себя
    sandbox_run buttons
    t_eq "наследник не наслоился сам на себя" "Adwaita-dk-glyphs" \
        "$(sb_get org.gnome.desktop.interface icon-theme)"
    t_nofile "нет двойного наследника" "$SB/.local/share/icons/Adwaita-dk-glyphs-dk-glyphs"

    # Минимальный режим для тем, рисующих кнопки самостоятельно
    sandbox_drop
    sandbox_new
    sandbox_run buttons --glyphs keep --hover none
    t_rc "минимальный режим отработал" 0
    t_has "размер кнопки задан" "$SB/.config/gtk-4.0/gtk.css" "min-width: 46px"
    t_hasnt "фон кнопки не тронут" "$SB/.config/gtk-4.0/gtk.css" "background-image: none"
    t_hasnt "своей подсветки нет" "$SB/.config/gtk-4.0/gtk.css" "alpha(currentColor"
    t_eq "тема значков не подменялась" "Adwaita"         "$(sb_get org.gnome.desktop.interface icon-theme)"

    # правила предшественника не должны сосуществовать с нашими
    sandbox_drop
    sandbox_new
    printf '/* чужое правило */\nwindow { color: red; }\n/* look-begin */\nbutton.titlebutton { min-width: 46px; }\n/* look-end */\n' \
        > "$SB/.config/gtk-3.0/gtk.css"
    sandbox_run buttons
    t_hasnt "блок старого look.sh убран" "$SB/.config/gtk-3.0/gtk.css" "look-begin"
    t_has "чужое правило при этом уцелело" "$SB/.config/gtk-3.0/gtk.css" "чужое правило"
    t_has "наш блок записан" "$SB/.config/gtk-3.0/gtk.css" "dk:buttons-begin"
    t_out_has "про старые правила сказано вслух" "look.sh"

    # Ответ «нет» должен уважаться: правила остаются на месте.
    sandbox_drop
    sandbox_new
    printf '/* look-begin */
button.titlebutton { min-width: 46px; }
/* look-end */
'         > "$SB/.config/gtk-3.0/gtk.css"
    sandbox_run_no buttons --glyphs keep
    t_has "на ответ «нет» правила предшественника остались"         "$SB/.config/gtk-3.0/gtk.css" "look-begin"

    # Непарный маркер: вырезать нельзя, файл съело бы до конца.
    sandbox_drop
    sandbox_new
    printf '/* look-begin */
button { min-width: 46px; }
window { color: red; }
'         > "$SB/.config/gtk-3.0/gtk.css"
    sandbox_run buttons --glyphs keep
    t_has "при непарном маркере файл не тронут"         "$SB/.config/gtk-3.0/gtk.css" "window { color: red; }"
    t_out_has "сказано про непарные маркеры" "не парные"

    # тема значков от предшественника тоже должна распознаваться
    sandbox_drop
    sandbox_new
    mkdir -p "$SB/.local/share/icons/Papirus-Dark-Fluent-Titlebar"
    printf '[Icon Theme]\nName=x\n' > "$SB/.local/share/icons/Papirus-Dark-Fluent-Titlebar/index.theme"
    sb_set org.gnome.desktop.interface icon-theme "Papirus-Dark-Fluent-Titlebar"
    sandbox_run revert buttons
    t_eq "наследник предшественника снят до базы" "Papirus-Dark" \
        "$(sb_get org.gnome.desktop.interface icon-theme)"
    t_file "чужой каталог значков не удалён" \
        "$SB/.local/share/icons/Papirus-Dark-Fluent-Titlebar/index.theme"

    # Полный цикл: тема предшественника -> buttons -> revert. Вернуться
    # должно ТОЧНОЕ прежнее имя, а не база, вычисленная из наследника.
    sandbox_drop
    sandbox_new
    mkdir -p "$SB/.local/share/icons/Papirus-Dark-Fluent-Titlebar"
    printf '[Icon Theme]\nName=x\n' > "$SB/.local/share/icons/Papirus-Dark-Fluent-Titlebar/index.theme"
    sb_set org.gnome.desktop.interface icon-theme "Papirus-Dark-Fluent-Titlebar"
    sandbox_run buttons
    # Наследуем от НАСТОЯЩЕЙ темы, а не от наследника предшественника:
    # иначе цепочка наследования росла бы с каждым переходом.
    t_eq "наследник построен от настоящей базы" "Papirus-Dark-dk-glyphs" \
        "$(sb_get org.gnome.desktop.interface icon-theme)"
    sandbox_run revert buttons
    t_eq "откат вернул ТОЧНОЕ прежнее имя" "Papirus-Dark-Fluent-Titlebar" \
        "$(sb_get org.gnome.desktop.interface icon-theme)"

    # gtk-4.0/gtk.css как симлинк в тему — ссылку надо снять
    sandbox_drop
    sandbox_new
    mkdir -p "$SB/.themes/Graphite-Dark/gtk-4.0" "$SB/.config/gtk-4.0"
    printf '/* внутри темы */\n' > "$SB/.themes/Graphite-Dark/gtk-4.0/gtk.css"
    ln -sf "$SB/.themes/Graphite-Dark/gtk-4.0/gtk.css" "$SB/.config/gtk-4.0/gtk.css"
    sandbox_run buttons
    if [ -L "$SB/.config/gtk-4.0/gtk.css" ]; then
        t_fail "симлинк gtk-4.0 не снят — правки уедут внутрь темы"
    else
        t_ok "симлинк gtk-4.0 снят перед записью"
    fi
    t_hasnt "внутрь темы ничего не записано" "$SB/.themes/Graphite-Dark/gtk-4.0/gtk.css" "dk:buttons"

    sandbox_drop
}

# ------------------------------------------------------------ corners

st_corners() {
    t_group "corners: скругление окон"
    sandbox_new

    local c4="$SB/.config/gtk-4.0/gtk.css"

    sandbox_run buttons
    sandbox_run corners --radius 8
    t_has "радиус применился" "$c4" "border-radius: 8px"
    t_has "блок кнопок уцелел" "$c4" "dk:buttons-begin"
    t_has "блок углов записан" "$c4" "dk:corners-begin"

    sandbox_run corners --square
    t_has "острые углы: радиус 0" "$c4" "border-radius: 0px"
    t_eq "блок углов остался один" "1" "$(grep -c 'dk:corners-begin' "$c4")"
    t_has "блок кнопок пережил повтор" "$c4" "dk:buttons-begin"

    # снятие одного блока не должно задевать другой
    sandbox_run revert corners
    t_hasnt "блок углов снят" "$c4" "dk:corners-begin"
    t_has "блок кнопок на месте" "$c4" "dk:buttons-begin"

    sandbox_drop
}

# -------------------------------------------------------------- theme

st_theme() {
    t_group "theme: тема окон и переключение варианта"
    sandbox_new

    # разбор имён — чистая логика, без запуска команд
    local vcase nm rest want_v want_b got
    local vbad=0
    for vcase in "Graphite-Dark:dark:Graphite" "Graphite-Light:light:Graphite" \
                 "Yaru-dark:dark:Yaru" "Graphite-teal-Dark:dark:Graphite-teal" \
                 "WhiteSur-Darker:dark:WhiteSur" "Adwaita:unknown:Adwaita" \
                 "Graphite-Dark-Square:dark:Graphite-Square" \
                 "Colloid-Dark-Catppuccin:dark:Colloid-Catppuccin"; do
        nm="${vcase%%:*}"
        rest="${vcase#*:}"
        want_v="${rest%%:*}"
        want_b="${rest##*:}"
        got=$(theme_variant_of "$nm")
        if [ "$got" != "$want_v" ]; then
            t_fail "разбор '$nm': вариант"
            t_detail "ожидалось [$want_v], получено [$got]"
            vbad=1
        fi
        got=$(theme_base_of "$nm")
        if [ "$got" != "$want_b" ]; then
            t_fail "разбор '$nm': база"
            t_detail "ожидалось [$want_b], получено [$got]"
            vbad=1
        fi
    done
    if [ "$vbad" = "0" ]; then
        t_ok "имена тем разбираются верно (8 форм)"
    fi

    # Краевые имена не должны валить разбор: пустое приходит, когда
    # gsettings молчит, а одно слово-вариант — это тема с именем "Dark".
    local edge_bad=0
    local e
    for e in "" "-" "Dark" "Тема-Тёмная" "a b-Dark"; do
        if ! theme_variant_of "$e" >/dev/null 2>&1; then
            t_fail "разбор имени '$e' завершился ошибкой"
            edge_bad=1
        fi
        if ! theme_base_of "$e" >/dev/null 2>&1; then
            t_fail "выделение базы из '$e' завершилось ошибкой"
            edge_bad=1
        fi
    done
    if [ "$edge_bad" = "0" ]; then
        t_ok "краевые имена тем не валят разбор (5 случаев)"
    fi
    if theme_exists ""; then
        t_fail "пустое имя считается существующей темой"
    else
        t_ok "пустое имя темой не считается"
    fi

    # Вариант в середине имени — это не выдумка: ровно так называются темы
    # vinceliuice, и на живой машине переключатель предлагал САМУ ЖЕ тёмную
    # тему как светлую.
    sb_set org.gnome.desktop.interface gtk-theme "Graphite-Dark-Square"
    sandbox_run theme --light
    t_eq "вариант в середине имени: Dark-Square -> Light-Square" \
        "Graphite-Light-Square" "$(sb_get org.gnome.desktop.interface gtk-theme)"
    sandbox_run theme --dark
    t_eq "и обратно" "Graphite-Dark-Square" \
        "$(sb_get org.gnome.desktop.interface gtk-theme)"

    # Стоковая Ubuntu: тема Yaru, тёмная — Yaru-dark. Слова варианта в
    # имени нет, и на этом theme --light раньше отказывал на СВЕЖЕЙ системе.
    sb_set org.gnome.desktop.interface gtk-theme "Yaru"
    sb_set org.gnome.desktop.interface color-scheme "prefer-dark"
    sandbox_run theme --light
    t_rc "стоковая Yaru: команда отработала" 0
    t_eq "тема осталась Yaru" "Yaru" "$(sb_get org.gnome.desktop.interface gtk-theme)"
    t_eq "схема стала светлой" "prefer-light"         "$(sb_get org.gnome.desktop.interface color-scheme)"
    sandbox_run theme --dark
    t_eq "и обратно в Yaru-dark" "Yaru-dark"         "$(sb_get org.gnome.desktop.interface gtk-theme)"

    # слово варианта в имени есть, а пары нет — нельзя выдавать саму себя
    sb_set org.gnome.desktop.interface gtk-theme "Loner-Dark"
    sandbox_run theme --light
    t_rc_not "не выдаёт тёмную тему за светлый вариант"
    t_eq "тема осталась тёмной" "Loner-Dark" \
        "$(sb_get org.gnome.desktop.interface gtk-theme)"

    # вернуть исходное состояние для следующих проверок
    sb_set org.gnome.desktop.interface gtk-theme "Graphite-Dark"
    sb_set org.gnome.desktop.interface color-scheme "prefer-dark"

    # переключение на светлую без знания имени
    sandbox_run theme --light
    t_rc "переключение прошло" 0
    t_eq "Graphite-Dark стала Graphite-Light" "Graphite-Light" \
        "$(sb_get org.gnome.desktop.interface gtk-theme)"
    t_eq "схема пошла следом" "prefer-light" \
        "$(sb_get org.gnome.desktop.interface color-scheme)"
    t_eq "тема значков не тронута" "Adwaita" \
        "$(sb_get org.gnome.desktop.interface icon-theme)"
    t_out_has "сказано, что значки не менялись" "тема значков не менялась"
    t_eq "тема оболочки поставлена" "Graphite-Light" \
        "$(sb_dconf /org/gnome/shell/extensions/user-theme/name)"

    # и обратно
    sandbox_run theme --dark
    t_eq "обратно в тёмную" "Graphite-Dark" \
        "$(sb_get org.gnome.desktop.interface gtk-theme)"

    # светлый вариант без суффикса
    sb_set org.gnome.desktop.interface gtk-theme "Yaru-dark"
    sandbox_run theme --light
    t_eq "Yaru-dark стала Yaru" "Yaru" "$(sb_get org.gnome.desktop.interface gtk-theme)"

    # пары нет — не менять НИЧЕГО
    sb_set org.gnome.desktop.interface gtk-theme "Loner-Dark"
    sb_set org.gnome.desktop.interface color-scheme "prefer-dark"
    sandbox_run theme --light
    t_rc_not "без пары команда отказывает"
    t_eq "тема не тронута" "Loner-Dark" "$(sb_get org.gnome.desktop.interface gtk-theme)"
    t_eq "схема не тронута — рассинхрона нет" "prefer-dark" \
        "$(sb_get org.gnome.desktop.interface color-scheme)"
    t_out_has "предложен --scheme-only" "scheme-only"
    t_out_has "показан список светлых тем" "Graphite-Light"

    # --scheme-only меняет только схему
    sandbox_run theme --light --scheme-only
    t_eq "схема сменилась" "prefer-light" "$(sb_get org.gnome.desktop.interface color-scheme)"
    t_eq "тема осталась" "Loner-Dark" "$(sb_get org.gnome.desktop.interface gtk-theme)"

    # имя темы — данные, а не регулярка
    sandbox_run theme "Graphite.Light"
    t_rc_not "имя с точкой не считается совпадением"
    t_ne "в настройки не уехало несуществующее имя" "Graphite.Light"         "$(sb_get org.gnome.desktop.interface gtk-theme)"

    # несуществующая тема
    sandbox_run theme НетТакойТемы
    t_rc_not "несуществующая тема отвергнута"
    t_out_has "показан список доступных" "Graphite-Dark"

    # регистр имени
    sandbox_run theme graphite-light
    t_eq "имя в другом регистре принято" "Graphite-Light" \
        "$(sb_get org.gnome.desktop.interface gtk-theme)"

    sandbox_drop
}

# -------------------------------------------------------------- icons

st_icons() {
    t_group "icons: тема значков"
    sandbox_new

    sandbox_run icons Papirus
    t_eq "тема значков сменилась" "Papirus" "$(sb_get org.gnome.desktop.interface icon-theme)"

    sandbox_run icons НетТакойТемы
    t_rc_not "несуществующая тема значков отвергнута"
    t_eq "при отказе тема не менялась" "Papirus" \
        "$(sb_get org.gnome.desktop.interface icon-theme)"

    # значки заголовка не должны осиротеть при смене базовой темы
    sandbox_run buttons
    t_eq "наследник поверх Papirus" "Papirus-dk-glyphs" \
        "$(sb_get org.gnome.desktop.interface icon-theme)"
    sandbox_run icons Papirus-Dark
    t_eq "наследник пересобран поверх новой темы" "Papirus-Dark-dk-glyphs" \
        "$(sb_get org.gnome.desktop.interface icon-theme)"
    t_has "наследник наследует новую базу" \
        "$SB/.local/share/icons/Papirus-Dark-dk-glyphs/index.theme" "Inherits=Papirus-Dark"
    t_out_has "про пересборку сказано вслух" "пересобираю"

    # цвет папок только для Papirus
    sb_set org.gnome.desktop.interface icon-theme "Adwaita"
    sandbox_run icons --folders blue
    t_rc_not "перекраска не-Papirus отвергнута"
    t_out_has "объяснено почему" "Papirus"

    sandbox_drop
}

# --------------------------------------------------------------- font

st_font() {
    t_group "font: шрифты интерфейса"
    sandbox_new

    sandbox_run font "Cantarell 13"
    t_eq "шрифт применился" "Cantarell 13" "$(sb_get org.gnome.desktop.interface font-name)"

    sandbox_run font "НетТакогоШрифта 12"
    t_rc_not "несуществующий шрифт отвергнут"
    t_eq "при отказе шрифт не менялся" "Cantarell 13" \
        "$(sb_get org.gnome.desktop.interface font-name)"

    # подстрока имени не должна сходить за шрифт
    sandbox_run font "Cantarel 12"
    t_rc_not "обрезанное имя шрифта отвергнуто"
    t_ne "обрезанное имя не применилось" "Cantarel 12"         "$(sb_get org.gnome.desktop.interface font-name)"

    sandbox_run font --mono "JetBrainsMono Nerd Font 12"
    t_eq "моноширинный применился" "JetBrainsMono Nerd Font 12" \
        "$(sb_get org.gnome.desktop.interface monospace-font-name)"

    # повторная смена не должна затирать запомненное исходное
    sandbox_run font "Cantarell 14"
    sandbox_run revert font
    t_eq "откат вернул ПЕРВОЕ значение, а не предыдущее" "Cantarell 11" \
        "$(sb_get org.gnome.desktop.interface font-name)"

    sandbox_drop
}

# ------------------------------------------------------------- widget

st_widget() {
    t_group "widget: виджет conky"
    sandbox_new

    local conf="$SB/.config/conky/main.conf"
    local lua="$SB/.config/conky/desktop-kit-bg.lua"

    sandbox_run widget --radius 14
    t_file "lua-файл подложки создан" "$lua"
    t_has "радиус попал в lua" "$lua" "local RADIUS = 14"
    t_has "конфиг подключил lua" "$conf" "lua_load"
    t_has "конфиг вызывает отрисовку" "$conf" "lua_draw_hook_pre"
    t_has "своё окно стало прозрачным" "$conf" "own_window_argb_value = 0"

    # повторный запуск не должен плодить строки
    sandbox_run widget --radius 10
    t_eq "lua_load не задвоился" "1" "$(grep -c 'lua_load' "$conf")"
    t_eq "хук отрисовки не задвоился" "1" "$(grep -c 'lua_draw_hook_pre' "$conf")"
    t_has "новый радиус применился" "$lua" "local RADIUS = 10"

    # плотность: должна помниться ПОСЛЕДНЯЯ заданная, а не первая
    sandbox_run widget --opacity 200
    sandbox_run widget --opacity 120
    sandbox_run widget --radius 6
    t_has "взята последняя плотность" "$lua" "0.471"

    # контраст
    sandbox_run widget --colour f2f2f2
    t_out_has "предупреждение о белом на белом" "не виден"
    sandbox_run widget --light
    t_has "--light поставил тёмный текст" "$conf" "default_color = '1e1e2e'"
    sandbox_run widget --dark
    t_has "--dark вернул светлый текст" "$conf" "default_color = 'ffffff'"

    # нет конфига — внятный отказ
    rm -f "$conf"
    sandbox_run widget
    t_rc_not "без конфига conky команда отказывает"
    t_out_has "путь к конфигу назван" "conky"

    sandbox_drop
}

# ----------------------------------------------------------- terminal

st_terminal() {
    t_group "terminal: GNOME Terminal"
    sandbox_new

    local prof="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1-профиль/"

    sandbox_run terminal --opacity 15
    t_eq "прозрачность применилась" "15" "$(sb_get "$prof" background-transparency-percent)"
    t_eq "прозрачный фон включён" "true" "$(sb_get "$prof" use-transparent-background)"

    sandbox_run terminal --font "JetBrainsMono Nerd Font 12"
    t_eq "шрифт применился" "JetBrainsMono Nerd Font 12" "$(sb_get "$prof" font)"
    t_eq "системный шрифт отключён" "false" "$(sb_get "$prof" use-system-font)"

    sandbox_run terminal --palette wal
    t_eq "своя палитра включена" "false" "$(sb_get "$prof" use-theme-colors)"
    t_eq "фон из палитры" "#101014" "$(sb_get "$prof" background-color)"

    # откат должен вернуть ВСЕ ключи, а не часть
    sandbox_run revert terminal
    t_eq "прозрачность вернулась" "0" "$(sb_get "$prof" background-transparency-percent)"
    t_eq "системный шрифт вернулся" "true" "$(sb_get "$prof" use-system-font)"
    t_eq "цвета темы вернулись" "true" "$(sb_get "$prof" use-theme-colors)"

    sandbox_drop
}

# ------------------------------------------------------------- newtab

st_newtab() {
    t_group "newtab: страница новой вкладки"
    sandbox_new

    local page="$SB/.local/share/newtab/index.html"
    local links="$SB/.local/share/newtab/links.txt"

    if ! have python3; then
        t_skip "newtab: нет python3 — значки из Chrome не проверить"
    fi
    sandbox_run newtab
    t_file "страница собрана" "$page"
    t_has "ярлык из списка попал на страницу" "$page" "Тест"
    t_hasnt "в JavaScript не утекло слово local" "$page" "local idx"
    t_has "страница закрыта тегом" "$page" "</html>"

    # ярлыки со спецсимволами — самое хрупкое место генератора
    sandbox_run newtab --add 'Кавычка"и&амперсанд|https://example.com/?a=1&b=2'
    t_rc "ярлык со спецсимволами принят" 0
    sandbox_run newtab
    t_has "спецсимволы не сломали страницу" "$page" "</html>"
    t_has "амперсанд в адресе экранирован" "$page" "a=1&amp;"

    # удаление по имени с точкой не должно снести соседа
    sandbox_run newtab --add 'A.B|https://ab.example'
    sandbox_run newtab --add 'AXB|https://axb.example'
    sandbox_run newtab --remove 'A.B'
    t_hasnt "нужный ярлык удалён" "$links" "A.B|"
    t_has "сосед по маске уцелел" "$links" "AXB|"

    # дубль не добавляется
    sandbox_run newtab --add 'AXB|https://other.example'
    t_rc_not "дубль имени отвергнут"

    # список
    sandbox_run newtab --list
    t_out_has "список показывает ярлык" "AXB"

    sandbox_drop
}

# --------------------------------------------------------------- wall

st_wall() {
    t_group "wall: смена обоев по порядку"
    sandbox_new

    sandbox_run wall --set "$SB/Pictures/wallpapers/w1.jpg"
    t_eq "обои поставлены" "file://$SB/Pictures/wallpapers/w1.jpg" \
        "$(sb_get org.gnome.desktop.background picture-uri)"
    t_eq "экран блокировки тоже" "file://$SB/Pictures/wallpapers/w1.jpg" \
        "$(sb_get org.gnome.desktop.screensaver picture-uri)"

    sandbox_run wall
    t_eq "следующая по порядку" "file://$SB/Pictures/wallpapers/w2.jpg" \
        "$(sb_get org.gnome.desktop.background picture-uri)"
    sandbox_run wall
    t_eq "и ещё одна" "file://$SB/Pictures/wallpapers/w3.jpg" \
        "$(sb_get org.gnome.desktop.background picture-uri)"
    sandbox_run wall --prev
    t_eq "назад по порядку" "file://$SB/Pictures/wallpapers/w2.jpg" \
        "$(sb_get org.gnome.desktop.background picture-uri)"

    # конец списка заворачивается в начало
    sandbox_run wall --set "$SB/Pictures/wallpapers/w5.jpg"
    sandbox_run wall
    t_eq "с последней перешли на первую" "file://$SB/Pictures/wallpapers/w1.jpg" \
        "$(sb_get org.gnome.desktop.background picture-uri)"

    sandbox_run wall --show
    t_out_has "показан номер в списке" "w1.jpg"

    sandbox_drop
}

# --------------------------------------------------------- wallpapers

st_wallpapers() {
    t_group "wallpapers: банк картинок"
    sandbox_new

    if ! have jq; then
        t_skip "wallpapers: нет jq"
        sandbox_drop
        return 0
    fi

    sandbox_run wallpapers --count 3
    t_out_has "докачка отчиталась" "банке"
    t_file "картинка скачалась" "$SB/Pictures/wallpapers/wallhaven-t1.jpg"

    # чистка не должна трогать чужие файлы
    t_file "чужой файл в каталоге уцелел" "$SB/Pictures/wallpapers/sources.txt"

    # расписание
    sandbox_run wallpapers --timer Wed 13:00
    t_file "юнит таймера создан" "$SB/.config/systemd/user/desktop-kit-wallpapers.timer"
    t_file "юнит службы создан" "$SB/.config/systemd/user/desktop-kit-wallpapers.service"
    t_has "день и время попали в юнит" \
        "$SB/.config/systemd/user/desktop-kit-wallpapers.timer" "Wed 13:00"
    t_has "пропуск догоняется" \
        "$SB/.config/systemd/user/desktop-kit-wallpapers.timer" "Persistent=true"
    t_file "скрипт скопирован в ~/bin" "$SB/bin/desktop-kit"

    sandbox_run wallpapers --timer Funday 13:00
    t_rc_not "несуществующий день отвергнут"

    # чистка банка
    sandbox_run wallpapers --prune 2
    t_file "чужой файл пережил чистку" "$SB/Pictures/wallpapers/sources.txt"
    local left
    left=$(find "$SB/Pictures/wallpapers" -maxdepth 1 -type f -name '*.jpg' | wc -l)
    t_eq "в банке осталось сколько просили" "2" "$left"

    sandbox_drop
}

# --------------------------------------------------------------- keys

st_keys() {
    t_group "keys: горячие клавиши"
    sandbox_new

    # чужое сочетание, заведённое человеком до нас
    sb_set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
    sb_set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/" name "Чужое"

    sandbox_run keys --add "Скриншот|flameshot gui|<Control>q"
    t_rc "сочетание добавлено" 0
    local list
    list=$(sb_get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
    case "$list" in
        *custom0*) t_ok "чужое сочетание в списке уцелело" ;;
        *) t_fail "чужое сочетание пропало из списка"; t_detail "список: $list" ;;
    esac
    case "$list" in
        *custom1*) t_ok "своё сочетание добавлено рядом" ;;
        *) t_fail "своё сочетание не добавилось"; t_detail "список: $list" ;;
    esac

    # повторный запуск не должен плодить копии
    sandbox_run keys --add "Скриншот|flameshot gui|<Control>q"
    list=$(sb_get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
    local n
    n=$(printf '%s' "$list" | grep -o 'custom-keybindings/custom' | wc -l)
    t_eq "повтор не создал третьего пути" "2" "$n"

    # снятие своего
    sandbox_run keys --remove "Скриншот"
    list=$(sb_get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
    case "$list" in
        *custom0*) t_ok "после удаления чужое на месте" ;;
        *) t_fail "удаление своего снесло чужое"; t_detail "список: $list" ;;
    esac

    sandbox_run keys --remove "НетТакого"
    t_rc_not "удаление несуществующего отвергнуто"

    sandbox_drop
}

# -------------------------------------------------------------- panel

st_panel() {
    t_group "panel: панель задач"
    sandbox_new

    printf "/org/gnome/shell/extensions/dash-to-panel/panel-sizes '{\"0\":48}'\n" \
        > "$SB_STORE/dconf"

    sandbox_run panel --opacity 0
    t_eq "своя прозрачность включена" "true" \
        "$(sb_dconf /org/gnome/shell/extensions/dash-to-panel/trans-use-custom-opacity)"
    t_eq "прозрачность выставлена" "0.00" \
        "$(sb_dconf /org/gnome/shell/extensions/dash-to-panel/trans-panel-opacity)"

    sandbox_run panel --size 40
    t_has "высота панели поменялась" "$SB_STORE/dconf" "40"

    sandbox_run panel --opacity 300
    t_rc_not "прозрачность больше 100 отвергнута"

    sandbox_run revert panel
    t_eq "размеры панели вернулись" '{"0":48}' \
        "$(sb_dconf /org/gnome/shell/extensions/dash-to-panel/panel-sizes)"

    sandbox_drop
}

# ---------------------------------------------------------------- app

st_app() {
    t_group "app: своя тема для приложения"
    sandbox_new

    mkdir -p "$SB/usr-applications"
    printf '[Desktop Entry]\nName=Почта\nExec=evolution %%U\nType=Application\nActions=compose\n\n[Desktop Action compose]\nExec=evolution mailto:\n' \
        > "$SB/usr-applications/evolution.desktop"

    # чужой ярлык нельзя сносить
    sandbox_run app chuzhoe --reset
    t_file "чужой ярлык не удалён" "$SB/.local/share/applications/chuzhoe.desktop"
    t_rc_not "удаление чужого ярлыка отвергнуто"

    sandbox_drop
}

# -------------------------------------------------------------- serve

st_serve() {
    t_group "serve: локальная апка по http"
    sandbox_new

    mkdir -p "$SB/apka"
    printf '<html></html>' > "$SB/apka/index.html"

    sandbox_run serve "$SB/apka" --port 8099
    t_file "юнит службы создан" "$SB/.config/systemd/user/desktop-kit-serve-apka.service"
    t_has "порт попал в юнит" "$SB/.config/systemd/user/desktop-kit-serve-apka.service" "8099"
    t_has "слушает только петлевой адрес" \
        "$SB/.config/systemd/user/desktop-kit-serve-apka.service" "127.0.0.1"

    sandbox_run revert serve
    t_nofile "юнит снят откатом" "$SB/.config/systemd/user/desktop-kit-serve-apka.service"

    sandbox_drop
}

# ------------------------------------------------------------- revert

st_revert() {
    t_group "revert: обратимость"
    sandbox_new

    local c3="$SB/.config/gtk-3.0/gtk.css"
    local conf="$SB/.config/conky/main.conf"

    sandbox_run buttons
    sandbox_run corners --radius 8
    sandbox_run theme Graphite-Light
    sandbox_run icons Papirus
    sandbox_run font "Cantarell 13"
    sandbox_run widget --radius 12
    sandbox_run terminal --opacity 20

    # правка, сделанная человеком ПОСЛЕ установки, обязана уцелеть
    printf '/* правка после установки */\n' >> "$c3"

    sandbox_run revert all
    t_hasnt "наши блоки убраны" "$c3" "dk:buttons-begin"
    t_has "чужое правило уцелело" "$c3" "чужое правило"
    t_has "поздняя правка уцелела" "$c3" "правка после установки"
    # Ярлык с подменой темы, сделанный не нами, откат сносить не имеет права.
    t_file "чужой ярлык с GTK_THEME уцелел" \
        "$SB/.local/share/applications/chuzhoe-theme.desktop"
    t_eq "тема окон вернулась" "Graphite-Dark" \
        "$(sb_get org.gnome.desktop.interface gtk-theme)"
    t_eq "тема значков вернулась" "Adwaita" \
        "$(sb_get org.gnome.desktop.interface icon-theme)"
    t_eq "шрифт вернулся" "Cantarell 11" \
        "$(sb_get org.gnome.desktop.interface font-name)"
    t_has "конфиг conky вернулся" "$conf" "own_window_argb_value = 225"
    t_nofile "lua подложки удалён" "$SB/.config/conky/desktop-kit-bg.lua"
    t_file "обои не тронуты откатом" "$SB/Pictures/wallpapers/w1.jpg"
    t_nofile "снимок исходных значений убран" "$SB/.local/state/desktop-kit/before.env"

    # когда поздних правок не было — файл восстанавливается целиком
    sandbox_drop
    sandbox_new
    sandbox_run buttons
    sandbox_run revert all
    local c3b="$SB/.config/gtk-3.0/gtk.css"
    t_eq "файл вернулся дословно" \
        "$(printf '/* чужое правило */\nwindow { color: red; }')" \
        "$(cat "$c3b")"

    # неизвестная подсистема
    sandbox_run revert нетакой
    t_rc_not "неизвестная подсистема отвергнута"
    t_out_has "перечислены доступные" "terminal"

    sandbox_run revert --list
    t_rc "revert --list работает" 0

    sandbox_drop
}

st_themes() {
    t_group "themes: банк готовых тем"
    sandbox_new

    sandbox_run themes
    t_rc "список банка выводится" 0
    t_out_has "в списке есть Graphite" "Graphite"
    t_out_has "в списке есть Qogir" "Qogir"

    sandbox_run themes --install НетТакойТемы
    t_rc_not "тема вне банка отвергается"
    t_out_has "сказано, где смотреть список" "themes"

    # Совместимость определяется по исходникам темы, а не по названию.
    mkdir -p "$SB/.themes/Хорошая/gtk-3.0" "$SB/.themes/Плохая/gtk-3.0"
    printf 'button.titlebutton { min-width: 24px; }
'         > "$SB/.themes/Хорошая/gtk-3.0/gtk.css"
    printf 'button.titlebutton.close { background-image: url("c.png"); }
'         > "$SB/.themes/Плохая/gtk-3.0/gtk.css"

    sandbox_run themes --check Хорошая
    t_rc "совместимая тема проходит проверку" 0
    t_out_has "сказано, что кнопки отданы значкам" "отданы теме значков"

    sandbox_run themes --check Плохая
    t_rc_not "тема со своими кнопками не проходит"
    t_out_has "предложен минимальный режим" "hover none"

    # Нет ни одного gtk.css — проверять нечего, и это не «совместима»
    mkdir -p "$SB/.themes/Пустая"
    sandbox_run themes --check Пустая
    t_rc_not "тема без gtk.css не объявляется совместимой"
    t_out_has "объяснено, что проверять нечего" "проверять нечего"

    sandbox_run themes --check НетНаДиске
    t_rc_not "отсутствующая тема отвергается"

    sandbox_drop
}

# ------------------------------------------------- согласованность справки

st_refresh() {
    t_group "refresh: возврат своих правил"
    sandbox_new

    # Пустое состояние — это «ещё не настраивали», а не «правила снесли»
    sandbox_run refresh
    t_rc "на чистой системе возврат не ошибка" 0
    t_out_has "сказано, что настраивать нечего" "ещё не настраивались"
    t_hasnt_out "нет ложной тревоги про установщик" "снёс установщик темы"

    sandbox_run buttons --size 44 32 --icon 19 --glyphs keep
    sandbox_run corners --radius 6
    t_has "аргументы кнопок запомнены"         "$SB/.local/state/desktop-kit/state.env" "BTN_ARGS"
    t_has "аргументы углов запомнены"         "$SB/.local/state/desktop-kit/state.env" "CORNERS_ARGS"

    # Установщики тем перезаписывают этот файл целиком — воспроизводим
    rm -f "$SB/.config/gtk-4.0/gtk.css"
    printf '/* правила темы */
window { background: blue; }
'         > "$SB/.config/gtk-4.0/gtk.css"

    sandbox_run refresh
    t_rc "возврат отработал" 0
    t_has "блок кнопок вернулся" "$SB/.config/gtk-4.0/gtk.css" "dk:buttons-begin"
    t_has "с прежним размером" "$SB/.config/gtk-4.0/gtk.css" "min-width: 44px"
    t_has "блок углов вернулся" "$SB/.config/gtk-4.0/gtk.css" "border-radius: 6px"
    t_has "правила темы не затёрты" "$SB/.config/gtk-4.0/gtk.css" "правила темы"

    sandbox_run refresh
    t_out_has "второй раз возвращать нечего" "возвращать нечего"

    # Симлинк в тему снимается: иначе наши правки уехали бы внутрь темы
    mkdir -p "$SB/.themes/Тема/gtk-4.0"
    printf '/* внутри темы */
' > "$SB/.themes/Тема/gtk-4.0/gtk.css"
    rm -f "$SB/.config/gtk-4.0/gtk.css"
    ln -sf "$SB/.themes/Тема/gtk-4.0/gtk.css" "$SB/.config/gtk-4.0/gtk.css"
    sandbox_run refresh
    if [ -L "$SB/.config/gtk-4.0/gtk.css" ]; then
        t_fail "симлинк в тему остался"
    else
        t_ok "симлинк в тему снят"
    fi
    t_hasnt "внутрь темы ничего не записано"         "$SB/.themes/Тема/gtk-4.0/gtk.css" "dk:buttons"

    sandbox_drop
}

st_tune() {
    t_group "tune: настройка вопросами"
    sandbox_new

    # Без терминала мастер обязан отказаться, а не повиснуть на read
    sandbox_run tune corners
    t_rc_not "без терминала мастер отказывается"
    t_out_has "объяснено, почему" "нет терминала"

    # Дальше подаём ответы, притворившись терминалом
    tune_run() {
        printf '%s' "$1" | env -i             HOME="$SB" USER="${USER:-tester}"             PATH="$SB_BIN:/usr/local/bin:/usr/bin:/bin"             LANG="${LANG:-C.UTF-8}" TERM="${TERM:-dumb}"             DK_STUB_STORE="$SB_STORE" DK_ASK_FORCE=1             XDG_CONFIG_HOME="$SB/.config" XDG_DATA_HOME="$SB/.local/share"             XDG_STATE_HOME="$SB/.local/state" XDG_CACHE_HOME="$SB/.cache"             DK_SYS_THEMES="$SB/sys/themes" DK_SYS_ICONS="$SB/sys/icons"             DK_SYS_APPS="$SB/sys/applications"             bash "$SELF" "$2" "$3" > "$SB_OUT" 2>&1
        SB_RC=$?
    }

    # выбор по номеру: третий вариант — радиус 12
    tune_run '3
' tune corners
    t_has "выбранный радиус применился" "$SB/.config/gtk-4.0/gtk.css" "border-radius: 12px"
    t_out_has "показана команда-эквивалент" "corners --radius 12"

    # пустой ответ ничего не меняет
    tune_run '
' tune corners
    t_has "пустой ответ оставил как было" "$SB/.config/gtk-4.0/gtk.css" "border-radius: 12px"

    # своё значение вместо номера
    tune_run '7
' tune corners
    t_has "принято своё значение" "$SB/.config/gtk-4.0/gtk.css" "border-radius: 7px"

    # кнопки: ширина, высота, значок, форма, цвет, вопрос про тему
    tune_run '50

22
1
2
n
' tune buttons
    t_has "ширина кнопки из ответа" "$SB/.config/gtk-4.0/gtk.css" "min-width: 50px"
    t_has "высота осталась прежней" "$SB/.config/gtk-4.0/gtk.css" "min-height: 34px"
    t_has "цвет закрытия из списка" "$SB/.config/gtk-4.0/gtk.css" "c42b1c"
    t_out_has "команда-эквивалент для кнопок" "buttons --size 50 34"

    # ответ «тема рисует сама» переводит в минимальный режим
    tune_run '46
34
20
1
1
y
' tune buttons
    t_hasnt "в минимальном режиме фон не трогается"         "$SB/.config/gtk-4.0/gtk.css" "background-image: none"

    # Мастер вызывает команды изнутри: раньше в память уезжали аргументы
    # внешней команды, и в BTN_ARGS попадало слово "buttons".
    tune_run '52
36
21
1
1
n
' tune buttons
    t_has "запомнены аргументы кнопок, а не слово tune"         "$SB/.local/state/desktop-kit/state.env" "--size 52 36"
    t_hasnt "слово buttons в память не попало"         "$SB/.local/state/desktop-kit/state.env" "BTN_ARGS='buttons'"

    # и они должны быть применимы: refresh не имеет права падать
    rm -f "$SB/.config/gtk-4.0/gtk.css"
    printf '/* тема */
' > "$SB/.config/gtk-4.0/gtk.css"
    sandbox_run refresh
    t_rc "возврат после мастера отработал" 0
    t_has "размер из мастера вернулся" "$SB/.config/gtk-4.0/gtk.css" "min-width: 52px"

    sandbox_run tune нетакого
    t_rc_not "неизвестный раздел отвергается"
    t_out_has "перечислены разделы" "corners"

    sandbox_drop
}

st_report() {
    t_group "отчёт: один файл, без лишних папок"
    sandbox_new

    sandbox_run selftest
    # Рядом с архивом не должно оставаться распакованного каталога:
    # человек его потом убирает руками.
    t_nofile "каталог отчёта не остался" "$SB/desktop-kit-selftest"

    local arc=""
    if [ -f "$SB/desktop-kit-selftest.zip" ]; then
        arc="$SB/desktop-kit-selftest.zip"
    fi
    if [ -f "$SB/desktop-kit-selftest.tar.gz" ]; then
        arc="$SB/desktop-kit-selftest.tar.gz"
    fi
    if [ -z "$arc" ]; then
        t_fail "архив с отчётом не создан"
        sandbox_drop
        return 0
    fi
    t_ok "архив создан: $(basename "$arc")"

    # Внутри — файлы, а не папка с файлами и не вложенный архив
    local inside
    case "$arc" in
        *.tar.gz) inside=$(tar -tzf "$arc" 2>/dev/null) ;;
        *)        inside=$(unzip -Z1 "$arc" 2>/dev/null) ;;
    esac
    case "$inside" in
        *selftest.md*) t_ok "отчёт внутри архива" ;;
        *) t_fail "в архиве нет selftest.md"; t_detail "содержимое: $(printf '%s' "$inside" | tr '
' ' ')" ;;
    esac
    case "$inside" in
        *desktop-kit-selftest/*)
            t_fail "внутри архива лишняя папка"
            t_detail "содержимое: $(printf '%s' "$inside" | tr '
' ' ')"
            ;;
        *) t_ok "лишней папки внутри нет" ;;
    esac
    case "$inside" in
        *.tar*|*.zip*|*.gz*)
            t_fail "внутри архива лежит ещё один архив"
            t_detail "содержимое: $(printf '%s' "$inside" | tr '
' ' ')"
            ;;
        *) t_ok "вложенных архивов нет" ;;
    esac

    sandbox_drop
}

st_presets() {
    t_group "наборы: имя вместо флагов"
    sandbox_new

    sandbox_run buttons thin --glyphs keep
    t_rc "набор thin отработал" 0
    t_has "размер из набора применился" "$SB/.config/gtk-4.0/gtk.css" "min-width: 46px"
    t_out_has "сказано, какой набор развернулся" "набор 'thin'"

    sandbox_run buttons default --glyphs keep
    t_has "набор default даёт другой размер" "$SB/.config/gtk-4.0/gtk.css" "min-width: 32px"

    # Флаг после имени набора должен перекрывать его значение
    sandbox_run buttons thin --icon 26 --glyphs keep
    t_has "флаг после набора перекрыл его" "$SB/.config/gtk-4.0/gtk.css" "-gtk-icon-size: 26px"

    sandbox_run corners sharp
    t_has "corners sharp даёт прямые углы" "$SB/.config/gtk-4.0/gtk.css" "border-radius: 0px"
    sandbox_run corners round
    t_has "corners round даёт скругление" "$SB/.config/gtk-4.0/gtk.css" "border-radius: 12px"

    sandbox_run widget light
    t_has "widget light ставит тёмный текст" "$SB/.config/conky/main.conf" "default_color = '1e1e2e'"

    # Имя, которого нет, не должно молча проглатываться
    sandbox_run buttons нетакогонабора
    t_rc_not "неизвестное имя набора отвергается"

    # Наборы обязаны быть видны там, где человек их будет искать
    sandbox_run help buttons
    t_out_has "наборы перечислены в справке команды" "thin"
    sandbox_run help corners
    t_out_has "и у corners тоже" "sharp"

    sandbox_drop
}

st_help() {
    t_group "справка: покрытие всех команд"
    sandbox_new

    local all_cmds="buttons corners theme icons font widget terminal newtab"
    all_cmds="$all_cmds wallpapers wall serve app keys panel audit status selftest revert"

    local c
    local missing=""
    for c in $all_cmds; do
        sandbox_run help "$c"
        if [ ! -s "$SB_OUT" ]; then
            missing="$missing $c"
            continue
        fi
        if grep -q "нет справки" "$SB_OUT"; then
            missing="$missing $c"
        fi
    done
    if [ -z "$missing" ]; then
        t_ok "у каждой команды есть справка ($(echo $all_cmds | wc -w) шт.)"
    else
        t_fail "команды без справки:$missing"
    fi

    sandbox_run help --settings
    local k
    local nosettings=""
    for k in gtk-theme icon-theme color-scheme font-name picture-uri palette \
             panel-sizes custom-keybindings gtk-3.0 conky newtab systemd; do
        if ! grep -qF -- "$k" "$SB_OUT"; then
            nosettings="$nosettings $k"
        fi
    done
    if [ -z "$nosettings" ]; then
        t_ok "help --settings перечисляет все группы настроек"
    else
        t_fail "в help --settings не хватает:$nosettings"
    fi

    sandbox_run help --all
    local lines
    lines=$(wc -l < "$SB_OUT")
    if [ "$lines" -gt 200 ]; then
        t_ok "help --all печатает всю справку ($lines строк)"
    else
        t_fail "help --all подозрительно короткий: $lines строк"
    fi

    sandbox_drop
}
# =====================================================================
#  help и диспетчер
# =====================================================================

usage() {
    cat <<EOF
desktop-kit $VERSION — настройка десктопа Ubuntu 24.04 / GNOME 46

  $0 <команда> [параметры]

ВНЕШНИЙ ВИД
  tune         настроить вопросами: показывает варианты и спрашивает
  buttons      кнопки заголовка: размер, значки, подсветка
                 $(presets_names buttons)
  corners      скругление углов окон
                 $(presets_names corners)
  refresh      вернуть свои правила, если их снесла установка темы
  theme        тема оформления, цветовая схема
  themes       банк готовых тем: список и установка
  icons        тема значков, цвет папок
  font         шрифт интерфейса и моноширинный
  widget       виджет conky: скругление, цвет, плотность
                 $(presets_names widget)
  terminal     GNOME Terminal: прозрачность, шрифт, палитра
                 $(presets_names terminal)

  Слово после команды — готовый набор параметров: buttons thin,
  corners sharp. Флаги после него перекрывают: buttons thin --icon 24.
  Что делает каждый набор: $0 help buttons

СОДЕРЖИМОЕ
  newtab       страница новой вкладки Chrome и её ярлыки
                 $(presets_names newtab)
  wallpapers   банк обоев: пополнение, расписание, чистка
  wall         сменить обои: следующие, предыдущие, случайные
  serve        отдать локальную апку по http://localhost

ПРОЧЕЕ
  keys         горячие клавиши
  panel        панель задач: прозрачность, высота
  app          своя тема для одного приложения
  audit        полный снимок системы в markdown
  status       что сейчас применено
  selftest     проверить себя на этой машине и собрать архив
  revert       вернуть как было

ГЛОБАЛЬНЫЕ ПАРАМЕТРЫ
  --dry-run    рассказать, что было бы сделано, ничего не меняя
  --yes        не переспрашивать
  --quiet      без вывода, только лог

  $0 help <команда>   подробности и все параметры
  $0 help --all       ВСЯ справка разом, по всем командам
  $0 help --settings  полный перечень изменяемых настроек

Лог всех действий: $LOG_FILE
EOF
}

help_settings() {
    cat <<'EOF'
Полный перечень того, что этот скрипт может изменить.
Слева — команда, справа — конкретная настройка или файл.

НАСТРОЙКИ GNOME (gsettings org.gnome.desktop.interface)
  theme        gtk-theme                  тема окон
  theme        color-scheme               светлая/тёмная схема
  icons        icon-theme                 тема значков
  buttons      icon-theme                 подменяет на своего наследника
  font         font-name                  шрифт интерфейса
  font         monospace-font-name        моноширинный
  font         document-font-name         шрифт документов

НАСТРОЙКИ ЧЕРЕЗ DCONF
  theme        /org/gnome/shell/extensions/user-theme/name     тема оболочки
  panel        /org/gnome/shell/extensions/dash-to-panel/
                 trans-use-custom-opacity, trans-panel-opacity, panel-sizes
  keys         /org/gnome/settings-daemon/plugins/media-keys/
                 custom-keybindings и по одному пути на каждое сочетание

ОБОИ
  wall         org.gnome.desktop.background picture-uri
  wall         org.gnome.desktop.background picture-uri-dark
  wall         org.gnome.desktop.background picture-options = zoom
  wall         org.gnome.desktop.screensaver picture-uri      экран блокировки

ПРОФИЛЬ GNOME TERMINAL (профиль по умолчанию)
  terminal     use-transparent-background, background-transparency-percent
  terminal     use-system-font, font
  terminal     use-theme-colors, background-color, foreground-color, palette
  wall         те же цвета — при смене обоев палитра идёт следом

ФАЙЛЫ
  buttons      ~/.config/gtk-3.0/gtk.css      блок dk:buttons
  buttons      ~/.config/gtk-4.0/gtk.css      блок dk:buttons
  corners      те же два файла                блок dk:corners
  buttons      ~/.local/share/icons/<база>-dk-glyphs/   тема-наследник
  icons        сама тема Papirus на диске     цвет папок (--folders)
  widget       ~/.config/conky/main.conf      подложка, цвет текста, lua
  widget       ~/.config/conky/desktop-kit-bg.lua       отрисовка подложки
  newtab       ~/.local/share/newtab/index.html, links.txt, icons.json
  wallpapers   каталог обоев                  докачка и чистка
  app          ~/.local/share/applications/<app>.desktop  (с меткой авторства)
  (любая)      ~/bin/desktop-kit              копия себя для расписания

СЛУЖБЫ SYSTEMD (пользовательские, каталог ~/.config/systemd/user)
  wallpapers   desktop-kit-wallpapers.service и .timer
  serve        desktop-kit-serve-<имя>.service   постоянный, с автозапуском

СЛУЖЕБНОЕ (можно удалять руками)
  ~/.local/state/desktop-kit/before.env    как было до нас, основа отката
  ~/.local/state/desktop-kit/state.env     наши последние настройки
  ~/.local/state/desktop-kit/backups/      копии файлов до первой правки
  ~/.local/state/desktop-kit/desktop-kit.log   лог всех действий
  ~/.cache/desktop-kit/themes/             исходники собранных тем

ЧЕГО СКРИПТ НЕ ДЕЛАЕТ
  не ставит пакеты через apt, не трогает /etc, не меняет настройки входа,
  не работает с сетью кроме wallhaven, GitHub и wttr.in.

ТРЕБУЕТ ВНЕШНИХ ПРОГРАММ
  buttons      curl                значки Fluent качаются с GitHub
  icons        papirus-folders     только для --folders
  theme        git, sassc          только для --install
  widget       conky с поддержкой lua и cairo
  terminal     pywal               только для --palette wal
  newtab       python3             для значков из кэша Chrome
  wallpapers   curl, jq, file
  audit        python3
EOF
}

cmd_help() {
    local topic="${1:-}"
    case "$topic" in
        --settings|settings) help_settings; return 0 ;;
        --all|all)
            local topics="buttons corners theme icons font widget terminal"
            topics="$topics newtab wallpapers wall serve app keys panel"
            topics="$topics selftest revert"
            usage
            local one
            for one in $topics; do
                echo
                echo "============================================================"
                cmd_help "$one"
            done
            echo
            echo "============================================================"
            help_settings
            return 0
            ;;
        buttons)    help_buttons ;;
        corners)    help_corners ;;
        theme)      help_theme ;;
        icons)      help_icons ;;
        font)       help_font ;;
        widget)     help_widget ;;
        terminal)   help_terminal ;;
        newtab)     help_newtab ;;
        wallpapers) help_wallpapers ;;
        wall)       help_wall ;;
        app)        help_app ;;
        themes)     help_themes ;;
        refresh)    help_refresh ;;
        tune)       help_tune ;;
        keys)       help_keys ;;
        panel)      help_panel ;;
        serve)      help_serve ;;
        selftest)   help_selftest ;;
        audit)      echo "audit — полный снимок системы в markdown"
                    echo
                    echo "  desktop-kit audit [ФАЙЛ]"
                    echo
                    echo "  Собирает версии программ, темы, расширения GNOME с их"
                    echo "  настройками, горячие клавиши, конфиги Tabby и Chrome,"
                    echo "  банк обоев, таймеры и автозапуск. Ничего не меняет."
                    echo "  Пароли и ключи заменяются на <скрыто>."
                    ;;
        status)     echo "status — что сейчас применено"
                    echo
                    echo "  desktop-kit status"
                    echo
                    echo "  Показывает темы, шрифты, какие блоки правил лежат в"
                    echo "  gtk.css, состояние банка обоев и расписания, и что"
                    echo "  запомнено для отката. Ничего не меняет."
                    ;;
        revert)     help_revert ;;
        "")         usage ;;
        *)          echo "нет справки по '$topic'"; usage; return 1 ;;
    esac
}

# глобальные флаги можно ставить где угодно
ARGS=""
for a in "$@"; do
    case "$a" in
        --dry-run) DRY_RUN=1 ;;
        --yes)     ASSUME_YES=1 ;;
        --quiet)   QUIET=1 ;;
        *) ARGS="$ARGS
$a" ;;
    esac
done

set --
while IFS= read -r a; do
    if [ -n "$a" ]; then
        set -- "$@" "$a"
    fi
done <<EOF
$ARGS
EOF

COMMAND="${1:-}"
if [ $# -gt 0 ]; then
    shift
fi
# Аргументы команды — чтобы подсистемы могли запомнить, чем их применяли
DK_CMD_ARGS="$*"

log "запуск: $COMMAND $*"

case "$COMMAND" in
    buttons)    cmd_buttons "$@" ;;
    corners)    cmd_corners "$@" ;;
    theme)      cmd_theme "$@" ;;
    icons)      cmd_icons "$@" ;;
    font)       cmd_font "$@" ;;
    widget)     cmd_widget "$@" ;;
    terminal)   cmd_terminal "$@" ;;
    newtab)     cmd_newtab "$@" ;;
    wallpapers) cmd_wallpapers "$@" ;;
    wall)       cmd_wall "$@" ;;
    app)        cmd_app "$@" ;;
    serve)      cmd_serve "$@" ;;
    themes)     cmd_themes "$@" ;;
    refresh)    cmd_refresh "$@" ;;
    tune)       cmd_tune "$@" ;;
    keys)       cmd_keys "$@" ;;
    panel)      cmd_panel "$@" ;;
    audit)      cmd_audit "$@" ;;
    status)     cmd_status "$@" ;;
    selftest)   cmd_selftest "$@" ;;
    revert)     cmd_revert "$@" ;;
    help|-h|--help) cmd_help "$@" ;;
    version|--version|-V) echo "desktop-kit $VERSION" ;;
    "")         usage ;;
    *)
        echo "неизвестная команда: $COMMAND"
        blank
        usage
        exit 1
        ;;
esac
