#include "include/StubSjLj.h"

#include <setjmp.h>

static jmp_buf gStubJmp;

static void stubLongJump(void)
{
  longjmp(gStubJmp, 7);
}

int stubSjLjRoundTrip(void)
{
  const int aStatus = setjmp(gStubJmp);
  if (aStatus == 0)
  {
    stubLongJump();
    return -1;
  }
  return aStatus;
}
