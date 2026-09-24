// Epic #766, Issue233FaceFromSurfaceWireTests.swift, Issue244PointGridDegreeTests.swift,
// Issue266FaceAnalysisFollowupTests.swift, Issue266FaceWithHolesTests.swift and
// Issue317PeriodicConicalSingleWireTests.swift: kernel parity. The same OCCT calls as the bridge
// functions named in the evidence records, on the same inputs.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepLib.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <ShapeAnalysis_Surface.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeFix_Face.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static double area(const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::SurfaceProperties(s, g);
  return g.Mass();
}

static TopoDS_Wire poly(std::vector<gp_Pnt> p)
{
  BRepBuilderAPI_MakePolygon m;
  for (auto& q : p)
    m.Add(q);
  m.Close();
  return m.Wire();
}

// OCCTShapeCreateFaceFromSurfaceWire / ...WithHoles: MakeFace(surf, outer, true), holes added
// reversed first, then ShapeFix_Face with a ReShape context, BuildCurves3d, BRepCheck.
static TopoDS_Face faceWithHoles(const Handle(Geom_Surface)& s, const TopoDS_Wire& outer,
                                 const std::vector<TopoDS_Wire>& holes, bool& ok)
{
  ok = false;
  for (int attempt = 0; attempt < 2; attempt++)
  {
    BRepBuilderAPI_MakeFace m(s, outer, Standard_True);
    if (!m.IsDone())
      return TopoDS_Face();
    bool good = true;
    for (auto& h : holes)
    {
      m.Add(attempt == 0 ? TopoDS::Wire(h.Reversed()) : h);
      if (!m.IsDone())
      {
        good = false;
        break;
      }
    }
    if (!good)
      continue;
    ShapeFix_Face fx(m.Face());
    fx.SetContext(new ShapeBuild_ReShape);
    fx.Perform();
    TopoDS_Face f = fx.Face();
    BRepLib::BuildCurves3d(f);
    if (BRepCheck_Analyzer(f).IsValid())
    {
      ok = true;
      return f;
    }
  }
  return TopoDS_Face();
}

int main()
{
  Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  {
    // 233: UV polygon (OCCTShapeCreateFaceFromSurfaceUVPolygon).
    double                  uv[4][2] = {{0.2, 0}, {2.0, 1}, {1.5, 6}, {0.0, 4}};
    BRepBuilderAPI_MakeWire wm;
    for (int i = 0; i < 4; i++)
    {
      int j = (i + 1) % 4;
      Handle(Geom2d_TrimmedCurve) seg = GCE2d_MakeSegment(gp_Pnt2d(uv[i][0], uv[i][1]), gp_Pnt2d(uv[j][0], uv[j][1])).Value();
      wm.Add(BRepBuilderAPI_MakeEdge(seg, cyl).Edge());
    }
    TopoDS_Face f = BRepBuilderAPI_MakeFace(cyl, wm.Wire(), Standard_True).Face();
    BRepLib::BuildCurves3d(f);
    TopoDS_Face rect = BRepBuilderAPI_MakeFace(cyl, 0, 2, 0, 6, 1e-6).Face();
    printf("233 uvPolygon: valid=%d area=%.12g rect(0..2 x 0..6) area=%.12g\n", BRepCheck_Analyzer(f).IsValid(), area(f), area(rect));
    std::vector<gp_Pnt> pts;
    for (auto& q : uv)
      pts.push_back(gp_Pnt(5 * cos(q[0]), 5 * sin(q[0]), q[1]));
    bool        ok;
    TopoDS_Face fw = faceWithHoles(cyl, poly(pts), {}, ok);
    printf("233 wireBoundary: ok=%d area=%.12g\n", ok, ok ? area(fw) : -1);
  }
  {
    // 244: GeomAPI_PointsToBSplineSurface on the n x n grid, degree clamped to n - 1 as the Swift
    // wrapper does, and unclamped at degMax 8.
    for (int n : {4, 5, 7})
    {
      TColgp_Array2OfPnt pts(1, n, 1, n);
      for (int v = 0; v < n; v++)
        for (int u = 0; u < n; u++)
          pts.SetValue(u + 1, v + 1, gp_Pnt(u, v, 2 * sin(1.3 * u) * cos(1.1 * v)));
      int cap = std::min(8, n - 1), dmin = std::min(3, cap);
      GeomAPI_PointsToBSplineSurface a(pts, dmin, cap, GeomAbs_C2, 1e-3);
      printf("244 n=%d clamped [%d, %d]: done=%d", n, dmin, cap, a.IsDone());
      if (a.IsDone())
        printf(" degree=(%d, %d) poles=%dx%d", a.Surface()->UDegree(), a.Surface()->VDegree(), a.Surface()->NbUPoles(), a.Surface()->NbVPoles());
      try
      {
        GeomAPI_PointsToBSplineSurface b(pts, 3, 8, GeomAbs_C2, 1e-3);
        printf(" | unclamped [3, 8]: done=%d", b.IsDone());
        if (b.IsDone())
          printf(" degree=(%d, %d) poles=%dx%d", b.Surface()->UDegree(), b.Surface()->VDegree(), b.Surface()->NbUPoles(), b.Surface()->NbVPoles());
      }
      catch (Standard_Failure& e)
      {
        printf(" | unclamped threw %s", e.GetMessageString());
      }
      printf("\n");
    }
  }
  Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  TopoDS_Wire        outer = poly({gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)});
  {
    bool        ok;
    TopoDS_Face f1 = faceWithHoles(plane, outer, {poly({gp_Pnt(3, 3, 0), gp_Pnt(7, 3, 0), gp_Pnt(7, 7, 0), gp_Pnt(3, 7, 0)})}, ok);
    printf("266 holes one: ok=%d area=%.12g\n", ok, ok ? area(f1) : -1);
    TopoDS_Face f0 = faceWithHoles(plane, outer, {}, ok);
    printf("266 holes none: ok=%d area=%.12g\n", ok, ok ? area(f0) : -1);
    TopoDS_Face f2 = faceWithHoles(plane, outer,
                                   {poly({gp_Pnt(1, 1, 0), gp_Pnt(3, 1, 0), gp_Pnt(3, 3, 0), gp_Pnt(1, 3, 0)}),
                                    poly({gp_Pnt(6, 6, 0), gp_Pnt(9, 6, 0), gp_Pnt(9, 9, 0), gp_Pnt(6, 9, 0)})},
                                   ok);
    printf("266 holes two: ok=%d area=%.12g\n", ok, ok ? area(f2) : -1);
    TopoDS_Face f3 = faceWithHoles(plane, outer, {poly({gp_Pnt(3, 3, 5), gp_Pnt(7, 3, 5), gp_Pnt(7, 7, 5), gp_Pnt(3, 7, 5)})}, ok);
    printf("266 holes off-surface: ok=%d area=%.12g\n", ok, ok ? area(f3) : -1);
  }
  {
    Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(cyl);
    double                        U = 0, V = 0;
    double                        d = sas->UVFromIso(gp_Pnt(5, 0, 3), 1e-6, U, V);
    printf("266 uvFromIso: gap=%.3g u=%.12g v=%.12g\n", d, U, V);
    Handle(Geom_ConicalSurface) cone = new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0.5, 5);
    Handle(ShapeAnalysis_Surface) cs = new ShapeAnalysis_Surface(cone);
    printf("266 cone: NbSingularities(1e-7)=%d", cs->NbSingularities(1e-7));
    gp_Pnt   P;
    gp_Pnt2d f2, l2;
    double   fp, lp, pr = 0;
    bool     ui;
    if (cs->Singularity(1, pr, P, f2, l2, fp, lp, ui))
      printf(" singularity(1)=(%.12g, %.12g, %.12g) firstUV=(%g, %g) lastUV=(%g, %g)", P.X(), P.Y(), P.Z(), f2.X(), f2.Y(), l2.X(), l2.Y());
    printf(" Singularity(99) ok=%d\n", (int)cs->Singularity(99, pr, P, f2, l2, fp, lp, ui));
    Handle(ShapeAnalysis_Surface) ds = new ShapeAnalysis_Surface(cyl);
    ds->SetDomain(0, M_PI, 0, 10);
    gp_Pnt2d r = ds->ValueOfUV(gp_Pnt(5, 0, 2), 1e-6);
    printf("266 projectInDomain: uv=(%.12g, %.12g) gap=%.3g\n", r.X(), r.Y(), ds->Gap());
  }
  {
    bool           ok;
    TopoDS_Face    f = faceWithHoles(plane, outer, {}, ok);
    BRepGProp_Face gf(f);
    double         u1, u2, v1, v2;
    gf.Bounds(u1, u2, v1, v2);
    Handle(NCollection_HArray1<double>) uk = gf.GetUKnots(u1, u2);
    printf("266 integration: UIntegrationOrder=%d VIntegrationOrder=%d UKnots=", gf.UIntegrationOrder(), gf.VIntegrationOrder());
    for (int i = uk->Lower(); i <= uk->Upper(); i++)
      printf("%g ", uk->Value(i));
    printf("SIntOrder(eps)=%d SUIntSubs=%d SVIntSubs=%d\n", gf.SIntOrder(1e-6), gf.SUIntSubs(), gf.SVIntSubs());
    TopTools_IndexedMapOfShape em;
    TopExp::MapShapes(f, TopAbs_EDGE, em);
    gf.Load(TopoDS::Edge(em(1)));
    printf("266 boundary edge 0: LIntOrder=%d LIntSubs=%d edges=%d\n", gf.LIntOrder(1e-6), gf.LIntSubs(), em.Extent());
    BRepAdaptor_Surface as(f);
    // TangentU/V are D1U/D1V normalised; read the derivatives directly (constructing
    // BRepLProp_SLProps here aborted with a zero-norm gp_Dir in this probe build).
    gp_Pnt P;
    gp_Vec du, dv;
    as.D1(5, 5, P, du, dv);
    printf("266 tangents at (5,5): D1U=(%g,%g,%g) D1V=(%g,%g,%g)\n", du.X(), du.Y(), du.Z(), dv.X(), dv.Y(), dv.Z());
    ShapeFix_Face fx(f);
    fx.SetMinTolerance(1e-7);
    fx.SetMaxTolerance(1e-2);
    fx.Perform();
    printf("266 faceFixer: result valid=%d area=%.12g\n", BRepCheck_Analyzer(fx.Result()).IsValid(), area(fx.Result()));
  }
  return 0;
}
