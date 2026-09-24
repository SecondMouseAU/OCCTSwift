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

#include <XCAFDoc_MaterialTool.hxx>
#include <Standard_OutOfRange.hxx>

// DocumentMaterialTests. The bridge (OCCTDocumentGetMaterialCount / OCCTDocumentGetMaterialInfo) calls
// XCAFDoc_MaterialTool::Set(Main) and reads GetMaterialLabels; the document's own material table is
// XCAFDoc_DocumentTool::MaterialTool(Main). Both are measured, and index 0 is measured as the 1-based
// Value(0 + 1) the bridge would take, raising.
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
  Handle(TDocStd_Application)  app;
  Handle(TDocStd_Document)     d  = newDoc(app);
  Handle(XCAFDoc_MaterialTool) mt = XCAFDoc_MaterialTool::Set(d->Main());
  TDF_LabelSequence            ms;
  mt->GetMaterialLabels(ms);
  printf("bridge call XCAFDoc_MaterialTool::Set(Main): material labels=%d\n", ms.Length());
  Handle(XCAFDoc_MaterialTool) table = XCAFDoc_DocumentTool::MaterialTool(d->Main());
  TDF_LabelSequence            ts;
  table->GetMaterialLabels(ts);
  printf("document material table XCAFDoc_DocumentTool::MaterialTool(Main): material labels=%d\n", ts.Length());
  printf("index 0 (Value(1)) raises Standard_OutOfRange=%s\n", tf(valueRaises(ms, 1)));
  return 0;
}
