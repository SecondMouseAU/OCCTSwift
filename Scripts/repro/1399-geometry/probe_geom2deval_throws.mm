// #1399, geometry family: do the Geom2dEval_* curve constructors throw on ordinary caller
// arguments, and would that throw escape the bridge?
//
// The ten Geom2dEval_* D0/D1 bridge entry points in OCCTBridge_Geom2d_Curves.mm construct their
// curve and evaluate it with no try/catch, unlike every GeomEval_* (3D) sibling and every
// *Create function, which all have one. If the constructors throw on plain argument values, a
// Swift caller passing one gets an uncatchable process abort (CLAUDE.md, #345: OCC_CATCH_SIGNALS
// is inert in this build and a C++ exception reaching the Swift boundary is uncatchable).
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1399-geometry/probe_geom2deval_throws.mm -o /tmp/occt_probe_1399
//   /tmp/occt_probe_1399

#include <Geom2dEval_ArchimedeanSpiralCurve.hxx>
#include <Geom2dEval_CircleInvoluteCurve.hxx>
#include <Geom2dEval_LogarithmicSpiralCurve.hxx>
#include <Geom2dEval_SineWaveCurve.hxx>
#include <Standard_Failure.hxx>
#include <gp_Ax2d.hxx>

#include <cstdio>

static const gp_Ax2d AX(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));

template <typename Fn>
static void probe(const char* label, Fn build)
{
  try
  {
    build();
    printf("  %-58s constructed, no throw\n", label);
  }
  catch (const Standard_Failure& e)
  {
    printf("  %-58s THREW Standard_Failure: %s\n", label,
           e.GetMessageString() ? e.GetMessageString() : "(no message)");
  }
  catch (...)
  {
    printf("  %-58s THREW (non-Standard_Failure)\n", label);
  }
}

int main()
{
  printf("Geom2dEval_* constructors on arguments a Swift caller can pass:\n");

  probe("SineWaveCurve(amplitude=1, omega=1, phase=0)",
        [] { Geom2dEval_SineWaveCurve c(AX, 1.0, 1.0, 0.0); });
  probe("SineWaveCurve(amplitude=0, omega=1, phase=0)",
        [] { Geom2dEval_SineWaveCurve c(AX, 0.0, 1.0, 0.0); });
  probe("SineWaveCurve(amplitude=1, omega=0, phase=0)",
        [] { Geom2dEval_SineWaveCurve c(AX, 1.0, 0.0, 0.0); });

  probe("CircleInvoluteCurve(radius=5)", [] { Geom2dEval_CircleInvoluteCurve c(AX, 5.0); });
  probe("CircleInvoluteCurve(radius=0)", [] { Geom2dEval_CircleInvoluteCurve c(AX, 0.0); });

  probe("ArchimedeanSpiralCurve(initialRadius=1, growthRate=0.1)",
        [] { Geom2dEval_ArchimedeanSpiralCurve c(AX, 1.0, 0.1); });
  probe("ArchimedeanSpiralCurve(initialRadius=1, growthRate=0)",
        [] { Geom2dEval_ArchimedeanSpiralCurve c(AX, 1.0, 0.0); });
  probe("ArchimedeanSpiralCurve(initialRadius=-1, growthRate=0.1)",
        [] { Geom2dEval_ArchimedeanSpiralCurve c(AX, -1.0, 0.1); });

  probe("LogarithmicSpiralCurve(scale=1, growthExponent=0.2)",
        [] { Geom2dEval_LogarithmicSpiralCurve c(AX, 1.0, 0.2); });
  probe("LogarithmicSpiralCurve(scale=0, growthExponent=0.2)",
        [] { Geom2dEval_LogarithmicSpiralCurve c(AX, 0.0, 0.2); });
  probe("LogarithmicSpiralCurve(scale=1, growthExponent=0)",
        [] { Geom2dEval_LogarithmicSpiralCurve c(AX, 1.0, 0.0); });

  printf("\nAny THREW line above is a value the bridge's untried Geom2dEval_* D0/D1 entry points\n"
         "let escape to the Swift boundary.\n");
  return 0;
}
