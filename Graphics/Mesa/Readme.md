# Инструменты Mesa для кросс-сборки Vulkan-драйвера Intel
Vulkan-драйвер Intel (anv) входит в состав Mesa. Начиная с Mesa 25 часть его внутренних шейдеров написана на OpenCL C и компилируется прямо во время сборки драйвера. Для этого используются две программы: mesa_clc переводит OpenCL C в SPIR-V, а vtn_bindgen генерирует из него код для драйвера. При кросс-сборке под OpenHarmony эти программы запускаются на машине сборки, а не на целевой системе, поэтому собрать их в рамках той же кросс-сборки нельзя: для этого понадобился бы LLVM под OpenHarmony, которого нет. Их собирают заранее, отдельно, и передают в кросс-сборку опцией -Dmesa-clc=system.

Контейнер сборки OpenHarmony основан на Ubuntu 20.04, и для этих инструментов в нём не хватает почти всего: нужны LLVM 18 с libclc, SPIRV-LLVM-Translator, SPIRV-Tools, свежие meson, libdrm и zstd. Ставить всё это в основной контейнер рискованно, поэтому инструменты собираются в отдельном контейнере mesa-tools на той же Ubuntu 20.04. Совпадение основы важно: собранные программы должны запускаться в контейнере сборки OpenHarmony, а значит не могут требовать более новую glibc. Инструменты также должны быть собраны из той же версии Mesa, что и кросс-собираемый драйвер, поэтому контейнер берёт исходники прямо из дерева OpenHarmony (third_party/mesa3d).

## Файлы
| Файл | Назначение |
|---|---|
| `Dockerfile` | Образ на Ubuntu 20.04 с LLVM 18, libclc-18, SPIRV-Headers/Tools, SPIRV-LLVM-Translator (ветка `llvm_release_180`), libdrm 2.4.120, zstd 1.5.6, meson 1.4.1, cmake |
| `build-tools.sh` | Сборка Mesa из `/src/third_party/mesa3d` с драйвером Intel и установка `mesa_clc` и `vtn_bindgen` в `/out/install/bin` |

## Сборка

```bash
docker build -t mesa-tools -f Dockerfile .
```
Инструменты (дерево OpenHarmony монтируется только для чтения, результат — в `./out`):
```bash
docker run --rm \
  -v <путь к дереву OpenHarmony>:/src:ro \
  -v $PWD/out:/out \
  mesa-tools
```
Результат: `out/install/bin/mesa_clc` и `out/install/bin/vtn_bindgen`. Попутно собирается
`libvulkan_intel.so` под glibc — для OpenHarmony он не годится и не используется.
Перед сборкой проверьте, что версия Mesa совпадает с той, которую будете кросс-компилировать:

```bash
cat <путь к дереву OpenHarmony>/third_party/mesa3d/VERSION
```
