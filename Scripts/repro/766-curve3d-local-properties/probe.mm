// Epic #766, Curve3DLocalPropertiesTests.swift: kernel parity for all seven tests.
// Same inputs as the Swift tests, straight to OCCT: GeomLProp_CLProps at resolution
// Precision::Confusion() (occtCurveLocalProps), Geom_Curve::D3 for torsion, and
// BndLib_Add3dCurve::Add with tolerance 0.01 for the bounding box.
#include <BndLib_Add3dCurve.hxx>
#include <Bnd_Box.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomLProp_CLProps.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Precision.hxx>
#include <cstdio>
#include <gp_Ax2.hxx>

int main()
{
  const double              res    = Precision::Confusion();
  Handle(Geom_Circle)       circle = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
  Handle(Geom_TrimmedCurve) seg    = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
  double                    mid    = (seg->FirstParameter() + seg->LastParameter()) / 2;

  {
    GeomLProp_CLProps p(circle, 0.0, 2, res);
    printf("circleRadius: tangentDefined=%d curvature=%.17g\n", p.IsTangentDefined(), p.Curvature());
  }
  {
    GeomLProp_CLProps p(seg, mid, 2, res);
    printf("lineCurvature: domain=[%.17g, %.17g] u=%.17g tangentDefined=%d curvature=%.17g\n",
           seg->FirstParameter(), seg->LastParameter(), mid, p.IsTangentDefined(), p.Curvature());
  }
  {
    GeomLProp_CLProps p(seg, mid, 1, res);
    gp_Dir            t;
    p.Tangent(t);
    printf("segmentTangent: tangent=(%.17g, %.17g, %.17g)\n", t.X(), t.Y(), t.Z());
  }
  {
    GeomLProp_CLProps p(circle, 0.0, 2, res);
    gp_Dir            n;
    p.Normal(n);
    gp_Pnt pt = circle->Value(0.0);
    printf("circleNormal: point=(%.17g, %.17g, %.17g) normal=(%.17g, %.17g, %.17g)\n",
           pt.X(), pt.Y(), pt.Z(), n.X(), n.Y(), n.Z());
  }
  {
    GeomLProp_CLProps p(circle, 0.0, 2, res);
    gp_Pnt            c;
    p.CentreOfCurvature(c);
    printf("circleCenterOfCurvature: centre=(%.17g, %.17g, %.17g)\n", c.X(), c.Y(), c.Z());
  }
  {
    gp_Pnt pnt;
    gp_Vec d1, d2, d3;
    circle->D3(0.5, pnt, d1, d2, d3);
    gp_Vec cross = d1.Crossed(d2);
    printf("circularTorsion: |d1 x d2|^2=%.17g torsion=%.17g\n",
           cross.SquareMagnitude(), cross.Dot(d3) / cross.SquareMagnitude());
  }
  {
    Handle(Geom_TrimmedCurve) s2 = GC_MakeSegment(gp_Pnt(1, 2, 3), gp_Pnt(10, 8, 6)).Value();
    GeomAdaptor_Curve         a(s2);
    Bnd_Box                   box;
    BndLib_Add3dCurve::Add(a, 0.01, box);
    double x0, y0, z0, x1, y1, z1;
    box.Get(x0, y0, z0, x1, y1, z1);
    printf("segmentBoundingBox: min=(%.17g, %.17g, %.17g) max=(%.17g, %.17g, %.17g)\n",
           x0, y0, z0, x1, y1, z1);
  }
  return 0;
}
