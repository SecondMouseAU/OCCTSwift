// #1049 / #1046: what the five OCCTSurfaceNLPlate* entry points return.
//
// Links the real bridge translation unit, so every number below is the shipped
// function's own answer, not a reimplementation of it. Build line in README.md.
//
// Each fixture reports three things, so a wrong answer can be attributed:
//
//   solver   what NLPlate_NLPlate itself says, reached directly, no bridge involved
//   grid     the pole grid the bridge builds from it
//   output   the surface the bridge hands back
//
// The doubling (#1049) sits between solver and grid; the parametrisation (#1046)
// sits between grid and output.

#import "../../../Sources/OCCTBridge/include/OCCTBridge.h"
#import "../../../Sources/OCCTBridge/src/OCCTBridge_Internal.h"

#include <Geom_BSplineSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_Surface.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG0G1Constraint.hxx>
#include <NLPlate_NLPlate.hxx>
#include <Plate_D1.hxx>
#include <Precision.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <cstdio>

// The bridge's own OCCTSurfaceRelease lives in another translation unit; this probe
// links only OCCTBridge_ProjLib_NLPlate.mm, so it frees the wrapper directly.
static void freeSurface(OCCTSurfaceRef s)
{
  delete (OCCTSurface*)s;
}

static Handle(Geom_Plane) planeSurface(double x, double y, double z)
{
  return new Geom_Plane(gp_Ax3(gp_Pnt(x, y, z), gp_Dir(0, 0, 1)));
}

static Handle(Geom_CylindricalSurface) cylinderSurface(double r)
{
  return new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), r);
}

static OCCTSurfaceRef wrap(const Handle(Geom_Surface) & s)
{
  return (OCCTSurfaceRef) new OCCTSurface(s);
}

static void report(const char* label, OCCTSurfaceRef s)
{
  if (!s)
  {
    printf("%-36s : NULL\n", label);
    return;
  }
  Handle(Geom_Surface) g = ((OCCTSurface*)s)->surface;
  Standard_Real        u1, u2, v1, v2;
  g->Bounds(u1, u2, v1, v2);
  printf("%-36s : %s  u [%g, %g]  v [%g, %g]  periodic u=%s v=%s\n",
         label,
         g->DynamicType()->Name(),
         u1,
         u2,
         v1,
         v2,
         g->IsUPeriodic() ? "yes" : "no",
         g->IsVPeriodic() ? "yes" : "no");
}

static void pointAt(const char* label, OCCTSurfaceRef s, double u, double v)
{
  if (!s)
  {
    printf("%-36s : NULL\n", label);
    return;
  }
  Handle(Geom_Surface) g = ((OCCTSurface*)s)->surface;
  Standard_Real        u1, u2, v1, v2;
  g->Bounds(u1, u2, v1, v2);
  const bool inside = (u >= u1 - 1e-9) && (u <= u2 + 1e-9) && (v >= v1 - 1e-9) && (v <= v2 + 1e-9);
  gp_Pnt     p      = g->Value(u, v);
  printf("%-36s : (%.6f, %.6f, %.6f)   uv inside output domain: %s\n",
         label,
         p.X(),
         p.Y(),
         p.Z(),
         inside ? "yes" : "NO");
}

// The bridge's own 20x20 sample grid, rebuilt here from the same solver, reported as the
// largest coordinate magnitude with and without the extra base term the bridge used to add.
static void gridStats(const char* label,
                      const NLPlate_NLPlate& solver,
                      const Handle(Geom_Surface) & base,
                      double u1,
                      double u2,
                      double v1,
                      double v2)
{
  double worstSolver = 0.0, worstDoubled = 0.0;
  for (int iu = 1; iu <= 20; iu++)
  {
    const double pu = u1 + (u2 - u1) * (iu - 1) / 19.0;
    for (int iv = 1; iv <= 20; iv++)
    {
      const double pv  = v1 + (v2 - v1) * (iv - 1) / 19.0;
      const gp_XYZ val = solver.Evaluate(gp_XY(pu, pv));
      const gp_Pnt b   = base->Value(pu, pv);
      worstSolver      = std::max(worstSolver, gp_Pnt(val.X(), val.Y(), val.Z()).XYZ().Modulus());
      worstDoubled =
        std::max(worstDoubled, gp_XYZ(val.X() + b.X(), val.Y() + b.Y(), val.Z() + b.Z()).Modulus());
    }
  }
  printf("%-36s : max |solver.Evaluate| %.6g,  max |base + Evaluate| %.6g\n",
         label,
         worstSolver,
         worstDoubled);
}

// Largest distance between the returned surface and the solver, compared at the same (u, v).
// Once the output carries the working domain's own parametrisation this is a direct question,
// with no mapping in between.
static double fitDeviation(OCCTSurfaceRef s,
                           const NLPlate_NLPlate& solver,
                           double u1,
                           double u2,
                           double v1,
                           double v2)
{
  if (!s)
    return -1.0;
  Handle(Geom_Surface) g     = ((OCCTSurface*)s)->surface;
  double               worst = 0.0;
  for (int i = 0; i <= 8; i++)
  {
    for (int j = 0; j <= 8; j++)
    {
      const double u   = u1 + (u2 - u1) * double(i) / 8.0;
      const double v   = v1 + (v2 - v1) * double(j) / 8.0;
      const gp_XYZ val = solver.Evaluate(gp_XY(u, v));
      worst = std::max(worst, g->Value(u, v).Distance(gp_Pnt(val.X(), val.Y(), val.Z())));
    }
  }
  return worst;
}

// Largest distance between the returned surface and the input surface, both walked over their
// own domains in step. Meaningful for the identity fixture, where the two must coincide.
static double deviationFromInput(OCCTSurfaceRef s,
                                 const Handle(Geom_Surface) & base,
                                 double wu1,
                                 double wu2,
                                 double wv1,
                                 double wv2)
{
  if (!s)
    return -1.0;
  Handle(Geom_Surface) g = ((OCCTSurface*)s)->surface;
  Standard_Real        u1, u2, v1, v2;
  g->Bounds(u1, u2, v1, v2);
  double worst = 0.0;
  for (int i = 0; i <= 8; i++)
  {
    for (int j = 0; j <= 8; j++)
    {
      const double t = double(i) / 8.0;
      const double w = double(j) / 8.0;
      worst          = std::max(worst,
                       g->Value(u1 + (u2 - u1) * t, v1 + (v2 - v1) * w)
                         .Distance(base->Value(wu1 + (wu2 - wu1) * t, wv1 + (wv2 - wv1) * w)));
    }
  }
  return worst;
}

int main()
{
  printf("=== the kernel's own contract ===\n");
  {
    // NLPlate_NLPlate::Evaluate is EvaluateDerivative(uv, 0, 0), which seeds Value with
    // myInitialSurface->Value(uv) and then adds each plate. So it is the absolute deformed
    // point. Iterate() corroborates: it loads G0Target() - Evaluate(UV) as the pinpoint
    // constraint, a subtraction that only makes sense if Evaluate is a point in the same
    // space as the target.
    Handle(Geom_Plane) pl = planeSurface(100, 0, 0);
    printf("base plane Value(0,0)                : (%.6f, %.6f, %.6f)\n",
           pl->Value(0, 0).X(),
           pl->Value(0, 0).Y(),
           pl->Value(0, 0).Z());
    printf("base plane Value(3,4)                : (%.6f, %.6f, %.6f)\n",
           pl->Value(3, 4).X(),
           pl->Value(3, 4).Y(),
           pl->Value(3, 4).Z());

    NLPlate_NLPlate solver(pl);
    solver.Load(new NLPlate_HPG0Constraint(gp_XY(0, 0), gp_XYZ(100, 0, 5)));
    solver.Solve2(4, 1);
    gp_XYZ e = solver.Evaluate(gp_XY(0, 0));
    printf("solver.IsDone                        : %s\n", solver.IsDone() ? "yes" : "no");
    printf("solver.Evaluate((0,0))               : (%.6f, %.6f, %.6f)\n", e.X(), e.Y(), e.Z());
    printf("  the constraint target was          : (100.000000, 0.000000, 5.000000)\n");
    gp_XYZ f = solver.Evaluate(gp_XY(3, 4));
    printf("solver.Evaluate((3,4))               : (%.6f, %.6f, %.6f)\n", f.X(), f.Y(), f.Z());
    printf("  which is the base point plus 5 in z, so Evaluate is a point, not a displacement\n");
  }

  printf("\n=== fixture 1: off-origin plane, zero-displacement G0 constraint ===\n");
  printf("Plane through (100, 0, 0), normal +Z. The constraint pins uv (0,0) to its own base\n");
  printf("point (100, 0, 0), so the plate load is the zero vector, the plate solution is\n");
  printf("identically zero, and the correct answer is the input surface itself over the\n");
  printf("working domain [-10, 10] x [-10, 10]. The doubled answer is 2 * base, whose worst\n");
  printf("deviation is |base(10, 10)| = sqrt(110^2 + 10^2) = 110.4536101718726.\n");
  {
    Handle(Geom_Plane) base = planeSurface(100, 0, 0);
    OCCTSurfaceRef     in   = wrap(base);
    double             c[5] = {0, 0, 100, 0, 0};
    OCCTSurfaceRef     out  = OCCTSurfaceNLPlateG0(in, c, 1, 4, 1e-3);
    report("G0 identity output", out);
    printf("%-36s : %.9f\n",
           "deviation from the input surface",
           deviationFromInput(out, base, -10, 10, -10, 10));
    freeSurface(out);
    freeSurface(in);
  }

  printf("\n=== fixture 2: off-origin plane, +5 in Z at uv (0,0), G0 ===\n");
  {
    Handle(Geom_Plane) base = planeSurface(100, 0, 0);
    OCCTSurfaceRef     in   = wrap(base);
    double             c[5] = {0, 0, 100, 0, 5};
    OCCTSurfaceRef     out  = OCCTSurfaceNLPlateG0(in, c, 1, 4, 1e-3);
    report("G0 output", out);
    pointAt("G0 at the caller's own uv (0,0)", out, 0, 0);
    printf("%-36s : (100.000000, 0.000000, 5.000000)\n", "  the constraint target was");

    NLPlate_NLPlate solver(new Geom_RectangularTrimmedSurface(base, -10.0, 10.0, -10.0, 10.0));
    solver.Load(new NLPlate_HPG0Constraint(gp_XY(0, 0), gp_XYZ(100, 0, 5)));
    solver.Solve2(4, 1);
    gridStats("G0 grid", solver, base, -10, 10, -10, 10);
    printf("%-36s : %.9g\n", "G0 output vs solver", fitDeviation(out, solver, -10, 10, -10, 10));
    freeSurface(out);
    freeSurface(in);
  }

  printf("\n=== fixture 3: same plane, G1 ===\n");
  {
    Handle(Geom_Plane) base   = planeSurface(100, 0, 0);
    OCCTSurfaceRef     in     = wrap(base);
    double             c[11]  = {0, 0, 100, 0, 5, 1, 0, 0.5, 0, 1, 0.5};
    OCCTSurfaceRef     out    = OCCTSurfaceNLPlateG1(in, c, 1, 4, 1e-3);
    report("G1 output", out);
    pointAt("G1 at the caller's own uv (0,0)", out, 0, 0);

    NLPlate_NLPlate solver(new Geom_RectangularTrimmedSurface(base, -10.0, 10.0, -10.0, 10.0));
    solver.Load(new NLPlate_HPG0G1Constraint(
      gp_XY(0, 0), gp_XYZ(100, 0, 5), Plate_D1(gp_XYZ(1, 0, 0.5), gp_XYZ(0, 1, 0.5))));
    solver.Solve2(4, 1);
    gridStats("G1 grid", solver, base, -10, 10, -10, 10);
    printf("%-36s : %.9g\n", "G1 output vs solver", fitDeviation(out, solver, -10, 10, -10, 10));
    freeSurface(out);
    freeSurface(in);
  }

  printf("\n=== fixture 4: same plane, G2 / G3 / Incremental ===\n");
  {
    Handle(Geom_Plane) base = planeSurface(100, 0, 0);
    OCCTSurfaceRef     in   = wrap(base);

    double c2[20] = {0, 0, 100, 0, 5, 1, 0, 0, 0, 1, 0, 0, 0, 0.1, 0, 0, 0, 0, 0, 0.1};
    OCCTSurfaceRef g2 = OCCTSurfaceNLPlateG2(in, c2, 1, 1e-3);
    report("G2 output", g2);
    pointAt("G2 at the caller's own uv (0,0)", g2, 0, 0);
    freeSurface(g2);

    double c3[32] = {0, 0, 100, 0, 5, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    OCCTSurfaceRef g3 = OCCTSurfaceNLPlateG3(in, c3, 1, 1e-3);
    report("G3 output", g3);
    pointAt("G3 at the caller's own uv (0,0)", g3, 0, 0);
    freeSurface(g3);

    double         ci[5] = {0, 0, 100, 0, 5};
    OCCTSurfaceRef inc   = OCCTSurfaceNLPlateIncrementalG0(in, ci, 1, 2, 1, 4);
    report("Incremental output", inc);
    pointAt("Incremental at the caller's (0,0)", inc, 0, 0);
    freeSurface(inc);

    freeSurface(in);
  }

  printf("\n=== fixture 4b: the identity constraint on all five entry points ===\n");
  printf("Same plane through (100, 0, 0). Every constraint asks for exactly what the base\n");
  printf("surface already has at uv (0,0), including its derivatives, so the plate load is\n");
  printf("zero and the correct answer is the input surface over [-10, 10] x [-10, 10].\n");
  {
    Handle(Geom_Plane) base = planeSurface(100, 0, 0);
    OCCTSurfaceRef     in   = wrap(base);

    double         g0[5] = {0, 0, 100, 0, 0};
    OCCTSurfaceRef s0    = OCCTSurfaceNLPlateG0(in, g0, 1, 4, 1e-3);
    printf("%-36s : %.12g\n", "G0 identity deviation", deviationFromInput(s0, base, -10, 10, -10, 10));
    freeSurface(s0);

    double         g1[11] = {0, 0, 100, 0, 0, 1, 0, 0, 0, 1, 0};
    OCCTSurfaceRef s1     = OCCTSurfaceNLPlateG1(in, g1, 1, 4, 1e-3);
    printf("%-36s : %.12g\n", "G1 identity deviation", deviationFromInput(s1, base, -10, 10, -10, 10));
    freeSurface(s1);

    double g2[20] = {0, 0, 100, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    OCCTSurfaceRef s2 = OCCTSurfaceNLPlateG2(in, g2, 1, 1e-3);
    printf("%-36s : %.12g\n", "G2 identity deviation", deviationFromInput(s2, base, -10, 10, -10, 10));
    freeSurface(s2);

    double g3[32] = {0, 0, 100, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    OCCTSurfaceRef s3 = OCCTSurfaceNLPlateG3(in, g3, 1, 1e-3);
    printf("%-36s : %.12g\n", "G3 identity deviation", deviationFromInput(s3, base, -10, 10, -10, 10));
    freeSurface(s3);

    double         gi[5] = {0, 0, 100, 0, 0};
    OCCTSurfaceRef si    = OCCTSurfaceNLPlateIncrementalG0(in, gi, 1, 2, 1, 4);
    printf("%-36s : %.12g\n",
           "Incremental identity deviation",
           deviationFromInput(si, base, -10, 10, -10, 10));
    freeSurface(si);

    freeSurface(in);
  }

  printf("\n=== fixture 4c: a pure-Z G0 constraint leaves x and y alone ===\n");
  printf("The pinpoint load a G0 constraint contributes is target - Evaluate(uv), so a target\n");
  printf("differing from the base only in z gives a plate with no x or y component at all,\n");
  printf("and the deformed surface keeps the base's own x = 100 + u and y = v everywhere.\n");
  {
    Handle(Geom_Plane) base = planeSurface(100, 0, 0);
    OCCTSurfaceRef     in   = wrap(base);
    double             c[5] = {0, 0, 100, 0, 5};
    OCCTSurfaceRef     out  = OCCTSurfaceNLPlateG0(in, c, 1, 4, 1e-3);
    if (out)
    {
      Handle(Geom_Surface) g      = ((OCCTSurface*)out)->surface;
      double               worst  = 0.0;
      double               maxAbsZ = 0.0;
      for (int i = 0; i <= 8; i++)
      {
        for (int j = 0; j <= 8; j++)
        {
          const double u = -10.0 + 20.0 * double(i) / 8.0;
          const double v = -10.0 + 20.0 * double(j) / 8.0;
          gp_Pnt       p = g->Value(u, v);
          worst          = std::max(worst, std::max(std::abs(p.X() - (100.0 + u)), std::abs(p.Y() - v)));
          maxAbsZ        = std::max(maxAbsZ, std::abs(p.Z()));
        }
      }
      printf("%-36s : %.12g\n", "worst |x - (100 + u)|, |y - v|", worst);
      printf("%-36s : %.12g\n", "max |z| over the domain", maxAbsZ);
    }
    freeSurface(out);
    freeSurface(in);
  }

  printf("\n=== fixture 5: cylinder radius 10 at the origin, G0 ===\n");
  printf("The u of a cylinder is an angle and its own bound is [0, 2pi]; only v is unbounded.\n");
  {
    Handle(Geom_CylindricalSurface) base = cylinderSurface(10);
    OCCTSurfaceRef                  in   = wrap(base);
    // Constraint at u = pi/2, v = 0, pushed 2 units outward in +Y.
    double         c[5] = {M_PI / 2, 0, 0, 12, 0};
    OCCTSurfaceRef out  = OCCTSurfaceNLPlateG0(in, c, 1, 4, 1e-3);
    report("cylinder G0 output", out);
    pointAt("cylinder G0 at the caller's u=pi/2", out, M_PI / 2, 0);
    printf("%-36s : (0.000000, 12.000000, 0.000000)\n", "  the constraint target was");

    NLPlate_NLPlate solver(new Geom_RectangularTrimmedSurface(base, 0.0, 2 * M_PI, -10.0, 10.0));
    solver.Load(new NLPlate_HPG0Constraint(gp_XY(M_PI / 2, 0), gp_XYZ(0, 12, 0)));
    solver.Solve2(4, 1);
    gp_XYZ e = solver.Evaluate(gp_XY(M_PI / 2, 0));
    printf("%-36s : (%.6f, %.6f, %.6f)\n", "  solver.Evaluate there", e.X(), e.Y(), e.Z());
    gridStats("cylinder G0 grid", solver, base, 0, 2 * M_PI, -10, 10);
    printf("%-36s : %.9g\n",
           "cylinder output vs solver",
           fitDeviation(out, solver, 0, 2 * M_PI, -10, 10));
    freeSurface(out);
    freeSurface(in);
  }

  printf("\n=== fixture 6: origin plane, the shape every shipped test uses ===\n");
  printf("The base is (u, v, 0), zero only at uv (0,0), so doubling stretches the patch by\n");
  printf("two in u and v everywhere else. No shipped test asserted a coordinate.\n");
  {
    Handle(Geom_Plane) base = planeSurface(0, 0, 0);
    OCCTSurfaceRef     in   = wrap(base);
    double             c[5] = {0, 0, 0, 0, 5};
    OCCTSurfaceRef     out  = OCCTSurfaceNLPlateG0(in, c, 1, 4, 0.1);
    report("origin plane G0 output", out);
    pointAt("at the caller's uv (0,0)", out, 0, 0);
    pointAt("at the caller's uv (5,5)", out, 5, 5);
    printf("%-36s : (5.000000, 5.000000, ...)\n", "  base there is");
    freeSurface(out);
    freeSurface(in);
  }

  return 0;
}
