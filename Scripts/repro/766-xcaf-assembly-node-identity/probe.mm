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
#include <TDataStd_Name.hxx>
#include <Interface_Static.hxx>

// AssemblyNodeIdentityTests: box -> STEP (AP214, as OCCTExportSTEP) -> STEPCAFControl_Reader with
// the modes OCCTDocumentLoadSTEP sets. The labelId registry is the bridge's own vector; the kernel
// side is the free-shape label it registers and the name attribute AssemblyNode.name reads.
int main()
{
  const char* path = "/tmp/766-xcaf-assembly-node-identity.step";
  {
    STEPControl_Writer w;
    Interface_Static::SetCVal("write.step.schema", "AP214");
    w.Transfer(centredBox(10, 10, 10), STEPControl_AsIs);
    w.Write(path);
  }
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  STEPCAFControl_Reader       r;
  r.SetColorMode(true); r.SetNameMode(true); r.SetLayerMode(true); r.SetPropsMode(true); r.SetMatMode(true);
  printf("ReadFile=%d\n", (int)r.ReadFile(path));
  printf("Transfer=%s\n", tf(r.Transfer(d)));
  TDF_LabelSequence roots;
  XCAFDoc_DocumentTool::ShapeTool(d->Main())->GetFreeShapes(roots);
  printf("free shapes=%d\n", roots.Length());
  TCollection_AsciiString entry;
  TDF_Tool::Entry(roots.Value(1), entry);
  printf("root[0] entry=%s isNull=%s\n", entry.ToCString(), tf(roots.Value(1).IsNull()));
  Handle(TDataStd_Name) nm;
  if (roots.Value(1).FindAttribute(TDataStd_Name::GetID(), nm))
    printf("root[0] name=\"%s\"\n", TCollection_AsciiString(nm->Get()).ToCString());
  else
    printf("root[0] name=<none>\n");
  // Re-fetching the free shapes (what Document.node(at:) warm-up does) yields the same label.
  TDF_LabelSequence again;
  XCAFDoc_DocumentTool::ShapeTool(d->Main())->GetFreeShapes(again);
  printf("second GetFreeShapes root[0] IsEqual first=%s\n", tf(again.Value(1).IsEqual(roots.Value(1))));
  // A fresh document has no free shapes, so no root label could be registered for Int64.max.
  Handle(TDocStd_Application) app2;
  Handle(TDocStd_Document)    d2 = newDoc(app2);
  TDF_LabelSequence none;
  XCAFDoc_DocumentTool::ShapeTool(d2->Main())->GetFreeShapes(none);
  printf("fresh doc free shapes=%d\n", none.Length());
  return 0;
}
