#!/usr/bin/env python3
# Re-init fdt global after expand_buf in fixup_dtb_init
p = "/mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/kexec-tools-2.0.32/kexec/arch/ppc/fixup_dtb.c"
s = open(p).read()
needle = "blob_buf = expand_buf(info->nr_segments"
if "fdt_init(blob_buf); /* HACK" in s:
    print("already patched")
else:
    idx = s.find(needle)
    if idx < 0:
        print("FAIL not found")
    else:
        # find end of statement (semicolon then newline)
        end = s.find(";", idx)
        end_nl = s.find("\n", end) + 1
        ins = "\tfdt_init(blob_buf); /* HACK: re-init fdt global; realloc moved blob */\n"
        s = s[:end_nl] + ins + s[end_nl:]
        open(p, "w").write(s)
        print("patched OK")
