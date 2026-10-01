// Epic #766, Tests/OCCTModelingTests/HalfSpaceTests.swift: kernel parity for its one test.
// OCCTShapeCreateHalfSpace is BRepPrimAPI_MakeHalfSpace(face, refPoint).Solid() on the first face
// of its argument. Same input: a planar face on the 20x20 rectangle Wire.rectangle builds (centred
// at the origin, z = 0), reference point (0, 0, 5).
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepPrimAPI_MakeHalfSpace.hxx>
#include <TopoDS_Solid.hxx>
#include <cstdio>

int main()
{
  gp_Pnt                  p1(-10, -10, 0), p2(10, -10, 0), p3(10, 10, 0), p4(-10, 10, 0);
  BRepBuilderAPI_MakeWire w;
  w.Add(BRepBuilderAPI_MakeEdge(p1, p2));
  w.Add(BRepBuilderAPI_MakeEdge(p2, p3));
  w.Add(BRepBuilderAPI_MakeEdge(p3, p4));
  w.Add(BRepBuilderAPI_MakeEdge(p4, p1));
  BRepBuilderAPI_MakeFace   mf(w.Wire(), Standard_True);
  BRepPrimAPI_MakeHalfSpace hs(mf.Face(), gp_Pnt(0, 0, 5));
  TopoDS_Solid              s = hs.Solid();
  BRepClass3d_SolidClassifier above(s, gp_Pnt(0, 0, 5), 1e-7), below(s, gp_Pnt(0, 0, -5), 1e-7);
  printf("halfSpaceFromFace: faceDone=%d done=%d null=%d state(0,0,5)=%d state(0,0,-5)=%d "
         "(0=IN,1=OUT)\n",
         mf.IsDone(), hs.IsDone(), s.IsNull(), (int)above.State(), (int)below.State());
  return 0;
}
