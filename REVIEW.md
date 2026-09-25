# REVIEW.md

Repository-specific guidance for the Kilo Code Review agent on `SecondMouseAU/OCCTSwift`.

**The rules are not in this file.** They live in [`okf/policies/`](okf/policies/), which is
canonical, and in [`CLAUDE.md`](CLAUDE.md), which is the working summary of them. This file says
which of those pages apply to a diff, what this repository counts as a defect, and which habits of
a general purpose reviewer produce noise here. Where this file and a policy page disagree, the
policy page wins and the disagreement is itself worth reporting.

## What this repository is

A Swift wrapper for OpenCASCADE Technology (OCCT), pinned to the latest release, in three layers: a
Swift public API in `Sources/OCCTSwift/`, a C function bridge written in Objective-C++ in
`Sources/OCCTBridge/`, and a pre-built OCCT static library in `Libraries/OCCT.xcframework`. Swift 6
language mode, strict concurrency, macOS arm64 v12+ and iOS arm64 v15+.

**The kernel is not stock.** `Scripts/patches/` carries fixes for defects this project found and
resolved, and the pinned build includes them, so upstream behaviour and this repository's behaviour
can legitimately differ. [`okf/references/carried-occt-patches.md`](okf/references/carried-occt-patches.md)
records which patches exist and which the pin actually holds.

The consequence that matters most for review: **an OS signal or a C++ exception raised inside OCCT
cannot be caught once it reaches Swift.** `OCC_CATCH_SIGNALS` is inert in this build. A missing
guard in the bridge is not a nil return, it is a process abort inside the consumer's application.

## Priorities, highest first

1. **A value returned as a measurement that was never computed.** A field left at its zero
   initialiser, a fallback constant, or a result read from an algorithm that reported failure, all
   handed to the caller as though measured. This repository runs a standing census for it
   (`Scripts/census-unmeasured-values.py`, issue #726). Tests usually pass over these, so a green
   suite is not a defence. CRITICAL.
2. **A missing null handle or null shape guard in the bridge.** See
   [`okf/policies/null-handle-guards.md`](okf/policies/null-handle-guards.md) for where the guard is
   required, where it is noise, what it must return, and the aliases the gate is blind to. 36 of
   the 57 handle taking entry points were measured to crash uncatchably without one. CRITICAL.
3. **An uncaught throwing OCCT call.** Every throwing construction or evaluator is caught, guarded
   or unreachable (`Scripts/check-throwing-calls.py`), and every function level `catch (...)` in the
   bridge records what it caught (`Scripts/check-bridge-diagnostics.py`). CRITICAL.
4. **A claim in the diff or the PR body that no measurement supports.** See
   [`okf/policies/measure-dont-assume.md`](okf/policies/measure-dont-assume.md). A comment, doc line
   or PR sentence asserting kernel behaviour derived from a signature, a name or recall rather than
   from observation is a finding here, even when it happens to be true.
5. **A test that was never proved to fail.**
   [`okf/policies/prove-the-test-fails.md`](okf/policies/prove-the-test-fails.md) requires every new
   test and every new `--self-test` case to be run once with its subject broken, with both results
   reported in the PR. A PR that adds a test and reports no injected failure is incomplete. WARNING.
6. **Documentation that did not ship with the change.**
   [`okf/policies/docs-current.md`](okf/policies/docs-current.md). A public API change carries its
   `///` summary, its parameter docs and at least one compilable `swift` snippet; `docs/reference/`
   and `docs/API_REFERENCE.md` are the other sites. WARNING.
7. **PR body mechanics**, all required by
   [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md): the CHANGELOG entry
   ([policy](okf/policies/changelog-on-merge.md)), the `## SemVer impact` statement
   ([policy](okf/policies/semver-at-release.md)), and one `Closes #<n>` line per issue, since GitHub
   reads the keyword per issue and not per list.
8. **Writing style**, in code comments, documentation, the commit message and the PR body alike: no
   em-dashes, plus the banned words in
   [`okf/policies/writing-style.md`](okf/policies/writing-style.md).
9. **Scope.** A feature that is not a direct wrap of an OCCT operation belongs in a downstream
   ecosystem package ([policy](okf/policies/scope-boundary.md)), and new code that reimplements
   something the repository already has is a finding
   ([policy](okf/policies/search-before-building.md)).

## Do not report these

Each of these has already been decided, and raising it costs a round trip.

- **`docs/CHANGELOG.md` and `docs/SEMVER.md` missing from the diff.** Their absence is correct and
  required: both are written on `main` at merge and at release, not in the PR. The SemVer policy
  says so in its own reviewer section. What is reviewable is whether the stated SemVer impact
  matches what the diff actually does, and a PR claiming PATCH while removing a public field is a
  real finding.
- **Per function repetition in the bridge.** `Sources/OCCTBridge/` is a hand written C wrapper over
  a C++ API. Every function repeating the same guard, cast and catch shape is the design, not
  duplication waiting to be factored out.
- **Formatting nits in `Scripts/repro/`.** Those directories hold ground truth probes and the
  verbatim captured output of running them. A transcript is evidence, so a missing trailing newline
  or an odd indent in one is not a defect. Six such comments landed on PR #2702.
- **Bridge formatting in general.** `Scripts/format-bridge.sh` and a pinned clang-format version own
  it and CI enforces it. Report that the tool appears not to have been run, but do not hand review
  alignment.
- **A `@Test(arguments:)` case list rewritten as one test walking an array.** That is a documented
  workaround for a toolchain defect (swiftlang/swift#91639), not a style choice to clean up. See
  `CLAUDE.md` under Test Conventions.
- **`withKnownIssue` wrappers that cite an issue.** They pin a known defect deliberately. One with
  no issue reference is worth flagging; one with a reference is not.
- **A broad `catch (...)` at the Swift boundary.** Narrowing it would let a C++ exception reach
  Swift, which aborts the process uncatchably.

## Where to look harder

- **Anything touching concurrency.** `docs/thread-safety.md` is the guidance and
  `Scripts/tsan-stress.sh` is a required gate for such a change. Unsynchronised OCCT globals have a
  long history in this project; [`okf/references/known-occt-bugs.md`](okf/references/known-occt-bugs.md)
  is the record.
- **`Scripts/patches/`.** A carried kernel patch has its own lifecycle
  ([policy](okf/policies/upstream-occt-patch-process.md)), and a patch on disk is not necessarily in
  the pinned asset ([policy](okf/policies/pinned-kernel-patch-check.md)).
- **`Package.swift`, `Libraries/` and the kernel pin**, which change what every consumer links
  against.
- **`Scripts/*.py` gates and censuses.** A change to a detector runs its `--self-test`
  ([policy](okf/policies/static-gates.md)): three gates were confidently wrong while reporting all
  clear.

## Swift Testing conventions worth checking

- **Never force unwrap inside `#expect`.** Swift Testing does not short circuit, so
  `#expect(r != nil)` followed by `#expect(r!.isValid)` crashes the run instead of failing the test.
  The `if let r = result { ... }` form is the one to use.
- **`@Suite` struct names are unique within a target**, and `swift test --filter` matches the struct
  name rather than the `@Suite` display string.
- **A new suite belongs in the domain target that matches it** (`Tests/OCCT<Domain>Tests/`), falling
  back to `OCCTMiscTests`. Each target is a separate module with its own `@testable import`.

## OCCT specifics a reviewer should not guess at

[`okf/policies/context-first.md`](okf/policies/context-first.md) binds reviewers too: do not assert
what an OCCT class does from recall. The pinned headers under
`Libraries/OCCT.xcframework/*/Headers` are the source of truth for the pinned version, and
[`okf/references/known-occt-bugs.md`](okf/references/known-occt-bugs.md) records the defects already
found, several of them cases where the obvious reading of OCCT's own documentation is wrong.
