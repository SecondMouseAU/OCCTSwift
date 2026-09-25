// #766 / #1987 kernel parity for the Foundation suites "Message_Messenger Tests",
// "Message_Report Tests", "OSD Timer Tests" and "OSD MemInfo Tests". Each section makes the OCCT
// calls the bridge function in its header makes, with the inputs the Swift test passes.
#include <Message_Messenger.hxx>
#include <Message_PrinterOStream.hxx>
#include <Message_Printer.hxx>
#include <Message_Report.hxx>
#include <Message_AlertExtended.hxx>
#include <OSD_Timer.hxx>
#include <OSD_MemInfo.hxx>
#include <TCollection_AsciiString.hxx>
#include <sstream>
#include <fstream>
#include <cstdio>
#include <ctime>
#include <sys/time.h>
#include <unistd.h>

int main()
{
  printf("== Message_Messenger (OCCTMessengerCreate / PrinterCount / AddFilePrinter / Send / RemoveAllPrinters) ==\n");
  {
    Handle(Message_Messenger) m = new Message_Messenger();
    printf("new Message_Messenger: Printers().Size() = %d\n", (int)m->Printers().Size());
    const char* path = "/tmp/occt_766_probe_msg.txt";
    remove(path);
    Handle(Message_PrinterOStream) p = new Message_PrinterOStream(path, false, Message_Info);
    printf("AddPrinter(file, Info) = %d, Size() = %d\n", (int)m->AddPrinter(p), (int)m->Printers().Size());
    m->Send(TCollection_AsciiString("Test from Swift"), Message_Info);
    m->RemovePrinters(STANDARD_TYPE(Message_Printer));
    printf("after RemovePrinters(Message_Printer): Size() = %d\n", (int)m->Printers().Size());
    p.Nullify();
    std::ifstream     in(path);
    std::stringstream ss;
    ss << in.rdbuf();
    std::string body = ss.str();
    printf("file printer received \"Test from Swift\": %d (file %zu bytes)\n",
           (int)(body.find("Test from Swift") != std::string::npos),
           body.size());
    remove(path);
  }

  printf("== Message_Report (OCCTReportCreate / Get/SetLimit / Clear / Dump) ==\n");
  {
    Handle(Message_Report) r = new Message_Report();
    printf("default Limit() = %d\n", r->Limit());
    r->SetLimit(100);
    printf("after SetLimit(100): Limit() = %d\n", r->Limit());
    std::ostringstream empty;
    r->Dump(empty);
    printf("Dump() of an empty report: \"%s\" (%zu bytes)\n", empty.str().c_str(), empty.str().size());
    r->Clear();
    r->Clear(Message_Warning);
    std::ostringstream cleared;
    r->Dump(cleared);
    printf("Dump() after Clear() and Clear(Warning): %zu bytes, Limit() = %d\n", cleared.str().size(), r->Limit());
    r->AddAlert(Message_Info, new Message_AlertExtended());
    std::ostringstream one;
    r->Dump(one);
    printf("Dump() after AddAlert(Info, Message_AlertExtended): %zu bytes\n", one.str().size());
  }

  printf("== OSD_Timer (OCCTTimerStart / Stop / Reset / ElapsedTime / GetWallClockTime) ==\n");
  {
    OSD_Timer t;
    t.Start();
    usleep(50000);
    t.Stop();
    printf("ElapsedTime() over a 50 ms sleep = %.4f s\n", t.ElapsedTime());
    t.Reset();
    printf("after Reset(): ElapsedTime() = %g\n", t.ElapsedTime());
    struct timeval tv;
    gettimeofday(&tv, nullptr);
    double now = tv.tv_sec + tv.tv_usec * 1e-6;
    printf("GetWallClockTime() - gettimeofday() = %.6f s\n", OSD_Timer::GetWallClockTime() - now);
  }

  printf("== OSD_MemInfo (OCCTMemInfoHeapUsage / HeapUsageMiB / PrintInfo) ==\n");
  {
    OSD_MemInfo info(true);
    double      bytes = (double)info.Value(OSD_MemInfo::MemHeapUsage);
    double      mib   = info.ValuePreciseMiB(OSD_MemInfo::MemHeapUsage);
    printf("Value(MemHeapUsage) > 0: %d; ValuePreciseMiB * 2^20 / Value = %.6f\n",
           (int)(bytes > 0),
           mib * 1048576.0 / bytes);
    TCollection_AsciiString s = OSD_MemInfo::PrintInfo();
    printf("PrintInfo() contains \"Heap memory\": %d\n", (int)(s.Search("Heap memory") > 0));
    printf("PrintInfo() first line: \"%s\"\n", TCollection_AsciiString(s).Token("\n", 1).ToCString());
  }
  return 0;
}
