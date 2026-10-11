// Epic #766 (#1978), kernel parity for CurveToAnaCurveTests.swift. Same inputs as the tests:
// GeomConvert_CurveToAnaCurve::ConvertToAnalytical over the BSpline's own domain, and
// GeomConvert_CurveToAnaCurve::IsLinear. CuttingPlaneLineTests.swift exercises Swift-only drawing
// geometry (Drawing.addCuttingPlaneLine and the DXF emitter), which has no kernel counterpart.
#include <GC_MakeSegment.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_CurveToAnaCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <cstdio>

static void ana(const char* name, const Handle(Geom_Curve)& basis, double a, double b)
{
  Handle(Geom_BSplineCurve)   bs = GeomConvert::CurveToBSplineCurve(new Geom_TrimmedCurve(basis, a, b));
  GeomConvert_CurveToAnaCurve conv(bs);
  Handle(Geom_Curve)          r;
  double                      nf = 0, nl = 0;
  bool ok = conv.ConvertToAnalytical(1e-4, r, bs->FirstParameter(), bs->LastParameter(), nf, nl);
  printf("%s: BSpline domain [%.17g, %.17g] ok=%d result=%s newFirst=%.17g newLast=%.17g gap=%.17g\n", name,
         bs->FirstParameter(), bs->LastParameter(), ok, ok ? r->DynamicType()->Name() : "-", nf, nl,
         conv.Gap());
}

int main()
{
  ana("line [0, 10]", new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 0, 10);
  ana("circle r=5 [0, pi]", new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5), 0, M_PI);
  NCollection_Array1<gp_Pnt> pts(1, 3);
  pts(1) = gp_Pnt(0, 0, 0);
  pts(2) = gp_Pnt(5, 0, 0);
  pts(3) = gp_Pnt(10, 0, 0);
  double dev = -1;
  bool   lin = GeomConvert_CurveToAnaCurve::IsLinear(pts, 1e-6, dev);
  printf("IsLinear (0,0,0) (5,0,0) (10,0,0): %d deviation=%.17g\n", lin, dev);
  return 0;
}
