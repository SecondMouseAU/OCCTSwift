// Epic #766 evidence fix, Tests/OCCTModelingTests/MissingShapeOpsTests.swift.
// probe.mm printed most numbers at %g, %.6g or %.10g. This probe repeats the same OCCT calls the bridge makes
// (BRepPrimAPI_MakeTorus for OCCTShapeCreateTorus, BRepFilletAPI_MakeChamfer on every explorer edge for
// OCCTShapeChamfer, BRepOffsetAPI_MakeOffsetShape::PerformBySimple for OCCTShapeOffset, gp_Trsf::SetScale and
// SetMirror through BRepBuilderAPI_Transform for OCCTShapeScale and OCCTShapeMirror, BRepAlgoAPI_Section with the
// plane z = const for OCCTShapeSliceAtZ, and that section chained by ShapeAnalysis_FreeBounds::ConnectEdgesToWires
// at 1e-6 for OCCTShapeSectionWiresAtZ) and prints every quantity the tests observe at %.17g. Bounding boxes are
// BRepBndLib::Add with triangulation, as Shape.bounds reads them (occtComputeBoundingBox); size and centre are
// max - min and (min + max) / 2, as Shape.size and Shape.center compute them.
#include <BRepAlgoAPI_Section.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_HSequenceOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <gp_Pln.hxx>

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static void bounds(const TopoDS_Shape& s, double* size, double* centre)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  size[0]   = x1 - x0;
  size[1]   = y1 - y0;
  size[2]   = z1 - z0;
  centre[0] = (x0 + x1) / 2;
  centre[1] = (y0 + y1) / 2;
  centre[2] = (z0 + z1) / 2;
}

int main()
{
  double size[3], centre[3];

  TopoDS_Shape torus = BRepPrimAPI_MakeTorus(10, 3).Shape();
  printf("torusCreation: valid=%d volume=%.17g analytic=%.17g\n", BRepCheck_Analyzer(torus).IsValid(), volume(torus),
         2.0 * M_PI * M_PI * 10.0 * 9.0);

  // Shape.box(width:height:depth:) is centred on the origin; the chamfer, offset and section inputs.
  TopoDS_Shape              b10 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  BRepFilletAPI_MakeChamfer ch(b10);
  for (TopExp_Explorer ex(b10, TopAbs_EDGE); ex.More(); ex.Next())
    ch.Add(1.0, TopoDS::Edge(ex.Current()));
  ch.Build();
  printf("chamferBox: produced=%d valid=%d faces=%d volume=%.17g\n", ch.IsDone(), BRepCheck_Analyzer(ch.Shape()).IsValid(),
         count(ch.Shape(), TopAbs_FACE), volume(ch.Shape()));

  BRepOffsetAPI_MakeOffsetShape off;
  off.PerformBySimple(b10, 1.0);
  printf("offsetSolid: produced=%d valid=%d volume=%.17g original=%.17g\n", off.IsDone(),
         off.IsDone() ? BRepCheck_Analyzer(off.Shape()).IsValid() : 0, off.IsDone() ? volume(off.Shape()) : 0.0, volume(b10));

  gp_Trsf sc;
  sc.SetScale(gp_Pnt(0, 0, 0), 2.0);
  TopoDS_Shape scaled = BRepBuilderAPI_Transform(b10, sc, Standard_True).Shape();
  bounds(scaled, size, centre);
  printf("scaleShape: valid=%d size=(%.17g, %.17g, %.17g)\n", BRepCheck_Analyzer(scaled).IsValid(), size[0], size[1], size[2]);

  TopoDS_Shape b5 = BRepPrimAPI_MakeBox(gp_Pnt(5, 0, 0), 10, 10, 10).Shape();
  gp_Trsf      mi;
  mi.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
  TopoDS_Shape mirrored = BRepBuilderAPI_Transform(b5, mi, Standard_True).Shape();
  bounds(mirrored, size, centre);
  printf("mirrorShape: valid=%d centre=(%.17g, %.17g, %.17g)\n", BRepCheck_Analyzer(mirrored).IsValid(), centre[0], centre[1],
         centre[2]);

  // sliceAtZ(5) and sectionWiresAtZ(5) on the centred 10 mm box: the top face's plane.
  BRepAlgoAPI_Section sec(b10, gp_Pln(gp_Pnt(0, 0, 5), gp_Dir(0, 0, 1)));
  sec.Build();
  const TopoDS_Shape& r = sec.Shape();
  bounds(r, size, centre);
  printf("sliceAtZ(5): produced=%d valid=%d edges=%d centreZ=%.17g\n", sec.IsDone(), BRepCheck_Analyzer(r).IsValid(),
         count(r, TopAbs_EDGE), centre[2]);
  Handle(TopTools_HSequenceOfShape) edges = new TopTools_HSequenceOfShape, wires = new TopTools_HSequenceOfShape;
  for (TopExp_Explorer ex(r, TopAbs_EDGE); ex.More(); ex.Next())
    edges->Append(ex.Current());
  ShapeAnalysis_FreeBounds::ConnectEdgesToWires(edges, 1e-6, Standard_False, wires);
  printf("sectionWiresAtZ(5): wires=%d", wires->Length());
  for (int i = 1; i <= wires->Length(); i++)
    printf(" [wire %d: edges=%d closed=%d]", i, count(wires->Value(i), TopAbs_EDGE), wires->Value(i).Closed());
  printf("\n");
  return 0;
}
