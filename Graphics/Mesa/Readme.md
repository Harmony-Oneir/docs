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
Сборка зависимости драйвера под x86_64:
```
./oneir/make.sh //third_party/libdrm:libdrm
./oneir/make.sh //third_party/zlib:libz
```
