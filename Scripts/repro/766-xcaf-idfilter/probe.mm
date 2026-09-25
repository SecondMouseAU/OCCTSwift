// Kernel-parity probe for #766 (OCCTXCAFTests). Calls the OCCT API the bridge calls, with the
// test's inputs, and prints what the kernel returns. Build line: CLAUDE.md "Compile a Ground
// Truth C++ Test", headers/lib from the pinned OCCT.xcframework.
#include <Standard_GUID.hxx>
#include <TDF_IDFilter.hxx>
#include <cstdio>

static const char* tf(bool b) { return b ? "true" : "false"; }

// IDFilterTests: TDF_IDFilter(ignoreAll), Keep / Ignore / IsKept / IsIgnored / IgnoreAll.
int main()
{
  const Standard_GUID g("2a96b606-ec8b-11d0-bee7-080009dc3333");
  TDF_IDFilter        ignoreAll(true);
  printf("TDF_IDFilter(true).IgnoreAll=%s\n", tf(ignoreAll.IgnoreAll()));
  TDF_IDFilter keepAll(false);
  printf("TDF_IDFilter(false).IgnoreAll=%s\n", tf(keepAll.IgnoreAll()));
  TDF_IDFilter k(true);
  k.Keep(g);
  printf("ignore-all filter, Keep(g): IsKept=%s\n", tf(k.IsKept(g)));
  TDF_IDFilter i(false);
  i.Ignore(g);
  printf("keep-all filter, Ignore(g): IsIgnored=%s\n", tf(i.IsIgnored(g)));
  TDF_IDFilter t(true);
  t.IgnoreAll(false);
  printf("IgnoreAll(false) on an ignore-all filter: IgnoreAll=%s\n", tf(t.IgnoreAll()));
  return 0;
}
