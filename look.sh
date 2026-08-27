#!/usr/bin/env bash
# Кнопки заголовка, углы окон и виджет conky.
#
#   ./look.sh                     кнопки + острые углы
#   ./look.sh --size 46 34 20     ширина, высота кнопки, размер значка (GTK4)
#   ./look.sh --gtk3-scale 1.0    масштаб значка в GTK3, 1.0 = чётко
#   ./look.sh --window-radius 6   скругление углов окон, 0 = острые
#   ./look.sh --widget 12         скруглить виджет conky
#   ./look.sh --font "Selawik 11" шрифт интерфейса
#   ./look.sh --import-theme      подключить тему в GTK4 (по умолчанию нет)
#   ./look.sh --selftest          проверка: значки станут ярко-зелёными
#   ./look.sh --check             что сейчас применено
#   ./look.sh --revert            вернуть всё как было
#
# ГЛАВНОЕ, ЧТО ВЫЯСНИЛОСЬ ДОРОГОЙ ЦЕНОЙ:
#
#   GTK НЕ ПОДДЕРЖИВАЕТ !important. Парсер считает его мусором в конце
#   значения и отбрасывает ПРАВИЛО ЦЕЛИКОМ:
#
#     Theme parser error: gtk.css:10:19-20: Junk at end of value for min-width
#
#   Именно поэтому ни одна из прошлых попыток не действовала, хотя файлы
#   писались верно и в верные места. Ни Fluent, ни Graphite, ни libadwaita
#   не используют !important ни в одной строке — теперь понятно, почему.
#
#   Он и не нужен: ~/.config/gtk-3.0/gtk.css и gtk-4.0/gtk.css грузятся с
#   приоритетом USER, а тема — с THEME, который ниже. При равной
#   специфичности пользовательское правило выигрывает само.
#
#   Отсюда: никакого !important, никакой копии темы; тема GTK и цветовая
#   схема не трогаются вовсе.
#
#   ПРО РАЗМЕР ЗНАЧКА. В GTK4 он задаётся до отрисовки (-gtk-icon-size),
#   поэтому получается чётким при любом значении. В GTK3 такого свойства
#   НЕТ: там иконка сперва растеризуется в 16px, а -gtk-icon-transform
#   растягивает уже готовый растр — отсюда пикселизация при масштабе
#   больше ~1.3. Поэтому масштаб GTK3 вынесен отдельным флагом и по
#   умолчанию равен 1.0: в терминале значок останется мелким, но чётким.
#
#   В libadwaita фон и круг рисует НЕ кнопка, а её дочерний image:
#     > image { background-color: $button_color; border-radius: 100%; }
#     &:hover > image { background-color: $button_hover_color; }
#   Сама кнопка всегда background: none. Поэтому целимся в image.
#
# Chrome, Tabby и Telegram не изменятся: это Electron, они рисуют себя сами.

set -uo pipefail

BTN_W=46
BTN_H=34
BTN_ICO=20
GTK3_SCALE=1.0
WIN_RADIUS=0
DO_CORNERS=1
IMPORT_THEME=0
SELFTEST=0
WIDGET=""
FONT=""
MODE="apply"

while [ $# -gt 0 ]; do
    case "$1" in
        --size)          BTN_W="${2:-46}"; BTN_H="${3:-34}"; BTN_ICO="${4:-20}"; shift 4 ;;
        --gtk3-scale)    GTK3_SCALE="${2:-1.0}"; shift 2 ;;
        --window-radius) WIN_RADIUS="${2:-0}"; shift 2 ;;
        --no-corners)    DO_CORNERS=0; shift ;;
        --widget)        WIDGET="${2:-12}"; shift 2 ;;
        --font)          FONT="${2:-}"; shift 2 ;;
        --import-theme)  IMPORT_THEME=1; shift ;;
        --selftest)      SELFTEST=1; shift ;;
        --check)         MODE="check"; shift ;;
        --revert)        MODE="revert"; shift ;;
        -h|--help)       sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "неизвестный аргумент: $1"; echo "подсказка: $0 --help"; exit 1 ;;
    esac
done

STATE="$HOME/.local/state"
BEFORE="$STATE/look-before.env"
CSS3="$HOME/.config/gtk-3.0/gtk.css"
CSS4="$HOME/.config/gtk-4.0/gtk.css"
BAK3="$HOME/.config/gtk-3.0/gtk.css.bak-look"
BAK4="$HOME/.config/gtk-4.0/gtk.css.bak-look"
CONKY_DIR="$HOME/.config/conky"
CONKY_CONF="$CONKY_DIR/main.conf"
CONKY_BAK="$CONKY_DIR/main.conf.bak-look"
LUA="$CONKY_DIR/rounded.lua"
FLUENT="https://raw.githubusercontent.com/vinceliuice/Fluent-icon-theme/master/src/symbolic/actions"

ok()  { echo "  ✓ $*"; }
bad() { echo "  ✗ $*"; }

gi_get() { gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | tr -d "'"; }
gi_set() { gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null; }

CUR_ICON=$(gi_get icon-theme)
BASE_ICON="$CUR_ICON"
case "$CUR_ICON" in *-Fluent-Titlebar) BASE_ICON="${CUR_ICON%-Fluent-Titlebar}" ;; esac
if [ -z "$BASE_ICON" ]; then
    BASE_ICON="Adwaita"
fi
NEW_ICON="$BASE_ICON-Fluent-Titlebar"
ICON_DIR="$HOME/.local/share/icons/$NEW_ICON"

strip_ours() {
    if [ -f "$1" ]; then
        sed -i '/look-begin/,/look-end/d' "$1"
        sed -i '/selftest-begin/,/selftest-end/d' "$1"
    fi
}

restart_conky() {
    if command -v conky >/dev/null 2>&1; then
        pkill -x conky >/dev/null 2>&1
        sleep 1
        nohup conky -c "$CONKY_CONF" >/dev/null 2>&1 &
        sleep 1
        if pgrep -x conky >/dev/null 2>&1; then
            ok "conky перезапущен"
        fi
    fi
}

restart_apps() {
    if command -v nautilus >/dev/null 2>&1; then
        nautilus -q >/dev/null 2>&1
        ok "Nautilus закрыт — откроется с новым видом"
    fi
    if pgrep -x gnome-terminal-server >/dev/null 2>&1; then
        bad "gnome-terminal-server работает — терминал не увидит правок"
        echo "     закрой его (все вкладки закроются): pkill -x gnome-terminal-server"
    fi
}

# ---------------------------------------------------------------- откат

if [ "$MODE" = "revert" ]; then
    echo "==> откат"

    for pair in "$CSS3:$BAK3" "$CSS4:$BAK4"; do
        F="${pair%%:*}"
        B="${pair##*:}"
        HAVE=0
        if [ -e "$B" ]; then HAVE=1; fi
        if [ -L "$B" ]; then HAVE=1; fi
        if [ "$HAVE" = "1" ]; then
            rm -f "$F"
            mv "$B" "$F"
            ok "$F восстановлен"
        elif [ -f "$F" ]; then
            strip_ours "$F"
            if [ ! -s "$F" ]; then
                rm -f "$F"
            fi
            ok "наши правила убраны из $F"
        fi
    done

    if [ -d "$ICON_DIR" ]; then
        rm -rf "$ICON_DIR"
        ok "тема значков удалена"
    fi

    if [ -f "$BEFORE" ]; then
        . "$BEFORE"
        if [ -n "${ICON_WAS:-}" ]; then
            gi_set icon-theme "$ICON_WAS"
            ok "тема иконок: $ICON_WAS"
        fi
        if [ -n "${FONT_WAS:-}" ]; then
            gi_set font-name "$FONT_WAS"
            ok "шрифт: $FONT_WAS"
        fi
        rm -f "$BEFORE"
    fi

    if [ -f "$CONKY_BAK" ]; then
        mv "$CONKY_BAK" "$CONKY_CONF"
        rm -f "$LUA"
        ok "конфиг conky восстановлен"
        restart_conky
    fi

    restart_apps
    echo
    echo "тема GTK и цветовая схема не трогались ни разу."
    exit 0
fi

# ---------------------------------------------------------------- состояние

if [ "$MODE" = "check" ]; then
    echo "==> состояние"
    echo "  тема окон:    $(gi_get gtk-theme)  (не трогается)"
    echo "  тема иконок:  $CUR_ICON"
    echo "  шрифт:        $(gi_get font-name)"
    for F in "$CSS3" "$CSS4"; do
        if grep -q 'look-begin' "$F" 2>/dev/null; then
            ok "правила в $F"
            sed -n '/look-begin/,/look-end/p' "$F" | grep -m1 'min-width' | sed 's/^/       /'
        else
            bad "правил нет в $F"
        fi
        if grep -q '!important' "$F" 2>/dev/null; then
            bad "в $F есть !important — GTK его не понимает"
        fi
    done
    if [ -d "$ICON_DIR" ]; then
        ok "значков Fluent: $(ls "$ICON_DIR/symbolic/actions" 2>/dev/null | wc -l) из 4"
    else
        bad "значки не подменены"
    fi
    if [ -f "$LUA" ]; then
        ok "виджет скруглён: $(grep -m1 'local RADIUS' "$LUA" | tr -d ' ')"
    fi
    exit 0
fi

# ---------------------------------------------------------------- применение

for v in "$BTN_W" "$BTN_H" "$BTN_ICO" "$WIN_RADIUS"; do
    if ! echo "$v" | grep -qE '^[0-9]+$'; then
        bad "размеры и радиус — числа: $0 --size 52 38 30"
        exit 1
    fi
done

mkdir -p "$STATE" "$(dirname "$CSS3")" "$(dirname "$CSS4")"
if [ ! -f "$BEFORE" ]; then
    {
        echo "ICON_WAS='$CUR_ICON'"
        echo "FONT_WAS='$(gi_get font-name)'"
    } > "$BEFORE"
    ok "запомнил исходное: иконки $CUR_ICON"
fi

# --- 1. бэкап пользовательских файлов ---------------------------------
for pair in "$CSS3:$BAK3" "$CSS4:$BAK4"; do
    F="${pair%%:*}"
    B="${pair##*:}"
    HAVE=0
    if [ -e "$B" ]; then HAVE=1; fi
    if [ -L "$B" ]; then HAVE=1; fi
    if [ "$HAVE" = "0" ]; then
        if [ -L "$F" ]; then
            cp -P "$F" "$B"
            ok "исходный симлинк сохранён: $(basename "$B")"
        elif [ -f "$F" ]; then
            if ! grep -q 'look-begin' "$F"; then
                cp "$F" "$B"
                ok "исходный файл сохранён: $(basename "$B")"
            fi
        fi
    fi
done

# --- 2. GTK4: симлинк темы --------------------------------------------
IMPORT_LINE=""
if [ -L "$CSS4" ]; then
    TARGET=$(readlink -f "$CSS4")
    rm -f "$CSS4"
    if [ "$IMPORT_THEME" = "1" ]; then
        IMPORT_LINE="@import url(\"file://$TARGET\");"
    fi
fi
touch "$CSS3" "$CSS4"
strip_ours "$CSS3"
strip_ours "$CSS4"

if [ -n "$IMPORT_LINE" ]; then
    if ! grep -q '@import' "$CSS4"; then
        printf '%s\n' "$IMPORT_LINE" > "$CSS4.new"
        cat "$CSS4" >> "$CSS4.new"
        mv "$CSS4.new" "$CSS4"
        ok "тема подключена импортом"
    fi
else
    ok "тема в GTK4 не подключается: окна берут вид Adwaita"
fi

# --- 3. правила -------------------------------------------------------
echo "==> правила"
echo "     без !important: GTK его не понимает и выбрасывает всё правило"

# GTK3: масштаб задаётся явно, а не выводится из размера значка —
# растягивание готового растра выше ~1.3 даёт заметные пиксели
SCALE="$GTK3_SCALE"
if ! echo "$SCALE" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
    bad "масштаб — число, например 1.0 или 1.25"
    exit 1
fi

CORNERS3=""
CORNERS4=""
if [ "$DO_CORNERS" = "1" ]; then
    CORNERS3="
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
  border-radius: ${WIN_RADIUS}px;
}
"
    CORNERS4="
window,
window.csd,
window.background,
headerbar,
.titlebar,
popover > contents,
tooltip,
.card,
.toolbar {
  border-radius: ${WIN_RADIUS}px;
}
"
fi

cat >> "$CSS3" <<EOF

/* look-begin */
headerbar button.titlebutton,
.titlebar button.titlebutton,
button.titlebutton {
  min-width: ${BTN_W}px;
  min-height: ${BTN_H}px;
  padding: 0;
  margin: 0;
  background-image: none;
  box-shadow: none;
  border: none;
  border-radius: 0;
}

headerbar button.titlebutton image,
.titlebar button.titlebutton image,
button.titlebutton image {
  -gtk-icon-transform: scale(${SCALE});
  min-width: ${BTN_ICO}px;
  min-height: ${BTN_ICO}px;
  background-color: transparent;
  background-image: none;
  border-radius: 0;
  padding: 0;
  box-shadow: none;
}

headerbar button.titlebutton:hover,
.titlebar button.titlebutton:hover,
button.titlebutton:hover {
  background-color: alpha(currentColor, 0.14);
  background-image: none;
  border-radius: 0;
}

headerbar button.titlebutton:hover image,
.titlebar button.titlebutton:hover image,
button.titlebutton:hover image {
  background-color: transparent;
  border-radius: 0;
}

headerbar button.titlebutton.close:hover,
.titlebar button.titlebutton.close:hover,
button.titlebutton.close:hover {
  background-color: #e81123;
  background-image: none;
  color: #ffffff;
  border-radius: 0;
}

headerbar button.titlebutton.close:hover image,
button.titlebutton.close:hover image {
  background-color: transparent;
  color: #ffffff;
}

headerbar button.titlebutton:active,
button.titlebutton:active {
  background-color: alpha(currentColor, 0.24);
  border-radius: 0;
}

headerbar button.titlebutton.close:active,
button.titlebutton.close:active {
  background-color: #c50f1f;
  color: #ffffff;
}
$CORNERS3
/* look-end */
EOF

cat >> "$CSS4" <<EOF

/* look-begin */
windowcontrols > button,
headerbar windowcontrols > button {
  min-width: ${BTN_W}px;
  min-height: ${BTN_H}px;
  padding: 0;
  margin: 0;
  background-image: none;
  box-shadow: none;
  border: none;
  border-radius: 0;
}

windowcontrols > button > image {
  background-color: transparent;
  background-image: none;
  border-radius: 0;
  padding: 0;
  margin: 0;
  box-shadow: none;
  -gtk-icon-size: ${BTN_ICO}px;
}

windowcontrols > button:hover {
  background-color: alpha(currentColor, 0.14);
  background-image: none;
  border-radius: 0;
}

windowcontrols > button:hover > image {
  background-color: transparent;
  border-radius: 0;
}

windowcontrols > button:active {
  background-color: alpha(currentColor, 0.24);
  border-radius: 0;
}

windowcontrols > button:active > image {
  background-color: transparent;
  border-radius: 0;
}

windowcontrols > button.close:hover {
  background-color: #e81123;
  background-image: none;
  border-radius: 0;
}

windowcontrols > button.close:hover > image {
  background-color: transparent;
  color: #ffffff;
  border-radius: 0;
}

windowcontrols > button.close:active {
  background-color: #c50f1f;
  border-radius: 0;
}

windowcontrols > button.close:active > image {
  background-color: transparent;
  color: #ffffff;
}
$CORNERS4
/* look-end */
EOF

ok "кнопка ${BTN_W}x${BTN_H}px, значок ${BTN_ICO}px (GTK4), масштаб GTK3 ${SCALE}"
if [ "$DO_CORNERS" = "1" ]; then
    ok "радиус окон: ${WIN_RADIUS}px"
fi

# --- 4. самотест ------------------------------------------------------
if [ "$SELFTEST" = "1" ]; then
    for F in "$CSS3" "$CSS4"; do
        cat >> "$F" <<'TESTEOF'

/* selftest-begin */
windowcontrols > button > image,
headerbar button.titlebutton image,
button.titlebutton image {
  background-color: #00ff00;
  border-radius: 0;
}
/* selftest-end */
TESTEOF
    done
    ok "маркер записан — значки должны стать ярко-зелёными"
    echo "     убрать: обычный запуск $0"
fi

# --- 5. значки Fluent -------------------------------------------------
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

# --- 6. виджет conky --------------------------------------------------
if [ -n "$WIDGET" ]; then
    echo "==> виджет conky (радиус ${WIDGET}px)"
    if ! echo "$WIDGET" | grep -qE '^[0-9]+$'; then
        bad "радиус — число: $0 --widget 12"
        exit 1
    fi
    if [ ! -f "$CONKY_CONF" ]; then
        bad "конфига нет: $CONKY_CONF"
    else
        COLOUR=$(grep -oP "own_window_colour\s*=\s*'\K[0-9a-fA-F]{6}" "$CONKY_CONF" | head -1)
        if [ -z "$COLOUR" ]; then
            COLOUR="1e1e2e"
        fi
        ALPHA=$(grep -oP "own_window_argb_value\s*=\s*\K[0-9]+" "$CONKY_CONF" | head -1)
        if [ -z "$ALPHA" ]; then
            ALPHA=225
        fi
        if [ "$ALPHA" = "0" ]; then
            ALPHA=225
        fi

        R_HEX="${COLOUR:0:2}"
        G_HEX="${COLOUR:2:2}"
        B_HEX="${COLOUR:4:2}"
        RF=$(awk "BEGIN{printf \"%.3f\", $((16#$R_HEX))/255}")
        GF=$(awk "BEGIN{printf \"%.3f\", $((16#$G_HEX))/255}")
        BF=$(awk "BEGIN{printf \"%.3f\", $((16#$B_HEX))/255}")
        AF=$(awk "BEGIN{printf \"%.3f\", $ALPHA/255}")

        cat > "$LUA" <<LUAEOF
-- Скруглённый фон для conky: своего border-radius у него нет.
require 'cairo'

local RADIUS = $WIDGET
local R, G, B, A = $RF, $GF, $BF, $AF

function conky_draw_bg()
    if conky_window == nil then
        return
    end

    local w = conky_window.width
    local h = conky_window.height
    local r = RADIUS
    if r * 2 > w then r = w / 2 end
    if r * 2 > h then r = h / 2 end

    local surface = cairo_xlib_surface_create(conky_window.display,
        conky_window.drawable, conky_window.visual, w, h)
    local cr = cairo_create(surface)

    cairo_new_path(cr)
    cairo_move_to(cr, r, 0)
    cairo_line_to(cr, w - r, 0)
    cairo_arc(cr, w - r, r, r, -math.pi / 2, 0)
    cairo_line_to(cr, w, h - r)
    cairo_arc(cr, w - r, h - r, r, 0, math.pi / 2)
    cairo_line_to(cr, r, h)
    cairo_arc(cr, r, h - r, r, math.pi / 2, math.pi)
    cairo_line_to(cr, 0, r)
    cairo_arc(cr, r, r, r, math.pi, 3 * math.pi / 2)
    cairo_close_path(cr)

    cairo_set_source_rgba(cr, R, G, B, A)
    cairo_fill(cr)

    cairo_destroy(cr)
    cairo_surface_destroy(surface)
end
LUAEOF
        ok "рисовалка фона: $LUA"

        if [ ! -f "$CONKY_BAK" ]; then
            cp "$CONKY_CONF" "$CONKY_BAK"
            ok "резервная копия конфига"
        fi

        sed -i "s|own_window_argb_value = [0-9]*|own_window_argb_value = 0|" "$CONKY_CONF"
        if grep -q 'lua_load' "$CONKY_CONF"; then
            sed -i "s|lua_load = '[^']*'|lua_load = '$LUA'|" "$CONKY_CONF"
        else
            sed -i "0,/conky.config = {/s|conky.config = {|conky.config = {\n    lua_load = '$LUA',|" "$CONKY_CONF"
        fi
        if ! grep -q 'lua_draw_hook_pre' "$CONKY_CONF"; then
            sed -i "s|lua_load = '$LUA',|lua_load = '$LUA',\n    lua_draw_hook_pre = 'draw_bg',|" "$CONKY_CONF"
        fi
        ok "конфиг conky обновлён"
        restart_conky
    fi
fi

# --- 7. шрифт ---------------------------------------------------------
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

restart_apps

echo
echo "==> проверка"
BADIMP=0
for F in "$CSS3" "$CSS4"; do
    if grep -q '!important' "$F" 2>/dev/null; then
        bad "$F содержит !important — GTK отбросит эти правила"
        BADIMP=1
    fi
done
if [ "$BADIMP" = "0" ]; then
    ok "в правилах нет !important — парсер их примет"
fi

echo
echo "состояние:  $0 --check"
echo "вернуть:    $0 --revert"
