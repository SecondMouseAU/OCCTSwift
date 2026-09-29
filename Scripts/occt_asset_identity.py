#!/usr/bin/env python3
"""#2818: identify the OCCT xcframework a script is about to read, before it reports about it.

Four scripts read `Libraries/OCCT.xcframework`, decided "this is the pinned kernel" from
`os.path.isdir` alone, and none of them looked where SwiftPM actually puts the pinned asset. So a
normal checkout gave `SKIPPED` over a population that is present, and a checkout with a locally
built or stale `Libraries/` gave verdicts about a kernel the repo does not pin. Measured on
2026-09-28, the two are genuinely different archives: the main checkout's
`Libraries/OCCT.xcframework/macos-arm64/libOCCT-macos.a` hashes to `e2254f34...` and the pinned
`v4.0.0-kernel.2` asset SwiftPM resolves hashes to `27329ac2...`, and `Libraries/` is these scripts'
**default**.

This module is a library, not a detector: it is named with underscores rather than hyphens so its
callers can `import` it directly, it registers no gate, and `Scripts/*.py` detectors import it. Its
`self_test()` returns a list of failures for a caller to fold into its own `--self-test`, so every
script that depends on this logic proves it is not blind rather than trusting a sibling's run.

WHAT IS ACTUALLY COMPARABLE, which is the whole design constraint
-----------------------------------------------------------------
`Package.swift`'s `checksum:` is the sha256 of **`OCCT.xcframework.zip`**, not of the xcframework
directory and not of any archive inside it. Zipping is not reproducible from an extracted tree
(entry order, timestamps, compression level), so **an extracted xcframework cannot be hashed into
that checksum**. There are exactly three things that can be compared, and one thing that cannot:

1. **A zip beside the xcframework.** sha256 it against `Package.swift`'s `checksum:`. This is
   proof, and it is the situation at a release step, where the question "is the thing I just
   checked the thing consumers will download" is live. Lifted out of
   `check-pinned-asset-patches.py`, which already computed it and then only printed it.
2. **SwiftPM's own resolution record.** `.build/workspace-state.json` names the artifact's path,
   its source URL and its checksum, and SwiftPM refuses to unpack an artifact whose zip does not
   hash to the checksum in `Package.swift`. So for a path SwiftPM records, matching that record's
   checksum against `Package.swift`'s is proof by provenance, and it needs no 1.3 GB re-hash.
3. **The archive fingerprint**, the sha256 and byte count of one slice's static library. This
   identifies *which* kernel was read and is comparable across runs and between machines, which is
   what makes a past verdict attributable. It is **not** comparable to anything in the repo, so it
   can never on its own say "this is the pinned asset".
4. **Nothing else.** An extracted tree with no zip beside it and no SwiftPM record is
   `unverifiable`, and saying so is the point: the previous behaviour was to call it pinned.

So the verdict is one of four, and `unverifiable` is a real answer rather than a failure:

    pinned         proven, by (1) or (2)
    not-pinned     positively disproven: a zip that hashes to something else, or a SwiftPM record
                   whose checksum is not the one Package.swift now pins (a stale `.build`)
    unverifiable   present and readable, with nothing in the repo to compare it to
    absent         no xcframework at any candidate path

`--require-pinned-asset` (the #2098 `--require-...` pattern, applied to the identity axis rather
than the empty-population one) makes anything but `pinned` an error, so a job that must measure the
pinned kernel fails loudly instead of reporting about another one.

RESOLUTION ORDER, and why `Libraries/` still wins
-------------------------------------------------
`explicit --asset` > `Libraries/OCCT.xcframework` > the SwiftPM artifact. `Libraries/` keeps
precedence deliberately: a locally built kernel lives there on purpose, and
`check-pinned-asset-patches.py`'s release run has to read exactly that freshly built asset, which is
by definition not yet the pinned one. What changes is not which asset is read but that the report
says which kernel it was. The SwiftPM fallback is what stops a clean checkout from reporting
`SKIPPED` over an asset that is right there.

ACKNOWLEDGING SOMETHING ABOUT AN ASSET
--------------------------------------
`key` is the string to key a per-asset acknowledgement on: the pinned tag when identity is proven,
and `sha256:<16 hex>` of the macos archive otherwise. `check-pinned-asset-patches.py` keyed its
`ACKNOWLEDGED` table on the tag `Package.swift` pins, which is a different thing from the asset it
read, so an acknowledgement written about the pinned asset suppressed a finding about whatever was
on disk. Keying on this instead means an acknowledgement applies to the asset it was written about
and to nothing else.
"""
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LIBRARIES_ASSET = os.path.join("Libraries", "OCCT.xcframework")
SWIFTPM_GLOB = os.path.join(".build", "artifacts", "*", "OCCT", "OCCT.xcframework")
WORKSPACE_STATE = os.path.join(".build", "workspace-state.json")

DEFAULT_SLICE = "macos-arm64"
SLICE_ARCHIVES = {
    "macos-arm64": "libOCCT-macos.a",
    "ios-arm64": "libOCCT-ios.a",
    "ios-arm64-simulator": "libOCCT-sim.a",
}

# These two read `Package.swift`, which is this repo's own file in a shape `swift build` will not
# reformat, so the regexes stay regexes rather than becoming a Swift parser. What matters is not that
# they are clever but that a regex which silently stopped matching would make **every** asset
# `unverifiable` while reading as caution, which is the same failure class as a gate's floor: an
# answer about a population that was never examined. So `identify()` checks that they matched at all
# and names `Package.swift` when they did not, and `self_test()` case 2 runs them against the real
# manifest on every PR. That pair is cheaper than a parser and catches more: a reformatting this
# regex could not survive would fail loudly at the manifest rather than quietly at the asset.
PIN_URL_RE = re.compile(
    r'url:\s*"https://[^"]*/releases/download/([^/]+)/OCCT\.xcframework\.zip"'
)
PIN_SUM_RE = re.compile(r'checksum:\s*"([0-9a-f]{64})"')

MANIFEST_UNREADABLE = (
    "Package.swift is present but its binaryTarget pin did not parse in full: tag=%s checksum=%s. "
    "This is a finding about the MANIFEST rather than about the asset at %s, and it is reported "
    "instead of a verdict because both halves are missing from what a verdict would say: with no "
    "checksum nothing can be compared, and with no tag a PINNED asset would be named after nothing "
    "and keyed for acknowledgement on its archive hash instead of on the pin. PIN_URL_RE and "
    "PIN_SUM_RE in Scripts/occt_asset_identity.py read the `url:` and `checksum:` lines; a "
    "reformatted manifest needs them updated."
)
MANIFEST_MISSING = (
    "No Package.swift at %s, so there is no pin to compare anything against and the asset at %s "
    "cannot be shown to be one."
)

PINNED = "pinned"
NOT_PINNED = "not-pinned"
UNVERIFIABLE = "unverifiable"
ABSENT = "absent"


# --- the pin -------------------------------------------------------------------------------------


def pinned_reference_from(text: str) -> tuple[str | None, str | None]:
    """(tag, checksum) out of `Package.swift`'s text, or (None, None) for either half."""
    tag = PIN_URL_RE.search(text)
    checksum = PIN_SUM_RE.search(text)
    return (tag.group(1) if tag else None), (checksum.group(1) if checksum else None)


def pinned_reference(repo: str = ".") -> tuple[str | None, str | None]:
    path = os.path.join(repo, "Package.swift")
    if not os.path.isfile(path):
        return None, None
    with open(path, encoding="utf-8", errors="replace") as fh:
        return pinned_reference_from(fh.read())


# --- what is on disk -----------------------------------------------------------------------------


def swiftpm_records_from(text: str) -> list[dict]:
    """Every xcframework artifact `.build/workspace-state.json` records, as {path, url, checksum}.

    SwiftPM verifies the downloaded zip against `Package.swift`'s `checksum:` before unpacking and
    refuses a mismatch, so this record is an identity statement about the extracted tree and not
    merely a note about where it came from.
    """
    try:
        state = json.loads(text)
    except ValueError:
        return []
    out = []
    for entry in (state.get("object") or {}).get("artifacts") or []:
        source = entry.get("source") or {}
        path = entry.get("path")
        if not path or source.get("type") != "remote":
            continue
        url = source.get("url") or ""
        tag = url.rsplit("/", 2)[-2] if url.count("/") >= 2 else None
        out.append({"path": path, "url": url, "tag": tag, "checksum": source.get("checksum")})
    return out


def swiftpm_records(repo: str = ".") -> list[dict]:
    path = os.path.join(repo, WORKSPACE_STATE)
    if not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8", errors="replace") as fh:
        return swiftpm_records_from(fh.read())


def is_asset_dir(path: str, slice_dir: str = DEFAULT_SLICE) -> bool:
    """An xcframework this repo can read: the slice's `Headers` directory is what every caller uses."""
    return os.path.isdir(os.path.join(path, slice_dir, "Headers"))


def candidates(repo: str = ".", explicit: str | None = None,
               slice_dir: str = DEFAULT_SLICE) -> list[tuple[str, str]]:
    """(origin, absolute path) in resolution order, whether or not each exists.

    Returned including non-existent paths on purpose: a caller that finds nothing should be able to
    say which paths it looked at, since "SKIPPED" without them is what #2818 is about.
    """
    out: list[tuple[str, str]] = []
    if explicit:
        out.append(("explicit", explicit if os.path.isabs(explicit)
                    else os.path.join(repo, explicit)))
    else:
        out.append(("libraries", os.path.join(repo, LIBRARIES_ASSET)))
        for record in swiftpm_records(repo):
            if is_asset_dir(record["path"], slice_dir):
                out.append(("swiftpm", record["path"]))
        for path in sorted(glob.glob(os.path.join(repo, SWIFTPM_GLOB))):
            if all(os.path.realpath(path) != os.path.realpath(p) for _, p in out):
                out.append(("swiftpm-glob", path))
    return out


def sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 22), b""):
            digest.update(chunk)
    return digest.hexdigest()


def archive_fingerprint(asset: str, slice_dir: str = DEFAULT_SLICE) -> tuple[str | None, int | None]:
    """(sha256, bytes) of one slice's static archive, or (None, None) if it is not there."""
    archive = SLICE_ARCHIVES.get(slice_dir)
    if not archive:
        return None, None
    path = os.path.join(asset, slice_dir, archive)
    if not os.path.isfile(path):
        return None, None
    return sha256_file(path), os.path.getsize(path)


# --- the verdict ---------------------------------------------------------------------------------


@dataclass
class AssetIdentity:
    """Which xcframework a run read, and whether it can be shown to be the one Package.swift pins."""

    path: str | None
    origin: str
    verdict: str
    reason: str
    pinned_tag: str | None = None
    pinned_checksum: str | None = None
    archive_sha256: str | None = None
    archive_bytes: int | None = None
    looked_at: tuple[str, ...] = ()

    @property
    def present(self) -> bool:
        return self.path is not None

    @property
    def key(self) -> str:
        """What to key a per-asset acknowledgement on. Never the pin unless the pin is proven."""
        if self.verdict == PINNED and self.pinned_tag:
            return self.pinned_tag
        if self.archive_sha256:
            return "sha256:" + self.archive_sha256[:16]
        return "unidentified"

    def banner(self, indent: str = "  ") -> list[str]:
        """The lines a caller prints before its own verdicts. Every run, not only a failing one."""
        lines = []
        if not self.present:
            lines.append(f"{indent}asset: ABSENT. {self.reason}")
            for path in self.looked_at:
                lines.append(f"{indent}  looked at: {path}")
            return lines
        lines.append(f"{indent}asset: {self.path}  (via {self.origin})")
        if self.archive_sha256:
            lines.append(f"{indent}archive: sha256={self.archive_sha256} "
                         f"bytes={self.archive_bytes}")
        lines.append(f"{indent}identity: {self.verdict.upper()}. {self.reason}")
        if self.verdict != PINNED:
            lines.append(f"{indent}  Every verdict below is about THIS kernel, which is not shown "
                         f"to be the one Package.swift pins.")
            lines.append(f"{indent}  Acknowledgement key for this asset: {self.key}")
        return lines


def identify(repo: str = ".", explicit: str | None = None, slice_dir: str = DEFAULT_SLICE,
             fingerprint: bool = True) -> AssetIdentity:
    """Resolve the asset a caller should read, and decide what can be proven about it."""
    tag, checksum = pinned_reference(repo)
    looked: list[str] = []
    chosen: tuple[str, str] | None = None
    for origin, path in candidates(repo, explicit, slice_dir):
        looked.append(path)
        if chosen is None and is_asset_dir(path, slice_dir):
            chosen = (origin, path)
    if chosen is None:
        return AssetIdentity(
            None, "none", ABSENT,
            "No OCCT.xcframework with a %s/Headers directory at any candidate path. "
            "`swift package resolve` puts the pinned one under .build/artifacts/." % slice_dir,
            tag, checksum, looked_at=tuple(looked),
        )

    origin, path = chosen
    sha, size = archive_fingerprint(path, slice_dir) if fingerprint else (None, None)
    identity = AssetIdentity(path, origin, UNVERIFIABLE, "", tag, checksum, sha, size,
                             tuple(looked))

    # 0. Did the pin parse at all? Without this, a `Package.swift` the regexes stopped matching sends
    #    every asset down branch 3 as `unverifiable`, or worse down branch 2 as NOT-PINNED with a
    #    message blaming a stale `.build`, which is a positive disproof drawn from a value never read.
    #    Name the manifest instead: `--require-pinned-asset` then refuses with the real cause.
    if not (tag and checksum):
        manifest = os.path.join(repo, "Package.swift")
        identity.verdict = UNVERIFIABLE
        identity.reason = (
            MANIFEST_UNREADABLE % (tag or "unparsed", checksum or "unparsed", path)
            if os.path.isfile(manifest)
            else MANIFEST_MISSING % (manifest, path)
        )
        return identity

    # 1. A zip beside it is the direct comparison, and the only one that survives without SwiftPM.
    #    Beside it, and nowhere else, deliberately: `docs/guides/building-occt.md` builds the release
    #    asset with `cd Libraries && zip -r -y -q OCCT.xcframework.zip OCCT.xcframework`, so the zip a
    #    release step hashes is this repo's documented sibling, and extracting a downloaded zip in
    #    place puts it in the same relation. Searching upward, or taking a `--zip` flag, would add
    #    paths no procedure here produces while widening what counts as proof of the pin, which is the
    #    one verdict that must not be reachable by accident. The two locations a zip is NOT beside the
    #    asset are both already covered: SwiftPM's own download is settled by branch 2's record, which
    #    is stronger, and an unrelated layout is `unverifiable`, which is a real answer and the whole
    #    of #2818. A `--zip` flag is the fix IF a workflow ever needs it; none does today.
    zip_path = os.path.join(os.path.dirname(os.path.abspath(path)), "OCCT.xcframework.zip")
    if os.path.isfile(zip_path) and checksum:
        actual = sha256_file(zip_path)
        if actual == checksum:
            identity.verdict = PINNED
            identity.reason = ("OCCT.xcframework.zip beside it hashes to Package.swift's "
                               "checksum, so this IS the pinned %s asset." % (tag or "asset"))
        else:
            identity.verdict = NOT_PINNED
            identity.reason = ("OCCT.xcframework.zip beside it hashes to %s... where Package.swift "
                               "pins %s..., so this is NOT the pinned asset."
                               % (actual[:16], checksum[:16]))
        return identity

    # 2. SwiftPM's record, which is proof by provenance: it refuses a zip that does not hash to
    #    Package.swift's checksum, so a path it records with that checksum holds that asset.
    real = os.path.realpath(path)
    for record in swiftpm_records(repo):
        if os.path.realpath(record["path"]) != real:
            continue
        if checksum and record["checksum"] == checksum:
            identity.verdict = PINNED
            identity.reason = (".build/workspace-state.json records this path as the artifact "
                               "SwiftPM resolved from %s, whose checksum is the one Package.swift "
                               "pins." % (record["tag"] or record["url"]))
        else:
            identity.verdict = NOT_PINNED
            identity.reason = (".build/workspace-state.json records this path as the artifact "
                               "resolved from %s with checksum %s..., where Package.swift now pins "
                               "%s...; the .build directory predates the repin."
                               % (record["tag"] or record["url"],
                                  (record["checksum"] or "none")[:16],
                                  (checksum or "none")[:16]))
        return identity

    # 3. Nothing comparable. Package.swift's checksum is of the ZIP, and an extracted tree cannot
    #    be re-zipped into it, so there is no computation that would settle this.
    identity.verdict = UNVERIFIABLE
    identity.reason = (
        "No OCCT.xcframework.zip beside it and no .build/workspace-state.json record for this "
        "path, and Package.swift's checksum is of the zip rather than of the extracted tree, so "
        "there is nothing this can be compared against. Run `swift package resolve` and read the "
        ".build artifact, or keep the zip beside the xcframework."
    )
    return identity


def add_arguments(ap: argparse.ArgumentParser, default_asset: str = LIBRARIES_ASSET,
                  asset_flag: bool = True) -> None:
    """Register the two flags every caller of this module shares."""
    if asset_flag:
        ap.add_argument("--asset", default=default_asset,
                        help="the OCCT.xcframework to read (default: %s, then the SwiftPM "
                             "artifact under .build/artifacts/)" % default_asset)
    ap.add_argument("--require-pinned-asset", action="store_true",
                    help="refuse to report unless the asset read is provably the one "
                         "Package.swift pins (#2818)")


def explicit_from(args: argparse.Namespace, default_asset: str = LIBRARIES_ASSET) -> str | None:
    """`--asset` as an override, or None when it is still the default and the fallback applies.

    A caller that passes `--asset` explicitly means that asset and nothing else. A caller that
    leaves it alone gets the resolution order, which is what stops a clean checkout from reporting
    SKIPPED while the pinned asset sits in `.build`.
    """
    value = getattr(args, "asset", None)
    if not value or value == default_asset:
        return None
    return value


def refusal(identity: AssetIdentity, require: bool) -> str | None:
    """The message a `--require-pinned-asset` run should die with, or None to carry on."""
    if not require or identity.verdict == PINNED:
        return None
    if not identity.present:
        return ("--require-pinned-asset and no asset was found. A clean report over a population "
                "that was never read is a false green, not a result. " + identity.reason)
    return ("--require-pinned-asset and the asset at %s is %s: %s"
            % (identity.path, identity.verdict.upper(), identity.reason))


# --- self-test, returned rather than printed ------------------------------------------------------


def self_test(repo: str = REPO_ROOT) -> list[str]:
    """Failures, for a caller to fold into its own `--self-test`. Empty means every case passed."""
    failures: list[str] = []
    import tempfile

    good = "a" * 64
    other = "b" * 64

    # 1. The pin is parsed out of Package.swift's real shape, tag and checksum both.
    manifest = (
        '        .binaryTarget(\n'
        '            name: "OCCT",\n'
        '            url: "https://github.com/SecondMouseAU/OCCTSwift/releases/download/'
        'v9.9.9-kernel.1/OCCT.xcframework.zip",\n'
        '            checksum: "%s"\n' % good
    )
    tag, checksum = pinned_reference_from(manifest)
    if (tag, checksum) != ("v9.9.9-kernel.1", good):
        failures.append(f"pinned_reference_from(): got {(tag, checksum)}")

    # 2. The real Package.swift yields both halves. Validate the view, not only the verdict: a
    #    regex that stopped matching would make every asset `unverifiable` and look cautious.
    real_tag, real_sum = pinned_reference(repo)
    if not real_tag or not real_sum:
        failures.append(
            f"the real Package.swift parsed to tag={real_tag!r} checksum={real_sum!r}; the pin "
            f"regexes no longer match, so no asset could ever be shown to be pinned"
        )

    # 3. workspace-state.json's shape, including the tag recovered from the URL.
    records = swiftpm_records_from(json.dumps({
        "version": 7,
        "object": {"artifacts": [
            {"path": "/x/.build/artifacts/p/OCCT/OCCT.xcframework",
             "source": {"type": "remote", "checksum": good,
                        "url": "https://h/releases/download/v1.2.3/OCCT.xcframework.zip"}},
            {"path": "/x/local", "source": {"type": "local"}},
        ]},
    }))
    if len(records) != 1 or records[0]["tag"] != "v1.2.3" or records[0]["checksum"] != good:
        failures.append(f"swiftpm_records_from(): got {records}")
    if swiftpm_records_from("not json at all") != []:
        failures.append("swiftpm_records_from() did not survive unparseable JSON")

    def scaffold(root: str, *, pin_sum: str, want_headers: bool = True,
                 asset_rel: str = LIBRARIES_ASSET) -> str:
        os.makedirs(os.path.join(root, "Libraries"), exist_ok=True)
        with open(os.path.join(root, "Package.swift"), "w") as fh:
            fh.write('url: "https://h/releases/download/v9.9.9/OCCT.xcframework.zip"\n'
                     'checksum: "%s"\n' % pin_sum)
        asset = os.path.join(root, asset_rel)
        if want_headers:
            os.makedirs(os.path.join(asset, DEFAULT_SLICE, "Headers"), exist_ok=True)
            with open(os.path.join(asset, DEFAULT_SLICE, SLICE_ARCHIVES[DEFAULT_SLICE]), "wb") as fh:
                fh.write(b"archive bytes")
        return asset

    # 4. ABSENT is not "unverifiable": a missing asset must say so, and must name where it looked.
    with tempfile.TemporaryDirectory() as root:
        scaffold(root, pin_sum=good, want_headers=False)
        ident = identify(root)
        if ident.verdict != ABSENT or ident.present:
            failures.append(f"a missing asset reported {ident.verdict}, expected {ABSENT}")
        if not ident.looked_at:
            failures.append("an absent asset reported no candidate paths, so the report cannot "
                            "say where to put one")

    # 5. UNVERIFIABLE: present, no zip, no SwiftPM record. This is the case that used to read as
    #    "this is the pinned kernel", and it is the whole of #2818.
    with tempfile.TemporaryDirectory() as root:
        scaffold(root, pin_sum=good)
        ident = identify(root)
        if ident.verdict != UNVERIFIABLE:
            failures.append(f"an extracted asset with nothing to compare reported "
                            f"{ident.verdict}, expected {UNVERIFIABLE}")
        if not ident.archive_sha256:
            failures.append("no archive fingerprint was computed, so the run is not attributable")
        if ident.key.startswith("v"):
            failures.append(f"an unverifiable asset took the PIN as its acknowledgement key "
                            f"({ident.key}); an acknowledgement about the pinned asset would "
                            f"suppress a finding about this one")

    # 6. PINNED by a zip beside it, and NOT-PINNED when that zip hashes to something else. The
    #    checksum is of the ZIP, which is why the fixture hashes a zip file rather than the tree.
    for label, pin, expected in (("matching", None, PINNED), ("differing", other, NOT_PINNED)):
        with tempfile.TemporaryDirectory() as root:
            asset = scaffold(root, pin_sum=good)
            zip_path = os.path.join(os.path.dirname(asset), "OCCT.xcframework.zip")
            with open(zip_path, "wb") as fh:
                fh.write(b"zip bytes")
            digest = sha256_file(zip_path)
            with open(os.path.join(root, "Package.swift"), "w") as fh:
                fh.write('url: "https://h/releases/download/v9.9.9/OCCT.xcframework.zip"\n'
                         'checksum: "%s"\n' % (pin or digest))
            ident = identify(root)
            if ident.verdict != expected:
                failures.append(f"a {label} zip beside the asset reported {ident.verdict}, "
                                f"expected {expected}")
            if expected == PINNED and ident.key != "v9.9.9":
                failures.append(f"a proven asset keyed on {ident.key}, expected the pinned tag")

    # 7. PINNED by SwiftPM's record, which is the case that matters in a clean checkout, and
    #    NOT-PINNED when `.build` predates the repin. Nothing else in the repo can tell those apart.
    for label, record_sum, expected in (("current", good, PINNED), ("stale", other, NOT_PINNED)):
        with tempfile.TemporaryDirectory() as root:
            asset = scaffold(root, pin_sum=good, want_headers=True,
                             asset_rel=os.path.join(".build", "artifacts", "p", "OCCT",
                                                    "OCCT.xcframework"))
            os.makedirs(os.path.join(root, ".build"), exist_ok=True)
            with open(os.path.join(root, WORKSPACE_STATE), "w") as fh:
                json.dump({"version": 7, "object": {"artifacts": [
                    {"path": asset, "source": {
                        "type": "remote", "checksum": record_sum,
                        "url": "https://h/releases/download/v9.9.9/OCCT.xcframework.zip"}}]}}, fh)
            ident = identify(root)
            if ident.verdict != expected:
                failures.append(f"a {label} workspace-state record reported {ident.verdict}, "
                                f"expected {expected}")
            if ident.origin != "swiftpm":
                failures.append(f"a recorded SwiftPM artifact resolved via {ident.origin} rather "
                                f"than from the record, so a clean checkout depends on the glob "
                                f"matching the scratch path")

    # 7b. The record route is not the same as the glob, and only the record survives a scratch path
    #     the glob cannot see (`swift build --scratch-path`, and the shared artifact cache). Without
    #     this case the removal matrix showed the record route could be deleted outright and every
    #     one of the five self-tests stayed green, because the fixture above sat under the glob too.
    with tempfile.TemporaryDirectory() as root:
        asset = scaffold(root, pin_sum=good, want_headers=True,
                         asset_rel=os.path.join("elsewhere", "OCCT.xcframework"))
        os.makedirs(os.path.join(root, ".build"), exist_ok=True)
        with open(os.path.join(root, WORKSPACE_STATE), "w") as fh:
            json.dump({"version": 7, "object": {"artifacts": [
                {"path": asset, "source": {
                    "type": "remote", "checksum": good,
                    "url": "https://h/releases/download/v9.9.9/OCCT.xcframework.zip"}}]}}, fh)
        ident = identify(root)
        if ident.origin != "swiftpm" or ident.verdict != PINNED:
            failures.append(f"an artifact recorded outside {SWIFTPM_GLOB} resolved as "
                            f"{ident.origin}/{ident.verdict}, expected swiftpm/{PINNED}")

    # 8. `Libraries/` keeps precedence, because a locally built kernel lives there on purpose and
    #    the release check has to read exactly it. What changes is the verdict, not the choice.
    with tempfile.TemporaryDirectory() as root:
        scaffold(root, pin_sum=good)
        build_asset = os.path.join(root, ".build", "artifacts", "p", "OCCT", "OCCT.xcframework")
        os.makedirs(os.path.join(build_asset, DEFAULT_SLICE, "Headers"))
        ident = identify(root, fingerprint=False)
        if ident.origin != "libraries":
            failures.append(f"Libraries/ lost precedence to {ident.origin}")

    # 9. The refusal fires on every non-pinned verdict and on nothing else, since a flag that
    #    passes an unverifiable asset is the behaviour this module replaces.
    for verdict, want_refusal in ((PINNED, False), (NOT_PINNED, True),
                                  (UNVERIFIABLE, True), (ABSENT, True)):
        ident = AssetIdentity("/x" if verdict != ABSENT else None, "explicit", verdict, "because")
        got = refusal(ident, require=True) is not None
        if got != want_refusal:
            failures.append(f"--require-pinned-asset on {verdict}: refusal={got}, "
                            f"expected {want_refusal}")
        if refusal(ident, require=False) is not None:
            failures.append(f"{verdict} refused without --require-pinned-asset")

    # 10. The banner carries the caveat on every non-pinned verdict, which is what a reader of a
    #     past report needs. A verdict with no caveat reads as a verdict about the pinned kernel.
    caveated = AssetIdentity("/x", "libraries", UNVERIFIABLE, "because",
                             archive_sha256="f" * 64, archive_bytes=1)
    text = "\n".join(caveated.banner())
    if "UNVERIFIABLE" not in text or "not shown to be the one Package.swift pins" not in text:
        failures.append("the banner for an unverifiable asset carries no caveat")
    if "f" * 64 not in text:
        failures.append("the banner omits the archive fingerprint, so the run is not attributable")
    clean = AssetIdentity("/x", "swiftpm", PINNED, "because", pinned_tag="v1")
    if "not shown to be" in "\n".join(clean.banner()):
        failures.append("a proven asset's banner carries a caveat it does not need")

    # 10b. #2833's review of the pin regexes. The answer is not a cleverer regex but a check that
    #      they matched at all: a `Package.swift` these two stop reading must produce a finding about
    #      the MANIFEST, not a quiet `unverifiable` about the asset, and above all not the NOT-PINNED
    #      "your .build predates the repin" that branch 2 used to reach with a checksum it never read.
    #      That second half is the one worth the fixture: it is a positive disproof drawn from None.
    for label, manifest_text in (("no checksum:", 'url: "https://h/releases/download/v9/'
                                                  'OCCT.xcframework.zip"\n'),
                                 ("no url:", 'checksum: "%s"\n' % good),
                                 ("reformatted", 'url:"https://h/x.zip"\nchecksum:"%s"\n' % good)):
        with tempfile.TemporaryDirectory() as root:
            asset = scaffold(root, pin_sum=good)
            with open(os.path.join(root, "Package.swift"), "w") as fh:
                fh.write(manifest_text)
            os.makedirs(os.path.join(root, ".build"), exist_ok=True)
            with open(os.path.join(root, WORKSPACE_STATE), "w") as fh:
                json.dump({"version": 7, "object": {"artifacts": [
                    {"path": asset, "source": {
                        "type": "remote", "checksum": good,
                        "url": "https://h/releases/download/v9.9.9/OCCT.xcframework.zip"}}]}}, fh)
            ident = identify(root)
            if ident.verdict != UNVERIFIABLE:
                failures.append(f"a manifest with {label} reported {ident.verdict}, expected "
                                f"{UNVERIFIABLE}; a pin that did not parse must not reach a verdict "
                                f"about the asset")
            if "Package.swift" not in ident.reason or "PIN_URL_RE" not in ident.reason:
                failures.append(f"a manifest with {label} blamed the asset rather than the "
                                f"manifest: {ident.reason}")
    #      ...and a repo with no manifest at all says so rather than falling through the same branch.
    with tempfile.TemporaryDirectory() as root:
        scaffold(root, pin_sum=good)
        os.remove(os.path.join(root, "Package.swift"))
        ident = identify(root)
        if ident.verdict != UNVERIFIABLE or "No Package.swift" not in ident.reason:
            failures.append(f"a repo with no Package.swift reported {ident.verdict}: {ident.reason}")

    # 11. `--asset` as an override versus left at its default. A caller that passes the default
    #     must still get the fallback, or #2818's SKIPPED comes straight back.
    ns = argparse.Namespace(asset=LIBRARIES_ASSET)
    if explicit_from(ns) is not None:
        failures.append("the default --asset was treated as an override, so the SwiftPM fallback "
                        "never applies")
    ns = argparse.Namespace(asset="/somewhere/else")
    if explicit_from(ns) != "/somewhere/else":
        failures.append("an explicit --asset was not honoured")

    return failures


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--self-test", action="store_true", help="prove each failure mode is caught")
    add_arguments(ap)
    args = ap.parse_args()

    if args.self_test:
        failures = self_test()
        for line in failures:
            print(f"SELF-TEST FAILURE: {line}")
        if failures:
            return 1
        print("SELF-TEST: OK (16 cases: pin parse, real pin, workspace-state parse x2, absent, "
              "unverifiable, zip pinned/not-pinned, workspace-state pinned/stale, a record "
              "outside the glob, Libraries precedence, refusal matrix, banner caveat, unparsed "
              "pin x3, missing manifest, --asset override)")
        return 0

    identity = identify(".", explicit_from(args))
    for line in identity.banner(indent=""):
        print(line)
    message = refusal(identity, args.require_pinned_asset)
    if message:
        print(message, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    os.chdir(REPO_ROOT)
    sys.exit(main())
