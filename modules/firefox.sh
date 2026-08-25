#!/usr/bin/env bash
# Тема Firefox под палитру обоев + обои фоном новой вкладки.
#
#   ./modules/firefox.sh
#
# Firefox должен быть ЗАКРЫТ. Браузером по умолчанию не назначается.
# Основано на конфиге Zproger/bspwm-dotfiles, но цвета не захардкожены,
# а берутся из pywal — то есть меняются вместе с обоями.

set -uo pipefail

echo "==> Firefox: поиск профиля"

if pgrep -x firefox >/dev/null; then
    echo "    Firefox запущен — закрой его и запусти скрипт снова"
    exit 1
fi

# snap-версия (умолчание Ubuntu 24.04) и классическая
PROF=""
for base in "$HOME/snap/firefox/common/.mozilla/firefox" "$HOME/.mozilla/firefox"; do
    if [ -d "$base" ]; then
        for p in "$base"/*.default-release "$base"/*.default; do
            if [ -d "$p" ]; then
                PROF="$p"
            fi
        done
    fi
done

if [ -z "$PROF" ]; then
    echo "    профиль не найден — запусти Firefox один раз, закрой, повтори"
    exit 1
fi
echo "    профиль: $PROF"

# цвета из палитры обоев, иначе Tokyo Night
BG="#1a1b26"; FG="#c0caf5"; AC="#7aa2f7"; SEL="#3b4261"
if [ -f "$HOME/.cache/wal/colors.sh" ]; then
    . "$HOME/.cache/wal/colors.sh"
    BG="$background"; FG="$foreground"; AC="$color4"; SEL="$color8"
fi
echo "    палитра: фон $BG, акцент $AC"

mkdir -p "$PROF/chrome"

# текущие обои рабочего стола -> фон новой вкладки
WALL=$(gsettings get org.gnome.desktop.background picture-uri-dark 2>/dev/null | tr -d "'" | sed 's|^file://||')
if [ -f "$WALL" ]; then
    cp "$WALL" "$PROF/chrome/bg.jpg"
    echo "    обои: $(basename "$WALL")"
fi

cat > "$PROF/user.js" <<EOF
// интерфейс
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.tabs.inTitlebar", 1);
user_pref("browser.uidensity", 0);
user_pref("browser.compactmode.show", true);

// стартовая и новая вкладка
user_pref("browser.startup.page", 1);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.default.sites", "");

// удобства
user_pref("browser.urlbar.suggest.calculator", true);
user_pref("browser.urlbar.unitConversion.enabled", true);
user_pref("browser.search.suggest.enabled", true);
user_pref("general.smoothScroll", true);
user_pref("browser.tabs.loadInBackground", true);
user_pref("browser.download.useDownloadDir", false);

// приватность
user_pref("privacy.trackingprotection.enabled", true);
user_pref("browser.contentblocking.category", "strict");
EOF

cat > "$PROF/chrome/userChrome.css" <<EOF
:root {
  --k-bg: $BG;
  --k-fg: $FG;
  --k-accent: $AC;
  --k-sel: $SEL;

  --toolbar-bgcolor: var(--k-bg) !important;
  --lwt-toolbarbutton-icon-fill: var(--k-fg) !important;
  --urlbar-separator-color: transparent !important;
  --autocomplete-popup-background: var(--k-bg) !important;
  --default-arrowpanel-background: var(--k-bg) !important;
  --default-arrowpanel-color: var(--k-fg) !important;
  --tab-border-radius: 8px !important;
}

/* панели в цвет палитры */
#navigator-toolbox,
#nav-bar,
#PersonalToolbar,
#titlebar,
#TabsToolbar {
  background: var(--k-bg) !important;
  border: none !important;
  box-shadow: none !important;
}

/* вкладки: скруглённые, активная подсвечена акцентом */
.tabbrowser-tab .tab-background {
  border-radius: 8px !important;
  margin-block: 4px !important;
  border: none !important;
}
.tabbrowser-tab[selected="true"] .tab-background {
  background: var(--k-sel) !important;
  box-shadow: inset 0 -2px 0 0 var(--k-accent) !important;
}
.tabbrowser-tab:not([selected]):hover .tab-background {
  background: color-mix(in srgb, var(--k-fg) 10%, transparent) !important;
}
.tabbrowser-tab[fadein]:not([selected]):not([pinned]) {
  max-width: 190px !important;
}

/* адресная строка */
#urlbar,
#searchbar {
  border-radius: 10px !important;
  background: color-mix(in srgb, var(--k-fg) 8%, transparent) !important;
  border: 1px solid transparent !important;
}
#urlbar[focused="true"] {
  border-color: var(--k-accent) !important;
  background: color-mix(in srgb, var(--k-fg) 12%, transparent) !important;
}
#urlbar-background {
  background: transparent !important;
  border: none !important;
}

/* подсказки — шрифтом терминала */
.urlbarView-row {
  font-family: "JetBrainsMono Nerd Font", monospace !important;
  border-radius: 8px !important;
}
.urlbarView-row[selected] {
  background: var(--k-sel) !important;
}

/* меню и попапы */
menupopup, panel {
  --panel-background: var(--k-bg) !important;
  --panel-border-radius: 10px !important;
}

/* убрать лишнее */
#firefox-view-button,
#alltabs-button { display: none !important; }
EOF

cat > "$PROF/chrome/userContent.css" <<EOF
/* новая вкладка: обои рабочего стола фоном */
@-moz-document url("about:newtab"), url("about:home"), url("about:blank") {
  body {
    background-image: url("bg.jpg") !important;
    background-size: cover !important;
    background-position: center !important;
    background-attachment: fixed !important;
  }
  .search-wrapper,
  .top-sites,
  .body-wrapper {
    backdrop-filter: blur(6px);
    border-radius: 14px;
  }
  .outer-wrapper {
    background: color-mix(in srgb, $BG 45%, transparent) !important;
  }
  html { background: $BG !important; }
}

/* без белой вспышки при загрузке */
@-moz-document url-prefix("about:") {
  html:not(#ublock0-epicker), body { background-color: $BG !important; }
}

/* скроллбары в тон */
* {
  scrollbar-color: $AC transparent !important;
  scrollbar-width: thin !important;
}
EOF

echo
echo "    готово — запусти Firefox, изменения применятся сразу"
