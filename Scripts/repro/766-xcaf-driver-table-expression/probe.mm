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

#include <TPrsStd_DriverTable.hxx>
#include <TDataStd_Expression.hxx>

// DriverTableTests: TPrsStd_DriverTable::Get (lazily created, never null), InitStandardDrivers,
// Clear. ExpressionTests: TDataStd_Expression::Set on tag 1, SetExpression, GetExpression, Name.
int main()
{
  Handle(TPrsStd_DriverTable) t = TPrsStd_DriverTable::Get();
  printf("DriverTable::Get null=%s\n", tf(t.IsNull()));
  t->InitStandardDrivers();
  t->Clear();
  printf("InitStandardDrivers + Clear returned; Get null afterwards=%s\n", tf(TPrsStd_DriverTable::Get().IsNull()));

  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);
  Handle(TDataStd_Expression) e = TDataStd_Expression::Set(tagLabel(d, 1));
  printf("Expression::Set null=%s\n", tf(e.IsNull()));
  e->SetExpression(TCollection_ExtendedString("x^2 + y^2"));
  printf("GetExpression=\"%s\"\n", TCollection_AsciiString(e->GetExpression()).ToCString());
  e->SetExpression(TCollection_ExtendedString("a + b"));
  printf("Name()=\"%s\"\n", TCollection_AsciiString(e->Name()).ToCString());
  return 0;
}
