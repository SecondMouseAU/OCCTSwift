// #766 kernel parity: Issue1058OuterBoundRefusalTests.
// Raw ShapeAnalysis_Wire::CheckOuterBound on the fixtures, with none of OCCTWireCheckOuterBound's
// refusal guards, so each refusal can be read against what the kernel alone would have said.
// The disconnected-edge wire is not run: without the null-WireAPIMake guard it SIGSEGVs in
// BRep_Builder::Add (#1058), which is exactly the defect the bridge guard exists for.
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Builder.hxx>
#include <BRepTools.hxx>
#include <Geom_Plane.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeAnalysis.hxx>
#include <ShapeExtend_WireData.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Wire.hxx>
#include <Precision.hxx>
#include <cmath>
#include <cstdio>

static TopoDS_Wire poly(double a, double b)
{
  BRepBuilderAPI_MakePolygon p(gp_Pnt(a, a, 0), gp_Pnt(b, a, 0), gp_Pnt(b, b, 0), gp_Pnt(a, b, 0), Standard_True);
  return p.Wire();
}

static void check(const char* label, const TopoDS_Wire& w, const TopoDS_Face& f)
{
  ShapeAnalysis_Wire saw;
  saw.Init(w, f, Precision::Confusion());
  if (!saw.IsReady())
  {
    printf("%s: IsReady=0 (kernel cannot run the check)\n", label);
    return;
  }
  try
  {
    Handle(ShapeExtend_WireData) sewd = new ShapeExtend_WireData(w);
    double                       tc   = ShapeAnalysis::TotCross2D(sewd, f);
    printf("%s: IsReady=1 CheckOuterBound=%d TotCross2D=%.3e\n", label, (int)saw.CheckOuterBound(), tc);
  }
  catch (Standard_Failure& e)
  {
    printf("%s: throws %s\n", label, e.what());
  }
}

int main()
{
  // panelWithCentredWindow: 10x10 plane face with a 4x4 centred hole.
  Handle(Geom_Plane)      pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  BRepBuilderAPI_MakeFace mf(pl, poly(0, 10));
  TopoDS_Wire             hole = poly(3, 7);
  hole.Reverse();
  mf.Add(hole);
  TopoDS_Face panel = mf.Face();
  TopoDS_Wire panelOuter;
  for (TopExp_Explorer e(panel, TopAbs_WIRE); e.More(); e.Next())
  {
    panelOuter = TopoDS::Wire(e.Current());
    break;
  }

  // cylinderLateralFace: widest face of a r5 h20 cylinder.
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 20).Shape();
  TopoDS_Face  lateral;
  double       best = 0;
  for (TopExp_Explorer e(cyl, TopAbs_FACE); e.More(); e.Next())
  {
    GProp_GProps p;
    BRepGProp::SurfaceProperties(e.Current(), p);
    if (p.Mass() > best)
    {
      best    = p.Mass();
      lateral = TopoDS::Face(e.Current());
    }
  }
  printf("lateral area=%.9f (2 pi r h = %.9f)\n", best, 2 * M_PI * 5 * 20);
  TopoDS_Wire own = BRepTools::OuterWire(lateral);
  for (TopExp_Explorer e(lateral, TopAbs_WIRE); e.More(); e.Next())
  {
    own = TopoDS::Wire(e.Current());
    break;
  }

  check("cylinder's own wire on its lateral face", own, lateral);
  check("panel wire on cylinder lateral face", panelOuter, lateral);
  check("cylinder wire on planar panel", own, panel);
  BRep_Builder b;
  TopoDS_Wire  empty;
  b.MakeWire(empty);
  check("edgeless wire on panel", empty, panel);
  check("panel's own outer wire on panel (control)", panelOuter, panel);
  return 0;
}
