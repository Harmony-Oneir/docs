
# SceneBoard

Режим можно включит указав аргумент сборки `window_manager_use_sceneboard=true` в компоненте `window_manager` в файле [oneir.json](https://github.com/Harmony-Oneir/productdefine/blob/main/common/products/oneir.json). 

Схема в этом режиме такая:
* в `foundation` работают `WindowManagerService` (4606) и `ScreenSessionManager` (4607, `libscreen_session_manager.z.so`), который управляет экранами;
* окнами управляет сам `SceneBoard`: `SceneSessionManager` работает внутри процесса приложения `SceneBoard`. Это системный HAP на ArkTS и ArkUI, который запускается при загрузке через `ServiceExtensionAbility`;
* окно любого приложения появляется только после того, как `SceneBoard` поднялся и создал для него сессию.

Поэтому для первого кадра в этом режиме нужны: window_manager (режим SceneBoard), ArkUI (ace_engine) и сам HAP SceneBoard, собранный и предустановленный как системное приложение. Плюс всё, что SceneBoard требует при старте: ресурсы, конфиги экранов, ввод.


# Сборка
Для сборки используйте команду `./make.sh --reload window_manager` в контейнере. Перед сборкой примените патч [0001-pip-abc-relative-source-path.patch](https://github.com/Harmony-Oneir/oneir_patches/blob/main/window_window_manager/0001-pip-abc-relative-source-path.patch)

# Проверка в QEMU

GPT-диск для QEMU:
```bash
cd /mnt/ohos/OpenHarmony7/out/oneir
R=ohos-root.img; U=userdata.img; D=/tmp/oneir-gpt.img
RM=$(( ($(stat -c %s $R) + 1048575) / 1048576 ))
UM=$(( ($(stat -c %s $U) + 1048575) / 1048576 ))
rm -f $D && truncate -s $(( RM + UM + 2 ))M $D
/usr/sbin/sgdisk -o -n 1:1M:+${RM}M -c 1:system -n 2:0:+${UM}M -c 2:userdata $D
dd if=$R of=$D bs=1M seek=1 conv=notrunc status=none
dd if=$U of=$D bs=1M seek=$(( 1 + RM )) conv=notrunc status=none
```
