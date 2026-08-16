**Status: never posted, and now moot.** Drafted 2026-08-07 as a reply to gkv311's review on
[OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418), held at prepare-and-stop, and
overtaken: dpasukhi merged #1418 on 2026-08-10 with "Thank you for the patch!", as the one-line
one-file change it was opened as. Kept because the measurement it reports is real, and because a
draft that reads as pending is worth marking rather than deleting.

**Two things it describes as done were never done**, and both are visible on the merged PR:

- The PR description was **not** rewritten to lead with the provenance. `pr-1418-description.md`
  beside this file is that rewrite; the live description is still the behavioural writeup filed
  first. The provenance itself is recorded in [`../README.md`](../README.md)'s "Upstream provenance
  (#756)" section, which is where it now lives.
- The Draw test was **not** added. `tests/bugs/moddata_3/bug1418` beside this file is still staged,
  and the merged PR touches exactly one file,
  `src/ModelingData/TKGeomBase/AdvApp2Var/AdvApp2Var_ApproxF2var.cxx`, 1 insertion and 1 deletion.
  Contributing it now would be a separate PR against a merged fix, which nobody has decided to do.

Two edits #803 asked for were never applied either, and no longer matter because nothing is going to
be sent: the "I did not have the OCCT tree checked out anywhere convenient" sentence in §1 (we have
one now, see §0 of the upstream patch process), and §2's claim that the Draw test uses "the same
idiom" as `tests/bugs/modalg_7/bug23942`, which is true of the `dlog`/`dump` capture but not of the
regex, where `bug23942` has a quirk we deliberately did not copy.

---

Thanks, both points landed. Answering in order.

## 1. Provenance

Confirmed, and pinned more precisely than the commit alone. `3016a390` renumbers every
workspace offset in `mma2ce1_` down by one (folding the old `ipt1` base into the new
`wrkar_off` pointer), and every other call site in the diff moves with it, for instance the
neighbouring `mmapptt_` calls going from `&wrkar[ipt1]`/`&wrkar[ipt2]` to
`wrkar_off`/`&wrkar_off[ipt1]`. The two `mma2jmx_` calls a few lines down should have become
`&wrkar_off[ipt4]` (U) and `&wrkar_off[ipt5]` (V). The V line moved; the U line kept its old
name, `ipt5`, landing both writes on the slot the V line already owns.

Checked the release tags either side of the commit directly, rather than just the commit's own
diff:

```
V7_5_0 (2020-11-02): AdvApp2Var_ApproxF2var::mma2jmx_(ndjacu, iordru, &wrkar[ipt5]);
                     AdvApp2Var_ApproxF2var::mma2jmx_(ndjacv, iordrv, &wrkar[ipt6]);

V7_6_0 (2021-11-01): AdvApp2Var_ApproxF2var::mma2jmx_(ndjacu, iordru, &wrkar_off[ipt5]);
                     AdvApp2Var_ApproxF2var::mma2jmx_(ndjacv, iordrv, &wrkar_off[ipt5]);
```

`V7_5_0` has two distinct slots. `V7_6_0`, the first release to carry the commit, already has
both calls on one slot, and `master` is unchanged from `V7_6_0` at this site today. So the
regression is confirmed at the shipped 7.6.0 release, not just at the commit in isolation. PR
description rewritten to lead with this; it is a much clearer way in than the behavioural
writeup I filed first.

I did not have the OCCT tree checked out anywhere convenient, so this was read from a disposable
shallow clone (`git fetch --depth=1` against the two tags and the commit) rather than a working
tree, but the diffs and file contents above are read directly, not reconstructed.

## 2. The Draw test

Added `tests/bugs/moddata_3/bug1418`, completing the assertion block. This project only builds
a static library, not `DRAWEXE`, so I could not run the script itself. The degree numbers are
still measured, not assumed: the same `GeomConvert_ApproxSurface` constructor call `approxsurf`
makes (confirmed by reading `GeomliteTest_SurfaceCommands.cxx`, including that `approxsurf`'s
9-argument form leaves `PrecisCode` at its default of 1, not 0) reproduces the sphere/tolerance
request outside Draw, against the same kernel build. Both `PrecisCode` values agree:

```
before:  udeg=1  vdeg=7
after:   udeg=7  vdeg=7
```

7/7 is correct. The test asserts both.

Two things in the commented-out block don't run as written, independent of the degree values.
`dumpjson` is not a Draw command anywhere in this tree; I could not find it registered, and the
nearest thing, `bounding -dumpJson`, is a flag on specific commands rather than a standalone one
taking an object name. And even a working `DumpJson` capture would not match `"udeg"`:
`Standard_Dump::DumpFieldToName` strips the `my` prefix from `myUDeg`/`myVDeg` but does not
change case, so the actual keys are `"UDeg"`/`"VDeg"`. Either problem alone leaves the `udeg`
Tcl variable unset, and the check becomes a Tcl error rather than a check of anything.

The test instead captures `dump r`'s existing textual output through `dlog`, and reads the
`Degrees :` line `GeomTools_SurfaceSet::PrintSurface` writes for a `Geom_BSplineSurface`. That
line and that capture pattern are already load-bearing elsewhere in the tree, in
`tests/bugs/modalg_7/bug23942`, so this is the same idiom rather than a new one:

```tcl
decho off
dlog reset
dlog on
dump r
set info [dlog get]
dlog reset
dlog off
decho on
regexp {Degrees :([0-9]+) +([0-9]+)} ${info} full udeg vdeg
```

It discriminates: `udeg` is 1 on stock and 7 with this PR applied, `vdeg` is 7 either way (this
particular defect is U-only, on this fixture).

No internal bug id is attached to this PR, so I named the file after the PR number. Happy to
rename to whatever id gets assigned.
