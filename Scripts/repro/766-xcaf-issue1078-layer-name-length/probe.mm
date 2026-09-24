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

#include <XCAFDoc_LayerTool.hxx>
#include <TDataStd_Name.hxx>

// Issue1078LayerNameLengthTests: the layer names OCCTDocumentGetLayerName reads. The bridge reads
// XCAFDoc_LayerTool::Set(Main()), a layer tool attached to the Main label itself, while
// OCCTDocumentSetLayer writes through XCAFDoc_DocumentTool::LayerTool(Main()), the document's real
// layer table. This probe lists both, before and after a 300-character layer is set on a box.
static void list(const char* what, const Handle(XCAFDoc_LayerTool)& lt)
{
  TCollection_AsciiString entry;
  TDF_Tool::Entry(lt->Label(), entry);
  TDF_LabelSequence ls;
  lt->GetLayerLabels(ls);
  printf("%s (tool label %s): %d layer(s)\n", what, entry.ToCString(), ls.Length());
  for (int i = 1; i <= ls.Length(); i++)
  {
    TCollection_ExtendedString nm;
    lt->GetLayer(ls.Value(i), nm);
    TCollection_AsciiString a(nm);
    printf("  [%d] length=%d name=\"%.20s%s\"\n", i - 1, a.Length(), a.ToCString(), a.Length() > 20 ? "..." : "");
  }
}

int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  list("XCAFDoc_LayerTool::Set(Main) [what OCCTDocumentGetLayer* read]", XCAFDoc_LayerTool::Set(d->Main()));
  list("XCAFDoc_DocumentTool::LayerTool(Main) [what OCCTDocumentSetLayer writes]",
       XCAFDoc_DocumentTool::LayerTool(d->Main()));
  TDF_Label box = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(10, 10, 10), true);
  TCollection_AsciiString longName;
  for (int i = 0; i < 300; i++)
    longName += "L";
  XCAFDoc_DocumentTool::LayerTool(d->Main())->SetLayer(box, TCollection_ExtendedString(longName.ToCString()));
  printf("after SetLayer(box, 300 x 'L'):\n");
  list("XCAFDoc_LayerTool::Set(Main)", XCAFDoc_LayerTool::Set(d->Main()));
  list("XCAFDoc_DocumentTool::LayerTool(Main)", XCAFDoc_DocumentTool::LayerTool(d->Main()));
  return 0;
}
