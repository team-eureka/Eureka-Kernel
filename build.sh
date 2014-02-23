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
kernel_repo="https://github.com/team-eureka/eureka_linux.git"
toolchain_repo="https://code.google.com/p/chromecast-mirrored-source.prebuilt/"
cctools_repo="https://github.com/tchebb/chromecast-tools.git"

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
    # Build kernel
    run_kernel_make $cross_compile $cpu_num $arch zImage-dtb.berlin2cd-dongle
	cd -
}

function move_kernel(){
	if [ ! -d "$PWD/output" ]; then
		mkdir $PWD/output
	fi
	
	for f in ${COPY_FILE_LIST[@]}
    do
      s=${f%%:*}
      d=${f##*:}
      cp $kernel_dir/$s $PWD/output/$d
    done
}

# LZOP package check
if [ ! -z "$(which lzop)" ] ; then
	echo "lzop is not installed. Install it with sudo apt-get install lzop. Terminating..."
	exit 1
fi

# Kernel Src DL
if [ ! -d "$PWD/$kernel_dir" ]; then
	echo "kernel Directory $kernel_dir does not exist, Downloading..."
	mkdir -p $PWD/$kernel_dir
	git clone --progress $kernel_repo $PWD/$kernel_dir
fi

# Chromecast Toolchain DL
if [ -d "$PWD/source/chromecast-mirrored-source/" ] || [ ! -z "$(which arm-unknown-linux-gnueabi-gcc)" ] ; then
	if [ -z "$(which arm-unknown-linux-gnueabi-gcc)" ] ; then
		PATH="$PWD/source/chromecast-mirrored-source/toolchain/arm-unknown-linux-gnueabi-4.5.3-glibc/bin:$PATH"
	fi
else
	echo "Chromecast toolchain is missing, Downloading..."
	git clone --progress $toolchain_repo $PWD/source/chromecast-mirrored-source/
	PATH="$PWD/source/chromecast-mirrored-source/toolchain/arm-unknown-linux-gnueabi-4.5.3-glibc/bin:$PATH"
fi

# Chromecast-Tools DL
if [ -d "$PWD/source/chromecast-tools" ] || [ ! -z "$(which cc-make-bootimg)" ] ; then
	if [ -z "$(which cc-make-bootimg)" ] ; then
		PATH="$PWD/source/chromecast-tools:$PATH"
	fi
else
	echo "Chromecast-Tools is missing, Downloading..."
	git clone --progress $cctools_repo $PWD/source/chromecast-tools/
	gcc $PWD/source/chromecast-tools/cc-mangle-bootimg.c -o $PWD/source/chromecast-tools/cc-mangle-bootimg
	chmod +x $PWD/source/chromecast-tools/*
	PATH="$PWD/source/chromecast-tools:$PATH"
fi

# Build kernel
build_kernel $kernel_dir

# Create a kernel package
move_kernel $kernel_dir

# Will add the fun parts of building a flashable image later
# Need to have a way to pull down a initramfs to modify and all first