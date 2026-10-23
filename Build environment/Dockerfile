# syntax=docker/dockerfile:1.4
#
# Образ сборки OpenHarmony со встроенными инструментами Mesa (mesa_clc, vtn_bindgen),
# которые нужны для кросс-сборки Vulkan-драйвера Intel (anv).
#
# Сборка (нужен BuildKit: docker 23+ или docker buildx):
#   docker build -t ohos-build \
#     --build-context mesa=<дерево OpenHarmony>/third_party/mesa3d \
#     -f Dockerfile .
#
# Исходники Mesa приходят через именованный контекст "mesa", поэтому инструменты
# всегда собираются из той же версии Mesa, что лежит в дереве, и пересобираются
# автоматически при её изменении.

############################################################################
# Этап 1: инструменты Mesa
############################################################################
FROM ubuntu:20.04 AS mesa-tools

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git pkg-config \
        python3 python3-pip python3-setuptools \
        bison flex glslang-tools \
        libexpat1-dev zlib1g-dev libwayland-dev libpciaccess-dev \
        llvm-18-dev libclang-18-dev libclc-18-dev \
    && rm -rf /var/lib/apt/lists/*

# Meson и CMake из репозитория слишком стары для mesa 25.
RUN pip3 install --no-cache-dir "meson==1.4.1" "cmake==3.29.6" ninja mako pyyaml
RUN ln -sf /usr/bin/llvm-config-18 /usr/local/bin/llvm-config

ARG SPIRV_TAG=vulkan-sdk-1.4.304.0
RUN git clone --depth 1 -b ${SPIRV_TAG} https://github.com/KhronosGroup/SPIRV-Headers.git /tmp/spirv-headers \
    && cmake -S /tmp/spirv-headers -B /tmp/spirv-headers-build \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build /tmp/spirv-headers-build -j"$(nproc)" \
    && cmake --install /tmp/spirv-headers-build \
    && git clone --depth 1 -b ${SPIRV_TAG} https://github.com/KhronosGroup/SPIRV-Tools.git /tmp/spirv-tools \
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
RUN git clone --depth 1 -b ${SPIRV_LLVM_BRANCH} https://github.com/KhronosGroup/SPIRV-LLVM-Translator.git /tmp/spirv-llvm \
    && cmake -S /tmp/spirv-llvm -B /tmp/spirv-llvm-build \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm -DBUILD_SHARED_LIBS=ON \
    && cmake --build /tmp/spirv-llvm-build -j"$(nproc)" \
    && cmake --install /tmp/spirv-llvm-build \
    && rm -rf /tmp/spirv-llvm*

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib/x86_64-linux-gnu/pkgconfig
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib/x86_64-linux-gnu

COPY build-tools.sh /build-tools.sh
# Исходники Mesa из дерева OpenHarmony (именованный контекст "mesa").
COPY --from=mesa . /src/mesa3d
RUN chmod +x /build-tools.sh && SRC=/src/mesa3d OUT=/out /build-tools.sh

############################################################################
# Этап 2: основной образ сборки OpenHarmony
############################################################################
FROM ubuntu:20.04

WORKDIR /home/openharmony
ARG DEBIAN_FRONTEND=noninteractive

RUN set -xe \
    && sed -i "s@http://.*archive.ubuntu.com@http://repo.huaweicloud.com@g" /etc/apt/sources.list \
    && sed -i "s@http://.*security.ubuntu.com@http://repo.huaweicloud.com@g" /etc/apt/sources.list \
    && apt-get update -y \
    && apt-get install -y \
        locales default-jre default-jdk libelf-dev bc rsync mtools dosfstools \
        wget curl ssh vim ccache libxi-dev libxrandr-dev libxcursor-dev \
        libxinerama-dev libpixman-1-dev qemu gcc-arm-none-eabi python2.7 \
        xsltproc lib32z1-dev libgl1-mesa-dev libx11-dev libxml2-dev kmod \
        libssl-dev openssl scons python3 mtd-utils binutils libglib2.0-dev \
        genext2fs apt-utils gnupg zlib1g-dev m4 u-boot-tools build-essential \
        unzip make libc6-dev-i386 x11proto-core-dev g++ libncurses5 libtinfo5 \
        git-lfs gcc cpio perl ruby flex bison python3-pip zip git gperf \
        doxygen liblz4-tool \
    && pip3 install --trusted-host https://repo.huaweicloud.com -i https://repo.huaweicloud.com/repository/pypi/simple pycryptodome ecdsa redis \
    && mkdir -p /home/tools/gn \
    && mkdir -p /home/tools/ninja \
    && wget -P /home/tools https://mirrors.huaweicloud.com/nodejs/v14.19.1/node-v14.19.1-linux-x64.tar.xz \
    && wget -P /home/tools https://repo.huaweicloud.com/harmonyos/compiler/ninja/1.10.1/linux/ninja-linux-x86-1.10.1.tar.gz \
    && wget -P /home/tools https://repo.huaweicloud.com/harmonyos/compiler/gn/2021/linux/gn-linux-x86-2021.tar.gz \
    && wget -P /home/tools https://repo.huaweicloud.com/harmonyos/compiler/clang/12.0.1-36cd05/linux/clang_linux-x86_64-36cd05-20221030.tar.bz2 \
    && locale-gen "en_US.UTF-8" \
    && rm -rf /bin/sh /usr/bin/python /usr/bin/python3 \
    && ln -s /bin/bash /bin/sh \
    && ln -s /usr/bin/python3.8 /usr/bin/python3 \
    && ln -s /usr/bin/python3.8 /usr/bin/python \
    && tar -xvf /home/tools/clang_linux-x86_64-36cd05-20221030.tar.bz2 -C /home/tools \
    && tar -xvf /home/tools/ninja-linux-x86-1.10.1.tar.gz -C /home/tools/ninja \
    && tar -xvf /home/tools/gn-linux-x86-2021.tar.gz -C /home/tools/gn \
    && tar -xJf /home/tools/node-v14.19.1-linux-x64.tar.xz -C /home/tools \
    && cp /home/tools/node-v14.19.1-linux-x64/bin/node /usr/local/bin \
    && ln -s /home/tools/node-v14.19.1-linux-x64/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /home/tools/node-v14.19.1-linux-x64/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && sed -i '$aexport PATH=/home/tools/clang_linux-x86_64-36cd05-20221030/bin:$PATH' /root/.bashrc \
    && sed -i '$aexport PATH=/home/tools/ninja:$PATH' /root/.bashrc \
    && sed -i '$aexport PATH=/home/tools/gn:$PATH' /root/.bashrc \
    && sed -i '$aexport PATH=/home/tools/node-v14.19.1-linux-x64/bin:$PATH' /root/.bashrc \
    && sed -i '$aexport PATH=/root/.local/bin:$PATH' /root/.bashrc \
    && cd /home/openharmony \
    && rm -rf /home/tools/*.xz /home/tools/*.gz /home/tools/*.tar /home/tools/*.bz2 \
    && npm install -g @ohos/hpm-cli --registry https://mirrors.huaweicloud.com/repository/npm/

RUN pip3 install pyyaml
RUN apt-get update && apt-get install -y autoconf automake libtool libtool-bin autopoint pkg-config cmake glslang-tools

# --- Инструменты Mesa из этапа 1 ---
# Программы и их библиотеки (LLVM 18, SPIRV и др.) — в отдельный каталог,
# чтобы не влиять на остальную сборку OpenHarmony.
COPY --from=mesa-tools /out/install/bin/mesa_clc    /usr/local/bin/mesa_clc.real
COPY --from=mesa-tools /out/install/bin/vtn_bindgen /usr/local/bin/vtn_bindgen.real
COPY --from=mesa-tools /out/deps/                   /usr/local/lib/mesa-tools-deps/
# Данные, которые инструменты ищут по абсолютным путям (заголовки clang, libclc).
COPY --from=mesa-tools /out/runtime.tar             /tmp/mesa-tools-runtime.tar
RUN tar -xf /tmp/mesa-tools-runtime.tar -C / && rm /tmp/mesa-tools-runtime.tar \
    && for t in mesa_clc vtn_bindgen; do \
         printf '#!/bin/sh\nLD_LIBRARY_PATH=/usr/local/lib/mesa-tools-deps exec /usr/local/bin/%s.real "$@"\n' $t > /usr/local/bin/$t; \
         chmod +x /usr/local/bin/$t /usr/local/bin/$t.real; \
       done \
    && mesa_clc -h > /dev/null \
    && pip3 install "meson==1.4.1" mako

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=Asia/Shanghai

CMD ["/bin/bash"]
