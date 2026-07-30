# OCCTSwift#499 probe: `TDocStd_PathParser` vs `OSD_Path`

Ground-truth measurement of the two OCCT path-parsing classes OCCTSwift wrapped behind two
identically-named Swift enums (`PathParser` and `OSDPath`). Not a crash reproducer: it prints what
each class returns for 19 inputs so the divergence can be read off rather than argued about.

No fixtures, no kernel patch, no OCCTSwift build. It links the pinned xcframework directly.

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/499-path-parsing-divergence/occt_499_path_divergence.mm -o /tmp/occt_499_probe
/tmp/occt_499_probe
```

It mirrors the bridge exactly on both sides: `TCollection_ExtendedString` in and
`TCollection_AsciiString` out for `TDocStd_PathParser` (what `OCCTPathParser*` did), plain
`TCollection_AsciiString` for `OSD_Path` (what `OCCTOSDPath*` does).

## What it shows

**The reported divergence, confirmed.** The extension differs by its leading dot, because the two
classes split at different offsets:

- `OSD_Path.cxx:254-257` (`UnixExtract`): `pos = name.SearchFromEnd("."); ext = name.Split(pos - 1);`
  splits one character *before* the dot, so the dot stays on the extension.
- `TDocStd_PathParser.cxx:30-33` (`Parse()`): `myExtension = temp.Split(PointPosition);` splits *at*
  the dot, so the dot is discarded.

**A larger divergence the issue did not mention.** `OSD_Path::Trek()` is OCCT's portable directory
syntax, not a filesystem path: `UnixExtract` runs `trek.ChangeAll('/', '|')` and rewrites `..` as
`^`. So `/home/user/model.step` gives `"|home|user|"` where `TDocStd_PathParser` gives
`"/home/user"`. `OSDPath.trek` had no test of any kind and a doc comment reading only "Get the
directory trek from a path".

**Four cases where `TDocStd_PathParser` is wrong, not just differently formatted.**

| input | `TDocStd_PathParser` | `OSD_Path` |
|---|---|---|
| `/home/user/model` | trek `""`, name `""`, ext `""` | trek `\|home\|user\|`, name `model`, ext `""` |
| `/home/user/.config` | throws `TCollection_ExtendedString::Split index` | name `""`, ext `.config` |
| `.` | throws `TCollection_ExtendedString::Split index` | ext `.` |
| `/home/a.b/model` | trek `/home`, name `a`, ext `b/model` | trek `\|home\|a.b\|`, name `model`, ext `""` |

`Parse()` returns early at `TDocStd_PathParser.cxx:35-38` when the path holds no dot, leaving name
and trek at their empty defaults. When the basename *starts* with a dot, the second `Split` is
handed an index equal to the remaining length and throws; the bridge's `catch (...)` turned that
into `nil`. And the dot search runs over the whole path with no separator awareness, so a dot in a
directory name is read as the start of the file's extension.

**The issue's non-ASCII prediction, inverted.** #499 expected `OSD_Path` to raise the
`ConstructionError` its header documents for characters outside `' '...'~'` (`OSD_Path.hxx:43-46`),
making every `OSDPath` method return `nil` for a non-ASCII path, while `TDocStd_PathParser`'s
`TCollection_ExtendedString` handled it. Both halves are wrong:

- `OSD_Path.cxx` contains no `Standard_ConstructionError` throw at all. The header includes the
  class and documents the constraint; nothing enforces it. `/home/üser/mødel.step` parses cleanly.
- `TDocStd_PathParser` returned `mÃ¸del` for that same path, from the bridge side:
  `TCollection_ExtendedString(const char* theString, bool theIsMultiByte = false)` defaults to
  *false*, so UTF-8 bytes were copied one per `ExtCharacter` and re-encoded as UTF-8 on the way back
  through `TCollection_AsciiString`.

**`OSD_Path::IsValid` accepts everything tried**, including the empty string, so `OSDPath.isValid`
is a system-type syntax check and not a "can I open this" test. Its doc comment now says so.

## Outcome

Fixed bridge-side, no kernel patch and no xcframework rebuild. `OCCTPathParserTrek`/`Name`/
`Extension`/`FreeString` are deleted, `TDocStd_PathParser` is no longer wrapped, and Swift
`PathParser` is a deprecated forwarder onto `OSDPath`. Regression coverage lives in
`Tests/OCCTFoundationTests/PathParsingContractTests.swift`, which cross-checks the two spellings
against each other and pins each case in the table above. 8 of its 15 original tests failed against
the unmodified bridge.

Neither `TDocStd_PathParser` defect is filed upstream. `TDocStd_PathParser` is OCAF-internal, used
by OCCT only on document paths it constructed itself, and OCCT has `OSD_Path` for general path
parsing; the fix for a consumer is to not use it, which is what this issue did.
