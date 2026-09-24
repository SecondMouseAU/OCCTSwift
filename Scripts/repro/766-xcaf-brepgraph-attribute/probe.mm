// Kernel-parity probe for #766 (OCCTXCAFTests). Calls the OCCT API the bridge calls, with the
// test's inputs, and prints what the kernel returns. Build line: CLAUDE.md "Compile a Ground
// Truth C++ Test", headers/lib from the pinned OCCT.xcframework.
#include <BRepPrimAPI_MakeBox.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDF_Tool.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>
#include <TopoDS_Shape.hxx>
#include <cstdio>

// OCCTDocument(): a private TDocStd_Application (#371), NewDocument("MDTV-XCAF"), then the three
// XCAF tools occtDocumentInit fetches.
static Handle(TDocStd_Document) newDoc(Handle(TDocStd_Application)& app)
{
  app = new TDocStd_Application();
  Handle(TDocStd_Document) d;
  app->NewDocument("MDTV-XCAF", d);
  XCAFDoc_DocumentTool::ShapeTool(d->Main());
  XCAFDoc_DocumentTool::ColorTool(d->Main());
  XCAFDoc_DocumentTool::VisMaterialTool(d->Main());
  return d;
}

// getLabelForTag: tag 0 is Main, otherwise Main().FindChild(tag, create).
static TDF_Label tagLabel(const Handle(TDocStd_Document)& d, int tag)
{
  return tag == 0 ? d->Main() : d->Main().FindChild(tag, Standard_True);
}

// OCCTShapeCreateBox: centred on the origin.
static TopoDS_Shape centredBox(double w, double h, double dp)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -dp / 2), w, h, dp).Shape();
}

static const char* tf(bool b) { return b ? "true" : "false"; }

#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <sstream>

// BRepGraphAttributeTests: the attribute store and its Codable snapshot are pure Swift, so only the
// graph side has a kernel counterpart: BRepGraph built as OCCTBRepGraphCreate builds it
// (Clear, then Shapes().Add, Parallel=false, no auto product), before and after a BRepTools
// Write/Read round-trip, and BRepTools::Read of a string that is not a BREP.
static void build(BRepGraph& g, const TopoDS_Shape& s)
{
  g.Clear();
  BRepGraph::ShapesView::Options o;
  o.Parallel          = false;
  o.CreateAutoProduct = false;
  g.Shapes().Add(s, o);
}

int main()
{
  TopoDS_Shape box = centredBox(10, 20, 30);
  std::ostringstream oss;
  BRepTools::Write(box, oss);
  std::istringstream iss(oss.str());
  BRep_Builder       bb;
  TopoDS_Shape       box2;
  BRepTools::Read(box2, iss, bb);
  BRepGraph g1, g2;
  build(g1, box);
  build(g2, box2);
  printf("g1 faces=%d edges=%d vertices=%d\n", g1.Topo().Faces().Nb(), g1.Topo().Edges().Nb(), g1.Topo().Vertices().Nb());
  printf("g2 faces=%d edges=%d vertices=%d\n", g2.Topo().Faces().Nb(), g2.Topo().Edges().Nb(), g2.Topo().Vertices().Nb());
  double maxd = 0;
  for (int i = 0; i < g1.Topo().Vertices().Nb(); i++)
  {
    gp_Pnt a = BRepGraph_Tool::Vertex::Pnt(g1, BRepGraph_VertexId(i));
    gp_Pnt b = BRepGraph_Tool::Vertex::Pnt(g2, BRepGraph_VertexId(i));
    printf("  v%d g1=(%g, %g, %g) g2=(%g, %g, %g)\n", i, a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
    maxd = std::max(maxd, a.Distance(b));
  }
  printf("max vertex distance across rebuild=%g\n", maxd);
  std::istringstream bad("not a brep");
  TopoDS_Shape       junk;
  BRepTools::Read(junk, bad, bb);
  printf("BRepTools::Read(\"not a brep\") null=%s\n", tf(junk.IsNull()));
  return 0;
}
