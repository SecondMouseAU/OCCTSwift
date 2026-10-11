// #766 kernel parity for MedialAxisRectangleTests.swift and MedialAxisVariousShapesTests.swift.
//
// Builds the same faces the tests build (Wire.rectangle is a polygon centred on the origin,
// Wire.polygon a closed polygon, Wire.circle a full circle, each made into a planar face) and runs
// the same OCCT calls OCCTMedialAxisCompute makes: BRepMAT2d_Explorer::Perform, then
// BRepMAT2d_BisectingLocus::Compute(explorer, 1, MAT_Left, GeomAbs_Arc, false). Distances to the
// boundary are the minimum Geom2dAPI_ProjectPointOnCurve::LowerDistance over the explorer's
// boundary curves, as the bridge's OCCTMedialAxis::distanceToBoundary computes them.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepMAT2d_BisectingLocus.hxx>
#include <BRepMAT2d_Explorer.hxx>
#include <Bisector_Bisec.hxx>
#include <GC_MakeCircle.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <MAT_Arc.hxx>
#include <MAT_Graph.hxx>
#include <MAT_Node.hxx>
#include <Precision.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <cstdio>
#include <cstring>
#include <csignal>
#include <sys/wait.h>
#include <unistd.h>
#include <limits>
#include <vector>

struct MA
{
  BRepMAT2d_Explorer                explorer;
  BRepMAT2d_BisectingLocus          locus;
  Handle(MAT_Graph)                 graph;
  std::vector<Handle(Geom2d_Curve)> boundary;

  double dist(const gp_Pnt2d& p) const
  {
    double m = std::numeric_limits<double>::max();
    for (const auto& c : boundary)
    {
      try
      {
        Geom2dAPI_ProjectPointOnCurve proj(p, c);
        if (proj.NbPoints() > 0 && proj.LowerDistance() < m)
          m = proj.LowerDistance();
      }
      catch (...)
      {
      }
    }
    return m < std::numeric_limits<double>::max() ? m : 0.0;
  }
};

static TopoDS_Face polygonFace(const std::vector<gp_Pnt>& pts)
{
  BRepBuilderAPI_MakePolygon poly;
  for (const auto& p : pts)
    poly.Add(p);
  poly.Close();
  return BRepBuilderAPI_MakeFace(poly.Wire(), true).Face();
}

static TopoDS_Face rectFace(double w, double h)
{
  return polygonFace({gp_Pnt(-w / 2, -h / 2, 0), gp_Pnt(w / 2, -h / 2, 0), gp_Pnt(w / 2, h / 2, 0),
                      gp_Pnt(-w / 2, h / 2, 0)});
}

static void run(const char* label, const TopoDS_Face& face, bool details)
{
  MA ma;
  ma.explorer.Perform(face);
  ma.locus.Compute(ma.explorer, 1, MAT_Left, GeomAbs_Arc, Standard_False);
  printf("== %s: locus.IsDone=%d\n", label, ma.locus.IsDone());
  if (!ma.locus.IsDone())
    return;
  ma.graph = ma.locus.Graph();
  if (ma.graph.IsNull())
  {
    printf("  graph null\n");
    return;
  }
  printf("  arcs=%d nodes=%d basicElts=%d\n", ma.graph->NumberOfArcs(), ma.graph->NumberOfNodes(),
         ma.graph->NumberOfBasicElts());
  for (int c = 1; c <= ma.explorer.NumberOfContours(); c++)
    for (ma.explorer.Init(c); ma.explorer.More(); ma.explorer.Next())
      ma.boundary.push_back(ma.explorer.Value());

  double minT = std::numeric_limits<double>::max();
  double xMin = 1e300, xMax = -1e300, yMin = 1e300, yMax = -1e300;
  for (int i = 1; i <= ma.graph->NumberOfNodes(); i++)
  {
    Handle(MAT_Node) n = ma.graph->Node(i);
    gp_Pnt2d         p = ma.locus.GeomElt(n);
    double           d = ma.dist(p);
    if (!n->Infinite() && d > 0 && d < minT)
      minT = d;
    xMin = std::min(xMin, p.X());
    xMax = std::max(xMax, p.X());
    yMin = std::min(yMin, p.Y());
    yMax = std::max(yMax, p.Y());
    if (details)
      printf("  node %d (%.12g, %.12g) dist=%.12g onBoundary=%d pending=%d\n", i, p.X(), p.Y(), d,
             n->OnBasicElt(), n->PendingNode());
  }
  printf("  minThickness=%.12g node x in [%.12g, %.12g] y in [%.12g, %.12g]\n",
         minT < std::numeric_limits<double>::max() ? minT : -1.0, xMin, xMax, yMin, yMax);
  if (!details)
    return;
  for (int i = 1; i <= ma.graph->NumberOfArcs(); i++)
  {
    Handle(MAT_Arc) a = ma.graph->Arc(i);
    // Distance at t = 0, 0.5, 1 along the trimmed bisector, as OCCTMedialAxisDistanceOnArc
    // evaluates it.
    Standard_Boolean            rev = Standard_False;
    Bisector_Bisec              b   = ma.locus.GeomBis(a, rev);
    Handle(Geom2d_TrimmedCurve) tc  = b.Value();
    double                      u0 = tc->FirstParameter(), u1 = tc->LastParameter();
    if (Precision::IsNegativeInfinite(u0))
      u0 = -1000.0;
    if (Precision::IsPositiveInfinite(u1))
      u1 = 1000.0;
    double d[3];
    for (int k = 0; k < 3; k++)
    {
      double t = k * 0.5;
      double u = rev ? (u1 - t * (u1 - u0)) : (u0 + t * (u1 - u0));
      d[k]     = ma.dist(tc->Value(u));
    }
    printf("  arc %d nodes %d-%d dist t=0 %.12g t=0.5 %.12g t=1 %.12g\n", i,
           a->FirstNode()->Index(), a->SecondNode()->Index(), d[0], d[1], d[2]);
  }
}

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  run("rectangle 10x4 (MedialAxisRectangleTests, and the 10x4 fixtures in VariousShapes)",
      rectFace(10, 4), true);
  run("square 6x6 (squareMedialAxis)", rectFace(6, 6), false);
  run("L-shape (lShapedMedialAxis)",
      polygonFace({gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 4, 0), gp_Pnt(4, 4, 0),
                   gp_Pnt(4, 8, 0), gp_Pnt(0, 8, 0)}),
      false);
  // The circle runs in a child process: it is the crash the two suites were disabled for.
  pid_t pid = fork();
  if (pid == 0)
  {
    BRepBuilderAPI_MakeEdge e(gp_Circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0));
    run("circle r=5 (circleMedialAxis)",
        BRepBuilderAPI_MakeFace(BRepBuilderAPI_MakeWire(e.Edge()).Wire(), true).Face(), true);
    _exit(0);
  }
  int status = 0;
  waitpid(pid, &status, 0);
  if (WIFSIGNALED(status))
    printf("  circle r=5: child process killed by signal %d (%s)\n", WTERMSIG(status),
           strsignal(WTERMSIG(status)));
  else
    printf("  circle r=5: child exited %d\n", WEXITSTATUS(status));
  run("narrow 20x1 (narrowRectangle)", rectFace(20, 1), false);
  run("triangle (triangleMedialAxis)",
      polygonFace({gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(5, 8, 0)}), false);
  return 0;
}
