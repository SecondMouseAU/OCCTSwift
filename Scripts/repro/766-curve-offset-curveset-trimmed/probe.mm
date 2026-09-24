// Epic #766 (#1978), kernel parity for GeomOffsetCurveTests.swift, GeomToolsCurveSetTests.swift and
// GeomTrimmedCurveTests.swift. Same inputs as the tests: Geom_OffsetCurve on the X axis,
// GeomTools_CurveSet Write/Read, Geom_TrimmedCurve BasisCurve/SetTrim.
#include <GeomTools_CurveSet.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_OffsetCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <cstdio>
#include <sstream>

int main()
{
  Handle(Geom_Line)        line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  Handle(Geom_OffsetCurve) oc   = new Geom_OffsetCurve(line, 5.0, gp_Dir(0, 0, 1));
  gp_Pnt                   p    = oc->Value(0);
  printf("offset of X axis by 5 along (0,0,1): Offset=%g Direction=(%g, %g, %g) value(0)=(%g, %g, %g)\n",
         oc->Offset(), oc->Direction().X(), oc->Direction().Y(), oc->Direction().Z(), p.X(), p.Y(), p.Z());

  Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1)), 7);
  GeomTools_CurveSet  cs;
  cs.Add(line);
  cs.Add(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5));
  std::ostringstream o;
  cs.Write(o);
  GeomTools_CurveSet rs;
  std::istringstream i(o.str());
  rs.Read(i);
  printf("CurveSet write/read of line + circle: %d chars, curve 2 is %s\n", (int)o.str().size(),
         rs.Curve(2)->DynamicType()->Name());
  GeomTools_CurveSet c1;
  c1.Add(circ);
  std::ostringstream o1;
  c1.Write(o1);
  GeomTools_CurveSet r1;
  std::istringstream i1(o1.str());
  r1.Read(i1);
  gp_Pnt q = r1.Curve(1)->Value(0);
  printf("circle (1,2,3) r=7 round trip: value(0)=(%g, %g, %g)\n", q.X(), q.Y(), q.Z());
  GeomTools_CurveSet d;
  int a = d.Add(line), b = d.Add(line);
  printf("adding one curve twice: indices %d and %d (deduplicated)\n", a, b);

  Handle(Geom_TrimmedCurve) t = new Geom_TrimmedCurve(line, 2, 8);
  printf("trim [2, 8]: start (%g, %g, %g) end (%g, %g, %g); basis %s domain [%g, %g]\n",
         t->StartPoint().X(), t->StartPoint().Y(), t->StartPoint().Z(), t->EndPoint().X(),
         t->EndPoint().Y(), t->EndPoint().Z(), t->BasisCurve()->DynamicType()->Name(),
         t->BasisCurve()->FirstParameter(), t->BasisCurve()->LastParameter());
  Handle(Geom_TrimmedCurve) u = new Geom_TrimmedCurve(line, 0, 10);
  u->SetTrim(3, 7);
  printf("trim [0, 10] then SetTrim(3, 7): start (%g, %g, %g) end (%g, %g, %g)\n", u->StartPoint().X(),
         u->StartPoint().Y(), u->StartPoint().Z(), u->EndPoint().X(), u->EndPoint().Y(), u->EndPoint().Z());
  return 0;
}
