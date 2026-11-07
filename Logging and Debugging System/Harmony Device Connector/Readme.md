# Harmony Device Connector (HDC)

HDC выполняет ровно те же задачи, что и adb в Android: служит мостом между рабочей машиной (хостом) и целевым устройством (смартфоном, платой, эмулятором или виртуальной машиной в QEMU) для отладки, передачи файлов и управления процессами.

## Из чего состоит

| Часть | Где работает | Что делает |
|---|---|---|
| **Клиент** `hdc` | Компьютер разработчика | Принимает команды пользователя (`hdc shell`, `hdc file send` и т.д.) |
| **Сервер** `hdc` | Компьютер разработчика, фоновый процесс | Запускается клиентом автоматически при первой команде. Держит соединения с устройствами и передаёт им команды клиентов. Клиент и сервер — одна программа, сервер слушает локальный порт `8710` (меняется переменной окружения `OHOS_HDC_SERVER_PORT`) |
| **Демон** `hdcd` | Устройство | Принимает подключения от сервера, выполняет команды: открывает шелл, принимает и отдаёт файлы |

## hdcd на устройстве

`hdcd` — обычный сервис init (не системная способность SA). Он работает от `root` с правом менять пользователя (`setuid`). Его токен доступа (`apl` и список разрешений в конфиге) наследуют все процессы шелла; среди разрешений есть и разрешения Wi-Fi, поэтому через `hdc shell` работает, например, `ohos-wifiManager`.

Конфигурация:

| Файл | Что задаёт |
|---|---|
| `hdcd.cfg` (`/system/etc/init/`) | Описание сервиса: путь, пользователь, группы, разрешения. И задания, которые запускают, перезапускают или останавливают `hdcd` при изменении параметров режима |
| `hdc.para` (`/system/etc/param/`) | Значения параметров по умолчанию |
| `hdc.para.dac` | Права доступа к параметрам hdc |
| `oneir.para` (`/vendor/etc/param/`, файлы платы) | Переопределения для продукта. Параметры из `/vendor` загружаются после системных и имеют приоритет |

Сам `hdcd` при загрузке не запускается (`disabled`, `start-mode: condition`): его запускают задания `hdcd.cfg`, когда параметры режима принимают значения.

## Условия запуска

`hdcd` проверяет при старте и во время работы несколько параметров системы:

| Параметр | Что проверяется | Откуда берётся |
|---|---|---|
| `const.security.developermode.state` | **Режим разработчика.** Если значение не `true`, `hdcd` сразу завершается с кодом 255 и записью в журнале `non developer mode, hdcd does not start` (`main.cpp`). Init при этом пытается перезапускать его каждые 10 секунд | Задаёт плата. На телефонах режим разработчика включается через «Настройки», а платы для разработки выставляют его в своих параметрах, как x86-эмулятор OpenHarmony (`device/qemu/common/virt_full/cfg/default.para`) |
| `const.secure` | **Авторизация.** При `0` задание `hdcd.cfg` устанавливает при загрузке `const.hdc.secure=0`, и `hdcd` не проверяет ключ компьютера | Системный `ohos.para` (компонент `init`) |
| `const.debuggable` | **Права шелла.** При `1` шелл работает от root (если `persist.hdc.root` не равен `0`), иначе `hdcd` сбрасывает права, и шелл работает от пользователя `shell` | Системный `ohos.para` (компонент `init`) |

`const.secure` и `const.debuggable` задаются вариантом сборки: в исходном `ohos.para` стоят отладочные значения (`const.secure=0`, `const.debuggable=1`), а при `build_variant = "user"` сборка дописывает `const.secure=1` и `const.debuggable=0`. Без явного варианта сборки система получается отладочной, поэтому для `oneir` эти параметры дополнительно задавать не нужно.

## Способы подключения

| Способ | Параметр | По умолчанию | Описание |
|---|---|---|---|
| USB | `persist.hdc.mode.usb` | `enable` | Устройство работает как USB-устройство (гаджет) и подключается к компьютеру кабелем. Требует контроллера USB в режиме устройства, которого у обычных ПК и ноутбуков нет |
| TCP | `persist.hdc.mode.tcp` | `disable` | Подключение по сети. Порт задаётся параметром `persist.hdc.port` |
| UART | `persist.hdc.mode.uart` | `disable` | Подключение через последовательный порт |

Если все способы выключены, `hdcd` останавливается. Для ноутбука используется TCP по Wi-Fi.

Что разрешено подключённому компьютеру, задают параметры `persist.hdc.control.shell`, `persist.hdc.control.file` и `persist.hdc.control.fport` (шелл, передача файлов, проброс портов); общий переключатель — `persist.hdc.control`.

## Настройки продукта

`oneir/rootfs/vendor/etc/param/oneir.para`:

```
# Режим разработчика: без него hdcd не запускается.
# Задаётся платой, как в device/qemu/common/virt_full/cfg/default.para
const.security.developermode.state=true

# hdcd по сети вместо USB
persist.hdc.mode.tcp=enable
persist.hdc.mode.usb=disable
persist.hdc.port=8710
```

Файл попадает в образ шагом с файлами платы (копирование `oneir/rootfs`), отдельно ставить его не нужно.

> **Внимание:** в отладочной сборке любой компьютер в той же сети может подключиться к порту `hdcd` без авторизации и получить шелл root. Это допустимо только для отладки в доверенной сети. Для итоговой системы нужна пользовательская сборка (`build_variant = "user"` в файле [args.gn](https://github.com/Harmony-Oneir/oneir/blob/main/args.gn)) и выключенный режим разработчика (`param set persist.oneir.developermode false`).

## Сборка


Клиент для macOS собирается тулчейном `//build/toolchain/mac:clang_x64` только на самом Mac (нужен Xcode) или берётся из OpenHarmony SDK.

Демон: `./make.sh hdcd`. Программа собирается под именем `hdcd_system` в `out/oneir/developtools/hdc/` (так её отличают от варианта для режима обновления, `hdcd_updater`), а модуль `hdcd_system` ставит её в образ как `/system/bin/hdcd`. 

Клиент: `./make.sh hdc_host_linux`, результат — `out/oneir/clang_x64/.../hdc`.


## Использование
Для использования в QEMU запустите виртуальную машину следующей командой:
```bash
sudo qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G -machine q35 \
  -kernel out/kernel/OBJ/linux-6.6/arch/x86/boot/bzImage \
  -drive file=out/oneir/ohos-root.img,format=raw,if=virtio,snapshot=on \
  -drive file=out/oneir/userdata.img,format=raw,if=virtio \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:18710-:8710 \
  -device e1000,netdev=n0 \
  -append "root=/dev/vda rw console=ttyS0 selinux=0 hardware=x86_64_oneir init=/system/bin/init quiet loglevel=3" \
  -nographic
```

На хосте поместите зависимости в переменные окружения:
```bash
HDC=$(sudo find out/oneir/clang_x64 -name hdc -type f -not -path "*unstripped*" | head -1)
LIBS=$(sudo find out/oneir/clang_x64 -name "*.so" -not -path "*unstripped*" -printf '%h\n' | sort -u | tr '\n' ':')
```

Установите соединение:
```bash
LD_LIBRARY_PATH="$LIBS" "$HDC" tconn 127.0.0.1:18710
LD_LIBRARY_PATH="$LIBS" "$HDC" list targets
```

```bash
hdc tconn <адрес устройства>:8710   # подключиться по сети
hdc list targets                    # подключённые устройства
hdc shell                           # удалённый шелл
hdc file send <файл> <путь>         # передать файл на устройство
hdc file recv <путь> <файл>         # забрать файл с устройства
```
