// Epic #766, Issue838FindSurfaceConsolidationTests.swift: kernel parity for the four tests.
// BRepLib_FindSurface (as occtRunFindSurface calls it) on the lateral-face wire of
// BRepPrimAPI_MakeCylinder(5, 10) and on the four-segment quad with one corner lifted 0.4.
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepLib_FindSurface.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <cstdio>

static void run(const char* name, const TopoDS_Shape& w, double tol, bool onlyPlane)
{
  BRepLib_FindSurface f(w, tol, onlyPlane);
  printf("%s tol=%g onlyPlane=%d: Found=%d", name, tol, onlyPlane, f.Found());
  if (f.Found())
    printf(" type=%d (GeomAbs_Plane=0, Cylinder=1) ToleranceReached=%.3g Existed=%d", (int)GeomAdaptor_Surface(f.Surface()).GetType(),
           f.ToleranceReached(), f.Existed());
  printf("\n");
}

int main()
{
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(BRepPrimAPI_MakeCylinder(5, 10).Shape(), TopAbs_FACE, faces);
  TopoDS_Shape lateral;
  for (int i = 1; i <= faces.Extent(); i++)
    if (BRepAdaptor_Surface(TopoDS::Face(faces(i))).GetType() == GeomAbs_Cylinder)
      lateral = faces(i);
  TopTools_IndexedMapOfShape wires;
  TopExp::MapShapes(lateral, TopAbs_WIRE, wires);
  run("cylinder lateral wire", wires(1), 0.5, false);
  run("cylinder lateral wire", wires(1), 0.5, true);
  gp_Pnt                  p[5] = {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0.4), gp_Pnt(0, 10, 0), gp_Pnt(0, 0, 0)};
  BRepBuilderAPI_MakeWire mw;
  for (int i = 0; i < 4; i++)
    mw.Add(BRepBuilderAPI_MakeEdge(p[i], p[i + 1]).Edge());
  run("quad, corner lifted 0.4", mw.Wire(), 1e-6, false);
  run("quad, corner lifted 0.4", mw.Wire(), 5.0, false);
  return 0;
}
