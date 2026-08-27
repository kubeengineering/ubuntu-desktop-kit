#!/usr/bin/env bash
# Проверка desktop-kit.sh на подставном доме с заглушками системных команд.
set -u

SRC="${KIT:-$(cd "$(dirname "$0")/.." && pwd)/desktop-kit.sh}"
T=$(mktemp -d)
export HOME="$T/home"
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/conky" "$HOME/.themes" \
         "$HOME/.local/share/icons/Papirus-Dark" "$HOME/Pictures/wallpapers-uw" \
         "$HOME/.local/share/newtab" "$T/bin"

# --- заглушки ---------------------------------------------------------
cat > "$T/bin/gsettings" <<'EOF'
#!/usr/bin/env bash
S="$HOME/gs.store"; touch "$S"
if [ "$1" = "set" ]; then
    KEY="$3"
    if [ "${1}" = "set" ] && [ "${2#org.gnome.Terminal}" != "$2" ]; then KEY="term-$3"; fi
    grep -v "^$KEY=" "$S" > "$S.t" 2>/dev/null; mv "$S.t" "$S"
    shift 3
    echo "$KEY=$*" >> "$S"
    exit 0
fi
if [ "$1" = "get" ]; then
    KEY="$3"
    if [ "${2#org.gnome.Terminal}" != "$2" ]; then KEY="term-$3"; fi
    V=$(grep "^$KEY=" "$S" | tail -1 | cut -d= -f2-)
    # настоящий gsettings массивы отдаёт без внешних кавычек
    case "$V" in
        "") : ;;
        \[*) echo "$V" ;;
        *) echo "'$V'" ;;
    esac
    exit 0
fi
exit 0
EOF
cat > "$T/bin/dconf" <<'EOF'
#!/usr/bin/env bash
S="$HOME/dconf.store"; touch "$S"
if [ "$1" = "write" ]; then echo "$3" | tr -d "'" > "$S"; exit 0; fi
if [ "$1" = "read" ]; then
    V=$(cat "$S" 2>/dev/null)
    if [ -n "$V" ]; then echo "'$V'"; fi
fi
exit 0
EOF
for stub in gtk-update-icon-cache nautilus conky pkill pgrep systemctl \
            notify-send update-desktop-database xdg-user-dir papirus-folders; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$T/bin/$stub"
done
printf '#!/usr/bin/env bash\necho "JetBrainsMono Nerd Font"\necho "Cantarell"\n' > "$T/bin/fc-list"
chmod +x "$T/bin/"*
export PATH="$T/bin:$PATH"

# --- исходное состояние ----------------------------------------------
mkdir -p "$HOME/.themes/Graphite-Dark/gtk-3.0" "$HOME/.themes/Yaru/gtk-3.0"
echo "Name=Graphite-Dark" > "$HOME/.themes/Graphite-Dark/index.theme"
echo "Name=Yaru" > "$HOME/.themes/Yaru/index.theme"
echo "[Icon Theme]" > "$HOME/.local/share/icons/Papirus-Dark/index.theme"

cat > "$HOME/.config/gtk-3.0/gtk.css" <<'EOF'
/* моя старая правка */
window.background { background-color: #101010; }
EOF

cat > "$HOME/.config/conky/main.conf" <<'EOF'
conky.config = {
    own_window_argb_value = 225,
    own_window_colour = '1e1e2e',
    font = 'JetBrainsMono Nerd Font:size=10',
}
EOF

printf 'ESXi|https://esxi.local\nGrafana|http://10.0.0.1:3000\n' > "$HOME/.local/share/newtab/links.txt"
for i in 1 2 3 4 5; do echo x > "$HOME/Pictures/wallpapers-uw/w$i.jpg"; done

"$T/bin/gsettings" set org.gnome.desktop.interface gtk-theme "Graphite-Dark"
"$T/bin/gsettings" set org.gnome.desktop.interface icon-theme "Papirus-Dark"
"$T/bin/gsettings" set org.gnome.desktop.interface color-scheme "prefer-dark"
"$T/bin/gsettings" set org.gnome.desktop.interface font-name "Cantarell 11"

K="$T/desktop-kit.sh"; cp "$SRC" "$K"
FAIL=0
say() { if [ "$1" = "0" ]; then echo "  OK   $2"; else echo "  FAIL $2"; FAIL=1; fi; }
gv() { grep "^$1=" "$HOME/gs.store" | tail -1 | cut -d= -f2-; }
run() { timeout 60 bash "$K" "$@"; }

C3="$HOME/.config/gtk-3.0/gtk.css"
C4="$HOME/.config/gtk-4.0/gtk.css"

echo "== справка =="
run help > "$T/o" 2>&1
if grep -q 'ВНЕШНИЙ ВИД' "$T/o"; then say 0 "общая справка"; else say 1 "нет общей справки"; fi
for c in buttons corners theme icons font widget terminal newtab wallpapers wall app serve selftest revert; do
    run help "$c" > "$T/h" 2>&1
    if [ -s "$T/h" ]; then :; else say 1 "нет справки по $c"; fi
done
say 0 "справка есть по каждой команде"
run wat > "$T/o" 2>&1
if grep -q 'неизвестная команда' "$T/o"; then say 0 "мусорная команда отвергнута"; else say 1 "проглотил мусор"; fi

echo
echo "== разбор аргументов не зацикливается =="
run buttons --size 40 > "$T/o" 2>&1
RC=$?
if [ "$RC" != "0" ]; then say 0 "неполный --size отвергнут, а не завис"; else say 1 "принял неполный --size"; fi
if grep -q 'нужно значений' "$T/o"; then say 0 "сказано, сколько значений нужно"; else say 1 "нет объяснения"; fi
run buttons --icon > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "флаг без значения отвергнут"; else say 1 "принял флаг без значения"; fi
run wallpapers --timer Wed > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "неполный --timer отвергнут"; else say 1 "принял неполный --timer"; fi
run wallpapers --timer off > "$T/o" 2>&1
if [ "$?" = "0" ]; then say 0 "--timer off принят одним словом"; else say 1 "--timer off не работает"; fi

echo
echo "== dry-run ничего не меняет =="
BEFORE=$(md5sum "$C3" | cut -d' ' -f1)
run --dry-run buttons > /dev/null 2>&1
run --dry-run corners --radius 8 > /dev/null 2>&1
run --dry-run widget --radius 20 > /dev/null 2>&1
AFTER=$(md5sum "$C3" | cut -d' ' -f1)
if [ "$BEFORE" = "$AFTER" ]; then say 0 "gtk-3.0 не тронут"; else say 1 "dry-run изменил файл"; fi
if [ -f "$HOME/.config/conky/desktop-kit-bg.lua" ]; then say 1 "dry-run создал lua"; else say 0 "lua не создан"; fi

echo
echo "== buttons =="
run buttons --size 52 38 --icon 24 --gtk3-scale 1.25 > "$T/o" 2>&1
if grep -q 'dk:buttons-begin' "$C3"; then say 0 "блок в gtk-3.0"; else say 1 "нет блока в gtk-3.0"; fi
if grep -q 'dk:buttons-begin' "$C4"; then say 0 "блок в gtk-4.0"; else say 1 "нет блока в gtk-4.0"; fi
if grep -q '!important' "$C3"; then say 1 "!important в gtk-3.0"; else say 0 "нет !important в gtk-3.0"; fi
if grep -q '!important' "$C4"; then say 1 "!important в gtk-4.0"; else say 0 "нет !important в gtk-4.0"; fi
if grep -q 'min-width: 52px' "$C4"; then say 0 "размер применён"; else say 1 "размер не применён"; fi
if grep -q 'gtk-icon-size: 24px' "$C4"; then say 0 "размер значка в GTK4"; else say 1 "нет размера значка"; fi
if grep -q 'scale(1.25)' "$C3"; then say 0 "масштаб в GTK3"; else say 1 "нет масштаба"; fi
if grep -q 'windowcontrols > button > image' "$C4"; then say 0 "целимся в image"; else say 1 "image не покрыт"; fi
if grep -qE '^\s*-gtk-icon-size:' "$C3"; then say 1 "GTK4-свойство попало в GTK3"; else say 0 "в GTK3 нет GTK4-свойств"; fi
if grep -qE '^\s*-gtk-icon-transform:' "$C4"; then say 1 "GTK3-свойство попало в GTK4"; else say 0 "в GTK4 нет GTK3-свойств"; fi
if grep -q 'моя старая правка' "$C3"; then say 0 "чужой css цел"; else say 1 "затёрли чужое"; fi

echo
echo "== цвета =="
run buttons --close '#ff0000' > /dev/null 2>&1
if grep -q '#ff0000' "$C4"; then say 0 "свой цвет закрытия"; else say 1 "цвет не применён"; fi
if grep -qE 'background-color: #[0-9a-f]{6};' "$C4"; then say 0 "цвет нажатия посчитан"; else say 1 "нет цвета нажатия"; fi
run buttons --close 'красный' > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "нехекс-цвет отвергнут"; else say 1 "принял 'красный'"; fi

echo
echo "== corners не мешает buttons =="
run corners --radius 6 > /dev/null 2>&1
if grep -q 'dk:corners-begin' "$C4"; then say 0 "блок углов записан"; else say 1 "нет блока углов"; fi
if grep -q 'dk:buttons-begin' "$C4"; then say 0 "блок кнопок уцелел"; else say 1 "углы затёрли кнопки"; fi
if grep -q 'border-radius: 6px' "$C4"; then say 0 "радиус 6px"; else say 1 "радиус не применён"; fi

echo
echo "== повтор не дублирует =="
run buttons > /dev/null 2>&1
run buttons > /dev/null 2>&1
N=$(grep -c 'dk:buttons-begin' "$C4")
if [ "$N" = "1" ]; then say 0 "блок кнопок один"; else say 1 "блоков: $N"; fi

echo
echo "== theme =="
run theme --list > "$T/o" 2>&1
if grep -q 'Graphite-Dark' "$T/o"; then say 0 "список тем"; else say 1 "список пуст"; fi
run theme Yaru > "$T/o" 2>&1
if [ "$(gv gtk-theme)" = "Yaru" ]; then say 0 "тема применена"; else say 1 "тема: $(gv gtk-theme)"; fi
run theme НетТакой > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "несуществующая тема отвергнута"; else say 1 "принял несуществующую"; fi
if grep -q 'доступные' "$T/o"; then say 0 "показал доступные"; else say 1 "не подсказал"; fi
run theme --light > /dev/null 2>&1
if [ "$(gv color-scheme)" = "prefer-light" ]; then say 0 "светлая схема"; else say 1 "схема: $(gv color-scheme)"; fi

echo
echo "== font =="
run font "Cantarell 12" > /dev/null 2>&1
if [ "$(gv font-name)" = "Cantarell 12" ]; then say 0 "шрифт применён"; else say 1 "шрифт: $(gv font-name)"; fi
run font "НетТакогоШрифта 11" > "$T/o" 2>&1
if grep -q 'нет' "$T/o"; then say 0 "несуществующий шрифт отвергнут"; else say 1 "принял несуществующий"; fi

echo
echo "== widget =="
run widget --radius 16 > "$T/o" 2>&1
LUA="$HOME/.config/conky/desktop-kit-bg.lua"
if grep -q 'local RADIUS = 16' "$LUA" 2>/dev/null; then say 0 "радиус 16"; else say 1 "нет радиуса"; fi
if grep -q '0.118, 0.118, 0.180' "$LUA" 2>/dev/null; then say 0 "цвет из конфига"; else say 1 "цвет неверный"; fi
if grep -q 'own_window_argb_value = 0' "$HOME/.config/conky/main.conf"; then say 0 "окно прозрачно"; else say 1 "argb не обнулён"; fi
run widget --radius 22 > /dev/null 2>&1
if grep -q 'local RADIUS = 22' "$LUA"; then say 0 "радиус меняется повторно"; else say 1 "радиус не сменился"; fi
if grep -q '0.882' "$LUA"; then say 0 "плотность взята из памяти, а не из обнулённого конфига"; else say 1 "плотность потеряна"; fi

echo
echo "== newtab =="
run newtab --list > "$T/o" 2>&1
if grep -q 'ESXi' "$T/o"; then say 0 "список ярлыков"; else say 1 "список пуст"; fi
run newtab --add "Wiki|https://wiki.local" > /dev/null 2>&1
if grep -q 'Wiki|https://wiki.local' "$HOME/.local/share/newtab/links.txt"; then say 0 "ярлык добавлен"; else say 1 "не добавлен"; fi
run newtab --add "Wiki|https://other" > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "дубликат отвергнут"; else say 1 "принял дубликат"; fi
run newtab --add "БезРазделителя" > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "строка без разделителя отвергнута"; else say 1 "принял без разделителя"; fi
run newtab --remove Wiki > /dev/null 2>&1
if grep -q 'Wiki' "$HOME/.local/share/newtab/links.txt"; then say 1 "ярлык не убран"; else say 0 "ярлык убран"; fi
if [ -f "$HOME/.local/share/newtab/index.html" ]; then say 0 "страница собрана"; else say 1 "страница не собралась"; fi

echo
echo "== wall =="
run wall --show > "$T/o" 2>&1
if grep -q 'картинок: 5' "$T/o"; then say 0 "картинки посчитаны"; else say 1 "счёт неверен"; fi
run wall > /dev/null 2>&1
CUR=$(cat "$HOME/.local/state/desktop-kit/current-wallpaper" 2>/dev/null)
if [ "$(basename "$CUR")" = "w1.jpg" ]; then say 0 "первая по порядку"; else say 1 "выбрана $(basename "$CUR")"; fi
run wall > /dev/null 2>&1
run wall > /dev/null 2>&1
CUR=$(cat "$HOME/.local/state/desktop-kit/current-wallpaper")
if [ "$(basename "$CUR")" = "w3.jpg" ]; then say 0 "идёт по порядку"; else say 1 "оказались на $(basename "$CUR")"; fi
run wall --prev > /dev/null 2>&1
CUR=$(cat "$HOME/.local/state/desktop-kit/current-wallpaper")
if [ "$(basename "$CUR")" = "w2.jpg" ]; then say 0 "назад по списку"; else say 1 "назад дало $(basename "$CUR")"; fi

echo
echo "== wallpapers =="
run wallpapers --status > "$T/o" 2>&1
if grep -q 'картинок:   5' "$T/o"; then say 0 "статус банка"; else say 1 "статус неверен"; fi
run wallpapers --urls > "$T/o" 2>&1
N=$(grep -c 'wallhaven.cc/api' "$T/o")
if [ "$N" -ge 12 ]; then say 0 "запросов: $N"; else say 1 "мало запросов: $N"; fi
if grep -q 'sorting=random' "$T/o"; then say 0 "случайная выдача"; else say 1 "нет random"; fi
if grep -q 'sorting=toplist' "$T/o"; then say 0 "лучшее за год"; else say 1 "нет toplist"; fi
A=$(run wallpapers --urls | grep 'q=' | head -3)
B=$(run wallpapers --urls | grep 'q=' | head -3)
if [ "$A" = "$B" ]; then say 0 "темы недели стабильны"; else say 1 "темы пляшут"; fi

echo
echo "== serve =="
run serve /нет/такого > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "несуществующий каталог отвергнут"; else say 1 "принял несуществующий"; fi
mkdir -p "$T/app"
run serve "$T/app" > "$T/o" 2>&1
if grep -q 'index.html' "$T/o"; then say 0 "каталог без index.html назван"; else say 1 "не проверил index.html"; fi

echo
echo "== app =="
mkdir -p "$T/usr-applications"
run app несуществующее --theme Yaru > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "неизвестное приложение отвергнуто"; else say 1 "принял неизвестное"; fi

echo
echo "== keys =="
run keys > "$T/o" 2>&1
if grep -q 'горячие клавиши' "$T/o"; then say 0 "команда отвечает"; else say 1 "нет вывода"; fi
run keys --add "Тест|echo hi|<Control>F12" > "$T/o" 2>&1
if grep -q 'custom-keybindings=' "$HOME/gs.store"; then say 0 "сочетание записано"; else say 1 "не записалось"; fi
if grep -q 'custom0' "$HOME/gs.store"; then say 0 "путь custom0 занят"; else say 1 "путь не создан"; fi
run keys --add "Второй|echo two|<Control>F11" > /dev/null 2>&1
LINE=$(grep '^custom-keybindings=' "$HOME/gs.store" | tail -1)
if echo "$LINE" | grep -q 'custom1'; then say 0 "второе сочетание не затёрло первое"; else say 1 "второе затёрло: $LINE"; fi
if echo "$LINE" | grep -q 'custom0'; then say 0 "первое осталось в списке"; else say 1 "первое пропало"; fi
run keys --add "БезРазделителей" > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "кривой формат отвергнут"; else say 1 "принял кривой формат"; fi
run keys --add > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "--add без значения отвергнут"; else say 1 "принял пустой --add"; fi

echo
echo "== panel =="
run panel > "$T/o" 2>&1
if grep -q 'панель задач' "$T/o"; then say 0 "команда отвечает"; else say 1 "нет вывода"; fi
run panel --opacity 150 > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "прозрачность больше 100 отвергнута"; else say 1 "принял 150"; fi
run panel --opacity abc > "$T/o" 2>&1
if [ "$?" != "0" ]; then say 0 "нечисловая прозрачность отвергнута"; else say 1 "принял 'abc'"; fi

echo
echo "== status =="
run status > "$T/o" 2>&1
if grep -q 'тема окон' "$T/o"; then say 0 "статус печатается"; else say 1 "статус пуст"; fi
if grep -q 'buttons' "$T/o"; then say 0 "видит применённые блоки"; else say 1 "не видит блоки"; fi

echo
echo "== revert =="
run revert buttons > /dev/null 2>&1
if grep -q 'dk:buttons-begin' "$C4"; then say 1 "кнопки остались"; else say 0 "кнопки убраны"; fi
if grep -q 'dk:corners-begin' "$C4"; then say 0 "углы не тронуты"; else say 1 "снесли углы заодно"; fi
run revert all > /dev/null 2>&1
if grep -q 'dk:' "$C3"; then say 1 "правила остались"; else say 0 "все правила убраны"; fi
if grep -q 'моя старая правка' "$C3"; then say 0 "чужой css уцелел"; else say 1 "потеряли чужое"; fi
if [ "$(gv gtk-theme)" = "Graphite-Dark" ]; then say 0 "тема вернулась"; else say 1 "тема: $(gv gtk-theme)"; fi
if [ "$(gv font-name)" = "Cantarell 11" ]; then say 0 "шрифт вернулся"; else say 1 "шрифт: $(gv font-name)"; fi
if grep -q 'own_window_argb_value = 225' "$HOME/.config/conky/main.conf"; then say 0 "conky восстановлен"; else say 1 "conky не вернулся"; fi
if [ -f "$HOME/Pictures/wallpapers-uw/w1.jpg" ]; then say 0 "обои не тронуты откатом"; else say 1 "откат снёс обои"; fi

echo
echo "== разрушительное поведение =="
# посторонний файл в каталоге обоев не должен исчезнуть
echo "мои заметки" > "$HOME/Pictures/wallpapers-uw/README.txt"
echo "не картинка" > "$HOME/Pictures/wallpapers-uw/notes.md"
run wallpapers --count 1 > /dev/null 2>&1
if [ -f "$HOME/Pictures/wallpapers-uw/README.txt" ]; then
    say 0 "чужой файл в каталоге обоев уцелел"
else
    say 1 "чистка удалила посторонний файл"
fi

# --dry-run revert не должен откатывать
run buttons > /dev/null 2>&1
run --dry-run revert all > "$T/o" 2>&1
if grep -q 'dk:buttons-begin' "$C3"; then
    say 0 "--dry-run revert ничего не откатил"
else
    say 1 "--dry-run revert реально откатил"
fi
if grep -q 'проверка' "$T/o"; then say 0 "--dry-run revert рассказал, что было бы"; else say 1 "промолчал"; fi

# имя ярлыка с метасимволами
run newtab --add "A.B|https://a.local" > /dev/null 2>&1
run newtab --add "AXB|https://b.local" > /dev/null 2>&1
run newtab --remove "A.B" > /dev/null 2>&1
if grep -qF 'AXB|' "$HOME/.local/share/newtab/links.txt"; then
    say 0 "точка в имени не съела соседний ярлык"
else
    say 1 "регулярка удалила лишнее"
fi
if grep -qF 'A.B|' "$HOME/.local/share/newtab/links.txt"; then
    say 1 "нужный ярлык не удалён"
else
    say 0 "нужный ярлык удалён"
fi

# правка, сделанная после установки, не должна пропасть при откате
run buttons > /dev/null 2>&1
echo "/* правка после установки */" >> "$C3"
run revert all > /dev/null 2>&1
if grep -q 'правка после установки' "$C3"; then
    say 0 "поздняя правка пережила откат"
else
    say 1 "откат стёр правку, сделанную после установки"
fi
if grep -q 'dk:' "$C3"; then say 1 "наши блоки остались"; else say 0 "наши блоки убраны"; fi

echo
echo "== selftest =="
run selftest > "$T/o" 2>&1
if grep -q 'проверок пройдено' "$T/o"; then say 0 "самопроверка отработала"; else say 1 "самопроверка молчит"; tail -5 "$T/o"; fi
if [ -f "$HOME/desktop-kit-selftest/selftest.md" ]; then say 0 "отчёт создан"; else say 1 "нет отчёта"; fi
if [ -f "$HOME/desktop-kit-selftest.tar.gz" ]; then say 0 "архив собран"; else say 1 "нет архива"; fi
if grep -q 'OK   ' "$HOME/desktop-kit-selftest/selftest.md" 2>/dev/null; then say 0 "в отчёте есть результаты"; else say 1 "отчёт пуст"; fi

echo
echo "== лог =="
if [ -f "$HOME/.local/state/desktop-kit/desktop-kit.log" ]; then say 0 "лог пишется"; else say 1 "лога нет"; fi
if grep -q 'запуск: buttons' "$HOME/.local/state/desktop-kit/desktop-kit.log"; then say 0 "в логе есть запуски"; else say 1 "лог пуст"; fi

rm -rf "$T"
echo
if [ "$FAIL" = "0" ]; then echo "все проверки прошли"; else echo "ЕСТЬ ПРОВАЛЫ"; fi
exit "$FAIL"
