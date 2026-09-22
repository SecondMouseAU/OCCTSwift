// The same program twice, differing only in how it reports a failure, so the difference in the two
// modules is the cost of keeping the exception contract and nothing else.
//
//   default build          : throws, catches, needs the exception flags and the eh runtime
//   -DPROBE_NO_EXCEPTIONS  : returns a sentinel, built -fno-exceptions
//
// No Swift here on purpose. A Swift executable's runtime is several megabytes and would bury the
// number being measured.
#include <cstdio>
#include <numeric>
#include <string>
#include <vector>

#ifndef PROBE_NO_EXCEPTIONS
#include <stdexcept>
#endif

namespace
{

double sum(const double *theValues, int theCount)
{
  if (theCount < 0 || theValues == nullptr)
  {
#ifdef PROBE_NO_EXCEPTIONS
    return -1.0;
#else
    throw std::runtime_error("size probe: negative count");
#endif
  }
  std::vector<double> aCollected(theValues, theValues + theCount);
  std::string         aTag = "sum";
  return std::accumulate(aCollected.begin(), aCollected.end(), 0.0) + (aTag.size() - 3);
}

} // namespace

int main()
{
  const double aValues[] = {1.5, 2.25, 3.0};
  std::printf("compute: %f\n", sum(aValues, 3));

#ifdef PROBE_NO_EXCEPTIONS
  std::printf("failure: %f\n", sum(nullptr, -1));
#else
  try
  {
    sum(nullptr, -1);
  }
  catch (const std::exception &e)
  {
    std::printf("failure: %d\n", -static_cast<int>(std::string(e.what()).size()));
  }
#endif
  return 0;
}
