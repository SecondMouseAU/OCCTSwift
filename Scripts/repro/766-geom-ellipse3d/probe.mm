// Kernel-parity probe for Tests/OCCTAnalysisTests/GeomEllipse3DTests.swift (#1722-#1728).
// Builds the same Geom_Ellipse the tests build through OCCTCurve3DCreateEllipse
// (gp_Ax2(origin, +Z), major 10, minor 5) and prints every value the tests read.
#include <Geom_Ellipse.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <cstdio>

int main()
{
  gp_Ax2               axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_Ellipse) e = new Geom_Ellipse(axis, 10, 5);

  printf("ellipseRadii: major=%.17g minor=%.17g\n", e->MajorRadius(), e->MinorRadius());
  printf("ellipseEccentricity: %.17g\n", e->Eccentricity());
  printf("ellipseFocal: %.17g\n", e->Focal());
  gp_Pnt f1 = e->Focus1(), f2 = e->Focus2();
  printf("ellipseFoci: focus1=(%.17g, %.17g, %.17g) focus2=(%.17g, %.17g, %.17g)\n",
         f1.X(), f1.Y(), f1.Z(), f2.X(), f2.Y(), f2.Z());
  printf("ellipseParameter: %.17g\n", e->Parameter());
  gp_Ax1 d = e->Directrix1();
  printf("ellipseDirectrix1: loc=(%.17g, %.17g, %.17g) dir=(%.17g, %.17g, %.17g)\n",
         d.Location().X(), d.Location().Y(), d.Location().Z(),
         d.Direction().X(), d.Direction().Y(), d.Direction().Z());

  // ellipseSetRadii: SetMajorRadius(20) then SetMinorRadius(8), as the bridge does after its
  // occtValidEllipseRadii check (both pairs pass it).
  e->SetMajorRadius(20);
  printf("ellipseSetRadii: after SetMajorRadius(20) major=%.17g\n", e->MajorRadius());
  e->SetMinorRadius(8);
  printf("ellipseSetRadii: after SetMinorRadius(8) minor=%.17g\n", e->MinorRadius());
  return 0;
}
