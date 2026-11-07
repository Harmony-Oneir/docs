# qos_manager

**QoS** — Quality of Service, «качество обслуживания». В OpenHarmony это механизм, которым приложения и сервисы сообщают системе, **насколько важна работа конкретного потока**: обрабатывает ли он действие пользователя, должен ли уложиться к отрисовке кадра или выполняет фоновую задачу, результат которой никто не ждёт. Система использует эти сведения, чтобы распределять процессорное время: важные потоки получают процессор раньше и на более быстрых ядрах, фоновые — по остаточному принципу.

Компонент `qos_manager` (`foundation/resourceschedule/qos_manager`) реализует этот механизм: системную службу, клиентские библиотеки и интерфейс для приложений.

## Роль в системе

Обычный планировщик Linux знает о процессах и потоках только их приоритет (`nice`) и класс планирования. QoS добавляет к этому смысл: поток помечается уровнем важности, а система переводит уровень в параметры планирования ядра.

Основные уровни QoS (от наименее к наиболее важному):

| Уровень | Для чего |
| --- | --- |
| Фоновый (`QOS_BACKGROUND`) | Работа, которую пользователь не видит: синхронизация, резервное копирование |
| Служебный (`QOS_UTILITY`) | Долгие задачи, результат которых ждут не сразу: загрузка, обработка данных |
| По умолчанию (`QOS_DEFAULT`) | Обычная работа без явной метки |
| Начатый пользователем (`QOS_USER_INITIATED`) | Пользователь запустил действие и ждёт результата: открытие файла |
| Со сроком (`QOS_DEADLINE_REQUEST`) | Работа, которая должна успеть к сроку, например к кадру |
| Взаимодействие с пользователем (`QOS_USER_INTERACTIVE`) | Отклик на касание и ввод, отрисовка интерфейса |

Кто пользуется QoS:

- **`ffrt`** (библиотека параллельных задач OpenHarmony, на которой построены многие системные сервисы) назначает уровень QoS своим рабочим потокам в зависимости от задач;
- **приложения** через интерфейс NDK (`qos.h`, функции вида `OH_QoS_SetThreadQoS`) могут пометить свои потоки;
- **сервисы**, связанные с отрисовкой кадров (`frame_aware_sched`), объединяют потоки, участвующие в подготовке кадра, в группы связанных потоков (RTG), чтобы планировщик рассматривал их вместе.

Сами решения о процессорном времени принимает ядро. Для этого в ядре OpenHarmony есть отдельные возможности (управление QoS и группы связанных потоков RTG), с которыми работает служба через специальные устройства ядра.


# Поддержка QoS в ядре

## Как клиенты QoS работают с ядром

Уровень QoS потоку назначает не сама служба `concurrent_task_service`, а клиентская библиотека в процессе, который его запрашивает: она напрямую обращается к специальным файлам ядра в `/proc` (`foundation/resourceschedule/qos_manager/services/src/qos_interface.cpp`).

| Файл | Назначение | Опция ядра |
| --- | --- | --- |
| `/proc/thread-self/sched_qos_ctrl` | Уровень QoS потока | `CONFIG_QOS_CTRL` (создаётся в `fs/proc/base.c` под `#ifdef CONFIG_QOS_CTRL`) |
| `/proc/self/sched_rtg_ctrl` | Группы связанных потоков (RTG), используются планированием с учётом отрисовки кадров | `CONFIG_SCHED_RTG`, `CONFIG_SCHED_RTG_FRAME` |

Если узла QoS нет, служба запускается и публикует SA 1912, но уровни потоков не применяются: клиенты получают ошибку и продолжают работу без приоритетов. В журнале это выглядит так (на примере `netsysnative`, назначающего уровень своему потоку DNS):

```
E C01707/CONCUR: [Interface] task 133 belong to user 1098 open qos node failed, errno = 2
```

## Модуль qos_auth

Опции управления QoS и правами описаны не в дереве ядра, а в общем модуле OpenHarmony `kernel/linux/common_modules/qos_auth/auth_ctl`. При сборке ядра `kernel/linux/build/kernel.mk` применяет `common_modules/qos_auth/apply_qos_auth.sh`, который добавляет модуль в дерево ядра как `drivers/auth_ctl` (подключается в `drivers/Kconfig` и `drivers/Makefile`). Поэтому опции доступны в конфигурации ядра без дополнительных шагов, но по умолчанию выключены.

| Опция | Назначение |
| --- | --- |
| `CONFIG_AUTHORITY_CTRL` | Контроль прав на возможности RTG и QoS по `uid`. Через него служба QoS выдаёт и отзывает права (устройство `/dev/auth_ctrl`). Должна быть `=y`: от неё зависят остальные опции, которые могут быть только встроенными |
| `CONFIG_QOS_CTRL` | Уровни QoS для потоков и узел `/proc/thread-self/sched_qos_ctrl` |
| `CONFIG_RTG_AUTHORITY` | Проверка прав для команд RTG |
| `CONFIG_QOS_AUTHORITY` | Проверка прав для команд QoS |

На эталонной плате rk3568 (`kernel/linux/config/linux-6.6/rk3568/arch/arm64_defconfig`, а также для ядра 5.10) и на плате wukong100 включены все четыре опции. Тот же набор включён в `x86_64_oneir_standard_defconfig`:

```
# Управление QoS потоков и права на RTG/QoS (common_modules/qos_auth), как на rk3568
CONFIG_AUTHORITY_CTRL=y
CONFIG_QOS_CTRL=y
CONFIG_RTG_AUTHORITY=y
CONFIG_QOS_AUTHORITY=y
```

С `QOS_AUTHORITY` и `RTG_AUTHORITY` ядро разрешает команды только тем `uid`, кому права выдала служба QoS. Если вместо отсутствия узла (`errno = 2`) клиенты начинают получать отказ в доступе, значит, проверка работает, и нужно смотреть выдачу прав службой и доступ к `/dev/auth_ctrl`.

Служба управляет правами через устройство `/dev/auth_ctrl`, которое создаёт модуль `auth_ctl`. Владелец и права файла задаются штатным конфигом `ueventd` из компонента `init` (`base/startup/init/ueventd/etc/ueventd.config`: `/dev/auth_ctrl 0660 system system`), поэтому служба, работающая от пользователя `system`, может его открыть без дополнительной настройки.

### Число политик QoS

Служба `qos_manager` при запуске задаёт ядру пять политик QoS (`QosPolicy::Init` в `qos_policy.cpp`):
`QOS_POLICY_DEFAULT` (1), `QOS_POLICY_SYSTEM_SERVER` (2), `QOS_POLICY_FRONT` (3), `QOS_POLICY_BACK` (4)
и `QOS_POLICY_FOCUS` (5). Ядро принимает номера политик меньше `QOS_POLICY_MAX_NR`, который задаётся опцией
`CONFIG_QOS_POLICY_MAX_NR` (по умолчанию 5, допустимо от 5 до 20). При значении по умолчанию политика `focus`
отвергается, и служба пишет `set g_focusQosPolicy failed, errno = 1`. На эталоне rk3568 опция не задана,
то есть расхождение есть и там. Для `oneir` задано `CONFIG_QOS_POLICY_MAX_NR=6`.

Отказы `pid not authorized` для сетевых сервисов (`netmanager`, `netsysnative`) ожидаемы: они работают от
собственных пользователей, а права на QoS ядро автоматически выдаёт только `system` (`SUPER_UID`); остальным
права выдаёт закрытое расширение `libtask_controller.z.so` или `frame_aware_sched` (для приложений на переднем плане).

## Сборка

Группа в `oneir/BUILD.gn`:

```gn
# Управление приоритетами потоков (QoS)
group("qos") {
  deps = [
    "//foundation/resourceschedule/qos_manager/services:concurrentsvc",
    "//foundation/resourceschedule/qos_manager/etc/init:concurrent_task_service.cfg",
    "//foundation/resourceschedule/qos_manager/sa_profile:concurrent_task_sa_profile",
    "//foundation/resourceschedule/qos_manager/etc/param:ffrt.para",
    "//foundation/resourceschedule/qos_manager/etc/param:ffrt.para.dac",
  ]
}
```

```bash
./oneir/make.sh qos
```

Результат сборки находится по пути `out/oneir/resourceschedule/qos_manager/`. Файл описания сервиса: [concurrent_task_service.json](https://github.com/Harmony-Oneir/oneir/blob/main/profile/concurrent_task_service.json).

## Проверка

```sh
ps -A -o PID,USER,NAME | grep concurrent_task
hilog -x | grep -E "SA:1912|concurrent" | tail -5
```

Ожидается процесс `concurrent_task_service` от пользователя `system` и публикация SA 1912. 

Для сборки тестов используйте команду `./make.sh qos_test` в контейнере. Результат сборки находится по пути `out/oneir/tests/unittest/qos_manager/qos_manager`:
| Тест | Описание |
| --- | --- |
| `concurrent_svc_intf_test` | Интерфейс службы `concurrent_task_service`: вызовы методов службы через её IPC-интерфейс |
| `concurrent_task_client_test` | Клиентская библиотека `concurrent_task_client`: обращения к работающей службе (SA 1912) из другого процесса |
| `concurrent_task_controller_interface_test` | Обёртка над расширением `libtask_controller.z.so` (контроллер задач, выдача прав). Без закрытого расширения часть проверок ожидаемо не проходит |
| `concurrent_task_service_ability_test` | Системная способность службы: запуск, публикация в `samgr`, реакция на появление и исчезновение других SA |
| `concurrent_task_service_test` | Логика самой службы: обработка запросов, отчёты о событиях, взаимодействие с контроллером задач |
| `func_loader_test` | Загрузчик расширений `FuncLoader`: загрузка библиотеки и поиск функций в ней. Проверки с `libtask_controller.z.so` ожидаемо не проходят |
| `qos_interface_test` | Работа с возможностями ядра напрямую: узлы `/proc/thread-self/sched_qos_ctrl` и `/proc/self/sched_rtg_ctrl`, применение и снятие уровней QoS, права. Проверяет конфигурацию ядра |
| `qos_ndk_test` | Интерфейс QoS для нативного кода приложений (NDK, `libqos.so`): назначение, получение и сброс уровня QoS потока |
| `qos_policy_test` | Задание политик QoS ядру (`QosPolicy::Init`): таблицы «уровень QoS → параметры планирования» для разных сценариев |
| `qos_test` | Библиотека уровней QoS для системных компонентов (`libqos.z.so`): назначение уровней текущему и другим потокам |

Внутри системы после сборки образа тесты находятся по пути `/system/tests/qos_manager`.
