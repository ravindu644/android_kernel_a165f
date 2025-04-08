#!/bin/bash
set -x

echo -e "\n[INFO]: BUILD STARTED..!\n"

export WDIR="$(pwd)"
mkdir -p "${WDIR}/dist"

# Init submodules
git submodule init && git submodule update

# Install the requirements for building the kernel when running the script for the first time
if [ ! -f ".requirements" ]; then
    echo -e "\n[INFO]: INSTALLING REQUIREMENTS..!\n"
    {
        sudo apt update
        sudo apt install -y rsync python2
    } && touch .requirements
fi

# Init Samsung's ndk
if [[ ! -d "${WDIR}/kernel/prebuilts" || ! -d "${WDIR}/prebuilts" ]]; then
    echo -e "\n[INFO] Cloning Samsung's NDK...\n"
    curl -LO "https://github.com/ravindu644/android_kernel_a165f/releases/download/toolchain/toolchain.tar.gz"
    tar -xf toolchain.tar.gz && rm toolchain.tar.gz
    cd "${WDIR}"
fi

# CHANGED DIR
cd "${WDIR}/kernel-5.10"

# Cook the build config
python2 scripts/gen_build_config.py \
    --kernel-defconfig a16_00_defconfig \
    --kernel-defconfig-overlays entry_level.config \
    -m user \
    -o ../out/target/product/a16/obj/KERNEL_OBJ/build.config

# OEM's variables from build_kernel.sh/README_Kernel.txt
export ARCH=arm64
export PLATFORM_VERSION=13
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_COMPAT="arm-linux-gnueabi-"
export OUT_DIR="../out/target/product/a16/obj/KERNEL_OBJ"
export DIST_DIR="../out/target/product/a16/obj/KERNEL_OBJ"
export BUILD_CONFIG="../out/target/product/a16/obj/KERNEL_OBJ/build.config"
export MERGE_CONFIG="${WDIR}/kernel-5.15/scripts/kconfig/merge_config.sh"

# Build options
export GKI_KERNEL_BUILD_OPTIONS="
    SKIP_MRPROPER=1 \
    KMI_SYMBOL_LIST_STRICT_MODE=0 \
    ABI_DEFINITION= \
"

# Run menuconfig only if you want to.
# It's better to use MAKE_MENUCONFIG=0 when everything is already properly enabled, disabled, or configured.
export MAKE_MENUCONFIG=1

if [ "$MAKE_MENUCONFIG" = "1" ]; then
    export HERMETIC_TOOLCHAIN=0
fi

# CHANGED DIR
cd "${WDIR}/kernel"

# Main cooking progress
env ${GKI_KERNEL_BUILD_OPTIONS} ./build/build.sh
