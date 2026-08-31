#!/usr/bin/env bash
# Банк обоев: пополнение, расписание, состояние.
#
#   wallpapers                    добрать 10 картинок
#   wallpapers add 25             добрать 25
#   wallpapers init               первая заливка (250)
#   wallpapers timer              каждую среду в 13:00
#   wallpapers timer Fri 19:00    свой день и время
#   wallpapers timer Tue,Fri      два раза в неделю
#   wallpapers timer off          снять расписание
#   wallpapers status             банк, расписание, последние запуски
#   wallpapers prune 900          оставить 900 самых свежих
#   wallpapers urls               показать, какие запросы уйдут
#   wallpapers help
#
# Качает с wallhaven рисованное (digital art, artwork, illustration) под
# родное разрешение монитора. Уже скачанное не перекачивает, битые файлы
# и всё тяжелее 12 МБ выбрасывает, страницу новой вкладки пересобирает.
#
# Ничего не удаляет без явной команды prune.

set -uo pipefail

VERSION="2.0"
ADD_DEFAULT=10          # сколько добирать по умолчанию и по расписанию
INIT_COUNT=250          # первая заливка
DAY_DEFAULT="Wed"       # будний день: рабочий ноутбук по выходным выключен
TIME_DEFAULT="13:00"
MAX_MB=12               # картинки тяжелее — мимо
UNIT="wallpapers-refill"
STATE="$HOME/.local/state"
LOG="$STATE/wallpapers.log"
UD="$HOME/.config/systemd/user"
SELFPATH="$HOME/bin/wallpapers"

# ------------------------------------------------------------ мелочи

log() {
    mkdir -p "$STATE"
    echo "$(date '+%Y-%m-%d %H:%M') $*" >> "$LOG"
    echo "$*"
}

die() {
    echo "✗ $*" >&2
    exit 1
}

human_mb() {
    echo "$(( $1 / 1024 / 1024 )) МБ"
}

usage() {
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

need_tools() {
    MISSING=""
    for t in curl jq file; do
        if ! command -v "$t" >/dev/null 2>&1; then
            MISSING="$MISSING $t"
        fi
    done
    if [ -n "$MISSING" ]; then
        die "не хватает:$MISSING — sudo apt install -y$MISSING"
    fi
}

# каталог банка: первый существующий, иначе создаём английский вариант
find_walldir() {
    for d in "$HOME/Pictures/wallpapers-uw" "$HOME/Изображения/wallpapers-uw" \
             "$HOME/Pictures/wallpapers" "$HOME/Изображения/wallpapers"; do
        if [ -d "$d" ]; then
            echo "$d"
            return
        fi
    done
    P=$(xdg-user-dir PICTURES 2>/dev/null)
    if [ -z "$P" ]; then
        P="$HOME/Pictures"
    fi
    echo "$P/wallpapers-uw"
}

count_files() {
    find "$1" -maxdepth 1 -type f -iname '*.jpg' 2>/dev/null | wc -l
}

dir_bytes() {
    du -sb "$1" 2>/dev/null | cut -f1
}

# родное разрешение панели: /sys честнее xrandr, тот на Wayland врёт
detect_res() {
    R=$(cat /sys/class/drm/card*-*/modes 2>/dev/null \
        | grep -oE '^[0-9]+x[0-9]+$' | sort -t x -k1,1nr -k2,2nr | head -1)
    if [ -z "$R" ]; then
        R=$(xrandr 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | head -1)
    fi
    if [ -z "$R" ]; then
        R="1920x1080"
    fi
    echo "$R"
}

# темы недели: набор меняется, но внутри одной недели повторяем тот же
# выбор — чтобы повторный запуск не тянул случайный мусор
themes_for_week() {
    ALL="digital+art artwork illustration scenery landscape fantasy space \
mountains forest sunset ocean neon city abstract minimal aurora clouds \
mist canyon lake nordic"
    SEED=$(date +%V)
    echo "$ALL" | tr ' ' '\n' | grep -v '^$' \
        | shuf --random-source=<(yes "$SEED") | head -6 | tr '\n' ' '
}

# два режима вперемешку: свежая случайная выдача плюс лучшее за год
build_urls() {
    RES="$1"
    SEED=$(date +%GW%V | tr -d 'W-' | cut -c1-6)
    for q in $(themes_for_week); do
        echo "https://wallhaven.cc/api/v1/search?q=$q&atleast=$RES&categories=100&purity=100&sorting=random&seed=$SEED&page=1"
        echo "https://wallhaven.cc/api/v1/search?q=$q&atleast=$RES&categories=100&purity=100&sorting=toplist&topRange=1y&page=1"
    done
}

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Обои" "$1" "$2" 2>/dev/null
    fi
}

# ------------------------------------------------------------ команды

cmd_add() {
    WANT="$1"
    need_tools

    WALLDIR=$(find_walldir)
    mkdir -p "$WALLDIR"
    RES=$(detect_res)
    HAVE=$(count_files "$WALLDIR")

    log "==> банк $WALLDIR: $HAVE шт., разрешение $RES, добираю $WANT"

    POOL=$(mktemp)
    NEW=$(mktemp)
    TAKE=$(mktemp)

    FAILED=0
    for u in $(build_urls "$RES"); do
        R=$(curl -sf --max-time 25 "$u" 2>/dev/null)
        if [ -z "$R" ]; then
            FAILED=$((FAILED + 1))
            continue
        fi
        echo "$R" | jq -r '.data[]?.path' 2>/dev/null >> "$POOL"
        sleep 2      # лимит wallhaven — 45 запросов в минуту
    done

    if [ ! -s "$POOL" ]; then
        rm -f "$POOL" "$NEW" "$TAKE"
        log "    wallhaven не ответил ни на один запрос — ничего не скачано"
        notify "Пополнение не удалось" "wallhaven недоступен"
        exit 1
    fi
    if [ "$FAILED" -gt 0 ]; then
        log "    запросов без ответа: $FAILED (остальные отработали)"
    fi

    grep '\.jpg$' "$POOL" | sort -u | shuf > "$NEW.all"
    : > "$NEW"
    while read -r url; do
        name=$(basename "$url")
        if [ ! -f "$WALLDIR/$name" ]; then
            echo "$url" >> "$NEW"
        fi
    done < "$NEW.all"

    head -n "$WANT" "$NEW" > "$TAKE"
    COUNT=$(wc -l < "$TAKE")
    log "    найдено новых: $(wc -l < "$NEW"), качаю: $COUNT"

    if [ "$COUNT" -eq 0 ]; then
        rm -f "$POOL" "$NEW" "$NEW.all" "$TAKE"
        log "    всё, что нашлось, уже в банке"
        exit 0
    fi

    ( cd "$WALLDIR"; xargs -r -n1 -P3 curl -sf --retry 2 --retry-delay 2 \
        --max-time 120 --remove-on-error -O ) < "$TAKE"

    # чистка: не-картинки (страницы ошибок) и слишком тяжёлые
    BAD=0
    for f in "$WALLDIR"/*; do
        if [ -f "$f" ]; then
            if ! file --brief --mime-type "$f" | grep -q '^image/'; then
                rm -f "$f"
                BAD=$((BAD + 1))
            fi
        fi
    done
    HEAVY=$(find "$WALLDIR" -maxdepth 1 -type f -size +${MAX_MB}M 2>/dev/null | wc -l)
    find "$WALLDIR" -maxdepth 1 -type f -size +${MAX_MB}M -delete 2>/dev/null
    if [ "$BAD" -gt 0 ]; then
        log "    выброшено битых: $BAD"
    fi
    if [ "$HEAVY" -gt 0 ]; then
        log "    выброшено тяжелее ${MAX_MB} МБ: $HEAVY"
    fi

    NOW=$(count_files "$WALLDIR")
    ADDED=$((NOW - HAVE))
    log "    добавлено $ADDED, всего в банке $NOW ($(human_mb "$(dir_bytes "$WALLDIR")"))"

    if [ -x "$HOME/bin/newtab" ]; then
        "$HOME/bin/newtab" >/dev/null 2>&1
        log "    страница новой вкладки пересобрана"
    fi

    notify "Обои пополнены" "добавлено $ADDED, всего $NOW"
    rm -f "$POOL" "$NEW" "$NEW.all" "$TAKE"
}

cmd_timer() {
    DAY="${1:-$DAY_DEFAULT}"
    AT="${2:-$TIME_DEFAULT}"

    if [ "$DAY" = "off" ]; then
        systemctl --user disable --now "$UNIT.timer" >/dev/null 2>&1
        rm -f "$UD/$UNIT.timer" "$UD/$UNIT.service"
        systemctl --user daemon-reload
        echo "✓ расписание снято, скрипт и банк на месте"
        exit 0
    fi

    if ! echo "$DAY" | grep -qE '^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)(,(Mon|Tue|Wed|Thu|Fri|Sat|Sun))*$'; then
        die "день: Mon Tue Wed Thu Fri Sat Sun, можно через запятую (Tue,Fri). Было: '$DAY'"
    fi
    if ! echo "$AT" | grep -qE '^[0-2][0-9]:[0-5][0-9]$'; then
        die "время в формате ЧЧ:ММ, например 13:00. Было: '$AT'"
    fi

    # ставим себя в постоянное место: таймер не должен зависеть от того,
    # откуда скрипт запустили — уборка ~/Desktop не сломает расписание
    mkdir -p "$HOME/bin"
    SELF=$(readlink -f "$0")
    if [ "$SELF" != "$SELFPATH" ]; then
        cp "$SELF" "$SELFPATH"
        chmod +x "$SELFPATH"
        echo "✓ скрипт установлен: $SELFPATH"
    fi

    mkdir -p "$UD"
    cat > "$UD/$UNIT.service" <<EOF
[Unit]
Description=Пополнение банка обоев
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$SELFPATH add $ADD_DEFAULT
EOF

    cat > "$UD/$UNIT.timer" <<EOF
[Unit]
Description=Пополнение банка обоев по расписанию

[Timer]
OnCalendar=$DAY $AT
RandomizedDelaySec=2h
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now "$UNIT.timer" >/dev/null 2>&1
    echo "✓ расписание: $DAY в $AT, по $ADD_DEFAULT картинок"
    echo
    systemctl --user list-timers "$UNIT.timer" --no-pager
    echo
    echo "сменить:   wallpapers timer Fri 19:00"
    echo "снять:     wallpapers timer off"
    echo "проверить: systemctl --user start $UNIT.service"
}

cmd_status() {
    WALLDIR=$(find_walldir)
    echo "Банк"
    if [ -d "$WALLDIR" ]; then
        echo "  каталог:     $WALLDIR"
        echo "  картинок:    $(count_files "$WALLDIR")"
        echo "  размер:      $(human_mb "$(dir_bytes "$WALLDIR")")"
        NEWEST=$(ls -t "$WALLDIR" 2>/dev/null | head -1)
        echo "  свежая:      $NEWEST"
    else
        echo "  каталога нет: $WALLDIR"
        echo "  создать:      wallpapers init"
    fi

    echo
    echo "Монитор"
    echo "  разрешение:  $(detect_res)"

    echo
    echo "Расписание"
    if [ -f "$UD/$UNIT.timer" ]; then
        grep '^OnCalendar' "$UD/$UNIT.timer" | sed 's/^/  /'
        systemctl --user list-timers "$UNIT.timer" --no-pager 2>/dev/null | sed -n '2p;3p' | sed 's/^/  /'
    else
        echo "  не настроено"
        echo "  включить:    wallpapers timer"
    fi

    echo
    echo "Последние запуски"
    if [ -f "$LOG" ]; then
        tail -8 "$LOG" | sed 's/^/  /'
    else
        echo "  лога ещё нет: $LOG"
    fi
}

cmd_prune() {
    KEEP="$1"
    WALLDIR=$(find_walldir)
    HAVE=$(count_files "$WALLDIR")
    if [ "$HAVE" -le "$KEEP" ]; then
        echo "в банке $HAVE, оставить просили $KEEP — удалять нечего"
        exit 0
    fi
    DROP=$((HAVE - KEEP))
    echo "в банке $HAVE, удалю $DROP самых старых по времени файла"
    printf 'продолжить? [y/N] '
    read -r ans
    if [ "$ans" != "y" ]; then
        echo "отменено"
        exit 0
    fi
    ls -t "$WALLDIR" | tail -n "$DROP" | while read -r f; do
        rm -f "$WALLDIR/$f"
    done
    log "prune: удалено $DROP, осталось $(count_files "$WALLDIR")"
    if [ -x "$HOME/bin/newtab" ]; then
        "$HOME/bin/newtab" >/dev/null 2>&1
    fi
}

cmd_urls() {
    echo "разрешение: $(detect_res)"
    echo "темы недели: $(themes_for_week)"
    echo
    build_urls "$(detect_res)"
}

# ------------------------------------------------------------ разбор

CMD="${1:-add}"
case "$CMD" in
    add)     cmd_add "${2:-$ADD_DEFAULT}" ;;
    init)    cmd_add "${2:-$INIT_COUNT}" ;;
    timer)   cmd_timer "${2:-$DAY_DEFAULT}" "${3:-$TIME_DEFAULT}" ;;
    status)  cmd_status ;;
    prune)   cmd_prune "${2:-900}" ;;
    urls)    cmd_urls ;;
    help|--help|-h) usage ;;
    version|--version) echo "wallpapers $VERSION" ;;
    ''|*[!0-9]*)
        echo "неизвестная команда: $CMD"
        echo
        usage
        ;;
    *)       cmd_add "$CMD" ;;    # просто число: wallpapers 25
esac
