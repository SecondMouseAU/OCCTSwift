// OCCTSwift#3519 ground truth: which accessors that read a stripe's simulated surface data
// dereference a null sequence, and whether BRepFilletAPI_MakeFillet::NbComputedSurfaces(IC) is a
// safe predicate for "this stripe holds any".
//
// BRepFilletAPI_MakeFillet::NbSurf(IC) is ChFi3d_FilBuilder::NbSurf(IC), and that is
//   itel.Value()->SetOfSurfData()->Length()        (ChFi3d_FilBuilder.cxx:439-452)
// with no null test. ChFiDS_Stripe::myHdata (what SetOfSurfData() returns) is a default-null handle,
// assigned only when ChFi3d_Builder::PerformSetOfKPart / PerformSetOfSurf runs on the stripe (Build,
// and Simulate, which is PerformSetOfSurf(stripe, true)), and Nullify()'d again by
// ChFiDS_Stripe::Reset(), which ChFi3d_Builder::Reset() runs on every stripe. Sect(IC, IS) has the
// same read, one step further: SetOfSurfData()->Value(IS)->Simul().
//
// ChFi3d_Builder::NbComputedSurfaces(IC) (ChFi3d_Builder_1.cxx:438-467) reads the same length
// behind `if (hd.IsNull()) return 0;`, so it is the null test OCCT itself ships for that sequence.
//
// Every (state, accessor) pair runs in its own forked child, so a SIGSEGV is a recorded row and not
// the end of the probe. OCC_CATCH_SIGNALS is inert in this build, so nothing in-process could
// absorb the signal; the parent reads it from waitpid. Reuses the harness of
// Scripts/repro/3516/occt_3516_nbsurfaces_matrix.mm.
//
// Compile (from the repo root, against the xcframework the package pins):
//   XC=.build/artifacts/<package>/OCCT/OCCT.xcframework
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/3519/occt_3519_simulated_surf_matrix.mm -o /tmp/occt_3519
#include <BRepAdaptor_Surface.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

#include <cstdio>
#include <cstring>
#include <functional>
#include <map>
#include <memory>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

// ---- fork harness (as in 3516) ---------------------------------------------------------------

static std::string runForked(const std::function<std::string()>& fn)
{
  int fds[2];
  if (pipe(fds) != 0)
    return "pipe failed";
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
      r = std::string("threw Standard_Failure: ")
          + (f.GetMessageString() ? f.GetMessageString() : "(none)");
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
    return std::string("CRASH signal ") + std::to_string(WTERMSIG(status)) + " ("
           + (WTERMSIG(status) == SIGSEGV ? "SIGSEGV" : WTERMSIG(status) == SIGBUS ? "SIGBUS" : "?")
           + ")";
  return out.empty() ? "(no output)" : out;
}

static std::string num(double v)
{
  char b[64];
  snprintf(b, sizeof b, "%g", v);
  return b;
}

// ---- fixtures and states ----------------------------------------------------------------------

// A 10 mm box. blendEdges[0] is the contour a state works on; blendEdges[1] is an edge sharing no
// vertex with it, so adding both gives two separate contours (the "second contour never simulated"
// state).
struct Fixture
{
  TopoDS_Shape                shape;
  TopTools_IndexedMapOfShape  edges;
  TopTools_IndexedMapOfShape  faces;
  std::vector<TopoDS_Edge>    blendEdges;
};

static Fixture boxFixture()
{
  Fixture f;
  f.shape = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopExp::MapShapes(f.shape, TopAbs_EDGE, f.edges);
  TopExp::MapShapes(f.shape, TopAbs_FACE, f.faces);
  const TopoDS_Edge first = TopoDS::Edge(f.edges(1));
  f.blendEdges.push_back(first);
  TopTools_IndexedMapOfShape firstVerts;
  TopExp::MapShapes(first, TopAbs_VERTEX, firstVerts);
  for (int i = 2; i <= f.edges.Extent(); ++i)
  {
    TopTools_IndexedMapOfShape v;
    TopExp::MapShapes(f.edges(i), TopAbs_VERTEX, v);
    bool shares = false;
    for (int j = 1; j <= v.Extent(); ++j)
      shares = shares || firstVerts.Contains(v(j));
    if (!shares)
    {
      f.blendEdges.push_back(TopoDS::Edge(f.edges(i)));
      break;
    }
  }
  return f;
}

enum State
{
  Fresh,              // constructed, nothing added
  AddedNotBuilt,      // one edge added, never Built, never Simulated
  Simulated,          // CONTROL: one edge added, Simulate(1) ran
  SimulatedThenReset, // Simulate(1), then Reset()
  SimulatedAgain,     // Simulate(1), Reset(), Simulate(1) again
  BuiltOk,            // built, radius 1 on one box edge
  BuiltThenReset,     // built, then Reset()
  SimulatedThenBuilt, // Simulate(1), then Build()
  BuiltThenSimulated, // Build(), then Simulate(1)
  DeclinedBuild,      // radius 20: Build() leaves IsDone() false
  SimulateDeclined,   // radius 20: Simulate(1) throws StartSol echec
  BuildNoContour,     // Build() with nothing added: throws "no suitable edges"
  TwoContoursSim1,    // two contours, only contour 1 Simulated
  TwoContoursNone     // two contours, nothing run
};

static const State kStates[] = {Fresh,          AddedNotBuilt,      Simulated,
                                SimulatedThenReset, SimulatedAgain, BuiltOk,
                                BuiltThenReset, SimulatedThenBuilt, BuiltThenSimulated,
                                DeclinedBuild,  SimulateDeclined,   BuildNoContour,
                                TwoContoursSim1, TwoContoursNone};

static const char* stateName(State s)
{
  switch (s)
  {
    case Fresh: return "fresh (no contour)";
    case AddedNotBuilt: return "edge added, never built, never simulated";
    case Simulated: return "CONTROL: edge added, Simulate(1)";
    case SimulatedThenReset: return "Simulate(1), then Reset()";
    case SimulatedAgain: return "Simulate(1), Reset(), Simulate(1)";
    case BuiltOk: return "built ok (radius 1)";
    case BuiltThenReset: return "built ok, then Reset()";
    case SimulatedThenBuilt: return "Simulate(1), then Build()";
    case BuiltThenSimulated: return "Build(), then Simulate(1)";
    case DeclinedBuild: return "declined build (radius 20)";
    case SimulateDeclined: return "Simulate(1) declined (radius 20, threw)";
    case BuildNoContour: return "Build() with no contour (threw)";
    case TwoContoursSim1: return "two contours, only contour 1 Simulate(1)'d";
    case TwoContoursNone: return "two contours, nothing run";
  }
  return "?";
}

// Both builders share the subset of the API the states use: Add(radius, edge), Build, Reset,
// Simulate(IC), IsDone, NbContours. The setup swallows Standard_Failure so a state that is declined
// by throwing still yields a builder in the state OCCT left it.
template <class Maker>
static std::string setup(State s, Maker& mk, const Fixture& fx)
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
  const TopoDS_Edge& e1 = fx.blendEdges[0];
  switch (s)
  {
    case Fresh: break;
    case AddedNotBuilt: mk.Add(1.0, e1); break;
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
    case TwoContoursSim1:
      mk.Add(1.0, e1);
      mk.Add(1.0, fx.blendEdges[1]);
      step([&] { mk.Simulate(1); });
      break;
    case TwoContoursNone:
      mk.Add(1.0, e1);
      mk.Add(1.0, fx.blendEdges[1]);
      break;
  }
  return note;
}

template <class Maker>
struct Case
{
  const char*                                   name;
  std::function<std::string(Maker&, Fixture&)> fn;
};

// Runs every case in every state, one forked child each, and returns name -> state -> result.
template <class Maker>
static std::map<std::string, std::map<int, std::string>> runMatrix(
  const char*                      title,
  const std::vector<Case<Maker>>&  cases)
{
  std::map<std::string, std::map<int, std::string>> table;
  printf("=== %s: one forked child per (state, accessor) ===\n", title);
  for (State s : kStates)
  {
    std::string head = runForked(
      [&]() -> std::string
      {
        Fixture fx = boxFixture();
        Maker   mk(fx.shape);
        std::string note = setup<Maker>(s, mk, fx);
        return "IsDone=" + num(mk.IsDone()) + " NbContours=" + num(mk.NbContours()) + " " + note;
      });
    printf("\n--- state: %s\n    %s\n", stateName(s), head.c_str());
    for (const Case<Maker>& c : cases)
    {
      std::string r = runForked(
        [&]() -> std::string
        {
          Fixture fx = boxFixture();
          Maker   mk(fx.shape);
          setup<Maker>(s, mk, fx);
          return c.fn(mk, fx);
        });
      table[c.name][(int)s] = r;
      printf("    %-34s %s\n", c.name, r.c_str());
    }
  }
  return table;
}

int main()
{
  // ---- the fillet ----------------------------------------------------------------------------
  std::vector<Case<BRepFilletAPI_MakeFillet>> fc = {
    {"NbSurf(1)", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbSurf(1)); }},
    {"NbSurf(2)", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbSurf(2)); }},
    {"NbSurf(0)", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbSurf(0)); }},
    {"NbSurf(99)", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbSurf(99)); }},
    {"NbComputedSurfaces(1)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbComputedSurfaces(1)); }},
    {"NbComputedSurfaces(2)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbComputedSurfaces(2)); }},
    {"NbComputedSurfaces(0)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbComputedSurfaces(0)); }},
    {"NbComputedSurfaces(99)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbComputedSurfaces(99)); }},
    {"Sect(1,1) [raw]",
     [](BRepFilletAPI_MakeFillet& m, Fixture&)
     {
       auto h = m.Sect(1, 1);
       return std::string(h.IsNull() ? "null" : "sections=" + num(h->Length()));
     }},
    {"Sect(2,1) [raw]",
     [](BRepFilletAPI_MakeFillet& m, Fixture&)
     {
       auto h = m.Sect(2, 1);
       return std::string(h.IsNull() ? "null" : "sections=" + num(h->Length()));
     }},
    {"Sect(1,1) if NbComputedSurfaces(1)>=1",
     [](BRepFilletAPI_MakeFillet& m, Fixture&)
     {
       if (m.NbComputedSurfaces(1) < 1)
         return std::string("(gated off)");
       auto h = m.Sect(1, 1);
       return std::string(h.IsNull() ? "null" : "sections=" + num(h->Length()));
     }},
    {"ComputedSurface(1,1) [raw]",
     [](BRepFilletAPI_MakeFillet& m, Fixture&)
     { return num(m.ComputedSurface(1, 1).IsNull() ? 0 : 1); }},
    {"Simulate(1) [as an operation]",
     [](BRepFilletAPI_MakeFillet& m, Fixture&)
     {
       m.Simulate(1);
       return std::string("returned");
     }},
    {"Simulate(2) [as an operation]",
     [](BRepFilletAPI_MakeFillet& m, Fixture&)
     {
       m.Simulate(2);
       return std::string("returned");
     }},
    {"Simulate(1); NbSurf(1)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&)
     {
       m.Simulate(1);
       return num(m.NbSurf(1));
     }},
    {"StripeStatus(1)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num((int)m.StripeStatus(1)); }},
  };
  auto ft = runMatrix<BRepFilletAPI_MakeFillet>("BRepFilletAPI_MakeFillet", fc);

  // ---- the chamfer: no NbComputedSurfaces or StripeStatus on this class --------------------
  std::vector<Case<BRepFilletAPI_MakeChamfer>> cc = {
    {"NbSurf(1)", [](BRepFilletAPI_MakeChamfer& m, Fixture&) { return num(m.NbSurf(1)); }},
    {"NbSurf(2)", [](BRepFilletAPI_MakeChamfer& m, Fixture&) { return num(m.NbSurf(2)); }},
    {"NbSurf(0)", [](BRepFilletAPI_MakeChamfer& m, Fixture&) { return num(m.NbSurf(0)); }},
    {"NbSurf(99)", [](BRepFilletAPI_MakeChamfer& m, Fixture&) { return num(m.NbSurf(99)); }},
    {"Sect(1,1) [raw]",
     [](BRepFilletAPI_MakeChamfer& m, Fixture&)
     {
       auto h = m.Sect(1, 1);
       return std::string(h.IsNull() ? "null" : "sections=" + num(h->Length()));
     }},
    {"Simulate(1) [as an operation]",
     [](BRepFilletAPI_MakeChamfer& m, Fixture&)
     {
       m.Simulate(1);
       return std::string("returned");
     }},
    {"Simulate(1); NbSurf(1)",
     [](BRepFilletAPI_MakeChamfer& m, Fixture&)
     {
       m.Simulate(1);
       return num(m.NbSurf(1));
     }},
  };
  printf("\n\n");
  runMatrix<BRepFilletAPI_MakeChamfer>("BRepFilletAPI_MakeChamfer", cc);

  // ---- the predicate check ---------------------------------------------------------------
  // The fix gates NbSurf(IC) on NbComputedSurfaces(IC) >= 1. That is sound exactly when, in every
  // state: where NbSurf faults, NbComputedSurfaces is 0; where NbSurf answers n, NbComputedSurfaces
  // answers the same n (so the gate never turns a real count into 0).
  printf("\n\n=== predicate check: NbSurf(IC) vs NbComputedSurfaces(IC), fillet ===\n");
  int bad = 0;
  for (const char* ic : {"1", "2"})
  {
    std::string nb = std::string("NbSurf(") + ic + ")";
    std::string cs = std::string("NbComputedSurfaces(") + ic + ")";
    for (State s : kStates)
    {
      const std::string& a = ft[nb][(int)s];
      const std::string& b = ft[cs][(int)s];
      bool               ok;
      if (a.rfind("CRASH", 0) == 0)
        ok = (b == "0");
      else
        ok = (a == b);
      printf("  %-4s %-46s NbSurf=%-22s NbComputedSurfaces=%-6s %s\n", ic, stateName(s), a.c_str(),
             b.c_str(), ok ? "agree" : "DISAGREE");
      bad += ok ? 0 : 1;
    }
  }
  printf("\npredicate check: %s (%d disagreements)\n", bad == 0 ? "PASS" : "FAIL", bad);
  return bad == 0 ? 0 : 1;
}
