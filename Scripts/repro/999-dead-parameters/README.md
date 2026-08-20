# #999 dead-parameter probes

Ground-truth C++ probes compiled against the pinned 8.0.1 kernel, one per adjudication that needed
a measurement rather than a reading of the headers. Build each with the recipe in `CLAUDE.md`:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/999-dead-parameters/<probe>.mm -o /tmp/<probe>
/tmp/<probe>
```

## `hlr_perspective.mm`

Does `HLRAlgo_Projector`'s perspective constructor change the projected geometry, and does it do so
for both HLR algorithms? Decides whether `OCCTDrawingCreate` and `OCCTDrawingCreatePoly` should wire
`projectionType` up or drop it.

Fixture: a 100x50x30 box placed to match `Shape.box(width:height:depth:)`, which centres on the
origin, viewed down +Z. Its near face therefore sits at z = +15, and a perspective projection from
focal distance f should scale it by f / (f - 15). The centring is measured rather than assumed:
`Issue999ProjectionTypeTests` builds the box through the Swift factory and gets exactly f / (f - 15)
at four focal distances, which no other placement in Z would produce.

```
ortho     Perspective()=0
exact ortho                  edges=4  bbox=[-50.000000 -25.000000 ...]..[50.000000 25.000000 ...]
            poly projector readback Perspective()=0
poly  ortho                  edges=4  bbox=[-50.000000 -25.000000 ...]..[50.000000 25.000000 ...]
persp f=20.0     Perspective()=1  Focus()=20.000000
exact persp f=20             edges=4  bbox=[-200.000000 -100.000000 ...]..[200.000000 100.000000 ...]
            poly projector readback Perspective()=1
poly  persp f=20             edges=4  bbox=[-50.000000 -25.000000 ...]..[50.000000 25.000000 ...]
persp f=50.0     Perspective()=1  Focus()=50.000000
exact persp f=50             edges=4  bbox=[-71.428572 -35.714286 ...]..[71.428572 35.714286 ...]
poly  persp f=50             edges=4  bbox=[-50.000000 -25.000000 ...]..[50.000000 25.000000 ...]
persp f=200.0    Perspective()=1  Focus()=200.000000
exact persp f=200            edges=4  bbox=[-54.054054 -27.027027 ...]..[54.054054 27.027027 ...]
poly  persp f=200            edges=4  bbox=[-50.000000 -25.000000 ...]..[50.000000 25.000000 ...]
persp f=1000.0   Perspective()=1  Focus()=1000.000000
exact persp f=1000           edges=4  bbox=[-50.761421 -25.380711 ...]..[50.761421 25.380711 ...]
poly  persp f=1000           edges=4  bbox=[-50.000000 -25.000000 ...]..[50.000000 25.000000 ...]
```

Two results, and the second is the one that needed measuring rather than assuming.

**`HLRBRep_Algo` honours perspective exactly.** 20/(20-15) = 4, 50/35 = 1.428571, 200/185 = 1.081081,
1000/985 = 1.015228, each matching the measured half-width to every printed digit, and converging on
the orthographic answer as f grows. So `OCCTDrawingCreate` has a real counterpart for
`projectionType`, and it needs the focal distance the perspective constructor takes.

**`HLRBRep_PolyAlgo` ignores it.** The projector is read back off the algorithm after `Projector()`
to prove the setter kept the flag: `Projector().Perspective()` is 1, and the output is still
byte-identical to the orthographic one at every focal distance tried, including f = 20 where the
exact algorithm diverges fourfold. The parameter has nothing to drive there, so it is removed rather
than faked. The pre-existing header comment on `OCCTDrawingCreatePoly` ("perspective not yet
supported for poly") already said so; nothing had checked it against this kernel.

The topology is identical across every row (`edges=4`), which is why the tests that pin this are
written against coordinates. A structural assertion cannot tell the two projections apart.

## `hlr_focus_domain.mm`

What does `HLRAlgo_Projector` do with a focal distance that is zero, negative, or short enough to
put the eye inside the shape? Decides what `OCCTDrawingCreate` has to reject before handing a
caller-supplied focus to OCCT.

```
focus=-100           edges=4 bbox x=[-58.823530 58.823530] y=[-29.411765 29.411765]
focus=0              VCompound NULL
focus=1e-12          VCompound NULL
focus=5              VCompound NULL
focus=15             VCompound NULL
focus=15             VCompound NULL     (15.0000001, printed by %g)
focus=30             edges=4 bbox x=[-100.000000 100.000000] y=[-50.000000 50.000000]
```

Nothing throws and nothing crashes. A non-positive focal distance is not refused by OCCT: zero gives
an empty result and a negative one gives a real projection at a different scale (100/85 = 1.176471),
neither of which reads as failure at the call site. That is why the bridge guards `focus > 0`
itself, written as `!(focus > 0)` so NaN is rejected too. A focal distance shorter than the shape's
own extent along the view direction (5, 15) yields an empty visible compound, which is a legitimate
geometric outcome rather than an input error, so it is left to OCCT.

`Focus()` raises `Standard_NoSuchObject` on a non-perspective projector, which is why the first
probe prints `Perspective()` alone for the orthographic case.
