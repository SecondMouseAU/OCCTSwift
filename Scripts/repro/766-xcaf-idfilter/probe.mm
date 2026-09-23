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

#include <TDF_IDFilter.hxx>
#include <Standard_GUID.hxx>

// IDFilterTests: TDF_IDFilter(ignoreAll), Keep / Ignore / IsKept / IsIgnored / IgnoreAll.
int main()
{
  const Standard_GUID g("2a96b606-ec8b-11d0-bee7-080009dc3333");
  TDF_IDFilter        ignoreAll(true);
  printf("TDF_IDFilter(true).IgnoreAll=%s\n", tf(ignoreAll.IgnoreAll()));
  TDF_IDFilter keepAll(false);
  printf("TDF_IDFilter(false).IgnoreAll=%s\n", tf(keepAll.IgnoreAll()));
  TDF_IDFilter k(true);
  k.Keep(g);
  printf("ignore-all filter, Keep(g): IsKept=%s\n", tf(k.IsKept(g)));
  TDF_IDFilter i(false);
  i.Ignore(g);
  printf("keep-all filter, Ignore(g): IsIgnored=%s\n", tf(i.IsIgnored(g)));
  TDF_IDFilter t(true);
  t.IgnoreAll(false);
  printf("IgnoreAll(false) on an ignore-all filter: IgnoreAll=%s\n", tf(t.IgnoreAll()));
  return 0;
}
