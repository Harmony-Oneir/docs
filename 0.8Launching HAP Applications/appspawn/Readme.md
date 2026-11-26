# appspawn

`appspawn` — демон, который создаёт процессы приложений. Это аналог `zygote` в Android. Его запускает
init при загрузке. Демон заранее загружает в себя общие библиотеки (ArkUI, ARK-рантайм, `appkit`),
получая «прогретый» процесс, и слушает сокет. Когда `AppMgr` (SA 501) решает запустить приложение,
он отправляет `appspawn` запрос с параметрами процесса. `appspawn` делает `fork`, и потомок:

- получает uid/gid приложения и access token (`SetAppAccessToken`);
- попадает в sandbox: отдельный mount namespace, где видны только каталоги приложения и разрешённые
  системные пути (конфиги `appdata-sandbox*.json`, модуль `sandbox`);
- получает ограничения seccomp и capabilities (модуль `common`), а при включённом SELinux — свой домен;
- загружает код приложения и передаёт управление рантайму ability.

Так приложение стартует быстро (без повторной загрузки библиотек) и изолированно от других.

Собирается из `base/startup/appspawn`:

| Цель | Что это |
|---|---|
| `standard:appspawn` | сам демон |
| `standard:appspawn_helper`, `standard:pid_ns_init` | вспомогательный процесс и init для PID namespace приложений |
| `:appspawn.rc` | cfg для init (`appspawn.cfg`) |
| `etc:etc_files` | sandbox-конфиг (`appdata-sandbox64.json`), списки предзагрузки, параметры |
| `modules/ace_adapter:appspawn_ace` | предзагрузка ArkUI/ARK в прогретый процесс |
| `modules/sandbox:appspawn_sandbox` | построение sandbox приложения |
| `modules/common:appspawn_common` | uid/gid, access token, seccomp, SELinux |
| `modules/spm`, `modules/module_engine` | вспомогательные модули и движок модулей |

Остальные «спаунеры» (`nwebspawn` для веб-движка, `cjappspawn` для Cangjie, `nativespawn`,
`hybridspawn`) и модули `asan`, `hnp`, `devicedebug` пока не собираются.

# Сборка
Для сборки используйте команду `./make.sh --reload appspawn` в контейнере. 

Перед сборкой:

2. В `productdefine/common/products/oneir.json` у компонента `appspawn`:
   ```
   "features": [ "appspawn_support_nweb=false" ]
   ```
3. Патч `oneir_patches/startup_appspawn/0001-appspawn_adapter-build-without-selinux.patch`

# Трудности
**webview.** Модуль `appspawn_ace` и рантайм `appkit` тянут веб-движок
(`webview:libarkweb_utils`, `nweb_ohos_adapter`). Тот при компоновке ищет NDK-библиотеки
(`libbundle_ndk.z.so`) в `prebuilts/ohos-sdk/linux/26.0.0/native/sysroot`, а такого SDK в дереве нет.
`build/prebuilts_download.sh` скачивает SDK только с флагом `--download-sdk`, и только API 12
из ветки 5.0.0 (в `prebuilts/ohos-sdk-12`), а 7.0 нужен API 26.

Временное решение: 
- компонент `webview` убран из `oneir.json` (копия конфига — `oneir.json.bak3`), и `appkit` собирается
  без web по условию `defined(global_parts_info.web_webview)`;
- для `appspawn` выставлен `appspawn_support_nweb=false` через `features` компонента.

Класть файлы в `prebuilts/ohos-sdk` вручную не нужно: это не воспроизводится при чистой сборке.
Чтобы включить webview позже, понадобятся SDK API 26 (собрать продукт `ohos-sdk` из дерева),
сам движок ArkWeb и `nwebspawn`.

**SELinux.** На стенде собираем с `build_selinux = false`. В `modules/common/appspawn_adapter.cpp`
часть кода (`CheckSpecialSpawnMode`, вызов `HapContextLoadConfig()`) не закрыта `#ifdef WITH_SELINUX`,
и сборка падает на `unknown type name 'HapDomainInfo'`. Это ошибка апстрима, она есть и в `master`.
Исправлено патчем `0001-appspawn_adapter-build-without-selinux.patch`, в апстрим отправлены issue и PR.

Без SELinux приложения изолируются через uid/gid, sandbox, seccomp и access token, но без мандатного
контроля доступа. Для включения SELinux нужны политика для всех служб и метки файлов в образе
(`ohos-image` сейчас не ставит xattr `security.selinux`).

# Проверка в QEMU

Выполнять примерно через минуту после загрузки.

1. Файлы на месте:
   ```sh
   ls -l /system/bin/appspawn /system/etc/init/appspawn.cfg
   ls /system/lib64/appspawn/
   ls /system/etc/sandbox/ 2>/dev/null || find /system/etc -name 'appdata-sandbox*.json'
   ```

2. Демон запущен:
   ```sh
   begetctl dump_service appspawn | grep -E 'status|pid|crashCnt'
   ps -ef | grep -E 'appspawn|pid_ns_init' | grep -v grep
   ```
   Ожидается `running`, `crashCnt: [0]`, процесс `appspawn`.

3. Сокет создан (по нему к `appspawn` обращается `AppMgr`):
   ```sh
   ls -l /dev/unix/socket/ | grep -i spawn
   ```

4. Ошибок при старте нет:
   ```sh
   hilog -x -P $(pidof appspawn) -L W,E | head -40
   dmesg | grep -i appspawn | tail -20
   ```
   Ошибки загрузки модулей (`dlopen` в `/system/lib64/appspawn/...`) обычно значат, что в образ
   не попала какая-то библиотека из предзагрузки.

5. Связка с AppMgr: при попытке AMS запустить приложение в логе `foundation` появляются обращения
   к `appspawn`, а в `hidumper -s 180 -a '-r'` — процесс приложения. Пока в образе нет установленного
   HAP, это не проверить: AMS не находит лаунчер (`bundleInfos_ is empty`).
