// Epic #766, Issue398ContinuityTests.swift, Issue403SurfaceKnotSplitParamsTests.swift,
// Issue437PlatePointG2Tests.swift and Issue480SurfaceKnotSplitContinuityTests.swift: kernel parity.
//  - GeomConvert_BSplineSurfaceKnotSplitting on the BSpline of GC_MakeTrimmedCylinder(r 5, h 10)
//    and on the #480 fixtures, as OCCTSurfaceKnotSplitting calls it (split params are knot values).
//  - GeomPlate_PointConstraint: order 2 on a bare point throws (the kernel side of #437), order 1
//    is accepted; and the plate the g0 tests build (same chain as OCCTShapePlatePointsAdvanced /
//    OCCTShapePlateMixed, see 766-advanced-plate-surface for the helper).
//  - GeomAbs_Shape ordinals for #398's ContinuityClass.
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepGProp.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <GProp_GProps.hxx>
#include <GeomAbs_Shape.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_BSplineSurfaceKnotSplitting.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Standard_Failure.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <cstdio>
#include <vector>

static void split(const char* tag, const Handle(Geom_BSplineSurface)& b, int uc, int vc)
{
  try
  {
    GeomConvert_BSplineSurfaceKnotSplitting s(b, uc, vc);
    printf("%s (%d, %d): U=", tag, uc, vc);
    for (int i = 1; i <= s.NbUSplits(); i++)
      printf("%.12g ", b->UKnot(s.USplitValue(i)));
    printf("V=");
    for (int i = 1; i <= s.NbVSplits(); i++)
      printf("%.12g ", b->VKnot(s.VSplitValue(i)));
    printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("%s (%d, %d): threw %s\n", tag, uc, vc, e.GetMessageString());
  }
}

static Handle(Geom_BSplineSurface) fixture(int degree, int interior, int bumpAt = 0, int bumpMult = 1)
{
  std::vector<double> k = {0};
  std::vector<int>    m = {degree + 1};
  for (int i = 1; i <= interior; i++)
  {
    k.push_back(i);
    m.push_back(i == bumpAt ? bumpMult : 1);
  }
  k.push_back(interior + 1);
  m.push_back(degree + 1);
  int sum = 0;
  for (int x : m)
    sum += x;
  int                     n = sum - degree - 1;
  TColgp_Array2OfPnt      p(1, n, 1, n);
  TColStd_Array1OfReal    kk(1, (int)k.size());
  TColStd_Array1OfInteger mm(1, (int)m.size());
  for (size_t i = 0; i < k.size(); i++)
  {
    kk((int)i + 1) = k[i];
    mm((int)i + 1) = m[i];
  }
  for (int u = 0; u < n; u++)
    for (int v = 0; v < n; v++)
      p(u + 1, v + 1) = gp_Pnt(u, v, ((u + v) % 3) * 0.5);
  return new Geom_BSplineSurface(p, kk, kk, mm, mm, degree, degree);
}

int main()
{
  Handle(Geom_RectangularTrimmedSurface) tc = GC_MakeTrimmedCylinder(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5, 10).Value();
  Handle(Geom_BSplineSurface)            b  = GeomConvert::SurfaceToBSplineSurface(tc);
  double                                 u1, u2, v1, v2;
  b->Bounds(u1, u2, v1, v2);
  printf("403 trimmed cylinder BSpline: bounds=[%.17g, %.17g]x[%.17g, %.17g]\n", u1, u2, v1, v2);
  split("403 C0 splits", b, 0, 0);

  auto s3 = fixture(3, 4);
  for (int c : {0, 1, 2, 3})
    split("480 bicubic", s3, c, c);
  split("480 bicubic mixed", s3, 3, 1);
  split("480 bump at knot 2 x3", fixture(3, 4, 2, 3), 1, 1);
  for (int c : {0, 1, 2, 3})
    split("480 degree 5", fixture(5, 4), c, c);
  split("480 bicubic continuity -1", s3, -1, -1);

  for (int order : {0, 1, 2})
  {
    try
    {
      Handle(GeomPlate_PointConstraint) pc = new GeomPlate_PointConstraint(gp_Pnt(0, 0, 0), order);
      printf("437 GeomPlate_PointConstraint(point, %d): accepted, Order()=%d\n", order, pc->Order());
    }
    catch (Standard_Failure& e)
    {
      printf("437 GeomPlate_PointConstraint(point, %d): threw %s\n", order, e.GetMessageString());
    }
  }
  try
  {
    GeomPlate_BuildPlateSurface bp(3, 15, 2);
    bp.Add(new GeomPlate_PointConstraint(gp_Pnt(5, 5, 3), 0));
    gp_Pnt c[4] = {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)};
    BRepBuilderAPI_MakeWire mw;
    for (int i = 0; i < 4; i++)
      mw.Add(BRepBuilderAPI_MakeEdge(c[i], c[(i + 1) % 4]).Edge());
    for (TopExp_Explorer e(mw.Wire(), TopAbs_EDGE); e.More(); e.Next())
      bp.Add(new GeomPlate_CurveConstraint(new BRepAdaptor_Curve(TopoDS::Edge(e.Current())), 0));
    bp.Perform();
    GeomPlate_MakeApprox        ap(bp.Surface(), 0.01, 20, 8, 0.001, 0, GeomAbs_C1);
    TopoDS_Face                 f = BRepBuilderAPI_MakeFace(ap.Surface(), 0.01).Face();
    GProp_GProps                g;
    BRepGProp::SurfaceProperties(f, g);
    printf("437 mixed g0 point + rectangle: area=%.17g\n", g.Mass());
  }
  catch (Standard_Failure& e)
  {
    printf("437 mixed: threw %s\n", e.GetMessageString());
  }
  printf("398 GeomAbs_Shape: C0=%d G1=%d C1=%d G2=%d C2=%d C3=%d CN=%d\n", GeomAbs_C0, GeomAbs_G1, GeomAbs_C1, GeomAbs_G2,
         GeomAbs_C2, GeomAbs_C3, GeomAbs_CN);
  return 0;
}
