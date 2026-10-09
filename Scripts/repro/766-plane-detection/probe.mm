// Kernel parity probe for Tests/OCCTAnalysisTests/PlaneDetectionTests.swift (#766).
//
// Builds the same shapes the tests build (the centred 10x10 rectangle wire of
// OCCTWireCreateRectangle, the four-segment skew wire joined by BRepBuilderAPI_MakeWire as
// OCCTWireJoin does, and BRepBuilderAPI_MakeFace over the rectangle as
// OCCTShapeCreateFaceFromWire does) and runs BRepBuilderAPI_FindPlane with tolerance 1e-6, the
// call OCCTShapeFindPlane makes.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_FindPlane.hxx>
#include <Geom_Plane.hxx>
#include <gp_Pln.hxx>
#include <TopoDS_Wire.hxx>
#include <TopoDS_Face.hxx>
#include <cstdio>

static TopoDS_Wire polyline(const gp_Pnt* pts, int n)
{
  BRepBuilderAPI_MakeWire mw;
  for (int i = 0; i < n; i++)
    mw.Add(BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(pts[i], pts[(i + 1) % n])).Wire());
  return mw.Wire();
}

static void report(const char* name, const TopoDS_Shape& s)
{
  BRepBuilderAPI_FindPlane finder(s, 1e-6);
  printf("%s: Found=%d\n", name, finder.Found());
  if (finder.Found())
  {
    gp_Pln pln = finder.Plane()->Pln();
    gp_Dir n   = pln.Axis().Direction();
    gp_Pnt o   = pln.Location();
    printf("  normal=(%.17g, %.17g, %.17g)\n", n.X(), n.Y(), n.Z());
    printf("  origin=(%.17g, %.17g, %.17g)\n", o.X(), o.Y(), o.Z());
  }
}

int main()
{
  gp_Pnt      rect[4] = {gp_Pnt(-5, -5, 0), gp_Pnt(5, -5, 0), gp_Pnt(5, 5, 0), gp_Pnt(-5, 5, 0)};
  TopoDS_Wire rectWire = polyline(rect, 4);
  report("Planar wire finds plane", rectWire);

  gp_Pnt skew[4] = {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 5), gp_Pnt(0, 10, 10)};
  report("Non-planar 3D wire returns nil", polyline(skew, 4));

  BRepBuilderAPI_MakeFace mf(rectWire, true);
  printf("face IsDone=%d\n", mf.IsDone());
  report("Face shape is planar", mf.Face());
  return 0;
}
