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

Для проверки работы запустите точку доступа Wi-fi следующей командой:
```bash
mkdir -p /data/local/tmp/ap
cat > /data/local/tmp/ap/hostapd.conf << 'EOF'
interface=wlan1
driver=nl80211
ssid=oneir-test
hw_mode=g
channel=6
wpa=2
wpa_passphrase=testpassword
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
/vendor/bin/hostapd -B /data/local/tmp/ap/hostapd.conf
```

Сканирование:
```bash
W="/vendor/bin/wpa_cli -p /data/service/el1/public/wifi/sockets/wpa -i wlan0"
$W scan; sleep 3; $W scan_results
```

Подключение:
```bash
$W add_network
$W set_network 0 ssid '"oneir-test"'
$W set_network 0 psk '"testpassword"'
$W enable_network 0
sleep 5; $W status
```

Передача данных:
```bash
ifconfig wlan1 192.168.50.1 netmask 255.255.255.0 up
ifconfig wlan0 192.168.50.2 netmask 255.255.255.0 up
ping -c 3 -I wlan0 192.168.50.1
```

Сохранение:

```bash
$W save_config
cat /data/service/el1/public/wifi/wpa_supplicant/wpa_supplicant.conf
```

# Как wifi_manager общается с wpa_supplicant?

В новых версиях OpenHarmony `wifi_manager` управляет `wpa_supplicant` через HDI, интерфейс драйверного фреймворка HDF. Ядро `wpa_supplicant` при этом работает внутри хоста HDF (поэтому он и собран библиотекой `libwpa.z.so`), а не отдельным процессом. Это требует HDF: [hdf_devmgr](https://github.com/Harmony-Oneir/docs/tree/main/Graphics/Hardware%20Driver%20Foundation), хосты, конфигурацию устройств.

У wifi есть флаги:

| Флаг | По умолчанию | Что делает |
|---|---|---|
| `wifi_feature_with_hdi_wpa_supported` | `true` | `wifi_manager` управляет `wpa_supplicant` через HDI (требует HDF) |
| `wifi_feature_non_hdf_driver` | `false` | Работа с драйвером Wi‑Fi без HDF |
| `CONFIG_CTRL_IFACE` | `"unix"` | Управление `wpa_supplicant` через UNIX-сокет |

Данные флаги указываются в [описании продукта](https://github.com/Harmony-Oneir/productdefine/blob/main/common/products/oneir.json). 

В режиме `non_hdf_driver` `wifi_manager` не обращается к `wpa_supplicant` напрямую. Он посылает команды отдельному процессу `wifi_hal_service`. А уже `wifi_hal_service` запускает `wpa_supplicant` и управляет им через его сокет.

Собрать сетевой стек можно командой `./make.sh netstack` в контейнере. Результат сборки `out/oneir/communication/netmanager_base/`:
| Название | Описание |
|---|---|
| `libnetsys_native_manager.z.so` | Реализация SA **NetsysNative**: единственный сервис, который напрямую меняет сетевые настройки ядра. Назначает интерфейсам IP-адреса, прописывает маршруты, управляет правилами `iptables`, содержит DNS-резолвер и сервер меток сокетов (fwmark) |
| `libnetsys_controller.z.so` | Прослойка для системных сервисов: превращает вызовы вида «добавить маршрут», «назначить адрес» в обращения к NetsysNative. Через неё работает `net_conn_manager` |
| `libnet_native_manager_if.z.so` | Клиентский интерфейс (IPC-прокси) SA NetsysNative для других процессов |
| `libnetsys_client.z.so` | Клиентская библиотека для DNS-запросов через резолвер NetsysNative. Её использует libc при разрешении имён (`getaddrinfo`), чтобы запросы шли через системный DNS с учётом выбранной сети |
| `libfwmark_client.z.so` | Клиент сервера меток сокетов: помечает сокет приложения номером сети и uid, чтобы ядро направляло его трафик по правильному маршруту |
| `libnetsys_bpf_utils.z.so` | Работа с eBPF: загрузка программ и доступ к картам eBPF в ядре. Используется для статистики трафика и ограничений доступа |
| `libnet_conn_manager.z.so` | Реализация SA **NetConnManager**: учёт доступных сетей (Wi-Fi, Ethernet, мобильная), выбор сети по умолчанию, проверка доступности интернета, уведомление приложений об изменениях |
| `libnet_conn_manager_if.z.so` | Клиентский интерфейс SA NetConnManager. Через него, например, `wifi_manager` регистрирует сеть Wi-Fi после подключения |
| `libnet_policy_manager.z.so` | Реализация SA **NetPolicy**: политики доступа к сети для приложений (запрет фонового трафика, лимитные сети, режим экономии) |
| `libnet_policy_manager_if.z.so` | Клиентский интерфейс SA NetPolicy |
| `libnet_stats_manager.z.so` | Реализация SA **NetStats**: сбор статистики трафика по интерфейсам и приложениям (через eBPF) |
| `libnet_stats_manager_if.z.so` | Клиентский интерфейс SA NetStats |
| `libnet_security_config_if.z.so` | Конфигурация сетевой безопасности приложений: доверенные сертификаты, закрепление сертификатов (pinning), запрет незашифрованного трафика |
| `libnet_manager_common.z.so` | Общие функции всех компонентов netmanager: журналирование, проверка прав, вспомогательные утилиты |
| `libnet_service_common.z.so` | Общий код сервисов netmanager: обработка системных событий, общие структуры данных |
| `libnet_data_share.z.so` | Доступ к системной базе настроек через DataShare: режим полёта, глобальный прокси и другие сетевые настройки |

Папка `out/oneir/communication/dhcp/`:
| Название | Описание |
|---|---|
| `libdhcp_client.z.so` | Реализация DHCP-клиента: отправляет в сеть запросы DHCP (Discover, Request), получает аренду адреса (IP, маску, шлюз, DNS-серверы, срок аренды) и продлевает её. Работает как системная способность (SA) и сообщает результат через обратный вызов тому, кто запустил DHCP |
| `libdhcp_sdk.z.so` | Клиентский интерфейс для других сервисов: «запусти DHCP на интерфейсе», «останови», «сообщи результат». Через него `wifi_manager` после подключения к сети просит получить адрес для `wlan0` |
| `libdhcp_utils.z.so` | Общие функции клиента и сервера DHCP: работа с адресами и сетевыми интерфейсами, разбор пакетов, журналирование |

Папка `out/oneir/communication/wifi/`:

| Название | Описание |
|---|---|
| `libwifi_manager_service.z.so` | Ядро менеджера Wi-Fi: конечный автомат подключения клиента (STA), работа с `wpa_supplicant`, хранение сохранённых сетей, выбор сети для автоподключения, запуск DHCP после подключения и регистрация сети в `net_conn_manager` |
| `libwifi_device_ability.z.so` | SA **WifiDevice** (режим клиента): интерфейс для включения и выключения Wi-Fi, подключения к сети, получения состояния и информации о текущем соединении |
| `libwifi_scan_ability.z.so` | SA **WifiScan**: запуск сканирования и выдача списка найденных сетей |
| `libwifi_hotspot_ability.z.so` | SA **WifiHotspot**: интерфейс режима точки доступа (раздача Wi-Fi с устройства) |
| `libwifi_ap_service.z.so` | Реализация режима точки доступа: управление `hostapd`, учёт подключённых устройств |
| `libwifi_p2p_ability.z.so` | SA **WifiP2p**: интерфейс Wi-Fi Direct (прямое соединение устройств без роутера) |
| `libwifi_p2p_service.z.so` | Реализация Wi-Fi Direct: поиск устройств, создание групп |
| `libwifi_sdk.z.so` | Клиентский интерфейс для других сервисов и утилит: обращения к SA Wi-Fi через IPC. Через него работает `ohos-wifiManager` |
| `libwifi_base.z.so` | Общие структуры данных и базовые функции компонента Wi-Fi |
| `libwifi_utils.z.so` | Вспомогательные функции: работа с адресами, строками, файлами конфигурации, журналирование |
| `ohos-wifiManager` | Консольная утилита для управления Wi-Fi: включить и выключить, просканировать, подключиться к сети, посмотреть состояние. Работает через `libwifi_sdk` |

