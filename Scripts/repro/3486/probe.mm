// #3486 probe: TDocStd_Application::Open on a crafted binary OCAF file, bridge guards NOT applied.
// Usage: probe <path>                 open it; prints "status=<PCDM_ReaderStatus> null=<0|1>"
//        probe <path> make-int        save a BinOcaf document with one Integer (what ocaf.py copies)
//        probe <path> make-named      save a BinOcaf document with a TNaming_NamedShape (a box)
//        probe <path> make-xcaf       save a BinXCAF document with a box in the shape tool
// A fault prints "SIGNAL <n>" and a backtrace, and exits 139. Build and run: see README.md.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BinDrivers.hxx>
#include <BinXCAFDrivers.hxx>
#include <TCollection_ExtendedString.hxx>
#include <TDF_Label.hxx>
#include <TDataStd_Integer.hxx>
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
  PCDM_ReaderStatus st = app->Open(path, doc);
  printf("status=%d null=%d\n", (int)st, (int)doc.IsNull());
  return 0;
}
