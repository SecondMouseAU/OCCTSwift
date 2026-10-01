#!/usr/bin/env python3
"""#2897's sweep: does the bridge lay out any OCCT vtable differently from the archive it links?

WHY THIS EXISTS

#2897 reported an `indirect call type mismatch` on wasm and read it as a possible vtable or ABI
disagreement between the headers the bridge compiles against and the kernel it links, which is a
class of defect no Apple build could detect: there the wrong slot is an indirect branch that
happens to work. The root cause turned out to be a dangling pointer rather than a layout
disagreement (see README.md), but the question the issue asked was the right one and nothing in
this repository had ever answered it. This answers it, mechanically, for every vtable the bridge's
own translation units lay out.

WHAT IT COMPARES

Left side: `clang -Xclang -fdump-vtable-layouts` over every `Sources/OCCTBridge/src/*.mm`,
compiled with the flags the wasm bridge build uses. That is exactly the set of vtables the bridge
can dispatch through, and exactly the slot indices its `call_indirect`s use, because clang computed
both from the same headers.

Right side: the `_ZTV<class>` data relocations in `Libraries/libOCCT-wasm.a`, which are the
vtables the program actually links, in slot order.

A disagreement in slot count, or in the (name, arity) at any slot, is a real finding: the bridge
would load a function pointer from a slot the archive filled with a different function.

USAGE

    Scripts/repro/2897/vtable-parity.py --dumps <dir>   # dir of per-TU clang dumps

`<dir>` is produced by compiling each bridge `.mm` with `-Xclang -fdump-vtable-layouts`; `run.sh
--vtable-parity` does both halves. Exit 0 when every shared class agrees, 1 on a disagreement.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

VTABLE_HEADER = re.compile(r"^Vtable for '(.+)' \((\d+) entries\)\.$")
ENTRY = re.compile(r"^\s*(\d+) \| (.*)$")
# Lines the dump emits that are not function slots.
NOT_A_SLOT = re.compile(r"^(offset_to_top|vbase_offset|vcall_offset|.* RTTI$)")


def qualified_name_and_arity(text: str) -> tuple[str, int] | None:
    """Reduce one printed declaration to ('Class::method', parameter count).

    Both sides print the same declaration in different dialects (`occ::handle<X> &` here,
    `opencascade::handle<X>&` from the demangler), so the comparison deliberately uses the name
    and the arity rather than the spelling of the types. An arity difference is what changes a
    wasm function type, which is the thing #2897 was about.
    """
    depth = 0
    open_paren = -1
    for i, ch in enumerate(text):
        if ch in "<([":
            if ch == "(" and depth == 0:
                open_paren = i
                break
            depth += 1
        elif ch in ">)]":
            depth -= 1
    if open_paren < 0:
        return None
    head = text[:open_paren].strip()
    if not head:
        return None
    # The declaration's last whitespace-separated token is the qualified name, possibly glued to a
    # returned reference or pointer ("const occ::handle<Standard_Type> &X::DynamicType").
    name = head.split()[-1].lstrip("*&")
    # Parameters: count top-level commas.
    depth = 0
    params = ""
    for ch in text[open_paren + 1 :]:
        if ch in "<([":
            depth += 1
        elif ch in ">)]":
            if depth == 0:
                break
            depth -= 1
        params += ch
    params = params.strip()
    if not params or params == "void":
        arity = 0
    else:
        depth = 0
        arity = 1
        for ch in params:
            if ch in "<([":
                depth += 1
            elif ch in ">)]":
                depth -= 1
            elif ch == "," and depth == 0:
                arity += 1
    return name, arity


def read_clang_dumps(dump_dir: str) -> dict[str, list[tuple[str, int]]]:
    """Every vtable clang laid out, as class -> ordered list of (name, arity) function slots."""
    layouts: dict[str, list[tuple[str, int]]] = {}
    for entry in sorted(os.listdir(dump_dir)):
        if not entry.endswith(".txt"):
            continue
        cls = None
        slots: list[tuple[str, int]] = []
        with open(os.path.join(dump_dir, entry), errors="replace") as handle:
            for line in handle:
                line = line.rstrip("\n")
                header = VTABLE_HEADER.match(line)
                if header:
                    if cls is not None:
                        layouts.setdefault(cls, slots)
                    cls = header.group(1)
                    slots = []
                    continue
                if cls is None:
                    continue
                if not line.strip():
                    layouts.setdefault(cls, slots)
                    cls = None
                    continue
                item = ENTRY.match(line)
                if not item:
                    continue
                body = item.group(2).strip()
                if NOT_A_SLOT.match(body):
                    continue
                parsed = qualified_name_and_arity(body)
                if parsed is None:
                    slots.append((body, -1))
                    continue
                name, arity = parsed
                if "~" in name:
                    kind = "deleting" if "[deleting]" in body else "complete"
                    slots.append((name + "#" + kind, arity))
                else:
                    slots.append((name, arity))
        if cls is not None:
            layouts.setdefault(cls, slots)
    return layouts


def archive_layouts(
    archive: str, nm: str, ar: str, objdump: str, cxxfilt: str, wanted: set[str]
) -> dict[str, list[tuple[str, int]]]:
    """Every `_ZTV<class>` in the archive, as class -> ordered list of (name, arity)."""
    listing = subprocess.run(
        [nm, "--defined-only", archive], capture_output=True, text=True
    ).stdout
    # object file -> the mangled vtable symbols it defines, for the classes asked about.
    by_object: dict[str, set[str]] = {}
    current = ""
    wanted_symbols = {"_ZTV" + mangle_class(c): c for c in wanted}
    for line in listing.splitlines():
        if line.endswith(":"):
            current = line[:-1]
            continue
        parts = line.split()
        if len(parts) >= 3 and parts[2] in wanted_symbols:
            by_object.setdefault(current, set()).add(parts[2])

    layouts: dict[str, list[tuple[str, int]]] = {}
    with tempfile.TemporaryDirectory() as work:
        for obj, symbols in by_object.items():
            subprocess.run([ar, "x", archive, obj], cwd=work, check=True)
            relocs = subprocess.run(
                [objdump, "-r", os.path.join(work, obj)], capture_output=True, text=True
            ).stdout
            rows = parse_data_relocations(relocs)
            for symbol in symbols:
                cls = wanted_symbols[symbol]
                typeinfo = "_ZTI" + symbol[4:]
                run = longest_table_run(rows, typeinfo)
                if run is None:
                    continue
                layouts[cls] = [demangled_slot(m, cxxfilt) for m in run]
    return layouts


def mangle_class(name: str) -> str:
    """Itanium mangling for a plain, non-template, non-namespaced class name."""
    return f"{len(name)}{name}"


def parse_data_relocations(text: str) -> list[tuple[int, str, str]]:
    rows: list[tuple[int, str, str]] = []
    in_data = False
    for line in text.splitlines():
        if line.startswith("RELOCATION RECORDS FOR [DATA]"):
            in_data = True
            continue
        if line.startswith("RELOCATION RECORDS FOR ["):
            in_data = False
            continue
        if not in_data:
            continue
        parts = line.split()
        if len(parts) != 3 or parts[0] == "OFFSET":
            continue
        try:
            offset = int(parts[0], 16)
        except ValueError:
            continue
        rows.append((offset, parts[1], parts[2].rsplit("+", 1)[0]))
    return rows


def longest_table_run(rows: list[tuple[int, str, str]], typeinfo: str) -> list[str] | None:
    """The vtable's function entries: the contiguous table-index run after the typeinfo pointer.

    `_ZTI<class>` appears in the typeinfo object as well as in the vtable, so the occurrence that
    is followed by the longest run of `R_WASM_TABLE_INDEX_I32` relocations at consecutive word
    offsets is the vtable's.
    """
    best: list[str] | None = None
    for index, (offset, kind, symbol) in enumerate(rows):
        if symbol != typeinfo or kind != "R_WASM_MEMORY_ADDR_I32":
            continue
        run: list[str] = []
        expected = offset + 4
        for next_offset, next_kind, next_symbol in rows[index + 1 :]:
            if next_offset != expected or next_kind != "R_WASM_TABLE_INDEX_I32":
                break
            run.append(next_symbol)
            expected += 4
        if run and (best is None or len(run) > len(best)):
            best = run
    return best


def demangled_slot(mangled: str, cxxfilt: str) -> tuple[str, int]:
    text = subprocess.run([cxxfilt, mangled], capture_output=True, text=True).stdout.strip()
    parsed = qualified_name_and_arity(text)
    if parsed is None:
        return (text, -1)
    name, arity = parsed
    if "~" in name:
        kind = "deleting" if mangled.endswith("D0Ev") else "complete"
        return (name + "#" + kind, arity)
    return (name, arity)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dumps", required=True, help="directory of per-TU clang vtable dumps")
    parser.add_argument("--archive", default=os.path.join(REPO, "Libraries", "libOCCT-wasm.a"))
    parser.add_argument("--llvm-bin", default=os.environ.get("LLVM_BIN", ""))
    args = parser.parse_args()

    tool = lambda n: os.path.join(args.llvm_bin, n) if args.llvm_bin else n
    if not os.path.isfile(args.archive):
        print(f"no archive at {args.archive}: run Scripts/fetch-occt-wasm.sh", file=sys.stderr)
        return 2

    bridge = read_clang_dumps(args.dumps)
    # Templates and namespaced classes are out: their mangling is not derivable from the printed
    # name, and OCCT's polymorphic hierarchy is plain classes.
    plain = {c for c in bridge if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", c)}
    archive = archive_layouts(
        args.archive, tool("llvm-nm"), tool("llvm-ar"), tool("llvm-objdump"), tool("llvm-cxxfilt"),
        plain,
    )

    shared = sorted(set(archive) & plain)
    findings = []
    for cls in shared:
        if bridge[cls] != archive[cls]:
            findings.append(cls)

    print(f"classes laid out by the bridge: {len(bridge)}")
    print(f"  of those, plain class names:  {len(plain)}")
    print(f"  with a vtable in the archive: {len(shared)}")
    print(f"  compared slot for slot:       {sum(len(archive[c]) for c in shared)} slots")
    print(f"  disagreements:                {len(findings)}")
    for cls in findings:
        print(f"\nDISAGREEMENT: {cls}")
        print(f"  bridge  ({len(bridge[cls])} slots): {bridge[cls]}")
        print(f"  archive ({len(archive[cls])} slots): {archive[cls]}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
