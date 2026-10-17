"""#3486: write each crafted file and open it with `probe`, under the 3477 malloc interposer.

  W=<work dir holding probe, interpose.dylib and a.cbf>  python3 cases.py [storage|data|shape]

See README.md for how to build the probe and the interposer, and for the measured table.
"""
import os, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ocaf import *  # noqa

W = os.environ["W"]
TYPES = ["TDataStd_Integer", "TDF_Reference", "TDataStd_IntegerArray", "TDataStd_RealArray",
         "TDataStd_ExtStringArray", "TDataStd_ByteArray", "TDataStd_IntPackedMap", "TDataStd_Name",
         "TDataStd_ReferenceArray", "TDataStd_IntegerList", "TNaming_NamedShape"]
T = {n: i + 1 for i, n in enumerate(TYPES)}
INFO = info(types=TYPES)


def run(name, blob, timeout=60):
    os.makedirs(f"{W}/cases", exist_ok=True)
    p = f"{W}/cases/{name}.cbf"
    open(p, "wb").write(blob)
    env = dict(os.environ, DYLD_INSERT_LIBRARIES=W + "/interpose.dylib")
    t = time.time()
    try:
        r = subprocess.run([W + "/probe", p], capture_output=True, timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        print(f"{name:30s} TIMEOUT {timeout}s", flush=True)
        return
    out = (r.stdout + r.stderr).decode(errors="replace").splitlines()
    last = [l for l in out if l.startswith(("status", "SIGNAL"))][-1:]
    big = [l for l in out if l.startswith("BIG")][:1]
    print(f"{name:30s} rc={r.returncode:4d} {time.time() - t:5.1f}s {last} {big}", flush=True)


def doc(records, tocs=None):
    return build(info_blob=INFO, data=document_data(label(children=[(1, label(records))]), tocs))


def ints(*v):
    return b"".join(I(x) for x in v)


def storage():
    C0 = (0,)
    run("base", build(comment=C0))
    for n in (0, 1, 2, 3, -1, 100, 1 << 20, 1 << 28):
        run(f"type_num_{n}", build(comment=C0, types=(1, (n, "X"))))
    run("type_count_neg5", build(comment=C0, types=(-5,)))
    run("nbobj_neg5", build(comment=C0, info_blob=info(nbobj=-5)))
    run("ref_no_type", build(comment=C0, refs=(1, (1, 1))))
    run("ref_type1", build(comment=C0, types=(1, (1, "X")), refs=(1, (1, 1))))
    run("ref_type_out", build(comment=C0, types=(1, (1, "X")), refs=(1, (1, 77))))
    run("ref_out_of_range", build(comment=C0, types=(1, (1, "X")), refs=(1, (1 << 20, 1))))
    run("ref_no_comment", build(comment=None, types=(1, (1, "X")), refs=(1, (1, 1))))
    run("root_no_comment", build(comment=None, roots=(1, (1, "r", "t"))))
    run("root_ref1", build(comment=C0, roots=(1, (1, "r", "t"))))
    for ref in (1 << 20, -1, 1 << 29):
        run(f"root_ref_{ref}", build(comment=C0, roots=(1, (ref, "r", "t"))))


def data():
    run("d_intarray_ok", doc([record(T["TDataStd_IntegerArray"], 1, ints(1, 3, 10, 20, 30) + b"\0")]))
    run("d_intarray_1g", doc([record(T["TDataStd_IntegerArray"], 1, ints(1, 1 << 28))]))
    run("d_intarray_8g", doc([record(T["TDataStd_IntegerArray"], 1, ints(1, 0x7fffffff))]))
    run("d_realarray_8g", doc([record(T["TDataStd_RealArray"], 1, ints(1, 0x3fffffff))]))
    run("d_extstrarray_big", doc([record(T["TDataStd_ExtStringArray"], 1, ints(1, 0x3fffffff))]))
    run("d_bytearray_big", doc([record(T["TDataStd_ByteArray"], 1, ints(1, 0x7fffffff))]))
    run("d_refarray_big", doc([record(T["TDataStd_ReferenceArray"], 1, ints(1, 0x3fffffff))]))
    run("d_intpackedmap_big", doc([record(T["TDataStd_IntPackedMap"], 1, ints(0x7fffffff))]))
    run("d_intlist_big", doc([record(T["TDataStd_IntegerList"], 1, ints(0x7fffffff))]))
    run("d_ref_label_2e30", doc([record(T["TDF_Reference"], 1, ints(1 << 30))]))
    run("p_len_huge", doc([record(1, 1, I(7), length=0x7fffffff)]))
    run("p_len_wrap", doc([record(1, 1, I(7), length=0x7ffffff8)]))
    run("p_len_neg", doc([record(1, 1, I(7), length=-5)]))
    run("p_type_huge", doc([record(0x7fffffff, 1, I(7))]))
    run("p_id_huge", doc([record(1, 0x7fffffff, I(7))]))
    for n in (512, 513):
        run(f"toc_{n}", build(info_blob=INFO, data=document_data(tocs=[toc(b"x" * n, name_size=n), toc()])))
    for n in (1000, 20000):
        inner = label([integer_record()])
        sizes, size = [], len(inner)
        for _ in range(n):
            size = 8 + 4 + 4 + size + 4
            sizes.append(size)
        body = b"".join(U64(s) + I(-1) + I(1) for s in reversed(sizes)) + inner + I(-2) * n
        run(f"deep_{n}", build(info_blob=INFO, data=document_data(body)))


def shape():
    def with_section(sec):
        def mk(off):
            return build(info_blob=INFO, data=document_data(
                tocs=[toc(b"SHAPE_SECTION_POS:", values=(off, len(sec), 0)), toc()]))
        return mk(len(mk(0))) + sec

    v4 = b"SHAPE_SECTION\nOpen CASCADE Topology V4, (c) Open Cascade\n"
    run("sh_ok_title_only", with_section(v4 + b"Locations 0\n"))
    run("sh_long_token_300", with_section(v4 + b"A" * 300))
    run("sh_long_token_4k", with_section(v4 + b"A" * 4096))


if __name__ == "__main__":
    for w in sys.argv[1:] or ["storage", "data", "shape"]:
        globals()[w]()
