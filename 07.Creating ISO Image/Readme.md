# Harmony Oneir: перенос на реальное железо

В данном документе описывается перенос Harmony Oneir на реальное железо под управлением процессора на архитектуре x64. 

> Корень исходников: `/mnt/ohos/OpenHarmony7`. Все команды выполняются из него, если не указано иное.

## 1. Общая схема

```
QEMU -kernel bzImage  -append "root=/dev/vda ..."
  /dev/vda  ← ohos-root.img  (голый образ, без разметки)
  /dev/vdb  ← userdata.img   (голый образ, без разметки)
fstab: /dev/block/vdb → /data
```

### Стало (UEFI + GPT, как на ноутбуке)

```
SSD (GPT)
├─ p1  ESP        512M  vfat   EFI/BOOT/BOOTX64.EFI  (UKI: ядро + cmdline)
├─ p2  ohos-root  2G    ext4   копия ohos-root.img   PARTUUID ...0000a1
└─ p3  userdata   4G+   ext4   копия userdata.img    PARTUUID ...0000a2

UEFI → BOOTX64.EFI → ядро (root=PARTUUID=...a1) → /system/bin/init
ueventd → /dev/block/by-name/userdata → fstab → /data
```

### Используемые инструменты

| Инструмент | Зачем |
|---|---|
| `ukify` (systemd) | собирает UKI: ядро + cmdline в один EFI-файл, отдельный загрузчик не нужен |
| `systemd-repart` | декларативно размечает диск (GPT) и побайтово копирует образы в разделы |
| Docker (`debian:trixie`) | свежие версии ukify/repart, не трогая хост (bookworm) |
| OVMF | UEFI-прошивка для QEMU |

---

## 2. Ядро

Конфиг: `out/kernel/OBJ/linux-6.6/.config`.

### Обязательные опции (`=y`, не `=m`: initramfs нет)

| Опция | Зачем | Статус |
|---|---|---|
| `CONFIG_EFI`, `CONFIG_EFI_STUB` | загрузка ядра напрямую из UEFI | ✅ |
| `CONFIG_BLK_DEV_NVME` | NVMe SSD | ✅ включено (было `not set`) |
| `CONFIG_SATA_AHCI` | SATA SSD | ✅ |
| `CONFIG_EXT4_FS` | ФС root и userdata | ✅ |
| `CONFIG_DRM_SIMPLEDRM` | изображение через EFI framebuffer | ✅ |
| `CONFIG_DRM_I915` | Intel GPU | ✅ |
| `CONFIG_USB_XHCI_HCD`, `CONFIG_HID_GENERIC` | USB клавиатура/мышь | ✅ |

### Пока не сделано

| Опция | Зачем | Статус |
|---|---|---|
| `CONFIG_I2C_HID_ACPI` (+ `I2C_DESIGNWARE_*`, `MFD_INTEL_LPSS_PCI`, `PINCTRL_<платформа>`) | тачпад | ❌ не включилось, не хватает зависимостей |
| `CONFIG_E1000E` | проводная сеть Intel | `=m` |
| `CONFIG_IWLWIFI` | Wi-Fi Intel | `=m`, нужна прошивка и стек Wi-Fi OHOS |
| `CONFIG_DRM_AMDGPU` | AMD GPU | не включено, нужно только для AMD |

### Проверка

```bash
K=out/kernel/OBJ/linux-6.6/.config
grep -E '^(# )?CONFIG_(EFI_STUB|BLK_DEV_NVME|SATA_AHCI|EXT4_FS|DRM_SIMPLEDRM|DRM_I915|I2C_HID_ACPI|E1000E)[ =]' $K
```

## 3. fstab

Файл: `oneir/rootfs/vendor/etc/fstab.x86_64_oneir`.

```
# fstab for x86_64_oneir (GPT disk: QEMU NVMe / real hardware)
#<src>                       <mnt_point>  <type>  <mnt_flags and options>  <fs_mgr_flags>
/dev/block/by-name/userdata   /data        ext4    noatime,nosuid,nodev     wait
```

- Устройство указано по **GPT-метке** раздела, а не по имени (`vdb`, `nvme0n1p3`, `sda3`). Это не зависит от типа диска и порядка обнаружения.
- `wait`: init ждёт появления устройства (NVMe появляется не мгновенно).
- Root монтирует **ядро** по `root=PARTUUID=...` (ядро не знает `by-name`), а не fstab.

> ⚠️ После этой правки старый способ запуска QEMU (`-kernel` + голый `userdata.img` на `vdb`) больше не монтирует `/data`: на голом диске нет GPT-метки.

---

## 4. Патчи ueventd

Без них `/dev/block/by-name/*` на x86 не создаются, и `/data` не монтируется.

Расположение: [`oneir/oneir_patches/base_startup_init/`](https://github.com/Harmony-Oneir/oneir_patches/tree/main/base_startup_init) (описание в `README.md` там же).
Репозиторий: `base/startup/init`, файл `ueventd/ueventd_device_handler.c`.

### Почему ссылок не было

1. `GetBlockDeviceSymbolLinks()` создаёт ссылки только для дисков, у которых родитель в sysfs находится на шине `platform` (так устроены ARM-платы). На x86 NVMe/SATA/USB находятся на **PCI**, поэтому ссылок не было вообще.
2. Короткая ссылка `/dev/block/by-name/<метка>` создаётся, только если родитель совпадает с параметром cmdline `default_boot_device=`. Это PCI-путь, который зависит от конкретного железа.

### Известное ограничение

В простом режиме (без `default_boot_device`) при двух дисках с разделом `userdata` ссылка укажет на тот, который обнаружен первым. Для одного SSD это не проблема; для защиты есть строгий режим (раздел 8).

---

## 5. Инструменты в Docker

Хост на Debian bookworm, а `systemd-ukify` есть только в trixie. Чтобы не обновлять systemd на хосте, инструменты запускаются в контейнере.

`oneir/installer/tools/Dockerfile`:

```dockerfile
FROM debian:trixie
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd-ukify systemd-boot-efi systemd-repart \
      dosfstools e2fsprogs mtools fdisk \
    && rm -rf /var/lib/apt/lists/*
```

```bash
docker build -t oneir-tools oneir/installer/tools
```

---

## 6. UKI (`BOOTX64.EFI`)

```bash
mkdir -p oneir/installer/esp/EFI/BOOT

sudo docker run --rm -v "$PWD":/src -w /src oneir-tools \
  ukify build \
    --linux out/kernel/OBJ/linux-6.6/arch/x86/boot/bzImage \
    --cmdline "root=PARTUUID=6a1c3b2e-0000-4000-8000-0000000000a1 rootwait rw console=tty0 console=ttyS0 selinux=0 hardware=x86_64_oneir init=/system/bin/init" \
    --output oneir/installer/esp/EFI/BOOT/BOOTX64.EFI
```

Отличия cmdline от QEMU-варианта:

| Параметр | Зачем |
|---|---|
| `root=PARTUUID=...a1` | вместо `/dev/vda`; UUID задаётся разделу в repart |
| `rootwait` | ждать появления диска (без initramfs обязательно) |
| `console=tty0 console=ttyS0` | экран + последовательная консоль (для QEMU) |
| без `quiet loglevel=3` | на время отладки, вернуть позже |

Путь `EFI/BOOT/BOOTX64.EFI` — это загрузчик по умолчанию, UEFI находит его без записей в NVRAM. Secure Boot на ноутбуке нужно отключить (UKI не подписан).

---

## 7. Разметка диска (systemd-repart)

`oneir/installer/repart.d/`. Пути `/opt/ohos/...` одинаковы для тестового диска в Docker и для будущей установочной флешки.

`00-esp.conf`
```ini
[Partition]
Type=esp
Format=vfat
Label=ESP
SizeMinBytes=512M
SizeMaxBytes=512M
CopyFiles=/opt/ohos/esp:/
```

`10-root.conf`
```ini
[Partition]
Type=linux-generic
Label=ohos-root
UUID=6a1c3b2e-0000-4000-8000-0000000000a1
CopyBlocks=/opt/ohos/ohos-root.img
# не расширять: ФС root не растягивается, свободное место — для userdata
Weight=0
```

`20-userdata.conf`
```ini
[Partition]
Type=linux-generic
Label=userdata
UUID=6a1c3b2e-0000-4000-8000-0000000000a2
CopyBlocks=/opt/ohos/userdata.img
SizeMinBytes=4G
```

Связи, которые должны совпадать:

| Где | Значение | Должно совпадать с |
|---|---|---|
| `10-root.conf` `UUID=` | `...0000a1` | `root=PARTUUID=` в UKI |
| `20-userdata.conf` `Label=` | `userdata` | `/dev/block/by-name/userdata` в fstab |

> `CopyBlocks` не растягивает ФС: на тестовом диске раздел userdata 4G, а ext4 внутри размером с исходный образ. Растягивать (`resize2fs`) будет установщик.

---

## 8. Тестирование в QEMU

### Сборка тестового диска

```bash
mkdir -p oneir/installer/test
sudo rm -f oneir/installer/test/disk.img      # --empty=create не перезаписывает файл

sudo docker run --rm \
  -v "$PWD/oneir/installer/esp":/opt/ohos/esp:ro \
  -v "$PWD/oneir/installer/repart.d":/opt/ohos/repart.d:ro \
  -v "$PWD/out/oneir/ohos-root.img":/opt/ohos/ohos-root.img:ro \
  -v "$PWD/out/oneir/userdata.img":/opt/ohos/userdata.img:ro \
  -v "$PWD/oneir/installer/test":/work \
  oneir-tools \
  systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
    --definitions=/opt/ohos/repart.d /work/disk.img
```

Проверка:
```bash
sudo fdisk -l oneir/installer/test/disk.img
sudo sfdisk --part-uuid oneir/installer/test/disk.img 2   # → 6A1C3B2E-...-0000000000A1
```

Диск пересобирается после **каждой** пересборки `ohos-root.img` или UKI.

### Запуск (UEFI + NVMe, как на ноутбуке)

```bash
sudo apt install ovmf

sudo qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G -machine q35 \
  -bios /usr/share/ovmf/OVMF.fd \
  -drive file=oneir/installer/test/disk.img,format=raw,if=none,id=nv0 \
  -device nvme,drive=nv0,serial=ssd0 \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:18710-:8710 \
  -device e1000,netdev=n0 \
  -device virtio-gpu-pci -vga none \
  -display none -vnc 127.0.0.1:0 \
  -serial mon:stdio
```

### Проверка внутри системы

```bash
ls -l /dev/block/by-name/
grep -E ' / | /data ' /proc/mounts
```

Результат (простой режим):
```
ESP       -> /dev/block/nvme0n1p1
ohos-root -> /dev/block/nvme0n1p2
userdata  -> /dev/block/nvme0n1p3

/dev/root                   /     ext4 ro,nodev,relatime
/dev/block/by-name/userdata /data ext4 rw,nosuid,nodev,noatime
```

### Строгий режим

В cmdline добавляется `default_boot_device=<PCI-путь контроллера SSD>`. Ссылки `by-name` получает только этот диск.

PCI-путь — это `readlink -f /sys/block/nvme0n1` без префикса `/sys/devices/` и без хвоста `nvme/...`:

```
/sys/devices/pci0000:00/0000:00:01.0/nvme/nvme0/nvme0n1
             └──────────┬──────────┘
          default_boot_device=pci0000:00/0000:00:01.0   (QEMU)
```

Тест: отдельный UKI в `oneir/installer/esp-strict/` и диск `test/disk-strict.img` (те же команды, что выше, с добавленным параметром и другими путями). Результат:

```
ueventd.c:404 Get cmdline param default_boot_device : pci0000:00/0000:00:01.0
```
ссылки `by-name` и `/data` на месте.

> Ограничение: если SSD переставить в другой слот или в другой компьютер, PCI-путь изменится, и `/data` не смонтируется. Поэтому по умолчанию используется простой режим.

