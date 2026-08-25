#!/usr/bin/env bash
# Отдаёт локальную страницу-апку по http://localhost и держит её живой.
#
#   ./localapp.sh                                   # каталог по умолчанию, порт 8800
#   ./localapp.sh ~/Desktop/work/commutator_app     # свой каталог
#   ./localapp.sh ~/Desktop/work/commutator_app 8801
#
# Зачем: страница новой вкладки живёт в контексте расширения, а Chrome
# запрещает переходы на file:// с таких страниц — плитка молча не
# открывается. Галка "Allow access to file URLs" тут не помогает, она про
# чтение самой страницы, а не про навигацию с неё. По http ограничения нет.
#
# Слушает только 127.0.0.1 — из сети апка недоступна.
#
# Откат:
#   systemctl --user disable --now localapp-ИМЯ.service
#   rm ~/.config/systemd/user/localapp-ИМЯ.service

set -uo pipefail

APPDIR="${1:-$HOME/Desktop/work/commutator_app}"
PORT="${2:-8800}"

# --- 1. апка на месте? ------------------------------------------------
if [ ! -d "$APPDIR" ]; then
    echo "✗ каталога нет: $APPDIR"
    echo "  запусти с верным путём: $0 /путь/к/апке"
    exit 1
fi
if [ ! -f "$APPDIR/index.html" ]; then
    echo "✗ в каталоге нет index.html: $APPDIR"
    echo "  что там лежит:"
    ls "$APPDIR"
    exit 1
fi
APPDIR=$(cd "$APPDIR"; pwd)
NAME=$(basename "$APPDIR")
echo "✓ апка: $APPDIR"

# --- 2. порт свободен? ------------------------------------------------
UNIT="localapp-$NAME.service"
if ss -ltn 2>/dev/null | grep -q ":$PORT "; then
    if systemctl --user is-active --quiet "$UNIT"; then
        echo "  порт $PORT занят нашей же службой — перезапущу"
        systemctl --user stop "$UNIT"
    else
        echo "✗ порт $PORT занят чужим процессом:"
        ss -ltnp 2>/dev/null | grep ":$PORT "
        echo "  возьми другой: $0 \"$APPDIR\" 8801"
        exit 1
    fi
fi

# --- 3. служба --------------------------------------------------------
UD="$HOME/.config/systemd/user"
mkdir -p "$UD"

cat > "$UD/$UNIT" <<EOF
[Unit]
Description=Локальная апка $NAME на порту $PORT
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server $PORT --bind 127.0.0.1 --directory $APPDIR
Restart=on-failure

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now "$UNIT"
echo "✓ служба запущена: $UNIT"

# --- 4. проверяем, что отвечает --------------------------------------
sleep 1
CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/" 2>/dev/null)
if [ "$CODE" = "200" ]; then
    echo "✓ отвечает: http://localhost:$PORT"
else
    echo "✗ не отвечает (код '$CODE'), смотри лог:"
    echo "  journalctl --user -u $UNIT -n 20 --no-pager"
    exit 1
fi

# --- 5. правим ссылку на странице новой вкладки -----------------------
LINKS="$HOME/.local/share/newtab/links.txt"
if [ -f "$LINKS" ]; then
    python3 - "$LINKS" "$NAME" "$PORT" <<'PY'
import sys, io

path, name, port = sys.argv[1], sys.argv[2], sys.argv[3]
new = 'http://localhost:' + port
lines = io.open(path, encoding='utf-8').read().splitlines()

out, fixed = [], 0
for ln in lines:
    if '|' in ln and not ln.strip().startswith('#'):
        title, url = ln.split('|', 1)
        if url.strip().startswith('file://') and name in url:
            ln = title + '|' + new
            fixed += 1
    out.append(ln)

if fixed == 0:
    print('  ссылки на file:// с этой апкой в links.txt не нашлось')
    print('  впиши строкой:  НАЗВАНИЕ|' + new)
else:
    io.open(path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
    print('✓ ссылок переписано на http: %d' % fixed)
PY
fi

# --- 6. пересобираем страницу ----------------------------------------
if [ -x "$HOME/bin/newtab" ]; then
    "$HOME/bin/newtab"
fi

echo
echo "апка:      http://localhost:$PORT"
echo "состояние: systemctl --user status $UNIT"
echo "выключить: systemctl --user disable --now $UNIT"
