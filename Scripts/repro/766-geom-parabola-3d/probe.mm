// #766 kernel parity for Tests/OCCTAnalysisTests/GeomParabola3DTests.swift.
// Builds the parabola the way OCCTCurve3DCreateParabola does (Geom_Parabola on
// gp_Ax2(center, normal), focal) and reads the same accessors the OCCTCurve3DParabola* bridge
// functions read.
#include <Geom_Parabola.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <cstdio>

static Handle(Geom_Parabola) make()
{
  return new Geom_Parabola(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3);
}

int main()
{
  printf("parabolaFocal: focal=%.17g\n", make()->Focal());
  Handle(Geom_Parabola) p = make();
  p->SetFocal(5);
  printf("parabolaSetFocal: focal after SetFocal(5)=%.17g\n", p->Focal());
  gp_Pnt f = make()->Focus();
  printf("parabolaFocus: focus=(%.17g, %.17g, %.17g)\n", f.X(), f.Y(), f.Z());
  printf("parabolaEccentricity: eccentricity=%.17g\n", make()->Eccentricity());
  printf("parabolaParameter: parameter=%.17g\n", make()->Parameter());
  gp_Ax1 d = make()->Directrix();
  printf("parabolaDirectrix: position=(%.17g, %.17g, %.17g) direction=(%.17g, %.17g, %.17g)\n",
         d.Location().X(), d.Location().Y(), d.Location().Z(), d.Direction().X(),
         d.Direction().Y(), d.Direction().Z());
  return 0;
}
