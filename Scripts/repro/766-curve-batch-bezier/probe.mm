// Epic #766 (#1978), kernel parity for BatchCurve3DTests.swift, BezierConversionTests.swift and
// BezierPatchGridTests.swift. Same inputs as the Swift tests, straight to OCCT, mirroring:
//   OCCTCurve3DEvaluateGrid / GridD1     -> GeomGridEval_Curve::EvaluateGrid / EvaluateGridD1
//   OCCTShapeConvertToBezier             -> ShapeUpgrade_ShapeConvertToBezier, every mode on
//   OCCTSurfaceBSplineToBezierPatches    -> GeomConvert_BSplineSurfaceToBezierSurface
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <GeomGridEval_Curve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_Circle.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <map>

static void grid(double r, const std::vector<double>& ps, bool d1)
{
  Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), r);
  GeomGridEval_Curve  ev(c);
  NCollection_Array1<double> arr(1, (int)ps.size());
  for (size_t i = 0; i < ps.size(); i++)
    arr((int)i + 1) = ps[i];
  if (!d1)
  {
    NCollection_Array1<gp_Pnt> res = ev.EvaluateGrid(arr);
    printf("  n=%d\n", res.Size());
    for (int i = 1; i <= res.Size(); i++)
    {
      gp_Pnt q = c->Value(ps[i - 1]);
      printf("  [%d] u=%.17g grid=(%.17g, %.17g, %.17g) D0=(%.17g, %.17g, %.17g)\n", i - 1,
             ps[i - 1], res(i).X(), res(i).Y(), res(i).Z(), q.X(), q.Y(), q.Z());
    }
  }
  else
  {
    NCollection_Array1<GeomGridEval::CurveD1> res = ev.EvaluateGridD1(arr);
    printf("  n=%d\n", res.Size());
    for (int i = 1; i <= res.Size(); i++)
      printf("  [%d] u=%.17g p=(%.17g, %.17g, %.17g) d1=(%.17g, %.17g, %.17g)\n", i - 1, ps[i - 1],
             res(i).Point.X(), res(i).Point.Y(), res(i).Point.Z(), res(i).D1.X(), res(i).D1.Y(),
             res(i).D1.Z());
  }
}

static void toBezier(const char* name, const TopoDS_Shape& s)
{
  ShapeUpgrade_ShapeConvertToBezier cv(s);
  cv.Set2dConversion(true);
  cv.Set3dConversion(true);
  cv.SetSurfaceConversion(true);
  cv.Set3dLineConversion(true);
  cv.Set3dCircleConversion(true);
  cv.Set3dConicConversion(true);
  cv.SetPlaneMode(true);
  cv.SetRevolutionMode(true);
  cv.SetExtrusionMode(true);
  cv.SetBSplineMode(true);
  bool         ok = cv.Perform();
  TopoDS_Shape r  = cv.Result();
  TopTools_IndexedMapOfShape inF, inE, outF, outE;
  TopExp::MapShapes(s, TopAbs_FACE, inF);
  TopExp::MapShapes(s, TopAbs_EDGE, inE);
  TopExp::MapShapes(r, TopAbs_FACE, outF);
  TopExp::MapShapes(r, TopAbs_EDGE, outE);
  std::map<int, int> ft, et;
  for (int i = 1; i <= outF.Extent(); i++)
    ft[(int)BRepAdaptor_Surface(TopoDS::Face(outF(i))).GetType()]++;
  for (int i = 1; i <= outE.Extent(); i++)
  {
    BRepAdaptor_Curve a(TopoDS::Edge(outE(i)));
    et[(int)a.GetType()]++;
  }
  printf("%s: perform=%d input faces=%d edges=%d -> result faces=%d edges=%d\n", name, ok,
         inF.Extent(), inE.Extent(), outF.Extent(), outE.Extent());
  printf("  result face surface types:");
  for (auto& kv : ft)
    printf(" type%d x%d", kv.first, kv.second);
  printf("\n  result edge curve types:");
  for (auto& kv : et)
    printf(" type%d x%d", kv.first, kv.second);
  printf("\n");
}

int main()
{
  std::vector<double> p8;
  for (double u = 0; u < 2 * M_PI; u += M_PI / 4)
    p8.push_back(u);
  printf("evalGrid: r=5, u = 0, pi/4, ..., 7pi/4\n");
  grid(5, p8, false);
  printf("evalGridD1: r=5, u = 0, pi/2\n");
  grid(5, {0.0, M_PI / 2}, true);
  std::vector<double> p13;
  for (double u = 0; u < 2 * M_PI; u += 0.5)
    p13.push_back(u);
  printf("gridMatchesIndividual: r=3, u = 0, 0.5, ..., 6.0\n");
  grid(3, p13, false);

  toBezier("cylinderToBezier r=5 h=10", BRepPrimAPI_MakeCylinder(5, 10).Shape());
  toBezier("sphereToBezier r=10", BRepPrimAPI_MakeSphere(10).Shape());
  toBezier("boxToBezier 10x20x30",
           BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 20, 30).Shape());
  toBezier("coneToBezier r1=10 r2=5 h=15", BRepPrimAPI_MakeCone(10, 5, 15).Shape());

  // BezierPatchGrid: the 4x4 degree-3 single-span surface.
  double z[4][4] = {{0, 1, -1, 0}, {1, 3, 0, 1}, {-1, 0, 2, -1}, {0, 1, -1, 0}};
  TColgp_Array2OfPnt poles(1, 4, 1, 4);
  for (int i = 0; i < 4; i++)
    for (int j = 0; j < 4; j++)
      poles(i + 1, j + 1) = gp_Pnt(i * 10, j * 10, z[i][j]);
  TColStd_Array1OfReal    k(1, 2);
  TColStd_Array1OfInteger m(1, 2);
  k(1) = 0;
  k(2) = 1;
  m(1) = 4;
  m(2) = 4;
  Handle(Geom_BSplineSurface) bs = new Geom_BSplineSurface(poles, k, k, m, m, 3, 3);
  GeomConvert_BSplineSurfaceToBezierSurface conv(bs);
  printf("bsplineToBezier: NbUPatches=%d NbVPatches=%d\n", conv.NbUPatches(), conv.NbVPatches());
  Handle(Geom_BezierSurface) patch = conv.Patch(1, 1);
  gp_Pnt a = bs->Value(0.3, 0.4), b = patch->Value(0.3, 0.4);
  printf("  surface(0.3,0.4)=(%.17g, %.17g, %.17g) patch(0.3,0.4)=(%.17g, %.17g, %.17g)\n", a.X(),
         a.Y(), a.Z(), b.X(), b.Y(), b.Z());
  printf("  patch poles %dx%d\n", patch->NbUPoles(), patch->NbVPoles());
  return 0;
}
