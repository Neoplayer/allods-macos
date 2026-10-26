# Аллоды Онлайн на macOS (Apple M4 Pro, macOS 26.5)

Состояние на 27.10.2026: **игра запускается и рисует картинку** (RU, VK Play, build 623).

## Установка на новом Маке (Apple Silicon)

1. Установить [CrossOver 26.3](https://www.codeweavers.com/crossover) в `/Applications`.
   Для другой версии CrossOver готовый `wine/bin/ntoskrnl.exe` может не подойти — см. шаг 6.
2. Скопировать эту папку на Мак и запустить:

   ```bash
   scripts/setup.sh
   ```

   Скрипт создаст бутылку `Allods` (win10_64), пропишет ей переменные окружения, скопирует
   движок CrossOver в `~/Games/cx`, поставит туда патченый `ntoskrnl.exe` и скачает установщик
   GameCenter (`https://static.gc.vkplay.ru/AllodsLoader.exe`).
3. Запустить установщик командой, которую напечатает скрипт. В GameCenter войти в VK Play
   (браузер откроет авторизацию; в Brave для `api.vkplay.ru` выключить Shields и разрешить
   Localhost access, Safari работает без настроек) и скачать Аллоды Онлайн (~17 ГБ).
4. Запустить `scripts/start-allods.sh`, нажать Play — игра создаст `Personal\global.cfg`.
   Закрыть игру.
5. Ещё раз `scripts/setup.sh` — он выключит MSAA в `global.cfg`. Дальше играть через
   `scripts/start-allods.sh`.
6. Только если версия CrossOver не 26.3: `brew install mingw-w64 bison`, затем
   `scripts/build-ntoskrnl.sh <версия>` (например `26.4.0`) — скачает исходники CrossOver,
   наложит `patches/ntoskrnl-impactdrv.patch`, соберёт и установит модуль.
   Если патч не накладывается, переносить правки вручную по `wine/ntoskrnl.exe/`.

Описание всех файлов папки — `wine/README.md`.

## Запуск

```bash
scripts/start-allods.sh
```

Скрипт останавливает wineserver бутылки, поднимает драйвер античита (`sc start impactdrv`) и
запускает GameCenter движком из `~/Games/cx`. Дальше в GameCenter: Аллоды Онлайн → Play.

Обычный запуск из CrossOver.app **не работает**: в нём штатный `ntoskrnl.exe`, античит упадёт.

## Что для этого нужно

| Компонент | Где |
|---|---|
| CrossOver 26.3 (триал) | `/Applications/CrossOver.app`, не изменён |
| Копия движка CrossOver с патченым `ntoskrnl.exe` | `~/Games/cx/CrossOver` |
| Исходники и сборка Wine (CrossOver 26.3) | `~/Games/src/sources/wine`, `~/Games/src/build` |
| Патч ntoskrnl | `patches/ntoskrnl-impactdrv.patch` |
| Бутылка `Allods` (win10_64) | `~/Library/Application Support/CrossOver/Bottles/Allods` |

Настройки бутылки (`cxbottle.conf`, секция `[EnvironmentVariables]`):

```
"CX_GRAPHICS_BACKEND" = "wined3d"
"LANG" = "ru_RU.UTF-8"
"LC_ALL" = "ru_RU.UTF-8"
```

- `wined3d`: D3DMetal не умеет D3D9, под DXVK (MoltenVK) часть шейдеров не компилируется — чёрный экран.
- Русская локаль даёт ANSI-кодировку 1251. Без неё игра создаёт каталоги ANSI-функциями,
  путь `C:\VK Play\Аллоды Онлайн\Personal` превращается в `?????? ??????`, и появляется
  «Couldn't create crash report directory».

Настройки игры (`C:\VK Play\Аллоды Онлайн\Personal\global.cfg`): `gfx_antialias=0`.
С MSAA wined3d не создаёт depth/stencil-поверхность (`D3DERR_NOTAVAILABLE`) — белый экран.
Оригинал конфига: `~/Games/src/global.cfg.orig`.

## Что исправлено в ntoskrnl (Wine)

Античит Astrum (`impactsvc` + драйвер ядра `impactdrv1.sys`) работает через эмуляцию ядра Wine
(`winedevice`). Чтобы он прошёл, в `dlls/ntoskrnl.exe` реализовано:

1. Функции памяти/MDL, бывшие заглушками: `MmProbeAndLockPages`, `MmUnlockPages`,
   `MmMapLockedPagesSpecifyCache`, `MmUnmapLockedPages`, `MmBuildMdlForNonPagedPool`;
   плюс `KeStallExecutionProcessor`, `KeGetProcessorNumberFromIndex`.
2. Хэндлы из процесса клиента в `ObReferenceObjectByHandle`: IRP выполняется в `winedevice`,
   а хэндл принадлежит `impactsvc` — хэндл дублируется из процесса клиента.
3. `KeGetCurrentThread` для потока запросов открывает клиентский поток с минимальными правами.
4. Текущий поток через `gs:[0x188]`: x64-драйверы читают `KPCR.Prcb.CurrentThread` инлайном,
   в Wine это `TEB.ReservedForDebuggerInstrumentation[15]` — теперь заполняется для каждого потока.
5. Безопасность клиента: `SeCreateClientSecurity`, `SeImpersonateClientEx`, `SeImpersonateClient`,
   `SeTokenType`, `PsRevertToSelf`, `PsDereferencePrimaryToken`, `PsDereferenceImpersonationToken`.

Сборка и установка после правок:

```bash
make -C ~/Games/src/build dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe
cp ~/Games/src/build/dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe ~/Games/cx/CrossOver/lib/wine/x86_64-windows/
```

## Риски

- Античит работает в нестандартном окружении; как на это отреагирует Astrum, неизвестно.
- После обновления клиента или античита патч может перестать хватать — смотреть
  `drive_c/users/crossover/AppData/Local/Temp/impactdiag.log` и `GameCenter/main.log` (cp1251).

## Логи

- `impactdiag.log`: строка `... 150029 <код>` — отказ запуска (были `5aa`, `6`, `57`, `5`).
  При успешном запуске её нет, но остаётся `100 ... 220601 c0000002` (STATUS_NOT_IMPLEMENTED
  в какой-то проверке античита) — возможная причина будущих вылетов.
- `bin_dx9\AOgame_d3d9.log` — лог DXVK, если включён.
- Трассы отладки: `~/Games/logs` (можно удалить, ~28 ГБ).
