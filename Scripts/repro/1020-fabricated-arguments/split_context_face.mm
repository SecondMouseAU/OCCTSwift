// Ground truth for #1020's second named site, OCCTShapeFixSplitEdge (OCCTBridge_Healing.mm),
// which builds its split context as
//
//     gp_Pln      plane(mid, gp_Dir(0, 0, 1));
//     TopoDS_Face face = BRepBuilderAPI_MakeFace(plane, -1000, 1000, -1000, 1000).Face();
//
// The issue's claim is that "an edge outside +-1000, or one whose natural plane is not XY, gets a
// split context that does not contain it". This probe asks whether the face is consulted at all,
// by running the same split against four deliberately incompatible context faces and comparing the
// two halves the tool returns. It also prints the parameter range SplitEdge reads off each face,
// because a first pass at this assumed that range was (0, 0) for a standalone edge and it is not:
// BRep_Tool::CurveOnSurface falls through to CurveOnPlane, which projects the edge onto a planar
// face and hands back the edge's own range.
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Line.hxx>
#include <ShapeAnalysis_Edge.hxx>
#include <ShapeFix_SplitTool.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <cmath>
#include <cstdio>

namespace
{

TopoDS_Edge lineEdge(const gp_Pnt& a, const gp_Pnt& b)
{
  return BRepBuilderAPI_MakeEdge(a, b).Edge();
}

TopoDS_Edge circleEdgeInXZ()
{
  gp_Circ c(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0), gp_Dir(1, 0, 0)), 10.0);
  return BRepBuilderAPI_MakeEdge(c).Edge();
}

double edgeLength(const TopoDS_Edge& e)
{
  GProp_GProps props;
  BRepGProp::LinearProperties(e, props);
  return props.Mass();
}

// The bridge's own body, with the context face handed in rather than fabricated inside.
bool split(const TopoDS_Edge& edge,
           double             param,
           const gp_Pnt&      vertexPnt,
           const TopoDS_Face& face,
           double&            len1,
           double&            len2,
           gp_Pnt&            shared)
{
  len1 = len2 = 0;
  try
  {
    TopoDS_Vertex      vert = BRepBuilderAPI_MakeVertex(vertexPnt).Vertex();
    ShapeFix_SplitTool tool;
    TopoDS_Edge        newE1, newE2;
    if (!tool.SplitEdge(edge, param, vert, face, newE1, newE2, 1e-6, 1e-6))
      return false;
    if (newE1.IsNull() || newE2.IsNull())
      return false;
    len1   = edgeLength(newE1);
    len2   = edgeLength(newE2);
    double f, l;
    Handle(Geom_Curve) c = BRep_Tool::Curve(newE1, f, l);
    shared               = c.IsNull() ? gp_Pnt(0, 0, 0) : c->Value(l);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

struct Context
{
  const char* label;
  TopoDS_Face face;
};

void runCase(const char* caseLabel, const TopoDS_Edge& edge, double param, const gp_Pnt& vertexPnt)
{
  double f, l;
  Handle(Geom_Curve) c = BRep_Tool::Curve(edge, f, l);
  gp_Pnt mid           = c->Value((f + l) / 2.0);

  Context contexts[] = {
    // What the bridge builds today.
    {"shipped +Z, +-1000", BRepBuilderAPI_MakeFace(gp_Pln(mid, gp_Dir(0, 0, 1)), -1000, 1000,
                                                   -1000, 1000)
                             .Face()},
    // Same normal, a trim far too small to contain the edge.
    {"+Z, +-0.001",
     BRepBuilderAPI_MakeFace(gp_Pln(mid, gp_Dir(0, 0, 1)), -0.001, 0.001, -0.001, 0.001).Face()},
    // A normal with no relation to the edge at all.
    {"normal (1,1,1), +-1000",
     BRepBuilderAPI_MakeFace(gp_Pln(mid, gp_Dir(1, 1, 1)), -1000, 1000, -1000, 1000).Face()},
    // A plane a long way from the edge.
    {"+Z at (1e6,1e6,1e6)",
     BRepBuilderAPI_MakeFace(gp_Pln(gp_Pnt(1e6, 1e6, 1e6), gp_Dir(0, 0, 1)), -1000, 1000, -1000,
                             1000)
       .Face()},
    // No null-face row. ShapeFix_SplitTool::SplitEdge segfaults on one (measured), which says the
    // face is dereferenced but not that its geometry is consulted, and the bridge never builds a
    // null one. The four rows above vary the geometry instead, which is the actual question.
  };

  printf("--- %s (param=%g) ---\n", caseLabel, param);
  for (const Context& ctx : contexts)
  {
    double len1, len2;
    gp_Pnt shared;
    bool   ok = split(edge, param, vertexPnt, ctx.face, len1, len2, shared);
    if (!ok)
    {
      printf("  %-24s REFUSED\n", ctx.label);
      continue;
    }
    printf("  %-24s len1=%.12g len2=%.12g sum=%.12g joint=(%.9g, %.9g, %.9g)\n",
           ctx.label,
           len1,
           len2,
           len1 + len2,
           shared.X(),
           shared.Y(),
           shared.Z());
  }
}

} // namespace

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  printf("=== a line in the XY plane near the origin, the case the shipped face suits ===\n");
  {
    TopoDS_Edge e = lineEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    runCase("XY line, length 10", e, 4.0, gp_Pnt(4, 0, 0));
  }

  printf("\n=== a line along Z, perpendicular to the shipped face's own plane ===\n");
  {
    TopoDS_Edge e = lineEdge(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10));
    runCase("Z line, length 10", e, 4.0, gp_Pnt(0, 0, 4));
  }

  printf("\n=== a line entirely outside the shipped face's +-1000 trim ===\n");
  {
    TopoDS_Edge e = lineEdge(gp_Pnt(5000, 5000, 0), gp_Pnt(5010, 5000, 0));
    runCase("far line, length 10", e, 4.0, gp_Pnt(5004, 5000, 0));
  }

  printf("\n=== a circle in the XZ plane, whose natural plane is not XY ===\n");
  {
    TopoDS_Edge e = circleEdgeInXZ();
    runCase("XZ circle, r=10", e, 1.0, gp_Pnt(10 * std::cos(1.0), 0, 10 * std::sin(1.0)));
  }

  printf("\n=== the parameter range SplitEdge reads off the context face ===\n");
  {
    // The guard SplitEdge makes with that range is |a - param| < tol2d || |b - param| < tol2d,
    // so what this range is decides which splits the kernel refuses on its own.
    Handle(Geom_Curve) line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    TopoDS_Edge        e[2] = {lineEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)),
                               BRepBuilderAPI_MakeEdge(line, -5.0, 5.0).Edge()};
    const char*        n[2] = {"XY line [0, 10]", "straddling line [-5, 5]"};
    for (int i = 0; i < 2; i++)
    {
      double             f, l;
      Handle(Geom_Curve) c   = BRep_Tool::Curve(e[i], f, l);
      gp_Pnt             mid = c->Value((f + l) / 2.0);
      TopoDS_Face        face =
        BRepBuilderAPI_MakeFace(gp_Pln(mid, gp_Dir(0, 0, 1)), -1000, 1000, -1000, 1000).Face();
      double                    a = -12345, b = -12345;
      ShapeAnalysis_Edge        sae;
      occ::handle<Geom2d_Curve> c2d;
      bool                      found = sae.PCurve(e[i], face, c2d, a, b, true);
      printf("  %-24s edge range [%g, %g], PCurve found=%d range [%g, %g]\n",
             n[i], f, l, found ? 1 : 0, a, b);
    }
  }

  printf("\n=== which splits the kernel refuses on its own ===\n");
  {
    Handle(Geom_Curve) line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    TopoDS_Edge        e    = BRepBuilderAPI_MakeEdge(line, -5.0, 5.0).Edge();
    // 0 is the midpoint, -5 and 5 are the vertices, 6 and 100 are outside the range entirely.
    for (double param : {0.0, 2.0, -5.0, 5.0, 6.0, 100.0})
    {
      double             f, l;
      Handle(Geom_Curve) c    = BRep_Tool::Curve(e, f, l);
      gp_Pnt             mid  = c->Value((f + l) / 2.0);
      TopoDS_Face        face =
        BRepBuilderAPI_MakeFace(gp_Pln(mid, gp_Dir(0, 0, 1)), -1000, 1000, -1000, 1000).Face();
      TopoDS_Vertex      vert = BRepBuilderAPI_MakeVertex(gp_Pnt(param, 0, 0)).Vertex();
      ShapeFix_SplitTool tool;
      TopoDS_Edge        newE1, newE2;
      bool ok = tool.SplitEdge(e, param, vert, face, newE1, newE2, 1e-6, 1e-6);
      if (!ok || newE1.IsNull() || newE2.IsNull())
        printf("  param=%-8g REFUSED\n", param);
      else
        printf("  param=%-8g len1=%.12g len2=%.12g sum=%.12g\n",
               param, edgeLength(newE1), edgeLength(newE2),
               edgeLength(newE1) + edgeLength(newE2));
    }
  }

  printf("\ndone\n");
  return 0;
}
