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
#include <sys/utsname.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>
#include <algorithm>

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
    printf("HostName() == gethostname(): %d (length %d)\n",
           (int)(host.HostName() == TCollection_AsciiString(buf)),
           host.HostName().Length());
    printf("SystemVersion() = \"%s\", uname sysname+release = \"%s %s\"\n",
           host.SystemVersion().ToCString(),
           u.sysname,
           u.release);
    printf("InternetAddress() = \"%s\", parses as IPv4: %d\n",
           ip.ToCString(),
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

    // The bridge's OCCTPerfMeterCreate does Init + Start; the test then burns 100 ms of CPU.
    OSD_PerfMeter  spin;
    spin.Init(TCollection_AsciiString("swift_test_766"));
    spin.Start();
    volatile double sum = 0;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    do
    {
      for (int i = 0; i < 1000; ++i)
        sum += i;
      clock_gettime(CLOCK_MONOTONIC, &t1);
    } while ((t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) * 1e-9 < 0.1);
    spin.Stop();
    printf("Elapsed() after Start, 100 ms CPU spin, Stop = %.4f s\n", spin.Elapsed());
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
    system(("rm -rf " + root + " && mkdir -p " + root + "/a " + root + "/b && touch " + root
            + "/x.txt " + root + "/y.txt " + root + "/z.dat")
             .c_str());
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
    system(("rm -rf " + root).c_str());
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
