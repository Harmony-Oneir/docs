# AbilityManager (AMS)
AbilityManager (AMS, SA 180, библиотека libabilityms.z.so из части ability_runtime, работает в процессе foundation) — центральная служба запуска и жизненного цикла приложений OpenHarmony. Это аналог ActivityManagerService и ActivityTaskManagerService в Android. Все запросы на запуск ability проходят через неё: экранных UIAbility и фоновых расширений (ServiceExtension, FormExtension и других). AMS находит нужный компонент через BundleMgr (401), проверяет права, решает, в каком процессе его запустить, и ведёт его жизненный цикл: создание, переход на передний план, в фон, уничтожение. Задачи пользователя (mission), то есть стек открытых окон приложения и список недавних, она хранит в mission_list. Запуск процессов делегируется AppMgr (501): AMS говорит, что нужно поднять, а AppMgr создаёт процесс через appspawn и следит за его состоянием. Окна для UIAbility создаются совместно с оконной службой WMS. AMS также отвечает за пользователей на уровне приложений. По вызову StartUser от accountmgr она запускает пользователя: поднимает его системные приложения (лаунчер, SystemUI) и сообщает об успехе. Только после этого аккаунт 100 становится активным (isForeground: 1). Поэтому на стенде без AMS аккаунт создаётся, но остаётся inactive.

# Сборка

Для сборки используйте команду `./make.sh ability_manager` в контейнере. 

# Тестирование в QEMU

GPT-диск для QEMU:
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

Диск собирается из чистого userdata.img, так что аккаунт 100 будет создан заново.

Запуск:

```bash
cd /mnt/ohos/OpenHarmony7
sudo qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G -machine q35 \
  -kernel out/kernel/OBJ/linux-6.6/arch/x86/boot/bzImage \
  -drive file=/tmp/oneir-gpt.img,format=raw,if=none,id=nvm \
  -device nvme,serial=oneir,drive=nvm \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:18710-:8710 \
  -device e1000,netdev=n0 \
  -append 'root=/dev/nvme0n1p1 rw console=ttyS0 selinux=0 hardware=x86_64_oneir init=/system/bin/init loglevel=4 bbox_ramoops=auto panic=5' \
  -nographic -device virtio-gpu-pci
```

Проверка:

```bash
hidumper -ls
cat /proc/$(pidof foundation)/maps | grep -cE 'libabilityms|libappms'
hidumper -s 200 -a '-os_account_infos'
hilog -x -D 0xD001B00 -L I,W,E | tail -30
hilog -x -P $(pidof foundation) -L W,E | tail -40
```
Что ожидаем:

* В списке SA появились AbilityManagerService (180) и AppMgrService (501).
* Счётчик библиотек в foundation больше 0.
* У аккаунта 100 Status: active и isForeground: 1.
* В логе accountmgr есть ActivateDefaultOsAccount без ошибки.
