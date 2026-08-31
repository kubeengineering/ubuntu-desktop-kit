#!/usr/bin/env bash
# ubuntu-desktop-kit — раскатка на свежей Ubuntu 24.04 с GNOME 46.
#
# Ставит то, чего в системе нет: пакеты, шрифт, расширения GNOME,
# палитру pywal. Внешний вид не настраивает сам — это делает
# desktop-kit.sh, который умеет откатывать свои правки и знает про
# GTK4, симлинки и прочие тонкости. Так у оформления одна точка правды.
#
#   ./bootstrap.sh                   обычный запуск
#   ./bootstrap.sh --look night      другой образ рабочего стола
#   ./bootstrap.sh --no-look         только пакеты, вид не трогать
#   ./bootstrap.sh --no-walls        не качать банк обоев (долго на медленной сети)
#
# Запускать повторно безопасно: всё уже стоящее пропускается.
# Лог подробностей: ~/.cache/ubuntu-kit-bootstrap.log

set -uo pipefail

# ─────────────────────────────────────────────── база
LOG="$HOME/.cache/ubuntu-kit-bootstrap.log"
mkdir -p "$HOME/.cache"; : > "$LOG"
CITY="${CITY:-Moscow}"
BIN="$HOME/bin"
HERE=$(cd "$(dirname "$0")" && pwd)
KIT="$HERE/desktop-kit.sh"
RAW="https://raw.githubusercontent.com/kubeengineering/ubuntu-desktop-kit/main"

LOOK="work"
WANT_LOOK=1
WANT_WALLS=1

FAILS=0
c()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok() { printf '    \033[32m✓\033[0m %s\n' "$*"; }
no() { printf '    \033[31m✗\033[0m %s\n' "$*"; FAILS=$((FAILS+1)); }
wr() { printf '    \033[33m!\033[0m %s\n' "$*"; }

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)  sed -n '2,17p' "$0"; exit 0 ;;
        --look)     LOOK="${2:-work}"; shift 2 ;;
        --no-look)  WANT_LOOK=0; shift ;;
        --no-walls) WANT_WALLS=0; shift ;;
        *) echo "неизвестный параметр: $1 (см. --help)"; exit 1 ;;
    esac
done

[ "$(id -u)" -eq 0 ] && { echo "Не запускай от root — скрипт сам спросит sudo"; exit 1; }
command -v apt-get >/dev/null || { echo "Это не Debian/Ubuntu"; exit 1; }

export PATH="$HOME/.local/bin:$BIN:$PATH"
SESSION="${XDG_SESSION_TYPE:-unknown}"

# sudo нужен для пакетов. Если запускают не из терминала (по ssh в
# фоне, из автозапуска), sudo не сможет спросить пароль и выдаст
# «a terminal is required» — сообщение, по которому непонятно, что
# делать. Объясняем сами.
if ! sudo -n true 2>/dev/null; then
    if [ ! -t 0 ]; then
        echo "Нужен sudo, а спросить пароль негде: запуск без терминала."
        echo "Запусти из обычного терминала, либо заранее выполни: sudo -v"
        exit 1
    fi
    echo "Нужен пароль sudo — он потребуется только для установки пакетов."
    sudo -v || exit 1
fi
( while true; do sleep 50; sudo -n true 2>/dev/null || exit; done ) &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null' EXIT

# ─────────────────────────────────────────────── пакеты
c "Пакеты из репозиториев"
APT="sudo apt-get -o DPkg::Lock::Timeout=600"

if ! $APT update --error-on=any >>"$LOG" 2>&1; then
    no "apt update не прошёл — нет сети, captive portal или система ещё ставит обновления первого запуска"
    echo "    Подключи сеть, подожди пару минут и запусти снова. Лог: $LOG"
    exit 1
fi
ok "индексы обновлены"

# papirus-folders нет ни в одном выпуске Ubuntu — только в PPA авторов.
# Оттуда же приезжает свежий papirus-icon-theme вместо сборки 2024 года.
c "PPA Papirus"
if sudo add-apt-repository -y ppa:papirus/papirus >>"$LOG" 2>&1; then
    $APT update >>"$LOG" 2>&1
    ok "подключён"
else
    wr "PPA не подключился — значки будут из архива Ubuntu (см. $LOG)"
fi

# Список поредел с прошлой версии: rofi, gpick и их меню отсюда убраны.
# Оба X11-нативные, а свежая Ubuntu входит в Wayland, где rofi теряет
# клавиатуру, а пипетка не работает вовсе. Меню питания и Wi-Fi в GNOME
# и так есть — свои дубликаты только путали.
PKGS=(
    gnome-tweaks gnome-shell-extension-manager gnome-shell-extensions
    papirus-icon-theme dconf-cli sassc make
    conky-all flameshot imagemagick jq curl wget git unzip file
    lsd bat ranger btop
    xclip xsel pipx gnome-keyring
    xdg-desktop-portal-gtk lm-sensors gir1.2-gtop-2.0 gnome-calendar
    fonts-jetbrains-mono
    copyq gnome-sushi fzf zoxide
)
if $APT install -y "${PKGS[@]}" >>"$LOG" 2>&1; then
    ok "установлены все ${#PKGS[@]}"
else
    wr "общая установка не прошла — ставлю по одному (см. $LOG)"
    for p in "${PKGS[@]}"; do
        $APT install -y "$p" >>"$LOG" 2>&1 || no "пакет $p"
    done
fi

# Без этого ядра дальше бессмысленно: конфиги лягут поверх пустоты.
CORE_MISSING=0
for t in git curl jq unzip conky sassc dconf; do
    command -v "$t" >/dev/null || { no "нет $t"; CORE_MISSING=1; }
done
[ "$CORE_MISSING" -eq 1 ] && { echo; echo "Базовые пакеты не встали — смотри $LOG, чини apt и перезапускай."; exit 1; }

# ─────────────────────────────────────────────── сам инструмент
c "desktop-kit"
if [ ! -f "$KIT" ]; then
    # Запустили bootstrap отдельно от репозитория — доносим скрипт сами,
    # иначе настраивать вид будет нечем.
    KIT="$HOME/.local/share/desktop-kit/desktop-kit.sh"
    mkdir -p "$(dirname "$KIT")"
    if curl -fsSL --max-time 60 "$RAW/desktop-kit.sh" -o "$KIT"; then
        chmod +x "$KIT"
        ok "скачан: $KIT"
    else
        no "не скачался — дальше только пакеты"
        WANT_LOOK=0
    fi
else
    ok "рядом: $KIT"
fi

# Запускалка `design`, чтобы дальше звать одним словом
if curl -fsSL --max-time 60 "$RAW/tools/design" -o "$HOME/.local/bin/design" 2>/dev/null; then
    chmod +x "$HOME/.local/bin/design"
    ok "запускалка: design"
else
    wr "запускалка не скачалась — зови скрипт по пути"
fi

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
        no "не скачался с GitHub — значки в виджете будут квадратами (см. $LOG)"
    fi
fi

# ─────────────────────────────────────────────── pywal16
c "pywal16 — палитра из обоев"
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
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
mkdir -p "$EXT_DIR"
SHELL_VER=$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)
[ -z "$SHELL_VER" ] && SHELL_VER=46

# Ставим напрямую с extensions.gnome.org. Раньше здесь был gext, но он
# на медленной сети умеет виснуть без единой строки в логе — а curl
# честно скажет, что не докачал.
install_ext() {
    local uuid="$1"
    if [ -d "$EXT_DIR/$uuid" ] && [ -f "$EXT_DIR/$uuid/metadata.json" ]; then
        ok "$uuid (уже стоит)"
        return 0
    fi
    local url
    url=$(curl -fsS --max-time 60 --retry 3 \
        "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$SHELL_VER" 2>/dev/null \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["download_url"])' 2>/dev/null)
    if [ -z "$url" ]; then
        no "$uuid — сайт расширений не ответил"
        return 1
    fi
    local zip="/tmp/$uuid.zip"
    if ! curl -fsSL --max-time 300 --retry 5 --retry-all-errors -o "$zip" \
         "https://extensions.gnome.org$url" >>"$LOG" 2>&1; then
        no "$uuid — не скачалось"
        return 1
    fi
    rm -rf "${EXT_DIR:?}/$uuid"
    mkdir -p "$EXT_DIR/$uuid"
    if unzip -oq "$zip" -d "$EXT_DIR/$uuid" >>"$LOG" 2>&1; then
        # Схемы надо скомпилировать, иначе настройки расширения не читаются
        [ -d "$EXT_DIR/$uuid/schemas" ] && glib-compile-schemas "$EXT_DIR/$uuid/schemas" 2>/dev/null
        rm -f "$zip"
        ok "$uuid"
        return 0
    fi
    no "$uuid — архив не распаковался"
    return 1
}

install_ext dash-to-panel@jderose9.github.com
install_ext blur-my-shell@aunetx
install_ext just-perfection-desktop@just-perfection
install_ext Vitals@CoreCoding.com

# Включаем всё и гасим ubuntu-dock: он навязан сессией и после релогина
# повис бы ПОВЕРХ dash-to-panel.
python3 - blur-my-shell@aunetx dash-to-panel@jderose9.github.com \
    just-perfection-desktop@just-perfection Vitals@CoreCoding.com \
    user-theme@gnome-shell-extensions.gcampax.github.com \
    -ubuntu-dock@ubuntu.com <<'PY' && ok "включены (заработают после релогина)" || no "не смог обновить список расширений"
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

# ─────────────────────────────────────────────── мелочи для терминала
c "Ranger и подсветка"
if [ -d "$HOME/.config/ranger/plugins/ranger_devicons" ]; then
    ok "значки ranger уже стоят"
else
    timeout 120 git clone -q --depth 1 https://github.com/alexanderjeurissen/ranger_devicons \
        "$HOME/.config/ranger/plugins/ranger_devicons" >>"$LOG" 2>&1 \
        && ok "значки ranger" || wr "ranger_devicons не склонировался — не критично"
fi
mkdir -p "$HOME/.config/ranger"
grep -q "default_linemode devicons" "$HOME/.config/ranger/rc.conf" 2>/dev/null || \
    echo "default_linemode devicons" >> "$HOME/.config/ranger/rc.conf"

# ─────────────────────────────────────────────── алиасы
c "Алиасы и функции"
if ! grep -q "# --- ubuntu-desktop-kit ---" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<'EOF'

# --- ubuntu-desktop-kit ---
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

# fzf: Ctrl-R история, Ctrl-T файлы, Alt-C переход
# (в noble это 0.44 — подключается через source, а не --bash)
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/bash-completion/completions/fzf ] && source /usr/share/bash-completion/completions/fzf
# zoxide: умный cd — команда z, через неделю знает твои каталоги
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
EOF
    ok "добавлены в .bashrc"
else
    ok "уже прописаны"
fi

# ─────────────────────────────────────────────── повадки GNOME
# Только поведение, не оформление: оформление ниже делает desktop-kit.
c "Повадки GNOME"
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 6
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.session idle-delay 900
ok "6 рабочих столов, тап по тачпаду, день недели в часах"

# ─────────────────────────────────────────────── обои
if [ "$WANT_WALLS" = "1" ]; then
    c "Банк обоев"
    if [ "$WANT_LOOK" = "1" ] || [ -f "$KIT" ]; then
        if bash "$KIT" --yes wallpapers --init >>"$LOG" 2>&1; then
            ok "банк залит (подробности в $LOG)"
        else
            wr "банк не залился — потом: design wallpapers --init"
        fi
    fi
fi

# ─────────────────────────────────────────────── внешний вид
if [ "$WANT_LOOK" = "1" ] && [ -f "$KIT" ]; then
    c "Внешний вид: образ $LOOK"

    # Тема и значки нужны образу — доносим их до применения.
    if bash "$KIT" --yes themes --install Graphite >>"$LOG" 2>&1; then
        ok "тема Graphite собрана"
    else
        no "тема не собралась — образ ляжет частично (см. $LOG)"
    fi

    if bash "$KIT" --yes look "$LOOK" 2>&1 | sed 's/^/    /'; then
        ok "образ '$LOOK' применён"
    else
        wr "часть шагов образа не прошла — что именно, видно выше"
    fi

    if bash "$KIT" --yes keys --defaults >>"$LOG" 2>&1; then
        ok "горячие клавиши поставлены"
    else
        wr "клавиши не встали — потом: design keys --defaults"
    fi

    if bash "$KIT" --yes widget --add weather >>"$LOG" 2>&1; then
        ok "погода в виджете (город: $CITY)"
        [ "$CITY" != "Moscow" ] && bash "$KIT" --yes widget --city "$CITY" >>"$LOG" 2>&1
    fi
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

  Дальше руками:
   1. ПЕРЕЛОГИНИТЬСЯ — расширения, алиасы и панель подхватятся
   2. Проверить вид:      design status
   3. Не нравится образ:  design look night   (или paper)
   4. Совсем назад:       design revert

  Клавиши (свои — design keys):
   Ctrl+Q               скриншот с выделением области
   Ctrl+*  /  Ctrl+/    обои вперёд / назад (серые клавиши цифрового блока)
   r                    ranger с переходом в каталог
FIN
if [ "$SESSION" = "wayland" ]; then
    echo "   ! Сессия Wayland. Виджет conky иногда не появляется до перезахода —"
    echo "     это его давняя особенность, после релогина встаёт на место."
fi
echo "────────────────────────────────────────────────"
