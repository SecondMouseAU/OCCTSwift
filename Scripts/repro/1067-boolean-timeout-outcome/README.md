# #1067, a boolean timeout is not a boolean failure

`subtracting`, `union` and `intersection` return `nil` both when the boolean genuinely fails and
when it exceeds its wall-clock `timeout` (`Shape.defaultBooleanTimeout`, 120s). A caller cannot tell
"this geometry is bad" from "this machine was busy", and the second is not a property of the
geometry at all.

This directory holds the ground truth the fix was built on.

## The probe

`probe_1067.mm` replicates `runBooleanEx` (`Sources/OCCTBridge/src/OCCTBridge_Modeling.mm`) exactly,
then prints the three facts the bridge has at the moment it decides to return `nullptr`: `IsDone()`,
the watchdog's own `tripped()` flag, and elapsed wall clock. It also asks OCCT itself, via
`HasError(STANDARD_TYPE(BOPAlgo_AlertUserBreak))`, so the watchdog's answer has a second,
independent construction to agree with.

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1067-boolean-timeout-outcome/probe_1067.mm -o /tmp/probe_1067
/tmp/probe_1067
```

## What it measured

Against the pinned `v3.0.0` kernel (`OCCT.xcframework.zip` sha256
`77df5a0a...e52ef2`), on the issue's own fixture: 36 tool copies cut from a cylinder.

```
=== 36-tool cut, the issue's fixture ===
cut, timeout 0 (unbounded)                 IsDone=true  tripped=false userBreak=false hasErr=false 0.2974s
cut, timeout 120 (the default)             IsDone=true  tripped=false userBreak=false hasErr=false 0.4840s  polls=13131
cut, timeout 1e-9 (deadline already past)  IsDone=false tripped=true  userBreak=true  hasErr=true  0.0008s  polls=3
cut, timeout 0.001                         IsDone=false tripped=true  userBreak=true  hasErr=true  0.0011s  polls=222

=== trivial cut: does a small boolean poll at all? ===
small cut, timeout 0 (unbounded)           IsDone=true  tripped=false userBreak=false hasErr=false 0.0020s
small cut, timeout 1e-9                    IsDone=false tripped=true  userBreak=true  hasErr=true  0.0001s  polls=4
small fuse, timeout 1e-9                   IsDone=false tripped=true  userBreak=true  hasErr=true  0.0000s  polls=4
small common, timeout 1e-9                 IsDone=false tripped=true  userBreak=true  hasErr=true  0.0000s  polls=4

=== genuine failure: a null operand, no watchdog at all ===
cut by null, timeout 0 (unbounded)         IsDone=false tripped=false userBreak=false hasErr=true  polls=0
cut by null, timeout 120                   IsDone=false tripped=false userBreak=false hasErr=true  polls=0
fuse with null, timeout 120                IsDone=false tripped=false userBreak=false hasErr=true  polls=0
common with null, timeout 120              IsDone=false tripped=false userBreak=false hasErr=true  polls=0

=== stability of the tiny-timeout trip, 200 repeats ===
tripped 200/200, IsDone 0/200, userBreak 200/200, tripped==userBreak 200/200
```

Four things follow, and each of them is load-bearing for the fix.

**1. The issue's premise holds.** A timeout leaves `IsDone() == false`, and so does a genuine
failure. `runBooleanEx` returned `nullptr` for both, and the Swift methods turned both into `nil`.

**2. The bridge already computed the distinction and threw it away.** `OCCTBoolTimeoutBreaker`
has had a `bool tripped()` accessor since #206, set from `UserBreak()`. `OCCTShapeSelfIntersectsBounded`
in the same file reads it to return its `-1` (indeterminate); `runBooleanEx` did not, and its comment
said so outright: *"IsDone() is false both on genuine failure and when the watchdog interrupted the
build, either way there is no usable result."* So the fix needed no new OCCT call, only for the
existing flag to reach the caller.

**3. OCCT agrees with the flag.** `tripped()` and OCCT's own `BOPAlgo_AlertUserBreak` matched on
every labelled row and on 200/200 repeats. The two are computed independently (ours from the
`Message_ProgressIndicator` subclass, OCCT's from its own alert list), so this is corroboration
rather than a restatement. `tripped()` was kept as the signal because it is already there and needs
no extra header.

**4. Both halves of the distinction can be driven deterministically, with no wall-clock wait.**

- `timeout: 1e-9` puts the deadline in the past *before* `Build()` is entered, so the first
  `UserBreak()` poll trips. This is not a race against machine speed: a faster machine reaches the
  first poll sooner, but the deadline is already behind it either way. The first poll arrives at
  poll 3 or 4, within 0.0002s. `Issue206BooleanTimeout` already uses the same technique at `1e-7`.
- A null operand is refused with **zero** polls even at a 120s timeout, so the watchdog structurally
  cannot have fired and the outcome must be `failed`. This is what makes the negative case, "the
  watchdog reported" rather than "a watchdog existed", testable rather than assumed.

## What was not measured

The `catch (...)` path. `Build(range)` did not throw on a break in any of the 212 runs above
(`threw=false` throughout), so nothing in the pinned kernel reaches the exception path with a tripped
breaker. The write there is therefore not exercised by any fixture, and is proven instead by
injection: forcing a `throw` immediately after a tripped `Build(range)` keeps the outcome at
`timedOut`, and removing the `catch`-path write under that same injection turns it into `failed`.
The sibling `OCCTShapeSelfIntersectsBounded` does reach its own `catch` on a break, because patch
`0010` (#319) makes `Intf_Interference`'s breaker abort by throwing, so keeping the two symmetric
costs two lines and closes a path that is live one function away.
