// Epic #766, Issue491SurfaceApproxParityTests.swift, Issue522ApproxC0CollapseTests.swift and
// Issue572ApproxConsumerTests.swift: kernel parity. GeomConvert_ApproxSurface(surf, tol, uCont,
// vCont, maxDeg, maxDeg, maxSeg, 0) as occtApproxSurface calls it (both approximated() and
// approxWithDetails() reach that one helper), and GeomConvert::SurfaceToBSplineSurface as
// OCCTSurfaceToBSpline calls it. The pinned kernel carries patch 0019 (#522).
#include <GC_MakeTrimmedCone.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <cstdio>

static void ap(const char* tag, const Handle(Geom_Surface)& s, double tol, GeomAbs_Shape uc, GeomAbs_Shape vc, int deg, int seg)
{
  GeomConvert_ApproxSurface a(s, tol, uc, vc, deg, deg, seg, 0);
  printf("%s: IsDone=%d HasResult=%d", tag, a.IsDone(), a.HasResult());
  if (a.HasResult())
  {
    Handle(Geom_BSplineSurface) b = a.Surface();
    printf(" MaxError=%.3g degree=(%d,%d) poles=(%d,%d)", a.MaxError(), b->UDegree(), b->VDegree(), b->NbUPoles(), b->NbVPoles());
  }
  printf("\n");
}

static void bs(const char* tag, const Handle(Geom_Surface)& s)
{
  Handle(Geom_BSplineSurface) b = GeomConvert::SurfaceToBSplineSurface(s);
  printf("%s: SurfaceToBSplineSurface degree=(%d,%d)\n", tag, b->UDegree(), b->VDegree());
}

int main()
{
  gp_Ax3                          ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_SphericalSurface)   s10 = new Geom_SphericalSurface(ax, 10);
  Handle(Geom_ToroidalSurface)    tor = new Geom_ToroidalSurface(ax, 20, 5);
  Handle(Geom_Surface)            cone = GC_MakeTrimmedCone(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 12), 5, 2).Value();
  ap("491 sphere r=10 tol 1e-3 C2", s10, 1e-3, GeomAbs_C2, GeomAbs_C2, 8, 100);
  ap("491 sphere r=10 tol 1e-9 C2", s10, 1e-9, GeomAbs_C2, GeomAbs_C2, 8, 100);
  ap("491 torus 20/5 tol 1e-9 C2", tor, 1e-9, GeomAbs_C2, GeomAbs_C2, 8, 100);
  ap("491 cone maxDegree 4 maxSegments 20", cone, 1e-3, GeomAbs_C2, GeomAbs_C2, 4, 20);
  ap("491 cone maxDegree 20 maxSegments 4", cone, 1e-3, GeomAbs_C2, GeomAbs_C2, 20, 4);
  ap("522 sphere r=10 C0/C0", s10, 1e-3, GeomAbs_C0, GeomAbs_C0, 8, 100);
  ap("522 sphere r=10 C0/C2", s10, 1e-3, GeomAbs_C0, GeomAbs_C2, 8, 100);
  {
    TColgp_Array2OfPnt p(1, 4, 1, 4);
    for (int i = 1; i <= 4; i++)
      for (int j = 1; j <= 4; j++)
        p(i, j) = gp_Pnt(i * 3.0, j * 3.0, (i * j) % 5);
    Handle(Geom_BezierSurface) bz = new Geom_BezierSurface(p);
    for (double t : {1e-1, 1e-3, 1e-5, 1e-7})
    {
      char tag[64];
      snprintf(tag, sizeof tag, "522 bicubic Bezier C0 tol %g", t);
      ap(tag, bz, t, GeomAbs_C0, GeomAbs_C0, 8, 100);
    }
  }
  {
    Handle(Geom_Surface) cyl = new Geom_RectangularTrimmedSurface(Handle(Geom_Surface)(new Geom_CylindricalSurface(ax, 5)), 0.0, 2 * M_PI, -10.0, 10.0, true, true);
    ap("522 V-linear trimmed cylinder C0/C0", cyl, 1e-3, GeomAbs_C0, GeomAbs_C0, 8, 100);
  }
  {
    TColgp_Array2OfPnt p(1, 6, 1, 4);
    for (int i = 1; i <= 6; i++)
      for (int j = 1; j <= 4; j++)
        p(i, j) = gp_Pnt(i * 1.5, j * 1.5, ((i * j) % 5) * 0.6);
    TColStd_Array1OfReal    ku(1, 3), kv(1, 2);
    TColStd_Array1OfInteger mu(1, 3), mv(1, 2);
    ku(1) = 0;
    ku(2) = 0.5;
    ku(3) = 1;
    mu(1) = 4;
    mu(2) = 2;
    mu(3) = 4;
    kv(1) = 0;
    kv(2) = 1;
    mv(1) = 4;
    mv(2) = 4;
    Handle(Geom_BSplineSurface) base = new Geom_BSplineSurface(p, ku, kv, mu, mv, 3, 3);
    Handle(Geom_OffsetSurface)  off  = new Geom_OffsetSurface(base, 0.6);
    bs("572 untrimmed offset", off);
    bs("572 trimmed offset [0.1, 0.9]^2", new Geom_RectangularTrimmedSurface(off, 0.1, 0.9, 0.1, 0.9, true, true));
    bs("572 sphere r=5", new Geom_SphericalSurface(ax, 5));
  }
  return 0;
}
