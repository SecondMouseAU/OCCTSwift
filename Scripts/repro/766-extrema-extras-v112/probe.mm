// Kernel parity probe for Tests/OCCTAnalysisTests/ExtremaExtrasV112Tests.swift (#766).
//
// Same inputs and the same OCCT calls as the four bridge functions the tests reach:
//   locateOnCurve         -> OCCTExtremaLocateOnCurve   (GeomAPI_ProjectPointOnCurve on a +/-10%
//                                                        window, whole-curve fallback)
//   projectPointOnCurve   -> OCCTExtremaPointCurve      (GeomAPI_ProjectPointOnCurve)
//   locateOnSurface       -> OCCTExtremaLocateOnSurface (Extrema_GenLocateExtPS)
//   projectPointOnSurface -> OCCTExtremaPointSurface    (GeomAPI_ProjectPointOnSurf)
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <GC_MakePlane.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Extrema_GenLocateExtPS.hxx>
#include <Extrema_POnSurf.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp.hxx>
#include <algorithm>
#include <cmath>
#include <cstdio>

int main()
{
  // locateOnCurve: circle r=5 about +Z at the origin, point (6, 0, 0), initParam 0.
  {
    Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    double f = c->FirstParameter(), l = c->LastParameter(), range = (l - f) * 0.1;
    double lo = std::max(f, 0.0 - range), hi = std::min(l, 0.0 + range);
    GeomAPI_ProjectPointOnCurve proj(gp_Pnt(6, 0, 0), c, lo, hi);
    printf("locateOnCurve: window=[%.17g, %.17g] NbPoints=%d\n", lo, hi, proj.NbPoints());
    if (proj.NbPoints() > 0)
      printf("  windowed: param=%.17g distance=%.17g\n", proj.LowerDistanceParameter(),
             proj.LowerDistance());
    GeomAPI_ProjectPointOnCurve whole(gp_Pnt(6, 0, 0), c);
    printf("  whole curve: NbPoints=%d nearest param=%.17g distance=%.17g\n", whole.NbPoints(),
           whole.LowerDistanceParameter(), whole.LowerDistance());
  }

  // projectPointOnCurve: line through the origin along +X, point (5, 3, 0).
  {
    Handle(Geom_Line)           ln = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    GeomAPI_ProjectPointOnCurve proj(gp_Pnt(5, 3, 0), ln);
    printf("projectPointOnCurve: NbPoints=%d\n", proj.NbPoints());
    for (int i = 1; i <= proj.NbPoints(); i++)
      printf("  [%d] param=%.17g distance=%.17g\n", i, proj.Parameter(i), proj.Distance(i));
  }

  // locateOnSurface: GC_MakePlane((0,0,0), +Z), point (5, 3, 10), init (0, 0), tol 1e-6.
  {
    Handle(Geom_Plane)     pl = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
    gp_Dir                 xd = pl->Position().XDirection();
    GeomAdaptor_Surface    as(pl);
    Extrema_GenLocateExtPS ext(as, 1e-6, 1e-6);
    ext.Perform(gp_Pnt(5, 3, 10), 0, 0);
    printf("locateOnSurface: plane XDirection=(%.17g, %.17g, %.17g) IsDone=%d\n", xd.X(), xd.Y(),
           xd.Z(), ext.IsDone());
    if (ext.IsDone())
    {
      double u, v;
      ext.Point().Parameter(u, v);
      printf("  u=%.17g v=%.17g distance=%.17g\n", u, v, std::sqrt(ext.SquareDistance()));
    }
  }

  // projectPointOnSurface: sphere r=5 at the origin, point (10, 0, 0).
  {
    Handle(Geom_SphericalSurface) s =
      new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
    GeomAPI_ProjectPointOnSurf proj(gp_Pnt(10, 0, 0), s);
    printf("projectPointOnSurface: IsDone=%d NbPoints=%d\n", proj.IsDone(), proj.NbPoints());
    for (int i = 1; i <= proj.NbPoints(); i++)
    {
      double u, v;
      proj.Parameters(i, u, v);
      printf("  [%d] u=%.17g v=%.17g distance=%.17g\n", i, u, v, proj.Distance(i));
    }
  }
  return 0;
}
