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

#include <TDataStd_Integer.hxx>
#include <TDataStd_NamedData.hxx>
#include <TDataStd_NoteBook.hxx>
#include <TDataStd_Real.hxx>
#include <TDataStd_RealList.hxx>

// Kernel-parity probe for the NamedData, NoteBook and RealList tests (#766). Each scenario is a fresh document
// (Document.create()) and mirrors the bridge function the test calls: tag labels are Main().FindChild(tag, true),
// createLabel() is Main().NewChild() (the first call returns the existing ShapeTool label 0:1:1), the named values
// go through TDataStd_NamedData::Set on the label (getOrCreateNamedData) then SetInteger, SetReal and SetString,
// the notebook is TDataStd_NoteBook::New(label) with Append(double) or Append(int), and the has-attribute answer is
// FindAttribute. The earlier probe in 766-xcaf-tdatastd/ built every attribute in one accumulated document (one
// notebook took all the appends, so the integer append came out as tag 3), never measured the three named values
// together, and printed no has-attribute state after a Set.
int main()
{
  {
    // Multiple named values on same label: setNamedInteger("count", 5), setNamedReal("weight", 12.5), setNamedString("material", "Steel")
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    TDF_Label                   l = d->Main().NewChild();
    Handle(TDataStd_NamedData)  nd;
    if (!l.FindAttribute(TDataStd_NamedData::GetID(), nd))
      nd = TDataStd_NamedData::Set(l);
    nd->SetInteger(TCollection_AsciiString("count"), 5);
    Handle(TDataStd_NamedData) nd2;
    if (!l.FindAttribute(TDataStd_NamedData::GetID(), nd2))
      nd2 = TDataStd_NamedData::Set(l);
    nd2->SetReal(TCollection_AsciiString("weight"), 12.5);
    Handle(TDataStd_NamedData) nd3;
    if (!l.FindAttribute(TDataStd_NamedData::GetID(), nd3))
      nd3 = TDataStd_NamedData::Set(l);
    nd3->SetString(TCollection_AsciiString("material"), TCollection_ExtendedString("Steel", true));
    Handle(TDataStd_NamedData) got;
    l.FindAttribute(TDataStd_NamedData::GetID(), got);
    TCollection_AsciiString entry;
    TDF_Tool::Entry(l, entry);
    printf("[named data multiple] label %s: same attribute reused=%s; HasInteger(count)=%s count=%d HasReal(weight)=%s weight=%g HasString(material)=%s "
           "material=\"%s\"\n",
           entry.ToCString(),
           tf(nd.get() == nd2.get() && nd2.get() == nd3.get()), tf(got->HasInteger("count")), got->GetInteger("count"), tf(got->HasReal("weight")),
           got->GetReal("weight"), tf(got->HasString("material")), TCollection_AsciiString(got->GetString("material")).ToCString());
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    // appendReal: setNoteBook(tag: 201), noteBookAppendReal(tag: 201, value: 3.14)
    Handle(TDataStd_NoteBook) nb = TDataStd_NoteBook::New(tagLabel(d, 201));
    Handle(TDataStd_Real)     r  = nb->Append(3.14);
    printf("[notebook append real] tag 201: New returned a notebook=%s, Append(3.14) returned an attribute=%s child tag=%d (the bridge returns this tag, "
           "so a non-null attribute is a non-nil result)\n",
           tf(!nb.IsNull()), tf(!r.IsNull()), r.IsNull() ? -1 : r->Label().Tag());
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    // appendInteger: setNoteBook(tag: 202), noteBookAppendInteger(tag: 202, value: 42)
    Handle(TDataStd_NoteBook) nb = TDataStd_NoteBook::New(tagLabel(d, 202));
    Handle(TDataStd_Integer)  i  = nb->Append(42);
    printf("[notebook append integer] tag 202: New returned a notebook=%s, Append(42) returned an attribute=%s child tag=%d\n", tf(!nb.IsNull()),
           tf(!i.IsNull()), i.IsNull() ? -1 : i->Label().Tag());
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    // multipleAppends: setNoteBook(tag: 203), two real appends then one integer append on the same notebook
    Handle(TDataStd_NoteBook) nb = TDataStd_NoteBook::New(tagLabel(d, 203));
    Handle(TDataStd_Real)     r1 = nb->Append(1.0);
    Handle(TDataStd_Real)     r2 = nb->Append(2.0);
    Handle(TDataStd_Integer)  i1 = nb->Append(10);
    const int                 t1 = r1.IsNull() ? -1 : r1->Label().Tag();
    const int                 t2 = r2.IsNull() ? -1 : r2->Label().Tag();
    const int                 t3 = i1.IsNull() ? -1 : i1->Label().Tag();
    printf("[notebook multiple appends] tag 203: child tags real=%d real=%d integer=%d; all attributes returned=%s first two tags differ=%s\n", t1, t2, t3,
           tf(!r1.IsNull() && !r2.IsNull() && !i1.IsNull()), tf(t1 != t2));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    Handle(TDataStd_RealList)   a;
    const bool                  before = tagLabel(d, 342).FindAttribute(TDataStd_RealList::GetID(), a);
    Handle(TDataStd_RealList)   lst    = TDataStd_RealList::Set(tagLabel(d, 342));
    lst->Clear();
    lst->Append(1.0);
    const bool after = tagLabel(d, 342).FindAttribute(TDataStd_RealList::GetID(), a);
    printf("[real list has] tag 342: FindAttribute before Set=%s, after setRealList([1.0])=%s\n", tf(before), tf(after));
  }
  return 0;
}
