
# bm и aa

Две консольные утилиты для работы с приложениями прямо со стенда, без DevEco Studio.
Обе — клиенты системных служб: сами ничего не устанавливают и не запускают, а передают запрос
по IPC.

## bm (bundle manager)

`/system/bin/bm`, собирается из `foundation/bundlemanager/bundle_tool` (цель `frameworks:bm`).
Обращается к `BundleMgr` (SA 401), а тот для работы с файлами загружает `Installd` (SA 511).
Аналог `pm` в Android.

```sh
bm install -p /data/local/tmp/app.hap   # установить HAP (можно каталог с несколькими HAP)
bm dump -a                              # список установленных пакетов
bm dump -n com.example.app              # подробности о пакете: модули, ability, права
bm uninstall -n com.example.app         # удалить пакет
bm clean -n com.example.app -d          # очистить данные приложения (-c — кэш)
```

## aa (ability assistant)

`/system/bin/aa`, собирается из `foundation/ability/ability_runtime/tools/aa` (группа `tools_aa`,
вместе с `shell_command_executor_config.json`). Обращается к `AbilityManagerService` (SA 180).
Аналог `am` в Android.

```sh
aa start -b com.example.app -a EntryAbility   # запустить ability (-m <модуль>, если их несколько)
aa force-stop com.example.app                 # остановить приложение
aa dump -a                                    # состояние ability и задач
```



# Сборка
Сборка запускается командой `./make.sh tools_bm_aa` в контейнере.
