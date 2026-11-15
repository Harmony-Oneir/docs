# Ядро
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

Проверить в запущенной системе:
```bash
K=/system/lib/modules/$(uname -r)
echo "== 1. config"; (zcat /proc/config.gz 2>/dev/null || echo "нет /proc/config.gz") | grep -E "^CONFIG_(BT|BT_BREDR|BT_LE|BT_RFCOMM|BT_HIDP|BT_HCIBTUSB|UHID)="
echo "== 2. модули в образе"; find $K -name "bluetooth.ko" -o -name "bt*.ko" -o -name "rfcomm.ko" -o -name "hidp.ko" -o -name "uhid.ko" | sed "s|$K/||"
echo "== 3. alias для 0cf3:e500"; grep -i "usb:v0CF3pE500" $K/modules.alias
echo "== 4. зависимости btusb"; grep "btusb.ko:" $K/modules.dep
echo "== 5. загружено"; lsmod | grep -E "^(bluetooth|btusb|btintel|btbcm|btrtl|btmtk|rfcomm|hidp|uhid) "
echo "== 6. контроллер"; ls /sys/class/bluetooth; cat /sys/class/rfkill/*/type
echo "== 7. dmesg"; dmesg | grep -iE "bluetooth|btusb|hci0|qca" | tail -15
```
