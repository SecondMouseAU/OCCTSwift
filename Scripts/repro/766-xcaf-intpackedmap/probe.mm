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

#include <TDataStd_IntPackedMap.hxx>
#include <TDataStd_Integer.hxx>
#include <TColStd_PackedMapOfInteger.hxx>
#include <algorithm>
#include <vector>

// Supplement to 766-xcaf-tdatastd for TDataStdIntPackedMapTests: the tests' own scenarios, one per
// test, through the calls the bridge makes (OCCTIntPackedMap*: TDataStd_IntPackedMap on tag labels,
// Contains / Extent / Remove / Clear / IsEmpty / GetMap iteration).
static std::vector<int> values(const Handle(TDataStd_IntPackedMap)& m)
{
  std::vector<int> v;
  for (TColStd_PackedMapOfInteger::Iterator it(m->GetMap()); it.More(); it.Next())
    v.push_back(it.Key());
  return v;
}

int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);

  // remove: adds 10 and 20, removes 10.
  Handle(TDataStd_IntPackedMap) r = TDataStd_IntPackedMap::Set(tagLabel(d, 102), false);
  r->Add(10);
  r->Add(20);
  bool removed = r->Remove(10);
  printf("remove: Remove(10)=%s Contains(10)=%s Extent=%d\n", tf(removed), tf(r->Contains(10)), r->Extent());

  // clearAndEmpty: adds 5, clears.
  Handle(TDataStd_IntPackedMap) c = TDataStd_IntPackedMap::Set(tagLabel(d, 103), false);
  c->Add(5);
  bool emptyBefore = c->IsEmpty();
  c->Clear();
  printf("clearAndEmpty: IsEmpty before Clear=%s IsEmpty after Clear=%s Extent after Clear=%d\n", tf(emptyBefore),
         tf(c->IsEmpty()), c->Extent());

  // getValues: adds 7, 42, 99 and reads the map back.
  Handle(TDataStd_IntPackedMap) g = TDataStd_IntPackedMap::Set(tagLabel(d, 104), false);
  g->Add(7);
  g->Add(42);
  g->Add(99);
  std::vector<int> v = values(g);
  std::sort(v.begin(), v.end());
  printf("getValues: Extent=%d values sorted:", g->Extent());
  for (int x : v)
    printf(" %d", x);
  printf("\n");

  // noInteger: a child of a child of Main has no TDataStd_Integer.
  TDF_Label parent = d->Main().NewChild();
  TDF_Label child  = parent.NewChild();
  printf("noInteger: fresh child label has a TDataStd_Integer=%s\n", tf(child.IsAttribute(TDataStd_Integer::GetID())));
  return 0;
}
