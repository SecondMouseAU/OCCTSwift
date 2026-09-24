// Epic #766, OCCTDrawingTests/DisplayDrawerTests.swift: kernel parity for all ten tests.
// A fresh Prs3d_Drawer, as OCCTDrawerCreate builds it, driven with the tests' setter values.
#include <Prs3d_Drawer.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  {
    Handle(Prs3d_Drawer) d = new Prs3d_Drawer();
    printf("defaults: autoTriangulation=%d wireDraw=%d faceBoundaryDraw=%d typeOfDeflection=%s "
           "discretisation=%d\n",
           d->IsAutoTriangulation(), d->WireDraw(), d->FaceBoundaryDraw(),
           d->TypeOfDeflection() == Aspect_TOD_RELATIVE ? "relative" : "absolute",
           d->Discretisation());
  }
  Handle(Prs3d_Drawer) d = new Prs3d_Drawer();
  d->SetDeviationCoefficient(0.005);
  printf("deviationCoefficient: %.17g\n", d->DeviationCoefficient());
  d->SetDeviationAngle(10.0 * M_PI / 180.0);
  printf("deviationAngle: %.17g\n", d->DeviationAngle());
  d->SetMaximalChordialDeviation(0.05);
  printf("maxChordialDeviation: %.17g\n", d->MaximalChordialDeviation());
  d->SetTypeOfDeflection(Aspect_TOD_ABSOLUTE);
  int t1 = d->TypeOfDeflection() == Aspect_TOD_ABSOLUTE;
  d->SetTypeOfDeflection(Aspect_TOD_RELATIVE);
  printf("deflectionType: absolute=%d then relative=%d\n", t1,
         d->TypeOfDeflection() == Aspect_TOD_RELATIVE);
  d->SetAutoTriangulation(false);
  printf("autoTriangulation: %d\n", d->IsAutoTriangulation());
  d->SetIsoOnTriangulation(true);
  printf("isoOnTriangulation: %d\n", d->IsoOnTriangulation());
  d->SetDiscretisation(50);
  printf("discretisation: %d\n", d->Discretisation());
  d->SetFaceBoundaryDraw(true);
  printf("faceBoundaryDraw: %d\n", d->FaceBoundaryDraw());
  d->SetWireDraw(false);
  printf("wireDraw: %d\n", d->WireDraw());
  return 0;
}
