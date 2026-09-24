// Epic #766, NLPlateDeformationTests.swift: kernel parity for the seven tests. The same
// NLPlate_NLPlate solve the bridge runs (OCCTSurfaceNLPlateG0 / G1: one NLPlate_HPG0Constraint or
// NLPlate_HPG0G1Constraint per input, Solve2(order, 1)) on the z = 0 Geom_Plane, then
// NLPlate_NLPlate::Evaluate at each constraint's (u, v): base point + solved displacement.
// This is the solver's own answer, before the bridge's working-domain trim and BSpline fit.
#include <Geom_Plane.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG0G1Constraint.hxx>
#include <NLPlate_NLPlate.hxx>
#include <Plate_D1.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <vector>

struct C
{
  double u, v, x, y, z;
  double tu[3], tv[3];
};

static void run(const char* name, const std::vector<C>& cs, int order, bool g1)
{
  try
  {
    Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    NLPlate_NLPlate    solver(plane);
    for (const C& c : cs)
    {
      if (g1)
        solver.Load(new NLPlate_HPG0G1Constraint(gp_XY(c.u, c.v), gp_XYZ(c.x, c.y, c.z),
                                                 Plate_D1(gp_XYZ(c.tu[0], c.tu[1], c.tu[2]), gp_XYZ(c.tv[0], c.tv[1], c.tv[2]))));
      else
        solver.Load(new NLPlate_HPG0Constraint(gp_XY(c.u, c.v), gp_XYZ(c.x, c.y, c.z)));
    }
    solver.Solve2(order, 1);
    printf("%s: IsDone=%d", name, solver.IsDone());
    if (solver.IsDone())
      for (const C& c : cs)
      {
        gp_XYZ p = plane->Value(c.u, c.v).XYZ() + solver.Evaluate(gp_XY(c.u, c.v));
        printf(" S(%g,%g)=(%.9g, %.9g, %.9g)", c.u, c.v, p.X(), p.Y(), p.Z());
      }
    printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", name, e.GetMessageString());
  }
}

int main()
{
  run("nlPlateG0FlatPlane", {{0, 0, 0, 0, 5}}, 4, false);
  run("nlPlateG0MultipleConstraints", {{-5, -5, -5, -5, 1}, {5, 5, 5, 5, 2}, {0, 0, 0, 0, 5}}, 4, false);
  run("nlPlateG0Evaluable", {{0, 0, 0, 0, 3}}, 4, false);
  run("nlPlateG1Deformation", {{0, 0, 0, 0, 5, {1, 0, 0.5}, {0, 1, 0.5}}}, 4, true);
  run("nlPlateG1MultipleConstraints", {{-2, 0, -2, 0, 1, {1, 0, 0.2}, {0, 1, 0}}, {2, 0, 2, 0, 1, {1, 0, -0.2}, {0, 1, 0}}}, 8, true);
  return 0;
}
