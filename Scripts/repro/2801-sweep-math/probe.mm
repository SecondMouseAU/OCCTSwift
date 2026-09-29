// #2801 sweep, dimension/squareness cluster.
//
// Compiled exactly as SwiftPM compiles Sources/OCCTBridge/src/*.mm: no -DNo_Exception, so every
// _Raise_if this translation unit EXPANDS is live. The kernel we link was built Release with
// -DNo_Exception, so every _Raise_if that sits in an OCCT .cxx/.pxx is absent from the binary.
// Each mode reproduces one bridge-reachable call whose only documented guard is such a check.
//
// Usage: probe <mode>. One mode per process; the exit code is the result.

#include <math_Matrix.hxx>
#include <math_Vector.hxx>
#include <math_Gauss.hxx>
#include <math_Uzawa.hxx>
#include <gp_Trsf.hxx>
#include <gp_Pnt.hxx>
#include <Standard_Failure.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <GProp_GProps.hxx>
#include <BRepGProp.hxx>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <typeinfo>

static void banner(const char* m)
{
  std::printf("[mode %s]\n", m);
  std::fflush(stdout);
}

int main(int argc, char** argv)
{
  const char* mode = argc > 1 ? argv[1] : "";
  banner(mode);

  // ---- 1. MathMatrix(rows:100, cols:1).invert()
  // OCCTMathMatrixInvert -> math_Matrix::Invert(). math_Matrix.cxx:187's math_NotSquare_Raise_if
  // is compiled out, so a 100x1 matrix reaches math_Gauss's ctor, which indexes LU(i,j) for
  // j in 1..RowNumber() inside math_Recipes.cxx.
  if (!std::strcmp(mode, "invert-nonsquare"))
  {
    try
    {
      math_Matrix A(1, 100, 1, 1, 1.0);
      std::printf("built %dx%d\n", A.RowNumber(), A.ColNumber());
      std::fflush(stdout);
      A.Invert();
      std::printf("Invert() returned normally; A(1,1)=%g\n", A.Value(1, 1));
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    catch (...)
    {
      std::printf("caught unknown\n");
      return 4;
    }
    return 0;
  }

  // ---- 2. MathMatrix(rows:100, cols:1).determinant
  // math_Matrix::Determinant() has no guard at all, not even a compiled-out one, and reaches the
  // same math_Gauss ctor.
  if (!std::strcmp(mode, "determinant-nonsquare"))
  {
    try
    {
      math_Matrix A(1, 100, 1, 1, 1.0);
      std::printf("built %dx%d\n", A.RowNumber(), A.ColNumber());
      std::fflush(stdout);
      const double d = A.Determinant();
      std::printf("Determinant() returned %g\n", d);
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  // ---- 2b. the same at 3x2, small enough to sit in math_DoubleTab's 64-element inline buffer.
  if (!std::strcmp(mode, "determinant-nonsquare-small"))
  {
    try
    {
      math_Matrix A(1, 3, 1, 2, 1.0);
      const double d = A.Determinant();
      std::printf("3x2 Determinant() returned %g\n", d);
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  // ---- 3. MathMatrix(rows:3, cols:2).transpose()
  // math_Matrix::Transpose()'s math_NotSquare_Raise_if is in math_Matrix.lxx, so it is LIVE here,
  // in the bridge's own unit. OCCTMathMatrixTranspose has no try, so it reaches Swift uncaught.
  if (!std::strcmp(mode, "transpose-nonsquare"))
  {
    try
    {
      math_Matrix A(1, 3, 1, 2, 1.0);
      A.Transpose();
      std::printf("Transpose() returned normally\n");
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  // ---- 3b. the same throw with no catch, which is what OCCTMathMatrixTranspose does.
  if (!std::strcmp(mode, "transpose-nonsquare-uncaught"))
  {
    math_Matrix A(1, 3, 1, 2, 1.0);
    A.Transpose();
    std::printf("Transpose() returned normally\n");
    return 0;
  }

  // ---- 4. MathMatrix.value(row:9, col:9) on a 3x3.
  // math_Matrix::Value is inline, so NCollection_Array1::at's Standard_OutOfRange_Raise_if is
  // live here. OCCTMathMatrixGetValue has no try.
  if (!std::strcmp(mode, "index-oob-uncaught"))
  {
    math_Matrix A(1, 3, 1, 3, 1.0);
    const double v = A.Value(9, 9);
    std::printf("A(9,9) = %g\n", v);
    return 0;
  }

  // ---- 5. MathMatrix(rows:0, cols:0): does the ctor refuse it, and does it throw here?
  if (!std::strcmp(mode, "zero-dims"))
  {
    try
    {
      math_Matrix A(1, 0, 1, 0, 0.0);
      std::printf("built %dx%d\n", A.RowNumber(), A.ColNumber());
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  // ---- 6. MathSolver.uzawa(nConstraints: 100, nVars: 40, ...)
  // The 6-argument math_Uzawa ctor sizes Errinit to Cont.ColNumber() and Perform then writes
  // Errinit(i) for i in 1..Cont.RowNumber(). math_Uzawa.cxx both is compiled with No_Exception
  // and #defines No_Standard_OutOfRange itself, so nothing checks the index.
  if (!std::strcmp(mode, "uzawa-overdetermined"))
  {
    try
    {
      const int nc = 100, nv = 40;
      math_Matrix Cont(1, nc, 1, nv, 0.0);
      for (int i = 1; i <= nc; i++)
        for (int j = 1; j <= nv; j++)
          Cont(i, j) = (i == j) ? 1.0 : 0.25;
      math_Vector Sec(1, nc, 1.0);
      math_Vector Start(1, nv, 0.0);
      std::printf("Cont %dx%d, Errinit will be sized %d and written to %d\n",
                  nc, nv, nv, nc);
      std::fflush(stdout);
      math_Uzawa u(Cont, Sec, Start, 1.0e-6, 1.0e-6, 500);
      std::printf("ctor returned; IsDone=%d\n", (int)u.IsDone());
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  // ---- 6b. the same, small enough to sit in math_VectorBase's 32-element inline buffer.
  if (!std::strcmp(mode, "uzawa-overdetermined-small"))
  {
    try
    {
      const int nc = 4, nv = 2;
      math_Matrix Cont(1, nc, 1, nv, 0.0);
      for (int i = 1; i <= nc; i++)
        for (int j = 1; j <= nv; j++)
          Cont(i, j) = (i == j) ? 1.0 : 0.25;
      math_Vector Sec(1, nc, 1.0);
      math_Vector Start(1, nv, 0.0);
      math_Uzawa u(Cont, Sec, Start, 1.0e-6, 1.0e-6, 500);
      std::printf("4x2 ctor returned; IsDone=%d\n", (int)u.IsDone());
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  // ---- 6c. nVars small enough for math_VectorBase's inline buffer but far fewer than
  // nConstraints: Errinit's 68 out-of-range writes then run off the end of the inline
  // std::array that lives INSIDE the math_Uzawa object, which the bridge holds on the stack.
  if (!std::strcmp(mode, "uzawa-few-vars"))
  {
    try
    {
      const int nc = 100, nv = 2;
      math_Matrix Cont(1, nc, 1, nv, 0.0);
      for (int i = 1; i <= nc; i++)
        for (int j = 1; j <= nv; j++)
          Cont(i, j) = (i == j) ? 1.0 : 0.25;
      math_Vector Sec(1, nc, 1.0);
      math_Vector Start(1, nv, 0.0);
      std::printf("Cont %dx%d, Errinit sized %d written to %d\n", nc, nv, nv, nc);
      std::fflush(stdout);
      math_Uzawa u(Cont, Sec, Start, 1.0e-6, 1.0e-6, 500);
      std::printf("ctor returned; IsDone=%d\n", (int)u.IsDone());
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  // ---- 7. Shape.trsfModification(all-zero 3x3): gp_Trsf::SetValues with a null determinant.
  if (!std::strcmp(mode, "trsf-setvalues-singular"))
  {
    try
    {
      gp_Trsf t;
      t.SetValues(0, 0, 0, 5, 0, 0, 0, 6, 0, 0, 0, 7);
      std::printf("SetValues returned; ScaleFactor=%g Value(1,1)=%g Value(2,2)=%g "
                  "Value(1,4)=%g isnan(1,1)=%d\n",
                  t.ScaleFactor(), t.Value(1, 1), t.Value(2, 2), t.Value(1, 4),
                  (int)std::isnan(t.Value(1, 1)));
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  // ---- 7b. a rank-2 (two identical rows) 3x3, the more realistic singular input.
  if (!std::strcmp(mode, "trsf-setvalues-rank2"))
  {
    try
    {
      gp_Trsf t;
      t.SetValues(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0);
      std::printf("SetValues returned; ScaleFactor=%g Value(1,1)=%g Value(3,3)=%g\n",
                  t.ScaleFactor(), t.Value(1, 1), t.Value(3, 3));
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  // ---- 8. Shape.scaledAboutPoint(factor: 0): gp_Trsf::SetScale with a null factor,
  // then gp_Trsf::Invert on the zero-scale transform.
  if (!std::strcmp(mode, "trsf-setscale-zero"))
  {
    try
    {
      gp_Trsf t;
      t.SetScale(gp_Pnt(0, 0, 0), 0.0);
      std::printf("SetScale(0) returned; ScaleFactor=%g\n", t.ScaleFactor());
      std::fflush(stdout);
      t.Invert();
      std::printf("Invert() returned; ScaleFactor=%g isinf=%d\n",
                  t.ScaleFactor(), (int)std::isinf(t.ScaleFactor()));
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  // ---- 8b. the same zero scale applied to a real solid, which is what the bridge does.
  if (!std::strcmp(mode, "scale-box-by-zero"))
  {
    try
    {
      TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
      gp_Trsf      t;
      t.SetScale(gp_Pnt(0, 0, 0), 0.0);
      BRepBuilderAPI_Transform x(box, t, true);
      std::printf("Transform IsDone=%d ShapeIsNull=%d\n",
                  (int)x.IsDone(), (int)x.Shape().IsNull());
      GProp_GProps props;
      BRepGProp::VolumeProperties(x.Shape(), props);
      std::printf("volume of the scaled-by-zero box = %g\n", props.Mass());
    }
    catch (Standard_Failure const& f)
    {
      std::printf("caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  std::printf("unknown mode\n");
  return 2;
}
