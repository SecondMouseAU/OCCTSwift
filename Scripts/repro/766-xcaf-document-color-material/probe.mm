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

#include <STEPControl_Writer.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <Interface_Static.hxx>
#include <XCAFDoc_Color.hxx>
#include <XCAFDoc_VisMaterial.hxx>
#include <XCAFDoc_VisMaterialPBR.hxx>
#include <Quantity_ColorRGBA.hxx>

// DocumentColorMaterialTests: a STEP-loaded box's free-shape label, then the colour/material
// attribute writes and reads the bridge makes.
static TDF_Label loadBoxRoot(Handle(TDocStd_Application)& app, Handle(TDocStd_Document)& d)
{
  const char* path = "/tmp/766-xcaf-document-color-material.step";
  STEPControl_Writer w;
  Interface_Static::SetCVal("write.step.schema", "AP214");
  w.Transfer(centredBox(10, 10, 10), STEPControl_AsIs);
  w.Write(path);
  d = newDoc(app);
  STEPCAFControl_Reader r;
  r.SetColorMode(true); r.SetNameMode(true); r.SetLayerMode(true); r.SetPropsMode(true); r.SetMatMode(true);
  r.ReadFile(path);
  r.Transfer(d);
  TDF_LabelSequence roots;
  XCAFDoc_DocumentTool::ShapeTool(d->Main())->GetFreeShapes(roots);
  return roots.Value(1);
}

int main()
{
  {
    Handle(TDocStd_Application) app; Handle(TDocStd_Document) d;
    TDF_Label l = loadBoxRoot(app, d);
    Handle(XCAFDoc_ColorTool) ct = XCAFDoc_DocumentTool::ColorTool(d->Main());
    Quantity_Color c0;
    printf("setLabelColor: before GetColor(Gen)=%s\n", tf(ct->GetColor(l, XCAFDoc_ColorGen, c0)));
    ct->SetColor(l, Quantity_Color(1, 0, 0, Quantity_TOC_RGB), XCAFDoc_ColorGen);
    Quantity_Color c;
    bool ok = ct->GetColor(l, XCAFDoc_ColorGen, c);
    printf("setLabelColor: GetColor(Gen)=%s rgb=(%.6f, %.6f, %.6f)\n", tf(ok), c.Red(), c.Green(), c.Blue());
  }
  {
    Handle(TDocStd_Application) app; Handle(TDocStd_Document) d;
    TDF_Label l = loadBoxRoot(app, d);
    Handle(XCAFDoc_Color) a = XCAFDoc_Color::Set(l, Quantity_Color(0.5, 0.25, 0.75, Quantity_TOC_RGB));
    Quantity_Color c = a->GetColor();
    printf("colorAttr TOC_RGB: set null=%s read=(%.6f, %.6f, %.6f)\n", tf(a.IsNull()), c.Red(), c.Green(), c.Blue());
    Handle(XCAFDoc_Color) s = XCAFDoc_Color::Set(l, Quantity_Color(0.5, 0.25, 0.75, Quantity_TOC_sRGB));
    c = s->GetColor();
    printf("colorAttr TOC_sRGB (the #1508 defect): read=(%.6f, %.6f, %.6f)\n", c.Red(), c.Green(), c.Blue());
  }
  {
    Handle(TDocStd_Application) app; Handle(TDocStd_Document) d;
    TDF_Label l = loadBoxRoot(app, d);
    Handle(XCAFDoc_Color) a = XCAFDoc_Color::Set(l, Quantity_ColorRGBA(Quantity_Color(0.5, 0.25, 0.75, Quantity_TOC_RGB), 0.4f));
    Quantity_ColorRGBA c = a->GetColorRGBA();
    printf("colorRGBAAttr: read=(%.6f, %.6f, %.6f, %.6f)\n", c.GetRGB().Red(), c.GetRGB().Green(), c.GetRGB().Blue(), c.Alpha());
  }
  {
    Handle(TDocStd_Application) app; Handle(TDocStd_Document) d;
    TDF_Label l = loadBoxRoot(app, d);
    Handle(XCAFDoc_VisMaterialTool) mt = XCAFDoc_DocumentTool::VisMaterialTool(d->Main());
    TopoDS_Shape shape = XCAFDoc_DocumentTool::ShapeTool(d->Main())->GetShape(l);
    Handle(XCAFDoc_VisMaterial) vm = new XCAFDoc_VisMaterial();
    XCAFDoc_VisMaterialPBR pbr;
    pbr.BaseColor = Quantity_ColorRGBA(Quantity_Color(0.8, 0.2, 0.1, Quantity_TOC_RGB), 1.0f);
    pbr.Metallic = 0.9f;
    pbr.Roughness = 0.3f;
    vm->SetPbrMaterial(pbr);
    TDF_Label ml = mt->AddMaterial(vm, TCollection_AsciiString("Material"));
    mt->SetShapeMaterial(shape, ml);
    Handle(XCAFDoc_VisMaterial) got = mt->GetShapeMaterial(shape);
    printf("material: found=%s hasPbr=%s metallic=%.6f roughness=%.6f\n", tf(!got.IsNull()),
           tf(!got.IsNull() && got->HasPbrMaterial()), got.IsNull() ? -1.0 : got->PbrMaterial().Metallic,
           got.IsNull() ? -1.0 : got->PbrMaterial().Roughness);
  }
  return 0;
}
