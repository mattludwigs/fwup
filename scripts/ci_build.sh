#!/bin/bash

#
# Build script for CircleCi
#
# Inputs:
#    CIRCLE_OS_NAME - "linux" or "osx"
#    MODE           - "static", "dynamic", "windows", or "raspberrypi"
#
# Static builds use scripts to download libarchive, libconfuse, and libsodium,
# so those are only installed on shared library builds.
#

set -e
set -v

# Create ./configure
./autogen.sh

case "${CIRCLE_OS_NAME}-${MODE}" in
    *-static)
        # If this is a static build, run 'build_pkg.sh'
        bash -v scripts/build_pkg.sh
        exit 0
        ;;
    linux-dynamic)
        ./configure --enable-gcov
        ;;
    linux-singlethread)
        # The verify-syscalls script can't follow threads, so
        # single thread builds are the only way to verify that
        # the issued read and write calls follow the expected
        # alignment, size and order
        ./configure --enable-gcov --without-pthreads
        ;;
    osx-dynamic)
        PKG_CONFIG_PATH="/usr/local/opt/libarchive/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH" ./configure;
        ;;
    linux-windows)
        CC=x86_64-w64-mingw32-gcc \
            CROSS_COMPILE=x86_64-w64-mingw32 \
            bash -v scripts/build_pkg.sh
        exit 0
        ;;
    linux-raspberrypi)
        CC=arm-linux-gnueabihf-gcc \
            CROSS_COMPILE=arm-linux-gnueabihf \
            PATH=~/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin:$PATH \
            QEMU_LD_PREFIX=~/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/arm-linux-gnueabihf/libc/lib/arm-linux-gnueabihf \
            bash -v scripts/build_pkg.sh
        exit 0
        ;;
    *)
        echo "Unexpected build option: ${CIRCLE_OS_NAME}-${MODE}"
        exit 1
esac

# Normal build
make -j4
make -j4 check
make dist

# Check that the distribution version works by building it again
mkdir distcheck
cd distcheck
tar xf ../fwup-*.tar.gz
cd fwup-*
if [ "$CIRCLE_OS_NAME" = "linux" ]; then
    ./configure;
else
    PKG_CONFIG_PATH="/usr/local/opt/libarchive/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH" ./configure;
fi
make -j4
make -j4 check
cd ../..
