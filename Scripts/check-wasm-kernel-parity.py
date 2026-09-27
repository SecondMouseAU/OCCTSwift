#!/usr/bin/env python3
"""Gate: the prebuilt wasm kernel must carry the same patch set as the pinned native kernel.

WHY THIS EXISTS

The two platforms pin their OCCT separately and nothing connects them. ``Package.swift`` names the
native kernel as a ``binaryTarget`` ``url:``/``checksum:`` pair and enumerates the carried patches
in a comment beside it; the wasm kernel is a release asset recorded in
``Scripts/wasm-kernel-pin.txt``, because SwiftPM's ``binaryTarget`` takes an xcframework and never a
bare static library.

So a repin of the native kernel that does not also rebuild and republish the wasm asset leaves the
two platforms on **different kernels**, and nothing about a macOS build, a macOS test run or any
existing gate would notice. The divergence is invisible precisely where it matters most: a carried
patch is a correctness fix, and "fixed on macOS, still broken in the browser" is not a state anyone
would choose, or discover quickly.

This is the same argument ``okf/policies/pinned-kernel-patch-check.md`` makes about the count of
patches on disk versus the count in the pinned asset, one level out: there the risk is a patch that
is carried but not pinned, here it is a patch that is pinned on one platform and not the other.

WHAT IT CHECKS

1. The wasm pin's patch count equals the number of patches ``Package.swift`` enumerates.
2. The wasm pin's FIRST and LAST patch numbers match that enumeration's ends.
3. The wasm pin's WASI-only patch count equals the files in ``Scripts/patches-wasi/``.
4. The pinned asset URL's release tag matches ``OCCT_WASM_RELEASE_TAG``, so the two cannot drift
   apart inside the pin file itself.

WHAT IT DOES NOT CHECK

That the published asset actually contains those patches. Nothing short of downloading 38 MB and
reading symbols could, and ``Scripts/check-pinned-asset-patches.py`` is the tool for that class of
question on the native side. This gate checks the DECLARATION, which is the thing that goes stale
silently. ``Scripts/fetch-occt-wasm.sh`` checks the artifact.

THE ACKNOWLEDGEMENT, AND WHY IT EXPIRES

A divergence with a written reason is expected; one without is a finding. Rebuilding the wasm kernel
is a 69-minute build, so a repin that cannot do both at once is legitimate, and the escape is:

    OCCT_WASM_PARITY_ACKNOWLEDGED_AGAINST=<the native patch count it was acknowledged at>
    OCCT_WASM_PARITY_ACKNOWLEDGED_REASON=<why, and what closes it>

The acknowledgement names the native state it was written against, so the NEXT native repin makes
it stale and the gate fires again. An acknowledgement that never expires is a suppression, and this
repo has been bitten by rows that outlived their reason: see the two stale ACKNOWLEDGED rows
#2190 found in ``Scripts/patches/README.md``.

Exit 0 when clean, 1 on a finding, 2 if run from outside the repo root.
"""

from __future__ import annotations

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PIN_FILE = os.path.join("Scripts", "wasm-kernel-pin.txt")

# The sentence in Package.swift's pin comment that the enumerated patch list follows. A literal,
# and therefore a thing that can be edited out from under this gate, so `pinned_patch_numbers`
# returns None rather than [] when it is gone and `check` reports that as its own finding.
# check-inventory-prose.py reads the same comment with the same anchor, and self_test asserts the
# two parsers agree, so this duplication is verified rather than merely noted.
ANCHOR = "survive, all present in Scripts/patches/, are:"


def read(rel, text=None):
    if text is not None:
        return text
    with open(os.path.join(REPO, rel), encoding="utf-8") as handle:
        return handle.read()


def parse_pins(text):
    """KEY=value lines, comments and blanks ignored. Same format as wasm-toolchain-versions.txt."""
    pins = {}
    for line in text.split("\n"):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "=" not in stripped:
            continue
        key, _, value = stripped.partition("=")
        pins[key.strip()] = value.strip()
    return pins


def pinned_patch_numbers(text=None):
    """The patch numbers enumerated in Package.swift's pinned-asset comment.

    Deliberately the same parse as check-inventory-prose.py's function of the same name. Two
    readers of one comment is already one too many, but a shared import between gate scripts is not
    how this directory is organised, and a divergence here would be caught by that gate's own
    count claim moving.
    """
    text = read("Package.swift", text)
    start = text.find(ANCHOR)
    if start < 0:
        # Fail-safe either way, since an empty list makes the count comparison below report a
        # divergence rather than pass. But "Package.swift enumerates 0" sends the reader to the
        # wrong place, so the caller distinguishes this and says the anchor moved.
        return None
    numbers = []
    for line in text[start:].split("\n")[1:]:
        stripped = line.strip()
        if not stripped.startswith("//"):
            break
        body = stripped[2:].strip()
        if not body:
            if numbers:
                break
            continue
        match = re.match(r"^(\d{4})\s", body)
        if match:
            numbers.append(match.group(1))
    return numbers


def wasi_patch_count():
    directory = os.path.join(REPO, "Scripts", "patches-wasi")
    if not os.path.isdir(directory):
        return 0
    return len([n for n in os.listdir(directory) if n.endswith(".patch")])


def check(pins, pinned, wasi_count):
    """Return a list of findings. Pure, so --self-test can drive it with synthetic inputs."""
    findings = []

    required = [
        "OCCT_WASM_RELEASE_TAG",
        "OCCT_WASM_ASSET_URL",
        "OCCT_WASM_ASSET_SHA256",
        "OCCT_WASM_PATCH_COUNT",
        "OCCT_WASM_PATCH_FIRST",
        "OCCT_WASM_PATCH_LAST",
        "OCCT_WASM_WASI_PATCH_COUNT",
    ]
    missing = [key for key in required if key not in pins]
    if missing:
        return ["%s has no %s" % (PIN_FILE, key) for key in missing]

    tag = pins["OCCT_WASM_RELEASE_TAG"]
    url = pins["OCCT_WASM_ASSET_URL"]
    if "/download/%s/" % tag not in url:
        findings.append(
            "OCCT_WASM_ASSET_URL does not point at the release OCCT_WASM_RELEASE_TAG names.\n"
            "  tag %s, url %s" % (tag, url))

    if not re.fullmatch(r"[0-9a-f]{64}", pins["OCCT_WASM_ASSET_SHA256"]):
        findings.append("OCCT_WASM_ASSET_SHA256 is not a 64-character lowercase hex digest")

    if pinned is None:
        return findings + [
            "Package.swift's pinned-patch comment no longer contains the anchor this gate reads.\n"
            "  looking for: %r\n"
            "Either the comment was reworded, in which case update ANCHOR here AND in\n"
            "check-inventory-prose.py, or the enumerated list is gone, in which case the native\n"
            "pin is undocumented and that is the real finding." % ANCHOR]

    declared = int(pins["OCCT_WASM_PATCH_COUNT"])
    native = len(pinned)

    # The acknowledgement is read only when there IS a divergence, so a stale acknowledgement
    # sitting beside a clean state is inert rather than a second way to fail.
    acknowledged_against = pins.get("OCCT_WASM_PARITY_ACKNOWLEDGED_AGAINST")
    acknowledged_reason = pins.get("OCCT_WASM_PARITY_ACKNOWLEDGED_REASON")

    if declared != native:
        message = (
            "the wasm kernel and the pinned native kernel carry different patch sets.\n"
            "  %s declares %d carried patches\n"
            "  Package.swift enumerates %d\n"
            "A native repin has to rebuild and republish the wasm asset too, or say here why not."
            % (PIN_FILE, declared, native))
        if acknowledged_against is None:
            findings.append(message)
        elif acknowledged_against != str(native):
            findings.append(
                message + "\n"
                "  An acknowledgement is present but STALE: it was written against %s native\n"
                "  patches and there are now %d. Re-decide it rather than bumping the number."
                % (acknowledged_against, native))
        elif not acknowledged_reason:
            findings.append(
                message + "\n"
                "  OCCT_WASM_PARITY_ACKNOWLEDGED_AGAINST is set with no\n"
                "  OCCT_WASM_PARITY_ACKNOWLEDGED_REASON. An acknowledgement without a reason is a\n"
                "  suppression.")
    else:
        if pinned:
            if pins["OCCT_WASM_PATCH_FIRST"] != pinned[0]:
                findings.append(
                    "OCCT_WASM_PATCH_FIRST is %s, Package.swift's first enumerated patch is %s"
                    % (pins["OCCT_WASM_PATCH_FIRST"], pinned[0]))
            if pins["OCCT_WASM_PATCH_LAST"] != pinned[-1]:
                findings.append(
                    "OCCT_WASM_PATCH_LAST is %s, Package.swift's last enumerated patch is %s"
                    % (pins["OCCT_WASM_PATCH_LAST"], pinned[-1]))

    declared_wasi = int(pins["OCCT_WASM_WASI_PATCH_COUNT"])
    if declared_wasi != wasi_count:
        findings.append(
            "OCCT_WASM_WASI_PATCH_COUNT is %d, Scripts/patches-wasi/ holds %d .patch files.\n"
            "A WASI patch added since the asset was built is NOT in it, and the asset needs a "
            "rebuild." % (declared_wasi, wasi_count))

    return findings


CLEAN_PINS = {
    "OCCT_WASM_RELEASE_TAG": "v9.9.9-kernel.1",
    "OCCT_WASM_ASSET_URL": "https://example.invalid/releases/download/v9.9.9-kernel.1/x.tar.gz",
    "OCCT_WASM_ASSET_SHA256": "a" * 64,
    "OCCT_WASM_PATCH_COUNT": "2",
    "OCCT_WASM_PATCH_FIRST": "0010",
    "OCCT_WASM_PATCH_LAST": "0011",
    "OCCT_WASM_WASI_PATCH_COUNT": "3",
}


def self_test():
    """Every branch above, driven with synthetic inputs, including the ones that must NOT fire."""
    cases = []

    def case(name, expect_finding, pins, pinned=("0010", "0011"), wasi=3):
        cases.append((name, expect_finding, pins,
                      None if pinned is None else list(pinned), wasi))

    case("a matching pin is clean", False, dict(CLEAN_PINS))

    case("a missing key is a finding", True,
         {k: v for k, v in CLEAN_PINS.items() if k != "OCCT_WASM_PATCH_COUNT"})

    case("a url naming a different tag is a finding", True,
         dict(CLEAN_PINS, OCCT_WASM_ASSET_URL="https://x.invalid/download/v1.2.3/x.tar.gz"))

    case("a non-hex sha is a finding", True, dict(CLEAN_PINS, OCCT_WASM_ASSET_SHA256="nope"))

    case("a wasm kernel behind the native one is a finding", True,
         dict(CLEAN_PINS), pinned=("0010", "0011", "0012"))

    case("an acknowledgement against the CURRENT native count clears it", False,
         dict(CLEAN_PINS,
              OCCT_WASM_PARITY_ACKNOWLEDGED_AGAINST="3",
              OCCT_WASM_PARITY_ACKNOWLEDGED_REASON="rebuild scheduled, see #1"),
         pinned=("0010", "0011", "0012"))

    case("a STALE acknowledgement does not clear it", True,
         dict(CLEAN_PINS,
              OCCT_WASM_PARITY_ACKNOWLEDGED_AGAINST="3",
              OCCT_WASM_PARITY_ACKNOWLEDGED_REASON="rebuild scheduled"),
         pinned=("0010", "0011", "0012", "0013"))

    case("an acknowledgement with no reason does not clear it", True,
         dict(CLEAN_PINS, OCCT_WASM_PARITY_ACKNOWLEDGED_AGAINST="3"),
         pinned=("0010", "0011", "0012"))

    case("a stale acknowledgement beside a CLEAN state is inert", False,
         dict(CLEAN_PINS,
              OCCT_WASM_PARITY_ACKNOWLEDGED_AGAINST="99",
              OCCT_WASM_PARITY_ACKNOWLEDGED_REASON="long gone"))

    case("a missing anchor is its own finding, not 'enumerates 0'", True,
         dict(CLEAN_PINS), pinned=None)

    case("a wrong FIRST is a finding", True, dict(CLEAN_PINS, OCCT_WASM_PATCH_FIRST="0009"))
    case("a wrong LAST is a finding", True, dict(CLEAN_PINS, OCCT_WASM_PATCH_LAST="0099"))
    case("a wasi count that moved is a finding", True, dict(CLEAN_PINS), wasi=4)

    failures = []
    for name, expect_finding, pins, pinned, wasi in cases:
        got = check(pins, pinned, wasi)
        if bool(got) != expect_finding:
            failures.append("  %s: expected %s, got %s"
                            % (name, "a finding" if expect_finding else "clean",
                               got if got else "clean"))

    # The real pin file must parse, so a formatting change cannot make the gate vacuous.
    real = parse_pins(read(PIN_FILE))
    if "OCCT_WASM_ASSET_URL" not in real:
        failures.append("  the real %s does not parse into pins" % PIN_FILE)

    # The real anchor must still be there, or every run of this gate reports the same false
    # divergence and somebody acknowledges it to make the noise stop.
    if pinned_patch_numbers() is None:
        failures.append("  Package.swift no longer contains ANCHOR %r" % ANCHOR)

    # This script's pinned_patch_numbers is a COPY of check-inventory-prose.py's. Two readers of one
    # comment is one too many, and gate scripts here are deliberately standalone rather than
    # importing each other, so the duplication is verified instead: both must return the same list
    # for the real Package.swift. A divergence means one was edited and the other was not, which is
    # exactly the failure a shared literal invites.
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "inventory_prose", os.path.join(REPO, "Scripts", "check-inventory-prose.py"))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        theirs = module.pinned_patch_numbers()
        mine = pinned_patch_numbers()
        if theirs != mine:
            failures.append(
                "  the two copies of pinned_patch_numbers disagree:\n"
                "    check-inventory-prose.py: %s\n"
                "    this script:              %s" % (theirs, mine))
    except Exception as exc:  # pragma: no cover
        failures.append("  could not cross-check against check-inventory-prose.py: %s" % exc)

    if failures:
        print("check-wasm-kernel-parity --self-test: %d FAILED" % len(failures))
        print("\n".join(failures))
        return 1
    print("check-wasm-kernel-parity --self-test: %d cases, all pass" % len(cases))
    return 0


def main(argv):
    if os.path.abspath(os.getcwd()) != REPO:
        print("error: run this from the repository root (%s)" % REPO, file=sys.stderr)
        return 2
    if "--self-test" in argv:
        return self_test()

    pins = parse_pins(read(PIN_FILE))
    pinned = pinned_patch_numbers()
    wasi = wasi_patch_count()

    findings = check(pins, pinned, wasi)
    if findings:
        print("check-wasm-kernel-parity: %d finding(s)" % len(findings))
        for finding in findings:
            print("\n" + finding)
        return 1

    print("check-wasm-kernel-parity: clean")
    print("  wasm asset:  %s, %s carried patches (%s..%s), %s WASI patches"
          % (pins["OCCT_WASM_RELEASE_TAG"], pins["OCCT_WASM_PATCH_COUNT"],
             pins["OCCT_WASM_PATCH_FIRST"], pins["OCCT_WASM_PATCH_LAST"],
             pins["OCCT_WASM_WASI_PATCH_COUNT"]))
    print("  native pin:  %d enumerated patches in Package.swift" % len(pinned))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
