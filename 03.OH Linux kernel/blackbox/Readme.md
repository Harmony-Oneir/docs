## blackbox, hievent и `/dev/bbox`

**Кратко:** `/dev/bbox` создаёт драйвер **hievent**, а не blackbox — имя узла
историческое. Обе подсистемы — дополнения OpenHarmony к ядру (`drivers/staging/`),
в mainline Linux их нет.

> Для LiteOS (mini/small) есть отдельная библиотека `base/hiviewdfx/blackbox`
> с той же схемой (`BBoxNotifyError`, `SystemModule*`) — к Linux-ядру отношения не имеет.

| Параметр | blackbox | hievent |
|---|---|---|
| Задача | Сохранить следы аварии | Передать события в hiview |
| Когда работает | При панике и перезагрузке | Постоянно |
| Переживает перезагрузку | Да (через pstore) | Нет |
| Узел в `/dev` | Нет | `/dev/bbox` |
| Опция | `CONFIG_BLACKBOX` | `CONFIG_HIEVENT` |
| Кто потребляет | Сам пишет лог в `CONFIG_BLACKBOX_LOG_ROOT_PATH` | hiview |

### blackbox (`drivers/staging/blackbox`)

«Бортовой самописец» для тяжёлых сбоев: паника ядра, сбойная перезагрузка.

**Ядро blackbox — только реестр модулей**, своего триггера у него нет
(`blackbox_core.c`: статический `ops_list`, `bbox_register_module_ops`, `core_initcall`).
Без зарегистрированного модуля событие заканчивается строкой
`[...] hasn't been registered!`. Строка `bbox:` в начале dmesg — только инициализация реестра.

Рабочая цепочка:

1. паника → **системный адаптер платформы** (panic_notifier) записывает лог через
   pstore (`CONFIG_PSTORE_BLACKBOX` + бэкенд `pstore_ram`, он же ramoops);
2. перезагрузка → адаптер находит запись (на 6.6 — по флагу `g_blackbox_flag`
   из `blackbox_storage.c`);
3. после монтирования `CONFIG_BLACKBOX_LOG_PART_REPRESENTATIVE` blackbox пишет лог
   в `CONFIG_BLACKBOX_LOG_ROOT_PATH`.

Варианты хранения (`BLACKBOX_STORAGE_BY_*`) на x86-ноутбуке:

| Вариант | На стенде |
|---|---|
| `MEMORY` | Ненадёжно: нужна тёплая перезагрузка без стирания ОЗУ |
| `PSTORE_BLK` | Нет: у NVMe нет `panic_write` |
| `PSTORE_RAM` | **Выбран.** Нужен резерв ОЗУ под ramoops в cmdline |
| `RAW_PARTITION` | Не проверялся |

**Адаптер Rockchip** (`blackbox/rockchip`) в `kernel_linux_6.6` нет — он приходит из
`kernel/linux/patches/linux-6.6/rk3568_patch/kernel.patch` и собирается только при
`ARCH_ROCKCHIP`. На стенде этот патч наложен прямо на рабочее дерево.
Код адаптера платформенно-независим, кроме сброса кэша (только ARM).

**x86-адаптер** — патч `oneir_patches/linux_kernel/0008-blackbox-add-x86-system-adapter.patch`:
`drivers/staging/blackbox/x86/` (копия `rockchip/system_adapter.c`, сброс кэша через
`clflush_cache_range()`), опция `CONFIG_BLACKBOX_X86`. Хуки в начале `blackbox/Kconfig`
и `Makefile`, поэтому патч накладывается и на чистое ядро, и поверх `rk3568_patch`
(проверено `git apply --check`).

Опции в defconfig:

```
CONFIG_PSTORE=y
CONFIG_PSTORE_RAM=y
CONFIG_PSTORE_BLACKBOX=y
CONFIG_BLACKBOX_STORAGE_BY_PSTORE_RAM=y
CONFIG_DEF_BLACKBOX_STORAGE_BY_PSTORE_RAM=y
CONFIG_BLACKBOX_X86=y
CONFIG_BLACKBOX_LOG_ROOT_PATH="/data/log/bbox"
CONFIG_BLACKBOX_LOG_PART_REPRESENTATIVE="/data"
```

Не включать вместе с `CONFIG_EFI_VARS_PSTORE`: pstore работает с одним бэкендом,
blackbox нужен ramoops. Если нужны только логи паник без blackbox — проще
efi-pstore (`/sys/fs/pstore`, без резерва памяти и своего кода).

### hievent (`drivers/staging/hievent`) → `/dev/bbox`

Пассивный кольцевой буфер событий в ядре (`hievent_driver.c`: `HIEVENT_DEV_NAME "bbox"`).
Своего потока нет; если никто не читает, старые записи затираются.

| Кто | Что делает с `/dev/bbox` |
|---|---|
| Драйверы ядра | Пишут события через `hiview_hievent.c` / `hiview_hisysevent.c` |
| init | `init_cmds.c:1380` открывает на запись; без узла — `open /dev/bbox failed` (что пишет — не проверено) |
| hiview | `plugins/sysevent_source/event_server.cpp:253` читает, превращает в hisysevent |

- Узел создаётся при загрузке в devtmpfs, в образе его нет — rootfs пересобирать не нужно.
- При `=y` драйвер встроен в ядро, отдельного `.ko` в `/system/lib/modules` не будет.
- Без правила в ueventd узел будет `root:root 0600` — hiview (не root) читать не сможет.
- Пока hiview нет в образе, включение даёт только пропажу ошибки init.

### `/sys/kbox`

faultloggerd (`kernel_snapshot_task.cpp:36`) ждёт `/sys/kbox/snapshot_clear` — снимок
ядра от kbox. В открытом ядре источника нет, при отсутствии faultloggerd снимок не
снимает. Не трогаем.

### Кто ловит аварии (для ориентира)

- падения процессов — faultloggerd (`/data/log/faultlog`);
- паника ядра — blackbox или штатный pstore;
- зависания служб — hicollie;
- сбор и анализ — hiview.
