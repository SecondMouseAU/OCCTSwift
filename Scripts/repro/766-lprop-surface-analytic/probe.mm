// #766 kernel parity for LProp3dSurfaceTests.swift and LPropAnalyticCurInfTests.swift.
// Same inputs as the tests, same resolution as the bridge (occtSurfaceLocalProps uses
// Precision::Confusion()). OCCTLPropAnalyticCurInf reimplements LProp_AnalyticCurInf inline because
// OCCT 8.0.1 no longer ships that class (no header, no symbol in libOCCT-macos.a), so its kernel
// counterpart here is GeomLProp_CurAndInf2d::Perform on real Geom2d curves of each type, which
// computes the curvature extrema and inflections of the same curve kinds.
#include <GeomLProp_SLProps.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <GeomLProp_CurAndInf2d.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <gp_Ax22d.hxx>
#include <gp_Ax2d.hxx>
#include <LProp_CurAndInf.hxx>
#include <Precision.hxx>
#include <gp_Ax3.hxx>
#include <cstdio>
#include <cmath>

static void surf(const char* label, const Handle(Geom_Surface)& s, double u, double v)
{
  GeomLProp_SLProps p(s, u, v, 2, Precision::Confusion());
  printf("%s u=%g v=%g curvatureDefined=%d umbilic=%d\n", label, u, v, p.IsCurvatureDefined(),
         p.IsCurvatureDefined() ? p.IsUmbilic() : -1);
  if (!p.IsCurvatureDefined())
    return;
  printf("  gaussian=%.17g mean=%.17g max=%.17g min=%.17g\n", p.GaussianCurvature(),
         p.MeanCurvature(), p.MaxCurvature(), p.MinCurvature());
  if (!p.IsUmbilic())
  {
    gp_Dir dmax, dmin;
    p.CurvatureDirections(dmax, dmin);
    printf("  maxDir=(%.17g, %.17g, %.17g) minDir=(%.17g, %.17g, %.17g)\n", dmax.X(), dmax.Y(),
           dmax.Z(), dmin.X(), dmin.Y(), dmin.Z());
  }
}

static void analytic(const char* label, const Handle(Geom2d_Curve)& c, double first, double last)
{
  GeomLProp_CurAndInf2d r;
  r.Perform(new Geom2d_TrimmedCurve(c, first, last));
  printf("%s IsDone=%d\n", label, r.IsDone());
  printf("%s [%g, %g]: NbPoints=%d\n", label, first, last, r.NbPoints());
  for (int i = 1; i <= r.NbPoints(); i++)
  {
    const char* ty = r.Type(i) == LProp_Inflection ? "Inflection"
                     : r.Type(i) == LProp_MinCur   ? "MinCur"
                                                   : "MaxCur";
    printf("  param=%.17g type=%s\n", r.Parameter(i), ty);
  }
}

int main()
{
  Handle(Geom_SphericalSurface) sphere =
    new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 10.0);
  surf("sphere r=10 (sphereCurvatures)", sphere, 0.0, 0.5);
  Handle(Geom_CylindricalSurface) cyl =
    new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
  surf("cylinder r=5 (cylinderCurvatures, curvatureDirections)", cyl, 0.0, 0.0);

  // The Swift API takes only a curve type, so any radii will do; the parameters are
  // shape-independent for an ellipse (its axis vertices).
  gp_Ax22d ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  analytic("ellipse 3x1 (ellipseHasExtrema)", new Geom2d_Ellipse(ax, 3.0, 1.0), 0, 2 * M_PI);
  analytic("line (lineHasNoSpecialPoints)", new Geom2d_Line(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0))), 0, 10);
  analytic("circle r=2 (circleHasNoSpecialPoints)", new Geom2d_Circle(ax, 2.0), 0, 2 * M_PI);
  return 0;
}
