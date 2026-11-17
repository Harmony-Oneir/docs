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

Необходимые прошивки для Bluetooth модуля модуля:
```
oneir/firmware/linux-firmware/qca/rampatch_usb_00000302.bin
oneir/firmware/linux-firmware/qca/nvm_usb_00000302.bin
```

# Сборка
Для сборки сервисов используйте команду `./make.sh oneir_bluetooth` в контейнере. Результат сборки находится в каталогах 

**bluetooth hdi**:

* `out/oneir/hdf/drivers_interface_bluetooth/`

**bluetooth service**:

* `out/oneir/communication/bluetooth_service/`

**bluetooth client**:

* `out/oneir/communication/bluetooth/`

SA сервис: [bluetooth_service.json](https://github.com/Harmony-Oneir/oneir/blob/main/profile/bluetooth_service.json). После запуска, Init загружает `foundation/communication/bluetooth_service/services/bluetooth/etc/init/bluetooth_service.cfg`.



# Управление bluetooth через CLI

Инструмент управления bluetooth находится по пути `/system/bin/cli_tool/executable/ohos-bluetoothTool`:

* **Посмотреть состояние**: ohos-bluetoothTool get-state
* **Включить**: ohos-bluetoothTool enable-bt


# Bluetooth Host

`bluetooth_host` — это отдельный процесс HDF, в котором живёт драйвер HCI (`libbluetooth_hci_hdi_driver.z.so`) и публикуется HDI-сервис `hci_interface_service`. Через этот сервис служба `bluetooth_service` получает доступ к контроллеру: стек сам с железом не работает, он только вызывает `IHciInterface::Get()` и обменивается с ним HCI-пакетами (команды, события, ACL, SCO). Хост отделяет стек от железа. Внутри него HDI-драйвер загружает vendor-библиотеку (`libbt_vendor.z.so`), которая знает конкретный транспорт до контроллера — у нас это сокет `HCI_CHANNEL_USER` на `hci0`, на других платах UART. Поэтому смена железа требует замены только vendor-библиотеки, а стек и служба остаются прежними. Кроме того, хост работает в отдельном процессе со своими правами (`NET_ADMIN`/`NET_RAW` для сокета): при падении драйвера страдает только он, а не служба Bluetooth или система целиком. Без `bluetooth_host` у стека нет адресата, и именно поэтому мы получали `hdiInit failed: 2`.

**HCS-запись хоста**. В [device_info.hcs](https://github.com/Harmony-Oneir/oneir/blob/main/hdf_config/uhdf/device_info.hcs):
```
        /* Bluetooth: HCI HDI, контроллер QCA9377 под btusb, доступ через HCI_CHANNEL_USER в libbt_vendor. */
        bluetooth :: host {
            hostName = "bluetooth_host";
            priority = 50;
            caps = ["NET_ADMIN", "NET_RAW"];
            uid = "bluetooth";
            gid = ["bluetooth"];
            bluetooth_device :: device {
                device0 :: deviceNode {
                    policy = 2;
                    priority = 100;
                    moduleName = "libbluetooth_hci_hdi_driver.z.so";
                    serviceName = "hci_interface_service";
                }
            }
        }
```

> После изменения пересборка `./make.sh oneir/hdf_config/uhdf:hdf_config`. `hdf_config` собирает `hdf_default.hcb` и `hdf_devhost.cfg` из `hdf.hcs`. В образ оба файла попадают через `minimal_system_deps.json` / `connectivity_wifi_deps.json`.

Для работы ядра хостовой части необходимо скомпилировать [bt_vendor_oneir](https://github.com/Harmony-Oneir/bt_vendor_oneir/tree/main). Данная цель является частью группы `oneir_bluetooth`.
