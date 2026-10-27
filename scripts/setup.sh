#!/bin/zsh
# Prepares a Mac to run Allods Online: bottle, patched CrossOver engine copy, bottle settings,
# game settings. Safe to run again at any stage; run it once more after the game is installed.
set -e

REPO="${0:A:h:h}"
CX_APP=/Applications/CrossOver.app
CX_SRC="$CX_APP/Contents/SharedSupport/CrossOver"
CX_COPY="$HOME/Games/cx/CrossOver"
BOTTLE=Allods
PREFIX="$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE"
INSTALLER="$HOME/Games/installers/AllodsLoader.exe"
INSTALLER_URL=https://static.gc.vkplay.ru/AllodsLoader.exe
EXPECTED_CX=26.3
GAME_CFG="$PREFIX/drive_c/VK Play/Аллоды Онлайн/Personal/global.cfg"

if [[ ! -d $CX_APP ]]; then
    echo "CrossOver не найден в $CX_APP. Установите CrossOver $EXPECTED_CX и запустите скрипт снова." >&2
    exit 1
fi

cx_version=$(defaults read "$CX_APP/Contents/Info.plist" CFBundleShortVersionString)
if [[ $cx_version != $EXPECTED_CX ]]; then
    echo "CrossOver $cx_version, а готовые ntoskrnl.exe, ntdll.so и winemac.so собраны для $EXPECTED_CX." >&2
    echo "Пересоберите их: scripts/build-ntoskrnl.sh <версия> (исходники нужной версии CrossOver)." >&2
fi

echo "== Бутылка $BOTTLE"
if [[ ! -d $PREFIX ]]; then
    "$CX_SRC/bin/cxbottle" --bottle "$BOTTLE" --create --template win10_64
fi

echo "== Переменные окружения бутылки"
python3 - "$PREFIX/cxbottle.conf" <<'EOF'
import re, sys

path = sys.argv[1]
wanted = {"CX_GRAPHICS_BACKEND": "dxmt", "WINEMSYNC": "1", "LANG": "ru_RU.UTF-8", "LC_ALL": "ru_RU.UTF-8"}

text = open(path, encoding="utf-8").read()
head, sep, tail = text.partition("[EnvironmentVariables]\n")
if not sep:
    head, sep, tail = text.rstrip("\n") + "\n\n", "[EnvironmentVariables]\n", ""

# drop old values of our keys inside the section, then add the wanted ones first
section_end = re.search(r"^\[", tail, re.M)
section, rest = (tail[:section_end.start()], tail[section_end.start():]) if section_end else (tail, "")
lines = [l for l in section.splitlines(True)
         if not any(re.match(r'\s*"%s"\s*=' % k, l) for k in wanted)]
new = "".join('"%s" = "%s"\n' % kv for kv in wanted.items())
open(path, "w", encoding="utf-8").write(head + sep + new + "".join(lines) + rest)
EOF

echo "== Копия движка CrossOver в $CX_COPY"
if [[ ! -d $CX_COPY ]]; then
    mkdir -p "${CX_COPY:h}"
    cp -R "$CX_SRC" "${CX_COPY:h}/"
fi
target="$CX_COPY/lib/wine/x86_64-windows/ntoskrnl.exe"
cp "$REPO/wine/bin/ntoskrnl.exe" "$target"
echo "ntoskrnl.exe установлен ($(md5 -q "$target"))"
target="$CX_COPY/lib/wine/x86_64-unix/ntdll.so"
cp "$REPO/wine/bin/ntdll.so" "$target"
echo "ntdll.so установлен ($(md5 -q "$target"))"
target="$CX_COPY/lib/wine/x86_64-unix/winemac.so"
cp "$REPO/wine/bin/winemac.so" "$target"
echo "winemac.so установлен ($(md5 -q "$target"))"

echo "== Фокус окна игры"
# The game crashes in the world when it becomes active again after another Mac app was in
# front; with this it keeps the Windows foreground while macOS switches apps.
reg_game() {
    WINEPREFIX="$PREFIX" "$CX_COPY/bin/wine" --bottle "$BOTTLE" \
        reg add 'HKCU\Software\Wine\AppDefaults\AOgame.exe\Mac Driver' /v $1 /t REG_SZ /d $2 /f >/dev/null 2>&1
}
reg_game KeepForegroundOnDeactivate y
reg_game SyncDisplaysOnActivate n

echo "== Клавиши: Cmd как Ctrl, Option как Alt"
# By default Cmd is Alt; after Cmd+Tab the game never sees Alt released and crashes in the world.
for key in LeftCommandIsCtrl RightCommandIsCtrl LeftOptionIsAlt RightOptionIsAlt; do
    WINEPREFIX="$PREFIX" "$CX_COPY/bin/wine" --bottle "$BOTTLE" \
        reg add 'HKCU\Software\Wine\Mac Driver' /v $key /t REG_SZ /d y /f >/dev/null 2>&1
done

echo "== Установщик VK Play GameCenter"
if [[ ! -f $PREFIX/drive_c/users/crossover/AppData/Local/GameCenter/GameCenter.exe ]]; then
    if [[ ! -f $INSTALLER ]]; then
        mkdir -p "${INSTALLER:h}"
        curl -L --fail -o "$INSTALLER" "$INSTALLER_URL"
    fi
    echo "GameCenter ещё не установлен. Запустите установщик, войдите в VK Play и скачайте игру:"
    echo "  \"$CX_COPY/bin/wine\" --bottle $BOTTLE \"$INSTALLER\""
fi

echo "== Настройки игры"
if [[ -f $GAME_CFG ]]; then
    sed -i '' -e 's/^gfx_antialias=.*/gfx_antialias=0/' "$GAME_CFG"
    grep -a '^gfx_antialias=' "$GAME_CFG"
else
    echo "global.cfg появится после первого запуска игры; затем запустите setup.sh ещё раз"
    echo "(или скопируйте config/game/global.cfg в Personal\\ вручную)."
fi

echo "Готово. Запуск: $REPO/scripts/start-allods.sh"
