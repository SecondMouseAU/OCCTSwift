// #2860 / #2857: the preconditions the bridge guards are built on, measured rather than reasoned.
//
// The #2801 sweep probes (Scripts/repro/2801-sweep-math, Scripts/repro/2801-sweep-index) prove the
// defects. This one measures the four things a guard author has to know and cannot derive from a
// signature:
//
//   1. the two inline-buffer thresholds, so a test can sit on both sides of each one;
//   2. whether a negative-dimension math_Matrix is safe to construct at all, which decides whether
//      OCCTMathMatrixCreate needs a refusal channel or whether guarding every accessor is enough;
//   3. what gp_Mat::Determinant() returns for the inputs gp_Trsf::SetValues would have refused,
//      since that determinant IS the guard predicate;
//   4. whether a singular gp_GTrsf collapses a solid the way a zero gp_Trsf scale does, which the
//      sweep left unmeasured and which decides whether OCCTShapeGTrsfModification needs a guard.
//
// Usage: probe <mode>. One mode per process; the exit code is the result.

#include <math_Matrix.hxx>
#include <math_Vector.hxx>
#include <math_Uzawa.hxx>
#include <gp_Mat.hxx>
#include <gp_GTrsf.hxx>
#include <gp_Trsf.hxx>
#include <gp_Pnt.hxx>
#include <gp_XYZ.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools_GTrsfModification.hxx>
#include <BRepTools_Modifier.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <typeinfo>

// True when theItem sits inside the [theObj, theObj + theSize) footprint, which is exactly what
// "the container used its inlined buffer" means, and therefore what decides whether an overrun
// scribbles inside the object (silent, a wrong number) or off the end of a heap block (a fault).
static bool inlined(const void* theObj, const size_t theSize, const void* theItem)
{
  const char* base = static_cast<const char*>(theObj);
  const char* item = static_cast<const char*>(theItem);
  return item >= base && item < base + theSize;
}

static double uzawaRun(int nc, int nv)
{
  math_Matrix Cont(1, nc, 1, nv, 0.0);
  for (int i = 1; i <= nc; i++)
    for (int j = 1; j <= nv; j++)
      Cont(i, j) = (i == j) ? 1.0 : 0.25;
  math_Vector Sec(1, nc, 1.0);
  math_Vector Start(1, nv, 0.0);
  std::printf("  Cont %dx%d: Errinit sized %d, written to %d\n", nc, nv, nv, nc);
  std::fflush(stdout);
  math_Uzawa u(Cont, Sec, Start, 1.0e-6, 1.0e-6, 500);
  std::printf("  ctor returned; IsDone=%d", (int)u.IsDone());
  if (u.IsDone())
    std::printf(" Value(1)=%g", u.Value()(1));
  std::printf("\n");
  return 0;
}

int main(int argc, char** argv)
{
  const char* mode = argc > 1 ? argv[1] : "";
  std::printf("[mode %s]\n", mode);
  std::fflush(stdout);

  // ---- 1. The two thresholds, read off the headers and confirmed against IsDeletable(), which is
  // false exactly when the container is pointing at the inlined buffer rather than at the heap.
  if (!std::strcmp(mode, "thresholds"))
  {
    std::printf("math_DoubleTab THE_BUFFER_SIZE is 64 doubles, math_VectorBase's is 32.\n");
    std::printf("sizeof(math_Matrix)=%zu sizeof(math_Vector)=%zu\n",
                sizeof(math_Matrix),
                sizeof(math_Vector));
    const int cases[][2] = {{2, 32}, {2, 33}, {3, 2}, {100, 1}, {8, 8}, {9, 8}};
    for (const auto& c : cases)
    {
      math_Matrix A(1, c[0], 1, c[1], 1.0);
      std::printf("  math_Matrix %dx%d = %d elements: inline=%d\n",
                  c[0],
                  c[1],
                  c[0] * c[1],
                  (int)inlined(&A, sizeof(A), &A(1, 1)));
    }
    for (int n : {31, 32, 33})
    {
      math_Vector v(1, n, 0.0);
      std::printf("  math_Vector %d elements: inline=%d\n",
                  n,
                  (int)inlined(&v, sizeof(v), &v(1)));
    }
    return 0;
  }

  // ---- 2. A negative-dimension math_Matrix: does OCCTMathMatrixCreate need a refusal channel, or
  // is guarding every accessor enough? RowNumber() is (upper - lower + 1), so it reports the
  // negative width, and every guard of the form (row < 1 || row > RowNumber()) then refuses.
  if (!std::strcmp(mode, "negative-dims"))
  {
    try
    {
      math_Matrix A(1, -5, 1, -5, 7.0);
      std::printf("  built, RowNumber=%d ColNumber=%d\n", A.RowNumber(), A.ColNumber());
    }
    catch (Standard_Failure const& f)
    {
      std::printf("  caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  if (!std::strcmp(mode, "zero-dims-accessors"))
  {
    math_Matrix A(1, 0, 1, 0, 0.0);
    std::printf("  built 0x0, RowNumber=%d ColNumber=%d\n", A.RowNumber(), A.ColNumber());
    std::fflush(stdout);
    // A 0x0 is "square", so a squareness-only guard would let Transpose and Invert through.
    A.Transpose();
    std::printf("  Transpose() on 0x0 returned\n");
    std::fflush(stdout);
    const double d = A.Determinant();
    std::printf("  Determinant() on 0x0 returned %g\n", d);
    std::fflush(stdout);
    A.Invert();
    std::printf("  Invert() on 0x0 returned\n");
    return 0;
  }

  // ---- 3. Uzawa either side of math_VectorBase's 32.
  if (!std::strcmp(mode, "uzawa-at-threshold"))
    return (int)uzawaRun(32, 32); // nc == nv: no overrun at all, the control
  if (!std::strcmp(mode, "uzawa-one-past"))
    return (int)uzawaRun(33, 32); // one slot past the 32-element inline buffer
  if (!std::strcmp(mode, "uzawa-heap"))
    return (int)uzawaRun(40, 33); // Errinit on the heap, written 7 past its end

  // ---- 4. gp_Mat::Determinant() on the inputs gp_Trsf::SetValues would have refused, and on one
  // it would have accepted. This value is the guard predicate, so it has to be measured.
  if (!std::strcmp(mode, "trsf-determinant"))
  {
    struct Row
    {
      const char* name;
      double      a[9]; // a11 a12 a13 a21 a22 a23 a31 a32 a33
    };
    const Row rows[] = {
      {"all-zero", {0, 0, 0, 0, 0, 0, 0, 0, 0}},
      {"rank2-identical-rows", {1, 0, 0, 0, 1, 0, 0, 1, 0}},
      {"identity", {1, 0, 0, 0, 1, 0, 0, 0, 1}},
      {"uniform-scale-2", {2, 0, 0, 0, 2, 0, 0, 0, 2}},
      {"tiny-but-nonzero", {1e-5, 0, 0, 0, 1e-5, 0, 0, 0, 1e-5}},
    };
    std::printf("  gp::Resolution() = %g\n", gp::Resolution());
    for (const auto& r : rows)
    {
      gp_Mat M(gp_XYZ(r.a[0], r.a[3], r.a[6]),
               gp_XYZ(r.a[1], r.a[4], r.a[7]),
               gp_XYZ(r.a[2], r.a[5], r.a[8]));
      const double s = M.Determinant();
      std::printf("  %-22s det=%-14g refused-by-kernel-test=%d\n",
                  r.name,
                  s,
                  (int)(std::abs(s) < gp::Resolution()));
    }
    return 0;
  }

  // ---- 5. A singular gp_GTrsf through BRepTools_GTrsfModification: does it collapse the solid the
  // way the zero gp_Trsf scale of finding 7 does? gp_GTrsf::SetValue carries no determinant check of
  // its own, so if this comes back with a volume the guard belongs on gp_Trsf alone.
  if (!std::strcmp(mode, "gtrsf-singular"))
  {
    try
    {
      TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
      gp_GTrsf     g;
      g.SetValue(1, 1, 1);
      g.SetValue(1, 2, 0);
      g.SetValue(1, 3, 0);
      g.SetValue(1, 4, 0);
      g.SetValue(2, 1, 0);
      g.SetValue(2, 2, 1);
      g.SetValue(2, 3, 0);
      g.SetValue(2, 4, 0);
      g.SetValue(3, 1, 0);
      g.SetValue(3, 2, 0);
      g.SetValue(3, 3, 0); // flattens z: the vectorial part is rank 2
      g.SetValue(3, 4, 0);
      std::printf("  gtrsf vectorial determinant = %g\n", g.VectorialPart().Determinant());
      std::fflush(stdout);
      Handle(BRepTools_GTrsfModification) mod = new BRepTools_GTrsfModification(g);
      BRepTools_Modifier                  modifier(box, mod);
      std::printf("  modifier IsDone=%d\n", (int)modifier.IsDone());
      std::fflush(stdout);
      if (modifier.IsDone())
      {
        TopoDS_Shape result = modifier.ModifiedShape(box);
        std::printf("  result IsNull=%d\n", (int)result.IsNull());
        std::fflush(stdout);
        if (!result.IsNull())
        {
          GProp_GProps props;
          BRepGProp::VolumeProperties(result, props);
          std::printf("  volume = %g\n", props.Mass());
        }
      }
    }
    catch (Standard_Failure const& f)
    {
      std::printf("  caught Standard_Failure: %s\n", typeid(f).name());
      return 3;
    }
    return 0;
  }

  std::printf("unknown mode\n");
  return 2;
}
