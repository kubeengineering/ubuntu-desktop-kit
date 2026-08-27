#!/usr/bin/env bash
# Тесты новых возможностей: варианты темы, независимость подсистем, справка.
set -u
KIT="${KIT:-$(cd "$(dirname "$0")/.." && pwd)/desktop-kit.sh}"
PASS=0
FAIL=0

say() {
    if [ "$1" = "0" ]; then
        PASS=$((PASS + 1)); echo "  OK   $2"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL $2"
    fi
}

# --- песочница -------------------------------------------------------
setup() {
    T=$(mktemp -d)
    export HOME="$T/home"
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.themes" \
             "$HOME/.local/share/icons" "$T/bin"

    cat > "$T/bin/gsettings" <<'EOF'
#!/usr/bin/env bash
S="$HOME/gs.store"; touch "$S"
if [ "$1" = "set" ]; then
    KEY="$3"; shift 3
    grep -v "^$KEY=" "$S" > "$S.t" 2>/dev/null; mv "$S.t" "$S"
    echo "$KEY=$*" >> "$S"; exit 0
fi
if [ "$1" = "get" ]; then
    V=$(grep "^$3=" "$S" | tail -1 | cut -d= -f2-)
    case "$V" in "") : ;; \[*) echo "$V" ;; *) echo "'$V'" ;; esac
fi
exit 0
EOF
    cat > "$T/bin/dconf" <<'EOF'
#!/usr/bin/env bash
D="$HOME/dconf.store"; touch "$D"
if [ "$1" = "write" ]; then
    grep -v "^$2 " "$D" > "$D.t" 2>/dev/null; mv "$D.t" "$D"
    echo "$2 $3" >> "$D"; exit 0
fi
if [ "$1" = "read" ]; then
    grep "^$2 " "$D" | tail -1 | cut -d' ' -f2-
fi
exit 0
EOF
    for s in gtk-update-icon-cache nautilus pgrep pkill systemctl conky notify-send; do
        printf '#!/usr/bin/env bash\nexit 0\n' > "$T/bin/$s"
    done
    printf '#!/usr/bin/env bash\necho Cantarell\n' > "$T/bin/fc-list"
    chmod +x "$T/bin/"*
    export PATH="$T/bin:$PATH"
}

teardown() { rm -rf "$T"; }

mktheme() {
    mkdir -p "$HOME/.themes/$1/gtk-3.0"
}

mkicon() {
    mkdir -p "$HOME/.local/share/icons/$1"
    printf '[Icon Theme]
Name=%s
' "$1" > "$HOME/.local/share/icons/$1/index.theme"
}

curtheme() {
    grep "^gtk-theme=" "$HOME/gs.store" | tail -1 | cut -d= -f2-
}
curscheme() {
    grep "^color-scheme=" "$HOME/gs.store" | tail -1 | cut -d= -f2-
}
curicons() {
    grep "^icon-theme=" "$HOME/gs.store" | tail -1 | cut -d= -f2-
}

echo "== переключение варианта темы =="

setup
mktheme Graphite-Dark; mktheme Graphite-Light
gsettings set org.gnome.desktop.interface gtk-theme "Graphite-Dark"
bash "$KIT" theme --light >/dev/null 2>&1
if [ "$(curtheme)" = "Graphite-Light" ]; then
    say 0 "Graphite-Dark -> Graphite-Light по --light"
else
    say 1 "ожидал Graphite-Light, получил '$(curtheme)'"
fi
if [ "$(curscheme)" = "prefer-light" ]; then
    say 0 "схема переключилась вместе с темой"
else
    say 1 "схема '$(curscheme)', ожидал prefer-light"
fi
teardown

setup
mktheme Yaru; mktheme Yaru-dark
gsettings set org.gnome.desktop.interface gtk-theme "Yaru-dark"
bash "$KIT" theme --light >/dev/null 2>&1
if [ "$(curtheme)" = "Yaru" ]; then
    say 0 "Yaru-dark -> Yaru (светлый без суффикса)"
else
    say 1 "ожидал Yaru, получил '$(curtheme)'"
fi
teardown

setup
mktheme Graphite-teal-Dark; mktheme Graphite-teal-Light
gsettings set org.gnome.desktop.interface gtk-theme "Graphite-teal-Dark"
bash "$KIT" theme --light >/dev/null 2>&1
if [ "$(curtheme)" = "Graphite-teal-Light" ]; then
    say 0 "двойной суффикс: Graphite-teal-Dark -> -Light"
else
    say 1 "ожидал Graphite-teal-Light, получил '$(curtheme)'"
fi
teardown

setup
mktheme Yaru; mktheme Yaru-dark
gsettings set org.gnome.desktop.interface gtk-theme "Yaru"
bash "$KIT" theme --dark >/dev/null 2>&1
if [ "$(curtheme)" = "Yaru-dark" ]; then
    say 0 "обратно: Yaru -> Yaru-dark"
else
    say 1 "ожидал Yaru-dark, получил '$(curtheme)'"
fi
teardown

echo "== пары нет: ничего не менять =="

setup
mktheme OneOnly-Dark
gsettings set org.gnome.desktop.interface gtk-theme "OneOnly-Dark"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
out=$(bash "$KIT" theme --light 2>&1)
rc=$?
if [ "$rc" != "0" ]; then
    say 0 "без пары команда возвращает ошибку"
else
    say 1 "без пары вернулся успех"
fi
if [ "$(curtheme)" = "OneOnly-Dark" ]; then
    say 0 "тема не тронута"
else
    say 1 "тема поменялась на '$(curtheme)'"
fi
if [ "$(curscheme)" = "prefer-dark" ]; then
    say 0 "схема не тронута — рассинхрона нет"
else
    say 1 "схема стала '$(curscheme)' при прежней тёмной теме"
fi
if echo "$out" | grep -q "scheme-only"; then
    say 0 "подсказан выход через --scheme-only"
else
    say 1 "про --scheme-only не сказано"
fi
teardown

setup
mktheme OneOnly-Dark
gsettings set org.gnome.desktop.interface gtk-theme "OneOnly-Dark"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
bash "$KIT" theme --light --scheme-only >/dev/null 2>&1
if [ "$(curscheme)" = "prefer-light" ]; then
    say 0 "--scheme-only меняет только схему"
else
    say 1 "--scheme-only не сработал"
fi
if [ "$(curtheme)" = "OneOnly-Dark" ]; then
    say 0 "--scheme-only тему не трогает"
else
    say 1 "--scheme-only поменял тему"
fi
teardown

echo "== тема и значки независимы =="

setup
mktheme Graphite-Dark; mktheme Graphite-Light
mkicon Papirus-Dark
gsettings set org.gnome.desktop.interface gtk-theme "Graphite-Dark"
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
bash "$KIT" theme --light >/dev/null 2>&1
if [ "$(curicons)" = "Papirus-Dark" ]; then
    say 0 "смена темы не тронула тему значков"
else
    say 1 "значки стали '$(curicons)'"
fi
out=$(bash "$KIT" theme Graphite-Dark 2>&1)
if echo "$out" | grep -q "тема значков не менялась"; then
    say 0 "скрипт прямо сообщает, что значки не трогал"
else
    say 1 "про значки ничего не сказано"
fi
teardown

echo "== откат по подсистемам =="

setup
mktheme Graphite-Dark; mktheme Graphite-Light
mkicon Papirus; mkicon Adwaita
gsettings set org.gnome.desktop.interface gtk-theme "Graphite-Dark"
gsettings set org.gnome.desktop.interface icon-theme "Adwaita"
gsettings set org.gnome.desktop.interface font-name "Cantarell 11"
bash "$KIT" icons Papirus >/dev/null 2>&1
bash "$KIT" font "Cantarell 12" >/dev/null 2>&1
bash "$KIT" theme Graphite-Light >/dev/null 2>&1
bash "$KIT" revert theme >/dev/null 2>&1
if [ "$(curtheme)" = "Graphite-Dark" ]; then
    say 0 "revert theme вернул тему"
else
    say 1 "тема после отката '$(curtheme)'"
fi
if [ "$(curicons)" = "Papirus" ]; then
    say 0 "revert theme НЕ тронул значки"
else
    say 1 "revert theme сбросил значки в '$(curicons)'"
fi
if grep -q "^font-name=Cantarell 12" "$HOME/gs.store"; then
    say 0 "revert theme НЕ тронул шрифт"
else
    say 1 "revert theme сбросил шрифт"
fi
bash "$KIT" revert icons >/dev/null 2>&1
if [ "$(curicons)" = "Adwaita" ]; then
    say 0 "revert icons вернул тему значков"
else
    say 1 "значки после revert icons: '$(curicons)'"
fi
bash "$KIT" revert font >/dev/null 2>&1
if grep -q "^font-name=Cantarell 11" "$HOME/gs.store"; then
    say 0 "revert font вернул шрифт"
else
    say 1 "шрифт после revert font не вернулся"
fi
teardown

setup
out=$(bash "$KIT" revert nosuch 2>&1)
if echo "$out" | grep -q "не знаю подсистемы"; then
    say 0 "неизвестная подсистема отвергается"
else
    say 1 "неизвестная подсистема проглочена"
fi
if echo "$out" | grep -q "panel"; then
    say 0 "перечислены доступные подсистемы"
else
    say 1 "список подсистем не показан"
fi
teardown

echo "== справка =="

setup
out=$(bash "$KIT" help --settings 2>&1)
for k in gtk-theme icon-theme color-scheme picture-uri palette panel-sizes \
         custom-keybindings document-font-name; do
    if echo "$out" | grep -q "$k"; then
        say 0 "help --settings упоминает $k"
    else
        say 1 "help --settings не знает про $k"
    fi
done
for f in "gtk-3.0/gtk.css" "conky/main.conf" "desktop-kit-wallpapers" "before.env"; do
    if echo "$out" | grep -qF "$f"; then
        say 0 "help --settings упоминает $f"
    else
        say 1 "help --settings не знает про $f"
    fi
done
teardown

setup
out=$(bash "$KIT" help --all 2>&1)
for c in buttons corners theme icons font widget terminal newtab wallpapers \
         wall serve app keys panel selftest revert; do
    if echo "$out" | grep -q "^$c — "; then
        say 0 "help --all содержит раздел $c"
    else
        say 1 "help --all не содержит раздел $c"
    fi
done
teardown

echo "== виджет: контраст =="

setup
mkdir -p "$HOME/.config/conky"
printf "conky.config = {\n    own_window_argb_value = 225,\n    own_window_colour = '1e1e2e',\n    default_color = 'ffffff',\n}\n" \
    > "$HOME/.config/conky/main.conf"
out=$(bash "$KIT" widget --colour f2f2f2 2>&1)
if echo "$out" | grep -q "не виден"; then
    say 0 "предупреждает о светлом тексте на светлой подложке"
else
    say 1 "молча оставил белое на белом"
fi
bash "$KIT" widget --light >/dev/null 2>&1
if grep -q "default_color = '1e1e2e'" "$HOME/.config/conky/main.conf"; then
    say 0 "--light поставил тёмный текст"
else
    say 1 "--light не поменял цвет текста"
fi
teardown

echo
echo "прошло: $PASS, провалено: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "ЕСТЬ ПРОВАЛЫ"
    exit 1
fi
echo "все проверки прошли"
