#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p artifacts
exec > >(tee artifacts/runner-setup.log) 2>&1
[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted && ${RUNNER_OS:-} == Linux ]] || {
  echo 'This script is restricted to disposable GitHub-hosted Linux runners.'; exit 1;
}
# Only fixed, preinstalled SDK directories on the disposable runner are removed.
for unused_sdk in /usr/share/dotnet /usr/local/lib/android /opt/ghc /opt/hostedtoolcache/CodeQL; do
  if [[ -d "$unused_sdk" && ! -L "$unused_sdk" && $(realpath -- "$unused_sdk") == "$unused_sdk" ]]; then
    sudo rm -rf -- "$unused_sdk"
  fi
done
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  bc bison build-essential ca-certificates cpio curl dwarves flex git \
  libelf-dev libssl-dev lz4 python3 rsync unzip xz-utils zstd \
  binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi
df -h .
free -h
available_kib=$(df -Pk . | awk 'NR==2 {print $4}')
(( available_kib >= 24 * 1024 * 1024 )) || { echo 'Need at least 24 GiB free before downloading sources.'; exit 1; }
swap_file="$RUNNER_TEMP/astonc-build.swap"
[[ ! -e "$swap_file" ]] || { echo 'Unexpected existing swap path.'; exit 1; }
sudo fallocate -l 8G "$swap_file"
sudo chmod 600 "$swap_file"
sudo mkswap "$swap_file"
sudo swapon "$swap_file"
free -h
dpkg-query -W -f='${Package} ${Version}\n' > artifacts/host-packages.txt
