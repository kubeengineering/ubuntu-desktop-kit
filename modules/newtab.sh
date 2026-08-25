#!/usr/bin/env bash
# Своя страница новой вкладки для Chrome: часы, свои ярлыки,
# обои рабочего стола фоном (кроме той картинки, что стоит на столе).
#
#   ./modules/newtab.sh
#
# Картинка запоминается между вкладками и перезапусками браузера,
# листается стрелками влево/вправо прямо на странице.
#
# Подключение (Chrome не даёт подменить новую вкладку без расширения):
#   1. поставить New Tab Redirect или Custom New Tab URL из Web Store
#   2. в его настройках указать file:///home/USER/.local/share/newtab/index.html
#   3. chrome://extensions -> Details расширения -> включить
#      "Allow access to file URLs" (иначе будет белый экран)

set -uo pipefail

DIR="$HOME/.local/share/newtab"
LINKS="$DIR/links.txt"

WALLDIR="$HOME/Pictures/wallpapers-uw"
if [ ! -d "$WALLDIR" ]; then
    WALLDIR="$HOME/Изображения/wallpapers-uw"
fi
if [ ! -d "$WALLDIR" ]; then
    WALLDIR="$HOME/Pictures/wallpapers"
fi

mkdir -p "$DIR"

# первый запуск — вытаскиваем ярлыки из Chrome как заготовку
if [ ! -s "$LINKS" ]; then
    echo "==> собираю ярлыки из Chrome"
    P="$HOME/.config/google-chrome/Default"
    rm -rf /tmp/chr; mkdir -p /tmp/chr
    for f in "Top Sites" "History" "Bookmarks" "Preferences"; do
        if [ -f "$P/$f" ]; then
            cp "$P/$f" "/tmp/chr/$f" 2>/dev/null
        fi
    done

    python3 - <<'PY' > "$LINKS"
import json, os, sqlite3
from collections import OrderedDict
D = '/tmp/chr'
found = OrderedDict()

def add(name, url):
    if not url or not url.startswith('http'):
        return
    if url.startswith('https://www.google.com/search'):
        return
    key = url.rstrip('/')
    if key in found:
        return
    name = (name or '').strip()
    if not name:
        name = url.split('/')[2] if '://' in url else url
    found[key] = name[:22]

pref = os.path.join(D, 'Preferences')
if os.path.exists(pref):
    try:
        data = json.load(open(pref, encoding='utf-8', errors='replace'))
        def dig(o):
            if isinstance(o, dict):
                if isinstance(o.get('url'), str):
                    add(o.get('title') or o.get('name'), o['url'])
                for v in o.values():
                    dig(v)
            elif isinstance(o, list):
                for v in o:
                    dig(v)
        for k in ('custom_links', 'ntp', 'browser'):
            if k in data:
                dig(data[k])
    except Exception:
        pass

ts = os.path.join(D, 'Top Sites')
if os.path.exists(ts):
    try:
        c = sqlite3.connect(ts)
        for url, title in c.execute('SELECT url, title FROM top_sites'):
            add(title, url)
        c.close()
    except Exception:
        pass

bm = os.path.join(D, 'Bookmarks')
if os.path.exists(bm):
    try:
        d = json.load(open(bm, encoding='utf-8'))
        def walk(node):
            for ch in node.get('children', []):
                if ch.get('type') == 'url':
                    add(ch.get('name'), ch.get('url'))
                elif ch.get('type') == 'folder':
                    walk(ch)
        for root in d.get('roots', {}).values():
            if isinstance(root, dict):
                walk(root)
    except Exception:
        pass

hist = os.path.join(D, 'History')
if os.path.exists(hist) and len(found) < 12:
    try:
        c = sqlite3.connect(hist)
        for url, title, _ in c.execute(
                'SELECT url, title, visit_count FROM urls ORDER BY visit_count DESC LIMIT 40'):
            add(title, url)
        c.close()
    except Exception:
        pass

print('# ярлыки новой вкладки. формат: Название|адрес')
print('# лишнее удаляй, порядок можно менять, потом запусти скрипт снова')
for url, name in list(found.items())[:14]:
    print(f'{name}|{url}')
PY
    rm -rf /tmp/chr
fi

# текущие обои исключаем — на новой вкладке всегда другая картинка
CUR=$(gsettings get org.gnome.desktop.background picture-uri-dark 2>/dev/null | tr -d "'" | sed 's#^file://##')
CURNAME=$(basename "$CUR")

BG="#1a1b26"
if [ -f "$HOME/.cache/wal/colors.sh" ]; then
    . "$HOME/.cache/wal/colors.sh"
    BG="$background"
fi

IMGS=$(find "$WALLDIR" -maxdepth 1 -type f -iname '*.jpg' 2>/dev/null \
       | grep -vF "$CURNAME" | sort | sed 's|.*|    "file://&",|')

# значки берём из локальной базы Chrome: внутренние адреса сервис Google
# не видит, а Chrome их уже скачал сам
FAVDB=/tmp/newtab-favicons
rm -f "$FAVDB"
if [ -f "$HOME/.config/google-chrome/Default/Favicons" ]; then
    cp "$HOME/.config/google-chrome/Default/Favicons" "$FAVDB" 2>/dev/null
fi

TILES=$(python3 - "$LINKS" "$FAVDB" <<'PY'
import sys, html, os, base64, sqlite3

cur = None
if len(sys.argv) > 2 and os.path.exists(sys.argv[2]):
    try:
        cur = sqlite3.connect(sys.argv[2]).cursor()
    except Exception:
        cur = None

def local_icon(host):
    """Самый крупный значок этого хоста из кэша Chrome, как data:URI."""
    if cur is None:
        return ''
    try:
        row = cur.execute(
            'SELECT b.image_data FROM icon_mapping m '
            'JOIN favicon_bitmaps b ON b.icon_id = m.icon_id '
            'WHERE m.page_url LIKE ? AND length(b.image_data) > 0 '
            'ORDER BY b.width DESC LIMIT 1', ('%' + host + '%',)).fetchone()
    except Exception:
        return ''
    if not row or not row[0]:
        return ''
    return 'data:image/png;base64,' + base64.b64encode(row[0]).decode()

rows = []
for line in open(sys.argv[1], encoding='utf-8'):
    line = line.strip()
    if not line or line.startswith('#') or '|' not in line:
        continue
    name, url = line.split('|', 1)
    name = html.escape(name.strip()[:22]); url = html.escape(url.strip())
    letter = html.escape(name[:1].upper()) if name else '?'
    host = url.split('/')[2] if '://' in url else url

    # порядок попыток: кэш Chrome -> сам сайт -> сервис Google -> буква
    chain = [local_icon(host),
             f'https://{host}/favicon.ico',
             f'https://www.google.com/s2/favicons?sz=64&domain={host}']
    chain = [c for c in chain if c]
    src, alts = chain[0], '|'.join(chain[1:])

    rows.append(f'<a class="tile" href="{url}"><span class="ico">'
                f'<img src="{src}" data-alt="{html.escape(alts)}" data-letter="{letter}" '
                f'onerror="nextIcon(this)"></span>'
                f'<span class="cap">{name}</span></a>')
print('\n'.join(rows))
PY
)
rm -f "$FAVDB"

cat > "$DIR/index.html" <<EOF
<!doctype html>
<html><head><meta charset="utf-8"><title>New Tab</title>
<style>
  html,body{margin:0;height:100%;font-family:"JetBrainsMono Nerd Font",monospace;}
  body{background:$BG center/cover no-repeat fixed;display:flex;align-items:center;
       justify-content:center;flex-direction:column;gap:34px;}
  .box{padding:30px 56px;border-radius:22px;background:rgba(0,0,0,.32);
       backdrop-filter:blur(14px);text-align:center;}
  .clock{font-size:110px;font-weight:600;color:#fff;letter-spacing:2px;line-height:1;}
  .date{font-size:24px;font-weight:600;color:#fff;opacity:.9;margin-top:8px;}
  .tiles{display:flex;flex-wrap:wrap;gap:14px;justify-content:center;max-width:900px;}
  .tile{width:130px;padding:22px 10px;border-radius:16px;background:rgba(0,0,0,.32);
        backdrop-filter:blur(10px);text-decoration:none;display:flex;flex-direction:column;
        align-items:center;gap:11px;transition:.15s;}
  .tile:hover{background:rgba(255,255,255,.18);transform:translateY(-2px);}
  .ico{width:52px;height:52px;border-radius:13px;background:rgba(255,255,255,.14);
       display:flex;align-items:center;justify-content:center;color:#fff;font-size:22px;font-weight:700;}
  .ico img{width:34px;height:34px;}
  .cap{font-size:16px;font-weight:700;color:#fff;max-width:116px;overflow:hidden;
       text-overflow:ellipsis;white-space:nowrap;}
  .hint{position:fixed;bottom:16px;right:20px;font-size:12px;color:#fff;opacity:.35;}
  .toast{position:fixed;bottom:16px;left:20px;font-size:13px;color:#fff;opacity:0;
         background:rgba(0,0,0,.45);padding:7px 13px;border-radius:9px;transition:opacity .25s;}
</style></head>
<body>
  <div class="box"><div class="clock" id="c"></div><div class="date" id="d"></div></div>
  <div class="tiles">
$TILES
  </div>
  <div class="hint">← → смена фона</div>
  <div class="toast" id="t"></div>
<script>
// значок не загрузился — пробуем следующий источник, в конце ставим букву
function nextIcon(img){
  var rest=img.dataset.alt;
  if(!rest){rest='';}
  var list=rest.split('|').filter(Boolean);
  if(list.length){
    img.src=list.shift();
    img.dataset.alt=list.join('|');
    return;
  }
  var letter=img.dataset.letter;
  if(!letter){letter='?';}
  img.replaceWith(document.createTextNode(letter));
}
const imgs=[
$IMGS
];
const KEY='ntbg';
let idx=parseInt(localStorage.getItem(KEY),10);
if(isNaN(idx)){idx=-1;}
if(idx<0){idx=Math.floor(Math.random()*imgs.length);}
if(idx>=imgs.length){idx=Math.floor(Math.random()*imgs.length);}
function show(i,say){
  if(!imgs.length)return;
  idx=(i%imgs.length+imgs.length)%imgs.length;
  localStorage.setItem(KEY,idx);
  document.body.style.backgroundImage='url("'+imgs[idx]+'")';
  if(say){
    const t=document.getElementById('t');
    t.textContent=(idx+1)+' / '+imgs.length;
    t.style.opacity='1';
    clearTimeout(window._tm);
    window._tm=setTimeout(function(){t.style.opacity='0';},1400);
  }
}
show(idx,false);
document.addEventListener('keydown',function(e){
  if(e.key==='ArrowRight'){show(idx+1,true);e.preventDefault();}
  if(e.key==='ArrowLeft'){show(idx-1,true);e.preventDefault();}
});
function tick(){const n=new Date();
  document.getElementById('c').textContent=String(n.getHours()).padStart(2,'0')+':'+String(n.getMinutes()).padStart(2,'0');
  document.getElementById('d').textContent=n.toLocaleDateString('ru-RU',{weekday:'long',day:'numeric',month:'long'});}
tick();setInterval(tick,10000);
</script>
</body></html>
EOF

echo "==> страница: $DIR/index.html"
echo "    ярлыков:  $(grep -c 'class="tile"' "$DIR/index.html")"
echo "    значков из кэша Chrome: $(grep -o 'src="data:image' "$DIR/index.html" | wc -l)"
echo "    картинок: $(echo "$IMGS" | grep -c 'file://')"
echo "    свои ссылки правь в: $LINKS"
