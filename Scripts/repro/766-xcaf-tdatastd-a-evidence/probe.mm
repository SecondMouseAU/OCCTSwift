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

#include <TDataStd_BooleanArray.hxx>
#include <TDataStd_BooleanList.hxx>
#include <TDataStd_ByteArray.hxx>

// Kernel-parity probe for BooleanArray, BooleanList and ByteArray tests (#766). Each scenario is a fresh document
// (Document.create()) and mirrors the bridge function the test calls: the labels are Main().FindChild(tag, true),
// the boolean array is Set(label, 1, count), the byte array is Set(label, 0, count - 1) (the bridge's bounds),
// the boolean list is Set(label), Clear, Append, and the reads are FindAttribute then Length / Extent and Value.
// The earlier probe in 766-xcaf-tdatastd/ built every attribute in one accumulated document, used 1-based bounds for
// the byte array, and never printed a length or the has-attribute state after the Set.
static bool hasBooleanArray(const TDF_Label& l)
{
  Handle(TDataStd_BooleanArray) a;
  return l.FindAttribute(TDataStd_BooleanArray::GetID(), a);
}

static bool hasBooleanList(const TDF_Label& l)
{
  Handle(TDataStd_BooleanList) a;
  return l.FindAttribute(TDataStd_BooleanList::GetID(), a);
}

static bool hasByteArray(const TDF_Label& l)
{
  Handle(TDataStd_ByteArray) a;
  return l.FindAttribute(TDataStd_ByteArray::GetID(), a);
}

int main()
{
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    // setBooleanArray(tag: 300, values: [true, false, true, false, true])
    const bool                    v[5] = {true, false, true, false, true};
    Handle(TDataStd_BooleanArray) arr  = TDataStd_BooleanArray::Set(tagLabel(d, 300), 1, 5);
    for (int i = 0; i < 5; i++)
      arr->SetValue(1 + i, v[i]);
    Handle(TDataStd_BooleanArray) got;
    const bool                    found = tagLabel(d, 300).FindAttribute(TDataStd_BooleanArray::GetID(), got);
    printf("[boolean array set/get] tag 300, Set(1, 5): found=%s Length=%d Lower=%d values(1..3)=%d %d %d\n", tf(found), got->Length(), got->Lower(),
           (int)got->Value(got->Lower()), (int)got->Value(got->Lower() + 1), (int)got->Value(got->Lower() + 2));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d      = newDoc(app);
    const bool                  before = hasBooleanArray(tagLabel(d, 301));
    Handle(TDataStd_BooleanArray) arr  = TDataStd_BooleanArray::Set(tagLabel(d, 301), 1, 1);
    arr->SetValue(1, true);
    printf("[boolean array has] tag 301: FindAttribute before Set=%s, after setBooleanArray([true])=%s\n", tf(before), tf(hasBooleanArray(tagLabel(d, 301))));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    printf("[boolean array empty] tag 302, nothing set: FindAttribute=%s (the bridge returns -1, which Swift reads as nil)\n",
           tf(hasBooleanArray(tagLabel(d, 302))));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d   = newDoc(app);
    // setBooleanList(tag: 310, values: [true, false, true])
    Handle(TDataStd_BooleanList) lst = TDataStd_BooleanList::Set(tagLabel(d, 310));
    lst->Clear();
    for (bool b : {true, false, true})
      lst->Append(b);
    Handle(TDataStd_BooleanList) got;
    const bool                   found = tagLabel(d, 310).FindAttribute(TDataStd_BooleanList::GetID(), got);
    printf("[boolean list set/get] tag 310: found=%s Extent=%d values(1..2)=", tf(found), got->Extent());
    int i = 0;
    for (auto it = got->List().cbegin(); it != got->List().cend() && i < 2; ++it, ++i)
      printf("%s%d", i ? " " : "", (int)(*it != 0));
    printf("\n");
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d      = newDoc(app);
    const bool                  before = hasBooleanList(tagLabel(d, 312));
    Handle(TDataStd_BooleanList) lst   = TDataStd_BooleanList::Set(tagLabel(d, 312));
    lst->Clear();
    lst->Append(true);
    printf("[boolean list has] tag 312: FindAttribute before Set=%s, after setBooleanList([true])=%s\n", tf(before), tf(hasBooleanList(tagLabel(d, 312))));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d = newDoc(app);
    // setByteArray(tag: 320, values: [42, 255, 0, 128])
    const int                  v[4] = {42, 255, 0, 128};
    Handle(TDataStd_ByteArray) arr  = TDataStd_ByteArray::Set(tagLabel(d, 320), 0, 3);
    for (int i = 0; i < 4; i++)
      arr->SetValue(0 + i, (Standard_Byte)v[i]);
    Handle(TDataStd_ByteArray) got;
    const bool                 found = tagLabel(d, 320).FindAttribute(TDataStd_ByteArray::GetID(), got);
    printf("[byte array set/get] tag 320, Set(0, 3): found=%s Length=%d Lower=%d values(0..3)=%d %d %d %d\n", tf(found), got->Length(), got->Lower(),
           (int)got->Value(got->Lower()), (int)got->Value(got->Lower() + 1), (int)got->Value(got->Lower() + 2), (int)got->Value(got->Lower() + 3));
  }
  {
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document)    d      = newDoc(app);
    const bool                  before = hasByteArray(tagLabel(d, 321));
    Handle(TDataStd_ByteArray)  arr    = TDataStd_ByteArray::Set(tagLabel(d, 321), 0, 2);
    for (int i = 0; i < 3; i++)
      arr->SetValue(i, (Standard_Byte)(i + 1));
    printf("[byte array has] tag 321: FindAttribute before Set=%s, after setByteArray([1, 2, 3])=%s\n", tf(before), tf(hasByteArray(tagLabel(d, 321))));
  }
  return 0;
}
