#!/usr/bin/env bash
# Кнопки заголовка в стиле Windows: тонкие значки, квадратная подсветка,
# красный квадрат на закрытии. Больше ничего не трогает.
#
#   ./titlebuttons.sh              кнопка 40x32, значок 20
#   ./titlebuttons.sh 46 32 20     ширина, высота, значок
#   ./titlebuttons.sh --revert     вернуть как было
#
# Тема GTK, цветовая схема, папки, обои и панель не затрагиваются.
#
# Кнопку рисуют два источника: форму значка даёт тема иконок, размер и
# подложку — тема GTK. Поэтому скрипт делает две вещи:
#
#   1. Создаёт тему иконок ИМЯ-Fluent-Titlebar, которая наследует текущую
#      целиком и переопределяет ровно четыре значка, взятых из Fluent.
#      Папки и приложения остаются прежними, обновления не затирают.
#   2. Пишет размер и подсветку в ~/.config/gtk-3.0/gtk.css и gtk-4.0/gtk.css.
#      КАЖДОЕ свойство с !important: в темах вроде Graphite правило
#      button.titlebutton:not(.suggested-action):not(.destructive-action)
#      специфичнее пользовательского, и без !important подложка остаётся
#      круглой, сколько её ни переопределяй.
#
# Chrome, Tabby и Telegram не изменятся: это Electron, они рисуют кнопки сами.

set -uo pipefail

BTN_W="${1:-40}"
BTN_H="${2:-32}"
BTN_ICO="${3:-20}"
FLUENT="https://raw.githubusercontent.com/vinceliuice/Fluent-icon-theme/master/src/symbolic/actions"

ok()  { echo "  ✓ $*"; }
bad() { echo "  ✗ $*"; }

gget() { gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'"; }
gset() { gsettings set org.gnome.desktop.interface icon-theme "$1" 2>/dev/null; }

strip_block() {
    if [ -f "$1" ]; then
        sed -i '/titlebuttons-begin/,/titlebuttons-end/d' "$1"
    fi
}

CUR=$(gget)
BASE="$CUR"
case "$CUR" in *-Fluent-Titlebar) BASE="${CUR%-Fluent-Titlebar}" ;; esac
if [ -z "$BASE" ]; then
    BASE="Adwaita"
fi
THEME="$BASE-Fluent-Titlebar"
DIR="$HOME/.local/share/icons/$THEME"

# ---------------------------------------------------------------- откат

if [ "$BTN_W" = "--revert" ]; then
    strip_block "$HOME/.config/gtk-3.0/gtk.css"
    strip_block "$HOME/.config/gtk-4.0/gtk.css"
    case "$CUR" in
        *-Fluent-Titlebar)
            rm -rf "$HOME/.local/share/icons/$CUR"
            gset "$BASE"
            ok "тема иконок возвращена: $BASE"
            ;;
        *)  ok "тема иконок и так своя: $CUR" ;;
    esac
    ok "блок из gtk.css убран"
    echo "готово"
    exit 0
fi

for v in "$BTN_W" "$BTN_H" "$BTN_ICO"; do
    if ! echo "$v" | grep -qE '^[0-9]+$'; then
        bad "размеры — числа: $0 46 32 20"
        exit 1
    fi
done

# ---------------------------------------------------------------- значки

FOUND=""
for d in "$HOME/.local/share/icons/$BASE" "$HOME/.icons/$BASE" "/usr/share/icons/$BASE"; do
    if [ -d "$d" ]; then
        FOUND="$d"
    fi
done
if [ -z "$FOUND" ]; then
    bad "темы иконок $BASE нет ни в ~/.local/share/icons, ни в /usr/share/icons"
    exit 1
fi
ok "базовая тема: $BASE"

mkdir -p "$DIR/symbolic/actions"
GOT=0
for n in close maximize minimize restore; do
    F="$DIR/symbolic/actions/window-$n-symbolic.svg"
    CODE=$(curl -sf -L --max-time 30 -o "$F" -w '%{http_code}' \
           "$FLUENT/window-$n-symbolic.svg" 2>/dev/null)
    if [ "$CODE" = "200" ]; then
        if head -c 200 "$F" 2>/dev/null | grep -q '<svg'; then
            GOT=$((GOT + 1))
        else
            rm -f "$F"
        fi
    else
        rm -f "$F"
    fi
done

if [ "$GOT" -ne 4 ]; then
    bad "значков скачалось $GOT из 4 — ничего не менял"
    rm -rf "$DIR"
    exit 1
fi
ok "значки Fluent: 4 из 4"

cat > "$DIR/index.theme" <<EOF
[Icon Theme]
Name=$THEME
Comment=$BASE с кнопками заголовка из Fluent
Inherits=$BASE,Adwaita,hicolor
Directories=symbolic/actions

[symbolic/actions]
Size=16
MinSize=8
MaxSize=512
Context=Actions
Type=Scalable
EOF

gtk-update-icon-cache -f "$DIR" >/dev/null 2>&1
ok "тема иконок: $THEME"

# ---------------------------------------------------------------- css

write_css() {
    F="$1"
    mkdir -p "$(dirname "$F")"
    touch "$F"
    strip_block "$F"
    cat >> "$F" <<EOF
/* titlebuttons-begin */
/* Квадратная подсветка вместо круглой подложки темы.
   !important обязателен: правило темы специфичнее пользовательского. */
headerbar button.titlebutton,
.titlebar button.titlebutton,
headerbar windowcontrols button,
windowcontrols button,
windowcontrols > button {
  min-width: ${BTN_W}px !important;
  min-height: ${BTN_H}px !important;
  padding: 0 !important;
  margin: 0 !important;
  background: none !important;
  background-color: transparent !important;
  background-image: none !important;
  box-shadow: none !important;
  border: none !important;
  border-radius: 0 !important;
  outline: none !important;
  -gtk-outline-radius: 0 !important;
}

headerbar button.titlebutton:hover,
.titlebar button.titlebutton:hover,
headerbar windowcontrols button:hover,
windowcontrols button:hover,
windowcontrols > button:hover {
  background-color: alpha(currentColor, 0.14) !important;
  background-image: none !important;
  border-radius: 0 !important;
}

headerbar button.titlebutton:active,
.titlebar button.titlebutton:active,
headerbar windowcontrols button:active,
windowcontrols button:active,
windowcontrols > button:active {
  background-color: alpha(currentColor, 0.22) !important;
  border-radius: 0 !important;
}

headerbar button.titlebutton.close:hover,
.titlebar button.titlebutton.close:hover,
headerbar windowcontrols button.close:hover,
windowcontrols button.close:hover,
windowcontrols > button.close:hover {
  background-color: #e81123 !important;
  background-image: none !important;
  color: #ffffff !important;
  border-radius: 0 !important;
}

headerbar button.titlebutton.close:active,
.titlebar button.titlebutton.close:active,
headerbar windowcontrols button.close:active,
windowcontrols button.close:active,
windowcontrols > button.close:active {
  background-color: #c50f1f !important;
  color: #ffffff !important;
  border-radius: 0 !important;
}

headerbar button.titlebutton image,
.titlebar button.titlebutton image,
windowcontrols button image,
windowcontrols > button image {
  -gtk-icon-size: ${BTN_ICO}px !important;
}
/* titlebuttons-end */
EOF
}

write_css "$HOME/.config/gtk-3.0/gtk.css"
write_css "$HOME/.config/gtk-4.0/gtk.css"
ok "кнопка ${BTN_W}x${BTN_H}px, значок ${BTN_ICO}px, подсветка квадратная"

gset "$THEME"

# ---------------------------------------------------------------- проверка

echo
echo "проверка:"
python3 - "$THEME" <<'PY' 2>/dev/null
import sys
try:
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk
except Exception:
    print('  python3-gi нет, значки не проверить')
    raise SystemExit(0)

theme = Gtk.IconTheme.new()
theme.set_custom_theme(sys.argv[1])
for name in ('window-close-symbolic', 'window-maximize-symbolic',
             'window-minimize-symbolic'):
    info = theme.lookup_icon(name, 16, 0)
    print('  %-26s %s' % (name, info.get_filename() if info else 'НЕ НАЙДЕНА'))
PY

echo
echo "GTK3-окна (Nautilus, Evolution) подхватят сразу или после перезапуска."
echo "GTK4 — после перезапуска приложения. Оболочка не трогалась."
echo
echo "другой размер:    $0 46 32 22"
echo "вернуть как было: $0 --revert"
