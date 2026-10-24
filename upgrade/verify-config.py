#!/usr/bin/env python3
"""Reject semantic configuration drift outside compiler/tool capability probes."""
import hashlib
import json
import pathlib
import re
import sys


def parse_config(path):
    values = {}
    for line in pathlib.Path(path).read_text().splitlines():
        if line.startswith("CONFIG_") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
        else:
            match = re.fullmatch(r"# (CONFIG_\w+) is not set", line)
            if match:
                values[match.group(1)] = "n"
    return values


def main():
    baseline, generated, destination = map(pathlib.Path, sys.argv[1:4])
    lock = json.loads(pathlib.Path("sources.lock.json").read_text())
    digest = hashlib.sha256(baseline.read_bytes()).hexdigest()
    if digest != lock["baseline"]["config_sha256"]:
        raise SystemExit("Baseline config SHA-256 mismatch")
    old, new = parse_config(baseline), parse_config(generated)
    generated_keys = {
        "CONFIG_CC_VERSION_TEXT", "CONFIG_CC_IS_CLANG", "CONFIG_CLANG_VERSION",
        "CONFIG_GCC_VERSION", "CONFIG_AS_VERSION", "CONFIG_LD_VERSION",
        "CONFIG_LLD_VERSION", "CONFIG_PAHOLE_VERSION",
    }
    changes = [
        {"symbol": key, "before": old.get(key, "n"), "after": new.get(key, "n"),
         "tool_probe": key in generated_keys}
        for key in sorted(old.keys() | new.keys())
        if old.get(key, "n") != new.get(key, "n")
    ]
    critical = ["CONFIG_ARM64", "CONFIG_KSU", "CONFIG_KSU_SUSFS", "CONFIG_LTO_CLANG_FULL",
                "CONFIG_CFI_CLANG", "CONFIG_MODVERSIONS", "CONFIG_MODULE_SIG", "CONFIG_MODULE_SIG_PROTECT"]
    violations = [change for change in changes if not change["tool_probe"]
                  and not change["symbol"].startswith("CONFIG_KSU_")
                  and change["symbol"] != "CONFIG_LOCALVERSION"]
    if new.get("CONFIG_LOCALVERSION") != '"-ksun342-susfs230-exp"':
        violations.append({"symbol": "CONFIG_LOCALVERSION", "required": "experimental suffix"})
    for key in ["CONFIG_KSU_DISABLE_MANAGER", "CONFIG_KSU_DISABLE_POLICY", "CONFIG_KSU_DEBUG"]:
        if new.get(key, "n") != "n":
            violations.append({"symbol": key, "required": "n"})
    for key in critical:
        if new.get(key) != "y":
            violations.append({"symbol": key, "required": "y", "actual": new.get(key)})
    if new.get("CONFIG_CLANG_VERSION") != "210000":
        violations.append({"symbol": "CONFIG_CLANG_VERSION", "required": "210000"})
    result = {"baseline_sha256": digest, "changes": changes, "violations": violations,
              "passed": not violations, "scope": "configuration only; no boot or module compatibility claim"}
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    if violations:
        raise SystemExit("Configuration drift requires review; build stopped")


if __name__ == "__main__":
    main()
