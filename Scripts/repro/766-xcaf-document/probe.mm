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
#include <XCAFDoc_LengthUnit.hxx>

// DocumentTests: a fresh document's free shapes; XCAFDoc_LengthUnit on a STEP-round-tripped box
// (looked up on Root, then Main, as OCCTDocumentGetLengthUnit does) and on a fresh document.
static bool unit(const Handle(TDocStd_Document)& d, double& scale, TCollection_AsciiString& name)
{
  Handle(XCAFDoc_LengthUnit) lu;
  if (!d->Main().Root().FindAttribute(XCAFDoc_LengthUnit::GetID(), lu)
      && !d->Main().FindAttribute(XCAFDoc_LengthUnit::GetID(), lu))
    return false;
  scale = lu->GetUnitValue();
  name  = lu->GetUnitName();
  return true;
}

int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    fresh = newDoc(app);
  TDF_LabelSequence           roots;
  XCAFDoc_DocumentTool::ShapeTool(fresh->Main())->GetFreeShapes(roots);
  printf("fresh document free shapes=%d\n", roots.Length());
  double                  s = 0;
  TCollection_AsciiString n;
  printf("fresh document length unit present=%s\n", tf(unit(fresh, s, n)));

  const char* path = "/tmp/766-xcaf-document-lengthunit.step";
  STEPControl_Writer w;
  Interface_Static::SetCVal("write.step.schema", "AP214");
  w.Transfer(centredBox(10, 20, 30), STEPControl_AsIs);
  w.Write(path);
  Handle(TDocStd_Application) app2;
  Handle(TDocStd_Document)    d = newDoc(app2);
  STEPCAFControl_Reader       r;
  r.SetColorMode(true); r.SetNameMode(true); r.SetLayerMode(true); r.SetPropsMode(true); r.SetMatMode(true);
  r.ReadFile(path);
  r.Transfer(d);
  bool has = unit(d, s, n);
  printf("STEP round-trip length unit present=%s scale=%g name=\"%s\"\n", tf(has), s, n.ToCString());
  return 0;
}
