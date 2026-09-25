// Epic #766 (#1978), kernel parity for Issue485Curve3DContinuityTests, Issue486Curve3DBatchTests and
// Issue490ContinuityDecoderTests: GeomAbs_Shape ordinals from Geom_Curve::Continuity() on the G1
// offset fixture, a line and a circle; ShapeUpgrade_SplitCurve3dContinuity on the six-point
// interpolation at C2, C3 and CN; and GeomConvert_ApproxCurve at C0...C3.
#include <GeomAPI_Interpolate.hxx>
#include <GeomConvert_ApproxCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_OffsetCurve.hxx>
#include <ShapeUpgrade_SplitCurve3dContinuity.hxx>
#include <TColGeom_HArray1OfCurve.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cstdio>

int main()
{
  printf("GeomAbs ordinals: C0 %d G1 %d C1 %d G2 %d C2 %d C3 %d CN %d\n", GeomAbs_C0, GeomAbs_G1, GeomAbs_C1,
         GeomAbs_G2, GeomAbs_C2, GeomAbs_C3, GeomAbs_CN);
  TColgp_Array1OfPnt p(1, 7);
  gp_Pnt             pp[] = {gp_Pnt(0, 0, 0), gp_Pnt(1, 1, 0), gp_Pnt(2, 0, 0), gp_Pnt(3, 0, 0),
                             gp_Pnt(5, 0, 0), gp_Pnt(6, 1, 0), gp_Pnt(7, 0, 0)};
  for (int i = 0; i < 7; i++)
    p(i + 1) = pp[i];
  TColStd_Array1OfReal    k(1, 3);
  TColStd_Array1OfInteger m(1, 3);
  k(1) = 0; k(2) = 0.5; k(3) = 1;
  m(1) = 4; m(2) = 3; m(3) = 4;
  Handle(Geom_BSplineCurve) basis = new Geom_BSplineCurve(p, k, m, 3);
  Handle(Geom_OffsetCurve)  off   = new Geom_OffsetCurve(basis, 1.0, gp_Dir(0, 0, 1));
  printf("G1 fixture: basis continuity %d, offset continuity %d\n", basis->Continuity(), off->Continuity());
  printf("line %d circle %d\n", (new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)))->Continuity(),
         (new Geom_Circle(gp_Ax2(), 10))->Continuity());

  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, 6);
  gp_Pnt q[] = {gp_Pnt(0, 0, 0), gp_Pnt(1, 2, 0), gp_Pnt(3, 1, 1), gp_Pnt(5, 3, 0), gp_Pnt(7, 0, 2), gp_Pnt(9, 2, 1)};
  for (int i = 0; i < 6; i++)
    a->SetValue(i + 1, q[i]);
  GeomAPI_Interpolate ip(a, false, 1e-7);
  ip.Perform();
  Handle(Geom_BSplineCurve) c = ip.Curve();
  printf("six-point interpolation: degree %d knots %d continuity %d\n", c->Degree(), c->NbKnots(), c->Continuity());
  for (GeomAbs_Shape s : {GeomAbs_C2, GeomAbs_C3, GeomAbs_CN})
  {
    ShapeUpgrade_SplitCurve3dContinuity sp;
    sp.Init(c);
    sp.SetCriterion(s);
    sp.SetTolerance(1e-6);
    sp.Perform();
    Handle(TColGeom_HArray1OfCurve) r = sp.GetCurves();
    printf("  split at criterion %d -> %d pieces\n", (int)s, r.IsNull() ? 0 : r->Length());
  }
  for (GeomAbs_Shape s : {GeomAbs_C0, GeomAbs_C1, GeomAbs_C2, GeomAbs_C3})
  {
    try
    {
      GeomConvert_ApproxCurve ap(c, 1e-3, s, 100, 8);
      printf("  GeomConvert_ApproxCurve %d: HasResult %d\n", (int)s, ap.HasResult());
    }
    catch (Standard_Failure& e)
    {
      printf("  GeomConvert_ApproxCurve %d: throws %s\n", (int)s, e.what());
    }
  }
  return 0;
}
