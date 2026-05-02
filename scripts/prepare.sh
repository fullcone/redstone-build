#!/bin/sh
# Remote-side: prepare ImmortalWrt build tree on /mnt/nvme/.
# - clones ImmortalWrt 24.10 if not present
# - runs feeds update + install
# - applies our patches/ if any
# Idempotent.

set -eu

NVME=/mnt/nvme
IMM_BRANCH=openwrt-24.10
IMM_TAG=v24.10.6

cd "$NVME"

# OpenWrt build needs ~70 host packages. Install once (idempotent).
DEPS="ack antlr3 asciidoc autoconf automake autopoint binutils bison \
build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler ecj \
fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf \
haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev \
libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld \
llvm lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf \
python3 python3-pip python3-ply python3-docutils python3-pyelftools \
qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd"

if ! dpkg -l libncurses-dev 2>/dev/null | grep -q '^ii'; then
    echo "==> apt install OpenWrt build deps (~70 packages)"
    apt-get install -y $DEPS 2>&1 | tail -5
fi

if [ ! -d immortalwrt/.git ]; then
    echo "==> cloning ImmortalWrt $IMM_BRANCH"
    git clone --depth 100 --branch "$IMM_BRANCH" \
        https://github.com/immortalwrt/immortalwrt.git immortalwrt
fi

cd immortalwrt
echo "==> ImmortalWrt at $(git log --oneline -1)"

echo "==> feeds update + install"
./scripts/feeds update -a 2>&1 | tail -5
./scripts/feeds install -a 2>&1 | tail -5

echo "==> done"
