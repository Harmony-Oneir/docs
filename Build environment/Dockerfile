# Шаг 1: Базовый образ (судя по слоям, это Ubuntu)
FROM ubuntu:20.04

# Шаг 2: Создание директории для инструментов
WORKDIR /home/openharmony

# Шаг 3: Настройка неинтерактивного режима установки
ARG DEBIAN_FRONTEND=noninteractive

# Шаг 4: Основной блок установки пакетов, компиляторов и утилит
RUN set -xe \
    # Настройка зеркала Huawei для APT и обновление пакетов
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
    # Установка Python-пакетов
    && pip3 install --trusted-host https://repo.huaweicloud.com -i https://repo.huaweicloud.com/repository/pypi/simple pycryptodome ecdsa redis \
    # Создание папки для инструментов и скачивание бинарников OpenHarmony
    && mkdir -p /home/tools/gn \
    && mkdir -p /home/tools/ninja \
    && wget -P /home/tools https://mirrors.huaweicloud.com/nodejs/v14.19.1/node-v14.19.1-linux-x64.tar.xz \
    && wget -P /home/tools https://repo.huaweicloud.com/harmonyos/compiler/ninja/1.10.1/linux/ninja-linux-x86-1.10.1.tar.gz \
    && wget -P /home/tools https://repo.huaweicloud.com/harmonyos/compiler/gn/2021/linux/gn-linux-x86-2021.tar.gz \
    && wget -P /home/tools https://repo.huaweicloud.com/harmonyos/compiler/clang/12.0.1-36cd05/linux/clang_linux-x86_64-36cd05-20221030.tar.bz2 \
    # Генерация локали
    && locale-gen "en_US.UTF-8" \
    # Очистка старых интерпретаторов Python и привязка Python 3.8
    && rm -rf /bin/sh /usr/bin/python /usr/bin/python3 \
    && ln -s /bin/bash /bin/sh \
    && ln -s /usr/bin/python3.8 /usr/bin/python3 \
    && ln -s /usr/bin/python3.8 /usr/bin/python \
    # Распаковка архивов
    && tar -xvf /home/tools/clang_linux-x86_64-36cd05-20221030.tar.bz2 -C /home/tools \
    && tar -xvf /home/tools/ninja-linux-x86-1.10.1.tar.gz -C /home/tools/ninja \
    && tar -xvf /home/tools/gn-linux-x86-2021.tar.gz -C /home/tools/gn \
    && tar -xJf /home/tools/node-v14.19.1-linux-x64.tar.xz -C /home/tools \
    # Симлинки для Node.js и npm
    && cp /home/tools/node-v14.19.1-linux-x64/bin/node /usr/local/bin \
    && ln -s /home/tools/node-v14.19.1-linux-x64/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /home/tools/node-v14.19.1-linux-x64/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    # Экспорт путей в .bashrc
    && sed -i '$aexport PATH=/home/tools/clang_linux-x86_64-36cd05-20221030/bin:$PATH' /root/.bashrc \
    && sed -i '$aexport PATH=/home/tools/ninja:$PATH' /root/.bashrc \
    && sed -i '$aexport PATH=/home/tools/gn:$PATH' /root/.bashrc \
    && sed -i '$aexport PATH=/home/tools/node-v14.19.1-linux-x64/bin:$PATH' /root/.bashrc \
    && sed -i '$aexport PATH=/root/.local/bin:$PATH' /root/.bashrc \
    # Очистка скачанных архивов
    && cd /home/openharmony \
    && rm -rf /home/tools/*.xz /home/tools/*.gz /home/tools/*.tar /home/tools/*.bz2 \
    # Установка hpm-cli через npm
    && npm install -g @ohos/hpm-cli --registry https://mirrors.huaweicloud.com/repository/npm/

RUN pip3 install pyyaml
RUN apt-get update && apt-get install -y autoconf automake libtool libtool-bin autopoint pkg-config cmake

# Шаг 5: Переменные окружения по умолчанию
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=Asia/Shanghai

# Шаг 6: Команда по умолчанию
CMD ["/bin/bash"]
