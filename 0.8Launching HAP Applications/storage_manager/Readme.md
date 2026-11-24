`storage_manager` (SA 5003) — управляющая часть подсистемы хранения OpenHarmony. Это аналог `StorageManagerService` в Android, а `storage_daemon` — аналог `vold`. Разделение такое: `storage_manager` работает без привилегий, принимает запросы от других служб и решает, что делать, а `storage_daemon` от `root` выполняет системную работу: создаёт каталоги, монтирует, ставит ключи шифрования `fscrypt`. Сам `storage_daemon` почти ничего не инициирует, он ждёт команд от `storage_manager`.


# Сборка
Для сборки используйте команду `./make.sh storage_manager` в контейнере. При запуске системы, Init загружает `storage_manager` через `storage_manager.cfg`, который в своею очередь загружает SA профиль `storage_manager.json`.
