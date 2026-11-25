// OCCTSwift#3529 ground truth: what STEPControl_Reader and STEPCAFControl_Reader do with a STEP file
// that starts with a UTF-8 byte order mark (EF BB BF), and whether ReadStream positioned after the
// mark reads the same model.
//
// Both readers' ReadFile open the file through OSD_FileSystem::DefaultFileSystem()->OpenIStream
// (StepSelect_WorkLibrary.cxx:63 into StepFile_Read.cxx:77-89) and scan the stream, which has to
// start with `ISO-10303-21;`. ReadStream(name, stream) is the same read with the stream given by the
// caller (StepSelect_WorkLibrary.cxx:78). This probe writes a 10 x 20 x 30 box, writes a copy with
// the mark in front, and for each reader prints the status of
//   ReadFile(plain)           the control
//   ReadFile(marked)          the defect
//   ReadStream(marked, after) the mark skipped, which is what OCCTSwift now does
//   ReadStream(marked, whole) the mark NOT skipped: the same refusal as ReadFile, so the stream path
//                             is not what makes the difference, the skipped bytes are
// and, where a read completed, the number of roots and the volume the transfer gives.
//
// Compile (from the repo root, against the xcframework the package pins):
//   XC=Libraries/OCCT.xcframework      # or .build/artifacts/<package>/OCCT/OCCT.xcframework
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/3529/occt_3529_step_bom.mm -o /tmp/occt_3529
//   /tmp/occt_3529 > Scripts/repro/3529/probe-output.txt
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <OSD_FileSystem.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <TDocStd_Document.hxx>
#include <TCollection_AsciiString.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>

#include <cstdio>
#include <fstream>
#include <iterator>
#include <memory>
#include <sstream>
#include <string>
#include <unistd.h>
#include <vector>

static const char* statusName(IFSelect_ReturnStatus s)
{
  switch (s)
  {
    case IFSelect_RetVoid: return "RetVoid";
    case IFSelect_RetDone: return "RetDone";
    case IFSelect_RetError: return "RetError";
    case IFSelect_RetFail: return "RetFail";
    case IFSelect_RetStop: return "RetStop";
  }
  return "?";
}

static std::string slurp(const std::string& path)
{
  std::ifstream in(path, std::ios::binary);
  return std::string((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
}

static void spit(const std::string& path, const std::string& bytes)
{
  std::ofstream out(path, std::ios::binary);
  out.write(bytes.data(), (std::streamsize)bytes.size());
}

static double volumeOf(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

// Reads `bytes` as a STEP model with STEPControl_Reader, the stream from `skip` bytes in.
static void probeStepControl(const char* label, const std::string& path, size_t skip, bool stream)
{
  STEPControl_Reader reader;
  IFSelect_ReturnStatus status;
  if (stream)
  {
    const occ::handle<OSD_FileSystem>& fs = OSD_FileSystem::DefaultFileSystem();
    std::shared_ptr<std::istream>      in = fs->OpenIStream(path.c_str(), std::ios::in | std::ios::binary);
    in->ignore((std::streamsize)skip);
    status = reader.ReadStream(path.c_str(), *in);
  }
  else
  {
    status = reader.ReadFile(path.c_str());
  }
  printf("  STEPControl_Reader     %-28s %s", label, statusName(status));
  if (status == IFSelect_RetDone)
  {
    reader.TransferRoots();
    printf("  roots=%d  volume=%g", reader.NbRootsForTransfer(), volumeOf(reader.OneShape()));
  }
  printf("\n");
}

static void probeStepCaf(const char* label, const std::string& path, size_t skip, bool stream)
{
  STEPCAFControl_Reader reader;
  IFSelect_ReturnStatus status;
  if (stream)
  {
    const occ::handle<OSD_FileSystem>& fs = OSD_FileSystem::DefaultFileSystem();
    std::shared_ptr<std::istream>      in = fs->OpenIStream(path.c_str(), std::ios::in | std::ios::binary);
    in->ignore((std::streamsize)skip);
    status = reader.ReadStream(path.c_str(), *in);
  }
  else
  {
    status = reader.ReadFile(path.c_str());
  }
  printf("  STEPCAFControl_Reader  %-28s %s", label, statusName(status));
  if (status == IFSelect_RetDone)
  {
    occ::handle<XCAFApp_Application> app = XCAFApp_Application::GetApplication();
    occ::handle<TDocStd_Document>    doc;
    app->NewDocument("BinXCAF", doc);
    const bool ok = reader.Transfer(doc);
    NCollection_Sequence<TDF_Label> labels;
    XCAFDoc_DocumentTool::ShapeTool(doc->Main())->GetFreeShapes(labels);
    printf("  transfer=%d  freeShapes=%d", (int)ok, labels.Length());
  }
  printf("\n");
}

int main()
{
  const std::string dir   = "/tmp/occt3529_" + std::to_string(getpid());
  (void)!system(("mkdir -p " + dir).c_str());
  const std::string plain  = dir + "/plain.step";
  const std::string marked = dir + "/marked.step";

  {
    STEPControl_Writer writer;
    writer.Transfer(BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape(), STEPControl_AsIs);
    writer.Write(plain.c_str());
  }
  const std::string bytes = slurp(plain);
  spit(marked, std::string("\xEF\xBB\xBF") + bytes);
  printf("plain:  %zu bytes, starts with %.13s\n", bytes.size(), bytes.c_str());
  printf("marked: %zu bytes, starts with EF BB BF\n\n", bytes.size() + 3);

  probeStepControl("ReadFile(plain)", plain, 0, false);
  probeStepControl("ReadFile(marked)", marked, 0, false);
  probeStepControl("ReadStream(marked, skip 3)", marked, 3, true);
  probeStepControl("ReadStream(marked, skip 0)", marked, 0, true);
  printf("\n");
  probeStepCaf("ReadFile(plain)", plain, 0, false);
  probeStepCaf("ReadFile(marked)", marked, 0, false);
  probeStepCaf("ReadStream(marked, skip 3)", marked, 3, true);
  probeStepCaf("ReadStream(marked, skip 0)", marked, 0, true);

  (void)!system(("rm -rf " + dir).c_str());
  return 0;
}
