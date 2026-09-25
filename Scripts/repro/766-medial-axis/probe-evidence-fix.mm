// #766 evidence fix for the three medial-axis records that carried equal: false with no differences
// (MedialAxisRectangleTests.rectangleDrawArc, rectangleDrawAll and MedialAxisVariousShapesTests.noFaceFails).
//
// The bridge's OCCTMedialAxisDrawArc does not draw anything itself: it takes the trimmed bisector
// BRepMAT2d_BisectingLocus::GeomBis returns for an arc and evaluates Geom2d_TrimmedCurve::D0 at
// maxPoints parameters spread uniformly over [FirstParameter, LastParameter] (an infinite end is
// clamped to +-1000), never applying the `reverse` flag. OCCTMedialAxisDrawAll asks for
// maxPoints / arcCount points per arc. This probe runs the same OCCT calls on the same 10 x 4
// rectangle face, so the kernel side is what OCCT returns for that sampling.
//
// noFaceFails: OCCTMedialAxisCompute takes the first face of the shape with
// TopExp_Explorer(shape, TopAbs_FACE) and returns null when there is none, before any BRepMAT2d
// call, so the probe reports what the explorer finds on a wire-only shape.
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepMAT2d_BisectingLocus.hxx>
#include <BRepMAT2d_Explorer.hxx>
#include <Bisector_Bisec.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <MAT_Arc.hxx>
#include <MAT_Graph.hxx>
#include <Precision.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static TopoDS_Wire rectWire(double w, double h)
{
  BRepBuilderAPI_MakePolygon poly;
  poly.Add(gp_Pnt(-w / 2, -h / 2, 0));
  poly.Add(gp_Pnt(w / 2, -h / 2, 0));
  poly.Add(gp_Pnt(w / 2, h / 2, 0));
  poly.Add(gp_Pnt(-w / 2, h / 2, 0));
  poly.Close();
  return poly.Wire();
}

// The samples OCCTMedialAxisDrawArc takes for one arc: numPoints uniform parameters over the
// trimmed bisector's range. Returns the number of samples that evaluated to a finite point.
static int sampleArc(BRepMAT2d_BisectingLocus& locus, const Handle(MAT_Arc)& arc, int numPoints,
                     gp_Pnt2d& first, gp_Pnt2d& last)
{
  Standard_Boolean            reverse = Standard_False;
  Bisector_Bisec              bisec   = locus.GeomBis(arc, reverse);
  Handle(Geom2d_TrimmedCurve) trimmed = bisec.Value();
  if (trimmed.IsNull())
    return -1;
  double u0 = trimmed->FirstParameter();
  double u1 = trimmed->LastParameter();
  if (Precision::IsNegativeInfinite(u0))
    u0 = -1000.0;
  if (Precision::IsPositiveInfinite(u1))
    u1 = 1000.0;
  int finite = 0;
  for (int i = 0; i < numPoints; i++)
  {
    double   t = (numPoints > 1) ? (double)i / (numPoints - 1) : 0.0;
    gp_Pnt2d p;
    trimmed->D0(u0 + t * (u1 - u0), p);
    if (std::isfinite(p.X()) && std::isfinite(p.Y()))
      finite++;
    if (i == 0)
      first = p;
    if (i == numPoints - 1)
      last = p;
  }
  return finite;
}

int main()
{
  TopoDS_Face face = BRepBuilderAPI_MakeFace(rectWire(10, 4), true).Face();
  BRepMAT2d_Explorer explorer;
  explorer.Perform(face);
  BRepMAT2d_BisectingLocus locus;
  locus.Compute(explorer, 1, MAT_Left, GeomAbs_Arc, Standard_False);
  Handle(MAT_Graph) graph = locus.Graph();
  printf("rectangle 10x4: locus.IsDone=%d arcs=%d\n", (int)locus.IsDone(), graph->NumberOfArcs());

  gp_Pnt2d first, last;
  int      finite = sampleArc(locus, graph->Arc(1), 20, first, last);
  printf("drawArc arc 1, 20 samples: finite=%d first=(%.17g, %.17g) last=(%.17g, %.17g)\n", finite,
         first.X(), first.Y(), last.X(), last.Y());

  // OCCTMedialAxisDrawAll with maxPoints = 16 * arcCount: 16 points per arc, one polyline per arc.
  int arcCount = graph->NumberOfArcs();
  printf("drawAll 16 samples per arc over %d arcs:\n", arcCount);
  for (int i = 1; i <= arcCount; i++)
  {
    int f = sampleArc(locus, graph->Arc(i), 16, first, last);
    printf("  arc %d: finite=%d of 16 first=(%.17g, %.17g) last=(%.17g, %.17g)\n", i, f, first.X(),
           first.Y(), last.X(), last.Y());
  }

  // noFaceFails: a wire-only shape (Shape.fromWire of a 5 x 5 rectangle wire).
  TopoDS_Wire wire = rectWire(5, 5);
  TopExp_Explorer faceExp(wire, TopAbs_FACE);
  printf("wire-only shape: TopExp_Explorer(TopAbs_FACE).More()=%d\n", (int)faceExp.More());
  return 0;
}
