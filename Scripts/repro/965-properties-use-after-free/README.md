# #965: `*Properties` views borrowed their parent's handle without retaining it

Nineteen `*Properties` accessors returned a value that stored the parent's `OCCT*Ref` directly.
The parent is a `final class` whose `deinit` calls the matching `Release`, so a view that outlived
its parent held a released handle. Reading any member of it was a use-after-free.

The reproducer is `Scripts/repro/harnesses/PropertiesLifetime.swift`, run as
`OCCTSWIFT_LOCAL=1 swift run Harnesses 965-properties-lifetime` (the shared `Harnesses` target,
per #694: an issue's own directory keeps its README and captured output, not Swift source).

## What it actually did before the fix

**It crashed, every time, and it also returned garbage.** Both, not one or the other, and which one
you get depends only on how far the read is from the release.

- **SIGSEGV, deterministic.** `harness-before-fix.txt` records three separate runs, each isolating
  one read shape. All three exit 139. The issue's own spelling,
  `edge.curve3D?.circleProperties.radius`, is the first of them. The corresponding test crashes the
  test process on its own too: `swift test --filter chainedAccessOnATemporaryParent` alone exits
  with `unexpected signal code 11`.
- **A silently wrong number, when the read happens to land after the block is reused.**
  `tests-before-fix.txt` is the injected-defect run of the three new suites, and it has
  `result.view.radius → 1002.0` where 5.0 was expected, `1001.0` where 7.0 was, `1004.0` where 7.0
  was. Those are ballast radii: the freed wrapper was recycled by a later `Curve3D.circle(radius:
  1000 + i)`, and the view read a completely different curve. No crash, no diagnostic, a plausible
  double.
- **Correct, when the parent happens to be alive.** The `control` rows pass before and after the
  fix. That is the workaround the issue documents, and it is why the defect survived: any call site
  that binds the parent to a local works.

The transcript's last line is truncated mid-message because the process died while Swift Testing was
still writing it. That is left as captured rather than tidied.

## AddressSanitizer was not needed, and was run anyway

The crash is deterministic in a plain debug build, so ASan was not required to establish that
something is wrong. It was run to establish *what*, and it names the mechanism rather than the
symptom. `asan-heap-use-after-free.txt` is the report: `READ of size 8`, freed by
`Curve3D.deinit -> OCCTCurve3DRelease`, allocated by `Curve3D.circle -> OCCTCurve3DCreateCircle`,
read by `CircleProperties.radius -> OCCTCurve3DCircleRadius -> handle<Geom_Curve>::get()`. The
allocation, the free and the read are all in one report with the three stacks that matter.

Reproduce with:

    OCCT965_READ=escaped OCCTSWIFT_LOCAL=1 \
      swift run --sanitize=address Harnesses 965-properties-lifetime

ASan sees this because SwiftPM builds `OCCTBridge` from source and therefore instruments the load
inside `OCCTCurve3DCircleRadius`. The OCCT static archive itself is uninstrumented, which does not
matter here: the read that faults is on our side of the boundary.

## Phase 1 is the part that reports when the process cannot

Reading through a dangling view can crash, so the harness measures the lifetime first, without
touching freed memory at all: it takes a view, lets the parent's scope end, and asks a `weak`
reference whether the parent survived. Before the fix that is `false` for all three parents; after
it, `true`. The tests are built the same way, which is why
`everyAccessorKeepsItsParentAlive` fails cleanly and reports all nineteen accessors, where the
chained test can only kill the process.

## Files

| File | What it is |
|---|---|
| `harness-before-fix.txt` | Three runs against the unfixed tree, all exit 139 |
| `harness-after-fix.txt` | The same harness after the fix, exit 0, every value correct |
| `tests-before-fix.txt` | The three new suites run against the injected defect |
| `asan-heap-use-after-free.txt` | The ASan report, with the allocate/free/read stacks |

## The fix, and what holds it

`NativeHandleView` (`Sources/OCCTSwift/NativeHandleView.swift`) stores the owner and reads the
handle through it. All nineteen conform, so the retain is written once rather than nineteen times.

`Scripts/check-borrowed-handles.py` is what keeps nineteen from becoming eighteen: it fails on any
struct or enum in `Sources/OCCTSwift` that stores an `OCCT*Ref`, since neither has a `deinit` to
release one. Run against the pre-fix tree it reports exactly these nineteen sites, at the same line
numbers an independently written sweep found; against the fixed tree it reports none.
