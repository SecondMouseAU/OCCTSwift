// #2174: STEP export on wasip1, in its own executable.
//
// Separate from probe.cxx because it does not link. STEPConstruct_ContextTool references
// STEPConstruct_AP203Context, which is the ONE source file of 5,488 that this build does not
// compile: it includes <pwd.h> behind a guard that names _WIN32, __ANDROID__ and __EMSCRIPTEN__
// and not WASI. So this file is the measurement of what that single gap costs, and it is expected
// to fail at the link until the gap is closed. Run it through run.sh, which reports the link's
// result as a measurement rather than as an error.
//
// #1689's client scope is STEP export, STEP import and mesh export, so this is not an incidental
// file: it sits on the path the whole port exists to serve.

#include <cstdio>

#include <BRepPrimAPI_MakeBox.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <STEPControl_StepModelType.hxx>
#include <STEPControl_Writer.hxx>
#include <TopoDS_Shape.hxx>

int main(int argc, char** argv)
{
  if (argc < 2)
  {
    std::printf("usage: probe-step <writable-directory>\n");
    return 2;
  }
  char aPath[512];
  std::snprintf(aPath, sizeof(aPath), "%s/probe-box.step", argv[1]);

  const TopoDS_Shape aBox = BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();

  STEPControl_Writer          aWriter;
  const IFSelect_ReturnStatus aTransferred = aWriter.Transfer(aBox, STEPControl_AsIs);
  const IFSelect_ReturnStatus aWritten =
    (aTransferred == IFSelect_RetDone) ? aWriter.Write(aPath) : aTransferred;

  long aBytes = -1;
  if (std::FILE* aFile = std::fopen(aPath, "rb"))
  {
    std::fseek(aFile, 0, SEEK_END);
    aBytes = std::ftell(aFile);
    std::fclose(aFile);
  }
  std::printf("Transfer=%d Write=%d file=%s bytes=%ld\n", (int)aTransferred, (int)aWritten, aPath,
              aBytes);
  return (aTransferred == IFSelect_RetDone && aWritten == IFSelect_RetDone && aBytes > 0) ? 0 : 1;
}
