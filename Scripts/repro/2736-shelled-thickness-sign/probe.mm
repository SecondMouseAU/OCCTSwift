// Ground-truth probe for #2736: confirm BRepOffsetAPI_MakeThickSolid's sign convention
// (does positive Offset shell outward or inward?), and check whether
// MakeThickSolidBySimple (the single-argument OCCTShapeShell path) works at all on a
// closed solid, independent of sign.
//
// Compile (from repo root, against the SwiftPM-resolved pinned xcframework so this
// probe matches the same v4.0.0-kernel.1 asset the package actually builds against):
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I".build/artifacts/agent-a2f58b4a247e7a816/OCCT/OCCT.xcframework/macos-arm64/Headers" \
//     -L".build/artifacts/agent-a2f58b4a247e7a816/OCCT/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2736-shelled-thickness-sign/probe.mm -o /tmp/occt_probe_2736
//   /tmp/occt_probe_2736

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <cstdio>
#include <cmath>

static double volumeOf(const TopoDS_Shape& shape)
{
  GProp_GProps props;
  BRepGProp::VolumeProperties(shape, props);
  return props.Mass();
}

// Find the face whose center has the largest Z (the "top" face of an axis-aligned box).
static TopoDS_Face topFaceOf(const TopoDS_Shape& shape)
{
  TopoDS_Face best;
  double      bestZ = -1e18;
  for (TopExp_Explorer exp(shape, TopAbs_FACE); exp.More(); exp.Next())
  {
    TopoDS_Face  f = TopoDS::Face(exp.Current());
    GProp_GProps props;
    BRepGProp::SurfaceProperties(f, props);
    double z = props.CentreOfMass().Z();
    if (z > bestZ)
    {
      bestZ = z;
      best  = f;
    }
  }
  return best;
}

int main()
{
  // === Part 1: MakeThickSolidByJoin sign, on a 20mm cube with the top face open. ===
  // Mirrors the issue's own claim exactly: 20mm cube, top face open, thickness 2.0.
  {
    BRepPrimAPI_MakeBox boxMaker(20.0, 20.0, 20.0);
    TopoDS_Shape        box = boxMaker.Shape();
    printf("box volume: %f\n", volumeOf(box));

    TopoDS_Face          top = topFaceOf(box);
    TopTools_ListOfShape closingFaces;
    closingFaces.Append(top);

    BRepOffsetAPI_MakeThickSolid positiveMaker;
    positiveMaker.MakeThickSolidByJoin(box, closingFaces, 2.0, 1e-6);
    positiveMaker.Build();
    bool posDone = positiveMaker.IsDone();
    double posVol = posDone ? volumeOf(positiveMaker.Shape()) : -1.0;
    printf("MakeThickSolidByJoin(+2.0) IsDone=%d volume=%f\n", posDone, posVol);

    BRepOffsetAPI_MakeThickSolid negativeMaker;
    negativeMaker.MakeThickSolidByJoin(box, closingFaces, -2.0, 1e-6);
    negativeMaker.Build();
    bool negDone = negativeMaker.IsDone();
    double negVol = negDone ? volumeOf(negativeMaker.Shape()) : -1.0;
    printf("MakeThickSolidByJoin(-2.0) IsDone=%d volume=%f\n", negDone, negVol);

    // Expected reference numbers from the issue: outward ~4519.41, inward ~3392 (8000 - 16*16*18).
    printf("expected inward-shell reference volume (8000 - 16*16*18): %f\n",
           8000.0 - 16.0 * 16.0 * 18.0);
  }

  // === Part 2: MakeThickSolidBySimple on a CLOSED solid, both signs. ===
  {
    BRepPrimAPI_MakeBox boxMaker(20.0, 20.0, 20.0);
    TopoDS_Shape        box = boxMaker.Shape();

    BRepOffsetAPI_MakeThickSolid simplePos;
    simplePos.MakeThickSolidBySimple(box, 2.0);
    simplePos.Build();
    bool posDone = simplePos.IsDone();
    printf("MakeThickSolidBySimple(closed solid, +2.0, w/ Build()) IsDone=%d\n", posDone);

    BRepOffsetAPI_MakeThickSolid simpleNeg;
    simpleNeg.MakeThickSolidBySimple(box, -2.0);
    simpleNeg.Build();
    bool negDone = simpleNeg.IsDone();
    printf("MakeThickSolidBySimple(closed solid, -2.0, w/ Build()) IsDone=%d\n", negDone);
  }

  // === Part 3: MakeThickSolidBySimple on an OPEN face, both signs. ===
  {
    BRepPrimAPI_MakeBox boxMaker(20.0, 20.0, 20.0);
    TopoDS_Shape        box = boxMaker.Shape();
    TopoDS_Face         top = topFaceOf(box);

    BRepOffsetAPI_MakeThickSolid simplePos;
    simplePos.MakeThickSolidBySimple(top, 2.0);
    bool posDone = simplePos.IsDone();
    double posVol = posDone ? volumeOf(simplePos.Shape()) : -1.0;
    printf("MakeThickSolidBySimple(face, +2.0) IsDone=%d volume=%f\n", posDone, posVol);

    BRepOffsetAPI_MakeThickSolid simpleNeg;
    simpleNeg.MakeThickSolidBySimple(top, -2.0);
    bool negDone = simpleNeg.IsDone();
    double negVol = negDone ? volumeOf(simpleNeg.Shape()) : -1.0;
    printf("MakeThickSolidBySimple(face, -2.0) IsDone=%d volume=%f\n", negDone, negVol);
  }

  // === Part 4: for the record, does MakeThickSolidByJoin with an EMPTY closing-face
  // list work on a closed solid? (Informational only, for the follow-up issue: this
  // is the algorithm the two-argument overload already uses successfully.)
  {
    BRepPrimAPI_MakeBox boxMaker(20.0, 20.0, 20.0);
    TopoDS_Shape        box = boxMaker.Shape();
    TopTools_ListOfShape empty;

    BRepOffsetAPI_MakeThickSolid maker;
    maker.MakeThickSolidByJoin(box, empty, 2.0, 1e-6);
    maker.Build();
    bool done = maker.IsDone();
    double vol = done ? volumeOf(maker.Shape()) : -1.0;
    printf("MakeThickSolidByJoin(closed solid, empty closing faces, +2.0) IsDone=%d volume=%f\n",
           done, vol);
  }

  return 0;
}
