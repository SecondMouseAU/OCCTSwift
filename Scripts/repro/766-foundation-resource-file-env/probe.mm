// #766 / #1987 kernel parity for the Foundation suites "Resource_Manager Tests", "OSD_File Tests",
// "OSD Process Tests", "OSD Chronometer Tests" and "OSD Environment Tests". Each section makes the
// OCCT calls the bridge function in its header makes, with the inputs the Swift test passes.
// User name and home directory are compared, not printed, so the transcript names no account.
#include <Resource_Manager.hxx>
#include <OSD_File.hxx>
#include <OSD_Path.hxx>
#include <OSD_Protection.hxx>
#include <OSD_Process.hxx>
#include <OSD_Chronometer.hxx>
#include <OSD_Environment.hxx>
#include <TCollection_AsciiString.hxx>
#include <sys/resource.h>
#include <unistd.h>
#include <pwd.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

int main()
{
  printf("== Resource_Manager (OCCTResourceManagerSet*/Find/Get*) ==\n");
  {
    Handle(Resource_Manager) mgr = new Resource_Manager();
    mgr->SetResource("key1", "hello");
    mgr->SetResource("intKey", 42);
    mgr->SetResource("realKey", 3.14);
    printf("Find(key1) %d, Value(key1) \"%s\"\n", (int)mgr->Find("key1"), mgr->Value("key1"));
    printf("Integer(intKey) %d\n", mgr->Integer("intKey"));
    printf("Real(realKey) %.17g\n", mgr->Real("realKey"));
    printf("Find(no_such_key) %d\n", (int)mgr->Find("no_such_key"));
  }

  printf("== OSD_File (OCCTFileCreate / Open / Write / OpenReadOnly / ReadLine / Size / IsOpen) ==\n");
  {
    const char* path = "/tmp/occt_766_probe_osdfile.txt";
    OSD_File    w{OSD_Path(TCollection_AsciiString(path))};
    w.Build(OSD_ReadWrite, OSD_Protection());
    printf("Build(ReadWrite) failed %d, IsOpen %d\n", (int)w.Failed(), (int)w.IsOpen());
    TCollection_AsciiString content("Hello, OSD_File!\nLine 2\n");
    w.Write(content, content.Length());
    w.Close();
    printf("after Close: IsOpen %d\n", (int)w.IsOpen());

    OSD_File r{OSD_Path(TCollection_AsciiString(path))};
    r.Open(OSD_ReadOnly, OSD_Protection());
    TCollection_AsciiString line;
    int                     n = 0;
    r.ReadLine(line, 4096, n);
    printf("ReadLine(4096): \"%s\" (length %d, nbread %d)\n", line.ToCString(), line.Length(), n);
    printf("Size() of the 2-line file = %zu\n", r.Size());
    r.Close();

    OSD_File w5(OSD_Path(TCollection_AsciiString("/tmp/occt_766_probe_osdfile5.txt")));
    w5.Build(OSD_ReadWrite, OSD_Protection());
    w5.Write(TCollection_AsciiString("ABCDE"), 5);
    w5.Close();
    OSD_File r5(OSD_Path(TCollection_AsciiString("/tmp/occt_766_probe_osdfile5.txt")));
    r5.Open(OSD_ReadOnly, OSD_Protection());
    printf("Size() after writing \"ABCDE\" = %zu\n", r5.Size());
    r5.Close();
    remove(path);
    remove("/tmp/occt_766_probe_osdfile5.txt");
  }

  printf("== OSD_Process (OCCTProcessId / OCCTProcessUserName) ==\n");
  {
    OSD_Process p;
    printf("ProcessId() == getpid(): %d\n", (int)(p.ProcessId() == getpid()));
    struct passwd* pw = getpwuid(getuid());
    printf("UserName() == getpwuid(getuid())->pw_name: %d\n",
           (int)(pw && p.UserName() == TCollection_AsciiString(pw->pw_name)));
  }

  printf("== OSD_Chronometer::GetProcessCPU (OCCTGetProcessCPU) ==\n");
  {
    volatile double s = 0;
    for (int i = 0; i < 20000000; ++i)
      s += i;
    struct rusage before, after;
    getrusage(RUSAGE_SELF, &before);
    double user = 0, sys = 0;
    OSD_Chronometer::GetProcessCPU(user, sys);
    getrusage(RUSAGE_SELF, &after);
    double b = before.ru_utime.tv_sec + before.ru_utime.tv_usec * 1e-6;
    double a = after.ru_utime.tv_sec + after.ru_utime.tv_usec * 1e-6;
    // GetProcessCPU reports in 1/100 s steps, so it can sit up to 0.01 s below getrusage.
    printf("user %.6f s, getrusage user [%.6f, %.6f], within 0.02 s: %d; user > 0: %d\n",
           user,
           b,
           a,
           (int)(user >= b - 0.02 && user <= a + 0.02),
           (int)(user > 0));
  }

  printf("== OSD_Environment (OCCTEnvironmentSet / Get / Remove) ==\n");
  {
    OSD_Environment set(TCollection_AsciiString("OCCT_SWIFT_TEST"), TCollection_AsciiString("hello"));
    set.Build();
    printf("Build failed %d, Value \"%s\"\n",
           (int)set.Failed(),
           OSD_Environment(TCollection_AsciiString("OCCT_SWIFT_TEST")).Value().ToCString());
    OSD_Environment(TCollection_AsciiString("OCCT_SWIFT_TEST")).Remove();
    printf("after Remove: Value length %d\n",
           OSD_Environment(TCollection_AsciiString("OCCT_SWIFT_TEST")).Value().Length());
    const char* home = getenv("HOME");
    printf("Value(HOME) == getenv(HOME): %d\n",
           (int)(home && OSD_Environment(TCollection_AsciiString("HOME")).Value() == TCollection_AsciiString(home)));
  }
  return 0;
}
