// #811: does `nlPlateDeformed` preserve the input surface's parametrisation, and where does
// its result sit in space?
//
// BOTH ANSWERS CHANGED UNDER THIS PROBE. It was written to demonstrate two defects, #1046 and
// #1049, and #1069 fixed both on `main` while #811 was in review. Run against the current
// bridge it now records correct behaviour, which makes it a regression witness rather than a
// demonstration. `probe-transcript.txt` beside it is the current output, not the output that
// motivated the findings; the findings' own figures are in this directory's README, labelled
// as historical.
//
// `docs/reference/Surface-Advanced.md:110` claimed, before this PR, "Distinct from fitting a fresh
// surface to a point set, the existing parametrisation is preserved." This probe calls the real
// bridge entry point `OCCTSurfaceNLPlateG0` and measures both halves of that claim against the
// surface it hands back: the parameter bounds, and whether a (u, v) the input answers for is even
// inside the output's own domain.
//
// Two fixtures for the parametrisation question, per okf/policies/measure-dont-assume.md's
// second-construction rule. A cylinder, whose own u range is [0, 2pi] and periodic; and a plane,
// whose parametrisation a uniform point-grid fit is likeliest to reproduce by accident. The claim
// fails on both, so it is a property of the fitting step rather than of the cylinder.
//
// A THIRD SECTION, for a different defect. #1049 is that `OCCTSurfaceNLPlateG0` and `G1` add the
// input surface's own point to a value that already contains it: `NLPlate_NLPlate::Evaluate` seeds
// its return with `myInitialSurface->Value(u, v)` and then adds each plate, so it returns the
// deformed point, not an offset. The result is `2 * base + plate` at every sampled point.
//
// THAT DOUBLES SIZE, NOT ONLY POSITION, and an earlier version of this probe missed it by measuring
// one off-origin fixture and printing no corners for the origin ones. A plane through the origin is
// affected everywhere except at the single (u, v) whose base point IS the origin: its own domain
// comes back twice as wide. So "only a surface away from the origin is affected" was wrong, and
// `reportDoubleAdd` now measures both fixtures and both affected entry points.
//
// Build and run from the repo root, with `Libraries/OCCT.xcframework` present:
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -I"Sources/OCCTBridge/include" -I"Sources/OCCTBridge/src" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     Scripts/repro/811-refman-coverage-features/probe_nlplate_parametrisation.mm \
//     Sources/OCCTBridge/src/OCCTBridge_ProjLib_NLPlate.mm \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     -o /tmp/probe_811 && /tmp/probe_811

#import <Foundation/Foundation.h>

#include <Geom_BSplineSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_Surface.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pnt.hxx>

#include "OCCTBridge.h"
#include "OCCTBridge_Internal.h"

#include <cstdio>

static void report(const char* label, const Handle(Geom_Surface)& in, double uSample, double vSample)
{
  double iu1, iu2, iv1, iv2;
  in->Bounds(iu1, iu2, iv1, iv2);
  std::printf("\n=== %s ===\n", label);
  std::printf("input          : %s\n", in->DynamicType()->Name());
  std::printf("input bounds   : u [%g, %g]  v [%g, %g]\n", iu1, iu2, iv1, iv2);
  std::printf("input periodic : u %s, v %s\n",
              in->IsUPeriodic() ? "yes" : "no",
              in->IsVPeriodic() ? "yes" : "no");

  OCCTSurface* wrapper = new OCCTSurface(in);

  // One constraint. Stride is five doubles: u, v, targetX, targetY, targetZ.
  const double constraints[5] = {0.0, 0.0, 14.0, 0.0, 0.0};

  OCCTSurfaceRef out = OCCTSurfaceNLPlateG0(wrapper, constraints, 1, 4, 1e-3);
  if (!out)
  {
    std::printf("FAILED: OCCTSurfaceNLPlateG0 returned null\n");
    return;
  }

  Handle(Geom_Surface) res = out->surface;
  double               ou1, ou2, ov1, ov2;
  res->Bounds(ou1, ou2, ov1, ov2);
  std::printf("output         : %s\n", res->DynamicType()->Name());
  std::printf("output bounds  : u [%g, %g]  v [%g, %g]\n", ou1, ou2, ov1, ov2);

  const bool inRange = (uSample >= ou1 && uSample <= ou2 && vSample >= ov1 && vSample <= ov2);
  std::printf("sample (u=%g, v=%g) inside the output's own domain: %s\n",
              uSample,
              vSample,
              inRange ? "yes" : "NO");
  if (inRange)
  {
    gp_Pnt pIn  = in->Value(uSample, vSample);
    gp_Pnt pOut = res->Value(uSample, vSample);
    std::printf("input  at sample: (%.6f, %.6f, %.6f)\n", pIn.X(), pIn.Y(), pIn.Z());
    std::printf("output at sample: (%.6f, %.6f, %.6f)\n", pOut.X(), pOut.Y(), pOut.Z());
    std::printf("distance        : %.6f\n", pIn.Distance(pOut));
  }

  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(res);
  if (!bs.IsNull())
  {
    std::printf("output degrees : u %d, v %d\n", bs->UDegree(), bs->VDegree());
    std::printf("output poles   : u %d, v %d\n", bs->NbUPoles(), bs->NbVPoles());
    std::printf("output periodic: u %s, v %s\n",
                bs->IsUPeriodic() ? "yes" : "no",
                bs->IsVPeriodic() ? "yes" : "no");
  }
}

// #1049, measured on both affected entry points and on an origin-centred fixture as well as an
// off-origin one, because "only off-origin surfaces are affected" was the wrong conclusion the
// off-origin-only version supported.
static void reportOneDoubleAdd(const char* label, double px, bool useG1)
{
  Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(px, 0, 0), gp_Dir(0, 0, 1));
  OCCTSurface*       wrapper = new OCCTSurface(plane);

  // Stride 5 for G0, 11 for G1: u, v, target xyz, then the two tangents for G1.
  const double g0[5]  = {0.0, 0.0, px, 0.0, 5.0};
  const double g1[11] = {0.0, 0.0, px, 0.0, 5.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0};
  OCCTSurfaceRef out  = useG1 ? OCCTSurfaceNLPlateG1(wrapper, g1, 1, 4, 1e-3)
                              : OCCTSurfaceNLPlateG0(wrapper, g0, 1, 4, 1e-3);
  if (!out)
  {
    std::printf("  %-34s returned null\n", label);
    return;
  }

  Handle(Geom_Surface) res = out->surface;
  double               u1, u2, v1, v2;
  res->Bounds(u1, u2, v1, v2);
  gp_Pnt mid  = res->Value(0.5 * (u1 + u2), 0.5 * (v1 + v2));
  gp_Pnt lo   = res->Value(u1, v1);
  gp_Pnt hi   = res->Value(u2, v2);
  gp_Pnt at00 = plane->Value(g0[0], g0[1]);
  std::printf("  %-34s asked (%.1f, %.1f, %.1f) at uv (%g, %g), input there (%.1f, %.1f, %.1f)\n",
              label, g0[2], g0[3], g0[4], g0[0], g0[1], at00.X(), at00.Y(), at00.Z());
  std::printf("  %-34s centre (%.4f, %.4f, %.4f), corners (%.1f, %.1f) .. (%.1f, %.1f)\n",
              "", mid.X(), mid.Y(), mid.Z(), lo.X(), lo.Y(), hi.X(), hi.Y());
}

static void reportDoubleAdd()
{
  std::printf("\n=== the #1049 double-add, both affected entry points, on and off the origin ===\n");
  std::printf("  the working domain is the constraint point padded by 10 in each direction, so a\n"
              "  correct result would span 20 by 20 about that point.\n");
  reportOneDoubleAdd("G0, plane at x = 100", 100.0, false);
  reportOneDoubleAdd("G0, plane through the origin", 0.0, false);
  reportOneDoubleAdd("G1, plane at x = 100", 100.0, true);
  reportOneDoubleAdd("G1, plane through the origin", 0.0, true);
}

// The `[0, 1] x [0, 1]` output domain, asked of ALL FIVE entry points rather than inferred from
// G0. G2, G3 and Incremental take a different sampling path (a hardcoded [0, 1] grid in the input's
// own parameter space), so "the same output domain" is not something one measurement settles.
static void reportAllFiveDomains()
{
  std::printf("\n=== output domain of each of the five deformers, plane through the origin ===\n");
  Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

  static const double g0[5]  = {0.0, 0.0, 0.0, 0.0, 5.0};
  static const double g1[11] = {0.0, 0.0, 0.0, 0.0, 5.0, 1.0, 0.0, 0.5, 0.0, 1.0, 0.5};
  static const double g2[20] = {0.0, 0.0, 0.0, 0.0, 5.0, 1.0, 0.0, 0.5, 0.0, 1.0,
                                0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
  static const double g3[32] = {0.0, 0.0, 0.0, 0.0, 5.0, 1.0, 0.0, 0.5, 0.0, 1.0,
                                0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};

  OCCTSurface* w = new OCCTSurface(plane);

  struct Row
  {
    const char*    name;
    OCCTSurfaceRef out;
  };
  Row rows[5] = {
    {"nlPlateDeformed", OCCTSurfaceNLPlateG0(w, g0, 1, 4, 1e-3)},
    {"nlPlateDeformedG1", OCCTSurfaceNLPlateG1(w, g1, 1, 4, 1e-3)},
    {"nlPlateDeformedG2", OCCTSurfaceNLPlateG2(w, g2, 1, 1e-3)},
    {"nlPlateDeformedG3", OCCTSurfaceNLPlateG3(w, g3, 1, 1e-3)},
    {"nlPlateDeformedIncremental", OCCTSurfaceNLPlateIncrementalG0(w, g0, 1, 2, 1, 4)},
  };

  for (int i = 0; i < 5; i++)
  {
    if (!rows[i].out)
    {
      std::printf("  %-28s returned null\n", rows[i].name);
      continue;
    }
    double u1, u2, v1, v2;
    rows[i].out->surface->Bounds(u1, u2, v1, v2);
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(rows[i].out->surface);
    std::printf("  %-28s u [%g, %g]  v [%g, %g]   periodic u %s\n",
                rows[i].name,
                u1,
                u2,
                v1,
                v2,
                (!bs.IsNull() && bs->IsUPeriodic()) ? "yes" : "no");
  }
}

int main()
{
  gp_Ax3                          ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
  Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(ax, 10.0);
  report("cylinder, radius 10", cyl, 1.5707963267948966, 0.0);

  Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  report("plane through the origin", plane, 3.0, 4.0);

  reportDoubleAdd();
  reportAllFiveDomains();
  return 0;
}
