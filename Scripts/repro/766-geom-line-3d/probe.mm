// #766 kernel parity for Tests/OCCTAnalysisTests/GeomLine3DTests.swift.
// Builds the line the way OCCTCurve3DCreateLine does (Geom_Line(gp_Pnt, gp_Dir)) and reads the
// same accessors the OCCTCurve3DLine* bridge functions read.
#include <Geom_Line.hxx>
#include <gp_Ax1.hxx>
#include <gp_Lin.hxx>
#include <cstdio>

static Handle(Geom_Line) make()
{
  return new Geom_Line(gp_Pnt(1, 2, 3), gp_Dir(1, 0, 0));
}

int main()
{
  gp_Dir d = make()->Lin().Direction();
  printf("lineDirection: direction=(%.17g, %.17g, %.17g)\n", d.X(), d.Y(), d.Z());
  gp_Pnt p = make()->Lin().Location();
  printf("lineLocation: location=(%.17g, %.17g, %.17g)\n", p.X(), p.Y(), p.Z());

  Handle(Geom_Line) l = make();
  l->SetDirection(gp_Dir(0, 1, 0));
  d = l->Lin().Direction();
  printf("lineSetDirection: direction after SetDirection(0,1,0)=(%.17g, %.17g, %.17g)\n", d.X(),
         d.Y(), d.Z());

  l = make();
  l->SetLocation(gp_Pnt(5, 5, 5));
  p = l->Lin().Location();
  printf("lineSetLocation: location after SetLocation(5,5,5)=(%.17g, %.17g, %.17g)\n", p.X(), p.Y(),
         p.Z());

  gp_Ax1 pos = make()->Position();
  printf("linePosition: location=(%.17g, %.17g, %.17g) direction=(%.17g, %.17g, %.17g)\n",
         pos.Location().X(), pos.Location().Y(), pos.Location().Z(), pos.Direction().X(),
         pos.Direction().Y(), pos.Direction().Z());

  gp_Lin gl = make()->Lin();
  printf("lineLin: location=(%.17g, %.17g, %.17g) direction=(%.17g, %.17g, %.17g)\n",
         gl.Location().X(), gl.Location().Y(), gl.Location().Z(), gl.Direction().X(),
         gl.Direction().Y(), gl.Direction().Z());
  return 0;
}
