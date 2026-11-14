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

`wpa_supplicant` ожидает файл конфигурации по пути `/data/service/el1/public/wifi/wpa_supplicant/wpa_supplicant.conf`, который устанавливается в систему через файл `wpa_supplicant.conf_module_info.json`.


## Тестирование в QEMU

Следующая команда запуска может быть использована для запуска qemu:
```
cd /mnt/ohos/OpenHarmony7
sudo qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G \
  -kernel out/kernel/OBJ/linux-6.6/arch/x86/boot/bzImage \
  -drive file=out/oneir/ohos-root.img,format=raw,if=virtio \
  -drive file=out/oneir/userdata.img,format=raw,if=virtio \
  -append "root=/dev/vda rw console=ttyS0 selinux=0 hardware=x86_64_oneir init=/system/bin/init quiet loglevel=3" \
  -nographic
```

В терминале необходимо загрузить модуль `mac80211_hwsim.ko` следующей командой:

```
insmod /lib/modules/$(uname -r)/kernel/drivers/net/wireless/virtual/mac80211_hwsim.ko radios=2
```

После этого в системе появятся виртуальные интерфейсы wlan:
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

В новых версиях OpenHarmony `wifi_manager` управляет `wpa_supplicant` через HDI, интерфейс драйверного фреймворка HDF. Ядро `wpa_supplicant` при этом работает внутри хоста HDF (поэтому он и собран библиотекой `libwpa.z.so`), а не отдельным процессом. Это требует HDF: [hdf_devmgr](https://github.com/Harmony-Oneir/docs/tree/main/04.Minimal%20System/Hardware%20Driver%20Foundation), хосты, конфигурацию устройств.

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

# Автоподключение к Wifi для отладки
Поскольку подключение к Wi-Fi происходит при первом сканировании, для отладки надежней всего принудительно инициировать сканирование сети. Для этого можно поместить два файла уже установленную систему:
```bash
hdc shell "mount -o remount,rw /"
hdc file send ~/wifi_autoscan.sh /vendor/bin/wifi_autoscan.sh
hdc file send ~/wifi_autoscan.cfg /vendor/etc/init/wifi_autoscan.cfg
hdc shell "chmod 755 /vendor/bin/wifi_autoscan.sh; chmod 644 /vendor/etc/init/wifi_autoscan.cfg; ls -l /vendor/bin/wifi_autoscan.sh /vendor/etc/init/wifi_autoscan.cfg"
```

Файл `wifi_autoscan.sh`:
```bash

#!/system/bin/sh
# Временный обход для ноутбука без графики:
#  1. wifi_manager считает экран выключенным и не сканирует после загрузки,
#     одного scan-start достаточно для автоподключения;
#  2. маршрут по умолчанию OHOS кладёт в таблицу сети Wi-Fi, а hdcd отвечает
#     через main — добавляем default в main, чтобы hdc работал из других подсетей.
# Убрать после включения wifi_feature_screen_always_on и настройки маршрутов.

W=/system/bin/cli_tool/executable/ohos-wifiManager
GW_FALLBACK=192.168.88.1
LOG=/data/local/tmp/wifi_autoscan.log

log() { echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }

setup_net() {
  # шлюз из маршрутов, которые создал NetsysNative; иначе запасной
  GW=$(ip route show table all 2>/dev/null \
        | sed -n 's/^default via \([0-9.]*\) dev wlan0.*/\1/p' | head -n 1)
  [ -n "$GW" ] || GW=$GW_FALLBACK

  if route -n | grep -q '^0\.0\.0\.0'; then
    log "default route already present"
  else
    route add default gw "$GW" && log "default route via $GW added" \
                               || log "route add via $GW FAILED"
  fi

  begetctl service_control stop hdcd
  begetctl service_control start hdcd
  log "hdcd restarted"
}

log "start"
n=0
while [ $n -lt 30 ]; do
  sleep 10
  n=$((n + 1))

  if ! ifconfig wlan0 2>/dev/null | grep -q 'inet addr'; then
    $W scan-start >/dev/null 2>&1
    log "try $n: no IP, scan requested"
    continue
  fi

  # IP есть — ждём 20 с и убеждаемся, что соединение устойчиво
  sleep 20
  if $W sta-getLinkedInfo 2>/dev/null | grep -q '"detailedState":"Connected"'; then
    log "connected: $($W sta-getLinkedInfo 2>/dev/null)"
    setup_net
    exit 0
  fi
  log "try $n: IP present but not Connected after 20 s"
done

log "gave up after $n tries"
exit 1
```

Файл `wifi_autoscan.cfg`:

```
{
    "jobs" : [{
            "name" : "boot",
            "cmds" : ["start wifi_autoscan"]
        }
    ],
    "services" : [{
            "name" : "wifi_autoscan",
            "path" : ["/system/bin/sh", "/vendor/bin/wifi_autoscan.sh"],
            "uid" : "root",
            "gid" : ["root"],
            "once" : 1,
            "start-mode" : "condition",
            "apl" : "system_basic",
            "permission" : [
                "ohos.permission.GET_WIFI_INFO",
                "ohos.permission.SET_WIFI_INFO",
            		"ohos.permission.GET_WIFI_CONFIG",
            		"ohos.permission.SET_WIFI_CONFIG",
            		"ohos.permission.MANAGE_WIFI_CONNECTION",
            		"ohos.permission.GET_WIFI_LOCAL_MAC",
            		"ohos.permission.GET_WIFI_PEERS_MAC",
            		"ohos.permission.GET_NETWORK_INFO",
            		"ohos.permission.CONNECTIVITY_INTERNAL",
            		"ohos.permission.INTERNET",
            		"ohos.permission.LOCATION",
            		"ohos.permission.APPROXIMATELY_LOCATION",
            		"ohos.permission.cli.MANAGE_WIFI_SCAN",
            		"ohos.permission.cli.MANAGE_WIFI_CONNECT"
            ]
        }
    ]
}
```

# DHCP-сервер
DHCP-сервер OpenHarmony сделан как SA (`1127`) и работает внутри процесса `wifi_manager_service`. Но это не самостоятельный сервис, который можно направить на любой интерфейс: им управляет сам `wifi_manager` через `dhcp_sdk`. Он запускает DHCP-сервер, когда включается режим точки доступа (SA `1121`, `WifiHotspot`), и раздаёт адреса устройствам, подключившимся к раздаче Wi-Fi с этого устройства.

# Раздача Wi-Fi
Режим точки доступа (SoftAP) и раздача интернета с устройства. Проводная сеть при этом служит источником интернета (upstream), а Wi-Fi — раздающим интерфейсом. Для отладки удобно подключаться к стенду по hdc через `eth0`: при переключении `wlan0` в режим точки доступа связь не теряется.

```
 eth0 (интернет) ──NAT──► wlan0 (точка доступа) ◄── клиенты
       ▲                       ▲
 netmanager:              wifi_manager_service:
 SA 1154 NetworkShare     SA 1121 WifiHotspot → HDI hostapd_host → ap_main() из libwpa.z.so
 (iptables MASQUERADE,    SA 1127 DhcpServer — раздаёт адреса клиентам
  ip_forward, маршруты)
```

## Проверка адаптера

Поддержку режима точки доступа можно проверить у запущенного `wpa_supplicant`, без `iw`:

```sh
/vendor/bin/wpa_cli -p /data/service/el1/public/wifi/sockets/wpa -i wlan0 driver_flags
```

В списке должны быть `AP` и `AP_MLME`.

## Состав

| Часть | Цель / файл | SA, процесс | Состояние |
|---|---|---|---|
| Точка доступа | `libwifi_hotspot_ability.z.so`, `libwifi_ap_service.z.so` | 1121, `wifi_manager_service` | в образе |
| HDI hostapd | `//drivers/peripheral/wlan/hostapd:hostapd_entry`, хост `hostapd_host` в `device_info.hcs` (`preload = 2`) | хост HDF, по запросу | в образе |
| Ядро hostapd | `libwpa.z.so` (функция `ap_main`) | внутри `hostapd_host` | в образе (`/vendor/lib64`) |
| Конфиги hostapd | `hostapd.conf`, `hostapd_coex.conf` → `system/etc/wifi/` (собираются через `relation_services`) | — | добавить в образ |
| DHCP-сервер | `//foundation/communication/dhcp/services/dhcp_server:dhcp_server` | 1127, `wifi_manager_service` | добавить |
| Общий доступ (NAT) | `//foundation/communication/netmanager_ext/services/networksharemanager:net_tether_manager` | 1154, `netmanager` | добавить |
| Конфиг общего доступа | `...networksharemanager:network_share_config` | — | добавить |
| Утилита | `//foundation/communication/netmanager_ext/tools/ohos-networkShare:ohos-networkShare` | — | добавить |
| Модули NAT | `iptable_nat.ko`, `xt_MASQUERADE.ko`, `xt_nat.ko` в `/lib/modules/6.6.101/kernel/net/` | ядро | в образе |

Исполняемые файлы `/vendor/bin/hostapd` и `hostapd_cli` для работы через `wifi_manager` не нужны: HDI-служба вызывает `ap_main()` из `libwpa.z.so` внутри своего процесса. Отдельный `hostapd` нужен только для ручных тестов (например, точка доступа на `mac80211_hwsim` в QEMU).

## Сборка

Сборка происходит в контейнере:
```sh
./oneir/make.sh hotspot
```

## Профили SA

| Профиль | Добавить |
|---|---|
| `oneir/profile/wifi_manager_service.json` | SA `1127` (`libdhcp_server.z.so`) из `dhcp/services/sa_profile/profiles/1127.json` |
| `oneir/profile/netmanager.json` | SA `1154` (`libnet_tether_manager.z.so`) из `netmanager_base/sa_profile/profiles/1154.json` |
