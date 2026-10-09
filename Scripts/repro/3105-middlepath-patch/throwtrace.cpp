#include <cstdio>
#include <typeinfo>
#include <execinfo.h>
extern "C" void __cxa_throw(void*, std::type_info*, void (*)(void*));
static void tt(void* e, std::type_info* t, void (*d)(void*)) {
  void* fr[40]; int n = backtrace(fr, 40); fprintf(stderr, "THROW %s\n", t->name()); backtrace_symbols_fd(fr, n, 2);
  __cxa_throw(e, t, d);
}
__attribute__((used)) static struct { const void* r; const void* o; } ip[] __attribute__((section("__DATA,__interpose"))) = {{(const void*)tt, (const void*)__cxa_throw}};
