// #766 / #1989: kernel-parity probe for the unbent SheetMetal fixtures in
// Tests/OCCTMiscTests/OCCTMiscTests.swift (SheetMetalTests).
//
// SheetMetal.Builder extrudes each flange's lifted profile along its normal by the thickness
// (Shape.extrude: a planar face from the closed polygon, then BRepPrimAPI_MakePrism) and fuses the
// bodies (Shape.union: BRepAlgoAPI_Fuse). For the fixtures with no bend that is the whole
// construction, so the kernel can build the same solids directly and report their volumes. The
// bent fixtures add a Swift-chosen fillet edge or a Swift-built bend-material prism; those have no
// single kernel counterpart and their test volumes are regression pins, not parity values.
//
// Build (from the repo root, against the SwiftPM-resolved pinned kernel):
//   X=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$X/Headers" -L"$X" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/766-misc-sheetmetal/probe.mm -o /tmp/probe_766_sheetmetal

#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <GProp_GProps.hxx>
#include <cstdio>

// A flange: origin o, in-plane axes uAxis/vAxis, normal n, rectangle w x h, extruded by t.
static TopoDS_Shape flange(gp_Pnt o, gp_Vec uAxis, gp_Vec vAxis, gp_Vec n, double w, double h, double t)
{
  auto at = [&](double u, double v) { return o.Translated(uAxis * u + vAxis * v); };
  BRepBuilderAPI_MakePolygon poly(at(0, 0), at(w, 0), at(w, h), at(0, h), Standard_True);
  TopoDS_Face                face = BRepBuilderAPI_MakeFace(poly.Wire()).Face();
  return BRepPrimAPI_MakePrism(face, n * t).Shape();
}

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  return g.Mass();
}

int main()
{
  const gp_Vec X(1, 0, 0), Y(0, 1, 0), Z(0, 0, 1);
  std::printf("singleFlange (50 x 25, t 3): %.12g\n",
              volume(flange(gp_Pnt(0, 0, 0), X, Y, Z, 50, 25, 3)));
  std::printf("singleFlangeVolumeSanity (40 x 20, t 2.5): %.12g\n",
              volume(flange(gp_Pnt(0, 0, 0), X, Y, Z, 40, 20, 2.5)));
  {
    TopoDS_Shape a = flange(gp_Pnt(0, 0, 0), X, Y, Z, 20, 10, 2);
    TopoDS_Shape b = flange(gp_Pnt(0, 10, 0), X, Z, Y, 10, 10, 2);
    std::printf("flangesOnlyNoBends (fused): %.12g\n", volume(BRepAlgoAPI_Fuse(a, b).Shape()));
  }
  {
    TopoDS_Shape base    = flange(gp_Pnt(0, 0, 0), X, Y, Z, 65, 28, 3);
    TopoDS_Shape upright = flange(gp_Pnt(0, 28, 0), X, Z, Y, 65, 40, 3);
    std::printf("fusedTwoFlangeVolume (fused): %.12g\n",
                volume(BRepAlgoAPI_Fuse(base, upright).Shape()));
  }
  return 0;
}
