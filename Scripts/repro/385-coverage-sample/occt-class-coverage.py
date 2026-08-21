#!/usr/bin/env python3
"""Public methods declared in an OCCT header against the distinct methods our bridge invokes.

A SCREENING PROBE, NOT A GATE. Its measured false-positive rate is in
`Scripts/repro/1001-detector-fp-rates/`, over a forty-row hand-adjudicated sample.

THE DENOMINATOR WAS SYSTEMATICALLY INFLATED, AND ALL FOUR CAUSES ARE FIXED HERE (#1001)
---------------------------------------------------------------------------------------
Every one of the eight false positives in that sample was the same shape: something counted as a
public member function that is not one. That inflates the denominator and makes coverage look WORSE
than it is, so the detector was biased rather than noisy. The four causes, each mechanical:

  1. **A default argument.** `Perform(const Message_ProgressRange& theRange = Message_ProgressRange())`
     read as a method called `Message_ProgressRange`. Four of the eight.
  2. **Private and protected sections.** `GeomPlate_BuildPlateSurface`'s `ProjectCurve` and
     `ComputeAnisotropie` are both declared after `private:` at `:207`.
  3. **Macros.** `Standard_DEPRECATED("Use CoefPol()...")` matched the `Identifier(` pattern.
  4. **A call inside an inline body.** `Location` is not a member of
     `XCAFDimTolObjects_DimensionObject` at all; the pattern caught `myConnection1.Location()`
     inside the inline body of `GetPoint`, a call on a `gp_Ax2` member.

Measured over the same forty rows: 8 false positives before, 0 after. See that directory's README
for the before/after scoring.

WHAT IS NOT A FALSE POSITIVE, AND STAYS
---------------------------------------
The denominator still counts `Set*` and `DumpJson`. Those really are public member functions this
bridge does not call, so they are adjudicated TRUE and no parser change removes them. They are a
reason the ratio is a poor proxy for "how much of this class do we usefully reach", which is a
question about the metric rather than a defect in it. It screens, it does not adjudicate.

Usage:
    occt-class-coverage.py <Class> [<Class> ...]
"""
import re, os, sys, collections
H="Libraries/OCCT.xcframework/macos-arm64/Headers"
BR="Sources/OCCTBridge/src"

# Names that look like `Identifier(` but are never member functions.
MACROS = {"Standard_EXPORT", "Standard_DEPRECATED", "Standard_NODISCARD", "Standard_OVERRIDE",
          "NCollection_Sequence", "Handle"}


def strip_nested(src):
    """Blank everything at brace depth >= 2, preserving newlines.

    The class body is depth 1, so its member DECLARATIONS survive and every inline function BODY is
    blanked. That is fix 4: a call inside an inline body is not a declaration of anything.
    """
    out, depth = [], 0
    for ch in src:
        if ch == "{":
            depth += 1
            out.append(" " if depth >= 2 else ch)
        elif ch == "}":
            out.append(" " if depth >= 2 else ch)
            depth -= 1
        elif depth >= 2:
            out.append("\n" if ch == "\n" else " ")
        else:
            out.append(ch)
    return "".join(out)


def public_only(src):
    """Blank everything after a `private:` or `protected:` label until the next `public:`.

    Fix 2. Labels are matched at the start of a line, which is how OCCT's headers write them.
    """
    out, keep = [], True
    for line in src.split("\n"):
        label = re.match(r'\s*(public|protected|private)\s*:', line)
        if label:
            keep = label.group(1) == "public"
            out.append("")
            continue
        out.append(line if keep else "")
    return "\n".join(out)


def occt_public_methods(cls):
    """Public methods declared in an OCCT header, excluding ctors/dtor/operators/macros."""
    p=f"{H}/{cls}.hxx"
    if not os.path.exists(p): return None
    src=open(p,errors="ignore").read()
    src=re.sub(r'//[^\n]*','',src)
    src=re.sub(r'/\*.*?\*/','',src,flags=re.S)
    src=strip_nested(src)
    src=public_only(src)
    names=set()
    for m in re.finditer(r'\b([A-Z][A-Za-z0-9_]*)\s*\(', src):
        n=m.group(1)
        if n==cls or n.startswith("DEFINE_") or n in MACROS: continue
        # Fix 1: a default argument is an initialiser, not a declaration. `= Foo()` is preceded by
        # `=` once whitespace is skipped, and a real declaration never is.
        before = src[:m.start()].rstrip()
        if before.endswith("="): continue
        names.add(n)
    return names


def bridge_calls(cls, files):
    """Distinct OCCT methods our bridge invokes on this class, by ->Method( / ::Method( near the class."""
    used=set()
    for f in files:
        p=f"{BR}/{f}"
        if not os.path.exists(p): continue
        src=open(p,errors="ignore").read()
        if cls not in src: continue
        for m in re.finditer(rf'{cls}::([A-Za-z][A-Za-z0-9_]*)\s*\(', src): used.add(m.group(1))
        # instance calls: find variables declared of this type, then their -> / . calls
        for vm in re.finditer(rf'\b{cls}\b[\s&*]+([a-z][A-Za-z0-9_]*)', src):
            v=vm.group(1)
            for cm in re.finditer(rf'\b{v}\s*(?:->|\.)\s*([A-Za-z][A-Za-z0-9_]*)\s*\(', src): used.add(cm.group(1))
        for vm in re.finditer(rf'Handle\({cls}\)\s+([a-zA-Z][A-Za-z0-9_]*)', src):
            v=vm.group(1)
            for cm in re.finditer(rf'\b{v}\s*(?:->|\.)\s*([A-Za-z][A-Za-z0-9_]*)\s*\(', src): used.add(cm.group(1))
    return used

SAMPLE=sys.argv[1:] if len(sys.argv)>1 else []
# Scan .mm AND the in-src headers: this repo hosts shared helpers in OCCTBridge_Internal.h
# as inline (CLAUDE.md's reach rule), so a .mm-only scan misses the most-shared call sites.
ALL=[f for f in os.listdir(BR) if f.endswith(".mm") or f.endswith(".h")]
print(f"{'OCCT class':<44} {'public':>7} {'we call':>8} {'cover':>7}")
print("-"*72)
rows=[]
for cls in SAMPLE:
    pub=occt_public_methods(cls)
    if pub is None: print(f"{cls:<44} {'no header':>7}"); continue
    used=bridge_calls(cls, ALL)
    hit=used & pub
    pct=100*len(hit)/max(1,len(pub))
    rows.append((cls,len(pub),len(hit),pct,sorted(pub-hit)))
    print(f"{cls:<44} {len(pub):>7} {len(hit):>8} {pct:>6.0f}%")
print()
for cls,n,h,pct,missing in sorted(rows,key=lambda r:r[3]):
    print(f"== {cls}: not reached ({len(missing)}) ==")
    print("   "+", ".join(missing[:24])+(" ..." if len(missing)>24 else ""))
