// #666 (Cluster C) ground truth. Two independent measurements this census's triage depends on.
// Each probe runs in a forked child, so a SIGSEGV is reported rather than ending the run - same
// harness shape as Scripts/repro/556-null-handle-guard-sweep/repro_556.mm.
//
// Compile and run from the repo root, per CLAUDE.md's ground-truth recipe:
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/cluster-c-null-handle-shapes/probe_cluster_c.mm -o /tmp/probe_cluster_c
//   /tmp/probe_cluster_c
//
// PART 1 answers whether OCCTBridge_Surface.mm's OCCTGeomFillCoonsAlgPatchEval - the checker's
// one new #666 finding, a local Handle(Geom_Curve) obtained from BRep_Tool::Curve rather than a
// wrapper argument - is safe to leave in ALLOWED: does GeomAdaptor_Curve raise a catchable
// Standard_Failure on a null Handle(Geom_Curve), on both the 1-arg and 3-arg (trimmed) forms?
//
// PART 2 answers a question this census's own investigation of #644 raised but does not fix:
// OCCTBridge_Surface.mm has NINE sites using a fifth alias form the checker (even after #666)
// still cannot see - `const Handle(Geom_Curve)& x = *(const Handle(Geom_Curve)*)wrapperParam;` -
// and three of those nine are genuinely unguarded, reaching GeomFill_Profiler::AddCurve,
// GeomFill_SectionGenerator::AddCurve (OCCTGeomFillAppSurf's own curve array - #644's own
// function) and the GeomFill_SectionPlacement constructor with no IsNull() check at all. Measured
// here, not fixed: see the census README's "Found, deliberately not taught: a fifth alias form,
// with three real, live SIGSEGVs" section for why.
#include <GeomAdaptor_Curve.hxx>
#include <GeomFill_Profiler.hxx>
#include <GeomFill_SectionGenerator.hxx>
#include <GeomFill_SectionPlacement.hxx>
#include <GeomFill_LocationDraft.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Circle.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <Standard_Failure.hxx>
#include <Standard_Handle.hxx>

#include <cstdio>
#include <functional>
#include <sys/wait.h>
#include <unistd.h>

static void probe(const char* what, const std::function<void()>& body) {
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        try { body(); }
        catch (Standard_Failure const& e) { printf("      caught: %s\n", e.GetMessageString()); fflush(stdout); _exit(3); }
        catch (...) { fflush(stdout); _exit(4); }
        fflush(stdout);
        _exit(0);
    }
    int st = 0;
    waitpid(pid, &st, 0);
    const char* verdict;
    if (WIFSIGNALED(st)) {
        verdict = (WTERMSIG(st) == SIGSEGV) ? "SIGSEGV (uncatchable)" : "SIGNAL (uncatchable)";
    } else if (WEXITSTATUS(st) == 3) {
        verdict = "Standard_Failure (catchable)";
    } else if (WEXITSTATUS(st) == 4) {
        verdict = "other exception (catchable)";
    } else {
        verdict = "returned normally";
    }
    printf("  %-68s %s\n", what, verdict);
}

int main() {
    occ::handle<Geom_Curve> nullCurve;

    printf("PART 1: GeomAdaptor_Curve on a null Handle(Geom_Curve) "
           "(ALLOWED entry for OCCTGeomFillCoonsAlgPatchEval)\n\n");

    probe("GeomAdaptor_Curve(nullCurve) [1-arg, whole curve]", [&] {
        GeomAdaptor_Curve a(nullCurve);
    });
    probe("new GeomAdaptor_Curve(nullCurve, 0.0, 1.0) [3-arg, trimmed]", [&] {
        occ::handle<GeomAdaptor_Curve> a = new GeomAdaptor_Curve(nullCurve, 0.0, 1.0);
    });
    probe("new GeomAdaptor_Curve(nullCurve, 0.0, 1.0) then ->Value(0.5)", [&] {
        occ::handle<GeomAdaptor_Curve> a = new GeomAdaptor_Curve(nullCurve, 0.0, 1.0);
        gp_Pnt p = a->Value(0.5);
        printf("      p = (%f, %f, %f)\n", p.X(), p.Y(), p.Z());
    });

    printf("\nPART 2: GeomFill_* family on a null Handle(Geom_Curve), the fifth alias form "
           "(*(const Type*)wrapperParam) the checker still cannot see\n\n");

    probe("GeomFill_Profiler().AddCurve(nullCurve)                  [OCCTGeomFillProfilerAddCurve]", [&] {
        GeomFill_Profiler profiler;
        profiler.AddCurve(nullCurve);
        printf("      added ok\n");
    });
    probe("GeomFill_SectionGenerator().AddCurve(nullCurve)          [OCCTGeomFillAppSurf, #644's own fn]", [&] {
        GeomFill_SectionGenerator secGen;
        secGen.AddCurve(nullCurve);
        printf("      added ok\n");
    });
    // Labelled ctor+Perform, not just ctor: the crash's exact origin within this body is not
    // isolated (the probe forks the whole lambda, so a SIGSEGV anywhere inside it reads the same
    // from outside). Matches OCCTGeomFillSectionPlacement's own call sequence (construct, then
    // Perform, then IsDone) rather than claiming a narrower verdict than what was actually run.
    probe("GeomFill_SectionPlacement(loc, nullCurve) ctor+Perform     [OCCTGeomFillSectionPlacement]", [&] {
        occ::handle<GeomFill_LocationDraft> loc = new GeomFill_LocationDraft(gp_Dir(0, 0, 1), 0.0);
        gp_Ax2 axes(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
        occ::handle<Geom_Curve> path = new Geom_Circle(axes, 5.0);
        occ::handle<GeomAdaptor_Curve> pathAdaptor = new GeomAdaptor_Curve(path);
        loc->SetCurve(pathAdaptor);
        GeomFill_SectionPlacement placement(loc, nullCurve);
        placement.Perform(1e-7);
        printf("      IsDone=%d\n", placement.IsDone());
    });

    return 0;
}
