// #1008: what TopoDS::Edge actually does with a non-edge, against the pinned kernel.
//
// OCCTMakeWireFromEdges (OCCTBridge_Topology.mm) casts every caller-supplied shape with
// TopoDS::Edge and no ShapeType() test. TopoDS::Edge's own guard is a macro,
// Standard_TypeMismatch_Raise_if, and Standard_TypeMismatch.hxx gates that macro on
// `#if !defined No_Exception && !defined No_Standard_TypeMismatch`. The macro expands in the
// CALLER's translation unit, so whether the guard exists at all is a property of how the bridge is
// compiled, not of how the kernel archive was built.
//
// This probe reports the macro state it was compiled under, then runs the unfixed loop body and the
// fixed one over six inputs, each in a forked child so a crash in one case does not stop the rest.
// A child that dies on a signal is reported with that signal rather than swallowed.

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRep_Builder.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <cstring>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

// The bridge's own guarded spelling, transcribed from OCCTBridge_Internal.h's occtEdgeAt(shape, 0)
// reduced to the "is this shape itself an edge" question this call site asks.
static TopoDS_Edge guardedEdge(const TopoDS_Shape& shape)
{
  if (shape.IsNull() || shape.ShapeType() != TopAbs_EDGE)
    return TopoDS_Edge();
  return TopoDS::Edge(shape);
}

struct Fixture
{
  std::string  name;
  TopoDS_Shape shape;
};

static std::vector<Fixture> buildFixtures()
{
  std::vector<Fixture> out;

  TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge();
  out.push_back({"edge (the supported input)", edge});

  BRepBuilderAPI_MakePolygon poly(gp_Pnt(0, 0, 0),
                                  gp_Pnt(10, 0, 0),
                                  gp_Pnt(10, 10, 0),
                                  gp_Pnt(0, 10, 0));
  poly.Close();
  TopoDS_Wire wire = poly.Wire();
  out.push_back({"wire (4 edges)", wire});

  TopoDS_Face face = BRepBuilderAPI_MakeFace(wire).Face();
  out.push_back({"face", face});

  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  out.push_back({"solid (box)", box});

  TopoDS_Vertex vertex = BRepBuilderAPI_MakeVertex(gp_Pnt(1, 2, 3)).Vertex();
  out.push_back({"vertex", vertex});

  BRep_Builder     builder;
  TopoDS_Compound  compound;
  builder.MakeCompound(compound);
  builder.Add(compound, edge);
  out.push_back({"compound holding one edge", compound});

  // TopoDS::Edge's guard reads `theShape.IsNull() ? false : ...`, so a NULL shape is passed through
  // with no check at all, on every build. Whether that matters is a question about what
  // BRepBuilderAPI_MakeWire::Add does with a null edge, measured rather than assumed.
  out.push_back({"null shape", TopoDS_Shape()});

  return out;
}

// The unfixed body of OCCTMakeWireFromEdges, for one element.
static void runUnfixed(const TopoDS_Shape& shape)
{
  try
  {
    BRepBuilderAPI_MakeWire mw;
    mw.Add(TopoDS::Edge(shape));
    if (!mw.IsDone())
    {
      std::printf("      not done, bridge would return nullptr\n");
      return;
    }
    TopoDS_Wire w        = mw.Wire();
    int         edgeCount = 0;
    for (TopExp_Explorer exp(w, TopAbs_EDGE); exp.More(); exp.Next())
      edgeCount++;
    std::printf("      ACCEPTED, wire with %d edge(s)\n", edgeCount);
  }
  catch (Standard_Failure const& f)
  {
    std::printf("      REFUSED by Standard_Failure: %s\n", f.GetMessageString());
  }
  catch (...)
  {
    std::printf("      REFUSED by an unknown C++ exception\n");
  }
}

// The fixed body: refuse the whole call when any element is not an edge.
static void runFixed(const TopoDS_Shape& shape)
{
  try
  {
    BRepBuilderAPI_MakeWire mw;
    TopoDS_Edge             e = guardedEdge(shape);
    if (e.IsNull())
    {
      std::printf("      REFUSED by the guard, bridge returns nullptr\n");
      return;
    }
    mw.Add(e);
    if (!mw.IsDone())
    {
      std::printf("      not done, bridge would return nullptr\n");
      return;
    }
    TopoDS_Wire w        = mw.Wire();
    int         edgeCount = 0;
    for (TopExp_Explorer exp(w, TopAbs_EDGE); exp.More(); exp.Next())
      edgeCount++;
    std::printf("      ACCEPTED, wire with %d edge(s)\n", edgeCount);
  }
  catch (Standard_Failure const& f)
  {
    std::printf("      REFUSED by Standard_Failure: %s\n", f.GetMessageString());
  }
  catch (...)
  {
    std::printf("      REFUSED by an unknown C++ exception\n");
  }
}

// Runs `body` in a forked child so a SIGSEGV or SIGABRT is reported rather than ending the probe.
// Returns true when the child exited normally.
static bool runIsolated(void (*body)(const TopoDS_Shape&), const TopoDS_Shape& shape)
{
  std::fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    body(shape);
    std::fflush(stdout);
    _exit(0);
  }
  int status = 0;
  waitpid(pid, &status, 0);
  if (WIFSIGNALED(status))
  {
    std::printf("      CRASHED on signal %d (%s)\n", WTERMSIG(status), strsignal(WTERMSIG(status)));
    return false;
  }
  return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

int main()
{
  std::printf("=== #1008: TopoDS::Edge on a non-edge, pinned kernel ===\n\n");

  std::printf("Compile-time macro state in THIS translation unit:\n");
#if defined No_Exception
  std::printf("  No_Exception                DEFINED\n");
#else
  std::printf("  No_Exception                not defined\n");
#endif
#if defined No_Standard_TypeMismatch
  std::printf("  No_Standard_TypeMismatch    DEFINED\n");
#else
  std::printf("  No_Standard_TypeMismatch    not defined\n");
#endif
#if defined No_Exception || defined No_Standard_TypeMismatch
  std::printf("  => Standard_TypeMismatch_Raise_if expands to NOTHING: TopoDS::Edge is a bare\n");
  std::printf("     reinterpret_cast on this build.\n\n");
#else
  std::printf("  => Standard_TypeMismatch_Raise_if is live: TopoDS::Edge throws on a non-edge.\n\n");
#endif

  std::vector<Fixture> fixtures = buildFixtures();

  std::printf("--- the unfixed loop body: mw.Add(TopoDS::Edge(shape)) ---\n");
  int crashes = 0;
  for (const Fixture& f : fixtures)
  {
    std::printf("  %s\n", f.name.c_str());
    if (!runIsolated(runUnfixed, f.shape))
      crashes++;
  }

  std::printf("\n--- the fixed loop body: guard on ShapeType() first ---\n");
  for (const Fixture& f : fixtures)
  {
    std::printf("  %s\n", f.name.c_str());
    if (!runIsolated(runFixed, f.shape))
      crashes++;
  }

  std::printf("\ncrashing cases: %d\n", crashes);
  return crashes > 0 ? 1 : 0;
}
