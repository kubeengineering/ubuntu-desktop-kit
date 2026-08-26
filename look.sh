#!/usr/bin/env bash
# Кнопки заголовка и углы окон — правкой КОПИИ темы, а не пользовательского css.
#
#   ./look.sh                     кнопки + острые углы
#   ./look.sh --no-corners        только кнопки, углы оставить как есть
#   ./look.sh --size 46 34 24     ширина, высота кнопки, размер значка
#   ./look.sh --font "JetBrainsMono Nerd Font 11"   шрифт интерфейса
#   ./look.sh --check             что сейчас применено
#   ./look.sh --revert            вернуть исходную тему
#
# ПОЧЕМУ ТАК, а не через ~/.config/gtk-3.0/gtk.css:
#
#   Прошлые попытки писали правила в пользовательский css и не действовали.
#   Разбор показал сразу три причины:
#     * ~/.config/gtk-4.0/gtk.css у тем, поставленных с флагом -l, это СИМЛИНК
#       внутрь темы — правки уезжали в саму тему;
#     * свойство -gtk-icon-size существует ТОЛЬКО в GTK4, в GTK3 его нет,
#       поэтому значок там не увеличивался ни при каких значениях;
#     * ошибки разбора в самой теме (No property named "--accent-color")
#       сыпались до нашего блока.
#
#   Здесь тема копируется в ИМЯ-Square, правила дописываются в САМЫЙ КОНЕЦ
#   её собственных файлов, и система переключается на копию. Оригинал не
#   трогается вовсе, пользовательский css не трогается вовсе, спорить со
#   специфичностью не с кем.
#
# ЧТО НЕ ТРОГАЕТСЯ: оригинальная тема, цветовая схема, тема оболочки,
# иконки папок, обои, панель, conky, ~/.config/gtk-*.
#
# Chrome, Tabby и Telegram не изменятся: это Electron, они рисуют себя сами.

set -uo pipefail

BTN_W=46
BTN_H=34
BTN_ICO=24
DO_CORNERS=1
FONT=""
MODE="apply"

while [ $# -gt 0 ]; do
    case "$1" in
        --no-corners) DO_CORNERS=0; shift ;;
        --size)       BTN_W="${2:-46}"; BTN_H="${3:-34}"; BTN_ICO="${4:-24}"; shift 4 ;;
        --font)       FONT="${2:-}"; shift 2 ;;
        --check)      MODE="check"; shift ;;
        --revert)     MODE="revert"; shift ;;
        -h|--help)    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "неизвестный аргумент: $1"; echo "подсказка: $0 --help"; exit 1 ;;
    esac
done

STATE="$HOME/.local/state"
BEFORE="$STATE/look-before.env"
SUFFIX="-Square"
FLUENT="https://raw.githubusercontent.com/vinceliuice/Fluent-icon-theme/master/src/symbolic/actions"

ok()  { echo "  ✓ $*"; }
bad() { echo "  ✗ $*"; }

gi_get() { gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | tr -d "'"; }
gi_set() { gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null; }

CUR_GTK=$(gi_get gtk-theme)
CUR_ICON=$(gi_get icon-theme)

BASE_GTK="$CUR_GTK"
case "$CUR_GTK" in *"$SUFFIX") BASE_GTK="${CUR_GTK%$SUFFIX}" ;; esac
BASE_ICON="$CUR_ICON"
case "$CUR_ICON" in *-Fluent-Titlebar) BASE_ICON="${CUR_ICON%-Fluent-Titlebar}" ;; esac

NEW_GTK="$BASE_GTK$SUFFIX"
NEW_ICON="$BASE_ICON-Fluent-Titlebar"
THEME_DIR="$HOME/.themes/$NEW_GTK"
ICON_DIR="$HOME/.local/share/icons/$NEW_ICON"

# где лежит исходная тема
find_theme() {
    for d in "$HOME/.themes/$1" "$HOME/.local/share/themes/$1" "/usr/share/themes/$1"; do
        if [ -d "$d" ]; then
            echo "$d"
            return
        fi
    done
}

# ---------------------------------------------------------------- откат

if [ "$MODE" = "revert" ]; then
    echo "==> откат"

    if [ -f "$BEFORE" ]; then
        . "$BEFORE"
        if [ -n "${GTK_WAS:-}" ]; then
            gi_set gtk-theme "$GTK_WAS"
            ok "тема окон: $GTK_WAS"
        fi
        if [ -n "${ICON_WAS:-}" ]; then
            gi_set icon-theme "$ICON_WAS"
            ok "тема иконок: $ICON_WAS"
        fi
        if [ -n "${FONT_WAS:-}" ]; then
            gi_set font-name "$FONT_WAS"
            ok "шрифт: $FONT_WAS"
        fi
        rm -f "$BEFORE"
    else
        gi_set gtk-theme "$BASE_GTK"
        gi_set icon-theme "$BASE_ICON"
        ok "вернул: тема $BASE_GTK, иконки $BASE_ICON"
    fi

    if [ -d "$THEME_DIR" ]; then
        rm -rf "$THEME_DIR"
        ok "копия темы удалена: $THEME_DIR"
    fi
    if [ -d "$ICON_DIR" ]; then
        rm -rf "$ICON_DIR"
        ok "тема значков удалена"
    fi

    if command -v nautilus >/dev/null 2>&1; then
        nautilus -q >/dev/null 2>&1
    fi
    echo
    echo "готово. Пользовательский ~/.config/gtk-* не трогался ни разу."
    exit 0
fi

# ---------------------------------------------------------------- состояние

if [ "$MODE" = "check" ]; then
    echo "==> состояние"
    echo "  тема окон:    $CUR_GTK"
    echo "  тема иконок:  $CUR_ICON"
    echo "  шрифт:        $(gi_get font-name)"
    if [ -d "$THEME_DIR" ]; then
        if grep -q 'squarebuttons-begin' "$THEME_DIR/gtk-3.0/gtk.css" 2>/dev/null; then
            ok "копия темы на месте, правила внутри неё"
            grep -m1 'min-width' "$THEME_DIR/gtk-3.0/gtk.css" | sed 's/^/     GTK3: /'
        else
            bad "копия темы есть, но правил в ней нет"
        fi
        if grep -q 'squarebuttons-begin' "$THEME_DIR/gtk-4.0/gtk.css" 2>/dev/null; then
            grep -m1 'gtk-icon-size' "$THEME_DIR/gtk-4.0/gtk.css" | sed 's/^/     GTK4: /'
        else
            bad "в GTK4-части копии правил нет"
        fi
    else
        bad "копии темы нет — правки не применялись"
    fi
    if [ -d "$ICON_DIR" ]; then
        ok "значков Fluent: $(ls "$ICON_DIR/symbolic/actions" 2>/dev/null | wc -l) из 4"
    else
        bad "значки не подменены"
    fi
    exit 0
fi

# ---------------------------------------------------------------- применение

for v in "$BTN_W" "$BTN_H" "$BTN_ICO"; do
    if ! echo "$v" | grep -qE '^[0-9]+$'; then
        bad "размеры — числа: $0 --size 46 34 24"
        exit 1
    fi
done

mkdir -p "$STATE"
if [ ! -f "$BEFORE" ]; then
    # значения в кавычках: в именах шрифтов есть пробелы, и без них
    # строка FONT_WAS=Ubuntu Sans 11 при чтении разваливается на команду
    {
        echo "GTK_WAS='$CUR_GTK'"
        echo "ICON_WAS='$CUR_ICON'"
        echo "FONT_WAS='$(gi_get font-name)'"
    } > "$BEFORE"
    ok "запомнил исходное: тема $CUR_GTK, иконки $CUR_ICON"
fi

# --- 1. копия темы ----------------------------------------------------
echo "==> копия темы"
SRC_THEME=$(find_theme "$BASE_GTK")
if [ -z "$SRC_THEME" ]; then
    bad "не нашёл тему $BASE_GTK ни в ~/.themes, ни в /usr/share/themes"
    exit 1
fi
ok "исходная тема: $SRC_THEME"

rm -rf "$THEME_DIR"
mkdir -p "$HOME/.themes"
cp -r "$SRC_THEME" "$THEME_DIR"

# копия должна называть себя по-новому, иначе GNOME путается
if [ -f "$THEME_DIR/index.theme" ]; then
    sed -i "s|^Name=.*|Name=$NEW_GTK|" "$THEME_DIR/index.theme"
    sed -i "s|^GtkTheme=.*|GtkTheme=$NEW_GTK|" "$THEME_DIR/index.theme"
    sed -i "s|^MetacityTheme=.*|MetacityTheme=$NEW_GTK|" "$THEME_DIR/index.theme"
fi
ok "копия: $THEME_DIR"

# --- 2. правила в конец файлов копии ----------------------------------
echo "==> правила кнопок и углов"

# GTK3 не знает -gtk-icon-size: значок масштабируется трансформацией
SCALE=$(awk "BEGIN{printf \"%.2f\", $BTN_ICO/16}")

CORNERS3=""
CORNERS4=""
if [ "$DO_CORNERS" -eq 1 ]; then
    CORNERS3="
decoration,
decoration:backdrop,
window.csd,
window.background,
.titlebar,
headerbar,
headerbar.titlebar,
menu,
.menu,
.context-menu,
popover.background,
tooltip,
tooltip.background {
  border-radius: 0 !important;
}
"
    CORNERS4="
window,
window.csd,
window.background,
.background,
headerbar,
.titlebar,
popover > contents,
popover > arrow,
tooltip,
.card,
.toolbar {
  border-radius: 0 !important;
}
"
fi

mkdir -p "$THEME_DIR/gtk-3.0" "$THEME_DIR/gtk-4.0"
touch "$THEME_DIR/gtk-3.0/gtk.css" "$THEME_DIR/gtk-4.0/gtk.css"

cat >> "$THEME_DIR/gtk-3.0/gtk.css" <<EOF

/* squarebuttons-begin
   Дописано в самый конец файла темы: спорить со специфичностью не с кем.
   В GTK3 НЕТ свойства -gtk-icon-size, поэтому значок увеличивается
   трансформацией -gtk-icon-transform. */
headerbar button.titlebutton,
.titlebar button.titlebutton,
button.titlebutton {
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

headerbar button.titlebutton image,
.titlebar button.titlebutton image,
button.titlebutton image {
  -gtk-icon-transform: scale(${SCALE}) !important;
}

headerbar button.titlebutton:hover,
.titlebar button.titlebutton:hover,
button.titlebutton:hover {
  background-color: alpha(currentColor, 0.14) !important;
  background-image: none !important;
  border-radius: 0 !important;
}

headerbar button.titlebutton:active,
.titlebar button.titlebutton:active,
button.titlebutton:active {
  background-color: alpha(currentColor, 0.24) !important;
  border-radius: 0 !important;
}

headerbar button.titlebutton.close:hover,
.titlebar button.titlebutton.close:hover,
button.titlebutton.close:hover {
  background-color: #e81123 !important;
  background-image: none !important;
  color: #ffffff !important;
  border-radius: 0 !important;
}

headerbar button.titlebutton.close:active,
.titlebar button.titlebutton.close:active,
button.titlebutton.close:active {
  background-color: #c50f1f !important;
  color: #ffffff !important;
  border-radius: 0 !important;
}
$CORNERS3
/* squarebuttons-end */
EOF

cat >> "$THEME_DIR/gtk-4.0/gtk.css" <<EOF

/* squarebuttons-begin
   В GTK4 узел называется windowcontrols, и здесь -gtk-icon-size работает. */
windowcontrols > button,
windowcontrols button,
headerbar windowcontrols > button {
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
}

windowcontrols > button > image,
windowcontrols button image {
  -gtk-icon-size: ${BTN_ICO}px !important;
  min-width: ${BTN_ICO}px !important;
  min-height: ${BTN_ICO}px !important;
}

windowcontrols > button:hover,
windowcontrols button:hover {
  background-color: alpha(currentColor, 0.14) !important;
  background-image: none !important;
  border-radius: 0 !important;
}

windowcontrols > button:active,
windowcontrols button:active {
  background-color: alpha(currentColor, 0.24) !important;
  border-radius: 0 !important;
}

windowcontrols > button.close:hover,
windowcontrols button.close:hover {
  background-color: #e81123 !important;
  background-image: none !important;
  color: #ffffff !important;
  border-radius: 0 !important;
}

windowcontrols > button.close:active,
windowcontrols button.close:active {
  background-color: #c50f1f !important;
  color: #ffffff !important;
  border-radius: 0 !important;
}
$CORNERS4
/* squarebuttons-end */
EOF

ok "кнопка ${BTN_W}x${BTN_H}px, значок ${BTN_ICO}px (GTK3 через scale ${SCALE})"
if [ "$DO_CORNERS" -eq 1 ]; then
    ok "углы окон, меню и подсказок сделаны острыми"
fi

# --- 3. значки Fluent -------------------------------------------------
echo "==> значки Fluent"
SRC_ICON=""
for d in "$HOME/.local/share/icons/$BASE_ICON" "$HOME/.icons/$BASE_ICON" \
         "/usr/share/icons/$BASE_ICON"; do
    if [ -d "$d" ]; then
        SRC_ICON="$d"
    fi
done

if [ -z "$SRC_ICON" ]; then
    bad "темы иконок $BASE_ICON нет — значки оставляю прежними"
else
    rm -rf "$ICON_DIR"
    mkdir -p "$ICON_DIR/symbolic/actions"
    GOT=0
    for n in close maximize minimize restore; do
        F="$ICON_DIR/symbolic/actions/window-$n-symbolic.svg"
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
        bad "скачалось $GOT из 4 — значки оставляю прежними"
        rm -rf "$ICON_DIR"
    else
        cat > "$ICON_DIR/index.theme" <<EOF
[Icon Theme]
Name=$NEW_ICON
Comment=$BASE_ICON с кнопками заголовка из Fluent
Inherits=$BASE_ICON,Adwaita,hicolor
Directories=symbolic/actions

[symbolic/actions]
Size=16
MinSize=8
MaxSize=512
Context=Actions
Type=Scalable
EOF
        gtk-update-icon-cache -f "$ICON_DIR" >/dev/null 2>&1
        gi_set icon-theme "$NEW_ICON"
        ok "значки Fluent поверх $BASE_ICON"
    fi
fi

# --- 4. шрифт ---------------------------------------------------------
if [ -n "$FONT" ]; then
    echo "==> шрифт интерфейса"
    NAME=$(echo "$FONT" | sed 's/ [0-9]*$//')
    if fc-list 2>/dev/null | grep -qi "$NAME"; then
        gi_set font-name "$FONT"
        ok "шрифт: $FONT"
    else
        bad "шрифта '$NAME' в системе нет — не менял"
    fi
fi

# --- 5. переключаемся -------------------------------------------------
echo "==> переключение"
gi_set gtk-theme "$NEW_GTK"
ok "тема окон: $NEW_GTK"

if command -v nautilus >/dev/null 2>&1; then
    nautilus -q >/dev/null 2>&1
    ok "Nautilus закрыт — откроется с новым видом"
fi

# --- 6. что реально применилось ---------------------------------------
echo
echo "==> проверка"
echo "  тема окон:    $(gi_get gtk-theme)"
echo "  тема иконок:  $(gi_get icon-theme)"
echo "  правил в GTK3: $(grep -c '!important' "$THEME_DIR/gtk-3.0/gtk.css" 2>/dev/null)"
echo "  правил в GTK4: $(grep -c '!important' "$THEME_DIR/gtk-4.0/gtk.css" 2>/dev/null)"

python3 - "$NEW_ICON" <<'PY' 2>/dev/null
import sys
try:
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk
except Exception:
    raise SystemExit(0)
theme = Gtk.IconTheme.new()
theme.set_custom_theme(sys.argv[1])
for name in ('window-close-symbolic', 'window-minimize-symbolic'):
    info = theme.lookup_icon(name, 16, 0)
    print('  %-26s %s' % (name, info.get_filename() if info else 'НЕ НАЙДЕНА'))
PY

echo
echo "Открой папку заново. Если вид не изменился — перелогинься:"
echo "оболочка кэширует тему до перезапуска сессии."
echo
echo "состояние:  $0 --check"
echo "крупнее:    $0 --size 52 38 28"
echo "вернуть:    $0 --revert"
