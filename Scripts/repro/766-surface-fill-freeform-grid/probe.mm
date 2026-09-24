// Epic #766, SurfaceFillingTests.swift, SurfaceFreeformTests.swift, SurfaceFromGridTests.swift,
// SurfaceKnotSplittingTests.swift and SurfaceNormalParityTests.swift: kernel parity for the
// fourteen tests.
//  - Shape.fill(boundaries:) = OCCTShapeFill: BRepOffsetAPI_MakeFilling(3, 15, 2, false, tol / 10,
//    tol, 0.01, 0.1, maxDeg, maxSeg) (occtFillingMakeBuilder) with every boundary edge added
//    bound at C0 for .g0; the centred 10 x 10 rectangle (tol 1e-4) and the 0..10 polygon (1e-3).
//  - The explicit-pole bicubic Geom_BSplineSurface; GeomLProp_SLProps normal / curvature on the
//    radius-5 sphere; GeomAPI_PointsToBSplineSurface(3, 4, C2, 1e-3) of the 5 x 5 sin/cos grid
//    (fromPointGrid's capped degrees); GeomConvert_BSplineSurfaceKnotSplitting of the trimmed
//    cylinder (GC_MakeTrimmedCylinder r 5 h 10, then GeomConvert::SurfaceToBSplineSurface);
//    the apex cone's normal definedness.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_BSplineSurfaceKnotSplitting.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <NCollection_Array1.hxx>
#include <Precision.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static void fill(const char* name, const std::vector<gp_Pnt>& c, double tol)
{
  BRepOffsetAPI_MakeFilling f(3, 15, 2, false, tol * 0.1, tol, 0.01, 0.1, 8, 9);
  for (size_t i = 0; i < c.size(); i++)
    f.Add(BRepBuilderAPI_MakeEdge(c[i], c[(i + 1) % c.size()]).Edge(), GeomAbs_C0, true);
  f.Build();
  printf("%s: IsDone=%d", name, f.IsDone());
  if (f.IsDone())
  {
    GProp_GProps g;
    BRepGProp::SurfaceProperties(f.Shape(), g);
    printf(" valid=%d area=%.17g", BRepCheck_Analyzer(f.Shape()).IsValid(), g.Mass());
  }
  printf("\n");
}

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  fill("fillClosedWireBoundary", {gp_Pnt(-5, -5, 0), gp_Pnt(5, -5, 0), gp_Pnt(5, 5, 0), gp_Pnt(-5, 5, 0)}, 1e-4);
  fill("fillPolygonBoundary", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)}, 1e-3);

  double P[4][4][3] = {{{0, 0, 0}, {3, 0, 0}, {7, 0, 0}, {10, 0, 0}},
                       {{0, 3, 1}, {3, 3, 2}, {7, 3, 2}, {10, 3, 1}},
                       {{0, 7, 1}, {3, 7, 2}, {7, 7, 2}, {10, 7, 1}},
                       {{0, 10, 0}, {3, 10, 0}, {7, 10, 0}, {10, 10, 0}}};
  TColgp_Array2OfPnt poles(1, 4, 1, 4);
  for (int i = 0; i < 4; i++)
    for (int j = 0; j < 4; j++)
      poles(i + 1, j + 1) = gp_Pnt(P[i][j][0], P[i][j][1], P[i][j][2]);
  TColStd_Array1OfReal    k(1, 2);
  NCollection_Array1<int> m(1, 2);
  k(1) = 0;
  k(2) = 1;
  m(1) = m(2) = 4;
  Handle(Geom_BSplineSurface) bsp = new Geom_BSplineSurface(poles, k, k, m, m, 3, 3);
  gp_Pnt                      q   = bsp->Value(0.3, 0.7);
  printf("bsplineSurface: S(0.3,0.7)=(%.17g, %.17g, %.17g)\n", q.X(), q.Y(), q.Z());

  Handle(Geom_Surface) sphere = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
  GeomLProp_SLProps    sp(sphere, 0, M_PI / 4, 2, Precision::Confusion());
  printf("surfaceNormal: N=(%.17g, %.17g, %.17g)\n", sp.Normal().X(), sp.Normal().Y(), sp.Normal().Z());
  printf("surfaceCurvatures: defined=%d K=%.17g H=%.17g\n", sp.IsCurvatureDefined(), sp.GaussianCurvature(), sp.MeanCurvature());

  TColgp_Array2OfPnt g(1, 5, 1, 5);
  for (int v = 0; v < 5; v++)
    for (int u = 0; u < 5; u++)
      g(u + 1, v + 1) = gp_Pnt(u, v, std::sin(double(u)) * std::cos(double(v)));
  Handle(Geom_BSplineSurface) fit = GeomAPI_PointsToBSplineSurface(g, 3, 4, GeomAbs_C2, 1e-3).Surface();
  double                      u1, u2, v1, v2;
  fit->Bounds(u1, u2, v1, v2);
  gp_Pnt c0 = fit->Value(u1, v1), c1 = fit->Value(u2, v2);
  printf("surfaceFromGrid: degree %dx%d poles %dx%d S(start)=(%.17g, %.17g, %.17g) S(end)=(%.17g, %.17g, %.17g)\n", fit->UDegree(), fit->VDegree(),
         fit->NbUPoles(), fit->NbVPoles(), c0.X(), c0.Y(), c0.Z(), c1.X(), c1.Y(), c1.Z());

  Handle(Geom_BSplineSurface) tc = GeomConvert::SurfaceToBSplineSurface(GC_MakeTrimmedCylinder(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5, 10).Value());
  GeomConvert_BSplineSurfaceKnotSplitting ks(tc, 0, 0);
  printf("knotSplitting: NbUSplits=%d NbVSplits=%d (U knots %d, V knots %d)\n", ks.NbUSplits(), ks.NbVSplits(), tc->NbUKnots(), tc->NbVKnots());

  Handle(Geom_Surface) cone = new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), M_PI / 6, 0);
  GeomLProp_SLProps    apex(cone, 0, 0, 1, Precision::Confusion()), near(cone, 0, 1e-16, 1, Precision::Confusion()), far(cone, 0, 5, 1, Precision::Confusion());
  printf("normal parity: apex defined=%d; v=1e-16 defined=%d", apex.IsNormalDefined(), near.IsNormalDefined());
  if (near.IsNormalDefined())
    printf(" N=(%.17g, %.17g, %.17g)", near.Normal().X(), near.Normal().Y(), near.Normal().Z());
  printf("; v=5 N=(%.17g, %.17g, %.17g)\n", far.Normal().X(), far.Normal().Y(), far.Normal().Z());
  return 0;
}
