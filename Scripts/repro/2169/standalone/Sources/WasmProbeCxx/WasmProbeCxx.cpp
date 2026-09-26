#include "include/WasmProbeCxx.h"

#include <cstring>
#include <numeric>
#include <stdexcept>
#include <string>
#include <vector>

extern "C" double wasm_probe_sum(const double *values, int count)
{
  try
  {
    if (count < 0 || values == nullptr)
    {
      throw std::runtime_error("wasm probe: negative count");
    }
    // std::vector and std::string exercise the libc++ allocator, not just arithmetic.
    std::vector<double> collected(values, values + count);
    std::string         tag = "sum";
    return std::accumulate(collected.begin(), collected.end(), 0.0) + (tag.size() - 3);
  }
  catch (const std::exception &e)
  {
    // Returning the message length proves the exception object crossed the unwinder intact.
    return -static_cast<double>(std::strlen(e.what()));
  }
}
