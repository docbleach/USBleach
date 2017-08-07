#!/usr/bin/env bash
set -ex


SDK_FILE="OpenWrt-SDK-x86-64_gcc-4.8-linaro_glibc-2.21.Linux-x86_64.tar.bz2"
SDK_URL="http://downloads.overthebox.ovh/trunk/x86/64/$SDK_FILE"

if [ ! -f $SDK_FILE ]; then
    wget ${SDK_URL}
fi

rm -rf sdk || echo "sdk was already empty"
mkdir -p sdk
tar -C sdk --strip-components 1 -xjf  "$SDK_FILE"

mkdir -p sdk/package/luci-app-usbleach/
rsync -a ./ sdk/package/luci-app-usbleach/ --exclude=sdk --exclude=.git

wget https://raw.githubusercontent.com/openwrt/luci/for-15.05/luci.mk -O sdk/luci.mk

rm -fr sdk/bin/*

make -C sdk defconfig
echo "defconfig: done"
make -C sdk world V=s

cp sdk/bin/x86-glibc/packages/base/luci-app-usbleach_0.1-1_x86_64.ipk ./
echo "Package created in ./luci-app-usbleach_0.1-1_x86_64.ipk"
