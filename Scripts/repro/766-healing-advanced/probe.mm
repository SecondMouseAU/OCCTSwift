// #766 kernel parity: AdvancedHealingTests + AnalyticalConversionTests.
// Same OCCT calls, same inputs as the bridge functions those tests reach.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <BRep_Tool.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <ShapeFix_Shape.hxx>
#include <Geom_Circle.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_CurveToAnaCurve.hxx>
#include <GeomConvert_SurfToAnaSurf.hxx>
#include <cstdio>

static const char* stype(int t)
{
  const char* n[] = {"plane", "cylinder", "cone", "sphere", "torus", "bezier",
                     "bspline", "revolution", "extrusion", "offset", "other"};
  return n[t];
}

static void report(const char* label, const TopoDS_Shape& s)
{
  if (s.IsNull())
  {
    printf("%s: NULL\n", label);
    return;
  }
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  int nf         = 0;
  int counts[11] = {0};
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
  {
    nf++;
    BRepAdaptor_Surface a(TopoDS::Face(e.Current()));
    counts[a.GetType()]++;
  }
  printf("%s: type=%d valid=%d faces=%d volume=%.9f surfaces:", label, (int)s.ShapeType(),
         (int)BRepCheck_Analyzer(s).IsValid(), nf, p.Mass());
  for (int i = 0; i < 11; i++)
    if (counts[i])
      printf(" %s=%d", stype(i), counts[i]);
  printf("\n");
}

int main()
{
  // Shape.box(width: 10, height: 10, depth: 10) is centered: OCCTShapeCreateBox.
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  report("input box", box);
  report("input cylinder", cyl);

  // divideCylinder: OCCTShapeDivide(cyl, 1 = C1, 1e-7)
  {
    ShapeUpgrade_ShapeDivideContinuity d(cyl);
    d.SetBoundaryCriterion(GeomAbs_C1);
    d.SetPCurveCriterion(GeomAbs_C1);
    d.SetSurfaceCriterion(GeomAbs_C1);
    d.SetTolerance(1e-7);
    d.SetSurfaceSegmentMode(Standard_True);
    Standard_Boolean ok = d.Perform();
    printf("divide C1 Perform=%d\n", (int)ok);
    report("divide C1 result", d.Result());
  }
  // OCCTShapeDirectFaces / ScaleGeometry / BSplineRestriction / ConvertToBSpline / SweptToElementary
  report("DirectFaces(box)", ShapeCustom::DirectFaces(box));
  report("ScaleShape(box, 2)", ShapeCustom::ScaleShape(box, 2.0));
  {
    Handle(ShapeCustom_RestrictionParameters) prm = new ShapeCustom_RestrictionParameters();
    report("BSplineRestriction(box,0.01,0.01,9,10000,C1,C1,T,T)",
           ShapeCustom::BSplineRestriction(box, 0.01, 0.01, 9, 10000, GeomAbs_C1, GeomAbs_C1,
                                           Standard_True, Standard_True, prm));
  }
  report("ConvertToBSpline(box,T,T,T,F)",
         ShapeCustom::ConvertToBSpline(box, Standard_True, Standard_True, Standard_True, Standard_False));
  report("SweptToElementary(cyl)", ShapeCustom::SweptToElementary(cyl));
  // OCCTShapeSewSingle
  {
    BRepBuilderAPI_Sewing sw(1e-6);
    sw.Add(box);
    sw.Perform();
    report("Sewing(box,1e-6) SewedShape", sw.SewedShape());
  }
  // OCCTShapeUpgrade: sew; a non-solid result gets one solid per body shell; ShapeFix_Shape.
  {
    BRepBuilderAPI_Sewing sw(1e-6);
    sw.Add(box);
    sw.Perform();
    TopoDS_Shape s = sw.SewedShape();
    TopoDS_Shape r = s;
    if (s.ShapeType() != TopAbs_SOLID)
    {
      for (TopExp_Explorer e(s, TopAbs_SHELL); e.More(); e.Next())
      {
        BRepBuilderAPI_MakeSolid ms(TopoDS::Shell(e.Current()));
        r = ms.Solid();
        break;
      }
    }
    ShapeFix_Shape fx(r);
    fx.Perform();
    report("Upgrade(box,1e-6)", fx.Shape());
  }

  // bsplineCircle: circle r=10 -> GeomConvert::CurveToBSplineCurve -> CurveToAnaCurve(0.01)
  {
    Handle(Geom_Circle)       c  = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
    Handle(Geom_BSplineCurve) bs = GeomConvert::CurveToBSplineCurve(c);
    printf("circle BSpline: first=%.9f last=%.9f\n", bs->FirstParameter(), bs->LastParameter());
    GeomConvert_CurveToAnaCurve conv(bs);
    Handle(Geom_Curve)          res;
    double                      nf = 0, nl = 0;
    Standard_Boolean            ok =
      conv.ConvertToAnalytical(0.01, res, bs->FirstParameter(), bs->LastParameter(), nf, nl);
    printf("CurveToAnaCurve ok=%d null=%d gap=%.3e newFirst=%.9f newLast=%.9f\n", (int)ok,
           (int)res.IsNull(), conv.Gap(), nf, nl);
    if (!res.IsNull())
    {
      Handle(Geom_Circle) rc = Handle(Geom_Circle)::DownCast(res);
      printf("  isCircle=%d radius=%.9f\n", (int)!rc.IsNull(), rc.IsNull() ? -1.0 : rc->Radius());
      gp_Pnt p = res->Value(0);
      printf("  value(0)=(%.9f, %.9f, %.9f)\n", p.X(), p.Y(), p.Z());
    }
  }
  // surfaceConversion: Surface.cylinder(origin: .zero, axis: z, radius: 5) is unbounded.
  Handle(Geom_CylindricalSurface) cs =
    new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  try
  {
    Handle(Geom_BSplineSurface) bs = GeomConvert::SurfaceToBSplineSurface(cs);
    printf("infinite cylinder SurfaceToBSplineSurface: null=%d\n", (int)bs.IsNull());
  }
  catch (Standard_Failure& f)
  {
    printf("infinite cylinder SurfaceToBSplineSurface: THROWS %s\n", f.what());
  }
  // Trimmed to [0, 2pi] x [0, 10] first, as the rewritten test does.
  {
    Handle(Geom_RectangularTrimmedSurface) t =
      new Geom_RectangularTrimmedSurface(cs, 0.0, 2 * M_PI, 0.0, 10.0);
    Handle(Geom_BSplineSurface) bs = GeomConvert::SurfaceToBSplineSurface(t);
    printf("trimmed cylinder BSpline: null=%d\n", (int)bs.IsNull());
    GeomConvert_SurfToAnaSurf conv(bs);
    Handle(Geom_Surface)      res = conv.ConvertToAnalytical(0.01);
    printf("SurfToAnaSurf null=%d gap=%.3e\n", (int)res.IsNull(), conv.Gap());
    if (!res.IsNull())
    {
      Handle(Geom_CylindricalSurface) rc = Handle(Geom_CylindricalSurface)::DownCast(res);
      printf("  type=%s isCylinder=%d radius=%.9f\n", res->DynamicType()->Name(), (int)!rc.IsNull(),
             rc.IsNull() ? -1.0 : rc->Radius());
      gp_Pnt p = res->Value(0, 0);
      printf("  value(0,0)=(%.9f, %.9f, %.9f)\n", p.X(), p.Y(), p.Z());
    }
  }
  return 0;
}
