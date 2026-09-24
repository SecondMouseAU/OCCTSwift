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

// DocumentExplorerTests: XCAFPrs_DocumentExplorer (OnlyLeafNodes) over a document holding one box
// added with AddShape(box, makeAssembly = true), as Document.addShape does by default.
int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(10, 10, 10), true);
  int n = 0;
  TCollection_AsciiString id0;
  bool shape0 = false;
  for (XCAFPrs_DocumentExplorer e(d, XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes, XCAFPrs_Style()); e.More(); e.Next(), n++)
    if (n == 0)
    {
      id0 = e.Current().Id;
      shape0 = !XCAFDoc_ShapeTool::GetShape(e.Current().RefLabel).IsNull();
    }
  printf("leaf node count=%d\n", n);
  printf("node[0] shape non-null=%s\n", tf(shape0));
  printf("node[0] path id=\"%s\"\n", id0.ToCString());
  TopoDS_Shape f = XCAFPrs_DocumentExplorer::FindShapeFromPathId(d, id0);
  printf("FindShapeFromPathId non-null=%s type=%d\n", tf(!f.IsNull()), f.IsNull() ? -1 : (int)f.ShapeType());
  return 0;
}
