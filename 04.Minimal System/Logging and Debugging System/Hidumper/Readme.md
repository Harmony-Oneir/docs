Это штатный диагностический инструмент OpenHarmony, аналог dumpsys в Android. `hidumper -ls` выводит список зарегистрированных SA, `hidumper -s <id>` — дамп конкретной службы (например, `-s 10` для `render_service`), есть ещё `--mem`, `--cpuusage` и т. п. Работает он через собственную SA `hidumper_service`, поэтому в образе нужны и бинарник, и профиль службы.

# Сборка
Для сборки используйте команду `./make.sh hidumper` в контейнере. 

SA профиль: [hidumper_service.json](https://github.com/Harmony-Oneir/oneir/blob/main/profile/hidumper_service.json). После запуска системы, Init загружает файл `hidumper_service.cfg`.


# Использование
## Системные службы (SA)
Самое полезное для отладки: каждая SA реализует Dump(), и hidumper вызывает его через samgr.
```bash
H "hidumper -ls"                    # список зарегистрированных SA (имена и ID)
H "hidumper -s 10"                  # дамп одной SA по ID (10 — render_service)
H "hidumper -s 10 -a '-h'"          # справка самой SA: какие аргументы она понимает
H "hidumper -s 10 -a 'screen'"      # дамп с аргументом (набор аргументов — из -h)
H "hidumper -s 10 1212"             # несколько SA сразу
H "hidumper -s"                     # все SA подряд (долго и много)
```

## Процессы и потоки
```bash
H "hidumper -p"                          # все процессы и потоки
H "hidumper -p \$(pidof render_service)"  # потоки, smaps, mountinfo, время выполнения
H "hidumper -p \$(pidof render_service) --fd"       # открытые дескрипторы
H "hidumper -p \$(pidof render_service) --thread -v"
```
`--fd` удобен, чтобы проверить, какие устройства держит процесс (например, `/dev/dri/card0` у `composer_host`).

## Память

```
H "hidumper --mem"                       # сводка по всей системе
H "hidumper --mem --prune"               # упрощённая сводка
H "hidumper --mem \$(pidof render_service)"                # память процесса
H "hidumper --mem \$(pidof render_service) --show-dmabuf"  # + dmabuf (буферы графики)
H "hidumper --mem-smaps \$(pidof render_service) -v"       # разбор /proc/pid/smaps
H "hidumper --mem \$(pidof render_service) -t 1"           # запись изменений, Ctrl+C; итог в /data/log/hidumper/record_mem.txt
```
`--show-dmabuf` — главное для графики: видно, сколько буферов держат RS и композитор и не текут ли они. Графы GPU-памяти берутся через HDI memorytracker; если на стенде нет его реализации, эти столбцы будут пустыми или нулевыми, это нормально.

## CPU
```bash
hidumper --cpuusage                  # загрузка по процессам и категориям
hidumper --cpuusage \$(pidof render_service)
hidumper --cpufreq                   # реальная частота каждого ядра
```

## IPC (binder)

```bash
hidumper --ipc \$(pidof render_service) --start-stat
# ... прогнать тест, например /data/local/tmp/rs_probe hwc
hidumper --ipc \$(pidof render_service) --stat
hidumper --ipc \$(pidof render_service) --stop-stat
```
Показывает, какие интерфейсы и коды вызываются и сколько. Пригодно, чтобы подтвердить, что oneway-команды клиента RS действительно доходят (история с `callingPid = 0`). Вместо PID можно `-a` — все процессы.

## Сеть и хранилище
```bash
hidumper --net                       # сводка по сети
hidumper --net \$(pidof hdcd)         # трафик процесса
hidumper --storage                   # сводка по хранилищу
hidumper --storage \$(pidof render_service)  # /proc/pid/io
```
Часть сведений `--net` зависит от `netmanager`; если его SA нет, вывод будет неполным.

## Кластеры системной информации
```bash
hidumper -lc                         # список кластеров
hidumper -c base                     # конкретный кластер
hidumper -c                          # все
```

Описание кластеров — в `/system/etc/hidumper/infos_config.json`.

## Журнал падений
```bash
H "hidumper -e --list"
H "hidumper -e --print render_service -n 3"
```
Берёт данные у hiview/faultloggerd.

## Сохранение и сжатие
```bash
H "hidumper -s 10 --zip"                 # результат архивом в /data/log/hidumper
```
Каталог /data/log/hidumper создаёт hidumper_service.cfg при старте службы (владелец hidumper_service:shell).
