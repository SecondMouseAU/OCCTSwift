// Epic #766 (#1978), kernel parity for Issue1476CurveTypeOtherCurveFallbackTests,
// Issue1513UniformDeflectionNullGuardTests and Issue1675DocSnippetArcTests: the GeomAbs_CurveType
// ordinals, CPnts_UniformDeflection on an ordinary cylinder edge, and the snippet arcs through
// GC_MakeArcOfCircle.
#include <BRepAdaptor_Curve.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <CPnts_UniformDeflection.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GeomAbs_CurveType.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomLProp_CLProps.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  printf("GeomAbs_OffsetCurve %d GeomAbs_OtherCurve %d GeomAbs_Line %d\n", (int)GeomAbs_OffsetCurve,
         (int)GeomAbs_OtherCurve, (int)GeomAbs_Line);
  Handle(Geom_Line) l = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  printf("line GetType %d\n", (int)GeomAdaptor_Curve(l).GetType());

  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(10, 5).Shape();
  for (TopExp_Explorer ex(cyl, TopAbs_EDGE); ex.More(); ex.Next())
  {
    BRepAdaptor_Curve       bac(TopoDS::Edge(ex.Current()));
    CPnts_UniformDeflection ud(bac, 0.1, bac.FirstParameter(), bac.LastParameter(), 1e-7, true);
    int                     n = 0;
    for (; ud.More(); ud.Next())
      n++;
    printf("cylinder edge type %d uniform deflection 0.1 -> %d points\n", (int)bac.GetType(), n);
  }

  struct A
  {
    gp_Pnt s, m, e;
  } arcs[] = {{gp_Pnt(5, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(-5, 0, 0)},
              {gp_Pnt(13, 0, 0), gp_Pnt(10, 3, 0), gp_Pnt(7, 0, 0)},
              {gp_Pnt(23, 0, 0), gp_Pnt(20, 3, 0), gp_Pnt(17, 0, 0)}};
  for (auto& a : arcs)
  {
    GC_MakeArcOfCircle mk(a.s, a.m, a.e);
    if (!mk.IsDone())
    {
      printf("arc not done\n");
      continue;
    }
    Handle(Geom_TrimmedCurve) c = mk.Value();
    double            u0 = c->FirstParameter(), u1 = c->LastParameter();
    GeomLProp_CLProps pr(c, u0, 2, 1e-9);
    gp_Pnt            cc;
    pr.CentreOfCurvature(cc);
    gp_Pnt p0 = c->Value(u0), p1 = c->Value(u1);
    printf("arc: curvature %.17g centre (%.3g, %.3g, %.3g) start (%.17g, %.3g) end (%.17g, %.3g)\n",
           pr.Curvature(), cc.X(), cc.Y(), cc.Z(), p0.X(), p0.Y(), p1.X(), p1.Y());
  }
  return 0;
}
