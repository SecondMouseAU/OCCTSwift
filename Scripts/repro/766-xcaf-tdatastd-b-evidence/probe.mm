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

#include <Standard_OutOfRange.hxx>
#include <TDataStd_ExtStringArray.hxx>
#include <TDataStd_ExtStringList.hxx>
#include <TDataStd_IntegerArray.hxx>
#include <TDataStd_IntegerList.hxx>

// Kernel-parity probe for the ExtStringArray, ExtStringList, IntegerList and integer array tests (#766). Each
// scenario is a fresh document (Document.create()) and mirrors the bridge function the test calls: tag labels are
// Main().FindChild(tag, true), createLabel() is Main().NewChild(), the ExtStringArray is Set(label, 1, count), the
// lists are Set(label), Clear, Append, and the has-attribute answer is FindAttribute. The earlier probe in
// 766-xcaf-tdatastd/ built every attribute in one accumulated document and printed neither the has-attribute state
// after a Set nor any read of an index outside an array's bounds.
int main()
{
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    Handle(TDataStd_ExtStringArray) a;
    const bool before = tagLabel(d, 351).FindAttribute(TDataStd_ExtStringArray::GetID(), a);
    Handle(TDataStd_ExtStringArray) arr = TDataStd_ExtStringArray::Set(tagLabel(d, 351), 1, 1);
    arr->SetValue(1, TCollection_ExtendedString("A", true));
    const bool after = tagLabel(d, 351).FindAttribute(TDataStd_ExtStringArray::GetID(), a);
    printf("[ext string array has] tag 351: FindAttribute before Set=%s, after setExtStringArray([\"A\"])=%s\n", tf(before), tf(after));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    Handle(TDataStd_ExtStringList) a;
    const bool before = tagLabel(d, 362).FindAttribute(TDataStd_ExtStringList::GetID(), a);
    Handle(TDataStd_ExtStringList) lst = TDataStd_ExtStringList::Set(tagLabel(d, 362));
    lst->Clear();
    lst->Append(TCollection_ExtendedString("A", true));
    const bool after = tagLabel(d, 362).FindAttribute(TDataStd_ExtStringList::GetID(), a);
    printf("[ext string list has] tag 362: FindAttribute before Set=%s, after setExtStringList([\"A\"])=%s\n", tf(before), tf(after));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    Handle(TDataStd_IntegerList) a;
    const bool before = tagLabel(d, 332).FindAttribute(TDataStd_IntegerList::GetID(), a);
    Handle(TDataStd_IntegerList) lst = TDataStd_IntegerList::Set(tagLabel(d, 332));
    lst->Clear();
    lst->Append(1);
    const bool after = tagLabel(d, 332).FindAttribute(TDataStd_IntegerList::GetID(), a);
    printf("[integer list has] tag 332: FindAttribute before Set=%s, after setIntegerList([1])=%s\n", tf(before), tf(after));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    // createLabel() then initIntegerArray(lower: 0, upper: 2), then integerArrayValue(at: 99)
    TDF_Label                     l   = d->Main().NewChild();
    Handle(TDataStd_IntegerArray) arr = TDataStd_IntegerArray::Set(l, 0, 2);
    Handle(TDataStd_IntegerArray) attr;
    const bool                    found = l.FindAttribute(TDataStd_IntegerArray::GetID(), attr);
    const bool                    inBounds = 99 >= attr->Lower() && 99 <= attr->Upper();
    bool                          raised   = false;
    try
    {
      (void)attr->Value(99);
    }
    catch (const Standard_OutOfRange&)
    {
      raised = true;
    }
    printf("[integer array out of bounds] initIntegerArray(0, 2): found=%s Lower=%d Upper=%d index 99 within bounds=%s; the raw Value(99) "
           "raised Standard_OutOfRange=%s and returned a value=%s\n",
           tf(found), attr->Lower(), attr->Upper(), tf(inBounds), tf(raised), tf(!raised));
  }
  return 0;
}
