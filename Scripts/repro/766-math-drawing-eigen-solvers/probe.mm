// Kernel parity probe for DrawingCompositionTests, EigenValuesTests, EllipseThreePointsTests,
// FRPRTests, FunctionAllRootsTests and GaussLeastSquareTests (#1983). Each block mirrors the
// bridge function the test reaches, with the test's own inputs.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GC_MakeEllipse.hxx>
#include <Geom_Ellipse.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <NCollection_Array1.hxx>
#include <math_EigenValuesSearcher.hxx>
#include <math_FRPR.hxx>
#include <math_FunctionAllRoots.hxx>
#include <math_FunctionRoots.hxx>
#include <math_FunctionSample.hxx>
#include <math_FunctionWithDerivative.hxx>
#include <math_GaussLeastSquare.hxx>
#include <math_Matrix.hxx>
#include <math_MultipleVarFunctionWithGradient.hxx>
#include <math_Vector.hxx>
#include <cmath>
#include <cstdio>

// Bounds of every vertex of the compounds OCCTDrawingCreate keeps (visible/hidden sharp, smooth
// and outline). Every edge of a box view is a straight segment, so its vertices are its extent.
static void hlrBounds(const char* tag, double w, double h, double d, gp_Dir dir)
{
  BRepPrimAPI_MakeBox box(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d);
  Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
  algo->Add(box.Shape());
  algo->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), dir)));
  algo->Update();
  algo->Hide();
  HLRBRep_HLRToShape s(algo);
  TopoDS_Shape       cs[6] = {s.VCompound(),
                              s.Rg1LineVCompound(),
                              s.OutLineVCompound(),
                              s.HCompound(),
                              s.Rg1LineHCompound(),
                              s.OutLineHCompound()};
  double minX = 1e100, minY = 1e100, maxX = -1e100, maxY = -1e100;
  int    nEdges = 0;
  for (auto& c : cs)
  {
    if (c.IsNull())
      continue;
    for (TopExp_Explorer ex(c, TopAbs_VERTEX); ex.More(); ex.Next())
    {
      gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(ex.Current()));
      minX     = std::min(minX, p.X());
      maxX     = std::max(maxX, p.X());
      minY     = std::min(minY, p.Y());
      maxY     = std::max(maxY, p.Y());
    }
    for (TopExp_Explorer ex(c, TopAbs_EDGE); ex.More(); ex.Next())
      nEdges++;
  }
  printf("%s edges=%d min (%.12g, %.12g) max (%.12g, %.12g)\n", tag, nEdges, minX, minY, maxX, maxY);
}

static void eigen(const char* tag, bool fixedConvention)
{
  NCollection_Array1<double> diag(1, 3), sub(1, 3);
  for (int i = 1; i <= 3; i++)
    diag(i) = 2.0;
  // OCCTMathEigenValues: slot 1 is discarded, the n-1 off-diagonals go in 2..n (#1643).
  if (fixedConvention)
  {
    sub(1) = 0.0;
    sub(2) = 1.0;
    sub(3) = 1.0;
  }
  else
  {
    sub(1) = 1.0;
    sub(2) = 1.0;
    sub(3) = 0.0;
  }
  math_EigenValuesSearcher e(diag, sub);
  printf("%s done=%d", tag, e.IsDone());
  for (int i = 1; i <= e.Dimension(); i++)
    printf(" %.15g", e.EigenValue(i));
  printf("\n");
}

struct Quad2 : math_MultipleVarFunctionWithGradient
{
  int  NbVariables() const override { return 2; }
  bool Value(const math_Vector& X, double& F) override
  {
    F = (X(1) - 1) * (X(1) - 1) + (X(2) - 2) * (X(2) - 2);
    return true;
  }
  bool Gradient(const math_Vector& X, math_Vector& G) override
  {
    G(1) = 2 * (X(1) - 1);
    G(2) = 2 * (X(2) - 2);
    return true;
  }
  bool Values(const math_Vector& X, double& F, math_Vector& G) override
  {
    Value(X, F);
    return Gradient(X, G);
  }
};

struct SinF : math_FunctionWithDerivative
{
  bool Value(const double x, double& f) override { f = std::sin(x); return true; }
  bool Derivative(const double x, double& d) override { d = std::cos(x); return true; }
  bool Values(const double x, double& f, double& d) override
  {
    f = std::sin(x);
    d = std::cos(x);
    return true;
  }
};

int main()
{
  hlrBounds("drawingBounds frontView(box 100x50x25)", 100, 50, 25, gp_Dir(0, 1, 0));
  hlrBounds("topView(box 10x10x10)", 10, 10, 10, gp_Dir(0, 0, 1));
  eigen("tridiagonal/withVectors eigenvalues (bridge convention)", true);
  eigen("pre-#1643 convention, off-diagonals in slots 1..n-1", false);
  {
    GC_MakeEllipse       me(gp_Pnt(10, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(0, 0, 0));
    Handle(Geom_Ellipse) e = me.Value();
    printf("ellipseFromThreePoints done=%d major=%.12g minor=%.12g domain [%.12g, %.12g]\n",
           me.IsDone(), e->MajorRadius(), e->MinorRadius(), e->FirstParameter(), e->LastParameter());
    gp_Pnt a = e->Value(0), b = e->Value(M_PI / 2);
    printf("ellipseFromThreePoints P(0) (%.12g, %.12g, %.12g) P(pi/2) (%.12g, %.12g, %.12g)\n",
           a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
  }
  {
    // MathSolver.minimizeFRPR defaults: see the Swift wrapper (tolerance 1e-8, 200 iterations).
    Quad2       f;
    math_FRPR   frpr(f, 1e-8, 200);
    math_Vector start(1, 2);
    start(1) = 10;
    start(2) = 10;
    frpr.Perform(f, start);
    printf("minimizeQuadratic done=%d location (%.12g, %.12g) minimum %.3g\n",
           frpr.IsDone(), frpr.Location()(1), frpr.Location()(2), frpr.Minimum());
  }
  {
    // sinRoots: MathSolver.findAllRoots(in:) with no samples argument resolves to the overload
    // that calls OCCTMathFunctionRoots (math_FunctionRoots, 20 samples), not
    // OCCTMathFunctionAllRoots. Both are printed; the first is the one the test reaches.
    SinF               f;
    math_FunctionRoots fr(f, 0.1, 10.0, 20);
    printf("sinRoots (math_FunctionRoots, 20 samples) done=%d n=%d", fr.IsDone(), fr.NbSolutions());
    for (int i = 1; i <= fr.NbSolutions(); i++)
      printf(" %.12g", fr.Value(i));
    printf("\n");
  }
  {
    SinF                  f;
    math_FunctionSample   sample(0.1, 10.0, 100);
    math_FunctionAllRoots all(f, sample, 1e-8, 1e-8, 1e-8);
    printf("math_FunctionAllRoots, 100 samples: done=%d n=%d", all.IsDone(), all.NbPoints());
    for (int i = 1; i <= all.NbPoints(); i++)
      printf(" %.12g", all.GetPoint(i));
    printf("\n");
  }
  {
    math_Matrix A(1, 3, 1, 2);
    double      a[6] = {1, 0, 0, 1, 1, 1};
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 2; j++)
        A(i + 1, j + 1) = a[i * 2 + j];
    math_GaussLeastSquare gls(A);
    math_Vector           b(1, 3), x(1, 2);
    b(1) = 1;
    b(2) = 2;
    b(3) = 3;
    gls.Solve(b, x);
    printf("overdetermined done=%d x (%.15g, %.15g)\n", gls.IsDone(), x(1), x(2));
  }
  return 0;
}
