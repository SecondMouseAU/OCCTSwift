// #766 kernel parity for Tests/OCCTAnalysisTests/CenterOfMassTests.swift.
// Every centre-of-mass entry point the suite reaches (OCCTShapeGetCenterOfMass,
// OCCTShapeGetProperties, OCCTShapeCentroid, OCCTShapeVolumeInertia, OCCTShapeInertiaProperties)
// reads BRepGProp::VolumeProperties(shape, props, OnlyClosed = true) and refuses Mass() == 0
// (occtVolumeMassProperties). This probe makes the same call on the same fixtures, and prints the
// bounding-box centre (the #605 defect) and the OnlyClosed = false integral (the #609 defect) beside it.
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static TopoDS_Shape moved(const TopoDS_Shape& s, double dx, double dy, double dz)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(dx, dy, dz));
  return BRepBuilderAPI_Transform(s, t, true).Shape();
}

static TopoDS_Shape sew(const TopTools_IndexedMapOfShape& faces, int n)
{
  BRepBuilderAPI_Sewing sewing(1e-6);
  for (int i = 1; i <= n; ++i)
    sewing.Add(faces(i));
  sewing.Perform();
  TopoDS_Shape sewn = sewing.SewedShape();
  if (sewn.ShapeType() == TopAbs_SHELL && sewn.Closed())
  {
    BRepBuilderAPI_MakeSolid ms(TopoDS::Shell(sewn));
    if (ms.IsDone())
      return ms.Solid();
  }
  return sewn;
}

static void report(const char* label, const TopoDS_Shape& s)
{
  GProp_GProps closed, open;
  BRepGProp::VolumeProperties(s, closed, true);
  BRepGProp::VolumeProperties(s, open, false);
  printf("%s (type %d): OnlyClosed mass=%.17g", label, (int)s.ShapeType(), closed.Mass());
  if (closed.Mass() != 0)
  {
    gp_Pnt c = closed.CentreOfMass();
    gp_Mat m = closed.MatrixOfInertia();
    printf(" com=(%.17g, %.17g, %.17g) Iyy=%.17g", c.X(), c.Y(), c.Z(), m.Value(2, 2));
  }
  else
    printf(" -> nil");
  printf(" | OnlyClosed=false mass=%.17g", open.Mass());
  Bnd_Box bb;
  BRepBndLib::Add(s, bb);
  if (!bb.IsVoid())
  {
    double x0, y0, z0, x1, y1, z1;
    bb.Get(x0, y0, z0, x1, y1, z1);
    printf(" | bbox x=[%.6g, %.6g] centre=(%.6g, %.6g, %.6g)", x0, x1, (x0 + x1) / 2, (y0 + y1) / 2,
           (z0 + z1) / 2);
  }
  printf("\n");
}

int main()
{
  TopoDS_Shape twoCubes = BRepAlgoAPI_Fuse(box(10, 10, 10), moved(box(2, 2, 2), 20, 0, 0)).Shape();
  report("twoCubes (asymmetricSolid, propertiesAgrees, agreesWithCentroid, agreesWithInertia)",
         twoCubes);
  GProp_GProps sp;
  BRepGProp::SurfaceProperties(twoCubes, sp);
  printf("  twoCubes surface area=%.17g\n", sp.Mass());

  report("cone r=10 h=20 (conePrimitive, agreesWithCentroid)",
         BRepPrimAPI_MakeCone(10, 0, 20).Shape());
  report("10-cube moved +20 x (inertiaIsAboutTheCentreOfMass)",
         moved(box(10, 10, 10), 20, 0, 0));

  TopoDS_Shape               b = moved(box(10, 20, 30), 100, 200, 300);
  TopTools_IndexedMapOfShape faces, edges, wires, verts, shells;
  TopExp::MapShapes(b, TopAbs_FACE, faces);
  TopExp::MapShapes(b, TopAbs_EDGE, edges);
  TopExp::MapShapes(b, TopAbs_WIRE, wires);
  TopExp::MapShapes(b, TopAbs_VERTEX, verts);
  TopExp::MapShapes(b, TopAbs_SHELL, shells);
  report("subShapesWithoutVolume: face 0", faces(1));
  GProp_GProps fa;
  BRepGProp::SurfaceProperties(faces(1), fa);
  printf("  face 0 area=%.17g\n", fa.Mass());
  report("subShapesWithoutVolume: edge 0", edges(1));
  GProp_GProps el;
  BRepGProp::LinearProperties(edges(1), el);
  printf("  edge 0 length=%.17g\n", el.Mass());
  report("subShapesWithoutVolume: wire 0", wires(1));
  report("subShapesWithoutVolume: vertex 0", verts(1));
  report("openShellIsRefused: 5 faces sewn", sew(faces, 5));
  report("openShellIsRefused: 6 faces sewn", sew(faces, 6));
  report("closedShellNotInASolid: shell 0", shells(1));
  return 0;
}
