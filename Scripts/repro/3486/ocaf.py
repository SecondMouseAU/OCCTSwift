"""#3486: build binary OCAF files (BinOcaf, storage version 12) with chosen contents.

Layout (FSD_BinaryFile + BinLDrivers_DocumentStorageDriver), all little endian:

  "BINFILE"                                  7 byte magic
  FSD_FileHeader                             thirteen ints, see `build`
  info section                               object count, 4 strings, application name (UTF-16),
                                             application version, data type (UTF-16), a count of
                                             user-info lines, the lines (the attribute type table
                                             of BinLDrivers sits between START_TYPES / END_TYPES)
  comment / type / root / reference sections at the offsets the header names (BinOcaf writes only
                                             an empty comment section)
  document data, from `edata`:
      section TOC          int name size, name, three uint64 (offset, length, post-read); the
                           reader stops at the section named ":" (ENDSECTION_POS)
      int                  tag of the root label
      label                uint64 size (itself included), then
                           records  int type id, int object id, int length, payload ...
                           int -1   end of attributes
                           children int tag, label ...
                           int -2   end of children

`probe <path> BinOcaf` writes a real document to compare against; `selftest()` checks that
`build()` reproduces its layout.
"""
import struct


def I(v):
    return struct.pack("<i", v)


def U64(v):
    return struct.pack("<Q", v)


def string(s, unit=1):
    s = s.encode() if unit == 1 else s.encode("utf-16-le")
    return I(len(s) // unit) + s


def info(types=("TDataStd_Integer",), nbobj=1, version="12", lines=None, line_count=None):
    out = I(nbobj)
    for s in (version, "10/18/2026", "", "1"):
        out += string(s)
    out += string("", 2) + string("") + string("", 2)
    if lines is None:
        lines = (["FILE_FORMAT: BinOcaf", "REFERENCE_COUNTER: 0", "MODIFICATION_COUNTER: 1",
                  "START_TYPES"] + list(types) + ["END_TYPES"])
    out += I(len(lines) if line_count is None else line_count)
    for ln in lines:
        out += string(ln)
    return out


def toc(name=b":", name_size=None, values=(0, 0, 0)):
    """One TOC entry. name is padded to a multiple of 4 like WriteTOC does."""
    pad = name + b"\0" * (-len(name) % 4)
    return I(len(pad) if name_size is None else name_size) + pad + b"".join(U64(v) for v in values)


def record(type_id, obj_id, payload=b"", length=None):
    return I(type_id) + I(obj_id) + I(len(payload) if length is None else length) + payload


def label(records=(), children=()):
    """children: [(tag, label bytes)]"""
    c = b"".join(records) + I(-1)
    for tag, lab in children:
        c += I(tag) + lab
    c += I(-2)
    return U64(8 + len(c)) + c


def integer_record(value=7, obj_id=1):
    return record(1, obj_id, I(value))


def document_data(root=None, tocs=None):
    root = label(children=[(1, label([integer_record()]))]) if root is None else root
    return (b"".join(tocs) if tocs else toc()) + I(0) + root


def build(comment=(0,), types=None, roots=None, refs=None, info_blob=None, data=None,
          order=("comment", "type", "root", "ref")):
    """The storage sections are (declared count, *records) tuples, or raw bytes, or None to omit.

    types: (count, (type number, name), ...)   roots: (count, (reference, name, type name), ...)
    refs: (count, (reference, type number), ...)  comment: (count, raw extended-string bytes ...)
    """
    info_blob = info() if info_blob is None else info_blob
    data = document_data() if data is None else data
    secs = {}
    if comment is not None:
        secs["comment"] = comment if isinstance(comment, bytes) else I(comment[0]) + b"".join(comment[1:])
    if types is not None:
        secs["type"] = I(types[0]) + b"".join(I(n) + string(nm) for n, nm in types[1:])
    if roots is not None:
        secs["root"] = I(roots[0]) + b"".join(I(r) + string(n) + string(t) for r, n, t in roots[1:])
    if refs is not None:
        secs["ref"] = I(refs[0]) + b"".join(I(r) + I(t) for r, t in refs[1:])
    einfo = 7 + 13 * 4 + len(info_blob)
    pos = einfo
    off = {}
    body = b""
    for k in order:
        if k in secs:
            off[k] = (pos, pos + len(secs[k]))
            body += secs[k]
            pos += len(secs[k])

    def at(k, i):
        return off[k][i] if k in off else -1

    hdr = [0x04030201, 7, einfo, at("comment", 0), at("comment", 1), at("type", 0), at("type", 1),
           at("root", 0), at("root", 1), at("ref", 0), at("ref", 1), -1, pos]
    return b"BINFILE" + b"".join(I(v) for v in hdr) + info_blob + body + data


def selftest(real_path):
    """build() against a file `probe <path> BinOcaf` saved (the date differs)."""
    real = open(real_path, "rb").read()
    mine = build()
    assert len(real) == len(mine), (len(real), len(mine))
    diff = [i for i in range(len(real)) if real[i] != mine[i]]
    assert all(0x43 + 2 <= i < 0x43 + 2 + 4 + 10 for i in diff), diff
    print("ok: build() matches a saved BinOcaf file except the date")


if __name__ == "__main__":
    import sys
    selftest(sys.argv[1])
