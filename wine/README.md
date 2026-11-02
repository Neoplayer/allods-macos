# Изменения в Wine (CrossOver 26.3)

Меняются `dlls/ntoskrnl.exe`, `dlls/ntdll/unix/system.c` и `dlls/winemac.drv`. Исходники — исходники CrossOver 26.3
(`https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz`,
sha256 `ac99c8ca4b3848f3e81784135f023df266b61c2345726ea55a50b3e030dd6872`; локально `~/Games/src/cx.tar.gz`, распакованы в `~/Games/src/sources/wine`, ядро Wine 11.0).

| Файл | Что это |
|---|---|
| `ntoskrnl.exe/ntoskrnl.c`, `ntoskrnl.exe/ntoskrnl.exe.spec`, `ntoskrnl.exe/ntoskrnl_private.h` | изменённые исходники целиком |
| `ntoskrnl.exe/original/` | те же файлы до изменений |
| `../patches/ntoskrnl-impactdrv.patch` | разница в виде патча (`git apply` в корне исходников Wine) |
| `bin/ntoskrnl.exe` | собранный патченый модуль, который сейчас стоит в `~/Games/cx` |
| `bin/ntoskrnl.exe.orig` | оригинальный модуль из CrossOver 26.3 |
| `ntdll/system.c`, `ntdll/original/system.c` | изменённый и исходный `dlls/ntdll/unix/system.c` |
| `../patches/ntdll-firmware-tables.patch` | патч ntdll (ответ про ACPI-таблицы) |
| `../patches/ntdll-platform-role.patch` | патч ntdll поверх предыдущего (`NtPowerInformation(PlatformRole)`) |
| `bin/ntdll.so`, `bin/ntdll.so.orig` | собранная unix-часть ntdll (x86_64, macOS 10.15+, rpath `@loader_path/../../../lib64` добавлен `install_name_tool`) и оригинал |
| `winemac.drv/*.c`, `winemac.drv/*.h`, `winemac.drv/*.m`, `winemac.drv/original/` | изменённые и исходные файлы драйвера macOS |
| `../patches/winemac-focus.patch` | патч winemac (фокус окна игры, `WM_DISPLAYCHANGE` при активации) |
| `bin/winemac.so`, `bin/winemac.so.orig` | собранный драйвер macOS (x86_64, macOS 10.15+, с MoltenVK, тот же rpath) и оригинал |
| `configure-unix-command.txt` | configure для x86_64 unix-сборки (из `~/Games/src/build-x64`); Vulkan через MoltenVK из `~/Games/cx/CrossOver/lib64` нужен для winemac.so |
| `configure-command.txt` | команда configure (из каталога `~/Games/src/build`) |

## Восстановление с нуля

```bash
# копия движка CrossOver; модули меняются только в копии
mkdir -p ~/Games/cx
cp -R /Applications/CrossOver.app/Contents/SharedSupport/CrossOver ~/Games/cx/

# установить готовые модули
cp wine/bin/ntoskrnl.exe ~/Games/cx/CrossOver/lib/wine/x86_64-windows/ntoskrnl.exe
cp wine/bin/ntdll.so ~/Games/cx/CrossOver/lib/wine/x86_64-unix/ntdll.so
cp wine/bin/winemac.so ~/Games/cx/CrossOver/lib/wine/x86_64-unix/winemac.so
```

Пересборка из исходников:

```bash
REPO=$(pwd)   # корень клона allods-macos
cd ~/Games/src/sources/wine && git apply "$REPO"/patches/ntoskrnl-impactdrv.patch
mkdir -p ~/Games/src/build && cd ~/Games/src/build
$(cat "$REPO"/wine/configure-command.txt)
make dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe
cp dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe ~/Games/cx/CrossOver/lib/wine/x86_64-windows/
```

Нужен кросс-компилятор `x86_64-w64-mingw32-gcc` (Homebrew `mingw-w64`).

# Настройки (`config/`)

- `bottle/cxbottle.conf` — текущий конфиг бутылки (`CX_GRAPHICS_BACKEND`, `LANG`, `LC_ALL`);
  `cxbottle.conf.orig` — до изменений. Кладётся в `~/Library/Application Support/CrossOver/Bottles/Allods/`.
- `game/global.cfg` — настройки игры (`gfx_antialias=0`, 1920×1080 @60); `global.cfg.orig` —
  как игра создала сама. Кладётся в `C:\VK Play\Аллоды Онлайн\Personal\`.

# Скрипты (`scripts/`)

- `setup.sh` — подготовка Мака: бутылка, копия движка, ntoskrnl/ntdll/winemac, переменные,
  клавиши и фокус окна в реестре, настройки игры.
- `build-ntoskrnl.sh [версия]` — пересборка ntoskrnl.exe, ntdll.so и winemac.so из исходников CrossOver.
- `start-allods.sh` — запуск GameCenter с патченым движком.
- `run-wine-staging.sh` — обёртка Wine Staging 11.18 (пробный вариант, не используется).

# Лицензия

Файлы этой папки и `patches/` получены из Wine/CrossOver и распространяются под
LGPL-2.1-or-later, текст — [`COPYING.LIB`](COPYING.LIB).
