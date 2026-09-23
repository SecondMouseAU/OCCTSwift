// #766 kernel parity for Tests/OCCTAnalysisTests/BRepBndLibTests.swift.
// Calls the OCCT API each bridge function wraps, with the fixtures each test builds.
#include <BRepAlgoAPI_Common.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <Bnd_Box.hxx>
#include <Bnd_OBB.hxx>
#include <gp_Ax1.hxx>
#include <gp_Trsf.hxx>
#include <cmath>
#include <cstdio>

// Shape.box(width:height:depth:) -> OCCTShapeCreateBox: centred on the origin.
static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

// occtComputeBoundingBox (OCCTBridge_Internal.h), shared by OCCTShapeBoundingBox,
// OCCTShapeBoundingBoxOptimal and OCCTShapeGetBounds.
static void printBox(const char* label, const TopoDS_Shape& s, bool optimal, bool useTol)
{
  Bnd_Box box;
  if (optimal)
    BRepBndLib::AddOptimal(s, box, true, useTol);
  else
    BRepBndLib::Add(s, box, true);
  if (box.IsVoid())
  {
    printf("%s: IsVoid=1\n", label);
    return;
  }
  double x0, y0, z0, x1, y1, z1;
  box.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: IsVoid=0 min=(%.17g, %.17g, %.17g) max=(%.17g, %.17g, %.17g)\n",
         label, x0, y0, z0, x1, y1, z1);
}

// OCCTShapeOrientedBoundingBox, which OCCTShapeOrientedBoundingBoxDetailed delegates to.
static void printOBB(const char* label, const TopoDS_Shape& s, bool optimal)
{
  Bnd_OBB obb;
  BRepBndLib::AddOBB(s, obb, true, optimal, true);
  if (obb.IsVoid())
  {
    printf("%s: IsVoid=1\n", label);
    return;
  }
  gp_XYZ c = obb.Center();
  printf("%s: center=(%.17g, %.17g, %.17g) half=(%.17g, %.17g, %.17g)\n",
         label, c.X(), c.Y(), c.Z(), obb.XHSize(), obb.YHSize(), obb.ZHSize());
}

int main()
{
  TopoDS_Shape box      = centredBox(10, 20, 30);
  TopoDS_Shape sphere10 = BRepPrimAPI_MakeSphere(10).Shape();
  TopoDS_Shape sphere5  = BRepPrimAPI_MakeSphere(5).Shape();

  printBox("shapeBoundingBox (Add)", box, false, false);
  printBox("shapeBoundingBoxOptimal (AddOptimal, useShapeTolerance=false)", box, true, false);
  printBox("shapeBoundingBoxOptimalWithTolerance (AddOptimal, useShapeTolerance=true)", box, true, true);
  printOBB("orientedBoundingBoxDetailed (AddOBB, optimal=false)", box, false);
  printOBB("orientedBoundingBoxDetailedOptimal sphere r=5 (AddOBB, optimal=true)", sphere5, true);
  printOBB("orientedBoundingBoxDetailedOptimal sphere r=5 (AddOBB, optimal=false)", sphere5, false);

  gp_Trsf rot;
  rot.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 6);
  TopoDS_Shape rotated = BRepBuilderAPI_Transform(box, rot, Standard_True).Shape();
  printOBB("orientedBoundingBoxDetailedMatchesPacked rotated box (AddOBB, optimal=false)", rotated, false);

  printBox("boundingBoxSphere r=10 (Add)", sphere10, false, false);

  // makeVoidShape(): Shape.box(width:10,...) is centred; Shape.box(origin:(1000,1000,1000),...)
  TopoDS_Shape       b1 = centredBox(10, 10, 10);
  TopoDS_Shape       b2 = BRepPrimAPI_MakeBox(gp_Pnt(1000, 1000, 1000), 10, 10, 10).Shape();
  BRepAlgoAPI_Common common(b1, b2);
  common.Build();
  printf("voidShape: Common IsDone=%d\n", common.IsDone() ? 1 : 0);
  printBox("voidShape (Add)", common.Shape(), false, false);

  TopoDS_Shape v = BRepBuilderAPI_MakeVertex(gp_Pnt(0, 0, 0)).Vertex();
  printBox("pointVertexAtOrigin (AddOptimal)", v, true, false);
  printBox("pointVertexAtOrigin (Add)", v, false, false);
  return 0;
}
