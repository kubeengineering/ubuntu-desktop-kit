#!/usr/bin/env bash
# Кнопки заголовка и углы окон: копия темы для GTK3, пользовательский css для GTK4.
#
#   ./look.sh                     кнопки + острые углы
#   ./look.sh --no-corners        только кнопки, углы оставить как есть
#   ./look.sh --size 46 34 24     ширина, высота кнопки, размер значка
#   ./look.sh --font "JetBrainsMono Nerd Font 11"   шрифт интерфейса
#   ./look.sh --widget 18         скруглить виджет conky на 18px
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
#       сыпались до нашего блока;
#     * и главное: libadwaita ЖЁСТКО ставит gtk-theme-name в Adwaita-empty
#       и темы не читает вовсе, поэтому Nautilus и Настройки нельзя
#       изменить через тему — только через ~/.config/gtk-4.0/gtk.css.
#
#   Отсюда две разные цели:
#     GTK3-окна (терминал, Evolution) — копия темы ИМЯ-Square;
#     GTK4-окна (Nautilus, Настройки) — ~/.config/gtk-4.0/gtk.css.
#
#   Тема копируется в ИМЯ-Square, правила дописываются в конец её файлов,
#   система переключается на копию. Оригинал темы не трогается.
#   Файл ~/.config/gtk-4.0/gtk.css сохраняется рядом как .bak-look до
#   первой правки и восстанавливается при откате.
#
# ЧТО НЕ ТРОГАЕТСЯ: оригинальная тема, цветовая схема, тема оболочки,
# иконки папок, обои, панель, conky, ~/.config/gtk-3.0/gtk.css.
#
# Chrome, Tabby и Telegram не изменятся: это Electron, они рисуют себя сами.

set -uo pipefail

BTN_W=46
BTN_H=34
BTN_ICO=24
DO_CORNERS=1
FONT=""
WIDGET=""
MODE="apply"

while [ $# -gt 0 ]; do
    case "$1" in
        --no-corners) DO_CORNERS=0; shift ;;
        --size)       BTN_W="${2:-46}"; BTN_H="${3:-34}"; BTN_ICO="${4:-24}"; shift 4 ;;
        --font)       FONT="${2:-}"; shift 2 ;;
        --widget)     WIDGET="${2:-18}"; shift 2 ;;
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

# Без имени темы дальше нельзя: путь вида ~/.themes/-Square попал бы
# под rm -rf, да и откатывать было бы уже не к чему.
if [ -z "$BASE_GTK" ]; then
    echo "  x gsettings не отдал текущую тему окон - ничего не делаю"
    echo "     проверь: gsettings get org.gnome.desktop.interface gtk-theme"
    exit 1
fi
if [ -z "$BASE_ICON" ]; then
    echo "  x gsettings не отдал текущую тему иконок - ничего не делаю"
    exit 1
fi

NEW_GTK="$BASE_GTK$SUFFIX"
NEW_ICON="$BASE_ICON-Fluent-Titlebar"
THEME_DIR="$HOME/.themes/$NEW_GTK"
ICON_DIR="$HOME/.local/share/icons/$NEW_ICON"

# libadwaita (Nautilus, Настройки) ИГНОРИРУЕТ тему: он жёстко ставит
# gtk-theme-name в Adwaita-empty. Единственный рычаг для таких окон —
# пользовательский ~/.config/gtk-4.0/gtk.css, поэтому GTK4-правила идут
# туда, а не в копию темы. Для GTK3-окон работает копия темы.
USER_CSS4="$HOME/.config/gtk-4.0/gtk.css"
USER_BAK="$HOME/.config/gtk-4.0/gtk.css.bak-look"

CONKY_DIR="$HOME/.config/conky"
CONKY_CONF="$CONKY_DIR/main.conf"
CONKY_BAK="$CONKY_DIR/main.conf.bak-look"
LUA="$CONKY_DIR/rounded.lua"

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

    # вернуть пользовательский GTK4-файл: либо из копии, либо снять наш блок
    HAVE_BAK=0
    if [ -e "$USER_BAK" ]; then HAVE_BAK=1; fi
    if [ -L "$USER_BAK" ]; then HAVE_BAK=1; fi
    if [ "$HAVE_BAK" = "1" ]; then
        rm -f "$USER_CSS4"
        mv "$USER_BAK" "$USER_CSS4"
        ok "~/.config/gtk-4.0/gtk.css восстановлен"
    elif [ -f "$USER_CSS4" ]; then
        sed -i '/squarebuttons-begin/,/squarebuttons-end/d' "$USER_CSS4"
        if [ ! -s "$USER_CSS4" ]; then
            rm -f "$USER_CSS4"
        fi
        ok "правила из ~/.config/gtk-4.0/gtk.css убраны"
    fi

    if [ -d "$THEME_DIR" ]; then
        rm -rf "$THEME_DIR"
        ok "копия темы удалена: $THEME_DIR"
    fi
    if [ -d "$ICON_DIR" ]; then
        rm -rf "$ICON_DIR"
        ok "тема значков удалена"
    fi

    if [ -f "$CONKY_BAK" ]; then
        mv "$CONKY_BAK" "$CONKY_CONF"
        rm -f "$LUA"
        ok "конфиг conky восстановлен"
        restart_conky
    fi

    if command -v nautilus >/dev/null 2>&1; then
        nautilus -q >/dev/null 2>&1
    fi
    echo
    echo "готово. Оригинал темы и ~/.config/gtk-3.0 не трогались."
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
    else
        bad "копии темы нет — GTK3-окна не изменятся"
    fi
    if grep -q 'squarebuttons-begin' "$USER_CSS4" 2>/dev/null; then
        ok "GTK4-правила в ~/.config/gtk-4.0/gtk.css"
        grep -m1 'gtk-icon-size' "$USER_CSS4" | sed 's/^/     GTK4: /'
        if grep -q '@import' "$USER_CSS4"; then
            echo "     тема подключена импортом"
        fi
    else
        bad "GTK4-правил нет — Nautilus не изменится"
    fi
    if [ -d "$ICON_DIR" ]; then
        ok "значков Fluent: $(ls "$ICON_DIR/symbolic/actions" 2>/dev/null | wc -l) из 4"
    else
        bad "значки не подменены"
    fi
    if [ -f "$LUA" ]; then
        ok "виджет скруглён: $(grep -m1 "local RADIUS" "$LUA" | tr -d " ")"
    else
        bad "виджет не скруглён"
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
  background-color: transparent !important;
  background-image: none !important;
  border-radius: 0 !important;
  padding: 0 !important;
  box-shadow: none !important;
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

# --- 2б. GTK4: только через пользовательский css ----------------------
# libadwaita не читает темы, поэтому копии темы для Nautilus мало.
# Оригинальный файл (часто это симлинк темы) сохраняем целиком.
mkdir -p "$(dirname "$USER_CSS4")"
# Бэкап делаем только с ЧИСТОГО файла. Иначе повторный запуск сохранит
# файл, где уже лежат наши правила, и откат вернёт их же.
HAVE_BAK=0
if [ -e "$USER_BAK" ]; then HAVE_BAK=1; fi
if [ -L "$USER_BAK" ]; then HAVE_BAK=1; fi
if [ "$HAVE_BAK" = "0" ]; then
    if [ -L "$USER_CSS4" ]; then
        cp -P "$USER_CSS4" "$USER_BAK"
        ok "исходный симлинк сохранён: $USER_BAK"
    elif [ -f "$USER_CSS4" ]; then
        if ! grep -q 'squarebuttons' "$USER_CSS4"; then
            cp "$USER_CSS4" "$USER_BAK"
            ok "исходный файл сохранён: $USER_BAK"
        fi
    fi
fi

# было симлинком — подключаем тему импортом, чтобы вид не потерялся
IMPORT_LINE=""
if [ -L "$USER_CSS4" ]; then
    LINK_TARGET=$(readlink -f "$USER_CSS4")
    IMPORT_LINE="@import url(\"file://$LINK_TARGET\");"
    rm -f "$USER_CSS4"
fi
touch "$USER_CSS4"
sed -i '/squarebuttons-begin/,/squarebuttons-end/d' "$USER_CSS4"

if [ -n "$IMPORT_LINE" ]; then
    if ! grep -q '@import' "$USER_CSS4"; then
        printf '%s
' "$IMPORT_LINE" > "$USER_CSS4.new"
        cat "$USER_CSS4" >> "$USER_CSS4.new"
        mv "$USER_CSS4.new" "$USER_CSS4"
        ok "тема подключена импортом, вид окон сохранён"
    fi
fi

cat >> "$USER_CSS4" <<EOF

/* squarebuttons-begin
   ГЛАВНОЕ: в libadwaita круглую подложку рисует НЕ кнопка, а её дочерний
   image — там стоит border-radius: 100% и свой background-color. Правки
   на самой кнопке круг не убирают, сколько их ни ставь. Поэтому фон и
   радиус снимаются с image, а подсветка вешается на кнопку. */
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
  background-color: transparent !important;
  background-image: none !important;
  border-radius: 0 !important;
  padding: 0 !important;
  margin: 0 !important;
  box-shadow: none !important;
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

windowcontrols > button:hover > image,
windowcontrols button:hover image {
  background-color: transparent !important;
  border-radius: 0 !important;
}

windowcontrols > button:active,
windowcontrols button:active {
  background-color: alpha(currentColor, 0.24) !important;
  border-radius: 0 !important;
}

windowcontrols > button:active > image,
windowcontrols button:active image {
  background-color: transparent !important;
  border-radius: 0 !important;
}

windowcontrols > button.close:hover,
windowcontrols button.close:hover {
  background-color: #e81123 !important;
  background-image: none !important;
  color: #ffffff !important;
  border-radius: 0 !important;
}

windowcontrols > button.close:hover > image,
windowcontrols button.close:hover image {
  background-color: transparent !important;
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
ok "GTK4-правила в ~/.config/gtk-4.0/gtk.css (единственный путь для libadwaita)"


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


# --- 4б. виджет conky -------------------------------------------------
if [ -n "$WIDGET" ]; then
    echo "==> виджет conky (радиус ${WIDGET}px)"
    if ! echo "$WIDGET" | grep -qE '^[0-9]+$'; then
        bad "радиус — число: $0 --widget 18"
        exit 1
    fi
    if [ ! -f "$CONKY_CONF" ]; then
        bad "конфига нет: $CONKY_CONF — виджет пропускаю"
    else
        # цвет и плотность берём из конфига, чтобы вид не поехал
        COLOUR=$(grep -oP "own_window_colour\s*=\s*'\K[0-9a-fA-F]{6}" "$CONKY_CONF" | head -1)
        if [ -z "$COLOUR" ]; then
            COLOUR="1e1e2e"
        fi
        ALPHA=$(grep -oP "own_window_argb_value\s*=\s*\K[0-9]+" "$CONKY_CONF" | head -1)
        if [ -z "$ALPHA" ]; then
            ALPHA=225
        fi
        if [ "$ALPHA" = "0" ]; then
            ALPHA=225      # уже применяли: берём прежнюю плотность
        fi

        R_HEX="${COLOUR:0:2}"
        G_HEX="${COLOUR:2:2}"
        B_HEX="${COLOUR:4:2}"
        RF=$(awk "BEGIN{printf \"%.3f\", $((16#$R_HEX))/255}")
        GF=$(awk "BEGIN{printf \"%.3f\", $((16#$G_HEX))/255}")
        BF=$(awk "BEGIN{printf \"%.3f\", $((16#$B_HEX))/255}")
        AF=$(awk "BEGIN{printf \"%.3f\", $ALPHA/255}")

        cat > "$LUA" <<LUAEOF
-- Скруглённый фон для conky: своего border-radius у него нет, поэтому
-- подложка рисуется здесь, а окно conky делается прозрачным.
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
echo "  правил в GTK4: $(grep -c '!important' "$USER_CSS4" 2>/dev/null) (в ~/.config/gtk-4.0)"

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
