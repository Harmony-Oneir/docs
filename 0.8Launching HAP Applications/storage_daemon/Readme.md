`storage_daemon` (SA 5002): работает с правами root: создаёт каталоги пользователя (`/data/app/el1..el4/<id>`, `/data/service/el*/<id>`), монтирует их, готовит ключи шифрования (`fscrypt`), монтирует внешние носители.
`storage_daemon` — делает то, что требует настоящих прав: монтирует, создаёт каталоги с нужными владельцами и метками, управляет ключами шифрования. Сам он почти ничего не решает: решения принимают другие службы, а он выполняет.

## Кто к нему обращается
* **init**: при загрузке через sdc filecrypt init_global_key и init_main_user.
* **accountmgr**: при создании, удалении, запуске и остановке пользователя (SendToStorageAccountCreate, ...Start и т.д.).
* **storage_manager** (5003): публичный фасад для приложений и системных служб. Он проверяет права и политику, а реальную работу передаёт в демон.

## Что он делает (по областям)

### Каталоги пользователей

У каждого пользователя есть набор каталогов, распределённых по уровням защиты — **EL (encryption level)**:

- **EL1** доступен сразу после загрузки устройства.
- **EL2** — после первой разблокировки.
- **EL3, EL4 и EL5** — более строгие уровни защиты.

Каталоги могут располагаться, например, в `/data/app/elN/<id>`, `/data/service/elN/<id>`, `/data/chipset/...`. Их точные пути, права и владельцы описаны в `storage_user_path.json`.

**Подготовить пользователя** (`PrepareUserDirs`) — значит создать все предусмотренные для него каталоги.

**Запустить пользователя** (`StartUser`) — значит смонтировать его представления: bind-монтирования, `hmdfs` и `sharefs`. Конфигурация монтирований хранится в `storage_mount_info.json`.

### Шифрование (fscrypt)

Демон создаёт и хранит ключи:

- глобальный ключ устройства для EL1 (`init_global_key`);
- пользовательские ключи для EL2 и выше.

Пользовательские ключи привязаны к паролю или PIN через `huks` (хранилище ключей) и `userauth`. 

При блокировке и разблокировке экрана демон снимает и устанавливает ключи EL3/EL4. Для этого требуется разрешение `ACCESS_SCREEN_LOCK`.

### Внешние носители

За работу с внешними носителями отвечают компоненты `NetlinkManager`, `DiskManager` и `ReplayUevent`. Демон слушает uevent от ядра, а при старте повторно обрабатывает события уже подключённых устройств.

По `disk_config` он определяет, какие блочные устройства считать съёмными, например USB-флешки и SD-карты. Для них демон создаёт тома, проверяет и монтирует файловые системы (`vfat`, `exfat` и другие) в `/mnt/data/external`, а затем сообщает о них `storage_manager`.

С этим функционалом связаны:

- обработка события появления `5003`;
- MTP (`mtp_tmp`);
- `usb_config.para`.

### Распределённые и облачные файловые системы

К этому функционалу относятся:

- `hmdfs` — общая файловая система между устройствами одного аккаунта;
- `sharefs` — обмен файлами между приложениями;
- `/config/hmdfs` через `configfs`;
- связь с cloud daemon для облачной синхронизации: `libcloud_daemon_kit_inner` и подписка на `CLOUD_DAEMON_SERVICE`.

### Статистика и квоты

Поток `StorageRadarThd` собирает статистику занятого места и отправляет события через `hisysevent`.

Квоты по UID работают, если файловая система их поддерживает. `storage_manager` использует эти данные, чтобы предоставлять приложениям информацию о размерах хранилища.

### Файлы конфигурации

В системе присутствует папка `/system/etc/storage_daemon/` в которой находятся `disk_config`, `storage_user_path.json` и `storage_mount_info.json`.

**`storage_user_path.json`: какие каталоги создавать для пользователя**

Это список шаблонов каталогов, по которым работают PrepareUserDirs и DestroyUserDirs.
**`storage_mount_info.json`: что монтировать при запуске пользователя**

Это список узлов монтирования (MountNodeInfo) для StartUser/StopUser: источник, точка монтирования, тип ФС, флаги и опции.

**`disk_config` задаёт правила для DiskManager** внутри `storage_daemon`: какие блочные устройства считать внешними носителями, которыми демон должен управлять, то есть разбирать разделы, создавать тома и монтировать их в `/mnt/data/external`.

# Сборка

Для сборки используйте команду `./make.sh storage` в контейнере. После запуска Init откроет файл `storage_daemon.cfg` по пути `system/etc/init/`.
Для сборки тестов используйте команду `./make.sh storage_tests`.


# Тесты

## `file_utils_test`: `FileUtilsTest` — около 50 кейсов

### Каталоги и права
- `MkDir`
- `PrepareDir` / `PrepareDirSimple` — создание каталога с заданными режимом, UID и GID; ровно то, что делает `PrepareUserDirs`
- `ChMod`
- `ChOwn`
- `TravelChmod`
- `DelFolder`
- `DeleteFile`
- `IsFile` / `IsFolder` / `IsTempFolder`

### Чтение
- `ReadFile`
- `ReadFileContent`
- `ReadFileInParentDirs`
- `Split`

### Размеры
- `GetSubFilesSize`
- `StatisticsFilesTotalSize`
- `GetRmgDataSize` / `GetRmgResourceSize`

### Запуск процессов
- `ForkExec*`
- `ForkExecInteractive_*`
- `RedirectStdToPipe`
- `KillProcess`

Так демон запускает внешние утилиты, например `fsck` и mount-хелперы.

### Без окружения
- `MaskSensitiveInfo` — маскирование путей и ID в логах
- `IsBusinessPath`

---

## `user_path_resolver_test`: `UserPathResolverTest` — 17 кейсов

### Разбор JSON
- `DirInfo_FromJson` — разбор записей из `storage_user_path.json`
- `MountNodeInfo_FromJson` — разбор записей из `storage_mount_info.json`

### Построение путей
- `GetUserBasePath`
- `GetUserServicePath`
- `GetAppdataPath`
- `GetVirtualPath`

### Списки монтирований
- `GetAppDataMountNodeList`
- `GetAppDataMountStartupNodeList`

### Реальные действия
- `MakeDir`
- `RemoveDir`
- `MountDir_001`–`MountDir_005`
- `UpdateDirUid`

---

# `user_manager_test`: `UserManagerTest` — 26 кейсов

### Основные сценарии
- `PrepareUserDirs_001`–`PrepareUserDirs_004`
- `PrepareUserDirsForUpdate_001`–`PrepareUserDirsForUpdate_004` — досоздание каталогов после обновления системы
- `StartUser_001`–`StartUser_002`
- `StopUser_001`–`StopUser_003`
- `DestroyUserDirs_001`
- `CheckUserIdRange`
- `CheckDirsFromVec`

### Вспомогательные сценарии
Кейсы названы `MountManagerTest_*`, но находятся в этом тестовом файле:

- `CreateUserDir`
- `CreateElxBundleDataDir`
- `LocalMount`
- `MountMediaFuse`
- `RestoreconSystemServiceDirs`
- `SetCloudState`
- `FindAndKillProcess`
- `GetProcessInfo`
- `CheckMaps`

---

# `mount_manager_test`: `MountManagerTest` — около 50 кейсов

Проверяет почти всё, что связано с монтированиями.

### Распределённые и облачные файловые системы
- `MountHmdfs`
- `MountSharefs`
- `MountDfsDocs`
- `UMountDfsDocs`
- `MountDisShareFile`
- `UMountDisShareFile_001`–`UMountDisShareFile_009`
- `FindMountsByNetworkId`
- `CloudAndFuseDirFlag`

### FUSE
- `MountFileMgrFuse`
- `UMountFileMgrFuse` — `/mnt/data/100/smb/...`
- `MediaFuseDirFlag`

### Песочницы приложений
- `MountSandboxPath`
- `PrepareAppdataDir`
- `PrepareAppdataDirByUserId`
- `CreateVirtualDirs`
- `LocalMount`

### Поиск процессов, удерживающих файлы
- `FindProcForPath`
- `FindProcForMulti`
- `IsFileOccupied`
- `OpenProcFor*` — проверка через `/proc/*/fd` и `maps`

Это нужно, чтобы перед `StopUser` завершить процессы, мешающие размонтированию.

### Служебные проверки и операции
- `CheckMaps`
- `CheckSymlink`
- `CheckPathValid`
- `DirExist`
- `UMountByListWithDetach`
- Сценарии «второго монтирования»: `*SecondMount*`, `IsBundleNeedClear`

---

# `storage_daemon_clt_test`: `StorageDaemonClientTest`

Тесты обращаются к работающему демону через SA 5002.

### Пользователи
- `PrepareUserDirs`
- `StartUser`
- `StopUser`
- `DestroyUserDirs`
- `PrepareUserSpace`
- `DestroyUserSpace`
- `GetUserNeedActiveStatus`

### Ключи и шифрование
- `InitGlobalKey`
- `InitGlobalUserKeys`
- `ActiveUserKey` / `InactiveUserKey`
- `UpdateUserAuth`
- `UpdateKeyContext`
- `CreateRecoverKey` / `SetRecoverKey`
- `GenerateAppkey` / `DeleteAppkey`
- `SetDirEncryptionPolicy`
- `FscryptEnable`
- `GetFileEncryptStatus`
- `EraseAllUserEncryptedKeys`

### Экран блокировки
- `LockUserScreen`
- `UnlockUserScreen`
- `GetLockScreenStatus`

### Прочее
- `CheckServiceStatus`
- `GetStorageDaemonProxy`
- `IsFileOccupied`
- `ListUserdataDirInfo`
- `MountDfsDocs` / `UMountDfsDocs`
- `MountFileMgrFuse` / `UMountFileMgrFuse`
- `NewErrBranches_*` — передача неверных аргументов

## Запустить тесты

```bash
mkdir -p /data/test
mkdir -p /data/local/tmp/st && cd /data/local/tmp/st
T=/system/tests/storage
$T/string_utils_test
```

## Для тестирования в QEMU
Создать GPT диск:
```bash
cd /mnt/ohos/OpenHarmony7/out/oneir
R=ohos-root.img; U=userdata.img; D=/tmp/oneir-gpt.img
RM=$(( ($(stat -c %s $R) + 1048575) / 1048576 ))
UM=$(( ($(stat -c %s $U) + 1048575) / 1048576 ))
rm -f $D && truncate -s $(( RM + UM + 2 ))M $D
/usr/sbin/sgdisk -o -n 1:1M:+${RM}M -c 1:system -n 2:0:+${UM}M -c 2:userdata $D
dd if=$R of=$D bs=1M seek=1 conv=notrunc status=none
dd if=$U of=$D bs=1M seek=$(( 1 + RM )) conv=notrunc status=none
```

Запуск QEMU:
```bash
cd /mnt/ohos/OpenHarmony7
sudo qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G -machine q35 \
  -kernel out/kernel/OBJ/linux-6.6/arch/x86/boot/bzImage \
  -drive file=/tmp/oneir-gpt.img,format=raw,if=none,id=nvm \
  -device nvme,serial=oneir,drive=nvm \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:18710-:8710 \
  -device e1000,netdev=n0 \
  -append 'root=/dev/nvme0n1p1 rw console=ttyS0 selinux=0 hardware=x86_64_oneir init=/system/bin/init loglevel=1 bbox_ramoops=auto panic=5' \
  -nographic -device virtio-gpu-pci
```
