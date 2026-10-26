#!/bin/zsh
# Rebuilds the patched ntoskrnl.exe and ntdll.so from CodeWeavers' CrossOver sources and installs
# them into the engine copy in ~/Games/cx. Needs: brew install mingw-w64 bison
set -e

REPO="${0:A:h:h}"
CX_VERSION="${1:-26.3.0}"
SRC="$HOME/Games/src"
URL="https://media.codeweavers.com/pub/crossover/source/crossover-sources-$CX_VERSION.tar.gz"
LIB="$HOME/Games/cx/CrossOver/lib/wine"

mkdir -p "$SRC"
cd "$SRC"
[[ -f cx.tar.gz ]] || curl -L --fail -o cx.tar.gz "$URL"

if [[ ! -d sources/wine ]]; then
    tar xzf cx.tar.gz 'sources/wine/*'
    patch -d sources/wine -p1 < "$REPO/patches/ntoskrnl-impactdrv.patch"
    patch -d sources/wine -p1 < "$REPO/patches/ntdll-firmware-tables.patch"
fi

# Windows side (PE modules) and build tools, native arch
mkdir -p build
cd build
[[ -f Makefile ]] || PATH="/opt/homebrew/opt/bison/bin:$PATH" zsh -c "$(cat "$REPO/wine/configure-command.txt")"
PATH="/opt/homebrew/opt/bison/bin:$PATH" make -j"$(sysctl -n hw.ncpu)" dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe
cp dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe "$LIB/x86_64-windows/ntoskrnl.exe"
echo "Установлен $LIB/x86_64-windows/ntoskrnl.exe"

# Unix side: CrossOver runs x86_64 under Rosetta, built for macOS 10.15
mkdir -p ../build-x64
cd ../build-x64
[[ -f Makefile ]] || zsh -c "$(cat "$REPO/wine/configure-unix-command.txt")"
MACOSX_DEPLOYMENT_TARGET=10.15 PATH="/opt/homebrew/opt/bison/bin:$PATH" make -j"$(sysctl -n hw.ncpu)" dlls/ntdll/ntdll.so
cp dlls/ntdll/ntdll.so "$LIB/x86_64-unix/ntdll.so"
echo "Установлен $LIB/x86_64-unix/ntdll.so"
