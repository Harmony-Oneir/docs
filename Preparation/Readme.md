# Загрузка репозиториев OpenHarmony

Следующая команда инициирует загрузку исходного кода OpenHarmony 7.0:

```
repo init -u https://github.com/openharmony/manifest.git -b OpenHarmony-7.0-Release                                     
repo sync -c --no-clone-bundle -j$(nproc)
```

Исходный код всесит около 100GB. Однако стоит учитывать, что вовремя разработки потребуется дозагрузка тяжелых компонентов и инструментов сборки. Кроме этого, в процессе сборки образуются временные файлы, которые занимают много места. 
Рекомендация: заранее подготовить 500GB свободного места.

# Загрузка репозиториев Oneir

Проект Oneir содержит ряд исправлений необходимых для компиляции OpenHarmony. Кроме этого в проекте используются реализации драйверов, скриптов сборки и программы необходимые для тестирования отдельных компонентов системы. Перед началом сборки загрузите следующие репозитория в папку с исходным кодом OpenHarmony:

```
# Основные скрипты сборки
git clone https://github.com/Harmony-Oneir/oneir.git /mnt/ohos/OpenHarmony7/oneir
# Список исправлений
git clone https://github.com/Harmony-Oneir/oneir_patches.git /mnt/ohos/OpenHarmony7/oneir_patches
# Код програм для тестирования отдельных компонентов
git clone https://github.com/Harmony-Oneir/tests.git /mnt/ohos/OpenHarmony7/tests
# display_composer
git clone https://github.com/Harmony-Oneir/display_composer.git /mnt/ohos/OpenHarmony7/oneir/display_composer
#display_buffer
git clone https://github.com/Harmony-Oneir/display_buffer.git /mnt/ohos/OpenHarmony7/oneir/display_buffer
```

Файл [описания продукта](https://github.com/Harmony-Oneir/productdefine/blob/main/common/products/oneir.json) положите в папку `productdefine/common/products/`.
Файл по пути `build/subsystem_config.json` заменить на [subsystem_config.json](https://github.com/Harmony-Oneir/productdefine/blob/main/build/subsystem_config.json).

# Докачиваем тяжелые исходники
```
cd /mnt/ohos/OpenHarmony7/foundation/arkui/ace_engine
git lfs install
git lfs pull --include="frameworks/bridge/arkts_frontend/arkui_idlize/*.tgz"
```
