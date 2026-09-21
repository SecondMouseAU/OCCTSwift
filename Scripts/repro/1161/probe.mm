// Probe for issue #1161: can a shared helper, called from inside an existing
// `catch (...)` block, classify the in-flight exception with a bare `throw;`?
//
// Build:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1161/probe.mm -o /tmp/occt_probe_1161

#include <Standard_Failure.hxx>
#include <Standard_ConstructionError.hxx>
#include <Standard_OutOfRange.hxx>
#include <Standard_NullObject.hxx>
#include <gp_Dir.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <exception>
#include <stdexcept>
#include <cstdio>
#include <string>

// The candidate helper shape: called from inside `catch (...) { }`.
static void classify(const char* theContext)
{
  try
  {
    throw;
  }
  catch (const Standard_Failure& anEx)
  {
    std::printf("  [%s] Standard_Failure type=%s what=\"%s\" stackLen=%zu\n",
                theContext,
                anEx.ExceptionType(),
                anEx.what(),
                std::string(anEx.GetStackString()).size());
  }
  catch (const std::exception& anEx)
  {
    std::printf("  [%s] std::exception what=\"%s\"\n", theContext, anEx.what());
  }
  catch (...)
  {
    std::printf("  [%s] unknown exception\n", theContext);
  }
}

// The guard the shipped helper carries: a bare `throw;` with no exception in flight calls
// std::terminate, and std::current_exception() is how that is detected without throwing.
static void classifyGuarded(const char* theContext)
{
  if (!std::current_exception())
  {
    std::printf("  [%s] guard fired: no exception in flight, returning safely\n", theContext);
    return;
  }
  classify(theContext);
}

int main()
{
  std::printf("1. Standard_ConstructionError thrown by hand\n");
  try
  {
    throw Standard_ConstructionError("hand-thrown construction error");
  }
  catch (...)
  {
    classify("case1");
  }

  std::printf("2. real OCCT throw: gp_Dir from a zero vector\n");
  try
  {
    gp_Dir aDir(0.0, 0.0, 0.0);
    (void)aDir;
  }
  catch (...)
  {
    classify("case2");
  }

  std::printf("3. std::runtime_error\n");
  try
  {
    throw std::runtime_error("plain std error");
  }
  catch (...)
  {
    classify("case3");
  }

  std::printf("4. non-exception type (int)\n");
  try
  {
    throw 42;
  }
  catch (...)
  {
    classify("case4");
  }

  std::printf("5. nested: helper called from an INNER catch, outer still rethrows fine\n");
  try
  {
    try
    {
      throw Standard_OutOfRange("inner");
    }
    catch (...)
    {
      classify("case5-inner");
      throw; // outer must still see the same exception
    }
  }
  catch (...)
  {
    classify("case5-outer");
  }

  std::printf("6. with stack traces requested\n");
  Standard_Failure::SetDefaultStackTraceLength(8);
  try
  {
    throw Standard_NullObject("with trace");
  }
  catch (...)
  {
    classify("case6");
  }
  Standard_Failure::SetDefaultStackTraceLength(0);

  std::printf("7. OCCT throw from deeper in the kernel: MakeEdge on identical points\n");
  try
  {
    BRepBuilderAPI_MakeEdge aMaker(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 0));
    (void)aMaker.Edge(); // Edge() raises StdFail_NotDone when not done
  }
  catch (...)
  {
    classify("case7");
  }

  std::printf("8. the guard: helper called with NO exception in flight\n");
  // A bare throw; with no exception in flight calls std::terminate, so the shipped helper checks
  // std::current_exception() first. This is that check, called from outside any catch block: it
  // must print the guard line and return, leaving the process alive to reach "done" below.
  classifyGuarded("case8");

  std::printf("done\n");
  return 0;
}
