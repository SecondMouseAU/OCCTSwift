// #2174, #2266: STEP export on wasip1, in its own executable.
//
// Separate from probe.cxx because until #2266 it did not link. STEPConstruct_ContextTool
// references STEPConstruct_AP203Context, which was the ONE source file of 5,488 that this build
// did not compile: it included <pwd.h> behind a guard that named _WIN32, __ANDROID__ and
// __EMSCRIPTEN__ and not WASI. So this file measured what that single gap cost, 20 undefined
// symbols, and `run.sh link` now ASSERTS that it links, runs and writes a file rather than
// reporting the failure as a result.
//
// It writes AP203 rather than the AP214IS default, deliberately. AP203 is the only schema for
// which STEPConstruct_ContextTool reaches theAP203 at all (`mySchema == 3`), so it is the only
// one under which wasi-stepconstruct-ap203context.patch's branches run: the person record built
// from an empty OSD_Process::UserName(), and the UTC offset that replaces `timezone`. Writing
// AP214IS here would link the patched object and execute none of it.
//
// #1689's client scope is STEP export, STEP import and mesh export, so this is not an incidental
// file: it sits on the path the whole port exists to serve.

#include <cstdio>
#include <cstring>

#include <BRepPrimAPI_MakeBox.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <Interface_Static.hxx>
#include <STEPControl_Controller.hxx>
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

  // Before the writer, not after: STEPControl_Writer's model captures WriteSchema from
  // Interface_Static when it is constructed.
  STEPControl_Controller::Init();
  Interface_Static::SetCVal("write.step.schema", "AP203");

  const TopoDS_Shape aBox = BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();

  STEPControl_Writer          aWriter;
  const IFSelect_ReturnStatus aTransferred = aWriter.Transfer(aBox, STEPControl_AsIs);
  const IFSelect_ReturnStatus aWritten =
    (aTransferred == IFSelect_RetDone) ? aWriter.Write(aPath) : aTransferred;

  // The AP203 product-management entities this patch supplies, echoed from the file that was
  // written rather than from the values the code meant to write.
  long aBytes    = -1;
  int  aPerson   = 0;
  int  aOrg      = 0;
  int  aUTCShift = 0;
  if (std::FILE* aFile = std::fopen(aPath, "rb"))
  {
    char aLine[1024];
    while (std::fgets(aLine, sizeof(aLine), aFile) != nullptr)
    {
      if (std::strstr(aLine, "PERSON(") != nullptr && std::strstr(aLine, "PERSON_AND_") == nullptr)
      {
        aPerson++;
        std::printf("  %s", aLine);
      }
      else if (std::strstr(aLine, "ORGANIZATION(") != nullptr)
      {
        aOrg++;
        std::printf("  %s", aLine);
      }
      else if (std::strstr(aLine, "COORDINATED_UNIVERSAL_TIME_OFFSET(") != nullptr)
      {
        aUTCShift++;
        std::printf("  %s", aLine);
      }
    }
    std::fseek(aFile, 0, SEEK_END);
    aBytes = std::ftell(aFile);
    std::fclose(aFile);
  }

  std::printf("Transfer=%d Write=%d file=%s bytes=%ld PERSON=%d ORGANIZATION=%d UTC_OFFSET=%d\n",
              (int)aTransferred, (int)aWritten, aPath, aBytes, aPerson, aOrg, aUTCShift);
  // The three entity counts are part of the assertion: an AP203 file with no PERSON and no
  // COORDINATED_UNIVERSAL_TIME_OFFSET would mean STEPConstruct_AP203Context linked and never ran,
  // which is the way this probe can pass while measuring nothing.
  return (aTransferred == IFSelect_RetDone && aWritten == IFSelect_RetDone && aBytes > 0
          && aPerson > 0 && aOrg > 0 && aUTCShift > 0)
           ? 0
           : 1;
}
