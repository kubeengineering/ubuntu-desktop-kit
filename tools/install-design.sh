#!/usr/bin/env bash
# Установка запускалки `design` — одной командой, на свежей системе тоже.
#
#   curl -fsSL https://raw.githubusercontent.com/kubeengineering/ubuntu-desktop-kit/main/tools/install-design.sh | bash
#
# Кладёт запускалку в ~/.local/bin и следит за тем, чтобы её было видно
# по имени. Тонкость, из-за которой простой однострочник не годится:
# Ubuntu добавляет ~/.local/bin в PATH из ~/.profile, но ТОЛЬКО если
# каталог уже существовал на момент входа в систему. На свежей машине
# его нет, поэтому после создания команда не найдётся до перезахода —
# если не поправить это сразу, что мы здесь и делаем.

set -uo pipefail

RAW="https://raw.githubusercontent.com/kubeengineering/ubuntu-desktop-kit/main"
BIN="$HOME/.local/bin"

say()  { printf '\033[38;5;108m  ставлю\033[0m  %s\n' "$*"; }
warn() { printf '\033[38;5;174m  внимание\033[0m  %s\n' "$*" >&2; }

if ! command -v curl >/dev/null 2>&1; then
    warn "нет curl, поставь его: sudo apt install -y curl"
    exit 1
fi

mkdir -p "$BIN"

if ! curl -fsSL --max-time 45 "$RAW/tools/design" -o "$BIN/design"; then
    warn "не удалось скачать запускалку — проверь сеть"
    exit 1
fi
if ! head -1 "$BIN/design" | grep -q '^#!/usr/bin/env bash'; then
    warn "скачалось не то — оставляю как есть"
    rm -f "$BIN/design"
    exit 1
fi
chmod +x "$BIN/design"
say "запускалка: $BIN/design"

# Видно ли её по имени, и будет ли видно в новых терминалах
in_path=0
case ":$PATH:" in
    *":$BIN:"*) in_path=1 ;;
esac

profile_ok=0
if grep -qs 'local/bin' "$HOME/.profile" 2>/dev/null; then
    profile_ok=1
fi
if grep -qs 'local/bin' "$HOME/.bashrc" 2>/dev/null; then
    profile_ok=1
fi

if [ "$profile_ok" = "0" ]; then
    printf '\n# добавлено установщиком design\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
    say "прописал путь в ~/.bashrc"
fi

# Сразу тянем сам инструмент, чтобы первый запуск был мгновенным
"$BIN/design" --update

echo
if [ "$in_path" = "1" ]; then
    say "готово, пробуй:  design"
else
    say "готово, но в ЭТОМ терминале команда ещё не видна"
    say "выполни один раз:  source ~/.profile"
    say "или просто открой новый терминал, дальше — design"
fi
