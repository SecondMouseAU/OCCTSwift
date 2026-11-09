// OCCTSwift#3516 ground truth: which BRepFilletAPI_MakeFillet / MakeChamfer accessors dereference a
// null data structure when the builder has not completed a build.
//
// BRepFilletAPI_MakeFillet::NbSurfaces() is `myBuilder.Builder()->DataStructure()->NbSurfaces()`.
// `Builder()` is ChFi3d_Builder::myCoup, a TopOpeBRepBuild_HBuilder made in the constructor, but its
// DataStructure() is TopOpeBRepBuild_Builder::myDataStructure, which only HBuilder::Perform(HDS)
// assigns, and ChFi3d_Builder::Compute reaches that call only when the build got that far. So the
// handle is null for a builder that was never built as well as for one whose build was declined.
//
// Every (state, accessor) pair runs in its own forked child, so a SIGSEGV is a recorded row and not
// the end of the probe. OCC_CATCH_SIGNALS is inert in this build, so nothing in-process could
// absorb the signal; the parent reads it from waitpid.
//
// Compile (from the repo root, against the xcframework the package pins):
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/3516/occt_3516_nbsurfaces_matrix.mm -o /tmp/occt_3516
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <BRep_Builder.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Trsf.hxx>

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

// ---- fixtures -------------------------------------------------------------------------------

struct Fixture
{
  TopoDS_Shape           shape;
  TopTools_IndexedMapOfShape edges;
  TopTools_IndexedMapOfShape faces;
  std::vector<TopoDS_Edge> blendEdges; // the edges a state adds
};

static void mapOf(Fixture& f)
{
  TopExp::MapShapes(f.shape, TopAbs_EDGE, f.edges);
  TopExp::MapShapes(f.shape, TopAbs_FACE, f.faces);
}

static Fixture boxFixture()
{
  Fixture f;
  f.shape = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  mapOf(f);
  f.blendEdges.push_back(TopoDS::Edge(f.edges(1)));
  return f;
}

// The upstream report's model (Open-Cascade-SAS/OCCT#1716): a cylinder r 95 along X, x in
// [-70, 70], fused with three cylinders r 80 along Z, z in [0, 135], patterned 120 deg about X,
// cut to the same slab; the concave arm-to-disc edges are the ones between a cylinder with an X
// axis and a cylinder with a Z-ish axis.
static Fixture threeCylinderFixture()
{
  Fixture f;
  TopoDS_Shape disc =
    BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(-70, 0, 0), gp_Dir(1, 0, 0)), 95.0, 140.0).Shape();
  TopoDS_Shape result = disc;
  for (int k = 0; k < 3; ++k)
  {
    TopoDS_Shape arm =
      BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 80.0, 135.0).Shape();
    gp_Trsf t;
    t.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), k * 2.0 * M_PI / 3.0);
    arm    = arm.Moved(TopLoc_Location(t));
    result = BRepAlgoAPI_Fuse(result, arm).Shape();
  }
  TopoDS_Shape slab = BRepPrimAPI_MakeBox(gp_Pnt(-70, -300, -300), gp_Pnt(70, 300, 300)).Shape();
  f.shape           = BRepAlgoAPI_Common(result, slab).Shape();
  mapOf(f);
  NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>, TopTools_ShapeMapHasher>
    anc;
  TopExp::MapShapesAndAncestors(f.shape, TopAbs_EDGE, TopAbs_FACE, anc);
  for (int i = 1; i <= anc.Extent(); ++i)
  {
    const NCollection_List<TopoDS_Shape>& fl = anc(i);
    if (fl.Extent() != 2)
      continue;
    BRepAdaptor_Surface s1(TopoDS::Face(fl.First()));
    BRepAdaptor_Surface s2(TopoDS::Face(fl.Last()));
    if (s1.GetType() != GeomAbs_Cylinder || s2.GetType() != GeomAbs_Cylinder)
      continue;
    gp_Dir d1 = s1.Cylinder().Axis().Direction();
    gp_Dir d2 = s2.Cylinder().Axis().Direction();
    if (std::abs(d1.Dot(d2)) > 0.99) // parallel axes: not an arm-to-disc seam
      continue;
    f.blendEdges.push_back(TopoDS::Edge(anc.FindKey(i)));
  }
  return f;
}

// ---- states ---------------------------------------------------------------------------------

enum State
{
  Fresh,           // constructed, nothing added
  AddedNotBuilt,   // one edge added, Build() never called
  BuildNoContours, // Build() with nothing added: throws "no suitable edges"
  DeclinedOversize, // radius far above the box: Build() leaves IsDone() false
  Declined3Cyl,    // the upstream model at R 17
  BuiltOk,         // control: a build that completed
  ResetAfterOk     // completed, then Reset()
};

static const char* stateName(State s)
{
  switch (s)
  {
    case Fresh: return "fresh (never built, no contour)";
    case AddedNotBuilt: return "added, Build() never called";
    case BuildNoContours: return "Build() with no contour (threw)";
    case DeclinedOversize: return "declined: box edge, radius 20";
    case Declined3Cyl: return "declined: three-cylinder model, R 17";
    case BuiltOk: return "CONTROL: built ok";
    case ResetAfterOk: return "built ok, then Reset()";
  }
  return "?";
}

template <class Maker>
static void prepare(State s, Fixture& fx, std::unique_ptr<Maker>& mk, double radius)
{
  fx = (s == Declined3Cyl) ? threeCylinderFixture() : boxFixture();
  mk.reset(new Maker(fx.shape));
}

// ---- the fillet matrix ----------------------------------------------------------------------

struct FilletCase
{
  const char*                                                         name;
  std::function<std::string(BRepFilletAPI_MakeFillet&, Fixture&)> fn;
};

static std::string num(double v)
{
  char b[64];
  snprintf(b, sizeof b, "%g", v);
  return b;
}

static std::string filletSetup(State s, std::unique_ptr<BRepFilletAPI_MakeFillet>& mk, Fixture& fx)
{
  prepare<BRepFilletAPI_MakeFillet>(s, fx, mk, 0);
  try
  {
    switch (s)
    {
      case Fresh: break;
      case AddedNotBuilt: mk->Add(1.0, fx.blendEdges[0]); break;
      case BuildNoContours: mk->Build(); break;
      case DeclinedOversize:
        mk->Add(20.0, fx.blendEdges[0]);
        mk->Build();
        break;
      case Declined3Cyl:
        for (const TopoDS_Edge& e : fx.blendEdges)
          mk->Add(17.0, e);
        mk->Build();
        break;
      case BuiltOk:
        mk->Add(1.0, fx.blendEdges[0]);
        mk->Build();
        break;
      case ResetAfterOk:
        mk->Add(1.0, fx.blendEdges[0]);
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

int main()
{
  const State states[] = {Fresh, AddedNotBuilt, BuildNoContours, DeclinedOversize,
                          Declined3Cyl, BuiltOk, ResetAfterOk};

  std::vector<FilletCase> cases = {
    {"NbSurfaces()", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbSurfaces()); }},
    {"NbComputedSurfaces(1)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbComputedSurfaces(1)); }},
    {"StripeStatus(1)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num((int)m.StripeStatus(1)); }},
    {"NbSurf(1) [simulated]", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbSurf(1)); }},
    {"Simulate(1); NbSurf(1)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&)
     {
       m.Simulate(1);
       return num(m.NbSurf(1));
     }},
    {"HasResult()", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.HasResult()); }},
    {"BadShape()",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.BadShape().IsNull() ? 0 : 1); }},
    {"NbFaultyContours()",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbFaultyContours()); }},
    {"NbFaultyVertices()",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbFaultyVertices()); }},
    {"FaultyContour(1)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.FaultyContour(1)); }},
    {"FaultyVertex(1)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.FaultyVertex(1).IsNull() ? 0 : 1); }},
    {"Generated(edge)",
     [](BRepFilletAPI_MakeFillet& m, Fixture& f) { return num(m.Generated(f.edges(1)).Size()); }},
    {"Modified(face)",
     [](BRepFilletAPI_MakeFillet& m, Fixture& f) { return num(m.Modified(f.faces(1)).Size()); }},
    {"IsDeleted(face)",
     [](BRepFilletAPI_MakeFillet& m, Fixture& f) { return num(m.IsDeleted(f.faces(1))); }},
    {"NewFaces(1)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NewFaces(1).Size()); }},
    {"ComputedSurface(1,1)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&)
     { return num(m.ComputedSurface(1, 1).IsNull() ? 0 : 1); }},
    {"Sect(1,1)",
     [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.Sect(1, 1).IsNull() ? 0 : 1); }},
    {"NbContours()", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbContours()); }},
    {"NbEdges(1)", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.NbEdges(1)); }},
    {"Length(1)", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.Length(1)); }},
    {"Radius(1)", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.Radius(1)); }},
    {"Closed(1)", [](BRepFilletAPI_MakeFillet& m, Fixture&) { return num(m.Closed(1)); }},
  };

  printf("=== BRepFilletAPI_MakeFillet: one forked child per (state, accessor) ===\n");
  for (State s : states)
  {
    // The state line itself: what the builder reports, which is safe in every state.
    std::string head = runForked(
      [&]() -> std::string
      {
        std::unique_ptr<BRepFilletAPI_MakeFillet> mk;
        Fixture                                    fx;
        std::string                                note = filletSetup(s, mk, fx);
        return "IsDone=" + num(mk->IsDone()) + " NbContours=" + num(mk->NbContours()) + " " + note;
      });
    printf("\n--- state: %s\n    %s\n", stateName(s), head.c_str());
    for (FilletCase& c : cases)
    {
      std::string r = runForked(
        [&]() -> std::string
        {
          std::unique_ptr<BRepFilletAPI_MakeFillet> mk;
          Fixture                                    fx;
          filletSetup(s, mk, fx);
          return c.fn(*mk, fx);
        });
      printf("    %-26s %s\n", c.name, r.c_str());
    }
  }

  // ---- the chamfer builder: it has no NbSurfaces, so the question is its history queries ------
  printf("\n=== BRepFilletAPI_MakeChamfer ===\n");
  struct ChamferCase
  {
    const char*                                                         name;
    std::function<std::string(BRepFilletAPI_MakeChamfer&, Fixture&)> fn;
  };
  std::vector<ChamferCase> ccases = {
    {"NbSurf(1) [simulated]", [](BRepFilletAPI_MakeChamfer& m, Fixture&) { return num(m.NbSurf(1)); }},
    {"Simulate(1); NbSurf(1)",
     [](BRepFilletAPI_MakeChamfer& m, Fixture&)
     {
       m.Simulate(1);
       return num(m.NbSurf(1));
     }},
    {"Generated(edge)",
     [](BRepFilletAPI_MakeChamfer& m, Fixture& f) { return num(m.Generated(f.edges(1)).Size()); }},
    {"Modified(face)",
     [](BRepFilletAPI_MakeChamfer& m, Fixture& f) { return num(m.Modified(f.faces(1)).Size()); }},
    {"IsDeleted(face)",
     [](BRepFilletAPI_MakeChamfer& m, Fixture& f) { return num(m.IsDeleted(f.faces(1))); }},
    {"Builder() non-null",
     [](BRepFilletAPI_MakeChamfer& m, Fixture&) { return num(!m.Builder().IsNull()); }},
  };
  auto chamferSetup = [](State s, std::unique_ptr<BRepFilletAPI_MakeChamfer>& mk, Fixture& fx)
  {
    fx = boxFixture();
    mk.reset(new BRepFilletAPI_MakeChamfer(fx.shape));
    try
    {
      switch (s)
      {
        case Fresh: break;
        case AddedNotBuilt: mk->Add(1.0, fx.blendEdges[0]); break;
        case BuildNoContours: mk->Build(); break;
        case DeclinedOversize:
          mk->Add(20.0, fx.blendEdges[0]);
          mk->Build();
          break;
        case BuiltOk:
          mk->Add(1.0, fx.blendEdges[0]);
          mk->Build();
          break;
        case ResetAfterOk:
          mk->Add(1.0, fx.blendEdges[0]);
          mk->Build();
          mk->Reset();
          break;
        case Declined3Cyl: break; // not applicable
      }
    }
    catch (Standard_Failure const&)
    {
    }
  };
  for (State s : {Fresh, AddedNotBuilt, BuildNoContours, DeclinedOversize, BuiltOk, ResetAfterOk})
  {
    std::string head = runForked(
      [&]() -> std::string
      {
        std::unique_ptr<BRepFilletAPI_MakeChamfer> mk;
        Fixture                                     fx;
        chamferSetup(s, mk, fx);
        return "IsDone=" + num(mk->IsDone()) + " NbContours=" + num(mk->NbContours());
      });
    printf("\n--- state: %s\n    %s\n", stateName(s), head.c_str());
    for (ChamferCase& c : ccases)
    {
      std::string r = runForked(
        [&]() -> std::string
        {
          std::unique_ptr<BRepFilletAPI_MakeChamfer> mk;
          Fixture                                     fx;
          chamferSetup(s, mk, fx);
          return c.fn(*mk, fx);
        });
      printf("    %-26s %s\n", c.name, r.c_str());
    }
  }
  return 0;
}
