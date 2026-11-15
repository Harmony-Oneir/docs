
Для работы с Bluetooth в [конфигурации ядра](https://github.com/Harmony-Oneir/productdefine/blob/main/kernel/linux/build/linux-6.6/arch/x86/configs/x86_64_oneir_standard_defconfig) необходимы следующие значения:
```
CONFIG_BT=m
CONFIG_BT_BREDR=y
CONFIG_BT_LE=y
CONFIG_BT_RFCOMM=m
CONFIG_BT_HIDP=m
CONFIG_BT_HCIBTUSB=m
CONFIG_UHID=m
```
