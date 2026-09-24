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

#include <XCAFPrs_DocumentExplorer.hxx>
#include <XCAFPrs_Style.hxx>

// DocumentExplorerExtensionTests: depth / IsAssembly / Location of the leaf-only explorer, for a
// plain box and for a real one-component assembly (part at +5 in x).
static void dump(const char* what, const Handle(TDocStd_Document)& d)
{
  int n = 0;
  for (XCAFPrs_DocumentExplorer e(d, XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes, XCAFPrs_Style()); e.More(); e.Next(), n++)
  {
    const XCAFPrs_DocumentNode& node = e.Current();
    gp_Trsf t = node.Location.Transformation();
    printf("%s node[%d]: depth=%d IsAssembly(node.Label)=%s IsAssembly(node.RefLabel)=%s locIdentity=%s matrix=[", what, n,
           e.CurrentDepth(), tf(XCAFDoc_ShapeTool::IsAssembly(node.Label)), tf(XCAFDoc_ShapeTool::IsAssembly(node.RefLabel)),
           tf(node.Location.IsIdentity()));
    for (int r = 1; r <= 3; r++)
      for (int c = 1; c <= 4; c++)
        printf("%g%s", node.Location.IsIdentity() ? (r == c ? 1.0 : 0.0) : t.Value(r, c), (r == 3 && c == 4) ? "" : ", ");
    printf("]\n");
  }
  printf("%s leaf count=%d\n", what, n);
}

// The bridge's lookup (OCCTDocumentExplorerDepth / IsAssembly / Location): walk the leaf-only explorer
// and stop at the node whose flat index equals `index`; report whether one was reached.
static bool nodeAt(const Handle(TDocStd_Document)& d, int index)
{
  int i = 0;
  for (XCAFPrs_DocumentExplorer e(d, XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes, XCAFPrs_Style()); e.More(); e.Next(), i++)
    if (i == index)
      return true;
  return false;
}

int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(10, 10, 10), true);
  dump("box", d);
  printf("box: node at index 0 reached=%s, node at index count+100 (101) reached=%s\n", tf(nodeAt(d, 0)), tf(nodeAt(d, 101)));

  Handle(TDocStd_Application) app2;
  Handle(TDocStd_Document)    d2 = newDoc(app2);
  Handle(XCAFDoc_ShapeTool)   st = XCAFDoc_DocumentTool::ShapeTool(d2->Main());
  TDF_Label part = st->AddShape(centredBox(10, 10, 10), false);
  TDF_Label asmL = st->NewShape();
  gp_Trsf tr; tr.SetTranslation(gp_Vec(5, 0, 0));
  TDF_Label comp = st->AddComponent(asmL, part, TopLoc_Location(tr));
  st->UpdateAssemblies();
  printf("assembly: component null=%s asm IsAssembly=%s\n", tf(comp.IsNull()), tf(XCAFDoc_ShapeTool::IsAssembly(asmL)));
  dump("assembly", d2);
  // Out-of-range index: the bridge's pre-filled fallback is the row-major 3x4 identity
  // (slots 0, 5, 10); the pre-#1480 formula (i % 4 == i / 3) set slots:
  printf("old fallback formula sets 1.0 at:");
  for (int j = 0; j < 12; j++) if (j % 4 == j / 3) printf(" %d", j);
  printf("\n");
  return 0;
}
