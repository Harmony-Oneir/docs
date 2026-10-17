# System Ability Framework (safwk)

System Ability Framework обеспечивает запуск и работу служб.
Safwk состоит из двух частей:
* **библиотека system_ability_fwk** — общий каркас для любого сервиса;
* **программа sa_main** — пустой процесс-"здание", который этот каркас запускает.

Сами сервисы — это не самостоятельные исполняемые программы, а библиотеки. У них нет собственной функции `main()`, поэтому их нельзя запустить напрямую. Необходимо поместить их в специальный процесс, который обеспечит их загрузку и работу. Этим и занимается safwk.

## Сборка
Для сборки safwk внутри контейнера выполните следующую команду:
```bash
./make.sh sa_main
```

Результат сборки находится по пути:
```bash
out/oneir/systemabilitymgr/safwk/sa_main
```

Прямые зависимости sa_main:

| Библиотека | Откуда | Зачем|
| --- | :---: | :--- |
| libsystem_ability_fwk.z.so | foundation/systemabilitymgr/safwk | сам каркас safwk: LocalAbilityManager, класс SystemAbility |
| libutils.z.so | commonlibrary/c_utils | базовые типы OpenHarmony: умные указатели sptr/RefBase, Parcel, потоки |
| libhilog.so | base/hiviewdfx/hilog | запись в журнал событий |
| libbegetutil.z.so | base/startup/init | утилиты init: системные параметры и управление службами. Без init эти вызовы на стенде вернут ошибку или значение по умолчанию |
| libsamgr_common.z.so | foundation/systemabilitymgr/samgr | общий с samgr код, в первую очередь разбор профилей SA |
| libsec_shared.z.so | third_party/bounds_checking_function | безопасные функции memcpy_s, strcpy_s и т.п. |
| libc.so | third_party/musl | libc musl от OpenHarmony, не glibc хоста |
| libc++.so | prebuilts/clang/ohos/.../x86_64-linux-ohos | стандартная библиотека C++ из LLVM |


