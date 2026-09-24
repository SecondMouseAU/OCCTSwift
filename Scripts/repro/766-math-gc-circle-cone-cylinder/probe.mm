// Kernel parity probe for GCMakeCircleTests, GCMakeConicalSurfaceTests and
// GCMakeCylindricalSurfaceTests (#1983): the GC_MakeCircle / GC_MakeConicalSurface /
// GC_MakeCylindricalSurface calls the OCCTGCMake* bridge functions make, with each test's inputs.
#include <GC_MakeCircle.hxx>
#include <GC_MakeConicalSurface.hxx>
#include <GC_MakeCylindricalSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Standard_Failure.hxx>
#include <gp_Circ.hxx>
#include <gp_Cylinder.hxx>
#include <cmath>
#include <cstdio>

static void pr(const char* tag, const gp_Pnt& p)
{
  printf("%s (%.12g, %.12g, %.12g)\n", tag, p.X(), p.Y(), p.Z());
}

static void circ(const char* tag, GC_MakeCircle& mc)
{
  printf("%s done=%d", tag, mc.IsDone());
  if (!mc.IsDone())
  {
    printf("\n");
    return;
  }
  Handle(Geom_Circle) c = mc.Value();
  printf(" radius=%.12g closed=%d\n", c->Radius(), c->IsClosed());
  pr("  center", c->Location());
  pr("  P(0)", c->Value(0));
  pr("  P(pi/2)", c->Value(M_PI / 2));
}

static void cyl(const char* tag, GC_MakeCylindricalSurface& mc)
{
  printf("%s done=%d", tag, mc.IsDone());
  if (!mc.IsDone())
  {
    printf(" status=%d\n", (int)mc.Status());
    return;
  }
  Handle(Geom_CylindricalSurface) s = mc.Value();
  gp_Dir                          d = s->Position().Direction();
  printf(" radius=%.12g axis (%.12g, %.12g, %.12g)\n", s->Radius(), d.X(), d.Y(), d.Z());
  pr("  location", s->Location());
  pr("  S(0,0)", s->Value(0, 0));
  pr("  S(pi/2,3)", s->Value(M_PI / 2, 3));
}

int main()
{
  gp_Ax2 z(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  {
    GC_MakeCircle mc(z, 5);
    circ("circleFromAxisAndRadius", mc);
  }
  {
    GC_MakeCircle mc(gp_Pnt(1, 0, 0), gp_Pnt(0, 1, 0), gp_Pnt(-1, 0, 0));
    circ("circleFrom3Points", mc);
  }
  {
    GC_MakeCircle mc(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1), 10);
    circ("circleCenterNormal", mc);
  }
  {
    GC_MakeCircle mc(gp_Circ(z, 5), 3);
    circ("circleParallel (radius 5, dist 3)", mc);
    GC_MakeCircle mn(gp_Circ(z, 5), -3);
    circ("circleParallel with dist -3", mn);
  }
  {
    GC_MakeConicalSurface       mc(z, M_PI / 6, 5);
    Handle(Geom_ConicalSurface) s = mc.Value();
    printf("conicalFromAxisAngleRadius done=%d semiAngle=%.15g refRadius=%.12g\n",
           mc.IsDone(), s->SemiAngle(), s->RefRadius());
    pr("  S(0,1)", s->Value(0, 1));
  }
  {
    GC_MakeConicalSurface       mc(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), 5, 2);
    Handle(Geom_ConicalSurface) s = mc.Value();
    printf("conicalFrom2PtsRadii done=%d semiAngle=%.15g refRadius=%.12g\n",
           mc.IsDone(), s->SemiAngle(), s->RefRadius());
    pr("  S(0,0)", s->Value(0, 0));
  }
  {
    try
    {
      GC_MakeConicalSurface mc(gp_Pnt(5, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(2, 0, 10), gp_Pnt(0, 2, 10));
      printf("conicalFrom4Pts done=%d status=%d\n", mc.IsDone(), (int)mc.Status());
    }
    catch (const Standard_Failure& e)
    {
      printf("conicalFrom4Pts throws %s\n", e.ExceptionType());
    }
  }
  {
    GC_MakeCylindricalSurface mc(z, 5);
    cyl("cylindricalFromAxisRadius", mc);
  }
  {
    GC_MakeCylindricalSurface mc(gp_Pnt(5, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(-5, 0, 0));
    cyl("cylindricalFrom3Pts", mc);
  }
  {
    GC_MakeCylindricalSurface mc(gp_Circ(z, 5));
    cyl("cylindricalFromCircle", mc);
  }
  {
    GC_MakeCylindricalSurface mc(gp_Cylinder(gp_Ax3(z), 5), 2);
    cyl("cylindricalParallel (radius 5, dist 2)", mc);
  }
  {
    GC_MakeCylindricalSurface mc(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    cyl("cylindricalFromAxis", mc);
  }
  return 0;
}
