// #766 kernel parity: ShapeConstructCurveTests, ShapeConstructTriangulationTests,
// ShapeCustomBSplineRestrictionTests, ShapeCustomDirectModificationTests,
// ShapeCustomSurfacePeriodicTests, ShapeCustomTrsfModificationTests, ShapeExtendExplorerTests.
// Same OCCT calls and inputs as the bridge functions those tests reach.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepTools_Modifier.hxx>
#include <BRep_Builder.hxx>
#include <Geom_Line.hxx>
#include <Geom_Circle.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <ShapeConstruct_Curve.hxx>
#include <ShapeConstruct_MakeTriangulation.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_DirectModification.hxx>
#include <ShapeCustom_TrsfModification.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <ShapeCustom_Surface.hxx>
#include <ShapeExtend_Explorer.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static int unique(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static void solid(const char* label, const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  int planes = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    if (BRepAdaptor_Surface(TopoDS::Face(e.Current())).GetType() == GeomAbs_Plane)
      planes++;
  printf("%s: valid=%d faces=%d planes=%d volume=%.9f\n", label, (int)BRepCheck_Analyzer(s).IsValid(),
         unique(s, TopAbs_FACE), planes, g.Mass());
}

int main()
{
  ShapeConstruct_Curve scc;
  {
    Handle(Geom_Line)         l = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    Handle(Geom_BSplineCurve) b = scc.ConvertToBSpline(l, 0, 10, 1e-6);
    gp_Pnt                    a = b->Value(b->FirstParameter()), z = b->Value(b->LastParameter());
    printf("line [0,10] -> BSpline: degree=%d poles=%d start=(%g, %g, %g) end=(%g, %g, %g)\n", b->Degree(), b->NbPoles(), a.X(),
           a.Y(), a.Z(), z.X(), z.Y(), z.Z());
    printf("AdjustCurve(line, (0,0,0), (10,0,0))=%d\n", (int)scc.AdjustCurve(l, gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)));
  }
  {
    Handle(Geom_Circle)       c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    Handle(Geom_BSplineCurve) b = scc.ConvertToBSpline(c, 0, M_PI, 1e-3);
    gp_Pnt a = b->Value(b->FirstParameter()), z = b->Value(b->LastParameter());
    gp_Pnt m = b->Value((b->FirstParameter() + b->LastParameter()) / 2);
    printf("circle [0,pi] -> BSpline: degree=%d start=(%g, %g, %g) end=(%g, %g, %g) mid=(%.6f, %.6f, %g) domain=[%g, %g]\n",
           b->Degree(), a.X(), a.Y(), a.Z(), z.X(), z.Y(), z.Z(), m.X(), m.Y(), m.Z(), b->FirstParameter(), b->LastParameter());
  }
  {
    Handle(Geom2d_Line)         l = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom2d_BSplineCurve) b = scc.ConvertToBSpline(l, 0, 5, 1e-6);
    gp_Pnt2d                    a = b->Value(b->FirstParameter()), z = b->Value(b->LastParameter());
    printf("2D line [0,5] -> BSpline: degree=%d start=(%g, %g) end=(%g, %g)\n", b->Degree(), a.X(), a.Y(), z.X(), z.Y());
  }
  {
    TColgp_Array1OfPnt pts(1, 4);
    pts(1) = gp_Pnt(0, 0, 0);
    pts(2) = gp_Pnt(10, 0, 0);
    pts(3) = gp_Pnt(10, 10, 0);
    pts(4) = gp_Pnt(0, 10, 0);
    ShapeConstruct_MakeTriangulation mt(pts);
    mt.Build();
    GProp_GProps g;
    if (mt.IsDone())
      BRepGProp::SurfaceProperties(mt.Shape(), g);
    printf("triangulation from 4 points: done=%d type=%d faces=%d area=%.9f\n", (int)mt.IsDone(),
           mt.IsDone() ? (int)mt.Shape().ShapeType() : -1, mt.IsDone() ? unique(mt.Shape(), TopAbs_FACE) : -1, g.Mass());
    BRepBuilderAPI_MakePolygon       p(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(5, 10, 0), true);
    ShapeConstruct_MakeTriangulation mw(p.Wire());
    mw.Build();
    GProp_GProps g2;
    if (mw.IsDone())
      BRepGProp::SurfaceProperties(mw.Shape(), g2);
    printf("triangulation from triangle wire: done=%d type=%d faces=%d area=%.9f\n", (int)mw.IsDone(),
           mw.IsDone() ? (int)mw.Shape().ShapeType() : -1, mw.IsDone() ? unique(mw.Shape(), TopAbs_FACE) : -1, g2.Mass());
  }
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  {
    Handle(ShapeCustom_RestrictionParameters) prm = new ShapeCustom_RestrictionParameters();
    solid("BSplineRestriction(box, defaults 0.01/0.01/8/100/C1/C1)",
          ShapeCustom::BSplineRestriction(box, 0.01, 0.01, 8, 100, GeomAbs_C1, GeomAbs_C1, true, false, prm));
    solid("BSplineRestriction(box, 0.001/0.001/4/50/C2/C2)",
          ShapeCustom::BSplineRestriction(box, 0.001, 0.001, 4, 50, GeomAbs_C2, GeomAbs_C2, true, false, prm));
  }
  {
    BRepTools_Modifier m(box);
    m.Perform(new ShapeCustom_DirectModification());
    solid("DirectModification(box)", m.ModifiedShape(box));
    gp_Trsf t;
    t.SetScale(gp_Pnt(0, 0, 0), 2.0);
    BRepTools_Modifier m2(box);
    m2.Perform(new ShapeCustom_TrsfModification(t));
    solid("TrsfModification(box, scale 2)", m2.ModifiedShape(box));
  }
  {
    Handle(Geom_CylindricalSurface) cs = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    ShapeCustom_Surface             sc(cs);
    printf("ConvertToPeriodic(cylindrical surface) null=%d\n", (int)sc.ConvertToPeriodic(false).IsNull());
  }
  {
    BRep_Builder    b;
    TopoDS_Compound two, one;
    b.MakeCompound(two);
    b.Add(two, BRepPrimAPI_MakeBox(gp_Pnt(-2.5, -2.5, -2.5), 5, 5, 5).Shape());
    b.Add(two, BRepPrimAPI_MakeBox(gp_Pnt(-1.5, -1.5, -1.5), 3, 3, 3).Shape());
    b.MakeCompound(one);
    b.Add(one, box);
    ShapeExtend_Explorer ex;
    TopoDS_Shape         s = ex.SortedCompound(two, TopAbs_SOLID, true, true);
    TopoDS_Shape         f = ex.SortedCompound(two, TopAbs_FACE, true, true);
    TopoDS_Shape         e = ex.SortedCompound(one, TopAbs_EDGE, true, true);
    printf("SortedCompound: solids=%d faces=%d edges(one box)=%d; ShapeType(two boxes)=%d\n", unique(s, TopAbs_SOLID),
           unique(f, TopAbs_FACE), unique(e, TopAbs_EDGE), (int)ex.ShapeType(two, true));
  }
  return 0;
}
