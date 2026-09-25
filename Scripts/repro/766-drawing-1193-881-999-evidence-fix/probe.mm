// Epic #766, #1984 evidence correction for PR #2499 (Issue1193CuttingPlaneDirectionTests,
// Issue881PerpendicularBasisTests, Issue999ProjectionTypeTests). What the original probe printed at
// %.12g or did not measure:
//   1. The gp_Ax2(origin, nearDegenerate) frame: XDirection and YDirection at %.17g, the kernel
//      side of the basis records (Swift's perpendicularBasis(to:) right and up).
//   2. Issue999: the visible half-extents of the centred 100x50x30 box for the orthographic
//      projector and for perspective at focus 20, 50, 200, 1000, at %.17g, and the polygonal
//      HLRBRep_PolyAlgo result (deflection 0.01, the Swift default).
//   3. Issue999, the refused focal distances: HLRBRep_Algo with HLRAlgo_Projector(ax, focus) run
//      WITHOUT the bridge's `!(focus > 0)` guard for focus 0, -100 and NaN, reporting what the
//      kernel does with each, so the refusal can be recorded as a design divergence.
#include <BRepBndLib.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <Bnd_Box.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS_Compound.hxx>
#include <cmath>
#include <cstdio>

static TopoDS_Shape box()
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-50, -25, -15), 100, 50, 30).Shape();
}

static void halfExtent(const char* tag, const TopoDS_Shape parts[3])
{
  BRep_Builder    bld;
  TopoDS_Compound c;
  bld.MakeCompound(c);
  for (int i = 0; i < 3; ++i)
    if (!parts[i].IsNull())
      bld.Add(c, parts[i]);
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(c, TopAbs_EDGE, m);
  Bnd_Box bb;
  BRepBndLib::Add(c, bb, true);
  if (bb.IsVoid())
  {
    printf("%s: edges=%d, void bounding box (empty result)\n", tag, m.Extent());
    return;
  }
  double x0, y0, z0, x1, y1, z1;
  bb.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: edges=%d half extent (%.17g, %.17g)\n", tag, m.Extent(), (x1 - x0) / 2, (y1 - y0) / 2);
}

static void exact(const char* tag, double focus, bool perspective)
{
  Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
  algo->Add(box());
  gp_Ax2 ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  algo->Projector(perspective ? HLRAlgo_Projector(ax, focus) : HLRAlgo_Projector(ax));
  algo->Update();
  algo->Hide();
  HLRBRep_HLRToShape h(algo);
  TopoDS_Shape       v[3] = {h.VCompound(), h.Rg1LineVCompound(), h.OutLineVCompound()};
  halfExtent(tag, v);
}

int main()
{
  // ---- 1. the gp_Ax2 frame
  {
    const double d15 = 15.0 * M_PI / 180.0;
    gp_Dir       nearDegenerate(std::sin(d15) * 0.6, std::sin(d15) * 0.8, std::cos(d15));
    gp_Ax2       f(gp_Pnt(0, 0, 0), nearDegenerate);
    printf("gp_Ax2 XDirection = (%.17g, %.17g, %.17g)\n", f.XDirection().X(), f.XDirection().Y(),
           f.XDirection().Z());
    printf("gp_Ax2 YDirection = (%.17g, %.17g, %.17g)\n", f.YDirection().X(), f.YDirection().Y(),
           f.YDirection().Z());
  }
  // ---- 2. the projection types at full precision
  exact("orthographic", 0, false);
  for (double focus : {20.0, 50.0, 200.0, 1000.0})
  {
    char tag[64];
    snprintf(tag, sizeof tag, "perspective focus %g", focus);
    exact(tag, focus, true);
  }
  {
    TopoDS_Shape             b = box();
    BRepMesh_IncrementalMesh mesh(b, 0.01);
    Handle(HLRBRep_PolyAlgo) poly = new HLRBRep_PolyAlgo();
    poly->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))));
    poly->Load(b);
    poly->Update();
    HLRBRep_PolyHLRToShape ps;
    ps.Update(poly);
    TopoDS_Shape v[3] = {ps.VCompound(), ps.Rg1LineVCompound(), ps.OutLineVCompound()};
    halfExtent("projectFast (PolyAlgo, deflection 0.01)", v);
  }
  // ---- 3. the focal distances the bridge refuses, unguarded
  for (double focus : {0.0, -100.0, (double)NAN})
  {
    char tag[80];
    snprintf(tag, sizeof tag, "unguarded perspective focus %g", focus);
    try
    {
      exact(tag, focus, true);
    }
    catch (Standard_Failure& e)
    {
      printf("%s: HLRBRep_Algo threw %s\n", tag, e.GetMessageString());
    }
  }
  return 0;
}
