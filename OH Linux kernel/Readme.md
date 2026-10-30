
# Сборка ядра
Перед сборкой необходимо применить патч:
```
cd /mnt/ohos/OpenHarmont7/kernel/linux/linux-6.6
patch -p1 --dry-run < ../patches/linux-6.6/qemu-arm-linux_patch/oh_headers.patch
patch -p1 < ../patches/linux-6.6/qemu-arm-linux_patch/oh_headers.patch

KP=/mnt/ohos/OpenHarmont7/kernel/linux/patches/linux-6.6/rk3568_patch/kernel.patch
patch -p1 --forward --no-backup-if-mismatch < $KP 
```

Так же для успешной сборки x64 необходимо применить исправления из репозитория [oneir_patches](https://github.com/Harmony-Oneir/oneir_patches/tree/main/linux_kernel):

* `0001-x86-mm-pat-fix-track_pfn_copy-after-CVE-backport.patch`
* `0002-x86-add-missing-amd-fch-h.patch`
* `0003-binfmt_misc-use-6.6-allow_write_access-API.patch`
* `0004-kernel.mk-apply-missing-common-modules.patch`
* `0005-sched-walt-use-arch_scale_cpu_capacity.patch`
  
Для сборки ядра выполните следующую команду из контейнера сборки:
```bash
rm -rf out/kernel/src_tmp out/kernel/OBJ # при необходимости отчистить сборку
cd kernel/linux/build
./kernel_module_build.sh /home/openharmony/out standard x86_64 device/board x86_64_oneir linux-6.6
```
`x86_64_oneir` — это файл конфигурации ядра Linux расположенный по пути `kernel/linux/<linux-6.6>/arch/<x86>/configs`. Файл конфигурации `x86_64_oneir` доступен [здесь](https://github.com/Harmony-Oneir/productdefine/tree/main/kernel/linux/build/linux-6.6/arch/x86/configs).

Результат сборки находится по пути `out/kernel/OBJ/linux-6.6/arch/x86/boot/bzImage`.

Следующим этапом является сборка [Init](https://github.com/Harmony-Oneir/docs/tree/main/OH%20Linux%20kernel/Init). После сборки запустите скрипт [make_ohos-root.sh](https://github.com/Harmony-Oneir/oneir/blob/main/make_ohos-root.sh), который создаст `ohos-root.img`:

```bash
sudo REBUILD=1 ./make_ohos-root.sh
```

**Промежуточный тест**. Запустите собранное ядро через qemu:
```bash
cd /mnt/ohos/OpenHarmony7                                                   
sudo qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G \
  -kernel out/kernel/OBJ/linux-6.6/arch/x86/boot/bzImage \
  -drive file=out/oneir/ohos-root.img,format=raw,if=virtio \
  -drive file=out/oneir/userdata.img,format=raw,if=virtio \
  -append "root=/dev/vda rw console=ttyS0 selinux=0 hardware=x86_64_oneir init=/system/bin/init" \
  -nographic
```

Запуск без логов ядра:
```
cd /mnt/ohos/OpenHarmony7
sudo qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G \
  -kernel out/kernel/OBJ/linux-6.6/arch/x86/boot/bzImage \
  -drive file=out/oneir/ohos-root.img,format=raw,if=virtio \
  -drive file=out/oneir/userdata.img,format=raw,if=virtio \
  -append "root=/dev/vda rw console=ttyS0 selinux=0 hardware=x86_64_oneir init=/system/bin/init quiet loglevel=3" \
  -nographic
```

В появившиеся консоли:
```bash
ls -l /dev/binder /dev/hwbinder /dev/vndbinder
crw------- 1 0 0 10, 123 2026-10-29 19:07 /dev/binder
crw------- 1 0 0 10, 122 2026-10-29 19:07 /dev/hwbinder
crw------- 1 0 0 10, 121 2026-10-29 19:07 /dev/vndbinder
```

Все три устройства на месте. Ядро теперь полностью готово для OpenHarmony: binder, ashmem, AccessTokenID и RTG есть. 

# Тестирование OH ядра

### accesstokenid_test

`accesstokenid_test` проверяет драйвер `AccessTokenID` в ядре (`/dev/access_token_id`). Это механизм, на котором строится вся система прав OpenHarmony: у каждого процесса есть идентификатор токена, по которому сервисы проверяют, что вызывающему разрешено. Тест убеждается, что процесс может прочитать и установить свой токен (`tokenid`) и «первый токен» (`ftokenid`, токен исходного вызывающего в цепочке вызовов), что дочерние потоки наследуют токен родителя и могут менять его независимо, что ядро отвергает некорректные аргументы и неизвестные команды ioctl, а непривилегированный пользователь не может работать с устройством. Отдельно проверяется, что процесс, запущенный в системе, уже получил ненулевой токен от init.

Собрать тесты можно следующей командой из контейнера:
```bash
./make.sh //kernel/linux/build/test:accesstokenid_test
```
Результат сборки:
* out/oneir/tests/unittest/linux-linux/accesstokenid_test

### rtg_test

rtg_test проверяет драйвер RTG (Related Thread Group) в планировщике (/dev/sched_rtg_ctrl). RTG объединяет связанные потоки, например потоки, вместе отрисовывающие кадр интерфейса, в группу, которой планировщик выделяет ресурсы CPU согласованно. На этом построено «кадровое» планирование OpenHarmony, отвечающее за плавность UI. Тест включает механизм, создаёт и удаляет группы, добавляет в них потоки и проверяет ограничения на их число, отправляет события начала и конца кадра и сцены, задаёт минимальную загрузку и запас производительности группы, меняет её атрибуты и конфигурацию, а также проверяет реакцию на ошибочные параметры.

Собрать тест можно следующей командой из контейнера:
```bash
./make.sh //kernel/linux/build/test:rtg_test
```
Перед компиляцией примените следующие патчи:
* [0006-test-rtg-use-unsigned-char-for-ioctl-magic.patch](https://github.com/Harmony-Oneir/oneir_patches/blob/main/linux_kernel/0006-test-rtg-use-unsigned-char-for-ioctl-magic.patch)

Результат сборки:
* `out/oneir/tests/unittest/linux-linux/rtg_test`

---

После запуска `make_ohos-root.sh` тесты находятся по пути `/system/tests/`.
