//
// occt_1190_test.mm
// Ground-truth regression test for #1190.
//
// OCCTDrawingGetEdges (Sources/OCCTBridge/src/OCCTBridge_HLR.mm) used to reimplement
// `if (!x.IsNull()) { builder.Add(compound, x); }` eight times, once per TopoDS_Shape field of
// `struct OCCTDrawing` its three switch cases might contribute (three for .visible, three for
// .hidden, two more re-reading visibleOutline/hiddenOutline for .outline). The fix collapses all
// eight to a single `occtAddShapeIfPresent` helper (Sources/OCCTBridge/src/OCCTBridge_Internal.h).
//
// Why this can't be a Swift-level test: `OCCTDrawing`'s six TopoDS_Shape fields are bridge-internal
// (no Swift-visible getter exists or should exist for them), and which fields a REAL HLRBRep
// projection populates is a property of the input geometry, not something a Swift fixture can
// hand-pick. Every existing Swift test (Tests/OCCTDrawingTests/*.swift) can only assert "the
// aggregate Shape? is non-nil" -- #1190's own issue body documents this exact gap ("no test
// isolates a single guard block... coverage is at the 'does calling this edgeType return a
// non-nil compound' granularity only"). A test built that way could not tell a dropped, duplicated,
// or misrouted guard from correct behavior. This test hand-constructs an OCCTDrawing with each of
// the six fields independently null or a distinguishable single-vertex shape, then calls the REAL,
// compiled OCCTDrawingGetEdges (this file is compiled alongside the actual OCCTBridge_HLR.mm, not a
// reimplementation of it) for all three OCCTEdgeType values, and checks the returned compound by
// exact vertex identity, not mere non-nullness, so a single mis-routed or dropped guard is caught.
//
// Build & run: see run.sh in this directory, or:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -I"Sources/OCCTBridge/include" -I"Sources/OCCTBridge/src" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Sources/OCCTBridge/src/OCCTBridge_HLR.mm \
//     Scripts/repro/1190-drawinggetedges-guard-helper/occt_1190_test.mm \
//     -o /tmp/occt_1190_test
//   /tmp/occt_1190_test
//
// Prove-the-test-fails (okf/policies/prove-the-test-fails.md): run.sh's transcript is committed as
// fixed.txt (subject intact, all checks pass) and broken.txt (occtAddShapeIfPresent's guard
// disabled, i.e. always adds regardless of IsNull(), run against this same test). See README.md.

#include "OCCTBridge.h"
#include "OCCTBridge_Internal.h"

#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRep_Tool.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <cstdio>

static int gFailures = 0;

#define CHECK(cond, msg)                                                                         \
  do                                                                                               \
  {                                                                                                 \
    if (!(cond))                                                                                    \
    {                                                                                                \
      std::fprintf(stderr, "FAIL: %s (%s:%d)\n", msg, __FILE__, __LINE__);                            \
      gFailures++;                                                                                    \
    }                                                                                                  \
    else                                                                                               \
    {                                                                                                    \
      std::fprintf(stdout, "ok:   %s\n", msg);                                                            \
    }                                                                                                      \
  } while (0)

static TopoDS_Shape vertexAt(double x, double y, double z)
{
  return BRepBuilderAPI_MakeVertex(gp_Pnt(x, y, z)).Shape();
}

// Count how many vertices of `shape` sit at (x, y, z). Every fixture vertex below is at a unique
// coordinate, so this identifies WHICH source field's shape made it into a result compound.
static int vertexCountAt(const TopoDS_Shape& shape, double x, double y, double z)
{
  if (shape.IsNull())
    return 0;
  int count = 0;
  for (TopExp_Explorer exp(shape, TopAbs_VERTEX); exp.More(); exp.Next())
  {
    gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(exp.Current()));
    if (std::abs(p.X() - x) < 1e-9 && std::abs(p.Y() - y) < 1e-9 && std::abs(p.Z() - z) < 1e-9)
      count++;
  }
  return count;
}

static int totalVertexCount(const TopoDS_Shape& shape)
{
  if (shape.IsNull())
    return 0;
  int count = 0;
  for (TopExp_Explorer exp(shape, TopAbs_VERTEX); exp.More(); exp.Next())
    count++;
  return count;
}

int main()
{
  // --- Part 1: the shared helper itself, in isolation -------------------------------------

  {
    BRep_Builder    builder;
    TopoDS_Compound compound;
    builder.MakeCompound(compound);

    occtAddShapeIfPresent(builder, compound, vertexAt(10, 0, 0));
    CHECK(totalVertexCount(compound) == 1, "helper: adds a non-null shape");
    CHECK(vertexCountAt(compound, 10, 0, 0) == 1, "helper: added shape is the one supplied");

    occtAddShapeIfPresent(builder, compound, TopoDS_Shape());
    CHECK(totalVertexCount(compound) == 1, "helper: a null shape is a no-op, not added");
  }

  // --- Part 2: all eight OCCTDrawingGetEdges guard-then-add call sites --------------------
  //
  // Six distinguishable fields: four present (unique vertex each), two deliberately left null.
  // visibleOutline and hiddenOutline are each read by TWO call sites (their own case arm, and
  // .outline's), so exercising all three OCCTEdgeType values below reaches exactly eight guard
  // sites, matching #1190's own count.

  OCCTDrawing drawing; // default-constructed TopoDS_Shape fields are already null
  drawing.visibleSharp = vertexAt(1, 0, 0);
  // drawing.visibleSmooth left null (deliberately)
  drawing.visibleOutline = vertexAt(3, 0, 0);
  // drawing.hiddenSharp left null (deliberately)
  drawing.hiddenSmooth  = vertexAt(5, 0, 0);
  drawing.hiddenOutline = vertexAt(6, 0, 0);

  {
    OCCTShapeRef result = OCCTDrawingGetEdges(&drawing, OCCTEdgeTypeVisible);
    CHECK(result != nullptr, "visible: non-null result");
    if (result)
    {
      CHECK(vertexCountAt(result->shape, 1, 0, 0) == 1, "visible: includes visibleSharp");
      CHECK(vertexCountAt(result->shape, 3, 0, 0) == 1, "visible: includes visibleOutline");
      CHECK(totalVertexCount(result->shape) == 2,
            "visible: excludes visibleSmooth (null) -- exactly 2 vertices");
    }
  }

  {
    OCCTShapeRef result = OCCTDrawingGetEdges(&drawing, OCCTEdgeTypeHidden);
    CHECK(result != nullptr, "hidden: non-null result");
    if (result)
    {
      CHECK(vertexCountAt(result->shape, 5, 0, 0) == 1, "hidden: includes hiddenSmooth");
      CHECK(vertexCountAt(result->shape, 6, 0, 0) == 1, "hidden: includes hiddenOutline");
      CHECK(totalVertexCount(result->shape) == 2,
            "hidden: excludes hiddenSharp (null) -- exactly 2 vertices");
    }
  }

  {
    OCCTShapeRef result = OCCTDrawingGetEdges(&drawing, OCCTEdgeTypeOutline);
    CHECK(result != nullptr, "outline: non-null result");
    if (result)
    {
      CHECK(vertexCountAt(result->shape, 3, 0, 0) == 1, "outline: includes visibleOutline");
      CHECK(vertexCountAt(result->shape, 6, 0, 0) == 1, "outline: includes hiddenOutline");
      CHECK(totalVertexCount(result->shape) == 2, "outline: exactly the two outline fields");
    }
  }

  // --- Part 3: the existing null-drawing guard is untouched by this refactor --------------
  CHECK(OCCTDrawingGetEdges(nullptr, OCCTEdgeTypeVisible) == nullptr, "null drawing: refused");

  std::fprintf(stdout, "\n%s (%d failure%s)\n", gFailures == 0 ? "ALL PASS" : "SOME FAILED",
               gFailures, gFailures == 1 ? "" : "s");
  return gFailures == 0 ? 0 : 1;
}
