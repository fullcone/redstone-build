#!/usr/bin/env python3
"""Re-order ImmortalWrt mirror lists so non-CN mirrors come first.
Usage: python3 reorder-mirrors.py /mnt/nvme/immortalwrt/scripts/projectsmirrors.json
"""
import json, sys

p = sys.argv[1]
CN_KEYWORDS = (
    "tencent.com", "aliyun.com", "tsinghua.edu", "ustc.edu",
    "iscas.ac", "nju.edu", "sjtu.edu", "zju.edu", "buaa.edu",
    "xjtu.edu", "cqu.edu", ".cn/", ".cn:", "sustech.edu",
    "163.com", "huawei.com",
)

with open(p) as f:
    d = json.load(f)

moved = 0
for k, v in d.items():
    if not isinstance(v, list):
        continue
    new = [u for u in v if not any(c in u for c in CN_KEYWORDS)]
    if new != v:
        d[k] = new
        moved += 1

with open(p, "w") as f:
    json.dump(d, f, indent=2)
    f.flush()

print(f"reordered {moved} mirror entries (CN to end)")
print("@GNU first 3:", d.get("@GNU", [])[:3])
print("@KERNEL first 3:", d.get("@KERNEL", [])[:3])
print("@OPENWRT first 3:", d.get("@OPENWRT", [])[:3])
print("@DEBIAN first 3:", d.get("@DEBIAN", [])[:3])
