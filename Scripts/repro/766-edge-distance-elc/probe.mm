// #766 kernel parity for four Tests/OCCTAnalysisTests files:
//   EdgePropertyTests.swift        BRepAdaptor_Curve::GetType, as OCCTEdgeIsLine / OCCTEdgeIsCircle
//   ExtendedDistanceTests.swift    BRepExtrema_DistShapeShape, as OCCTShapeAllDistanceSolutions /
//                                  OCCTShapeIsInnerDistance
//   ExtremaElCCircCircTests.swift  Extrema_ExtElC(gp_Circ, gp_Circ), as OCCTExtremaElCCircCirc
//   ExtremaElCLinElipsTests.swift  Extrema_ExtElC(gp_Lin, gp_Elips), as OCCTExtremaElCLinElips
// Shapes are built the way the bridge builds them: OCCTShapeCreateBox centres the box on the
// origin, OCCTShapeCreateSphere/Cylinder use the default placement, translated(by:) is a
// gp_Trsf translation.
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <Extrema_ExtElC.hxx>
#include <Extrema_POnCurv.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <gp_Circ.hxx>
#include <gp_Elips.hxx>
#include <gp_Lin.hxx>
#include <gp_Trsf.hxx>
#include <cstdio>

static TopoDS_Shape moved(const TopoDS_Shape& s, double dx)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(dx, 0, 0));
  return BRepBuilderAPI_Transform(s, t, true).Shape();
}

static void dist(const char* name, const TopoDS_Shape& a, const TopoDS_Shape& b)
{
  BRepExtrema_DistShapeShape d(a, b);
  printf("%s: IsDone=%d NbSolution=%d Value=%.17g InnerSolution=%d\n",
         name, d.IsDone() ? 1 : 0, d.NbSolution(), d.Value(), d.InnerSolution() ? 1 : 0);
  for (int i = 1; i <= d.NbSolution(); ++i)
  {
    gp_Pnt p1 = d.PointOnShape1(i), p2 = d.PointOnShape2(i);
    printf("  [%d] p1=(%.17g, %.17g, %.17g) p2=(%.17g, %.17g, %.17g)\n",
           i, p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
  }
}

static void elc(const char* name, Extrema_ExtElC& ext)
{
  printf("%s: IsDone=%d IsParallel=%d", name, ext.IsDone() ? 1 : 0, ext.IsParallel() ? 1 : 0);
  if (ext.IsParallel())
  {
    printf(" SquareDistance(1)=%.17g\n", ext.SquareDistance(1));
    return;
  }
  printf(" NbExt=%d\n", ext.NbExt());
  for (int i = 1; i <= ext.NbExt(); ++i)
  {
    Extrema_POnCurv p1, p2;
    ext.Points(i, p1, p2);
    printf("  [%d] sq=%.17g p1=(%.17g, %.17g, %.17g) p2=(%.17g, %.17g, %.17g)\n",
           i, ext.SquareDistance(i),
           p1.Value().X(), p1.Value().Y(), p1.Value().Z(),
           p2.Value().X(), p2.Value().Y(), p2.Value().Z());
  }
}

int main()
{
  // EdgePropertyTests
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape boxEdges;
  TopExp::MapShapes(box, TopAbs_EDGE, boxEdges);
  for (int i = 1; i <= boxEdges.Extent(); ++i)
  {
    BRepAdaptor_Curve c(TopoDS::Edge(boxEdges(i)));
    printf("box edge %d: GetType=%d (Line=%d Circle=%d)\n",
           i, (int)c.GetType(), (int)GeomAbs_Line, (int)GeomAbs_Circle);
  }
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopTools_IndexedMapOfShape cylEdges;
  TopExp::MapShapes(cyl, TopAbs_EDGE, cylEdges);
  for (int i = 1; i <= cylEdges.Extent(); ++i)
  {
    BRepAdaptor_Curve c(TopoDS::Edge(cylEdges(i)));
    printf("cylinder edge %d: GetType=%d\n", i, (int)c.GetType());
  }

  // ExtendedDistanceTests
  TopoDS_Shape s1 = BRepPrimAPI_MakeSphere(5).Shape();
  dist("sphereDistanceSolutions", s1, moved(BRepPrimAPI_MakeSphere(5).Shape(), 20));
  dist("boxDistanceSolutions", box, moved(box, 20));
  dist("notInner", box, moved(box, 20));

  // ExtremaElCCircCircTests
  {
    gp_Circ        c1(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    gp_Circ        c2(gp_Ax2(gp_Pnt(20, 0, 0), gp_Dir(0, 0, 1)), 5);
    Extrema_ExtElC e(c1, c2);
    elc("coplanarCircles", e);
  }
  {
    gp_Circ        c1(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    gp_Circ        c2(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3);
    Extrema_ExtElC e(c1, c2);
    elc("coaxialCirclesReturnRadiusDifference", e);
  }

  // ExtremaElCLinElipsTests
  {
    gp_Lin         l(gp_Pnt(0, 0, 10), gp_Dir(1, 0, 0));
    gp_Elips       el(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)), 5, 3);
    Extrema_ExtElC e(l, el);
    elc("lineEllipseDistance", e);
  }
  {
    gp_Lin         l(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1));
    gp_Elips       el(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)), 5, 5);
    Extrema_ExtElC e(l, el);
    elc("lineOnEllipseAxisReturnsDistance", e);
  }
  return 0;
}
