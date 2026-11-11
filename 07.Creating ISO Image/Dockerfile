FROM debian:trixie
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd-ukify systemd-boot-efi systemd-repart \
      dosfstools e2fsprogs mtools fdisk \
    && rm -rf /var/lib/apt/lists/*
