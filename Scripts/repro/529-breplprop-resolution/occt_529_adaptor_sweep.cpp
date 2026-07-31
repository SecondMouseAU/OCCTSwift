// OCCTSwift#529 — does the Resolution argument change what the *adaptor-based* local-property
// classes report, and do they agree with their Geom_* counterparts once the value matches?
//
// BRepLProp_SLProps / BRepLProp_CLProps are, in OCCT 8.0, plain aliases for the same header-only
// templates GeomLProp_SLProps / GeomLProp_CLProps use, differing only in the adaptor they read
// through (BRepAdaptor_Surface / BRepAdaptor_Curve instead of a Geom_ handle). So the Resolution
// means exactly what #494 measured it to mean; this probe checks that it is observable through the
// adaptor, and that the two halves land on the same answer at the same value.
//
// Build:
//   L=Libraries/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$L/Headers" -L"$L" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/529-breplprop-resolution/occt_529_adaptor_sweep.cpp -o /tmp/occt_529_sweep

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepLProp_CLProps.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRep_Tool.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Precision.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>

#include <cmath>
#include <cstdio>
#include <string>

static const double kOld = 1e-6;                     // what the 18 bridge sites pass today
static const double kNew = Precision::Confusion();   // 1e-7, occtLocalPropsResolution()

// ---------------------------------------------------------------------------------------------
// Geometry

static TopoDS_Face apexConeFace()
{
  // Semi-angle 30 deg, apex radius 0: the apex sits at v = 0 and |dS/du| falls off linearly with v,
  // so sweeping v walks smoothly through both resolutions' null-vector thresholds.
  gp_Ax3 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  occ::handle<Geom_ConicalSurface> cone = new Geom_ConicalSurface(axis, M_PI / 6.0, 0.0);
  return BRepBuilderAPI_MakeFace(cone, 0.0, 2 * M_PI, -1.0, 10.0, Precision::Confusion()).Face();
}

static TopoDS_Face sphereFace(double radius)
{
  gp_Ax3 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  occ::handle<Geom_SphericalSurface> sphere = new Geom_SphericalSurface(axis, radius);
  return BRepBuilderAPI_MakeFace(sphere, 0.0, 2 * M_PI, -M_PI / 2, M_PI / 2, Precision::Confusion())
      .Face();
}

// A cubic Bezier whose first two poles sit `spacing` apart, so |D1(0)| = 3 * spacing. At spacing 0
// the start is a cusp: the first significant derivative has order 2 and OCCT reports RealLast()
// curvature there.
static TopoDS_Edge cuspBezierEdge(double spacing)
{
  TColgp_Array1OfPnt poles(1, 4);
  poles(1) = gp_Pnt(0, 0, 0);
  poles(2) = gp_Pnt(spacing, 0, 0);
  poles(3) = gp_Pnt(1, 1, 0);
  poles(4) = gp_Pnt(2, 0, 0);
  occ::handle<Geom_BezierCurve> bez = new Geom_BezierCurve(poles);
  return BRepBuilderAPI_MakeEdge(bez).Edge();
}

// ---------------------------------------------------------------------------------------------
// Reporting helpers

struct SurfaceAnswer
{
  bool normalDefined = false;
  bool curvatureDefined = false;
  double mean = 0.0;
  double gaussian = 0.0;
};

template <typename Props>
static SurfaceAnswer readSurface(Props& p)
{
  SurfaceAnswer a;
  a.normalDefined = p.IsNormalDefined();
  a.curvatureDefined = p.IsCurvatureDefined();
  if (a.curvatureDefined)
  {
    a.mean = p.MeanCurvature();
    a.gaussian = p.GaussianCurvature();
  }
  return a;
}

static std::string describe(const SurfaceAnswer& a)
{
  char buf[128];
  if (!a.curvatureDefined)
  {
    std::snprintf(buf, sizeof(buf), "UNDEFINED (normal %s)", a.normalDefined ? "def" : "undef");
    return buf;
  }
  std::snprintf(buf, sizeof(buf), "def H=%-12.4g K=%-12.4g", a.mean, a.gaussian);
  return buf;
}

static bool sameSurface(const SurfaceAnswer& x, const SurfaceAnswer& y)
{
  if (x.normalDefined != y.normalDefined || x.curvatureDefined != y.curvatureDefined) return false;
  if (!x.curvatureDefined) return true;
  return x.mean == y.mean && x.gaussian == y.gaussian;
}

// ---------------------------------------------------------------------------------------------

static void surfaceSweep(const char* title, const TopoDS_Face& face, double u,
                         const double* vs, int nvs)
{
  std::printf("\n=== %s ===\n", title);
  std::printf("%-14s | %-34s | %-34s | %s\n", "v", "BRepLProp @ 1e-6 (today)",
              "BRepLProp @ Confusion (fix)", "GeomLProp @ Confusion (canonical)");

  occ::handle<Geom_Surface> surf = BRep_Tool::Surface(face);
  for (int i = 0; i < nvs; ++i)
  {
    const double v = vs[i];
    BRepAdaptor_Surface adaptor(face);
    BRepLProp_SLProps oldProps(adaptor, u, v, 2, kOld);
    BRepLProp_SLProps newProps(adaptor, u, v, 2, kNew);
    GeomLProp_SLProps geomProps(surf, u, v, 2, kNew);

    SurfaceAnswer o = readSurface(oldProps);
    SurfaceAnswer n = readSurface(newProps);
    SurfaceAnswer g = readSurface(geomProps);

    std::printf("%-14.6g | %-34s | %-34s | %s%s\n", v, describe(o).c_str(), describe(n).c_str(),
                describe(g).c_str(),
                sameSurface(n, g) ? "" : "   <-- adaptor/geom MISMATCH at same resolution");
    if (!sameSurface(o, n)) std::printf("%-14s | ^ resolution changes the answer here\n", "");
  }
}

static void curveSweep(const char* title, const TopoDS_Edge& edge, const double* us, int nus)
{
  std::printf("\n=== %s ===\n", title);
  std::printf("%-14s | %-30s | %-30s | %s\n", "u", "BRepLProp @ 1e-6 (today)",
              "BRepLProp @ Confusion (fix)", "GeomLProp @ Confusion");

  double f = 0, l = 0;
  occ::handle<Geom_Curve> curve = BRep_Tool::Curve(edge, f, l);

  for (int i = 0; i < nus; ++i)
  {
    const double u = us[i];
    BRepAdaptor_Curve adaptor(edge);
    BRepLProp_CLProps oldProps(adaptor, u, 2, kOld);
    BRepLProp_CLProps newProps(adaptor, u, 2, kNew);
    GeomLProp_CLProps geomProps(curve, u, 2, kNew);

    const bool oTan = oldProps.IsTangentDefined();
    const bool nTan = newProps.IsTangentDefined();
    const bool gTan = geomProps.IsTangentDefined();
    const double oCur = oldProps.Curvature();
    const double nCur = newProps.Curvature();
    const double gCur = geomProps.Curvature();

    char ob[64], nb[64], gb[64];
    std::snprintf(ob, sizeof(ob), "%s k=%-12.6g", oTan ? "tan  " : "NOTAN", oCur);
    std::snprintf(nb, sizeof(nb), "%s k=%-12.6g", nTan ? "tan  " : "NOTAN", nCur);
    std::snprintf(gb, sizeof(gb), "%s k=%-12.6g", gTan ? "tan  " : "NOTAN", gCur);
    std::printf("%-14.6g | %-30s | %-30s | %s%s\n", u, ob, nb, gb,
                (nTan == gTan && nCur == gCur) ? "" : "   <-- adaptor/geom MISMATCH");
    if (oTan != nTan || oCur != nCur)
      std::printf("%-14s | ^ resolution changes the answer here\n", "");
  }
}

int main()
{
  std::printf("OCCT resolution values: 1e-6 (bridge today) vs Precision::Confusion() = %g\n", kNew);

  const double coneVs[] = {10.0, 1.0, 1e-2, 1e-5, 3e-6, 1.5e-6, 1e-6, 3e-7, 1e-7, 1e-8, 0.0};
  surfaceSweep("SLProps on a FACE: cone (semi-angle 30 deg, apex radius 0), u=0", apexConeFace(),
               0.0, coneVs, sizeof(coneVs) / sizeof(coneVs[0]));

  const double poleVs[] = {M_PI / 2 - 1e-3, M_PI / 2 - 1e-5, M_PI / 2 - 1e-6,
                           M_PI / 2 - 1e-7, M_PI / 2 - 1e-8, M_PI / 2};
  surfaceSweep("SLProps on a FACE: sphere r=3 approaching the north pole, u=0", sphereFace(3.0),
               0.0, poleVs, sizeof(poleVs) / sizeof(poleVs[0]));

  const double us[] = {0.0, 1e-9, 1e-8, 1e-7, 0.5};
  for (double spacing : {0.0, 1e-8, 1e-7, 3e-7, 1e-6, 1e-5})
  {
    char title[160];
    std::snprintf(title, sizeof(title),
                  "CLProps on an EDGE: cubic Bezier, first two poles %g apart (|D1(0)| = %g)",
                  spacing, 3 * spacing);
    curveSweep(title, cuspBezierEdge(spacing), us, sizeof(us) / sizeof(us[0]));
  }

  return 0;
}
