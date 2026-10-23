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
  -Dplatforms= -Dvulkan-drivers=intel -Dgallium-drivers= \
  -Dopengl=false -Degl=disabled -Dgles1=disabled -Dgles2=disabled -Dglx=disabled -Dgbm=disabled \
  -Dllvm=disabled -Dintel-rt=disabled -Dtools= -Dcpp_rtti=false \
  -Dzstd=disabled -Dxmlconfig=disabled \
  -Dmesa-clc=system -Dprecomp-compiler=system
ninja -C thirdparty/mesa3d-vk/build
find thirdparty/mesa3d-vk/build -name "libvulkan_intel.so" -o -name "intel_icd*.json"
```
