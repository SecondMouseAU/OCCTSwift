// Epic #766, Issue1442DiskUnicodeOSDUtilitiesTests.swift: kernel parity for all six tests.
// Same inputs as the Swift tests, straight to OCCT: OSD_Disk(const char*) DiskSize/DiskFree/
// Failed (OCCTDiskSize/OCCTDiskFree/OCCTDiskIsValid), and Resource_Unicode::
// ConvertFormatToUnicode under ANSI and SJIS (OCCTUnicodeConvertToUnicode).
#include <OSD_Disk.hxx>
#include <Resource_Unicode.hxx>
#include <TCollection_ExtendedString.hxx>
#include <cstdio>
#include <sys/statvfs.h>

static void units(const char* label, const char* bytes)
{
  TCollection_ExtendedString e;
  Resource_Unicode::ConvertFormatToUnicode(bytes, e);
  printf("%s: length=%d code units:", label, e.Length());
  for (int i = 1; i <= e.Length(); i++)
    printf(" U+%04X", (unsigned)e.Value(i));
  printf("\n");
}

int main()
{
  struct statvfs vfs;
  statvfs("/", &vfs);
  unsigned long long totalBlocks = (unsigned long long)vfs.f_blocks * (vfs.f_frsize / 512);
  unsigned long long freeBlocks  = (unsigned long long)vfs.f_bavail * (vfs.f_frsize / 512);
  printf("statvfs(/): total512Blocks=%llu totalKB=%llu free512Blocks=%llu freeKB=%llu\n",
         totalBlocks, totalBlocks / 2, freeBlocks, freeBlocks / 2);

  OSD_Disk root("/");
  long long size = (long long)root.DiskSize();
  long long fre  = (long long)root.DiskFree();
  printf("OSD_Disk(\"/\"): DiskSize=%lld (KB=%lld) DiskFree=%lld (KB=%lld) Failed=%d\n",
         size, size / 2, fre, fre / 2, (int)root.Failed());

  OSD_Disk bogus("/this/path/does/not/exist/xyz123_555555");
  bogus.DiskSize();
  printf("OSD_Disk(nonexistent): Failed=%d\n", (int)bogus.Failed());

  Resource_Unicode::SetFormat(Resource_FormatType_ANSI);
  const char ansi[] = {0x41, (char)0xE9, 0x42, 0};
  units("ANSI [41 E9 42]", ansi);
  Resource_Unicode::SetFormat(Resource_FormatType_SJIS);
  const char sjis[] = {(char)0x82, (char)0xA0, 0};
  units("SJIS [82 A0]", sjis);
  return 0;
}
