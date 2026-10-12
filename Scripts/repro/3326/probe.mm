// #3326: BRepGProp_Vinert(face, gp_Pln, location) on a 10-cube centred on the origin.
// The #2660 v5 transcript recorded vinertPlaneZ=0 for all six faces; the pinned kernel prints 500
// for the two faces normal to z. This probe is the #766 probe's Vinert section, widened to print
// the area, the face's z, and the closed form, so a reader can see which kernel computes what.
//
//   Closed form (planar face): mass = (n . nFace) * area * (n . areaCentroid - d), plane n.p = d.
//   Plane z = 0 (d = 0): the z = +5 face and the z = -5 face each bound a 10 x 10 x 5 column, so
//   |mass| = 100 * 5 = 500; the four faces parallel to n have n . nFace = 0 and contribute 0.
//
// Compile (SLICE is the xcframework's macos-arm64 directory under test):
//   clang++ -std=c++17 -ObjC++ -w -I"$SLICE/Headers" -L"$SLICE" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ Scripts/repro/3326/probe.mm -o probe
#include <BRepAdaptor_Surface.hxx>
#include <BRepGProp.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepGProp_Vinert.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape b = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(b, TopAbs_FACE, faces);
  GProp_GProps vol;
  BRepGProp::VolumeProperties(b, vol);
  printf("Shape volume (BRepGProp::VolumeProperties): %.17g\n", vol.Mass());
  const double planeZ[] = {0.0, -10.0};
  for (double d : planeZ)
  {
    gp_Pln pln(gp_Pnt(0, 0, d), gp_Dir(0, 0, 1));
    double sum = 0;
    printf("plane z = %g\n", d);
    for (int i = 1; i <= faces.Extent(); ++i)
    {
      const TopoDS_Face& f = TopoDS::Face(faces(i));
      BRepGProp_Face     g(f);
      BRepGProp_Vinert   byPoint;
      byPoint.SetLocation(gp_Pnt(0, 0, 0));
      byPoint.Perform(g);
      BRepGProp_Vinert byPlane(g, pln, gp_Pnt(0, 0, 0));
      GProp_GProps     s;
      BRepGProp::SurfaceProperties(f, s);
      printf("  face %d: area=%.6g faceZ(centroid)=%.6g vinert=%.17g vinertPlane=%.17g\n", i - 1,
             s.Mass(), s.CentreOfMass().Z(), byPoint.Mass(), byPlane.Mass());
      sum += byPlane.Mass();
    }
    printf("  by-plane sum over the six faces = %.17g\n", sum);
  }
  return 0;
}
