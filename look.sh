#!/usr/bin/env bash
# Внешний вид окон одним скриптом: кнопки заголовка как в Windows,
# острые углы у окон, скруглённый виджет conky.
#
#   ./look.sh                   всё сразу
#   ./look.sh --buttons         только кнопки заголовка
#   ./look.sh --corners         только углы окон
#   ./look.sh --widget 20       только виджет, радиус 20px
#   ./look.sh --size 52 38 28   размер кнопок: ширина, высота, значок
#   ./look.sh --font "JetBrainsMono Nerd Font 11"   шрифт интерфейса
#   ./look.sh --check           ничего не менять, показать состояние
#   ./look.sh --diag            почему css мог не примениться
#   ./look.sh --revert          вернуть всё как было
#
# Тема GTK, цветовая схема, папки, обои и панель НЕ трогаются.
#
# Что и почему делается:
#
#   Кнопки. Форму значка даёт тема иконок, размер и подложку — тема GTK.
#   Поэтому создаётся тема ИМЯ-Fluent-Titlebar: наследует текущую целиком,
#   переопределяет ровно четыре значка из Fluent. Размер и квадратная
#   подсветка пишутся в gtk.css, каждое свойство с !important — правило
#   темы button.titlebutton:not(.suggested-action):not(.destructive-action)
#   специфичнее пользовательского, и без !important подложка остаётся
#   круглой, сколько её ни переопределяй.
#
#   Углы. Скругление задаёт тема, снимается тем же способом.
#
#   Виджет. У conky радиуса нет вовсе, поэтому подложку рисует Lua через
#   Cairo, а собственное окно conky делается прозрачным. Цвет и плотность
#   берутся из текущего конфига, сам конфиг сохраняется рядом.
#
# Chrome, Tabby и Telegram не изменятся: это Electron, они рисуют себя сами.

set -uo pipefail

# части выключены; если ни одна не названа явно, включаются все три
DO_BUTTONS=0
DO_CORNERS=0
DO_WIDGET=0
BTN_W=46
BTN_H=34
BTN_ICO=24
RADIUS=14
FONT=""
MODE="apply"
PICKED=0
STATE="$HOME/.local/state"
BEFORE="$STATE/look-before.env"

while [ $# -gt 0 ]; do
    case "$1" in
        --buttons) DO_BUTTONS=1; PICKED=1; shift ;;
        --corners) DO_CORNERS=1; PICKED=1; shift ;;
        --widget)  DO_WIDGET=1; PICKED=1; RADIUS="${2:-14}"; shift 2 ;;
        --size)    BTN_W="${2:-46}"; BTN_H="${3:-34}"; BTN_ICO="${4:-24}"; shift 4 ;;
        --font)    FONT="${2:-JetBrainsMono Nerd Font 11}"; PICKED=1; shift 2 ;;
        --diag)    MODE="diag"; shift ;;
        --check)   MODE="check"; shift ;;
        --revert)  MODE="revert"; shift ;;
        -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "неизвестный аргумент: $1"; echo "подсказка: $0 --help"; exit 1 ;;
    esac
done

if [ "$PICKED" -eq 0 ]; then
    DO_BUTTONS=1
    DO_CORNERS=1
    DO_WIDGET=1
fi

CSS3="$HOME/.config/gtk-3.0/gtk.css"
CSS4="$HOME/.config/gtk-4.0/gtk.css"
CONKY_DIR="$HOME/.config/conky"
CONKY_CONF="$CONKY_DIR/main.conf"
CONKY_BAK="$CONKY_DIR/main.conf.bak-look"
LUA="$CONKY_DIR/rounded.lua"
FLUENT="https://raw.githubusercontent.com/vinceliuice/Fluent-icon-theme/master/src/symbolic/actions"

ok()  { echo "  ✓ $*"; }
bad() { echo "  ✗ $*"; }

gget() { gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'"; }
gset() { gsettings set org.gnome.desktop.interface icon-theme "$1" 2>/dev/null; }
fget() { gsettings get org.gnome.desktop.interface font-name 2>/dev/null | tr -d "'"; }
fset() { gsettings set org.gnome.desktop.interface font-name "$1" 2>/dev/null; }

# GTK читает css при старте приложения: без перезапуска правки не видны
restart_apps() {
    if command -v nautilus >/dev/null 2>&1; then
        nautilus -q >/dev/null 2>&1
        ok "Nautilus закрыт — откроется уже с новым видом"
    fi
}

strip_block() {
    if [ -f "$2" ]; then
        sed -i "/$1-begin/,/$1-end/d" "$2"
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

restart_conky() {
    if command -v conky >/dev/null 2>&1; then
        pkill -x conky >/dev/null 2>&1
        sleep 1
        nohup conky -c "$CONKY_CONF" >/dev/null 2>&1 &
        sleep 1
        if pgrep -x conky >/dev/null 2>&1; then
            ok "conky перезапущен"
        else
            bad "conky не поднялся — посмотри: conky -c $CONKY_CONF"
        fi
    fi
}

# ---------------------------------------------------------------- откат

if [ "$MODE" = "revert" ]; then
    echo "==> откат"
    strip_block titlebuttons "$CSS3"
    strip_block titlebuttons "$CSS4"
    strip_block corners "$CSS3"
    strip_block corners "$CSS4"
    ok "правила из gtk.css убраны"

    case "$CUR" in
        *-Fluent-Titlebar)
            rm -rf "$HOME/.local/share/icons/$CUR"
            gset "$BASE"
            ok "тема иконок возвращена: $BASE"
            ;;
        *) ok "тема иконок и так своя: $CUR" ;;
    esac

    if [ -f "$CONKY_BAK" ]; then
        mv "$CONKY_BAK" "$CONKY_CONF"
        rm -f "$LUA"
        ok "конфиг conky восстановлен"
        restart_conky
    else
        ok "conky не трогался"
    fi

    if [ -f "$BEFORE" ]; then
        . "$BEFORE"
        if [ -n "${FONT_WAS:-}" ]; then
            fset "$FONT_WAS"
            ok "шрифт интерфейса возвращён: $FONT_WAS"
        fi
        rm -f "$BEFORE"
    fi

    restart_apps
    echo
    echo "перелогинься, чтобы применилось везде"
    exit 0
fi

# ---------------------------------------------------------------- диагностика

if [ "$MODE" = "diag" ]; then
    echo "==> файлы"
    for F in "$CSS3" "$CSS4"; do
        if [ -f "$F" ]; then
            echo "  $F — строк $(wc -l < "$F"), блоков: кнопки $(grep -c 'titlebuttons-begin' "$F"), углы $(grep -c 'corners-begin' "$F")"
        else
            echo "  $F — НЕТ"
        fi
    done

    echo
    echo "==> что GTK думает о нашем css"
    echo "  (ошибки разбора означают, что правило целиком отброшено)"
    if command -v nautilus >/dev/null 2>&1; then
        nautilus -q >/dev/null 2>&1
        sleep 1
        timeout 12 env GTK_DEBUG=css nautilus --new-window >"$HOME/.cache/look-diag.log" 2>&1 &
        sleep 6
        nautilus -q >/dev/null 2>&1
        grep -iE 'gtk.css|error|not a valid|unknown|expected' "$HOME/.cache/look-diag.log" 2>/dev/null \
            | head -20 | sed 's/^/    /'
        echo "  полный вывод: $HOME/.cache/look-diag.log"
    else
        echo "  nautilus не установлен, проверить нечем"
    fi
    exit 0
fi

# ---------------------------------------------------------------- проверка

if [ "$MODE" = "check" ]; then
    echo "==> состояние"
    echo "  тема иконок:  $CUR"
    if [ -d "$DIR" ]; then
        ok "кнопки: тема $THEME, значков $(ls "$DIR/symbolic/actions" 2>/dev/null | wc -l) из 4"
    else
        bad "кнопки не настроены"
    fi
    if grep -q 'titlebuttons-begin' "$CSS3" 2>/dev/null; then
        ok "размер кнопок прописан: $(grep -m1 'min-width' "$CSS3" | tr -d ' ;')"
    else
        bad "размер кнопок не прописан"
    fi
    if grep -q 'corners-begin' "$CSS3" 2>/dev/null; then
        ok "углы окон сделаны острыми"
    else
        bad "углы окон от темы"
    fi
    if [ -f "$LUA" ]; then
        ok "виджет скруглён: $(grep -m1 'local RADIUS' "$LUA" | tr -d ' ')"
    else
        bad "виджет не скруглён"
    fi
    echo "  шрифт интерфейса: $(fget)"
    exit 0
fi

# ---------------------------------------------------------------- кнопки

if [ "$DO_BUTTONS" -eq 1 ]; then
    echo "==> кнопки заголовка"

    for v in "$BTN_W" "$BTN_H" "$BTN_ICO"; do
        if ! echo "$v" | grep -qE '^[0-9]+$'; then
            bad "размеры — числа: $0 --size 46 34 22"
            exit 1
        fi
    done

    FOUND=""
    for d in "$HOME/.local/share/icons/$BASE" "$HOME/.icons/$BASE" "/usr/share/icons/$BASE"; do
        if [ -d "$d" ]; then
            FOUND="$d"
        fi
    done

    if [ -z "$FOUND" ]; then
        bad "темы иконок $BASE нет — кнопки пропускаю"
    else
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
            bad "значков скачалось $GOT из 4 — кнопки не менял"
            rm -rf "$DIR"
        else
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

            # GTK3 и GTK4 понимают РАЗНЫЙ набор свойств и селекторов:
            # -gtk-outline-radius и decoration есть только в GTK3, и на
            # неизвестном свойстве GTK4 отбрасывает правило целиком.
            # Поэтому блоки пишутся раздельно.
            mkdir -p "$(dirname "$CSS3")" "$(dirname "$CSS4")"
            touch "$CSS3" "$CSS4"
            strip_block titlebuttons "$CSS3"
            strip_block titlebuttons "$CSS4"

            cat >> "$CSS3" <<EOF
/* titlebuttons-begin */
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
  background-color: alpha(currentColor, 0.22) !important;
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

headerbar button.titlebutton image,
.titlebar button.titlebutton image,
button.titlebutton image {
  -gtk-icon-size: ${BTN_ICO}px !important;
}
/* titlebuttons-end */
EOF

            cat >> "$CSS4" <<EOF
/* titlebuttons-begin */
windowcontrols button,
windowcontrols > button,
headerbar windowcontrols button,
.titlebar windowcontrols button {
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

windowcontrols button:hover,
windowcontrols > button:hover,
headerbar windowcontrols button:hover {
  background-color: alpha(currentColor, 0.14) !important;
  background-image: none !important;
  border-radius: 0 !important;
}

windowcontrols button:active,
windowcontrols > button:active,
headerbar windowcontrols button:active {
  background-color: alpha(currentColor, 0.22) !important;
  border-radius: 0 !important;
}

windowcontrols button.close:hover,
windowcontrols > button.close:hover,
headerbar windowcontrols button.close:hover {
  background-color: #e81123 !important;
  background-image: none !important;
  color: #ffffff !important;
  border-radius: 0 !important;
}

windowcontrols button.close:active,
windowcontrols > button.close:active,
headerbar windowcontrols button.close:active {
  background-color: #c50f1f !important;
  color: #ffffff !important;
  border-radius: 0 !important;
}

windowcontrols button image,
windowcontrols > button image {
  -gtk-icon-size: ${BTN_ICO}px !important;
  min-width: ${BTN_ICO}px !important;
  min-height: ${BTN_ICO}px !important;
}
/* titlebuttons-end */
EOF

            gset "$THEME"
            ok "значки Fluent поверх $BASE"
            ok "кнопка ${BTN_W}x${BTN_H}px, значок ${BTN_ICO}px, подсветка квадратная"
        fi
    fi
fi

# ---------------------------------------------------------------- углы

if [ "$DO_CORNERS" -eq 1 ]; then
    echo "==> углы окон"
    mkdir -p "$(dirname "$CSS3")" "$(dirname "$CSS4")"
    touch "$CSS3" "$CSS4"
    strip_block corners "$CSS3"
    strip_block corners "$CSS4"

    # GTK3: скругление живёт в decoration и в classic-виджетах меню
    cat >> "$CSS3" <<'CSSEOF'
/* corners-begin */
decoration,
decoration:backdrop,
window.csd,
window.csd:backdrop,
window.background,
window.dialog-csd,
.background.csd,
.titlebar,
.titlebar:backdrop,
headerbar,
headerbar.titlebar,
headerbar:backdrop,
menu,
.menu,
.context-menu,
popover.background,
tooltip,
tooltip.background,
.osd {
  border-radius: 0 !important;
}
/* corners-end */
CSSEOF

    # GTK4: decoration и menu не существуют, зато есть popover > contents
    cat >> "$CSS4" <<'CSSEOF'
/* corners-begin */
window,
window.csd,
window.background,
window.dialog,
.background,
headerbar,
.titlebar,
popover > contents,
popover > arrow,
tooltip,
.card,
.osd,
.toolbar {
  border-radius: 0 !important;
}
/* corners-end */
CSSEOF
    ok "скругление снято у окон, заголовков, меню и подсказок"
fi

# ---------------------------------------------------------------- виджет

if [ "$DO_WIDGET" -eq 1 ]; then
    echo "==> виджет conky (радиус ${RADIUS}px)"

    if ! echo "$RADIUS" | grep -qE '^[0-9]+$'; then
        bad "радиус — число: $0 --widget 14"
        exit 1
    fi

    if [ ! -f "$CONKY_CONF" ]; then
        bad "конфига нет: $CONKY_CONF — виджет пропускаю"
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
            ALPHA=225      # уже применяли: берём плотность по умолчанию
        fi

        # hex в доли единицы: awk есть везде, bc и python3 — не всегда
        R_HEX="${COLOUR:0:2}"
        G_HEX="${COLOUR:2:2}"
        B_HEX="${COLOUR:4:2}"
        RF=$(awk "BEGIN{printf \"%.3f\", $((16#$R_HEX))/255}")
        GF=$(awk "BEGIN{printf \"%.3f\", $((16#$G_HEX))/255}")
        BF=$(awk "BEGIN{printf \"%.3f\", $((16#$B_HEX))/255}")
        AF=$(awk "BEGIN{printf \"%.3f\", $ALPHA/255}")

        cat > "$LUA" <<EOF
-- Скруглённый фон для conky: своего border-radius у него нет, поэтому
-- подложка рисуется здесь, а окно conky делается прозрачным.
require 'cairo'

local RADIUS = $RADIUS
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
EOF
        ok "рисовалка фона: $LUA"

        if [ ! -f "$CONKY_BAK" ]; then
            cp "$CONKY_CONF" "$CONKY_BAK"
            ok "резервная копия конфига: $CONKY_BAK"
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

# ---------------------------------------------------------------- итог

# ---------------------------------------------------------------- шрифт

if [ -n "$FONT" ]; then
    echo "==> шрифт интерфейса"
    mkdir -p "$STATE"
    if [ ! -f "$BEFORE" ]; then
        echo "FONT_WAS=$(fget)" > "$BEFORE"
        ok "прежний шрифт записан: $(fget)"
    fi
    if fc-list 2>/dev/null | grep -qi "$(echo "$FONT" | sed 's/ [0-9]*$//')"; then
        fset "$FONT"
        ok "шрифт: $FONT"
    else
        bad "шрифта '$FONT' нет в системе — не менял"
        echo "     что есть:  fc-list --format='%{family[0]}\\n' | sort -u | head -30"
    fi
fi

restart_apps

echo
echo "проверка значков:"
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
echo "GTK3-окна подхватят сразу, GTK4 — после перезапуска приложения."
echo "состояние:        $0 --check"
echo "крупнее значки:   $0 --size 52 38 28"
echo "если не видно:    $0 --diag"
echo "вернуть как было: $0 --revert"
