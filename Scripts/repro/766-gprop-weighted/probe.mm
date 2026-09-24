// Epic #766, Tests/OCCTAnalysisTests/GPropWeightedTests.swift: kernel parity probe.
// OCCTGPropPointSetWeightedCentroid and OCCTGPropBarycentre both accumulate into GProp_PGProps
// (AddPoint(p, w) and AddPoint(p) respectively) and read Mass() and CentreOfMass().
#include <GProp_PGProps.hxx>
#include <cstdio>

int main()
{
  {
    GProp_PGProps props;
    props.AddPoint(gp_Pnt(0, 0, 0), 1.0);
    props.AddPoint(gp_Pnt(10, 0, 0), 3.0);
    gp_Pnt cm = props.CentreOfMass();
    printf("weightedCentroid Mass=%.17g CentreOfMass=(%.17g, %.17g, %.17g)\n",
           props.Mass(), cm.X(), cm.Y(), cm.Z());
  }
  {
    GProp_PGProps props;
    props.AddPoint(gp_Pnt(0, 0, 0));
    props.AddPoint(gp_Pnt(10, 0, 0));
    props.AddPoint(gp_Pnt(0, 10, 0));
    gp_Pnt cm = props.CentreOfMass();
    printf("barycentre Mass=%.17g CentreOfMass=(%.17g, %.17g, %.17g)\n",
           props.Mass(), cm.X(), cm.Y(), cm.Z());
  }
  return 0;
}
