
# Сборка ядра
Перед сборкой необходимо применить патч:
```
cd /mnt/ohos/OpenHarmont7/kernel/linux/linux-6.6
patch -p1 --dry-run < ../patches/linux-6.6/qemu-arm-linux_patch/oh_headers.patch
patch -p1 < ../patches/linux-6.6/qemu-arm-linux_patch/oh_headers.patch
```

Так же для успешной сборки x64 необходимо применить исправления из репозитория [oneir_patches](https://github.com/Harmony-Oneir/oneir_patches/tree/main/linux_kernel):

* 0001-x86-mm-pat-fix-track_pfn_copy-after-CVE-backport.patch

Для сборки ядра выполните следующую команду из контейнера сборки:
```bash
rm -rf out/kernel/src_tmp out/kernel/OBJ # при необходимости отчистить сборку
cd kernel/linux/build
./kernel_module_build.sh /home/openharmony/out standard x86_64 device/board x86_64_oneir linux-6.6
```
`x86_64_oneir` — это файл конфигурации ядра Linux расположенный по пути `kernel/linux/<linux-6.6>/arch/<x86>/configs`. Файл конфигурации `x86_64_oneir` доступен [здесь](https://github.com/Harmony-Oneir/productdefine/tree/main/kernel/linux/build/linux-6.6/arch/x86/configs).
