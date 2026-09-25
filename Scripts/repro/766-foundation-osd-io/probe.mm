// #766 / #1987 kernel parity for the Foundation suites "OSD_Host", "OSD_PerfMeter",
// "OSD_Directory", "Resource_Unicode", "OSD_DirectoryIterator", "OSD_FileIterator" and "OSD_Disk".
// Each section makes the OCCT calls the bridge function in its header makes, with the inputs the
// Swift test passes. The iterator fixture is the one the tests build: a fresh directory holding
// subdirectories a/ and b/ and files x.txt, y.txt, z.dat.
#include <OSD_Host.hxx>
#include <OSD_PerfMeter.hxx>
#include <OSD_Directory.hxx>
#include <OSD_DirectoryIterator.hxx>
#include <OSD_FileIterator.hxx>
#include <OSD_File.hxx>
#include <OSD_Path.hxx>
#include <OSD_Protection.hxx>
#include <OSD_Disk.hxx>
#include <Resource_Unicode.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <sys/statvfs.h>
#include <sys/resource.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <cstdio>
#include <string>
#include <atomic>
#include <thread>
#include <vector>
#include <time.h>
#include <cstdlib>
#include <string>
#include <vector>
#include <algorithm>
#include <filesystem>
#include <fstream>

static double wallNow()
{
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec + t.tv_nsec * 1e-9;
}

static double processCPU()
{
  struct rusage r;
  getrusage(RUSAGE_SELF, &r);
  return r.ru_utime.tv_sec + r.ru_utime.tv_usec * 1e-6 + r.ru_stime.tv_sec + r.ru_stime.tv_usec * 1e-6;
}

// Spin until the calling thread has used `seconds` of its own CPU time.
static void spinThreadCPU(double seconds)
{
  volatile double sum = 0;
  double          t0  = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) * 1e-9;
  while (clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) * 1e-9 - t0 < seconds)
    for (int i = 0; i < 1000; ++i)
      sum += i;
}

static std::string sysName(const OSD_Path& p)
{
  TCollection_AsciiString s;
  p.SystemName(s);
  return s.ToCString();
}

int main()
{
  printf("== OSD_Host (OCCTHostName / OCCTSystemVersion / OCCTInternetAddress) ==\n");
  {
    OSD_Host host;
    char     buf[256] = {0};
    gethostname(buf, sizeof(buf));
    struct utsname u;
    uname(&u);
    TCollection_AsciiString ip = host.InternetAddress();
    in_addr                 a;
    // The host name itself is not printed, so the committed transcript carries no machine name.
    // OSD_Host::HostName() resolves through the system resolver, so its form can differ from
    // gethostname(): on the macOS CI runner gethostname gave "<host>.local" and OSD_Host gave
    // "<host>." (trailing dot). The Swift test therefore compares the first DNS label.
    std::string kernel = host.HostName().ToCString();
    std::string posix  = buf;
    auto        label  = [](std::string x) { return x.substr(0, x.find('.')); };
    printf("HostName() == gethostname(): %d; HostName() ends with '.': %d; first DNS labels equal: %d\n",
           (int)(kernel == posix),
           (int)(!kernel.empty() && kernel.back() == '.'),
           (int)(label(kernel) == label(posix)));
    printf("SystemVersion() = \"%s\", uname sysname+release = \"%s %s\"\n",
           host.SystemVersion().ToCString(),
           u.sysname,
           u.release);
    printf("InternetAddress() parses as an IPv4 dotted quad: %d\n",
           inet_pton(AF_INET, ip.ToCString(), &a) == 1);
  }

  printf("== OSD_PerfMeter (OCCTPerfMeterCreate / Stop / Elapsed) ==\n");
  {
    OSD_PerfMeter m;
    m.Init(TCollection_AsciiString("swift_test"));
    m.Start();
    usleep(50000);
    m.Stop();
    printf("Elapsed() after Start, 50 ms sleep, Stop = %.4f s\n", m.Elapsed());

    // The bridge's OCCTPerfMeterCreate does Init + Start. The test then spins until THIS thread
    // has used 0.1 s of CPU (not 0.1 s of wall time, which a busy machine can shorten to 0.05 s
    // of CPU: an earlier version of this probe read 0.0484 for that reason).
    OSD_PerfMeter spin;
    spin.Init(TCollection_AsciiString("swift_test_766"));
    double p0 = processCPU();
    spin.Start();
    spinThreadCPU(0.1);
    spin.Stop();
    double p1 = processCPU();
    printf("Elapsed() after a 0.1 s thread-CPU spin = %.4f s; process CPU (getrusage) over the same interval = %.4f s\n",
           spin.Elapsed(),
           p1 - p0);
    printf("  0.09 <= Elapsed() <= process CPU + 0.02: %d\n",
           (int)(spin.Elapsed() >= 0.09 && spin.Elapsed() <= p1 - p0 + 0.02));

    // OSD_PerfMeter reads CPU time summed over the process's LIVE threads, not the calling
    // thread's and not wall time. Threads still running inflate a window; a thread that exits
    // inside it takes its whole CPU history out of the sum. So the Swift test cannot bound the
    // reading by wall time, and cannot rely on a lower bound holding in every window.
    for (int mode = 0; mode < 3; ++mode)
    {
      int                      threads = mode == 0 ? 1 : 4;
      OSD_PerfMeter            m2;
      m2.Init(TCollection_AsciiString(("swift_test_766_mt" + std::to_string(mode)).c_str()));
      std::atomic<bool> stopFlag{false};
      double            c0 = processCPU();
      m2.Start();
      std::vector<std::thread> ts;
      for (int i = 1; i < threads; ++i)
        ts.emplace_back([&, mode] {
          if (mode == 1)
            spinThreadCPU(0.2);
          else
            while (!stopFlag)
            {
            }
        });
      spinThreadCPU(0.2);
      if (mode == 1)
        for (auto& t : ts)
          t.join();
      m2.Stop();
      double c1 = processCPU();
      stopFlag  = true;
      for (auto& t : ts)
        if (t.joinable())
          t.join();
      printf("%d thread(s), workers %s at Stop: Elapsed() = %.2f s, process CPU over the interval = %.2f s\n",
             threads,
             mode == 0 ? "none" : (mode == 1 ? "exited" : "still running"),
             m2.Elapsed(),
             c1 - c0);
    }
  }

  printf("== OSD_Directory (OCCTDirectoryBuildTemporary / Create / Exists / Remove) ==\n");
  {
    OSD_Directory tmp = OSD_Directory::BuildTemporary();
    OSD_Path      p;
    tmp.Path(p);
    std::string name = sysName(p);
    printf("BuildTemporary() gives a path under /tmp: %d, Exists %d\n",
           name.rfind("/tmp", 0) == 0,
           (int)OSD_Directory(OSD_Path(name.c_str())).Exists());
    OSD_Directory d(OSD_Path(name.c_str()));
    d.Remove();
    printf("after Remove(): Exists %d\n", (int)OSD_Directory(OSD_Path(name.c_str())).Exists());

    std::string   path = "/tmp/occt_766_probe_dir";
    OSD_Directory made(OSD_Path(path.c_str()));
    made.Build(OSD_Protection());
    printf("Build(%s): Exists %d\n", path.c_str(), (int)made.Exists());
    made.Remove();
    printf("Remove(): Exists %d\n", (int)made.Exists());
  }

  printf("== Resource_Unicode (OCCTUnicodeSetFormat / GetFormat / ConvertToUnicode / ConvertFromUnicode) ==\n");
  {
    Resource_Unicode::SetFormat(Resource_FormatType_SJIS);
    printf("SetFormat(SJIS) -> GetFormat() == SJIS: %d\n",
           (int)(Resource_Unicode::GetFormat() == Resource_FormatType_SJIS));
    Resource_Unicode::SetFormat(Resource_FormatType_ANSI);
    printf("SetFormat(ANSI) -> GetFormat() == ANSI: %d\n",
           (int)(Resource_Unicode::GetFormat() == Resource_FormatType_ANSI));
    TCollection_ExtendedString e;
    Resource_Unicode::ConvertFormatToUnicode("hello", e);
    printf("ConvertFormatToUnicode(\"hello\") length %d, as ASCII \"%s\"\n",
           e.Length(),
           TCollection_AsciiString(e).ToCString());
    char                out[64] = {0};
    Standard_PCharacter outPtr  = out;
    bool ok = Resource_Unicode::ConvertUnicodeToFormat(TCollection_ExtendedString("hello", true), outPtr, 64);
    printf("ConvertUnicodeToFormat(\"hello\") ok %d -> \"%s\"\n", (int)ok, out);
  }

  printf("== OSD_DirectoryIterator / OSD_FileIterator on the fixture ==\n");
  {
    std::string root = "/tmp/occt_766_probe_iter";
    // Use C++ filesystem instead of system() call
    std::filesystem::remove_all(root);
    std::filesystem::create_directories(root + "/a");
    std::filesystem::create_directories(root + "/b");
    std::ofstream(root + "/x.txt").close();
    std::ofstream(root + "/y.txt").close();
    std::ofstream(root + "/z.dat").close();
    OSD_Path                 rp(root.c_str());
    std::vector<std::string> dirs, files;
    for (OSD_DirectoryIterator it(rp, "*"); it.More(); it.Next())
    {
      OSD_Path q;
      it.Values().Path(q);
      dirs.push_back(sysName(q));
    }
    for (OSD_FileIterator it(rp, "*"); it.More(); it.Next())
    {
      OSD_Path q;
      it.Values().Path(q);
      files.push_back(sysName(q));
    }
    std::sort(dirs.begin(), dirs.end());
    std::sort(files.begin(), files.end());
    printf("DirectoryIterator count %zu:", dirs.size());
    for (auto& s : dirs)
      printf(" \"%s\"", s.c_str());
    printf("\nFileIterator count %zu:", files.size());
    for (auto& s : files)
      printf(" \"%s\"", s.c_str());
    printf("\n");
    std::filesystem::remove_all(root);
  }

  printf("== OSD_Disk (OCCTDiskSize / DiskFree / IsValid / Name) ==\n");
  {
    OSD_Disk       disk("/");
    struct statvfs v;
    statvfs("/", &v);
    unsigned long long blocks = (unsigned long long)v.f_blocks * (v.f_frsize / 512);
    printf("DiskSize()/2 = %lld KB, statvfs f_blocks*(f_frsize/512)/2 = %llu KB\n",
           (long long)disk.DiskSize() / 2,
           blocks / 2);
    printf("DiskFree()/2 = %lld KB (> 0: %d)\n",
           (long long)disk.DiskFree() / 2,
           (int)(disk.DiskFree() > 0));
    printf("Failed() after DiskSize on \"/\" = %d\n", (int)disk.Failed());
    OSD_Disk byPath(OSD_Path(TCollection_AsciiString("/")));
    printf("OSD_Disk(OSD_Path(\"/\")).Name() system name = \"%s\"\n", sysName(byPath.Name()).c_str());
  }
  return 0;
}
