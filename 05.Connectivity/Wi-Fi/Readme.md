# Введение
Для работы с Wi-Fi в Open Harmony существует SA сервис `wifi_manager`. Данный сервис не связывается в Wi-Fi модулем напрямую. Для связи с железом `wifi_manager` использует `wpa_supplicant` (нужен для режима клиента и Wi-Fi Direct), `hostapd` (для режима точки доступа). Таким образом вся работа с железом идёт через HDI-сервисы в хостах HDF.

Для реализации Wi-Fi необходимо следующее:
| Слой | Что это | Откуда взять |
|---|---|---|
| 1. Драйвер в ядре | `cfg80211`, `mac80211` и драйвер вашего чипа | Конфиг ядра |
| 2. Прошивка чипа | Бинарный файл, который драйвер загружает в адаптер | Пакет `linux-firmware` |
| 3. Подключение к сети | `wpa_supplicant`: поиск сети, авторизация WPA2 | `third_party/wpa_supplicant` из OpenHarmony |
| 4. IP-адрес | DHCP-клиент или статический адрес | `dhcp_client` из OpenHarmony или `ifconfig` из Toybox |

Перед продолжением примените патчи из списка [wifi](https://github.com/Harmony-Oneir/oneir_patches/tree/main/wifi).

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

| Флаг |  Что делает |
|---|---|
| `wifi_feature_with_hdi_wpa_supported` | `wifi_manager` управляет `wpa_supplicant` через HDI (требует HDF) |
| `wifi_feature_non_hdf_driver` | Работа с драйвером Wi‑Fi без HDF |
| `CONFIG_CTRL_IFACE` | Управление `wpa_supplicant` через UNIX-сокет |
| `drivers_peripheral_wlan_feature_enable_HDF_NL80211` | Включает работу через netlink со стандартными драйверами Linux.|

Данные флаги указываются в [описании продукта](https://github.com/Harmony-Oneir/productdefine/blob/main/common/products/oneir.json). 
> **Примечание**: в OpenHarmony 7.0 отсутствует кодовая база для работы в режиме `non hdf`. Поэтому перед продолжением убедитесь, что сервисы hdf работают в вашей системе. Флаги сборки компонента wifi должны стоять следующим образом:
> `"wifi_feature_with_hdi_wpa_supported = false",`
> `"wifi_feature_non_hdf_driver = true",`

Параметр `wifi_feature_with_hdi_chip_supported` решает, будет ли `wifi_manager` работать с адаптером через HDI-сервис чипа (chip_interface_service). Этот сервис отвечает за:
* создание и удаление интерфейсов (клиент, точка доступа, P2P) и их сочетания;
* запуск сканирования и получение его результатов;
* сведения о возможностях чипа (поддерживаемые диапазоны, стандарты, категория вроде Wi-Fi 6/7);
* питание, код страны, часть настроек энергосбережения.

При значении false сканирование сети должно идти через `wpa_supplicant`, то есть через HDI wpa. Это классическая схема для стандартных драйверов Linux: `wpa_supplicant` сам умеет запускать сканирование (команда SCAN, внутри — `NL80211_CMD_TRIGGER_SCAN`) и отдавать результаты (`SCAN_RESULTS`).
В версии OpenHarmony 7.0 сканирование реализовано только через сервис чипа, и без него оно не работает, поэтому флаг включён. 

Собрать сетевой стек можно командой `./make.sh netstack` в контейнере. Результат сборки находится в папке `out/oneir/communication/netmanager_base/`:
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


# Сборка драйверной части
Что бы сервис HDF знал, что запускать, соберем группу `hdf_wlan` командой `./make.sh hdf_wlan` в контейнере. Конфигурация HDF находится в репозитории [hdf_config/uhdf](https://github.com/Harmony-Oneir/oneir/tree/main/hdf_config/uhdf).

### Состав группы

| Цель | Что собирает |
|---|---|
| `//drivers/peripheral/wlan:wlan_entry` | Сервис адаптера `wlan_interface_service` и `wifi_hal`, работающий с драйвером через `nl80211` |
| `//drivers/peripheral/wlan/chip:wlan_chip_entry` | Сервис чипа `chip_interface_service` и его реализацию `wifi_hal_default` поверх `nl80211` |
| `//drivers/peripheral/wlan/wpa:wpa_entry` | Сервис `wpa_interface_service`, внутри которого работает ядро `wpa_supplicant` (`libwpa`) |
| `//drivers/peripheral/wlan/hostapd:hostapd_entry` | Сервис `hostapd_interface_service` для режима точки доступа |
| `//oneir/hdf_config/uhdf:hdf_config` | `hdf_default.hcb` (описание хостов и устройств для `hdf_devmgr`) и `hdf_devhost.cfg` (конфиги init для запуска хостов) |

### Флаги продукта

Драйверный слой собирается для стандартных драйверов Linux, по образцу rk3568. В описании продукта (`productdefine/common/products/oneir.json`) для компонента `drivers_peripheral_wlan` заданы:

| Флаг | Значение | Назначение |
|---|---|---|
| `drivers_peripheral_wlan_feature_enable_HDF_NL80211` | `true` | Работа с ядром через `nl80211` |
| `drivers_peripheral_wlan_feature_vendor` | `default` | Реализация сервиса чипа по умолчанию, без кода производителя |
| `drivers_peripheral_wlan_feature_enable_HDF_WLAN_EXTEND_VDI` | `false` | Без расширения производителя (`libhdi_wlan_impl.z.so`) |
| `drivers_peripheral_wlan_p2p_name` | `p2p-dev-wlan0` | Имя интерфейса Wi-Fi Direct |
| `drivers_peripheral_wlan_feature_enable_HDF_UT` | `false` | Без тестового режима |

После изменения флагов настройки сборки нужно пересоздать: `./make.sh --reload hdf_wlan`.

### Хосты

Файл `device_info.hcs` описывает три хоста Wi-Fi:

| Хост | Сервисы | Запуск |
|---|---|---|
| `wifi_host` | `wlan_interface_service`, `chip_interface_service` | При загрузке |
| `wpa_host` | `wpa_interface_service` | По запросу `wifi_manager` (`preload = 2`) |
| `hostapd_host` | `hostapd_interface_service` | По запросу (`preload = 2`) |

Номера хостов в `hdf_devhost.cfg` вычисляются из `device_info.hcs`, поэтому после любого изменения конфигурации файлы `hdf_default.hcb` и `hdf_devhost.cfg` нужно ставить в образ вместе.

### Проверка

После загрузки системы хост `wifi_host` должен быть запущен, а оба его сервиса инициализированы без ошибок:

```sh
ps -A -o PID,USER,NAME | grep -E "hdf_devmgr|_host"
hilog -x | grep -i "HDF_WIFI_CORE" | tail -10
```

Хосты `wpa_host` и `hostapd_host` появятся только после включения Wi-Fi (`ohos-wifiManager sta-enable`) или запуска точки доступа соответственно.

# wifi_manager_service

`wifi_manager_service` — это процесс, в котором работают несколько SA: `1120` (режим клиента), `1121` (точка доступа), `1123` (Wi-Fi Direct), `1124` (сканирование), а также DHCP-клиент и сервер (`1126`, `1127`).

Описание перечисленных SA сервисов находятся в репозитори [oneir/profile](https://github.com/Harmony-Oneir/oneir/tree/main/profile) (`wifi_manager_service.json`, `netsysnative.json`, `netmanager.json`). При сборке образа они копируются в `/system/profile/`.

Для работы с wi-fi у процесса должны быть соответствующие разрешения. В OpenHarmony root (uid 0) не даёт прав автоматически. Права проверяются по токену доступа процесса. У каждого процесса есть токен, а у токена — список разрешений. CLI инструмент для управления `wifi_manager` (`/system/bin/cli_tool/executable/ohos-wifiManager`) запускается из консоли и наследует её токен. Консоль запускает init по конфигу [console.cfg](https://github.com/Harmony-Oneir/productdefine/blob/main/rootfs/system/etc/init/console.cfg). Таким образом разрешения должны быть перечислены в нем. 

## Флаги компонента wifi

### wifi_feature_with_scan_control 
Флаг превращается в макрос SUPPORT_SCAN_CONTROL (в wifi_scan и wifi_toolkit). Сканирование Wi-Fi расходует энергию и занимает радиоканал, поэтому `wifi_manager` не сканирует «по каждому запросу», а применяет политику управления сканированием. Флаг `wifi_feature_with_scan_control` (по умолчанию `true`) включает в сборке макрос `SUPPORT_SCAN_CONTROL`, а с ним — правила, которые ограничивают сканирование в зависимости от сценария работы устройства: подключён ли Wi-Fi, в каком состоянии приложение, запросившее сканирование (на переднем плане или в фоне), и некоторые особые ситуации (например, игровой режим). Для каждого сценария задаётся, какие виды сканирования разрешены (запрос приложения, периодическое системное, фоновое `Pno`) и с каким интервалом. Связанный флаг `wifi_feature_with_scan_control_action_listen` дополнительно учитывает действия пользователя. Независимо от этого флага сканирование всегда привязано к состоянию экрана. При включённом экране и отключённом Wi-Fi `wifi_manager` периодически выполняет системное сканирование, а при выключенном оставляет только фоновое сканирование `Pno`, которое выполняет сам чип в режиме энергосбережения. Состояние экрана `wifi_manager` определяет при запуске, запрашивая менеджер питания (`PowerMgrClient::IsScreenOn()`), а затем обновляет по событиям включения и выключения экрана, приходящим через CES. Если этих сервисов в системе нет, при запуске устанавливается состояние «экран выключен», и оно больше не меняется. Тогда при отсутствии поддержки `Pno` в драйвере после загрузки не выполняется ни одного сканирования, и автоподключение к сохранённой сети не срабатывает, хотя сама сеть и её пароль сохранены корректно; достаточно одного сканирования по запросу (`ohos-wifiManager scan-start`), чтобы `wifi_manager` подключился. Поэтому выключение `wifi_feature_with_scan_control` эту проблему не решает: для автоподключения `wifi_manager` должен знать, что экран включён.

### wifi_feature_screen_always_on
Флаг продукта, добавленный патчем [wifi/0002-wifi-add-wifi_feature_screen_always_on.patch](https://github.com/Harmony-Oneir/oneir_patches/blob/main/wifi/0002-wifi-add-wifi_feature_screen_always_on.patch). По умолчанию `false`: поведение OpenHarmony не меняется.

`wifi_manager` учитывает состояние экрана во многих подсистемах: сканировании, режиме клиента, самовосстановлении соединения, умном выборе сети, Wi-Fi Direct. Состояние экрана он определяет при запуске, запрашивая менеджер питания (`PowerMgrClient::IsScreenOn()`), а затем обновляет по событиям включения и выключения экрана через CES. Менеджер питания, в свою очередь, получает состояние от менеджера дисплея, а тот — от графического стека. На продукте без этих компонентов запрос не проходит, и `wifi_manager` навсегда считает экран выключенным. Самое заметное следствие: периодическое системное сканирование выполняется только при включённом экране, поэтому после загрузки Wi-Fi не подключается к сохранённой сети, хотя сеть и пароль сохранены, а состояние «Wi-Fi включён» восстанавливается.

При `wifi_feature_screen_always_on = true` (макрос `WIFI_FEATURE_SCREEN_ALWAYS_ON`) `wifi_manager` считает экран всегда включённым: начальное состояние устанавливается без обращения к менеджеру питания, а события выключения экрана его не меняют. Все подсистемы Wi-Fi работают так же, как на устройстве с включённым экраном. Флаг предназначен для продуктов, где состоянием экрана никто не управляет: ПК без менеджера питания и дисплея, безэкранные устройства. Когда в продукте появятся менеджер питания и графический стек, флаг стоит выключить, чтобы вернуть штатное поведение с экономией энергии при выключенном экране.

Включение в описании продукта (`productdefine/common/products/oneir.json`, раздел компонента `wifi`), затем пересоздание настроек сборки (`./oneir/make.sh --reload rootfs_netstack`):

```json
"wifi_feature_screen_always_on = true"
```

## Сборка

Для сборки выполните команду `./make.sh netstack` в контейнере. Результаты сборки наход в `out/oneir/communication/wifi/`, `out/oneir/communication/dhcp/` и `out/oneir/communication/netmanager_base/`.

## Управление через ohos-wifiManager

Утилита лежит в каталоге CLI-инструментов и не входит в `PATH`:

```sh
export PATH=$PATH:/system/bin/cli_tool/executable
```

| Команда | Действие |
|---|---|
| `sta-enable` | Включить Wi-Fi в режиме клиента |
| `sta-disable` | Выключить Wi-Fi |
| `scan-start` | Запустить сканирование |
| `scan-list` | Показать результаты последнего сканирования |
| `sta-connect --ssid <имя> --preSharedKey <пароль>` | Подключиться к сети |
| `sta-getLinkedInfo` | Состояние текущего подключения |

Ответы выводятся в формате JSON. Сканирование занимает несколько секунд, поэтому `scan-list` сразу после `scan-start` может вернуть пустой список.

Пример сценария:

```sh
ohos-wifiManager sta-enable; sleep 3; ohos-wifiManager sta-enable
ohos-wifiManager scan-start; sleep 6; ohos-wifiManager scan-list
ohos-wifiManager sta-connect --ssid oneir-test --preSharedKey testpassword
sleep 10; ohos-wifiManager sta-getLinkedInfo
```

# DHCP-сервер
DHCP-сервер OpenHarmony сделан как SA (`1127`) и работает внутри процесса `wifi_manager_service`. Но это не самостоятельный сервис, который можно направить на любой интерфейс: им управляет сам `wifi_manager` через `dhcp_sdk`. Он запускает DHCP-сервер, когда включается режим точки доступа (SA `1121`, `WifiHotspot`), и раздаёт адреса устройствам, подключившимся к раздаче Wi-Fi с этого устройства.
