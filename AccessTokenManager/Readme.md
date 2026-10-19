# AccessTokenManager (ATM)

AccessTokenManager — системный сервис с SA ID 3503. Через него в OpenHarmony проверяются права. У каждого процесса есть AccessTokenID, 32-битный идентификатор. В нём закодированы тип субъекта.

## Типы субъектов (AType) в AccessTokenID

В подсистеме security/access_token тип субъекта закодирован в битах 29–30:

```C
typedef enum ATypeEnum {
    TOKEN_INVALID = -1,
    TOKEN_HAP = 0,      // Приложения (HAP-пакеты)
    TOKEN_NATIVE = 1,   // Системные процессы / Нативные сервисы (Native)
    TOKEN_SHELL = 2,    // Процессы Shell / HDC / Дебаг
    TOKEN_TYPE_BUTT
} ATypeEnum;
```

* **TOKEN_HAP** — любое обычное или системное UI-приложение, запакованное в .hap.
* **TOKEN_NATIVE** — нативные C++ процессы и демоны, запускаемые процессом init или samgr.
* **TOKEN_SHELL** — процессы, запущенные через отладочный консольный интерфейс `hdc shell` или системный скрипт.

## Битовая структура 32-битного AccessTokenID

Если разложить 32 бита AccessTokenID, то они распределяются следующим образом:

```
31 30   29 28 27               16 15                        0
+--+-----+--+-------------------+---------------------------+
|R |AType|R |   DLP / User ID   |        Token Index        |
+--+-----+--+-------------------+---------------------------+
```

* **Бит 31**: Зарезервирован (Res).
* **Биты 29–30 (AType)**: Тип субъекта (00 = HAP, 01 = NATIVE, 10 = SHELL).
* **Бит 28**: Зарезервирован (Res).
* **Биты 16–27**: Идентификатор пользователя (User ID в многопользовательской системе) или флаг DLP (Data Loss Prevention / защищенный контейнер).
* **Биты 0–15**: Уникальный порядковый индекс токена в таблице AccessTokenManager.

# Сборка

Для сборки ATM, в контейнере запустите следующую команду:
```
./make.sh atm
```
Результат сборки лежит по пути `out/oneir/security/access_token/`:

| Библиотека | Назначение |
| --- | :--- | 
| libaccesstoken_manager_service.z.so | сам ATM (SA 3503), его загружает sa_main | 
| libaccesstoken_json_parse.z.so, libaccesstoken_cjson_utils.z.so | разбор nativetoken.json и профилей прав |
| libaccesstoken_common_cxx.z.so, libaccesstoken_communication_adapter_cxx.z.so| общий код и (де)сериализация для IPC |
| libaccesstoken_sdk.z.so | клиентская библиотека: через неё другие процессы вызывают ATM (VerifyAccessToken и т.п.) |
| libtokenid_sdk.z.so, libtoken_callback_sdk.z.so | вспомогательные клиентские API |
| libtokensetproc_shared.z.so, libpermsetproc_shared.z.so | общая версия token_setproc и установки прав процесса |
| libprivacy_sdk.z.so, libprivacy_communication_adapter_cxx.z.so | клиент privacy-сервиса (учёт использования прав). Для запуска ATM не нужны|

В системе журналирования служба ATM имеет домен `0xD005A01`. Следующей командой можно отфильтровать его записи:
```bash
sudo /system/bin/hilog -D 0xD005A01
```


> **Внимание!** На системе без родного ядра Open Harmony необходимо применить исправления из раздела [Running on a non-native kernel](https://github.com/Harmony-Oneir/docs/tree/main/Running%20on%20a%20non-native%20kernel).
> Так же для работы на не родном ядре установите `token_init` используя команду `./make.sh oneir_token_init`.

# Откуда ATM знает о правах сервисов? 
**Нативные процессы**: в `.cfg` службы указаны apl и список permission. init передаёт их в libnativetoken, и они попадают в `nativetoken.json`. ATM читает этот файл при старте. На стенде без оригинального ядра эту роль играет наша реализация `token_init`, который запускается при старте и создает список разрешений. 

**Приложения (HAP)**: права перечислены в `module.json5` самого приложения. При установке BMS вызывает у ATM `AllocHapToken` со списком запрошенных прав. ATM выдаёт токен и сразу решает:
* system_grant-права, доступные по уровню APL или по ACL, выдаются сразу;
* user_grant-права, к которым относится камера, записываются как запрошенные, но не выданные.
