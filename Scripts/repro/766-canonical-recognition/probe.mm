// Kernel parity probe for Tests/OCCTAnalysisTests/CanonicalRecognitionTests.swift (#1936, #1937).
// Mirrors OCCTShapeRecognizeCanonical: one ShapeAnalysis_CanonicalRecognition over the whole solid,
// IsPlane -> IsCylinder -> IsCone -> IsSphere -> IsLine -> IsCircle -> IsEllipse with ClearStatus()
// between checks, tolerance 1e-4 (recognizeCanonical's default).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <gp_Circ.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Elips.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Sphere.hxx>
#include <cstdio>

static void run(const char* label, const TopoDS_Shape& s)
{
  const double                       tol = 1e-4;
  ShapeAnalysis_CanonicalRecognition r(s);
  gp_Pln                             pln;
  gp_Cylinder                        cyl;
  gp_Cone                            cone;
  gp_Sphere                          sph;
  gp_Lin                             lin;
  gp_Circ                            circ;
  gp_Elips                           el;
  printf("%s: ShapeType=%d\n", label, (int)s.ShapeType());
  bool b = r.IsPlane(tol, pln);
  printf("  IsPlane=%d status=%d\n", (int)b, r.GetStatus());
  r.ClearStatus();
  b = r.IsCylinder(tol, cyl);
  printf("  IsCylinder=%d status=%d\n", (int)b, r.GetStatus());
  r.ClearStatus();
  b = r.IsCone(tol, cone);
  printf("  IsCone=%d status=%d\n", (int)b, r.GetStatus());
  r.ClearStatus();
  b = r.IsSphere(tol, sph);
  printf("  IsSphere=%d status=%d\n", (int)b, r.GetStatus());
  r.ClearStatus();
  b = r.IsLine(tol, lin);
  printf("  IsLine=%d status=%d\n", (int)b, r.GetStatus());
  r.ClearStatus();
  b = r.IsCircle(tol, circ);
  printf("  IsCircle=%d status=%d\n", (int)b, r.GetStatus());
  r.ClearStatus();
  b = r.IsEllipse(tol, el);
  printf("  IsEllipse=%d status=%d\n", (int)b, r.GetStatus());
}

int main()
{
  run("box solid 10x10x10", BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape());
  run("cylinder solid r=5 h=10", BRepPrimAPI_MakeCylinder(5, 10).Shape());
  return 0;
}
