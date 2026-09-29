// #2801: what one <Exception>_Raise_if costs, measured on the checks that ARE compiled in.
//
// The kernel's out-of-line checks cannot be timed without rebuilding it, which is ~65 minutes per
// configuration times three slices. The inline ones can, because the bridge's own translation unit
// is where they are expanded, and -DNo_Exception removes them from exactly the same source. That is
// the same macro, the same condition shape and the same compiler, so it bounds the per-check cost
// even though it is not a measurement of libOCCT.
//
// Read it as: this is what BUILD_RELEASE_DISABLE_EXCEPTIONS is buying per check, not how many
// checks a real workload executes. The second number is the one this cannot supply.
//
// Build both ways via run-bench.sh.

#include <gp_Dir.hxx>
#include <gp_Vec.hxx>
#include <gp_XYZ.hxx>

#include <chrono>
#include <cstdio>

// The quantity being resolved is one `_Raise_if`, and it came out at about a tenth of a nanosecond:
// 1.70 vs 1.57 ns/op for `gp_Dir(x, y, z)`. So the iteration count is not arbitrary and is not a
// warm-up figure. At 1.6 ns/op these 40 million iterations are about 64 ms per bench, which puts the
// difference being read at roughly 5 ms, comfortably above the steady_clock noise on a loaded
// machine, and run-bench.sh interleaves three runs of each configuration on top of that. Drop it by
// an order of magnitude and the difference is inside the noise; the reported numbers would still
// print, which is the trap.
static const long long ITERATIONS = 40000000;

template <class F>
static double time_ns(const char* name, F body)
{
  auto start = std::chrono::steady_clock::now();
  double sink = body();
  auto  end   = std::chrono::steady_clock::now();
  double ns =
    std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count() / double(ITERATIONS);
  printf("  %-42s %7.3f ns/op   (sink %.3f)\n", name, ns, sink);
  return ns;
}

int main()
{
#ifdef No_Exception
  printf("bench WITH -DNo_Exception (the checks are gone)\n");
#else
  printf("bench WITHOUT -DNo_Exception (the checks are compiled in)\n");
#endif

  // gp_Dir's constructor: Standard_ConstructionError_Raise_if on the square magnitude against
  // gp::Resolution() squared, then a divide by the modulus. One of the cheapest possible bodies to
  // add a branch to, which is why it is the right place to bound the cost.
  time_ns("gp_Dir(x, y, z) constructor", [] {
    double sink = 0.0;
    for (long long i = 1; i <= ITERATIONS; i++)
    {
      gp_Dir d(double(i), 1.0, 2.0);
      sink += d.X();
    }
    return sink;
  });

  // gp_Dir::Coord(i): Standard_OutOfRange_Raise_if on an index. This is the shape of the 48
  // out-of-line Standard_OutOfRange checks, which are the ones a hot loop would meet.
  time_ns("gp_Dir::Coord(index)", [] {
    gp_Dir d(1.0, 2.0, 3.0);
    double sink = 0.0;
    for (long long i = 1; i <= ITERATIONS; i++)
    {
      sink += d.Coord(int(i % 3) + 1);
    }
    return sink;
  });

  // gp_Vec::Normalized(): the same check on a different body, via a temporary.
  time_ns("gp_Vec::Normalized()", [] {
    double sink = 0.0;
    for (long long i = 1; i <= ITERATIONS; i++)
    {
      gp_Vec v(double(i), 1.0, 2.0);
      sink += v.Normalized().X();
    }
    return sink;
  });

  return 0;
}
