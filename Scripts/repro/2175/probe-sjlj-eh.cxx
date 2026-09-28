// #2175: setjmp and wasm exceptions in one function produce an INVALID module.
//
// This is the blocker the Phase 0 spike hit, reduced to a file with no OCCT in it. It reproduces
// the shape `OCC_CATCH_SIGNALS` has inside a `try` block, which is what
// `Standard_ErrorHandler.hxx` expands to when `OCC_CONVERT_SIGNALS` is defined:
//
//     try { Standard_ErrorHandler h; if (setjmp(h.Label())) { h.Raise(); } ... }
//     catch (Standard_Failure const&) { ... }
//
// and repeats it, because the function that first failed,
// `BRepCheck_ParallelAnalyzer::operator()(int) const`, carries SIX of them in one body.
//
// Built with the exception flags and `-mllvm -wasm-enable-sjlj`, exactly as
// Scripts/build-occt-wasm.sh built OCCT before this issue, the emitted function contains a
// `br_table` whose targets do not all have the same label types: one is a multi-value block
// carrying `[i32, exnref]`, the others carry nothing. The WebAssembly specification requires
// every `br_table` target to have the same label types, so the module is invalid and a
// conforming runtime must refuse it. wasmkit does, with
//
//     expected the same copy types for all branches in `br_table`
//
// Built with the same flags and no setjmp, the same function is valid and runs.
//
// `run.sh sjlj` builds it both ways and runs both.

#include <csetjmp>
#include <cstdio>
#include <cstdlib>

namespace {

struct Failure
{
  int code;
};

// Stands in for Standard_ErrorHandler: an object with a jmp_buf, a destructor that must run
// during unwinding, and a Raise() that throws. The destructor is what makes this an exception
// problem as well as a setjmp one.
class Handler
{
public:
  Handler()
      : myActive(true)
  {
  }

  ~Handler() { myActive = false; }

  std::jmp_buf& Label() { return myLabel; }

  void Raise() const { throw Failure{myActive ? 7 : 11}; }

private:
  std::jmp_buf myLabel;
  bool         myActive;
};

// The compiler must not fold the branches away, so the trip counts come from argv.
volatile int gSink = 0;

int oneGuardedSection(int aSelector)
{
  int aTotal = 0;
  try
  {
    Handler aHandler;
    if (setjmp(aHandler.Label()))
    {
      aHandler.Raise();
    }
    if (aSelector == 3)
    {
      throw Failure{aSelector};
    }
    aTotal += aSelector;
  }
  catch (const Failure& aFailure)
  {
    aTotal -= aFailure.code;
  }
  return aTotal;
}

// Six guarded sections in one function body, which is the count in
// BRepCheck_ParallelAnalyzer::operator()(int) const.
int sixGuardedSections(int aSelector)
{
  int aTotal = 0;
  for (int anIndex = 0; anIndex < 6; ++anIndex)
  {
    try
    {
      Handler aHandler;
      if (setjmp(aHandler.Label()))
      {
        aHandler.Raise();
      }
      if (aSelector == anIndex)
      {
        throw Failure{anIndex};
      }
      aTotal += anIndex;
      gSink = aTotal;
    }
    catch (const Failure& aFailure)
    {
      aTotal -= aFailure.code;
    }
  }
  return aTotal;
}

} // namespace

int main(int argc, char** argv)
{
  const int aSelector = argc > 1 ? std::atoi(argv[1]) : 3;
  std::printf("one guarded section:  %d\n", oneGuardedSection(aSelector));
  std::printf("six guarded sections: %d\n", sixGuardedSections(aSelector));
  std::printf("both returned, so the module was accepted and both exception paths ran\n");
  return 0;
}
