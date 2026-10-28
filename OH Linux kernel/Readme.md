
# Сборка ядра
Для сборки ядра выполните следующую команду из контейнера сборки:
```bash
cd kernel/linux/build
./kernel_module_build.sh /home/openharmony/out standard x86_64 device/board x86_64_oneir linux-6.6
```
`x86_64_oneir` — это файл конфигурации ядра Linux расположенный по пути `kernel/linux/<linux-6.6>/arch/<x86>/configs`. Файл конфигурации `x86_64_oneir` доступен [здесь](https://github.com/Harmony-Oneir/productdefine/tree/main/kernel/linux/build/linux-6.6/arch/x86/configs).
