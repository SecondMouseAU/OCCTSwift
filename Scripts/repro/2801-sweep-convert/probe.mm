// #2801 sweep, cluster: domain guards on conversion and filling.
//
// Every mode below mirrors exactly what the bridge does: the same validation the bridge performs
// (radii/focal only), the same OCCT constructor, the same try/catch (...), and the same
// array-building helper (buildCurve2DFromConic / buildSurfaceFromElementary). The u/v parameters
// are the raw caller doubles the bridge forwards.
//
// The checks that OCCT documents on these constructors are Standard_DomainError_Raise_if written
// in the .cxx, so they are compiled out of the Release kernel we link. Convert_CircleToBSplineCurve
// is the control: it uses a literal `throw Standard_DomainError(...)`, which no macro gates.

#import <Foundation/Foundation.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <string>

#include <Convert_CircleToBSplineCurve.hxx>
#include <Convert_EllipseToBSplineCurve.hxx>
#include <Convert_HyperbolaToBSplineCurve.hxx>
#include <Convert_ParabolaToBSplineCurve.hxx>
#include <Convert_ConeToBSplineSurface.hxx>
#include <Convert_CylinderToBSplineSurface.hxx>
#include <Convert_SphereToBSplineSurface.hxx>
#include <Convert_TorusToBSplineSurface.hxx>
#include <Convert_ConicToBSplineCurve.hxx>
#include <Convert_ElementarySurfaceToBSplineSurface.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <GeomFill_Profiler.hxx>
#include <GeomFill_Coons.hxx>
#include <GeomFill_Curved.hxx>
#include <GeomFill_Stretch.hxx>
#include <Geom_BezierCurve.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <Geom_Circle.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <GeomConvert.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <NCollection_Array1.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <gp.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Hypr2d.hxx>
#include <gp_Parab2d.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array2OfReal.hxx>
#include <Standard_Failure.hxx>

// ---- verbatim copy of the bridge's buildCurve2DFromConic ----------------------------------
static Handle(Geom2d_BSplineCurve) buildCurve2DFromConic(const Convert_ConicToBSplineCurve& conv)
{
  int np = conv.NbPoles(), nk = conv.NbKnots(), deg = conv.Degree();
  printf("    conv: NbPoles=%d NbKnots=%d Degree=%d\n", np, nk, deg);
  fflush(stdout);
  TColgp_Array1OfPnt2d    poles(1, np);
  TColStd_Array1OfReal    weights(1, np), knots(1, nk);
  TColStd_Array1OfInteger mults(1, nk);
  const TColgp_Array1OfPnt2d&    convPoles   = conv.Poles();
  const TColStd_Array1OfReal&    convWeights = conv.Weights();
  const TColStd_Array1OfReal&    convKnots   = conv.Knots();
  const TColStd_Array1OfInteger& convMults   = conv.Multiplicities();
  for (int i = 1; i <= np; i++) { poles(i) = convPoles.Value(i); weights(i) = convWeights.Value(i); }
  for (int i = 1; i <= nk; i++) { knots(i) = convKnots.Value(i); mults(i) = convMults.Value(i); }
  for (int i = 1; i <= np; i++)
    printf("    pole[%d] = (%g, %g) w=%g\n", i, poles(i).X(), poles(i).Y(), weights(i));
  for (int i = 1; i <= nk; i++)
    printf("    knot[%d] = %g mult=%d\n", i, knots(i), mults(i));
  fflush(stdout);
  Handle(Geom2d_BSplineCurve) bsc = new Geom2d_BSplineCurve(poles, weights, knots, mults, deg);
  return bsc;
}

// ---- verbatim copy of the bridge's buildSurfaceFromElementary ----------------------------
static Handle(Geom_BSplineSurface) buildSurfaceFromElementary(
  const Convert_ElementarySurfaceToBSplineSurface& conv)
{
  int nup = conv.NbUPoles(), nvp = conv.NbVPoles();
  int nuk = conv.NbUKnots(), nvk = conv.NbVKnots();
  int udeg = conv.UDegree(), vdeg = conv.VDegree();
  printf("    conv: NbUPoles=%d NbVPoles=%d NbUKnots=%d NbVKnots=%d UDeg=%d VDeg=%d\n",
         nup, nvp, nuk, nvk, udeg, vdeg);
  fflush(stdout);
  TColgp_Array2OfPnt   poles(1, nup, 1, nvp);
  TColStd_Array2OfReal weights(1, nup, 1, nvp);
  const TColgp_Array2OfPnt&   convPoles   = conv.Poles();
  const TColStd_Array2OfReal& convWeights = conv.Weights();
  for (int i = 1; i <= nup; i++)
    for (int j = 1; j <= nvp; j++)
    { poles(i, j) = convPoles.Value(i, j); weights(i, j) = convWeights.Value(i, j); }
  TColStd_Array1OfReal    uknots(1, nuk), vknots(1, nvk);
  TColStd_Array1OfInteger umults(1, nuk), vmults(1, nvk);
  const TColStd_Array1OfReal&    convUKnots = conv.UKnots();
  const TColStd_Array1OfInteger& convUMults = conv.UMultiplicities();
  const TColStd_Array1OfReal&    convVKnots = conv.VKnots();
  const TColStd_Array1OfInteger& convVMults = conv.VMultiplicities();
  for (int i = 1; i <= nuk; i++) { uknots(i) = convUKnots.Value(i); umults(i) = convUMults.Value(i); }
  for (int i = 1; i <= nvk; i++) { vknots(i) = convVKnots.Value(i); vmults(i) = convVMults.Value(i); }
  for (int i = 1; i <= nuk; i++) printf("    uknot[%d] = %g mult=%d\n", i, uknots(i), umults(i));
  for (int i = 1; i <= nvk; i++) printf("    vknot[%d] = %g mult=%d\n", i, vknots(i), vmults(i));
  for (int i = 1; i <= nup; i++)
    for (int j = 1; j <= nvp; j++)
      printf("    pole(%d,%d) = (%g, %g, %g) w=%g\n", i, j,
             poles(i,j).X(), poles(i,j).Y(), poles(i,j).Z(), weights(i,j));
  fflush(stdout);
  return new Geom_BSplineSurface(poles, weights, uknots, vknots, umults, vmults,
                                 udeg, vdeg, conv.IsUPeriodic(), conv.IsVPeriodic());
}

// ---- the bridge's own validators (occtValidEllipseRadii etc, in spirit) -------------------
static bool validEllipseRadii(double R, double r) { return R > 0 && r > 0 && r <= R; }
static bool validHyperbolaRadii(double R, double r) { return R > 0 && r > 0; }
static bool validParabolaFocal(double f) { return f > 0; }
static bool validCircleRadius(double R) { return R > 0; }

// ------------------------------------------------------------------------------------------
static void ellipse(double u1, double u2)
{
  printf("  Convert_EllipseToBSplineCurve(major=20, minor=10, u1=%g, u2=%g) delta=%g\n",
         u1, u2, u2 - u1);
  if (!validEllipseRadii(20, 10)) { printf("  bridge refused on radii\n"); return; }
  try {
    gp_Elips2d e(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0), gp_Dir2d(0, 1)), 20, 10);
    Convert_EllipseToBSplineCurve conv(e, u1, u2);
    Handle(Geom2d_BSplineCurve) c = buildCurve2DFromConic(conv);
    printf("  RESULT: %s curve, FirstParameter=%g LastParameter=%g\n",
           c.IsNull() ? "null" : "non-null",
           c.IsNull() ? 0.0 : c->FirstParameter(), c.IsNull() ? 0.0 : c->LastParameter());
  } catch (Standard_Failure& f) {
    printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
  } catch (...) { printf("  THREW (...)\n"); }
}

static void hyperbola(double u1, double u2)
{
  printf("  Convert_HyperbolaToBSplineCurve(major=10, minor=5, u1=%g, u2=%g)\n", u1, u2);
  if (!validHyperbolaRadii(10, 5)) { printf("  bridge refused on radii\n"); return; }
  try {
    gp_Hypr2d h(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0), gp_Dir2d(0, 1)), 10, 5);
    Convert_HyperbolaToBSplineCurve conv(h, u1, u2);
    Handle(Geom2d_BSplineCurve) c = buildCurve2DFromConic(conv);
    if (!c.IsNull()) {
      gp_Pnt2d p = c->Value(c->FirstParameter());
      printf("  RESULT: non-null curve, Value(first) = (%g, %g)\n", p.X(), p.Y());
    } else printf("  RESULT: null curve\n");
  } catch (Standard_Failure& f) {
    printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
  } catch (...) { printf("  THREW (...)\n"); }
}

static void parabola(double u1, double u2)
{
  printf("  Convert_ParabolaToBSplineCurve(focal=5, u1=%g, u2=%g)\n", u1, u2);
  if (!validParabolaFocal(5)) { printf("  bridge refused on focal\n"); return; }
  try {
    gp_Parab2d p(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0), gp_Dir2d(0, 1)), 5);
    Convert_ParabolaToBSplineCurve conv(p, u1, u2);
    Handle(Geom2d_BSplineCurve) c = buildCurve2DFromConic(conv);
    printf("  RESULT: %s curve\n", c.IsNull() ? "null" : "non-null");
  } catch (Standard_Failure& f) {
    printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
  } catch (...) { printf("  THREW (...)\n"); }
}

static void circle(double u1, double u2)
{
  printf("  Convert_CircleToBSplineCurve(radius=5, u1=%g, u2=%g)  [CONTROL: literal throw]\n", u1, u2);
  if (!validCircleRadius(5)) { printf("  bridge refused on radius\n"); return; }
  try {
    gp_Circ2d ci(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Convert_CircleToBSplineCurve conv(ci, u1, u2);
    Handle(Geom2d_BSplineCurve) c = buildCurve2DFromConic(conv);
    printf("  RESULT: %s curve\n", c.IsNull() ? "null" : "non-null");
  } catch (Standard_Failure& f) {
    printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
  } catch (...) { printf("  THREW (...)\n"); }
}

static void cylinder(double u1, double u2, double v1, double v2)
{
  printf("  Convert_CylinderToBSplineSurface(r=5, u1=%g, u2=%g, v1=%g, v2=%g) deltaU=%g\n",
         u1, u2, v1, v2, u2 - u1);
  printf("    arrays are sized for TheNbUPoles=9 / TheNbUKnots=5 at construction\n");
  fflush(stdout);
  try {
    gp_Cylinder cyl(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    Convert_CylinderToBSplineSurface conv(cyl, u1, u2, v1, v2);
    Handle(Geom_BSplineSurface) s = buildSurfaceFromElementary(conv);
    printf("  RESULT: %s surface\n", s.IsNull() ? "null" : "non-null");
  } catch (Standard_Failure& f) {
    printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
  } catch (...) { printf("  THREW (...)\n"); }
}

static void cone(double u1, double u2, double v1, double v2)
{
  printf("  Convert_ConeToBSplineSurface(semiAngle=0.3, refRadius=5, u1=%g, u2=%g, v1=%g, v2=%g) deltaU=%g\n",
         u1, u2, v1, v2, u2 - u1);
  fflush(stdout);
  try {
    gp_Cone c(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0.3, 5);
    Convert_ConeToBSplineSurface conv(c, u1, u2, v1, v2);
    Handle(Geom_BSplineSurface) s = buildSurfaceFromElementary(conv);
    printf("  RESULT: %s surface\n", s.IsNull() ? "null" : "non-null");
  } catch (Standard_Failure& f) {
    printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
  } catch (...) { printf("  THREW (...)\n"); }
}


// ---- GCPnts_TangentialDeflection: the dead check is
//      theCurvatureDeflection < Precision::Confusion() || theAngularDeflection < Precision::Angular()
//      in GCPnts_TangentialDeflection::initialize, a template defined in the .cxx.
static void tangential(double angularDefl, double curvatureDefl, int minPts)
{
  printf("  GCPnts_TangentialDeflection(BRepAdaptor_Curve(circular edge), ang=%g, curv=%g, minPts=%d)\n",
         angularDefl, curvatureDefl, minPts);
  fflush(stdout);
  try {
    // A circular edge: PerformCircular / PerformCurve is the branch the deflections steer.
    Handle(Geom_Circle) ci = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10.0);
    BRepBuilderAPI_MakeEdge me(ci, 0.0, M_PI);
    if (!me.IsDone()) { printf("  edge build failed\n"); return; }
    BRepAdaptor_Curve curve(TopoDS::Edge(me.Shape()));
    GCPnts_TangentialDeflection sampler(curve, angularDefl, curvatureDefl, std::max(minPts, 2));
    int n = sampler.NbPoints();
    printf("  RESULT: NbPoints = %d\n", n);
    if (n >= 1) {
      gp_Pnt p = sampler.Value(1);
      printf("  Value(1) = (%g, %g, %g)  Parameter(1) = %g\n", p.X(), p.Y(), p.Z(), sampler.Parameter(1));
    }
    if (n >= 2) printf("  Parameter(%d) = %g (last)\n", n, sampler.Parameter(n));
    if (n > 10000)
      printf("  the bridge truncates to maxPoints=10000: Parameter(10000) = %g, i.e. %.2f%% of the\n"
             "  arc, returned to Swift as a sampling of the whole edge with no error signal\n",
             sampler.Parameter(10000), 100.0 * sampler.Parameter(10000) / M_PI);
  } catch (Standard_Failure& f) {
    printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
  } catch (...) { printf("  THREW (...)\n"); }
}

// ---- GeomFill_Stretch / Coons / Curved: the dead check is a pole/weight array LENGTH mismatch.
//      The bridge builds all four arrays at the same length, so the condition cannot hold.
//      What the bridge does NOT bound is `count` itself (OCCTGeomFillStretch has no count guard).
static void stretch(int count)
{
  printf("  GeomFill_Stretch(four NCollection_Array1<gp_Pnt> of length %d)\n", count);
  fflush(stdout);
  try {
    NCollection_Array1<gp_Pnt> P1(1, count), P2(1, count), P3(1, count), P4(1, count);
    for (int i = 1; i <= count; i++) {
      P1(i) = gp_Pnt(i, 0, 0); P2(i) = gp_Pnt(count, i, 0);
      P3(i) = gp_Pnt(i, count, 0); P4(i) = gp_Pnt(0, i, 0);
    }
    GeomFill_Stretch st(P1, P2, P3, P4);
    printf("  RESULT: NbUPoles=%d NbVPoles=%d isRational=%d\n",
           st.NbUPoles(), st.NbVPoles(), (int)st.isRational());
  } catch (Standard_Failure& f) {
    printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
  } catch (...) { printf("  THREW (...)\n"); }
}

// ---- GeomFill_Profiler::KnotsAndMults: the dead check swallows `int n = NbKnots()`, and the
//      raise is Knots.Length() != n || Mults.Length() != n.
static void profiler(int arrayLen, bool addCurves)
{
  printf("  GeomFill_Profiler::KnotsAndMults into arrays of length %d (curves added: %d)\n",
         arrayLen, (int)addCurves);
  fflush(stdout);
  try {
    GeomFill_Profiler pr;
    if (addCurves) {
      TColgp_Array1OfPnt a(1, 3), b(1, 3);
      a(1) = gp_Pnt(0,0,0); a(2) = gp_Pnt(5,5,0);  a(3) = gp_Pnt(10,0,0);
      b(1) = gp_Pnt(0,0,10); b(2) = gp_Pnt(5,5,10); b(3) = gp_Pnt(10,0,10);
      pr.AddCurve(new Geom_BezierCurve(a));
      pr.AddCurve(new Geom_BezierCurve(b));
      pr.Perform(1e-6);
      printf("    after Perform: NbKnots=%d NbPoles=%d Degree=%d\n",
             pr.NbKnots(), pr.NbPoles(), pr.Degree());
    }
    TColStd_Array1OfReal    knots(1, arrayLen);
    TColStd_Array1OfInteger mults(1, arrayLen);
    pr.KnotsAndMults(knots, mults);
    printf("  RESULT: returned normally; knots =");
    for (int i = 1; i <= arrayLen; i++) printf(" %g", knots(i));
    printf("  mults =");
    for (int i = 1; i <= arrayLen; i++) printf(" %d", mults(i));
    printf("\n");
  } catch (Standard_Failure& f) {
    printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
  } catch (...) { printf("  THREW (...)\n"); }
}


// ---- INDIRECT REACH: GeomConvert::SurfaceToBSplineSurface reaches the same
//      Convert_CylinderToBSplineSurface(Cyl, U1, U2, V1, V2) ctor, passing the trimmed surface's
//      own Bounds(). Geom_RectangularTrimmedSurface::SetTrim normalises U1 > U2 with a LITERAL
//      throw on U1 == U2, so the negative deltaU cannot arrive by this route. Measured, not assumed.
static void trimmedCylinderToBSpline(double u1, double u2, double v1, double v2)
{
  printf("  GeomConvert::SurfaceToBSplineSurface(Geom_RectangularTrimmedSurface(cylinder r=5, "
         "u1=%g, u2=%g, v1=%g, v2=%g))\n", u1, u2, v1, v2);
  fflush(stdout);
  try {
    Handle(Geom_CylindricalSurface) cyl =
      new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
    Handle(Geom_RectangularTrimmedSurface) trimmed =
      new Geom_RectangularTrimmedSurface(cyl, u1, u2, v1, v2);
    double au1, au2, av1, av2;
    trimmed->Bounds(au1, au2, av1, av2);
    printf("    the trim normalised to U [%g, %g] V [%g, %g], deltaU = %g\n",
           au1, au2, av1, av2, au2 - au1);
    fflush(stdout);
    Handle(Geom_BSplineSurface) bs = GeomConvert::SurfaceToBSplineSurface(trimmed);
    printf("  RESULT: %s surface, NbUPoles=%d NbVPoles=%d\n", bs.IsNull() ? "null" : "non-null",
           bs.IsNull() ? 0 : bs->NbUPoles(), bs.IsNull() ? 0 : bs->NbVPoles());
  } catch (Standard_Failure& f) {
    printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
  } catch (...) { printf("  THREW (...)\n"); }
}

// ---- INDIRECT REACH: Geom2dConvert::CurveToBSplineCurve reaches
//      Convert_HyperbolaToBSplineCurve(H2d, U1, U2) with U1/U2 from the curve's own bounds.
//      An UNTRIMMED Geom2d_Hyperbola has bounds -inf..+inf.
static void hyperbolaCurveToBSpline(bool trim, double t1, double t2)
{
  printf("  Geom2dConvert::CurveToBSplineCurve(%s Geom2d_Hyperbola(10, 5)%s)\n",
         trim ? "trimmed" : "UNTRIMMED", trim ? "" : "  [bounds are -inf..+inf]");
  fflush(stdout);
  try {
    Handle(Geom2d_Hyperbola) h =
      new Geom2d_Hyperbola(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0), gp_Dir2d(0, 1)), 10, 5);
    Handle(Geom2d_Curve) c = h;
    if (trim) c = new Geom2d_TrimmedCurve(h, t1, t2);
    printf("    FirstParameter=%g LastParameter=%g\n", c->FirstParameter(), c->LastParameter());
    fflush(stdout);
    Handle(Geom2d_BSplineCurve) bs = Geom2dConvert::CurveToBSplineCurve(c);
    if (bs.IsNull()) { printf("  RESULT: null curve\n"); return; }
    printf("  RESULT: non-null curve, NbPoles=%d\n", bs->NbPoles());
    for (int i = 1; i <= bs->NbPoles(); i++)
      printf("    pole[%d] = (%g, %g) w=%g\n", i, bs->Pole(i).X(), bs->Pole(i).Y(), bs->Weight(i));
    gp_Pnt2d p = bs->Value(bs->FirstParameter());
    printf("    Value(first) = (%g, %g)\n", p.X(), p.Y());
  } catch (Standard_Failure& f) {
    printf("  THREW Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "(none)");
  } catch (...) { printf("  THREW (...)\n"); }
}

int main(int argc, char** argv)
{
  int mode = argc > 1 ? atoi(argv[1]) : 0;
  printf("== mode %d ==\n", mode);
  fflush(stdout);
  switch (mode)
  {
    // --- Convert_EllipseToBSplineCurve: the dead check is (delta > 2pi + Tol) || (delta <= 0)
    case 1: ellipse(0, M_PI); break;             // baseline, valid
    case 2: ellipse(M_PI, 0); break;             // delta < 0  -> refused by the dead check
    case 3: ellipse(1, 1); break;                // delta == 0 -> refused by the dead check
    case 4: ellipse(0, 100); break;              // delta >> 2pi -> refused by the dead check

    // --- Convert_HyperbolaToBSplineCurve: dead check is |U2-U1| < Epsilon(0.)
    case 10: hyperbola(-1, 1); break;            // baseline, valid
    case 11: hyperbola(1, 1); break;             // U1 == U2 -> refused by the dead check

    // --- Convert_ParabolaToBSplineCurve: dead check is |U2-U1| < Epsilon(0.)
    case 20: parabola(-2, 2); break;             // baseline, valid
    case 21: parabola(1, 1); break;              // U1 == U2 -> refused by the dead check

    // --- Convert_CircleToBSplineCurve: CONTROL, literal throw, so the check is live
    case 30: circle(0, M_PI); break;             // baseline, valid
    case 31: circle(1, 1); break;                // delta == 0 -> live throw expected
    case 32: circle(0, 100); break;              // delta >> 2pi -> live throw expected

    // --- Convert_CylinderToBSplineSurface: dead check is
    //     (|V2-V1| <= |Epsilon(V1)|) || (deltaU > 2pi) || (deltaU < 0)
    case 40: cylinder(0, M_PI, 0, 10); break;    // baseline, valid
    case 41: cylinder(0, 100, 0, 10); break;     // deltaU >> 2pi -> refused by the dead check
    case 42: cylinder(0, -100, 0, 10); break;    // deltaU very negative
    case 43: cylinder(0, -1, 0, 10); break;      // deltaU = -1, small negative
    case 44: cylinder(0, M_PI, 5, 5); break;     // V1 == V2
    case 45: cylinder(0, 7, 0, 10); break;       // deltaU just over 2pi (7 > 6.283)

    // --- Convert_ConeToBSplineSurface: same shape
    case 50: cone(0, M_PI, 0, 10); break;        // baseline, valid
    case 51: cone(0, 100, 0, 10); break;         // deltaU >> 2pi
    case 52: cone(0, -100, 0, 10); break;        // deltaU very negative
    case 53: cone(0, M_PI, 5, 5); break;         // V1 == V2
    case 54: cone(0, 7, 0, 10); break;           // deltaU just over 2pi

    // --- how negative does deltaU have to be? nbUSpans = trunc(1.2*deltaU/pi) + 1, and the
    //     arrays are sized for nbUSpans in [1, 4]. nbUSpans <= 0 gives a zero or negative
    //     NbUPoles / NbUKnots and an index <= 0 into a 1-based array.
    case 46: cylinder(2 * M_PI, 0, 0, 10); break;   // swapped full-turn bounds, deltaU = -2pi
    case 47: cylinder(M_PI, 0, 0, 10); break;       // swapped half-turn bounds, deltaU = -pi
    case 48: cylinder(0, -5.0, 0, 10); break;       // deltaU = -5.0  (nbUSpans == 0)
    case 49: cylinder(0, -5.3, 0, 10); break;       // deltaU = -5.3  (nbUSpans == -1)
    case 55: cone(2 * M_PI, 0, 0, 10); break;       // swapped full-turn bounds, deltaU = -2pi
    case 56: cone(M_PI, 0, 0, 10); break;           // swapped half-turn bounds, deltaU = -pi

    // --- deltaU >= 10.472 needs nbUSpans == 5, i.e. 11 poles into the 9-pole array
    case 57: cylinder(0, 11, 0, 10); break;
    case 58: cone(0, 11, 0, 10); break;

    // --- Convert_HyperbolaToBSplineCurve: |U2-U1| >= Epsilon(0.), so the dead check passes,
    //     yet sinh(UL-UF) overflows to +inf and x = inf/inf = NaN. Not what the dead check was
    //     about; recorded as a separate NaN route on the same entry point.
    case 12: hyperbola(0, 800); break;
    case 13: hyperbola(0, 400); break;

    // --- GCPnts_TangentialDeflection, Edge.tangentialDeflectionPoints' own default arguments
    case 60: tangential(0.1, 0.1, 2); break;     // the Swift defaults, baseline
    case 61: tangential(0.1, 0.0, 2); break;     // curvatureDeflection 0 -> refused by the dead check
    case 62: tangential(0.0, 0.1, 2); break;     // angularDeflection 0   -> refused by the dead check
    case 63: tangential(0.0, 0.0, 2); break;     // both 0
    case 64: tangential(-1.0, -1.0, 2); break;   // both negative
    case 65: tangential(0.1, 1e-12, 2); break;   // curvature just under Precision::Confusion()

    // --- GeomFill_Stretch, count unbounded by the bridge
    case 70: stretch(4); break;                  // baseline
    case 71: stretch(2); break;
    case 72: stretch(1); break;
    case 73: stretch(0); break;
    case 74: stretch(-1); break;

    // --- GeomFill_Profiler::KnotsAndMults, the swallowed n = NbKnots()
    case 80: profiler(2, true); break;            // arrays the right length after Perform
    case 81: profiler(1, true); break;            // arrays SHORTER than NbKnots()
    case 82: profiler(2, false); break;           // no curves added at all

    // --- indirect reach through GeomConvert::SurfaceToBSplineSurface
    case 90: trimmedCylinderToBSpline(0, M_PI, 0, 10); break;        // baseline
    case 91: trimmedCylinderToBSpline(2 * M_PI, 0, 0, 10); break;    // the shape that crashes DIRECTLY
    case 92: trimmedCylinderToBSpline(M_PI, 0, 0, 10); break;
    case 93: trimmedCylinderToBSpline(1, 1, 0, 10); break;           // U1 == U2

    // --- indirect reach through Geom2dConvert::CurveToBSplineCurve
    case 95: hyperbolaCurveToBSpline(true, -1, 1); break;            // baseline
    case 96: hyperbolaCurveToBSpline(false, 0, 0); break;            // untrimmed, infinite bounds
    case 97: hyperbolaCurveToBSpline(true, 0, 800); break;           // trimmed but huge

    default: printf("  unknown mode\n"); return 2;
  }
  printf("== mode %d returned normally ==\n", mode);
  fflush(stdout);
  return 0;
}
