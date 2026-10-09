#!/usr/bin/env python3
"""Generate the injection shadow for the OCCTCurveTests batch 2 weak-assertion lift.

usage (from the repo root):
    python3 Scripts/repro/curve-injection-matrix-weak-assertion-rewrites-b2/generate-shadow.py \
        --out Sources/OCCTSwift/InjectionShadow.swift --switches <dir>/switches.txt

For every bridge entry point named in funcs.txt (written by reachable-funcs.py), it reads the C declaration out of Sources/OCCTBridge/include and writes a
module-local Swift function with the SAME name and signature. A module-local declaration wins over
the imported one at every call site, so no call site and no .mm is edited (okf/references/
injection-sweep-mechanics.md). Each shadow calls the real function and then, when the environment
variable CRV_SWITCH names one of its switches, distorts the answer:

    F_RET_FLIP        a Bool verdict inverted
    F_RET_NIL         a reference result dropped
    F_RET_PLUS / _NEG a scalar result offset by 1e-3 / negated
    F_RET_PLUS1       an Int32 result (a count) off by one
    F_RET_MINUS1      a count with the last element dropped (arrays: nothing past the new count is read)
    F_RET_ZERO        a count reported as zero
    F_<out>_PLUS / _NEG / _PLUS1   one out parameter (or one field of an out struct, or one element
                                   range of an out array) offset by 1e-3 / negated / by one
    F_IN<i>_PLUS      the i-th Double input offset by 1e-3 before the call
    F_IN_<name>_FLIP  a Bool input inverted before the call

The file is generated, never hand-edited, and must never be committed under Sources/.
"""
import argparse
import glob
import re
import sys

FUNCS = None  # read in main() from --funcs (default funcs.txt beside this script)

SWIFT_BASE = {
    "double": "Double", "float": "Float", "int32_t": "Int32", "int": "Int32", "uint32_t": "UInt32",
    "int64_t": "Int64", "size_t": "Int", "bool": "Bool", "char": "CChar", "void": "Void",
}


def strip_comments(t):
    t = re.sub(r"/\*.*?\*/", "", t, flags=re.S)
    return re.sub(r"//[^\n]*", "", t)


def load_headers():
    decls, structs, enums = {}, {}, set()
    for f in glob.glob("Sources/OCCTBridge/include/*.h"):
        t = strip_comments(open(f).read())
        for m in re.finditer(r"typedef struct[^{]*\{([^}]*)\}\s*(\w+)\s*;", t):
            fields = []
            for decl in m.group(1).split(";"):
                decl = decl.strip()
                if not decl:
                    continue
                mm = re.match(r"(\w+)\s+(.*)", decl, re.S)
                if not mm:
                    continue
                for name in mm.group(2).split(","):
                    if "[" in name:  # a fixed-size array imports as a tuple, which cannot be indexed
                        continue
                    fields.append((mm.group(1), name.strip()))
            structs[m.group(2)] = fields
        for m in re.finditer(r"typedef enum[^{]*\{[^}]*\}\s*(\w+)\s*;", t):
            enums.add(m.group(1))
        for m in re.finditer(r"([A-Za-z_][\w \*]*?)\b(OCCT\w+)\s*\(([^;{}]*)\)\s*;", t):
            decls[m.group(2)] = (re.sub(r"\s+", " ", m.group(1)).strip(), re.sub(r"\s+", " ", m.group(3)).strip())
    return decls, structs, enums


def parse_type(txt):
    """-> (base, stars, const, nonnull) from e.g. 'const double* _Nonnull'."""
    nonnull = "_Nonnull" in txt
    txt = re.sub(r"_Nonnull|_Nullable|_Null_unspecified", "", txt)
    const = bool(re.search(r"\bconst\b", txt))
    txt = re.sub(r"\bconst\b", "", txt)
    stars = txt.count("*")
    base = txt.replace("*", "").strip()
    return base, stars, const, nonnull


def swift_scalar(base):
    if base in SWIFT_BASE:
        return SWIFT_BASE[base]
    return base


def is_ref(base):
    return base.endswith("Ref")


def swift_type(txt):
    base, stars, const, nonnull = parse_type(txt)
    b = swift_scalar(base)
    if stars == 0:
        if is_ref(base):
            if nonnull:
                return b
            # an unannotated reference imports as an implicitly unwrapped optional, which call sites
            # rely on (`Shape(handle: OCCTShapeFromWire(w))`), so the shadow must be one too
            return b + "?" if "_Nullable" in txt else b + "!"
        return b
    if stars == 1:
        if is_ref(base):
            # a pointer to a reference imports with a nullability the header text does not carry
            raise ValueError(txt)
        if base == "void":
            t = "UnsafeRawPointer" if const else "UnsafeMutableRawPointer"
        else:
            el = b + "?" if is_ref(base) else b
            t = f"UnsafePointer<{el}>" if const else f"UnsafeMutablePointer<{el}>"
        return t if nonnull else t + "?"
    raise ValueError(txt)


def split_params(s):
    out = []
    if not s or s.strip() == "void":
        return out
    for p in s.split(","):
        p = p.strip()
        m = re.match(r"(.*?)(\w+)$", p)
        out.append((m.group(1).strip(), m.group(2)))
    return out


def gen(name, ret, params, structs, enums, switches):
    base_r, stars_r, _, nn_r = parse_type(ret)
    ret_sw = swift_type(ret) if not (base_r == "void" and stars_r == 0) else None
    sig = ", ".join(f"_ {n}: {swift_type(t)}" for t, n in params)
    args = ", ".join(n for _, n in params)
    L = [f"func {name}({sig})" + (f" -> {ret_sw}" if ret_sw else "") + " {"]
    pre, post = [], []
    sw = lambda s: (switches.append(f"{name}_{s}"), f"{name}_{s}")[1]
    dbl_in = 0
    for t, n in params:
        base, stars, const, nonnull = parse_type(t)
        if stars == 0 and base == "double":
            dbl_in += 1
            pre.append(f'    var {n} = {n}\n    if GD.on("{sw(f"IN{dbl_in}_PLUS")}") {{ {n} += 1e-3 }}')
        if stars == 0 and base == "bool":
            pre.append(f'    var {n} = {n}\n    if GD.on("{sw(f"IN_{n}_FLIP")}") {{ {n} = !{n} }}')
    # shadow parameters: rebind via local copies so the call below uses the possibly-offset values
    L += pre
    call = f"OCCTBridge.{name}({args})"
    returns_value = ret_sw is not None
    L.append(f"    var rr = {call}" if returns_value else f"    {call}")
    rb = base_r
    cond = ""  # distort outs only when a Bool verdict is true
    if returns_value and rb == "bool" and stars_r == 0:
        post.append(f'    if GD.on("{sw("RET_FLIP")}") {{ rr = !rr }}')
        cond = "rr && "
    elif returns_value and rb == "double" and stars_r == 0:
        post.append(f'    if GD.on("{sw("RET_PLUS")}") {{ rr += 1e-3 }}')
        post.append(f'    if GD.on("{sw("RET_NEG")}") {{ rr = -rr }}')
    elif returns_value and rb in ("int32_t", "int") and stars_r == 0:
        post.append(f'    if GD.on("{sw("RET_PLUS1")}") {{ rr += 1 }}')
        post.append(f'    if GD.on("{sw("RET_MINUS1")}") {{ if rr > 0 {{ rr -= 1 }} }}')
        post.append(f'    if GD.on("{sw("RET_ZERO")}") {{ rr = 0 }}')
    elif returns_value and is_ref(rb) and not nn_r:
        post.append(f'    if GD.on("{sw("RET_NIL")}") {{ return nil }}')
    elif returns_value and rb in structs:
        for ft, fn in structs[rb]:
            post += field_switch(name, f"RET_{fn}", "rr", fn, ft, enums, sw, "")
    count = "Int(rr)" if returns_value and rb in ("int32_t", "int") and stars_r == 0 else None
    for t, n in params:
        base, stars, const, nonnull = parse_type(t)
        if stars != 1 or const:
            continue
        p = f"{n}_p"
        bind = f"do {{ let {p} = {n};" if nonnull else f"if let {p} = {n} {{"

        def guarded(label, body):
            return f'    if GD.on("{sw(label)}") {{ {bind} {body} }} }}'

        if base == "double":
            m = re.search(r"(\d+)$", n)
            length = int(m.group(1)) if m else (count if count else 1)
            post.append(guarded(f"{n}_PLUS", f"for i in 0..<{length} {{ {p}[i] += 1e-3 }}"))
            post.append(guarded(f"{n}_NEG", f"for i in 0..<{length} {{ {p}[i] = -{p}[i] }}"))
        elif base in ("int32_t", "int"):
            length = count if count else 1
            post.append(guarded(f"{n}_PLUS1", f"for i in 0..<{length} {{ {p}[i] += 1 }}"))
        elif base in structs:
            length = count if count else 1
            for ft, fn in structs[base]:
                for line in field_switch(name, f"{n}_{fn}", f"{p}[i]", fn, ft, enums, sw, length):
                    # field_switch emits '    if GD.on("sw") { for i in 0..<L { BODY } }'; re-wrap with the binding
                    mm = re.match(r'    if GD.on\("([^"]+)"\) \{ (.*) \}$', line)
                    post.append(f'    if GD.on("{mm.group(1)}") {{ {bind} {mm.group(2)} }} }}')
    L += wrap_cond(post, cond, count)
    if returns_value:
        L.append("    return rr")
    L.append("}")
    return "\n".join(L)


def field_switch(fn_name, label, lhs, field, ftype, enums, sw, length):
    pre = ""
    post = ""
    if length != "":
        pre = f"for i in 0..<{length} {{ "
        post = " }"
    acc = lhs if length != "" else lhs
    if ftype == "double":
        return [
            f'    if GD.on("{sw(label + "_PLUS")}") {{ {pre}{acc}.{field} += 1e-3{post} }}',
            f'    if GD.on("{sw(label + "_NEG")}") {{ {pre}{acc}.{field} = -{acc}.{field}{post} }}',
        ]
    if ftype in ("int32_t", "int"):
        return [f'    if GD.on("{sw(label + "_PLUS1")}") {{ {pre}{acc}.{field} += 1{post} }}']
    if ftype in enums:
        return [
            f'    if GD.on("{sw(label + "_PLUS1")}") {{ {pre}{acc}.{field} = {ftype}(rawValue: {acc}.{field}.rawValue &+ 1){post} }}']
    return []


def wrap_cond(post, cond, count):
    out = []
    for line in post:
        if cond and "RET_FLIP" not in line:
            line = line.replace("if GD.on(", f"if {cond}GD.on(", 1)
        out.append(line)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--switches", required=True)
    ap.add_argument("--funcs", default=__file__.rsplit("/", 1)[0] + "/funcs.txt")
    a = ap.parse_args()
    decls, structs, enums = load_headers()
    names = open(a.funcs).read().split()
    switches, body, skipped = [], [], []
    for n in dict.fromkeys(names):
        if n not in decls:
            skipped.append((n, "no declaration"))
            continue
        ret, ps = decls[n]
        try:
            body.append(gen(n, ret, split_params(ps), structs, enums, switches))
        except ValueError as e:
            skipped.append((n, f"unmappable type {e}"))
    head = (
        "import Foundation\nimport OCCTBridge\n\n"
        "// GENERATED by generate-shadow.py for the OCCTCurveTests batch 2 injection matrix. TEMPORARY: copied to\n"
        "// Sources/OCCTSwift/InjectionShadow.swift for a sweep and deleted again. Never committed there.\n\n"
        "enum GD {\n"
        '    static let active: String = Foundation.ProcessInfo.processInfo.environment["CRV_SWITCH"] ?? ""\n'
        "    static func on(_ name: String) -> Bool { active == name }\n"
        "}\n\n"
    )
    open(a.out, "w").write(head + "\n\n".join(body) + "\n")
    open(a.switches, "w").write(
        "# CRV_SWITCH values, one per line, derived by generate-shadow.py from the bridge declarations.\n"
        + "\n".join(switches) + "\n")
    print(f"{len(body)} shadows, {len(switches)} switches, skipped: {skipped}")


if __name__ == "__main__":
    main()
