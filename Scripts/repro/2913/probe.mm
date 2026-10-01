// #2913 ground truth: what BRepGraph_Transform::Perform does with GeomPolicy::Share.
//
// The issue filed the mechanism as "Share points the target at the source's geometry, so
// Perform cannot apply the transform, and it does not". This probe tests that against the
// kernel: Perform's Share path is a *location-only* transform
// (BRepGraph_Transform.cxx:Perform -> applyLocationTransformInCopiedRange), which composes
// the trsf into every root Product's top-level OccurrenceRef::LocalLocation. OCCT's own
// GTest BRepGraph_TransformTest.LocationOnly_NoCopyGeom asserts exactly that, including
// that vertex definition points must NOT move.
//
// The question this probe answers is therefore not "does Perform move the vertices" (it
// does not, by design) but "does an OCCTSwift graph have anywhere for the location to
// land". OCCTBRepGraphCreate passes Options::CreateAutoProduct = false, so block B
// rebuilds that exact configuration and counts the Products.

#include <BRepGraph.hxx>
#include <BRepGraph_Copy.hxx>
#include <BRepGraph_Iterator.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_RefsView.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Transform.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopLoc_Location.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <cstdio>

static void dumpV0(const char* tag, const BRepGraph& g)
{
  if (g.Topo().Vertices().Nb() == 0)
  {
    printf("  %-24s v0=<none>\n", tag);
    return;
  }
  gp_Pnt p = BRepGraph_Tool::Vertex::Pnt(g, BRepGraph_VertexId(0));
  printf("  %-24s v0=(%.1f,%.1f,%.1f) verts=%u faces=%u products=%u\n",
         tag,
         p.X(),
         p.Y(),
         p.Z(),
         g.Topo().Vertices().Nb(),
         g.Topo().Faces().Nb(),
         g.Topo().Products().Nb());
}

static void dumpRootOccLoc(const char* tag, const BRepGraph& g)
{
  if (g.Topo().Products().Nb() == 0)
  {
    printf("  %-24s NO PRODUCT: nowhere for a location-only transform to land\n", tag);
    return;
  }
  const BRepGraph_ProductId pid = BRepGraph_ProductId::Start();
  const auto&               rel = g.Topo().Products().Relations(pid);
  if (rel.OccurrenceRefIds.Size() < 1)
  {
    printf("  %-24s product has no OccurrenceRef\n", tag);
    return;
  }
  const TopLoc_Location& loc =
    g.Refs().Occurrences().Entry(rel.OccurrenceRefIds.Value(0)).LocalLocation;
  gp_Trsf t = loc.Transformation();
  printf("  %-24s rootOccLoc identity=%d trans=(%.1f,%.1f,%.1f)\n",
         tag,
         (int)loc.IsIdentity(),
         t.Value(1, 4),
         t.Value(2, 4),
         t.Value(3, 4));
}

static void run(const char* label, bool createAutoProduct)
{
  printf("%s (CreateAutoProduct=%d)\n", label, (int)createAutoProduct);
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10.0, 20.0, 30.0).Shape();

  BRepGraph src;
  src.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = createAutoProduct;
  if (!src.Shapes().Add(box, opts).IsOk())
  {
    printf("  Add failed\n");
    return;
  }
  dumpV0("source", src);

  gp_Trsf trsf;
  trsf.SetTranslation(gp_Vec(100.0, 200.0, 300.0));

  BRepGraph copyTgt;
  bool okCopy = BRepGraph_Transform::Perform(src, copyTgt, trsf, BRepGraph_Copy::GeomPolicy::Copy);
  printf("  GeomPolicy::Copy  ok=%d\n", (int)okCopy);
  dumpV0("  copy target", copyTgt);
  dumpRootOccLoc("  copy target", copyTgt);

  BRepGraph shareTgt;
  bool okShare =
    BRepGraph_Transform::Perform(src, shareTgt, trsf, BRepGraph_Copy::GeomPolicy::Share);
  printf("  GeomPolicy::Share ok=%d\n", (int)okShare);
  dumpV0("  share target", shareTgt);
  dumpRootOccLoc("  share target", shareTgt);
  printf("\n");
}

int main()
{
  // Block A: OCCT's own default, which its GTest exercises.
  run("A. kernel default", true);
  // Block B: what OCCTBRepGraphCreate actually builds.
  run("B. OCCTSwift's configuration", false);
  return 0;
}
