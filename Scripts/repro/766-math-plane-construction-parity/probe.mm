// Epic #766 kernel-parity probe: PlaneConstructionTests, PlaneFactoryParityTests.
// Same OCCT calls and inputs as OCCTSurfacePlaneFromPoints (GC_MakePlane(p1, p2, p3)) and
// OCCTSurfacePlaneFromPointNormal (GC_MakePlane(p, gp_Dir(n))), which planeFrom3Points and
// plane(origin:normal:) reach through Swift delegation. Surface.point(atU:v:) is Geom_Surface::D0,
// Surface.normal(atU:v:) is GeomLProp_SLProps(surface, u, v, 1, Precision::Confusion()).Normal().
#include <GC_MakePlane.hxx>
#include <Geom_Plane.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <gp_Pnt.hxx>
#include <gp_Dir.hxx>
#include <cstdio>

static void report(const char* name, GC_MakePlane& m)
{
  if (!m.IsDone())
  {
    printf("%s: IsDone=0 (bridge returns nil)\n", name);
    return;
  }
  Handle(Geom_Plane) pl = m.Value();
  gp_Pnt             p;
  pl->D0(0, 0, p);
  GeomLProp_SLProps props(pl, 0, 0, 1, Precision::Confusion());
  gp_Dir            n = props.Normal();
  printf("%s: IsDone=1 point(0,0)=%.17g %.17g %.17g normal=%.17g %.17g %.17g\n",
         name, p.X(), p.Y(), p.Z(), n.X(), n.Y(), n.Z());
}

static void three(const char* name, gp_Pnt a, gp_Pnt b, gp_Pnt c)
{
  try
  {
    GC_MakePlane m(a, b, c);
    report(name, m);
  }
  catch (const Standard_Failure& e)
  {
    printf("%s: threw %s (bridge returns nil)\n", name, e.what());
  }
}

static void pn(const char* name, gp_Pnt a, double nx, double ny, double nz)
{
  try
  {
    GC_MakePlane m(a, gp_Dir(nx, ny, nz));
    report(name, m);
  }
  catch (const Standard_Failure& e)
  {
    printf("%s: threw %s (bridge returns nil)\n", name, e.what());
  }
}

int main()
{
  three("fromPoints / threePointControlMatches (0,0,0) (10,0,0) (0,10,0)",
        gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(0, 10, 0));
  three("threePointCollinearRejectedByBoth", gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0), gp_Pnt(2, 0, 0));
  three("threePointCollinearUnevenRejectedByBoth", gp_Pnt(0, 0, 0), gp_Pnt(0.3, 0, 0), gp_Pnt(5, 0, 0));
  three("threePointTwoCoincidentRejectedByBoth", gp_Pnt(1, 1, 1), gp_Pnt(1, 1, 1), gp_Pnt(0, 1, 0));
  three("threePointAllCoincidentRejectedByBoth", gp_Pnt(2, 2, 2), gp_Pnt(2, 2, 2), gp_Pnt(2, 2, 2));
  pn("fromPointNormal / pointNormalControlMatches (5,5,5) n(1,1,1)", gp_Pnt(5, 5, 5), 1, 1, 1);
  pn("pointNormalZeroLengthRejectedByBoth", gp_Pnt(0, 0, 0), 0, 0, 0);
  pn("pointNormalNearZeroLengthRejectedByBoth", gp_Pnt(0, 0, 0), 1e-300, 0, 0);
  return 0;
}
