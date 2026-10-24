#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p artifacts src toolchain
exec > >(tee artifacts/fetch.log) 2>&1
read_lock() { python3 -c 'import json,sys; d=json.load(open("sources.lock.json")); print(d[sys.argv[1]][sys.argv[2]])' "$1" "$2"; }
fetch_pinned() {
  local section=$1 target=$2 url commit
  url=$(read_lock "$section" url)
  commit=$(read_lock "$section" commit)
  [[ "$url" == https://github.com/* && "$commit" =~ ^[0-9a-f]{40}$ ]] || exit 1
  [[ ! -e "$target" ]] || { echo "Refusing to replace $target"; exit 1; }
  git init "$target"
  git -C "$target" remote add origin "$url"
  git -C "$target" fetch --depth=1 --no-tags origin "$commit"
  git -C "$target" checkout --detach FETCH_HEAD
  [[ $(git -C "$target" rev-parse HEAD) == "$commit" ]] || exit 1
}
fetch_pinned kernel src/sm8550
expected_ksu=$(read_lock kernelsu commit)
git clone --filter=blob:none --no-checkout "$(read_lock kernelsu upstream_url)" src/sm8550/KernelSU-Next
git -C src/sm8550/KernelSU-Next fetch "$(read_lock kernelsu url)" "$expected_ksu"
git -C src/sm8550/KernelSU-Next checkout -b dev-susfs "$expected_ksu"
git -C src/sm8550/KernelSU-Next update-ref refs/remotes/origin/dev "$(read_lock kernelsu upstream_base)"
git -C src/sm8550/KernelSU-Next merge-base --is-ancestor "$(read_lock kernelsu stable_ancestor)" HEAD
[[ $(git -C src/sm8550/KernelSU-Next rev-parse HEAD) == "$expected_ksu" ]]
git -C src/sm8550/KernelSU-Next describe --tags --long | tee artifacts/kernelsu-source-version.txt
echo "$(read_lock susfs local_patch_sha256)  upgrade/susfs-210-to-230.patch" | sha256sum --check --strict
git -C src/sm8550 apply --check "$PWD/upgrade/susfs-210-to-230.patch"
git -C src/sm8550 apply "$PWD/upgrade/susfs-210-to-230.patch"
git -C src/sm8550 diff --check
git -C src/sm8550 diff --stat > artifacts/applied-kernel-changes.txt
grep -Fx '#define SUSFS_VERSION "v2.3.0"' src/sm8550/include/linux/susfs.h
[[ -f src/sm8550/drivers/kernelsu/Kconfig ]]
fetch_pinned modules src/sm8550-modules
fetch_pinned devicetrees src/sm8550-devicetrees

toolchain_commit=$(read_lock toolchain commit)
toolchain_dir=$(read_lock toolchain directory)
toolchain_repository=$(read_lock toolchain repository)
[[ "$toolchain_repository" == https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 ]] || exit 1
[[ "$toolchain_commit" =~ ^[0-9a-f]{40}$ && "$toolchain_dir" == clang-r563880c ]] || exit 1
archive_url="$toolchain_repository/+archive/$toolchain_commit/$toolchain_dir.tar.gz"
curl --fail --location --retry 4 --retry-delay 10 --connect-timeout 30 --max-time 1800 \
  "$archive_url" -o toolchain/clang.tar.gz
echo "$(read_lock toolchain archive_sha256)  toolchain/clang.tar.gz" | sha256sum --check --strict
sha256sum toolchain/clang.tar.gz > artifacts/toolchain-archive.sha256
printf '%s\n' "$archive_url" > artifacts/toolchain-source-url.txt
mkdir toolchain/clang
tar -xzf toolchain/clang.tar.gz -C toolchain/clang
rm -- toolchain/clang.tar.gz
toolchain/clang/bin/clang --version | tee artifacts/clang-version.txt
grep -F '14054515' artifacts/clang-version.txt
grep -F 'r563880c' artifacts/clang-version.txt
grep -F 'clang version 21.0.0' artifacts/clang-version.txt
toolchain/clang/bin/ld.lld --version | tee artifacts/lld-version.txt
for section in kernel kernelsu modules devicetrees; do
  printf '%s %s\n' "$section" "$(read_lock "$section" commit)"
done | tee artifacts/source-commits.txt
df -h .
