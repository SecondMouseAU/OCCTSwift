// Ground truth for #1019 and #1020, both against OCCTGeomPlateSurface
// (OCCTBridge_ProjLib_NLPlate.mm), which builds
//
//     GeomPlate_BuildPlateSurface builder(3, 10, 5, tolerance);
//
// #1019: the fourth slot is Tol2d, not Tol3d, so the caller's 3D tolerance lands on the 2D
//        parametric tolerance and Tol3d keeps its own 1e-4 default.
// #1020: maxDegree and maxSegments reach only GeomPlate_MakeApprox, never the builder.
//
// Each row below rebuilds the entry point's own pipeline with one argument moved, and reports the
// fitted surface's pole counts plus the worst distance from the caller's own input points to the
// result. The last number is the one the entry point's contract is about.
#include <BRepBuilderAPI_MakeFace.hxx>
#include <Geom_BSplineSurface.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <GeomAbs_Shape.hxx>
#include <Standard_Failure.hxx>
#include <gp_Pnt.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

namespace
{

// Which fixture the rows below are measured on. A tolerance slot that is genuinely unread has to
// stay unread across more than one cloud, so the wide sweep runs both.
int gFixture = 0;

// Fixture 0: the cloud from Shape.plateSurface's own doc comment, with real out-of-plane
// structure, so that a change to the plate's own resolution or to the tolerance it is held to has
// somewhere to show up. A near-planar cloud would agree across every row for a reason unrelated to
// the argument under test.
//
// Fixture 1: far from the origin, much larger, unevenly spaced and steeply folded. Tol3d feeds
// GeomPlate_BuildAveragePlane's planarity test (myTol3d / 1000) and the projection resolutions
// (UResolution(myTol3d)), and both of those are trivial on a small centred cloud sitting near its
// own average plane. If Tol3d is inert here too, it is inert for this entry point rather than for
// this fixture.
std::vector<gp_Pnt> cloud()
{
  std::vector<gp_Pnt> pts;
  if (gFixture == 0)
  {
    for (int i = 0; i < 5; i++)
      for (int j = 0; j < 5; j++)
        pts.push_back(
          gp_Pnt(i * 4.0, j * 4.0, 4.0 * std::sin(i * 1.3) * std::cos(j * 1.1)));
  }
  else
  {
    for (int i = 0; i < 7; i++)
    {
      for (int j = 0; j < 7; j++)
      {
        double x = 1000.0 + i * i * 3.0;
        double y = -500.0 + j * (4.0 + 0.7 * i);
        double z = 250.0 + 60.0 * std::sin(i * 0.9) * std::cos(j * 1.7) + 8.0 * i * std::sin(j);
        pts.push_back(gp_Pnt(x, y, z));
      }
    }
  }
  return pts;
}

// Deliberately no G0Error/G1Error/G2Error column. Those three are uninitialised members after a
// point-constraint-only Perform() (#1018), so they are not a number yet and cannot be read as a
// quality signal here. The worst distance from the caller's own input points is measured instead.
struct Row
{
  bool   built = false;
  int    uPoles = 0, vPoles = 0, uDegree = 0, vDegree = 0;
  double worstPointMiss = 0;
};

// The entry point's own pipeline, with every argument it hardcodes or forwards exposed.
Row run(int    builderDegree,
        int    nbPtsOnCur,
        int    nbIter,
        double tol2d,
        double tol3d,
        double approxTolerance,
        int    maxDegree,
        int    maxSegments)
{
  Row row;
  try
  {
    GeomPlate_BuildPlateSurface builder(builderDegree, nbPtsOnCur, nbIter, tol2d, tol3d);
    std::vector<gp_Pnt>         pts = cloud();
    for (const gp_Pnt& p : pts)
      builder.Add(new GeomPlate_PointConstraint(p, 0));

    builder.Perform();
    if (!builder.IsDone())
      return row;
    Handle(GeomPlate_Surface) plate = builder.Surface();
    if (plate.IsNull())
      return row;

    // occtPlateApproxSurface's own body: dmax = tolerance * 0.1, continuity C1.
    GeomPlate_MakeApprox approx(plate,
                                approxTolerance,
                                maxSegments,
                                maxDegree,
                                approxTolerance * 0.1,
                                0,
                                GeomAbs_C1);
    Handle(Geom_BSplineSurface) bspline = approx.Surface();
    if (bspline.IsNull())
      return row;

    // A face is what the entry point returns; build one so a row that would fail there is not
    // reported as a success here.
    BRepBuilderAPI_MakeFace faceMaker(bspline, approxTolerance);
    if (!faceMaker.IsDone())
      return row;

    row.built   = true;
    row.uPoles  = bspline->NbUPoles();
    row.vPoles  = bspline->NbVPoles();
    row.uDegree = bspline->UDegree();
    row.vDegree = bspline->VDegree();
    for (const gp_Pnt& p : pts)
    {
      GeomAPI_ProjectPointOnSurf proj(p, bspline);
      if (proj.NbPoints() > 0 && proj.LowerDistance() > row.worstPointMiss)
        row.worstPointMiss = proj.LowerDistance();
    }
  }
  catch (const Standard_Failure& f)
  {
    printf("        (threw: %s)\n", f.GetMessageString() ? f.GetMessageString() : "?");
  }
  catch (...)
  {
    printf("        (threw)\n");
  }
  return row;
}

void report(const char* label, const Row& r)
{
  if (!r.built)
  {
    printf("%-46s NOT BUILT\n", label);
    return;
  }
  printf("%-46s poles=%dx%d deg=%dx%d worstInputPointMiss=%.9g\n",
         label,
         r.uPoles,
         r.vPoles,
         r.uDegree,
         r.vDegree,
         r.worstPointMiss);
}

} // namespace

int main()
{
  char label[128];

  // Shipped default in Shape.plateSurface: tolerance 1e-3, maxDegree 8, maxSegments 20.
  printf("=== #1019: which tolerance slot the caller's value lands in ===\n");
  for (double tol : {1e-1, 1e-3, 1e-6})
  {
    snprintf(label, sizeof(label), "shipped: Tol2d=%g, Tol3d=default 1e-4", tol);
    report(label, run(3, 10, 5, tol, 1e-4, tol, 8, 20));
  }
  for (double tol : {1e-1, 1e-3, 1e-6})
  {
    snprintf(label, sizeof(label), "fixed:   Tol2d=default 1e-5, Tol3d=%g", tol);
    report(label, run(3, 10, 5, 1e-5, tol, tol, 8, 20));
  }
  printf("  -- Tol2d alone, holding everything else fixed --\n");
  for (double t2 : {1e-1, 1e-5, 1e-9})
  {
    snprintf(label, sizeof(label), "Tol2d=%g  Tol3d=1e-4  approxTol=1e-3", t2);
    report(label, run(3, 10, 5, t2, 1e-4, 1e-3, 8, 20));
  }
  printf("  -- Tol3d alone, holding everything else fixed --\n");
  for (double t3 : {1e-1, 1e-4, 1e-9})
  {
    snprintf(label, sizeof(label), "Tol2d=1e-5  Tol3d=%g  approxTol=1e-3", t3);
    report(label, run(3, 10, 5, 1e-5, t3, 1e-3, 8, 20));
  }

  printf("\n=== #1020: the builder's own Degree, which the caller never reaches ===\n");
  for (int d : {2, 3, 4, 5, 8, 9, 10})
  {
    snprintf(label, sizeof(label), "builder Degree=%d (approx maxDegree stays 8)", d);
    report(label, run(d, 10, 5, 1e-5, 1e-3, 1e-3, 8, 20));
  }

  printf("\n=== #1020: NbIter, 5 here against the siblings' 2 ===\n");
  for (int n : {1, 2, 3, 5, 10})
  {
    snprintf(label, sizeof(label), "builder NbIter=%d", n);
    report(label, run(3, 10, n, 1e-5, 1e-3, 1e-3, 8, 20));
  }

  printf("\n=== #1020: NbPtsOnCur, the builder's second slot ===\n");
  for (int n : {0, 1, 10, 15, 40})
  {
    snprintf(label, sizeof(label), "builder NbPtsOnCur=%d", n);
    report(label, run(3, n, 5, 1e-5, 1e-3, 1e-3, 8, 20));
  }

  printf("\n=== the approximation caps the caller does reach ===\n");
  for (int d : {3, 5, 8})
  {
    for (int s : {2, 20})
    {
      snprintf(label, sizeof(label), "approx maxDegree=%d maxSegments=%d", d, s);
      report(label, run(3, 10, 5, 1e-5, 1e-3, 1e-3, d, s));
    }
  }

  // The narrow sweeps above hold one fixture. Widen both the range and the fixture before
  // concluding that either builder tolerance slot is unread: an argument that looks inert on a
  // small centred near-planar cloud is the classic way to mistake a fixture for a finding.
  printf("\n=== wide sweep: is either builder tolerance slot read at all? ===\n");
  for (int f : {0, 1})
  {
    gFixture = f;
    printf("  -- fixture %d --\n", f);
    for (double t2 : {1e-12, 1e-9, 1e-5, 1e-2, 1e0, 1e2})
    {
      snprintf(label, sizeof(label), "f%d Tol2d=%-8g Tol3d=1e-4", f, t2);
      report(label, run(3, 10, 5, t2, 1e-4, 1e-3, 8, 20));
    }
    for (double t3 : {1e-12, 1e-9, 1e-5, 1e-2, 1e0, 1e2})
    {
      snprintf(label, sizeof(label), "f%d Tol2d=1e-5   Tol3d=%-8g", f, t3);
      report(label, run(3, 10, 5, 1e-5, t3, 1e-3, 8, 20));
    }
    printf("  -- and the approximation tolerance, for contrast --\n");
    for (double ta : {1e-1, 1e-3, 1e-6})
    {
      snprintf(label, sizeof(label), "f%d approxTol=%-8g", f, ta);
      report(label, run(3, 10, 5, 1e-5, 1e-4, ta, 8, 20));
    }
  }
  gFixture = 0;

  printf("\ndone\n");
  return 0;
}
