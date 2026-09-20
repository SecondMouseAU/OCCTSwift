#include <GeomConvert.hxx>
#include <GeomFill_Pipe.hxx>
#include <GeomInt_IntSS.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <gp_Ax1.hxx>
#include <cstdio>

int main()
{
  Handle(Geom_Line) line = new Geom_Line(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  try
  {
    Handle(Geom_BSplineCurve) b = GeomConvert::CurveToBSplineCurve(line);
    printf("GeomConvert(Geom_Line) -> ok, null=%d\n", (int)b.IsNull());
  }
  catch (Standard_Failure const& f)
  {
    printf("GeomConvert(Geom_Line) THREW: %s\n", f.GetMessageString() ? f.GetMessageString() : "?");
  }

  // exactly what LocOpe_SplitDrafts does: two planes at an angle, intersect, pipe along a normal
  Handle(Geom_Plane) p1 = new Geom_Plane(gp_Pnt(5, 0, 10), gp_Dir(0, 0, 1));
  Handle(Geom_Plane) p2 = new Geom_Plane(gp_Pnt(5, 0, 10), gp_Dir(0.17, 0, 0.98));
  GeomInt_IntSS      i2s(p1, p2, Precision::Confusion());
  printf("IntSS done=%d nbLines=%d\n", (int)i2s.IsDone(), i2s.IsDone() ? i2s.NbLines() : -1);
  if (i2s.IsDone() && i2s.NbLines() > 0)
  {
    printf("line 1 type: %s\n", i2s.Line(1)->DynamicType()->Name());
    Handle(Geom_Line) axis = new Geom_Line(gp_Ax1(gp_Pnt(5, 0, 10), gp_Dir(0, 0, 1)));
    GeomFill_Pipe     pipe;
    pipe.GenerateParticularCase(true);
    pipe.Init(axis, i2s.Line(1));
    try
    {
      pipe.Perform(true);
      printf("pipe done=%d\n", (int)pipe.IsDone());
    }
    catch (Standard_Failure const& f)
    {
      printf("pipe THREW: %s\n", f.GetMessageString() ? f.GetMessageString() : "?");
    }
  }
  return 0;
}
