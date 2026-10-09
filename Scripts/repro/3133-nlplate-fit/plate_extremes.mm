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
#include <Standard_Failure.hxx>
#include <cstdio>
static void dump(const char* n, NLPlate_NLPlate& s){
  printf("%s done=%d\n",n,s.IsDone());
  double mn=1e300,mx=-1e300;
  for(double v=-15;v<=15.01;v+=3){ for(double u=-15;u<=15.01;u+=3){ gp_XYZ p=s.Evaluate(gp_XY(u,v)); printf("%9.3g ",p.Z()); mn=fmin(mn,p.Z());mx=fmax(mx,p.Z());} printf("\n");}
  gp_XYZ p=s.Evaluate(gp_XY(0.5,0.5)); printf("at .5,.5 %g %g %g ; (0,0): ",p.X(),p.Y(),p.Z());
  p=s.Evaluate(gp_XY(0,0)); printf("%g %g %g\n",p.X(),p.Y(),p.Z());
}
int main(){
  Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(0,0,0),gp_Dir(0,0,1));
  { NLPlate_NLPlate s(plane);
    s.Load(new NLPlate_HPG0G1Constraint(gp_XY(0,0),gp_XYZ(0,0,5),Plate_D1(gp_XYZ(1,0,.5),gp_XYZ(0,1,.5))));
    s.Solve2(4,1); dump("G1 single",s);}
  { NLPlate_NLPlate s(plane);
    s.Load(new NLPlate_HPG0G1Constraint(gp_XY(-2,0),gp_XYZ(-2,0,1),Plate_D1(gp_XYZ(1,0,.2),gp_XYZ(0,1,0))));
    s.Load(new NLPlate_HPG0G1Constraint(gp_XY(2,0),gp_XYZ(2,0,1),Plate_D1(gp_XYZ(1,0,-.2),gp_XYZ(0,1,0))));
    s.Solve2(8,1); dump("G1 double",s);}
  { NLPlate_NLPlate s(plane);
    s.Load(new NLPlate_HPG0G2Constraint(gp_XY(.5,.5),gp_XYZ(.5,.5,1),Plate_D1(gp_XYZ(1,0,0),gp_XYZ(0,1,0)),Plate_D2(gp_XYZ(0,0,.1),gp_XYZ(0,0,0),gp_XYZ(0,0,.1))));
    s.Solve2(2,1); dump("G2",s);}
}
