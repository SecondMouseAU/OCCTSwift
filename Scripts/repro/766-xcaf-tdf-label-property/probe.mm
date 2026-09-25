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

#include <TDF_ChildIterator.hxx>
#include <TDF_Tool.hxx>
#include <TDataStd_Name.hxx>

// Supplement to 766-xcaf-tdataxtd-tdf for TDFLabelPropertyTests: each test's own scenario through
// the TDF_Label calls the bridge makes (OCCTDocumentLabel*: Tag, Depth, IsNull, IsRoot, Father, Root,
// HasAttribute, NbAttributes, HasChild, NbChildren, FindChild, ForgetAllAttributes(true),
// TDF_ChildIterator). createLabel is Main().NewChild() and createLabel(parent:) is parent.NewChild().
static TCollection_AsciiString entry(const TDF_Label& l)
{
  TCollection_AsciiString e;
  TDF_Tool::Entry(l, e);
  return e;
}

int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d    = newDoc(app);
  TDF_Label                   main = d->Main();

  printf("labelTag: Main tag=%d entry=%s\n", main.Tag(), entry(main).ToCString());

  TDF_Label c = main.NewChild();
  printf("labelDepth: Main depth=%d child-of-Main depth=%d\n", main.Depth(), c.Depth());

  printf("labelIsNull: Main IsNull=%s\n", tf(main.IsNull()));

  printf("labelIsRoot: Main IsRoot=%s Main.Root IsRoot=%s\n", tf(main.IsRoot()), tf(main.Root().IsRoot()));

  TDF_Label fc = main.NewChild();
  printf("labelFather: child.Father is Main=%s (father entry %s)\n", tf(fc.Father().IsEqual(main)),
         entry(fc.Father()).ToCString());

  TDF_Label rc = main.NewChild();
  printf("labelRoot: child.Root IsRoot=%s\n", tf(rc.Root().IsRoot()));

  TDF_Label ap = main.NewChild();
  TDF_Label al = ap.NewChild();
  int       freshCount = al.NbAttributes();
  bool      freshHas   = al.HasAttribute();
  TDataStd_Name::Set(al, TCollection_ExtendedString("TestPart", true));
  printf("labelAttributes: fresh HasAttribute=%s NbAttributes=%d; after Name HasAttribute=%s NbAttributes=%d\n", tf(freshHas),
         freshCount, tf(al.HasAttribute()), al.NbAttributes());

  TDF_Label chp = main.NewChild();
  bool      hc0 = chp.HasChild();
  int       n0  = chp.NbChildren();
  chp.NewChild();
  chp.NewChild();
  printf("labelChildren: new label HasChild=%s NbChildren=%d; after two children HasChild=%s NbChildren=%d\n", tf(hc0), n0,
         tf(chp.HasChild()), chp.NbChildren());

  TDF_Label fp = main.NewChild();
  TDF_Label fchild = fp.NewChild();
  TDF_Label found = fp.FindChild(fchild.Tag(), false);
  TDF_Label none  = fp.FindChild(999, false);
  TDF_Label made  = fp.FindChild(999, true);
  printf("labelFindChild: existing found=%s (IsEqual child=%s); FindChild(999, false) null=%s; FindChild(999, true) null=%s; NbChildren after=%d\n",
         tf(!found.IsNull()), tf(found.IsEqual(fchild)), tf(none.IsNull()), tf(made.IsNull()), fp.NbChildren());

  TDF_Label fa = main.NewChild().NewChild();
  TDataStd_Name::Set(fa, TCollection_ExtendedString("Temporary", true));
  bool before = fa.HasAttribute();
  fa.ForgetAllAttributes(true);
  printf("labelForgetAllAttributes: HasAttribute before=%s after ForgetAllAttributes(true)=%s\n", tf(before), tf(fa.HasAttribute()));

  TDF_Label dp = main.NewChild();
  TDF_Label d1 = dp.NewChild();
  dp.NewChild();
  d1.NewChild();
  d1.NewChild();
  int direct = 0, all = 0;
  for (TDF_ChildIterator it(dp, false); it.More(); it.Next())
    direct++;
  for (TDF_ChildIterator it(dp, true); it.More(); it.Next())
    all++;
  printf("labelDescendants: direct=%d all=%d\n", direct, all);

  TDF_Label bp = main.NewChild();
  const int extra = 1024 + 5;
  for (int i = 0; i < extra; i++)
    bp.NewChild();
  int walked = 0;
  for (TDF_ChildIterator it(bp, false); it.More(); it.Next())
    walked++;
  printf("labelDescendantsBeyondBufferCap: %d children created, TDF_ChildIterator(direct) walks %d\n", extra, walked);
  return 0;
}
