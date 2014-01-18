#!/bin/bash
# Build kernel for use with Eureka.
# Modified for Team-Eureka's Use by ddggttff3
# Original script: https://code.google.com/p/chromecast-mirrored-source/source/browse/build_kernel.sh?repo=kernel

set -o errtrace
trap 'echo Fatal error: script $0 aborting at line $LINENO, command \"$BASH_COMMAND\" returned $?; exit 1' ERR

# List of files to be copied to Eureka build
declare -a \
    COPY_FILE_LIST=(arch/arm/boot/zImage-dtb.berlin2cd-dongle:zImage
                    COPYING:./
                   )


# Kernel configuration for Eureka
kernel_config=eureka_stock_defconfig
arch=arm
cross_compile=arm-unknown-linux-gnueabi-
kernel_dir=source/eureka_kernel

# Repo configuration
source_repo="https://github.com/tchebb/eureka_linux.git -b stock"

cpu_num=$(grep -c processor /proc/cpuinfo)

function run_kernel_make(){
    echo "***** compiling $5 *****"
    CROSS_COMPILE=$1 make -j$2 ARCH=$3 $4
    echo "***** completed compiling $5 *****"
}

function build_kernel(){
    local kernel_dir=$(readlink -f $1)

    cd $kernel_dir

    # Clean kernel
    run_kernel_make $cross_compile $cpu_num $arch clean
    # Build kernel config
    run_kernel_make $cross_compile $cpu_num $arch $kernel_config
    # Verify kernel config
    # diff .config arch/arm/configs/$kernel_config
    # Build kernel
    run_kernel_make $cross_compile $cpu_num $arch zImage-dtb.berlin2cd-dongle
}

function create_kernel_pkg(){
    local kernel_dir=$(readlink -f $1)
    local pkg_dir=$(mktemp -d)
    local wd=$(pwd)

    for f in ${COPY_FILE_LIST[@]}
    do
      s=${f%%:*}
      d=${f##*:}
      cp $kernel_dir/$s $pkg_dir/$d
    done

    mkdir $wd/output
    (cd $pkg_dir; mv ./* $wd/output/)
    rm -fr $pkg_dir
}

# Kernel Src DL
if [ ! -d "$kernel_dir" ]; then
	echo "kernel Directory $kernel_dir does not exist, downloading..."
	mkdir -p $kernel_dir
	git clone --progress $source_repo ./$kernel_dir
fi

# Chromecast Toolchain DL
if [ ! -x $(which arm-unknown-linux-gnueabi-gcc) ]; then
	echo "Chromecast toolchain is missing, downloading..."
	git clone --progress https://code.google.com/p/chromecast-mirrored-source.prebuilt/ ./source/
	PATH="$PWD/source/toolchain/arm-unknown-linux-gnueabi-4.5.3-glibc/bin:$PATH"
else
	toolchain_path=$(which arm-unknown-linux-gnueabi-gcc | awk -F "/arm-unknown-linux-gnueabi-gcc" '{print $1}')
	PATH="$toolchain_path:$PATH"
fi

# Chromecast-Tools DL
if [ ! -x $(which cc-make-bootimg) ]; then
	echo "Chromecast-Tools is missing, downloading..."
	git clone --progress https://github.com/tchebb/chromecast-tools.git ./source/chromecast-tools/
	gcc ./source/chromecast-tools/cc-mangle-bootimg.c -o ./source/chromecast-tools/cc-mangle-bootimg
	chmod +x ./source/chromecast-tools/*
	PATH="$PWD/source/chromecast-tools:$PATH"
else
	chromecasttools_path=$(which cc-make-bootimg | awk -F "/cc-make-bootimg" '{print $1}')
	PATH="$chromecasttools_path:$PATH"
fi

# Build kernel
build_kernel $kernel_dir

# Create a kernel package
create_kernel_pkg $kernel_dir

# Will add the fun parts of building a flashable image later
# Need to have a way to pull down a initramfs to modify and all first