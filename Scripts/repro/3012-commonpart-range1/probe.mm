// Ground truth for #3012: what an IntTools_CommonPrt carries for each part type, which fields OCCT's
// own consumers read from it, and what the bridge's fillCommonPart reported before it stopped
// overwriting Range1() with VertexParameter1().
//
// Build and run: see README.md in this directory.
//
// Every number printed is read straight off the kernel. The "before #3012" line is what the bridge
// reported before (both ends of the range set to VertexParameter on a VERTEX part), derived from
// the very same part so the two cannot disagree about which part they describe.

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Circle.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_EdgeEdge.hxx>
#include <IntTools_EdgeFace.hxx>
#include <IntTools_Range.hxx>
#include <IntTools_Tools.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <cstdio>

static const double kPi = M_PI;

// Tallies, printed at the end so the run is the assertion and not a table nobody reads.
static int g_vertexParts         = 0;
static int g_vertexRawOutside    = 0; // raw VertexParameter1 outside Range1: resolved != raw
static int g_vertexRangeWide     = 0; // Range1 wider than 1e-6, so the bridge's (t, t) lost something
static int g_edgeParts           = 0;
static int g_edgeVertexParamSet  = 0; // an EDGE part whose VertexParameter1 is not the 0.0 default
static int g_vertexRange2Present = 0;
static int g_vertexParts2        = 0;

static const char* typeName(TopAbs_ShapeEnum t)
{
  switch (t)
  {
    case TopAbs_VERTEX:
      return "VERTEX";
    case TopAbs_EDGE:
      return "EDGE";
    default:
      return "other";
  }
}

static TopoDS_Edge segment(gp_Pnt a, gp_Pnt b)
{
  BRepBuilderAPI_MakeEdge mk(a, b);
  return TopoDS::Edge(mk.Shape());
}

static TopoDS_Edge arc(gp_Pnt centre, double radius, double u1, double u2)
{
  gp_Circ                 c(gp_Ax2(centre, gp_Dir(0, 0, 1)), radius);
  Handle(Geom_Circle)     g = new Geom_Circle(c);
  BRepBuilderAPI_MakeEdge mk(g, u1, u2);
  return TopoDS::Edge(mk.Shape());
}

// A circle in the XZ plane, so it can touch a z = const face from below.
static TopoDS_Edge circleXZ(double radius)
{
  gp_Circ                 c(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0)), radius);
  Handle(Geom_Circle)     g = new Geom_Circle(c);
  BRepBuilderAPI_MakeEdge mk(g);
  return TopoDS::Edge(mk.Shape());
}

static void printPart(int i, const IntTools_CommonPrt& cp, bool isEdgeEdge)
{
  const IntTools_Range& r1 = cp.Range1();
  const double          w1 = r1.Last() - r1.First();
  printf("    part %d: type=%-6s Range1=(%.12g, %.12g) width=%.3g\n",
         i,
         typeName(cp.Type()),
         r1.First(),
         r1.Last(),
         w1);
  if (isEdgeEdge && cp.Ranges2().Length() > 0)
  {
    const IntTools_Range& r2 = cp.Ranges2()(1);
    printf("            Ranges2(1)=(%.12g, %.12g) width=%.3g\n",
           r2.First(),
           r2.Last(),
           r2.Last() - r2.First());
  }
  printf("            VertexParameter1=%.12g VertexParameter2=%.12g\n",
         cp.VertexParameter1(),
         cp.VertexParameter2());
  if (cp.Type() == TopAbs_VERTEX)
  {
    ++g_vertexParts;
    double resolved1 = 0, resolved2 = 0;
    if (isEdgeEdge)
    {
      // BOPAlgo_PaveFiller_3.cxx:381, the call PerformEE makes.
      IntTools_Tools::VertexParameters(cp, resolved1, resolved2);
      ++g_vertexParts2;
      if (cp.Ranges2().Length() > 0)
        ++g_vertexRange2Present;
    }
    else
    {
      // BOPAlgo_PaveFiller_5.cxx:412, the call PerformEF makes. It has no second edge.
      IntTools_Tools::VertexParameter(cp, resolved1);
    }
    const bool rawInRange =
      cp.VertexParameter1() >= r1.First() && cp.VertexParameter1() <= r1.Last();
    if (!rawInRange)
    {
      ++g_vertexRawOutside;
      const double excess = (cp.VertexParameter1() > r1.Last()) ? cp.VertexParameter1() - r1.Last()
                                                                 : r1.First() - cp.VertexParameter1();
      printf("            raw VertexParameter1 is OUTSIDE Range1 by %.3g (raw %.17g, Range1 last %.17g)\n",
             excess,
             cp.VertexParameter1(),
             r1.Last());
    }
    if (w1 > 1e-6)
      ++g_vertexRangeWide;
    printf("            resolved by IntTools_Tools: %.12g%s  raw in Range1: %d\n",
           resolved1,
           isEdgeEdge ? "" : " (edge 1 only)",
           (int)rawInRange);
    if (isEdgeEdge)
      printf("            resolved on edge 2: %.12g\n", resolved2);
    printf("            bridge before #3012 reported param1Range=(%.12g, %.12g)\n",
           cp.VertexParameter1(),
           cp.VertexParameter1());
  }
  else if (cp.Type() == TopAbs_EDGE)
  {
    ++g_edgeParts;
    if (cp.VertexParameter1() != 0.0)
      ++g_edgeVertexParamSet;
    printf("            EDGE part: VertexParameter1 is %s\n",
           cp.VertexParameter1() == 0.0 ? "the constructor's 0.0, never set" : "SET");
  }
}

static void edgeEdge(const char* label, const TopoDS_Edge& e1, const TopoDS_Edge& e2)
{
  IntTools_EdgeEdge ee(e1, e2);
  ee.Perform();
  printf("%-54s done=%d parts=%d\n", label, (int)ee.IsDone(), ee.CommonParts().Length());
  if (!ee.IsDone())
    return;
  for (int i = 1; i <= ee.CommonParts().Length(); ++i)
    printPart(i, ee.CommonParts()(i), true);
}

// The same configuration the bridge uses (#1631): the edge's own range, set explicitly. Only the
// faces that report something are printed.
static void edgeFaceAllFaces(const char* label, const TopoDS_Edge& e, const TopoDS_Shape& solid)
{
  int n = 0;
  for (TopExp_Explorer ex(solid, TopAbs_FACE); ex.More(); ex.Next(), ++n)
  {
    char buf[160];
    snprintf(buf, sizeof buf, "%s, face %d", label, n);
    IntTools_EdgeFace ef;
    ef.SetEdge(e);
    ef.SetFace(TopoDS::Face(ex.Current()));
    double first = 0.0, last = 0.0;
    BRep_Tool::Range(e, first, last);
    ef.SetRange(IntTools_Range(first, last));
    ef.Perform();
    if (!ef.IsDone() || ef.CommonParts().IsEmpty())
      continue;
    printf("%-54s done=%d parts=%d\n", buf, (int)ef.IsDone(), ef.CommonParts().Length());
    for (int i = 1; i <= ef.CommonParts().Length(); ++i)
      printPart(i, ef.CommonParts()(i), false);
  }
}

int main()
{
  printf("=== IntTools_EdgeEdge: transversal crossings ===\n");
  edgeEdge("perpendicular lines through the origin",
           segment(gp_Pnt(-1, 0, 0), gp_Pnt(1, 0, 0)),
           segment(gp_Pnt(0, -1, 0), gp_Pnt(0, 1, 0)));
  {
    const double a = 1.0 * kPi / 180.0;
    edgeEdge("lines crossing at 1 degree",
             segment(gp_Pnt(-1, 0, 0), gp_Pnt(1, 0, 0)),
             segment(gp_Pnt(-std::cos(a), -std::sin(a), 0), gp_Pnt(std::cos(a), std::sin(a), 0)));
  }
  {
    const double a = 0.01 * kPi / 180.0;
    edgeEdge("lines crossing at 0.01 degree",
             segment(gp_Pnt(-1, 0, 0), gp_Pnt(1, 0, 0)),
             segment(gp_Pnt(-std::cos(a), -std::sin(a), 0), gp_Pnt(std::cos(a), std::sin(a), 0)));
  }
  edgeEdge("line x = 0 through a radius-10 circle (two crossings)",
           segment(gp_Pnt(0, -20, 0), gp_Pnt(0, 20, 0)),
           arc(gp_Pnt(0, 0, 0), 10.0, 0, 2 * kPi));
  edgeEdge("line y = 10 tangent to the radius-10 circle",
           segment(gp_Pnt(-5, 10, 0), gp_Pnt(5, 10, 0)),
           arc(gp_Pnt(0, 0, 0), 10.0, 0, 2 * kPi));
  edgeEdge("two radius-10 circles, centres 10 apart",
           arc(gp_Pnt(0, 0, 0), 10.0, 0, 2 * kPi),
           arc(gp_Pnt(10, 0, 0), 10.0, 0, 2 * kPi));

  printf("\n=== IntTools_EdgeEdge: tangential overlaps of arcs of one circle (#2994 rows) ===\n");
  struct Arc
  {
    const char* label;
    double      a1, a2, b1, b2;
  } arcs[] = {
    {"A  a=[0,pi]       b=[pi/2,3pi/2]", 0, kPi, kPi / 2, 3 * kPi / 2},
    {"B  a=[0,pi]       b=[pi/4,3pi/4]", 0, kPi, kPi / 4, 3 * kPi / 4},
    {"C  a=[0,pi]       b=[pi/2,pi]   ", 0, kPi, kPi / 2, kPi},
    {"E  a=[0,pi]       b=[0,pi]      ", 0, kPi, 0, kPi},
    {"F  a=[0,pi/2]     b=[pi/4,3pi/4]", 0, kPi / 2, kPi / 4, 3 * kPi / 4},
    {"G  a=[0,pi/2]     b=[pi/4,pi/2] ", 0, kPi / 2, kPi / 4, kPi / 2},
  };
  for (const Arc& f : arcs)
  {
    edgeEdge(f.label,
             arc(gp_Pnt(0, 0, 0), 10.0, f.a1, f.a2),
             arc(gp_Pnt(0, 0, 0), 10.0, f.b1, f.b2));
  }

  printf("\n=== IntTools_EdgeEdge: straight overlaps, which take ComputeLineLine ===\n");
  edgeEdge("H  a=[0,2] b=[1,3]",
           segment(gp_Pnt(0, 0, 0), gp_Pnt(2, 0, 0)),
           segment(gp_Pnt(1, 0, 0), gp_Pnt(3, 0, 0)));

  printf("\n=== IntTools_EdgeFace on a centred 10 x 10 x 10 box ===\n");
  const TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), gp_Pnt(5, 5, 5)).Shape();
  edgeFaceAllFaces("edge (0,0,-10)-(0,0,10) up the middle",
                   segment(gp_Pnt(0, 0, -10), gp_Pnt(0, 0, 10)),
                   box);
  edgeFaceAllFaces("edge (5,5,-1)-(5,5,11) in the x = 5 plane",
                   segment(gp_Pnt(5, 5, -1), gp_Pnt(5, 5, 11)),
                   box);

  printf("\n=== IntTools_EdgeFace on a 200 x 200 x 10 slab, shallow crossings of z = 5 ===\n");
  const TopoDS_Shape slab =
    BRepPrimAPI_MakeBox(gp_Pnt(-100, -100, -5), gp_Pnt(100, 100, 5)).Shape();
  edgeFaceAllFaces("edge (-10,0,4.99)-(10,0,5.01), slope 0.001",
                   segment(gp_Pnt(-10, 0, 4.99), gp_Pnt(10, 0, 5.01)),
                   slab);
  edgeFaceAllFaces("edge (-10,0,4.9999)-(10,0,5.0001), slope 1e-5",
                   segment(gp_Pnt(-10, 0, 4.9999), gp_Pnt(10, 0, 5.0001)),
                   slab);

  printf("\n=== IntTools_EdgeFace: a circle touching and an arc lying in a face ===\n");
  edgeFaceAllFaces("circle r=5 in the XZ plane, touching z = 5", circleXZ(5.0), box);
  {
    const TopoDS_Shape plate =
      BRepPrimAPI_MakeBox(gp_Pnt(-20, -20, 0), gp_Pnt(20, 20, 2)).Shape();
    edgeFaceAllFaces("arc [0,pi] r=10 in the z = 0 face of a plate",
                     arc(gp_Pnt(0, 0, 0), 10.0, 0, kPi),
                     plate);
  }

  printf("\n=== tallies ===\n");
  printf("VERTEX parts                                   %d\n", g_vertexParts);
  printf("  raw VertexParameter1 outside Range1           %d  (resolved would differ from raw)\n",
         g_vertexRawOutside);
  printf("  Range1 wider than 1e-6 (bridge's (t,t) lost)  %d\n", g_vertexRangeWide);
  printf("  edge-edge VERTEX parts with a Ranges2(1)      %d of %d\n",
         g_vertexRange2Present,
         g_vertexParts2);
  printf("EDGE parts                                     %d\n", g_edgeParts);
  printf("  with a VertexParameter1 other than 0.0        %d\n", g_edgeVertexParamSet);
  return 0;
}
