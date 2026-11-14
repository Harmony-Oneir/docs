

# netmanager_ext
Компонент расширений сетевого стека (`foundation/communication/netmanager_ext`). Дополняет `netmanager_base` (менеджер подключений, политики, статистика, `netsysnative`) службами для отдельных видов сетей и сетевых функций. На данном этапе нужна служба **Ethernet**: она обнаруживает проводные интерфейсы (`eth0`), получает для них адрес по DHCP (через службу DHCP) и регистрирует сеть в `netmanager`, после чего `netsysnative` создаёт маршруты, настраивает DNS и начинает учёт трафика. Без неё проводной интерфейс приходится настраивать вручную, и для сетевого стека OpenHarmony он остаётся «невидимым»: нет маршрута по умолчанию, DNS и статистики трафика.

# Общая схема
```
 USB-адаптер / PCI-сетевая карта
        │ uevent (add, modalias)
        ▼
 ┌─ ядро 6.6 ──────────────────────────────────────────────────────────────┐
 │  ueventd_module_loader ── modules.alias ──► insmod r8152 / usbnet /     │
 │  (автозагрузка модулей)                     cdc_ether / ...             │
 │                                                    │                    │
 │                                                    ▼                    │
 │                                                  eth0                   │
 └──────────────────────────────────────────────────▲───────▲──────────────┘
                                                    │       │
                         netlink, ioctl, iptables   │       │ DHCP (raw socket)
                                                    │       │
 ┌─ netsysnative (SA 1158) ─────────────────────┐   │   ┌─ wifi_manager_service ──────────┐
 │ libnetsys_native_manager                     │───┘   │ SA 1126 DhcpClient              │
 │ маршруты и ip rule по сетям, iptables,       │       │   libdhcp_client  (по запросу)  │
 │ DNS-прокси (сокет dnsproxyd), fwmarkd, BPF   │       │ WifiNetAgent: сеть Wi-Fi        │
 └──────────────────────▲───────────────────────┘       │   (supplier 1003)               │
                        │ NetsysController (IPC)        └────────▲───────────────┬────────┘
                        │                                        │ DhcpSdk (IPC) │ регистрация
 ┌─ netmanager ─────────┴────────────────────────────────────────┴───────────┐   │ сети Wi-Fi
 │ SA 1157 EthernetService  libethernet_manager                              │   │
 │   читает ethernet_interfaces.json, следит за eth*, запускает DHCP,        │   │
 │   регистрирует проводную сеть (supplier 1004)                             │   │
 │        │                                                                  │   │
 │        ▼                                                                  │   │
 │ SA 1151 NetConnManager  libnet_conn_manager   ◄───────────────────────────┼───┘
 │   выбор лучшей сети, проверка доступа (netdetectionurl.conf)              │
 │ SA 1152 NetPolicy        SA 1153 NetStats                                 │
 └───────────────────────────────────────────────────────────────────────────┘
        ▲ запуск: init (netmanager_base.cfg, netsysnative.cfg), регистрация SA: samgr
```
Порядок событий: адаптер подключён → ueventd грузит драйвер → появляется eth0 → EthernetService поднимает интерфейс и просит адрес у DhcpClient (SA 1126) → адрес назначен на eth0 → EthernetService регистрирует сеть в NetConnManager → NetConnManager через netsysnative создаёт сеть (netId), маршруты и DNS, выполняет проверку доступа и выбирает основную сеть.

## Состав

| Часть | Группа сборки (`service_group`) | Флаг |
| --- | --- | --- | 
| Ethernet | `:ethernet_packages`, `services/etc/init:ethernet.cfg` | `netmanager_ext_feature_ethernet` | 
| Общий доступ к сети (точка доступа, модем через USB) | `:share_packages`, `tools/ohos-networkShare` | `netmanager_ext_feature_share` |
| mDNS (обнаружение устройств в локальной сети) | `:mdns_packages`, `mdnsmanager.rc`, `mdnsmanager_trust`, `sa_profile:mdns_manager_profile` | `netmanager_ext_feature_mdns` |
| VPN | `:vpn_packages`, `:vpn_ext_packages`, `vpnmanager.cfg` | `netmanager_ext_feature_vpn`, `..._vpnext`, `..._sysvpn`, `..._vpn_for_user0` |
| Сетевой брандмауэр | `:netfirewall_packages`, `sa_profile:netfirewall_manager_profile` | `netmanager_ext_feature_net_firewall` |
| Распределённая сеть носимых устройств | `:wearable_distributed_net_packages`, `sa_profile:wearable_distributed_net_manager_profile` | `netmanager_ext_feature_wearable_distributed_net` |
| Сетевые срезы 5G (URSP) | `:networkslice_packages`, `sa_profile:networkslice_manager_profile`, `UrspConfig*_xml`, `reportUrsp` | `netmanager_ext_feature_networkslice` |
| Интерфейсы ArkTS | `frameworks/ets/ani:ani_package` | — |

## Процессы и системные способности

| SA | Процесс | Библиотека | `run-on-create` |
| --- | --- | --- | --- |
| 1161 | `mdnsmanager` | `libmdns_manager.z.so` | да |
| 8300 | `netmanager` | `libnetfirewall_manager.z.so` | нет |
| 8301 | `netmanager` | `libnetworkslice_manager.z.so` | да |
| 8400 | `netmanager` | `libwearable_distributed_net_manager.z.so` | нет |

Профиля службы Ethernet среди профилей `netmanager_ext` нет: её системная способность описана в профилях `netmanager_base` и работает в общем процессе `netmanager`.

## Сборка
Для сборки используйте команду `./make.sh net_all` в контейнере. 

## Конфигурация

| Файл | Назначение |
| --- | --- |
| `services/etc/init/ethernet.cfg` | Задания init для службы Ethernet (каталоги, права) |
| `services/ethernetmanager/config/ethernet_interfaces.json` | Список проводных интерфейсов и способ их настройки (DHCP или статический адрес) |
| `services/etc/init/vpnmanager.cfg`, `mdnsmanager.cfg` | Процессы VPN и mDNS |
