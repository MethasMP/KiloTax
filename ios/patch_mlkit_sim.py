import os, struct, subprocess

def patch_file(p):
    if not os.path.isfile(p):
        return
    with open(p, "r+b") as f:
        content = bytearray(f.read())
        count = 0
        idx = 0
        while True:
            # Look for cmd 0x32 (LC_BUILD_VERSION), cmdsize 24 (0x18), platform 2 (PLATFORM_IOS)
            pos = content.find(b"\x32\x00\x00\x00\x18\x00\x00\x00\x02\x00\x00\x00", idx)
            if pos == -1:
                break
            struct.pack_into("<I", content, pos + 8, 7) # PLATFORM_IOSSIMULATOR = 7
            count += 1
            idx = pos + 12
        if count > 0:
            f.seek(0)
            f.write(content)
            print(f"Patched {count} LC_BUILD_VERSION headers in {p}")

if __name__ == "__main__":
    pods_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "Pods"))
    for root, dirs, files in os.walk(pods_dir):
        for d in dirs:
            if d.endswith(".framework"):
                name = d[:-len(".framework")]
                bin_path = os.path.join(root, d, name)
                patch_file(bin_path)
