// #766 kernel parity for Tests/OCCTAnalysisTests/AdaptorLocalPropsParityTests.swift.
// Adaptor side: BRepLProp_SLProps / BRepLProp_CLProps at Precision::Confusion() (occtFaceLocalProps,
// occtEdgeLocalProps). Geom side: GeomLProp_SLProps / GeomLProp_CLProps at the same resolution
// (occtSurfaceLocalProps, occtCurveLocalProps). The "res1e-6" column is what the adaptor side
// reports at the pre-#529 literal, the OCCT766_INJ_P_RES injection.
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepLProp_CLProps.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Precision.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static const double kRes = Precision::Confusion();

static void faceRow(const char* label, const TopoDS_Face& f, double u, double v)
{
  BRepAdaptor_Surface as(f);
  BRepLProp_SLProps   a(as, u, v, 2, kRes);
  BRepLProp_SLProps   old(as, u, v, 2, 1e-6);
  double              uu = u, vv = v;
  occ::handle<Geom_Surface> s = BRep_Tool::Surface(f);
  GeomLProp_SLProps          g(s, uu, vv, 2, kRes);
  printf("%s u=%g v=%g | adaptor curvDef=%d", label, u, v, (int)a.IsCurvatureDefined());
  if (a.IsCurvatureDefined())
    printf(" mean=%.17g gauss=%.17g kMax=%.17g kMin=%.17g", a.MeanCurvature(),
           a.GaussianCurvature(), a.MaxCurvature(), a.MinCurvature());
  printf(" | geom curvDef=%d", (int)g.IsCurvatureDefined());
  if (g.IsCurvatureDefined())
    printf(" mean=%.17g gauss=%.17g kMax=%.17g kMin=%.17g", g.MeanCurvature(),
           g.GaussianCurvature(), g.MaxCurvature(), g.MinCurvature());
  printf(" | res1e-6 curvDef=%d", (int)old.IsCurvatureDefined());
  BRepLProp_SLProps a1(as, u, v, 1, kRes);
  GeomLProp_SLProps g1(s, uu, vv, 1, kRes);
  if (a1.IsNormalDefined() && g1.IsNormalDefined())
  {
    gp_Dir na = a1.Normal(), ng = g1.Normal();
    if (f.Orientation() == TopAbs_REVERSED)
      ng.Reverse();
    printf(" | normal adaptor=(%.6f,%.6f,%.6f) oriented=(%.6f,%.6f,%.6f) |dot|=%.17g", na.X(),
           na.Y(), na.Z(), ng.X(), ng.Y(), ng.Z(), std::fabs(na.Dot(ng)));
  }
  printf("\n");
}

static TopoDS_Edge bezierEdge(double spacing)
{
  TColgp_Array1OfPnt poles(1, 4);
  poles(1) = gp_Pnt(0, 0, 0);
  poles(2) = gp_Pnt(spacing, 0, 0);
  poles(3) = gp_Pnt(1, 1, 0);
  poles(4) = gp_Pnt(2, 0, 0);
  return BRepBuilderAPI_MakeEdge(new Geom_BezierCurve(poles)).Edge();
}

static void edgeRow(const char* label, const TopoDS_Edge& e, double u)
{
  BRepAdaptor_Curve ac(e);
  BRepLProp_CLProps a(ac, u, 2, kRes);
  BRepLProp_CLProps old(ac, u, 2, 1e-6);
  double            f, l;
  occ::handle<Geom_Curve> c = BRep_Tool::Curve(e, f, l);
  GeomLProp_CLProps        g(c, u, 2, kRes);
  printf("%s u=%g | adaptor tanDef=%d", label, u, (int)a.IsTangentDefined());
  if (a.IsTangentDefined())
  {
    double k = a.Curvature();
    printf(" curvature=%.17g", k);
    // occtCurveCurvatureIsInvertible: above the resolution and not the RealLast() sentinel
    if (std::fabs(k) > kRes && k < RealLast())
    {
      gp_Pnt p;
      a.CentreOfCurvature(p);
      gp_Dir n;
      a.Normal(n);
      printf(" centre=(%.17g, %.17g, %.17g) normal=(%.6f,%.6f,%.6f)", p.X(), p.Y(), p.Z(), n.X(),
             n.Y(), n.Z());
    }
    else
      printf(" centre=none normal=none");
    gp_Pnt pt = a.Value();
    printf(" value=(%g,%g,%g) |D1|=%.6g", pt.X(), pt.Y(), pt.Z(), a.D1().Magnitude());
  }
  printf(" | geom tanDef=%d", (int)g.IsTangentDefined());
  if (g.IsTangentDefined())
  {
    double k = g.Curvature();
    printf(" curvature=%.17g", k);
    if (std::fabs(k) > kRes && k < RealLast())
    {
      gp_Pnt p;
      g.CentreOfCurvature(p);
      printf(" centre=(%.17g, %.17g, %.17g)", p.X(), p.Y(), p.Z());
    }
    else
      printf(" centre=none");
  }
  printf(" | res1e-6 tanDef=%d", (int)old.IsTangentDefined());
  if (old.IsTangentDefined())
    printf(" curvature=%.17g", old.Curvature());
  printf("\n");
}

int main()
{
  occ::handle<Geom_ConicalSurface> cone =
    new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 6, 0);
  TopoDS_Face coneFace = BRepBuilderAPI_MakeFace(cone, 0, 2 * M_PI, -1, 10, 1e-6).Face();

  printf("== faceToleranceWindowAgrees (u = 0)\n");
  for (double v : {3e-7, 5e-7, 1e-6, 1.5e-6, 3e-6, 1e-5, 1e-2, 1.0})
    faceRow("cone", coneFace, 0, v);

  printf("== facePrincipalCurvaturesAgree (u = 0.4)\n");
  for (double v : {-1e-9, 0.0, 1e-9, 5e-7, 1e-6, 1e-3, 2.0})
    faceRow("cone", coneFace, 0.4, v);

  printf("== ordinaryFacePointsAgree\n");
  const double uv[3][2] = {{0.3, 0.2}, {1.1, -0.4}, {2.0, 0.9}};
  TopoDS_Shape solids[2] = {BRepPrimAPI_MakeSphere(5).Shape(),
                            BRepPrimAPI_MakeCylinder(3, 12).Shape()};
  const char*  names[2]  = {"sphere", "cylinder"};
  for (int s = 0; s < 2; ++s)
  {
    int i = 0;
    for (TopExp_Explorer e(solids[s], TopAbs_FACE); e.More(); e.Next(), ++i)
      for (auto& p : uv)
      {
        char label[64];
        snprintf(label, sizeof label, "%s face %d", names[s], i);
        faceRow(label, TopoDS::Face(e.Current()), p[0], p[1]);
      }
  }

  printf("== edgeToleranceWindowAgrees (u = 0)\n");
  for (double sp : {3e-7, 5e-7, 1e-6, 1e-5, 1e-3})
  {
    char label[64];
    snprintf(label, sizeof label, "bezier spacing=%g", sp);
    edgeRow(label, bezierEdge(sp), 0);
  }

  printf("== cuspHasNoCentreOfCurvature (u = 0)\n");
  for (double sp : {0.0, 1e-12, 1e-9, 1e-8})
  {
    char label[64];
    snprintf(label, sizeof label, "bezier spacing=%g", sp);
    edgeRow(label, bezierEdge(sp), 0);
  }

  printf("== straightEdgeHasNoCentreOfCurvature (u = 5)\n");
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  int          i   = 0;
  for (TopExp_Explorer e(box, TopAbs_EDGE); e.More(); e.Next(), ++i)
  {
    char label[64];
    snprintf(label, sizeof label, "box edge %d", i);
    edgeRow(label, TopoDS::Edge(e.Current()), 5.0);
  }

  printf("== circleCentreOfCurvature\n");
  occ::handle<Geom_Circle> circ = new Geom_Circle(gp_Ax2(gp_Pnt(1, 2, 0), gp_Dir(0, 0, 1)), 4);
  TopoDS_Edge              ce   = BRepBuilderAPI_MakeEdge(circ).Edge();
  for (double u : {0.0, 1.0, 2.5, 4.0})
    edgeRow("circle", ce, u);
  return 0;
}
