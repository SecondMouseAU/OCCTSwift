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
#include <Quantity_ColorRGBA.hxx>
#include <TColStd_HSequenceOfExtendedString.hxx>

// Supplement to 766-xcaf-xde for XDEColorToolByShapeTests and XDELayerToolExpansionTests: the tests'
// own scenarios through the XCAFDoc_ColorTool / XCAFDoc_LayerTool calls the bridge makes
// (OCCTDocumentSetShapeColorRGBA / IsShapeColorSet / GetShapeColor with XCAFDoc_ColorGen, and
// OCCTDocumentSetLayer / GetLabelLayers), with the raw values printed at %.17g. A 10x20x30 box is added
// with AddShape(box, true), as Document.addShape does by default.
static void color(const char* what, double r, double g, double b, float a)
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d   = newDoc(app);
  Handle(XCAFDoc_ShapeTool)   st  = XCAFDoc_DocumentTool::ShapeTool(d->Main());
  Handle(XCAFDoc_ColorTool)   ct  = XCAFDoc_DocumentTool::ColorTool(d->Main());
  TopoDS_Shape                box = centredBox(10, 20, 30);
  st->AddShape(box, true);
  ct->SetColor(box, Quantity_ColorRGBA(Quantity_Color(r, g, b, Quantity_TOC_RGB), a), XCAFDoc_ColorGen);
  bool               isSet = ct->IsSet(box, XCAFDoc_ColorGen);
  Quantity_ColorRGBA got;
  bool               has = ct->GetColor(box, XCAFDoc_ColorGen, got);
  printf("%s: set (%g, %g, %g, %g): IsSet=%s GetColor=%s rgba=(%.17g, %.17g, %.17g, %.17g)\n", what, r, g, b, (double)a, tf(isSet),
         tf(has), got.GetRGB().Red(), got.GetRGB().Green(), got.GetRGB().Blue(), (double)got.Alpha());
}

int main()
{
  color("setAndGetColor / shapeColorOpaqueUnaffected (red, opaque)", 1.0, 0.0, 0.0, 1.0f);
  color("shapeColorPreservesAlpha (translucent)", 0.2, 0.4, 0.6, 0.5f);

  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d  = newDoc(app);
  Handle(XCAFDoc_ShapeTool)   st = XCAFDoc_DocumentTool::ShapeTool(d->Main());
  Handle(XCAFDoc_LayerTool)   lt = XCAFDoc_DocumentTool::LayerTool(d->Main());
  TDF_Label                   l  = st->AddShape(centredBox(10, 20, 30), true);
  const int                   extra = 16 + 3;
  for (int i = 0; i < extra; i++)
    lt->SetLayer(l, TCollection_ExtendedString((TCollection_AsciiString("Layer") + i).ToCString()));
  Handle(TColStd_HSequenceOfExtendedString) layers = lt->GetLayers(l);
  printf("getLayersBeyondBufferCap: %d layers set on the label, GetLayers reports %d\n", extra, layers.IsNull() ? -1 : layers->Length());
  return 0;
}
