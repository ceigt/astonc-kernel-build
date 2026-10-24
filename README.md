# astonc baseline kernel build

Build-validation workflow for AlphaDroid 4.7 (2026-09-01), OnePlus Ace 3 (`astonc`).

The first stage rebuilds the existing kernel versions. It does not upgrade KernelSU/SUSFS, generate a boot image, connect to a phone, or flash anything.

## Pinned inputs

- Kernel: `a62400d531bc7c26747001eb3f7c9d505a94dbdf` (5.15.197).
- KernelSU-Next gitlink: `87e4122f73a94ff829b347ccdf1b2f2e8d60eb78`.
- SUSFS: v2.1.0, already integrated in that kernel source.
- Official Android Clang: r563880c / build 14054515 / 21.0.0, pinned AOSP prebuilt commit.
- `configs/astonc-baseline.config`: running-kernel configuration, also verified against the existing boot image's embedded IKCONFIG. No boot image or device identifier is uploaded.
- Module and device-tree repositories: timestamp-selected source candidates. These are not claimed to be the exact original ROM manifest pins.

## Run

Use **Actions → astonc baseline kernel → Run workflow**. Changes to the workflow, scripts, lock file or configuration on `main` also trigger a build. Documentation-only changes do not trigger a build.

The disposable Ubuntu runner installs its build dependencies and allocates 8 GiB swap. It keeps Full LTO, CFI, MODVERSIONS and module signature protection. Semantic configuration changes outside compiler/tool version probes stop the build for review.

## Results

Download `astonc-baseline-validation-<run number>` from the run's artifacts. Logs and provenance are uploaded even when compilation fails.

A successful run produces a raw `Image.experimental`, symbol information, embedded kernel configuration, source pins and SHA-256 checksums. It does **not** produce `boot.img` or a flashable package. Original vendor signing keys, full ROM dependency matching, module ABI compatibility and a device boot test remain separate requirements.

Only public-source references, build definitions and the kernel configuration are stored here. The original boot partition backup remains local.
