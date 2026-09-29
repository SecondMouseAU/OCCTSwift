// #2827 ground truth: BRepGProp_Gauss::convert discards the by-plane mass.
//
// Three fixtures, three questions per fixture:
//
//   1. BRepGProp_Vinert BY POINT, summed per face, with the face's BRepGProp_Domain loaded, which
//      is what #2806 gave OCCTBRepGPropVinertPlane's sibling. This is the control: it equals the
//      shape's volume.
//   2. BRepGProp_Vinert BY PLANE, the same loop through the gp_Pln overload. This is the defect.
//   3. BRepGProp::VolumePropertiesGK(S, Props, thePln, ...), OCCT's own by-plane public entry
//      point, which goes through BRepGProp_VinertGK and math_KronrodSingleIntegration rather than
//      BRepGProp_Gauss. This is the independent construction that says what (2) should report.
//
// Compile (from a checkout with Libraries/OCCT.xcframework, or point -I/-L at the SwiftPM artifact
// under .build/artifacts/<pkg>/OCCT/OCCT.xcframework):
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2827/probe.mm -o /tmp/occt_probe_2827

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepGProp.hxx>
#include <BRepGProp_Domain.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepGProp_Vinert.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Ax2.hxx>
#include <gp_Pln.hxx>
#include <gp_Trsf.hxx>
#include <BRepBuilderAPI_Transform.hxx>

#include <cstdio>
#include <string>

// The same domain load OCCTBRepGPropVinert/VinertPlane do: a face with wires is integrated over the
// region they trim, a face with none over its natural UV bounds.
static bool loadDomain(const TopoDS_Face& f, BRepGProp_Domain& d)
{
  TopExp_Explorer ex(f, TopAbs_EDGE);
  if (!ex.More())
    return false;
  d.Init(f);
  return true;
}

static void report(const char* name, const TopoDS_Shape& s, const gp_Pln& pln, const char* plnName)
{
  double byPoint = 0.0, byPlane = 0.0;
  int    nFaces = 0;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    const TopoDS_Face& f = TopoDS::Face(ex.Current());
    ++nFaces;
    {
      BRepGProp_Face   gf(f);
      BRepGProp_Domain d;
      BRepGProp_Vinert v;
      v.SetLocation(gp_Pnt(0, 0, 0));
      if (loadDomain(f, d))
        v.Perform(gf, d);
      else
        v.Perform(gf);
      byPoint += v.Mass();
    }
    {
      BRepGProp_Face   gf(f);
      BRepGProp_Domain d;
      BRepGProp_Vinert v;
      v.SetLocation(gp_Pnt(0, 0, 0));
      if (loadDomain(f, d))
        v.Perform(gf, d, pln);
      else
        v.Perform(gf, pln);
      byPlane += v.Mass();
    }
  }

  GProp_GProps gk;
  double       gkErr = BRepGProp::VolumePropertiesGK(s, gk, pln, 1.0e-6, true, true, false);

  std::printf("%-34s %-22s faces=%2d\n", name, plnName, nFaces);
  std::printf("    Vinert by point, summed        %.16g\n", byPoint);
  std::printf("    Vinert by plane, summed        %.16g   <-- #2827\n", byPlane);
  std::printf("    VolumePropertiesGK by plane    %.16g   (error reached %.3g)\n",
              gk.Mass(),
              gkErr);
}

int main()
{
  // A 10-cube at the origin corner, so no face is coplanar with z = 0 by accident except the base.
  TopoDS_Shape cube = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();

  // A 20x20x2 plate with a radius-3 hole through it.
  TopoDS_Shape plate = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 20, 20, 2).Shape();
  TopoDS_Shape drill =
    BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(10, 10, -5), gp_Dir(0, 0, 1)), 3, 10).Shape();
  TopoDS_Shape holed = BRepAlgoAPI_Cut(plate, drill).Shape();

  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();

  const gp_Pln z0(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  const gp_Pln far(gp_Pnt(0, 0, -100), gp_Dir(0, 0, 1));
  const gp_Pln oblique(gp_Pnt(1, 2, 3), gp_Dir(1, 2, 3));

  report("10-cube", cube, z0, "plane z = 0");
  report("10-cube", cube, far, "plane z = -100");
  report("10-cube", cube, oblique, "oblique plane");
  report("20x20x2 plate, radius-3 hole", holed, z0, "plane z = 0");
  report("cylinder r = 5 h = 10", cyl, z0, "plane z = 0");

  // And the shape-level control: the by-point volume the sums above are compared against.
  GProp_GProps v;
  BRepGProp::VolumeProperties(cube, v, true);
  std::printf("\ncontrol BRepGProp::VolumeProperties  cube  %.16g\n", v.Mass());
  GProp_GProps v2;
  BRepGProp::VolumeProperties(holed, v2, true);
  std::printf("control BRepGProp::VolumeProperties  plate %.16g\n", v2.Mass());
  GProp_GProps v3;
  BRepGProp::VolumeProperties(cyl, v3, true);
  std::printf("control BRepGProp::VolumeProperties  cyl   %.16g\n", v3.Mass());
  return 0;
}
