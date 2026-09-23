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

#include <TDataStd_AsciiString.hxx>
#include <TDataStd_BooleanArray.hxx>
#include <TDataStd_BooleanList.hxx>
#include <TDataStd_ByteArray.hxx>
#include <TDataStd_Comment.hxx>
#include <TDataStd_ExtStringArray.hxx>
#include <TDataStd_ExtStringList.hxx>
#include <TDataStd_IntegerArray.hxx>
#include <TDataStd_IntegerList.hxx>
#include <TDataStd_Integer.hxx>
#include <TDataStd_IntPackedMap.hxx>
#include <TDataStd_NamedData.hxx>
#include <TDataStd_NoteBook.hxx>
#include <TDataStd_RealArray.hxx>
#include <TDataStd_RealList.hxx>
#include <TDataStd_Real.hxx>
#include <TDataStd_ReferenceArray.hxx>
#include <TDataStd_ReferenceList.hxx>
#include <TDataStd_Relation.hxx>
#include <TDataStd_TreeNode.hxx>
#include <TColStd_PackedMapOfInteger.hxx>
#include <TColStd_HPackedMapOfInteger.hxx>
#include <cmath>

// The TDataStd* test files: each attribute's Set / Get / list edit on the labels the tests use
// (tag labels via Main().FindChild(tag), or Main().NewChild() where the test calls createLabel).
static TCollection_AsciiString a(const TCollection_ExtendedString& s) { return TCollection_AsciiString(s); }

int main()
{
  Handle(TDocStd_Application) app;
  Handle(TDocStd_Document)    d = newDoc(app);

  TDF_Label as = d->Main().NewChild();
  TDataStd_AsciiString::Set(as, "hello");
  printf("AsciiString: %s", TDataStd_AsciiString::Set(as, "hello")->Get().ToCString());
  TDataStd_AsciiString::Set(as, "world");
  Handle(TDataStd_AsciiString) asA;
  as.FindAttribute(TDataStd_AsciiString::GetID(), asA);
  printf(" -> after second Set: %s\n", asA->Get().ToCString());

  TDF_Label ba = tagLabel(d, 300);
  Handle(TDataStd_BooleanArray) bArr = TDataStd_BooleanArray::Set(ba, 1, 5);
  const bool bv[5] = {true, false, true, false, true};
  for (int i = 0; i < 5; i++)
    bArr->SetValue(i + 1, bv[i]);
  printf("BooleanArray 1..5: %d %d %d %d %d; tag 301 has one before Set=%s; tag 302 has one=%s\n", bArr->Value(1), bArr->Value(2),
         bArr->Value(3), bArr->Value(4), bArr->Value(5), tf(tagLabel(d, 301).IsAttribute(TDataStd_BooleanArray::GetID())),
         tf(tagLabel(d, 302).IsAttribute(TDataStd_BooleanArray::GetID())));

  Handle(TDataStd_BooleanList) bl = TDataStd_BooleanList::Set(tagLabel(d, 311));
  bl->Append(true);
  bl->Append(false);
  printf("BooleanList: after two appends Extent=%d First=%d", bl->Extent(), bl->First());
  bl->Clear();
  printf(" after Clear Extent=%d\n", bl->Extent());

  Handle(TDataStd_ByteArray) by = TDataStd_ByteArray::Set(tagLabel(d, 320), 1, 4);
  const int bytes[4] = {42, 255, 0, 128};
  for (int i = 0; i < 4; i++)
    by->SetValue(i + 1, (Standard_Byte)bytes[i]);
  printf("ByteArray: %d %d %d %d\n", by->Value(1), by->Value(2), by->Value(3), by->Value(4));

  TDF_Label cm = d->Main().NewChild();
  TDataStd_Comment::Set(cm, TCollection_ExtendedString("my comment"));
  Handle(TDataStd_Comment) cmA;
  cm.FindAttribute(TDataStd_Comment::GetID(), cmA);
  printf("Comment: %s\n", a(cmA->Get()).ToCString());

  Handle(TDataStd_ExtStringArray) esa = TDataStd_ExtStringArray::Set(tagLabel(d, 350), 1, 3);
  esa->SetValue(1, "Hello");
  esa->SetValue(2, "World");
  esa->SetValue(3, "!");
  printf("ExtStringArray: Length=%d [1]=%s [2]=%s\n", esa->Length(), a(esa->Value(1)).ToCString(), a(esa->Value(2)).ToCString());

  Handle(TDataStd_ExtStringList) esl = TDataStd_ExtStringList::Set(tagLabel(d, 360));
  esl->Append("Alpha");
  esl->Append("Beta");
  esl->Append("Gamma");
  printf("ExtStringList: Extent=%d First=%s Last=%s", esl->Extent(), a(esl->First()).ToCString(), a(esl->Last()).ToCString());
  esl->Clear();
  printf(" after Clear Extent=%d\n", esl->Extent());

  TDF_Label ia = d->Main().NewChild();
  Handle(TDataStd_IntegerArray) iArr = TDataStd_IntegerArray::Set(ia, 1, 5);
  for (int i = 1; i <= 5; i++)
    iArr->SetValue(i, i * 10);
  printf("IntegerArray: bounds %d..%d values(1,3,5)=%d %d %d; index 99 in range=%s\n", iArr->Lower(), iArr->Upper(), iArr->Value(1),
         iArr->Value(3), iArr->Value(5), tf(99 <= iArr->Upper()));

  Handle(TDataStd_IntegerList) il = TDataStd_IntegerList::Set(tagLabel(d, 330));
  il->Append(10);
  il->Append(20);
  il->Append(30);
  printf("IntegerList: Extent=%d First=%d Last=%d", il->Extent(), il->First(), il->Last());
  il->Clear();
  printf(" after Clear Extent=%d\n", il->Extent());

  TDF_Label in = d->Main().NewChild();
  TDataStd_Integer::Set(in, 42);
  Handle(TDataStd_Integer) inA;
  in.FindAttribute(TDataStd_Integer::GetID(), inA);
  printf("Integer: %d", inA->Get());
  TDataStd_Integer::Set(in, 99);
  printf(" -> %d; a fresh child label has one=%s\n", inA->Get(),
         tf(d->Main().NewChild().NewChild().IsAttribute(TDataStd_Integer::GetID())));

  Handle(TDataStd_IntPackedMap) pm = TDataStd_IntPackedMap::Set(tagLabel(d, 100), false);
  pm->Add(42);
  pm->Add(100);
  printf("IntPackedMap: Contains(42)=%s Contains(100)=%s", tf(pm->Contains(42)), tf(pm->Contains(100)));
  pm->Add(1);
  printf(" Extent after 3 adds=%d", pm->Extent());
  pm->Remove(42);
  printf(" after Remove(42) Contains=%s Extent=%d", tf(pm->Contains(42)), pm->Extent());
  pm->Clear();
  printf(" after Clear IsEmpty=%s\n", tf(pm->IsEmpty()));
  TColStd_PackedMapOfInteger nm;
  for (int k : {10, 20, 30, 40, 50})
    nm.Add(k);
  pm->Add(1);
  pm->ChangeMap(nm);
  printf("IntPackedMap ChangeMap(10..50): Extent=%d Contains(30)=%s Contains(1)=%s\n", pm->Extent(), tf(pm->Contains(30)),
         tf(pm->Contains(1)));

  TDF_Label nd = d->Main().NewChild();
  Handle(TDataStd_NamedData) ndA = TDataStd_NamedData::Set(nd);
  ndA->SetInteger("count", 42);
  ndA->SetReal("pi", 3.14159);
  ndA->SetString("partName", "MyPart");
  printf("NamedData: count=%d HasInteger(other)=%s pi=%g partName=%s\n", ndA->GetInteger("count"), tf(ndA->HasInteger("other")),
         ndA->GetReal("pi"), a(ndA->GetString("partName")).ToCString());

  Handle(TDataStd_NoteBook) nb = TDataStd_NoteBook::New(tagLabel(d, 203));
  Handle(TDataStd_Real)     r1 = nb->Append(1.0, Standard_False);
  Handle(TDataStd_Real)     r2 = nb->Append(2.0, Standard_False);
  Handle(TDataStd_Integer)  i1 = nb->Append(10, Standard_False);
  Handle(TDataStd_NoteBook) found;
  printf("NoteBook: Find=%s appended tags %d %d %d\n", tf(TDataStd_NoteBook::Find(tagLabel(d, 203), found)), r1->Label().Tag(),
         r2->Label().Tag(), i1->Label().Tag());

  TDF_Label ra = d->Main().NewChild();
  Handle(TDataStd_RealArray) rArr = TDataStd_RealArray::Set(ra, 0, 2);
  rArr->SetValue(0, 1.1);
  rArr->SetValue(1, 2.2);
  rArr->SetValue(2, 3.3);
  printf("RealArray 0..2: %g %g %g\n", rArr->Value(0), rArr->Value(1), rArr->Value(2));

  Handle(TDataStd_RealList) rl = TDataStd_RealList::Set(tagLabel(d, 340));
  rl->Append(1.5);
  rl->Append(2.5);
  rl->Append(3.14);
  printf("RealList: Extent=%d First=%g Last=%g", rl->Extent(), rl->First(), rl->Last());
  rl->Clear();
  printf(" after Clear Extent=%d\n", rl->Extent());

  TDF_Label re = d->Main().NewChild();
  TDataStd_Real::Set(re, 3.14);
  Handle(TDataStd_Real) reA;
  re.FindAttribute(TDataStd_Real::GetID(), reA);
  printf("Real: %g", reA->Get());
  TDataStd_Real::Set(re, 2.718);
  printf(" -> %g\n", reA->Get());

  Handle(TDataStd_ReferenceArray) rfa = TDataStd_ReferenceArray::Set(tagLabel(d, 370), 1, 3);
  for (int i = 0; i < 3; i++)
    rfa->SetValue(i + 1, tagLabel(d, 400 + i));
  printf("ReferenceArray tags: %d %d %d\n", rfa->Value(1).Tag(), rfa->Value(2).Tag(), rfa->Value(3).Tag());
  Handle(TDataStd_ReferenceList) rfl = TDataStd_ReferenceList::Set(tagLabel(d, 380));
  rfl->Append(tagLabel(d, 410));
  rfl->Append(tagLabel(d, 411));
  printf("ReferenceList: Extent=%d First=%d Last=%d", rfl->Extent(), rfl->First().Tag(), rfl->Last().Tag());
  rfl->Clear();
  printf(" after Clear Extent=%d\n", rfl->Extent());

  Handle(TDataStd_Relation) rel = TDataStd_Relation::Set(tagLabel(d, 390));
  rel->SetRelation("a = b");
  printf("Relation: %s; tag 391 has one before Set=%s\n", a(rel->GetRelation()).ToCString(),
         tf(tagLabel(d, 391).IsAttribute(TDataStd_Relation::GetID())));

  TDF_Label root = d->Main().NewChild(), c1 = d->Main().NewChild(), c2 = d->Main().NewChild();
  Handle(TDataStd_TreeNode) tr = TDataStd_TreeNode::Set(root), t1 = TDataStd_TreeNode::Set(c1), t2 = TDataStd_TreeNode::Set(c2);
  printf("TreeNode fresh: HasFather=%s Depth=%d", tf(tr->HasFather()), tr->Depth());
  tr->Append(t1);
  tr->Append(t2);
  printf("; after two Append: child1 HasFather=%s Depth=%d root NbChildren=%d First is c1=%s c1.Next is c2=%s c2.Next null=%s\n",
         tf(t1->HasFather()), t1->Depth(), tr->NbChildren(), tf(tr->First() == t1), tf(t1->Next() == t2), tf(t2->Next().IsNull()));
  return 0;
}
