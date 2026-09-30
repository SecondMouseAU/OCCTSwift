// #2884: adjudicate the four open `#ifndef No_Exception` regions against the bridge.
//
// Each mode runs in its own process (see run.sh), because several of them fault and a fault in
// one case must not hide the result of the next. The probe mirrors what the bridge actually does
// at the call site it actually has, so a mode number maps to a bridge entry point and not to a
// hypothetical one.
//
//   modes  1-12  Convert_EllipseToBSplineCurve(E, UFirst, ULast), the ONLY one of the three
//                Convert rows the bridge reaches with caller values
//                (OCCTBridge_Geom2d_Conversion.mm:760, OCCTConvertEllipseToBSpline2D).
//   modes 20-23  Convert_SphereToBSplineSurface / Convert_TorusToBSplineSurface, the 1-argument
//                constructors the bridge calls (no dead region) beside the 4-argument ones that
//                hold it (no bridge caller), to show the second is a different overload.
//   modes 30-34  GeomFill_Profiler::KnotsAndMults and ::Poles, driven the way
//                OCCTGeomFillProfilerKnotsAndMults / OCCTGeomFillProfilerPoles drive them.
//
// Build and run: Scripts/repro/2884/run.sh

#include <Convert_EllipseToBSplineCurve.hxx>
#include <Convert_SphereToBSplineSurface.hxx>
#include <Convert_TorusToBSplineSurface.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GeomFill_Profiler.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <GC_MakeSegment.hxx>
#include <NCollection_Array1.hxx>
#include <Precision.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <gp_Ax22d.hxx>
#include <gp_Ax3.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>

// A copy of OCCTBridge_Geom2d_Conversion.mm's buildCurve2DFromConic, so the probe measures the
// bridge's whole path and not just the constructor.
static Handle(Geom2d_BSplineCurve) buildCurve2DFromConic(const Convert_ConicToBSplineCurve& conv)
{
  int                     np = conv.NbPoles(), nk = conv.NbKnots(), deg = conv.Degree();
  printf("    NbPoles=%d NbKnots=%d Degree=%d\n", np, nk, deg);
  fflush(stdout);
  TColgp_Array1OfPnt2d    poles(1, np);
  TColStd_Array1OfReal    weights(1, np), knots(1, nk);
  TColStd_Array1OfInteger mults(1, nk);
  const TColgp_Array1OfPnt2d&    convPoles   = conv.Poles();
  const TColStd_Array1OfReal&    convWeights = conv.Weights();
  const TColStd_Array1OfReal&    convKnots   = conv.Knots();
  const TColStd_Array1OfInteger& convMults   = conv.Multiplicities();
  for (int i = 1; i <= np; i++)
  {
    poles(i)   = convPoles.Value(i);
    weights(i) = convWeights.Value(i);
  }
  for (int i = 1; i <= nk; i++)
  {
    knots(i) = convKnots.Value(i);
    mults(i) = convMults.Value(i);
  }
  return new Geom2d_BSplineCurve(poles, weights, knots, mults, deg);
}

static void ellipseCase(double u1, double u2)
{
  const double delta = u2 - u1;
  printf("  u1=%.17g u2=%.17g delta=%.17g (delta/pi=%.6g)\n", u1, u2, delta, delta / M_PI);
  printf("  kernel Raise_if would fire: %s\n",
         ((delta > (2 * M_PI + Precision::PConfusion())) || (delta <= 0.0)) ? "YES" : "no");
  fflush(stdout);
  try
  {
    gp_Elips2d                    e(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0), gp_Dir2d(0, 1)), 5, 3);
    Convert_EllipseToBSplineCurve conv(e, u1, u2);
    Handle(Geom2d_BSplineCurve)   c = buildCurve2DFromConic(conv);
    if (c.IsNull())
    {
      printf("  RESULT: null curve\n");
      return;
    }
    gp_Pnt2d p0 = c->Value(c->FirstParameter());
    gp_Pnt2d p1 = c->Value(c->LastParameter());
    printf("  RESULT: curve, first=[%.17g %.17g] last=[%.17g %.17g] range=[%.17g %.17g]\n",
           p0.X(), p0.Y(), p1.X(), p1.Y(), c->FirstParameter(), c->LastParameter());
  }
  catch (const Standard_Failure& f)
  {
    printf("  RESULT: Standard_Failure: %s\n", f.GetMessageString() ? f.GetMessageString() : "");
  }
  catch (...)
  {
    printf("  RESULT: non-Standard_Failure exception\n");
  }
}

static Handle(Geom_Curve) segment(double z)
{
  return GC_MakeSegment(gp_Pnt(0, 0, z), gp_Pnt(10, 0, z)).Value();
}

// The bridge's own shape: both arrays sized to exactly NbKnots().
static void profilerBridgeShape()
{
  GeomFill_Profiler profiler;
  profiler.AddCurve(segment(0));
  profiler.AddCurve(segment(1));
  profiler.Perform(1e-6);
  int nKnots = profiler.NbKnots();
  printf("  NbKnots=%d NbPoles=%d\n", nKnots, profiler.NbPoles());
  NCollection_Array1<double> knots(1, nKnots);
  NCollection_Array1<int>    mults(1, nKnots);
  profiler.KnotsAndMults(knots, mults);
  printf("  RESULT: knots[1]=%.17g knots[%d]=%.17g mults[1]=%d\n",
         knots(1), nKnots, knots(nKnots), mults(1));
}

// A deliberately short array, which is exactly what the dead region's condition was testing.
static void profilerShortArrays(int shrinkBy)
{
  GeomFill_Profiler profiler;
  profiler.AddCurve(segment(0));
  profiler.AddCurve(segment(1));
  profiler.Perform(1e-6);
  int nKnots = profiler.NbKnots();
  int n      = nKnots - shrinkBy;
  printf("  NbKnots=%d, passing arrays of length %d\n", nKnots, n);
  fflush(stdout);
  NCollection_Array1<double> knots(1, n);
  NCollection_Array1<int>    mults(1, n);
  profiler.KnotsAndMults(knots, mults);
  printf("  RESULT: returned. knots.Length() now %d, mults.Length() now %d\n",
         knots.Length(), mults.Length());
  printf("  knots(1)=%.17g\n", knots(1));
}

static void profilerPolesIndex(int index)
{
  GeomFill_Profiler profiler;
  profiler.AddCurve(segment(0));
  profiler.AddCurve(segment(1));
  profiler.Perform(1e-6);
  int nPoles = profiler.NbPoles();
  printf("  2 curves in the profiler, NbPoles=%d, asking for curve index %d\n", nPoles, index);
  fflush(stdout);
  NCollection_Array1<gp_Pnt> poles(1, nPoles);
  profiler.Poles(index, poles);
  printf("  RESULT: returned. poles(1)=[%.17g %.17g %.17g]\n",
         poles(1).X(), poles(1).Y(), poles(1).Z());
}

int main(int argc, char** argv)
{
  int mode = argc > 1 ? atoi(argv[1]) : 0;
  switch (mode)
  {
    // --- Convert_EllipseToBSplineCurve, the bridge's own call, u1/u2 caller-controlled ---
    case 1:
      printf("[1] ellipse, valid half turn (control)\n");
      ellipseCase(0, M_PI);
      break;
    case 2:
      printf("[2] ellipse, delta exactly 0 (the Raise_if's `delta <= 0` boundary)\n");
      ellipseCase(1, 1);
      break;
    case 3:
      printf("[3] ellipse, small negative delta\n");
      ellipseCase(0, -1);
      break;
    case 4:
      printf("[4] ellipse, delta = -pi\n");
      ellipseCase(M_PI, 0);
      break;
    case 5:
      printf("[5] ellipse, delta = -2pi (two adjacent arguments swapped)\n");
      ellipseCase(2 * M_PI, 0);
      break;
    case 6:
      printf("[6] ellipse, delta = -6 (past -5pi/3, where num_spans goes negative)\n");
      ellipseCase(6, 0);
      break;
    case 7:
      printf("[7] ellipse, delta = -100\n");
      ellipseCase(100, 0);
      break;
    case 8:
      printf("[8] ellipse, delta exactly 2pi (the Raise_if lets this through)\n");
      ellipseCase(0, 2 * M_PI);
      break;
    case 9:
      printf("[9] ellipse, delta just past 2pi + PConfusion\n");
      ellipseCase(0, 2 * M_PI + 1e-6);
      break;
    case 10:
      printf("[10] ellipse, delta = 12 (well past 2pi)\n");
      ellipseCase(0, 12);
      break;
    case 11:
      printf("[11] ellipse, delta = 1e9\n");
      ellipseCase(0, 1e9);
      break;
    case 12:
      printf("[12] ellipse, u2 = NaN\n");
      ellipseCase(0, std::nan(""));
      break;

    // --- Convert_Sphere / Convert_Torus: which overload the bridge calls ---
    case 20:
    {
      printf("[20] Convert_SphereToBSplineSurface(Sph), the 1-arg ctor the bridge calls\n");
      gp_Sphere                      s(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
      Convert_SphereToBSplineSurface conv(s);
      printf("  RESULT: NbUPoles=%d NbVPoles=%d\n", conv.NbUPoles(), conv.NbVPoles());
      break;
    }
    case 21:
    {
      printf("[21] Convert_TorusToBSplineSurface(T), the 1-arg ctor the bridge calls\n");
      gp_Torus                      t(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10, 3);
      Convert_TorusToBSplineSurface conv(t);
      printf("  RESULT: NbUPoles=%d NbVPoles=%d\n", conv.NbUPoles(), conv.NbVPoles());
      break;
    }
    case 22:
    {
      printf("[22] Convert_SphereToBSplineSurface(Sph, P1, P2, UTrim), the 4-arg ctor holding the\n"
             "     dead region, delta = -2pi. NO BRIDGE CALLER; this is what one would cost.\n");
      fflush(stdout);
      gp_Sphere                      s(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
      Convert_SphereToBSplineSurface conv(s, 2 * M_PI, 0.0, true);
      printf("  RESULT: NbUPoles=%d NbVPoles=%d\n", conv.NbUPoles(), conv.NbVPoles());
      break;
    }
    case 23:
    {
      printf("[23] Convert_TorusToBSplineSurface(T, P1, P2, UTrim), the 4-arg ctor holding the\n"
             "     dead region, delta = -2pi. NO BRIDGE CALLER.\n");
      fflush(stdout);
      gp_Torus                      t(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10, 3);
      Convert_TorusToBSplineSurface conv(t, 2 * M_PI, 0.0, true);
      printf("  RESULT: NbUPoles=%d NbVPoles=%d\n", conv.NbUPoles(), conv.NbVPoles());
      break;
    }

    // --- GeomFill_Profiler ---
    case 30:
      printf("[30] profiler KnotsAndMults, arrays sized NbKnots() (what the bridge does)\n");
      profilerBridgeShape();
      break;
    case 31:
      printf("[31] profiler KnotsAndMults, arrays one SHORT (what the dead region tested for)\n");
      profilerShortArrays(1);
      break;
    case 32:
      printf("[32] profiler KnotsAndMults, arrays NbKnots()-1 short by 1 with a length readback\n");
      profilerShortArrays(1);
      break;
    case 33:
      printf("[33] profiler Poles with curveIndex past the end (bridge passes it unchecked)\n");
      profilerPolesIndex(5);
      break;
    case 34:
      printf("[34] profiler Poles with curveIndex 0\n");
      profilerPolesIndex(0);
      break;
    case 35:
      printf("[35] profiler Poles with curveIndex 1000000\n");
      profilerPolesIndex(1000000);
      break;
    case 36:
    {
      printf("[36] profiler Perform() with NO curves added, then the accessors the bridge exposes\n");
      fflush(stdout);
      GeomFill_Profiler profiler;
      profiler.Perform(1e-6);
      printf("  Perform returned\n");
      fflush(stdout);
      printf("  NbKnots=%d\n", profiler.NbKnots());
      break;
    }
    case 37:
    {
      printf("[37] profiler Curve(Index) out of range: is NCollection_Sequence's INLINE check\n"
             "     live in this (non-kernel) translation unit?\n");
      fflush(stdout);
      GeomFill_Profiler profiler;
      profiler.AddCurve(segment(0));
      profiler.AddCurve(segment(1));
      profiler.Perform(1e-6);
      try
      {
        const Handle(Geom_Curve)& c = profiler.Curve(0);
        printf("  RESULT: Curve(0) returned without throwing, IsNull=%d\n", (int)c.IsNull());
      }
      catch (const Standard_Failure& f)
      {
        printf("  RESULT: Curve(0) threw %s\n", f.GetMessageString() ? f.GetMessageString() : "");
      }
      break;
    }

    case 38:
    {
      printf("[38] profiler Perform() with exactly ONE curve: where the boundary is\n");
      fflush(stdout);
      GeomFill_Profiler profiler;
      profiler.AddCurve(segment(0));
      profiler.Perform(1e-6);
      printf("  RESULT: Perform returned, NbKnots=%d NbPoles=%d\n",
             profiler.NbKnots(), profiler.NbPoles());
      break;
    }

    default:
      printf("usage: probe <mode>\n");
      return 2;
  }
  printf("[mode %d] completed normally\n", mode);
  fflush(stdout);
  return 0;
}
