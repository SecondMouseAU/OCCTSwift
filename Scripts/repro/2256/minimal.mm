// #2256: the whole crash, in nine lines.
//
// Not one character of Objective-C is in this file. The extension is the only thing that makes
// clang compile it as Objective-C++, and that alone is enough: a plain C++ try/catch in an
// Objective-C++ translation unit crashes the WebAssembly backend under -fwasm-exceptions.
//
// Compile it as C++ (rename it, or pass -x c++) and it is fine. See README.md.
#include <stdexcept>

extern "C" int probe(int x)
{
  try
  {
    if (x < 0)
      throw std::runtime_error("neg");
    return x * 2;
  }
  catch (...)
  {
    return -1;
  }
}
