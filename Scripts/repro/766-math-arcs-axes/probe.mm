// Kernel parity probe for ArcOfHyperbolaTests, ArcOfParabolaTests, Axis1PlacementTests and
// Axis2PlacementTests (#1983). Each block mirrors the bridge function the test reaches, with the
// test's own inputs.
#include <GC_MakeArcOfHyperbola.hxx>
#include <GC_MakeArcOfParabola.hxx>
#include <Geom_Axis1Placement.hxx>
#include <Geom_Axis2Placement.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <gp_Hypr.hxx>
#include <gp_Parab.hxx>
#include <cstdio>

static void pr(const char* tag, const gp_XYZ& p)
{
  printf("%s (%.12g, %.12g, %.12g)\n", tag, p.X(), p.Y(), p.Z());
}

int main()
{
  { // arcOfHyperbola: OCCTCurve3DArcOfHyperbola
    gp_Ax2                    ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Hypr                   h(ax, 5.0, 3.0);
    GC_MakeArcOfHyperbola     mk(h, -1.0, 1.0, Standard_True);
    Handle(Geom_TrimmedCurve) c = mk.Value();
    printf("arcOfHyperbola domain [%.12g, %.12g]\n", c->FirstParameter(), c->LastParameter());
    pr("arcOfHyperbola start", c->Value(c->FirstParameter()).XYZ());
    pr("arcOfHyperbola end", c->Value(c->LastParameter()).XYZ());
  }
  { // arcOfParabola: OCCTCurve3DArcOfParabola
    gp_Ax2                    ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Parab                  p(ax, 2.0);
    GC_MakeArcOfParabola      mk(p, -3.0, 3.0, Standard_True);
    Handle(Geom_TrimmedCurve) c = mk.Value();
    printf("arcOfParabola domain [%.12g, %.12g]\n", c->FirstParameter(), c->LastParameter());
    pr("arcOfParabola point(0)", c->Value(0.0).XYZ());
    pr("arcOfParabola start", c->Value(c->FirstParameter()).XYZ());
    pr("arcOfParabola end", c->Value(c->LastParameter()).XYZ());
  }
  { // Axis1Placement: OCCTAxis1PlacementCreate / Location / Direction / Reverse / Reversed / Set*
    Handle(Geom_Axis1Placement) a = new Geom_Axis1Placement(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1));
    pr("ax1 createAndRead location", a->Location().XYZ());
    pr("ax1 createAndRead direction", a->Direction().XYZ());
    Handle(Geom_Axis1Placement) b = new Geom_Axis1Placement(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    b->Reverse();
    pr("ax1 reverse direction", b->Direction().XYZ());
    Handle(Geom_Axis1Placement) c = new Geom_Axis1Placement(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0));
    Handle(Geom_Axis1Placement) r = Handle(Geom_Axis1Placement)::DownCast(c->Reversed());
    pr("ax1 reversedCopy reversed direction", r->Direction().XYZ());
    pr("ax1 reversedCopy original direction", c->Direction().XYZ());
    Handle(Geom_Axis1Placement) d = new Geom_Axis1Placement(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    d->SetDirection(gp_Dir(0, 1, 0));
    d->SetLocation(gp_Pnt(5, 5, 5));
    pr("ax1 setters direction", d->Direction().XYZ());
    pr("ax1 setters location", d->Location().XYZ());
  }
  { // Axis2Placement: OCCTAxis2PlacementCreate / Direction / XDirection / YDirection / Set*
    Handle(Geom_Axis2Placement) a =
      new Geom_Axis2Placement(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    pr("ax2 createAndRead xDirection", a->XDirection().XYZ());
    pr("ax2 createAndRead yDirection", a->YDirection().XYZ());
    pr("ax2 createAndRead mainDirection", a->Direction().XYZ());
    Handle(Geom_Axis2Placement) b =
      new Geom_Axis2Placement(gp_Pnt(5, 5, 5), gp_Dir(0, 1, 0), gp_Dir(1, 0, 0));
    pr("ax2 location location", b->Location().XYZ());
    Handle(Geom_Axis2Placement) c =
      new Geom_Axis2Placement(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    c->SetDirection(gp_Dir(0, 1, 0));
    pr("ax2 setDirection mainDirection", c->Direction().XYZ());
    Handle(Geom_Axis2Placement) d =
      new Geom_Axis2Placement(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    d->SetXDirection(gp_Dir(0, 1, 0));
    pr("ax2 setXDirection xDirection", d->XDirection().XYZ());
  }
  return 0;
}
