// #3003: BRepOffsetAPI_MakeOffsetShape / MakeThickSolid volumes are not bit-reproducible run to run.
//
// One run of this program prints one reading of each of the six lines below. The census over many
// processes is run.sh's job, because the claim is about the spread between runs and a single run
// cannot show a spread.
//
//   lines    (default) <label> <volume as %a> <hash of the bit-exact BinTools dump> <volume as %.17g>
//            The first four labels are the offsets of 766-modeling-evidence-fix/probe.mm, the last
//            two are the shells of 766-modeling-issue568-index-skip/probe-evidence-fix.mm, built the
//            same way (same shapes, same arguments, same volume call).
//   order    the iteration order of an NCollection_DataMap<TopoDS_Shape, int, TopTools_ShapeMapHasher>
//            filled with the 26 faces of offsetArc's result, as indices into TopExp_Explorer order.
//            Nothing OCCT-specific runs: this is the container BuildOffsetByArc iterates, on shapes
//            whose order we know.
//   threads  the thread count of the process after the operations, and BOPAlgo_Options' global
//            parallel mode. A thread pool starts its workers when it is first used.
//   perturb  one process, 32 builds of offsetArc, with a different amount of heap held before each.
//            Reports how many distinct face orders came out, which is how much of the order is the
//            allocator's doing. Run it with the heap NOT perturbed too (`perturb quiet`): the
//            allocator reuses addresses in a short cycle, so even then the order is not constant.
//
// The dump hash is what separates "the volume moved" from "the result moved": a result whose
// sub-shapes come out in another order dumps differently even when its volume does not change.
#include <BRepGProp.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BOPAlgo_Options.hxx>
#include <BinTools.hxx>
#include <GProp_GProps.hxx>
#include <NCollection_DataMap.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <map>
#include <mach/mach.h>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

static uint64_t fnv(const std::string& s)
{
  uint64_t h = 1469598103934665603ull;
  for (unsigned char c : s)
  {
    h ^= c;
    h *= 1099511628211ull;
  }
  return h;
}

static uint64_t dumpHash(const TopoDS_Shape& s)
{
  std::ostringstream bin;
  BinTools::Write(s, bin);
  return fnv(bin.str());
}

// Shape.volume -> OCCTShapeGetVolume: BRepGProp::VolumeProperties with OnlyClosed = true, which is
// what 766-modeling-evidence-fix/probe.mm measures; the shell probe uses the default (false).
static double volume(const TopoDS_Shape& s, bool onlyClosed)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, onlyClosed);
  return p.Mass();
}

// Shape.box is centred on the origin.
static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static gp_Dir normalOf(const TopoDS_Face& f)
{
  BRepAdaptor_Surface s(f);
  BRepLProp_SLProps   p(s, (s.FirstUParameter() + s.LastUParameter()) / 2,
                      (s.FirstVParameter() + s.LastVParameter()) / 2, 1, 1e-6);
  gp_Dir n = p.Normal();
  if (f.Orientation() == TopAbs_REVERSED)
    n.Reverse();
  return n;
}

static void report(const char* label, const TopoDS_Shape& r, double v)
{
  printf("%s %a %016llx %.17g\n", label, v, (unsigned long long)dumpHash(r), v);
}

static void offsetLine(const char* label, const TopoDS_Shape& s, double d, GeomAbs_JoinType j)
{
  BRepOffsetAPI_MakeOffsetShape m;
  m.PerformByJoin(s, d, 1e-7, BRepOffset_Skin, false, false, j, false);
  if (!m.IsDone() || m.Shape().IsNull())
  {
    printf("%s not-done-or-null\n", label);
    return;
  }
  report(label, m.Shape(), volume(m.Shape(), true));
}

static TopoDS_Shape offsetArcResult()
{
  BRepOffsetAPI_MakeOffsetShape m;
  m.PerformByJoin(box(10, 10, 10), 1, 1e-7, BRepOffset_Skin, false, false, GeomAbs_Arc, false);
  return m.Shape();
}

int main(int argc, char** argv)
{
  const char* mode = argc > 1 ? argv[1] : "lines";

  if (!strcmp(mode, "lines"))
  {
    offsetLine("offsetArc", box(10, 10, 10), 1, GeomAbs_Arc);
    offsetLine("offsetInward", box(10, 10, 10), -1, GeomAbs_Arc);
    offsetLine("offsetIntersection", box(10, 10, 10), 1, GeomAbs_Intersection);
    offsetLine("offsetCylinder", BRepPrimAPI_MakeCylinder(5, 10).Shape(), 1, GeomAbs_Arc);

    // 766-modeling-issue568-index-skip/probe-evidence-fix.mm: Shell on a 20-cube, thickness 2.0,
    // MakeThickSolidByJoin(1e-6), with the faces facing up as the opening, and with none.
    TopoDS_Shape               b = box(20, 20, 20);
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(b, TopAbs_FACE, faces);
    TopTools_ListOfShape top, none;
    for (int i = 1; i <= faces.Extent(); i++)
      if (normalOf(TopoDS::Face(faces(i))).Z() > std::cos(0.01))
        top.Append(faces(i));
    BRepOffsetAPI_MakeThickSolid ts;
    ts.MakeThickSolidByJoin(b, top, 2.0, 1e-6);
    if (ts.IsDone())
      report("shellOwnFaces", ts.Shape(), volume(ts.Shape(), false));
    BRepOffsetAPI_MakeThickSolid te;
    te.MakeThickSolidByJoin(b, none, 2.0, 1e-6);
    if (te.IsDone())
      report("shellNoOpenFace", te.Shape(), volume(te.Shape(), false));
    return 0;
  }

  if (!strcmp(mode, "order"))
  {
    TopoDS_Shape                                                  r = offsetArcResult();
    TopTools_IndexedMapOfShape                                    faces;
    TopExp::MapShapes(r, TopAbs_FACE, faces);
    NCollection_DataMap<TopoDS_Shape, int, TopTools_ShapeMapHasher> m;
    for (int i = 1; i <= faces.Extent(); i++)
      m.Bind(faces(i), i);
    printf("faces=%d hash order:", faces.Extent());
    for (NCollection_DataMap<TopoDS_Shape, int, TopTools_ShapeMapHasher>::Iterator it(m); it.More();
         it.Next())
      printf(" %d", it.Value());
    printf("\n");
    return 0;
  }

  if (!strcmp(mode, "threads"))
  {
    offsetLine("offsetArc", box(10, 10, 10), 1, GeomAbs_Arc);
    TopTools_ListOfShape none;
    BRepOffsetAPI_MakeThickSolid te;
    te.MakeThickSolidByJoin(box(20, 20, 20), none, 2.0, 1e-6);
    thread_act_array_t list  = nullptr;
    mach_msg_type_number_t count = 0;
    task_threads(mach_task_self(), &list, &count);
    printf("threads in the process after the operations: %u\n", count);
    printf("BOPAlgo_Options::GetParallelMode(): %d\n", (int)BOPAlgo_Options::GetParallelMode());
    return 0;
  }

  if (!strcmp(mode, "perturb"))
  {
    const bool                           quiet = argc > 2 && !strcmp(argv[2], "quiet");
    std::vector<std::unique_ptr<char[]>> held;
    std::map<std::string, int>           orders;
    for (int run = 0; run < 32; run++)
    {
      if (!quiet)
        held.emplace_back(new char[16 + 16 * run]);
      // Where each face of the result is, in the order the shape holds them: two builds that agree
      // on this list agree on the order, and the centres are all different so it identifies it.
      std::string  order;
      TopoDS_Shape r = offsetArcResult();
      for (TopExp_Explorer ex(r, TopAbs_FACE); ex.More(); ex.Next())
      {
        GProp_GProps p;
        BRepGProp::SurfaceProperties(ex.Current(), p);
        char buf[96];
        snprintf(buf, sizeof buf, "%.6f,%.6f,%.6f;", std::round(p.CentreOfMass().X() * 1e6) / 1e6 + 0.0,
                 std::round(p.CentreOfMass().Y() * 1e6) / 1e6 + 0.0,
                 std::round(p.CentreOfMass().Z() * 1e6) / 1e6 + 0.0);
        order += buf;
      }
      orders[order]++;
    }
    printf("builds=32 heap %s: distinct face orders=%zu\n", quiet ? "untouched" : "perturbed",
           orders.size());
    return 0;
  }

  fprintf(stderr, "usage: probe [lines|order|threads|perturb [quiet]]\n");
  return 2;
}
