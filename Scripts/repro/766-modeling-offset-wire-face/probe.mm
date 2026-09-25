// Epic #766, Tests/OCCTModelingTests/OffsetWireFaceTests.swift: kernel parity for all three tests.
// OCCTOffsetWireOnPlane is BRepOffsetAPI_MakeOffset(wire, join).Perform(distance) (join Arc or
// Intersection); face.offsetFace(distance:) resolves to OCCTBRepOffsetOffsetFace, which is
// BRepOffset_Offset(face, offset, false, GeomAbs_Arc).Face().
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <BRepOffset_Offset.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Wire rect(double w, double h)
{
  gp_Pnt                  p1(-w / 2, -h / 2, 0), p2(w / 2, -h / 2, 0), p3(w / 2, h / 2, 0), p4(-w / 2, h / 2, 0);
  BRepBuilderAPI_MakeWire mw;
  mw.Add(BRepBuilderAPI_MakeEdge(p1, p2).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p2, p3).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p3, p4).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p4, p1).Edge());
  return mw.Wire();
}

static void wireOff(const char* label, double d, GeomAbs_JoinType j)
{
  BRepOffsetAPI_MakeOffset mo(rect(10, 10), j);
  mo.Perform(d);
  printf("%s: done=%d", label, mo.IsDone());
  if (mo.IsDone())
    for (TopExp_Explorer ex(mo.Shape(), TopAbs_WIRE); ex.More(); ex.Next())
    {
      BRepAdaptor_CompCurve c(TopoDS::Wire(ex.Current()));
      printf(" wire length=%.10g", GCPnts_AbscissaPoint::Length(c));
    }
  printf("\n");
}

int main()
{
  wireOff("offsetWire (arc, 2)", 2, GeomAbs_Arc);
  wireOff("offsetWireIntersection (1)", 1, GeomAbs_Intersection);
  TopoDS_Face       f = BRepBuilderAPI_MakeFace(rect(20, 20), Standard_True).Face();
  BRepOffset_Offset o(f, 2.0, false, GeomAbs_Arc);
  TopoDS_Face       r = o.Face();
  printf("offsetFace (2): null=%d", r.IsNull());
  if (!r.IsNull())
  {
    GProp_GProps p;
    BRepGProp::SurfaceProperties(r, p);
    printf(" area=%.10g centre z=%g", p.Mass(), p.CentreOfMass().Z());
  }
  printf("\n");
  return 0;
}
