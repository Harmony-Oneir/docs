

# netmanager_ext
Компонент расширений сетевого стека (`foundation/communication/netmanager_ext`). Дополняет `netmanager_base` (менеджер подключений, политики, статистика, `netsysnative`) службами для отдельных видов сетей и сетевых функций. На данном этапе нужна служба **Ethernet**: она обнаруживает проводные интерфейсы (`eth0`), получает для них адрес по DHCP (через службу DHCP) и регистрирует сеть в `netmanager`, после чего `netsysnative` создаёт маршруты, настраивает DNS и начинает учёт трафика. Без неё проводной интерфейс приходится настраивать вручную, и для сетевого стека OpenHarmony он остаётся «невидимым»: нет маршрута по умолчанию, DNS и статистики трафика.
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

## Конфигурация

| Файл | Назначение |
| --- | --- |
| `services/etc/init/ethernet.cfg` | Задания init для службы Ethernet (каталоги, права) |
| `services/ethernetmanager/config/ethernet_interfaces.json` | Список проводных интерфейсов и способ их настройки (DHCP или статический адрес) |
| `services/etc/init/vpnmanager.cfg`, `mdnsmanager.cfg` | Процессы VPN и mDNS |
