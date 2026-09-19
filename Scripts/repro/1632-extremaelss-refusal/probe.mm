// Probe for #1632: which Extrema_ExtElSS pairs the pinned 8.0.1 kernel actually implements.
//
// SAFETY: this probe never calls Extrema_ExtElSS::Points() on a parallel plane/plane result.
// Perform(gp_Pln, gp_Pln) sets myNbExt = 1 in its parallel branch but fills only mySqDist,
// leaving myPOnS1/myPOnS2 as null NCollection_HArray1 handles, so Points() dereferences null.
// That is an OS fault, not a catchable exception, and OCC_CATCH_SIGNALS is inert in this build
// (okf/references/known-occt-bugs.md, #345), so it would take the whole process down. The fault
// itself was established once, in the probe #1632 was filed from; there is no reason to repeat it.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1632-extremaelss-refusal/probe.mm -o /tmp/occt_probe_1632
//   /tmp/occt_probe_1632

#include <Extrema_ExtElSS.hxx>
#include <Standard_Failure.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Pln.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>

#include <cmath>
#include <cstdio>
#include <typeinfo>

template <class F>
static void tryPair(const char* label, F make)
{
  printf("  %-24s ", label);
  try
  {
    make();
  }
  catch (const Standard_Failure& e)
  {
    printf("ctor THREW %s (%s)\n", typeid(e).name(), e.GetMessageString() ? e.GetMessageString() : "");
    return;
  }
  catch (...)
  {
    printf("ctor THREW an unknown exception\n");
    return;
  }
}

int main()
{
  const gp_Pln    plZ0(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  const gp_Pln    plZ5(gp_Pnt(0, 0, 5), gp_Dir(0, 0, 1));
  const gp_Pln    plX0(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  const gp_Sphere sp1(gp_Ax3(gp_Pnt(0, 0, 20), gp_Dir(0, 0, 1)), 5.0);
  const gp_Sphere sp2(gp_Ax3(gp_Pnt(20, 0, 0), gp_Dir(0, 0, 1)), 5.0);
  const gp_Cylinder cyl(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3.0);
  const gp_Cone     cone(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0.5, 2.0);
  const gp_Torus    tor(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10.0, 2.0);

  printf("=== Extrema_ExtElSS on the pinned 8.0.1 kernel\n");

  // plane/plane, parallel. z=0 and z=5, so the distance is 5 and the square distance 25.
  {
    printf("  %-24s ", "plane/plane parallel");
    Extrema_ExtElSS ext(plZ0, plZ5);
    printf("IsDone=%d IsParallel=%d NbExt=%d SquareDistance(1)=%g\n",
           (int)ext.IsDone(), (int)ext.IsParallel(), ext.NbExt(),
           ext.NbExt() > 0 ? ext.SquareDistance(1) : NAN);
    printf("  %-24s (Points() NOT called: myPOnS1/myPOnS2 are null handles here, see header)\n", "");
  }

  // plane/plane, crossing. Distance is zero along the intersection line, and the class records
  // no extremum for that: NbExt() == 0 with IsDone() true.
  {
    printf("  %-24s ", "plane/plane crossing");
    Extrema_ExtElSS ext(plZ0, plX0);
    printf("IsDone=%d IsParallel=%d NbExt=%d\n",
           (int)ext.IsDone(), (int)ext.IsParallel(), ext.NbExt());
  }

  // The five pairs the bridge and the docs claim, or could claim, an answer for.
  tryPair("plane/sphere", [&] {
    Extrema_ExtElSS ext(plZ0, sp1);
    printf("IsDone=%d NbExt=%d\n", (int)ext.IsDone(), ext.NbExt());
  });
  tryPair("sphere/sphere", [&] {
    Extrema_ExtElSS ext(sp1, sp2);
    printf("IsDone=%d NbExt=%d\n", (int)ext.IsDone(), ext.NbExt());
  });
  tryPair("sphere/cylinder", [&] {
    Extrema_ExtElSS ext(sp1, cyl);
    printf("IsDone=%d NbExt=%d\n", (int)ext.IsDone(), ext.NbExt());
  });
  tryPair("sphere/cone", [&] {
    Extrema_ExtElSS ext(sp1, cone);
    printf("IsDone=%d NbExt=%d\n", (int)ext.IsDone(), ext.NbExt());
  });
  tryPair("sphere/torus", [&] {
    Extrema_ExtElSS ext(sp1, tor);
    printf("IsDone=%d NbExt=%d\n", (int)ext.IsDone(), ext.NbExt());
  });

  return 0;
}
