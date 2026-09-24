// Epic #766 kernel-parity probe for QuaternionInterpolationTests.swift and QuaternionTests.swift.
// Same OCCT calls, same inputs, as OCCTQuaternionSLerp, OCCTQuaternionNLerp, OCCTTrsfInterpolate
// (OCCTBridge_Spatial_GeometryUtils.mm) and the OCCTQuaternion* functions
// (OCCTBridge_Curve3D_Curves.mm).
#include <NCollection_Lerp.hxx>
#include <gp_EulerSequence.hxx>
#include <gp_Mat.hxx>
#include <gp_Quaternion.hxx>
#include <gp_QuaternionNLerp.hxx>
#include <gp_QuaternionSLerp.hxx>
#include <gp_Trsf.hxx>
#include <gp_TrsfNLerp.hxx>
#include <gp_Vec.hxx>
#include <cmath>
#include <cstdio>

static void pq(const char* name, const gp_Quaternion& q)
{
  printf("%s: (x, y, z, w) = (%.17g, %.17g, %.17g, %.17g)\n", name, q.X(), q.Y(), q.Z(), q.W());
}

static void pv(const char* name, const gp_Vec& v)
{
  printf("%s: (%.17g, %.17g, %.17g)\n", name, v.X(), v.Y(), v.Z());
}

static gp_Trsf trsfOf(double tx, double ty, double tz, const gp_Quaternion& q)
{
  gp_Mat  m = q.GetMatrix();
  gp_Trsf tr;
  tr.SetValues(m(1, 1), m(1, 2), m(1, 3), tx, m(2, 1), m(2, 2), m(2, 3), ty, m(3, 1), m(3, 2),
               m(3, 3), tz);
  return tr;
}

int main()
{
  gp_Quaternion id(0, 0, 0, 1);
  gp_Quaternion z90(0, 0, sin(M_PI / 4), cos(M_PI / 4));
  pq("slerpMidpoint", gp_QuaternionSLerp::Interpolate(id, z90, 0.5));
  gp_Quaternion n0 = gp_QuaternionNLerp::Interpolate(id, z90, 0.0);
  n0.Normalize();
  pq("nlerpEndpoints t=0", n0);

  NCollection_Lerp<gp_Trsf> lerp(trsfOf(0, 0, 0, id), trsfOf(10, 0, 0, id));
  gp_Trsf                   r;
  lerp.Interpolate(0.5, r);
  gp_XYZ tp = r.TranslationPart();
  printf("transformInterpolate: translation (%.17g, %.17g, %.17g)\n", tp.X(), tp.Y(), tp.Z());
  pq("transformInterpolate rotation", r.GetRotation());

  gp_Quaternion q0;
  pq("identity (default)", q0);
  gp_Quaternion ident(0, 0, 0, 1);
  pq("identity Quaternion() = (0, 0, 0, 1)", ident);

  gp_Quaternion aa(gp_Vec(0, 0, 1), M_PI / 2);
  pv("fromAxisAngle rotate (1,0,0)", aa.Multiply(gp_Vec(1, 0, 0)));

  gp_Quaternion fv(gp_Vec(1, 0, 0), gp_Vec(0, 1, 0));
  pv("fromVectors rotate (1,0,0)", fv.Multiply(gp_Vec(1, 0, 0)));

  gp_Quaternion eu(0, 0, 0, 1);
  eu.SetEulerAngles((gp_EulerSequence)8, M_PI / 4, 0, 0);
  double a, b, g;
  eu.GetEulerAngles((gp_EulerSequence)8, a, b, g);
  printf("eulerAngles: order 8 (gp_Intrinsic_XYZ=%d) alpha=%.17g beta=%.17g gamma=%.17g\n",
         (int)gp_Intrinsic_XYZ, a, b, g);

  gp_Mat m = aa.GetMatrix();
  printf("matrix: [");
  for (int i = 1; i <= 3; i++)
    for (int j = 1; j <= 3; j++)
      printf(" %.17g", m.Value(i, j));
  printf(" ]\n");

  gp_Quaternion q45(gp_Vec(0, 0, 1), M_PI / 4);
  pv("multiply rotate (1,0,0)", q45.Multiplied(q45).Multiply(gp_Vec(1, 0, 0)));

  gp_Quaternion q30(gp_Vec(0, 0, 1), M_PI / 6);
  gp_Vec        ax;
  double        ang;
  q30.GetVectorAndAngle(ax, ang);
  printf("axisAngle: axis (%.17g, %.17g, %.17g) angle %.17g (pi/6 = %.17g)\n", ax.X(), ax.Y(),
         ax.Z(), ang, M_PI / 6);

  gp_Quaternion q60(gp_Vec(0, 0, 1), M_PI / 3);
  printf("rotationAngle: %.17g (pi/3 = %.17g)\n", q60.GetRotationAngle(), M_PI / 3);

  gp_Quaternion qn(1, 2, 3, 4);
  qn.Normalize();
  pq("normalize", qn);
  printf("normalize: norm %.17g\n", qn.Norm());
  return 0;
}
