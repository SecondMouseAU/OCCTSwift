// Epic #766, GeomOffsetSurfaceExtTests, GeomPlateBuildAveragePlaneTests, GeomPlateSurfaceTests,
// GeomToolsSurfaceSetTests, HelixGeomEvalTests and IntegrationUVSurfaceEvaluationTests: kernel
// parity for the 16 tests. Same inputs, straight to the kernel calls the bridge makes:
//  - Geom_OffsetSurface(plane z = 0, d): Offset(), SetOffsetValue, BasisSurface, D0
//  - GeomPlate_BuildAveragePlane(points, nbBound = count, 1e-3, 1, 1): IsPlane/IsLine, Plane, MinMaxBox
//  - GeomPlate_BuildPlateSurface(3, 10, 5) + point constraints, GeomPlate_MakeApprox(tol, max(20, 2)
//    segments, 8, tol * 0.1, 0, C1), BRepBuilderAPI_MakeFace (OCCTGeomPlateSurface): area and the
//    constraint points' distance to the face
//  - GeomTools_SurfaceSet: Add return values for [plane, cylinder] and [plane, plane], Write/Read
//  - HelixGeom_HelixCurve::Load(0, 4 pi, 5, 10, 0, false) D0/D1/D2 and HelixGeom_Tools::ApprHelix(1e-3)
//  - Geom_CylindricalSurface r25: D0 radius and the 100-segment polyline length at mid v
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <GeomPlate_BuildAveragePlane.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <GeomTools_SurfaceSet.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Line.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_Plane.hxx>
#include <HelixGeom_HelixCurve.hxx>
#include <HelixGeom_Tools.hxx>
#include <NCollection_HArray1.hxx>
#include <TopoDS_Face.hxx>
#include <cmath>
#include <cstdio>
#include <sstream>
#include <vector>

static void plate(const char* tag, std::vector<gp_Pnt> pts, double tol)
{
  GeomPlate_BuildPlateSurface b(3, 10, 5);
  for (auto& p : pts)
    b.Add(new GeomPlate_PointConstraint(p, 0));
  b.Perform();
  printf("%s: IsDone=%d", tag, b.IsDone());
  if (b.IsDone())
  {
    GeomPlate_MakeApprox        ap(b.Surface(), tol, 20, 8, tol * 0.1, 0, GeomAbs_C1);
    Handle(Geom_BSplineSurface) bs = ap.Surface();
    TopoDS_Face                 f  = BRepBuilderAPI_MakeFace(bs, tol).Face();
    GProp_GProps                g;
    BRepGProp::SurfaceProperties(f, g);
    double worst = 0;
    for (auto& p : pts)
    {
      BRepExtrema_DistShapeShape d(BRepBuilderAPI_MakeVertex(p).Vertex(), f);
      worst = std::max(worst, d.Value());
    }
    printf(" area=%.12g maxPointDistance=%.3g", g.Mass(), worst);
  }
  printf("\n");
}

static void avg(const char* tag, std::vector<gp_Pnt> pts)
{
  Handle(NCollection_HArray1<gp_Pnt>) a = new NCollection_HArray1<gp_Pnt>(1, (int)pts.size());
  for (size_t i = 0; i < pts.size(); i++)
    a->SetValue((int)i + 1, pts[i]);
  GeomPlate_BuildAveragePlane ap(a, (int)pts.size(), 1e-3, 1, 1);
  printf("%s: IsPlane=%d IsLine=%d", tag, ap.IsPlane(), ap.IsLine());
  if (ap.IsPlane())
  {
    gp_Pln p = ap.Plane()->Pln();
    double u1, u2, v1, v2;
    ap.MinMaxBox(u1, u2, v1, v2);
    printf(" normal=(%.12g, %.12g, %.12g) origin=(%.12g, %.12g, %.12g) uv=[%.12g, %.12g]x[%.12g, %.12g]", p.Axis().Direction().X(),
           p.Axis().Direction().Y(), p.Axis().Direction().Z(), p.Location().X(), p.Location().Y(), p.Location().Z(), u1, u2, v1,
           v2);
  }
  if (ap.IsLine())
  {
    gp_Lin l = ap.Line()->Lin();
    printf(" line origin=(%.12g, %.12g, %.12g) dir=(%.12g, %.12g, %.12g)", l.Location().X(), l.Location().Y(), l.Location().Z(),
           l.Direction().X(), l.Direction().Y(), l.Direction().Z());
  }
  printf("\n");
}

int main()
{
  Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  {
    Handle(Geom_OffsetSurface) o = new Geom_OffsetSurface(plane, 5.0);
    printf("offsetValueRoundTrip: Offset()=%.12g\n", o->Offset());
    Handle(Geom_OffsetSurface) o3 = new Geom_OffsetSurface(plane, 3.0);
    o3->SetOffsetValue(7.5);
    printf("setOffsetValue: Offset() after SetOffsetValue(7.5)=%.12g\n", o3->Offset());
    Handle(Geom_OffsetSurface) o2 = new Geom_OffsetSurface(plane, 2.0);
    gp_Pnt                     b  = o2->BasisSurface()->Value(1, 2), q = o2->Value(1, 2);
    printf("offsetBasisIsNotNil: basis %s S(1,2)=(%.12g, %.12g, %.12g) offset S(1,2)=(%.12g, %.12g, %.12g)\n",
           o2->BasisSurface()->DynamicType()->Name(), b.X(), b.Y(), b.Z(), q.X(), q.Y(), q.Z());
    printf("nonOffsetSurface: Geom_Plane is %s a Geom_OffsetSurface (bridge returns 0 / nil for it)\n",
           Handle(Geom_OffsetSurface)::DownCast(plane).IsNull() ? "not" : "");
  }
  avg("averagePlane planarPoints", {gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0.1), gp_Pnt(0, 1, 0), gp_Pnt(1, 1, 0.1), gp_Pnt(0.5, 0.5, 0.05)});
  avg("averagePlane collinearPoints", {gp_Pnt(0, 0, 0), gp_Pnt(1, 1, 1), gp_Pnt(2, 2, 2)});
  plate("plateSurfaceThroughPoints tol 1e-3", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 1), gp_Pnt(0, 10, -1), gp_Pnt(10, 10, 0.5)}, 1e-3);
  plate("plateSurfaceMorePoints tol 1e-2",
        {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 2), gp_Pnt(20, 0, 0), gp_Pnt(0, 10, -1), gp_Pnt(10, 10, 1), gp_Pnt(20, 10, -0.5)}, 1e-2);
  {
    Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3.0);
    GeomTools_SurfaceSet            s1;
    int                             a = s1.Add(plane), b = s1.Add(cyl);
    std::ostringstream              os;
    s1.Write(os);
    GeomTools_SurfaceSet s2;
    std::istringstream   is(os.str());
    s2.Read(is);
    int n = 0;
    try
    {
      for (int i = 1;; i++)
      {
        if (s2.Surface(i).IsNull())
          break;
        n = i;
      }
    }
    catch (...)
    {
    }
    GeomTools_SurfaceSet s3;
    int                  c = s3.Add(plane), d = s3.Add(plane);
    printf("surfaceSet: Add(plane)=%d Add(cyl)=%d written=%zu bytes read back=%d surfaces; duplicate: Add(plane)=%d Add(plane)=%d\n", a, b,
           os.str().size(), n, c, d);
  }
  {
    HelixGeom_HelixCurve hc;
    hc.Load(0, 4 * M_PI, 5.0, 10.0, 0, false);
    gp_Pnt p0 = hc.Value(0);
    gp_Pnt p;
    gp_Vec v1, v2;
    hc.D1(0, p, v1);
    printf("helix eval(0)=(%.12g, %.12g, %.12g) D1(0) point=(%.12g, %.12g, %.12g) d1=(%.12g, %.12g, %.12g)\n", p0.X(), p0.Y(), p0.Z(), p.X(),
           p.Y(), p.Z(), v1.X(), v1.Y(), v1.Z());
    hc.D2(M_PI, p, v1, v2);
    printf("helix D2(pi) point=(%.12g, %.12g, %.12g) d1=(%.12g, %.12g, %.12g) d2=(%.12g, %.12g, %.12g)\n", p.X(), p.Y(), p.Z(), v1.X(),
           v1.Y(), v1.Z(), v2.X(), v2.Y(), v2.Z());
    Handle(Geom_BSplineCurve) bs;
    double                    err = 0;
    int st = HelixGeom_Tools::ApprHelix(0, 4 * M_PI, 5.0, 10.0, 0, false, 1e-3, bs, err);
    printf("helix ApprHelix(1e-3): status=%d maxError=%.6g\n", st, err);
  }
  {
    Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 25.0);
    double                          u1, u2, v1, v2;
    cyl->Bounds(u1, u2, v1, v2);
    double worst = 0, len = 0;
    for (int i = 0; i < 8; i++)
      for (int j = 0; j < 4; j++)
      {
        gp_Pnt q = cyl->Value(2 * M_PI * i / 8, -100 + 200.0 * j / 4);
        worst    = std::max(worst, std::abs(std::hypot(q.X(), q.Y()) - 25));
      }
    gp_Pnt prev = cyl->Value(0, 0);
    for (int i = 1; i <= 100; i++)
    {
      gp_Pnt q = cyl->Value(2 * M_PI * i / 100, 0);
      len += q.Distance(prev);
      prev = q;
    }
    printf("cylinder r25: Bounds u=[%.12g, %.12g] v=[%g, %g] max|r-25| over the 8x4 grid=%.3g polyline(100) length=%.12g (2 pi r = %.12g)\n",
           u1, u2, v1, v2, worst, len, 2 * M_PI * 25);
  }
  return 0;
}
