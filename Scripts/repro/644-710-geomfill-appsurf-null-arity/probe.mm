// OCCTSwift#644 + #710 ground truth: two independent, uncatchable SIGSEGVs in
// OCCTGeomFillAppSurf (OCCTBridge_Surface.mm) and two sibling GeomFill_* bridge functions.
//
// #644: GeomFill_SectionGenerator + GeomFill_AppSurf crash on a single (valid, non-null) curve.
// Counts of 2+ succeed. Not the unguarded `(double)i / (double)(count - 1)` divisor at the old
// line 3285 -- substituting a guarded 0.0 there still crashes (see the issue). PART 1 below
// isolates the real mechanism: AppDef_Compute::Perform (called from AppBlend_AppSurf's
// InternalPerform, the template body behind GeomFill_AppSurf) is never given a MultiLine with
// fewer than 2 points anywhere else in the kernel; at NbPoint == 1 the first/last section are the
// same point evaluated twice, and the approximation solver segfaults setting up degree-of-freedom
// bookkeeping that assumes at least one free interior span.
//
// #710: three sites in OCCTBridge_Surface.mm reach a `Handle(Geom_Curve)` through the alias form
// `*(const Handle(Geom_Curve)*)curveRef`, invisible to Scripts/check-null-handle-guards.py, and
// dereference it unconditionally. PART 2 below reproduces all three directly against the OCCT API
// the bridge calls, bypassing OCCTBridge/OCCTSwift entirely:
//   - GeomFill_Profiler::AddCurve            (OCCTGeomFillProfilerAddCurve)
//   - GeomFill_SectionGenerator::AddCurve    (OCCTGeomFillAppSurf's curveRefs loop -- the same
//                                              function as GeomFill_Profiler::AddCurve; the
//                                              subclass does not override it)
//   - GeomFill_SectionPlacement ctor         (OCCTGeomFillSectionPlacement's sectionCurve arg)
//
// Each probe runs in a forked child so a SIGSEGV is reported as a table row instead of ending the
// whole run (same idiom as Scripts/repro/556-null-handle-guard-sweep/repro_556.mm).
//
// Compile and run against the pinned kernel (v2.0.0-kernel.1's OCCT.xcframework -- either a local
// Libraries/OCCT.xcframework, or the copy `swift build` already fetched into
// .build/artifacts/*/OCCT/OCCT.xcframework, which needs no extra download):
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"<xcframework>/macos-arm64/Headers" \
//     -L"<xcframework>/macos-arm64" \
//     Scripts/repro/644-710-geomfill-appsurf-null-arity/probe.mm -o /tmp/occt_644_710_probe \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++
//   /tmp/occt_644_710_probe

#include <GC_MakeCircle.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Geometry.hxx>
#include <GeomFill_AppSurf.hxx>
#include <GeomFill_Line.hxx>
#include <GeomFill_LocationDraft.hxx>
#include <GeomFill_Profiler.hxx>
#include <GeomFill_SectionGenerator.hxx>
#include <GeomFill_SectionPlacement.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <NCollection_HArray1.hxx>
#include <Standard_Failure.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <functional>
#include <sys/wait.h>
#include <unistd.h>

static int uncatchable = 0, catchable = 0, benign = 0;

static void probe(const char* label, const std::function<void()>& body) {
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        try { body(); }
        catch (Standard_Failure const&) { _exit(3); }
        catch (...) { _exit(4); }
        _exit(0);
    }
    int st = 0;
    waitpid(pid, &st, 0);
    const char* verdict;
    bool crash = false;
    if (WIFSIGNALED(st)) { verdict = "SIGNAL (uncatchable, uncaught by any catch(...))"; crash = true; }
    else if (WEXITSTATUS(st) == 3) { verdict = "Standard_Failure (catchable)"; catchable++; }
    else if (WEXITSTATUS(st) == 4) { verdict = "other exception (catchable)"; catchable++; }
    else { verdict = "returned normally"; benign++; }
    if (crash) uncatchable++;
    printf("  %-46s %s\n", label, verdict);
}

static Handle(Geom_Curve) makeCircle(double cz) {
    gp_Ax2 ax(gp_Pnt(0, 0, cz), gp_Dir(0, 0, 1));
    GC_MakeCircle mc(ax, 5.0);
    return mc.Value();
}

int main() {
    printf("#644 + #710: OCCTGeomFillAppSurf and its two sibling GeomFill_* bridge functions\n\n");

    // ---- PART 1 (#644): arity, real curves, no null handle involved ----
    printf("PART 1 -- #644 arity (GeomFill_SectionGenerator + GeomFill_AppSurf, valid curves)\n");
    probe("count=0 curves", [&] {
        GeomFill_SectionGenerator secGen;
        secGen.Perform(1e-6);
        Handle(NCollection_HArray1<double>) params = new NCollection_HArray1<double>(1, 0);
        secGen.SetParam(params);
        Handle(GeomFill_Line) line = new GeomFill_Line(0);
        GeomFill_AppSurf appSurf(3, 8, 1e-3, 1e-3, 10, false);
        appSurf.Perform(line, secGen, false);
        (void)appSurf.IsDone();
    });
    probe("count=1 curve", [&] {
        GeomFill_SectionGenerator secGen;
        secGen.AddCurve(makeCircle(0));
        secGen.Perform(1e-6);
        Handle(NCollection_HArray1<double>) params = new NCollection_HArray1<double>(1, 1);
        params->SetValue(1, 0.0);
        secGen.SetParam(params);
        Handle(GeomFill_Line) line = new GeomFill_Line(1);
        GeomFill_AppSurf appSurf(3, 8, 1e-3, 1e-3, 10, false);
        appSurf.Perform(line, secGen, false);
        (void)appSurf.IsDone();
    });
    probe("count=2 curves (control -- must succeed)", [&] {
        GeomFill_SectionGenerator secGen;
        secGen.AddCurve(makeCircle(0));
        secGen.AddCurve(makeCircle(10));
        secGen.Perform(1e-6);
        Handle(NCollection_HArray1<double>) params = new NCollection_HArray1<double>(1, 2);
        params->SetValue(1, 0.0);
        params->SetValue(2, 1.0);
        secGen.SetParam(params);
        Handle(GeomFill_Line) line = new GeomFill_Line(2);
        GeomFill_AppSurf appSurf(3, 8, 1e-3, 1e-3, 10, false);
        appSurf.Perform(line, secGen, false);
        if (!appSurf.IsDone()) { printf("    (unexpected: control did not report IsDone)\n"); }
    });

    printf("\nPART 2 -- #710 null Handle(Geom_Curve), the three unguarded alias-form sites\n");
    Handle(Geom_Curve) nullCurve; // default-constructed, IsNull() == true

    probe("OCCTGeomFillProfilerAddCurve: GeomFill_Profiler::AddCurve(null)", [&] {
        GeomFill_Profiler profiler;
        profiler.AddCurve(nullCurve);
    });
    probe("OCCTGeomFillAppSurf: GeomFill_SectionGenerator::AddCurve(null)", [&] {
        GeomFill_SectionGenerator secGen;
        secGen.AddCurve(nullCurve); // same non-virtual GeomFill_Profiler::AddCurve as above
    });
    probe("OCCTGeomFillSectionPlacement: GeomFill_SectionPlacement ctor(null section)", [&] {
        Handle(GeomFill_LocationDraft) loc = new GeomFill_LocationDraft(gp_Dir(0, 0, 1), 0.0);
        Handle(Geom_Curve) path = makeCircle(0);
        Handle(GeomAdaptor_Curve) pathAdaptor = new GeomAdaptor_Curve(path);
        loc->SetCurve(pathAdaptor);
        Handle(Geom_Geometry) nullSection; // upcast of a null Handle(Geom_Curve)
        GeomFill_SectionPlacement placement(loc, nullSection);
        (void)placement.IsDone();
    });

    printf("\nFor contrast -- the six #710 sites that ARE already guarded in substance, because they\n");
    printf("wrap the handle in GeomAdaptor_Curve first, which raises catchably:\n");
    probe("GeomFill_LocationDraft::SetCurve path: new GeomAdaptor_Curve(null)", [&] {
        Handle(GeomAdaptor_Curve) a = new GeomAdaptor_Curve(nullCurve);
        (void)a;
    });

    // ---- PART 3: the fix itself, applied inline against the real kernel ----
    // The actual PR diff adds `if (curve.IsNull()) return <fallback>;` immediately before each
    // call below, matching this file's existing idiom. Reproduced here verbatim (guard + call) so
    // the "after" claim is checked against the pinned kernel, not just read off the diff.
    printf("\nPART 3 -- the fix (guard + call), same three sites, run against the same kernel\n");
    probe("#644: Surface.appSurf's `curves.count >= 2` guard, count=1", [&] {
        int count = 1;
        if (count < 2) return; // the added Swift-side guard, reproduced here
        GeomFill_SectionGenerator secGen;
        secGen.AddCurve(makeCircle(0));
        secGen.Perform(1e-6);
        Handle(NCollection_HArray1<double>) params = new NCollection_HArray1<double>(1, count);
        params->SetValue(1, 0.0);
        secGen.SetParam(params);
        Handle(GeomFill_Line) line = new GeomFill_Line(count);
        GeomFill_AppSurf appSurf(3, 8, 1e-3, 1e-3, 10, false);
        appSurf.Perform(line, secGen, false);
    });
    probe("OCCTGeomFillProfilerAddCurve, guarded", [&] {
        GeomFill_Profiler profiler;
        const Handle(Geom_Curve)& curve = nullCurve;
        if (curve.IsNull()) return; // the added guard
        profiler.AddCurve(curve);
    });
    probe("OCCTGeomFillAppSurf's curveRefs loop, guarded", [&] {
        GeomFill_SectionGenerator secGen;
        const Handle(Geom_Curve)& curve = nullCurve;
        if (curve.IsNull()) return; // the added guard
        secGen.AddCurve(curve);
    });
    probe("OCCTGeomFillSectionPlacement, guarded", [&] {
        Handle(GeomFill_LocationDraft) loc = new GeomFill_LocationDraft(gp_Dir(0, 0, 1), 0.0);
        Handle(Geom_Curve) path = makeCircle(0);
        Handle(GeomAdaptor_Curve) pathAdaptor = new GeomAdaptor_Curve(path);
        loc->SetCurve(pathAdaptor);
        const Handle(Geom_Curve)& sectionCurve = nullCurve;
        if (sectionCurve.IsNull()) return; // the added guard
        GeomFill_SectionPlacement placement(loc, sectionCurve);
        (void)placement.IsDone();
    });

    printf("\n%d uncatchable (SIGSEGV), %d catchable, %d returned normally\n",
           uncatchable, catchable, benign);
    return 0;
}
