// #636 kernel-level ground truth. Bridge-side, `OCCTCurve3DExtrema` already guards this with an
// `IsParallel()` check (PR #730, `Sources/OCCTBridge/src/OCCTBridge_Curve3D.mm`) - that guard is
// not touched here. This probe isolates the kernel defect underneath it: `Extrema_ExtCC::NbExt()`
// counts `mySqDist` while `Extrema_ExtCC::Points()` reads `mypoints`, and several branches of
// `PrepareParallelResult` (Extrema_ExtCC.cxx) append a distance without a matching point pair, so
// `NbExt()` over-reports and `Points()` indexes an empty `NCollection_Sequence`.
//
// Four fixtures, chosen to separate the shapes PrepareParallelResult actually produces (all
// verified against Extrema_ExtCC.cxx's source, not guessed from behavior):
//
//   1. OVERLAPPING  - two finite parallel segments whose projected ranges overlap over a genuine
//      interval (Delta() > Precision::Confusion()). IsParallel=1, NbExtrema=1, no point pair
//      exists at all (there is a whole equidistant family) - crashes on stock, and correctly
//      SHOULD refuse to answer Points(1) even after the fix: there is no single right answer.
//   2. DISJOINT     - two finite parallel segments whose projected ranges don't overlap.
//      PrepareParallelResult explicitly resets IsParallel=0 and returns the real nearest-endpoint
//      pair. Never crashes, and must not change under this fix - it is the control case proving
//      the fix doesn't regress the ordinary "parallel lines, but there IS a unique answer" path.
//   3. UNBOUNDED    - two infinite Geom_Line's, parallel. isFirstInfinite/isLastInfinite branch:
//      "infinite number of solutions", distance only, no point pair. Crashes on stock, same shape
//      as case 1 but through a different branch (this is the fixture PR #730's own regression
//      tests use).
//   4. TOUCHING     - two finite parallel segments whose projected ranges intersect at EXACTLY one
//      point (Delta() <= Precision::Confusion(), range not void). This is the case that makes
//      "gate Points() on IsParallel()" the wrong general-purpose kernel fix: IsParallel() stays
//      TRUE here (PrepareParallelResult never resets it in this branch) AND a real, unique point
//      pair is appended and always has been reachable. Must not change under this fix, and this is
//      exactly the shape the bridge-side IsParallel() guard (correctly, for its own narrower job)
//      trades away: it would return empty for this case too, discarding a real answer. Not fixed
//      here (out of scope, PR #730 owns that file) - reported so a future 2D/bridge pass has the
//      finding on record.
//
// Every fixture is run through GeomAPI_ExtremaCurveCurve (the same class OCCTCurve3DExtrema calls),
// not just the internal Extrema_ExtCC, because GeomAPI_ExtremaCurveCurve::Points() has its own
// bounds check that is ALSO compiled to nothing under No_Exception (it uses the
// Standard_OutOfRange_Raise_if macro, same as NCollection_Sequence::Value() does) - so this probe
// also answers "does a real, raw `throw` inside Extrema_ExtCC::Points() survive being called
// through a wrapper whose own guard is a no-op". LowerDistance()/SquareDistance(1) are probed too,
// on every fixture, to confirm they are unaffected in every branch (they only ever read mySqDist,
// which every branch populates correctly - this fix does not touch NbExt() or mySqDist at all).
//
// Compile and run against the pinned kernel (v2.0.0-kernel.1, no override):
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/636-extrema-parallel/probe_636.mm -o /tmp/probe_636
//   /tmp/probe_636
//
// To validate the patch without a full kernel rebuild, override-link the patched
// Extrema_ExtCC.cxx ahead of the archive - see this directory's README for the exact command,
// which follows Scripts/patches/README.md's `#0001` entry for the technique, compiled with
// `-DNDEBUG -DNo_Exception` to match the production build (or Raise_if comes back and this
// measures a kernel nobody ships).
//
// Each case forks so a SIGSEGV in the child is reported to the parent rather than ending the run
// (same idiom as Scripts/repro/643-geomtools-null-write/probe_643.mm's `probe()`).

#include <GC_MakeSegment.hxx>
#include <GeomAPI_ExtremaCurveCurve.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Extrema_ExtCC.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Standard_Failure.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cerrno>
#include <cstdio>
#include <functional>
#include <sys/wait.h>
#include <unistd.h>

static void probe(const char* what, const std::function<void()>& body) {
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        try { body(); }
        catch (Standard_OutOfRange const& e) {
            printf("      caught Standard_OutOfRange: %s\n", e.GetMessageString());
            fflush(stdout);
            _exit(3);
        }
        catch (Standard_Failure const& e) {
            printf("      caught Standard_Failure: %s\n", e.GetMessageString());
            fflush(stdout);
            _exit(4);
        }
        catch (...) { fflush(stdout); _exit(5); }
        fflush(stdout);
        _exit(0);
    }
    if (pid < 0) {
        printf("  %-46s fork() failed (errno %d) - not measured\n", what, errno);
        return;
    }
    int st = 0;
    if (waitpid(pid, &st, 0) < 0) {
        printf("  %-46s waitpid() failed (errno %d) - not measured\n", what, errno);
        return;
    }
    const char* verdict;
    if (WIFSIGNALED(st)) {
        verdict = (WTERMSIG(st) == SIGSEGV) ? "SIGSEGV (uncatchable)" : "SIGNAL (uncatchable)";
    } else if (WEXITSTATUS(st) == 3) {
        verdict = "Standard_OutOfRange (catchable)";
    } else if (WEXITSTATUS(st) == 4) {
        verdict = "Standard_Failure (catchable)";
    } else if (WEXITSTATUS(st) == 5) {
        verdict = "other exception (catchable)";
    } else {
        verdict = "returned normally";
    }
    printf("  %-46s %s\n", what, verdict);
}

static void runCase(const char* label,
                     const occ::handle<Geom_Curve>& c1,
                     const occ::handle<Geom_Curve>& c2) {
    printf("-- %s --\n", label);

    GeomAPI_ExtremaCurveCurve ext(c1, c2);
    printf("  IsParallel()  = %d\n", (int)ext.IsParallel());
    printf("  NbExtrema()   = %d\n", ext.NbExtrema());

    probe("GeomAPI_ExtremaCurveCurve::LowerDistance()", [&] {
        printf("      LowerDistance() = %.6f\n", ext.LowerDistance());
    });
    if (ext.NbExtrema() >= 1) {
        probe("GeomAPI_ExtremaCurveCurve::SquareDistance/Distance(1)", [&] {
            printf("      Distance(1) = %.6f\n", ext.Distance(1));
        });
        probe("GeomAPI_ExtremaCurveCurve::Points(1, ...)", [&] {
            gp_Pnt p1, p2;
            ext.Points(1, p1, p2);
            printf("      P1=(%.3f,%.3f,%.3f) P2=(%.3f,%.3f,%.3f)\n",
                   p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
        });

        // Same fixture, straight through the low-level class GeomAPI_ExtremaCurveCurve wraps -
        // confirms the defect (and the fix) sit in Extrema_ExtCC itself, not in the wrapper.
        probe("Extrema_ExtCC::Points(1, ...) [direct, low-level]", [&] {
            GeomAdaptor_Curve a1(c1), a2(c2);
            Extrema_ExtCC extcc(a1, a2);
            extcc.Perform();
            Extrema_POnCurv p1, p2;
            extcc.Points(1, p1, p2);
            printf("      NbExt()=%d P1 param=%.3f P2 param=%.3f\n",
                   extcc.NbExt(), p1.Parameter(), p2.Parameter());
        });
    }
    printf("\n");
}

int main() {
    printf("#636 Extrema_ExtCC parallel-curve ground truth\n\n");

    // 1. OVERLAPPING projected ranges - finite segments, no unique closest pair exists.
    {
        occ::handle<Geom_TrimmedCurve> c1 = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
        occ::handle<Geom_TrimmedCurve> c2 = GC_MakeSegment(gp_Pnt(3, 1, 0), gp_Pnt(13, 1, 0)).Value();
        runCase("1. OVERLAPPING projected ranges (finite, parallel)", c1, c2);
    }

    // 2. DISJOINT projected ranges - finite segments, exactly one real answer, must stay unaffected.
    {
        occ::handle<Geom_TrimmedCurve> c1 = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
        occ::handle<Geom_TrimmedCurve> c2 = GC_MakeSegment(gp_Pnt(20, 1, 0), gp_Pnt(30, 1, 0)).Value();
        runCase("2. DISJOINT projected ranges (finite, parallel)", c1, c2);
    }

    // 3. UNBOUNDED - two infinite lines, parallel. PR #730's own fixture shape.
    {
        occ::handle<Geom_Line> c1 = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
        occ::handle<Geom_Line> c2 = new Geom_Line(gp_Pnt(0, 1, 0), gp_Dir(1, 0, 0));
        runCase("3. UNBOUNDED (infinite Geom_Line, parallel)", c1, c2);
    }

    // 4. TOUCHING at exactly one point - IsParallel stays true, but a real unique pair exists.
    {
        occ::handle<Geom_TrimmedCurve> c1 = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
        occ::handle<Geom_TrimmedCurve> c2 = GC_MakeSegment(gp_Pnt(10, 1, 0), gp_Pnt(20, 1, 0)).Value();
        runCase("4. TOUCHING at one point (finite, parallel, IsParallel stays true)", c1, c2);
    }

    return 0;
}
