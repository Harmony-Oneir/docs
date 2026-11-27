
# SceneBoard

Режим можно включит указав аргумент сборки `window_manager_use_sceneboard=true` в компоненте `window_manager` в файле [oneir.json](https://github.com/Harmony-Oneir/productdefine/blob/main/common/products/oneir.json). 

Схема в этом режиме такая:
* в `foundation` работают `WindowManagerService` (4606) и `ScreenSessionManager` (4607, `libscreen_session_manager.z.so`), который управляет экранами;
* окнами управляет сам `SceneBoard`: `SceneSessionManager` работает внутри процесса приложения `SceneBoard`. Это системный HAP на ArkTS и ArkUI, который запускается при загрузке через `ServiceExtensionAbility`;
* окно любого приложения появляется только после того, как `SceneBoard` поднялся и создал для него сессию.

Поэтому для первого кадра в этом режиме нужны: window_manager (режим SceneBoard), ArkUI (ace_engine) и сам HAP SceneBoard, собранный и предустановленный как системное приложение. Плюс всё, что SceneBoard требует при старте: ресурсы, конфиги экранов, ввод.
