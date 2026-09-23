// Epic #766, OCCTDrawingTests: Issue1193CuttingPlaneDirectionTests,
// Issue881PerpendicularBasisTests, Issue999ProjectionTypeTests.
// #881/#1193: the gp_Ax2(origin, nearDegenerate) frame the fixture constants in
// DrawingTestFixtures.swift (PerpendicularBasisGroundTruth) claim to be.
// #999: HLRBRep_Algo with the orthographic and perspective HLRAlgo_Projector OCCTDrawingCreate
// builds, and HLRBRep_PolyAlgo as OCCTDrawingCreatePoly runs it, on the centred 100x50x30 box;
// visible half-extents, plus the bridge's focus/reach guards for the refused focal distances.
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
#include <TopoDS_Compound.hxx>
#include <cmath>
#include <cstdio>

static void halfExtent(const char* tag, TopoDS_Shape a, TopoDS_Shape b, TopoDS_Shape c)
{
  TopoDS_Compound comp;
  BRep_Builder    bld;
  bld.MakeCompound(comp);
  TopoDS_Shape parts[3] = {a, b, c};
  for (const TopoDS_Shape& s : parts)
    if (!s.IsNull())
      bld.Add(comp, s);
  Bnd_Box box;
  BRepBndLib::Add(comp, box, true);
  double x0, y0, z0, x1, y1, z1;
  box.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: half extent (%.12g, %.12g)\n", tag, (x1 - x0) / 2, (y1 - y0) / 2);
}

static TopoDS_Shape box()
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-50, -25, -15), 100, 50, 30).Shape();
}

static void exact(const char* tag, double focus)
{
  gp_Ax2               ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
  algo->Add(box());
  algo->Projector(focus > 0 ? HLRAlgo_Projector(ax, focus) : HLRAlgo_Projector(ax));
  algo->Update();
  algo->Hide();
  HLRBRep_HLRToShape h(algo);
  halfExtent(tag, h.VCompound(), h.Rg1LineVCompound(), h.OutLineVCompound());
}

int main()
{
  const double d15 = 15.0 * M_PI / 180.0;
  gp_Dir       nearDegenerate(std::sin(d15) * 0.6, std::sin(d15) * 0.8, std::cos(d15));
  gp_Ax2       f(gp_Pnt(0, 0, 0), nearDegenerate);
  printf("gp_Ax2 XDirection = (%.17g, %.17g, %.17g)\n", f.XDirection().X(), f.XDirection().Y(),
         f.XDirection().Z());
  printf("gp_Ax2 YDirection = (%.17g, %.17g, %.17g)\n", f.YDirection().X(), f.YDirection().Y(),
         f.YDirection().Z());
  printf("fixture expectedRight = (0.0, 0.9777876596251666, -0.20959793101254465)\n");
  printf("fixture expectedUp    = (-0.987868702146798, 0.03254876181607849, 0.1518420410263285)\n");

  exact("orthographic", 0);
  for (double focus : {20.0, 50.0, 200.0, 1000.0})
  {
    char tag[64];
    snprintf(tag, sizeof tag, "perspective focus %g (expected x %.12g)", focus,
             50.0 * focus / (focus - 15.0));
    exact(tag, focus);
  }
  // The bridge refuses focus <= 0 or NaN before any OCCT call; the reach guard (zmax = 15 along
  // +Z) would refuse 0 and -100 too.
  printf("nonPositiveFocus: !(0 > 0)=%d !(-100 > 0)=%d !(nan > 0)=%d\n", !(0.0 > 0), !(-100.0 > 0),
         !(NAN > 0));

  TopoDS_Shape b = box();
  BRepMesh_IncrementalMesh     mesh(b, 0.01);
  Handle(HLRBRep_PolyAlgo) poly = new HLRBRep_PolyAlgo();
  poly->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))));
  poly->Load(b);
  poly->Update();
  HLRBRep_PolyHLRToShape ps;
  ps.Update(poly);
  halfExtent("projectFast (PolyAlgo, deflection 0.01)", ps.VCompound(), ps.Rg1LineVCompound(),
             ps.OutLineVCompound());
  return 0;
}
