
# Сборка
Собрать Render Service можно следующей командой в контейнере:
```
./make.sh oneir_graphics
```
Поумолчанию RS работает в режиме OpenGL. Аргумент `graphic_2d_feature_enable_vulkan = true` переключает на Vulkan.
Аргумент сборки `skia_use_vulkan` включает Vulkan-бэкенд в Skia. Аргумент `skia_vk_enable_partialrender` включает частичную перерисовку.

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

## Логирование

Следующие домены характерны для render_service:

| Domain | Модуль |
|-----------|-----------------------|
| 0xD001406 | Основные логи RS, HPAE|
| 0xD001400 | Composer, VSync и opengl_wrapper|
