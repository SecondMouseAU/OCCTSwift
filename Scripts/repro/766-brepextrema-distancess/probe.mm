// Kernel parity probe for Tests/OCCTAnalysisTests/BRepExtremaDistanceSSTests.swift (#766).
//
// vertexDistance reaches OCCTBRepExtremaDistanceSS (OCCTBridge_Topology_Extrema.mm): Bnd_Box of
// each shape via BRepBndLib::Add, BRepExtrema_DistanceSS(s1, s2, b1, b2, 1e10, deflection = 1e-7),
// IsDone, DistValue, Seq1Value/Seq2Value first points.
// edgeVertexDistance reaches OCCTShapeDistance (OCCTBridge_Properties.mm):
// BRepExtrema_DistShapeShape(s1, s2, deflection = 1e-6), IsDone, NbSolution, Value, PointOnShape1/2(1).
// Also runs DistanceSS on the edge-vertex pair, to record what the test's comment says it skips.
//
// Inputs: Shape.box(1, 1, 1) is centred (corner (-0.5, -0.5, -0.5)); Shape.box(origin:) puts the
// corner at origin (OCCTShapeCreateBoxAt). subShapes(ofType:).first is the first entry of
// TopExp::MapShapes.
#include <BRepBndLib.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepExtrema_DistanceSS.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

static TopoDS_Shape first(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m(1);
}

static void distanceSS(const char* label, const TopoDS_Shape& s1, const TopoDS_Shape& s2)
{
  Bnd_Box b1, b2;
  BRepBndLib::Add(s1, b1);
  BRepBndLib::Add(s2, b2);
  BRepExtrema_DistanceSS dss(s1, s2, b1, b2, 1e10, 1e-7);
  int                    n = dss.Seq1Value().Size();
  printf("%s DistanceSS isDone=%d distance=%.17g solutions=%d\n", label, (int)dss.IsDone(), dss.DistValue(), n);
  if (n > 0)
  {
    gp_Pnt p1 = dss.Seq1Value().First().Point();
    gp_Pnt p2 = dss.Seq2Value().First().Point();
    printf("%s DistanceSS p1=(%.17g, %.17g, %.17g) p2=(%.17g, %.17g, %.17g)\n", label, p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
  }
}

int main()
{
  TopoDS_Shape box1 = BRepPrimAPI_MakeBox(gp_Pnt(-0.5, -0.5, -0.5), 1, 1, 1).Shape();
  {
    TopoDS_Shape box2 = BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 1, 1, 1).Shape();
    TopoDS_Shape v1   = first(box1, TopAbs_VERTEX);
    TopoDS_Shape v2   = first(box2, TopAbs_VERTEX);
    gp_Pnt       a    = BRep_Tool::Pnt(TopoDS::Vertex(v1));
    gp_Pnt       b    = BRep_Tool::Pnt(TopoDS::Vertex(v2));
    printf("vertexDistance v1=(%.17g, %.17g, %.17g) v2=(%.17g, %.17g, %.17g)\n", a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
    distanceSS("vertexDistance", v1, v2);
  }
  {
    TopoDS_Shape box2 = BRepPrimAPI_MakeBox(gp_Pnt(5, 5, 0), 1, 1, 1).Shape();
    TopoDS_Shape e    = first(box1, TopAbs_EDGE);
    TopoDS_Shape v    = first(box2, TopAbs_VERTEX);
    gp_Pnt       b    = BRep_Tool::Pnt(TopoDS::Vertex(v));
    printf("edgeVertexDistance v=(%.17g, %.17g, %.17g)\n", b.X(), b.Y(), b.Z());
    BRepExtrema_DistShapeShape d(e, v, 1e-6);
    printf("edgeVertexDistance DistShapeShape isDone=%d nbSolution=%d distance=%.17g\n", (int)d.IsDone(), d.NbSolution(), d.Value());
    if (d.IsDone() && d.NbSolution() > 0)
    {
      gp_Pnt p1 = d.PointOnShape1(1);
      gp_Pnt p2 = d.PointOnShape2(1);
      printf("edgeVertexDistance DistShapeShape p1=(%.17g, %.17g, %.17g) p2=(%.17g, %.17g, %.17g)\n", p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
    }
    distanceSS("edgeVertexDistance", e, v);
  }
  return 0;
}
