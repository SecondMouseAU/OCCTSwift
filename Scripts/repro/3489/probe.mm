// #3489 probe (the #3486 probe plus `roundtrip`): TDocStd_Application::Open on a crafted binary OCAF file, bridge guards NOT applied.
// Usage: probe <path>                 open it; prints "status=<PCDM_ReaderStatus> null=<0|1>"
//        probe <path> make-int        save a BinOcaf document with one Integer (what ocaf.py copies)
//        probe <path> make-named      save a BinOcaf document with a TNaming_NamedShape (a box)
//        probe <path> make-xcaf       save a BinXCAF document with a box in the shape tool
//        probe <path> roundtrip       save one of each array/list/named-data attribute, reopen, compare
// A fault prints "SIGNAL <n>" and a backtrace, and exits 139. Build and run: see README.md.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BinDrivers.hxx>
#include <BinXCAFDrivers.hxx>
#include <TCollection_ExtendedString.hxx>
#include <TDF_Label.hxx>
#include <NCollection_HArray1.hxx>
#include <TDataStd_BooleanArray.hxx>
#include <TDataStd_BooleanList.hxx>
#include <TDataStd_ByteArray.hxx>
#include <TDataStd_ExtStringArray.hxx>
#include <TDataStd_Integer.hxx>
#include <TDataStd_IntegerArray.hxx>
#include <TDataStd_IntegerList.hxx>
#include <TDataStd_NamedData.hxx>
#include <TDataStd_RealArray.hxx>
#include <TDataStd_RealList.hxx>
#include <TDataStd_ReferenceArray.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TNaming_Builder.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XmlDrivers.hxx>
#include <XmlXCAFDrivers.hxx>
#include <execinfo.h>
#include <signal.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
static void onSignal(int s)
{
  void* f[40];
  int   n = backtrace(f, 40);
  fprintf(stderr, "SIGNAL %d\n", s);
  backtrace_symbols_fd(f, n, 2);
  _exit(139);
}
int main(int argc, char** argv)
{
  if (argc < 2)
    return 2;
  signal(SIGSEGV, onSignal);
  signal(SIGBUS, onSignal);
  Handle(TDocStd_Application) app = new TDocStd_Application();
  BinDrivers::DefineFormat(app);
  XmlDrivers::DefineFormat(app);
  BinXCAFDrivers::DefineFormat(app);
  XmlXCAFDrivers::DefineFormat(app);
  Handle(TDocStd_Document) doc;
  const TCollection_ExtendedString path(argv[1], true);
  if (argc > 2 && !strcmp(argv[2], "make-int"))
  {
    app->NewDocument("BinOcaf", doc);
    TDataStd_Integer::Set(doc->Main(), 7);
    printf("saved status=%d\n", (int)app->SaveAs(doc, path));
    return 0;
  }
  if (argc > 2 && !strcmp(argv[2], "make-named"))
  {
    app->NewDocument("BinOcaf", doc);
    TNaming_Builder b(doc->Main().FindChild(1));
    b.Generated(BRepPrimAPI_MakeBox(1, 2, 3).Shape());
    printf("saved status=%d\n", (int)app->SaveAs(doc, path));
    return 0;
  }
  if (argc > 2 && !strcmp(argv[2], "make-xcaf"))
  {
    app->NewDocument("BinXCAF", doc);
    XCAFDoc_DocumentTool::ShapeTool(doc->Main())->AddShape(BRepPrimAPI_MakeBox(1, 2, 3).Shape());
    printf("saved status=%d\n", (int)app->SaveAs(doc, path));
    return 0;
  }
  if (argc > 2 && !strcmp(argv[2], "roundtrip"))
  {
    // One attribute of every kind whose reader allocates from a declared span (#3489), saved and
    // reopened: the bound must not refuse a file the writer produced.
    app->NewDocument("BinOcaf", doc);
    TDF_Label m = doc->Main();
    auto      L = [&](int tag) { return m.FindChild(tag); };
    occ::handle<TDataStd_IntegerArray> ia = TDataStd_IntegerArray::Set(L(1), 1, 3);
    for (int i = 1; i <= 3; i++)
      ia->SetValue(i, 10 * i);
    occ::handle<TDataStd_RealArray> ra = TDataStd_RealArray::Set(L(2), -1, 1);
    for (int i = -1; i <= 1; i++)
      ra->SetValue(i, 0.5 * i);
    occ::handle<TDataStd_ByteArray> ba = TDataStd_ByteArray::Set(L(3), 1, 4);
    for (int i = 1; i <= 4; i++)
      ba->SetValue(i, (uint8_t)(i + 60));
    occ::handle<TDataStd_ExtStringArray> ea = TDataStd_ExtStringArray::Set(L(4), 1, 3);
    ea->SetValue(1, "a");
    ea->SetValue(2, "");
    ea->SetValue(3, "ccc");
    occ::handle<TDataStd_BooleanArray> bo = TDataStd_BooleanArray::Set(L(5), 1, 11);
    for (int i = 1; i <= 11; i++)
      bo->SetValue(i, i % 3 == 0);
    occ::handle<TDataStd_IntegerList> il = TDataStd_IntegerList::Set(L(6));
    il->Append(5);
    il->Append(6);
    occ::handle<TDataStd_RealList> rl = TDataStd_RealList::Set(L(7));
    rl->Append(1.5);
    occ::handle<TDataStd_BooleanList> bl = TDataStd_BooleanList::Set(L(8));
    bl->Append(true);
    bl->Append(false);
    occ::handle<TDataStd_ReferenceArray> rf = TDataStd_ReferenceArray::Set(L(9), 1, 2);
    rf->SetValue(1, L(1));
    rf->SetValue(2, L(2));
    occ::handle<TDataStd_NamedData> nd = TDataStd_NamedData::Set(L(10));
    occ::handle<NCollection_HArray1<int>>    nia = new NCollection_HArray1<int>(1, 3);
    occ::handle<NCollection_HArray1<double>> nra = new NCollection_HArray1<double>(1, 2);
    for (int i = 1; i <= 3; i++)
      nia->SetValue(i, i);
    for (int i = 1; i <= 2; i++)
      nra->SetValue(i, i * 0.25);
    nd->SetInteger("i", 4);
    nd->SetArrayOfIntegers("ia", nia);
    nd->SetArrayOfReals("ra", nra);
    printf("saved status=%d\n", (int)app->SaveAs(doc, path));
    app->Close(doc); // Open of a path whose document is still open answers AlreadyRetrieved
    Handle(TDocStd_Document) back;
    PCDM_ReaderStatus        st = app->Open(path, back);
    int                      bad = st != PCDM_RS_OK || back.IsNull();
    if (!bad)
    {
      TDF_Label bm = back->Main();
      auto      F  = [&](int tag) { return bm.FindChild(tag); };
      occ::handle<TDataStd_IntegerArray> a;
      occ::handle<TDataStd_RealArray>    b;
      occ::handle<TDataStd_ByteArray>    c;
      occ::handle<TDataStd_ExtStringArray> d;
      occ::handle<TDataStd_BooleanArray> e;
      occ::handle<TDataStd_IntegerList>  f;
      occ::handle<TDataStd_RealList>     g;
      occ::handle<TDataStd_BooleanList>  h;
      occ::handle<TDataStd_ReferenceArray> r;
      occ::handle<TDataStd_NamedData>    n;
      bad |= !F(1).FindAttribute(TDataStd_IntegerArray::GetID(), a) || a->Array().IsNull()
             || a->Length() != 3 || a->Value(2) != 20;
      bad |= !F(2).FindAttribute(TDataStd_RealArray::GetID(), b) || b->Array().IsNull()
             || b->Lower() != -1 || b->Value(1) != 0.5;
      bad |= !F(3).FindAttribute(TDataStd_ByteArray::GetID(), c) || c->Length() != 4
             || c->Value(4) != 64;
      bad |= !F(4).FindAttribute(TDataStd_ExtStringArray::GetID(), d) || d->Length() != 3
             || d->Value(3) != TCollection_ExtendedString("ccc");
      bad |= !F(5).FindAttribute(TDataStd_BooleanArray::GetID(), e) || e->Length() != 11
             || !e->Value(3) || e->Value(4);
      bad |= !F(6).FindAttribute(TDataStd_IntegerList::GetID(), f) || f->Extent() != 2
             || f->Last() != 6;
      bad |= !F(7).FindAttribute(TDataStd_RealList::GetID(), g) || g->Extent() != 1;
      bad |= !F(8).FindAttribute(TDataStd_BooleanList::GetID(), h) || h->Extent() != 2
             || !h->First();
      bad |= !F(9).FindAttribute(TDataStd_ReferenceArray::GetID(), r) || r->Length() != 2
             || r->Value(2).Tag() != 2;
      bad |= !F(10).FindAttribute(TDataStd_NamedData::GetID(), n) || n->GetInteger("i") != 4
             || !n->HasArrayOfIntegers("ia") || n->GetArrayOfIntegers("ia")->Value(3) != 3
             || !n->HasArrayOfReals("ra") || n->GetArrayOfReals("ra")->Value(2) != 0.5;
    }
    printf("roundtrip %s status=%d\n", bad ? "FAIL" : "OK", (int)st);
    return bad;
  }
  PCDM_ReaderStatus st = app->Open(path, doc);
  printf("status=%d null=%d\n", (int)st, (int)doc.IsNull());
  return 0;
}
