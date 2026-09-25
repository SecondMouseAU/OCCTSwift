// Epic #766, Tests/OCCTModelingTests/LocOpeSpliterV71Tests.swift: kernel parity for both tests.
// splitByWireOnFace: OCCTLocOpeSplitByWires binds (wire, face) with LocOpe_WiresOnShape::Bind (no
// BindAll) and runs LocOpe_Spliter; the test tries every face of the origin-cornered 10 mm box
// with the edge (0,5,10)-(10,5,10) made into a wire by BOPAlgo_WireSplitter::MakeWire.
// autoSplit: OCCTLocOpeSplitByWiresAuto adds the wire's edges with LocOpe_WiresOnShape::Add and
// BindAll()s them, on the CENTRED box (-5..5), where z=10 is off the shape.
#include <BOPAlgo_WireSplitter.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepLib_MakeEdge.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <LocOpe_Spliter.hxx>
#include <LocOpe_WiresOnShape.hxx>
#include <NCollection_Sequence.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static int nfaces(const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_FACE, m);
  return m.Extent();
}

int main()
{
  TopoDS_Edge                    e = BRepLib_MakeEdge(gp_Pnt(0, 5, 10), gp_Pnt(10, 5, 10)).Edge();
  NCollection_List<TopoDS_Shape> edges;
  edges.Append(e);
  TopoDS_Wire w;
  BOPAlgo_WireSplitter::MakeWire(edges, w);
  printf("wire null=%d\n", w.IsNull());

  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  int best = faces.Extent();
  for (int i = 1; i <= faces.Extent(); i++)
  {
    try
    {
      Handle(LocOpe_WiresOnShape) wos = new LocOpe_WiresOnShape(box);
      wos->Bind(w, TopoDS::Face(faces(i)));
      LocOpe_Spliter sp(box);
      sp.Perform(wos);
      if (!sp.IsDone() || sp.ResultingShape().IsNull())
      {
        printf("splitByWireOnFace face %d: not done\n", i - 1);
        continue;
      }
      int n = nfaces(sp.ResultingShape());
      printf("splitByWireOnFace face %d: faces=%d valid=%d directLeft=%d\n", i - 1, n,
             BRepCheck_Analyzer(sp.ResultingShape()).IsValid(), sp.DirectLeft().Extent());
      if (n > best)
        best = n;
    }
    catch (Standard_Failure& ex)
    {
      printf("splitByWireOnFace face %d: threw %s\n", i - 1, ex.what());
    }
  }
  printf("splitByWireOnFace: original=%d best=%d\n", faces.Extent(), best);

  TopoDS_Shape centred = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  try
  {
    Handle(LocOpe_WiresOnShape)        wos = new LocOpe_WiresOnShape(centred);
    NCollection_Sequence<TopoDS_Shape> seq;
    for (TopExp_Explorer ex(w, TopAbs_EDGE); ex.More(); ex.Next())
      seq.Append(ex.Current());
    wos->Add(seq);
    wos->BindAll();
    LocOpe_Spliter sp(centred);
    sp.Perform(wos);
    printf("autoSplit: done=%d", sp.IsDone());
    if (sp.IsDone() && !sp.ResultingShape().IsNull())
      printf(" faces=%d valid=%d", nfaces(sp.ResultingShape()), BRepCheck_Analyzer(sp.ResultingShape()).IsValid());
    printf("\n");
  }
  catch (Standard_Failure& ex)
  {
    printf("autoSplit: threw %s\n", ex.what());
  }
  // The same auto split with the edge actually on the centred box's top face (z=5).
  try
  {
    TopoDS_Edge                    e5 = BRepLib_MakeEdge(gp_Pnt(-5, 0, 5), gp_Pnt(5, 0, 5)).Edge();
    Handle(LocOpe_WiresOnShape)        wos = new LocOpe_WiresOnShape(centred);
    NCollection_Sequence<TopoDS_Shape> seq;
    seq.Append(e5);
    wos->Add(seq);
    wos->BindAll();
    LocOpe_Spliter sp(centred);
    sp.Perform(wos);
    printf("autoSplit (edge on z=5 face): done=%d", sp.IsDone());
    if (sp.IsDone() && !sp.ResultingShape().IsNull())
      printf(" faces=%d valid=%d", nfaces(sp.ResultingShape()), BRepCheck_Analyzer(sp.ResultingShape()).IsValid());
    printf("\n");
  }
  catch (Standard_Failure& ex)
  {
    printf("autoSplit (edge on z=5 face): threw %s\n", ex.what());
  }
  return 0;
}
