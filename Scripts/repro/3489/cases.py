"""#3489: write each crafted file and open it with `probe`, under the 3477 malloc interposer.

  W=<work dir holding probe, interpose.dylib>  PROBE=probe  python3 cases.py [arrays|label|shape]

See README.md for how to build the probe and the interposer, and for the measured table. Each line
is `case rc seconds status BIG`: `BIG` is the first allocation of 8 MiB or more the load made.
"""
import os, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ocaf import *  # noqa

W = os.environ["W"]
PROBE = os.environ.get("PROBE", "probe")
TYPES = ["TDataStd_Integer", "TDF_Reference", "TDataStd_IntegerArray", "TDataStd_RealArray",
         "TDataStd_ExtStringArray", "TDataStd_ByteArray", "TDataStd_BooleanArray",
         "TDataStd_ReferenceArray", "TDataStd_IntegerList", "TDataStd_RealList",
         "TDataStd_BooleanList", "TDataStd_NamedData", "TNaming_NamedShape"]
# TNaming_NamedShape must be among the file's types: the shape section is read only through that
# attribute's driver, which the driver table holds only for a type the file names.
T = {n: i + 1 for i, n in enumerate(TYPES)}
INFO = info(types=TYPES)


def run(name, blob, timeout=60):
    os.makedirs(f"{W}/cases", exist_ok=True)
    p = f"{W}/cases/{name}.cbf"
    open(p, "wb").write(blob)
    env = dict(os.environ, DYLD_INSERT_LIBRARIES=W + "/interpose.dylib")
    t = time.time()
    try:
        r = subprocess.run([W + "/" + PROBE, p], capture_output=True, timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        print(f"{name:34s} TIMEOUT {timeout}s", flush=True)
        return
    out = (r.stdout + r.stderr).decode(errors="replace").splitlines()
    last = [l for l in out if l.startswith(("status", "SIGNAL"))][-1:]
    big = [l for l in out if l.startswith("BIG")][:1]
    print(f"{name:34s} rc={r.returncode:4d} {time.time() - t:5.1f}s {last} {big}", flush=True)


def doc(records, tocs=None):
    return build(info_blob=INFO, data=document_data(label(children=[(1, label(records))]), tocs))


def ints(*v):
    return b"".join(I(x) for x in v)


def rec(kind, payload):
    return doc([record(T[kind], 1, payload)])


def arrays():
    """A declared span far larger than the record, per kind; the `_ok` rows are the controls."""
    big = 1 << 28
    run("intarray_ok", rec("TDataStd_IntegerArray", ints(1, 3, 10, 20, 30) + b"\0"))
    run("intarray_2^28", rec("TDataStd_IntegerArray", ints(1, big)))
    run("intarray_int_max", rec("TDataStd_IntegerArray", ints(1, 0x7fffffff)))
    run("intarray_full_range", rec("TDataStd_IntegerArray", ints(-(1 << 31), 0x7fffffff)))
    run("realarray_ok", rec("TDataStd_RealArray", ints(1, 1) + struct.pack("<d", 2.5) + b"\0"))
    run("realarray_2^29", rec("TDataStd_RealArray", ints(1, 1 << 29)))
    run("bytearray_ok", rec("TDataStd_ByteArray", ints(1, 4) + b"abcd" + b"\0"))
    run("bytearray_int_max", rec("TDataStd_ByteArray", ints(1, 0x7fffffff)))
    run("extstrarray_2^30", rec("TDataStd_ExtStringArray", ints(1, 1 << 30)))
    run("refarray_2^30", rec("TDataStd_ReferenceArray", ints(1, 1 << 30)))
    run("boolarray_ok", rec("TDataStd_BooleanArray", ints(1, 11) + b"\x24\x00"))
    run("boolarray_int_max", rec("TDataStd_BooleanArray", ints(1, 0x7fffffff)))
    # lists append what they read; declaring 2^22 makes the unpatched kernel build a 4M node list
    run("intlist_ok", rec("TDataStd_IntegerList", ints(1, 2, 5, 6)))
    run("intlist_2^22", rec("TDataStd_IntegerList", ints(1, 1 << 22)))
    run("reallist_2^22", rec("TDataStd_RealList", ints(1, 1 << 22)))
    run("boollist_2^22", rec("TDataStd_BooleanList", ints(1, 1 << 22)))
    # NamedData: integers, reals, strings, bytes (all empty), then an array of integers by name
    empty = ints(0, 0) * 4
    run("nameddata_intarray_big",
        rec("TDataStd_NamedData", empty + ints(1, 1) + b"k\0\0\0" + ints(1, 1 << 29)))
    run("nameddata_realarray_big",
        rec("TDataStd_NamedData",
            empty + ints(0, 0) + ints(1, 1) + b"k\0\0\0" + ints(1, 1 << 29)))


def label_():
    """The tag count of a TDF_Reference's label: aLen * 4 wraps from 2^29 on."""
    run("ref_ok_no_tags", rec("TDF_Reference", ints(0)))
    for n in (1 << 20, 1 << 28, 1 << 29, 1 << 30, 0x7fffffff, -1):
        run(f"ref_tags_{n}", rec("TDF_Reference", ints(n)))


def shape():
    """A shape section whose table name is a token far longer than the 255 byte buffer."""
    v4 = b"SHAPE_SECTION\nOpen CASCADE Topology V4, (c) Open Cascade\n"
    tables = [b"Locations 0\n", b"Curve2ds 0\n", b"Curves 0\n", b"Polygon3D 0\n",
              b"PolygonOnTriangulations 0\n", b"Surfaces 0\n", b"Triangulations 0\n\n"]

    def with_section(sec):
        def mk(off):
            return build(info_blob=INFO, data=document_data(
                tocs=[toc(b"SHAPE_SECTION_POS:", values=(off, len(sec), 0)), toc()]))
        return mk(len(mk(0))) + sec

    names = ["Locations", "Curve2ds", "Curves", None, None, "Surfaces", None, "TShapes"]
    for size in (300, 4096, 1 << 20):
        # the n-th table name is a long token; the n-1 tables before it are well formed
        for n, name in enumerate(names):
            if name is None or (size == 1 << 20 and name != "Locations"):
                continue
            body = v4 + b"".join(tables[:n]) + b"A" * size
            run(f"token_{size}_at_{name}", with_section(body))


if __name__ == "__main__":
    for w in sys.argv[1:] or ["arrays", "label", "shape"]:
        {"arrays": arrays, "label": label_, "shape": shape}[w]()
