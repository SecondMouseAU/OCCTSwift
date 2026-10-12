// #3318 probe: TDocStd_Application::Open on empty / text / short-header files.
// Usage: probe <path>   (one input per process: a SIGSEGV kills it)
#include <BinDrivers.hxx>
#include <BinXCAFDrivers.hxx>
#include <XmlDrivers.hxx>
#include <XmlXCAFDrivers.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TCollection_ExtendedString.hxx>
#include <execinfo.h>
#include <signal.h>
#include <unistd.h>
#include <cstdio>
static void onSegv(int s)
{
  void* f[40];
  int   n = backtrace(f, 40);
  fprintf(stderr, "SIGNAL %d\n", s);
  backtrace_symbols_fd(f, n, 2);
  _exit(139);
}
int main(int argc, char** argv)
{
  signal(SIGSEGV, onSegv);
  signal(SIGBUS, onSegv);
  Handle(TDocStd_Application) app = new TDocStd_Application();
  BinDrivers::DefineFormat(app);
  XmlDrivers::DefineFormat(app);
  BinXCAFDrivers::DefineFormat(app);
  XmlXCAFDrivers::DefineFormat(app);
  Handle(TDocStd_Document) doc;
  if (argc > 2) // mode "make <fmt>": write a real empty document to argv[1]
  {
    app->NewDocument(argv[2], doc);
    PCDM_StoreStatus ss = app->SaveAs(doc, TCollection_ExtendedString(argv[1], true));
    printf("saved status=%d\n", (int)ss);
    return 0;
  }
  PCDM_ReaderStatus        st = app->Open(TCollection_ExtendedString(argv[1], true), doc);
  printf("status=%d null=%d\n", (int)st, (int)doc.IsNull());
  return 0;
}
