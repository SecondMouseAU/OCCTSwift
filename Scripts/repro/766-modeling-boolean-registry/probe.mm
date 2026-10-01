// Epic #766, Tests/OCCTModelingTests/BooleanRegistryTests.swift: kernel parity.
// unionNamedRevolves: FeatureReconstructor lifts each 2D profile to (x, 0, y), revolves it 360
// degrees about Z (OCCTShapeCreateRevolution, BRepPrimAPI_MakeRevol on the planar face) and the
// named union runs BRepAlgoAPI_Fuse (OCCTBooleanUnionWithHistory). missingLeftRef never reaches
// the kernel: it is a registry lookup in Swift, recorded N/A.
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <GProp_GProps.hxx>
#include <cstdio>
#include <gp_Ax1.hxx>

static TopoDS_Shape revolve(double x0, double x1)
{
  BRepBuilderAPI_MakePolygon poly(gp_Pnt(x0, 0, 0), gp_Pnt(x1, 0, 0), gp_Pnt(x1, 0, 5), Standard_True);
  TopoDS_Face                face = BRepBuilderAPI_MakeFace(poly.Wire(), Standard_True);
  return BRepPrimAPI_MakeRevol(face, gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 2 * M_PI).Shape();
}

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

int main()
{
  TopoDS_Shape     a = revolve(0, 5), b = revolve(10, 15);
  BRepAlgoAPI_Fuse u(a, b);
  printf("unionNamedRevolves: a=%.10g b=%.10g union done=%d volume=%.10g\n", volume(a), volume(b), u.IsDone(),
         volume(u.Shape()));
  return 0;
}
