#!/usr/bin/env bash
# Обои по порядку — как листание стрелками на странице новой вкладки.
#
#   setwall            следующая по списку
#   setwall prev       предыдущая по списку
#   setwall random     случайная
#   setwall current    какая стоит сейчас и её номер
#   setwall set ФАЙЛ   поставить конкретную
#   setwall help
#
# Список — все картинки каталога, отсортированные по имени. Позиция
# запоминается ИМЕНЕМ файла, а не номером: банк пополняется каждую
# неделю, и номер бы съезжал при появлении новых картинок.
#
# Заодно обновляет палитру pywal, перекрашивает GNOME Terminal под
# текущую картинку и пересобирает страницу новой вкладки.

set -uo pipefail

STATE="$HOME/.local/state"
CUR_FILE="$STATE/wallpaper-current"

usage() {
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

find_walldir() {
    for d in "$HOME/Pictures/wallpapers-uw" "$HOME/Изображения/wallpapers-uw" \
             "$HOME/Pictures/wallpapers" "$HOME/Изображения/wallpapers"; do
        if [ -d "$d" ]; then
            echo "$d"
            return
        fi
    done
    echo "$HOME/Pictures/wallpapers-uw"
}

WALLDIR=$(find_walldir)

# отсортированный список — он и задаёт порядок листания
list_images() {
    find "$WALLDIR" -maxdepth 1 -type f \
        -iregex '.*\.\(jpg\|jpeg\|png\|webp\)' 2>/dev/null | sort
}

# какая картинка стоит сейчас: сперва наше состояние, иначе спросим GNOME
current_path() {
    if [ -s "$CUR_FILE" ]; then
        C=$(cat "$CUR_FILE")
        if [ -f "$C" ]; then
            echo "$C"
            return
        fi
    fi
    G=$(gsettings get org.gnome.desktop.background picture-uri-dark 2>/dev/null \
        | tr -d "'" | sed 's#^file://##')
    if [ -f "$G" ]; then
        echo "$G"
    fi
}

apply() {
    F="$1"
    mkdir -p "$STATE"
    echo "$F" > "$CUR_FILE"

    gsettings set org.gnome.desktop.background picture-uri "file://$F"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$F"
    gsettings set org.gnome.desktop.background picture-options 'zoom'
    gsettings set org.gnome.desktop.screensaver picture-uri "file://$F"

    # палитра под картинку
    if command -v wal >/dev/null 2>&1; then
        wal -i "$F" -n -q >/dev/null 2>&1
        recolor_terminal
    fi

    # у страницы новой вкладки свой фон, и он не должен совпадать
    # с тем, что стоит на рабочем столе — пересобираем в фоне
    if [ -x "$HOME/bin/newtab" ]; then
        ( "$HOME/bin/newtab" >/dev/null 2>&1 & )
    fi
}

# цвета GNOME Terminal из свежей палитры pywal
recolor_terminal() {
    COLORS="$HOME/.cache/wal/colors.sh"
    if [ ! -f "$COLORS" ]; then
        return
    fi
    # в colors.sh есть строки вида $FZF_DEFAULT_OPTS — под set -u они
    # роняют скрипт, поэтому проверку на время подключения снимаем
    set +u
    . "$COLORS"
    set -u

    PROF=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    if [ -z "$PROF" ]; then
        return
    fi
    P="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROF/"

    PALETTE="['$color0', '$color1', '$color2', '$color3', '$color4', '$color5', \
'$color6', '$color7', '$color8', '$color9', '$color10', '$color11', '$color12', \
'$color13', '$color14', '$color15']"

    gsettings set "$P" use-theme-colors false 2>/dev/null
    gsettings set "$P" background-color "$background" 2>/dev/null
    gsettings set "$P" foreground-color "$foreground" 2>/dev/null
    gsettings set "$P" palette "$PALETTE" 2>/dev/null
}

toast() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Обои" -t 1500 -h string:x-canonical-private-synchronous:setwall \
            "$1" "$2" 2>/dev/null
    fi
}

# сдвиг на N позиций от текущей, по кругу
step() {
    DELTA="$1"
    TMP=$(mktemp)
    list_images > "$TMP"
    N=$(wc -l < "$TMP")
    if [ "$N" -eq 0 ]; then
        rm -f "$TMP"
        echo "в каталоге нет картинок: $WALLDIR"
        exit 1
    fi

    CUR=$(current_path)
    POS=0
    if [ -n "$CUR" ]; then
        L=$(grep -n -x -F "$CUR" "$TMP" | head -1 | cut -d: -f1)
        if [ -n "$L" ]; then
            POS="$L"
        fi
    fi

    # POS — номер строки с единицы; 0 значит «текущей нет в списке»
    if [ "$POS" -eq 0 ]; then
        NEXT=1
    else
        NEXT=$(( (POS - 1 + DELTA + N) % N + 1 ))
    fi

    F=$(sed -n "${NEXT}p" "$TMP")
    rm -f "$TMP"
    apply "$F"
    echo "$NEXT / $N  $(basename "$F")"
    toast "$NEXT / $N" "$(basename "$F")"
}

cmd_random() {
    TMP=$(mktemp)
    list_images > "$TMP"
    N=$(wc -l < "$TMP")
    if [ "$N" -eq 0 ]; then
        rm -f "$TMP"
        echo "в каталоге нет картинок: $WALLDIR"
        exit 1
    fi
    F=$(shuf -n1 "$TMP")
    rm -f "$TMP"
    apply "$F"
    echo "случайная: $(basename "$F")"
    toast "Случайная" "$(basename "$F")"
}

cmd_current() {
    CUR=$(current_path)
    if [ -z "$CUR" ]; then
        echo "обои не определены"
        exit 1
    fi
    TMP=$(mktemp)
    list_images > "$TMP"
    N=$(wc -l < "$TMP")
    L=$(grep -n -x -F "$CUR" "$TMP" | head -1 | cut -d: -f1)
    rm -f "$TMP"
    if [ -z "$L" ]; then
        L="вне списка"
    fi
    echo "каталог:  $WALLDIR"
    echo "картинок: $N"
    echo "позиция:  $L"
    echo "файл:     $CUR"
}

cmd_set() {
    F="$1"
    if [ ! -f "$F" ]; then
        echo "нет такого файла: $F"
        exit 1
    fi
    F=$(readlink -f "$F")
    apply "$F"
    echo "поставлено: $(basename "$F")"
}

CMD="${1:-next}"
case "$CMD" in
    next|'')  step 1 ;;
    prev)     step -1 ;;
    random)   cmd_random ;;
    current|status) cmd_current ;;
    set)      cmd_set "${2:-}" ;;
    help|--help|-h) usage ;;
    *)
        echo "неизвестная команда: $CMD"
        echo
        usage
        ;;
esac
