// Kernel parity probe for Tests/OCCTAnalysisTests/DistAngleChamferTests.swift (#766).
//
// Same calls as OCCTShapeChamferDistAngle (OCCTBridge_Modeling_Fillet.mm): BRepFilletAPI_MakeChamfer
// on the centred 10-unit box (OCCTShapeCreateBox), edge and face taken from TopExp::MapShapes at
// 0-based index 0, AddDA(distance, degrees * M_PI / 180, edge, face), Build, IsDone. The result
// is then measured the way the rewritten tests measure it: BRepCheck_Analyzer (OCCTShapeIsValid),
// BRepGProp::VolumeProperties (Shape.volume), and the face count.
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cmath>
#include <cstdio>

static void run(double degrees)
{
  BRepPrimAPI_MakeBox        mk(gp_Pnt(-5, -5, -5), 10, 10, 10);
  TopoDS_Shape               box = mk.Shape();
  TopTools_IndexedMapOfShape edges, faces;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  BRepFilletAPI_MakeChamfer ch(box);
  ch.AddDA(1.0, degrees * M_PI / 180.0, TopoDS::Edge(edges(1)), TopoDS::Face(faces(1)));
  ch.Build();
  if (!ch.IsDone())
  {
    printf("angle=%g not done\n", degrees);
    return;
  }
  TopoDS_Shape r = ch.Shape();
  GProp_GProps g;
  BRepGProp::VolumeProperties(r, g);
  TopTools_IndexedMapOfShape rf;
  TopExp::MapShapes(r, TopAbs_FACE, rf);
  const double removed = 0.5 * 1.0 * std::tan(degrees * M_PI / 180.0) * 10.0;
  printf("angle=%g valid=%d faces=%d volume=%.17g (1000 - 0.5*d*d*tan(a)*10 = %.17g)\n",
         degrees,
         (int)BRepCheck_Analyzer(r).IsValid(),
         rf.Extent(),
         g.Mass(),
         1000.0 - removed);
}

int main()
{
  run(45.0);
  run(30.0);
  run(60.0);
  return 0;
}
