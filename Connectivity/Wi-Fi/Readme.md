# Введение
Для реализации Wi-Fi необходимо следующее:
| Слой | Что это | Откуда взять |
|---|---|---|
| 1. Драйвер в ядре | `cfg80211`, `mac80211` и драйвер вашего чипа | Конфиг ядра |
| 2. Прошивка чипа | Бинарный файл, который драйвер загружает в адаптер | Пакет `linux-firmware` |
| 3. Подключение к сети | `wpa_supplicant`: поиск сети, авторизация WPA2 | `third_party/wpa_supplicant` из OpenHarmony |
| 4. IP-адрес | DHCP-клиент или статический адрес | `dhcp_client` из OpenHarmony или `ifconfig` из Toybox |

В полноценной реализации над этим работают ещё `wifi_manager`, `netmanager` и HAL Wi-Fi через HDF.

# Сборка


**Сборка wpa_supplicant.** В OpenHarmony `wpa_supplicant` по умолчанию собирается для работы через драйверный фреймворк HDF. Чтобы он работал со стандартными драйверами Wi-Fi Linux (любой адаптер, поддерживаемый ядром), сборка переключена на интерфейс `nl80211` аргументом GN `wpa_supplicant_driver_nl80211 = true`. Результат — `wpa_supplicant`, `wpa_cli` и библиотека `libwpa.z.so`, которые устанавливаются в раздел `vendor`.

Для сборки используйте команду `./make.sh network`. Результат сборки находится по пути `out/oneir/thirdparty/wpa_supplicant/ `:

| Название | Описание |
|---|---|
| `libwpa.z.so` | Основная библиотека wpa_supplicant: поиск сетей, ассоциация с точкой доступа, авторизация WPA/WPA2/WPA3, работа с драйвером через `nl80211`. В OpenHarmony ядро wpa_supplicant собрано отдельной библиотекой, чтобы его могли использовать и исполняемый файл, и Wi-Fi HAL системы |
| `wpa_supplicant` | Демон подключения к Wi-Fi. Небольшая программа-оболочка, которая загружает `libwpa.z.so`, читает конфигурацию (`-c wpa_supplicant.conf`), работает с интерфейсом (`-i wlan0`) и держит соединение с сетью |
| `wpa_cli` | Консольный клиент для управления запущенным `wpa_supplicant` через его управляющий сокет: сканирование (`scan`, `scan_results`), добавление сети (`add_network`, `set_network`), подключение и просмотр состояния (`status`) |
|`hostapd`| Демон точки доступа Wi-Fi: превращает адаптер в точку доступа, рассылает её имя (SSID), принимает подключения клиентов и проводит авторизацию WPA/WPA2/WPA3. Работает с драйвером через `nl80211`, использует ту же библиотеку `libwpa.z.so`, что и `wpa_supplicant`. В проекте нужен для тестов в QEMU: создаёт тестовую сеть на виртуальном адаптере `mac80211_hwsim` |
|`hostapd_cli`| Консольный клиент для управления запущенным `hostapd` через его управляющий сокет: список подключённых клиентов (`all_sta`), состояние точки доступа (`status`), отключение клиента, перечитывание конфигурации |

Конфиг сервиса для init лежит в `oneir/rootfs/vendor/etc/init/wpa_supplicant.cfg`. 

**Сервис.** `wpa_supplicant` описан как сервис init, работающий от пользователя `wifi` с правами на настройку сети. Сам он не запускается: его стартуют явно, когда в системе появляется интерфейс `wlan0`. При первой загрузке init создаёт в `/data` пустой файл конфигурации с разрешением на запись. Сеть настраивается один раз через `wpa_cli` и сохраняется командой `save_config`, после чего подключение происходит автоматически при каждой загрузке.


## Тестирование в QEMU

Для теста Wi-Fi через mac80211_hwsim в QEMU ничего добавлять не нужно: виртуальные адаптеры создаёт само ядро, без отдельного устройства:
```
cd /mnt/ohos/OpenHarmony7
sudo qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G \
  -kernel out/kernel/OBJ/linux-6.6/arch/x86/boot/bzImage \
  -drive file=out/oneir/ohos-root.img,format=raw,if=virtio \
  -drive file=out/oneir/userdata.img,format=raw,if=virtio \
  -append "root=/dev/vda rw console=ttyS0 selinux=0 hardware=x86_64_oneir init=/system/bin/init quiet loglevel=3" \
  -nographic
```

Внутри проверка интерфейсов:
```
# ifconfig -a
lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0 
          inet6 addr: ::1/128 Scope: Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0 
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0 
          collisions:0 txqueuelen:1000 
          RX bytes:0 TX bytes:0 

eth0      Link encap:Ethernet  HWaddr 52:54:00:12:34:56  Driver e1000
          BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0 
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0 
          collisions:0 txqueuelen:1000 
          RX bytes:0 TX bytes:0 

wlan0     Link encap:Ethernet  HWaddr 02:00:00:00:00:00  Driver mac80211_hwsim
          BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0 
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0 
          collisions:0 txqueuelen:1000 
          RX bytes:0 TX bytes:0 

wlan1     Link encap:Ethernet  HWaddr 02:00:00:00:01:00  Driver mac80211_hwsim
          BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0 
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0 
          collisions:0 txqueuelen:1000 
          RX bytes:0 TX bytes:0 

hwsim0    Link encap:UNSPEC  
          BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0 
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0 
          collisions:0 txqueuelen:1000 
          RX bytes:0 TX bytes:0 

sit0      Link encap:IPv6-in-IPv4  
          NOARP  MTU:1480  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0 
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0 
          collisions:0 txqueuelen:1000 
          RX bytes:0 TX bytes:0
```
