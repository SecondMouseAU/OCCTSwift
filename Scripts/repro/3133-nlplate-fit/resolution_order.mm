// #3133/#3134/#3135: NLPlate_NLPlate::Evaluate is exact at each constraint and extreme away from it
// for G1 and above (Plate_Plate::SolveTI1 regularises an underdetermined polynomial block with 1e-8).
// Build: clang++ -std=c++17 -ObjC++ -w -I$M/Headers -L$M -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ FILE.mm

#include <Geom_Plane.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG0G1Constraint.hxx>
#include <NLPlate_HPG0G2Constraint.hxx>
#include <NLPlate_NLPlate.hxx>
#include <Plate_D1.hxx>
#include <Plate_D2.hxx>
#include <cstdio>
int main(){
  Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(0,0,0),gp_Dir(0,0,1));
  for(int ord=2; ord<=9; ord++){
    NLPlate_NLPlate s(plane);
    s.Load(new NLPlate_HPG0G1Constraint(gp_XY(0,0),gp_XYZ(0,0,5),Plate_D1(gp_XYZ(1,0,.5),gp_XYZ(0,1,.5))));
    s.Solve2(ord,1);
    printf("G1 single ord %d:",ord);
    double d[]={0,.001,.1,1,5,10};
    for(double t:d){gp_XYZ p=s.Evaluate(gp_XY(t,t)); printf(" %g", p.Z());}
    printf("\n");
  }
  for(int ord=2; ord<=9; ord++){
    NLPlate_NLPlate s(plane);
    s.Load(new NLPlate_HPG0G1Constraint(gp_XY(-2,0),gp_XYZ(-2,0,1),Plate_D1(gp_XYZ(1,0,.2),gp_XYZ(0,1,0))));
    s.Load(new NLPlate_HPG0G1Constraint(gp_XY(2,0),gp_XYZ(2,0,1),Plate_D1(gp_XYZ(1,0,-.2),gp_XYZ(0,1,0))));
    s.Solve2(ord,1);
    printf("G1 dbl ord %d:",ord);
    double d[]={-2,-1,0,1,2,5,10};
    for(double t:d){gp_XYZ p=s.Evaluate(gp_XY(t,0)); printf(" %g", p.Z());}
    gp_XYZ p=s.Evaluate(gp_XY(0,3)); printf(" | (0,3) %g\n",p.Z());
  }
  for(int ord=2; ord<=9; ord++){
    NLPlate_NLPlate s(plane);
    s.Load(new NLPlate_HPG0G2Constraint(gp_XY(.5,.5),gp_XYZ(.5,.5,1),Plate_D1(gp_XYZ(1,0,0),gp_XYZ(0,1,0)),Plate_D2(gp_XYZ(0,0,.1),gp_XYZ(0,0,0),gp_XYZ(0,0,.1))));
    s.Solve2(ord,1);
    printf("G2 ord %d:",ord);
    double d[]={.5,.501,.6,1.5,5,10};
    for(double t:d){gp_XYZ p=s.Evaluate(gp_XY(t,t)); printf(" %g", p.Z());}
    printf("\n");
  }
}
