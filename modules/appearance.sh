#!/usr/bin/env bash
# Внешний вид «как на скриншоте Graphite»: светлая чёрно-белая тема,
# монохромные папки Tela-circle и крупные тонкие кнопки заголовка Fluent.
# После применения сам проверяет результат и делает снимок окна.
#
#   ./appearance.sh                     весь пресет целиком
#   ./appearance.sh --dark              то же, но тёмный вариант Graphite
#   ./appearance.sh --folders black     другой цвет папок (grey, black, standard…)
#   ./appearance.sh --buttons 36 20     другой размер кнопок
#   ./appearance.sh --skip-theme        не трогать тему GTK, только иконки и кнопки
#   ./appearance.sh --check             ничего не менять, только проверить
#   ./appearance.sh --revert            вернуть ровно то, что было до первого запуска
#
# Панель Dash to Panel, обои, терминалы и conky не трогаются.
#
# Отчёт и снимок кладутся в ~/appearance-report/ — их можно переслать.

set -uo pipefail

VARIANT="light"
FOLDERS="grey"
BTN_SIZE=34
BTN_ICO=20
MODE="apply"
SKIP_THEME=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dark)       VARIANT="dark"; shift ;;
        --light)      VARIANT="light"; shift ;;
        --folders)    FOLDERS="${2:-grey}"; shift 2 ;;
        --buttons)    BTN_SIZE="${2:-34}"; BTN_ICO="${3:-20}"; shift 3 ;;
        --skip-theme) SKIP_THEME=1; shift ;;
        --check)      MODE="check"; shift ;;
        --revert)     MODE="revert"; shift ;;
        -h|--help)    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)  echo "неизвестный аргумент: $1"; echo "подсказка: $0 --help"; exit 1 ;;
    esac
done

STATE="$HOME/.local/state"
BEFORE="$STATE/appearance-before.env"
REPORT_DIR="$HOME/appearance-report"
REPORT="$REPORT_DIR/report.md"
SHOT="$REPORT_DIR/screenshot.png"
FLUENT="https://raw.githubusercontent.com/vinceliuice/Fluent-icon-theme/master/src/symbolic/actions"

ok()  { echo "  ✓ $*"; }
bad() { echo "  ✗ $*"; }

gget() { gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | tr -d "'"; }
gset() { gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null; }

shell_theme_get() { dconf read /org/gnome/shell/extensions/user-theme/name 2>/dev/null | tr -d "'"; }
shell_theme_set() { dconf write /org/gnome/shell/extensions/user-theme/name "'$1'" 2>/dev/null; }

strip_block() {
    if [ -f "$1" ]; then
        sed -i '/titlebuttons-begin/,/titlebuttons-end/d' "$1"
    fi
}

# ------------------------------------------------------------ запомнить как было

save_before() {
    if [ -f "$BEFORE" ]; then
        return          # первый снимок — самый ценный, не перезаписываем
    fi
    mkdir -p "$STATE"
    {
        echo "GTK_THEME_WAS=$(gget gtk-theme)"
        echo "ICON_THEME_WAS=$(gget icon-theme)"
        echo "COLOR_SCHEME_WAS=$(gget color-scheme)"
        echo "SHELL_THEME_WAS=$(shell_theme_get)"
    } > "$BEFORE"
    ok "прежние настройки записаны: $BEFORE"
}

# ------------------------------------------------------------ откат

if [ "$MODE" = "revert" ]; then
    echo "==> откат"
    CUR=$(gget icon-theme)
    strip_block "$HOME/.config/gtk-3.0/gtk.css"
    strip_block "$HOME/.config/gtk-4.0/gtk.css"
    case "$CUR" in
        *-Fluent-Titlebar) rm -rf "$HOME/.local/share/icons/$CUR" ;;
    esac

    if [ -f "$BEFORE" ]; then
        . "$BEFORE"
        if [ -n "${GTK_THEME_WAS:-}" ]; then
            gset gtk-theme "$GTK_THEME_WAS"; ok "тема GTK: $GTK_THEME_WAS"
        fi
        if [ -n "${ICON_THEME_WAS:-}" ]; then
            gset icon-theme "$ICON_THEME_WAS"; ok "иконки: $ICON_THEME_WAS"
        fi
        if [ -n "${COLOR_SCHEME_WAS:-}" ]; then
            gset color-scheme "$COLOR_SCHEME_WAS"; ok "схема: $COLOR_SCHEME_WAS"
        fi
        if [ -n "${SHELL_THEME_WAS:-}" ]; then
            shell_theme_set "$SHELL_THEME_WAS"; ok "тема оболочки: $SHELL_THEME_WAS"
        fi
        rm -f "$BEFORE"
    else
        bad "снимка прежних настроек нет — вернул только кнопки"
    fi
    echo "готово. Перелогинься, чтобы применилось везде."
    exit 0
fi

# ------------------------------------------------------------ применение

if [ "$MODE" = "apply" ]; then
    save_before

    # --- 1. тема GTK: Graphite нужного варианта ------------------------
    if [ "$SKIP_THEME" -eq 0 ]; then
        echo "==> тема Graphite ($VARIANT)"
        MISS=""
        for p in sassc git; do
            if ! command -v "$p" >/dev/null 2>&1; then
                MISS="$MISS $p"
            fi
        done
        if [ -n "$MISS" ]; then
            bad "не хватает:$MISS — sudo apt install -y$MISS gnome-themes-extra gtk2-engines-murrine"
        else
            SRCDIR="$HOME/.cache/graphite-src"
            if [ ! -d "$SRCDIR/.git" ]; then
                rm -rf "$SRCDIR"
                git clone -q --depth 1 \
                    https://github.com/vinceliuice/Graphite-gtk-theme.git "$SRCDIR" 2>/dev/null
            fi
            if [ -x "$SRCDIR/install.sh" ]; then
                # -l кладёт ссылку в ~/.config/gtk-4.0, иначе новые
                # приложения останутся стандартными
                ( cd "$SRCDIR"; ./install.sh -l -c "$VARIANT" -t grey >/dev/null 2>&1 )
                NAME=$(ls -d "$HOME/.themes/Graphite"* 2>/dev/null \
                       | grep -iE "Graphite(-grey)?-$VARIANT\$" | head -1)
                if [ -z "$NAME" ]; then
                    NAME=$(ls -d "$HOME/.themes/Graphite"* 2>/dev/null | head -1)
                fi
                if [ -n "$NAME" ]; then
                    T=$(basename "$NAME")
                    gset gtk-theme "$T"
                    shell_theme_set "$T"
                    if [ "$VARIANT" = "light" ]; then
                        gset color-scheme "prefer-light"
                    else
                        gset color-scheme "prefer-dark"
                    fi
                    ok "тема: $T, схема: $VARIANT"
                else
                    bad "тема собралась, но каталог не найден в ~/.themes"
                fi
            else
                bad "Graphite не скачалась (сеть?) — тему не менял"
            fi
        fi
    else
        echo "==> тему GTK не трогаю (--skip-theme)"
    fi

    # --- 2. иконки Tela-circle ----------------------------------------
    echo "==> иконки Tela-circle ($FOLDERS)"
    SRCDIR="$HOME/.cache/tela-circle-src"
    if [ ! -d "$SRCDIR/.git" ]; then
        rm -rf "$SRCDIR"
        git clone -q --depth 1 \
            https://github.com/vinceliuice/Tela-circle-icon-theme.git "$SRCDIR" 2>/dev/null
    fi
    if [ -x "$SRCDIR/install.sh" ]; then
        ( cd "$SRCDIR"; ./install.sh "$FOLDERS" >/dev/null 2>&1 )
        # для светлой темы берём обычный вариант, для тёмной — -dark
        WANT="Tela-circle-$FOLDERS"
        if [ "$FOLDERS" = "standard" ]; then
            WANT="Tela-circle"
        fi
        if [ "$VARIANT" = "dark" ]; then
            if [ -d "$HOME/.local/share/icons/$WANT-dark" ]; then
                WANT="$WANT-dark"
            fi
        fi
        if [ -d "$HOME/.local/share/icons/$WANT" ]; then
            gset icon-theme "$WANT"
            ok "иконки: $WANT"
        else
            bad "не нашёл $WANT — что установилось:"
            ls "$HOME/.local/share/icons" 2>/dev/null | sed 's/^/     /'
        fi
    else
        bad "Tela-circle не скачалась (сеть?) — иконки не менял"
    fi

    # --- 3. кнопки заголовка из Fluent --------------------------------
    echo "==> кнопки заголовка"
    CUR=$(gget icon-theme)
    BASE="$CUR"
    case "$CUR" in *-Fluent-Titlebar) BASE="${CUR%-Fluent-Titlebar}" ;; esac
    if [ -z "$BASE" ]; then
        BASE="Papirus-Dark"
    fi
    THEME="$BASE-Fluent-Titlebar"
    DIR="$HOME/.local/share/icons/$THEME"

    FOUND=""
    for d in "$HOME/.local/share/icons/$BASE" "$HOME/.icons/$BASE" "/usr/share/icons/$BASE"; do
        if [ -d "$d" ]; then
            FOUND="$d"
        fi
    done

    if [ -z "$FOUND" ]; then
        bad "базовой темы $BASE нет, кнопки пропускаю"
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
Inherits=$BASE,Papirus,Adwaita,hicolor
Directories=symbolic/actions

[symbolic/actions]
Size=16
MinSize=8
MaxSize=512
Context=Actions
Type=Scalable
EOF
            gtk-update-icon-cache -f "$DIR" >/dev/null 2>&1

            for V in 3.0 4.0; do
                F="$HOME/.config/gtk-$V/gtk.css"
                mkdir -p "$(dirname "$F")"
                touch "$F"
                strip_block "$F"
                cat >> "$F" <<EOF
/* titlebuttons-begin */
headerbar button.titlebutton,
.titlebar button.titlebutton,
windowcontrols button {
  min-width: ${BTN_SIZE}px;
  min-height: ${BTN_SIZE}px;
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
  -gtk-icon-size: ${BTN_ICO}px;
}
/* titlebuttons-end */
EOF
            done
            gset icon-theme "$THEME"
            ok "значки Fluent поверх $BASE"
            ok "кнопка ${BTN_SIZE}px, значок ${BTN_ICO}px"
        fi
    fi
fi

# ------------------------------------------------------------ проверка

echo "==> проверка"
mkdir -p "$REPORT_DIR"

ACTIVE=$(gget icon-theme)
GTK=$(gget gtk-theme)
SCHEME=$(gget color-scheme)
SHELL_T=$(shell_theme_get)

RESOLVE=$(python3 - "$ACTIVE" <<'PY' 2>/dev/null
import sys
try:
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk
except Exception as e:
    print('не проверить: нет python3-gi (%s)' % e)
    raise SystemExit(0)

theme = Gtk.IconTheme.new()
if sys.argv[1]:
    theme.set_custom_theme(sys.argv[1])
for name in ('window-close-symbolic', 'window-maximize-symbolic',
             'window-minimize-symbolic', 'window-restore-symbolic',
             'folder'):
    info = theme.lookup_icon(name, 16, 0)
    print('%-28s %s' % (name, info.get_filename() if info else 'НЕ НАЙДЕНА'))
PY
)

echo "$RESOLVE" | sed 's/^/  /'

HITS=$(echo "$RESOLVE" | grep -c 'Fluent-Titlebar')
if [ "$HITS" -ge 3 ]; then
    ok "кнопки берутся из нашей темы ($HITS из 4)"
else
    bad "кнопки пока не из нашей темы — нужен перелогин"
fi

# --- снимок -----------------------------------------------------------
echo "==> снимок"
rm -f "$SHOT"
SHOOTER=""
for s in gnome-screenshot flameshot import scrot; do
    if command -v "$s" >/dev/null 2>&1; then
        SHOOTER="$s"
        break
    fi
done

if [ -n "$SHOOTER" ]; then
    if command -v nautilus >/dev/null 2>&1; then
        nautilus "$HOME" >/dev/null 2>&1 &
        sleep 4
    fi
    case "$SHOOTER" in
        gnome-screenshot) gnome-screenshot -w -f "$SHOT" >/dev/null 2>&1 ;;
        flameshot)        flameshot full -p "$SHOT" >/dev/null 2>&1 ;;
        import)           import -window root "$SHOT" >/dev/null 2>&1 ;;
        scrot)            scrot -o "$SHOT" >/dev/null 2>&1 ;;
    esac
    if [ -f "$SHOT" ]; then
        if command -v convert >/dev/null 2>&1; then
            convert "$SHOT" -resize 1800x\> -quality 82 "$SHOT" >/dev/null 2>&1
        fi
        ok "снимок: $SHOT ($(du -h "$SHOT" | cut -f1))"
    else
        bad "снять не удалось ($SHOOTER) — сними сам и пришли"
    fi
else
    bad "нет программы для снимков — сними сам и пришли"
fi

# --- отчёт ------------------------------------------------------------
{
    echo "# Что применилось"
    echo
    echo "- дата: $(date '+%Y-%m-%d %H:%M')"
    echo "- тема GTK: \`$GTK\`"
    echo "- тема оболочки: \`$SHELL_T\`"
    echo "- схема: \`$SCHEME\`"
    echo "- тема иконок: \`$ACTIVE\`"
    echo "- кнопка: ${BTN_SIZE}px, значок: ${BTN_ICO}px"
    echo
    echo "## Откуда GTK берёт значки"
    echo
    echo '```'
    echo "$RESOLVE"
    echo '```'
    echo
    echo "## Блок в gtk.css"
    echo
    echo '```css'
    sed -n '/titlebuttons-begin/,/titlebuttons-end/p' "$HOME/.config/gtk-3.0/gtk.css" 2>/dev/null
    echo '```'
    echo
    echo "## Было до первого запуска"
    echo
    echo '```'
    cat "$BEFORE" 2>/dev/null
    echo '```'
    echo
    echo "## Темы в системе"
    echo
    echo '```'
    echo "иконки:"
    ls "$HOME/.local/share/icons" 2>/dev/null | sed 's/^/  /'
    echo "темы:"
    ls "$HOME/.themes" 2>/dev/null | sed 's/^/  /'
    echo '```'
} > "$REPORT"

ok "отчёт: $REPORT"
echo
echo "пришли оба файла из $REPORT_DIR"
echo "вернуть как было: $0 --revert"
