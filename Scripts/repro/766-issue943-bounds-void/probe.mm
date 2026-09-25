// Epic #766, Tests/OCCTAnalysisTests/Issue943BoundsVoidTests.swift: kernel parity probe.
//
// Every bounds accessor the four tests read (Shape.bounds, boundingBox, boundingBoxOptimal,
// Edge.bounds, Face.bounds, Face.exactBounds) reaches occtComputeBoundingBox, which runs
// BRepBndLib::Add(shape, box, useTriangulation) or BRepBndLib::AddOptimal(shape, box,
// useTriangulation, useShapeTolerance) and answers "no box" exactly when Bnd_Box::IsVoid().
// This probe runs the same calls on the same fixtures. Scripts/repro/943-bounds-void-vs-zero/
// holds #943's own, wider probe; this one is scoped to the test file.
#include <BRepAlgoAPI_Common.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

static void report(const char* label, const TopoDS_Shape& s, bool optimal, bool useTri)
{
  Bnd_Box box;
  if (optimal)
    BRepBndLib::AddOptimal(s, box, useTri, false);
  else
    BRepBndLib::Add(s, box, useTri);
  if (box.IsVoid())
  {
    printf("%s IsVoid=1\n", label);
    return;
  }
  double x0, y0, z0, x1, y1, z1;
  box.Get(x0, y0, z0, x1, y1, z1);
  printf("%s IsVoid=0 min=(%.17g, %.17g, %.17g) max=(%.17g, %.17g, %.17g)\n",
         label, x0, y0, z0, x1, y1, z1);
}

int main()
{
  {
    // makeVoidShape(): the common of two disjoint boxes, as OCCTShapeIntersect builds it.
    TopoDS_Shape       b1 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    TopoDS_Shape       b2 = BRepPrimAPI_MakeBox(gp_Pnt(1000, 1000, 1000), 10, 10, 10).Shape();
    BRepAlgoAPI_Common common(b1, b2);
    common.Build();
    printf("voidShape common IsDone=%d\n", common.IsDone());
    report("voidShape bounds/boundingBox (Add, useTri)", common.Shape(), false, true);
    report("voidShape boundingBoxOptimal (AddOptimal)", common.Shape(), true, true);
  }
  {
    TopoDS_Shape v = BRepBuilderAPI_MakeVertex(gp_Pnt(0, 0, 0)).Shape();
    report("pointVertex bounds/boundingBox (Add, useTri)", v, false, true);
    report("pointVertex boundingBoxOptimal (AddOptimal)", v, true, true);
  }
  {
    // Shape.sphere(center: (0, 0, 5), radius: 5): its south pole's degenerate edge is at origin.
    TopoDS_Shape               sph = BRepPrimAPI_MakeSphere(gp_Pnt(0, 0, 5), 5).Shape();
    TopTools_IndexedMapOfShape edges;
    TopExp::MapShapes(sph, TopAbs_EDGE, edges);
    for (int i = 1; i <= edges.Extent(); ++i)
    {
      TopoDS_Edge e = TopoDS::Edge(edges(i));
      char        label[96];
      snprintf(label, sizeof(label), "sphereEdge[%d] degenerated=%d length=%.3g", i - 1,
               BRep_Tool::Degenerated(e),
               BRep_Tool::Degenerated(e) ? 0.0
                                         : GCPnts_AbscissaPoint::Length(BRepAdaptor_Curve(e)));
      report(label, e, false, true);
    }
  }
  {
    TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(box, TopAbs_FACE, faces);
    int occurrences = 0;
    for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next())
      ++occurrences;
    printf("boxFaces unique=%d occurrences=%d\n", faces.Extent(), occurrences);
    for (int i = 1; i <= faces.Extent(); ++i)
    {
      char label[64];
      snprintf(label, sizeof(label), "boxFace[%d] bounds (Add, useTri)", i - 1);
      report(label, faces(i), false, true);
      snprintf(label, sizeof(label), "boxFace[%d] exactBounds (Add, no tri)", i - 1);
      report(label, faces(i), false, false);
    }
  }
  return 0;
}
