// Epic #766, OCCTDrawingTests: LengthDimensionTests and NormalProjectionTests.
// PrsDim_LengthDimension built the way OCCTBridge_AIS.mm builds it (points with a plane through
// the line, an edge with the same plane, two faces), and BRepOffsetAPI_NormalProjection with the
// Swift defaults (tol3d 1e-4, tol2d 1e-5, C2, maxDegree 14, maxSeg 16) on a radius-10 sphere.
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepOffsetAPI_NormalProjection.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <Bnd_Box.hxx>
#include <PrsDim_LengthDimension.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

// computePlaneForPoints in OCCTBridge_AIS.mm.
static gp_Pln planeFor(const gp_Pnt& p1, const gp_Pnt& p2)
{
  gp_Vec d(p1, p2), up(0, 0, 1);
  if (d.IsParallel(up, 1e-6))
    up = gp_Vec(0, 1, 0);
  return gp_Pln(p1, gp_Dir(d.Crossed(up)));
}

static void points(const char* tag, gp_Pnt a, gp_Pnt b)
{
  Handle(PrsDim_LengthDimension) d = new PrsDim_LengthDimension(a, b, planeFor(a, b));
  gp_Pnt f = d->FirstPoint(), s = d->SecondPoint();
  printf("%s: value=%.17g valid=%d first=(%g, %g, %g) second=(%g, %g, %g)\n", tag, d->GetValue(),
         d->IsValid(), f.X(), f.Y(), f.Z(), s.X(), s.Y(), s.Z());
  d->SetCustomValue(42.0);
  printf("%s: after SetCustomValue(42) value=%.17g\n", tag, d->GetValue());
}

static void projection(const char* tag, gp_Pnt a, gp_Pnt b)
{
  BRepOffsetAPI_NormalProjection proj(BRepPrimAPI_MakeSphere(10).Shape());
  proj.Add(BRepBuilderAPI_MakeEdge(a, b).Edge());
  proj.SetParams(1e-4, 1e-5, GeomAbs_C2, 14, 16);
  proj.Build();
  printf("%s: IsDone=%d\n", tag, proj.IsDone());
  if (!proj.IsDone())
    return;
  TopoDS_Shape               r = proj.Projection();
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(r, TopAbs_EDGE, m);
  Bnd_Box bb;
  BRepBndLib::Add(r, bb, true);
  double x0, y0, z0, x1, y1, z1;
  bb.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: edges=%d bbox=(%.9g, %.9g, %.9g)..(%.9g, %.9g, %.9g)\n", tag, m.Extent(), x0, y0, z0,
         x1, y1, z1);
}

int main()
{
  points("pointToPoint", gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
  points("diagonalDistance", gp_Pnt(0, 0, 0), gp_Pnt(3, 4, 0));
  points("threeDDistance", gp_Pnt(1, 2, 3), gp_Pnt(4, 6, 3));
  points("geometryPoints", gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 0));
  {
    TopoDS_Edge                    e = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(7, 0, 0)).Edge();
    Handle(PrsDim_LengthDimension) d =
      new PrsDim_LengthDimension(e, planeFor(gp_Pnt(0, 0, 0), gp_Pnt(7, 0, 0)));
    printf("edgeLength: value=%.17g valid=%d\n", d->GetValue(), d->IsValid());
  }
  {
    BRepBuilderAPI_MakePolygon poly(gp_Pnt(-10, -15, 0), gp_Pnt(10, -15, 0), gp_Pnt(10, 15, 0),
                                    gp_Pnt(-10, 15, 0), true);
    TopoDS_Face f1 = BRepBuilderAPI_MakeFace(poly.Wire()).Face();
    gp_Trsf     t;
    t.SetTranslation(gp_Vec(0, 0, 10));
    TopoDS_Face f2 = TopoDS::Face(BRepBuilderAPI_Transform(f1, t, true).Shape());
    Handle(PrsDim_LengthDimension) d = new PrsDim_LengthDimension(f1, f2);
    printf("faceToFaceDistance: value=%.17g valid=%d\n", d->GetValue(), d->IsValid());
  }
  projection("projectOnSphere", gp_Pnt(8, -2, 0), gp_Pnt(8, 2, 0));
  projection("projectOutsideSphere", gp_Pnt(15, -5, 0), gp_Pnt(15, 5, 0));
  return 0;
}
