// OCCTSwift #597: GeomFill_Sweep.cxx:325 overwrites the measured approximation error
// with the requested tolerance instead of reading what GeomConvert_ApproxSurface actually
// achieved.
//
// This harness answers the three questions the issue raises before the "obvious fix"
// (`SError = ConvertApprox.MaxError();`) can be trusted:
//
//   1. Does the stock kernel really report a hardcoded 1e-4 regardless of the true fit?
//   2. Does `GeomConvert_ApproxSurface::MaxError()` measure the same quantity, against the
//      same reference, that `mySurface` is being converted FROM -- or does it measure
//      fidelity to some other, wrong object the way GeomPlate_MakeApprox::ApproxError() did
//      in #571 (measuring against an intermediate GeomPlate_Surface, not the caller's own
//      input points)?
//   3. Does that MaxError() actually MOVE now that patch 0019 (#522) repaired the AdvApp2Var
//      workspace-slot bug that used to make interior truncation error structurally zero?
//
// Method: build the pipe shell twice, once with ForceApproxC1 off (which never reaches the
// C1-forcing block at all, so its ErrorOnSurface() is Approx.MaxErrorOnSurf() -- the exact
// surface GeomConvert_ApproxSurface is handed as its "Surf" argument once ForceApproxC1 is
// on) and once with it on. Then reconstruct the SAME GeomConvert_ApproxSurface call the
// kernel makes internally, from OUTSIDE the kernel, using the unforced result as input and
// the literal parameters read from GeomFill_Sweep.cxx:290-297 (theTol=1e-4, C1/C1, degU=degV=14,
// nmax=16, prec=1). Its MaxError() is what SError would report after the fix, and its
// Surface() should match the real forced-build output bit for bit -- proving the external
// reconstruction is not a divergent simulation but the exact call the kernel makes.
// Finally, sample both surfaces on a grid and report two independent geometric deviations:
// paramDev (same normalised parameter on both surfaces -- what an approximator's own error
// model is about) and projDev (nearest point on the fit to each sampled source point --
// independent of parameterisation, so it measures only the shape). This is the "second
// construction" measure-dont-assume.md asks for before trusting MaxError()'s own report.
//
// Getting here is the hard part this file exists to save the next person from redoing:
// GeomFill_Sweep's myForceApproxC1 branch only fires when the SWEPT surface itself fails
// IsCNv(1) (not C1 across the spine parameter). BRepFill_Sweep splits its sweep at every
// spine VERTEX, so a polyline or multi-edge spine never reaches it -- the discontinuity has
// to sit INSIDE one edge. The fixture that does this (borrowed from #572, and pinned by
// Tests/OCCTModelingTests/Issue572SweepApproxTests.swift) is a single-edge spine built as one
// degree-2 B-spline curve with an interior knot of multiplicity 2 -- a C0 corner in the
// middle of what BRepFill_Sweep treats as a single, unsplit edge.
//
// Compile (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/597-geomfill-sweep-error-overwrite/occt_597_sweep_error.mm -o /tmp/occt_597
//   /tmp/occt_597
//
// For the override-link validation (does the REAL kernel, patched, report what this predicts?)
// see the README in this directory.

#include <cstdio>
#include <cmath>

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepFill_PipeShell.hxx>
#include <BRep_Tool.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Circle.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <NCollection_Array1.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Pnt.hxx>

// ---------------------------------------------------------------------------
// Fixture: Issue572SweepApproxTests.cornerSpine() -- a single-edge spine with a C0
// corner in the middle (degree 2, interior knot of multiplicity 2), plus a unit circle
// profile. This is the only OCCTSwift-reachable input that fires GeomFill_Sweep's
// myForceApproxC1 branch (measured in #572's probe-census.txt).
// ---------------------------------------------------------------------------

static TopoDS_Wire cornerSpine()
{
  NCollection_Array1<gp_Pnt> poles(1, 5);
  poles(1) = gp_Pnt(0, 0, 0);
  poles(2) = gp_Pnt(0, 0, 4);
  poles(3) = gp_Pnt(0, 0, 8);
  poles(4) = gp_Pnt(4, 0, 11);
  poles(5) = gp_Pnt(9, 0, 13);
  NCollection_Array1<double> knots(1, 3);
  knots(1) = 0.0;
  knots(2) = 0.5;
  knots(3) = 1.0;
  NCollection_Array1<int> mults(1, 3);
  mults(1) = 3;
  mults(2) = 2;
  mults(3) = 3;
  BRepBuilderAPI_MakeEdge me(new Geom_BSplineCurve(poles, knots, mults, 2));
  BRepBuilderAPI_MakeWire mw(me.Edge());
  return mw.Wire();
}

static TopoDS_Wire circleWire(const gp_Ax2& ax, double r)
{
  BRepBuilderAPI_MakeEdge me(new Geom_Circle(gp_Circ(ax, r)));
  BRepBuilderAPI_MakeWire mw(me.Edge());
  return mw.Wire();
}

// The surface carried by the first B-spline face of a shape -- what the bridge's
// OCCTPipeShellShape hands back and what a caller actually receives.
static Handle(Geom_Surface) firstBSplineFaceSurface(const TopoDS_Shape& sh)
{
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(sh, TopAbs_FACE, faces);
  for (int i = 1; i <= faces.Extent(); ++i)
  {
    TopLoc_Location      loc;
    Handle(Geom_Surface) s = BRep_Tool::Surface(TopoDS::Face(faces(i)), loc);
    if (!Handle(Geom_BSplineSurface)::DownCast(s).IsNull())
      return s;
  }
  return Handle(Geom_Surface)();
}

// Build the pipe shell exactly as the bridge does (OCCTPipeShellCreate / SetFrenet /
// SetForceApproxC1 / Add / SetIsBuildHistory(false) / Build), matching
// Sources/OCCTBridge/src/OCCTBridge_Modeling.mm and Issue572SweepApproxTests.build(...).
static bool buildPipeShell(bool forceApproxC1,
                           TopoDS_Shape& outShape,
                           double&       outErrorOnSurface)
{
  BRepFill_PipeShell ps(cornerSpine());
  ps.Set(Standard_True); // Frenet trihedron, matching PipeShellBuilder.setFrenet(true)
  ps.SetForceApproxC1(forceApproxC1 ? Standard_True : Standard_False);
  ps.Add(circleWire(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1.0));
  ps.SetIsBuildHistory(Standard_False);
  if (!ps.Build())
    return false;
  outShape          = ps.Shape();
  outErrorOnSurface = ps.ErrorOnSurface();
  return true;
}

// Two deviation measures between `truth` and `candidate`, both parametrised the same way
// GeomConvert_ApproxSurface keeps the source's own parameter range:
//   paramDev: same normalised (u, v) on both surfaces -- what the approximator's internal
//             error model actually compares against.
//   projDev:  nearest point on `candidate` to each sampled `truth` point -- independent of
//             parameterisation, so it measures the shape and nothing else.
struct Deviation
{
  double paramDev = 0.0;
  double projDev  = 0.0;
};

static Deviation measureDeviation(const Handle(Geom_Surface)& truth,
                                  const Handle(Geom_Surface)& candidate,
                                  int                          samples = 40)
{
  Deviation result;
  if (truth.IsNull() || candidate.IsNull())
    return result;
  double tu0, tu1, tv0, tv1, cu0, cu1, cv0, cv1;
  truth->Bounds(tu0, tu1, tv0, tv1);
  candidate->Bounds(cu0, cu1, cv0, cv1);
  for (int i = 0; i <= samples; ++i)
  {
    for (int j = 0; j <= samples; ++j)
    {
      const double a = double(i) / samples, b = double(j) / samples;
      gp_Pnt       p = truth->Value(tu0 + (tu1 - tu0) * a, tv0 + (tv1 - tv0) * b);
      gp_Pnt       q = candidate->Value(cu0 + (cu1 - cu0) * a, cv0 + (cv1 - cv0) * b);
      result.paramDev = std::max(result.paramDev, p.Distance(q));

      GeomAPI_ProjectPointOnSurf proj(p, candidate, cu0, cu1, cv0, cv1);
      if (proj.IsDone() && proj.NbPoints() > 0)
        result.projDev = std::max(result.projDev, proj.LowerDistance());
    }
  }
  return result;
}

static void describeSurface(const char* label, const Handle(Geom_Surface)& s)
{
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(s);
  if (bs.IsNull())
  {
    printf("%-28s not a BSpline surface\n", label);
    return;
  }
  printf("%-28s deg=%dx%d poles=%dx%d knots=%dx%d\n",
         label,
         bs->UDegree(),
         bs->VDegree(),
         bs->NbUPoles(),
         bs->NbVPoles(),
         bs->NbUKnots(),
         bs->NbVKnots());
}

int main()
{
  printf("### #597: GeomFill_Sweep.cxx:325 SError = theTol; vs the achieved error\n\n");

  // Stage 1: unforced. Never reaches the C1-forcing block, so ErrorOnSurface() here is
  // Approx.MaxErrorOnSurf() (line 286), untouched by #597. Its resulting surface is
  // EXACTLY what mySurface holds at the moment the forced build's ConvertApprox
  // constructor runs (GeomFill_Sweep.cxx:296-297).
  TopoDS_Shape unforcedShape;
  double       unforcedReportedError = 0.0;
  if (!buildPipeShell(false, unforcedShape, unforcedReportedError))
  {
    printf("FAILED to build the unforced pipe shell\n");
    return 1;
  }
  Handle(Geom_Surface) unforcedSurface = firstBSplineFaceSurface(unforcedShape);
  if (unforcedSurface.IsNull())
  {
    printf("FAILED to find a BSpline face on the unforced shape\n");
    return 1;
  }
  describeSurface("unforced surface", unforcedSurface);
  printf("%-28s %.6g  (Approx.MaxErrorOnSurf(), stage 1 -- unaffected by #597)\n\n",
         "unforced ErrorOnSurface()",
         unforcedReportedError);

  // Stage 2: forced. This is the path GeomFill_Sweep.cxx:288-327 takes.
  TopoDS_Shape forcedShape;
  double       forcedReportedErrorStock = 0.0;
  if (!buildPipeShell(true, forcedShape, forcedReportedErrorStock))
  {
    printf("FAILED to build the forced pipe shell\n");
    return 1;
  }
  Handle(Geom_Surface) forcedSurface = firstBSplineFaceSurface(forcedShape);
  if (forcedSurface.IsNull())
  {
    printf("FAILED to find a BSpline face on the forced shape\n");
    return 1;
  }
  describeSurface("forced surface (real)", forcedSurface);
  printf("%-28s %.6g  (stock kernel's SError -- should read exactly theTol=1e-4)\n\n",
         "forced ErrorOnSurface()",
         forcedReportedErrorStock);

  // Reconstruct the SAME GeomConvert_ApproxSurface call GeomFill_Sweep.cxx:296-297 makes,
  // from outside the kernel, with the unforced surface as its input -- exactly what
  // mySurface holds at that point in the real function.
  const double        theTol   = 1.e-4;
  const GeomAbs_Shape theUCont = GeomAbs_C1, theVCont = GeomAbs_C1;
  const int           degU = 14, degV = 14;
  const int           nmax    = 16;
  const int           thePrec = 1;
  GeomConvert_ApproxSurface
    convertApprox(unforcedSurface, theTol, theUCont, theVCont, degU, degV, nmax, thePrec);

  printf("### the reconstructed GeomConvert_ApproxSurface call (mirrors lines 296-297)\n");
  printf("%-28s %d\n", "HasResult()", (int)convertApprox.HasResult());
  printf("%-28s %d\n", "IsDone()", (int)convertApprox.IsDone());
  printf("%-28s %.6g  <-- what SError would report after the fix\n",
         "MaxError()",
         convertApprox.MaxError());
  if (convertApprox.HasResult())
    describeSurface("reconstructed surface", convertApprox.Surface());
  printf("\n");

  // Equivalence check: does the reconstructed call actually build the same surface the
  // real, in-kernel forced build produced? If not, this harness is measuring something
  // other than what GeomFill_Sweep.cxx really does, and nothing below is trustworthy.
  if (convertApprox.HasResult())
  {
    Handle(Geom_BSplineSurface) realBS  = Handle(Geom_BSplineSurface)::DownCast(forcedSurface);
    Handle(Geom_BSplineSurface) reconBS = convertApprox.Surface();
    const bool sameShape = !realBS.IsNull() && !reconBS.IsNull()
                          && realBS->UDegree() == reconBS->UDegree()
                          && realBS->VDegree() == reconBS->VDegree()
                          && realBS->NbUPoles() == reconBS->NbUPoles()
                          && realBS->NbVPoles() == reconBS->NbVPoles();
    printf("### equivalence check: reconstructed call vs the real forced build\n");
    printf("%-28s %s\n\n",
           "same deg/pole counts",
           sameShape ? "YES -- this harness reconstructs the real call" : "NO -- MISMATCH, see below");
    if (!sameShape)
    {
      describeSurface("  real forced surface", forcedSurface);
      describeSurface("  reconstructed surface", convertApprox.Surface());
    }
  }

  // Second construction: measure the real geometric deviation between the surface being
  // converted (unforced) and the C1-forced result, independent of what OCCT itself reports.
  Deviation devReal  = measureDeviation(unforcedSurface, forcedSurface);
  Deviation devRecon = convertApprox.HasResult()
                       ? measureDeviation(unforcedSurface, convertApprox.Surface())
                       : Deviation{};

  printf("### independent geometric deviation (unforced surface -> forced surface)\n");
  printf("%-28s paramDev=%.6g projDev=%.6g  (real, in-kernel forced build)\n",
         "measured (real build)",
         devReal.paramDev,
         devReal.projDev);
  printf("%-28s paramDev=%.6g projDev=%.6g  (reconstructed ConvertApprox.Surface())\n\n",
         "measured (reconstructed)",
         devRecon.paramDev,
         devRecon.projDev);

  printf("### summary\n");
  printf("%-28s %.6g\n", "stock SError (reported)", forcedReportedErrorStock);
  printf("%-28s %.6g\n", "fixed SError (= MaxError())", convertApprox.MaxError());
  printf("%-28s %.6g\n", "real deviation (projDev)", devReal.projDev);
  printf("%-28s %.6g\n", "real deviation (paramDev)", devReal.paramDev);
  if (devReal.projDev > 0)
    printf("%-28s %.4g\n", "MaxError() / projDev", convertApprox.MaxError() / devReal.projDev);
  if (devReal.paramDev > 0)
    printf("%-28s %.4g\n", "MaxError() / paramDev", convertApprox.MaxError() / devReal.paramDev);

  return 0;
}
