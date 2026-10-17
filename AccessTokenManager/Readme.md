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

* TOKEN_HAP — любое обычное или системное UI-приложение, запакованное в .hap.
* TOKEN_NATIVE — нативные C++ процессы и демоны, запускаемые процессом init или samgr.
* TOKEN_SHELL — процессы, запущенные через отладочный консольный интерфейс `hdc shell` или системный скрипт.
