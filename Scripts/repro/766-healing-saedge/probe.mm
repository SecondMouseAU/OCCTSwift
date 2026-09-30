// #766 kernel parity: SAEdgeAnalysisTests. ShapeAnalysis_Edge on the same edges and faces the
// tests pick: Shape.subShapes(ofType:) is TopExp::MapShapes order (OCCTShapeGetSubShapes), so
// "edges.first" is the box's first mapped edge and "faces.first" its first mapped face.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom2d_Circle.hxx>
#include <ShapeAnalysis_Edge.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape edges, faces;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  TopoDS_Edge                e0 = TopoDS::Edge(edges(1)), e1 = TopoDS::Edge(edges(2));
  TopoDS_Face                f0 = TopoDS::Face(faces(1));
  TopTools_IndexedMapOfShape fedges;
  TopExp::MapShapes(f0, TopAbs_EDGE, fedges);
  TopoDS_Edge        fe = TopoDS::Edge(fedges(1));
  ShapeAnalysis_Edge sae;
  printf("box edge0 == face0 edge0: %d\n", (int)e0.IsSame(fe));
  printf("HasCurve3d(e0)=%d IsClosed3d(e0)=%d HasPCurve(e0,f0)=%d IsSeam(e0,f0)=%d\n", (int)sae.HasCurve3d(e0),
         (int)sae.IsClosed3d(e0), (int)sae.HasPCurve(e0, f0), (int)sae.IsSeam(e0, f0));
  double maxdev = 0;
  bool   sp     = sae.CheckSameParameter(e0, maxdev);
  printf("CheckSameParameter(e0)=%d maxdev=%.3e\n", (int)sp, maxdev);
  printf("CheckVerticesWithCurve3d(e0, -1)=%d  (e0, 1e-6)=%d\n", (int)sae.CheckVerticesWithCurve3d(e0, -1),
         (int)sae.CheckVerticesWithCurve3d(e0, 1e-6));
  printf("CheckVerticesWithPCurve(e0, f0, -1)=%d CheckCurve3dWithPCurve(e0, f0)=%d\n",
         (int)sae.CheckVerticesWithPCurve(e0, f0, -1), (int)sae.CheckCurve3dWithPCurve(e0, f0));
  gp_Pnt a = BRep_Tool::Pnt(sae.FirstVertex(e0)), b = BRep_Tool::Pnt(sae.LastVertex(e0));
  printf("FirstVertex(e0)=(%g, %g, %g) LastVertex(e0)=(%g, %g, %g)\n", a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
  double t1 = 0, t2 = 0;
  bool   vt = sae.CheckVertexTolerance(e0, f0, t1, t2);
  printf("CheckVertexTolerance(e0, f0)=%d toler1=%.3e toler2=%.3e\n", (int)vt, t1, t2);
  double ov = 1e-7;
  bool   o1 = sae.CheckOverlapping(e0, e1, ov, 0.0);
  printf("CheckOverlapping(e0, e1, 1e-7)=%d tol=%.3e\n", (int)o1, ov);
  ov      = 1e-7;
  bool o2 = sae.CheckOverlapping(e0, e0, ov, 0.0);
  printf("CheckOverlapping(e0, e0, 1e-7)=%d tol=%.3e\n", (int)o2, ov);
  gp_Pnt2d p1, p2;
  bool     bu = sae.BoundUV(fe, f0, p1, p2);
  printf("BoundUV(fe, f0)=%d first=(%g, %g) last=(%g, %g)\n", (int)bu, p1.X(), p1.Y(), p2.X(), p2.Y());
  gp_Pnt2d pos;
  gp_Vec2d tan;
  bool     et = sae.GetEndTangent2d(fe, f0, false, pos, tan);
  printf("GetEndTangent2d(fe, f0, start)=%d pos=(%g, %g) tangent=(%g, %g)\n", (int)et, pos.X(), pos.Y(), tan.X(), tan.Y());
  printf("CheckPCurveRange(fe, f0, 0, 10)=%d\n", (int)sae.CheckPCurveRange(0, 10, BRep_Tool::CurveOnSurface(fe, f0, p1.ChangeCoord().ChangeCoord(1), p2.ChangeCoord().ChangeCoord(1))));

  // #1577: two edges 0.005 apart, tolerances loosened to 0.01, joined by MakeWire
  {
    TopoDS_Edge  ea = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge  eb = BRepBuilderAPI_MakeEdge(gp_Pnt(10.005, 0, 0), gp_Pnt(20, 0, 0));
    BRep_Builder bb;
    for (TopoDS_Edge* e : {&ea, &eb})
    {
      bb.UpdateEdge(*e, 0.01);
      TopoDS_Vertex v1, v2;
      TopExp::Vertices(*e, v1, v2);
      bb.UpdateVertex(v1, 0.01);
      bb.UpdateVertex(v2, 0.01);
    }
    BRepBuilderAPI_MakeWire mw;
    mw.Add(ea);
    mw.Add(eb);
    printf("#1577 wire done=%d:", (int)mw.IsDone());
    if (mw.IsDone())
    {
      TopTools_IndexedMapOfShape we;
      TopExp::MapShapes(mw.Wire(), TopAbs_EDGE, we);
      for (int i = 1; i <= we.Extent(); i++)
        printf(" edge%d: fixed1e-6=%d sentinel=%d;", i, (int)sae.CheckVerticesWithCurve3d(TopoDS::Edge(we(i)), 1e-6),
               (int)sae.CheckVerticesWithCurve3d(TopoDS::Edge(we(i)), -1));
    }
    printf("\n");
  }
  // #1438 pcurve range: circle pcurve (centre (0,5), r 3) on a cylinder r5, edge trimmed [0, pi/2]
  {
    Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    Handle(Geom2d_Circle)           pc  = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 5), gp_Dir2d(1, 0)), 3);
    printf("#1438 CheckPCurveRange(0, pi)=%d CheckPCurveRange(0, 2pi+0.5)=%d\n", (int)sae.CheckPCurveRange(0, M_PI, pc),
           (int)sae.CheckPCurveRange(0, 2 * M_PI + 0.5, pc));
  }
  return 0;
}
