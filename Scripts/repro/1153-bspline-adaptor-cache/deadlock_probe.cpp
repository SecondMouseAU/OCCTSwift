// #1153 finding 1: single-threaded proof that the original PR's non-recursive std::mutex
// self-deadlocks the moment any derivative-family method is called, because e.g. D1() locks
// myMutex and then calls D1Local(), which locks the *same* non-recursive mutex again on the
// same thread. No concurrency needed to observe this: one thread, one call, is enough.
//
// Build against the ORIGINAL (broken) PR content: hangs forever on D1 (never returns).
// Build against the real fix (recursive_mutex): D0/D1/D2/D3 all return immediately.
//
// Run under `timeout` since a genuine deadlock never exits on its own.

#include <cstdio>
#include <NCollection_Array1.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include <BSplCLib_Cache.hxx>

int main()
{
  NCollection_Array1<gp_Pnt> aPoles(1, 4);
  aPoles(1) = gp_Pnt(0, 0, 0);
  aPoles(2) = gp_Pnt(1, 2, 0);
  aPoles(3) = gp_Pnt(2, 2, 0);
  aPoles(4) = gp_Pnt(3, 0, 0);

  NCollection_Array1<double> aFlatKnots(1, 8);
  for (int i = 1; i <= 4; ++i)
  {
    aFlatKnots(i)     = 0.0;
    aFlatKnots(i + 4) = 1.0;
  }

  occ::handle<BSplCLib_Cache> aCache = new BSplCLib_Cache(3, false, aFlatKnots, aPoles, nullptr);
  aCache->BuildCache(0.5, aFlatKnots, aPoles, nullptr);
  fprintf(stderr, "BuildCache returned\n");
  fflush(stderr);

  gp_Pnt aPoint;
  gp_Vec aTangent;
  fprintf(stderr, "calling D1 (this is where the original PR content hangs forever)...\n");
  fflush(stderr);
  aCache->D1(0.5, aPoint, aTangent);
  fprintf(stderr, "D1 returned: point=(%f,%f,%f) tangent=(%f,%f,%f)\n",
          aPoint.X(), aPoint.Y(), aPoint.Z(), aTangent.X(), aTangent.Y(), aTangent.Z());
  return 0;
}
