// OCCTSwift#3518 ground truth: which BRepFilletAPI_MakeFillet / MakeChamfer accessors that take a
// contour index (IC), or an edge index within a contour (IinC, J), fault or answer garbage when the
// index is outside 1..NbContours() / 1..NbEdges(IC), and in which builder states.
//
// The mechanism, from Libraries/occt-src (ChFi3d_Builder_1.cxx, ChFi3d_FilBuilder.cxx):
//   - ChFi3d_Builder::Value(I) walks myListStripe I-1 times and dereferences the iterator. A loop
//     bound of `ic < I` means I <= 1 runs zero steps (0 and negatives alias contour 1), and an I
//     past the list steps off the end (a null node), and an empty list is dereferenced at once.
//   - NbEdges(I) and Edge(I, J) call Value(I) with no check at all.
//   - Length, FirstVertex, LastVertex, Abscissa, RelativeAbscissa, Closed, ClosedAndTangent and the
//     FilBuilder radius family check only `IC <= NbElements()`: the upper bound, never the lower.
//   - StripeStatus(IC) walks the stripe list and dereferences `st` whether or not it found one.
//   - Edge(I, J) then indexes the spine's edge sequence with J, and Standard_OutOfRange_Raise_if is
//     inert in this build, so J is not checked either.
//
// Every (state, accessor, index) triple runs in its own forked child, so a SIGSEGV is a recorded
// cell and not the end of the probe. OCC_CATCH_SIGNALS is inert in this build, so nothing
// in-process could absorb the signal; the parent reads it from waitpid.
//
// Compile (from the repo root, against the xcframework the package pins):
//   XC=.build/artifacts/<package>/OCCT/OCCT.xcframework      # or Libraries/OCCT.xcframework
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/3518/occt_3518_contour_index_matrix.mm -o /tmp/occt_3518
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <Law_Function.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Vertex.hxx>

#include <climits>
#include <cstdio>
#include <cstring>
#include <functional>
#include <memory>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

// ---- fork harness ---------------------------------------------------------------------------

// A case that does something and then reads back calls progress() between the two, so a fault in
// the readback is reported as "SEGV[did X]" and not as a fault in X.
static int         g_progressFd = -1;
static const char* g_filter     = nullptr; // optional argv[1]: run only accessors whose name contains it

static void progress(const char* what)
{
  if (g_progressFd >= 0)
    (void)!write(g_progressFd, what, strlen(what));
}

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
    g_progressFd = fds[1];
    std::string r;
    try
    {
      r = fn();
    }
    catch (Standard_Failure const& f)
    {
      // The first 24 characters tell the exceptions apart ("Spine is not constant", "StartSol
      // echec", "ChFiDS_FilSpine::ChangeLaw : ..."); the rest only bloats the table.
      std::string msg = f.GetMessageString() ? f.GetMessageString() : "(none)";
      r               = "threw:" + msg.substr(0, 24);
    }
    catch (...)
    {
      r = "threw?";
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
  {
    // SIGSEGV and SIGBUS are one outcome here: which of the two a wild address raises varies from
    // run to run (the same extreme index gave BUS in one run and SEGV in the next).
    std::string sig = (WTERMSIG(status) == SIGSEGV || WTERMSIG(status) == SIGBUS) ? "SEGV" : "SIG?";
    return out.empty() ? sig : sig + "[" + out + "]";
  }
  return out.empty() ? "(none)" : out;
}

static std::string num(double v)
{
  char b[64];
  snprintf(b, sizeof b, "%g", v);
  return b;
}

// ---- fixtures and states --------------------------------------------------------------------

struct Fixture
{
  TopoDS_Shape               shape;
  TopTools_IndexedMapOfShape edges;
};

static Fixture boxFixture()
{
  Fixture f;
  f.shape = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopExp::MapShapes(f.shape, TopAbs_EDGE, f.edges);
  return f;
}

enum State
{
  Fresh,            // constructed, nothing added
  AddedNotBuilt,    // one edge added, Build() never called: 1 contour of 1 edge
  TwoNotBuilt,      // two unrelated edges added, never built: 2 contours
  BuildNoContour,   // Build() with nothing added: throws "no suitable edges"
  Declined,         // one box edge, radius 20: Build() leaves IsDone() false
  BuiltOne,         // control: a build that completed, 1 contour
  BuiltTwo,         // a build that completed, 2 contours
  ResetAfterBuilt,  // completed, then Reset()
  ResetAfterDeclined // declined, then Reset()
};

static const State kStates[] = {Fresh,   AddedNotBuilt, TwoNotBuilt,     BuildNoContour,
                                Declined, BuiltOne,      BuiltTwo,        ResetAfterBuilt,
                                ResetAfterDeclined};

static const char* stateName(State s)
{
  switch (s)
  {
    case Fresh: return "fresh";
    case AddedNotBuilt: return "added, never built";
    case TwoNotBuilt: return "two contours, never built";
    case BuildNoContour: return "Build() with no contour";
    case Declined: return "declined (R 20)";
    case BuiltOne: return "built ok, 1 contour";
    case BuiltTwo: return "built ok, 2 contours";
    case ResetAfterBuilt: return "built ok, then Reset()";
    case ResetAfterDeclined: return "declined, then Reset()";
  }
  return "?";
}

// The second edge for the two-contour states: the first box edge that Add() puts in a contour of
// its own.
template <class Maker>
static void addSecondContour(Maker& mk, Fixture& fx, double r)
{
  for (int i = 2; i <= fx.edges.Extent(); ++i)
  {
    mk.Add(r, TopoDS::Edge(fx.edges(i)));
    if (mk.NbContours() == 2)
      return;
  }
}

static std::string fillerSetup(State s, std::unique_ptr<BRepFilletAPI_MakeFillet>& mk, Fixture& fx)
{
  fx = boxFixture();
  mk.reset(new BRepFilletAPI_MakeFillet(fx.shape));
  const TopoDS_Edge e1 = TopoDS::Edge(fx.edges(1));
  try
  {
    switch (s)
    {
      case Fresh: break;
      case AddedNotBuilt: mk->Add(1.0, e1); break;
      case TwoNotBuilt:
        mk->Add(1.0, e1);
        addSecondContour(*mk, fx, 1.0);
        break;
      case BuildNoContour: mk->Build(); break;
      case Declined:
        mk->Add(20.0, e1);
        mk->Build();
        break;
      case BuiltOne:
        mk->Add(1.0, e1);
        mk->Build();
        break;
      case BuiltTwo:
        mk->Add(1.0, e1);
        addSecondContour(*mk, fx, 1.0);
        mk->Build();
        break;
      case ResetAfterBuilt:
        mk->Add(1.0, e1);
        mk->Build();
        mk->Reset();
        break;
      case ResetAfterDeclined:
        mk->Add(20.0, e1);
        mk->Build();
        mk->Reset();
        break;
    }
  }
  catch (Standard_Failure const& f)
  {
    return std::string("[setup threw: ") + (f.GetMessageString() ? f.GetMessageString() : "") + "]";
  }
  return "";
}

static std::string chamferSetup(State s,
                                std::unique_ptr<BRepFilletAPI_MakeChamfer>& mk,
                                Fixture&                                    fx)
{
  fx = boxFixture();
  mk.reset(new BRepFilletAPI_MakeChamfer(fx.shape));
  const TopoDS_Edge e1 = TopoDS::Edge(fx.edges(1));
  try
  {
    switch (s)
    {
      case Fresh: break;
      case AddedNotBuilt: mk->Add(1.0, e1); break;
      case TwoNotBuilt:
        mk->Add(1.0, e1);
        addSecondContour(*mk, fx, 1.0);
        break;
      case BuildNoContour: mk->Build(); break;
      case Declined:
        mk->Add(20.0, e1);
        mk->Build();
        break;
      case BuiltOne:
        mk->Add(1.0, e1);
        mk->Build();
        break;
      case BuiltTwo:
        mk->Add(1.0, e1);
        addSecondContour(*mk, fx, 1.0);
        mk->Build();
        break;
      case ResetAfterBuilt:
        mk->Add(1.0, e1);
        mk->Build();
        mk->Reset();
        break;
      case ResetAfterDeclined:
        mk->Add(20.0, e1);
        mk->Build();
        mk->Reset();
        break;
    }
  }
  catch (Standard_Failure const& f)
  {
    return std::string("[setup threw: ") + (f.GetMessageString() ? f.GetMessageString() : "") + "]";
  }
  return "";
}

// ---- the matrix -----------------------------------------------------------------------------

struct Idx
{
  int         v;
  const char* label;
};
static const Idx kIdx[] = {{-1, "-1"},        {0, "0"},         {1, "1"},
                           {2, "2"},          {3, "3"},         {100000, "1e5"},
                           {INT_MAX, "MAX"},  {INT_MIN, "MIN"}};

template <class Maker>
struct Case
{
  const char*                                              name;
  std::function<std::string(Maker&, Fixture&, int)>        fn;
};

template <class Maker>
static void runMatrix(const char*                                                 title,
                      const std::vector<Case<Maker>>&                             cases,
                      std::function<std::string(State, std::unique_ptr<Maker>&, Fixture&)> setup)
{
  printf("=== %s: one forked child per (state, accessor, index) ===\n", title);
  printf("index columns: ");
  for (const Idx& i : kIdx)
    printf("%s ", i.label);
  printf("\n");
  for (const Case<Maker>& c : cases)
  {
    if (g_filter && !strstr(c.name, g_filter))
      continue;
    printf("\n## %s\n", c.name);
    for (State s : kStates)
    {
      std::string head = runForked(
        [&]() -> std::string
        {
          std::unique_ptr<Maker> mk;
          Fixture                fx;
          std::string            note = setup(s, mk, fx);
          return "nc=" + num(mk->NbContours()) + " done=" + num(mk->IsDone()) + note;
        });
      printf("  %-28s [%s]\n   ", stateName(s), head.c_str());
      for (const Idx& i : kIdx)
      {
        std::string r = runForked(
          [&]() -> std::string
          {
            std::unique_ptr<Maker> mk;
            Fixture                fx;
            setup(s, mk, fx);
            return c.fn(*mk, fx, i.v);
          });
        printf(" %s:%s", i.label, r.c_str());
      }
      printf("\n");
      fflush(stdout);
    }
  }
}

static std::string vtx(const TopoDS_Vertex& v)
{
  return v.IsNull() ? "null" : "vtx";
}

int main(int argc, char** argv)
{
  if (argc > 1)
    g_filter = argv[1];
  using M = BRepFilletAPI_MakeFillet;
  auto firstVertexOfEdge1 = [](Fixture& f)
  { return TopExp::FirstVertex(TopoDS::Edge(f.edges(1))); };

  std::vector<Case<M>> fillet = {
    // ---- reads that take a contour index
    {"NbEdges(IC)", [](M& m, Fixture&, int i) { return num(m.NbEdges(i)); }},
    {"StripeStatus(IC)", [](M& m, Fixture&, int i) { return num((int)m.StripeStatus(i)); }},
    {"NbComputedSurfaces(IC)", [](M& m, Fixture&, int i) { return num(m.NbComputedSurfaces(i)); }},
    {"Length(IC)", [](M& m, Fixture&, int i) { return num(m.Length(i)); }},
    {"Radius(IC)", [](M& m, Fixture&, int i) { return num(m.Radius(i)); }},
    {"IsConstant(IC)", [](M& m, Fixture&, int i) { return num(m.IsConstant(i)); }},
    {"Closed(IC)", [](M& m, Fixture&, int i) { return num(m.Closed(i)); }},
    {"ClosedAndTangent(IC)", [](M& m, Fixture&, int i) { return num(m.ClosedAndTangent(i)); }},
    {"FirstVertex(IC)", [](M& m, Fixture&, int i) { return vtx(m.FirstVertex(i)); }},
    {"LastVertex(IC)", [](M& m, Fixture&, int i) { return vtx(m.LastVertex(i)); }},
    {"Abscissa(IC, v)",
     [&](M& m, Fixture& f, int i) { return num(m.Abscissa(i, firstVertexOfEdge1(f))); }},
    {"RelativeAbscissa(IC, v)",
     [&](M& m, Fixture& f, int i) { return num(m.RelativeAbscissa(i, firstVertexOfEdge1(f))); }},
    {"NbSurf(IC) [sibling #3519]", [](M& m, Fixture&, int i) { return num(m.NbSurf(i)); }},
    {"GetBounds(IC, e1)",
     [](M& m, Fixture& f, int i)
     {
       double a = -7, b = -7;
       bool   ok = m.GetBounds(i, TopoDS::Edge(f.edges(1)), a, b);
       return num(ok) + "(" + num(a) + "," + num(b) + ")";
     }},
    {"GetLaw(IC, e1)",
     [](M& m, Fixture& f, int i)
     { return std::string(m.GetLaw(i, TopoDS::Edge(f.edges(1))).IsNull() ? "null" : "law"); }},
    // ---- reads that take an edge index within contour 1 (or a contour index and edge 1)
    {"Edge(IC, 1)", [](M& m, Fixture&, int i) { return std::string(m.Edge(i, 1).IsNull() ? "null" : "edge"); }},
    {"Edge(1, J)", [](M& m, Fixture&, int i) { return std::string(m.Edge(1, i).IsNull() ? "null" : "edge"); }},
    {"Edge(1, J).IsSame(Edge(1, 1))",
     [](M& m, Fixture&, int i)
     {
       const TopoDS_Edge& a = m.Edge(1, i);
       progress("got;");
       return std::string(a.IsNull() ? "null" : a.IsSame(m.Edge(1, 1)) ? "same-as-edge1" : "OTHER");
     }},
    // ---- fault indices (a different index domain, same kind of walk)
    {"FaultyContour(I)", [](M& m, Fixture&, int i) { return num(m.FaultyContour(i)); }},
    {"FaultyVertex(I)", [](M& m, Fixture&, int i) { return vtx(m.FaultyVertex(i)); }},
    // ---- writes: report what contour 1 reads afterwards, to catch a write that aliased to it
    {"SetRadius(7, IC, edge1); Radius(1)",
     [](M& m, Fixture& f, int i)
     {
       m.SetRadius(7.0, i, TopoDS::Edge(f.edges(1)));
       progress("set;");
       return "Radius(1)=" + num(m.Radius(1));
     }},
    {"SetRadius(7, IC, vertex1); Radius(1)",
     [&](M& m, Fixture& f, int i)
     {
       m.SetRadius(7.0, i, firstVertexOfEdge1(f));
       progress("set;");
       return "Radius(1)=" + num(m.Radius(1));
     }},
    {"SetRadius(7, 9, 1, J); IsConstant(1)",
     [](M& m, Fixture&, int i)
     {
       m.SetRadius(7.0, 9.0, 1, i);
       progress("set;");
       return "IsConstant(1)=" + num(m.IsConstant(1));
     }},
    {"SetRadius(7, 9, IC, 1); Radius(1)",
     [](M& m, Fixture&, int i)
     {
       m.SetRadius(7.0, 9.0, i, 1);
       progress("set;");
       return "Radius(1)=" + num(m.Radius(1));
     }},
    {"ResetContour(IC); Radius(1)",
     [](M& m, Fixture&, int i)
     {
       m.ResetContour(i);
       progress("set;");
       return "Radius(1)=" + num(m.Radius(1));
     }},
    {"Simulate(IC); NbComputedSurfaces(1)",
     [](M& m, Fixture&, int i)
     {
       m.Simulate(i);
       progress("sim;");
       return "ncs(1)=" + num(m.NbComputedSurfaces(1));
     }},
  };
  runMatrix<M>("BRepFilletAPI_MakeFillet", fillet, fillerSetup);

  using C = BRepFilletAPI_MakeChamfer;
  std::vector<Case<C>> chamfer = {
    {"NbEdges(IC)", [](C& m, Fixture&, int i) { return num(m.NbEdges(i)); }},
    {"Length(IC)", [](C& m, Fixture&, int i) { return num(m.Length(i)); }},
    {"Closed(IC)", [](C& m, Fixture&, int i) { return num(m.Closed(i)); }},
    {"ClosedAndTangent(IC)", [](C& m, Fixture&, int i) { return num(m.ClosedAndTangent(i)); }},
    {"FirstVertex(IC)", [](C& m, Fixture&, int i) { return vtx(m.FirstVertex(i)); }},
    {"LastVertex(IC)", [](C& m, Fixture&, int i) { return vtx(m.LastVertex(i)); }},
    {"Abscissa(IC, v)",
     [&](C& m, Fixture& f, int i) { return num(m.Abscissa(i, firstVertexOfEdge1(f))); }},
    {"RelativeAbscissa(IC, v)",
     [&](C& m, Fixture& f, int i) { return num(m.RelativeAbscissa(i, firstVertexOfEdge1(f))); }},
    {"Edge(IC, 1)", [](C& m, Fixture&, int i) { return std::string(m.Edge(i, 1).IsNull() ? "null" : "edge"); }},
    {"Edge(1, J)", [](C& m, Fixture&, int i) { return std::string(m.Edge(1, i).IsNull() ? "null" : "edge"); }},
    {"IsTwoDistances(IC)", [](C& m, Fixture&, int i) { return num(m.IsTwoDistances(i)); }},
    {"IsDistanceAngle(IC)", [](C& m, Fixture&, int i) { return num(m.IsDistanceAngle(i)); }},
    {"GetDist(IC)",
     [](C& m, Fixture&, int i)
     {
       double d = -7;
       m.GetDist(i, d);
       return num(d);
     }},
    {"Dists(IC)",
     [](C& m, Fixture&, int i)
     {
       double d1 = -7, d2 = -7;
       m.Dists(i, d1, d2);
       return num(d1) + "," + num(d2);
     }},
    {"GetDistAngle(IC)",
     [](C& m, Fixture&, int i)
     {
       double d = -7, a = -7;
       m.GetDistAngle(i, d, a);
       return num(d) + "," + num(a);
     }},
    {"NbSurf(IC) [sibling #3519 class]", [](C& m, Fixture&, int i) { return num(m.NbSurf(i)); }},
    {"Simulate(IC); NbSurf(1)",
     [](C& m, Fixture&, int i)
     {
       m.Simulate(i);
       progress("sim;");
       return "nbsurf(1)=" + num(m.NbSurf(1));
     }},
    {"ResetContour(IC); GetDist(1)",
     [](C& m, Fixture&, int i)
     {
       m.ResetContour(i);
       progress("set;");
       double d = -7;
       m.GetDist(1, d);
       return "GetDist(1)=" + num(d);
     }},
  };
  runMatrix<C>("BRepFilletAPI_MakeChamfer", chamfer, chamferSetup);
  return 0;
}
