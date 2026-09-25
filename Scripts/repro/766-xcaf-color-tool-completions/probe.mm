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

#include <Quantity_Color.hxx>

// ColorToolCompletionsTests: the XCAFDoc_ColorTool calls the OCCTDocumentColorTool* bridge makes.
static int colorCount(const Handle(XCAFDoc_ColorTool)& ct)
{
  TDF_LabelSequence s;
  ct->GetColors(s);
  return s.Length();
}

int main()
{
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    Handle(XCAFDoc_ColorTool)   ct = XCAFDoc_DocumentTool::ColorTool(d->Main());
    TDF_Label a = ct->AddColor(Quantity_Color(1, 0, 0, Quantity_TOC_RGB));
    TDF_Label f = ct->FindColor(Quantity_Color(1, 0, 0, Quantity_TOC_RGB));
    printf("addAndFindColor: added null=%s found IsEqual added=%s\n", tf(a.IsNull()), tf(f.IsEqual(a)));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    Handle(XCAFDoc_ColorTool)   ct = XCAFDoc_DocumentTool::ColorTool(d->Main());
    int before = colorCount(ct);
    ct->AddColor(Quantity_Color(0, 1, 0, Quantity_TOC_RGB));
    printf("colorCount: before=%d after=%d\n", before, colorCount(ct));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    Handle(XCAFDoc_ColorTool)   ct = XCAFDoc_DocumentTool::ColorTool(d->Main());
    TDF_Label lab = ct->AddColor(Quantity_Color(0, 0, 1, Quantity_TOC_RGB));
    int before = colorCount(ct);
    ct->RemoveColor(lab);
    printf("removeColor: before=%d after=%d\n", before, colorCount(ct));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d  = newDoc(app);
    Handle(XCAFDoc_ColorTool)   ct = XCAFDoc_DocumentTool::ColorTool(d->Main());
    TDF_Label s = XCAFDoc_DocumentTool::ShapeTool(d->Main())->AddShape(centredBox(10, 10, 10), true);
    bool v0 = XCAFDoc_ColorTool::IsVisible(s);
    ct->SetVisibility(s, false);
    bool v1 = XCAFDoc_ColorTool::IsVisible(s);
    ct->SetVisibility(s, true);
    bool v2 = XCAFDoc_ColorTool::IsVisible(s);
    printf("visibility: default=%s afterFalse=%s afterTrue=%s\n", tf(v0), tf(v1), tf(v2));
    bool b0 = ct->IsColorByLayer(s);
    ct->SetColorByLayer(s, true);
    printf("colorByLayer: default=%s afterTrue=%s\n", tf(b0), tf(ct->IsColorByLayer(s)));
  }
  return 0;
}
