// Kernel parity probe for Curve3DTransformTests and CylindricalSurfaceTests (#1983).
// Curve3DTransform: OCCTCurve3DInterpolate (GeomAPI_Interpolate) then OCCTCurve3DTransform
// (Geom_Geometry::Transform with the gp_Trsf occtBuildTrsf3D builds), read back at u = 0.
// CylindricalSurface: OCCTSurfaceCylindricalFromAxis / OCCTSurfaceCylindricalFromPoints.
#include <GC_MakeCylindricalSurface.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Trsf.hxx>
#include <cmath>
#include <cstdio>

static Handle(Geom_BSplineCurve) interp(gp_Pnt a, gp_Pnt b, gp_Pnt c)
{
  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 3);
  pts->SetValue(1, a);
  pts->SetValue(2, b);
  pts->SetValue(3, c);
  GeomAPI_Interpolate in(pts, Standard_False, 1e-6);
  in.Perform();
  return in.Curve();
}

static void pr(const char* tag, const gp_Pnt& p)
{
  printf("%s (%.12g, %.12g, %.12g)\n", tag, p.X(), p.Y(), p.Z());
}

int main()
{
  {
    Handle(Geom_BSplineCurve) c = interp(gp_Pnt(0, 0, 0), gp_Pnt(5, 5, 0), gp_Pnt(10, 0, 0));
    pr("translateCurve before", c->Value(0));
    gp_Trsf t;
    t.SetTranslation(gp_Vec(10, 0, 0));
    c->Transform(t);
    pr("translateCurve after", c->Value(0));
  }
  {
    Handle(Geom_BSplineCurve) c = interp(gp_Pnt(1, 0, 0), gp_Pnt(2, 0, 0), gp_Pnt(3, 0, 0));
    gp_Trsf t;
    t.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 2);
    c->Transform(t);
    pr("rotateCurve", c->Value(0));
  }
  {
    Handle(Geom_BSplineCurve) c = interp(gp_Pnt(1, 0, 0), gp_Pnt(2, 0, 0), gp_Pnt(3, 0, 0));
    gp_Trsf t;
    t.SetScale(gp_Pnt(0, 0, 0), 2);
    c->Transform(t);
    pr("scaleCurve", c->Value(0));
  }
  {
    Handle(Geom_BSplineCurve) c = interp(gp_Pnt(1, 0, 0), gp_Pnt(2, 0, 0), gp_Pnt(3, 0, 0));
    gp_Trsf t;
    t.SetMirror(gp_Pnt(0, 0, 0));
    c->Transform(t);
    pr("mirrorPointCurve", c->Value(0));
  }
  {
    Handle(Geom_BSplineCurve) c = interp(gp_Pnt(1, 1, 0), gp_Pnt(2, 1, 0), gp_Pnt(3, 1, 0));
    gp_Trsf t;
    t.SetMirror(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
    c->Transform(t);
    pr("mirrorAxisCurve", c->Value(0));
  }
  {
    Handle(Geom_BSplineCurve) c = interp(gp_Pnt(1, 0, 5), gp_Pnt(2, 0, 5), gp_Pnt(3, 0, 5));
    gp_Trsf t;
    t.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    c->Transform(t);
    pr("mirrorPlaneCurve", c->Value(0));
  }
  {
    GC_MakeCylindricalSurface       mk(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3.0);
    Handle(Geom_CylindricalSurface) s = mk.Value();
    printf("fromAxis done=%d radius=%.12g\n", mk.IsDone(), s->Radius());
    pr("fromAxis S(0,0)", s->Value(0, 0));
    pr("fromAxis S(pi/2,4)", s->Value(M_PI / 2, 4));
  }
  {
    GC_MakeCylindricalSurface       mk(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), gp_Pnt(5, 0, 5));
    Handle(Geom_CylindricalSurface) s = mk.Value();
    printf("fromPoints done=%d radius=%.12g\n", mk.IsDone(), s->Radius());
    pr("fromPoints location", s->Location());
    gp_Dir d = s->Position().Direction();
    printf("fromPoints axis (%.12g, %.12g, %.12g)\n", d.X(), d.Y(), d.Z());
    pr("fromPoints S(0,0)", s->Value(0, 0));
    pr("fromPoints S(0,5)", s->Value(0, 5));
  }
  return 0;
}
