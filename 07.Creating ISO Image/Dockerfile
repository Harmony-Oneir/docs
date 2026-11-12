FROM debian:trixie
RUN apt-get update && apt-get install -y \
      systemd-ukify systemd-boot-efi systemd-repart \
      dosfstools e2fsprogs mtools fdisk \
      live-build debootstrap xorriso squashfs-tools \
      grub-efi-amd64-bin grub-pc-bin syslinux-common isolinux \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*
