// #766 kernel parity for three Tests/OCCTAnalysisTests files:
//   ExtremaElCLinLinTests.swift       Extrema_ExtElC(gp_Lin, gp_Lin, 1e-6), as OCCTExtremaElCLinLin
//   ExtremaElCSLinPlaneTests.swift    Extrema_ExtElCS(gp_Lin, gp_Pln), as OCCTExtremaElCSLinPlane
//   ExtremaElSSPlanePlaneTests.swift  Extrema_ExtElSS(gp_Pln, gp_Pln), as OCCTExtremaElSSPlanePlane
//                                     (the six tests #2262 does not cover)
#include <Extrema_ExtElC.hxx>
#include <Extrema_ExtElCS.hxx>
#include <Extrema_ExtElSS.hxx>
#include <Extrema_POnCurv.hxx>
#include <Extrema_POnSurf.hxx>
#include <Standard_Failure.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <cstdio>
#include <typeinfo>

static void linlin(const char* name, gp_Pnt p1, gp_Dir d1, gp_Pnt p2, gp_Dir d2)
{
  Extrema_ExtElC e(gp_Lin(p1, d1), gp_Lin(p2, d2), 1e-6);
  printf("%s: IsDone=%d IsParallel=%d", name, e.IsDone() ? 1 : 0, e.IsParallel() ? 1 : 0);
  if (e.IsParallel())
  {
    printf(" SquareDistance(1)=%.17g\n", e.SquareDistance(1));
    return;
  }
  printf(" NbExt=%d\n", e.NbExt());
  for (int i = 1; i <= e.NbExt(); ++i)
  {
    Extrema_POnCurv a, b;
    e.Points(i, a, b);
    printf("  [%d] sq=%.17g p1=(%.17g, %.17g, %.17g) p2=(%.17g, %.17g, %.17g)\n",
           i, e.SquareDistance(i), a.Value().X(), a.Value().Y(), a.Value().Z(),
           b.Value().X(), b.Value().Y(), b.Value().Z());
  }
}

static void linpln(const char* name, gp_Pnt lp, gp_Dir ld, gp_Pnt pp, gp_Dir pn)
{
  Extrema_ExtElCS e(gp_Lin(lp, ld), gp_Pln(pp, pn));
  printf("%s: IsDone=%d IsParallel=%d", name, e.IsDone() ? 1 : 0, e.IsParallel() ? 1 : 0);
  if (e.IsParallel())
  {
    printf(" SquareDistance(1)=%.17g\n", e.SquareDistance(1));
    return;
  }
  printf(" NbExt=%d\n", e.NbExt());
}

static void plnpln(const char* name, gp_Pnt p1, double n1x, double n1y, double n1z,
                   gp_Pnt p2, gp_Dir n2)
{
  try
  {
    gp_Pln          a(p1, gp_Dir(n1x, n1y, n1z));
    Extrema_ExtElSS e(a, gp_Pln(p2, n2));
    printf("%s: IsDone=%d IsParallel=%d NbExt=%d", name, e.IsDone() ? 1 : 0,
           e.IsParallel() ? 1 : 0, e.NbExt());
    if (e.IsParallel() && e.NbExt() >= 1)
      printf(" SquareDistance(1)=%.17g", e.SquareDistance(1));
    printf("\n");
  }
  catch (const Standard_Failure& f)
  {
    printf("%s: threw %s (%s)\n", name, typeid(f).name(), f.what());
  }
}

int main()
{
  linlin("parallelLines", gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0), gp_Pnt(0, 5, 0), gp_Dir(1, 0, 0));
  linlin("intersectingLines", gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0), gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0));
  linlin("skewLines", gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0), gp_Pnt(0, 0, 3), gp_Dir(0, 1, 0));

  linpln("parallelLinePlane", gp_Pnt(0, 0, 10), gp_Dir(1, 0, 0), gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  linpln("intersectingLinePlane", gp_Pnt(0, 0, 10), gp_Dir(0, 0, -1), gp_Pnt(0, 0, 0),
         gp_Dir(0, 0, 1));

  plnpln("oppositeNormalsAreStillParallel", gp_Pnt(0, 0, 0), 0, 0, 1, gp_Pnt(0, 0, 4),
         gp_Dir(0, 0, -1));
  plnpln("coincidentPlanesReportZeroRatherThanNil", gp_Pnt(0, 0, 0), 0, 0, 1, gp_Pnt(4, -9, 0),
         gp_Dir(0, 0, 1));
  plnpln("degenerateNormalIsRefused", gp_Pnt(0, 0, 0), 0, 0, 0, gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1));
  plnpln("Issue1463 parallelPlanesWriteTheDistance", gp_Pnt(0, 0, 0), 0, 0, 1, gp_Pnt(0, 0, 10),
         gp_Dir(0, 0, 1));
  plnpln("Issue1463 crossingPlanesLeaveTheOutParamUntouched", gp_Pnt(0, 0, 0), 0, 0, 1,
         gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  plnpln("Issue1463 refusedInputLeavesTheOutParamUntouched", gp_Pnt(0, 0, 0), 0, 0, 0,
         gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1));
  return 0;
}
