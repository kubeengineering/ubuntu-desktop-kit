#!/usr/bin/env bash
# ubuntu-desktop-bootstrap.sh
# Разворачивает рабочий десктоп на свежей Ubuntu 24.04 GNOME:
# тема, шрифты, виджеты, обои с палитрой, утилиты, хоткеи.
# Идемпотентен — можно запускать повторно.
#
#   chmod +x ubuntu-desktop-bootstrap.sh && ./ubuntu-desktop-bootstrap.sh
#
# Без sudo внутри там, где не нужно. Пароль спросит один раз в начале.

set -uo pipefail

WALL_DIR="$HOME/Pictures/wallpapers"
BIN="$HOME/bin"
CITY="Moscow"

c()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok() { printf '    \033[32m✓\033[0m %s\n' "$*"; }
no() { printf '    \033[31m✗\033[0m %s\n' "$*"; }

[ "$(id -u)" -eq 0 ] && { no "Не запускай от root — скрипт сам спросит sudo"; exit 1; }
command -v apt >/dev/null || { no "Это не Debian/Ubuntu"; exit 1; }

sudo -v || exit 1
# держим sudo живым, пока идёт установка
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

# ─────────────────────────────────────────────────────────── пакеты
c "Пакеты из репозиториев"
sudo apt update -qq
sudo apt install -y -qq \
    gnome-tweaks gnome-shell-extension-manager papirus-icon-theme dconf-cli \
    conky-all rofi flameshot feh imagemagick jq curl wget git unzip \
    lsd bat ranger zathura zathura-pdf-poppler btop calcurse ncal \
    gpick xclip xsel mat2 pipx dex policykit-1-gnome gnome-keyring \
    xdg-desktop-portal-gtk lm-sensors neofetch gnome-calendar \
    fonts-jetbrains-mono >/dev/null 2>&1 && ok "установлены" || no "часть пакетов не встала"

# ─────────────────────────────────────────────────────────── шрифт
c "JetBrainsMono Nerd Font"
if fc-list 2>/dev/null | grep -q "JetBrainsMono Nerd"; then
    ok "уже стоит"
else
    mkdir -p "$HOME/.local/share/fonts"
    wget -qO /tmp/JBM.zip \
        https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/JetBrainsMono.zip &&
    unzip -qo /tmp/JBM.zip -d "$HOME/.local/share/fonts/JetBrainsMono" &&
    fc-cache -f >/dev/null && rm -f /tmp/JBM.zip && ok "установлен" || no "не скачался"
fi

# ─────────────────────────────────────────────────────────── тема
c "Тема Tokyo Night"
if [ -d "$HOME/.themes/Tokyonight-Dark" ]; then
    ok "уже стоит"
else
    mkdir -p "$HOME/.themes"
    git clone -q --depth 1 https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme /tmp/tn &&
    cp -r /tmp/tn/themes/* "$HOME/.themes/" && rm -rf /tmp/tn && ok "установлена" || no "не склонировалась"
fi

# ─────────────────────────────────────────────────────────── pywal
c "pywal16"
if command -v wal >/dev/null; then
    ok "уже стоит"
else
    pipx install pywal16 >/dev/null 2>&1 && pipx ensurepath >/dev/null 2>&1 && ok "установлен" || no "не встал"
fi
export PATH="$HOME/.local/bin:$PATH"

mkdir -p "$HOME/.config/wal/templates"
cat > "$HOME/.config/wal/templates/colors-kitty.conf" <<'T'
foreground {foreground}
background {background}
cursor {cursor}
color0 {color0}
color1 {color1}
color2 {color2}
color3 {color3}
color4 {color4}
color5 {color5}
color6 {color6}
color7 {color7}
color8 {color8}
color9 {color9}
color10 {color10}
color11 {color11}
color12 {color12}
color13 {color13}
color14 {color14}
color15 {color15}
T
ok "шаблон палитры готов"

# ─────────────────────────────────────────────────────────── расширения GNOME
c "Расширения GNOME"
if ! command -v gext >/dev/null; then
    pipx install gnome-extensions-cli >/dev/null 2>&1
fi
if command -v gext >/dev/null; then
    for e in blur-my-shell@aunetx dash-to-panel@jderose9.github.com \
             just-perfection-desktop@just-perfection Vitals@CoreCoding.com \
             user-theme@gnome-shell-extensions.gcampax.github.com; do
        gext install "$e" >/dev/null 2>&1 && ok "$e" || no "$e (поставь вручную через Extension Manager)"
    done
else
    no "gext не встал — расширения ставь через Extension Manager"
fi

# ─────────────────────────────────────────────────────────── обои
c "Обои"
mkdir -p "$WALL_DIR"
have=$(find "$WALL_DIR" -maxdepth 1 -type f | wc -l)
if [ "$have" -ge 30 ]; then
    ok "уже есть $have шт."
else
    RES=$(xrandr 2>/dev/null | grep -oP '\d+x\d+' | head -1)
    [ -z "$RES" ] && RES="1920x1080"
    ok "целевое разрешение: $RES"
    for q in nature minimal space mountains dark city abstract forest; do
        curl -s "https://wallhaven.cc/api/v1/search?q=$q&atleast=$RES&categories=100&purity=100&sorting=views" \
            | jq -r '.data[].path' 2>/dev/null
        sleep 2
    done | grep '\.jpg$' | sort -u > /tmp/wl.txt
    ( cd "$WALL_DIR" && xargs -n1 -P3 curl -sO < /tmp/wl.txt )
    find "$WALL_DIR" -type f -size +12M -delete
    ok "скачано: $(find "$WALL_DIR" -maxdepth 1 -type f | wc -l)"
fi

# ─────────────────────────────────────────────────────────── скрипты
c "Скрипты в ~/bin"
mkdir -p "$BIN"

cat > "$BIN/weather-line" <<EOF
#!/bin/bash
CITY="\${1:-$CITY}"
curl -s "https://wttr.in/\$CITY?format=%t++%C&lang=ru" --max-time 5
echo
curl -s "https://wttr.in/\$CITY?format=Ветер+%w++Влажность+%h&lang=ru" --max-time 5
EOF

cat > "$BIN/conky-recolor" <<'EOF'
#!/bin/bash
[ -f ~/.cache/wal/colors.sh ] || exit
source ~/.cache/wal/colors.sh
for f in ~/.config/conky/*.conf; do
    [ -f "$f" ] || continue
    sed -i "s/own_window_colour = '.*'/own_window_colour = '${background#\#}'/" "$f"
    sed -i "s/default_color = '.*'/default_color = '${foreground#\#}'/" "$f"
    sed -i "s/color1 = '.*'/color1 = '${color4#\#}'/" "$f"
done
pkill conky; sleep 0.5
for f in ~/.config/conky/*.conf; do conky -c "$f" & done
EOF

cat > "$BIN/setwall" <<EOF
#!/bin/bash
DIR="$WALL_DIR"
HIST=~/.cache/wallhistory
FAV=~/.cache/wallfav
PIN=~/.cache/wallpin
touch "\$HIST" "\$FAV"

term_colors() {
    [ -f ~/.cache/wal/colors.sh ] || return
    source ~/.cache/wal/colors.sh
    local p; p=\$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
    [ -z "\$p" ] && return
    local b="/org/gnome/terminal/legacy/profiles:/:\$p/"
    dconf write "\${b}use-theme-colors" "false"
    dconf write "\${b}background-color" "'\$background'"
    dconf write "\${b}foreground-color" "'\$foreground'"
    dconf write "\${b}cursor-colors-set" "true"
    dconf write "\${b}cursor-background-color" "'\$cursor'"
    dconf write "\${b}palette" "['\$color0','\$color1','\$color2','\$color3','\$color4','\$color5','\$color6','\$color7','\$color8','\$color9','\$color10','\$color11','\$color12','\$color13','\$color14','\$color15']"
}

apply() {
    wal -i "\$1" -n -q 2>/dev/null
    gsettings set org.gnome.desktop.background picture-uri "file://\$1"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://\$1"
    gsettings set org.gnome.desktop.screensaver picture-uri "file://\$1"
    term_colors
    ~/bin/conky-recolor 2>/dev/null
    notify-send -t 2000 "Обои" "\$(basename "\$1")  ·  всего: \$(find "\$DIR" -maxdepth 1 -type f | wc -l)"
}

current() { gsettings get org.gnome.desktop.background picture-uri-dark | tr -d "'" | sed 's|^file://||'; }

case "\${1:-}" in
  pin)
    if [ -f "\$PIN" ]; then rm -f "\$PIN"; notify-send -t 2500 "Обои" "Откреплены";
    else touch "\$PIN"; notify-send -t 2500 "Обои" "Закреплены: \$(basename "\$(current)")"; fi ;;
  fav)
    C=\$(current); grep -qxF "\$C" "\$FAV" || echo "\$C" >> "\$FAV"
    notify-send -t 2500 "Избранное" "\$(basename "\$C")  ·  \$(wc -l < "\$FAV") шт." ;;
  favs)
    [ -s "\$FAV" ] || { notify-send -t 2000 "Избранное" "Пусто"; exit; }
    W=\$(shuf -n1 "\$FAV"); [ -f "\$W" ] && { echo "\$W" >> "\$HIST"; apply "\$W"; } ;;
  prev)
    [ -f "\$PIN" ] && { notify-send -t 2000 "Обои" "Закреплены"; exit; }
    [ "\$(wc -l < "\$HIST")" -lt 2 ] && { notify-send -t 2000 "Обои" "История пуста"; exit; }
    sed -i '\$d' "\$HIST"; W=\$(tail -1 "\$HIST"); [ -f "\$W" ] && apply "\$W" ;;
  *)
    [ -f "\$PIN" ] && { notify-send -t 2000 "Обои" "Закреплены — Super+P чтобы открепить"; exit; }
    W=\$(find "\$DIR" -maxdepth 1 -type f | shuf -n1)
    echo "\$W" >> "\$HIST"; tail -100 "\$HIST" > "\$HIST.tmp" && mv "\$HIST.tmp" "\$HIST"
    apply "\$W" ;;
esac
EOF

cat > "$BIN/powermenu" <<'EOF'
#!/bin/bash
C=$(printf "Заблокировать\nВыйти\nПерезагрузка\nВыключить\nСон" | rofi -dmenu -i -p "Питание")
case "$C" in
    "Заблокировать") loginctl lock-session ;;
    "Выйти") gnome-session-quit --logout --no-prompt ;;
    "Перезагрузка") systemctl reboot ;;
    "Выключить") systemctl poweroff ;;
    "Сон") systemctl suspend ;;
esac
EOF

cat > "$BIN/wifimenu" <<'EOF'
#!/bin/bash
nmcli device wifi rescan 2>/dev/null
SSID=$(nmcli -f SSID,SIGNAL device wifi list | tail -n +2 | sort -k2 -rn \
       | rofi -dmenu -i -p "Wi-Fi" | sed 's/ *[0-9]*$//' | sed 's/ *$//')
[ -z "$SSID" ] && exit
nmcli device wifi connect "$SSID" 2>/dev/null || {
    P=$(rofi -dmenu -password -p "Пароль")
    nmcli device wifi connect "$SSID" password "$P"
}
EOF

cat > "$BIN/pickcolor" <<'EOF'
#!/bin/bash
C=$(gpick -p -s -o 2>/dev/null | head -1)
[ -n "$C" ] && echo -n "$C" | xclip -selection clipboard && notify-send -t 3000 "Цвет скопирован" "$C"
EOF

cat > "$BIN/cleanmeta" <<'EOF'
#!/bin/bash
for f in "$@"; do mat2 --inplace "$f" && echo "cleaned: $f"; done
EOF

chmod +x "$BIN"/*
ok "setwall, weather-line, conky-recolor, powermenu, wifimenu, pickcolor, cleanmeta"

# ─────────────────────────────────────────────────────────── conky
c "Виджет Conky"
mkdir -p "$HOME/.config/conky"
cat > "$HOME/.config/conky/main.conf" <<'EOF'
conky.config = {
    alignment = 'top_right',
    gap_x = 60, gap_y = 60, minimum_width = 340,
    own_window = true, own_window_type = 'desktop',
    own_window_transparent = false, own_window_argb_visual = true,
    own_window_argb_value = 225, own_window_colour = '1e1e2e',
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    double_buffer = true, update_interval = 1.0, border_inner_margin = 20,
    use_xft = true, font = 'JetBrainsMono Nerd Font:size=10',
    override_utf8_locale = true,
    default_color = 'CDD6F4', color1 = '89B4FA', color2 = 'A6E3A1',
}
conky.text = [[
${color1}${font JetBrainsMono Nerd Font:size=48}${time %H:%M}${font}${color}
${font JetBrainsMono Nerd Font:size=12}${time %A, %d %B %Y}${font}

${color1}ПОГОДА${color}
${execpi 900 $HOME/bin/weather-line}

${color1}СИСТЕМА${color}
Процессор${goto 130}${cpu cpu0}%${alignr}${cpubar 6,110}
Память${goto 130}${memperc}%${alignr}${membar 6,110}
Диск${goto 130}${fs_used_perc /}%${alignr}${fs_bar 6,110 /}

${color1}СЕТЬ${color}
${if_existing /proc/net/route wlan0}Приём${goto 130}${downspeed wlan0}
Передача${goto 130}${upspeed wlan0}${endif}
${if_up tun0}${color2}VPN активен${color}${endif}
]]
EOF

# подставляем реальное имя wifi-интерфейса
IFACE=$(ip -br link 2>/dev/null | awk '$1 ~ /^wl/ {print $1; exit}')
[ -n "$IFACE" ] && sed -i "s/wlan0/$IFACE/g" "$HOME/.config/conky/main.conf" && ok "wifi-интерфейс: $IFACE"

mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/conky.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Conky
Exec=bash -c "sleep 5; conky -c $HOME/.config/conky/main.conf"
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
ok "виджет + автозапуск"

# ─────────────────────────────────────────────────────────── алиасы
c "Алиасы и функции"
if ! grep -q "# --- bootstrap aliases ---" "$HOME/.bashrc" 2>/dev/null; then
cat >> "$HOME/.bashrc" <<'EOF'

# --- bootstrap aliases ---
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
alias ls='lsd'
alias ll='lsd -l'
alias la='lsd -la'
alias lt='lsd --tree'
alias c='batcat'
alias walls='find ~/Pictures/wallpapers -maxdepth 1 -type f | wc -l'

ranger_cd() {
    local tmp; tmp="$(mktemp -t ranger_cd.XXXXXX)"
    ranger --choosedir="$tmp" -- "${@:-$PWD}"
    local dir; dir="$(command cat -- "$tmp")"
    [ -n "$dir" ] && [ "$dir" != "$PWD" ] && cd -- "$dir"
    rm -f -- "$tmp"
}
alias r='ranger_cd'
EOF
ok "добавлены в .bashrc"
else
ok "уже прописаны"
fi

# ─────────────────────────────────────────────────────────── внешний вид
c "Настройки GNOME"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Tokyonight-Dark' 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.interface clock-show-seconds false
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 6
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.session idle-delay 900
ok "тема, иконки, шрифт, рабочие столы"

# ─────────────────────────────────────────────────────────── хоткеи
c "Горячие клавиши"
K=org.gnome.settings-daemon.plugins.media-keys
P=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings

add_key() { # имя команда клавиши индекс
    local path="$P/custom$4/"
    dconf write "${path}name"    "'$1'"
    dconf write "${path}command" "'$2'"
    dconf write "${path}binding" "'$3'"
    ok "$3 → $1"
}

add_key "Rofi"          "rofi -show drun"          "<Super>d"        0
add_key "Flameshot"     "flameshot gui"            "<Super><Shift>s" 1
add_key "Wallpaper"     "$BIN/setwall"             "<Control>r"      2
add_key "Wallpaper prev" "$BIN/setwall prev"       "<Control><Shift>r" 3
add_key "Wallpaper pin" "$BIN/setwall pin"         "<Super>p"        4
add_key "Wallpaper fav" "$BIN/setwall fav"         "<Super>f"        5
add_key "Powermenu"     "$BIN/powermenu"           "<Super>x"        6
add_key "Wifimenu"      "$BIN/wifimenu"            "<Super>w"        7
add_key "Pick color"    "$BIN/pickcolor"           "<Super><Shift>c" 8
add_key "Calendar"      "gnome-calendar"           "<Super>c"        9

LIST=""
for i in $(seq 0 9); do LIST="$LIST'$P/custom$i/',"; done
dconf write "$K/custom-keybindings" "[${LIST%,}]"
ok "список зарегистрирован"

# ─────────────────────────────────────────────────────────── финал
c "Первый запуск"
FIRST=$(find "$WALL_DIR" -maxdepth 1 -type f | head -1)
[ -n "$FIRST" ] && "$BIN/setwall" >/dev/null 2>&1 && ok "обои и палитра применены"
pkill conky 2>/dev/null; (conky -c "$HOME/.config/conky/main.conf" &) 2>/dev/null
ok "виджет запущен"

cat <<'FIN'

────────────────────────────────────────────────
  ГОТОВО

  Осталось руками:
   1. Перелогиниться — подхватятся тема и алиасы
   2. Extension Manager → настроить Blur My Shell,
      Dash to Panel, Just Perfection под себя
   3. Settings → Online Accounts → почта и календарь

  Клавиши:
   Super+D            меню приложений
   Super+Shift+S      скриншот
   Ctrl+R / Ctrl+Sh+R обои вперёд / назад
   Super+P            закрепить обои
   Super+F            в избранное
   Super+X            меню питания
   Super+W            Wi-Fi
   Super+Shift+C      пипетка цвета
   Super+C            календарь
   r                  ranger с переходом в каталог
────────────────────────────────────────────────
FIN
