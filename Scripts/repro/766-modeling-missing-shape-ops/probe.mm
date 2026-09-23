// Epic #766, Tests/OCCTModelingTests/MissingShapeOpsTests.swift: kernel parity for all seven tests.
// Same inputs, straight to the OCCT calls the bridge makes: BRepPrimAPI_MakeTorus
// (OCCTShapeCreateTorus), BRepFilletAPI_MakeChamfer on every explorer edge (OCCTShapeChamfer),
// BRepOffsetAPI_MakeOffsetShape::PerformBySimple (OCCTShapeOffset), gp_Trsf::SetScale about the
// origin and SetMirror(gp_Ax2) through BRepBuilderAPI_Transform (OCCTShapeScale, OCCTShapeMirror),
// BRepAlgoAPI_Section with the plane z = const (OCCTShapeSliceAtZ), and the same section chained
// by ShapeAnalysis_FreeBounds::ConnectEdgesToWires at 1e-6 (OCCTShapeSectionWiresAtZ).
// Bounding boxes are BRepBndLib::Add, as Shape.bounds reads them.
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

static void box(const char* label, const TopoDS_Shape& s)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: bounds min=(%g, %g, %g) max=(%g, %g, %g) size=(%.6g, %.6g, %.6g) centre=(%g, %g, %g)\n", label,
         x0, y0, z0, x1, y1, z1, x1 - x0, y1 - y0, z1 - z0, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
}

static void section(double z, const TopoDS_Shape& s)
{
  BRepAlgoAPI_Section sec(s, gp_Pln(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1)));
  sec.Build();
  printf("sliceAtZ(%g): done=%d", z, sec.IsDone());
  if (!sec.IsDone())
  {
    printf("\n");
    return;
  }
  const TopoDS_Shape& r = sec.Shape();
  printf(" type=%d edges=%d vertices=%d valid=%d\n", (int)r.ShapeType(), count(r, TopAbs_EDGE),
         count(r, TopAbs_VERTEX), BRepCheck_Analyzer(r).IsValid());
  if (count(r, TopAbs_EDGE) > 0)
    box("  section", r);
  Handle(TopTools_HSequenceOfShape) edges = new TopTools_HSequenceOfShape, wires;
  for (TopExp_Explorer ex(r, TopAbs_EDGE); ex.More(); ex.Next())
    edges->Append(ex.Current());
  if (edges->Length() == 0)
  {
    printf("sectionWiresAtZ(%g): no edges (bridge returns nullptr, Swift [])\n", z);
    return;
  }
  wires = new TopTools_HSequenceOfShape;
  ShapeAnalysis_FreeBounds::ConnectEdgesToWires(edges, 1e-6, Standard_False, wires);
  printf("sectionWiresAtZ(%g): wires=%d", z, wires->Length());
  for (int i = 1; i <= wires->Length(); i++)
    printf(" [wire %d: edges=%d closed=%d]", i, count(wires->Value(i), TopAbs_EDGE),
           wires->Value(i).Closed());
  printf("\n");
}

int main()
{
  TopoDS_Shape torus = BRepPrimAPI_MakeTorus(10, 3).Shape();
  printf("torusCreation: valid=%d volume=%.10g expected 2*pi^2*10*9=%.10g\n", BRepCheck_Analyzer(torus).IsValid(),
         volume(torus), 2 * M_PI * M_PI * 90);

  TopoDS_Shape              b10 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  BRepFilletAPI_MakeChamfer ch(b10);
  for (TopExp_Explorer ex(b10, TopAbs_EDGE); ex.More(); ex.Next())
    ch.Add(1.0, TopoDS::Edge(ex.Current()));
  ch.Build();
  printf("chamferBox: done=%d valid=%d faces=%d volume=%.10g\n", ch.IsDone(), BRepCheck_Analyzer(ch.Shape()).IsValid(),
         count(ch.Shape(), TopAbs_FACE), volume(ch.Shape()));

  BRepOffsetAPI_MakeOffsetShape off;
  off.PerformBySimple(b10, 1.0);
  printf("offsetSolid: done=%d valid=%d volume=%.10g (original 1000)\n", off.IsDone(),
         off.IsDone() ? BRepCheck_Analyzer(off.Shape()).IsValid() : 0, off.IsDone() ? volume(off.Shape()) : 0.0);

  gp_Trsf sc;
  sc.SetScale(gp_Pnt(0, 0, 0), 2.0);
  TopoDS_Shape scaled = BRepBuilderAPI_Transform(b10, sc, Standard_True).Shape();
  printf("scaleShape: valid=%d\n", BRepCheck_Analyzer(scaled).IsValid());
  box("scaleShape", scaled);

  TopoDS_Shape b5 = BRepPrimAPI_MakeBox(gp_Pnt(5, 0, 0), 10, 10, 10).Shape();
  gp_Trsf      mi;
  mi.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
  TopoDS_Shape mirrored = BRepBuilderAPI_Transform(b5, mi, Standard_True).Shape();
  printf("mirrorShape: valid=%d\n", BRepCheck_Analyzer(mirrored).IsValid());
  box("mirrorShape input", b5);
  box("mirrorShape", mirrored);

  section(5, b10);
  section(0, b10);
  section(6, b10);
  return 0;
}
