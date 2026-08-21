// #1018 reproducer: GeomPlate_BuildPlateSurface::G0Error()/G1Error()/G2Error() return
// uninitialised members after a Perform() whose constraints were all point constraints.
//
// Mechanism, read from GeomPlate_BuildPlateSurface.cxx at the pinned V8_0_1:
//   - myG0Error / myG1Error / myG2Error have no in-class initialiser and no constructor writes
//     them (three constructors, none mentions any of the three).
//   - VerifSurface() is the only writer (myG0Error = 0, myG1Error = 0, myG2Error = 0 followed by
//     a max loop over the curve constraints).
//   - Perform() calls VerifSurface() only on the branch that has curve constraints. The point-only
//     branch ends with VerifPoints(di, an, cu), whose three deviations go into locals and are
//     discarded.
//
// Four sections:
//   A. point-only plate, placement-new'd over a buffer filled with 0x5A, so the read is visible as
//      a specific bit pattern rather than as "some number". This isolates the constructors: the
//      pattern survives construction, which is only possible if nothing wrote the members.
//   B. the same plate built on the stack, which is what a caller actually writes.
//   C. the deviations the kernel computed and threw away, recomputed here from the built surface,
//      so the value the members SHOULD carry is measured rather than asserted.
//   D. a plate with a curve constraint, which takes the VerifSurface() branch. This is the control:
//      the patch must not move these numbers.
//
// Build (unpatched): see run.sh.

#include <GeomAdaptor_Curve.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Message_ProgressRange.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Circ.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>

#include <cstdio>
#include <cstdlib>
#include <algorithm>
#include <cstring>
#include <new>
#include <vector>

namespace
{

struct Pt
{
  double x, y, z;
};

// A wavy 5x5 grid, the same fixture shape #999's probe used, so the plate has something to deviate
// from rather than interpolating a plane exactly.
std::vector<Pt> gridPoints()
{
  std::vector<Pt> pts;
  for (int i = 0; i < 5; i++)
  {
    for (int j = 0; j < 5; j++)
    {
      const double x = i * 2.5;
      const double y = j * 2.5;
      pts.push_back({x, y, 2.0 * ((i + j) % 2 ? 1.0 : -1.0) + 0.35 * x - 0.2 * y});
    }
  }
  return pts;
}

void addPoints(GeomPlate_BuildPlateSurface& theBuilder, const std::vector<Pt>& thePts)
{
  for (const Pt& aP : thePts)
  {
    theBuilder.Add(new GeomPlate_PointConstraint(gp_Pnt(aP.x, aP.y, aP.z), 0, 1e-4));
  }
}

void report(const char* theLabel, GeomPlate_BuildPlateSurface& theBuilder)
{
  if (!theBuilder.IsDone())
  {
    printf("%-46s NOT DONE\n", theLabel);
    return;
  }
  printf("%-46s G0=%.12g G1=%.12g G2=%.12g\n",
         theLabel,
         theBuilder.G0Error(),
         theBuilder.G1Error(),
         theBuilder.G2Error());
}

// The deviations VerifPoints() computes and discards, recomputed from outside the class with the
// same formulas VerifPoints() uses: for an order-0 constraint the distance from its 2d location on
// the built plate to the 3d point it was built from, and for an order-1 constraint that distance
// plus the angle between the two normals.
//
// Reported as both the maximum and the last, because VerifPoints() assigns rather than accumulates,
// so "the last constraint's deviation" and "the max over constraints" are different numbers and
// only the second matches what G0Error() documents ("the max distance").
void reportDiscardedPointDeviations(GeomPlate_BuildPlateSurface& theBuilder, const int theNbPts)
{
  if (!theBuilder.IsDone())
  {
    printf("  plate not done, nothing to measure\n");
    return;
  }
  occ::handle<GeomPlate_Surface> aPlate = theBuilder.Surface();
  double aMaxD = 0.0, aLastD = 0.0, aMaxA = 0.0, aLastA = 0.0;
  for (int i = 1; i <= theNbPts; i++)
  {
    occ::handle<GeomPlate_PointConstraint> aPC = theBuilder.PointConstraint(i);
    const gp_Pnt2d                         a2d = aPC->Pnt2dOnSurf();
    double                                 aD = 0.0, aA = 0.0;
    if (aPC->Order() == 0)
    {
      gp_Pnt aTarget;
      aPC->D0(aTarget);
      gp_Pnt aOnPlate;
      aPlate->D0(a2d.Coord(1), a2d.Coord(2), aOnPlate);
      aD = aOnPlate.Distance(aTarget);
    }
    else if (aPC->Order() == 1)
    {
      gp_Pnt aTarget, aOnPlate;
      gp_Vec a1i, a2i, a1f, a2f;
      aPC->D1(aTarget, a1i, a2i);
      aPlate->D1(a2d.Coord(1), a2d.Coord(2), aOnPlate, a1f, a2f);
      aD = aOnPlate.Distance(aTarget);
      aA = (a1f ^ a2f).Angle(a1i ^ a2i);
      if (aA > (M_PI / 2))
      {
        aA = M_PI - aA;
      }
    }
    aLastD = aD;
    aLastA = aA;
    aMaxD  = std::max(aMaxD, aD);
    aMaxA  = std::max(aMaxA, aA);
  }
  printf("  discarded by VerifPoints: dist max=%.12g last=%.12g | angle max=%.12g last=%.12g\n",
         aMaxD,
         aLastD,
         aMaxA,
         aLastA);
}

} // namespace

int main()
{
  const std::vector<Pt> aPts = gridPoints();

  printf("=== A. point-only plate, placement-new over a 0x5A-filled buffer ===\n");
  printf("    0x5A repeated reads back as 1.78389e+127. A constructor that writes the three\n");
  printf("    members overwrites the pattern; the pinned kernel's does not.\n");
  {
    alignas(GeomPlate_BuildPlateSurface) unsigned char aBuf[sizeof(GeomPlate_BuildPlateSurface)];
    memset(aBuf, 0x5A, sizeof(aBuf));
    GeomPlate_BuildPlateSurface* aBuilder =
      new (static_cast<void*>(aBuf)) GeomPlate_BuildPlateSurface(3, 10, 5, 1e-5, 1e-1);
    printf("  after the constructor, before Perform()        G0=%.12g G1=%.12g G2=%.12g\n",
           aBuilder->G0Error(),
           aBuilder->G1Error(),
           aBuilder->G2Error());
    addPoints(*aBuilder, aPts);
    aBuilder->Perform(Message_ProgressRange());
    report("  after Perform(), point-only", *aBuilder);
    aBuilder->~GeomPlate_BuildPlateSurface();
  }

  printf("\n=== B. point-only plate, ordinary stack construction, three times in one process ===\n");
  for (int aRun = 0; aRun < 3; aRun++)
  {
    GeomPlate_BuildPlateSurface aBuilder(3, 10, 5, 1e-5, 1e-1);
    addPoints(aBuilder, aPts);
    aBuilder.Perform(Message_ProgressRange());
    char aLabel[96];
    snprintf(aLabel, sizeof(aLabel), "  run %d: after Perform(), point-only", aRun);
    report(aLabel, aBuilder);
  }

  printf("\n=== C. what the point-only branch measured and threw away ===\n");
  {
    GeomPlate_BuildPlateSurface aBuilder(3, 10, 5, 1e-5, 1e-1);
    addPoints(aBuilder, aPts);
    aBuilder.Perform(Message_ProgressRange());
    report("  point-only plate, order 0", aBuilder);
    reportDiscardedPointDeviations(aBuilder, (int)aPts.size());
  }
  {
    // Order-1 constraints taken off a sphere, so the plate is asked to match normals it cannot all
    // match at once. This is where a fabricated 0 would be furthest from the truth.
    GeomPlate_BuildPlateSurface aBuilder(3, 10, 5, 1e-5, 1e-1);
    occ::handle<Geom_SphericalSurface> aSphere =
      new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0.0, 0.0, 0.0), gp_Dir(0.0, 0.0, 1.0)), 5.0);
    int aNb = 0;
    for (int i = 0; i < 3; i++)
    {
      for (int j = 0; j < 3; j++)
      {
        const double aU = i * 0.7;
        const double aV = 0.3 + j * 0.35;
        aBuilder.Add(new GeomPlate_PointConstraint(aU, aV, aSphere, 1, 1e-4, 1e-2, 1e-1));
        aNb++;
      }
    }
    aBuilder.Perform(Message_ProgressRange());
    report("  point-only plate, order 1 off a sphere", aBuilder);
    reportDiscardedPointDeviations(aBuilder, aNb);
  }

  printf("\n=== D. control: a curve constraint takes the VerifSurface() branch ===\n");
  {
    GeomPlate_BuildPlateSurface aBuilder(3, 10, 5, 1e-5, 1e-1);
    occ::handle<Geom_Circle>    aCirc =
      new Geom_Circle(gp_Ax2(gp_Pnt(5.0, 5.0, 0.0), gp_Dir(0.0, 0.0, 1.0)), 6.0);
    occ::handle<GeomAdaptor_Curve> aAdaptor = new GeomAdaptor_Curve(aCirc);
    aBuilder.Add(new GeomPlate_CurveConstraint(aAdaptor, 0, 10, 1e-4));
    aBuilder.Perform(Message_ProgressRange());
    report("  curve-only plate", aBuilder);
  }
  {
    GeomPlate_BuildPlateSurface aBuilder(3, 10, 5, 1e-5, 1e-1);
    occ::handle<Geom_Circle>    aCirc =
      new Geom_Circle(gp_Ax2(gp_Pnt(5.0, 5.0, 0.0), gp_Dir(0.0, 0.0, 1.0)), 6.0);
    occ::handle<GeomAdaptor_Curve> aAdaptor = new GeomAdaptor_Curve(aCirc);
    aBuilder.Add(new GeomPlate_CurveConstraint(aAdaptor, 0, 10, 1e-4));
    addPoints(aBuilder, aPts);
    aBuilder.Perform(Message_ProgressRange());
    report("  curve + points plate", aBuilder);
  }

  return 0;
}
