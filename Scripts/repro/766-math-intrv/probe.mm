// Epic #766 kernel-parity probe for Tests/OCCTMathTests/IntrvIntervalsTests.swift and
// IntrvIntervalTests.swift. Same Intrv_Intervals / Intrv_Interval calls and inputs as the
// OCCTIntrvIntervals* and OCCTIntrvInterval* bridge functions (tolerances default to 0).
#include <Intrv_Interval.hxx>
#include <Intrv_Intervals.hxx>
#include <cstdio>

static void dump(const char* n, const Intrv_Intervals& s)
{
  printf("%s: count=%d", n, s.NbIntervals());
  for (int i = 1; i <= s.NbIntervals(); i++)
  {
    double a, b;
    float  ta, tb;
    s.Value(i).Bounds(a, ta, b, tb);
    printf(" [%.10g, %.10g]", a, b);
  }
  printf("\n");
}

static void bounds(const char* n, const Intrv_Interval& iv)
{
  double a, b;
  float  ta, tb;
  iv.Bounds(a, ta, b, tb);
  printf("%s: start=%.10g tolStart=%.10g end=%.10g tolEnd=%.10g\n", n, a, ta, b, tb);
}

int main()
{
  dump("createSingle", Intrv_Intervals(Intrv_Interval(1, 5)));
  dump("createEmpty", Intrv_Intervals());
  {
    Intrv_Intervals s(Intrv_Interval(1, 3));
    s.Unite(Intrv_Interval(5, 8));
    dump("uniteNonOverlapping", s);
  }
  {
    Intrv_Intervals s(Intrv_Interval(1, 5));
    s.Unite(Intrv_Interval(3, 8));
    dump("uniteOverlapping", s);
  }
  {
    Intrv_Intervals s(Intrv_Interval(0, 10));
    s.Subtract(Intrv_Interval(3, 7));
    dump("subtractMiddle", s);
  }
  {
    Intrv_Intervals s(Intrv_Interval(0, 10));
    s.Intersect(Intrv_Interval(3, 7));
    dump("intersect", s);
  }
  {
    Intrv_Intervals s(Intrv_Interval(0, 5));
    s.XUnite(Intrv_Interval(3, 8));
    dump("xUnite", s);
  }

  bounds("createAndBounds", Intrv_Interval(1.0, 0.0f, 5.0, 0.0f));
  bounds("createWithTolerances", Intrv_Interval(1.0, 0.01f, 5.0, 0.02f));
  printf("probablyEmpty: big=%d empty=%d\n",
         Intrv_Interval(0, 0.0f, 10, 0.0f).IsProbablyEmpty() ? 1 : 0,
         Intrv_Interval(5, 1.0f, 5, 1.0f).IsProbablyEmpty() ? 1 : 0);
  {
    Intrv_Interval a(1, 0.0f, 3, 0.0f), b(5, 0.0f, 8, 0.0f);
    printf("beforeAfter: a.IsBefore(b)=%d b.IsAfter(a)=%d\n", a.IsBefore(b) ? 1 : 0, b.IsAfter(a) ? 1 : 0);
    printf("position: a.Position(b)=%d (Intrv_Before=%d) b.Position(a)=%d\n",
           (int)a.Position(b), (int)Intrv_Before, (int)b.Position(a));
  }
  {
    Intrv_Interval outer(0, 0.0f, 10, 0.0f), inner(2, 0.0f, 8, 0.0f);
    printf("insideEnclosing: inner.IsInside(outer)=%d outer.IsEnclosing(inner)=%d\n",
           inner.IsInside(outer) ? 1 : 0, outer.IsEnclosing(inner) ? 1 : 0);
  }
  printf("similar: %d\n",
         Intrv_Interval(0, 0.0f, 10, 0.0f).IsSimilar(Intrv_Interval(0, 0.0f, 10, 0.0f)) ? 1 : 0);
  {
    Intrv_Interval iv(0, 0.0f, 10, 0.0f);
    iv.SetStart(2, 0.0f);
    iv.SetEnd(8, 0.0f);
    bounds("modifyBounds", iv);
  }
  {
    Intrv_Interval iv(3, 0.0f, 7, 0.0f);
    iv.FuseAtStart(1, 0.0f);
    bounds("fuseCut after FuseAtStart(1)", iv);
    iv.FuseAtEnd(9, 0.0f);
    bounds("fuseCut after FuseAtEnd(9)", iv);
    iv.CutAtStart(2, 0.0f);
    bounds("fuseCut after CutAtStart(2)", iv);
    iv.CutAtEnd(8, 0.0f);
    bounds("fuseCut after CutAtEnd(8)", iv);
  }
  return 0;
}
