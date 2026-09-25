// #766 kernel parity for Tests/OCCTAnalysisTests/BRepGPropSinertTests.swift.
// Face.faces() -> OCCTShapeGetFaces (TopExp::MapShapes order); Face.surfaceInertia ->
// OCCTBRepGPropSinert; Face.surfaceInertia(epsilon:) -> OCCTBRepGPropSinertAdaptive
// (OCCTBridge_Properties.mm).
#include <BRepGProp_Domain.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepGProp_Sinert.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  // Shape.box(width:10,height:10,depth:10) is centred on the origin (OCCTShapeCreateBox).
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape boxFaces;
  TopExp::MapShapes(box, TopAbs_FACE, boxFaces);
  {
    BRepGProp_Face   gf(TopoDS::Face(boxFaces(1)));
    BRepGProp_Sinert s;
    s.SetLocation(gp_Pnt(0, 0, 0));
    s.Perform(gf);
    gp_Pnt cm = s.CentreOfMass();
    printf("faceSurfaceInertia box faces()[0]: Mass=%.17g CentreOfMass=(%.17g, %.17g, %.17g)\n",
           s.Mass(), cm.X(), cm.Y(), cm.Z());
  }

  TopoDS_Shape               sphere = BRepPrimAPI_MakeSphere(10).Shape();
  TopTools_IndexedMapOfShape sphFaces;
  TopExp::MapShapes(sphere, TopAbs_FACE, sphFaces);
  printf("sphere r=10 face count=%d (4*pi*r^2 = %.17g)\n", sphFaces.Extent(), 4 * M_PI * 100);
  {
    BRepGProp_Face   gf(TopoDS::Face(sphFaces(1)));
    BRepGProp_Sinert s;
    s.SetLocation(gp_Pnt(0, 0, 0));
    double err = s.Perform(gf, 1e-6);
    gp_Pnt cm  = s.CentreOfMass();
    printf("adaptiveSurfaceInertia sphere faces()[0], eps=1e-6: Mass=%.17g error=%.17g "
           "CentreOfMass=(%.17g, %.17g, %.17g)\n",
           s.Mass(), err, cm.X(), cm.Y(), cm.Z());
  }
  {
    BRepGProp_Face   gf(TopoDS::Face(sphFaces(1)));
    BRepGProp_Sinert s;
    s.SetLocation(gp_Pnt(0, 0, 0));
    s.Perform(gf);
    printf("  non-adaptive Perform on the same face, for comparison: Mass=%.17g\n", s.Mass());
  }
  {
    // Perform(Face&, double) hands Gauss an empty, default-constructed BRepGProp_Domain
    // (BRepGProp_Sinert.cxx). The same call with the face's own domain, for comparison.
    BRepGProp_Face   gf(TopoDS::Face(sphFaces(1)));
    BRepGProp_Domain dom(TopoDS::Face(sphFaces(1)));
    BRepGProp_Sinert s;
    s.SetLocation(gp_Pnt(0, 0, 0));
    double err = s.Perform(gf, dom, 1e-6);
    printf("  adaptive Perform(face, BRepGProp_Domain(face), 1e-6), for comparison: Mass=%.17g "
           "error=%.17g\n",
           s.Mass(), err);
  }
  {
    BRepGProp_Face   gf(TopoDS::Face(boxFaces(1)));
    BRepGProp_Sinert s;
    s.SetLocation(gp_Pnt(0, 0, 0));
    double err = s.Perform(gf, 1e-6);
    printf("  adaptive Perform(face, 1e-6) on box faces()[0] (planar, area 100): Mass=%.17g "
           "error=%.17g\n",
           s.Mass(), err);
  }
  return 0;
}
