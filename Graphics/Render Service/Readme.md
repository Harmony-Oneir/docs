
# Сборка
Собрать Render Service можно следующей командой в контейнере:
```
./make.sh oneir_graphics
```
Поумолчанию RS работает в режиме OpenGL. Аргумент `graphic_2d_feature_enable_vulkan = true` переключает на Vulkan.
Аргумент сборки `skia_use_vulkan` включает Vulkan-бэкенд в Skia. Аргумент `skia_vk_enable_partialrender` включает частичную перерисовку.

При запуске RS читает системный параметр `persist.sys.graphic.GpuApitype`, который определяет режим работы:
| persist.sys.graphic.GpuApitype |  Бэкенд |
|---|---|
| `0` (по умолчанию)| OpenGL |
| `1` | Vulkan |
| `2` | DDGR (собственный GPU-движок Huawei) |

Значит, нужно:
```
param set persist.sys.graphic.GpuApitype 1
param get persist.sys.graphic.GpuApitype     # должно вернуть 1
```

После запуска RS, следующее сообщение в `hilog` подтверждает переключение на Vulkan:
```
PrintCurrentStatus: drawing is opened, gpu type is vulkan
```



### После сборки
Результат сборки находится по пути `out/oneir/graphic/graphic_2d/`:

| Файл |  Назначение |
|---|---|
| `render_service` |  Процесс Render Service: точка входа `main`, регистрация в samgr, запуск главного цикла |
| `librender_service.z.so` | Вся логика RS: главный поток, UniRender, обход дерева, HWC-решения, управление экранами, захват экрана |
| `librender_service_base.z.so` |  Общая основа клиента и сервера: узлы, свойства, команды, сериализация транзакций, модификаторы, анимации |
| `librender_service_client.z.so` | Клиентская часть RS: `RSInterfaces`, `RSNode`, `RSSurfaceNode`, отправка транзакций, подключение к RS через samgr |
| `libcomposer.z.so` | Композитор: работа со слоями и выводом на дисплей через Display HDI |
| `libvsync.z.so` | Генерация и раздача VSync: источник сигнала, VSync-соединения для клиентов |
| `libhyper_graphic_manager.z.so` | HGM: управление частотой обновления экрана, голосование за частоту кадров, LTPO |
| `lib2d_graphics.z.so` | Drawing: 2D-движок отрисовки поверх Skia (холст, кисти, пути, изображения, GPU-контексты) |
| `librosen_text.z.so` | Текстовый движок: шрифты, раскладка и шейпинг текста, абзацы |
| `libEGL.so` | Диспетчер EGL из `opengl_wrapper`: загружает реальный драйвер (у вас Zink) и создаёт GPU-контексты |
| `libGLESv3.so` | Диспетчер OpenGL ES 3: перенаправляет вызовы GLES в реальный драйвер |
| `libcolor_manager.z.so` | Цветовые пространства и гамуты (sRGB, Display P3 и др.), преобразование цветов |
| `libnative_color_space_manager.so` | Нативный C API управления цветовыми пространствами для приложений |
| `libcolor_space_object_convertor.z.so` | Преобразование объектов цветового пространства между JS (NAPI) и нативным кодом |
| `libcreate_pixelmap_surface.z.so` | Создание PixelMap (изображения) из содержимого Surface: скриншоты, захват |
| `libsocketpair.z.so` | Обёртка над socketpair: быстрый канал для VSync-событий между процессами |
| `libframe_analyzer.z.so` | Анализ кадров: статистика времени отрисовки, выявление пропущенных кадров (jank) |
| `libwindow_animation.z.so` | Оконные анимации: открытие, закрытие, переходы окон (`RSWindowAnimation`) |

Связанные зависимости в каталоге `out/oneir/hdf/drivers_interface_display/`:

| Библиотека | Описание |
|---|---|
| `libdisplay_buffer_hdi_impl_v1_4.z.so` | Клиентская обёртка аллокатора (новейшая версия интерфейса): выделение буферов через IPC к `allocator_service` и отображение в память через passthrough-mapper прямо в процессе клиента. Её используют `graphic_surface` и composer RS |
| `libdisplay_buffer_proxy_1.0.z.so` … `libdisplay_buffer_proxy_1.4.z.so` | IPC-прокси интерфейса Display Buffer, сгенерированные из IDL. Каждая версия расширяет предыдущую и зависит от неё, поэтому собирается вся линейка |
| `libdisplay_composer_hdi_impl_1.1.z.so` … `libdisplay_composer_hdi_impl_1.5.z.so` | Клиентская обёртка Display Composer: упаковывает команды по слоям в буфер разделяемой памяти (`DisplayCmdRequester` + `SharedMemQueue`) и отправляет их сервису пачкой. Версию 1.5 RS использует при подключении к композитору (видно в backtrace) |
| `libdisplay_composer_proxy_1.0.z.so` … `libdisplay_composer_proxy_1.5.z.so` | IPC-прокси интерфейса Display Composer, сгенерированные из IDL: экраны и режимы, VSync, hotplug, питание, слои, prepare/commit |
| `libdisplay_commontype_proxy_1.0.z.so` … `libdisplay_commontype_proxy_2.4.z.so` | Общие типы дисплейных интерфейсов из IDL: форматы пикселей, структуры описаний буферов и слоёв, цветовые пространства, HDR, а также их сериализация для IPC. Используются и аллокатором, и композитором |
| `libhdifd_parcelable.z.so` | Обёртка для передачи файловых дескрипторов через IPC HDI: fence'ы синхронизации и dma-buf буферов (`HdifdParcelable`) |


Результат сборки skia находится по пути `out/oneir/thirdparty/skia/`:

| Файл | Назначение |
|----------------------|------------|
| `libskia_canvaskit.z.so` |библиотека Skia, графический движок, который в OpenHarmony собран в одну библиотеку|

## Логирование

Следующие домены характерны для render_service:

| Domain | Модуль |
|-----------|-----------------------|
| `0xD001406` | Основные логи RS, HPAE|
| `0xD001400` | Composer, VSync и opengl_wrapper|
