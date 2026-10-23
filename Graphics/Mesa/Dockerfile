# Контейнер для сборки инструментов mesa (intel_clc, mesa_clc, vtn_bindgen).
#
# Основа — Ubuntu 20.04, та же, что у контейнера сборки OpenHarmony:
# полученные программы должны запускаться там, а значит не могут
# требовать более новую glibc.
#
# Поверх основы добираем то, чего в репозитории 20.04 нет или слишком старое:
#   LLVM 18 и libclc-18 — из репозитория, они там есть;
#   libdrm и zstd       — из исходников, версии в 20.04 ниже требуемых;
#   meson и cmake       — через pip, тоже ради версий.
#
# Сборка:
#   docker build -t mesa-tools -f Dockerfile .
#
# Использование (дерево монтируется только на чтение, результат — наружу):
#   docker run --rm \
#     -v ~/Desktop/OpenHarmony-6.1-Release:/src:ro \
#     -v $PWD/mesa-tools-out:/out \
#     mesa-tools /build-tools.sh

FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git pkg-config \
        python3 python3-pip python3-setuptools \
        bison flex glslang-tools \
        libexpat1-dev zlib1g-dev libwayland-dev \
        llvm-18-dev libclang-18-dev libclc-18-dev \
        libexpat1-dev zlib1g-dev libwayland-dev libpciaccess-dev \
    && rm -rf /var/lib/apt/lists/*

# Meson и CMake из репозитория слишком стары для mesa 25.
RUN pip3 install --no-cache-dir "meson==1.4.1" "cmake==3.29.6" ninja mako pyyaml

# llvm-config без номера версии — meson ищет именно такое имя.
RUN ln -sf /usr/bin/llvm-config-18 /usr/local/bin/llvm-config





#ARG SPIRV_TAG=vulkan-sdk-1.3.290.0

ARG SPIRV_TAG=vulkan-sdk-1.4.304.0
RUN git clone --depth 1 -b ${SPIRV_TAG} \
        https://github.com/KhronosGroup/SPIRV-Headers.git /tmp/spirv-headers \
    && cmake -S /tmp/spirv-headers -B /tmp/spirv-headers-build \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build /tmp/spirv-headers-build -j"$(nproc)" \
    && cmake --install /tmp/spirv-headers-build \
    && git clone --depth 1 -b ${SPIRV_TAG} \
        https://github.com/KhronosGroup/SPIRV-Tools.git /tmp/spirv-tools \
    && cmake -S /tmp/spirv-tools -B /tmp/spirv-tools-build \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DSPIRV-Headers_SOURCE_DIR=/tmp/spirv-headers \
        -DSPIRV_SKIP_TESTS=ON -DBUILD_SHARED_LIBS=ON \
    && cmake --build /tmp/spirv-tools-build -j"$(nproc)" \
    && cmake --install /tmp/spirv-tools-build \
    && rm -rf /tmp/spirv-*




# libdrm: в 20.04 версия 2.4.107, mesa 25 требует не ниже 2.4.109.
ARG LIBDRM_VERSION=2.4.120
RUN curl -fsSL "https://dri.freedesktop.org/libdrm/libdrm-${LIBDRM_VERSION}.tar.xz" -o /tmp/libdrm.tar.xz \
    && tar -xf /tmp/libdrm.tar.xz -C /tmp \
    && meson setup "/tmp/libdrm-${LIBDRM_VERSION}" /tmp/libdrm-build \
         --prefix=/usr/local -Dintel=enabled -Dtests=false \
    && ninja -C /tmp/libdrm-build install \
    && rm -rf /tmp/libdrm*

# zstd: в 20.04 версия 1.4.4.
ARG ZSTD_VERSION=1.5.6
RUN curl -fsSL "https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz" -o /tmp/zstd.tar.gz \
    && tar -xf /tmp/zstd.tar.gz -C /tmp \
    && make -C "/tmp/zstd-${ZSTD_VERSION}" -j"$(nproc)" install PREFIX=/usr/local \
    && rm -rf /tmp/zstd*


ARG SPIRV_LLVM_BRANCH=llvm_release_180
RUN git clone --depth 1 -b ${SPIRV_LLVM_BRANCH} \
        https://github.com/KhronosGroup/SPIRV-LLVM-Translator.git /tmp/spirv-llvm \
    && cmake -S /tmp/spirv-llvm -B /tmp/spirv-llvm-build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm \
        -DBUILD_SHARED_LIBS=ON \
    && cmake --build /tmp/spirv-llvm-build -j"$(nproc)" \
    && cmake --install /tmp/spirv-llvm-build \
    && rm -rf /tmp/spirv-llvm*



ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib/x86_64-linux-gnu/pkgconfig
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib/x86_64-linux-gnu

COPY build-tools.sh /build-tools.sh
RUN chmod +x /build-tools.sh

WORKDIR /src
CMD ["/build-tools.sh"]
echo "готово, инструменты:"
ls -l "$PREFIX/bin"
