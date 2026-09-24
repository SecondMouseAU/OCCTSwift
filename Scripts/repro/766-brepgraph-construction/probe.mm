// Kernel-parity probe for #1986 (Epic #766): ConstructionAxisTests, ConstructionPlaneTests,
// ConstructionPointTests, ContainedInTests, TopologyRefResolverTests,
// Issue881PerpendicularBasisTests. The Swift resolvers compose OCCTSwift calls; this probe
// evaluates the same OCCT calls those bridge functions make (BRepGraph_Tool::Vertex::Pnt,
// BRepGraph_ChildExplorer, BRep_Tool::Curve + D0/GeomLProp_CLProps, GeomLProp_SLProps with
// face-orientation reversal as in OCCTFaceGetNormalAtUV, BRepGProp::SurfaceProperties,
// gp_Ax2) on each test's inputs, so the Swift-composed answer can be checked against it.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <GeomLProp_SLProps.hxx>
#include <GeomLProp_CLProps.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Precision.hxx>
#include <TopoDS.hxx>
#include <TopExp_Explorer.hxx>
#include <gp_Ax2.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_ChildExplorer.hxx>
#include <cmath>
#include <cstdio>

static void build(BRepGraph& g, const TopoDS_Shape& s) // OCCTBRepGraphCreate
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  (void)g.Shapes().Add(s, opts);
}

static gp_Pnt vtx(const BRepGraph& g, int i) // OCCTBRepGraphVertexPoint
{
  return BRepGraph_Tool::Vertex::Pnt(g, BRepGraph_VertexId(i));
}

static TopoDS_Face faceOf(const BRepGraph& g, int i) // OCCTBRepGraphShapeFromNode(face)
{
  return TopoDS::Face(g.Shapes().Shape(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, i)));
}

// Face.uvMidpointSample: UV bounds midpoint, point + orientation-corrected normal.
static void uvMid(const TopoDS_Face& f, gp_Pnt& p, gp_Dir& n)
{
  double u0, u1, v0, v1;
  BRepTools::UVBounds(f, u0, u1, v0, v1);
  GeomLProp_SLProps pr(BRep_Tool::Surface(f), (u0 + u1) / 2, (v0 + v1) / 2, 1,
                       Precision::Confusion());
  p = pr.Value();
  n = pr.Normal();
  if (f.Orientation() == TopAbs_REVERSED)
    n.Reverse();
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  BRepGraph    g;
  build(g, box);

  // Vertices 0..2 (atVertex, byThreePoints, coincident/collinear use vertex 0).
  for (int i = 0; i < 3; ++i)
  {
    gp_Pnt p = vtx(g, i);
    printf("box vertex %d = (%.6f, %.6f, %.6f)\n", i, p.X(), p.Y(), p.Z());
  }
  {
    gp_Vec a(vtx(g, 0), vtx(g, 1)), b(vtx(g, 0), vtx(g, 2));
    gp_Vec n = a.Crossed(b);
    printf("byThreePoints(v0,v1,v2): cross = (%.6f, %.6f, %.6f), |n| = %.6f\n", n.X(), n.Y(),
           n.Z(), n.Magnitude());
  }

  // Edge 0: endpoints, point + tangent at linear fraction 0.25 / 0.5.
  {
    TopoDS_Edge e =
      TopoDS::Edge(g.Shapes().Shape(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Edge, 0)));
    double f, l;
    auto   c = BRep_Tool::Curve(e, f, l);
    for (double t : {0.0, 0.25, 0.5, 1.0})
    {
      GeomLProp_CLProps pr(c, f + (l - f) * t, 1, Precision::Confusion());
      gp_Pnt            p = pr.Value();
      gp_Dir            d;
      pr.Tangent(d);
      printf("box edge 0 at fraction %.2f: point = (%.6f, %.6f, %.6f) tangent = (%.6f, %.6f, "
             "%.6f)\n",
             t, p.X(), p.Y(), p.Z(), d.X(), d.Y(), d.Z());
    }
  }

  // Face 0 UV-midpoint sample (offsetFromFace, normalToFace plane fallback).
  {
    gp_Pnt p;
    gp_Dir n;
    uvMid(faceOf(g, 0), p, n);
    printf("box face 0 uvMidpoint: point = (%.6f, %.6f, %.6f) normal = (%.6f, %.6f, %.6f) "
           "orientation=%d\n",
           p.X(), p.Y(), p.Z(), n.X(), n.Y(), n.Z(), (int)faceOf(g, 0).Orientation());
    printf("offsetFromFace(face 0, 5): origin = (%.6f, %.6f, %.6f)\n", p.X() + 5 * n.X(),
           p.Y() + 5 * n.Y(), p.Z() + 5 * n.Z());
  }

  // containedIn(solid 0, face, k): BRepGraph_ChildExplorer order.
  {
    BRepGraph_ChildExplorer ex(g, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0),
                               BRepGraph_NodeId::Kind::Face);
    printf("childIndices(solid 0, face):");
    int n = 0;
    for (; ex.More(); ex.Next(), ++n)
      printf(" %d", (int)ex.Current().DefId.Index);
    printf("  (count %d)\n", n);
  }

  // Cylinder r=5 h=10: face 0 axis, vertex 1, rims, lateral-face centroid.
  {
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    BRepGraph    cg;
    build(cg, cyl);
    TopoDS_Face f0 = faceOf(cg, 0);
    auto        s  = Handle(Geom_CylindricalSurface)::DownCast(BRep_Tool::Surface(f0));
    if (!s.IsNull())
    {
      gp_Ax1 ax = s->Axis();
      printf("cylinder face 0: cylindrical, axis origin (%.6f, %.6f, %.6f) dir (%.6f, %.6f, "
             "%.6f)\n",
             ax.Location().X(), ax.Location().Y(), ax.Location().Z(), ax.Direction().X(),
             ax.Direction().Y(), ax.Direction().Z());
    }
    for (int i = 0; i < (int)cg.Topo().Vertices().Nb(); ++i)
    {
      gp_Pnt p = vtx(cg, i);
      printf("cylinder vertex %d = (%.6f, %.6f, %.6f)\n", i, p.X(), p.Y(), p.Z());
    }
    // tangentToFace(face 0, vertex 1): normal at the projection of vertex 1 onto face 0.
    {
      gp_Pnt p = vtx(cg, 1);
      double u = 0, v = p.Z(); // vertex 1 sits on the seam, u = 0
      GeomLProp_SLProps pr(BRep_Tool::Surface(f0), u, v, 1, Precision::Confusion());
      gp_Dir            n = pr.Normal();
      if (f0.Orientation() == TopAbs_REVERSED)
        n.Reverse();
      printf("cylinder face 0 normal at (u=0, v=%.3f) = (%.6f, %.6f, %.6f)\n", v, n.X(), n.Y(),
             n.Z());
    }
    GProp_GProps gp;
    BRepGProp::SurfaceProperties(f0, gp);
    gp_Pnt cm = gp.CentreOfMass();
    printf("cylinder face 0 area centroid = (%.6f, %.6f, %.6f), area = %.6f\n", cm.X(), cm.Y(),
           cm.Z(), gp.Mass());
  }

  // Torus R=20 r=5: face 0 axis and vertex 0 (normalToFace torus).
  {
    BRepGraph tg;
    build(tg, BRepPrimAPI_MakeTorus(20, 5).Shape());
    auto s = Handle(Geom_ToroidalSurface)::DownCast(BRep_Tool::Surface(faceOf(tg, 0)));
    gp_Pnt p = vtx(tg, 0);
    if (!s.IsNull())
      printf("torus face 0: toroidal, axis dir (%.6f, %.6f, %.6f); vertex 0 = (%.6f, %.6f, "
             "%.6f), height along axis = %.6f\n",
             s->Axis().Direction().X(), s->Axis().Direction().Y(), s->Axis().Direction().Z(),
             p.X(), p.Y(), p.Z(), p.Z());
  }

  // alongEdgeEllipticalRim fixture: cylinder r5 h20 intersected with a big box tilted 25 degrees
  // about Y (OCCTShapeRotate: gp_Ax1 through the origin, BRepBuilderAPI_Transform copy). For
  // each elliptical edge: BRepGProp::LinearProperties length (what OCCTEdgeGetLength returns).
  {
    double       theta = 25.0 * M_PI / 180.0, z0 = 10.0 * cos(theta);
    TopoDS_Shape cyl   = BRepPrimAPI_MakeCylinder(5, 20).Shape();
    TopoDS_Shape big =
      BRepPrimAPI_MakeBox(gp_Pnt(-500, -500, -1000), 1000, 1000, 1000 + z0).Shape();
    gp_Trsf rot;
    rot.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0)), theta);
    TopoDS_Shape tilted = BRepBuilderAPI_Transform(big, rot, Standard_True).Shape();
    TopoDS_Shape cut    = BRepAlgoAPI_Common(cyl, tilted).Shape();
    for (TopExp_Explorer ex(cut, TopAbs_EDGE); ex.More(); ex.Next())
    {
      TopoDS_Edge        e = TopoDS::Edge(ex.Current());
      BRepAdaptor_Curve  c(e);
      if (c.GetType() != GeomAbs_Ellipse)
        continue;
      GProp_GProps gp;
      BRepGProp::LinearProperties(e, gp);
      gp_Pnt p0 = c.Value(c.FirstParameter()), p1 = c.Value(c.LastParameter());
      printf("ellipse rim edge: params [%.6f, %.6f] length=%.9f start=(%.4f,%.4f,%.4f) "
             "end=(%.4f,%.4f,%.4f) closed=%d\n",
             c.FirstParameter(), c.LastParameter(), gp.Mass(), p0.X(), p0.Y(), p0.Z(), p1.X(),
             p1.Y(), p1.Z(), BRep_Tool::IsClosed(e) ? 1 : 0);
    }
  }

  // Issue881: gp_Ax2(origin, dir) canonical X/Y for the oblique and the six axis normals.
  {
    double d15 = 15.0 * M_PI / 180.0;
    gp_Dir dirs[7] = {gp_Dir(sin(d15) * 0.6, sin(d15) * 0.8, cos(d15)),
                      gp_Dir(1, 0, 0), gp_Dir(-1, 0, 0), gp_Dir(0, 1, 0),
                      gp_Dir(0, -1, 0), gp_Dir(0, 0, 1), gp_Dir(0, 0, -1)};
    for (auto& d : dirs)
    {
      gp_Ax2 a(gp_Pnt(0, 0, 0), d);
      printf("gp_Ax2 N=(%.4f,%.4f,%.4f): X=(%.16g, %.16g, %.16g) Y=(%.16g, %.16g, %.16g)\n",
             d.X(), d.Y(), d.Z(), a.XDirection().X(), a.XDirection().Y(), a.XDirection().Z(),
             a.YDirection().X(), a.YDirection().Y(), a.YDirection().Z());
    }
  }
  return 0;
}
