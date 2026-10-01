// Epic #766, PR #2369 evidence fix: the polyhedral-HLR edge count against the mesh deflection.
//
// Issue196PolyHLRTests.deflectionControlsDetail used to claim "coarser mesh yields fewer drawing edges"
// and assert only coarse != fine, while the committed data (transcript.txt) had the coarse mesh at MORE
// visible-sharp edges (2089 against 1873). This probe measures the counts properly, per category, through
// the calls OCCTHLRPolyGetEdgesByCategory makes:
//   BRepMesh_IncrementalMesh(shape, deflection), then HLRBRep_PolyAlgo Load / Projector(view +X) / Update,
//   then HLRBRep_PolyHLRToShape Update, and VCompound (visibleSharp) or OutLineVCompound (visibleOutline).
// Each deflection reads the BREP afresh (BRepMesh_IncrementalMesh refines and never coarsens, so a shape
// already meshed finely would mask a coarse deflection). The BREP is the M10x1.0 thread, length 26 on a
// 50 mm blank, that the Swift run wrote before any meshing. The triangle count is the total of
// Poly_Triangulation::NbTriangles over the faces after meshing.
//
//   probe <file.brep> <deflection>...     polyhedral HLR edge counts, as above
//   probe groove <file.brep>              the #213 flank measurement, below
//
// #213 (Issue213VProfile.flankAngleOfBuiltThread), mode `groove`: the old test rebuilt the flank angle
// from ThreadSpec arithmetic and asserted a constant. The new one measures the groove of the built
// M10x1.5 ISO-68 thread. This mode makes the same measurement on the BREP the Swift run wrote:
// BRepClass3d_SolidClassifier(shape, (r, 0, z), 1e-6) as OCCTShapeClassifyPoint does, TopAbs_OUT meaning
// inside the groove, scanned over two pitches from z = 6 at a 0.05 step, each edge bisected to 1e-5,
// at radii 5 - 0.75 * cutDepth and 5 - 0.25 * cutDepth (cutDepth = 5H/8 with H = P * sqrt(3) / 2, P = 1.5).
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

static int edgeCount(const TopoDS_Shape& s)
{
  if (s.IsNull())
    return 0;
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(s, TopAbs_EDGE, edges);
  return edges.Extent();
}


// Width of the groove along the line (r, 0, z), as Issue213VProfile.grooveWidth measures it.
static bool outside(const TopoDS_Shape& s, double r, double z)
{
  BRepClass3d_SolidClassifier c(s, gp_Pnt(r, 0, z), 1e-6);
  return c.State() == TopAbs_OUT;
}

static double edgeOf(const TopoDS_Shape& s, double r, double inside, double outsidePt)
{
  double a = inside, b = outsidePt;
  while (fabs(b - a) > 1e-5)
  {
    double m = (a + b) / 2;
    if (outside(s, r, m))
      b = m;
    else
      a = m;
  }
  return (a + b) / 2;
}

static double grooveWidth(const TopoDS_Shape& s, double r, double z0, double pitch)
{
  const double step    = 0.05;
  const int    samples = (int)std::lround(2 * pitch / step);
  bool         prev    = outside(s, r, z0);
  bool         have    = false;
  double       start   = 0;
  for (int i = 1; i <= samples; i++)
  {
    double z   = z0 + i * step;
    bool   now = outside(s, r, z);
    if (!prev && now)
    {
      start = edgeOf(s, r, z - step, z);
      have  = true;
    }
    else if (prev && !now && have)
      return edgeOf(s, r, z, z - step) - start;
    prev = now;
  }
  return -1;
}

int main(int argc, char** argv)
{
  if (argc < 3)
    return 2;
  if (!strcmp(argv[1], "groove"))
  {
    TopoDS_Shape s;
    BRep_Builder bb;
    BRepTools::Read(s, argv[2], bb);
    const double pitch    = 1.5;
    const double cutDepth = pitch * sqrt(3.0) / 2 * 5 / 8;
    double       deep     = 5 - 0.75 * cutDepth;
    double       shallow  = 5 - 0.25 * cutDepth;
    double       wDeep    = grooveWidth(s, deep, 6, pitch);
    double       wShallow = grooveWidth(s, shallow, 6, pitch);
    double       half     = atan((wShallow - wDeep) / 2 / (0.5 * cutDepth)) * 180 / M_PI;
    printf("KERNEL groove cutDepth=%.17g deep=%.17g shallow=%.17g wDeep=%.17g wShallow=%.17g halfAngle=%.17g\n", cutDepth,
           deep, shallow, wDeep, wShallow, half);
    return 0;
  }
  std::string path = argv[1];
  std::string name = path.substr(path.find_last_of('/') + 1);
  for (int i = 2; i < argc; i++)
  {
    double       defl = atof(argv[i]);
    TopoDS_Shape s;
    BRep_Builder bb;
    BRepTools::Read(s, path.c_str(), bb);
    BRepMesh_IncrementalMesh mesh(s, defl);
    long                     tris = 0;
    for (TopExp_Explorer fe(s, TopAbs_FACE); fe.More(); fe.Next())
    {
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(fe.Current()), loc);
      if (!t.IsNull())
        tris += t->NbTriangles();
    }
    HLRAlgo_Projector        proj(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
    Handle(HLRBRep_PolyAlgo) algo = new HLRBRep_PolyAlgo();
    algo->Load(s);
    algo->Projector(proj);
    algo->Update();
    HLRBRep_PolyHLRToShape toShape;
    toShape.Update(algo);
    printf("KERNEL %s defl=%g visibleSharp=%d visibleOutline=%d triangles=%ld\n", name.c_str(), defl,
           edgeCount(toShape.VCompound()), edgeCount(toShape.OutLineVCompound()), tris);
  }
  return 0;
}
