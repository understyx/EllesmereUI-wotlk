#!/usr/bin/env bash
# Reject translated UI literals in runtime code. Translations belong in
# Locales/<code>.lua; runtime files should render English keys through L/Lf.
set -euo pipefail

cd "$(dirname "$0")/.."

matches="$({
  rg -n --pcre2 '[\x{3400}-\x{9FFF}]' \
    --glob '*.lua' \
    --glob '!Locales/**' \
    --glob '!Libs/**' \
    --glob '!EllesmereUIPallyPower/libs/**' \
    --glob '!EllesmereUIPallyPower/locale/**' \
    . \
  | rg --pcre2 'SetText|AddLine|AddDoubleLine|SetFormattedText|AddMessage|print\(|EllesmereUI\.Print|\b(text|tooltip|label|title|message)\s*=' \
  | rg -v 'EUI__General_Options\.lua:.*\["zh(CN|TW)"\]'
} || true)"

if [[ -n "$matches" ]]; then
  echo "Hard-coded translated UI text found outside locale catalogs:"
  echo "$matches"
  echo
  echo "Keep the English source string in runtime code via EllesmereUI.L/Lf and add the translation under Locales/."
  exit 1
fi

echo "No hard-coded CJK UI strings found outside locale catalogs."
