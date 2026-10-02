// Ground truth for #2994: why IntTools_EdgeEdge types one partial arc overlap as a vertex and
// another as an edge, and what OCCT's own consumer (BOPAlgo_PaveFiller::PerformEE) does with each.
//
// Build and run: see README.md in this directory.

#include <BRepAlgoAPI_BuilderAlgo.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Circle.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_EdgeEdge.hxx>
#include <IntTools_Tools.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <cstdio>

static const double kPi = M_PI;

static TopoDS_Edge arcEdge(double u1, double u2)
{
  gp_Circ                 c(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10.0);
  Handle(Geom_Circle)     g = new Geom_Circle(c);
  BRepBuilderAPI_MakeEdge mk(g, u1, u2);
  return TopoDS::Edge(mk.Shape());
}

static TopoDS_Edge segEdge(double x1, double x2)
{
  BRepBuilderAPI_MakeEdge mk(gp_Pnt(x1, 0, 0), gp_Pnt(x2, 0, 0));
  return TopoDS::Edge(mk.Shape());
}

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

// The rule read out of IntTools_EdgeEdge::MergeSolutions: the merged common range is promoted to
// TopAbs_EDGE only when it covers the WHOLE of range 1 or the WHOLE of range 2. Predicted here
// from the geometry alone, so the measurement either confirms that reading or refutes it.
static const char* predictMerged(double a1, double a2, double b1, double b2)
{
  const double lo = std::fmax(a1, b1), hi = std::fmin(a2, b2);
  if (hi <= lo)
    return "none";
  const double eps     = 1e-9;
  const bool   coversA = (std::fabs(lo - a1) < eps) && (std::fabs(hi - a2) < eps);
  const bool   coversB = (std::fabs(lo - b1) < eps) && (std::fabs(hi - b2) < eps);
  return (coversA || coversB) ? "EDGE" : "VERTEX";
}

static void report(const char*        label,
                   const TopoDS_Edge& e1,
                   const TopoDS_Edge& e2,
                   const char*        predicted)
{
  IntTools_EdgeEdge ee(e1, e2);
  ee.Perform();
  printf("%-48s done=%d parts=%d", label, (int)ee.IsDone(), ee.CommonParts().Length());
  if (!ee.IsDone() || ee.CommonParts().IsEmpty())
  {
    printf("  predicted=%s\n", predicted);
    return;
  }
  for (int i = 1; i <= ee.CommonParts().Length(); ++i)
  {
    const IntTools_CommonPrt& cp  = ee.CommonParts()(i);
    double                    r1f = 0, r1l = 0;
    cp.Range1(r1f, r1l);
    printf("\n    part %d: type=%-6s range1=(%.9f, %.9f)", i, typeName(cp.Type()), r1f, r1l);
    if (cp.Ranges2().Length() > 0)
    {
      double r2f = 0, r2l = 0;
      cp.Ranges2()(1).Range(r2f, r2l);
      printf(" range2=(%.9f, %.9f)", r2f, r2l);
    }
    if (cp.Type() == TopAbs_VERTEX)
    {
      double t1 = 0, t2 = 0;
      IntTools_Tools::VertexParameters(cp, t1, t2);
      printf(" vertexParams=(%.9f, %.9f)", t1, t2);
    }
    printf(" allNull=%d", (int)cp.AllNullFlag());
  }
  printf("\n    predicted=%s\n", predicted);
}

// What OCCT's own consumer makes of each pair. General Fuse is BOPAlgo_PaveFiller plus
// BOPAlgo_Builder, so its output is PerformEE's VERTEX / EDGE branches taken to their conclusion.
static void generalFuse(const char* label, const TopoDS_Edge& e1, const TopoDS_Edge& e2)
{
  TopTools_ListOfShape args;
  args.Append(e1);
  args.Append(e2);
  BRepAlgoAPI_BuilderAlgo gf;
  gf.SetArguments(args);
  gf.SetRunParallel(false);
  gf.Build();
  printf("%-48s GF done=%d", label, (int)gf.IsDone());
  if (!gf.IsDone())
  {
    printf("\n");
    return;
  }
  int nE = 0, nV = 0;
  for (TopExp_Explorer ex(gf.Shape(), TopAbs_EDGE); ex.More(); ex.Next())
    ++nE;
  for (TopExp_Explorer ex(gf.Shape(), TopAbs_VERTEX); ex.More(); ex.Next())
    ++nV;
  printf(" edges=%d vertices=%d\n", nE, nV);
  // Where each argument was split tells us whether the overlap was treated as a range or a point.
  const TopoDS_Edge* inputs[2] = {&e1, &e2};
  for (int a = 0; a < 2; ++a)
  {
    const TopTools_ListOfShape& mods = gf.Modified(*inputs[a]);
    printf("      arg%d -> %d piece(s):", a + 1, mods.Extent());
    for (TopTools_ListOfShape::Iterator it(mods); it.More(); it.Next())
    {
      double f = 0, l = 0;
      BRep_Tool::Range(TopoDS::Edge(it.Value()), f, l);
      printf(" (%.6f, %.6f)", f, l);
    }
    printf("\n");
  }
}

int main()
{
  printf("=== IntTools_EdgeEdge, radius-10 circle about the origin, normal +Z ===\n");
  printf("pi/4 = %.9f  pi/2 = %.9f  3pi/4 = %.9f  pi = %.9f\n\n",
         kPi / 4,
         kPi / 2,
         3 * kPi / 4,
         kPi);

  struct Arc
  {
    const char* label;
    double      a1, a2, b1, b2;
  } arcs[] = {
    {"A  a=[0,pi]       b=[pi/2,3pi/2] (#2994 row 1)", 0, kPi, kPi / 2, 3 * kPi / 2},
    {"B  a=[0,pi]       b=[pi/4,3pi/4] (#2994 row 2)", 0, kPi, kPi / 4, 3 * kPi / 4},
    {"C  a=[0,pi]       b=[pi/2,pi]    (b at a's end)", 0, kPi, kPi / 2, kPi},
    {"D  a=[pi/4,3pi/4] b=[0,pi]       (a contained)", kPi / 4, 3 * kPi / 4, 0, kPi},
    {"E  a=[0,pi]       b=[0,pi]       (identical)", 0, kPi, 0, kPi},
    {"F  a=[0,pi/2]     b=[pi/4,3pi/4] (staggered)", 0, kPi / 2, kPi / 4, 3 * kPi / 4},
    {"G  a=[0,pi/2]     b=[pi/4,pi/2]  (b at a's end)", 0, kPi / 2, kPi / 4, kPi / 2},
  };
  for (const Arc& f : arcs)
  {
    report(f.label,
           arcEdge(f.a1, f.a2),
           arcEdge(f.b1, f.b2),
           predictMerged(f.a1, f.a2, f.b1, f.b2));
  }

  printf("\n=== the same situation in straight lines, which take ComputeLineLine instead ===\n");
  struct Seg
  {
    const char* label;
    double      a1, a2, b1, b2;
  } segs[] = {
    {"H  a=[0,2]        b=[1,3]        (staggered)", 0, 2, 1, 3},
    {"I  a=[0,2]        b=[0.5,1.5]    (b contained)", 0, 2, 0.5, 1.5},
  };
  for (const Seg& f : segs)
  {
    report(f.label,
           segEdge(f.a1, f.a2),
           segEdge(f.b1, f.b2),
           predictMerged(f.a1, f.a2, f.b1, f.b2));
  }

  printf("\n=== BOPAlgo_PaveFiller's own conclusion (General Fuse of the two edges) ===\n");
  generalFuse("A  arcs [0,pi] + [pi/2,3pi/2]", arcEdge(0, kPi), arcEdge(kPi / 2, 3 * kPi / 2));
  generalFuse("B  arcs [0,pi] + [pi/4,3pi/4]", arcEdge(0, kPi), arcEdge(kPi / 4, 3 * kPi / 4));
  generalFuse("H  segs [0,2] + [1,3]", segEdge(0, 2), segEdge(1, 3));
  generalFuse("I  segs [0,2] + [0.5,1.5]", segEdge(0, 2), segEdge(0.5, 1.5));
  return 0;
}
