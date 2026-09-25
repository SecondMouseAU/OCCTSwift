// #766 kernel parity for Tests/OCCTAnalysisTests/IntAnaPlaneSphereTests.swift
// (planeSphereIntersection). Same construction as OCCTIntAnaPlaneSphere
// (OCCTBridge_Spatial_Intersection.mm).
#include <IntAna_QuadQuadGeo.hxx>
#include <gp_Ax3.hxx>
#include <gp_Circ.hxx>
#include <gp_Pln.hxx>
#include <gp_Sphere.hxx>
#include <cstdio>

int main()
{
  gp_Pln             plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  gp_Sphere          sphere(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
  IntAna_QuadQuadGeo inter(plane, sphere);
  printf("planeSphereIntersection: IsDone=%d NbSolutions=%d TypeInter=%d (IntAna_Circle=%d)\n",
         inter.IsDone() ? 1 : 0, inter.NbSolutions(), (int)inter.TypeInter(), (int)IntAna_Circle);
  if (inter.IsDone() && inter.TypeInter() == IntAna_Circle)
  {
    gp_Circ c = inter.Circle(1);
    printf("  circle 1: center=(%.17g, %.17g, %.17g) axis=(%.17g, %.17g, %.17g) radius=%.17g\n",
           c.Location().X(), c.Location().Y(), c.Location().Z(), c.Axis().Direction().X(),
           c.Axis().Direction().Y(), c.Axis().Direction().Z(), c.Radius());
  }
  return 0;
}
