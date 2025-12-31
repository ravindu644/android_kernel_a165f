#!/bin/bash
set -x

echo -e "\n[INFO]: BUILD STARTED..!\n"

export SCRIPT_DIR="$(dirname $(readlink -fq $0))"
mkdir -p "${SCRIPT_DIR}/dist"

# Init submodules
git submodule init && git submodule update

# Install the requirements for building the kernel when running the script for the first time
check_requirements_and_install_tc(){
    if [ ! -f ".requirements" ] && [ "$USER" != "ravindu644" ]; then
        echo -e "\n[INFO]: INSTALLING REQUIREMENTS..!\n"
        {
            sudo apt update
            sudo apt install -y rsync python2
        } && touch .requirements
    fi

    # Init Samsung's ndk
    if [[ ! -d "${SCRIPT_DIR}/kernel/prebuilts" || ! -d "${SCRIPT_DIR}/prebuilts" ]]; then
        echo -e "\n[INFO] Cloning Samsung's NDK...\n"
        curl -LO "https://github.com/ravindu644/android_kernel_a165f/releases/download/toolchain/toolchain.tar.gz"
        tar -xf toolchain.tar.gz && rm toolchain.tar.gz
        cd "${SCRIPT_DIR}"
    fi
}

# Localversion
if [ -z "$BUILD_KERNEL_VERSION" ]; then
    export BUILD_KERNEL_VERSION="dev"
fi

echo -e "CONFIG_LOCALVERSION_AUTO=n\nCONFIG_LOCALVERSION=\"-ravindu644-${BUILD_KERNEL_VERSION}\"\n" > "${SCRIPT_DIR}/custom_defconfigs/version_defconfig"

# CHANGED DIR
cd "${SCRIPT_DIR}/kernel-5.10"

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
export MERGE_CONFIG="${SCRIPT_DIR}/kernel-5.10/scripts/kconfig/merge_config.sh"

# Build options
export GKI_KERNEL_BUILD_OPTIONS="
    SKIP_MRPROPER=1 \
    KMI_SYMBOL_LIST_STRICT_MODE=0 \
    ABI_DEFINITION= \
    BUILD_BOOT_IMG=1 \
    MKBOOTIMG_PATH=${SCRIPT_DIR}/mkbootimg/mkbootimg.py \
    KERNEL_BINARY=Image.gz \
    BOOT_IMAGE_HEADER_VERSION=4 \
    SKIP_VENDOR_BOOT=1 \
    AVB_SIGN_BOOT_IMG=1 \
    AVB_BOOT_PARTITION_SIZE=67108864 \
    AVB_BOOT_KEY=${SCRIPT_DIR}/mkbootimg/tests/data/testkey_rsa2048.pem \
    AVB_BOOT_ALGORITHM=SHA256_RSA2048 \
    AVB_BOOT_PARTITION_NAME=boot \
    GKI_RAMDISK_PREBUILT_BINARY=${SCRIPT_DIR}/oem_prebuilt_images/gki-ramdisk.lz4 \
    LTO=full \
"

# Build options (extra)
export MKBOOTIMG_EXTRA_ARGS="
    --os_version 12.0.0 \
    --os_patch_level 2025-05-00 \
    --pagesize 4096 \
"
export GKI_RAMDISK_PREBUILT_BINARY="${SCRIPT_DIR}/oem_prebuilt_images/gki-ramdisk.lz4"

# Run menuconfig only if you want to.
# It's better to use MAKE_MENUCONFIG=0 when everything is already properly enabled, disabled, or configured.
export MAKE_MENUCONFIG=0

if [ "$MAKE_MENUCONFIG" = "1" ]; then
    export HERMETIC_TOOLCHAIN=0
fi

# CHANGED DIR
cd "${SCRIPT_DIR}/kernel"

# Main cooking progress
build_kernel(){
    ( env ${GKI_KERNEL_BUILD_OPTIONS} ./build/build.sh || exit 1 ) && \
        ( cp "${SCRIPT_DIR}/out/target/product/a16/obj/KERNEL_OBJ/boot.img" "${SCRIPT_DIR}/dist" 
        cp "${SCRIPT_DIR}/out/target/product/a16/obj/KERNEL_OBJ/kernel-5.10/arch/arm64/boot/Image.gz" "${SCRIPT_DIR}/dist" )
}

# build vendor boot
build_vendor_boot(){
    SCRIPT_DIR="${SCRIPT_DIR}" \
        "${SCRIPT_DIR}/prebuilts_helio_g99/scripts/build_vendor_boot.sh"
}

# build vendor dlkm
build_vendor_dlkm(){
    SCRIPT_DIR="${SCRIPT_DIR}" \
        "${SCRIPT_DIR}/prebuilts_helio_g99/scripts/build_vendor_dlkm.sh"
}

# package stuffs
package_stuff(){
    cd "${SCRIPT_DIR}/dist"

    tar -cvf "KernelSU-Next-SM-A165F-${BUILD_KERNEL_VERSION}.tar" boot.img vendor_boot.img || {
        echo "Error: Failed to create tar file"
        return 1
    }

    zip -9 -r "KernelSU-Next-SM-A165F-${BUILD_KERNEL_VERSION}-packaged.zip" \
        "KernelSU-Next-SM-A165F-${BUILD_KERNEL_VERSION}.tar" \
        vendor_dlkm.img || {
        echo "Error: Failed to create zip file"
        return 1
    }

    rm -f "KernelSU-Next-SM-A165F-${BUILD_KERNEL_VERSION}.tar" vendor_dlkm.img boot.img vendor_boot.img

    cd "${SCRIPT_DIR}"
}

check_requirements_and_install_tc
build_kernel || exit 1
build_vendor_boot
build_vendor_dlkm
package_stuff
