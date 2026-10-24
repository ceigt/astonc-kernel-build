#!/usr/bin/env python3
"""Collect bounded diagnostics, hashes and truthful build status, even on failure."""
import hashlib
import json
import os
from pathlib import Path
import shutil


def main():
    artifacts = Path("artifacts")
    artifacts.mkdir(exist_ok=True)
    for source, target in [("sources.lock.json", "sources.lock.json"),
                           ("configs/astonc-baseline.config", "baseline.config"),
                           ("out/.config", "generated.config")]:
        if Path(source).is_file():
            shutil.copyfile(source, artifacts / target)
    status = artifacts / "compile-status.txt"
    built = status.is_file() and status.read_text().strip() == "success"
    image = artifacts / "Image.experimental"
    provenance = {
        "compile_succeeded": built,
        "image_present": image.is_file(),
        "validation_only": True,
        "boot_image_generated": False,
        "flashing_or_device_access": False,
        "repository": os.getenv("GITHUB_REPOSITORY"),
        "workflow_commit": os.getenv("GITHUB_SHA"),
        "run_id": os.getenv("GITHUB_RUN_ID"),
        "run_url": f'https://github.com/{os.getenv("GITHUB_REPOSITORY", "")}/actions/runs/{os.getenv("GITHUB_RUN_ID", "")}',
        "limitations": ["Not a flashable boot image", "No device boot test",
                        "Vendor module signing keys and full original ROM manifest are unavailable",
                        "Modules/device-tree commits are timestamp-selected candidates, not proven original build pins"],
    }
    (artifacts / "build-result.json").write_text(json.dumps(provenance, indent=2) + "\n")
    (artifacts / "READ-ME-FIRST.txt").write_text(
        "Experimental baseline build validation.\n"
        "Image.experimental is a raw kernel, NOT boot.img.\n"
        "Do not flash these artifacts. No phone was accessed by this workflow.\n"
        "A successful compile does not establish module/signature compatibility or bootability.\n"
        "Check build-result.json and config-verification.json.\n"
    )
    checksums = []
    for file in sorted(artifacts.iterdir()):
        if file.is_file() and file.name != "SHA256SUMS":
            checksums.append(f"{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}\n")
    (artifacts / "SHA256SUMS").write_text("".join(checksums))
    summary = os.getenv("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as handle:
            handle.write(f"## Baseline kernel build\n\nCompile succeeded: **{built}**\n\n")
            handle.write("Artifacts contain logs, source pins, configuration checks and SHA-256 checksums.\n\n")
            handle.write("Validation only. No boot image, flashing, reboot or device access.\n")
    print(json.dumps(provenance, indent=2))


if __name__ == "__main__":
    main()
