// Kernel parity probe for GCMakeEllipseTests, GCMakeHyperbolaTests, GCMakeTrimmedConeTests,
// GCMakeTrimmedCylinderTests and GeomDirectionTests (#1983), plus the valid four-point cone the
// rewritten conicalFrom4Pts test adds. Each block mirrors the bridge function the test reaches.
#include <GC_MakeConicalSurface.hxx>
#include <GC_MakeEllipse.hxx>
#include <GC_MakeHyperbola.hxx>
#include <GC_MakeTrimmedCone.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_Direction.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <gp_Circ.hxx>
#include <cmath>
#include <cstdio>

static void pr(const char* tag, const gp_Pnt& p)
{
  printf("%s (%.12g, %.12g, %.12g)\n", tag, p.X(), p.Y(), p.Z());
}

static void trimmed(const char* tag, bool done, const Handle(Geom_RectangularTrimmedSurface)& s,
                    int status)
{
  printf("%s done=%d", tag, done);
  if (!done)
  {
    printf(" status=%d\n", status);
    return;
  }
  double u1, u2, v1, v2;
  s->Bounds(u1, u2, v1, v2);
  printf(" bounds u [%.12g, %.12g] v [%.12g, %.12g]\n", u1, u2, v1, v2);
  pr("  S(u1,v1)", s->Value(u1, v1));
  pr("  S(u1,v2)", s->Value(u1, v2));
}

int main()
{
  gp_Ax2 z(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  {
    GC_MakeEllipse       me(z, 10, 5);
    Handle(Geom_Ellipse) e = me.Value();
    printf("ellipseFromAxisAndRadii done=%d closed=%d major=%.12g minor=%.12g\n",
           me.IsDone(), e->IsClosed(), e->MajorRadius(), e->MinorRadius());
    pr("  P(0)", e->Value(0));
    pr("  P(pi/2)", e->Value(M_PI / 2));
  }
  {
    GC_MakeEllipse       me(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)), 10, 5);
    Handle(Geom_Ellipse) e = me.Value();
    printf("ellipseFromFullAx2 done=%d closed=%d\n", me.IsDone(), e->IsClosed());
    pr("  P(0)", e->Value(0));
    pr("  P(pi/2)", e->Value(M_PI / 2));
  }
  {
    GC_MakeHyperbola       mh(z, 10, 5);
    Handle(Geom_Hyperbola) h = mh.Value();
    printf("hyperbolaFromAxisAndRadii done=%d major=%.12g minor=%.12g\n",
           mh.IsDone(), h->MajorRadius(), h->MinorRadius());
    pr("  P(0)", h->Value(0));
    pr("  P(1)", h->Value(1));
  }
  {
    GC_MakeTrimmedCone mc(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), 5, 2);
    trimmed("trimmedCone2Pts", mc.IsDone(), mc.IsDone() ? mc.Value() : nullptr, (int)mc.Status());
  }
  {
    GC_MakeTrimmedCone mc(gp_Pnt(5, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(2, 0, 10), gp_Pnt(0, 2, 10));
    trimmed("trimmedCone4Pts", mc.IsDone(), mc.IsDone() ? mc.Value() : nullptr, (int)mc.Status());
  }
  {
    GC_MakeTrimmedCylinder mc(gp_Circ(z, 5), 10);
    trimmed("trimmedCylinderCircle", mc.IsDone(), mc.IsDone() ? mc.Value() : nullptr,
            (int)mc.Status());
  }
  {
    GC_MakeTrimmedCylinder mc(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5, 10);
    trimmed("trimmedCylinderAxis", mc.IsDone(), mc.IsDone() ? mc.Value() : nullptr,
            (int)mc.Status());
  }
  {
    GC_MakeTrimmedCylinder mc(gp_Pnt(5, 0, 0), gp_Pnt(5, 0, 10), gp_Pnt(0, 5, 0));
    trimmed("trimmedCylinder3Pts", mc.IsDone(), mc.IsDone() ? mc.Value() : nullptr,
            (int)mc.Status());
  }
  {
    // The valid four-point cone the rewritten conicalFrom4Pts test adds: axis through P1 and P2,
    // P3 and P4 on the surface at radii 5 and 2.
    GC_MakeConicalSurface mc(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), gp_Pnt(5, 0, 0), gp_Pnt(2, 0, 10));
    printf("conicalFrom4Pts valid done=%d", mc.IsDone());
    if (mc.IsDone())
    {
      Handle(Geom_ConicalSurface) s = mc.Value();
      printf(" semiAngle=%.15g refRadius=%.12g\n", s->SemiAngle(), s->RefRadius());
      pr("  location", s->Location());
      pr("  S(0,0)", s->Value(0, 0));
    }
    else
      printf(" status=%d\n", (int)mc.Status());
  }
  {
    Handle(Geom_Direction) d = new Geom_Direction(0, 0, 1);
    printf("create (%.12g, %.12g, %.12g)\n", d->X(), d->Y(), d->Z());
    Handle(Geom_Direction) n = new Geom_Direction(3, 4, 0);
    printf("normalizes (%.12g, %.12g, %.12g)\n", n->X(), n->Y(), n->Z());
    Handle(Geom_Direction) dx = new Geom_Direction(1, 0, 0);
    Handle(Geom_Direction) dy = new Geom_Direction(0, 1, 0);
    Handle(Geom_Vector)    c  = dx->Crossed(dy);
    printf("crossed (%.12g, %.12g, %.12g)\n", c->X(), c->Y(), c->Z());
    Handle(Geom_Direction) s = new Geom_Direction(1, 0, 0);
    s->SetCoord(0, 1, 0);
    printf("setCoordinates (%.12g, %.12g, %.12g)\n", s->X(), s->Y(), s->Z());
  }
  return 0;
}
