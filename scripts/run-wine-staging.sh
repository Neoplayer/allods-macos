#!/bin/zsh
# Usage: run-wine.sh <windows program> [args...]
export WINEPREFIX="$HOME/Games/allods-prefix"
export WINEDEBUG="${WINEDEBUG:--all,err+all}"
export WINEMSYNC=1
exec "$HOME/Games/wine/Wine Staging.app/Contents/Resources/wine/bin/wine" "$@"
