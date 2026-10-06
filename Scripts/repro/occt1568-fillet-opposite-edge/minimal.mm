// Minimal corroboration for OCCT #1568's mechanism: a Geom2dAdaptor_Curve that holds no curve
// reports GeomAbs_OtherCurve, so every evaluator falls to the switch's default arm and
// dereferences the null Handle(Geom2d_Curve) without a check.
#include <execinfo.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

#include <Geom2dAdaptor_Curve.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>

static void onFatalSignal(int theSig)
{
  fprintf(stderr, "\n*** SIGNAL %d in the minimal case ***\n", theSig);
  void* aFrames[16];
  int   aCount = backtrace(aFrames, 16);
  backtrace_symbols_fd(aFrames, aCount, STDERR_FILENO);
  _exit(128 + theSig);
}

int main()
{
  signal(SIGSEGV, onFatalSignal);
  signal(SIGBUS, onFatalSignal);

  Geom2dAdaptor_Curve anAdaptor;  // never loaded
  printf("GetType()      = %d (GeomAbs_OtherCurve = %d)\n", (int)anAdaptor.GetType(), (int)GeomAbs_OtherCurve);
  printf("Curve().IsNull = %s\n", anAdaptor.Curve().IsNull() ? "true" : "false");
  fflush(stdout);

  gp_Pnt2d aP;
  gp_Vec2d aV;
  printf("calling D1(0.5) on it\n");
  fflush(stdout);
  anAdaptor.D1(0.5, aP, aV);

  printf("returned without a signal\n");
  return 0;
}
