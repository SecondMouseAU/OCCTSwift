// Epic #766, OCCTDrawingTests: HLRReflectLinesTests and Issue1036PerspectiveEyeAnchorTests.
// Issue1059ProjectionTypeHashableTests is pure Swift (the enum's Hashable conformance) and has
// no kernel counterpart.
// Reflect lines: HLRAppli_ReflectLines on a radius-10 sphere with the tests' axes, as
// OCCTHLRReflectLines / OCCTHLRReflectLinesFiltered call it. Perspective: HLRBRep_Algo with
// HLRAlgo_Projector(gp_Ax2(origin, +Z), focus) as OCCTDrawingCreate builds it, on corner-based
// 10-unit cubes, reporting the reach along the view direction that the bridge's guard compares
// with focus, and the visible X range.
#include <BRepBndLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Builder.hxx>
#include <Bnd_Box.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRAppli_ReflectLines.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS_Compound.hxx>
#include <cstdio>

static void report(const char* tag, const TopoDS_Shape& s)
{
  if (s.IsNull())
  {
    printf("%s: null\n", tag);
    return;
  }
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_EDGE, m);
  Bnd_Box b;
  BRepBndLib::Add(s, b, true);
  if (b.IsVoid())
  {
    printf("%s: edges=%d (void box)\n", tag, m.Extent());
    return;
  }
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: edges=%d bbox=(%.9g, %.9g, %.9g)..(%.9g, %.9g, %.9g)\n", tag, m.Extent(), x0, y0, z0,
         x1, y1, z1);
}

static void perspective(const char* tag, double xMin, double zMin, double focus)
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(xMin, -5, zMin), 10, 10, 10).Shape();
  Bnd_Box      bb;
  BRepBndLib::Add(box, bb);
  double x0, y0, z0, x1, y1, z1;
  bb.Get(x0, y0, z0, x1, y1, z1);
  double reach = z1; // view direction +Z: the bridge's reach is zmax
  printf("%s: reach=%.9g focus=%g guard(reach >= focus)=%s\n", tag, reach, focus,
         reach >= focus ? "refuse" : "project");
  if (reach >= focus)
    return;
  Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
  algo->Add(box);
  algo->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), focus));
  algo->Update();
  algo->Hide();
  HLRBRep_HLRToShape h(algo);
  TopoDS_Compound    c;
  BRep_Builder       bld;
  bld.MakeCompound(c);
  TopoDS_Shape parts[3] = {h.VCompound(), h.Rg1LineVCompound(), h.OutLineVCompound()};
  for (const TopoDS_Shape& s : parts)
    if (!s.IsNull())
      bld.Add(c, s);
  Bnd_Box vb;
  BRepBndLib::Add(c, vb, true);
  vb.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: visible x range [%.12g, %.12g]\n", tag, x0, x1);
}

int main()
{
  TopoDS_Shape          sphere = BRepPrimAPI_MakeSphere(10).Shape();
  HLRAppli_ReflectLines rl(sphere);
  rl.SetAxes(0, 0, 1, 0, 0, 100, 0, 1, 0);
  rl.Perform();
  report("reflectLinesSphere", rl.GetResult());
  report("reflectLinesFiltered outLine visible in3d",
         rl.GetCompoundOf3dEdges(HLRBRep_OutLine, true, true));

  perspective("shapeBeyondTheEye", 20, 1000, 50);
  perspective("eyePlaneCuttingTheShape", 20, 0, 5.5);
  perspective("eyeExactlyOnAFace", 20, 0, 10);
  perspective("eyeAnchor atOrigin", -5, 0, 50);
  perspective("eyeAnchor farAway", -5, 1000, 1050);
  perspective("shapeBehindThePicturePlane", 20, -1010, 50);
  perspective("extremeButValidFocus", 20, 0, 10.01);
  return 0;
}
