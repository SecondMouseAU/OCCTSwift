// #3330 probe: TDocStd_Application::Open on malformed OCAF files, bridge guard NOT applied.
// Usage: probe <path>                 one input; a fault prints a backtrace and exits 139
//        probe <path> <fmt>           write a real empty <fmt> document to <path>
//        probe -list <listfile> [n]   open each path in the file from line n; a fault prints
//                                     "CRASH <line> <path>" (a 5 s hang prints "HANG ...") and exits 139 (restart from line+1)
#include <BinDrivers.hxx>
#include <BinXCAFDrivers.hxx>
#include <XmlDrivers.hxx>
#include <XmlXCAFDrivers.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TDataStd_Integer.hxx>
#include <TDF_Label.hxx>
#include <TCollection_ExtendedString.hxx>
#include <execinfo.h>
#include <signal.h>
#include <unistd.h>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <string>
static int gLine = -1;
static std::string gPath;
static void onSegv(int s)
{
  if (gLine >= 0)
  {
    fprintf(stderr, "%s %d %s\n", s == SIGALRM ? "HANG" : "CRASH", gLine, gPath.c_str());
    _exit(139);
  }
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
  signal(SIGALRM, onSegv); // -list mode arms a 5 s watchdog per file
  Handle(TDocStd_Application) app = new TDocStd_Application();
  BinDrivers::DefineFormat(app);
  XmlDrivers::DefineFormat(app);
  BinXCAFDrivers::DefineFormat(app);
  XmlXCAFDrivers::DefineFormat(app);
  Handle(TDocStd_Document) doc;
  if (argc > 2 && std::string(argv[1]) == "-list")
  {
    std::ifstream list(argv[2]);
    std::string   line;
    int           n = 0, start = argc > 3 ? atoi(argv[3]) : 0;
    while (std::getline(list, line))
    {
      if (n++ < start)
        continue;
      gLine = n - 1;
      gPath = line;
      Handle(TDocStd_Document) d;
      alarm(5);
      PCDM_ReaderStatus        st = app->Open(TCollection_ExtendedString(line.c_str(), true), d);
      alarm(0);
      printf("%d %d %s\n", n - 1, (int)st, line.c_str());
      if (!d.IsNull())
        app->Close(d);
    }
    return 0;
  }
  if (argc > 2) // mode "make <fmt>": write a real empty document to argv[1]
  {
    app->NewDocument(argv[2], doc);
    TDataStd_Integer::Set(doc->Main(), 7);
    PCDM_StoreStatus ss = app->SaveAs(doc, TCollection_ExtendedString(argv[1], true));
    printf("saved status=%d\n", (int)ss);
    return 0;
  }
  PCDM_ReaderStatus        st = app->Open(TCollection_ExtendedString(argv[1], true), doc);
  printf("status=%d null=%d\n", (int)st, (int)doc.IsNull());
  return 0;
}
