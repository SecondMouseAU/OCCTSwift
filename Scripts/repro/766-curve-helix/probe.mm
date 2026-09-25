// Epic #766 (#1978), kernel parity for HelixGeomBuildTests.swift and HelixTests.swift. Same inputs
// and calls as OCCTHelixBuild / OCCTHelixCoilBuild (HelixGeom_BuilderHelix /
// HelixGeom_BuilderHelixCoil, tolerance 1e-3) and OCCTWireCreateHelix / OCCTWireCreateHelixTapered
// (HelixBRep_BuilderHelix with diameters, axis reversed when not clockwise).
#include <BRepAdaptor_CompCurve.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <HelixBRep_BuilderHelix.hxx>
#include <HelixGeom_BuilderHelix.hxx>
#include <HelixGeom_BuilderHelixCoil.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void wire(const char* name, gp_Pnt o, double r1, double r2, double pitch, double turns, bool cw)
{
  gp_Dir d(0, 0, 1);
  if (!cw)
    d.Reverse();
  NCollection_Array1<double> p(1, 1), n(1, 1);
  p(1) = pitch;
  n(1) = turns;
  HelixBRep_BuilderHelix b;
  if (r1 == r2)
    b.SetParameters(gp_Ax3(o, d), r1 * 2, p, n);
  else
    b.SetParameters(gp_Ax3(o, d), r1 * 2, r2 * 2, p, n);
  b.Perform();
  printf("%s: error=%d", name, b.ErrorStatus());
  if (b.ErrorStatus() == 0 && !b.Shape().IsNull())
  {
    BRepAdaptor_CompCurve c(TopoDS::Wire(b.Shape()));
    gp_Pnt a = c.Value(c.FirstParameter()), e = c.Value(c.LastParameter());
    printf(" start=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g) length=%.17g", a.X(), a.Y(), a.Z(),
           e.X(), e.Y(), e.Z(), GCPnts_AbscissaPoint::Length(c));
  }
  printf("\n");
}

static void geom(const char* name, gp_Pnt o, double t1, double t2, double pitch, double r, double taper, bool cw, bool coil)
{
  Handle(Geom_Curve) c;
  double             tol = -1;
  if (coil)
  {
    HelixGeom_BuilderHelixCoil b;
    b.SetCurveParameters(t1, t2, pitch, r, taper, cw);
    b.SetTolerance(1e-3);
    b.Perform();
    tol = b.ToleranceReached();
    if (b.ErrorStatus() == 0 && !b.Curves().IsEmpty())
      c = b.Curves().First();
  }
  else
  {
    HelixGeom_BuilderHelix b;
    b.SetPosition(gp_Ax2(o, gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
    b.SetCurveParameters(t1, t2, pitch, r, taper, cw);
    b.SetTolerance(1e-3);
    b.Perform();
    tol = b.ToleranceReached();
    if (b.ErrorStatus() == 0 && !b.Curves().IsEmpty())
      c = b.Curves().First();
  }
  printf("%s: tolReached=%.6g", name, tol);
  if (!c.IsNull())
  {
    gp_Pnt a = c->Value(c->FirstParameter()), e = c->Value(c->LastParameter());
    printf(" start=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g)", a.X(), a.Y(), a.Z(), e.X(), e.Y(), e.Z());
  }
  printf("\n");
}

int main()
{
  geom("HelixGeom [0, 10] pitch 5 r 10", gp_Pnt(0, 0, 0), 0, 10, 5, 10, 0, false, false);
  geom("HelixGeom [0, 6pi] pitch 5 r 10 taper 5deg cw", gp_Pnt(0, 0, 0), 0, 6 * M_PI, 5, 10, 5 * M_PI / 180, true, false);
  geom("HelixGeom origin (1,2,3) [0, 10] pitch 4 r 8", gp_Pnt(1, 2, 3), 0, 10, 4, 8, 0, false, false);
  geom("HelixGeom coil [0, 8pi] pitch 3 r 5", gp_Pnt(0, 0, 0), 0, 8 * M_PI, 3, 5, 0, false, true);
  wire("Wire.helix r5 p2 t3", gp_Pnt(0, 0, 0), 5, 5, 2, 3, false);
  wire("Wire.helix origin (10,20,30) r10 p5 t2", gp_Pnt(10, 20, 30), 10, 10, 5, 2, false);
  wire("Wire.helix r5 p2 t1 ccw", gp_Pnt(0, 0, 0), 5, 5, 2, 1, false);
  wire("Wire.helix r5 p2 t1 cw", gp_Pnt(0, 0, 0), 5, 5, 2, 1, true);
  wire("Wire.helix r10 p5 t3 (sweep path)", gp_Pnt(0, 0, 0), 10, 10, 5, 3, false);
  wire("Wire.helixTapered r10 -> 3 p4 t4", gp_Pnt(0, 0, 0), 10, 3, 4, 4, false);
  wire("Wire.helix r5 p10 t0.5", gp_Pnt(0, 0, 0), 5, 5, 10, 0.5, false);
  wire("Wire.helix r5 p1 t20", gp_Pnt(0, 0, 0), 5, 5, 1, 20, false);
  return 0;
}
