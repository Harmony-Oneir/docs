Это штатный диагностический инструмент OpenHarmony, аналог dumpsys в Android. `hidumper -ls` выводит список зарегистрированных SA, `hidumper -s <id>` — дамп конкретной службы (например, `-s 10` для `render_service`), есть ещё `--mem`, `--cpuusage` и т. п. Работает он через собственную SA `hidumper_service`, поэтому в образе нужны и бинарник, и профиль службы.

# Сборка
Для сборки используйте команду `./make.sh hidumper` в контейнере. 

SA профиль: [hidumper_service.json](https://github.com/Harmony-Oneir/oneir/blob/main/profile/hidumper_service.json). После запуска системы, Init загружает файл `hidumper_service.cfg`.
