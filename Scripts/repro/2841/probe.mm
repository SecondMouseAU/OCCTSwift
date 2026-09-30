// Ground truth for #2841: the THREE-curve constructors of GeomFill_BSplineCurves and
// GeomFill_BezierCurves, the only unwrapped ones, and the guard they need.
//
// Reads:
//   GeomFill_BSplineCurves.cxx:396-439  Init(C1, C2, C3, Type)   synthesises C4, calls the 4-curve Init
//   GeomFill_BSplineCurves.cxx:271-287  Init(C1..C4, Type)       Arrange + the compiled-out refusal
//   GeomFill_BezierCurves.cxx:304-335   Init(C1, C2, C3, Type)   the same, with a 2-pole Bezier
//   GeomFill_BezierCurves.cxx:194-209   Init(C1..C4, Type)       the same Arrange + refusal
//
// Both 3-curve Inits build a straight two-pole fourth side between the FAR ends of C1 and C3,
// where "far" means the endpoint that does not meet C2, and then call the 4-curve Init. So C2 is
// positionally the middle curve, and a caller who guesses wrong hands the 4-curve Init a set that
// does not close. That refusal is compiled out of the kernel we ship (#2842), so the wrong guess
// is an uncatchable SIGSEGV rather than a nil.
//
// Compile (from the repo root, in a worktree with no Libraries/OCCT.xcframework, so the pinned
// asset SwiftPM resolved is what gets linked):
//
//   XCF=$(find .build/artifacts -maxdepth 4 -name OCCT.xcframework)
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"$XCF/macos-arm64/Headers" -L"$XCF/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2841/probe.mm -o /tmp/occt_probe_2841
//
// Run one section per process, because three of them crash:  ./occt_probe_2841 <A..G>
// Section G forks a child per case so the crashing cases can be counted rather than avoided.

#include <GC_MakeArcOfCircle.hxx>
#include <Convert_ParameterisationType.hxx>
#include <GeomConvert.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <GeomFill_BezierCurves.hxx>
#include <GeomFill_FillingStyle.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BezierSurface.hxx>
#include <NCollection_Array1.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sys/wait.h>
#include <unistd.h>

// A straight segment as a degree-3 Bezier (4 collinear poles). Degree 3 matters for the BSpline
// flavour: Coons style refuses fewer than 4 poles per direction after knot alignment
// (GeomFill_BSplineCurves.cxx:300), and that limit is a real `throw`, not the compiled-out macro.
static Handle(Geom_BezierCurve) bez(const gp_Pnt& a, const gp_Pnt& b)
{
  NCollection_Array1<gp_Pnt> p(1, 4);
  p(1) = a;
  p(2) = gp_Pnt(a.XYZ() + (b.XYZ() - a.XYZ()) / 3.0);
  p(3) = gp_Pnt(a.XYZ() + (b.XYZ() - a.XYZ()) * (2.0 / 3.0));
  p(4) = b;
  return new Geom_BezierCurve(p);
}

// The same segment as a bare two-pole degree-1 Bezier, for the Coons pole-count question.
static Handle(Geom_BezierCurve) bez2(const gp_Pnt& a, const gp_Pnt& b)
{
  NCollection_Array1<gp_Pnt> p(1, 2);
  p(1) = a;
  p(2) = b;
  return new Geom_BezierCurve(p);
}

static Handle(Geom_BSplineCurve) bsp(const gp_Pnt& a, const gp_Pnt& b)
{
  return GeomConvert::CurveToBSplineCurve(bez(a, b));
}

static Handle(Geom_BSplineCurve) bsp2(const gp_Pnt& a, const gp_Pnt& b)
{
  return GeomConvert::CurveToBSplineCurve(bez2(a, b));
}

// The four corners of a flat 10 x 10 square in z = 0.
static const gp_Pnt A(0, 0, 0), B(10, 0, 0), C(10, 10, 0), D(0, 10, 0);

static const char* styleName(GeomFill_FillingStyle s)
{
  switch (s)
  {
    case GeomFill_StretchStyle:
      return "stretch";
    case GeomFill_CoonsStyle:
      return "coons  ";
    default:
      return "curved ";
  }
}

// === the transcription under test =============================================================
//
// occtGeomFillThreeCurveChord, which the bridge will carry, is the endpoint half of the 3-curve
// Init's C4 synthesis: the SAME two tests, against the SAME Tol = Precision::Confusion() squared
// compared with SquareDistance. Only the two endpoints are computed; no curve is built, because
// the guard only needs to know where the synthesised side would start and end.
struct Chord
{
  gp_Pnt p1, p2;
};

static Chord synthesiseChord(const gp_Pnt& c1Start,
                             const gp_Pnt& c1End,
                             const gp_Pnt& c2Start,
                             const gp_Pnt& c2End,
                             const gp_Pnt& c3Start,
                             const gp_Pnt& c3End)
{
  double tol = Precision::Confusion();
  tol        = tol * tol;
  Chord r;
  r.p1 = (c1Start.SquareDistance(c2Start) > tol && c1Start.SquareDistance(c2End) > tol) ? c1Start
                                                                                        : c1End;
  r.p2 = (c3Start.SquareDistance(c2Start) > tol && c3Start.SquareDistance(c2End) > tol) ? c3Start
                                                                                        : c3End;
  return r;
}

// Arrange()'s acceptance half, exactly as OCCTBridge_Surface_Fill.mm already carries it for the
// four-curve entry points (#2829). Repeated here so the probe tests the same predicate.
struct Seg
{
  gp_Pnt s, e;
};

static bool arrangeSucceeds(Seg g[4], double tol, bool degeneratePrePass)
{
  for (int i = 1; i <= 3; i++)
  {
    bool found = false;
    if (degeneratePrePass)
    {
      for (int j = i; j <= 3 && !found; j++)
      {
        if (g[j].s.Distance(g[j].e) < tol && g[j].s.Distance(g[i - 1].e) < tol)
        {
          Seg t = g[i];
          g[i]  = g[j];
          g[j]  = t;
          found = true;
        }
      }
    }
    if (!found)
    {
      for (int j = i; j <= 3 && !found; j++)
      {
        if (g[j].s.Distance(g[i - 1].e) < tol)
        {
          Seg t = g[i];
          g[i]  = g[j];
          g[j]  = t;
          found = true;
        }
        else if (g[j].e.Distance(g[i - 1].e) < tol)
        {
          gp_Pnt sw = g[j].s;
          g[j].s    = g[j].e;
          g[j].e    = sw;
          Seg t     = g[i];
          g[i]      = g[j];
          g[j]      = t;
          found     = true;
        }
      }
    }
    if (!found)
      return false;
  }
  return true;
}

// The whole guard the bridge will apply to a three-curve request.
static bool threeCurvesJoin(const gp_Pnt ends[3][2], bool degeneratePrePass)
{
  Chord ch = synthesiseChord(ends[0][0],
                             ends[0][1],
                             ends[1][0],
                             ends[1][1],
                             ends[2][0],
                             ends[2][1]);
  Seg   g[4] = {{ends[0][0], ends[0][1]},
                {ends[1][0], ends[1][1]},
                {ends[2][0], ends[2][1]},
                {ch.p1, ch.p2}};
  return arrangeSucceeds(g, Precision::Confusion(), degeneratePrePass);
}

// === sections ==================================================================================

static void reportBSpline(const char*                    label,
                          const Handle(Geom_BSplineCurve) & c1,
                          const Handle(Geom_BSplineCurve) & c2,
                          const Handle(Geom_BSplineCurve) & c3,
                          GeomFill_FillingStyle style)
{
  fflush(stdout);
  try
  {
    GeomFill_BSplineCurves      f(c1, c2, c3, style);
    Handle(Geom_BSplineSurface) s = f.Surface();
    if (s.IsNull())
    {
      printf("  %s %s: NULL surface\n", label, styleName(style));
      return;
    }
    double u0, u1, v0, v1;
    s->Bounds(u0, u1, v0, v1);
    gp_Pnt c00 = s->Value(u0, v0), c10 = s->Value(u1, v0);
    gp_Pnt c01 = s->Value(u0, v1), c11 = s->Value(u1, v1);
    printf("  %s %s: poles %dx%d  bounds u=[%g,%g] v=[%g,%g]\n",
           label,
           styleName(style),
           s->NbUPoles(),
           s->NbVPoles(),
           u0,
           u1,
           v0,
           v1);
    printf("      (uMin,vMin)=(%.4f,%.4f,%.4f)  (uMax,vMin)=(%.4f,%.4f,%.4f)\n",
           c00.X(),
           c00.Y(),
           c00.Z(),
           c10.X(),
           c10.Y(),
           c10.Z());
    printf("      (uMin,vMax)=(%.4f,%.4f,%.4f)  (uMax,vMax)=(%.4f,%.4f,%.4f)\n",
           c01.X(),
           c01.Y(),
           c01.Z(),
           c11.X(),
           c11.Y(),
           c11.Z());
  }
  catch (const Standard_Failure& e)
  {
    printf("  %s %s: THREW %s (%s)\n", label, styleName(style), e.ExceptionType(), e.GetMessageString());
  }
}

static void reportBezier(const char*                   label,
                         const Handle(Geom_BezierCurve) & c1,
                         const Handle(Geom_BezierCurve) & c2,
                         const Handle(Geom_BezierCurve) & c3,
                         GeomFill_FillingStyle style)
{
  fflush(stdout);
  try
  {
    GeomFill_BezierCurves      f(c1, c2, c3, style);
    Handle(Geom_BezierSurface) s = f.Surface();
    if (s.IsNull())
    {
      printf("  %s %s: NULL surface\n", label, styleName(style));
      return;
    }
    double u0, u1, v0, v1;
    s->Bounds(u0, u1, v0, v1);
    gp_Pnt c00 = s->Value(u0, v0), c10 = s->Value(u1, v0);
    gp_Pnt c01 = s->Value(u0, v1), c11 = s->Value(u1, v1);
    printf("  %s %s: poles %dx%d  bounds u=[%g,%g] v=[%g,%g]\n",
           label,
           styleName(style),
           s->NbUPoles(),
           s->NbVPoles(),
           u0,
           u1,
           v0,
           v1);
    printf("      (uMin,vMin)=(%.4f,%.4f,%.4f)  (uMax,vMin)=(%.4f,%.4f,%.4f)\n",
           c00.X(),
           c00.Y(),
           c00.Z(),
           c10.X(),
           c10.Y(),
           c10.Z());
    printf("      (uMin,vMax)=(%.4f,%.4f,%.4f)  (uMax,vMax)=(%.4f,%.4f,%.4f)\n",
           c01.X(),
           c01.Y(),
           c01.Z(),
           c11.X(),
           c11.Y(),
           c11.Z());
  }
  catch (const Standard_Failure& e)
  {
    printf("  %s %s: THREW %s (%s)\n", label, styleName(style), e.ExceptionType(), e.GetMessageString());
  }
}

// Section G's single case, run in a forked child: build the three curves for one (middle, flips)
// combination and hand them to the kernel. Exit 0 if a surface came back, 2 on a catchable
// failure; a crash is whatever the signal makes it.
static int kernelCase(int middle, int flips, bool bspline)
{
  // The three sides of the square, before any rotation of which one is the middle.
  gp_Pnt seg[3][2] = {{A, B}, {B, C}, {C, D}};
  // middle == 1 is the canonical assignment (C2 = the middle side, B->C).
  // middle == 0 and 2 rotate the roles so the wrong side sits in the C2 slot.
  int order[3] = {(middle + 2) % 3, middle, (middle + 1) % 3};
  gp_Pnt pick[3][2];
  for (int k = 0; k < 3; k++)
  {
    bool rev  = (flips >> k) & 1;
    pick[k][0] = rev ? seg[order[k]][1] : seg[order[k]][0];
    pick[k][1] = rev ? seg[order[k]][0] : seg[order[k]][1];
  }
  fflush(stdout);
  try
  {
    if (bspline)
    {
      GeomFill_BSplineCurves f(bsp(pick[0][0], pick[0][1]),
                               bsp(pick[1][0], pick[1][1]),
                               bsp(pick[2][0], pick[2][1]),
                               GeomFill_CurvedStyle);
      return f.Surface().IsNull() ? 2 : 0;
    }
    GeomFill_BezierCurves f(bez(pick[0][0], pick[0][1]),
                            bez(pick[1][0], pick[1][1]),
                            bez(pick[2][0], pick[2][1]),
                            GeomFill_CurvedStyle);
    return f.Surface().IsNull() ? 2 : 0;
  }
  catch (const Standard_Failure&)
  {
    return 2;
  }
}

static void sectionG()
{
  printf("Agreement between the transcribed guard and the kernel, over 3 middle-slot assignments\n"
         "x 8 direction flips, for both flavours. Each kernel case runs in a forked child, so a\n"
         "SIGSEGV is counted rather than avoided.\n\n");
  printf("  flavour  middle  flips  guard   kernel\n");
  int agree = 0, total = 0, crashes = 0;
  for (int fl = 0; fl < 2; fl++)
  {
    bool bspline = (fl == 0);
    for (int middle = 0; middle < 3; middle++)
    {
      for (int flips = 0; flips < 8; flips++)
      {
        gp_Pnt seg[3][2] = {{A, B}, {B, C}, {C, D}};
        int    order[3]  = {(middle + 2) % 3, middle, (middle + 1) % 3};
        gp_Pnt ends[3][2];
        for (int k = 0; k < 3; k++)
        {
          bool rev    = (flips >> k) & 1;
          ends[k][0]  = rev ? seg[order[k]][1] : seg[order[k]][0];
          ends[k][1]  = rev ? seg[order[k]][0] : seg[order[k]][1];
        }
        bool guard = threeCurvesJoin(ends, bspline);

        fflush(stdout);
        pid_t pid = fork();
        if (pid == 0)
        {
          _exit(kernelCase(middle, flips, bspline));
        }
        int status = 0;
        waitpid(pid, &status, 0);
        const char* kernelSays;
        if (WIFSIGNALED(status))
        {
          kernelSays = "SIGNAL";
          crashes++;
        }
        else
        {
          kernelSays = (WEXITSTATUS(status) == 0) ? "surface" : "refused";
        }
        bool ok = guard ? (strcmp(kernelSays, "surface") == 0)
                        : (strcmp(kernelSays, "surface") != 0);
        agree += ok ? 1 : 0;
        total++;
        printf("  %-8s %6d  %5d  %-6s  %-7s  %s\n",
               bspline ? "bspline" : "bezier",
               middle,
               flips,
               guard ? "accept" : "refuse",
               kernelSays,
               ok ? "" : "  <-- DISAGREES");
      }
    }
  }
  printf("\n  agreement %d/%d, kernel crashed in %d of them\n", agree, total, crashes);
}

int main(int argc, char** argv)
{
  const char sec = (argc > 1) ? argv[1][0] : 'A';

  if (sec == 'A')
  {
    printf("[A] GeomFill_BSplineCurves 3-curve, canonical (bottom, right, top) of a flat square.\n"
           "    The synthesised fourth side is the chord A->D, the left side.\n\n");
    for (int s = 0; s <= 2; s++)
      reportBSpline("square", bsp(A, B), bsp(B, C), bsp(C, D), (GeomFill_FillingStyle)s);
    printf("\n    The same three sides with a TWO-POLE degree-1 middle curve, which is what\n"
           "    decides whether .coons is reachable: DegV = max(deg C2, deg C4) and both are 1.\n\n");
    for (int s = 0; s <= 2; s++)
      reportBSpline("2-pole C2", bsp(A, B), bsp2(B, C), bsp(C, D), (GeomFill_FillingStyle)s);
  }
  else if (sec == 'B')
  {
    printf("[B] GeomFill_BezierCurves 3-curve, the same three sides.\n"
           "    Its 4-curve Init raises every side to at least degree 3 for Coons style\n"
           "    (GeomFill_BezierCurves.cxx:212-215), so a two-pole middle is not a limit here.\n\n");
    for (int s = 0; s <= 2; s++)
      reportBezier("square", bez(A, B), bez(B, C), bez(C, D), (GeomFill_FillingStyle)s);
    printf("\n    With a two-pole degree-1 middle curve:\n\n");
    for (int s = 0; s <= 2; s++)
      reportBezier("2-pole C2", bez(A, B), bez2(B, C), bez(C, D), (GeomFill_FillingStyle)s);
  }
  else if (sec == 'C')
  {
    printf("[C] BSpline 3-curve on a PERIODIC support: a quarter patch on a cylinder of radius 5,\n"
           "    bottom arc, seam, top arc. The synthesised chord closes the second seam.\n\n");
    gp_Pnt             p0(5, 0, 0), p1(0, 5, 0), p2(0, 5, 8), p3(5, 0, 8);
    double             m = 5 * 0.7071067811865476;
    GC_MakeArcOfCircle arc0(p0, gp_Pnt(m, m, 0), p1);
    GC_MakeArcOfCircle arc8(p3, gp_Pnt(m, m, 8), p2);
    if (!arc0.IsDone() || !arc8.IsDone())
    {
      printf("    arc construction failed\n");
      return 1;
    }
    Handle(Geom_BSplineCurve) bottom = GeomConvert::CurveToBSplineCurve(arc0.Value());
    Handle(Geom_BSplineCurve) top    = GeomConvert::CurveToBSplineCurve(arc8.Value());
    for (int s = 0; s <= 2; s++)
      reportBSpline("cylinder", bottom, bsp(p1, p2), top, (GeomFill_FillingStyle)s);
  }
  else if (sec == 'D')
  {
    printf("[D] BSpline 3-curve with the WRONG middle: (bottom, top, right). The chord is then\n"
           "    A->B, which duplicates C1 rather than closing anything, Arrange returns false,\n"
           "    and the refusal is compiled out. Expect a signal.\n");
    gp_Pnt ends[3][2] = {{A, B}, {C, D}, {B, C}};
    printf("    guard says: %s\n", threeCurvesJoin(ends, true) ? "accept" : "refuse");
    fflush(stdout);
    GeomFill_BSplineCurves f(bsp(A, B), bsp(C, D), bsp(B, C), GeomFill_CurvedStyle);
    printf("    survived, surface null = %d\n", (int)f.Surface().IsNull());
  }
  else if (sec == 'E')
  {
    printf("[E] Bezier 3-curve, the same wrong middle. Expect a signal.\n");
    gp_Pnt ends[3][2] = {{A, B}, {C, D}, {B, C}};
    printf("    guard says: %s\n", threeCurvesJoin(ends, false) ? "accept" : "refuse");
    fflush(stdout);
    GeomFill_BezierCurves f(bez(A, B), bez(C, D), bez(B, C), GeomFill_CurvedStyle);
    printf("    survived, surface null = %d\n", (int)f.Surface().IsNull());
  }
  else if (sec == 'F')
  {
    printf("[F] BSpline 3-curve, three curves that form no chain at all: bottom, a floating\n"
           "    segment lifted to z = 5, and top. Expect a signal.\n");
    gp_Pnt f1(10, 0, 5), f2(10, 10, 5);
    gp_Pnt ends[3][2] = {{A, B}, {f1, f2}, {C, D}};
    printf("    guard says: %s\n", threeCurvesJoin(ends, true) ? "accept" : "refuse");
    fflush(stdout);
    GeomFill_BSplineCurves f(bsp(A, B), bsp(f1, f2), bsp(C, D), GeomFill_CurvedStyle);
    printf("    survived, surface null = %d\n", (int)f.Surface().IsNull());
  }
  else if (sec == 'G')
  {
    sectionG();
  }
  else if (sec == 'H')
  {
    // The bridge does not hand OCCT the curve it was given: toBSplineCurve in
    // OCCTBridge_Surface_Fill.mm runs GeomConvert::CurveToBSplineCurve(curve, Convert_QuasiAngular)
    // on every input. That changes the pole count of an arc, and the pole count is what decides
    // whether .coons is reachable, so the Swift wrapper and the raw kernel disagree on the same
    // three curves. This section measures the difference rather than leaving the test to assume it.
    printf("[H] What the bridge's Convert_QuasiAngular conversion does to an arc's pole count,\n"
           "    and therefore to .coons on the cylinder patch of section [C].\n\n");
    gp_Pnt             p0(5, 0, 0), p1(0, 5, 0), p2(0, 5, 8), p3(5, 0, 8);
    double             m = 5 * 0.7071067811865476;
    GC_MakeArcOfCircle arc0(p0, gp_Pnt(m, m, 0), p1);
    GC_MakeArcOfCircle arc8(p3, gp_Pnt(m, m, 8), p2);
    if (!arc0.IsDone() || !arc8.IsDone())
    {
      printf("    arc construction failed\n");
      return 1;
    }
    Handle(Geom_BSplineCurve) defBottom = GeomConvert::CurveToBSplineCurve(arc0.Value());
    Handle(Geom_BSplineCurve) qaBottom =
      GeomConvert::CurveToBSplineCurve(arc0.Value(), Convert_QuasiAngular);
    printf("    arc poles: default conversion %d, Convert_QuasiAngular %d\n",
           defBottom->NbPoles(),
           qaBottom->NbPoles());

    Handle(Geom_BSplineCurve) qaTop =
      GeomConvert::CurveToBSplineCurve(arc8.Value(), Convert_QuasiAngular);
    Handle(Geom_BSplineCurve) qaSeam =
      GeomConvert::CurveToBSplineCurve(bez(p1, p2), Convert_QuasiAngular);
    printf("\n    the same cylinder patch, every curve converted the way the bridge converts it:\n");
    for (int s = 0; s <= 2; s++)
      reportBSpline("cylinder(QA)", qaBottom, qaSeam, qaTop, (GeomFill_FillingStyle)s);
  }
  else
  {
    printf("unknown section %c\n", sec);
    return 1;
  }

  printf("\n=== section %c done ===\n", sec);
  return 0;
}
