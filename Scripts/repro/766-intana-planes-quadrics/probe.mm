// #766 kernel parity for Tests/OCCTAnalysisTests/IntAnaLinePlaneTests.swift,
// IntAnaPlanePlaneTests.swift, IntAnaQuadQuadTests.swift and IntAnaThreePlanesTests.swift.
// Mirrors OCCTIntAnaLineQuad, OCCTIntAnaPlanePlane, OCCTIntAnaCylinderSphere(+Identical) and
// OCCTIntAna3Planes in OCCTBridge_Spatial_Intersection.mm, same constructors and tolerances.
#include <IntAna_Int3Pln.hxx>
#include <IntAna_IntConicQuad.hxx>
#include <IntAna_IntQuadQuad.hxx>
#include <IntAna_QuadQuadGeo.hxx>
#include <IntAna_Quadric.hxx>
#include <Precision.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Sphere.hxx>
#include <cstdio>

static void linePlane(const char* name, gp_Pnt lo, gp_Dir ld)
{
  gp_Lin              line(lo, ld);
  gp_Pln              plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  IntAna_IntConicQuad inter(line, plane, Precision::Angular());
  printf("%s: done=%d parallel=%d inQuadric=%d", name, (int)inter.IsDone(),
         (int)inter.IsParallel(), (int)inter.IsInQuadric());
  // NbPoints() raises Standard_DomainError on a parallel pair; OCCTIntAnaLineQuad reads it inside
  // its try, after isParallel/isInQuadric are stored, so its count stays at the zero it was
  // initialised to.
  int n = 0;
  try
  {
    n = inter.NbPoints();
    printf(" nbPoints=%d", n);
  }
  catch (Standard_Failure& e)
  {
    printf(" nbPoints raised Standard_Failure: '%s' (bridge count stays 0)", e.what());
  }
  for (int i = 1; i <= n; i++)
    printf(" point%d=(%.17g, %.17g, %.17g) param=%.17g", i, inter.Point(i).X(), inter.Point(i).Y(),
           inter.Point(i).Z(), inter.ParamOnConic(i));
  printf("\n");
}

static void threePlanes(const char* name, gp_Pnt o1, gp_Pnt o2, gp_Pnt o3)
{
  IntAna_Int3Pln inter(gp_Pln(o1, gp_Dir(1, 0, 0)), gp_Pln(o2, gp_Dir(0, 1, 0)),
                       gp_Pln(o3, gp_Dir(0, 0, 1)));
  gp_Pnt p = inter.Value();
  printf("%s: done=%d empty=%d point=(%.17g, %.17g, %.17g)\n", name, (int)inter.IsDone(),
         (int)inter.IsEmpty(), p.X(), p.Y(), p.Z());
}

int main()
{
  linePlane("linePlaneIntersection", gp_Pnt(0, 0, -5), gp_Dir(0, 0, 1));
  linePlane("parallelLineAndPlane", gp_Pnt(0, 0, 5), gp_Dir(1, 0, 0));
  linePlane("embeddedLineLiesInPlane", gp_Pnt(1, 2, 0), gp_Dir(1, 0, 0));

  {
    gp_Pln             pl1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Pln             pl2(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0));
    IntAna_QuadQuadGeo inter(pl1, pl2, Precision::Angular(), Precision::Confusion());
    printf("planePlane: done=%d nbSolutions=%d typeInter=%d", (int)inter.IsDone(),
           inter.NbSolutions(), (int)inter.TypeInter());
    for (int i = 1; i <= inter.NbSolutions(); i++)
    {
      gp_Lin l = inter.Line(i);
      printf(" line%d origin=(%.17g, %.17g, %.17g) direction=(%.17g, %.17g, %.17g)", i,
             l.Location().X(), l.Location().Y(), l.Location().Z(), l.Direction().X(),
             l.Direction().Y(), l.Direction().Z());
    }
    printf("\n");
  }

  {
    gp_Cylinder    cyl(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3);
    IntAna_Quadric quad;
    quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5));
    IntAna_IntQuadQuad iqq(cyl, quad, 1e-6);
    printf("cylinderSphere: done=%d identical=%d nbCurve=%d\n", (int)iqq.IsDone(),
           (int)iqq.IdenticalElements(), iqq.NbCurve());
  }

  threePlanes("threePlanesAtOrigin", gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 0));
  threePlanes("offsetPlanes", gp_Pnt(1, 0, 0), gp_Pnt(0, 2, 0), gp_Pnt(0, 0, 3));
  return 0;
}
