
# SceneBoard

Режим можно включит указав аргумент сборки `window_manager_use_sceneboard=true` в компоненте `window_manager` в файле [oneir.json](https://github.com/Harmony-Oneir/productdefine/blob/main/common/products/oneir.json). 

Схема в этом режиме такая:
* в `foundation` работают `WindowManagerService` (4606) и `ScreenSessionManager` (4607, `libscreen_session_manager.z.so`), который управляет экранами;
* окнами управляет сам `SceneBoard`: `SceneSessionManager` работает внутри процесса приложения `SceneBoard`. Это системный HAP на ArkTS и ArkUI, который запускается при загрузке через `ServiceExtensionAbility`;
* окно любого приложения появляется только после того, как `SceneBoard` поднялся и создал для него сессию.

Поэтому для первого кадра в этом режиме нужны: window_manager (режим SceneBoard), ArkUI (ace_engine) и сам HAP SceneBoard, собранный и предустановленный как системное приложение. Плюс всё, что SceneBoard требует при старте: ресурсы, конфиги экранов, ввод.


# Сборка
Для сборки используйте команду `./make.sh --reload window_manager` в контейнере. Перед сборкой примените патч [0001-pip-abc-relative-source-path.patch](https://github.com/Harmony-Oneir/oneir_patches/blob/main/window_window_manager/0001-pip-abc-relative-source-path.patch)

---

# Ограничение: в QEMU окна не проверить

В QEMU оконную подсистему можно запустить, но довести её до работающего экрана нельзя.
Проверять `window_manager` вместе с отрисовкой нужно на реальном железе с GPU Intel.

## Почему

1. **`window_manager` впервые заставляет RS рисовать экран через GPU.** `ScreenSessionManager`
   (SA 4607, режим SceneBoard) при старте создаёт для физического экрана узел дисплея и включает
   его. После этого `RSUniRenderThread` делает GPU-композицию экрана: берёт буфер поверхности экрана
   (линейный DMA-BUF от `display_buffer`) и импортирует его в Vulkan
   (`MakeFromNativeWindowBuffer` → `vkGetNativeBufferPropertiesOHOS`). Без службы экранов RS этот путь
   не проходит, поэтому до появления `window_manager` в QEMU всё работало.

2. **В образе есть Vulkan-драйвер только для Intel.** Единственный ICD —
   `/vendor/lib64/libvulkan_intel.so` (`anv` из `third_party/mesa3d`). Расширения OpenHarmony
   (`VK_OHOS_native_buffer`, `VK_OHOS_external_memory`) в нём реализованы (`anv_ohos.c`,
   `vk_ohos.c`), но драйвер работает только с реальным GPU Intel. В QEMU у гостя только `virtio-gpu`,
   поэтому физических устройств Vulkan нет, устройство не создаётся, и все функции устройства,
   включая расширения OpenHarmony, остаются `NULL`.

3. **RS в ветке 7.0 этого не проверяет** и вызывает функцию расширения по нулевому указателю.

## Как это выглядит в QEMU

Без патча `0003-vulkan-check-ohos-extension-functions.patch` (`graphic_2d`):

- через ~140 мс после старта SA 4607 `render_service` падает с SIGSEGV в потоке `RSUniRenderThread`
  (`fault address: 0x0`);
- init по правилам RS останавливает `composer_host`, `allocator_host` и `foundation` и откладывает
  их перезапуск на 240 с;
- перезапущенный RS без composer через ~20 с выходит, и из-за `critical` у `render_service`
  стенд перезагружается по кругу (`ExecReboot panic`, логи в `/data/log/bbox/*/last_kmsg`).

С патчем RS не падает, в `hilog` появляется
`vkGetNativeBufferPropertiesOHOS is not available`, но экран через GPU не рисуется.

## Что можно проверить в QEMU

- что службы стартуют: в `hidumper -ls` есть `RenderService`, `DisplayManagerService` (4607),
  а `foundation` и RS работают одновременно;
- что в `foundation` загружены `libwms.z.so` и `libscreen_session_manager.z.so`;
- что `ScreenSessionManager` записал параметры экрана (`param get persist.window.screen.width`).

Отрисовку экрана и окон в QEMU проверить нельзя.
