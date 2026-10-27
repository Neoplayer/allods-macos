# Аллоды Онлайн на macOS (Apple M4 Pro, macOS 26.5)

Состояние на 27.10.2026: игра запускается из VK Play GameCenter, вход в мир и игра работают,
переключение приложений (Cmd+Tab, свайп) не роняет игру. Клиент RU, build 623, DirectX 11 через
DXMT, 55–70 FPS на главной площади.

## Установка на новом Маке (Apple Silicon)

1. Установить [CrossOver 26.3](https://www.codeweavers.com/crossover) в `/Applications`.
   Готовые модули в `wine/bin/` собраны под 26.3; для другой версии — шаг 6.
2. Скопировать эту папку на Мак и запустить:

   ```bash
   scripts/setup.sh
   ```

   Скрипт создаёт бутылку `Allods` (win10_64), прописывает ей переменные окружения, копирует
   движок CrossOver в `~/Games/cx`, ставит туда `ntoskrnl.exe`, `ntdll.so` и `winemac.so` из
   `wine/bin/`, прописывает в реестр бутылки раскладку клавиш и настройки фокуса окна игры,
   скачивает установщик GameCenter (`https://static.gc.vkplay.ru/AllodsLoader.exe`).
3. Запустить установщик командой, которую напечатает скрипт. В GameCenter войти в VK Play
   (браузер откроет авторизацию; в Brave для `api.vkplay.ru` выключить Shields и разрешить
   Localhost access, Safari работает без настроек) и скачать Аллоды Онлайн (~17 ГБ).
4. Запустить `scripts/start-allods.sh`, нажать Play — игра создаст `Personal\global.cfg`.
   Закрыть игру.
5. Ещё раз `scripts/setup.sh` — он выключит MSAA в `global.cfg`. Дальше играть через
   `scripts/start-allods.sh`.
6. Только если версия CrossOver не 26.3: `brew install mingw-w64 bison`, затем
   `scripts/build-ntoskrnl.sh <версия>` (например `26.4.0`). Скрипт скачивает исходники CrossOver,
   накладывает патчи из `patches/`, собирает и устанавливает модули. Если патч не накладывается,
   переносить правки вручную по `wine/ntoskrnl.exe/`, `wine/ntdll/`, `wine/winemac.drv/`.

Описание всех файлов папки — `wine/README.md`.

## Запуск

```bash
scripts/start-allods.sh
```

Скрипт останавливает wineserver бутылки, поднимает драйвер античита (`sc start impactdrv`) и
запускает GameCenter движком из `~/Games/cx`. Дальше в GameCenter: Аллоды Онлайн → Play.
В настройках игры в GameCenter должна стоять галка «Использовать DirectX 11».

Запуск из CrossOver.app не работает: там штатный `ntoskrnl.exe`, драйвер античита падает.

## Компоненты

| Компонент | Где |
|---|---|
| CrossOver 26.3 (триал) | `/Applications/CrossOver.app`, источник копии движка |
| Копия движка CrossOver с патчеными модулями | `~/Games/cx/CrossOver` |
| Исходники и сборка Wine (CrossOver 26.3) | `~/Games/src/sources/wine`, `~/Games/src/build`, `~/Games/src/build-x64` |
| Патчи | `patches/ntoskrnl-impactdrv.patch`, `patches/ntdll-firmware-tables.patch`, `patches/ntdll-platform-role.patch`, `patches/winemac-focus.patch` |
| Бутылка `Allods` (win10_64) | `~/Library/Application Support/CrossOver/Bottles/Allods` |

## Настройки

Бутылка (`cxbottle.conf`, секция `[EnvironmentVariables]`):

```
"CX_GRAPHICS_BACKEND" = "dxmt"
"WINEMSYNC" = "1"
"MTL_HUD_ENABLED" = "1"
"LANG" = "ru_RU.UTF-8"
"LC_ALL" = "ru_RU.UTF-8"
```

- В установке два клиента: `bin_dx9\AOgame.exe` (D3D9) и `bin\AOgame.exe` (D3D11). GameCenter
  запускает D3D11-клиент, если в настройках игры стоит «Использовать DirectX 11»
  (`ALTEXEFILENAME64BIT=bin\AOgame.exe` в `configBigGames.xml`).
- `dxmt`: D3D11 → Metal. Замер 27.10 на главной площади, окно без рамки, прежний `global.cfg`:

  | Режим | FPS | Мерцание |
  |---|---|---|
  | D3D11, `dxmt` | 55–70 | нет |
  | D3D11, `d3dmetal` | 51–66 | нет |
  | D3D11, `dxvk` (MoltenVK) | 56–84 | мелкое мерцание персонажа и неба, `dxvk.conf` с `invariantPosition` и `enableRtOutputNanFixup` не помогает |
  | D3D9, `wined3d` (OpenGL) | 30–43 | нет |

  Видеокарта тратит на кадр около 2 мс; упор в CPU: `AOgame.exe` под Rosetta занимает 2–2,5 ядра.
  DXMT держит 4 ГБ видеопамяти, D3DMetal — 0,8 ГБ. D3DMetal не поддерживает D3D9; под DXVK
  D3D9-клиент даёт чёрный экран, поэтому для D3D9 нужен `wined3d`.
- `WINEMSYNC=1`: синхронизация через mach-порты вместо wineserver, меньше нагрузка на CPU.
  `sc start impactdrv` с ним — RUNNING.
- `MTL_HUD_ENABLED=1`: счётчик кадров Metal поверх окна (FPS, время кадра GPU, `Game Mode`);
  `setup.sh` его не ставит, убрать, когда не нужен.
- Полноэкранный режим игры ничего не даёт: окно так же композитится, Game Mode macOS не
  включается, а после Cmd+Tab игра падает (см. «winemac.drv»). Нужен режим «Окно без рамки».
- Русская локаль даёт ANSI-кодировку 1251. Без неё игра создаёт каталоги ANSI-функциями,
  путь `C:\VK Play\Аллоды Онлайн\Personal` превращается в `?????? ??????`, и появляется
  «Couldn't create crash report directory».

Клавиатура (реестр бутылки, `HKCU\Software\Wine\Mac Driver`): `LeftCommandIsCtrl`,
`RightCommandIsCtrl`, `LeftOptionIsAlt`, `RightOptionIsAlt` = `y` — Cmd работает как Ctrl,
Option как Alt. По умолчанию CrossOver передаёт Cmd как Alt, и после Cmd+Tab игра не получает
отпускание Alt (ошибка Wine 48512).

Фокус окна игры (реестр бутылки, `HKCU\Software\Wine\AppDefaults\AOgame.exe\Mac Driver`):
`KeepForegroundOnDeactivate=y`, `SyncDisplaysOnActivate=n` — см. «winemac.drv».

Игра (`C:\VK Play\Аллоды Онлайн\Personal\global.cfg`): `gfx_antialias=0`.
С MSAA wined3d не создаёт depth/stencil-поверхность (`D3DERR_NOTAVAILABLE`) — белый экран.
Оригинал конфига: `~/Games/src/global.cfg.orig`.

## ntoskrnl.exe

Античит Astrum (`impactsvc` + драйвер ядра `impactdrv1.sys`) работает через эмуляцию ядра Wine
(`winedevice`). Для него в `dlls/ntoskrnl.exe` реализовано:

1. Функции памяти/MDL, бывшие заглушками: `MmProbeAndLockPages`, `MmUnlockPages`,
   `MmMapLockedPagesSpecifyCache`, `MmUnmapLockedPages`, `MmBuildMdlForNonPagedPool`;
   плюс `KeStallExecutionProcessor`, `KeGetProcessorNumberFromIndex`.
2. Хэндлы из процесса клиента в `ObReferenceObjectByHandle`: IRP выполняется в `winedevice`,
   а хэндл принадлежит `impactsvc` — хэндл дублируется из процесса клиента.
3. `KeGetCurrentThread` для потока запросов открывает клиентский поток с минимальными правами.
4. Текущий поток через `gs:[0x188]`: x64-драйверы читают `KPCR.Prcb.CurrentThread` инлайном,
   в Wine это `TEB.ReservedForDebuggerInstrumentation[15]` — заполняется для каждого потока.
5. Безопасность клиента: `SeCreateClientSecurity`, `SeImpersonateClientEx`, `SeImpersonateClient`,
   `SeTokenType`, `PsRevertToSelf`, `PsDereferencePrimaryToken`, `PsDereferenceImpersonationToken`.
6. Уведомления о процессах: `PsSetCreateProcessNotifyRoutine(Ex)`. В Wine нет перехвата создания
   процессов в ядре, поэтому поток `wine_process_monitor` в `winedevice` раз в 50 мс сверяет список
   процессов и сообщает драйверу о новых и завершённых (родитель, путь образа, командная строка).
   Уведомление приходит с опозданием до ~50 мс и не может запретить запуск.
7. Информация о процессах: `PsGetProcessImageFileName`, `PsGetProcessCreateTimeQuadPart`,
   `PsGetProcessSectionBaseAddress`, `PsReferenceProcessFilePointer`, `MmCopyVirtualMemory`.

## ntdll

`dlls/ntdll/unix/system.c`, два патча:

- `patches/ntdll-firmware-tables.patch`: на запрос таблиц прошивки ACPI/FIRM
  (`NtQuerySystemInformation(SystemFirmwareTableInformation)`) Wine отвечал `STATUS_NOT_IMPLEMENTED`.
  Теперь перечисление возвращает пустой список, запрос конкретной таблицы — `STATUS_NOT_FOUND`,
  как Windows для отсутствующей таблицы: у Apple Silicon ACPI-таблиц нет.
- `patches/ntdll-platform-role.patch`: `NtPowerInformation(PlatformRole)` (уровень 75, в заголовках
  Wine его нет) возвращает `PlatformRoleMobile`: машина — ноутбук. Раньше уровень уходил в
  `default` с `STATUS_NOT_IMPLEMENTED` и сообщением только в канале WARN. Этот запрос делает
  `acclient64.dll` напрямую после инициализации и пишет отказ в `impactdiag.log` строкой
  `100 ... 220601 c0000002`. Найдено трассой `+syscall` (27.10): других системных вызовов
  с `c0000002` в процессе игры нет.

## winemac.drv

Игра падала в мире (не в меню), когда снова становилась активной после Cmd+Tab или свайпа:
`ACCESS_VIOLATION` (чтение NULL) в `AOgame.exe` по адресу `0x140B8CAC4`, в первом кадре после
`WM_ACTIVATEAPP`, до ввода. Код игры зашифрован, причина внутри игры не установлена.

`patches/winemac-focus.patch` добавляет драйверу macOS две настройки, обе включены только для
`AOgame.exe`:
- `KeepForegroundOnDeactivate=y` — пока впереди другое приложение macOS, окно игры остаётся
  активным для Windows: игра не получает потерю и возврат фокуса. Курсор при переключении
  освобождается. Игра продолжает рисовать в фоне.
- `SyncDisplaysOnActivate=n` — не посылать `WM_DISPLAYCHANGE` при каждой активации приложения.

Проверено 27.10: в мире несколько Cmd+Tab и свайпов — падений нет. В полноэкранном режиме игры
патч не помогает: D3D11-клиент упал после Cmd+Tab (`0x140b8dce4` в `bin\AOgame.exe`).

Без этого патча не помогали: окно с рамкой (`gfxBorderless=0`), виртуальный рабочий стол Wine,
Cmd как Ctrl.

## Данные о машине, доступные игре и античиту

- SMBIOS (Wine берёт из IOKit macOS): производитель `Apple Inc.`, модель Мака, серийный номер и
  UUID платформы;
- ACPI: таблиц нет;
- роль платформы (`PlatformRole`): мобильная;
- `ntdll` экспортирует `wine_get_version`/`wine_get_host_version`: Wine на Darwin.

## Сборка и установка после правок

```bash
make -C ~/Games/src/build dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe
cp ~/Games/src/build/dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe ~/Games/cx/CrossOver/lib/wine/x86_64-windows/
# unix-часть — отдельная x86_64-сборка (CrossOver работает под Rosetta), см. wine/configure-unix-command.txt
MACOSX_DEPLOYMENT_TARGET=10.15 make -C ~/Games/src/build-x64 dlls/ntdll/ntdll.so
cp ~/Games/src/build-x64/dlls/ntdll/ntdll.so ~/Games/cx/CrossOver/lib/wine/x86_64-unix/
MACOSX_DEPLOYMENT_TARGET=10.15 make -C ~/Games/src/build-x64 dlls/winemac.drv/winemac.so
cp ~/Games/src/build-x64/dlls/winemac.drv/winemac.so ~/Games/cx/CrossOver/lib/wine/x86_64-unix/
```

После сборки unix-модулям нужен второй путь поиска библиотек, как у модулей CrossOver:

```bash
install_name_tool -add_rpath @loader_path/../../../lib64 ~/Games/cx/CrossOver/lib/wine/x86_64-unix/ntdll.so
install_name_tool -add_rpath @loader_path/../../../lib64 ~/Games/cx/CrossOver/lib/wine/x86_64-unix/winemac.so
```

Без него `ntdll` не загружает `cxcompatdb.so` (ему нужна `libgnutls.30.dylib` из `lib64`), и
CrossOver молча игнорирует `CX_GRAPHICS_BACKEND`: D3D11 рисует встроенный wined3d. Признак —
в HUD Metal написано `Metal` вместо `D3D11` у D3DMetal, а в `--cx-log` с `+module` строка
`error loading cxcompatdb.so`. На wined3d D3D11-клиент мерцает.

Или всё сразу: `scripts/build-ntoskrnl.sh`.

## Логи

- `drive_c/users/crossover/AppData/Local/Temp/impactdiag.log` — диагностика античита.
  Строка `... 150029 <код>` — отказ запуска (были `5aa`, `6`, `57`, `5`, все до исправлений
  ntoskrnl). Строка `100 ...` пишет `acclient64.dll` внутри `AOgame.exe`; `100 ... 220601 c0000002`
  была отказом `NtPowerInformation(PlatformRole)`, см. «ntdll».
- Если в `impactdiag.log` код `c0000002` или другой отказ без сообщений Wine: запустить с
  `--debugmsg +syscall` (лог в `.gz`, только на время запуска) и искать в процессе игры
  `SysRet ... retval=<код>`. Обычная трасса не поможет: без `--cx-log` обёртка CrossOver ставит
  `-all`, а часть заглушек Wine пишет в WARN, а не в FIXME.
- `drive_c/users/crossover/AppData/Local/GameCenter/main.log` (cp1251) — запуск игры, античит,
  `MacarController` (сессия GameCenter с сервером, раз в 20 с echo, раз в 80 с handshake).
- `C:\VK Play\Аллоды Онлайн\Personal\CrashReports\` — crash-отчёты игры (минидамп + xml).
- `bin_dx9\AOgame_d3d9.log` — лог DXVK, если включён.
- После обновления клиента или античита смотреть сначала `impactdiag.log` и `main.log`.

## Ограничения

- wined3d рисует через OpenGL macOS без части расширений (`GL_ARB_uniform_buffer_object`,
  `GL_EXT_texture_array`) и представляется GeForce 8800 GTX; в лог Wine идут предупреждения
  о шейдерах.
- Трассы отладки не хранить в репозитории: писать во временную папку (например `~/Games/trace`)
  через `wine --debugmsg <каналы> --cx-log <файл>` и удалять после разбора.
