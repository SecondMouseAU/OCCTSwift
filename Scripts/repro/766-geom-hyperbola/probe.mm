// Epic #766, Tests/OCCTAnalysisTests/GeomHyperbola3DTests.swift: kernel parity probe.
// OCCTCurve3DCreateHyperbola builds Geom_Hyperbola(gp_Ax2(center, normal), major, minor); the
// OCCTCurve3DHyperbola* accessors read the Geom_Hyperbola methods printed here.
#include <Geom_Hyperbola.hxx>
#include <gp_Ax2.hxx>
#include <cstdio>

int main()
{
  gp_Ax2                 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_Hyperbola) h = new Geom_Hyperbola(axis, 5, 3);
  printf("hyperbolaRadii MajorRadius=%.17g MinorRadius=%.17g\n", h->MajorRadius(), h->MinorRadius());
  printf("hyperbolaEccentricity Eccentricity=%.17g\n", h->Eccentricity());
  printf("hyperbolaFocal Focal=%.17g\n", h->Focal());
  gp_Pnt f = h->Focus1();
  printf("hyperbolaFocus1 Focus1=(%.17g, %.17g, %.17g)\n", f.X(), f.Y(), f.Z());
  gp_Ax1 a = h->Asymptote1();
  printf("hyperbolaAsymptote1 location=(%.17g, %.17g, %.17g) direction=(%.17g, %.17g, %.17g)\n",
         a.Location().X(), a.Location().Y(), a.Location().Z(),
         a.Direction().X(), a.Direction().Y(), a.Direction().Z());

  Handle(Geom_Hyperbola) s = new Geom_Hyperbola(axis, 5, 3);
  s->SetMajorRadius(8);
  printf("hyperbolaSetRadii after SetMajorRadius(8) MajorRadius=%.17g\n", s->MajorRadius());
  s->SetMinorRadius(4);
  printf("hyperbolaSetRadii after SetMinorRadius(4) MinorRadius=%.17g\n", s->MinorRadius());
  return 0;
}
