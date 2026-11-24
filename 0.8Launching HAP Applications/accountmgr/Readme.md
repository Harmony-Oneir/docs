`accountmgr` (SA 200, процесс `accountmgr`, uid account) — служба управления учётными записями OpenHarmony, аналог `UserManagerService` в Android. Она ведёт системные аккаунты пользователей (`os_account`: создание, удаление, переключение и ограничения) и хранит их в `/data/service/el1/public/account/`. Кроме того, через неё работают распределённый аккаунт (`ohos_account`), доменные аккаунты и аккаунты приложений (`app_account`). При первом запуске служба создаёт аккаунт по умолчанию `100`. Для этого она ждёт `StorageManager` (5003), который готовит каталоги и ключи пользователя через storage_daemon, и `BundleMgr` (401), который заводит пользователя в BMS. Активация аккаунта 100 требует ещё `AbilityManager` (180). События о пользователях служба рассылает через `CommonEventService` (3299). На стенде без AMS аккаунт `100` создаётся, но остаётся inactive
# Сборка
Для сборки используйте команду `./make.sh os_account` в контейнере. init запускает службу по `/system/etc/init/accountmgr.cfg`.
```
"path" : ["/system/bin/sa_main", "/system/profile/accountmgr.json"]
"uid"  : "account"
"gid"  : ["account", "shell", "access_token", "data_reserve", "readproc", "edc"]
```

`sa_main` читает профиль `/system/profile/accountmgr.json`

Для создания аккаунта 100 в образе должны быть `StorageManager` (5003) и `StorageDaemon` (5002),
а также `BundleMgr` (401) в процессе `foundation`. Для рассылки событий нужен `CommonEventService` (3299)
там же. SA 401 и 3299 должны быть **в одном** `/system/profile/foundation.json` (`oneir/profile/foundation.json`).

# Проверка

1. Служба запущена:
   ```sh
   begetctl dump_service accountmgr | grep -E 'pid|status|crashCnt'
   ```
   Ожидается `status: [running]`, `crashCnt: [0]`.

2. SA зарегистрирована и отвечает:
   ```sh
   hidumper -ls            # в списке AccountMgr, StorageManager, BundleMgr, CommonEventService
   hidumper -s 200 -a '-h' # список команд дампа
   ```

3. Аккаунт создан:
   ```sh
   hidumper -s 200 -a '-os_account_infos'
   ls -l /data/service/el1/public/account
   ```
   Ожидается аккаунт `ID: 100`, `Create Completed: true`, и в `account/` есть `account_list.json`.
   Без `AbilityManager` (180) статус `inactive`, это нормально.

4. Нет ошибок:
   ```sh
   hilog -x -D 0xD001B00 -L W,E | tail -30
   ```
   При первом создании в логе должно быть `Successed to create the first OS account`.
   Допустимые ошибки: `HksInit/HksGenerateKey err = -2` (нет HUKS) и
   `libactivation_lock_sdk.z.so` (опциональный плагин).
