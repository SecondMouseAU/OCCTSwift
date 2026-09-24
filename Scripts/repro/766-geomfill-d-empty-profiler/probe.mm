// Epic #766 finding while proving GeomFillProfilerTests' #710 regression test red: with its
// AddCurve suppressed, CurveProfiler.perform() on a profiler holding no curves killed the test
// process. This asks the kernel the same question with no bridge involved: GeomFill_Profiler
// default-constructed, then Perform(1e-6) (the Swift default tolerance), then Degree().
#include <GeomFill_Profiler.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>

int main()
{
  GeomFill_Profiler p;
  printf("before Perform on an empty GeomFill_Profiler\n");
  fflush(stdout);
  try
  {
    p.Perform(1e-6);
    printf("Perform returned; Degree=%d NbPoles=%d\n", p.Degree(), p.NbPoles());
  }
  catch (Standard_Failure& e)
  {
    printf("threw %s\n", e.GetMessageString());
  }
  return 0;
}
