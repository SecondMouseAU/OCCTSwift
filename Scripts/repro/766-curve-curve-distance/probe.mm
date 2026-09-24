// #766 kernel parity for Tests/OCCTAnalysisTests/CurveCurveDistanceTests.swift:
//   GeomAPI_ExtremaCurveCurve::LowerDistance   (OCCTCurve3DMinDistanceToCurve)
//   GeomAPI_ExtremaCurveCurve::Distance(i)     (OCCTCurve3DExtrema)
//   GeomAPI_ExtremaCurveSurface::LowerDistance (OCCTCurve3DDistanceToSurface)
// Curve3D.segment builds a Geom_TrimmedCurve over a Geom_Line (GC_MakeSegment).
#include <GC_MakePlane.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomAPI_ExtremaCurveCurve.hxx>
#include <GeomAPI_ExtremaCurveSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <cstdio>

static occ::handle<Geom_TrimmedCurve> seg(gp_Pnt a, gp_Pnt b)
{
  return GC_MakeSegment(a, b).Value();
}

int main()
{
  {
    GeomAPI_ExtremaCurveCurve e(seg(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)),
                                seg(gp_Pnt(0, 5, 0), gp_Pnt(10, 5, 0)));
    printf("parallelLines: NbExtrema=%d IsParallel=%d LowerDistance=%.17g\n", e.NbExtrema(),
           (int)e.IsParallel(), e.NbExtrema() ? e.LowerDistance() : -1.0);
  }
  {
    GeomAPI_ExtremaCurveCurve e(seg(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)),
                                seg(gp_Pnt(5, 3, -5), gp_Pnt(5, 3, 5)));
    printf("skewLines: NbExtrema=%d IsParallel=%d\n", e.NbExtrema(), (int)e.IsParallel());
    for (int i = 1; i <= e.NbExtrema(); ++i)
    {
      gp_Pnt p1, p2;
      e.Points(i, p1, p2);
      printf("  extremum %d: distance=%.17g p1=(%g,%g,%g) p2=(%g,%g,%g)\n", i, e.Distance(i),
             p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
    }
  }
  {
    occ::handle<Geom_Plane>     pl = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
    GeomAPI_ExtremaCurveSurface e(seg(gp_Pnt(0, 0, 5), gp_Pnt(10, 0, 5)), pl);
    printf("curveSurfaceDistance: NbExtrema=%d IsParallel=%d LowerDistance=%.17g\n", e.NbExtrema(),
           (int)e.IsParallel(), e.NbExtrema() ? e.LowerDistance() : -1.0);
  }
  return 0;
}
