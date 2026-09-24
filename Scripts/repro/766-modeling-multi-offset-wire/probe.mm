// Epic #766, Tests/OCCTModelingTests/MultiOffsetWireTests.swift: kernel parity for all three tests.
// OCCTWireMultiOffset takes the first face of the shape, builds one BRepOffsetAPI_MakeOffset(face,
// GeomAbs_Arc) and calls Perform(offset_i) per offset, collecting every wire of each result.
// Faces are Shape.face(from: Wire.rectangle(w, h)): a planar face on a centred rectangle.
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <vector>

static TopoDS_Face rectFace(double w, double h)
{
  gp_Pnt                  p1(-w / 2, -h / 2, 0), p2(w / 2, -h / 2, 0), p3(w / 2, h / 2, 0), p4(-w / 2, h / 2, 0);
  BRepBuilderAPI_MakeWire mw;
  mw.Add(BRepBuilderAPI_MakeEdge(p1, p2).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p2, p3).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p3, p4).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p4, p1).Edge());
  return BRepBuilderAPI_MakeFace(mw.Wire(), Standard_True).Face();
}

static void multi(const char* label, double size, std::vector<double> offs)
{
  BRepOffsetAPI_MakeOffset mo(rectFace(size, size), GeomAbs_Arc);
  printf("%s:", label);
  int n = 0;
  for (double o : offs)
  {
    mo.Perform(o);
    if (!mo.IsDone())
    {
      printf(" [offset %g: not done]", o);
      continue;
    }
    for (TopExp_Explorer ex(mo.Shape(), TopAbs_WIRE); ex.More(); ex.Next(), n++)
    {
      BRepAdaptor_CompCurve c(TopoDS::Wire(ex.Current()));
      printf(" [offset %g: wire length %.10g]", o, GCPnts_AbscissaPoint::Length(c));
    }
  }
  printf(" total wires=%d\n", n);
}

int main()
{
  multi("multipleInwardOffsets", 20, {-1, -2, -3});
  multi("outwardOffset", 10, {1, 2});
  multi("emptyOffsets as a single 0 offset (injection comparison)", 10, {0});
  return 0;
}
