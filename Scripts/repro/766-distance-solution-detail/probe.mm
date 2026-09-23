// Epic #766, DistanceSolutionDetailTests.swift: kernel parity for both tests.
// Same inputs as the Swift tests, straight to BRepExtrema_DistShapeShape, which is what
// OCCTShapeDistanceSolutionDetail and OCCTShapeAllDistanceSolutions construct.
// Shape.box(width:height:depth:) is centred on the origin (OCCTShapeCreateBox).
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <cstdio>
#include <gp_Trsf.hxx>

static TopoDS_Shape moved(const TopoDS_Shape& s, double x, double y, double z)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(x, y, z));
  return BRepBuilderAPI_Transform(s, t, true).Shape();
}

static void dump(const char* name, const TopoDS_Shape& a, const TopoDS_Shape& b)
{
  BRepExtrema_DistShapeShape d(a, b);
  printf("%s: done=%d value=%.17g nbSolution=%d\n", name, d.IsDone(), d.Value(), d.NbSolution());
  for (int i = 1; i <= d.NbSolution(); ++i)
  {
    gp_Pnt p1 = d.PointOnShape1(i), p2 = d.PointOnShape2(i);
    printf("  [%d] support1=%d support2=%d p1=(%g, %g, %g) p2=(%g, %g, %g)", i - 1,
           (int)d.SupportTypeShape1(i), (int)d.SupportTypeShape2(i), p1.X(), p1.Y(), p1.Z(), p2.X(),
           p2.Y(), p2.Z());
    if (d.SupportTypeShape1(i) == BRepExtrema_IsInFace)
    {
      double u, v;
      d.ParOnFaceS1(i, u, v);
      printf(" uv1=(%.17g, %.17g)", u, v);
    }
    if (d.SupportTypeShape2(i) == BRepExtrema_IsInFace)
    {
      double u, v;
      d.ParOnFaceS2(i, u, v);
      printf(" uv2=(%.17g, %.17g)", u, v);
    }
    if (d.SupportTypeShape1(i) == BRepExtrema_IsOnEdge)
    {
      double t;
      d.ParOnEdgeS1(i, t);
      printf(" t1=%.17g", t);
    }
    if (d.SupportTypeShape2(i) == BRepExtrema_IsOnEdge)
    {
      double t;
      d.ParOnEdgeS2(i, t);
      printf(" t2=%.17g", t);
    }
    printf("\n");
  }
}

int main()
{
  TopoDS_Shape box1 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape box2 = BRepPrimAPI_MakeBox(gp_Pnt(-2.5, -2.5, -2.5), 5, 5, 5).Shape();
  dump("detailBetweenBoxes", box1, moved(box2, 20, 0, 0));
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(3.0).Shape();
  dump("detailSupportTypes", box1, moved(sphere, 20, 5, 5));
  return 0;
}
