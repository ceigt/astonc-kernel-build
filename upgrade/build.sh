#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p artifacts out
exec > >(tee artifacts/build.log) 2>&1
export PATH="$PWD/toolchain/clang/bin:$PATH"
export ARCH=arm64
export LLVM=1 LLVM_IAS=1
export CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
[[ ${JOBS:-2} =~ ^[1-4]$ ]] || { echo 'Invalid worker count'; exit 1; }
kernel_source="$PWD/src/sm8550"
kernel_out="$PWD/out"
make_args=(-C "$kernel_source" O="$kernel_out" ARCH=arm64 LLVM=1 LLVM_IAS=1)
cp configs/astonc-baseline.config "$kernel_out/.config"
"$kernel_source/scripts/config" --file "$kernel_out/.config" --set-str LOCALVERSION '-ksun342-susfs230-exp' \
  --disable KSU_SAMSUNG_KDP --disable KSU_SAMSUNG_RKP --disable KSU_SAMSUNG_DEFEX --disable KSU_SAMSUNG_NO_PATCH_TEXT
make "${make_args[@]}" olddefconfig
cp "$kernel_out/.config" artifacts/generated.config
python3 upgrade/verify-config.py configs/astonc-baseline.config "$kernel_out/.config" artifacts/config-verification.json
make "${make_args[@]}" -s kernelrelease | tee artifacts/kernelrelease.txt
grep -E '^5\.15\.197-ksun342-susfs230-exp' artifacts/kernelrelease.txt
printf '%s\n' 'Building experimental upgraded Image and in-tree modules; no boot image is generated.'
# Keep Full LTO and CFI enabled. Limit linker concurrency rather than changing these options.
# Compile changed core paths first to surface integration errors before Full LTO.
make "${make_args[@]}" -j"${JOBS:-2}" net/netfilter/xt_DSCP.o
make "${make_args[@]}" -j"${JOBS:-2}" drivers/kernelsu/ fs/ kernel/ mm/ security/ drivers/input/
make "${make_args[@]}" -j"${JOBS:-2}" LD="$PWD/scripts/ld-lld-single-thread.sh" Image modules
cp "$kernel_out/arch/arm64/boot/Image" artifacts/Image.experimental
cp "$kernel_out/Module.symvers" artifacts/Module.symvers
cp "$kernel_out/System.map" artifacts/System.map
bash "$kernel_source/scripts/extract-ikconfig" artifacts/Image.experimental > artifacts/Image.config
cmp "$kernel_out/.config" artifacts/Image.config
python3 upgrade/verify-versions.py artifacts/Image.experimental artifacts/build.log artifacts/upgrade-verification.json
printf '%s\n' 'success' > artifacts/compile-status.txt
