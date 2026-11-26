**installs** (SA 511, процесс installs, библиотека `libinstalls.z.so` из части `bundle_framework`) — привилегированный исполнитель службы пакетов. 
Это аналог installd в Android. Сам BMS (`BundleMgr`, SA 401 в процессе `foundation`) работает с ограниченными правами: он разбирает HAP, проверяет подпись и `module.json` и ведёт базу установленных приложений. 
Все операции с файловой системой, для которых нужны root или особые capabilities, он поручает installs: 
распаковку HAP и нативных библиотек, создание каталогов приложения для каждого пользователя (`/data/app/el1…el2/<userId>/base/<bundle>`, `database`, `cache` и т.д.), назначение им uid и gid приложения и меток доступа, перемещение и удаление файлов при обновлении и удалении пакета, очистку кэша, извлечение `.abc` и `.so`. Служба запускается по требованию (`run-on-create: false`): samgr поднимает её при первом `LoadSystemAbility(511)` от BMS, обычно во время установки HAP, и выгружает после 180 с простоя (`stop-on-demand`). Поэтому сразу после загрузки SA 511 в `hidumper -ls` нет, и это нормально. Без installs BMS может запускаться и отвечать на запросы, но не может установить ни одного приложения, ни предустановленного из `/system/app`, ни через `bm install`.

# Сборка
Для сборки используйте команду `./make.sh installs` в контейнере.


# Запуск

init описывает службу в `/system/etc/init/installs.cfg`:

```
"path"     : ["/system/bin/sa_main", "/system/profile/installs.json"]
"uid"      : "installs"   (3060)
"ondemand" : true
```

Профиль `/system/profile/installs.json` — это `bundle_framework/sa_profile/511.json`
(`"process": "installs"`, `"run-on-create": false`, `stop-on-demand` → `longtimeunused-unload: 180`).
`sa_main` загружает `libinstalls.z.so` и публикует SA 511 под именем `Installd`.

Служба работает **по требованию**: init сам её не запускает. Её загружает samgr при первом
`LoadSystemAbility(511)` от BMS. Обычно это происходит уже при старте BMS (подготовка каталогов
пользователей), поэтому после загрузки `Installd` чаще всего уже в списке SA.
После ~180 с простоя samgr выгружает службу, и при следующем обращении BMS загружает её снова.

# Проверка

1. Файлы на месте:
   ```sh
   ls -l /system/lib64/libinstalls.z.so /system/etc/init/installs.cfg /system/profile/installs.json
   ```

2. init знает службу:
   ```sh
   begetctl dump_service installs | grep -E 'status|pid|crashCnt|perms uID|info \['
   ```
   Ожидается путь `sa_main` с `installs.json`, `perms uID [3060]`, `crashCnt: [0]`. Статус
   `running`, если службу уже загрузил BMS, или `stopped`, если она выгружена по простою.
   Оба варианта нормальны.

3. Пользователь существует:
   ```sh
   grep -E '^installs:' /etc/passwd /etc/group
   ```

4. SA зарегистрирована (после загрузки или после обращения BMS):
   ```sh
   hidumper -ls        # в списке Installd
   ```

5. Ручной запуск, если службы нет в списке:
   ```sh
   service_control start installs; sleep 5
   begetctl dump_service installs | grep -E 'status|pid|crashCnt'
   hidumper -ls
   ```
   Ожидается `running` и `Installd` в списке. Если процесс сразу завершился, причину покажут
   `dmesg | tail -30` (uid, gid, профиль) и `hilog -x -L E | tail -30`.

6. Выгрузка по простою:
   ```sh
   sleep 200; pidof installs || echo "выгружен"; hidumper -ls
   ```
   Процесс исчез, `Installd` пропал из списка, `crashCnt` не вырос: ondemand-цикл работает.

Полная проверка — установка HAP через `bm install`: при ней BMS обращается к `installs`,
и в `/data/app/el1/bundle/public/` появляется каталог пакета.

