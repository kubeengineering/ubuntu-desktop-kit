#!/usr/bin/env bash
# Быстрая проверка после точечной правки: синтаксис + только нужные группы.
#
# Полный selftest --full — это ~300 проверок и десятки минут ожидания в
# цикле правок. После правки ОДНОГО блока этого не нужно: гоняем группу
# этого блока и группы, которые от него зависят. Полный прогон остаётся
# для финала перед выкладкой.
#
#   bash tools/check.sh theme          одна группа
#   bash tools/check.sh "buttons refresh"   несколько
#   bash tools/check.sh                только синтаксис и справка
#
# Какую группу гонять после какой правки — таблица «Правишь → гоняй»
# в SCRIPT-MAP.md.

set -u
cd "$(dirname "$0")/.."

echo "== синтаксис =="
if ! bash -n desktop-kit.sh; then
    echo "СИНТАКСИС СЛОМАН — дальше нет смысла"
    exit 1
fi
echo "  ок"

echo "== справка живая =="
if ! bash desktop-kit.sh help >/dev/null 2>&1; then
    echo "  usage упал"
    exit 1
fi
echo "  ок"

if [ $# -eq 0 ]; then
    echo
    echo "группы не заданы — на этом всё"
    echo "полный прогон: bash desktop-kit.sh selftest --full"
    exit 0
fi

echo "== группы: $* =="
bash desktop-kit.sh selftest --only "$*" 2>&1 | grep -E "FAIL|пройдено|^  --"
