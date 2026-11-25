// OCCTSwift#3524 ground truth: in which builder states do the two BRepFilletAPI_MakeFillet setters
// that go through ChFiDS_FilSpine::SetRadius(UandR, IinC) fault with a VALID contour and edge index,
// and does "after IsDone()" cover all of them.
//
// The mechanism, from Libraries/occt-src (ChFiDS_FilSpine.cxx:164-215):
//   SetRadius(gp_XY UandR, int IinC) inserts the (abscissa, radius) pair and then, `if (splitdone)`,
//   replays the law: it reads `elspines.First()` through an iterator with no emptiness test. That
//   list is empty whenever the spine was split into no elementary spines, so with splitdone true and
//   elspines empty the read is a null dereference.
//   - SetRadius(R, IC, vertex)          -> FilSpine::SetRadius(R, V)   -> SetRadius(UandR, 0)
//   - SetRadius(R1, R2, IC, IinC)       -> FilSpine::SetRadius(UandR, IinC), twice
//   - SetRadius(R, IC, edge)            -> FilSpine::SetRadius(R, E), which sets splitdone = false
//                                          first, so it never reaches the replay (the control)
//
// Which states have splitdone true: ChFiDS_Spine::SplitDone(true) is set at the end of
// ChFi3d_Builder::PerformSetOfKPart (ChFi3d_Builder_2.cxx:3351), which Build() runs on every stripe
// and Simulate(IC) runs on one. ChFiDS_Spine::Reset() clears it, and ChFi3d_Builder::Reset() runs
// that on every stripe. So "after IsDone()" (Build completed) is one way to get there and a
// Simulate(IC) with no Build is another, which is why this probe walks both.
//
// Three fixtures, because elspines is empty for an analytic (KPart) blend and not for a general one:
//   box     a plane-plane edge (KPart)
//   cyl     the circular edge between a cylinder's side and its top (KPart, closed)
//   spline  the edge between a plane and a surface of linear extrusion over a BSpline (general)
//
// Every (fixture, state, case) triple runs in its own forked child, so a SIGSEGV is a recorded cell
// and not the end of the probe. OCC_CATCH_SIGNALS is inert in this build, so nothing in-process
// could absorb the signal; the parent reads it from waitpid.
//
// Compile (from the repo root, against the xcframework the package pins):
//   XC=Libraries/OCCT.xcframework      # or .build/artifacts/<package>/OCCT/OCCT.xcframework
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/3524/occt_3524_setradius_after_build.mm -o /tmp/occt_3524
//   /tmp/occt_3524 > Scripts/repro/3524/probe-output.txt
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRep_Tool.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <NCollection_Array1.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <cstdio>
#include <cstring>
#include <functional>
#include <memory>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

// ---- fork harness ---------------------------------------------------------------------------

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

static std::string num(double v)
{
  char b[64];
  snprintf(b, sizeof b, "%g", v);
  return b;
}

// ---- fixtures -------------------------------------------------------------------------------

struct Fixture
{
  const char*                 name;
  TopoDS_Shape                shape;
  TopTools_IndexedMapOfShape  edges;
  TopoDS_Edge                 blendEdge;   // the edge a state fillets
  TopoDS_Edge                 secondEdge;  // an edge that opens a contour of its own, or null
  double                      radius = 1.0; // a radius the fixture builds at
};

static void finish(Fixture& f)
{
  TopExp::MapShapes(f.shape, TopAbs_EDGE, f.edges);
}

static Fixture boxFixture()
{
  Fixture f;
  f.name  = "box";
  f.shape = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  finish(f);
  f.blendEdge = TopoDS::Edge(f.edges(1));
  {
    BRepFilletAPI_MakeFillet probe(f.shape);
    probe.Add(1.0, f.blendEdge);
    for (int i = 2; i <= f.edges.Extent(); ++i)
    {
      probe.Add(1.0, TopoDS::Edge(f.edges(i)));
      if (probe.NbContours() == 2)
      {
        f.secondEdge = TopoDS::Edge(f.edges(i));
        break;
      }
    }
  }
  return f;
}

static Fixture cylFixture()
{
  Fixture f;
  f.name  = "cyl";
  f.shape = BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape();
  finish(f);
  for (int i = 1; i <= f.edges.Extent(); ++i)
  {
    BRepAdaptor_Curve c(TopoDS::Edge(f.edges(i)));
    if (c.GetType() == GeomAbs_Circle && std::abs(c.Value(c.FirstParameter()).Z() - 10.0) < 1e-9)
    {
      f.blendEdge = TopoDS::Edge(f.edges(i));
      break;
    }
  }
  return f;
}

static Fixture splineFixture()
{
  Fixture f;
  f.name   = "spline";
  f.radius = 0.3;
  NCollection_Array1<gp_Pnt> pts(1, 5);
  pts(1) = gp_Pnt(0, 0, 0);
  pts(2) = gp_Pnt(3, 1, 0);
  pts(3) = gp_Pnt(6, -0.5, 0);
  pts(4) = gp_Pnt(8, 0.8, 0);
  pts(5) = gp_Pnt(10, 0, 0);
  GeomAPI_PointsToBSpline    fit(pts);
  TopoDS_Edge                curved = BRepBuilderAPI_MakeEdge(fit.Curve());
  TopoDS_Edge                closing = BRepBuilderAPI_MakeEdge(gp_Pnt(10, 0, 0), gp_Pnt(0, 0, 0));
  BRepBuilderAPI_MakeWire    wire(curved, closing);
  TopoDS_Face                face = BRepBuilderAPI_MakeFace(wire.Wire());
  f.shape                         = BRepPrimAPI_MakePrism(face, gp_Vec(0, 0, 5)).Shape();
  finish(f);
  for (int i = 1; i <= f.edges.Extent(); ++i)
  {
    BRepAdaptor_Curve c(TopoDS::Edge(f.edges(i)));
    if (c.GetType() == GeomAbs_BSplineCurve && std::abs(c.Value(c.FirstParameter()).Z() - 5.0) < 1e-9)
    {
      f.blendEdge = TopoDS::Edge(f.edges(i));
      break;
    }
  }
  return f;
}

// ---- states ---------------------------------------------------------------------------------

enum State
{
  AddedNotRun,        // one edge added, nothing run: splitdone false
  Simulated,          // Simulate(1): splitdone true, IsDone() false
  SimulatedThenReset, // Simulate(1) then Reset()
  Built,              // Build() completed: IsDone() true
  BuiltThenReset,     // Build() completed, then Reset()
  BuiltThenEdgeForm,  // Build() completed, then SetRadius(R, 1, edge), which clears splitdone
  Declined,           // radius 20: Build() leaves IsDone() false
  TwoBuilt,           // two contours, Build() completed
  TwoSimulatedFirst,  // two contours, only Simulate(1): contour 1 split, contour 2 not
  TwoSecondDeclined   // two contours, the second at radius 20: Build() leaves IsDone() false
};

static const State kStates[] = {AddedNotRun, Simulated, SimulatedThenReset, Built, BuiltThenReset,
                                BuiltThenEdgeForm, Declined, TwoBuilt, TwoSimulatedFirst,
                                TwoSecondDeclined};

static const char* stateName(State s)
{
  switch (s)
  {
    case AddedNotRun: return "added, nothing run";
    case Simulated: return "Simulate(1)";
    case SimulatedThenReset: return "Simulate(1), Reset()";
    case Built: return "Build() completed";
    case BuiltThenReset: return "Build() completed, Reset()";
    case BuiltThenEdgeForm: return "Build() completed, SetRadius(R,1,edge)";
    case Declined: return "declined (R 20)";
    case TwoBuilt: return "two contours, Build() completed";
    case TwoSimulatedFirst: return "two contours, only Simulate(1)";
    case TwoSecondDeclined: return "two contours, 2nd declined (R 20)";
  }
  return "?";
}

static bool needsSecond(State s)
{
  return s == TwoBuilt || s == TwoSimulatedFirst || s == TwoSecondDeclined;
}

static std::string setup(State s, Fixture& fx, std::unique_ptr<BRepFilletAPI_MakeFillet>& mk)
{
  mk.reset(new BRepFilletAPI_MakeFillet(fx.shape));
  try
  {
    const double r = (s == Declined) ? 20.0 : fx.radius;
    mk->Add(r, fx.blendEdge);
    if (needsSecond(s))
      mk->Add(s == TwoSecondDeclined ? 20.0 : r, fx.secondEdge);
    switch (s)
    {
      case AddedNotRun: break;
      case Simulated: mk->Simulate(1); break;
      case SimulatedThenReset:
        mk->Simulate(1);
        mk->Reset();
        break;
      case Built: mk->Build(); break;
      case BuiltThenReset:
        mk->Build();
        mk->Reset();
        break;
      case BuiltThenEdgeForm:
        mk->Build();
        mk->SetRadius(2.0, 1, fx.blendEdge);
        break;
      case Declined: mk->Build(); break;
      case TwoBuilt: mk->Build(); break;
      case TwoSimulatedFirst: mk->Simulate(1); break;
      case TwoSecondDeclined: mk->Build(); break;
    }
  }
  catch (Standard_Failure const& f)
  {
    return std::string("[setup threw: ") + (f.GetMessageString() ? f.GetMessageString() : "") + "]";
  }
  return "";
}

// ---- cases ----------------------------------------------------------------------------------

using M = BRepFilletAPI_MakeFillet;

struct Case
{
  const char*                                          name;
  std::function<std::string(M&, Fixture&, int)>        fn;
};

int main()
{
  std::vector<Fixture> fixtures = {boxFixture(), cylFixture(), splineFixture()};

  // Each case takes the contour (1 or 2) and applies one setter at it; the result is the setter's
  // outcome ("ok" or what it threw) so a fault stands out as SEGV.
  std::vector<Case> cases = {
    {"SetRadius(5, IC, vertex)",
     [](M& m, Fixture& f, int ic)
     {
       m.SetRadius(5.0, ic, TopExp::FirstVertex(m.NbContours() >= ic ? m.Edge(ic, 1) : f.blendEdge));
       return std::string("ok");
     }},
    {"SetRadius(5, 9, IC, 1)",
     [](M& m, Fixture&, int ic)
     {
       m.SetRadius(5.0, 9.0, ic, 1);
       return std::string("ok");
     }},
    {"Add(5, edge already in the contour)",
     [](M& m, Fixture& f, int ic)
     {
       m.Add(5.0, ic == 2 ? f.secondEdge : f.blendEdge);
       return std::string("ok");
     }},
    {"Add(5, 9, edge already in the contour)",
     [](M& m, Fixture& f, int ic)
     {
       m.Add(5.0, 9.0, ic == 2 ? f.secondEdge : f.blendEdge);
       return std::string("ok");
     }},
    {"SetRadius(5, IC, edge) [control]",
     [](M& m, Fixture& f, int ic)
     {
       m.SetRadius(5.0, ic, m.NbContours() >= ic ? m.Edge(ic, 1) : f.blendEdge);
       return std::string("ok");
     }},
  };

  printf("=== BRepFilletAPI_MakeFillet setters at a valid contour and edge index ===\n");
  for (Fixture& fx : fixtures)
  {
    printf("\n##### fixture: %s\n", fx.name);
    for (const Case& c : cases)
    {
      printf("\n## %s\n", c.name);
      for (State s : kStates)
      {
        if (needsSecond(s) && fx.secondEdge.IsNull())
        {
          printf("  %-40s [n/a: the fixture has no second contour]\n", stateName(s));
          continue;
        }
        std::string head = runForked(
          [&]() -> std::string
          {
            std::unique_ptr<M> mk;
            std::string        note = setup(s, fx, mk);
            return "nc=" + num(mk->NbContours()) + " done=" + num(mk->IsDone()) + note;
          });
        printf("  %-40s [%s]", stateName(s), head.c_str());
        for (int ic = 1; ic <= (needsSecond(s) ? 2 : 1); ++ic)
        {
          std::string r = runForked(
            [&]() -> std::string
            {
              std::unique_ptr<M> mk;
              setup(s, fx, mk);
              return c.fn(*mk, fx, ic);
            });
          printf("  IC=%d:%s", ic, r.c_str());
        }
        printf("\n");
        fflush(stdout);
      }
    }
  }
  return 0;
}
