// #766 kernel parity for Tests/OCCTAnalysisTests/GPropElementTests.swift (and the one
// GPropWeightedTests case this PR covers). Same OCCT calls, same inputs, as
// OCCTGPropLineSegment / OCCTGPropCircularArc / OCCTGPropPointSetCentroid /
// OCCTGPropSphereSurface / OCCTGPropSphereVolume in OCCTBridge_Properties.mm.
#include <GProp_CelGProps.hxx>
#include <GProp_PGProps.hxx>
#include <GProp_SelGProps.hxx>
#include <GProp_VelGProps.hxx>
#include <NCollection_Array1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Circ.hxx>
#include <gp_Lin.hxx>
#include <gp_Sphere.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  {
    gp_Pnt          p1(0, 0, 0), p2(10, 0, 0);
    gp_Lin          line(p1, gp_Dir(gp_Vec(p1, p2)));
    GProp_CelGProps props(line, 0.0, p1.Distance(p2), gp_Pnt(0, 0, 0));
    gp_Pnt          cm = props.CentreOfMass();
    printf("lineSegmentLength: length=%.17g center=(%.17g, %.17g, %.17g)\n",
           props.Mass(), cm.X(), cm.Y(), cm.Z());
  }
  {
    gp_Ax2          ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GProp_CelGProps props(gp_Circ(ax, 1.0), 0.0, M_PI, gp_Pnt(0, 0, 0));
    gp_Pnt          cm = props.CentreOfMass();
    printf("circularArcLength: arcLength=%.17g center=(%.17g, %.17g, %.17g)\n",
           props.Mass(), cm.X(), cm.Y(), cm.Z());
  }
  {
    NCollection_Array1<gp_Pnt> pts(1, 4);
    pts(1) = gp_Pnt(0, 0, 0);
    pts(2) = gp_Pnt(10, 0, 0);
    pts(3) = gp_Pnt(10, 10, 0);
    pts(4) = gp_Pnt(0, 10, 0);
    GProp_PGProps props(pts);
    gp_Pnt        cm = props.CentreOfMass();
    printf("pointSetCentroid: mass=%.17g centroid=(%.17g, %.17g, %.17g)\n",
           props.Mass(), cm.X(), cm.Y(), cm.Z());
  }
  {
    gp_Sphere       s(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
    GProp_SelGProps a(s, 0, 2 * M_PI, -M_PI / 2, M_PI / 2, gp_Pnt(0, 0, 0));
    GProp_VelGProps v(s, 0, 2 * M_PI, -M_PI / 2, M_PI / 2, gp_Pnt(0, 0, 0));
    printf("sphereSurfaceArea: area=%.17g (4*pi*25=%.17g)\n", a.Mass(), 4 * M_PI * 25);
    printf("sphereVolume: volume=%.17g (4/3*pi*125=%.17g)\n", v.Mass(), 4.0 / 3.0 * M_PI * 125);
  }
  // weightedCentroidLengthMismatchIsRejected: the length check is a Swift precondition in
  // GeometryProperties.weightedCentroid; no OCCT call is made for a mismatched pair, so there is
  // no kernel value to compare.
  printf("weightedCentroidLengthMismatchIsRejected: N/A (rejected in Swift before the bridge)\n");
  return 0;
}
