#!/usr/bin/env bash
# Острые углы у окон и скруглённый виджет conky.
#
#   ./corners.sh                  окна острые, виджет скруглён на 14px
#   ./corners.sh --windows        только окна
#   ./corners.sh --widget 20      только виджет, радиус 20px
#   ./corners.sh --revert         вернуть как было
#
# Окна: скругление задаёт тема GTK, снимается через ~/.config/gtk-3.0/gtk.css
# и gtk-4.0/gtk.css. !important обязателен — правила тем специфичнее
# пользовательских.
#
# Виджет: у conky скругления нет в принципе, поэтому фон рисуется самим
# conky через Lua и Cairo, а собственное окно делается прозрачным.
# Исходный конфиг сохраняется рядом с расширением .bak-corners.
#
# Chrome, Tabby и Telegram рисуют свои рамки сами — их это не касается.

set -uo pipefail

DO_WINDOWS=1
DO_WIDGET=1
RADIUS=14
MODE="apply"

while [ $# -gt 0 ]; do
    case "$1" in
        --windows) DO_WIDGET=0; shift ;;
        --widget)  DO_WINDOWS=0; RADIUS="${2:-14}"; shift 2 ;;
        --revert)  MODE="revert"; shift ;;
        -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "неизвестный аргумент: $1"; echo "подсказка: $0 --help"; exit 1 ;;
    esac
done

CONKY_DIR="$HOME/.config/conky"
CONKY_CONF="$CONKY_DIR/main.conf"
CONKY_BAK="$CONKY_DIR/main.conf.bak-corners"
LUA="$CONKY_DIR/rounded.lua"

ok()  { echo "  ✓ $*"; }
bad() { echo "  ✗ $*"; }

strip_block() {
    if [ -f "$1" ]; then
        sed -i '/corners-begin/,/corners-end/d' "$1"
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
        else
            bad "conky не поднялся — смотри: conky -c $CONKY_CONF"
        fi
    fi
}

# ---------------------------------------------------------------- откат

if [ "$MODE" = "revert" ]; then
    echo "==> откат"
    strip_block "$HOME/.config/gtk-3.0/gtk.css"
    strip_block "$HOME/.config/gtk-4.0/gtk.css"
    ok "скругление окон вернулось к теме"

    if [ -f "$CONKY_BAK" ]; then
        mv "$CONKY_BAK" "$CONKY_CONF"
        rm -f "$LUA"
        ok "конфиг conky восстановлен из резервной копии"
        restart_conky
    else
        ok "conky не трогался"
    fi
    echo "перелогинься, чтобы окна применили изменения везде"
    exit 0
fi

# ---------------------------------------------------------------- окна

if [ "$DO_WINDOWS" -eq 1 ]; then
    echo "==> углы окон"

    write_corners() {
        F="$1"
        mkdir -p "$(dirname "$F")"
        touch "$F"
        strip_block "$F"
        cat >> "$F" <<'EOF'
/* corners-begin */
/* Острые углы: снимаем скругление у окна, заголовка и всплывающих
   элементов. !important обязателен — правила тем специфичнее. */
decoration,
decoration:backdrop,
window,
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
popover.background,
popover > contents,
popover > arrow,
menu,
.menu,
.context-menu,
tooltip,
tooltip.background,
.card,
.osd {
  border-radius: 0 !important;
}
/* corners-end */
EOF
    }

    write_corners "$HOME/.config/gtk-3.0/gtk.css"
    write_corners "$HOME/.config/gtk-4.0/gtk.css"
    ok "скругление снято для окон, заголовков, меню и подсказок"
    echo "     GTK3-приложения подхватят сразу, GTK4 — после перезапуска"
fi

# ---------------------------------------------------------------- виджет

if [ "$DO_WIDGET" -eq 1 ]; then
    echo "==> виджет conky (радиус ${RADIUS}px)"

    if [ ! -f "$CONKY_CONF" ]; then
        bad "конфига нет: $CONKY_CONF — виджет пропускаю"
    else
        if ! echo "$RADIUS" | grep -qE '^[0-9]+$'; then
            bad "радиус — число: $0 --widget 14"
            exit 1
        fi

        # цвет и плотность берём из текущего конфига, чтобы вид не поехал
        COLOUR=$(grep -oP "own_window_colour\s*=\s*'\K[0-9a-fA-F]{6}" "$CONKY_CONF" | head -1)
        if [ -z "$COLOUR" ]; then
            COLOUR="1e1e2e"
        fi
        ALPHA=$(grep -oP "own_window_argb_value\s*=\s*\K[0-9]+" "$CONKY_CONF" | head -1)
        if [ -z "$ALPHA" ]; then
            ALPHA=225
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
-- Скруглённый фон для conky: собственного border-radius у него нет,
-- поэтому подложка рисуется здесь, а окно conky делается прозрачным.
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

        # окно conky делаем полностью прозрачным: фон теперь рисует Lua
        sed -i "s|own_window_argb_value = [0-9]*|own_window_argb_value = 0|" "$CONKY_CONF"

        # подключаем скрипт: если строка уже есть — обновляем путь,
        # иначе вставляем сразу после открытия conky.config
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

echo
echo "вернуть как было: $0 --revert"
