// #766 / #1989: kernel-parity probe for Tests/OCCTMiscTests/Issue1009Matrix12GroupedTests.swift.
//
// Each test's fixture, built with the same OCCT calls the bridge makes: a box centred on the
// origin (OCCTShapeCreateBox), a corner box (OCCTShapeCreateBoxAt), gp_Trsf::SetValues in the
// GROUPED permutation (occtTrsfFromMatrix12Grouped), BRepBuilderAPI_Transform (OCCTShapeTransformed),
// BRepBndLib::Add with triangulation (OCCTShapeBoundingBox), Geom_Curve::ParametricTransformation
// (OCCTCurve3DParametricTransformation), and TopoDS_Shape::Moved(TopLoc_Location) for the
// placement an XCAF component carries (OCCTDocumentAddComponentMatrix). The earlier #1009 probe in
// Scripts/repro/1009-matrix12-grouped/ proves the three readers identical; this one produces the
// values each Swift test asserts.
//
// Build (from the repo root, against the SwiftPM-resolved pinned kernel):
//   X=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$X/Headers" -L"$X" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/766-issue1009-matrix12-grouped/probe.mm -o /tmp/probe_766_1009

#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Bnd_Box.hxx>
#include <Geom_Line.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Trsf.hxx>
#include <cmath>
#include <cstdio>

static gp_Trsf grouped(const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[9], m[3], m[4], m[5], m[10], m[6], m[7], m[8], m[11]);
  return t;
}

static gp_Trsf interleaved(const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11]);
  return t;
}

static void bbox(const char* theLabel, const TopoDS_Shape& theShape)
{
  Bnd_Box aBox;
  BRepBndLib::Add(theShape, aBox, Standard_True);
  double x0, y0, z0, x1, y1, z1;
  aBox.Get(x0, y0, z0, x1, y1, z1);
  std::printf("%s: min (%.12g, %.12g, %.12g) max (%.12g, %.12g, %.12g)\n",
              theLabel, x0, y0, z0, x1, y1, z1);
}

int main()
{
  const double translate567[12] = {1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 6, 7};
  const double c = std::cos(M_PI / 6), s = std::sin(M_PI / 6);
  const double rotated[12] = {c, -s, 0, s, c, 0, 0, 0, 1, 5, 6, 7};

  // Shape.box(width: 10, height: 10, depth: 10): centred on the origin.
  TopoDS_Shape aBox = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();

  std::printf("== shapeTransformedAppliesTheGroupedTranslation ==\n");
  bbox("box before", aBox);
  bbox("box after GROUPED translate567",
       BRepBuilderAPI_Transform(aBox, grouped(translate567), Standard_True).Shape());
  bbox("box after the same array read INTERLEAVED",
       BRepBuilderAPI_Transform(aBox, interleaved(translate567), Standard_True).Shape());

  std::printf("== groupedAgreesWithItsInterleavedConversion ==\n");
  bbox("rotated via GROUPED reader",
       BRepBuilderAPI_Transform(aBox, grouped(rotated), Standard_True).Shape());
  // grouped.interleaved reshuffles to r00 r01 r02 tx | r10 r11 r12 ty | r20 r21 r22 tz.
  const double asInterleaved[12] = {rotated[0], rotated[1], rotated[2], rotated[9],
                                    rotated[3], rotated[4], rotated[5], rotated[10],
                                    rotated[6], rotated[7], rotated[8], rotated[11]};
  bbox("rotated via INTERLEAVED reader on the reshuffled array",
       BRepBuilderAPI_Transform(aBox, interleaved(asInterleaved), Standard_True).Shape());

  std::printf("== curve3dParametricTransformationReadsTheGroupedLayout ==\n");
  Handle(Geom_Line) aLine = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  const double scale2[12] = {2, 0, 0, 0, 2, 0, 0, 0, 2, 1, 2, 3};
  std::printf("ParametricTransformation GROUPED scale 2 = %.12g\n",
              aLine->ParametricTransformation(grouped(scale2)));
  std::printf("ParametricTransformation GROUPED translate567 = %.12g\n",
              aLine->ParametricTransformation(grouped(translate567)));
  BRepBuilderAPI_MakeEdge anEdge(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0));
  TopoDS_Shape aWire = BRepBuilderAPI_MakeWire(anEdge.Edge()).Wire();
  bbox("wire before", aWire);
  bbox("wire after GROUPED translate567",
       BRepBuilderAPI_Transform(aWire, grouped(translate567), Standard_True).Shape());

  std::printf("== documentAddComponentReadsTheGroupedLayout ==\n");
  bbox("box located by TopLoc_Location(GROUPED translate567)",
       aBox.Moved(TopLoc_Location(grouped(translate567))));

  std::printf("== documentAddComponentAcceptsAReflection ==\n");
  const double mirrorInX[12] = {-1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0};
  // Shape.box(origin: (1, 0, 0), ...): OCCTShapeCreateBoxAt, a corner box.
  TopoDS_Shape aCorner = BRepPrimAPI_MakeBox(gp_Pnt(1, 0, 0), 10, 10, 10).Shape();
  gp_Trsf aMirror = grouped(mirrorInX);
  std::printf("SetValues(mirror in X) accepted: IsNegative=%d ScaleFactor=%.12g\n",
              aMirror.IsNegative() ? 1 : 0, aMirror.ScaleFactor());
  bbox("corner box located by TopLoc_Location(GROUPED mirror in X)",
       aCorner.Moved(TopLoc_Location(aMirror)));
  return 0;
}
