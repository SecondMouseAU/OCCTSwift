// #1979 kernel parity for Curve2DCircleInvoluteTests: Geom2dEval_CircleInvoluteCurve with the
// placements OCCTGeom2dEvalCircleInvoluteCurveCreate and the *WithPlacement evaluators build, and
// the BRepLib_MakeEdge2d edge OCCTMakeEdge2dCurveRange makes from it.
#include <Geom2dEval_CircleInvoluteCurve.hxx>
#include <BRepLib_MakeEdge2d.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <Standard_Failure.hxx>
#include <TopoDS_Edge.hxx>
#include <cstdio>
#include <cmath>

static void show(const char* tag, double ox, double oy, double dx, double dy, double r)
{
  double                                 l = std::sqrt(dx * dx + dy * dy);
  Handle(Geom2dEval_CircleInvoluteCurve) c =
    new Geom2dEval_CircleInvoluteCurve(gp_Ax2d(gp_Pnt2d(ox, oy), gp_Dir2d(dx / l, dy / l)), r);
  gp_Pnt2d a = c->Value(0), b = c->Value(1);
  printf("%s domain=[%.12g, %.12g] periodic=%d closed=%d value(0)=(%.12g, %.12g) value(1)=(%.12g, "
         "%.12g)\n",
         tag, c->FirstParameter(), c->LastParameter(), c->IsPeriodic(), c->IsClosed(), a.X(), a.Y(),
         b.X(), b.Y());
}

int main()
{
  show("standard", 0, 0, 1, 0, 2);
  show("translated (10,20)", 10, 20, 1, 0, 2);
  show("rotated pi/2", 0, 0, cos(M_PI / 2), sin(M_PI / 2), 2);
  show("mirrored (-1,0)", 0, 0, -1, 0, 2);
  for (double r : {0.0, -1.0})
  {
    try
    {
      Handle(Geom2dEval_CircleInvoluteCurve) c =
        new Geom2dEval_CircleInvoluteCurve(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), r);
      printf("radius %g: constructed\n", r);
    }
    catch (const Standard_Failure&)
    {
      printf("radius %g: constructor raised\n", r);
    }
  }
  {
    Handle(Geom2dEval_CircleInvoluteCurve) c =
      new Geom2dEval_CircleInvoluteCurve(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 2);
    BRepLib_MakeEdge2d me(c, 0, 2);
    BRepAdaptor_Curve  ad(me.Edge());
    printf("edge [0, 2]: done=%d length=%.12g (R u^2 / 2 = %.12g)\n", me.IsDone(),
           GCPnts_AbscissaPoint::Length(ad), 2 * 4 / 2.0);
  }
  return 0;
}
