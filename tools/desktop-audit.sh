#!/usr/bin/env bash
# Снимок настроенного десктопа: что установлено, чем настроено, какими
# значениями. Результат — один markdown-файл, по которому видно, как
# воспроизвести систему на другой машине.
#
#   bash desktop-audit.sh                 # ~/desktop-audit-ГГГГ-ММ-ДД.md
#   bash desktop-audit.sh /путь/файл.md
#
# Ничего не меняет: только читает. Пароли, ключи и токены в конфигах
# заменяются на <скрыто> — файл можно пересылать.

set -uo pipefail

OUT="${1:-$HOME/desktop-audit-$(date +%F).md}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "нужен python3 — sudo apt install -y python3"
    exit 1
fi

python3 - "$OUT" <<'PYEOF'
# -*- coding: utf-8 -*-
import os, sys, re, json, glob, shutil, subprocess, time

OUT = sys.argv[1]
HOME = os.path.expanduser('~')

# ---------------------------------------------------------------- утилиты

def sh(cmd, timeout=20):
    """stdout команды или пустая строка. Никогда не бросает."""
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True,
                           text=True, timeout=timeout, errors='replace')
        return (r.stdout or '').strip()
    except Exception:
        return ''

def have(prog):
    return shutil.which(prog) is not None

def read(path, maxlines=None):
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            data = f.read()
    except Exception:
        return ''
    if maxlines:
        lines = data.splitlines()
        if len(lines) > maxlines:
            cut = len(lines) - maxlines
            return '\n'.join(lines[:maxlines]) + '\n… обрезано ещё %d строк' % cut
    return data

SECRET_KEYS = ('password', 'passphrase', 'secret', 'token', 'apikey',
               'api_key', 'privatekey', 'private_key', 'clientsecret',
               'auth', 'credential')

def sanitize(text):
    """Прячет значения секретных ключей и блоки приватных ключей."""
    if not text:
        return text
    out, inkey = [], False
    for ln in text.splitlines():
        if 'BEGIN' in ln and 'PRIVATE KEY' in ln:
            inkey = True
            out.append('<скрыт приватный ключ>')
            continue
        if inkey:
            if 'END' in ln and 'PRIVATE KEY' in ln:
                inkey = False
            continue
        low = ln.lower()
        hit = False
        for k in SECRET_KEYS:
            if k in low:
                hit = True
                break
        if hit:
            m = re.match(r'^(\s*[^\s:=]+\s*[:=]\s*)(.+)$', ln)
            if m and m.group(2).strip() not in ('', '{}', '[]', 'null', 'true', 'false'):
                ln = m.group(1) + '<скрыто>'
        out.append(ln)
    return '\n'.join(out)

def fence(text, lang=''):
    if not text or not text.strip():
        return '_пусто_'
    return '```' + lang + '\n' + text.rstrip() + '\n```'

def table(rows, head):
    if not rows:
        return '_пусто_'
    out = ['| ' + ' | '.join(head) + ' |',
           '|' + '|'.join(['---'] * len(head)) + '|']
    for r in rows:
        cells = []
        for c in r:
            c = str(c).replace('|', '\\|').replace('\n', ' ')
            cells.append(c)
        out.append('| ' + ' | '.join(cells) + ' |')
    return '\n'.join(out)

def human(n):
    for unit in ('Б', 'КБ', 'МБ', 'ГБ'):
        if n < 1024:
            return '%.0f %s' % (n, unit)
        n /= 1024.0
    return '%.1f ТБ' % n

def gset(schema, key):
    return sh('gsettings get %s %s' % (schema, key), timeout=8)

SECTIONS = []
def section(title):
    def deco(fn):
        SECTIONS.append((title, fn))
        return fn
    return deco

# ---------------------------------------------------------------- секции

@section('Система')
def s_system():
    rows = [
        ('дистрибутив', sh('lsb_release -ds')),
        ('ядро', sh('uname -r')),
        ('архитектура', sh('uname -m')),
        ('сессия', os.environ.get('XDG_SESSION_TYPE', '?')),
        ('окружение', os.environ.get('XDG_CURRENT_DESKTOP', '?')),
        ('GNOME Shell', sh('gnome-shell --version')),
        ('оболочка', os.environ.get('SHELL', '?')),
        ('пользователь', os.environ.get('USER', '?')),
        ('домашний каталог', HOME),
        ('аптайм', sh('uptime -p')),
    ]
    return table([r for r in rows if r[1]], ['параметр', 'значение'])

@section('Язык и форматы')
def s_locale():
    rows = [
        ('LANG', os.environ.get('LANG', '')),
        ('LC_TIME', os.environ.get('LC_TIME', '')),
        ('LC_NUMERIC', os.environ.get('LC_NUMERIC', '')),
        ('раскладки', gset('org.gnome.desktop.input-sources', 'sources')),
        ('переключение', gset('org.gnome.desktop.wm.keybindings', 'switch-input-source')),
    ]
    acc = '/var/lib/AccountsService/users/' + os.environ.get('USER', '')
    body = table([r for r in rows if r[1]], ['параметр', 'значение'])
    txt = read(acc)
    if txt:
        body += '\n\n**AccountsService** (`%s`) — он переопределяет локаль графической сессии:\n\n' % acc
        body += fence(txt, 'ini')
    return body

@section('Железо и мониторы')
def s_hw():
    rows = [
        ('модель', read('/sys/class/dmi/id/product_version').strip() + ' / ' +
                   read('/sys/class/dmi/id/product_name').strip()),
        ('процессор', sh("grep -m1 'model name' /proc/cpuinfo")),
        ('ядер', sh('nproc')),
        ('память', sh("grep MemTotal /proc/meminfo")),
        ('диск /', sh("df -h / | tail -1")),
        ('батарея', read('/sys/class/power_supply/BAT0/capacity').strip()),
    ]
    body = table([r for r in rows if r[1] and r[1] != ' / '], ['параметр', 'значение'])

    mons = []
    for p in sorted(glob.glob('/sys/class/drm/card*-*')):
        st = read(os.path.join(p, 'status')).strip()
        if st != 'connected':
            continue
        modes = read(os.path.join(p, 'modes')).split()
        mons.append((os.path.basename(p), st, modes[0] if modes else '?', len(modes)))
    if mons:
        body += '\n\n**Подключённые выходы**\n\n'
        body += table(mons, ['выход', 'состояние', 'максимальный режим', 'всего режимов'])

    xr = sh('xrandr --listmonitors')
    if xr:
        body += '\n\n**xrandr**\n\n' + fence(xr)
    rate = sh("xrandr | grep '\\*'")
    if rate:
        body += '\n\n**Текущие режимы и частоты**\n\n' + fence(rate)
    mx = read(os.path.join(HOME, '.config/monitors.xml'), maxlines=80)
    if mx:
        body += '\n\n**monitors.xml**\n\n' + fence(mx, 'xml')
    return body

@section('Инструменты: что установлено')
def s_tools():
    tools = [
        ('tabby', 'tabby --version'),
        ('google-chrome', 'google-chrome --version'),
        ('evolution', 'evolution --version'),
        ('conky', 'conky --version | head -1'),
        ('flameshot', 'flameshot --version'),
        ('rofi', 'rofi -version'),
        ('feh', 'feh --version | head -1'),
        ('convert', 'convert --version | head -1'),
        ('lsd', 'lsd --version'),
        ('batcat', 'batcat --version'),
        ('ranger', 'ranger --version | head -1'),
        ('btop', 'btop --version'),
        ('zathura', 'zathura --version | head -1'),
        ('calcurse', 'calcurse --version'),
        ('gpick', 'gpick --version'),
        ('xclip', 'xclip -version'),
        ('mat2', 'mat2 --version'),
        ('wal', 'wal --version'),
        ('lutgen', 'lutgen --version'),
        ('kitty', 'kitty --version'),
        ('gnome-tweaks', 'gnome-tweaks --version'),
        ('gnome-extensions', 'gnome-extensions --version'),
        ('gext', 'gext --version'),
        ('jq', 'jq --version'),
        ('curl', 'curl --version | head -1'),
        ('git', 'git --version'),
        ('python3', 'python3 --version'),
        ('sassc', 'sassc --version | head -1'),
        ('yt-dlp', 'yt-dlp --version'),
        ('ffmpeg', 'ffmpeg -version | head -1'),
        ('tmux', 'tmux -V'),
    ]
    rows = []
    for name, cmd in tools:
        if have(name):
            ver = sh(cmd, timeout=8).splitlines()
            rows.append((name, '✓', (ver[0] if ver else '?')[:60],
                         shutil.which(name)))
        else:
            rows.append((name, '—', '', ''))
    return table(rows, ['программа', 'есть', 'версия', 'путь'])

@section('Пакеты, репозитории, snap')
def s_pkgs():
    body = ''
    ppa = sh('ls /etc/apt/sources.list.d/')
    if ppa:
        body += '**Подключённые репозитории**\n\n' + fence(ppa) + '\n\n'
    man = sh('apt-mark showmanual | wc -l')
    if man:
        body += 'Вручную установленных пакетов: **%s**\n\n' % man
    key = ('conky-all rofi flameshot feh imagemagick lsd bat ranger btop zathura '
           'calcurse gpick xclip mat2 gnome-keyring sassc gnome-shell-extensions '
           'gnome-tweaks papirus-icon-theme papirus-folders gir1.2-gtop-2.0 '
           'lm-sensors tabby-terminal google-chrome-stable evolution python3-pip')
    rows = []
    for p in key.split():
        st = sh("dpkg-query -W -f='${Status}|${Version}' " + p, timeout=8)
        if st.startswith('install ok installed'):
            rows.append((p, '✓', st.split('|')[-1][:40]))
        else:
            rows.append((p, '—', ''))
    body += '**Ключевые пакеты**\n\n' + table(rows, ['пакет', 'есть', 'версия'])
    sn = sh('snap list')
    if sn:
        body += '\n\n**snap**\n\n' + fence(sn)
    fp = sh('flatpak list --columns=application,version')
    if fp:
        body += '\n\n**flatpak**\n\n' + fence(fp)
    return body

@section('Оформление GNOME')
def s_look():
    keys = [
        ('org.gnome.desktop.interface', 'gtk-theme'),
        ('org.gnome.desktop.interface', 'icon-theme'),
        ('org.gnome.desktop.interface', 'cursor-theme'),
        ('org.gnome.desktop.interface', 'cursor-size'),
        ('org.gnome.desktop.interface', 'color-scheme'),
        ('org.gnome.desktop.interface', 'font-name'),
        ('org.gnome.desktop.interface', 'monospace-font-name'),
        ('org.gnome.desktop.interface', 'font-antialiasing'),
        ('org.gnome.desktop.interface', 'text-scaling-factor'),
        ('org.gnome.desktop.interface', 'enable-animations'),
        ('org.gnome.desktop.interface', 'clock-format'),
        ('org.gnome.desktop.interface', 'clock-show-weekday'),
        ('org.gnome.desktop.wm.preferences', 'button-layout'),
        ('org.gnome.desktop.wm.preferences', 'titlebar-font'),
        ('org.gnome.desktop.wm.preferences', 'focus-mode'),
        ('org.gnome.mutter', 'dynamic-workspaces'),
        ('org.gnome.mutter', 'edge-tiling'),
        ('org.gnome.mutter', 'experimental-features'),
        ('org.gnome.desktop.peripherals.touchpad', 'tap-to-click'),
        ('org.gnome.desktop.peripherals.touchpad', 'natural-scroll'),
    ]
    rows = []
    for sch, k in keys:
        v = gset(sch, k)
        if v:
            rows.append((k, v[:70], sch))
    body = table(rows, ['ключ', 'значение', 'схема'])

    ut = sh('dconf read /org/gnome/shell/extensions/user-theme/name')
    body += '\n\nТема оболочки (user-theme): `%s`\n' % (ut if ut else 'не задана')

    for d, label in ((os.path.join(HOME, '.themes'), 'свои темы (~/.themes)'),
                     ('/usr/share/themes', 'системные темы'),
                     (os.path.join(HOME, '.icons'), 'свои иконки (~/.icons)'),
                     ('/usr/share/icons', 'системные иконки')):
        try:
            names = sorted(os.listdir(d))
        except Exception:
            continue
        body += '\n**%s** (%d): %s\n' % (label, len(names), ', '.join(names[:25]))
    return body

@section('Обои и палитра')
def s_wall():
    rows = [
        ('светлая тема', gset('org.gnome.desktop.background', 'picture-uri')),
        ('тёмная тема', gset('org.gnome.desktop.background', 'picture-uri-dark')),
        ('вписывание', gset('org.gnome.desktop.background', 'picture-options')),
        ('экран блокировки', gset('org.gnome.desktop.screensaver', 'picture-uri')),
    ]
    body = table([r for r in rows if r[1]], ['что', 'значение'])

    body += '\n\n**Банк картинок**\n\n'
    found = []
    for d in (os.path.join(HOME, 'Pictures', 'wallpapers-uw'),
              os.path.join(HOME, 'Изображения', 'wallpapers-uw'),
              os.path.join(HOME, 'Pictures', 'wallpapers'),
              os.path.join(HOME, 'Изображения', 'wallpapers')):
        if not os.path.isdir(d):
            continue
        exts, total, names = {}, 0, []
        try:
            for e in os.scandir(d):
                if not e.is_file():
                    continue
                ext = os.path.splitext(e.name)[1].lower()
                exts[ext] = exts.get(ext, 0) + 1
                total += e.stat().st_size
                names.append(e.name)
        except Exception:
            pass
        found.append((d, sum(exts.values()), human(total),
                      ', '.join('%s×%d' % (k, v) for k, v in sorted(exts.items()))))
        if names:
            body += 'Примеры имён в `%s`: `%s`\n\n' % (d, '`, `'.join(sorted(names)[:4]))
    body += table(found, ['каталог', 'файлов', 'размер', 'по расширениям'])

    for f in ('.cache/wall-history', '.cache/wall-favorites', '.cache/wall-pinned',
              '.cache/wall-index'):
        p = os.path.join(HOME, f)
        if os.path.exists(p):
            body += '\n`%s` — %s' % (f, human(os.path.getsize(p)))

    cs = os.path.join(HOME, '.cache/wal/colors.sh')
    if os.path.exists(cs):
        body += '\n\n**pywal — текущая палитра**\n\n' + fence(read(cs, maxlines=30), 'bash')
    return body

@section('Горячие клавиши')
def s_keys():
    body = ''
    lst = gset('org.gnome.settings-daemon.plugins.media-keys', 'custom-keybindings')
    paths = re.findall(r"'([^']+)'", lst or '')
    rows = []
    for p in paths:
        base = ('org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:'
                + p)
        name = sh("gsettings get %s name" % base, timeout=8).strip("'")
        cmd = sh("gsettings get %s command" % base, timeout=8).strip("'")
        binding = sh("gsettings get %s binding" % base, timeout=8).strip("'")
        rows.append((binding, name, cmd))
    body += '**Свои сочетания** (%d)\n\n' % len(rows)
    body += table(rows, ['клавиши', 'название', 'команда'])

    dump = sh('dconf dump /org/gnome/desktop/wm/keybindings/')
    if dump:
        body += '\n\n**Изменённые сочетания оконного менеджера**\n\n' + fence(dump, 'ini')
    dump2 = sh('dconf dump /org/gnome/shell/keybindings/')
    if dump2:
        body += '\n\n**Сочетания оболочки**\n\n' + fence(dump2, 'ini')
    dump3 = sh('dconf dump /org/gnome/mutter/keybindings/')
    if dump3:
        body += '\n\n**Сочетания mutter**\n\n' + fence(dump3, 'ini')
    return body

@section('Расширения GNOME')
def s_ext():
    enabled = gset('org.gnome.shell', 'enabled-extensions')
    disabled = gset('org.gnome.shell', 'disabled-extensions')
    body = 'Включены: `%s`\n\nОтключены: `%s`\n\n' % (enabled, disabled)

    rows = []
    for base in (os.path.join(HOME, '.local/share/gnome-shell/extensions'),
                 '/usr/share/gnome-shell/extensions'):
        if not os.path.isdir(base):
            continue
        for name in sorted(os.listdir(base)):
            meta = os.path.join(base, name, 'metadata.json')
            ver, human_name = '', ''
            try:
                d = json.load(open(meta, encoding='utf-8'))
                ver = str(d.get('version', ''))
                human_name = d.get('name', '')
            except Exception:
                pass
            where = 'своё' if base.startswith(HOME) else 'системное'
            rows.append((name, human_name, ver, where))
    body += table(rows, ['uuid', 'название', 'версия', 'откуда'])

    for path, label in (
            ('/org/gnome/shell/extensions/dash-to-panel/', 'Dash to Panel'),
            ('/org/gnome/shell/extensions/blur-my-shell/', 'Blur My Shell'),
            ('/org/gnome/shell/extensions/just-perfection/', 'Just Perfection'),
            ('/org/gnome/shell/extensions/vitals/', 'Vitals'),
            ('/org/gnome/shell/extensions/user-theme/', 'User Themes')):
        d = sh('dconf dump ' + path)
        if d:
            body += '\n\n**%s**\n\n' % label + fence(d, 'ini')
    return body

@section('Терминал GNOME')
def s_gterm():
    d = sh('dconf dump /org/gnome/terminal/')
    if not d:
        return '_GNOME Terminal не настроен или не установлен_'
    keys = ('use-transparent-background', 'background-transparency-percent',
            'use-theme-colors', 'font', 'use-system-font', 'background-color',
            'foreground-color', 'audible-bell', 'scrollback-lines')
    picked = []
    for ln in d.splitlines():
        for k in keys:
            if ln.startswith(k + '='):
                picked.append(ln)
    body = ''
    if picked:
        body += '**Главное**\n\n' + fence('\n'.join(picked), 'ini') + '\n\n'
    body += '**Полный дамп**\n\n' + fence(d, 'ini')
    return body

@section('Tabby')
def s_tabby():
    cfg = os.path.join(HOME, '.config/tabby/config.yaml')
    if not os.path.exists(cfg):
        return '_конфиг не найден: %s_' % cfg
    raw = read(cfg)
    body = 'Конфиг: `%s`, %s\n\n' % (cfg, human(os.path.getsize(cfg)))

    # ключевые параметры внешнего вида — вытащим отдельно
    want = ('vibrancy', 'opacity', 'css', 'colorScheme', 'background',
            'frame', 'spaciness', 'font', 'theme', 'gpu', 'acrylic')
    picked = []
    for ln in raw.splitlines():
        low = ln.lower()
        for w in want:
            if w.lower() in low:
                picked.append(ln)
                break
    if picked:
        body += '**Строки про внешний вид**\n\n' + fence('\n'.join(picked[:60]), 'yaml') + '\n\n'

    # сам Custom CSS — целиком, это главное.
    # Блок yaml задан отступом: берём строки, отступ которых строго больше,
    # чем у самого ключа css. Регулярка «до первой строки без отступа» тут
    # не годится — она прихватывает соседние ключи той же секции.
    css_lines, indent, collecting = [], None, False
    for ln in raw.splitlines():
        if not collecting:
            m = re.match(r'^(\s*)css:\s*\|', ln)
            if m:
                indent = len(m.group(1))
                collecting = True
            continue
        if not ln.strip():
            css_lines.append('')
            continue
        cur = len(ln) - len(ln.lstrip())
        if cur <= indent:
            break
        css_lines.append(ln)
    if css_lines:
        # снимаем общий отступ, чтобы CSS читался как CSS
        pad = min(len(l) - len(l.lstrip()) for l in css_lines if l.strip())
        css = '\n'.join(l[pad:] if l.strip() else '' for l in css_lines)
        body += '**Custom CSS**\n\n' + fence(css.strip('\n'), 'css') + '\n\n'

    prof = raw.count('- id:')
    body += 'Профилей и групп в конфиге (по `- id:`): **%d**\n\n' % prof
    body += '**Полный конфиг** (секреты скрыты)\n\n'
    body += fence(sanitize(read(cfg, maxlines=400)), 'yaml')
    return body

@section('Chrome')
def s_chrome():
    body = ''
    ver = sh('google-chrome --version')
    if ver:
        body += 'Версия: `%s`\n\n' % ver
    prof = os.path.join(HOME, '.config/google-chrome/Default')
    body += 'Профиль: `%s` (%s)\n\n' % (prof, 'есть' if os.path.isdir(prof) else 'нет')

    pol = []
    for d in ('/etc/opt/chrome/policies/managed', '/etc/opt/chrome/policies/recommended'):
        for f in sorted(glob.glob(os.path.join(d, '*.json'))):
            pol.append('# ' + f + '\n' + read(f))
    if pol:
        body += '**Политики**\n\n' + fence('\n\n'.join(pol), 'json') + '\n\n'
    else:
        body += 'Политик в `/etc/opt/chrome/policies` нет.\n\n'

    for pf in ('Preferences', 'Secure Preferences'):
        p = os.path.join(prof, pf)
        if not os.path.exists(p):
            continue
        try:
            data = json.load(open(p, encoding='utf-8', errors='replace'))
        except Exception:
            continue
        exts = (data.get('extensions', {}) or {}).get('settings', {}) or {}
        rows = []
        for eid, meta in exts.items():
            man = meta.get('manifest', {}) or {}
            name = man.get('name', '')
            if not name or name.startswith('__MSG'):
                name = meta.get('path', '')
            if str(meta.get('location', '')) == '5':
                continue          # компонент самого браузера
            rows.append((eid[:20], str(name)[:38], str(man.get('version', '')),
                         'вкл' if meta.get('state') == 1 else 'выкл'))
        if rows:
            body += '**Расширения (%s)**\n\n' % pf + table(
                sorted(rows, key=lambda r: r[1].lower()),
                ['id', 'название', 'версия', 'состояние']) + '\n\n'
        sess = data.get('session', {}) or {}
        if sess:
            body += '**Запуск (%s)**: restore_on_startup=`%s`, startup_urls=`%s`\n\n' % (
                pf, sess.get('restore_on_startup'), sess.get('startup_urls'))
    return body

@section('Своя страница новой вкладки')
def s_newtab():
    d = os.path.join(HOME, '.local/share/newtab')
    if not os.path.isdir(d):
        return '_каталог %s не найден_' % d
    body = ''
    rows = []
    for name in ('index.html', 'links.txt', 'icons.json'):
        p = os.path.join(d, name)
        if os.path.exists(p):
            rows.append((name, human(os.path.getsize(p)),
                         time.strftime('%Y-%m-%d %H:%M',
                                       time.localtime(os.path.getmtime(p)))))
        else:
            rows.append((name, '—', ''))
    body += table(rows, ['файл', 'размер', 'изменён']) + '\n\n'

    links = read(os.path.join(d, 'links.txt'))
    if links:
        body += '**links.txt**\n\n' + fence(links) + '\n\n'

    ic = os.path.join(d, 'icons.json')
    if os.path.exists(ic):
        try:
            data = json.load(open(ic, encoding='utf-8'))
            body += 'Кэш значков: **%d** хостов — %s\n\n' % (
                len(data), ', '.join(sorted(data.keys())[:12]))
        except Exception:
            body += 'Кэш значков есть, но не читается.\n\n'

    idx = os.path.join(d, 'index.html')
    if os.path.exists(idx):
        html = read(idx)
        body += 'В странице: плиток **%d**, значков **%d**, картинок фона **%d**\n\n' % (
            html.count('class="tile"'),
            html.count('src="data:image'),
            html.count('"file://'))
        m = re.search(r'\.clock\{font-size:(\d+)px', html)
        if m:
            body += 'Размер часов: `%s px`\n\n' % m.group(1)
    return body

@section('Автозапуск, службы, таймеры')
def s_services():
    body = ''
    t = sh('systemctl --user list-timers --all --no-pager')
    if t:
        body += '**Таймеры пользователя**\n\n' + fence(t) + '\n\n'
    u = sh('systemctl --user list-units --type=service --state=running --no-pager')
    if u:
        body += '**Работающие службы пользователя**\n\n' + fence(u) + '\n\n'

    ud = os.path.join(HOME, '.config/systemd/user')
    files = sorted(glob.glob(os.path.join(ud, '*.service')) +
                   glob.glob(os.path.join(ud, '*.timer')))
    for f in files:
        body += '**%s**\n\n' % os.path.basename(f) + fence(read(f), 'ini') + '\n\n'

    cr = sh('crontab -l')
    if cr:
        body += '**crontab**\n\n' + fence(cr) + '\n\n'

    au = os.path.join(HOME, '.config/autostart')
    rows = []
    for f in sorted(glob.glob(os.path.join(au, '*.desktop'))):
        txt = read(f)
        name = re.search(r'^Name=(.*)$', txt, re.M)
        ex = re.search(r'^Exec=(.*)$', txt, re.M)
        rows.append((os.path.basename(f),
                     name.group(1) if name else '',
                     ex.group(1) if ex else ''))
    if rows:
        body += '**Автозапуск**\n\n' + table(rows, ['файл', 'название', 'команда'])

    # агенты безопасности — важно, что живы
    ag = sh('systemctl list-units --type=service --no-pager --all '
            '| grep -iE "klnagent|vxagent|kesl|antivir"')
    if ag:
        body += '\n\n**Агенты безопасности**\n\n' + fence(ag)
    return body

@section('Свои скрипты ~/bin')
def s_bin():
    d = os.path.join(HOME, 'bin')
    if not os.path.isdir(d):
        return '_каталога ~/bin нет_'
    rows = []
    for name in sorted(os.listdir(d)):
        p = os.path.join(d, name)
        if not os.path.isfile(p):
            continue
        first = ''
        try:
            with open(p, encoding='utf-8', errors='replace') as f:
                for ln in f.read().splitlines()[:6]:
                    if ln.startswith('#') and not ln.startswith('#!'):
                        first = ln.lstrip('# ').strip()
                        break
        except Exception:
            pass
        rows.append((name, human(os.path.getsize(p)),
                     'да' if os.access(p, os.X_OK) else 'нет', first[:60]))
    return table(rows, ['скрипт', 'размер', 'исполняемый', 'о чём'])

@section('Conky')
def s_conky():
    p = os.path.join(HOME, '.config/conky/main.conf')
    if not os.path.exists(p):
        alt = sorted(glob.glob(os.path.join(HOME, '.config/conky/*')))
        if not alt:
            return '_conky не настроен_'
        p = alt[0]
    body = 'Конфиг: `%s`\n\n' % p
    body += fence(read(p, maxlines=120), 'lua')
    run = sh('pgrep -a conky')
    body += '\n\nПроцесс: ' + (fence(run) if run else '_не запущен_')
    return body

@section('Оболочка и алиасы')
def s_shell():
    body = ''
    for f in ('.bashrc', '.bash_aliases', '.profile', '.zshrc'):
        p = os.path.join(HOME, f)
        if not os.path.exists(p):
            continue
        txt = read(p)
        al = [ln for ln in txt.splitlines()
              if ln.strip().startswith('alias ') or ln.strip().startswith('export ')]
        body += '**%s** — %s, строк %d\n\n' % (f, human(os.path.getsize(p)),
                                               len(txt.splitlines()))
        if al:
            body += fence('\n'.join(al[:40])) + '\n\n'
    return body

@section('Шрифты')
def s_fonts():
    n = sh('fc-list | wc -l')
    nerd = sh('fc-list | grep -ci nerd')
    body = 'Всего шрифтов: **%s**, из них Nerd Font: **%s**\n\n' % (n, nerd)
    fam = sh("fc-list --format='%{family[0]}\\n' | sort -u | grep -i nerd | head -12")
    if fam:
        body += fence(fam)
    return body

@section('Evolution')
def s_evo():
    body = ''
    ver = sh('evolution --version')
    if ver:
        body += 'Версия: `%s`\n\n' % ver
    rows = [
        ('menubar-visible', sh('gsettings get org.gnome.evolution.shell menubar-visible')),
        ('menubar-visible-sub', sh('gsettings get org.gnome.evolution.shell menubar-visible-sub')),
    ]
    body += table([r for r in rows if r[1]], ['ключ', 'значение']) + '\n\n'
    for f in glob.glob(os.path.join(HOME, '.local/share/applications/*.desktop')):
        txt = read(f)
        if 'evolution' in txt.lower():
            body += '**Свой ярлык** `%s`\n\n' % os.path.basename(f)
            ex = [ln for ln in txt.splitlines() if ln.startswith('Exec=')]
            body += fence('\n'.join(ex), 'ini') + '\n\n'
    return body

@section('Сеть и VPN')
def s_net():
    body = ''
    con = sh("nmcli -t -f NAME,TYPE,DEVICE connection show")
    if con:
        body += '**Подключения NetworkManager**\n\n' + fence(con) + '\n\n'
    act = sh("nmcli -t -f NAME,TYPE connection show --active")
    if act:
        body += '**Активные**\n\n' + fence(act) + '\n\n'
    ifs = sh("ip -br link")
    if ifs:
        body += '**Интерфейсы**\n\n' + fence(ifs)
    return body

@section('Сводка: чего не хватает')
def s_summary():
    checks = []

    def add(name, ok, hint):
        checks.append((name, '✓' if ok else '—', '' if ok else hint))

    add('банк обоев', any(os.path.isdir(os.path.join(HOME, d, 'wallpapers-uw'))
                          for d in ('Pictures', 'Изображения')),
        'нет каталога wallpapers-uw')
    timers = sh('systemctl --user list-timers --all --no-pager')
    add('еженедельное пополнение обоев', 'wallpaper' in timers.lower(),
        'нет таймера пополнения')
    add('страница новой вкладки',
        os.path.exists(os.path.join(HOME, '.local/share/newtab/index.html')),
        'страница не собрана')
    add('кэш значков',
        os.path.exists(os.path.join(HOME, '.local/share/newtab/icons.json')),
        'значки не кэшируются, при пересборке могут слетать')
    add('Tabby настроен',
        os.path.exists(os.path.join(HOME, '.config/tabby/config.yaml')),
        'нет конфига Tabby')
    add('conky', os.path.exists(os.path.join(HOME, '.config/conky/main.conf')),
        'виджет не настроен')
    add('pywal', os.path.exists(os.path.join(HOME, '.cache/wal/colors.sh')),
        'палитра не сгенерирована')
    add('Nerd Font', bool(sh('fc-list | grep -ci nerd') not in ('', '0')),
        'шрифт со значками не установлен')
    add('свои хоткеи',
        bool(re.findall(r"'([^']+)'",
                        gset('org.gnome.settings-daemon.plugins.media-keys',
                             'custom-keybindings') or '')),
        'своих сочетаний не зарегистрировано')
    return table(checks, ['что', 'есть', 'замечание'])

# ---------------------------------------------------------------- сборка

def main():
    started = time.time()
    head = [
        '# Снимок десктопа',
        '',
        '- дата: **%s**' % time.strftime('%Y-%m-%d %H:%M'),
        '- машина: **%s**' % (sh('hostname') or '?'),
        '- пользователь: **%s**' % os.environ.get('USER', '?'),
        '',
        'Собран `desktop-audit.sh`. Значения секретных ключей заменены на '
        '`<скрыто>`.',
        '',
    ]
    parts = []
    total = len(SECTIONS)
    for i, (title, fn) in enumerate(SECTIONS, start=1):
        sys.stderr.write('  [%d/%d] %s\n' % (i, total, title))
        sys.stderr.flush()
        try:
            body = fn()
        except Exception as e:
            body = fence('не собралось: %r' % (e,))
        if not body or not str(body).strip():
            body = '_пусто_'
        parts.append('## %s\n\n%s\n' % (title, body))

    text = '\n'.join(head) + '\n' + '\n'.join(parts)
    text = sanitize(text)

    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(text)

    sys.stderr.write('\nготово за %.1f с\n' % (time.time() - started))
    print(OUT)

main()
PYEOF

RC=$?
if [ "$RC" -ne 0 ]; then
    echo "сбор завершился с ошибкой (код $RC)"
    exit "$RC"
fi

echo
echo "==> файл: $OUT"
if [ -f "$OUT" ]; then
    echo "    размер: $(du -h "$OUT" | cut -f1)"
    echo "    строк:  $(wc -l < "$OUT")"
fi
echo
echo "пришли этот файл в чат — по нему видно, как настроена система."
