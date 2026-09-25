// Kernel parity probe for BracketedRootTests, BracketMinimumTests, ConicalSurfaceTests and
// CoordinateSystemTests (#1983). Each block mirrors the bridge function the test reaches, with
// the test's own inputs.
#include <GC_MakeConicalSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <RWMesh_CoordinateSystemConverter.hxx>
#include <math_BracketMinimum.hxx>
#include <math_BracketedRoot.hxx>
#include <math_Function.hxx>
#include <math_FunctionWithDerivative.hxx>
#include <cmath>
#include <cstdio>

struct Sq : math_FunctionWithDerivative
{
  bool Value(const double x, double& f) override { f = x * x - 4.0; return true; }
  bool Derivative(const double x, double& d) override { d = 2.0 * x; return true; }
  bool Values(const double x, double& f, double& d) override
  {
    f = x * x - 4.0;
    d = 2.0 * x;
    return true;
  }
};

struct Sn : math_FunctionWithDerivative
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

struct Quad : math_Function
{
  bool Value(const double x, double& f) override { f = x * x; return true; }
};

static void pr(const char* tag, const gp_Pnt& p)
{
  printf("%s (%.12g, %.12g, %.12g)\n", tag, p.X(), p.Y(), p.Z());
}

int main()
{
  { // findRoot / findSinRoot: OCCTMathBracketedRoot, tolerance 1e-10, 100 iterations
    Sq                 f;
    math_BracketedRoot br(f, 0.0, 5.0, 1e-10, 100);
    printf("findRoot done=%d root=%.15g iter=%d\n", br.IsDone(), br.Root(), br.NbIterations());
    Sn                 g;
    math_BracketedRoot bs(g, 2.0, 4.0, 1e-10, 100);
    printf("findSinRoot done=%d root=%.15g iter=%d (pi=%.15g)\n",
           bs.IsDone(), bs.Root(), bs.NbIterations(), M_PI);
  }
  { // bracketQuadratic: OCCTMathBracketMinimum
    Quad                q;
    math_BracketMinimum bm(q, -5.0, 2.0);
    double              a, b, c, fa, fb, fc;
    bm.Values(a, b, c);
    bm.FunctionValues(fa, fb, fc);
    printf("bracketQuadratic done=%d a=%.12g b=%.12g c=%.12g fa=%.12g fb=%.12g fc=%.12g\n",
           bm.IsDone(), a, b, c, fa, fb, fc);
  }
  { // fromAxis: OCCTSurfaceConicalFromAxis, semiAngle pi/6, radius 5
    gp_Ax2                      ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GC_MakeConicalSurface       mk(ax, M_PI / 6, 5.0);
    Handle(Geom_ConicalSurface) s = mk.Value();
    printf("fromAxis done=%d semiAngle=%.12g refRadius=%.12g\n",
           mk.IsDone(), s->SemiAngle(), s->RefRadius());
    pr("fromAxis S(0,0)", s->Value(0, 0));
    pr("fromAxis S(0,1)", s->Value(0, 1));
    pr("fromAxis S(pi/2,2)", s->Value(M_PI / 2, 2));
  }
  { // fromPointsRadii: OCCTSurfaceConicalFromPointsRadii
    GC_MakeConicalSurface       mk(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), 5.0, 2.0);
    Handle(Geom_ConicalSurface) s = mk.Value();
    printf("fromPointsRadii done=%d semiAngle=%.12g refRadius=%.12g\n",
           mk.IsDone(), s->SemiAngle(), s->RefRadius());
    pr("fromPointsRadii location", s->Location());
    pr("fromPointsRadii S(0,0)", s->Value(0, 0));
    // v is measured along the generatrix; the generatrix from (5,0,0) to (2,0,10).
    double vLen = std::sqrt(9.0 + 100.0);
    pr("fromPointsRadii S(0,|gen|)", s->Value(0, vLen));
  }
  { // zUpDirection / yUpDirection: OCCTCoordSystemUpDirection
    gp_Ax3 z = RWMesh_CoordinateSystemConverter::StandardCoordinateSystem(RWMesh_CoordinateSystem_Zup);
    gp_Ax3 y = RWMesh_CoordinateSystemConverter::StandardCoordinateSystem(RWMesh_CoordinateSystem_Yup);
    pr("zUpDirection", gp_Pnt(z.Direction().XYZ()));
    pr("yUpDirection", gp_Pnt(y.Direction().XYZ()));
  }
  { // convertWithScaling / convertZupToYup: OCCTCoordSystemConvert
    RWMesh_CoordinateSystemConverter c1;
    c1.SetInputCoordinateSystem(RWMesh_CoordinateSystem_Zup);
    c1.SetInputLengthUnit(0.001);
    c1.SetOutputCoordinateSystem(RWMesh_CoordinateSystem_Zup);
    c1.SetOutputLengthUnit(1.0);
    gp_XYZ p1(1000, 0, 500);
    c1.TransformPosition(p1);
    pr("convertWithScaling", gp_Pnt(p1));
    RWMesh_CoordinateSystemConverter c2;
    c2.SetInputCoordinateSystem(RWMesh_CoordinateSystem_Zup);
    c2.SetInputLengthUnit(1.0);
    c2.SetOutputCoordinateSystem(RWMesh_CoordinateSystem_Yup);
    c2.SetOutputLengthUnit(1.0);
    gp_XYZ p2(1, 2, 3);
    c2.TransformPosition(p2);
    pr("convertZupToYup", gp_Pnt(p2));
  }
  return 0;
}
