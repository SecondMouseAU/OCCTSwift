// Kernel-parity probe for Tests/OCCTAnalysisTests/BndRangeTests.swift (#1837-#1842).
// Drives Bnd_Range through the same calls, with the same inputs, that the OCCTRange* bridge
// functions make for each test, and prints every value the tests read.
#include <Bnd_Range.hxx>
#include <cstdio>

static void bounds(const char* tag, const Bnd_Range& r)
{
  double f = 0, l = 0;
  bool   ok = r.GetBounds(f, l);
  printf("%s: GetBounds=%d first=%.17g last=%.17g IsVoid=%d Delta=%.17g\n",
         tag, ok, f, l, r.IsVoid(), r.Delta());
}

int main()
{
  // createAndQuery
  Bnd_Range r1(1.0, 5.0);
  bounds("createAndQuery Bnd_Range(1,5)", r1);

  // contains
  printf("contains: Contains(3)=%d Contains(6)=%d\n", r1.Contains(3.0), r1.Contains(6.0));

  // addValue
  Bnd_Range r2(2.0, 4.0);
  r2.Add(6.0);
  bounds("addValue Bnd_Range(2,4).Add(6)", r2);

  // common
  Bnd_Range a(1.0, 5.0), b(3.0, 7.0);
  a.Common(b);
  bounds("common Bnd_Range(1,5).Common(Bnd_Range(3,7))", a);

  // trimFromTo
  Bnd_Range t(0.0, 10.0);
  t.TrimFrom(3.0);
  t.TrimTo(7.0);
  bounds("trimFromTo Bnd_Range(0,10).TrimFrom(3).TrimTo(7)", t);

  // voidRange
  Bnd_Range v;
  bounds("voidRange Bnd_Range()", v);
  return 0;
}
