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
#include <Standard_OutOfRange.hxx>

// DocumentLayerTests. The bridge (OCCTDocumentGetLayerCount / OCCTDocumentGetLayerName) calls
// XCAFDoc_LayerTool::Set(Main) and reads GetLayerLabels; the document's own layer table is
// XCAFDoc_DocumentTool::LayerTool(Main), attached to LayersLabel(). Both are measured, and a 0-based
// index out of range is measured as the 1-based Value(index + 1) the bridge would take, raising.
static const char* entry(const TDF_Label& l)
{
  static TCollection_AsciiString s;
  s.Clear();
  TDF_Tool::Entry(l, s);
  return s.ToCString();
}

static void list(const char* what, const Handle(XCAFDoc_LayerTool)& lt, TDF_LabelSequence& ls)
{
  lt->GetLayerLabels(ls);
  printf("%s: tool on label %s, layer labels=%d\n", what, entry(lt->Label()), ls.Length());
  for (int i = 1; i <= ls.Length(); i++)
  {
    TCollection_ExtendedString nm;
    bool                       ok = lt->GetLayer(ls.Value(i), nm);
    printf("  layer[%d] label %s GetLayer=%s name=\"%s\"\n", i - 1, entry(ls.Value(i)), tf(ok),
           TCollection_AsciiString(nm).ToCString());
  }
}

static bool valueRaises(const TDF_LabelSequence& s, int oneBased)
{
  try
  {
    (void)s.Value(oneBased);
    return false;
  }
  catch (const Standard_OutOfRange&)
  {
    return true;
  }
}

int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  TDF_LabelSequence           bridgeLabels, tableLabels;
  list("bridge call XCAFDoc_LayerTool::Set(Main)", XCAFDoc_LayerTool::Set(d->Main()), bridgeLabels);
  list("document layer table XCAFDoc_DocumentTool::LayerTool(Main)", XCAFDoc_DocumentTool::LayerTool(d->Main()), tableLabels);
  printf("LayersLabel()=%s\n", entry(XCAFDoc_DocumentTool::LayersLabel(d->Main())));
  printf("index 999 (Value(1000)) raises Standard_OutOfRange=%s, index -1 (Value(0)) raises Standard_OutOfRange=%s\n",
         tf(valueRaises(bridgeLabels, 1000)), tf(valueRaises(bridgeLabels, 0)));
  return 0;
}
