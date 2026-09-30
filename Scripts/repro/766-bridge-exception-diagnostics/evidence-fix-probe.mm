// #766 / #1989 evidence correction for Tests/OCCTMiscTests/BridgeExceptionDiagnosticsTests.swift:
// the kernel side of the like-for-like records, one `<record>|<key>|<json>` line per key, the same
// format as the Swift-side print in bridge-observed.txt (a temporary test, deleted, never
// committed). The earlier probe.mm in this directory printed prose and named different quantities
// on the two sides. Keys starting with an underscore are notes, not part of a record.
//
// Build (from the repo root, against the SwiftPM-resolved pinned kernel):
//   X=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$X/Headers" -L"$X" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/766-bridge-exception-diagnostics/evidence-fix-probe.mm -o /tmp/probe_766_bed_fix

#include <IntTools_Tools.hxx>
#include <Standard_Failure.hxx>
#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>
#include <string>

static void emit(const char* id, const char* key, const std::string& json)
{
  std::printf("%s|%s|%s\n", id, key, json.c_str());
}
static std::string q(const std::string& s)
{
  std::string o = "\"";
  for (char c : s)
  {
    if (c == '"' || c == '\\')
      o += '\\';
    o += c;
  }
  return o + "\"";
}
static std::string b(bool v) { return v ? "true" : "false"; }

int main()
{
  // d1 and d6: what OCCTIntToolsIsDirsCoinside(0,0,0, 0,0,1) catches, at the default stack depth.
  try
  {
    IntTools_Tools::IsDirsCoinside(gp_Dir(0, 0, 0), gp_Dir(0, 0, 1));
    std::printf("d1|_no_throw|true\n");
  }
  catch (const Standard_Failure& e)
  {
    std::string stack = e.GetStackString() != nullptr ? e.GetStackString() : "";
    emit("d1", "exception_type", q(e.ExceptionType()));
    emit("d1", "message", q(e.what()));
    emit("d1", "stack_trace_empty", b(stack.empty()));
    emit("d6", "exception_type", q(e.ExceptionType()));
    emit("d6", "message", q(e.what()));
  }
  // d2: OCCTShapeHistoryFromRotate builds gp_Ax1(origin, gp_Dir(axis)) from the zero axis.
  try
  {
    gp_Ax1 axis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 0));
    (void)axis;
    std::printf("d2|_no_throw|true\n");
  }
  catch (const Standard_Failure& e)
  {
    emit("d2", "exception_type", q(e.ExceptionType()));
    emit("d2", "message", q(e.what()));
  }
  // d3: the same call with two equal unit directions.
  try
  {
    bool r = IntTools_Tools::IsDirsCoinside(gp_Dir(0, 0, 1), gp_Dir(0, 0, 1));
    emit("d3", "value", b(r));
    emit("d3", "threw", b(false));
  }
  catch (const Standard_Failure&)
  {
    emit("d3", "threw", b(true));
  }
  // d4: the default stack depth, then the stack string at depth 0 and at depth 16.
  {
    emit("d4", "depth_initial", std::to_string(Standard_Failure::DefaultStackTraceLength()));
    auto stackEmpty = []() {
      try
      {
        gp_Dir d(0, 0, 0);
        (void)d;
      }
      catch (const Standard_Failure& e)
      {
        std::string s = e.GetStackString() != nullptr ? e.GetStackString() : "";
        return s.empty();
      }
      return true;
    };
    emit("d4", "depth0_stack_empty", b(stackEmpty()));
    Standard_Failure::SetDefaultStackTraceLength(16);
    emit("d4", "depth_after_set_16", std::to_string(Standard_Failure::DefaultStackTraceLength()));
    emit("d4", "depth16_stack_empty", b(stackEmpty()));
  }
  // d5: what the kernel reads back after SetDefaultStackTraceLength(-5), with nothing clamping it.
  Standard_Failure::SetDefaultStackTraceLength(-5);
  emit("d5", "read_back", std::to_string(Standard_Failure::DefaultStackTraceLength()));
  Standard_Failure::SetDefaultStackTraceLength(0);
  return 0;
}
