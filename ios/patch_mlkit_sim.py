#!/usr/bin/env python3
"""
MLKit Simulator Patch Tool for iOS

Google MLKit precompiled fat frameworks contain iOS device-tagged load commands.
When building for the arm64 simulator on Apple Silicon Macs, the Mach-O platform
header (LC_BUILD_VERSION) may need to target PLATFORM_IOSSIMULATOR (7).
However, for device release builds (PLATFORM_IOS = 2, iphoneos), having simulator
headers will break Xcode code-signing, linking, and App Store submission.

This tool safely and conditionally switches or restores the Mach-O platform headers:
- Mode 'device' / 'restore': Ensures PLATFORM_IOS (2). Safe for device release builds.
- Mode 'simulator': Converts PLATFORM_IOS (2) -> PLATFORM_IOSSIMULATOR (7).
"""

import os
import struct
import sys
import shutil

PLATFORM_IOS = 2
PLATFORM_IOSSIMULATOR = 7

# LC_BUILD_VERSION pattern: cmd=0x32, cmdsize=0x18
LC_BUILD_VERSION_CMD = 0x32
LC_BUILD_VERSION_SIZE = 0x18

def patch_binary(path, to_platform):
    if not os.path.isfile(path) or os.path.islink(path):
        return

    try:
        with open(path, "rb") as f:
            content = bytearray(f.read())
    except Exception as e:
        print(f"Error reading {path}: {e}")
        return

    from_platform = PLATFORM_IOS if to_platform == PLATFORM_IOSSIMULATOR else PLATFORM_IOSSIMULATOR
    target_header = struct.pack("<III", LC_BUILD_VERSION_CMD, LC_BUILD_VERSION_SIZE, from_platform)
    
    count = 0
    idx = 0
    while True:
        pos = content.find(target_header, idx)
        if pos == -1:
            break
        # Update platform field at pos + 8
        struct.pack_into("<I", content, pos + 8, to_platform)
        count += 1
        idx = pos + 12

    if count > 0:
        # Create backup if not already present
        orig_path = path + ".orig"
        if not os.path.exists(orig_path):
            try:
                shutil.copy2(path, orig_path)
            except Exception:
                pass
        try:
            with open(path, "wb") as f:
                f.write(content)
            plat_name = "iOS Simulator (7)" if to_platform == PLATFORM_IOSSIMULATOR else "iOS Device (2)"
            print(f"Patched {count} LC_BUILD_VERSION header(s) in {os.path.basename(path)} -> {plat_name}")
        except Exception as e:
            print(f"Error writing {path}: {e}")

def restore_binary(path):
    orig_path = path + ".orig"
    if os.path.exists(orig_path):
        try:
            shutil.copy2(orig_path, path)
            print(f"Restored original binary from {orig_path}")
            return
        except Exception as e:
            print(f"Error restoring {orig_path}: {e}")
    # Fallback: patch 7 -> 2
    patch_binary(path, PLATFORM_IOS)

def determine_target_platform():
    # 1. Explicit CLI arguments
    if "--simulator" in sys.argv or "--sim" in sys.argv:
        return "simulator"
    if "--device" in sys.argv or "--restore" in sys.argv:
        return "device"

    # 2. Xcode Build Environment variables
    xcode_platform = os.environ.get("PLATFORM_NAME", "").lower()
    xcode_sdk = os.environ.get("SDK_NAME", "").lower()
    env_sim = os.environ.get("BUILD_FOR_SIMULATOR", "").lower()

    if "iphonesimulator" in xcode_platform or "iphonesimulator" in xcode_sdk or env_sim in ("1", "true", "yes"):
        return "simulator"
    if "iphoneos" in xcode_platform or "iphoneos" in xcode_sdk:
        return "device"

    # 3. Default safe: device builds (prevents corrupting release artifacts)
    return "device"

def process_pods(target_mode):
    pods_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "Pods"))
    if not os.path.isdir(pods_dir):
        return

    print(f"[MLKit Patch] Mode: {target_mode.upper()} for pods in {pods_dir}")
    to_platform = PLATFORM_IOSSIMULATOR if target_mode == "simulator" else PLATFORM_IOS

    for root, dirs, _ in os.walk(pods_dir):
        for d in dirs:
            if d.endswith(".framework"):
                name = d[:-len(".framework")]
                bin_path = os.path.join(root, d, name)
                if os.path.isfile(bin_path):
                    if target_mode == "restore":
                        restore_binary(bin_path)
                    else:
                        patch_binary(bin_path, to_platform)

if __name__ == "__main__":
    mode = determine_target_platform()
    process_pods(mode)
