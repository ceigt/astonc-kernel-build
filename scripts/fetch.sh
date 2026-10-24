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
[[ $(git -C src/sm8550 rev-parse HEAD:KernelSU-Next) == "$expected_ksu" ]] || {
  echo 'Pinned KernelSU commit does not match kernel gitlink.'; exit 1;
}
# KernelSU derives its version from Git history, so keep its real repository and tags.
git clone --filter=blob:none --no-checkout "$(read_lock kernelsu url)" src/sm8550/KernelSU-Next
git -C src/sm8550/KernelSU-Next checkout --detach "$expected_ksu"
[[ $(git -C src/sm8550/KernelSU-Next rev-parse HEAD) == "$expected_ksu" ]] || exit 1
[[ -f src/sm8550/drivers/kernelsu/Kconfig ]] || { echo 'KernelSU symlink does not resolve.'; exit 1; }
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
