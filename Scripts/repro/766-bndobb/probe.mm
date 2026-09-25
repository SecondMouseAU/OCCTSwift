// #766 kernel parity for Tests/OCCTAnalysisTests/BndOBBTests.swift.
// Each block builds the Bnd_OBB the matching OCCTOBB* bridge function builds and queries it the
// same way (OCCTBridge_Topology_BoundingBox.mm).
#include <BRepBndLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Bnd_Box.hxx>
#include <Bnd_OBB.hxx>
#include <cstdio>

static Bnd_OBB axisOBB(double cx, double cy, double cz, double hx, double hy, double hz)
{
  // OCCTOBBCreate
  return Bnd_OBB(gp_Pnt(cx, cy, cz), gp_Dir(1, 0, 0), gp_Dir(0, 1, 0), gp_Dir(0, 0, 1), hx, hy, hz);
}

int main()
{
  // createAndQuery
  Bnd_OBB a = axisOBB(0, 0, 0, 5, 3, 2);
  printf("createAndQuery: IsVoid=%d center=(%.17g, %.17g, %.17g) half=(%.17g, %.17g, %.17g)\n",
         a.IsVoid() ? 1 : 0, a.Center().X(), a.Center().Y(), a.Center().Z(),
         a.XHSize(), a.YHSize(), a.ZHSize());

  // pointInOut
  Bnd_OBB b = axisOBB(0, 0, 0, 5, 5, 5);
  printf("pointInOut: IsOut(1,1,1)=%d IsOut(10,10,10)=%d\n",
         b.IsOut(gp_Pnt(1, 1, 1)) ? 1 : 0, b.IsOut(gp_Pnt(10, 10, 10)) ? 1 : 0);

  // obbOverlap, plus a disjoint partner for the other polarity
  Bnd_OBB o1   = axisOBB(0, 0, 0, 5, 5, 5);
  Bnd_OBB o2   = axisOBB(4, 0, 0, 3, 3, 3);
  Bnd_OBB far_ = axisOBB(20, 0, 0, 3, 3, 3);
  printf("obbOverlap: o1.IsOut(o2 at x=4)=%d o1.IsOut(o at x=20)=%d\n",
         o1.IsOut(o2) ? 1 : 0, o1.IsOut(far_) ? 1 : 0);

  // fromShape: OCCTOBBCreateFromShape = BRepBndLib::Add then Bnd_OBB(Bnd_Box).
  // Shape.box(width:10,height:10,depth:10) is centred on the origin (OCCTShapeCreateBox).
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  Bnd_Box      bb;
  BRepBndLib::Add(box, bb);
  Bnd_OBB fs(bb);
  printf("fromShape: IsVoid=%d center=(%.17g, %.17g, %.17g) half=(%.17g, %.17g, %.17g) "
         "SquareExtent=%.17g\n",
         fs.IsVoid() ? 1 : 0, fs.Center().X(), fs.Center().Y(), fs.Center().Z(),
         fs.XHSize(), fs.YHSize(), fs.ZHSize(), fs.SquareExtent());

  // enlarge
  Bnd_OBB e = axisOBB(0, 0, 0, 1, 1, 1);
  e.Enlarge(2.0);
  printf("enlarge: half=(%.17g, %.17g, %.17g)\n", e.XHSize(), e.YHSize(), e.ZHSize());
  return 0;
}
