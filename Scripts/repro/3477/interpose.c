// #3477: log every malloc/calloc/realloc request >= 8 MiB with a backtrace.
// DYLD_INSERT_LIBRARIES=interpose.dylib ./probe <file>
#include <execinfo.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
static void big(const char* what, size_t n)
{
  if (n < (8u << 20))
    return;
  void* f[30];
  int   c = backtrace(f, 30);
  fprintf(stderr, "BIG %s %zu bytes\n", what, n);
  backtrace_symbols_fd(f, c, 2);
}
static void* my_malloc(size_t n)
{
  big("malloc", n);
  return malloc(n);
}
static void* my_calloc(size_t a, size_t b)
{
  big("calloc", a * b);
  return calloc(a, b);
}
static void* my_realloc(void* p, size_t n)
{
  big("realloc", n);
  return realloc(p, n);
}
#define INTERPOSE(n, o)                                                                           \
  __attribute__((used)) static struct                                                             \
  {                                                                                               \
    const void* a;                                                                                \
    const void* b;                                                                                \
  } _i_##o __attribute__((section("__DATA,__interpose"))) = {(const void*)(unsigned long)&n,       \
                                                              (const void*)(unsigned long)&o}
INTERPOSE(my_malloc, malloc);
INTERPOSE(my_calloc, calloc);
INTERPOSE(my_realloc, realloc);
