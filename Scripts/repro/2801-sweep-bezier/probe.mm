// #2801 sweep, index-taking pole/weight/knot accessors.
//
// One mode per candidate call site, selected by argv[1]. Each mode runs in its own process so a
// SIGSEGV in one does not hide the rest. Compiled exactly as SwiftPM compiles the bridge: no
// -DNo_Exception, so a check written INLINE in a header is live here while a check written in an
// OCCT .cxx is absent from the linked kernel.
//
// See okf/policies/occt-validation-is-compiled-out.md.

#import <Foundation/Foundation.h>

#include <Geom2d_BezierCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_Direction.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <Standard_Failure.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>

#include <cstdio>
#include <typeinfo>
#include <cstdlib>
#include <cstring>

static Handle(Geom2d_BezierCurve) makeBezier2d(int nbPoles)
{
  NCollection_Array1<gp_Pnt2d> poles(1, nbPoles);
  for (int i = 1; i <= nbPoles; i++)
    poles.SetValue(i, gp_Pnt2d((double)(i - 1), (double)((i - 1) * (i - 1))));
  return new Geom2d_BezierCurve(poles);
}

static Handle(Geom2d_BezierCurve) makeRationalBezier2d(int nbPoles)
{
  NCollection_Array1<gp_Pnt2d> poles(1, nbPoles);
  NCollection_Array1<double>   w(1, nbPoles);
  for (int i = 1; i <= nbPoles; i++)
  {
    poles.SetValue(i, gp_Pnt2d((double)(i - 1), (double)((i - 1) * (i - 1))));
    w.SetValue(i, 1.0 + 0.1 * i);
  }
  return new Geom2d_BezierCurve(poles, w);
}

static Handle(Geom_BezierCurve) makeBezier3d(int nbPoles)
{
  NCollection_Array1<gp_Pnt> poles(1, nbPoles);
  for (int i = 1; i <= nbPoles; i++)
    poles.SetValue(i, gp_Pnt((double)(i - 1), (double)((i - 1) * (i - 1)), 0.0));
  return new Geom_BezierCurve(poles);
}

static Handle(Geom_BezierSurface) makeBezierSurface(int nu, int nv)
{
  NCollection_Array2<gp_Pnt> poles(1, nu, 1, nv);
  for (int i = 1; i <= nu; i++)
    for (int j = 1; j <= nv; j++)
      poles.SetValue(i, j, gp_Pnt((double)i, (double)j, (double)(i * j)));
  return new Geom_BezierSurface(poles);
}

#define TRY_BEGIN try {
#define TRY_END                                                                                    \
  }                                                                                                \
  catch (Standard_Failure const& f) { printf("  -> THREW %s: %s\n", typeid(f).name(), f.GetMessageString() ? f.GetMessageString() : "(no message)"); } \
  catch (...) { printf("  -> THREW (unknown)\n"); }

int main(int argc, const char* argv[])
{
  int mode = (argc > 1) ? atoi(argv[1]) : 0;
  printf("mode %d\n", mode);
  fflush(stdout);

  switch (mode)
  {
    // ---- mode 0: control. Confirms the linked kernel really is a No_Exception build. ----
    case 0:
    {
      printf("control A: Geom_Direction(0,0,0) -- out-of-line check, should NOT throw here\n");
      fflush(stdout);
      TRY_BEGIN
      Handle(Geom_Direction) d = new Geom_Direction(0.0, 0.0, 0.0);
      printf("  -> built, X()=%g\n", d->X());
      TRY_END
      fflush(stdout);
      printf("control B: Geom_BezierCurve::Pole(1000) -- LITERAL throw in .cxx, should THROW\n");
      fflush(stdout);
      TRY_BEGIN
      Handle(Geom_BezierCurve) b = makeBezier3d(4);
      gp_Pnt                   p = b->Pole(1000);
      printf("  -> NO THROW, pole = (%g, %g, %g)\n", p.X(), p.Y(), p.Z());
      TRY_END
      break;
    }

    // ---- mode 1: Geom2d_BezierCurve::Pole(Index), OOB high.  Bridge: OCCTCurve2DBezierGetPole ----
    case 1:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(4);
      printf("NbPoles=%d; calling Pole(1000000)\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      const gp_Pnt2d& p = b->Pole(1000000);
      printf("  -> NO THROW, pole = (%g, %g)\n", p.X(), p.Y());
      TRY_END
      break;
    }

    // ---- mode 2: Geom2d_BezierCurve::Pole(Index), small OOB (index 7 on a 4-pole curve) ----
    case 2:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(4);
      printf("NbPoles=%d; calling Pole(7) then Pole(0) then Pole(-3)\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      const gp_Pnt2d& p = b->Pole(7);
      printf("  -> Pole(7) NO THROW, = (%g, %g)\n", p.X(), p.Y());
      TRY_END
      fflush(stdout);
      TRY_BEGIN
      const gp_Pnt2d& p = b->Pole(0);
      printf("  -> Pole(0) NO THROW, = (%g, %g)\n", p.X(), p.Y());
      TRY_END
      fflush(stdout);
      TRY_BEGIN
      const gp_Pnt2d& p = b->Pole(-3);
      printf("  -> Pole(-3) NO THROW, = (%g, %g)\n", p.X(), p.Y());
      TRY_END
      break;
    }

    // ---- mode 3: Geom2d_BezierCurve::SetPole(Index, P), OOB write.  Bridge: OCCTCurve2DBezierSetPole ----
    case 3:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(4);
      printf("NbPoles=%d; calling SetPole(1000000, ...)\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->SetPole(1000000, gp_Pnt2d(42.0, 43.0));
      printf("  -> NO THROW, SetPole(1000000) accepted\n");
      TRY_END
      break;
    }

    // ---- mode 4: Geom2d_BezierCurve::SetPole, small OOB (index 6 on a 4-pole curve) ----
    case 4:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(4);
      printf("NbPoles=%d; SetPole(6, (42,43))\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->SetPole(6, gp_Pnt2d(42.0, 43.0));
      printf("  -> NO THROW, accepted; NbPoles now %d\n", b->NbPoles());
      gp_Pnt2d v = b->Value(0.5);
      printf("  -> Value(0.5) = (%g, %g)\n", v.X(), v.Y());
      TRY_END
      break;
    }

    // ---- mode 5: Geom2d_BezierCurve::SetWeight -- non-positive weight (ConstructionError in .cxx) ----
    case 5:
    {
      Handle(Geom2d_BezierCurve) b = makeRationalBezier2d(4);
      printf("rational, NbPoles=%d; SetWeight(2, 0.0) then SetWeight(3, -5.0)\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->SetWeight(2, 0.0);
      printf("  -> SetWeight(2, 0.0) NO THROW; Weight(2) = %g\n", b->Weight(2));
      TRY_END
      fflush(stdout);
      TRY_BEGIN
      b->SetWeight(3, -5.0);
      printf("  -> SetWeight(3, -5.0) NO THROW; Weight(3) = %g\n", b->Weight(3));
      gp_Pnt2d v = b->Value(0.5);
      printf("  -> Value(0.5) = (%g, %g)\n", v.X(), v.Y());
      TRY_END
      break;
    }

    // ---- mode 6: Geom2d_BezierCurve::SetWeight, OOB index.  Bridge: OCCTCurve2DBezierSetWeight ----
    case 6:
    {
      Handle(Geom2d_BezierCurve) b = makeRationalBezier2d(4);
      printf("rational, NbPoles=%d; SetWeight(1000000, 2.0)\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->SetWeight(1000000, 2.0);
      printf("  -> NO THROW, accepted\n");
      TRY_END
      break;
    }

    // ---- mode 7: Geom2d_BezierCurve::Weight(Index), OOB read (non-rational -> fabricated 1.0) ----
    case 7:
    {
      Handle(Geom2d_BezierCurve) nb = makeBezier2d(4);
      printf("non-rational NbPoles=%d; Weight(1000000)\n", nb->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      printf("  -> NO THROW, Weight(1000000) = %g\n", nb->Weight(1000000));
      TRY_END
      fflush(stdout);
      Handle(Geom2d_BezierCurve) rb = makeRationalBezier2d(4);
      printf("rational NbPoles=%d; Weight(1000000)\n", rb->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      printf("  -> NO THROW, Weight(1000000) = %g\n", rb->Weight(1000000));
      TRY_END
      break;
    }

    // ---- mode 8: Geom2d_BezierCurve::InsertPoleAfter, OOB.  Bridge: OCCTCurve2DBezierInsertPoleAfter ----
    case 8:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(4);
      printf("NbPoles=%d; InsertPoleAfter(1000000, ...)\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->InsertPoleAfter(1000000, gp_Pnt2d(9.0, 9.0));
      printf("  -> NO THROW, NbPoles now %d\n", b->NbPoles());
      TRY_END
      break;
    }

    // ---- mode 9: Geom2d_BezierCurve::InsertPoleAfter, small OOB (index 9 on a 4-pole curve) ----
    case 9:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(4);
      printf("NbPoles=%d; InsertPoleAfter(9, ...)\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->InsertPoleAfter(9, gp_Pnt2d(9.0, 9.0));
      printf("  -> NO THROW, NbPoles now %d\n", b->NbPoles());
      TRY_END
      break;
    }

    // ---- mode 10: Geom2d_BezierCurve::InsertPoleAfter, weight <= Resolution (ConstructionError) ----
    case 10:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(4);
      printf("NbPoles=%d; InsertPoleAfter(2, P, Weight=0.0)\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->InsertPoleAfter(2, gp_Pnt2d(9.0, 9.0), 0.0);
      printf("  -> NO THROW, NbPoles now %d, IsRational=%d\n", b->NbPoles(), (int)b->IsRational());
      gp_Pnt2d v = b->Value(0.5);
      printf("  -> Value(0.5) = (%g, %g)\n", v.X(), v.Y());
      TRY_END
      break;
    }

    // ---- mode 11: Geom2d_BezierCurve::RemovePole, OOB index.  Bridge: OCCTCurve2DBezierRemovePole ----
    case 11:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(4);
      printf("NbPoles=%d; RemovePole(1000000)\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->RemovePole(1000000);
      printf("  -> NO THROW, NbPoles now %d\n", b->NbPoles());
      TRY_END
      break;
    }

    // ---- mode 12: RemovePole past the nbpoles<=2 floor, twice: 2 -> 1 -> empty poles ----
    case 12:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(2);
      printf("NbPoles=%d (a straight-line Bezier)\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->RemovePole(1);
      printf("  -> after RemovePole(1): NbPoles=%d Degree=%d\n", b->NbPoles(), b->Degree());
      TRY_END
      fflush(stdout);
      TRY_BEGIN
      b->RemovePole(1);
      printf("  -> after 2nd RemovePole(1): NbPoles=%d\n", b->NbPoles());
      TRY_END
      fflush(stdout);
      printf("now reading Multiplicities() on that curve (ProgramError guard is in the .cxx)\n");
      fflush(stdout);
      TRY_BEGIN
      const NCollection_Array1<int>& m = b->Multiplicities();
      printf("  -> NO THROW, Multiplicities Length=%d, first=%d\n", m.Length(), m.Value(m.Lower()));
      TRY_END
      break;
    }

    // ---- mode 13: Geom2d_BezierCurve::Increase(Deg) with Deg < Degree (ConstructionError) ----
    case 13:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(6);  // degree 5
      printf("Degree=%d; Increase(2)\n", b->Degree());
      fflush(stdout);
      TRY_BEGIN
      b->Increase(2);
      printf("  -> NO THROW, Degree now %d NbPoles %d\n", b->Degree(), b->NbPoles());
      TRY_END
      break;
    }

    // ---- mode 14: Geom2d_BezierCurve::Increase(Deg) with Deg > MaxDegree ----
    case 14:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(4);
      printf("Degree=%d MaxDegree=%d; Increase(MaxDegree+50)\n",
             b->Degree(),
             Geom2d_BezierCurve::MaxDegree());
      fflush(stdout);
      TRY_BEGIN
      b->Increase(Geom2d_BezierCurve::MaxDegree() + 50);
      printf("  -> NO THROW, Degree now %d NbPoles %d\n", b->Degree(), b->NbPoles());
      TRY_END
      break;
    }

    // ---- mode 15: Geom2d_BezierCurve::Increase(-5) ----
    case 15:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(4);
      printf("Degree=%d; Increase(-5)\n", b->Degree());
      fflush(stdout);
      TRY_BEGIN
      b->Increase(-5);
      printf("  -> NO THROW, Degree now %d NbPoles %d\n", b->Degree(), b->NbPoles());
      TRY_END
      break;
    }

    // ---- mode 16: Geom_BezierSurface::Pole(U,V), OOB.  Bridge: OCCTSurfaceBezierGetPole ----
    case 16:
    {
      Handle(Geom_BezierSurface) s = makeBezierSurface(3, 4);
      printf("NbUPoles=%d NbVPoles=%d; Pole(1000000, 1)\n", s->NbUPoles(), s->NbVPoles());
      fflush(stdout);
      TRY_BEGIN
      const gp_Pnt& p = s->Pole(1000000, 1);
      printf("  -> NO THROW, = (%g, %g, %g)\n", p.X(), p.Y(), p.Z());
      TRY_END
      break;
    }

    // ---- mode 17: Geom_BezierSurface::Pole(U,V), small OOB (5,7 on a 3x4 grid) ----
    case 17:
    {
      Handle(Geom_BezierSurface) s = makeBezierSurface(3, 4);
      printf("NbUPoles=%d NbVPoles=%d; Pole(5,7) then Pole(0,0) then Pole(-4,-4)\n",
             s->NbUPoles(),
             s->NbVPoles());
      fflush(stdout);
      TRY_BEGIN
      const gp_Pnt& p = s->Pole(5, 7);
      printf("  -> Pole(5,7) NO THROW, = (%g, %g, %g)\n", p.X(), p.Y(), p.Z());
      TRY_END
      fflush(stdout);
      TRY_BEGIN
      const gp_Pnt& p = s->Pole(0, 0);
      printf("  -> Pole(0,0) NO THROW, = (%g, %g, %g)\n", p.X(), p.Y(), p.Z());
      TRY_END
      fflush(stdout);
      TRY_BEGIN
      const gp_Pnt& p = s->Pole(-4, -4);
      printf("  -> Pole(-4,-4) NO THROW, = (%g, %g, %g)\n", p.X(), p.Y(), p.Z());
      TRY_END
      break;
    }

    // ---- mode 18: Geom_BezierSurface::SetPole / SetWeight -- LITERAL throws, expect THROW ----
    case 18:
    {
      Handle(Geom_BezierSurface) s = makeBezierSurface(3, 4);
      printf("NbUPoles=%d NbVPoles=%d; SetPole(1000000,1,...) then SetWeight(1,1,-3)\n",
             s->NbUPoles(),
             s->NbVPoles());
      fflush(stdout);
      TRY_BEGIN
      s->SetPole(1000000, 1, gp_Pnt(1, 2, 3));
      printf("  -> SetPole NO THROW (unexpected)\n");
      TRY_END
      fflush(stdout);
      TRY_BEGIN
      s->SetWeight(1, 1, -3.0);
      printf("  -> SetWeight(-3) NO THROW (unexpected)\n");
      TRY_END
      break;
    }

    // ---- mode 19: Geom_BezierSurface::Weight(U,V), OOB (no bridge caller; kernel record only) ----
    case 19:
    {
      Handle(Geom_BezierSurface) s = makeBezierSurface(3, 4);
      printf("NbUPoles=%d NbVPoles=%d; Weight(1000000, 1)\n", s->NbUPoles(), s->NbVPoles());
      fflush(stdout);
      TRY_BEGIN
      printf("  -> NO THROW, Weight = %g\n", s->Weight(1000000, 1));
      TRY_END
      break;
    }

    // ---- mode 20: Geom_BezierCurve (3D) index members -- LITERAL throws, expect THROW ----
    case 20:
    {
      Handle(Geom_BezierCurve) b = makeBezier3d(4);
      printf("3D NbPoles=%d; SetPole(1000000,..) / SetWeight(1000000,2) / RemovePole(1000000)\n",
             b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->SetPole(1000000, gp_Pnt(1, 2, 3));
      printf("  -> SetPole NO THROW (unexpected)\n");
      TRY_END
      fflush(stdout);
      TRY_BEGIN
      b->SetWeight(1000000, 2.0);
      printf("  -> SetWeight NO THROW (unexpected)\n");
      TRY_END
      fflush(stdout);
      TRY_BEGIN
      b->RemovePole(1000000);
      printf("  -> RemovePole NO THROW (unexpected)\n");
      TRY_END
      fflush(stdout);
      TRY_BEGIN
      b->Increase(2);
      printf("  -> Increase(2) below current degree NO THROW\n");
      TRY_END
      break;
    }

    // ---- mode 21: SetPole with a far index, to see whether the wild write faults ----
    case 21:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(4);
      printf("NbPoles=%d; SetPole(1 << 28, ...) -- a 4 GiB offset past the array\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->SetPole(1 << 28, gp_Pnt2d(42.0, 43.0));
      printf("  -> NO THROW, accepted\n");
      TRY_END
      break;
    }

    // ---- mode 22: mode 12 split -- one RemovePole below the floor, then Multiplicities() ----
    case 22:
    {
      Handle(Geom2d_BezierCurve) b = makeBezier2d(2);
      printf("NbPoles=%d; RemovePole(1) (the nbpoles<=2 guard is in the .cxx)\n", b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->RemovePole(1);
      printf("  -> NO THROW, NbPoles=%d Degree=%d\n", b->NbPoles(), b->Degree());
      TRY_END
      fflush(stdout);
      printf("Multiplicities() on the 1-pole curve\n");
      fflush(stdout);
      TRY_BEGIN
      const NCollection_Array1<int>& m = b->Multiplicities();
      printf("  -> NO THROW, Length=%d first=%d\n", m.Length(), m.Value(m.Lower()));
      TRY_END
      fflush(stdout);
      printf("Value(0.5) on the 1-pole curve\n");
      fflush(stdout);
      TRY_BEGIN
      gp_Pnt2d v = b->Value(0.5);
      printf("  -> NO THROW, = (%g, %g)\n", v.X(), v.Y());
      TRY_END
      break;
    }

    // ---- mode 23: SetPole just past the end -- is an adjacent heap object clobbered? ----
    case 23:
    {
      Handle(Geom2d_BezierCurve) b      = makeBezier2d(4);
      double*                    canary = (double*)malloc(64 * sizeof(double));
      for (int i = 0; i < 64; i++)
        canary[i] = 7.0;
      printf("NbPoles=%d; SetPole(5) and SetPole(6) past the end of a 4-slot array\n",
             b->NbPoles());
      fflush(stdout);
      TRY_BEGIN
      b->SetPole(5, gp_Pnt2d(-1.0e300, -2.0e300));
      b->SetPole(6, gp_Pnt2d(-3.0e300, -4.0e300));
      printf("  -> NO THROW; NbPoles still %d, Value(0.5) = (%g, %g)\n",
             b->NbPoles(),
             b->Value(0.5).X(),
             b->Value(0.5).Y());
      TRY_END
      fflush(stdout);
      int clobbered = 0;
      for (int i = 0; i < 64; i++)
        if (canary[i] != 7.0)
        {
          printf("  -> canary[%d] clobbered: %g\n", i, canary[i]);
          clobbered++;
        }
      printf("  -> %d canary slots clobbered\n", clobbered);
      break;
    }

    default:
      printf("unknown mode\n");
      return 2;
  }

  printf("mode %d completed without a fatal signal\n", mode);
  fflush(stdout);
  return 0;
}
