// OCCTSwift#3522 ground truth: BRepFilletAPI_MakeChamfer::NbSurf(IC) on a contour that holds no
// surface data, and whether ChFi3d_Builder::NbComputedSurfaces(IC) is an exact predicate for it.
//
// Scripts/repro/3519/ measured the fault (NbSurf is `stripe->SetOfSurfData()->Length()` with no null
// test, and a stripe's sequence is null until Build or Simulate reaches it and null again after
// Reset()) and fixed the fillet side with BRepFilletAPI_MakeFillet::NbComputedSurfaces, which reads
// the same length behind `if (hd.IsNull()) return 0;`. BRepFilletAPI_MakeChamfer exposes no such
// member and keeps its ChFi3d_ChBuilder in a private field `myBuilder`, so the predicate was
// thought unreachable (#3522).
//
// It is reachable without a kernel change. C++ lets exactly one construct name a private member
// outside its class: the argument of an explicit instantiation. This probe uses it to take a
// pointer to `BRepFilletAPI_MakeChamfer::myBuilder` and calls the public
// `ChFi3d_Builder::NbComputedSurfaces` on it, which is what the bridge does. The same code is in
// Sources/OCCTBridge/src/OCCTBridge_Modeling_Chamfer.mm.
//
// For every (state, IC) pair, each in its own forked child so a SIGSEGV is a recorded cell and not
// the end of the probe, it prints:
//   NbSurf        what OCCT answers, or SEGV
//   predicate     NbComputedSurfaces(IC) through the opened member
//   bridge        what the bridge now answers: 0 while the predicate is 0, otherwise NbSurf(IC)
// and it exits non-zero when
//   - NbSurf answered and the predicate disagrees with it (so the bridge would change an answer), or
//   - NbSurf faulted and the predicate is above 0 (so the bridge would still fault), or
//   - the bridge column faulted anywhere.
// The corner-stripe state is the one where the stripe list is longer than NbContours(): three
// chamfers meeting at a vertex leave a fourth stripe with no spine, which NbSurf(4) reads as a
// contour and NbContours() does not count.
//
// Compile (from the repo root, against the xcframework the package pins):
//   XC=Libraries/OCCT.xcframework      # or .build/artifacts/<package>/OCCT/OCCT.xcframework
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/3522/occt_3522_chamfer_surfdata_matrix.mm -o /tmp/occt_3522
//   /tmp/occt_3522 > Scripts/repro/3522/probe-output.txt; echo "exit $?"
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>

#include <cstdio>
#include <cstring>
#include <functional>
#include <memory>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

// ---- the private member, opened ---------------------------------------------------------------

namespace
{
struct InnerBuilderTag
{
  typedef ChFi3d_ChBuilder BRepFilletAPI_MakeChamfer::* Type;
  friend Type innerBuilderOf(InnerBuilderTag);
};

template <class Tag, typename Tag::Type Member>
struct InnerBuilderOpener
{
  friend typename Tag::Type innerBuilderOf(Tag) { return Member; }
};

template struct InnerBuilderOpener<InnerBuilderTag, &BRepFilletAPI_MakeChamfer::myBuilder>;
} // namespace

static int predicate(const BRepFilletAPI_MakeChamfer& chamfer, int ic)
{
  const ChFi3d_ChBuilder& inner = chamfer.*innerBuilderOf(InnerBuilderTag());
  return inner.NbComputedSurfaces(ic);
}

static int bridgeAnswer(const BRepFilletAPI_MakeChamfer& chamfer, int ic)
{
  if (predicate(chamfer, ic) <= 0)
    return 0;
  return chamfer.NbSurf(ic);
}

// ---- fork harness -----------------------------------------------------------------------------

static std::string runForked(const std::function<std::string()>& fn)
{
  int fds[2];
  if (pipe(fds) != 0)
    return "pipe failed";
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    close(fds[0]);
    std::string r;
    try
    {
      r = fn();
    }
    catch (Standard_Failure const& f)
    {
      r = std::string("threw:") + (f.GetMessageString() ? f.GetMessageString() : "");
    }
    catch (...)
    {
      r = "threw unknown";
    }
    (void)!write(fds[1], r.data(), r.size());
    _exit(0);
  }
  close(fds[1]);
  std::string out;
  char        buf[256];
  ssize_t     n;
  while ((n = read(fds[0], buf, sizeof buf)) > 0)
    out.append(buf, (size_t)n);
  close(fds[0]);
  int status = 0;
  waitpid(pid, &status, 0);
  if (WIFSIGNALED(status))
    return (WTERMSIG(status) == SIGSEGV || WTERMSIG(status) == SIGBUS) ? "SEGV" : "SIG?";
  return out.empty() ? "(none)" : out;
}

// ---- fixtures and states ----------------------------------------------------------------------

struct Fixture
{
  TopoDS_Shape             shape;
  std::vector<TopoDS_Edge> contourEdges;  // edges that each open a contour of their own
  std::vector<TopoDS_Edge> vertexEdges;   // the three box edges meeting at one vertex
};

static Fixture boxFixture()
{
  Fixture f;
  f.shape = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(f.shape, TopAbs_EDGE, edges);
  {
    BRepFilletAPI_MakeChamfer probe(f.shape);
    for (int i = 1; i <= edges.Extent() && f.contourEdges.size() < 3; ++i)
    {
      const int before = probe.NbContours();
      probe.Add(1.0, TopoDS::Edge(edges(i)));
      if (probe.NbContours() > before)
        f.contourEdges.push_back(TopoDS::Edge(edges(i)));
    }
  }
  TopTools_IndexedDataMapOfShapeListOfShape ancestors;
  TopExp::MapShapesAndAncestors(f.shape, TopAbs_VERTEX, TopAbs_EDGE, ancestors);
  for (const TopoDS_Shape& e : ancestors.FindFromIndex(1))
    f.vertexEdges.push_back(TopoDS::Edge(e));
  return f;
}

enum State
{
  Fresh,               // constructed, nothing added
  AddedNotRun,         // one edge added, never built, never simulated
  Simulated,           // CONTROL: Simulate(1)
  SimulatedThenReset,  // Simulate(1), Reset()
  SimulatedAgain,      // Simulate(1), Reset(), Simulate(1)
  BuiltOk,             // Build() completed
  BuiltThenReset,      // Build() completed, Reset()
  SimulatedThenBuilt,  // Simulate(1), Build()
  BuiltThenSimulated,  // Build(), Simulate(1)
  DeclinedBuild,       // distance 20: Build() leaves IsDone() false
  SimulateDeclined,    // distance 20: Simulate(1) throws
  BuildNoContour,      // Build() with nothing added: throws
  TwoSim1,             // two contours, only Simulate(1)
  TwoNone,             // two contours, nothing run
  BuiltThenAdd,        // Build(), then Add of a second contour: contour 2 never run
  BuiltTwoThenRemove,  // two contours built, then the first one removed: contour 2 becomes 1
  BuiltAtVertex        // three chamfers meeting at a vertex, built: a corner stripe after NbContours
};

static const State kStates[] = {Fresh,          AddedNotRun,       Simulated,
                                SimulatedThenReset, SimulatedAgain, BuiltOk,
                                BuiltThenReset, SimulatedThenBuilt, BuiltThenSimulated,
                                DeclinedBuild,  SimulateDeclined,   BuildNoContour,
                                TwoSim1,        TwoNone,            BuiltThenAdd,
                                BuiltTwoThenRemove, BuiltAtVertex};

static const char* stateName(State s)
{
  switch (s)
  {
    case Fresh: return "fresh (no contour)";
    case AddedNotRun: return "edge added, never built or simulated";
    case Simulated: return "CONTROL: Simulate(1)";
    case SimulatedThenReset: return "Simulate(1), Reset()";
    case SimulatedAgain: return "Simulate(1), Reset(), Simulate(1)";
    case BuiltOk: return "built ok";
    case BuiltThenReset: return "built ok, Reset()";
    case SimulatedThenBuilt: return "Simulate(1), Build()";
    case BuiltThenSimulated: return "Build(), Simulate(1)";
    case DeclinedBuild: return "declined build (distance 20)";
    case SimulateDeclined: return "Simulate(1) declined (distance 20)";
    case BuildNoContour: return "Build() with no contour";
    case TwoSim1: return "two contours, only Simulate(1)";
    case TwoNone: return "two contours, nothing run";
    case BuiltThenAdd: return "built ok, then a second edge added";
    case BuiltTwoThenRemove: return "two built, first contour removed";
    case BuiltAtVertex: return "three edges at a vertex, built";
  }
  return "?";
}

static std::string setup(State s, BRepFilletAPI_MakeChamfer& mk, const Fixture& fx)
{
  std::string note;
  auto        step = [&](const std::function<void()>& f)
  {
    try
    {
      f();
    }
    catch (Standard_Failure const& e)
    {
      note += std::string("[threw: ") + (e.GetMessageString() ? e.GetMessageString() : "") + "] ";
    }
  };
  const TopoDS_Edge& e1 = fx.contourEdges[0];
  const TopoDS_Edge& e2 = fx.contourEdges[1];
  switch (s)
  {
    case Fresh: break;
    case AddedNotRun: mk.Add(1.0, e1); break;
    case Simulated:
      mk.Add(1.0, e1);
      step([&] { mk.Simulate(1); });
      break;
    case SimulatedThenReset:
      mk.Add(1.0, e1);
      step([&] { mk.Simulate(1); });
      mk.Reset();
      break;
    case SimulatedAgain:
      mk.Add(1.0, e1);
      step([&] { mk.Simulate(1); });
      mk.Reset();
      step([&] { mk.Simulate(1); });
      break;
    case BuiltOk:
      mk.Add(1.0, e1);
      step([&] { mk.Build(); });
      break;
    case BuiltThenReset:
      mk.Add(1.0, e1);
      step([&] { mk.Build(); });
      mk.Reset();
      break;
    case SimulatedThenBuilt:
      mk.Add(1.0, e1);
      step([&] { mk.Simulate(1); });
      step([&] { mk.Build(); });
      break;
    case BuiltThenSimulated:
      mk.Add(1.0, e1);
      step([&] { mk.Build(); });
      step([&] { mk.Simulate(1); });
      break;
    case DeclinedBuild:
      mk.Add(20.0, e1);
      step([&] { mk.Build(); });
      break;
    case SimulateDeclined:
      mk.Add(20.0, e1);
      step([&] { mk.Simulate(1); });
      break;
    case BuildNoContour: step([&] { mk.Build(); }); break;
    case TwoSim1:
      mk.Add(1.0, e1);
      mk.Add(1.0, e2);
      step([&] { mk.Simulate(1); });
      break;
    case TwoNone:
      mk.Add(1.0, e1);
      mk.Add(1.0, e2);
      break;
    case BuiltThenAdd:
      mk.Add(1.0, e1);
      step([&] { mk.Build(); });
      mk.Add(1.0, e2);
      break;
    case BuiltTwoThenRemove:
      mk.Add(1.0, e1);
      mk.Add(1.0, e2);
      step([&] { mk.Build(); });
      mk.Remove(e1);
      break;
    case BuiltAtVertex:
      for (const TopoDS_Edge& e : fx.vertexEdges)
        mk.Add(1.0, e);
      step([&] { mk.Build(); });
      break;
  }
  return note;
}

static std::string num(double v)
{
  char b[64];
  snprintf(b, sizeof b, "%g", v);
  return b;
}

int main()
{
  int mismatches = 0;
  printf("=== BRepFilletAPI_MakeChamfer: NbSurf against the opened NbComputedSurfaces ===\n");
  for (State s : kStates)
  {
    auto run = [&](const std::function<double(BRepFilletAPI_MakeChamfer&)>& f)
    {
      return runForked(
        [&]() -> std::string
        {
          Fixture                   fx = boxFixture();
          BRepFilletAPI_MakeChamfer mk(fx.shape);
          setup(s, mk, fx);
          return num(f(mk));
        });
    };
    const std::string note = runForked(
      [&]() -> std::string
      {
        Fixture                   fx = boxFixture();
        BRepFilletAPI_MakeChamfer mk(fx.shape);
        return setup(s, mk, fx);
      });
    const std::string ncText = run([](BRepFilletAPI_MakeChamfer& m) { return m.NbContours(); });
    const std::string done   = run([](BRepFilletAPI_MakeChamfer& m) { return m.IsDone(); });
    const int         nc     = atoi(ncText.c_str());
    printf("\n--- state: %s\n    IsDone=%s NbContours=%s %s\n", stateName(s), done.c_str(),
           ncText.c_str(), note == "(none)" ? "" : note.c_str());
    for (int ic = 0; ic <= 4; ++ic)
    {
      const std::string n = run([&](BRepFilletAPI_MakeChamfer& m) { return m.NbSurf(ic); });
      const std::string p = run([&](BRepFilletAPI_MakeChamfer& m) { return predicate(m, ic); });
      const std::string b = run([&](BRepFilletAPI_MakeChamfer& m) { return bridgeAnswer(m, ic); });

      // The bridge never faults. For a real contour it keeps every answer NbSurf gave, and answers
      // 0, with a predicate of 0, where NbSurf faulted. Outside 1..NbContours() it answers 0, which
      // is the refusal and not a changed answer (a corner stripe is the only place NbSurf answers
      // there).
      const bool inRange = ic >= 1 && ic <= nc;
      bool       ok      = b != "SEGV";
      if (inRange && n != "SEGV")
        ok = ok && b == n && p == n;
      else if (inRange)
        ok = ok && b == "0" && p == "0";
      else
        ok = ok && b == "0";
      printf("    IC=%d%s  NbSurf=%-5s predicate=%-5s bridge=%-5s%s\n", ic,
             inRange ? " " : "*", n.c_str(), p.c_str(), b.c_str(), ok ? "" : "   <-- MISMATCH");
      if (!ok)
        ++mismatches;
    }
  }
  printf("\n(* = outside 1..NbContours())\n%d mismatch(es)\n", mismatches);
  return mismatches == 0 ? 0 : 1;
}
