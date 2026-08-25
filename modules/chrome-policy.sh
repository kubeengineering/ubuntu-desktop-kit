#!/usr/bin/env bash
# Ставит расширение Custom New Tab URL через системную политику Chrome
# и сразу указывает ему нашу страницу.
#
#   sudo ./modules/chrome-policy.sh
#
# Политика лежит в /etc/opt/chrome/policies/managed/ — Chrome читает её
# при старте. Расширение скачивается из Web Store: если он недоступен
# из корпоративной сети, политика не сработает, ставь вручную
# (см. modules/chrome.md).

set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "нужен root: sudo $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
PAGE="file://$REAL_HOME/.local/share/newtab/index.html"

if [ ! -f "$REAL_HOME/.local/share/newtab/index.html" ]; then
    echo "страница не найдена — сначала собери её: ./modules/newtab.sh"
    exit 1
fi

# Custom New Tab URL, ID из Chrome Web Store
EXT_ID="mmjbdbjnoablegbkcklggeknkfcjkjia"

POL_DIR="/etc/opt/chrome/policies/managed"
mkdir -p "$POL_DIR"

cat > "$POL_DIR/newtab.json" <<EOF
{
  "ExtensionInstallForcelist": [
    "$EXT_ID;https://clients2.google.com/service/update2/crx"
  ],
  "ExtensionSettings": {
    "$EXT_ID": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx",
      "file_url_navigation_allowed": true
    }
  },
  "URLAllowlist": [ "file:///" ]
}
EOF

chmod 644 "$POL_DIR/newtab.json"

echo "политика записана: $POL_DIR/newtab.json"
echo "страница:          $PAGE"
echo
echo "дальше:"
echo "  1. перезапусти Chrome полностью"
echo "  2. открой chrome://policy и нажми Reload policies — расширение появится"
echo "  3. в настройках расширения укажи адрес:"
echo "     $PAGE"
echo
echo "снять политику:"
echo "  sudo rm $POL_DIR/newtab.json"
