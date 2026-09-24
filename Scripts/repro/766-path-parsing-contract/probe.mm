// Epic #766, PathParsingContractTests.swift: kernel parity for all ten tests.
// Same inputs as the Swift tests, straight to OCCT's OSD_Path, the class every
// OCCTOSDPath* bridge function in OCCTBridge_IO_OSDUtilities.mm constructs.
#include <OSD_Path.hxx>
#include <TCollection_AsciiString.hxx>
#include <cstdio>

static void comp(const char* path)
{
  TCollection_AsciiString apath(path);
  OSD_Path                p(apath);
  TCollection_AsciiString sys;
  p.SystemName(sys);
  TCollection_AsciiString folder, file;
  OSD_Path::FolderAndFileFromPath(TCollection_AsciiString(path), folder, file);
  printf("[%s] name=[%s] ext=[%s] trek=[%s] system=[%s] folder=[%s] file=[%s] "
         "isValid=%d isUnix=%d isRelative=%d isAbsolute=%d\n",
         path,
         p.Name().ToCString(),
         p.Extension().ToCString(),
         p.Trek().ToCString(),
         sys.ToCString(),
         folder.ToCString(),
         file.ToCString(),
         (int)OSD_Path::IsValid(TCollection_AsciiString(path)),
         (int)OSD_Path::IsUnixPath(path),
         (int)OSD_Path::IsRelativePath(path),
         (int)OSD_Path::IsAbsolutePath(path));
}

int main()
{
  const char* paths[] = {"/home/üser/mødel.step",
                         "/home/user/模型.step",
                         "/home/user/model.step",
                         "/home/user/archive.tar.gz",
                         "/home/user/model",
                         "../up/f.txt",
                         "model.step",
                         "./sub/f.txt",
                         "/home/a.b/model",
                         "/tmp/test.txt",
                         ""};
  for (const char* p : paths)
    comp(p);
  return 0;
}
