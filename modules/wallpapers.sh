#!/usr/bin/env bash
# Пополнение банка обоев с wallhaven — рисованные, под разрешение монитора.
#
#   ./modules/wallpapers.sh                # добавить 8 новых
#   ./modules/wallpapers.sh 15             # добавить 15
#   ./modules/wallpapers.sh --init         # первичная заливка (~250 штук)
#   ./modules/wallpapers.sh --install-timer  # раз в неделю по 10, автоматом
#
# Уже скачанные не перекачиваются: сверка идёт по имени файла.
# Битые загрузки и HTML-страницы ошибок отсеиваются по mime-типу.

set -uo pipefail

WALL_DIR="$HOME/Pictures/wallpapers-uw"
if [ ! -d "$WALL_DIR" ]; then
    ALT="$HOME/Изображения/wallpapers-uw"
    if [ -d "$ALT" ]; then
        WALL_DIR="$ALT"
    fi
fi
mkdir -p "$WALL_DIR"

WANT="${1:-8}"
MODE="add"

if [ "$WANT" = "--init" ]; then
    MODE="init"
    WANT=250
fi

# ---------- еженедельный таймер ----------
if [ "$WANT" = "--install-timer" ]; then
    SELF=$(readlink -f "$0")

    # кладём себя в постоянное место: иначе таймер будет ссылаться на
    # ~/Downloads или ~/Desktop, и первая же уборка сломает автопополнение
    mkdir -p "$HOME/bin"
    TARGET="$HOME/bin/wallpapers"
    if [ "$SELF" != "$TARGET" ]; then
        cp "$SELF" "$TARGET"
        chmod +x "$TARGET"
        echo "скрипт установлен: $TARGET"
    fi

    UD="$HOME/.config/systemd/user"
    mkdir -p "$UD"

    cat > "$UD/wallpapers-refill.service" <<EOF
[Unit]
Description=Пополнение банка обоев
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$TARGET 10
EOF

    cat > "$UD/wallpapers-refill.timer" <<'EOF'
[Unit]
Description=Раз в неделю добирать обои

[Timer]
OnCalendar=Sun 13:00
RandomizedDelaySec=2h
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now wallpapers-refill.timer
    echo "таймер включён, ближайший запуск:"
    systemctl --user list-timers wallpapers-refill.timer --no-pager
    echo
    echo "проверить руками:  systemctl --user start wallpapers-refill.service"
    echo "посмотреть лог:    journalctl --user -u wallpapers-refill -n 30"
    echo "выключить:         systemctl --user disable --now wallpapers-refill.timer"
    exit 0
fi

for t in curl jq file; do
    if ! command -v "$t" >/dev/null; then
        echo "нет $t — sudo apt install -y curl jq file"
        exit 1
    fi
done

# родное разрешение панели: работает и на Wayland, и по SSH
RES=$(cat /sys/class/drm/card*-*/modes 2>/dev/null | grep -oE '^[0-9]+x[0-9]+$' \
      | sort -t x -k1,1nr -k2,2nr | head -1)
if [ -z "$RES" ]; then
    RES=$(xrandr 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | head -1)
fi
if [ -z "$RES" ]; then
    RES=1920x1080
fi

HAVE=$(find "$WALL_DIR" -maxdepth 1 -type f | wc -l)
echo "==> банк: $HAVE шт., целевое разрешение $RES, добираю до $WANT"

# digital art / artwork / illustration держат планку «рисованных»
if [ "$MODE" = "init" ]; then
    QUERIES="digital+art artwork illustration scenery fantasy space mountains city abstract forest sunset ocean"
    SORT="sorting=views"
else
    # каждую неделю новый набор тем и новая случайная выдача:
    # seed привязан к номеру недели, внутри недели повторный запуск даст то же,
    # на следующей — совсем другое
    ALL="digital+art artwork illustration scenery landscape fantasy space mountains forest sunset ocean neon city abstract minimal aurora clouds"
    QUERIES=$(echo "$ALL" | tr ' ' '\n' | shuf | head -6 | tr '\n' ' ')
    SEED=$(date +%GW%V | tr -d 'W-' | cut -c1-6)
    SORT="sorting=random&seed=$SEED"
fi
echo "    темы: $QUERIES"

: > /tmp/wl_all.txt
for q in $QUERIES; do
    for p in 1 2; do
        curl -sf --max-time 25 \
          "https://wallhaven.cc/api/v1/search?q=$q&atleast=$RES&categories=100&purity=100&$SORT&page=$p" \
          | jq -r '.data[].path' 2>/dev/null >> /tmp/wl_all.txt
        sleep 2   # лимит wallhaven — 45 запросов в минуту
    done
done

if [ ! -s /tmp/wl_all.txt ]; then
    echo "    wallhaven недоступен — ничего не скачано"
    exit 1
fi

# только jpg, только те, которых ещё нет, перемешать и взять нужное число
grep '\.jpg$' /tmp/wl_all.txt | sort -u | shuf > /tmp/wl_pool.txt
: > /tmp/wl_new.txt
while read -r url; do
    name=$(basename "$url")
    if [ ! -f "$WALL_DIR/$name" ]; then
        echo "$url" >> /tmp/wl_new.txt
    fi
done < /tmp/wl_pool.txt

head -n "$WANT" /tmp/wl_new.txt > /tmp/wl_take.txt
COUNT=$(wc -l < /tmp/wl_take.txt)
echo "    новых к загрузке: $COUNT"

if [ "$COUNT" -eq 0 ]; then
    echo "    всё, что нашлось, уже есть в банке"
    exit 0
fi

cd "$WALL_DIR"
xargs -r -n1 -P3 curl -sf --retry 2 --retry-delay 2 --max-time 120 \
      --remove-on-error -O < /tmp/wl_take.txt

# чистка: не-картинки и слишком тяжёлые
for f in "$WALL_DIR"/*; do
    if [ -f "$f" ]; then
        if ! file --brief --mime-type "$f" | grep -q '^image/'; then
            rm -f "$f"
        fi
    fi
done
find "$WALL_DIR" -maxdepth 1 -type f -size +12M -delete

NOW=$(find "$WALL_DIR" -maxdepth 1 -type f | wc -l)
echo "    добавлено: $((NOW - HAVE)), всего в банке: $NOW"

# страница новой вкладки знает список картинок — пересобираем
if [ -x "$HOME/bin/newtab" ]; then
    "$HOME/bin/newtab" >/dev/null 2>&1
    echo "    страница новой вкладки обновлена"
fi

rm -f /tmp/wl_all.txt /tmp/wl_pool.txt /tmp/wl_new.txt /tmp/wl_take.txt
