`/sys/kernel/hungtask/` — это интерфейс драйвера hungtask из ядра OpenHarmony (`drivers/staging/hungtask` в дереве OHOS). Это не то же самое, что обычный Linux-механизм `CONFIG_DETECT_HUNG_TASK` (поток `khungtaskd` и `/proc/sys/kernel/hung_task_*`), который ловит процессы, застрявшие в D-состоянии.

Драйвер OHOS следит за пользовательскими процессами. Системная служба записывается в `/sys/kernel/hungtask/userlist` и затем регулярно подаёт «пульс». Если пульс пропал, ядро считает процесс зависшим и пишет об этом, а при настройке может перезапустить службу или систему. С ядром эту функцию связывают XCollie (сторожевая библиотека `hiviewdfx` внутри служб) и init (`chown/chmod` на `userlist` в `cfg`).

Для сборки, в конфигурации ядра должен быть указаны следующие параметры: 
```
CONFIG_STAGING=y
CONFIG_DEBUG_KERNEL=y
CONFIG_DETECT_HUNG_TASK=y
CONFIG_DFX_HUNGTASK=y
CONFIG_DFX_HUNGTASK_USER=y
```

Сопутствующие опции, которые лучше оставить по умолчанию (в defconfig их можно не писать):
```
# CONFIG_BOOTPARAM_HUNG_TASK_PANIC is not set   # не паниковать при зависшей D-задаче
CONFIG_DEFAULT_HUNG_TASK_TIMEOUT=120            # порог khungtaskd, секунды
```
