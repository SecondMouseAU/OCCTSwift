#include "include/ProbeSetjmp.h"

#include <setjmp.h>

static jmp_buf theBuffer;

static void jump_back(void)
{
  longjmp(theBuffer, 7);
}

int probe_setjmp_roundtrip(void)
{
  const int aValue = setjmp(theBuffer);
  if (aValue == 0)
  {
    jump_back();
    return 0; // unreachable if longjmp works
  }
  return aValue;
}
