// #766 kernel parity for OrientedBoundingBoxTests.swift and PointClassificationTests.swift.
//
// OBB: BRepBndLib::AddOBB(shape, obb, true, optimal, true), as OCCTShapeOrientedBoundingBox calls
// it, on the same shapes (Shape.box is BRepPrimAPI_MakeBox centred on the origin, Shape.sphere a
// BRepPrimAPI_MakeSphere at the origin, the rotated box a gp_Trsf rotation about +Z by pi/4).
// Classification: BRepClass3d_SolidClassifier and BRepClass_FaceClassifier with the tests' points
// and tolerances, as OCCTClassifyPointInSolid / OnFace / OnFaceUV call them.
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <Bnd_OBB.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_Surface.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Trsf.hxx>
#include <cstdio>

static const char* st(TopAbs_State s)
{
  switch (s)
  {
    case TopAbs_IN:
      return "IN";
    case TopAbs_OUT:
      return "OUT";
    case TopAbs_ON:
      return "ON";
    default:
      return "UNKNOWN";
  }
}

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static void obb(const char* label, const TopoDS_Shape& s, bool optimal, bool corners)
{
  Bnd_OBB b;
  BRepBndLib::AddOBB(s, b, true, optimal, true);
  printf("%s optimal=%d: void=%d half=(%.12g, %.12g, %.12g) volume=%.12g center=(%.6g, %.6g, %.6g)\n",
         label, optimal, b.IsVoid(), b.XHSize(), b.YHSize(), b.ZHSize(),
         8 * b.XHSize() * b.YHSize() * b.ZHSize(), b.Center().X(), b.Center().Y(), b.Center().Z());
  if (corners)
  {
    gp_Pnt p[8];
    b.GetVertex(p);
    for (int i = 0; i < 8; i++)
      printf("  vertex %d (%.12g, %.12g, %.12g) |p-c|=%.12g\n", i, p[i].X(), p[i].Y(), p[i].Z(),
             p[i].XYZ().Subtracted(b.Center()).Modulus());
  }
}

int main()
{
  TopoDS_Shape box = centredBox(10, 5, 3);
  obb("box 10x5x3 (obbAlignedBox)", box, false, false);
  obb("box 10x5x3 (obbOptimal)", box, true, false);

  gp_Trsf rot;
  rot.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 4);
  TopoDS_Shape rotated = BRepBuilderAPI_Transform(centredBox(10, 2, 2), rot, true).Shape();
  obb("box 10x2x2 rotated pi/4 about Z (obbTighterThanAABB)", rotated, false, false);
  Bnd_Box aabb;
  BRepBndLib::Add(rotated, aabb);
  double x0, y0, z0, x1, y1, z1;
  aabb.Get(x0, y0, z0, x1, y1, z1);
  printf("  AABB (BRepBndLib::Add) volume=%.12g\n", (x1 - x0) * (y1 - y0) * (z1 - z0));

  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(gp_Pnt(0, 0, 0), 5).Shape();
  obb("sphere r=5 (obbCorners, obbSphere)", sphere, false, true);

  TopoDS_Shape cube = centredBox(10, 10, 10);
  printf("solid classify cube 10 at (0,0,0) tol 1e-6: %s (pointInsideBox)\n",
         st(BRepClass3d_SolidClassifier(cube, gp_Pnt(0, 0, 0), 1e-6).State()));
  printf("solid classify cube 10 at (100,100,100) tol 1e-6: %s (pointOutsideBox)\n",
         st(BRepClass3d_SolidClassifier(cube, gp_Pnt(100, 100, 100), 1e-6).State()));
  printf("solid classify cube 10 at (0,0,5) tol 1e-3: %s (pointOnBoxFace)\n",
         st(BRepClass3d_SolidClassifier(cube, gp_Pnt(0, 0, 5), 1e-3).State()));
  TopoDS_Shape sphere10 = BRepPrimAPI_MakeSphere(gp_Pnt(0, 0, 0), 10).Shape();
  printf("solid classify sphere 10 at (1,1,1) tol 1e-6: %s (pointInsideSphere)\n",
         st(BRepClass3d_SolidClassifier(sphere10, gp_Pnt(1, 1, 1), 1e-6).State()));

  // faceClassifyPoint: the cube's x = -5 face, a point at its centre and one on its plane
  // but outside its boundary.
  for (TopExp_Explorer e(cube, TopAbs_FACE); e.More(); e.Next())
  {
    TopoDS_Face f = TopoDS::Face(e.Current());
    double      u0, u1, v0, v1;
    BRepTools::UVBounds(f, u0, u1, v0, v1);
    GeomLProp_SLProps p(BRep_Tool::Surface(f), (u0 + u1) / 2, (v0 + v1) / 2, 1, 1e-7);
    gp_Pnt            c = p.Value();
    if (std::abs(c.X() + 5) > 1e-9)
      continue;
    printf("face x=-5: classify (-5,0,0) tol 1e-6: %s; (-5,20,0): %s (faceClassifyPoint)\n",
           st(BRepClass_FaceClassifier(f, gp_Pnt(-5, 0, 0), 1e-6).State()),
           st(BRepClass_FaceClassifier(f, gp_Pnt(-5, 20, 0), 1e-6).State()));
  }

  // faceClassifyUV: faces()[0] of the 10x5x3 box, at the centre of its UV bounds; the
  // TopExp_Explorer order is the order Shape.faces() returns.
  TopExp_Explorer e(box, TopAbs_FACE);
  TopoDS_Face     f0 = TopoDS::Face(e.Current());
  double          u0, u1, v0, v1;
  BRepTools::UVBounds(f0, u0, u1, v0, v1);
  printf("box 10x5x3 face 0 UV [%g, %g]x[%g, %g], centre (%g, %g): %s; (u1 + 10, v1 + 10): %s "
         "(faceClassifyUV)\n",
         u0, u1, v0, v1, (u0 + u1) / 2, (v0 + v1) / 2,
         st(BRepClass_FaceClassifier(f0, gp_Pnt2d((u0 + u1) / 2, (v0 + v1) / 2), 1e-6).State()),
         st(BRepClass_FaceClassifier(f0, gp_Pnt2d(u1 + 10, v1 + 10), 1e-6).State()));
  return 0;
}
