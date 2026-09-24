// Epic #766 kernel-parity probe for Tests/OCCTMathTests/GeometryConstructionTests.swift.
// Builds the same wires and faces the bridge builds (OCCTWireCreateRectangle,
// OCCTWireCreateCircleEx, OCCTShapeCreateFaceFromWire, OCCTShapeCreateFaceWithHoles,
// OCCTShapeCreateExtrusion) and measures them the way OCCTShapeGetSurfaceArea and
// OCCTShapeGetVolume do.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS.hxx>
#include <gp_Circ.hxx>
#include <cstdio>

static TopoDS_Wire rect(double w, double h)
{
  double hw = w / 2, hh = h / 2;
  gp_Pnt p1(-hw, -hh, 0), p2(hw, -hh, 0), p3(hw, hh, 0), p4(-hw, hh, 0);
  BRepBuilderAPI_MakeWire mw;
  mw.Add(BRepBuilderAPI_MakeEdge(p1, p2));
  mw.Add(BRepBuilderAPI_MakeEdge(p2, p3));
  mw.Add(BRepBuilderAPI_MakeEdge(p3, p4));
  mw.Add(BRepBuilderAPI_MakeEdge(p4, p1));
  return mw.Wire();
}

static TopoDS_Wire circ(double r)
{
  gp_Circ c(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), r);
  return BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(c)).Wire();
}

static TopoDS_Wire shifted(const TopoDS_Wire& w, double dx)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(dx, 0, 0));
  return TopoDS::Wire(BRepBuilderAPI_Transform(w, t, Standard_True).Shape());
}

static double area(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::SurfaceProperties(s, p);
  return p.Mass();
}

static void report(const char* name, const TopoDS_Shape& s)
{
  printf("%s: valid=%d area=%.10f\n", name, BRepCheck_Analyzer(s).IsValid() ? 1 : 0, area(s));
}

int main()
{
  report("faceFromRectangle", BRepBuilderAPI_MakeFace(rect(10, 5), true).Face());
  report("faceFromCircle", BRepBuilderAPI_MakeFace(circ(5), true).Face());

  // Both holes are wound the same way as the outer (counter-clockwise), so the bridge
  // reverses each one before adding it.
  {
    BRepBuilderAPI_MakeFace mf(rect(20, 20), true);
    mf.Add(TopoDS::Wire(circ(5).Reversed()));
    report("faceWithHole", mf.Face());
  }
  {
    BRepBuilderAPI_MakeFace mf(rect(30, 30), true);
    mf.Add(TopoDS::Wire(shifted(circ(3), -8).Reversed()));
    mf.Add(TopoDS::Wire(shifted(circ(3), 8).Reversed()));
    report("faceWithMultipleHoles", mf.Face());
  }
  {
    BRepBuilderAPI_MakeFace fm(rect(10, 5));
    BRepPrimAPI_MakePrism   pr(fm.Face(), gp_Vec(0, 0, 3));
    GProp_GProps            p;
    BRepGProp::VolumeProperties(pr.Shape(), p, true);
    printf("extrudeFace: valid=%d volume=%.10f\n",
           BRepCheck_Analyzer(pr.Shape()).IsValid() ? 1 : 0,
           p.Mass());
  }
  return 0;
}
