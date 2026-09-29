// Ground truth for #2829: what GeomFill_BSplineCurves / GeomFill_BezierCurves do to four
// boundary curves, and what the pinned kernel does when they do not join.
//
// Reads:
//   GeomFill_BSplineCurves.cxx:53  Arrange()      (head-to-tail, swaps and Reversed()s)
//   GeomFill_BSplineCurves.cxx:287 Standard_ConstructionError_Raise_if(!IsOK, "Courbes non jointives")
//   GeomFill_BezierCurves.cxx:103  Arrange()      (same, no degenerate pre-pass)
//   GeomFill_BezierCurves.cxx:209  the same raise
//
// The kernel is built -DCMAKE_BUILD_TYPE=Release and OCCT's BUILD_RELEASE_DISABLE_EXCEPTIONS
// defaults to ON, so -DNo_Exception is in the flags and that raise macro expands to NOTHING
// (Standard_ConstructionError.hxx:24-30). This probe measures what happens instead.

#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <GeomFill_BezierCurves.hxx>
#include <GeomFill_FillingStyle.hxx>
#include <GeomConvert.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Surface.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Circ.hxx>
#include <gp_Pnt.hxx>
#include <NCollection_Array1.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>

#include <cstdio>
#include <cstdlib>
#include <string>

// A straight segment as a degree-3 Bezier (4 collinear poles). Degree 3 matters: Coons style
// refuses fewer than 4 poles per direction (GeomFill_BSplineCurves.cxx:300), so a 2-pole line
// throws Standard_ConstructionError "invalid filling style" before Arrange's result is ever used.
static Handle(Geom_BezierCurve) bez(const gp_Pnt& a, const gp_Pnt& b)
{
  NCollection_Array1<gp_Pnt> p(1, 4);
  p(1) = a;
  p(2) = gp_Pnt(a.XYZ() + (b.XYZ() - a.XYZ()) / 3.0);
  p(3) = gp_Pnt(a.XYZ() + (b.XYZ() - a.XYZ()) * (2.0 / 3.0));
  p(4) = b;
  return new Geom_BezierCurve(p);
}

static Handle(Geom_BSplineCurve) bsp(const gp_Pnt& a, const gp_Pnt& b)
{
  return GeomConvert::CurveToBSplineCurve(bez(a, b));
}

// A literal transcription of the ACCEPTANCE half of GeomFill_BSplineCurves.cxx:53 Arrange():
// the same greedy walk over slots 1..3, the same reversal branch, the same optional
// degenerate-curve pre-pass. Endpoints only; no geometry is copied.
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
          std::swap(g[i], g[j]);
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
          std::swap(g[i], g[j]);
          found = true;
        }
        else if (g[j].e.Distance(g[i - 1].e) < tol)
        {
          std::swap(g[j].s, g[j].e);
          std::swap(g[i], g[j]);
          found = true;
        }
      }
    }
    if (!found)
      return false;
  }
  return true;
}

#define TRY_REPORT(tag, expr)                                                                      \
  do                                                                                               \
  {                                                                                                \
    fflush(stdout);                                                                                \
    try                                                                                            \
    {                                                                                              \
      expr;                                                                                        \
    }                                                                                              \
    catch (const Standard_Failure& e)                                                              \
    {                                                                                              \
      printf("  %-34s THREW %s: %s\n", tag, e.ExceptionType(),                                     \
             e.GetMessageString() ? e.GetMessageString() : "");                                    \
    }                                                                                              \
  } while (0)

static void reportSurface(const char* tag, const Handle(Geom_BSplineSurface) & s)
{
  if (s.IsNull())
  {
    printf("  %-34s surface=NULL\n", tag);
    return;
  }
  double u0, u1, v0, v1;
  s->Bounds(u0, u1, v0, v1);
  gp_Pnt c00 = s->Value(u0, v0), c10 = s->Value(u1, v0), c01 = s->Value(u0, v1),
         c11 = s->Value(u1, v1);
  printf("  %-34s poles=%dx%d deg=%dx%d\n", tag, s->NbUPoles(), s->NbVPoles(), s->UDegree(),
         s->VDegree());
  printf("      corners (u0v0)=(%.4f,%.4f,%.4f) (u1v0)=(%.4f,%.4f,%.4f)\n", c00.X(), c00.Y(),
         c00.Z(), c10.X(), c10.Y(), c10.Z());
  printf("              (u0v1)=(%.4f,%.4f,%.4f) (u1v1)=(%.4f,%.4f,%.4f)\n", c01.X(), c01.Y(),
         c01.Z(), c11.X(), c11.Y(), c11.Z());
}

int main(int argc, char** argv)
{
  std::string only = (argc > 1) ? argv[1] : "";
  auto want       = [&](const char* k) { return only.empty() || only == k; };

  printf("=== #2829 ground truth: GeomFill_BSplineCurves / GeomFill_BezierCurves ===\n");
  printf("Precision::Confusion() = %g\n\n", Precision::Confusion());

  // ---- a planar unit square, four separate segments of a closed loop ----------------
  gp_Pnt A(0, 0, 0), B(10, 0, 0), C(10, 10, 0), D(0, 10, 0);

  if (want("A"))
  {
    printf("[A] planar square, canonical head-to-tail order A->B, B->C, C->D, D->A\n");
    fflush(stdout);
    TRY_REPORT("coons", {
      GeomFill_BSplineCurves f(bsp(A, B), bsp(B, C), bsp(C, D), bsp(D, A), GeomFill_CoonsStyle);
      reportSurface("coons", f.Surface());
    });
    TRY_REPORT("curved", {
      GeomFill_BSplineCurves g(bsp(A, B), bsp(B, C), bsp(C, D), bsp(D, A), GeomFill_CurvedStyle);
      reportSurface("curved", g.Surface());
    });
    TRY_REPORT("stretch", {
      GeomFill_BSplineCurves h(bsp(A, B), bsp(B, C), bsp(C, D), bsp(D, A), GeomFill_StretchStyle);
      reportSurface("stretch", h.Surface());
    });
    printf("\n");
  }

  if (want("B"))
  {
    // Same four edges, scrambled slot order AND scrambled individual directions.
    // Arrange() is supposed to fix both, keeping only C1's own direction.
    printf("[B] SAME square, scrambled order and reversed directions:\n");
    printf("    C1=A->B  C2=D->C (reversed top)  C3=A->D (reversed left)  C4=C->B (reversed right)\n");
    fflush(stdout);
    TRY_REPORT("coons (scrambled)", {
      GeomFill_BSplineCurves f(bsp(A, B), bsp(D, C), bsp(A, D), bsp(C, B), GeomFill_CoonsStyle);
      reportSurface("coons (scrambled)", f.Surface());
    });
    TRY_REPORT("curved (scrambled)", {
      GeomFill_BSplineCurves g(bsp(A, B), bsp(D, C), bsp(A, D), bsp(C, B), GeomFill_CurvedStyle);
      reportSurface("curved (scrambled)", g.Surface());
    });
    printf("\n");
  }

  if (want("C"))
  {
    printf("[C] NON-JOINING set: the top edge lifted to z=5 so no corner meets it.\n");
    gp_Pnt C2p(10, 10, 5), D2p(0, 10, 5);
    Seg    segs[4] = {{A, B}, {B, C}, {C2p, D2p}, {D, A}};
    printf("    my Arrange-predicate says: %s\n",
           arrangeSucceeds(segs, Precision::Confusion(), true) ? "JOINS" : "DOES NOT JOIN");
    printf("    now handing it to GeomFill_BSplineCurves...\n");
    fflush(stdout);
    try
    {
      GeomFill_BSplineCurves f(bsp(A, B), bsp(B, C), bsp(C2p, D2p), bsp(D, A), GeomFill_CoonsStyle);
      reportSurface("coons (non-joining)", f.Surface());
      printf("    RETURNED NORMALLY (no exception)\n");
    }
    catch (const Standard_Failure& e)
    {
      printf("    THREW Standard_Failure: %s / %s\n", e.ExceptionType(), e.GetMessageString() ? e.GetMessageString() : "(no message)");
    }
    catch (...)
    {
      printf("    THREW something else\n");
    }
    printf("    survived [C]\n\n");
    fflush(stdout);
  }

  if (want("D"))
  {
    printf("[D] NON-JOINING set, Bezier flavour (GeomFill_BezierCurves).\n");
    gp_Pnt C2p(10, 10, 5), D2p(0, 10, 5);
    Seg    segs[4] = {{A, B}, {B, C}, {C2p, D2p}, {D, A}};
    printf("    my Arrange-predicate (no degenerate pre-pass) says: %s\n",
           arrangeSucceeds(segs, Precision::Confusion(), false) ? "JOINS" : "DOES NOT JOIN");
    fflush(stdout);
    try
    {
      GeomFill_BezierCurves f(bez(A, B), bez(B, C), bez(C2p, D2p), bez(D, A), GeomFill_CoonsStyle);
      Handle(Geom_BezierSurface) s = f.Surface();
      printf("    RETURNED NORMALLY, surface=%s\n", s.IsNull() ? "NULL" : "non-null");
    }
    catch (const Standard_Failure& e)
    {
      printf("    THREW Standard_Failure: %s\n", e.ExceptionType());
    }
    catch (...)
    {
      printf("    THREW something else\n");
    }
    printf("    survived [D]\n\n");
    fflush(stdout);
  }

  if (want("E"))
  {
    // Four boundary curves lying on a PERIODIC support (a cylinder), the second support #430
    // insists on. Two arcs at z=0 and z=8 plus two vertical seams.
    printf("[E] periodic support: a quarter patch on a cylinder r=5, arcs + vertical seams.\n");
    fflush(stdout);
    gp_Pnt P0(5, 0, 0), P1(0, 5, 0), P2(0, 5, 8), P3(5, 0, 8);
    gp_Pnt Mid0(5 * 0.7071067811865476, 5 * 0.7071067811865476, 0);
    gp_Pnt Mid8(5 * 0.7071067811865476, 5 * 0.7071067811865476, 8);
    GC_MakeArcOfCircle arc0(P0, Mid0, P1);
    GC_MakeArcOfCircle arc8(P3, Mid8, P2);
    if (!arc0.IsDone() || !arc8.IsDone())
    {
      printf("    arc construction failed\n");
    }
    else
    {
      Handle(Geom_BSplineCurve) bottom = GeomConvert::CurveToBSplineCurve(arc0.Value());
      Handle(Geom_BSplineCurve) top    = GeomConvert::CurveToBSplineCurve(arc8.Value());
      Handle(Geom_BSplineCurve) left   = bsp(P1, P2);
      Handle(Geom_BSplineCurve) right  = bsp(P3, P0);
      printf("    canonical order bottom(P0->P1), left(P1->P2), top(P3->P2), right(P3->P0)\n");
      TRY_REPORT("coons on cylinder", {
        GeomFill_BSplineCurves f(bottom, left, top, right, GeomFill_CoonsStyle);
        reportSurface("coons on cylinder", f.Surface());
      });
      TRY_REPORT("curved, args scrambled", {
        GeomFill_BSplineCurves g(bottom, top, right, left, GeomFill_CurvedStyle);
        reportSurface("curved, args scrambled", g.Surface());
      });
      // non-joining on the periodic support: push the top arc off the seam
      gp_Pnt Q2(0, 5, 8), Q3(5, 0, 20);
      Seg    segs[4] = {{P0, P1}, {P1, P2}, {Q3, Q2}, {P3, P0}};
      printf("    non-joining variant, my predicate says: %s\n",
             arrangeSucceeds(segs, Precision::Confusion(), true) ? "JOINS" : "DOES NOT JOIN");
      fflush(stdout);
      try
      {
        GeomFill_BSplineCurves h(bottom, left, bsp(Q3, Q2), right, GeomFill_CoonsStyle);
        reportSurface("coons (non-joining, cyl)", h.Surface());
        printf("    RETURNED NORMALLY\n");
      }
      catch (const Standard_Failure& e)
      {
        printf("    THREW %s\n", e.ExceptionType());
      }
      printf("    survived [E]\n");
    }
    printf("\n");
  }

  if (want("F"))
  {
    // Does the predicate ever disagree with the kernel on input the kernel ACCEPTS?
    // Walk all 24 permutations x 16 direction flips of the planar square and compare.
    printf("[F] predicate vs kernel over 24 permutations x 16 direction flips of the square\n");
    int  order[4] = {0, 1, 2, 3};
    gp_Pnt ends[4][2] = {{A, B}, {B, C}, {C, D}, {D, A}};
    int  agree = 0, predicateYes = 0, kernelYes = 0, disagree = 0;
    int  perm[24][4];
    int  np = 0;
    for (int a = 0; a < 4; a++)
      for (int b = 0; b < 4; b++)
        for (int c = 0; c < 4; c++)
          for (int d = 0; d < 4; d++)
          {
            if (a == b || a == c || a == d || b == c || b == d || c == d)
              continue;
            perm[np][0] = a;
            perm[np][1] = b;
            perm[np][2] = c;
            perm[np][3] = d;
            np++;
          }
    (void)order;
    for (int p = 0; p < np; p++)
      for (int flip = 0; flip < 16; flip++)
      {
        Seg segs[4];
        Handle(Geom_BSplineCurve) cv[4];
        for (int k = 0; k < 4; k++)
        {
          gp_Pnt s = ends[perm[p][k]][0], e = ends[perm[p][k]][1];
          if (flip & (1 << k))
            std::swap(s, e);
          segs[k] = {s, e};
          cv[k]   = bsp(s, e);
        }
        bool pred = arrangeSucceeds(segs, Precision::Confusion(), true);
        if (pred)
          predicateYes++;
        bool kern = false;
        try
        {
          GeomFill_BSplineCurves f(cv[0], cv[1], cv[2], cv[3], GeomFill_CurvedStyle);
          kern = !f.Surface().IsNull();
        }
        catch (...)
        {
          kern = false;
        }
        if (kern)
          kernelYes++;
        if (pred == kern)
          agree++;
        else
        {
          disagree++;
          if (disagree <= 5)
            printf("    DISAGREE perm=%d%d%d%d flip=%x predicate=%d kernel=%d\n", perm[p][0],
                   perm[p][1], perm[p][2], perm[p][3], flip, (int)pred, (int)kern);
        }
      }
    printf("    cases=%d agree=%d disagree=%d predicateYes=%d kernelYes=%d\n", np * 16, agree,
           disagree, predicateYes, kernelYes);
    printf("\n");
  }

  if (want("G"))
  {
    // Where exactly is the tolerance? Arrange compares Distance(...) < Precision::Confusion().
    printf("[G] tolerance boundary: a gap of g between the right edge and the top edge.\n");
    for (double g : {0.0, 5e-8, 9.9e-8, 2e-7, 1e-6})
    {
      gp_Pnt Cg(10, 10 + g, 0);
      Seg    segs[4] = {{A, B}, {B, Cg}, {C, D}, {D, A}};
      bool   pred    = arrangeSucceeds(segs, Precision::Confusion(), true);
      printf("    gap=%-8.3g predicate=%s", g, pred ? "JOINS    " : "NO-JOIN  ");
      fflush(stdout);
      if (!pred)
      {
        // Calling the kernel here is what sections C/D/E already recorded: a SIGSEGV.
        printf("  kernel=not called (C/D/E recorded the crash)\n");
        continue;
      }
      try
      {
        GeomFill_BSplineCurves f(bsp(A, B), bsp(B, Cg), bsp(C, D), bsp(D, A), GeomFill_CurvedStyle);
        printf("  kernel=%s\n", f.Surface().IsNull() ? "NULL surface" : "surface built");
      }
      catch (const Standard_Failure& e)
      {
        printf("  kernel THREW %s\n", e.ExceptionType());
      }
    }
    printf("\n");
  }

  if (want("H"))
  {
    // A triangular patch written as four sides with one side collapsed to a point. The BSpline
    // Arrange has a degenerate-curve pre-pass (GeomFill_BSplineCurves.cxx:77-91); the Bezier one
    // (GeomFill_BezierCurves.cxx:118) does not.
    printf("[H] one side degenerate (collapsed to the corner C).\n");
    Seg segs[4] = {{A, B}, {B, C}, {C, C}, {C, A}};
    printf("    predicate WITH degenerate pre-pass (BSpline flavour): %s\n",
           arrangeSucceeds(segs, Precision::Confusion(), true) ? "JOINS" : "NO-JOIN");
    Seg segs2[4] = {{A, B}, {B, C}, {C, C}, {C, A}};
    printf("    predicate WITHOUT it (Bezier flavour):                %s\n",
           arrangeSucceeds(segs2, Precision::Confusion(), false) ? "JOINS" : "NO-JOIN");
    fflush(stdout);
    try
    {
      GeomFill_BSplineCurves f(bsp(A, B), bsp(B, C), bsp(C, C), bsp(C, A), GeomFill_CurvedStyle);
      reportSurface("bspline, degenerate side", f.Surface());
    }
    catch (const Standard_Failure& e)
    {
      printf("    bspline THREW %s: %s\n", e.ExceptionType(),
             e.GetMessageString() ? e.GetMessageString() : "");
    }
    printf("    survived [H]\n\n");
    fflush(stdout);
  }

  if (want("I"))
  {
    // The TWO-curve Init is a different story: no Arrange, and its .curved branch refuses with a
    // real `throw Standard_OutOfRange` (GeomFill_BSplineCurves.cxx:545) rather than a Raise_if
    // macro, so No_Exception does not touch it and the bridge's catch (...) already sees it.
    printf("[I] two-curve Init, two PARALLEL curves that share no endpoint.\n");
    Handle(Geom_BSplineCurve) c1 = bsp(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    Handle(Geom_BSplineCurve) c2 = bsp(gp_Pnt(0, 10, 0), gp_Pnt(10, 10, 0));
    for (auto st : {GeomFill_StretchStyle, GeomFill_CoonsStyle, GeomFill_CurvedStyle})
    {
      const char* nm = st == GeomFill_StretchStyle  ? "stretch"
                       : st == GeomFill_CoonsStyle  ? "coons"
                                                    : "curved";
      fflush(stdout);
      try
      {
        GeomFill_BSplineCurves f(c1, c2, st);
        printf("    %-8s surface=%s\n", nm, f.Surface().IsNull() ? "NULL" : "built");
      }
      catch (const Standard_Failure& e)
      {
        printf("    %-8s THREW %s: %s\n", nm, e.ExceptionType(),
               e.GetMessageString() ? e.GetMessageString() : "");
      }
    }
    // ...and two that DO share an endpoint, which is what .curved wants.
    Handle(Geom_BSplineCurve) d1 = bsp(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    Handle(Geom_BSplineCurve) d2 = bsp(gp_Pnt(0, 0, 0), gp_Pnt(0, 10, 0));
    fflush(stdout);
    try
    {
      GeomFill_BSplineCurves f(d1, d2, GeomFill_CurvedStyle);
      printf("    curved, sharing a start point: surface=%s\n",
             f.Surface().IsNull() ? "NULL" : "built");
    }
    catch (const Standard_Failure& e)
    {
      printf("    curved, sharing a start point: THREW %s\n", e.ExceptionType());
    }
    printf("\n");
  }

  if (want("J"))
  {
    // The two claims the Swift doc snippets print, measured through the same calls they use.
    printf("[J] doc-snippet values.\n");
    // (a) Bezier flavour, scrambled order, Value(0, 0). Geom_BezierSurface is always 0..1 in both
    //     directions, which is what makes Surface.point(atU: 0, v: 0) the (u0, v0) corner.
    fflush(stdout);
    try
    {
      GeomFill_BezierCurves f(bez(A, B), bez(D, C), bez(A, D), bez(C, B), GeomFill_CoonsStyle);
      Handle(Geom_BezierSurface) s = f.Surface();
      if (s.IsNull())
      {
        printf("    bezier scrambled: NULL surface\n");
      }
      else
      {
        double u0, u1, v0, v1;
        s->Bounds(u0, u1, v0, v1);
        gp_Pnt p = s->Value(0, 0);
        printf("    bezier scrambled: bounds u=[%g,%g] v=[%g,%g] Value(0,0)=(%.4f,%.4f,%.4f)\n", u0,
               u1, v0, v1, p.X(), p.Y(), p.Z());
      }
    }
    catch (const Standard_Failure& e)
    {
      printf("    bezier scrambled THREW %s\n", e.ExceptionType());
    }
    // (b) BSpline flavour on the cylinder patch, scrambled: what its own domain is, so the doc
    //     snippet reads the corner off `domain` rather than assuming 0.
    gp_Pnt             P0(5, 0, 0), P1(0, 5, 0), P2(0, 5, 8), P3(5, 0, 8);
    double             m = 5 * 0.7071067811865476;
    GC_MakeArcOfCircle arc0(P0, gp_Pnt(m, m, 0), P1);
    GC_MakeArcOfCircle arc8(P3, gp_Pnt(m, m, 8), P2);
    fflush(stdout);
    if (arc0.IsDone() && arc8.IsDone())
    {
      try
      {
        GeomFill_BSplineCurves f(GeomConvert::CurveToBSplineCurve(arc0.Value()),
                                 GeomConvert::CurveToBSplineCurve(arc8.Value()),
                                 bsp(P3, P0),
                                 bsp(P1, P2),
                                 GeomFill_CurvedStyle);
        Handle(Geom_BSplineSurface) s = f.Surface();
        if (s.IsNull())
        {
          printf("    cylinder scrambled: NULL surface\n");
        }
        else
        {
          double u0, u1, v0, v1;
          s->Bounds(u0, u1, v0, v1);
          gp_Pnt at00 = s->Value(0, 0);
          gp_Pnt atMin = s->Value(u0, v0);
          printf("    cylinder scrambled: bounds u=[%g,%g] v=[%g,%g]\n", u0, u1, v0, v1);
          printf("      Value(0,0)      =(%.4f,%.4f,%.4f)\n", at00.X(), at00.Y(), at00.Z());
          printf("      Value(uMin,vMin)=(%.4f,%.4f,%.4f)\n", atMin.X(), atMin.Y(), atMin.Z());
        }
      }
      catch (const Standard_Failure& e)
      {
        printf("    cylinder scrambled THREW %s\n", e.ExceptionType());
      }
    }
    printf("\n");
  }

  printf("=== done ===\n");
  return 0;
}
