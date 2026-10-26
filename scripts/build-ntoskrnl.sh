#!/bin/zsh
# Rebuilds the patched ntoskrnl.exe from CodeWeavers' CrossOver sources and installs it
# into the engine copy in ~/Games/cx. Needs: brew install mingw-w64 bison
set -e

REPO="${0:A:h:h}"
CX_VERSION="${1:-26.3.0}"
SRC="$HOME/Games/src"
URL="https://media.codeweavers.com/pub/crossover/source/crossover-sources-$CX_VERSION.tar.gz"
TARGET="$HOME/Games/cx/CrossOver/lib/wine/x86_64-windows/ntoskrnl.exe"

mkdir -p "$SRC"
cd "$SRC"
[[ -f cx.tar.gz ]] || curl -L --fail -o cx.tar.gz "$URL"

if [[ ! -d sources/wine ]]; then
    tar xzf cx.tar.gz 'sources/wine/*'
    patch -d sources/wine -p1 < "$REPO/patches/ntoskrnl-impactdrv.patch"
fi

mkdir -p build
cd build
[[ -f Makefile ]] || zsh -c "$(cat "$REPO/wine/configure-command.txt")"
make -j"$(sysctl -n hw.ncpu)" dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe

cp dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe "$TARGET"
echo "Установлен $TARGET"
