// #643 ground truth. Two things this issue's fix depends on, both measured directly rather than
// assumed from reading the source:
//
// PART 1 confirms the upstream asymmetry the issue reports still holds at the pinned kernel
// (v2.0.0-kernel.1, OCCT V8_0_1 + carried patches): GeomTools_CurveSet::Add drops a null handle
// (returns 0), while GeomTools_Curve2dSet::Add and GeomTools_SurfaceSet::Add accept it silently
// (return a valid index) and only crash later, inside Write(). A SIGSEGV is an OS signal, so the
// bridge's own `catch (...)` cannot absorb it - the guard has to sit before Add(), not around it.
// Also checks Index(), a second, less severe divergence found while auditing the first: it does
// not crash (FindIndex never dereferences), but Curve2dSet/SurfaceSet report a bogus non-zero
// index for a handle that was never really bound, where CurveSet correctly reports 0.
//
// PART 2 answers the actual question for OCCTSwift: is the crash reachable through the bridge?
// It override-links against the REAL Sources/OCCTBridge/src/OCCTBridge_IO.mm (not a
// reimplementation) and calls OCCTGeomToolsCurve2dSetWrite/OCCTGeomToolsSurfaceSetWrite directly
// with an array containing a genuinely null-handle-wrapping OCCTCurve2D/OCCTSurface - the exact
// struct shape a Curve2D/Surface array element becomes once unwrapped by the bridge. Confirms the
// existing per-element guard (`if (!c || c->curve.IsNull()) return nullptr;`, the #618 "array
// element through a cast" shape) refuses the null before GeomTools_*Set::Add is ever called.
//
// Compile and run from the repo root, per CLAUDE.md's ground-truth recipe, with OCCTBridge_IO.mm
// linked in directly (the "incremental kernel slice rebuild" override-link technique - one real
// bridge TU compiled straight into a throwaway probe, no xcframework/package rebuild involved):
//
//   clang++ -std=c++17 -ObjC++ -w -fobjc-arc \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -I"Sources/OCCTBridge/include" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Sources/OCCTBridge/src/OCCTBridge_IO.mm \
//     Scripts/repro/643-geomtools-null-write/probe_643.mm -o /tmp/probe_643
//   /tmp/probe_643
//
// occtEnsureSignals() (defined in OCCTBridge.mm, called by an unrelated function elsewhere in
// OCCTBridge_IO.mm) is stubbed below rather than pulling in the whole file: it only installs
// OCCT's own SIGSEGV/SIGBUS handlers, unrelated to what this probe measures, and CLAUDE.md's own
// note stands regardless - OCC_CATCH_SIGNALS is inert in this build, so a SIGSEGV here is still a
// real, uncatchable-in-process OS signal either way. Each probe forks, so a crash in the child is
// reported to the parent rather than ending the run.

#include <GeomTools_Curve2dSet.hxx>
#include <GeomTools_CurveSet.hxx>
#include <GeomTools_SurfaceSet.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Surface.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom2d_Line.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Dir2d.hxx>
#include <Standard_Failure.hxx>

#include "OCCTBridge.h"
#include "OCCTBridge_Internal.h"

#include <cstdio>
#include <functional>
#include <sstream>
#include <sys/wait.h>
#include <unistd.h>

void occtEnsureSignals() {}

// The *FreeArray helpers (unused by this probe) call these Release functions, defined in
// sibling .mm files this probe does not link. Stubbed so the linker resolves cleanly; never
// actually invoked, since this probe never calls a *SetRead/*FreeArray path.
void OCCTCurve2DRelease(OCCTCurve2DRef) {}
void OCCTCurve3DRelease(OCCTCurve3DRef) {}
void OCCTSurfaceRelease(OCCTSurfaceRef) {}

static void probe(const char* what, const std::function<void()>& body) {
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        try { body(); }
        catch (Standard_Failure const&) { _exit(3); }
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
    printf("  %-58s %s\n", what, verdict);
}

int main() {
    occ::handle<Geom_Curve>   nullCurve3d;
    occ::handle<Geom2d_Curve> nullCurve2d;
    occ::handle<Geom_Surface> nullSurface;

    printf("PART 1: GeomTools_*Set, one null handle, three writers (pinned v2.0.0-kernel.1)\n\n");

    printf("  -- Add() alone --\n");
    probe("GeomTools_CurveSet::Add(null)", [&] {
        GeomTools_CurveSet s; printf("      Add returned %d\n", s.Add(nullCurve3d));
    });
    probe("GeomTools_Curve2dSet::Add(null)", [&] {
        GeomTools_Curve2dSet s; printf("      Add returned %d\n", s.Add(nullCurve2d));
    });
    probe("GeomTools_SurfaceSet::Add(null)", [&] {
        GeomTools_SurfaceSet s; printf("      Add returned %d\n", s.Add(nullSurface));
    });

    printf("\n  -- Add() then Write(), which is what the bridge does --\n");
    probe("GeomTools_CurveSet::Add(null) + Write", [&] {
        GeomTools_CurveSet s; s.Add(nullCurve3d);
        std::ostringstream o; s.Write(o);
    });
    probe("GeomTools_Curve2dSet::Add(null) + Write", [&] {
        GeomTools_Curve2dSet s; s.Add(nullCurve2d);
        std::ostringstream o; s.Write(o);
    });
    probe("GeomTools_SurfaceSet::Add(null) + Write", [&] {
        GeomTools_SurfaceSet s; s.Add(nullSurface);
        std::ostringstream o; s.Write(o);
    });

    printf("\n  -- Index(), a second divergence: no crash, but a bogus non-zero index --\n");
    probe("GeomTools_CurveSet::Add(null); Index(null)", [&] {
        GeomTools_CurveSet s; s.Add(nullCurve3d);
        printf("      Index returned %d\n", s.Index(nullCurve3d));
    });
    probe("GeomTools_Curve2dSet::Add(null); Index(null)", [&] {
        GeomTools_Curve2dSet s; s.Add(nullCurve2d);
        printf("      Index returned %d\n", s.Index(nullCurve2d));
    });
    probe("GeomTools_SurfaceSet::Add(null); Index(null)", [&] {
        GeomTools_SurfaceSet s; s.Add(nullSurface);
        printf("      Index returned %d\n", s.Index(nullSurface));
    });

    printf("\nPART 2: the actual bridge functions (OCCTBridge_IO.mm), override-linked - is the "
           "crash reachable through OCCTSwift?\n\n");

    probe("OCCTGeomToolsCurve2dSetWrite([nullWrappingCurve2D])", [&] {
        OCCTCurve2D nullWrapped(nullCurve2d);
        const OCCTCurve2DRef refs[1] = { (OCCTCurve2DRef)&nullWrapped };
        const char* result = OCCTGeomToolsCurve2dSetWrite(refs, 1);
        printf("      result = %s\n", result ? "non-null (BUG: should have refused)" : "nullptr (refused, as expected)");
    });
    probe("OCCTGeomToolsSurfaceSetWrite([nullWrappingSurface])", [&] {
        OCCTSurface nullWrapped(nullSurface);
        const OCCTSurfaceRef refs[1] = { (OCCTSurfaceRef)&nullWrapped };
        const char* result = OCCTGeomToolsSurfaceSetWrite(refs, 1);
        printf("      result = %s\n", result ? "non-null (BUG: should have refused)" : "nullptr (refused, as expected)");
    });
    probe("OCCTGeomToolsCurveSetWrite([nullWrappingCurve3D])", [&] {
        OCCTCurve3D nullWrapped(nullCurve3d);
        const OCCTCurve3DRef refs[1] = { (OCCTCurve3DRef)&nullWrapped };
        const char* result = OCCTGeomToolsCurveSetWrite(refs, 1);
        printf("      result = %s\n", result ? "non-null (BUG: should have refused)" : "nullptr (refused, as expected)");
    });
    // A mixed batch - one valid curve, one null - to confirm the guard rejects the WHOLE batch
    // rather than silently dropping just the bad element (matching the sibling comment in
    // OCCTGeomToolsCurveSetWrite about why "refuse the batch" was chosen over "drop the null").
    probe("OCCTGeomToolsCurve2dSetWrite([validLine, nullWrappingCurve2D])", [&] {
        occ::handle<Geom2d_Curve> validLine = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
        OCCTCurve2D validWrapped(validLine);
        OCCTCurve2D nullWrapped(nullCurve2d);
        const OCCTCurve2DRef refs[2] = { (OCCTCurve2DRef)&validWrapped, (OCCTCurve2DRef)&nullWrapped };
        const char* result = OCCTGeomToolsCurve2dSetWrite(refs, 2);
        printf("      result = %s\n", result ? "non-null (BUG: should have refused)" : "nullptr (refused, as expected)");
    });

    return 0;
}
