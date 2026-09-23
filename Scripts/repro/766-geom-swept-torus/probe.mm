// #766 kernel parity for Tests/OCCTAnalysisTests/GeomSwept3DTests.swift and
// GeomTorus3DTests.swift. Builds the surfaces the way OCCTSurfaceCreateExtrusion and
// OCCTSurfaceCreateTorus do and reads the accessors OCCTSurfaceSwept* / OCCTSurfaceTorus* read.
#include <Geom_Line.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <gp_Ax3.hxx>
#include <gp_Lin.hxx>
#include <cmath>
#include <cstdio>

static Handle(Geom_ToroidalSurface) torus()
{
  return new Geom_ToroidalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10, 2);
}

int main()
{
  Handle(Geom_Line)                     line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  Handle(Geom_SurfaceOfLinearExtrusion) ext =
    new Geom_SurfaceOfLinearExtrusion(line, gp_Dir(0, 0, 1));
  gp_Dir d = ext->Direction();
  printf("sweptDirection: direction=(%.17g, %.17g, %.17g)\n", d.X(), d.Y(), d.Z());
  Handle(Geom_Curve) basis = ext->BasisCurve();
  Handle(Geom_Line)  bl    = Handle(Geom_Line)::DownCast(basis);
  if (bl.IsNull())
    printf("sweptBasisCurve: basis is not a Geom_Line (%s)\n", basis->DynamicType()->Name());
  else
  {
    gp_Lin l = bl->Lin();
    printf("sweptBasisCurve: Geom_Line location=(%.17g, %.17g, %.17g) direction=(%.17g, %.17g, "
           "%.17g) same handle as profile=%d\n",
           l.Location().X(), l.Location().Y(), l.Location().Z(), l.Direction().X(),
           l.Direction().Y(), l.Direction().Z(), (int)(basis == line));
  }

  printf("torusRadii: major=%.17g minor=%.17g\n", torus()->MajorRadius(), torus()->MinorRadius());
  Handle(Geom_ToroidalSurface) t = torus();
  t->SetMajorRadius(15);
  double maj = t->MajorRadius();
  t->SetMinorRadius(3);
  printf("torusSetRadii: major after SetMajorRadius(15)=%.17g minor after SetMinorRadius(3)=%.17g\n",
         maj, t->MinorRadius());
  printf("torusArea: area=%.17g (4*pi^2*R*r=%.17g)\n", torus()->Area(), 4 * M_PI * M_PI * 10 * 2);
  printf("torusVolume: volume=%.17g (2*pi^2*R*r^2=%.17g)\n", torus()->Volume(),
         2 * M_PI * M_PI * 10 * 4);
  return 0;
}
