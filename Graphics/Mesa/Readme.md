# Инструменты Mesa для кросс-сборки Vulkan-драйвера Intel
Vulkan-драйвер Intel (anv) входит в состав Mesa. Начиная с Mesa 25 часть его внутренних шейдеров написана на OpenCL C и компилируется прямо во время сборки драйвера. Для этого используются две программы: mesa_clc переводит OpenCL C в SPIR-V, а vtn_bindgen генерирует из него код для драйвера. При кросс-сборке под OpenHarmony эти программы запускаются на машине сборки, а не на целевой системе, поэтому собрать их в рамках той же кросс-сборки нельзя: для этого понадобился бы LLVM под OpenHarmony, которого нет. Их собирают заранее, отдельно, и передают в кросс-сборку опцией -Dmesa-clc=system.

Контейнер сборки уже содержит инструменты `mesa_clc` и `meson` после выполнения действий указанных в [Build environment](https://github.com/Harmony-Oneir/docs/tree/main/Build%20environment).

## Сборка

Перед сборкой проверьте в контейнере наличие `mesa_clc` и `meson`:
```bash
root@327b02512ac3:/home/openharmony# mesa_clc -h | head -2
Usage: /usr/local/bin/mesa_clc.real [options] [input files] -- [clang args]
Options:
root@327b02512ac3:/home/openharmony# meson --version
1.4.1
```
Следующим шагом примените следующие патчи:
* [mesa_x86_64_no_neon.patch](https://github.com/Harmony-Oneir/oneir_patches/blob/main/graphics/mesa_x86_64_no_neon.patch)
* [mesa_libcxx_algorithm.patch](https://github.com/Harmony-Oneir/oneir_patches/blob/main/graphics/mesa_libcxx_algorithm.patch)
* [mesa_ohos_no_wsi_display.patch](https://github.com/Harmony-Oneir/oneir_patches/blob/main/graphics/mesa_ohos_no_wsi_display.patch)
* [mesa_ohos_vulkan_kms.patch](https://github.com/Harmony-Oneir/oneir_patches/blob/main/graphics/mesa_ohos_no_wsi_display.patch)
* [mesa_ohos_vk_registry.patch](https://github.com/Harmony-Oneir/oneir_patches/blob/main/graphics/mesa_ohos_vk_registry.patch)

Сборка зависимости драйвера под x86_64:
```
./oneir/make.sh //third_party/libdrm:libdrm
./oneir/make.sh //third_party/zlib:libz
./oneir/make.sh //foundation/resourceschedule/qos_manager/frameworks/native:qos_ndk
```
Кросс-файл под x86_64:
```
bash oneir/gen_mesa_cross_x86_64.sh /home/openharmony out/oneir
cat out/oneir/thirdparty/mesa3d-vk/cross_file
cat out/oneir/thirdparty/mesa3d-vk/pkgconfig/libdrm.pc
```
Сборка anv:
```
cd /home/openharmony/out/oneir
rm -rf thirdparty/mesa3d-vk/build
meson setup thirdparty/mesa3d-vk/build ../../third_party/mesa3d \
  --cross-file=thirdparty/mesa3d-vk/cross_file -Dbuildtype=release \
  -Dprefix=/vendor -Dlibdir=lib64 \
  -Dplatforms=ohos -Dvulkan-drivers=intel -Dgallium-drivers= \
  -Dopengl=false -Degl=disabled -Dgles1=disabled -Dgles2=disabled -Dglx=disabled -Dgbm=disabled \
  -Dllvm=disabled -Dintel-rt=disabled -Dtools= -Dcpp_rtti=false \
  -Dzstd=disabled -Dxmlconfig=disabled \
  -Dmesa-clc=system -Dprecomp-compiler=system
DESTDIR=$PWD/thirdparty/mesa3d-vk/stage ninja -C thirdparty/mesa3d-vk/build install
find thirdparty/mesa3d-vk/build -name "libvulkan_intel.so" -o -name "intel_icd*.json"
```
Результат сборки `out/oneir/thirdparty/mesa3d-vk/build/src/intel/vulkan/libvulkan_intel.so`. Зависимости:
| Зависимость | Описание |
|---|---|
| `libhitrace_meter.so` | Трассировка OpenHarmony (hitrace): метки производительности Mesa видны в hitrace и SmartPerf рядом с метками RS |
| `libhilog.so` | Система логирования OpenHarmony: сообщения драйвера пишутся в hilog |
| `libbegetutil.z.so` | Клиентская библиотека init: чтение системных параметров, например `persist.sys.graphic.openMesa3dTrace`, который включает трассировку Mesa |
| `libqos.so` | C-API NDK из qos_manager (цель `qos_ndk`): выставляет приоритет (QoS) рабочим потокам Mesa через `OH_QoS_SetThreadQoS` |
| `libexpat.so.1` | Разбор XML. Собран из подпроекта Mesa (`subprojects/expat-2.5.0`), а не взят из OpenHarmony, поэтому его нужно установить на целевую систему вместе с драйвером |
| `libdrm.so` | Работа с DRM-устройством ядра: открытие `/dev/dri/*`, ioctl'ы драйвера `i915`, буферы и синхронизация |
| `libshared_libz.z.so` | zlib из OpenHarmony: сжатие кэша шейдеров на диске |
| `libc++.so` | Стандартная библиотека C++ из OpenHarmony clang (компилятор шейдеров Intel написан на C++) |
| `libc.so` | Стандартная библиотека C (musl OpenHarmony) |


Для проверки Vulkan запустите тесты [vk_probe.c](https://github.com/Harmony-Oneir/tests/blob/main/graphics/vk_probe.c).
