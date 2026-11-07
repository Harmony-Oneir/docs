#!/bin/bash
# Собирает инструменты mesa для машины сборки.
#
# Дерево OpenHarmony ожидается в /src (только чтение),
# результат кладётся в /out.
#
# Собираем не графику, а компилятор шейдеров: он нужен кросс-сборке
# драйвера Intel, которая сама его построить не может — ей пришлось бы
# иметь LLVM для целевой системы, чего у нас нет.

set -eu

SRC=${SRC:-/src/third_party/mesa3d}
OUT=${OUT:-/out}
BUILD=$OUT/build
PREFIX=$OUT/install

[ -d "$SRC" ] || { echo "нет дерева mesa: $SRC"; exit 1; }

rm -rf "$BUILD" "$PREFIX"
mkdir -p "$OUT"

echo "== настройка =="
meson setup "$SRC" "$BUILD" \
    -Dbuildtype=release \
    -Dvulkan-drivers=intel \
    -Dgallium-drivers= \
    -Dplatforms= \
    -Dglx=disabled -Degl=disabled \
    -Dgles1=disabled -Dgles2=disabled -Dopengl=false \
    -Dintel-clc=enabled -Dinstall-intel-clc=true \
    -Dinstall-mesa-clc=true \
    -Dintel-rt=disabled \
    -Dtools= \
    --prefix="$PREFIX"

echo "== сборка =="
ninja -C "$BUILD"

echo "== установка =="
ninja -C "$BUILD" install

echo
echo "готово, инструменты:"
ls -l "$PREFIX/bin"
