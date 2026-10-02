// Probe for OCCTSwift #2875, carried OCCT patch 0045.
//
// Grows a Bezier curve one pole at a time until InsertPoleAfter refuses, and reports the longest
// curve each constructor will build. Unpatched the two disagree; patched they do not.
//
// Build and run: Scripts/repro/2875-bezier-insertpole-bound/run.sh

#include <Geom2d_BezierCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <NCollection_Array1.hxx>
#include <Standard_Failure.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>

#include <cstdio>

// Longest curve the constructor accepts, found by bisection-free upward probing.
static int maxConstructed2d()
{
  int aBest = 0;
  for (int n = 2; n <= Geom2d_BezierCurve::MaxDegree() + 4; ++n)
  {
    NCollection_Array1<gp_Pnt2d> aPoles(1, n);
    for (int i = 1; i <= n; ++i)
    {
      aPoles(i) = gp_Pnt2d(i, 0.0);
    }
    try
    {
      Handle(Geom2d_BezierCurve) aCurve = new Geom2d_BezierCurve(aPoles);
      aBest                             = n;
    }
    catch (const Standard_Failure&)
    {
      break;
    }
  }
  return aBest;
}

static int maxConstructed3d()
{
  int aBest = 0;
  for (int n = 2; n <= Geom_BezierCurve::MaxDegree() + 4; ++n)
  {
    NCollection_Array1<gp_Pnt> aPoles(1, n);
    for (int i = 1; i <= n; ++i)
    {
      aPoles(i) = gp_Pnt(i, 0.0, 0.0);
    }
    try
    {
      Handle(Geom_BezierCurve) aCurve = new Geom_BezierCurve(aPoles);
      aBest                           = n;
    }
    catch (const Standard_Failure&)
    {
      break;
    }
  }
  return aBest;
}

static int maxGrown2d()
{
  NCollection_Array1<gp_Pnt2d> aPoles(1, 2);
  aPoles(1) = gp_Pnt2d(0.0, 0.0);
  aPoles(2) = gp_Pnt2d(1.0, 0.0);
  Handle(Geom2d_BezierCurve) aCurve = new Geom2d_BezierCurve(aPoles);
  for (int i = 0; i < 100; ++i)
  {
    try
    {
      aCurve->InsertPoleAfter(aCurve->NbPoles(), gp_Pnt2d(2.0 + i, 1.0), 1.0);
    }
    catch (const Standard_Failure&)
    {
      break;
    }
  }
  return aCurve->NbPoles();
}

static int maxGrown3d()
{
  NCollection_Array1<gp_Pnt> aPoles(1, 2);
  aPoles(1) = gp_Pnt(0.0, 0.0, 0.0);
  aPoles(2) = gp_Pnt(1.0, 0.0, 0.0);
  Handle(Geom_BezierCurve) aCurve = new Geom_BezierCurve(aPoles);
  for (int i = 0; i < 100; ++i)
  {
    try
    {
      aCurve->InsertPoleAfter(aCurve->NbPoles(), gp_Pnt(2.0 + i, 1.0, 0.0), 1.0);
    }
    catch (const Standard_Failure&)
    {
      break;
    }
  }
  return aCurve->NbPoles();
}

int main()
{
  const int aMaxDegree = Geom2d_BezierCurve::MaxDegree();
  const int aCtor2d    = maxConstructed2d();
  const int aGrown2d   = maxGrown2d();
  const int aCtor3d    = maxConstructed3d();
  const int aGrown3d   = maxGrown3d();

  std::printf("MaxDegree               = %d\n", aMaxDegree);
  std::printf("Geom2d ctor max poles   = %d\n", aCtor2d);
  std::printf("Geom2d insert max poles = %d\n", aGrown2d);
  std::printf("Geom   ctor max poles   = %d\n", aCtor3d);
  std::printf("Geom   insert max poles = %d\n", aGrown3d);

  // Whether the 2d class's Standard_ConstructionError_Raise_if survived the build flags: under
  // No_Exception it is compiled out and insertion is unbounded, which is #2801's mechanism.
  std::printf("Geom2d insert check live = %s\n",
              aGrown2d > aMaxDegree + 1 ? "no (No_Exception)" : "yes");

  // A curve at the constructor's own maximum must still answer every derived query, which is what
  // puts MaxDegree() + 1 poles in range for the static Multiplicities/KnotSequence tables.
  NCollection_Array1<gp_Pnt2d> aFull(1, aCtor2d);
  for (int i = 1; i <= aCtor2d; ++i)
  {
    aFull(i) = gp_Pnt2d(i, 0.0);
  }
  Handle(Geom2d_BezierCurve) aCurve = new Geom2d_BezierCurve(aFull);
  std::printf("Geom2d at ctor max: degree=%d mults=%d knotseq=%d\n",
              aCurve->Degree(),
              aCurve->Multiplicities().Length(),
              aCurve->KnotSequence().Length());

  // The 3d class throws literally rather than through the macro, so its bound is the one the
  // shipped kernel actually enforces and the one this probe scores.
  const bool anAgree = (aCtor3d == aGrown3d);
  std::printf("VERDICT: 3d ctor and insert %s\n", anAgree ? "AGREE" : "DISAGREE");
  return anAgree ? 0 : 1;
}
