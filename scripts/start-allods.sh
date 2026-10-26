#!/bin/zsh
# Starts VK Play GameCenter in the Allods bottle using the CrossOver engine copy
# in ~/Games/cx, which carries the patched ntoskrnl.exe (patches/ntoskrnl-impactdrv.patch).
set -e

WINE="$HOME/Games/cx/CrossOver/bin/wine"
export WINEPREFIX="$HOME/Library/Application Support/CrossOver/Bottles/Allods"

# Stop anything left from the stock CrossOver engine: it would load the unpatched ntoskrnl.
"$HOME/Games/cx/CrossOver/bin/wineserver" -k 2>/dev/null || true
sleep 2

"$WINE" --bottle Allods sc start impactdrv >/dev/null
exec "$WINE" --bottle Allods "C:\\users\\crossover\\AppData\\Local\\GameCenter\\GameCenter.exe"
