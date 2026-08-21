// Ground truth for #999 sections A and D, three sites in one probe.
//
//  1. Geom2dConvert::CurveToBSplineCurve takes a Convert_ParameterisationType and no tolerance.
//     Does the parameterisation actually change the result? (OCCTCurve2DToBSpline site.)
//  2. Bisector_BisecPC::Perform takes a DistMax and no origin. Does DistMax change the result?
//     (OCCTCurve2DBisectorPC site.)
//  3. ShapeAnalysis_Wire::CheckOuterBound takes a bool APIMake and no precision. Does either the
//     precision handed to Init(), or APIMake itself, change the verdict?
//     (OCCTWireCheckOuterBound site.)
#include <BRep_Builder.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <Bisector_BisecPC.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Line.hxx>
#include <Geom_Plane.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax22d.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt2d.hxx>
#include <cmath>
#include <cstdio>

namespace
{

const char* kNames[] = {"TgtThetaOver2",
                        "TgtThetaOver2_1",
                        "TgtThetaOver2_2",
                        "TgtThetaOver2_3",
                        "TgtThetaOver2_4",
                        "QuasiAngular",
                        "RationalC1",
                        "Polynomial"};

// Geometric fidelity, not parametric agreement: the largest |distance to centre - radius| over
// the converted curve. Sampling the two curves at proportionally equal parameters would measure
// the parameterisation difference instead, which is the thing being varied, so it would report a
// large number for every correct answer.
double worstRadialError(const Handle(Geom2d_BSplineCurve) & b,
                        const gp_Pnt2d& centre,
                        double          major,
                        double          minor)
{
  double worst = 0;
  double f = b->FirstParameter(), l = b->LastParameter();
  for (int k = 0; k <= 400; k++)
  {
    gp_Pnt2d p  = b->Value(f + (l - f) * k / 400.0);
    double   dx = (p.X() - centre.X()) / major;
    double   dy = (p.Y() - centre.Y()) / minor;
    double   e  = std::fabs(std::sqrt(dx * dx + dy * dy) - 1.0);
    if (e > worst)
      worst = e;
  }
  return worst;
}

void reportParameterisation(const char*     label,
                            const Handle(Geom2d_Curve) & c,
                            const gp_Pnt2d& centre,
                            double          major,
                            double          minor)
{
  printf("--- %s ---\n", label);
  for (int i = 0; i < 8; i++)
  {
    Convert_ParameterisationType t = (Convert_ParameterisationType)i;
    Handle(Geom2d_BSplineCurve)  b;
    try
    {
      b = Geom2dConvert::CurveToBSplineCurve(c, t);
    }
    catch (...)
    {
      printf("  %-16s CONVERSION THREW\n", kNames[i]);
      continue;
    }
    if (b.IsNull())
    {
      printf("  %-16s NULL\n", kNames[i]);
      continue;
    }
    printf("  %-16s degree=%d poles=%d knots=%d rational=%d worstRelRadialError=%.12g\n",
           kNames[i],
           b->Degree(),
           b->NbPoles(),
           b->NbKnots(),
           (int)b->IsRational(),
           worstRadialError(b, centre, major, minor));
  }
}

void reportLine()
{
  // A Geom2d_Line is unbounded, so this is asked separately: the point is whether the CONVERSION
  // throws, not what the geometry looks like, and a fidelity loop over an infinite parameter range
  // would throw on its own and be mistaken for the conversion throwing.
  printf("--- infinite line: does the conversion itself throw? ---\n");
  Handle(Geom2d_Line) line = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 1));
  for (int i = 0; i < 8; i++)
  {
    try
    {
      Handle(Geom2d_BSplineCurve) b =
        Geom2dConvert::CurveToBSplineCurve(line, (Convert_ParameterisationType)i);
      printf("  %-16s %s\n", kNames[i], b.IsNull() ? "NULL" : "converted");
    }
    catch (...)
    {
      printf("  %-16s CONVERSION THREW\n", kNames[i]);
    }
  }
}

void reportBisector()
{
  printf("--- Bisector_BisecPC::Perform DistMax ---\n");
  // A point off a line: the bisector is a parabola, unbounded, so DistMax has something to trim.
  Handle(Geom2d_Line) line = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  for (double distMax : {1.0, 10.0, 100.0, 500.0, 5000.0})
  {
    Handle(Bisector_BisecPC) b = new Bisector_BisecPC();
    b->Perform(line, gp_Pnt2d(0, 4), 1.0, distMax);
    if (b->IsEmpty())
    {
      printf("  DistMax=%-8g EMPTY\n", distMax);
      continue;
    }
    printf("  DistMax=%-8g range=[%.9g, %.9g] start=(%.9g, %.9g) end=(%.9g, %.9g)\n",
           distMax,
           b->FirstParameter(),
           b->LastParameter(),
           b->Value(b->FirstParameter()).X(),
           b->Value(b->FirstParameter()).Y(),
           b->Value(b->LastParameter()).X(),
           b->Value(b->LastParameter()).Y());
  }
}

void checkOuterBound(const char* label, const TopoDS_Wire& wire, const TopoDS_Face& face)
{
  for (double prec : {1e-12, 1e-7, 1e-3, 1.0, 100.0})
    for (int apiMake = 0; apiMake <= 1; apiMake++)
    {
      ShapeAnalysis_Wire saw;
      saw.Init(wire, face, prec);
      if (!saw.IsReady())
      {
        printf("  %-22s prec=%-10g APIMake=%d NOT READY\n", label, prec, apiMake);
        continue;
      }
      printf("  %-22s prec=%-10g APIMake=%d CheckOuterBound=%d\n",
             label,
             prec,
             apiMake,
             (int)saw.CheckOuterBound(apiMake != 0));
    }
}

void reportOuterBound()
{
  printf("--- ShapeAnalysis_Wire::CheckOuterBound (true means NOT an outer bound) ---\n");
  Handle(Geom_Plane) plane = new Geom_Plane(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  gp_Pnt             p[4] = {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)};

  BRepBuilderAPI_MakeWire outer;
  for (int i = 0; i < 4; i++)
    outer.Add(BRepBuilderAPI_MakeEdge(p[i], p[(i + 1) % 4]).Edge());
  BRepBuilderAPI_MakeFace faceMaker(plane->Pln(), outer.Wire());
  TopoDS_Face             face = faceMaker.Face();

  checkOuterBound("MakeWire, forward", outer.Wire(), face);
  checkOuterBound("MakeWire, reversed", TopoDS::Wire(outer.Wire().Reversed()), face);

  // A wire assembled with BRep_Builder from independently built edges, so consecutive edges carry
  // coincident but DISTINCT vertices. This is the case APIMake's own documentation distinguishes:
  // "if False (to be used only when edges share common vertices) uses BRep_Builder to build the
  // wire". If APIMake is ever observable, it is here.
  BRep_Builder b;
  TopoDS_Wire  unshared;
  b.MakeWire(unshared);
  for (int i = 0; i < 4; i++)
    b.Add(unshared, BRepBuilderAPI_MakeEdge(p[i], p[(i + 1) % 4]).Edge());
  checkOuterBound("BRep_Builder, unshared", unshared, face);
}

} // namespace

int main()
{
  Handle(Geom2d_Circle) circle =
    new Geom2d_Circle(gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5.0));
  reportParameterisation("full circle r=5", circle, gp_Pnt2d(0, 0), 5.0, 5.0);

  Handle(Geom2d_Ellipse) ellipse =
    new Geom2d_Ellipse(gp_Elips2d(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 8.0, 3.0));
  reportParameterisation("full ellipse 8x3", ellipse, gp_Pnt2d(0, 0), 8.0, 3.0);

  printf("\n");
  reportLine();
  printf("\n");
  reportBisector();
  printf("\n");
  reportOuterBound();
  return 0;
}
