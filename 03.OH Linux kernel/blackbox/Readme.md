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


**Как это устроено по слоям:**

1. **pstore** (штатный Linux) — сам по себе уже сохраняет лог паники. При панике он записывает хвост dmesg в бэкенд, а после перезагрузки показывает его файлом в `/sys/fs/pstore` (например, `dmesg-ramoops-0` или `dmesg-efi-...`). Бэкенд — это где хранить: `ramoops` (зарезервированная область ОЗУ) или `efi-pstore` (переменные UEFI).
2. **blackbox** (OpenHarmony) — сверху. Он берёт запись из pstore и добавляет то, чего у pstore нет:
* зарегистрированные модули — каждый может добавить в дамп свои данные (на телефонах это модули чипсета, модема и т.п.);
* классификацию: событие, модуль, категория (паника, перезагрузка, выключение);
* раскладку логов в `/data/log/bbox` в формате, который ожидает hiview.

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


### Модули blackbox

В открытом коде только один — системный (`MODULE_SYSTEM`): `rockchip/system_adapter.c`,
`rockchip/system_adapter_by_memory.c` и наш `x86/system_adapter.c`. Модули чипсета,
модема и т.п. у производителей устройств закрытые.

Модуль = `struct module_ops` (`include/linux/blackbox.h`): имя, `dump` (при сбое),
`reset` (перед перезагрузкой), `get_last_log_info` (после загрузки: был ли сбой),
`save_last_log` (запись лога). О сбое сообщает `bbox_notify_error(event, module, desc,
need_sys_reset)`. Схема та же, что у LiteOS-версии (`SystemModule*`, `BBoxNotifyError`).

Системный модуль шлёт `EVENT_PANIC`, а также `EVENT_SYSREBOOT` и `EVENT_POWEROFF` —
вероятно, записывается и штатная перезагрузка (проверить обычным `reboot` до теста паники).

`bbox_register_module_ops` и `bbox_notify_error` не экспортированы: свои модули
только встроенные (`=y`), из `.ko` без патча с `EXPORT_SYMBOL` не зарегистрироваться.




---

# Тестирование blackbox в QEMU

Проверяет всю цепочку: паника → адаптер пишет лог через pstore в ramoops →
тёплая перезагрузка → init монтирует `/data` и pstore → blackbox читает запись →
лог в `/data/log/bbox/<время>-<номер>/last_kmsg`.

### Что должно быть в сборке

- Патчи ядра `oneir_patches/linux_kernel/0008` (x86-адаптер) и `0009` (чтение записи pstore на ядре 6.6).
- defconfig `x86_64_oneir_standard_defconfig`:

  ```
  CONFIG_PSTORE=y
  CONFIG_PSTORE_RAM=y
  CONFIG_PSTORE_BLACKBOX=y
  CONFIG_BLACKBOX_STORAGE_BY_PSTORE_RAM=y
  CONFIG_DEF_BLACKBOX_STORAGE_BY_PSTORE_RAM=y
  CONFIG_BLACKBOX_X86=y
  CONFIG_BLACKBOX_LOG_ROOT_PATH="/data/log/bbox"
  CONFIG_BLACKBOX_LOG_PART_REPRESENTATIVE="/dev/bbox_ready"
  # CONFIG_EFI_VARS_PSTORE is not set
  ```

  `CONFIG_EFI_VARS_PSTORE` включается сам вместе с `CONFIG_PSTORE`; в QEMU с `-kernel`
  (SeaBIOS) он не мешает, но на ноутбуке с UEFI может занять pstore раньше ramoops.
- `oneir/rootfs/vendor/etc/init.x86_64_oneir.cfg`, задание `post-fs-data`, первыми командами:

  ```json
  "mount pstore pstore /sys/fs/pstore nodev noexec nosuid",
  "chown system log /sys/fs/pstore",
  "chmod 0555 /sys/fs/pstore",
  "mkdir /dev/bbox_ready 0700 root root",
  ```

  В `init.cfg` продукта (`oneir/rootfs/system/etc/init.cfg`) монтирования pstore нет.
  Метка `/dev/bbox_ready` — то, чего ждёт blackbox: она появляется после монтирования
  `/data` и pstore и не переживает перезагрузку (tmpfs).

Проверить, что ядро действительно пересобрано с нужным:

```bash
cd /mnt/ohos/OpenHarmont7
grep -E 'BLACKBOX_X86|LOG_PART_REPRESENTATIVE|EFI_VARS_PSTORE' out/kernel/OBJ/linux-6.6/.config
grep -c read_iter out/kernel/src_tmp/linux-6.6/fs/pstore/inode.c
ls -l --time-style=full-iso out/kernel/OBJ/linux-6.6/arch/x86/boot/bzImage
```

### Диск: один GPT-образ по NVMe

fstab монтирует `/data` по имени раздела (`/dev/block/by-name/userdata`). Если подключить
`ohos-root.img` и `userdata.img` голыми дисками `virtio`, ссылки `by-name` не будет,
`/data` не смонтируется (флаг `wait` пропустит его молча), и лог писать будет некуда.
Поэтому собираем из двух образов один GPT-диск в `/tmp` (исходники не трогаются):

```bash
cd /mnt/ohos/OpenHarmont7/out/oneir
R=ohos-root.img; U=userdata.img; D=/tmp/oneir-gpt.img
RM=$(( ($(stat -c %s $R) + 1048575) / 1048576 ))
UM=$(( ($(stat -c %s $U) + 1048575) / 1048576 ))
rm -f $D && truncate -s $(( RM + UM + 2 ))M $D
/usr/sbin/sgdisk -o -n 1:1M:+${RM}M -c 1:system -n 2:0:+${UM}M -c 2:userdata $D
dd if=$R of=$D bs=1M seek=1 conv=notrunc status=none
dd if=$U of=$D bs=1M seek=$(( 1 + RM )) conv=notrunc status=none
/usr/sbin/sgdisk -p $D
```

`sgdisk` — пакет `gdisk`; лежит в `/usr/sbin`, которого нет в `PATH` обычного пользователя
Debian, поэтому полный путь. После пересборки `ohos-root.img` диск нужно собрать заново.

### Запуск

```bash
cd /mnt/ohos/OpenHarmont7
sudo qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G -machine q35 \
  -kernel out/kernel/OBJ/linux-6.6/arch/x86/boot/bzImage \
  -drive file=/tmp/oneir-gpt.img,format=raw,if=none,id=nvm \
  -device nvme,serial=oneir,drive=nvm \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:18710-:8710 \
  -device e1000,netdev=n0 \
  -append 'root=/dev/nvme0n1p1 rw console=ttyS0 selinux=0 hardware=x86_64_oneir init=/system/bin/init loglevel=4 bbox_ramoops=auto panic=5' \
  -nographic -device virtio-gpu-pci
```

| Параметр | Зачем |
|---|---|
| `memmap=1M$0x70000000` | прячет 1 МБ ОЗУ на отметке 1,75 ГБ от ядра (должно быть внутри `-m`) |
| `ramoops.mem_address`, `mem_size` | ramoops использует эту область |
| `ramoops.blackbox_size=0x40000` | отдельная область под запись blackbox (OHOS); по умолчанию крошечная; степень двойки |
| `ramoops.record_size=0x20000` | размер записей dmesg в остатке области |
| `ramoops.ecc=1` | защита записей от порчи |
| `panic=5` | перезагрузка через 5 с после паники (по умолчанию ядро висит) |
| `loglevel=4` | чтобы паника была видна в консоли |

- `-append` — **в одинарных кавычках**: в двойных оболочка подставит `$0` из `$0x70000000`.
- **Без `-no-reboot`**: с ним QEMU при перезагрузке завершается и память теряется.
  Сброс гостя внутри QEMU — тёплый, ОЗУ (и запись ramoops) сохраняется.
- **Выход из QEMU = холодный старт**: записи ramoops пропадают. Аварию и проверку делать
  в одной сессии.
- Порт `18710` занят — значит, работает предыдущий QEMU (`sudo ss -ltnp | grep 18710`).
  Для теста hdc не нужен: всё делается в консоли `-nographic`.

### Проверка

**1. После холодного старта** — всё поднялось, лога ещё нет:

```sh
ls -l /dev/block/by-name/                 # system, userdata
mount | grep -E ' /data |pstore'          # /data ext4 rw, pstore смонтирован
dmesg | grep -iE 'ramoops|bbox'
ls -lR /data/log/bbox                     # пусто или нет каталога
```

В dmesg ожидается:

```
ramoops: using 0x100000@0x70000000, ecc: 16
pstore: Registered ramoops as persistent store backend
bbox:[info][blackbox_core.c:510] [SYSTEM] is registered successfully!
bbox:[info][blackbox_core.c:263] wait for log part [/dev/bbox_ready] end!
```

**2. Штатная перезагрузка** (системный модуль пишет и её):

```sh
reboot
```

После загрузки — каталог в `/data/log/bbox` с событием `UNKNOWN` (так kmsg_dump на 6.6
называет перезагрузку/выключение) и непустым `last_kmsg`; в конце лога — остановка служб init.

**3. Паника:**

```sh
echo c > /proc/sysrq-trigger
```

`write /proc/sys/kernel/sysrq 0` в `init.cfg` не мешает: он ограничивает только SysRq
с клавиатуры. Через 5 с гость перезагрузится сам. После загрузки:

```sh
dmesg | grep -i bbox
ls -lR /data/log/bbox
tail -n 40 /data/log/bbox/*/last_kmsg
```

Ожидается:

```
bbox:[info][blackbox_storage.c:154] read /sys/fs/pstore/blackbox-ramoops-0: 137520 bytes
bbox:[info][blackbox_core.c:407] event: [PANIC] module: [SYSTEM], time is [20261120223923-00000033]!
bbox:[info][system_adapter.c:210] save last fault log successfully!
```

и в конце `last_kmsg`: `sysrq: Trigger a crash`, `Kernel panic - not syncing: sysrq triggered crash`
и стек вызовов.

Запись в `/sys/fs/pstore` blackbox удаляет сразу после чтения — после загрузки её там уже нет,
это нормально. Посмотреть запись до blackbox можно только вручную смонтировав pstore
в ядре без `CONFIG_BLACKBOX_X86`.
