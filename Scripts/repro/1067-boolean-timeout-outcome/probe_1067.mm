// Ground truth for #1067: does the boolean watchdog already know it tripped, and does that
// knowledge separate "the geometry is bad" from "the deadline passed"?
//
// Replicates runBooleanEx (OCCTBridge_Modeling.mm) exactly, then prints the three facts the
// bridge has at the moment it decides to return nullptr: IsDone(), the watchdog's own
// tripped() flag, and elapsed wall clock.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1067-boolean-timeout-outcome/probe_1067.mm -o /tmp/probe_1067
//   /tmp/probe_1067

#include <BOPAlgo_Alerts.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <Message_ProgressIndicator.hxx>
#include <Message_ProgressRange.hxx>
#include <Message_ProgressScope.hxx>
#include <Standard_Failure.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shape.hxx>
#include <BRep_Builder.hxx>
#include <gp_Ax1.hxx>
#include <gp_Trsf.hxx>

#include <chrono>
#include <cstdio>

// Verbatim copy of the bridge's watchdog.
class ProbeBreaker : public Message_ProgressIndicator
{
public:
  explicit ProbeBreaker(double seconds)
      : myDeadline(std::chrono::steady_clock::now()
                   + std::chrono::duration_cast<std::chrono::steady_clock::duration>(
                     std::chrono::duration<double>(seconds)))
  {
  }

  Standard_Boolean UserBreak() override
  {
    ++myPolls;
    if (std::chrono::steady_clock::now() >= myDeadline)
    {
      myTripped = true;
      return Standard_True;
    }
    return Standard_False;
  }

  void Show(const Message_ProgressScope&, const Standard_Boolean) override {}

  bool tripped() const { return myTripped; }
  long polls() const { return myPolls; }

  DEFINE_STANDARD_RTTI_INLINE(ProbeBreaker, Message_ProgressIndicator)
private:
  std::chrono::steady_clock::time_point myDeadline;
  bool                                  myTripped = false;
  long                                  myPolls   = 0;
};
DEFINE_STANDARD_HANDLE(ProbeBreaker, Message_ProgressIndicator)

struct Outcome
{
  bool   isDone     = false;
  bool   tripped    = false;
  bool   threw      = false;
  bool   userBreak  = false;  // second construction: OCCT's own BOPAlgo_AlertUserBreak
  bool   hasErrors  = false;
  long   polls      = 0;
  double seconds    = 0.0;
};

template <typename BoolOpT>
static Outcome runBoolean(const TopoDS_Shape& a, const TopoDS_Shape& b, double timeoutSeconds)
{
  Outcome                out;
  Handle(ProbeBreaker)   breaker;
  const auto             t0 = std::chrono::steady_clock::now();
  try
  {
    BoolOpT              op;
    TopTools_ListOfShape args;
    args.Append(a);
    TopTools_ListOfShape tools;
    tools.Append(b);
    op.SetArguments(args);
    op.SetTools(tools);
    if (timeoutSeconds > 0.0)
    {
      breaker                     = new ProbeBreaker(timeoutSeconds);
      Message_ProgressRange range = breaker->Start();
      op.Build(range);
    }
    else
    {
      op.Build();
    }
    out.isDone    = op.IsDone();
    out.hasErrors = op.HasErrors();
    out.userBreak = op.HasError(STANDARD_TYPE(BOPAlgo_AlertUserBreak));
  }
  catch (const Standard_Failure&)
  {
    out.threw = true;
  }
  catch (...)
  {
    out.threw = true;
  }
  out.seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
  if (!breaker.IsNull())
  {
    out.tripped = breaker->tripped();
    out.polls   = breaker->polls();
  }
  return out;
}

static void report(const char* label, const Outcome& o)
{
  std::printf("%-42s IsDone=%-5s tripped=%-5s userBreak=%-5s hasErr=%-5s threw=%-5s polls=%-6ld %.4fs\n",
              label,
              o.isDone ? "true" : "false",
              o.tripped ? "true" : "false",
              o.userBreak ? "true" : "false",
              o.hasErrors ? "true" : "false",
              o.threw ? "true" : "false",
              o.polls,
              o.seconds);
}

int main()
{
  // The issue's own fixture: 36 tool copies cut from a cylinder.
  TopoDS_Shape blank = BRepPrimAPI_MakeCylinder(20.0, 10.0).Shape();

  gp_Trsf shift;
  shift.SetTranslation(gp_Vec(15.0, 0.0, -10.0));
  TopoDS_Shape oneTool =
    BRepBuilderAPI_Transform(BRepPrimAPI_MakeCylinder(2.0, 30.0).Shape(), shift, Standard_True)
      .Shape();

  BRep_Builder    builder;
  TopoDS_Compound tools;
  builder.MakeCompound(tools);
  for (int i = 0; i < 36; ++i)
  {
    gp_Trsf rot;
    rot.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), i * (2.0 * M_PI / 36.0));
    builder.Add(tools, BRepBuilderAPI_Transform(oneTool, rot, Standard_True).Shape());
  }

  std::printf("=== 36-tool cut, the issue's fixture ===\n");
  report("cut, timeout 0 (unbounded)", runBoolean<BRepAlgoAPI_Cut>(blank, tools, 0.0));
  report("cut, timeout 120 (the default)", runBoolean<BRepAlgoAPI_Cut>(blank, tools, 120.0));
  report("cut, timeout 1e-9 (deadline already past)",
         runBoolean<BRepAlgoAPI_Cut>(blank, tools, 1e-9));
  report("cut, timeout 0.001", runBoolean<BRepAlgoAPI_Cut>(blank, tools, 0.001));

  std::printf("\n=== trivial cut: does a small boolean poll at all? ===\n");
  TopoDS_Shape smallA = BRepPrimAPI_MakeCylinder(10.0, 10.0).Shape();
  TopoDS_Shape smallB = BRepPrimAPI_MakeCylinder(4.0, 30.0).Shape();
  report("small cut, timeout 0 (unbounded)", runBoolean<BRepAlgoAPI_Cut>(smallA, smallB, 0.0));
  report("small cut, timeout 1e-9", runBoolean<BRepAlgoAPI_Cut>(smallA, smallB, 1e-9));
  report("small fuse, timeout 1e-9", runBoolean<BRepAlgoAPI_Fuse>(smallA, smallB, 1e-9));
  report("small common, timeout 1e-9", runBoolean<BRepAlgoAPI_Common>(smallA, smallB, 1e-9));

  std::printf("\n=== genuine failure: a null operand, no watchdog at all ===\n");
  TopoDS_Shape nullShape;  // default-constructed, IsNull() == true
  report("cut by null, timeout 0 (unbounded)",
         runBoolean<BRepAlgoAPI_Cut>(smallA, nullShape, 0.0));
  report("cut by null, timeout 120", runBoolean<BRepAlgoAPI_Cut>(smallA, nullShape, 120.0));
  report("fuse with null, timeout 120", runBoolean<BRepAlgoAPI_Fuse>(smallA, nullShape, 120.0));
  report("common with null, timeout 120",
         runBoolean<BRepAlgoAPI_Common>(smallA, nullShape, 120.0));

  std::printf("\n=== stability of the tiny-timeout trip, 200 repeats ===\n");
  int trippedCount   = 0;
  int doneCount      = 0;
  int userBreakCount = 0;
  int agreeCount     = 0;
  for (int i = 0; i < 200; ++i)
  {
    Outcome o = runBoolean<BRepAlgoAPI_Cut>(smallA, smallB, 1e-9);
    if (o.tripped)
      ++trippedCount;
    if (o.isDone)
      ++doneCount;
    if (o.userBreak)
      ++userBreakCount;
    if (o.tripped == o.userBreak)
      ++agreeCount;
  }
  std::printf("tripped %d/200, IsDone %d/200, userBreak %d/200, tripped==userBreak %d/200\n",
              trippedCount,
              doneCount,
              userBreakCount,
              agreeCount);

  return 0;
}
