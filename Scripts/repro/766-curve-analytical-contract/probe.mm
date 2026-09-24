// Epic #766 (#1978), kernel parity for AnalyticalConversionContractTests.swift (#492).
// Same inputs as the Swift tests, straight to GeomConvert_CurveToAnaCurve /
// GeomConvert_SurfToAnaSurf, the two classes occtCurveToAnalytical and occtSurfaceToAnalytical
// (OCCTBridge_Internal.h) call. Also prints whether the converter hands back the input handle,
// which is the aliasing the bridge's Copy() exists to break.
#include <GeomAPI_Interpolate.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_CurveToAnaCurve.hxx>
#include <GeomConvert_SurfToAnaSurf.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <GC_MakePlane.hxx>
#include <Standard_Failure.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cmath>
#include <cstdio>

static void curve(const char* name, const Handle(Geom_Curve)& c, double tol, double f, double l)
{
  GeomConvert_CurveToAnaCurve conv(c);
  Handle(Geom_Curve)          r;
  double                      nf = f, nl = l;
  bool                        ok = conv.ConvertToAnalytical(tol, r, f, l, nf, nl);
  printf("%s: tol=%g range=[%.17g, %.17g] ok=%d", name, tol, f, l, ok);
  if (ok && !r.IsNull())
  {
    printf(" result=%s sameHandleAsInput=%d newFirst=%.17g newLast=%.17g gap=%.17g",
           r->DynamicType()->Name(), r == c, nf, nl, conv.Gap());
    double mid = (nf + nl) / 2;
    gp_Pnt p   = r->Value(mid);
    printf(" result(mid)=(%.17g, %.17g, %.17g) |xy|=%.17g", p.X(), p.Y(), p.Z(),
           std::sqrt(p.X() * p.X() + p.Y() * p.Y()));
  }
  printf("\n");
}

static void surf(const char* name, const Handle(Geom_Surface)& s, double tol, const double* uv)
{
  GeomConvert_SurfToAnaSurf conv(s);
  Handle(Geom_Surface)      r;
  try
  {
    r = uv ? conv.ConvertToAnalytical(tol, uv[0], uv[1], uv[2], uv[3])
           : conv.ConvertToAnalytical(tol);
  }
  catch (Standard_Failure& e)
  {
    printf("%s: tol=%g threw %s: %s\n", name, tol, "Standard_Failure", e.what());
    return;
  }
  printf("%s: tol=%g ok=%d", name, tol, !r.IsNull());
  if (!r.IsNull())
  {
    gp_Pnt p = r->Value(0.3, 0.4);
    printf(" result=%s sameHandleAsInput=%d gap=%.17g result(0.3,0.4)=(%.17g, %.17g, %.17g)",
           r->DynamicType()->Name(), r == s, conv.Gap(), p.X(), p.Y(), p.Z());
    gp_Pnt q = s->Value(0.3, 0.4);
    printf(" input(0.3,0.4)=(%.17g, %.17g, %.17g)", q.X(), q.Y(), q.Z());
  }
  printf("\n");
}

int main()
{
  Handle(Geom_Circle) circle = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  curve("circle r=5 full domain", circle, 1e-4, 0, 2 * M_PI);

  Handle(Geom_TrimmedCurve) half = new Geom_TrimmedCurve(circle, 0, M_PI);
  Handle(Geom_BSplineCurve) halfBs = GeomConvert::CurveToBSplineCurve(half);
  printf("half-circle BSpline domain [%.17g, %.17g]\n", halfBs->FirstParameter(),
         halfBs->LastParameter());
  curve("half-circle BSpline full domain", halfBs, 1e-4, halfBs->FirstParameter(),
        halfBs->LastParameter());
  curve("half-circle BSpline domain + 1e-3", halfBs, 1e-4, halfBs->FirstParameter() + 1e-3,
        halfBs->LastParameter());

  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 6);
  pts->SetValue(1, gp_Pnt(0, 0, 0));
  pts->SetValue(2, gp_Pnt(1, 3, 0));
  pts->SetValue(3, gp_Pnt(2, -2, 1));
  pts->SetValue(4, gp_Pnt(4, 5, -3));
  pts->SetValue(5, gp_Pnt(6, 0, 2));
  pts->SetValue(6, gp_Pnt(8, 4, 0));
  GeomAPI_Interpolate ip(pts, false, 1e-6);
  ip.Perform();
  Handle(Geom_BSplineCurve) free = ip.Curve();
  curve("freeform curve 1e-4", free, 1e-4, free->FirstParameter(), free->LastParameter());
  curve("freeform curve 1e-6", free, 1e-6, free->FirstParameter(), free->LastParameter());

  Handle(Geom_BSplineCurve) fullBs = GeomConvert::CurveToBSplineCurve(circle);
  double                    a = fullBs->FirstParameter(), b = fullBs->LastParameter();
  double                    q = (b - a) / 4;
  printf("full-circle BSpline domain [%.17g, %.17g]\n", a, b);
  curve("full-circle BSpline middle half", fullBs, 1e-4, a + q, b - q);

  Handle(Geom_Plane) plane0 = GC_MakePlane(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1)).Value();
  surf("plane at (1,2,3)", plane0, 1e-4, nullptr);
  Handle(Geom_Plane) plane = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
  Handle(Geom_BSplineSurface) planeBs = GeomConvert::SurfaceToBSplineSurface(
    new Geom_RectangularTrimmedSurface(plane, -10.0, 10.0, -10.0, 10.0, true, true));
  double u1, u2, v1, v2;
  planeBs->Bounds(u1, u2, v1, v2);
  printf("BSpline plane bounds u [%.17g, %.17g] v [%.17g, %.17g]\n", u1, u2, v1, v2);
  surf("BSpline plane", planeBs, 1e-4, nullptr);
  const double full[4] = {u1, u2, v1, v2};
  surf("BSpline plane, full UV bounds", planeBs, 1e-4, full);
  double       um = (u1 + u2) / 2, uq = (u2 - u1) / 4, vm = (v1 + v2) / 2, vq = (v2 - v1) / 4;
  const double sub[4] = {um - uq, um + uq, vm - vq, vm + vq};
  surf("BSpline plane, middle-half UV bounds", planeBs, 1e-4, sub);
  const double inv[4] = {u2, u1, v2, v1};
  surf("BSpline plane, inverted UV bounds", planeBs, 1e-4, inv);
  const double invSwapped[4] = {u1, u2, v1, v2};
  (void)invSwapped;

  Handle(Geom_CylindricalSurface) cyl =
    new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  surf("cylinder r=5", cyl, 1e-4, nullptr);

  TColgp_Array2OfPnt fp(1, 4, 1, 4);
  for (int i = 0; i < 4; i++)
    for (int j = 0; j < 4; j++)
    {
      double x = i * 2, y = j * 2;
      fp(i + 1, j + 1) = gp_Pnt(x, y, std::sin(x * 0.7) * std::cos(y * 1.3) * 4);
    }
  TColStd_Array1OfReal    k(1, 2);
  TColStd_Array1OfInteger m(1, 2);
  k(1) = 0;
  k(2) = 1;
  m(1) = m(2) = 4;
  Handle(Geom_BSplineSurface) freeS = new Geom_BSplineSurface(fp, k, k, m, m, 3, 3);
  surf("freeform surface 1e-4", freeS, 1e-4, nullptr);
  surf("freeform surface 1e-6", freeS, 1e-6, nullptr);
  const double unit[4] = {0, 1, 0, 1};
  surf("freeform surface 1e-6 on [0,1]x[0,1]", freeS, 1e-6, unit);
  return 0;
}
