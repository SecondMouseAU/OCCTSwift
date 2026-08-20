// Ground truth for #999 site 5: OCCTSurfaceNLPlateG2/G3 declare maxIter and call
// NLPlate_NLPlate::Solve2(ord, InitialConsraintOrder), which takes no iteration count.
// IncrementalSolve does take an NbIncrements. Measured here before choosing between
// "remove the parameter" and "IncrementalSolve was the intended entry point".
#include <Geom_Plane.hxx>
#include <Geom_Surface.hxx>
#include <NLPlate_NLPlate.hxx>
#include <NLPlate_HPG0G2Constraint.hxx>
#include <Plate_D1.hxx>
#include <Plate_D2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pln.hxx>
#include <gp_XY.hxx>
#include <gp_XYZ.hxx>
#include <cstdio>
#include <cmath>

namespace
{

struct Constraint
{
  double u, v;
  double x, y, z;
};

// A saddle of G0+G2 constraints on a flat plane: enough deformation that a solver strategy
// change would show up in the evaluated surface.
// Deliberately large out-of-plane displacement (+-40 on a 10x10 plane): a mild deformation
// converges in one step for any strategy, which would make every row agree for a reason that
// has nothing to do with the parameter under test.
const Constraint kConstraints[] = {
  {0.25, 0.25, 2.5, 2.5, 40.0},
  {0.75, 0.25, 7.5, 2.5, -40.0},
  {0.25, 0.75, 2.5, 7.5, -40.0},
  {0.75, 0.75, 7.5, 7.5, 40.0},
  {0.50, 0.50, 5.0, 5.0, 12.0},
};

void load(NLPlate_NLPlate& solver)
{
  for (const Constraint& c : kConstraints)
  {
    gp_XY    uv(c.u, c.v);
    gp_XYZ   target(c.x, c.y, c.z);
    Plate_D1 d1(gp_XYZ(1, 0, 0), gp_XYZ(0, 1, 0));
    Plate_D2 d2(gp_XYZ(0, 0, 0), gp_XYZ(0, 0, 0), gp_XYZ(0, 0, 0));
    solver.Load(new NLPlate_HPG0G2Constraint(uv, target, d1, d2));
  }
}

Handle(Geom_Surface) basePlane()
{
  // A 10x10 plane parameterised so that (u, v) in [0, 1] covers it, matching how
  // OCCTSurfaceNLPlateG2 samples its 20x20 grid over [0, 1] x [0, 1].
  return new Geom_Plane(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
}

// A fingerprint of the solved surface: the 21 grid samples summed, plus the worst deviation
// from the loaded constraints. Two solver calls that agree on both agree on the answer.
void report(const char* label, NLPlate_NLPlate& solver)
{
  if (!solver.IsDone())
  {
    printf("%-26s NOT DONE\n", label);
    return;
  }
  // Sample the diagonal as well as a mid-row: a saddle is symmetric across v = 0.5, so a
  // mid-row-only checksum would agree between genuinely different surfaces.
  double checksum = 0;
  for (int i = 0; i <= 20; i++)
  {
    double u = i / 20.0;
    gp_XYZ a = solver.Evaluate(gp_XY(u, 0.5));
    gp_XYZ b = solver.Evaluate(gp_XY(u, u));
    gp_XYZ c = solver.Evaluate(gp_XY(u, 0.3 + 0.4 * u));
    checksum += a.X() + a.Y() + a.Z() + b.Z() * 1000 + c.Z() * 1e6;
  }
  double worst = 0;
  for (const Constraint& c : kConstraints)
  {
    gp_XYZ val = solver.Evaluate(gp_XY(c.u, c.v));
    double d   = sqrt((val.X() - c.x) * (val.X() - c.x) + (val.Y() - c.y) * (val.Y() - c.y)
                    + (val.Z() - c.z) * (val.Z() - c.z));
    if (d > worst)
      worst = d;
  }
  printf("%-26s checksum=%.12f  worstConstraintMiss=%.12g  continuity=%d\n",
         label,
         checksum,
         worst,
         solver.Continuity());
}

} // namespace

int main()
{
  {
    NLPlate_NLPlate solver(basePlane());
    load(solver);
    solver.Solve2(2, 1);
    report("Solve2(2, 1)", solver);
  }
  {
    NLPlate_NLPlate solver(basePlane());
    load(solver);
    solver.Solve(2, 1);
    report("Solve(2, 1)", solver);
  }
  for (int n : {1, 2, 4, 8, 16})
  {
    NLPlate_NLPlate solver(basePlane());
    load(solver);
    solver.IncrementalSolve(2, 1, n, false);
    char label[64];
    snprintf(label, sizeof(label), "IncrementalSolve n=%d", n);
    report(label, solver);
  }
  return 0;
}
