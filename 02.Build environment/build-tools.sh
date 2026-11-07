#!/bin/bash
# Собирает инструменты Mesa (mesa_clc, vtn_bindgen) для машины сборки и
# готовит всё, что нужно перенести в образ сборки OpenHarmony:
#   $OUT/install/bin  — программы
#   $OUT/deps         — их разделяемые библиотеки (LLVM 18, SPIRV и др.)
#   $OUT/runtime.tar  — данные по абсолютным путям (заголовки clang, libclc)
set -eu

SRC=${SRC:-/src/mesa3d}
OUT=${OUT:-/out}
BUILD=$OUT/build
PREFIX=$OUT/install

[ -d "$SRC" ] || { echo "нет дерева mesa: $SRC"; exit 1; }
rm -rf "$BUILD" "$PREFIX" "$OUT/deps" "$OUT/runtime.tar"
mkdir -p "$OUT"

echo "== версия mesa: $(cat "$SRC/VERSION") =="

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
ninja -C "$BUILD" install

echo "== зависимости =="
mkdir -p "$OUT/deps"
# Всё, кроме базовых библиотек glibc: они одинаковы в обоих образах (оба на Ubuntu 20.04).
for b in "$PREFIX"/bin/*; do
  ldd "$b" | awk '$3 ~ /^\// {print $3}'
done | sort -u \
  | grep -vE '/(libc|libm|libdl|libpthread|librt|ld-linux-x86-64)\.so' \
  | while read -r lib; do cp -L "$lib" "$OUT/deps/"; done
ls "$OUT/deps"

echo "== данные по абсолютным путям =="
# Заголовки clang (opencl-c-base.h и др.) и библиотеки libclc ищутся по путям,
# зашитым при сборке, поэтому переносятся по тем же путям.
paths=()
for p in /usr/lib/llvm-18/lib/clang /usr/lib/clc /usr/lib/llvm-18/lib/clc /usr/share/clc; do
  [ -e "$p" ] && paths+=("${p#/}")
done
tar -cf "$OUT/runtime.tar" -C / "${paths[@]}"
echo "в runtime.tar: ${paths[*]}"

echo
echo "готово, инструменты:"
ls -l "$PREFIX/bin"
