#!/usr/bin/env bash
# Светлая тема только для Evolution, система остаётся тёмной.
#
#   ./evolution-light.sh              # Yaru-light
#   ./evolution-light.sh Adwaita      # любая другая тема
#
# Своей темы у Evolution нет — он берёт системную GTK-тему. Обойти это
# можно переменной GTK_THEME, но задавать её надо на запуск, а не в
# сессии. Скрипт кладёт свою копию ярлыка в ~/.local/share/applications
# и подставляет переменную во все строки запуска, включая пункты
# контекстного меню дока (Actions) — иначе «Написать письмо» открывало бы
# тёмное окно.
#
# Откат: rm ~/.local/share/applications/org.gnome.Evolution.desktop

set -uo pipefail

THEME="${1:-Yaru-light}"
APPDIR="$HOME/.local/share/applications"

# --- 1. тема существует? ---------------------------------------------
FOUND=""
for d in "$HOME/.themes/$THEME" "/usr/share/themes/$THEME"; do
    if [ -d "$d" ]; then
        FOUND="$d"
    fi
done
if [ -z "$FOUND" ]; then
    echo "✗ темы '$THEME' нет ни в ~/.themes, ни в /usr/share/themes"
    echo
    echo "  что установлено:"
    ls /usr/share/themes
    if [ -d "$HOME/.themes" ]; then
        ls "$HOME/.themes"
    fi
    echo
    echo "  запусти с нужным именем: $0 ИМЯ_ТЕМЫ"
    exit 1
fi
echo "✓ тема найдена: $FOUND"

# --- 2. системный ярлык Evolution ------------------------------------
SRC=""
for f in /usr/share/applications/org.gnome.Evolution.desktop \
         /usr/share/applications/evolution.desktop; do
    if [ -f "$f" ]; then
        SRC="$f"
    fi
done
if [ -z "$SRC" ]; then
    echo "✗ ярлык Evolution не найден в /usr/share/applications"
    echo "  посмотри сам: ls /usr/share/applications | grep -i evolution"
    exit 1
fi
echo "✓ ярлык: $SRC"

# --- 3. своя копия ----------------------------------------------------
# копируем заново каждый раз: так повторный запуск с другой темой
# не накапливает старые env-префиксы
DST="$APPDIR/$(basename "$SRC")"
mkdir -p "$APPDIR"
cp "$SRC" "$DST"
echo "✓ скопирован в $DST"

# --- 4. подставляем GTK_THEME во все строки запуска -------------------
python3 - "$DST" "$THEME" <<'PY'
import sys, io

path, theme = sys.argv[1], sys.argv[2]
lines = io.open(path, encoding='utf-8').read().splitlines()

out, n = [], 0
for ln in lines:
    if ln.startswith('Exec='):
        cmd = ln[5:].strip()
        # снимаем старый env-префикс, если он вдруг есть
        if cmd.startswith('env '):
            words = cmd[4:].split()
            i = 0
            while i < len(words) and '=' in words[i]:
                i += 1
            cmd = ' '.join(words[i:])
        ln = 'Exec=env GTK_THEME=' + theme + ' ' + cmd
        n += 1
    out.append(ln)

io.open(path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('✓ строк запуска поправлено: %d' % n)
PY

# --- 5. обновляем базу ярлыков ---------------------------------------
if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$APPDIR" 2>/dev/null
    echo "✓ база ярлыков обновлена"
fi

# --- 6. закрываем работающий Evolution -------------------------------
if pgrep -x evolution >/dev/null; then
    evolution --quit
    echo "✓ Evolution закрыт — запусти заново иконкой"
fi

echo
echo "строки запуска теперь такие:"
grep '^Exec=' "$DST"
echo
echo "проверить руками: GTK_THEME=$THEME evolution"
echo "откатить:         rm $DST"
