# Common Event Service (CES)

## Назначение

CES (Common Event Service, служба общих событий) — механизм рассылки системных событий в OpenHarmony. Одни сервисы и приложения **публикуют** события («экран включён», «подключено питание», «сеть изменилась», «пользователь разблокирован» и т.п.), другие **подписываются** на нужные события и получают их. Публикующий не знает, кто получит событие, а подписчик — кто его отправил: CES связывает их через системную способность **SA 3299**.

Кроме рассылки CES:
- проверяет права: системные события (`usual.event.*`) могут публиковать только сервисы с разрешением `ohos.permission.PUBLISH_SYSTEM_COMMON_EVENT`, а некоторые события получают только подписчики с нужными разрешениями;
- хранит «липкие» события (sticky): последнее значение такого события получает каждый новый подписчик, даже если подписался позже публикации;
- запускает «статических подписчиков» — приложения, объявившие подписку в своём описании, даже если они не работают в момент события (требует менеджера приложений).

Без CES сервисы, которые подписываются на события при запуске, повторяют попытки подписки и пишут ошибки в журнал (в минимальной системе это был самый частый источник ошибок: обращения к SA 3299, `Ces`, `WifiEventSubscriberManager`). Некоторые сервисы прямо ждут его появления перед инициализацией: например, служба Ethernet (SA 1157) настраивает проводные интерфейсы, только когда в системе есть и менеджер подключений (SA 1151), и CES.

## Процесс foundation

CES — не отдельный процесс. Его системная способность работает в общем процессе **`foundation`** (`process: foundation` в профиле `sa_profile/3299.json`), где в полной системе вместе работают основные службы: менеджер приложений, менеджер пакетов, CES и другие. Конфиг init этого процесса (`foundation.cfg`) принадлежит компоненту `safwk` (`foundation/systemabilitymgr/safwk/etc/profile`) и рассчитан на все его службы:
Поэтому в `oneir` используется свой минимальный конфиг в файлах платы, `oneir/rootfs/system/etc/init/foundation.cfg`: процесс `foundation` от пользователя `foundation` (группа `system`, `apl: system_core`), без `critical`, `bootevents` и лишних групп, с разрешениями, которые нужны CES, и созданием его каталогов в `/data` (`/data/service/el1/public/notification`, `/data/service/el1/public/database/common_event_service`). Профиль процесса `/system/profile/foundation.json` содержит SA 3299 (`run-on-create: true`). Когда в систему будут добавлены другие службы `foundation`, конфиг нужно будет расширить.

## Сборка

Группа в `oneir/BUILD.gn`:

```gn
group("ces") {
  deps = [
    "//base/notification/common_event_service/services:cesfwk_services",
    "//base/notification/common_event_service/sa_profile:event_sa_profile",
    "//base/notification/common_event_service/tools:tools_target",
  ]
}
```

```bash
./oneir/make.sh --reload ces
```

Результат сборки находится по пути `out/oneir/notification/common_event_service/`.

Модуль | Путь в образе | Назначение |
| --- | --- | --- |
| `cesfwk_services` | `/system/lib64/libcesfwk_services.z.so` | Служба CES (SA 3299) |
| `cesfwk_core` | `/system/lib64/platformsdk/libcesfwk_core.z.so` | Ядро клиентской части: IPC-прокси, структуры событий и подписок |
| `cesfwk_innerkits` | `/system/lib64/platformsdk/libcesfwk_innerkits.z.so` | Клиентский интерфейс для системных сервисов (`CommonEventManager::PublishCommonEvent`, `SubscribeCommonEvent`) |
| `static_subscriber_ipc` | `/system/lib64/libstatic_subscriber_ipc.z.so` | IPC статических подписчиков |
| `cem` | `/system/bin/cem` | Консольная утилита: публикация событий и просмотр подписчиков |
| `ces.para`, `ces.para.dac` | `/system/etc/param/` | Параметры CES и права доступа к ним |

## Проверка

```sh
ps -A -o PID,USER,NAME | grep foundation      # процесс foundation от пользователя foundation
hilog -x | grep "SA:3299" | tail -3           # публикация SA и уведомления ожидающих её сервисов
cem dump -a | head -20                        # подписчики и их события
```

Опубликовать событие для проверки:

```sh
cem publish -e usual.event.SCREEN_ON
```

## Тесты

Модульных тестов (`ohos_unittest`) в компоненте нет. Есть системные тесты (`ohos_systemtest`), которые работают с настоящей службой CES (SA 3299), и тесты производительности (`ohos_benchmarktest`).

| Тест | Описание |
| --- | --- |
| `cesSystemTest` | Основные сценарии службы: подписка и отписка, публикация событий, получение событий подписчиком, липкие события |
| `cesCheckService` | Проверка доступности и работоспособности службы CES через её интерфейс |
| `CESPublishOrderedEventSystmTest` | Упорядоченные события: доставка подписчикам по приоритету, передача результата от одного подписчика к следующему, прерывание рассылки |
| `ActsCesSpecificationTest` | Соответствие спецификации CES: поведение публичного интерфейса в граничных и ошибочных случаях |
| `ActsCESSubscribeInfoTest` | Описание подписки (`CommonEventSubscribeInfo`): приоритет, права, пользователь, условия подписки |
| `ActsCESCESpublishInfoTest` | Параметры публикации (`CommonEventPublishInfo`): липкость, упорядоченность, требуемые права подписчиков |
| `ActsCESMatchingSkillsTest` | Условия совпадения события с подпиской (`MatchingSkills`): события, сущности, схемы |
| `ActsCESManagertest` | Клиентский интерфейс `CommonEventManager` для системных сервисов: публикация и подписка через него |
| `Common_Event_Manager_Service_Test` | Производительность операций службы |
| `Common_Event_Publish_Test` | Производительность публикации событий |

Для сборки тестов используйте команду `./make.sh ces_test` в контейнере.

## Результаты системных тестов

Основные механизмы работают: подписка с условиями (`CES_SubscriptionEventTheme_*`, `CES_VerifyMatchingSkills_*`), права на события (`CES_SetEventAuthority_0100`–`0700`), ограничение числа подписчиков (`CES_SubscriberMaxSize_*`), тайм-ауты упорядоченной доставки (`CES_PublishOrderTimeOut_*`), получение объекта службы (`CES_GetServiceObject_0100`). Падения делятся на группы:

| Группа | Примеры | Причина |
| --- | --- | --- |
| Подписчик не получил событие за 5 секунд | `cesCheckService.CES_ReceiveEvent_0100`, `cesSystemTest.CES_ReceiveEvent_0100/0300/0400`, `CES_SendEvent_1600`, `CES_SetEventAuthority_1200` | Нет менеджера пакетов, см. ниже |
| Упорядоченные события: неверный результат или подписчики не вызваны | `CommonEventPublishOrderedEventTest_0100/0200/0500/0600`, `ActsCESManagertest.CES_SendEvent_1700/1800` | Та же: задержка доставки одному из подписчиков цепочки |
| Ожидался отказ, а операция прошла | `CES_SendEvent_1300/1400/1500`, `CES_SetEventAuthority_0800`, `CES_RemoveStickyCommonEvent_0100`, `CES_SendEventSetViscosity_1000` | Тесты запускаются через `hdc shell` от root, а CES разрешает root и системным процессам публиковать системные и липкие события. Тесты рассчитаны на запуск от имени ограниченного процесса; это условия запуска, а не ошибка CES |
| Ограничение на публикацию | `ActsCesSpecificationTest.PublishCommonEventExceedLimit_0100` (код `1500003` вместо `0`) | Сработало ограничение частоты публикации событий |

### Задержка доставки без менеджера пакетов

При публикации обычного (не системного) события CES проверяет статических подписчиков — приложения, объявившие подписку в своём описании. Для этого ему нужен менеджер пакетов (SA 401), которого на данный момент нет. CES получает его через `BundleManagerHelper::GetBundleMgrProxy()` (`services/src/bundle_manager_helper.cpp`), который вызывает `GetSystemAbility` — функцию, ожидающую появления SA с повторами. Перед отказом проходит около 2,4 секунды, и всё это время событие не доставляется:

```
E C01202/Ces: Failed to get bundle manager service.
E C01202/Static: Failed to init AllowList
E C01202/Static: Failed to init subscribers
```

Задержка повторяется при каждой такой доставке (`cesCheckService.CES_ReceiveEvent_0100` проходит, но за 2,4 с; ошибка в журнале — по разу на каждый запуск). Системные события (`usual.event.*`, например из `cem publish`) задержки не вызывают. Тесты с лимитом ожидания 5 секунд падают, когда задержка совпадает с их ожиданием.

Исправлять это в CES не нужно: в коде уже есть вариант без ожидания (`CheckSystemAbility` при `isAsync`), но в полной системе ожидание нужно, чтобы дождаться менеджера пакетов при загрузке. Проблема уйдёт, когда в систему будет добавлен менеджер пакетов. До этого обычные события, которые сервисы публикуют друг для друга, доходят с задержкой около 2,4 секунды.
