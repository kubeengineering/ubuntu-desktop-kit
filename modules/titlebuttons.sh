#!/usr/bin/env bash
# Крупные тонкие кнопки заголовка окна, без круглой подложки.
#
#   ./titlebuttons.sh              кнопка 32px, значок 18px
#   ./titlebuttons.sh 36 20        свои размеры
#   ./titlebuttons.sh --revert     вернуть как было
#
# Кнопку рисуют два источника: форму значка даёт тема иконок, размер и
# подложку — тема GTK. Поэтому правится и то, и другое:
#
#   1. Создаётся тема иконок Papirus-Fluent-Titlebar. Она наследует
#      Papirus-Dark целиком и переопределяет ровно четыре значка,
#      взятые из Fluent-icon-theme. Папки, приложения и всё остальное
#      остаются папирусными, а обновления Papirus правки не затирают.
#   2. В ~/.config/gtk-3.0/gtk.css и gtk-4.0/gtk.css пишется блок с
#      размером кнопки. Он помечен маркерами и при повторном запуске
#      заменяется, а не дублируется.
#
# Не подействует на Chrome, Tabby и Telegram: это Electron, они рисуют
# кнопки сами.

set -uo pipefail

SIZE="${1:-32}"
ICO="${2:-18}"
THEME="Papirus-Fluent-Titlebar"
BASE="Papirus-Dark"
DIR="$HOME/.local/share/icons/$THEME"
# Маркеры намеренно без звёздочек и слэшей внутри: они попадают в адрес
# sed, где /* читалось бы как регулярное выражение и диапазон не находился
MARK_A="/* titlebuttons-begin */"
MARK_B="/* titlebuttons-end */"

SRC="https://raw.githubusercontent.com/vinceliuice/Fluent-icon-theme/master/src/symbolic/actions"

# ---------- вырезать наш блок из gtk.css, не трогая остальное ----------
strip_block() {
    F="$1"
    if [ ! -f "$F" ]; then
        return
    fi
    sed -i '/titlebuttons-begin/,/titlebuttons-end/d' "$F"
}

# ---------- откат ----------
if [ "$SIZE" = "--revert" ]; then
    strip_block "$HOME/.config/gtk-3.0/gtk.css"
    strip_block "$HOME/.config/gtk-4.0/gtk.css"
    rm -rf "$DIR"
    gsettings set org.gnome.desktop.interface icon-theme "$BASE"
    gtk-update-icon-cache -f "$HOME/.local/share/icons" 2>/dev/null
    echo "✓ вернул тему иконок $BASE и убрал блок из gtk.css"
    echo "  перелогинься, чтобы применилось везде"
    exit 0
fi

if ! echo "$SIZE$ICO" | grep -qE '^[0-9]+$'; then
    echo "✗ размеры — числа: $0 32 18"
    exit 1
fi

# ---------- базовая тема на месте? ----------
FOUND=""
for d in "$HOME/.local/share/icons/$BASE" "$HOME/.icons/$BASE" "/usr/share/icons/$BASE"; do
    if [ -d "$d" ]; then
        FOUND="$d"
    fi
done
if [ -z "$FOUND" ]; then
    echo "✗ темы иконок $BASE нет — сначала: sudo apt install papirus-icon-theme"
    exit 1
fi
echo "✓ базовая тема: $FOUND"

# ---------- забираем четыре значка ----------
mkdir -p "$DIR/symbolic/actions"
OK=0
for n in close maximize minimize restore; do
    F="$DIR/symbolic/actions/window-$n-symbolic.svg"
    CODE=$(curl -sf -L --max-time 30 -o "$F" -w '%{http_code}' \
           "$SRC/window-$n-symbolic.svg")
    if [ "$CODE" = "200" ]; then
        if head -c 200 "$F" | grep -q '<svg'; then
            OK=$((OK + 1))
        else
            rm -f "$F"
        fi
    else
        rm -f "$F"
    fi
done

if [ "$OK" -ne 4 ]; then
    echo "✗ скачалось значков: $OK из 4 — проверь сеть, ничего не менял"
    rm -rf "$DIR"
    exit 1
fi
echo "✓ значки Fluent: $OK из 4"

# ---------- описание темы ----------
cat > "$DIR/index.theme" <<EOF
[Icon Theme]
Name=$THEME
Comment=$BASE с кнопками заголовка из Fluent
Inherits=$BASE,Papirus,Adwaita,hicolor
Directories=symbolic/actions

[symbolic/actions]
Size=16
MinSize=8
MaxSize=512
Context=Actions
Type=Scalable
EOF

gtk-update-icon-cache -f "$DIR" 2>/dev/null
echo "✓ тема иконок создана: $DIR"

# ---------- размер кнопки для GTK3 и GTK4 ----------
write_css() {
    F="$1"
    mkdir -p "$(dirname "$F")"
    touch "$F"
    strip_block "$F"
    cat >> "$F" <<EOF
$MARK_A
/* кнопки заголовка: крупнее и без круглой подложки.
   Убрать всё это можно так: ./titlebuttons.sh --revert */
headerbar button.titlebutton,
.titlebar button.titlebutton,
windowcontrols button {
  min-width: ${SIZE}px;
  min-height: ${SIZE}px;
  padding: 0;
  margin: 0 2px;
  background: none;
  box-shadow: none;
  border: none;
  border-radius: 8px;
}

headerbar button.titlebutton:hover,
.titlebar button.titlebutton:hover,
windowcontrols button:hover {
  background: alpha(currentColor, 0.12);
}

headerbar button.titlebutton.close:hover,
.titlebar button.titlebutton.close:hover,
windowcontrols button.close:hover {
  background: #e05561;
  color: #ffffff;
}

headerbar button.titlebutton image,
.titlebar button.titlebutton image,
windowcontrols button image {
  -gtk-icon-size: ${ICO}px;
}
$MARK_B
EOF
}

write_css "$HOME/.config/gtk-3.0/gtk.css"
write_css "$HOME/.config/gtk-4.0/gtk.css"
echo "✓ размер прописан: кнопка ${SIZE}px, значок ${ICO}px"

# ---------- включаем ----------
gsettings set org.gnome.desktop.interface icon-theme "$THEME"
echo "✓ тема иконок включена"

echo
echo "GTK3-приложения подхватят сразу, GTK4 — после перезапуска приложения."
echo "Chrome, Tabby и Telegram не изменятся: они рисуют кнопки сами."
echo
echo "другой размер:  $0 36 20"
echo "вернуть как было: $0 --revert"
