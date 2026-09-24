// Epic #766 kernel-parity probe: LineGeometryTests, LogSampleTests, MathCroutTests.
// Calls the same OCCT API with the same inputs as the bridge functions the tests reach:
// OCCTLineDistanceToPoint / OCCTLineDistanceToLine / OCCTLineContainsPoint (gp_Lin),
// OCCTLogSample (GeomLib_LogSample), OCCTMathCroutSolve / OCCTMathCroutDeterminant (math_Crout).
#include <gp_Lin.hxx>
#include <gp_Pnt.hxx>
#include <gp_Dir.hxx>
#include <GeomLib_LogSample.hxx>
#include <math_Crout.hxx>
#include <math_Matrix.hxx>
#include <math_Vector.hxx>
#include <cstdio>

int main()
{
  gp_Lin x(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  printf("distanceToPointOnLine: %.17g\n", x.Distance(gp_Pnt(5, 0, 0)));
  printf("distanceToPointOffLine: %.17g\n", x.Distance(gp_Pnt(5, 3, 0)));
  printf("distanceBetweenParallelLines: %.17g\n",
         x.Distance(gp_Lin(gp_Pnt(0, 4, 0), gp_Dir(1, 0, 0))));
  printf("distanceBetweenIntersectingLines: %.17g\n",
         x.Distance(gp_Lin(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0))));
  printf("containsPointTrue: %d\n", (int)x.Contains(gp_Pnt(100, 0, 0), 1e-7));
  printf("containsPointFalse: %d\n", (int)x.Contains(gp_Pnt(0, 1, 0), 1e-7));

  {
    GeomLib_LogSample s(1, 100, 5);
    printf("logarithmicSampling:");
    for (int i = 1; i <= 5; i++)
      printf(" %.17g", s.GetParameter(i));
    printf("\n");
  }
  {
    GeomLib_LogSample s(1, 10, 1);
    printf("singleSample: %.17g\n", s.GetParameter(1));
  }

  {
    math_Matrix A(1, 2, 1, 2, 0.0);
    A(1, 1) = 4; A(1, 2) = 2; A(2, 1) = 2; A(2, 2) = 3;
    math_Crout crout(A);
    math_Vector B(1, 2, 0.0), X(1, 2, 0.0);
    B(1) = 8; B(2) = 7;
    crout.Solve(B, X);
    printf("symmetricSolve: done=%d x=%.17g %.17g\n", (int)crout.IsDone(), X(1), X(2));
    printf("determinant (Crout): %.17g\n", crout.Determinant());
  }
  return 0;
}
