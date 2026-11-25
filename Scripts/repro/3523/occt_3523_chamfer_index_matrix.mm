// OCCTSwift#3523 ground truth: which BRepFilletAPI_MakeChamfer accessors that take a contour index
// (IC), or an edge index within a contour (J), fault or answer garbage when the index is outside
// 1..NbContours() / 1..NbEdges(IC), and in which builder states.
//
// Scripts/repro/3518/occt_3518_contour_index_matrix.mm measured thirteen of them. This one measures
// every contour-indexed function the OCCTSwift ChamferBuilder wraps (twenty), because the three
// setters (SetDist, SetDists, SetDistAngle) and IsSymetric were not in that matrix, and it runs
// against the kernel the package pins now (OCCT V8_0_2 plus the carried patches).
//
// The mechanism, from Libraries/occt-src (ChFi3d_Builder_1.cxx, ChFi3d_ChBuilder.cxx,
// BRepFilletAPI_MakeChamfer.cxx):
//   - ChFi3d_Builder::Value(I) walks myListStripe I-1 times and dereferences the iterator it ends
//     on: I <= 1 runs no steps (0 and the negatives answer contour 1), I past the list steps onto
//     a null node, and an empty list is dereferenced at once.
//   - MakeChamfer::NbEdges and ::Edge call Value(I) with no test. GetDist, Dists, GetDistAngle and
//     IsChamfer (behind IsSymetric, IsTwoDistances, IsDistanceAngle) do too, through a down_cast
//     they never test.
//   - Length, FirstVertex, LastVertex, Abscissa, RelativeAbscissa, Closed, ClosedAndTangent,
//     SetDist, SetDists, SetDistAngle and ResetContour test only `IC <= NbElements()`: the upper
//     bound, never the lower.
//   - Edge(I, J) then indexes the spine's edge sequence with J, and the range check is compiled
//     out of this build, so J is not checked either.
//
// Every (state, accessor, index) triple runs in its own forked child, so a SIGSEGV is a recorded
// cell and not the end of the probe. OCC_CATCH_SIGNALS is inert in this build, so nothing in-process
// could absorb the signal; the parent reads it from waitpid.
//
// Compile (from the repo root, against the xcframework the package pins):
//   XC=Libraries/OCCT.xcframework      # or .build/artifacts/<package>/OCCT/OCCT.xcframework
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/3523/occt_3523_chamfer_index_matrix.mm -o /tmp/occt_3523
//   /tmp/occt_3523 > Scripts/repro/3523/probe-output.txt
//   /tmp/occt_3523 SetDist       # only the accessors whose name contains the argument
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
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
static const char* g_filter     = nullptr;

static void progress(const char* what)
{
  if (g_progressFd >= 0)
    (void)!write(g_progressFd, what, strlen(what));
}

static std::string runForked(const std::function<std::string()>& fn)
{
  int fds[2], pfds[2];
  if (pipe(fds) != 0 || pipe(pfds) != 0)
    return "pipe failed";
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    close(fds[0]);
    close(pfds[0]);
    g_progressFd = pfds[1];
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
  close(pfds[1]);
  std::string out, prog;
  char        buf[256];
  ssize_t     n;
  while ((n = read(fds[0], buf, sizeof buf)) > 0)
    out.append(buf, (size_t)n);
  while ((n = read(pfds[0], buf, sizeof buf)) > 0)
    prog.append(buf, (size_t)n);
  close(fds[0]);
  close(pfds[0]);
  int status = 0;
  waitpid(pid, &status, 0);
  if (WIFSIGNALED(status))
  {
    // SIGSEGV and SIGBUS are one outcome here: which of the two a wild address raises varies from
    // run to run.
    std::string sig = (WTERMSIG(status) == SIGSEGV || WTERMSIG(status) == SIGBUS) ? "SEGV" : "SIG?";
    return prog.empty() ? sig : sig + "[" + prog + "]";
  }
  return prog + (out.empty() ? "(none)" : out);
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
  TopoDS_Shape                shape;
  TopTools_IndexedMapOfShape  edges;
  TopoDS_Face                 faceOfEdge1; // a face edge 1 lies on, for the face-taking setters
};

static Fixture boxFixture()
{
  Fixture f;
  f.shape = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopExp::MapShapes(f.shape, TopAbs_EDGE, f.edges);
  TopTools_IndexedDataMapOfShapeListOfShape ancestors;
  TopExp::MapShapesAndAncestors(f.shape, TopAbs_EDGE, TopAbs_FACE, ancestors);
  f.faceOfEdge1 = TopoDS::Face(ancestors.FindFromKey(f.edges(1)).First());
  return f;
}

enum State
{
  Fresh,              // constructed, nothing added
  AddedNotBuilt,      // one edge added, Build() never called: 1 contour of 1 edge
  TwoNotBuilt,        // two unrelated edges added, never built: 2 contours
  BuildNoContour,     // Build() with nothing added: throws "no suitable edges"
  Declined,           // one box edge, distance 20: Build() leaves IsDone() false
  BuiltOne,           // control: a build that completed, 1 contour
  BuiltTwo,           // a build that completed, 2 contours
  ResetAfterBuilt,    // completed, then Reset()
  ResetAfterDeclined  // declined, then Reset()
};

static const State kStates[] = {Fresh,    AddedNotBuilt, TwoNotBuilt, BuildNoContour, Declined,
                                BuiltOne, BuiltTwo,      ResetAfterBuilt, ResetAfterDeclined};

static const char* stateName(State s)
{
  switch (s)
  {
    case Fresh: return "fresh";
    case AddedNotBuilt: return "added, never built";
    case TwoNotBuilt: return "two contours, never built";
    case BuildNoContour: return "Build() with no contour";
    case Declined: return "declined (d 20)";
    case BuiltOne: return "built ok, 1 contour";
    case BuiltTwo: return "built ok, 2 contours";
    case ResetAfterBuilt: return "built ok, then Reset()";
    case ResetAfterDeclined: return "declined, then Reset()";
  }
  return "?";
}

// The second edge for the two-contour states: the first box edge that Add() puts in a contour of
// its own.
static void addSecondContour(BRepFilletAPI_MakeChamfer& mk, Fixture& fx, double d)
{
  for (int i = 2; i <= fx.edges.Extent(); ++i)
  {
    mk.Add(d, TopoDS::Edge(fx.edges(i)));
    if (mk.NbContours() == 2)
      return;
  }
}

static std::string chamferSetup(State s, std::unique_ptr<BRepFilletAPI_MakeChamfer>& mk, Fixture& fx)
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
static const Idx kIdx[] = {{-1, "-1"},       {0, "0"},         {1, "1"},         {2, "2"},
                           {3, "3"},         {100000, "1e5"},  {INT_MAX, "MAX"}, {INT_MIN, "MIN"}};

using C = BRepFilletAPI_MakeChamfer;

struct Case
{
  const char*                                       name;
  std::function<std::string(C&, Fixture&, int)>     fn;
};

static std::string vtx(const TopoDS_Vertex& v)
{
  return v.IsNull() ? "null" : "vtx";
}

static void runMatrix(const std::vector<Case>& cases)
{
  printf("=== BRepFilletAPI_MakeChamfer: one forked child per (state, accessor, index) ===\n");
  printf("index columns: ");
  for (const Idx& i : kIdx)
    printf("%s ", i.label);
  printf("\n");
  for (const Case& c : cases)
  {
    if (g_filter && !strstr(c.name, g_filter))
      continue;
    printf("\n## %s\n", c.name);
    for (State s : kStates)
    {
      std::string head = runForked(
        [&]() -> std::string
        {
          std::unique_ptr<C> mk;
          Fixture            fx;
          std::string        note = chamferSetup(s, mk, fx);
          return "nc=" + num(mk->NbContours()) + " done=" + num(mk->IsDone()) + note;
        });
      printf("  %-28s [%s]\n   ", stateName(s), head.c_str());
      for (const Idx& i : kIdx)
      {
        std::string r = runForked(
          [&]() -> std::string
          {
            std::unique_ptr<C> mk;
            Fixture            fx;
            chamferSetup(s, mk, fx);
            return c.fn(*mk, fx, i.v);
          });
        printf(" %s:%s", i.label, r.c_str());
      }
      printf("\n");
      fflush(stdout);
    }
  }
}

int main(int argc, char** argv)
{
  if (argc > 1)
    g_filter = argv[1];
  auto firstVertexOfEdge1 = [](Fixture& f)
  { return TopExp::FirstVertex(TopoDS::Edge(f.edges(1))); };

  std::vector<Case> chamfer = {
    // ---- reads that take a contour index
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
    {"IsSymetric(IC)", [](C& m, Fixture&, int i) { return num(m.IsSymetric(i)); }},
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
    // ---- reads that take an edge index within a contour (or a contour index and edge 1)
    {"Edge(IC, 1)",
     [](C& m, Fixture&, int i) { return std::string(m.Edge(i, 1).IsNull() ? "null" : "edge"); }},
    {"Edge(1, J)",
     [](C& m, Fixture&, int i) { return std::string(m.Edge(1, i).IsNull() ? "null" : "edge"); }},
    // ---- writes: report what contour 1 reads afterwards, to catch a write that aliased to it
    {"SetDist(7, IC, face); GetDist(1)",
     [](C& m, Fixture& f, int i)
     {
       m.SetDist(7.0, i, f.faceOfEdge1);
       progress("set;");
       double d = -7;
       m.GetDist(1, d);
       return "GetDist(1)=" + num(d);
     }},
    {"SetDists(7, 9, IC, face); Dists(1)",
     [](C& m, Fixture& f, int i)
     {
       m.SetDists(7.0, 9.0, i, f.faceOfEdge1);
       progress("set;");
       double d1 = -7, d2 = -7;
       m.Dists(1, d1, d2);
       return "Dists(1)=" + num(d1) + "," + num(d2);
     }},
    {"SetDistAngle(7, 0.5, IC, face); GetDistAngle(1)",
     [](C& m, Fixture& f, int i)
     {
       m.SetDistAngle(7.0, 0.5, i, f.faceOfEdge1);
       progress("set;");
       double d = -7, a = -7;
       m.GetDistAngle(1, d, a);
       return "GetDistAngle(1)=" + num(d) + "," + num(a);
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
    // ---- the surface-data pair: the sibling defect (#3522), measured here for completeness
    {"NbSurf(IC) [sibling #3522]", [](C& m, Fixture&, int i) { return num(m.NbSurf(i)); }},
    {"Simulate(IC); NbSurf(1) [sibling #3522]",
     [](C& m, Fixture&, int i)
     {
       m.Simulate(i);
       progress("sim;");
       return "nbsurf(1)=" + num(m.NbSurf(1));
     }},
  };
  runMatrix(chamfer);
  return 0;
}
