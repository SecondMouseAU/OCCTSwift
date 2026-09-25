// Epic #766 evidence correction for PR #2687 (Tests/OCCTModelingTests/BooleanRegistryTests.swift),
// record unionNamedRevolves only. probe.mm printed the volumes at %.10g under keys the bridge side
// did not share. This probe repeats the same two revolves and their union and prints every double
// at %.17g and every flag as true/false. The profiles are FeatureSpec.Revolve's triangles
// (x0,0), (x1,0), (x1,5) in the XZ plane, revolved 2*pi about the z axis, fused with BRepAlgoAPI_Fuse.
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
  printf("unionNamedRevolves: revolveA=%.17g revolveB=%.17g unionDone=%s unionVolume=%.17g\n", volume(a),
         volume(b), u.IsDone() ? "true" : "false", volume(u.Shape()));
  return 0;
}
