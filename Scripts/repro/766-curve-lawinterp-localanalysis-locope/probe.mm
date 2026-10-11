// Epic #766 (#1978), kernel parity for LawInterpolateTests, LocalAnalysisCurveContinuityTests and
// LocOpeCurveShapeIntersectorTests: Law_Interpolate on [0, 1, 4, 1, 0] with and without explicit
// parameters; LocalAnalysis_CurveContinuity's metrics on the smooth-junction and sharp-corner
// fixtures; LocOpe_CurveShapeIntersector for the line x = y = 5 through the centred 10 box.
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <LocOpe_CurveShapeIntersector.hxx>
#include <LocOpe_PntFace.hxx>
#include <LocalAnalysis_CurveContinuity.hxx>
#include <Law_BSpline.hxx>
#include <Law_Interpolate.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <NCollection_HArray1.hxx>
#include <cstdio>

static Handle(Geom_Curve) fit(gp_Pnt a, gp_Pnt b, gp_Pnt c)
{
  TColgp_Array1OfPnt p(1, 3);
  p(1) = a; p(2) = b; p(3) = c;
  return GeomAPI_PointsToBSpline(p, 3, 8, GeomAbs_C2, 1e-3).Curve();
}

int main()
{
  Handle(NCollection_HArray1<double>) v = new NCollection_HArray1<double>(1, 5);
  double vals[] = {0, 1, 4, 1, 0};
  for (int i = 0; i < 5; i++)
    v->SetValue(i + 1, vals[i]);
  Law_Interpolate a(v, false, 1e-6);
  a.Perform();
  Handle(Law_BSpline) la = a.Curve();
  double f = la->FirstParameter(), l = la->LastParameter();
  printf("interpolate default params: [%.12g, %.12g] values at 0, 1/4, 1/2, 1: %.9g %.9g %.9g %.9g\n", f, l, la->Value(f),
         la->Value(f + (l - f) / 4), la->Value(f + (l - f) / 2), la->Value(l));
  Handle(NCollection_HArray1<double>) pr = new NCollection_HArray1<double>(1, 5);
  for (int i = 0; i < 5; i++)
    pr->SetValue(i + 1, i * 0.25);
  Law_Interpolate b(v, pr, false, 1e-6);
  b.Perform();
  Handle(Law_BSpline) lb = b.Curve();
  printf("interpolate params 0..1: values at 0.25, 0.5: %.9g %.9g\n", lb->Value(0.25), lb->Value(0.5));

  Handle(Geom_Curve) s1 = fit(gp_Pnt(0, 0, 0), gp_Pnt(2.5, 1, 0), gp_Pnt(5, 0, 0));
  Handle(Geom_Curve) s2 = fit(gp_Pnt(5, 0, 0), gp_Pnt(7.5, -1, 0), gp_Pnt(10, 0, 0));
  LocalAnalysis_CurveContinuity g1(s1, s1->LastParameter(), s2, s2->FirstParameter(), GeomAbs_G1);
  printf("smooth junction G1: IsG1 %d G1Angle %.9g C0Value %.3g\n", g1.IsG1(), g1.G1Angle(), g1.C0Value());
  LocalAnalysis_CurveContinuity c2(s1, s1->LastParameter(), s2, s2->FirstParameter(), GeomAbs_C2);
  printf("smooth junction C2: IsC1 %d C1Ratio %.9g C1Angle %.9g\n", c2.IsC1(), c2.C1Ratio(), c2.C1Angle());

  TopoDS_Shape                 box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  LocOpe_CurveShapeIntersector ix(gp_Ax1(gp_Pnt(5, 5, -10), gp_Dir(0, 0, 1)), box);
  printf("LocOpe line x=y=5: done %d NbPoints %d", ix.IsDone(), ix.IsDone() ? ix.NbPoints() : -1);
  for (int i = 1; ix.IsDone() && i <= ix.NbPoints(); i++)
    printf(" %.9g", ix.Point(i).Parameter());
  printf("\n");
  return 0;
}
