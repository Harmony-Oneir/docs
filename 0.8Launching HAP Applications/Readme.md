
# Порядок сборки

Собирать в такой последовательности:
1. `storage_daemon`
2. `storage_manager`
3. `BMS`
4. `accountmgr`
5. `AbilityManager` — (AMS) центральный класс управления, через который проходят все операции с ability
6. `installs` — (SA 511, процесс installs) — исполнитель BMS с правами root. Он распаковывает HAP, создаёт каталоги приложения в `/data/app/el1…el2/100/...` и выставляет права. Без него BMS не установит ни одного HAP, и appspawn будет нечего запускать.
7. `первое приложение HAP` — предустановленные приложения кладутся в `/system/app/...`, и BMS ставит их при первой загрузке (сканирование preinstall).
8. `appspawn` — когда AppMgr (501) решает запустить приложение, он просит appspawn создать процесс: fork от заранее прогретого процесса, настройка uid, sandbox и namespace, загрузка рантайма. Без него AMS найдёт лаунчер, но процесс не поднимется.
9. `resource_management` — TODO
10. `bm`, `aa` — TODO
11. `window_manager` — TODO
12. `ArkUI` — TODO
13. `multimodalinput`
    
...
