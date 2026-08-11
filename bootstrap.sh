#!/usr/bin/env bash
# ubuntu-desktop-kit bootstrap v2
# Разворачивает настроенный десктоп на свежей Ubuntu 24.04 GNOME:
# тема, шрифты, виджет, обои с палитрой, утилиты, хоткеи.
# Идемпотентен — можно запускать повторно, ничего не сломает.
#
#   ./bootstrap.sh                # обычный запуск
#   ./bootstrap.sh --xorg         # + сразу переключить вход по умолчанию на Xorg
#   ./bootstrap.sh --keep-wayland # не задавать вопрос про Xorg
#
# Лог всех скрытых операций: ~/.cache/ubuntu-kit-bootstrap.log

set -uo pipefail

# ─────────────────────────────────────────────── база
LOG="$HOME/.cache/ubuntu-kit-bootstrap.log"
mkdir -p "$HOME/.cache"; : > "$LOG"
CITY="${CITY:-Moscow}"
BIN="$HOME/bin"
FLAG="${1:-}"

# каталог картинок с учётом локали (~/Изображения на русской системе)
_pics=$(xdg-user-dir PICTURES 2>/dev/null || true)
{ [ -z "$_pics" ] || [ "$_pics" = "$HOME" ]; } && _pics="$HOME/Pictures"
WALL_DIR="$_pics/wallpapers"

FAILS=0
c()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok() { printf '    \033[32m✓\033[0m %s\n' "$*"; }
no() { printf '    \033[31m✗\033[0m %s\n' "$*"; FAILS=$((FAILS+1)); }
wr() { printf '    \033[33m!\033[0m %s\n' "$*"; }

[ "$FLAG" = "-h" ] || [ "$FLAG" = "--help" ] && { sed -n '2,11p' "$0"; exit 0; }
[ "$(id -u)" -eq 0 ] && { echo "Не запускай от root — скрипт сам спросит sudo"; exit 1; }
command -v apt-get >/dev/null || { echo "Это не Debian/Ubuntu"; exit 1; }

export PATH="$HOME/.local/bin:$BIN:$PATH"
SESSION="${XDG_SESSION_TYPE:-unknown}"

sudo -v || exit 1
( while true; do sleep 50; sudo -n true 2>/dev/null || exit; done ) &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null' EXIT

# ─────────────────────────────────────────────── Wayland / Xorg
# Набор X11-нативный: conky, rofi, gpick под Wayland работают плохо или никак.
if [ "$SESSION" = "wayland" ]; then
    c "Сессия Wayland"
    wr "Свежая Ubuntu входит в Wayland, а этот набор рассчитан на Xorg:"
    wr "виджет может не показаться, rofi терять клавиатуру, пипетка не работать."
    DO_XORG=ask
    [ "$FLAG" = "--xorg" ] && DO_XORG=yes
    [ "$FLAG" = "--keep-wayland" ] && DO_XORG=no
    if [ "$DO_XORG" = "ask" ]; then
        if [ -t 0 ]; then
            read -r -p "    Сделать Xorg сессией по умолчанию (нужна перезагрузка)? [y/N] " a
            case "$a" in y|Y|д|Д) DO_XORG=yes ;; *) DO_XORG=no ;; esac
        else
            DO_XORG=no
            wr "Запуск не из терминала — оставляю Wayland. Флаг --xorg переключит."
        fi
    fi
    if [ "$DO_XORG" = "yes" ]; then
        sudo sed -i 's/^#\s*WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
        if grep -q '^WaylandEnable=false' /etc/gdm3/custom.conf; then
            ok "Xorg станет сессией по умолчанию после перезагрузки"
        else
            no "не вышло — раскомментируй WaylandEnable=false в /etc/gdm3/custom.conf"
        fi
    else
        wr "Остаёмся на Wayland — на экране входа можно выбрать «Ubuntu on Xorg» шестерёнкой"
    fi
fi

# ─────────────────────────────────────────────── пакеты
c "Пакеты из репозиториев"
APT="sudo apt-get -o DPkg::Lock::Timeout=600"

if ! $APT update --error-on=any >>"$LOG" 2>&1; then
    no "apt update не прошёл — нет сети / captive portal / система ещё ставит обновления первого запуска"
    echo "    Подключи сеть, подожди пару минут и запусти скрипт снова. Лог: $LOG"
    exit 1
fi
ok "индексы обновлены"

PKGS=(
    gnome-tweaks gnome-shell-extension-manager gnome-shell-extensions
    papirus-icon-theme dconf-cli sassc
    conky-all rofi flameshot feh imagemagick jq curl wget git unzip file
    lsd bat ranger zathura zathura-pdf-poppler btop calcurse
    gpick xclip xsel mat2 pipx gnome-keyring
    xdg-desktop-portal-gtk lm-sensors gir1.2-gtop-2.0 neofetch gnome-calendar
    fonts-jetbrains-mono
    copyq gnome-sushi fzf zoxide tealdeer
)
if $APT install -y "${PKGS[@]}" >>"$LOG" 2>&1; then
    ok "установлены все ${#PKGS[@]}"
else
    wr "общая установка не прошла — ставлю по одному (см. $LOG)"
    for p in "${PKGS[@]}"; do
        $APT install -y "$p" >>"$LOG" 2>&1 || no "пакет $p"
    done
fi

# без этого ядра продолжать бессмысленно — конфиги лягут поверх пустоты
CORE_MISSING=0
for t in git curl jq unzip conky rofi; do
    command -v "$t" >/dev/null || { no "нет $t"; CORE_MISSING=1; }
done
[ "$CORE_MISSING" -eq 1 ] && { echo; echo "Базовые пакеты не встали — смотри $LOG, чини apt и перезапускай."; exit 1; }

# ─────────────────────────────────────────────── шрифт
c "JetBrainsMono Nerd Font"
if fc-list 2>/dev/null | grep -q "JetBrainsMono Nerd"; then
    ok "уже стоит"
else
    mkdir -p "$HOME/.local/share/fonts"
    if wget -q --timeout=30 --tries=2 -O /tmp/JBM.zip \
        https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/JetBrainsMono.zip &&
       unzip -qo /tmp/JBM.zip -d "$HOME/.local/share/fonts/JetBrainsMono"; then
        fc-cache -f >/dev/null 2>&1; rm -f /tmp/JBM.zip
        ok "установлен"
    else
        no "не скачался с GitHub — иконки будут квадратами (см. $LOG)"
    fi
fi

# ─────────────────────────────────────────────── тема Tokyo Night
# в репозитории НЕТ готовых тем — они собираются из исходников её же install.sh
c "Тема Tokyo Night (сборка)"
if [ -d "$HOME/.themes/Tokyonight-Dark" ]; then
    ok "уже собрана"
else
    rm -rf /tmp/tn
    if timeout 180 git clone -q --depth 1 \
        https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme /tmp/tn >>"$LOG" 2>&1 &&
       bash /tmp/tn/themes/install.sh -l >>"$LOG" 2>&1; then :; fi
    rm -rf /tmp/tn
    if [ -d "$HOME/.themes/Tokyonight-Dark" ]; then
        ok "собрана и слинкована для GTK4 (-l)"
    else
        no "сборка темы не прошла — останется Yaru (см. $LOG)"
    fi
fi

# ─────────────────────────────────────────────── pywal16
c "pywal16 (палитра из обоев)"
if command -v wal >/dev/null; then
    ok "уже стоит"
else
    pipx install pywal16 >>"$LOG" 2>&1 && pipx ensurepath >>"$LOG" 2>&1
    hash -r
    command -v wal >/dev/null && ok "установлен" || no "не встал (см. $LOG)"
fi

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

# ─────────────────────────────────────────────── расширения GNOME
c "Расширения GNOME"
if ! command -v gext >/dev/null; then
    pipx install gnome-extensions-cli >>"$LOG" 2>&1
    hash -r
fi

EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
EXTS=(
    blur-my-shell@aunetx
    dash-to-panel@jderose9.github.com
    just-perfection-desktop@just-perfection
    Vitals@CoreCoding.com
)
if command -v gext >/dev/null; then
    for e in "${EXTS[@]}"; do
        if [ -d "$EXT_DIR/$e" ]; then
            ok "$e (уже стоит)"
        # --filesystem: без пяти модальных диалогов, которые даёт dbus-бэкенд
        elif gext --filesystem install "$e" >>"$LOG" 2>&1; then
            ok "$e"
        else
            no "$e — поставь через Extension Manager"
        fi
    done
else
    no "gext не встал — расширения ставь вручную через Extension Manager"
fi

# включаем всё (+ user-theme из apt-пакета), гасим ubuntu-dock:
# он навязан сессией и после релогина повис бы ПОВЕРХ dash-to-panel
python3 - blur-my-shell@aunetx dash-to-panel@jderose9.github.com \
    just-perfection-desktop@just-perfection Vitals@CoreCoding.com \
    user-theme@gnome-shell-extensions.gcampax.github.com \
    -ubuntu-dock@ubuntu.com <<'PY' && ok "включены (активируются после релогина)" || no "не смог обновить список расширений"
import ast, subprocess, sys
def get(key):
    out = subprocess.run(["gsettings","get","org.gnome.shell",key],
                         capture_output=True, text=True).stdout.strip()
    if not out or out.startswith("@as"): return []
    try: return list(ast.literal_eval(out))
    except Exception: return []
def put(key, lst):
    r = subprocess.run(["gsettings","set","org.gnome.shell",key,str(lst)])
    if r.returncode: sys.exit(1)
en, dis = get("enabled-extensions"), get("disabled-extensions")
for u in sys.argv[1:]:
    if u.startswith("-"):
        u = u[1:]
        if u not in dis: dis.append(u)
        if u in en: en.remove(u)
    else:
        if u not in en: en.append(u)
        if u in dis: dis.remove(u)
put("enabled-extensions", en); put("disabled-extensions", dis)
PY

# тема оболочки для user-theme (gsettings не видит схему расширения — пишем в dconf)
dconf write /org/gnome/shell/extensions/user-theme/name "'Tokyonight-Dark'" 2>>"$LOG" \
    && ok "shell-тема: Tokyonight-Dark" || no "shell-тема не назначена"

# ─────────────────────────────────────────────── обои
c "Обои"
mkdir -p "$WALL_DIR"
have=$(find "$WALL_DIR" -maxdepth 1 -type f | wc -l)
if [ "$have" -ge 30 ]; then
    ok "уже есть $have шт."
else
    # реальное железное разрешение панели — работает и на Wayland, и по SSH
    RES=$(cat /sys/class/drm/card*-*/modes 2>/dev/null | grep -oE '^[0-9]+x[0-9]+$' \
          | sort -t x -k1,1nr -k2,2nr | head -1)
    [ -z "$RES" ] && RES=$(xrandr 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | head -1)
    [ -z "$RES" ] && RES=1920x1080
    ok "целевое разрешение: $RES"
    : > /tmp/wl.txt
    for q in nature minimal space mountains dark city abstract forest; do
        curl -sf --max-time 20 \
          "https://wallhaven.cc/api/v1/search?q=$q&atleast=$RES&categories=100&purity=100&sorting=views" \
          | jq -r '.data[].path' 2>/dev/null
        sleep 2   # лимит wallhaven — 45 запросов/мин
    done | grep '\.jpg$' | sort -u > /tmp/wl.txt
    if [ -s /tmp/wl.txt ]; then
        ( cd "$WALL_DIR" && xargs -r -n1 -P3 \
            curl -sf --retry 2 --retry-delay 2 --max-time 120 --remove-on-error -O \
            < /tmp/wl.txt ) >>"$LOG" 2>&1
        # выкинуть html-мусор и битое
        for f in "$WALL_DIR"/*; do
            [ -f "$f" ] || continue
            file --brief --mime-type "$f" | grep -q '^image/' || rm -f "$f"
        done
        find "$WALL_DIR" -maxdepth 1 -type f -size +12M -delete
        now=$(find "$WALL_DIR" -maxdepth 1 -type f | wc -l)
        if [ "$now" -gt "$have" ]; then
            ok "скачано $((now-have)), всего $now"
        else
            no "ничего не скачалось — обои добавишь позже (см. $LOG)"
        fi
    else
        no "wallhaven недоступен — обои пропущены, добавь картинки в $WALL_DIR"
    fi
fi

# ─────────────────────────────────────────────── скрипты в ~/bin
c "Скрипты в ~/bin"
mkdir -p "$BIN"

cat > "$BIN/weather-line" <<'EOF'
#!/bin/bash
CITY="${1:-@CITY@}"
curl -sf "https://wttr.in/$CITY?format=%t++%C&lang=ru" --max-time 5
echo
curl -sf "https://wttr.in/$CITY?format=Ветер+%w++Влажность+%h&lang=ru" --max-time 5
EOF

cat > "$BIN/conky-recolor" <<'EOF'
#!/bin/bash
[ -f ~/.cache/wal/colors.sh ] || exit 0
source ~/.cache/wal/colors.sh
for f in ~/.config/conky/*.conf; do
    [ -f "$f" ] || continue
    sed -i "s/own_window_colour = '.*'/own_window_colour = '${background#\#}'/" "$f"
    sed -i "s/default_color = '.*'/default_color = '${foreground#\#}'/" "$f"
    sed -i "s/color1 = '.*'/color1 = '${color4#\#}'/" "$f"
done
pkill -x conky 2>/dev/null; sleep 0.5
for f in ~/.config/conky/*.conf; do conky -c "$f" & done
EOF

cat > "$BIN/setwall" <<'EOF'
#!/bin/bash
DIR="@WALLDIR@"
HIST=~/.cache/wallhistory
FAV=~/.cache/wallfav
PIN=~/.cache/wallpin
touch "$HIST" "$FAV"

term_colors() {
    [ -f ~/.cache/wal/colors.sh ] || return
    source ~/.cache/wal/colors.sh
    local p; p=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    [ -z "$p" ] && return
    local b="/org/gnome/terminal/legacy/profiles:/:$p/"
    dconf write "${b}use-theme-colors" "false"
    dconf write "${b}background-color" "'$background'"
    dconf write "${b}foreground-color" "'$foreground'"
    dconf write "${b}cursor-colors-set" "true"
    dconf write "${b}cursor-background-color" "'$cursor'"
    dconf write "${b}palette" "['$color0','$color1','$color2','$color3','$color4','$color5','$color6','$color7','$color8','$color9','$color10','$color11','$color12','$color13','$color14','$color15']"
}

apply() {
    command -v wal >/dev/null && wal -i "$1" -n -q 2>/dev/null
    gsettings set org.gnome.desktop.background picture-uri "file://$1"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$1"
    gsettings set org.gnome.desktop.screensaver picture-uri "file://$1"
    term_colors
    ~/bin/conky-recolor 2>/dev/null
    notify-send -t 2000 "Обои" "$(basename "$1")  ·  всего: $(find "$DIR" -maxdepth 1 -type f | wc -l)" 2>/dev/null
}

current() { gsettings get org.gnome.desktop.background picture-uri-dark | tr -d "'" | sed 's|^file://||'; }

case "${1:-}" in
  pin)
    if [ -f "$PIN" ]; then rm -f "$PIN"; notify-send -t 2500 "Обои" "Откреплены";
    else touch "$PIN"; notify-send -t 2500 "Обои" "Закреплены: $(basename "$(current)")"; fi ;;
  fav)
    C=$(current); grep -qxF "$C" "$FAV" || echo "$C" >> "$FAV"
    notify-send -t 2500 "Избранное" "$(basename "$C")  ·  $(wc -l < "$FAV") шт." ;;
  favs)
    [ -s "$FAV" ] || { notify-send -t 2000 "Избранное" "Пусто"; exit 0; }
    W=$(shuf -n1 "$FAV"); [ -f "$W" ] && { echo "$W" >> "$HIST"; apply "$W"; } ;;
  prev)
    [ -f "$PIN" ] && { notify-send -t 2000 "Обои" "Закреплены"; exit 0; }
    [ "$(wc -l < "$HIST")" -lt 2 ] && { notify-send -t 2000 "Обои" "История пуста"; exit 0; }
    sed -i '$d' "$HIST"; W=$(tail -1 "$HIST"); [ -f "$W" ] && apply "$W" ;;
  *)
    [ -f "$PIN" ] && { notify-send -t 2000 "Обои" "Закреплены — Super+P чтобы открепить"; exit 0; }
    W=$(find "$DIR" -maxdepth 1 -type f | shuf -n1)
    [ -z "$W" ] && { notify-send -t 2500 "Обои" "Каталог пуст: $DIR"; exit 0; }
    echo "$W" >> "$HIST"; tail -100 "$HIST" > "$HIST.tmp" && mv "$HIST.tmp" "$HIST"
    apply "$W" ;;
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
[ -z "$SSID" ] && exit 0
nmcli device wifi connect "$SSID" 2>/dev/null || {
    P=$(rofi -dmenu -password -p "Пароль")
    nmcli device wifi connect "$SSID" password "$P"
}
EOF

cat > "$BIN/pickcolor" <<'EOF'
#!/bin/bash
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    notify-send -t 4000 "Пипетка" "gpick не работает на Wayland — поставь расширение Color Picker или войди в Xorg"
    exit 1
fi
C=$(gpick -p -s -o 2>/dev/null | head -1)
if [ -n "$C" ]; then
    echo -n "$C" | xclip -selection clipboard
    notify-send -t 3000 "Цвет скопирован" "$C"
else
    notify-send -t 3000 "Пипетка" "не удалось снять цвет"
fi
EOF

cat > "$BIN/cleanmeta" <<'EOF'
#!/bin/bash
for f in "$@"; do mat2 --inplace "$f" && echo "cleaned: $f"; done
EOF

sed -i "s|@CITY@|$CITY|" "$BIN/weather-line"
sed -i "s|@WALLDIR@|$WALL_DIR|" "$BIN/setwall"
chmod +x "$BIN"/weather-line "$BIN"/conky-recolor "$BIN"/setwall \
         "$BIN"/powermenu "$BIN"/wifimenu "$BIN"/pickcolor "$BIN"/cleanmeta
ok "setwall, weather-line, conky-recolor, powermenu, wifimenu, pickcolor, cleanmeta"

# ─────────────────────────────────────────────── мелочи из bspwm-dotfiles
c "Color-scripts и иконки ranger"
if [ -d "$BIN/color-scripts" ]; then
    ok "color-scripts уже есть"
else
    if timeout 120 git clone -q --depth 1 \
        https://github.com/Zproger/bspwm-dotfiles /tmp/zpd >>"$LOG" 2>&1; then
        cp -r /tmp/zpd/bin/color-scripts "$BIN/" && chmod +x "$BIN"/color-scripts/* \
            && ok "30 ASCII-анимаций в ~/bin/color-scripts" || no "color-scripts не скопировались"
        rm -rf /tmp/zpd
    else
        no "репозиторий bspwm-dotfiles недоступен — color-scripts пропущены"
    fi
fi
if [ -d "$HOME/.config/ranger/plugins/ranger_devicons" ]; then
    ok "иконки ranger уже стоят"
else
    timeout 120 git clone -q --depth 1 https://github.com/alexanderjeurissen/ranger_devicons \
        "$HOME/.config/ranger/plugins/ranger_devicons" >>"$LOG" 2>&1 \
        && ok "иконки ranger" || no "ranger_devicons не склонировался"
fi
grep -q "default_linemode devicons" "$HOME/.config/ranger/rc.conf" 2>/dev/null || {
    mkdir -p "$HOME/.config/ranger"
    echo "default_linemode devicons" >> "$HOME/.config/ranger/rc.conf"
}

# ─────────────────────────────────────────────── conky
c "Виджет Conky"
mkdir -p "$HOME/.config/conky"
cat > "$HOME/.config/conky/main.conf" <<'EOF'
conky.config = {
    alignment = 'top_right',
    gap_x = 60, gap_y = 60, minimum_width = 340,
    own_window = true,
    -- 'normal' + хинты: рекомендация conky-вики для GNOME ('desktop' прячется за DING)
    own_window_type = 'normal',
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
${execi 900 ~/bin/weather-line}

${color1}СИСТЕМА${color}
Процессор${goto 130}${cpu cpu0}%${alignr}${cpubar 6,110}
Память${goto 130}${memperc}%${alignr}${membar 6,110}
Диск${goto 130}${fs_used_perc /}%${alignr}${fs_bar 6,110 /}

${color1}СЕТЬ${color}
${if_up @NETIF@}Приём${goto 130}${downspeed @NETIF@}
Передача${goto 130}${upspeed @NETIF@}
${endif}${if_up tun0}${color2}VPN активен${color}${endif}
]]
EOF

NETIF=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
[ -z "$NETIF" ] && NETIF=$(ip -br link 2>/dev/null | awk '$1 ~ /^(wl|en)/ {print $1; exit}')
[ -z "$NETIF" ] && NETIF=eth0
sed -i "s/@NETIF@/$NETIF/g" "$HOME/.config/conky/main.conf"
ok "сетевой интерфейс: $NETIF"

mkdir -p "$HOME/.config/autostart"
# xrandr перед стартом будит XWayland — иначе на Wayland conky невидим (conky#1087)
cat > "$HOME/.config/autostart/conky.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Conky
Exec=bash -c 'xrandr >/dev/null 2>&1; sleep 3; exec conky -c "$HOME/.config/conky/main.conf"'
Terminal=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=5
EOF
ok "автозапуск прописан"

# ─────────────────────────────────────────────── алиасы
c "Алиасы и функции"
if ! grep -q "# --- bootstrap aliases ---" "$HOME/.bashrc" 2>/dev/null; then
    {
        cat <<'EOF'

# --- bootstrap aliases ---
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
command -v lsd >/dev/null && alias ls='lsd' && alias ll='lsd -l' && alias la='lsd -la' && alias lt='lsd --tree'
command -v batcat >/dev/null && alias c='batcat'

ranger_cd() {
    local tmp; tmp="$(mktemp -t ranger_cd.XXXXXX)"
    ranger --choosedir="$tmp" -- "${@:-$PWD}"
    local dir; dir="$(command cat -- "$tmp")"
    [ -n "$dir" ] && [ "$dir" != "$PWD" ] && cd -- "$dir"
    rm -f -- "$tmp"
}
alias r='ranger_cd'

# fzf: Ctrl-R история, Ctrl-T файлы, Alt-C переход (noble 0.44 — source, не --bash)
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/bash-completion/completions/fzf ] && source /usr/share/bash-completion/completions/fzf
# zoxide: умный cd — команда z (после недели знает твои каталоги)
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
EOF
        printf "alias walls='find \"%s\" -maxdepth 1 -type f | wc -l'\n" "$WALL_DIR"
    } >> "$HOME/.bashrc"
    ok "добавлены в .bashrc"
else
    ok "уже прописаны"
fi

# ─────────────────────────────────────────────── внешний вид GNOME
c "Настройки GNOME"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
[ -d "$HOME/.themes/Tokyonight-Dark" ] && \
    gsettings set org.gnome.desktop.interface gtk-theme 'Tokyonight-Dark'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 6
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.session idle-delay 900
ok "тема, иконки, шрифт, 6 рабочих столов"

# ─────────────────────────────────────────────── горячие клавиши
c "Горячие клавиши"

# освобождаем занятые по умолчанию сочетания:
# Super+P — mutter switch-monitor; Super+D — ubuntu show-desktop
gsettings set org.gnome.mutter.keybindings switch-monitor "['XF86Display']" \
    && ok "Super+P освобождён (переключение мониторов осталось на Fn-клавише)"
gsettings set org.gnome.desktop.wm.keybindings show-desktop \
    "['<Primary><Super>d','<Primary><Alt>d']" \
    && ok "Super+D освобождён (свернуть всё: Ctrl+Super+D)"

P=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings

add_key() { # имя команда клавиши индекс
    local path="$P/custom$4/"
    if dconf write "${path}name" "'$1'" &&
       dconf write "${path}command" "'$2'" &&
       dconf write "${path}binding" "'$3'"; then
        ok "$3 → $1"
    else
        no "$3 → $1"
    fi
}

FLAME_CMD='flameshot gui'
[ "$SESSION" = "wayland" ] && FLAME_CMD='sh -c "QT_QPA_PLATFORM=wayland flameshot gui"'

add_key "Rofi"           "rofi -show drun"    "<Super>d"          0
add_key "Flameshot"      "$FLAME_CMD"         "<Super><Shift>s"   1
add_key "Wallpaper next" "$BIN/setwall"       "<Super>r"          2
add_key "Wallpaper prev" "$BIN/setwall prev"  "<Super><Shift>r"   3
add_key "Wallpaper pin"  "$BIN/setwall pin"   "<Super>p"          4
add_key "Wallpaper fav"  "$BIN/setwall fav"   "<Super>f"          5
add_key "Wallpaper favs" "$BIN/setwall favs"  "<Super><Shift>f"   6
add_key "Powermenu"      "$BIN/powermenu"     "<Super>x"          7
add_key "Wifimenu"       "$BIN/wifimenu"      "<Super>w"          8
add_key "Pick color"     "$BIN/pickcolor"     "<Super><Shift>c"   9
add_key "Calendar"       "gnome-calendar"     "<Super>c"          10

LIST=""
for i in $(seq 0 10); do LIST="$LIST'$P/custom$i/',"; done
if gsettings set org.gnome.settings-daemon.plugins.media-keys \
    custom-keybindings "[${LIST%,}]"; then
    ok "все 11 зарегистрированы"
else
    no "регистрация хоткеев не прошла"
fi

# ─────────────────────────────────────────────── первый запуск и проверка
c "Первый запуск"
if [ -n "$(find "$WALL_DIR" -maxdepth 1 -type f -print -quit 2>/dev/null)" ]; then
    "$BIN/setwall" >>"$LOG" 2>&1 && ok "обои и палитра применены" || no "setwall упал (см. $LOG)"
else
    wr "обоев нет — пропускаю"
fi

pkill -x conky 2>/dev/null
( xrandr >/dev/null 2>&1; conky -c "$HOME/.config/conky/main.conf" >>"$LOG" 2>&1 & )
sleep 2
if pgrep -x conky >/dev/null; then
    ok "виджет запущен"
else
    no "conky не поднялся$([ "$SESSION" = wayland ] && echo ' — на Wayland это известная история, после входа в Xorg заработает')"
fi

# ─────────────────────────────────────────────── итог
echo
echo "────────────────────────────────────────────────"
if [ "$FAILS" -eq 0 ]; then
    echo "  ГОТОВО — все секции прошли чисто"
else
    echo "  ГОТОВО, но с проблемами: $FAILS ✗ — детали в $LOG"
fi
cat <<'FIN'

  Осталось руками:
   1. ПЕРЕЛОГИНИТЬСЯ — тема, расширения и алиасы подхватятся
   2. Extension Manager → настроить Blur My Shell,
      Dash to Panel, Just Perfection под себя
   3. Settings → Online Accounts → почта и календарь

  Клавиши:
   Super+D            меню приложений
   Super+Shift+S      скриншот
   Super+R / Super+Shift+R   обои вперёд / назад
   Super+P            закрепить обои
   Super+F            в избранное · Super+Shift+F случайная из избранного
   Super+X            меню питания
   Super+W            Wi-Fi
   Super+Shift+C      пипетка цвета
   Super+C            календарь
   r                  ranger с переходом в каталог
FIN
[ "$SESSION" = "wayland" ] && echo "   ! Сессия была Wayland — если что-то не работает, выбери «Ubuntu on Xorg» на входе"
echo "────────────────────────────────────────────────"
