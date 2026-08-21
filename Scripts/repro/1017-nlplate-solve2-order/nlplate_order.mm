// Ground truth for #1017: OCCTSurfaceNLPlateG0/G1 name a parameter maxIterations and pass it as
// NLPlate_NLPlate::Solve2's first argument, which is the plate's resolution order.
// This probe reproduces the bridge's own G0 and G1 paths line for line, on the exact fixtures the
// disabled NLPlateDeformationTests use, and sweeps the value the bridge calls maxIter.
#include <Geom_BSplineSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_Surface.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <GeomAbs_Shape.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG0G1Constraint.hxx>
#include <NLPlate_NLPlate.hxx>
#include <Plate_D1.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <gp_Ax3.hxx>
#include <gp_XY.hxx>
#include <gp_XYZ.hxx>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>

namespace
{

struct G0Constraint
{
  double u, v;
  double x, y, z;
};

struct G1Constraint
{
  double u, v;
  double x, y, z;
  double dux, duy, duz;
  double dvx, dvy, dvz;
};

// The three-constraint fixture from NLPlateDeformationTests.nlPlateG0MultipleConstraints.
const G0Constraint kG0[] = {
  {-5, -5, -5, -5, 1.0},
  {5, 5, 5, 5, 2.0},
  {0, 0, 0, 0, 5.0},
};

// The two-constraint fixture from NLPlateDeformationTests.nlPlateG1MultipleConstraints,
// which is the one that passes maxIterations: 8.
const G1Constraint kG1[] = {
  {-2, 0, -2, 0, 1.0, 1, 0, 0.2, 0, 1, 0},
  {2, 0, 2, 0, 1.0, 1, 0, -0.2, 0, 1, 0},
};

// Surface.plane is an unbounded Geom_Plane, so the bridge takes its needsTrim branch.
Handle(Geom_Surface) trimmedWorkSurface(double& u1, double& u2, double& v1, double& v2, bool isG1)
{
  Handle(Geom_Surface) plane =
    new Geom_Plane(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)));
  double minU = 1e30, maxU = -1e30, minV = 1e30, maxV = -1e30;
  if (isG1)
  {
    for (const G1Constraint& c : kG1)
    {
      minU = std::min(minU, c.u);
      maxU = std::max(maxU, c.u);
      minV = std::min(minV, c.v);
      maxV = std::max(maxV, c.v);
    }
  }
  else
  {
    for (const G0Constraint& c : kG0)
    {
      minU = std::min(minU, c.u);
      maxU = std::max(maxU, c.u);
      minV = std::min(minV, c.v);
      maxV = std::max(maxV, c.v);
    }
  }
  double padU = std::max(10.0, (maxU - minU) * 0.5);
  double padV = std::max(10.0, (maxV - minV) * 0.5);
  u1          = minU - padU;
  u2          = maxU + padU;
  v1          = minV - padV;
  v2          = maxV + padV;
  return new Geom_RectangularTrimmedSurface(plane, u1, u2, v1, v2);
}

// The bridge's own 20x20 sample-and-fit, reduced to two numbers: the largest absolute Z anywhere
// on the grid (the base plane is z = 0, so 0 means the solve moved nothing) and the worst distance
// from the solved field to the constraint targets.
void report(const char* label,
            NLPlate_NLPlate& solver,
            const Handle(Geom_Surface) & work,
            double u1,
            double u2,
            double v1,
            double v2,
            bool   isG1)
{
  if (!solver.IsDone())
  {
    printf("%-24s IsDone=false\n", label);
    return;
  }
  int                nu = 20, nv = 20;
  TColgp_Array2OfPnt poles(1, nu, 1, nv);
  double             maxAbsZ = 0;
  for (int iu = 1; iu <= nu; iu++)
  {
    double pu = u1 + (u2 - u1) * (iu - 1) / (nu - 1);
    for (int iv = 1; iv <= nv; iv++)
    {
      double pv   = v1 + (v2 - v1) * (iv - 1) / (nv - 1);
      gp_XYZ disp = solver.Evaluate(gp_XY(pu, pv));
      gp_Pnt orig;
      work->D0(pu, pv, orig);
      gp_Pnt np(orig.X() + disp.X(), orig.Y() + disp.Y(), orig.Z() + disp.Z());
      poles(iu, iv) = np;
      maxAbsZ       = std::max(maxAbsZ, std::abs(np.Z()));
    }
  }
  double worst = 0;
  if (isG1)
  {
    for (const G1Constraint& c : kG1)
    {
      gp_XYZ val = solver.Evaluate(gp_XY(c.u, c.v));
      worst      = std::max(worst, std::abs(val.Z() - c.z));
    }
  }
  else
  {
    for (const G0Constraint& c : kG0)
    {
      gp_XYZ val = solver.Evaluate(gp_XY(c.u, c.v));
      worst      = std::max(worst, std::abs(val.Z() - c.z));
    }
  }

  // The bridge wraps this whole body in try/catch(...) and returns nullptr, so record which
  // sweep rows would have come back as a plain nil rather than a surface.
  const char* fit = "ok";
  try
  {
    GeomAPI_PointsToBSplineSurface approx;
    approx.Init(poles, 3, 8, GeomAbs_C2, 0.1);
    Handle(Geom_BSplineSurface) fitted = approx.Surface();
    if (fitted.IsNull())
      fit = "null";
  }
  catch (const Standard_Failure&)
  {
    fit = "threw";
  }
  catch (...)
  {
    fit = "threw";
  }

  printf("%-24s IsDone=true  continuity=%d  maxAbsGridZ=%.9g  worstConstraintMissZ=%.9g  fit=%s\n",
         label,
         solver.Continuity(),
         maxAbsZ,
         worst,
         fit);
}

void runG0(int ord, int initialConstraintOrder)
{
  double               u1, u2, v1, v2;
  Handle(Geom_Surface) work = trimmedWorkSurface(u1, u2, v1, v2, false);
  NLPlate_NLPlate      solver(work);
  for (const G0Constraint& c : kG0)
    solver.Load(new NLPlate_HPG0Constraint(gp_XY(c.u, c.v), gp_XYZ(c.x, c.y, c.z)));
  char label[64];
  snprintf(label, sizeof(label), "G0 Solve2(%d, %d)", ord, initialConstraintOrder);
  solver.Solve2(ord, initialConstraintOrder);
  report(label, solver, work, u1, u2, v1, v2, false);
  fflush(stdout);
}

void runG1(int ord, int initialConstraintOrder)
{
  double               u1, u2, v1, v2;
  Handle(Geom_Surface) work = trimmedWorkSurface(u1, u2, v1, v2, true);
  NLPlate_NLPlate      solver(work);
  for (const G1Constraint& c : kG1)
  {
    Plate_D1 d1(gp_XYZ(c.dux, c.duy, c.duz), gp_XYZ(c.dvx, c.dvy, c.dvz));
    solver.Load(new NLPlate_HPG0G1Constraint(gp_XY(c.u, c.v), gp_XYZ(c.x, c.y, c.z), d1));
  }
  char label[64];
  snprintf(label, sizeof(label), "G1 Solve2(%d, %d)", ord, initialConstraintOrder);
  solver.Solve2(ord, initialConstraintOrder);
  report(label, solver, work, u1, u2, v1, v2, true);
  fflush(stdout);
}

} // namespace

int main()
{
  printf("=== G0, three constraints, sweeping the value the bridge calls maxIter ===\n");
  for (int ord : {0, 1, 2, 3, 4, 5, 8, 9, 10, 12, 100})
    runG0(ord, 1);

  printf("\n=== G1, two constraints, same sweep ===\n");
  for (int ord : {0, 1, 2, 3, 4, 5, 8, 9, 10, 12, 100})
    runG1(ord, 1);

  // Solve2's second argument is never passed by either bridge entry point. Its loop runs from
  // InitialConsraintOrder up to MaxActiveConstraintOrder, which is 0 for pure G0 constraints and
  // 1 for G0+G1, so the question is whether it is reachable at all from these two.
  printf("\n=== InitialConsraintOrder at the shipped order of 4 ===\n");
  for (int ico : {-1, 0, 1, 2, 3})
    runG0(4, ico);
  for (int ico : {-1, 0, 1, 2, 3})
    runG1(4, ico);

  printf("\ndone\n");
  return 0;
}
