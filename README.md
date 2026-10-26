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
6. Уведомления о процессах: `PsSetCreateProcessNotifyRoutine(Ex)`. У Wine нет перехвата создания
   процессов в ядре, поэтому поток `wine_process_monitor` в `winedevice` раз в 50 мс сверяет список
   процессов и сообщает драйверу о новых и завершённых с настоящими данными (родитель, путь
   образа, командная строка). Уведомление приходит с опозданием до ~50 мс и не может запретить запуск.
7. Информация о процессах: `PsGetProcessImageFileName`, `PsGetProcessCreateTimeQuadPart`,
   `PsGetProcessSectionBaseAddress`, `PsReferenceProcessFilePointer`, `MmCopyVirtualMemory`.

## Что исправлено в ntdll (Wine)

`dlls/ntdll/unix/system.c`: на запрос таблиц прошивки ACPI/FIRM
(`NtQuerySystemInformation(SystemFirmwareTableInformation)`) Wine отвечал «не реализовано».
Теперь он отвечает правду: у Apple Silicon ACPI-таблиц нет — пустой список, а на запрос конкретной
таблицы «не найдена», как Windows для отсутствующей таблицы. Таблицы не подделываются.

## Что видит античит о машине

Ничего не скрывается и не подделывается:
- SMBIOS (Wine берёт из IOKit macOS): производитель `Apple Inc.`, модель Мака, **настоящий
  серийный номер и UUID платформы**;
- ACPI: таблиц нет;
- `ntdll` экспортирует `wine_get_version`/`wine_get_host_version` — программа видит, что это Wine
  на Darwin.

Сборка и установка после правок:

```bash
make -C ~/Games/src/build dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe
cp ~/Games/src/build/dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe ~/Games/cx/CrossOver/lib/wine/x86_64-windows/
# ntdll.so — отдельная x86_64-сборка (CrossOver работает под Rosetta), см. wine/configure-unix-command.txt
MACOSX_DEPLOYMENT_TARGET=10.15 make -C ~/Games/src/build-x64 dlls/ntdll/ntdll.so
cp ~/Games/src/build-x64/dlls/ntdll/ntdll.so ~/Games/cx/CrossOver/lib/wine/x86_64-unix/
```

Или всё сразу: `scripts/build-ntoskrnl.sh`.

## Риски

- Античит работает в нестандартном окружении; как на это отреагирует Astrum, неизвестно.
- После обновления клиента или античита патч может перестать хватать — смотреть
  `drive_c/users/crossover/AppData/Local/Temp/impactdiag.log` и `GameCenter/main.log` (cp1251).

## Логи

- `impactdiag.log`: строка `... 150029 <код>` — отказ запуска (были `5aa`, `6`, `57`, `5`).
  При успешном запуске её нет, но остаётся `100 ... 220601 c0000002`. Это не ACPI (после
  честного ответа про ACPI код остался) и не функции ядра: запись появляется до загрузки
  `acclient64.dll`, и рядом нет ни одного сообщения Wine о нереализованной функции. Источник
  не найден.

## Известные проблемы

- **Игра падает при Alt+Tab** (проверено: без Alt+Tab работает, после — падение):
  `ACCESS_VIOLATION` (чтение NULL) в `AOgame.exe` по адресу `0x140B8CAC4`. Иногда перед этим
  `wined3d_swapchain_resize_buffers: Something's still holding back buffer 0`. Не помогли:
  обычное окно вместо окна без рамки (`gfxBorderless=0`), виртуальный рабочий стол Wine.
  Код игры зашифрован, причина не установлена. Пока не нажимать Alt+Tab в игре. wined3d рисует через OpenGL macOS, которому не хватает части расширений
  (`GL_ARB_uniform_buffer_object`, `GL_EXT_texture_array`), и представляется GeForce 8800 GTX.
  Crash-отчёты игры: `C:\VK Play\Аллоды Онлайн\Personal\CrashReports\`.
- `bin_dx9\AOgame_d3d9.log` — лог DXVK, если включён.
- Трассы отладки не хранятся: писать их во временную папку (например `~/Games/trace`) и удалять после разбора.
