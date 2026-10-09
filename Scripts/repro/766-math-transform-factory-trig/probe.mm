// Epic #766 kernel-parity probe for TransformFactory3DTests.swift and TrigRootsTests.swift.
// Same OCCT calls, same inputs, as OCCTMakeMirrorPoint/Axis/Plane, OCCTMakeRotation,
// OCCTMakeScaleTransform, OCCTMakeTranslationVec/Points (gce_Make* + _storeTrsf row-major 3x4,
// OCCTBridge_Modeling_Transform.mm), applied to the test point the way
// TransformMatrix3D.apply(to:) does, and OCCTTrigRoots / OCCTTrigRootsInfinite
// (math_TrigonometricFunctionRoots, OCCTBridge_Spatial_MathSolvers.mm).
#include <gce_MakeMirror.hxx>
#include <gce_MakeRotation.hxx>
#include <gce_MakeScale.hxx>
#include <gce_MakeTranslation.hxx>
#include <gp_Ax1.hxx>
#include <gp_Pln.hxx>
#include <gp_Trsf.hxx>
#include <math_TrigonometricFunctionRoots.hxx>
#include <cmath>
#include <cstdio>

static void apply(const char* name, const gp_Trsf& t, double x, double y, double z)
{
  double m[12];
  for (int r = 1; r <= 3; r++)
    for (int c = 1; c <= 4; c++)
      m[(r - 1) * 4 + (c - 1)] = t.Value(r, c);
  double px = m[0] * x + m[1] * y + m[2] * z + m[3];
  double py = m[4] * x + m[5] * y + m[6] * z + m[7];
  double pz = m[8] * x + m[9] * y + m[10] * z + m[11];
  printf("%s: (%g, %g, %g) -> (%.17g, %.17g, %.17g)\n", name, x, y, z, px, py, pz);
}

static void trig(const char* name, double A, double B, double C, double D, double E)
{
  math_TrigonometricFunctionRoots s(A, B, C, D, E, 0, 2 * M_PI);
  printf("%s: done=%d infinite=%d", name, s.IsDone(), s.IsDone() ? s.InfiniteRoots() : -1);
  if (s.IsDone() && !s.InfiniteRoots())
  {
    printf(" n=%d roots=[", s.NbSolutions());
    for (int i = 1; i <= s.NbSolutions(); i++)
      printf(" %.17g", s.Value(i));
    printf(" ]");
  }
  printf("\n");
}

int main()
{
  apply("pointMirror", gce_MakeMirror(gp_Pnt(0, 0, 0)).Value(), 1, 2, 3);
  apply("planeMirror", gce_MakeMirror(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))).Value(), 1, 2, 3);
  apply("rotation90",
        gce_MakeRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 2).Value(), 1, 0, 0);
  apply("scaleBy2", gce_MakeScale(gp_Pnt(0, 0, 0), 2).Value(), 1, 2, 3);
  apply("translationVector", gce_MakeTranslation(gp_Vec(10, 20, 30)).Value(), 1, 2, 3);
  apply("translationPoints", gce_MakeTranslation(gp_Pnt(0, 0, 0), gp_Pnt(5, 5, 5)).Value(), 1, 1, 1);
  apply("axisMirror", gce_MakeMirror(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))).Value(), 1, 2, 3);

  // math_TrigonometricFunctionRoots solves a cos^2 x + 2b cos x sin x + c cos x + d sin x + e = 0
  // on [0, 2pi]; the Swift labels a..e map straight onto A..E.
  trig("sinZero (d = 1)", 0, 0, 0, 1, 0);
  trig("cosHalf (c = 1, e = -0.5)", 0, 0, 1, 0, -0.5);
  trig("infiniteRoots (all zero)", 0, 0, 0, 0, 0);
  return 0;
}
