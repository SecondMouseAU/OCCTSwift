// Epic #766 kernel-parity probe for Tests/OCCTMathTests/Issue1443Ax3EmptyCatchTests.swift.
// Each test feeds OCCTAx3Create / CreateFromNormal / MirrorPoint / Rotate / Translate an input
// the kernel refuses. The parity question is whether the kernel really raises there (so the
// bridge's catch, and its fallback, is what the test observes), and with which exception.
#include <Standard_Failure.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax3.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include <cstdio>
#include <functional>

static void attempt(const char* name, const std::function<void()>& f)
{
  try
  {
    f();
    printf("%s: no exception\n", name);
  }
  catch (const Standard_Failure& e)
  {
    printf("%s: raised %s (%s)\n", name, typeid(e).name(), e.what());
  }
  catch (...)
  {
    printf("%s: raised non-Standard_Failure exception\n", name);
  }
}

int main()
{
  attempt("createParallelDirectionOverwritesSentinel",
          [] { gp_Ax3 a(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(0, 0, 1)); });
  attempt("createFromNormalZeroNormalOverwritesSentinel",
          [] { gp_Ax3 a(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 0)); });
  attempt("mirrorPointDegenerateSourceOverwritesSentinel", [] {
    gp_Ax3 a(gp_Pnt(5, 3, 2), gp_Dir(0, 0, 1), gp_Dir(0, 0, 1));
    a.Mirrored(gp_Pnt(1, 1, 1));
  });
  attempt("rotateZeroAxisDirectionOverwritesSentinel (input axis alone)",
          [] { gp_Ax3 a(gp_Pnt(5, 3, 2), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)); });
  attempt("rotateZeroAxisDirectionOverwritesSentinel (rotation axis)", [] {
    gp_Ax3 a(gp_Pnt(5, 3, 2), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    a.Rotated(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 0)), M_PI / 2);
  });
  attempt("translateDegenerateSourceOverwritesSentinel", [] {
    gp_Ax3 a(gp_Pnt(5, 3, 2), gp_Dir(0, 0, 1), gp_Dir(0, 0, 1));
    a.Translated(gp_Vec(1, 2, 3));
  });
  return 0;
}
