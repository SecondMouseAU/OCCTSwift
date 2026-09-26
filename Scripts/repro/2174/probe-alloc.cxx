// #2174: which runtime supplies operator new, and what an allocation failure does.
//
// #2171 left this explicitly unprobed: "under the wasm32 4 GB ceiling an OCCT allocation failure
// is a realistic path, and which of the two runtimes supplies operator new decides whether it
// throws or aborts". It is a separate executable from probe.cxx because the answer might be a
// trap, and a trap would take every other measurement in that program with it.
//
// Three outcomes, and the exit status says which:
//
//   0  operator new threw std::bad_alloc and the catch fired         (the C++ contract)
//   3  operator new returned, so the request was satisfied or nulled (no failure to observe)
//   -  the process aborts or traps, and nothing below prints         (the finding #2171 feared)
//
// The size is chosen against wasm32's ceiling: a single 3.5 GB request cannot be satisfied in a
// 32-bit linear memory whatever the allocator does, so a return is a statement about the
// allocator and not about how much memory the host had.

#include <cstdio>
#include <new>

int main()
{
  const unsigned long aHuge = 3500UL * 1024UL * 1024UL; // 3.5 GB, over wasm32's 4 GB ceiling

  std::printf("requesting %lu bytes with operator new[]...\n", aHuge);
  std::fflush(stdout);

  char* aBlock = nullptr;
  try
  {
    aBlock = new char[aHuge];
  }
  catch (const std::bad_alloc& theError)
  {
    std::printf("caught std::bad_alloc: %s\n", theError.what());
    return 0;
  }
  catch (...)
  {
    std::printf("caught something that is not std::bad_alloc\n");
    return 4;
  }

  std::printf("operator new[] returned %p without throwing\n", (void*)aBlock);
  // A nothrow-shaped allocator returns null instead of throwing; say which happened.
  std::printf("%s\n", aBlock == nullptr ? "it returned null" : "it returned a real block");
  delete[] aBlock;
  return 3;
}
