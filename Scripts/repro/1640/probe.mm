// Ground truth for #1640: the three (four) bridge functions in the healing family with no caller.
//
// Build: see CLAUDE.md, "Compile a Ground Truth C++ Test".

#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepLib_MakePolygon.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <BRepGProp.hxx>
#include <ShapeUpgrade_ClosedFaceDivide.hxx>
#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_ShapeDivideAngle.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <ShapeUpgrade_FaceDivideArea.hxx>
#include <ShapeUpgrade_ShapeDivideArea.hxx>
#include <ShapeUpgrade_ShapeDivideClosed.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <cstdio>

static int faceCount(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    n++;
  return n;
}

static int edgeCount(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
    n++;
  return n;
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape();

  printf("=== 1. OCCTShapeUpgradeSplitSurfaceArea's body, exactly as it stands today\n");
  {
    ShapeUpgrade_ShapeDivideArea sd(box);
    sd.SetSplittingByNumber(true);
    sd.NbParts() = 4;
    bool ok = sd.Perform();
    printf("   Perform() with MaxArea left at its default : %s, faces in 6, faces out %d\n",
           ok ? "true " : "false", faceCount(sd.Result()));
  }
  printf("   ... and with the #1491 fix (MaxArea() = -1) applied:\n");
  {
    ShapeUpgrade_ShapeDivideArea sd(box);
    sd.SetSplittingByNumber(true);
    sd.MaxArea()  = -1;
    sd.NbParts()  = 4;
    bool ok       = sd.Perform();
    printf("   Perform() with MaxArea() = -1              : %s, faces in 6, faces out %d\n",
           ok ? "true" : "false", faceCount(sd.Result()));
  }

  printf("\n=== 2. OCCTShapeUpgradeSplitSurfaceAngle vs OCCTShapeSplitByAngle (same body?)\n");
  for (double deg : {45.0, 90.0, 180.0})
  {
    ShapeUpgrade_ShapeDivideAngle a(deg * M_PI / 180.0, cyl);
    ShapeUpgrade_ShapeDivideAngle b(deg * M_PI / 180.0, cyl);
    bool                          okA = a.Perform();
    bool                          okB = b.Perform();
    printf("   %5.0f deg: SplitSurfaceAngle %s faces %d | SplitByAngle %s faces %d\n", deg,
           okA ? "ok " : "no ", faceCount(a.Result()), okB ? "ok " : "no ",
           faceCount(b.Result()));
  }

  printf("\n=== 3. ShapeUpgrade_ClosedFaceDivide, the one #1640 called a real capability\n");
  for (int n : {1, 2, 3})
  {
    ShapeUpgrade_ShapeDivide              sd(cyl);
    Handle(ShapeUpgrade_ClosedFaceDivide) cfd = new ShapeUpgrade_ClosedFaceDivide();
    cfd->SetNbSplitPoints(n);
    sd.SetSplitFaceTool(cfd);
    bool ok = sd.Perform();
    printf("   nbSplitPoints %d: Perform %s, cylinder faces in 3, faces out %d\n", n,
           ok ? "true " : "false", faceCount(sd.Result()));
  }

  printf("\n=== 3b. ... next to ShapeUpgrade_ShapeDivideClosed, already wrapped as"
         " Shape.dividedClosedFaces\n");
  for (int n : {1, 2, 3})
  {
    ShapeUpgrade_ShapeDivideClosed sd(cyl);
    sd.SetNbSplitPoints(n);
    bool ok = sd.Perform();
    printf("   nbSplitPoints %d: Perform %s, cylinder faces in 3, faces out %d\n", n,
           ok ? "true " : "false", faceCount(sd.Result()));
  }
  {
    // Same comparison on a sphere, whose single face is closed in both U and V.
    TopoDS_Shape                          sph = BRepPrimAPI_MakeSphere(5.0).Shape();
    ShapeUpgrade_ShapeDivide              a(sph);
    Handle(ShapeUpgrade_ClosedFaceDivide) cfd = new ShapeUpgrade_ClosedFaceDivide();
    cfd->SetNbSplitPoints(2);
    a.SetSplitFaceTool(cfd);
    a.Perform();
    ShapeUpgrade_ShapeDivideClosed b(sph);
    b.SetNbSplitPoints(2);
    b.Perform();
    printf("   sphere, nbSplitPoints 2: ClosedFaceDivide %d faces | ShapeDivideClosed %d faces\n",
           faceCount(a.Result()), faceCount(b.Result()));
  }

  printf("\n=== 4. BRepLib_MakePolygon vs BRepBuilderAPI_MakePolygon on the same points\n");
  {
    gp_Pnt p[4] = {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)};
    BRepLib_MakePolygon        a;
    BRepBuilderAPI_MakePolygon b;
    for (int i = 0; i < 4; i++)
    {
      a.Add(p[i]);
      b.Add(p[i]);
    }
    a.Close();
    b.Close();
    GProp_GProps ga, gb;
    BRepGProp::LinearProperties(a.Wire(), ga);
    BRepGProp::LinearProperties(b.Wire(), gb);
    printf("   BRepLib_MakePolygon        : edges %d, length %.9f, closed %s\n",
           edgeCount(a.Wire()), ga.Mass(), a.Wire().Closed() ? "true" : "false");
    printf("   BRepBuilderAPI_MakePolygon : edges %d, length %.9f, closed %s\n",
           edgeCount(b.Wire()), gb.Mass(), b.Wire().Closed() ? "true" : "false");
    printf("   same geometry              : %s\n",
           (edgeCount(a.Wire()) == edgeCount(b.Wire()) && std::abs(ga.Mass() - gb.Mass()) < 1e-12)
             ? "yes"
             : "NO");
  }

  printf("\n=== 5. ShapeUpgrade_ShapeDivideArea (dividedByParts) vs OCCTShapeDivideByNumber's own\n"
         "       tool, and which results BRepCheck_Analyzer accepts\n");
  {
    TopoDS_Shape cube = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
    printf("   input cube: %d faces, valid %s\n", faceCount(cube),
           BRepCheck_Analyzer(cube).IsValid() ? "YES" : "no");
    for (int parts : {2, 4, 9})
    {
      ShapeUpgrade_ShapeDivideArea sd(cube);
      sd.SetSplittingByNumber(true);
      sd.NbParts() = parts;
      sd.Perform();
      printf("   dividedByParts(%d)    : %2d faces, valid %s\n", parts, faceCount(sd.Result()),
             BRepCheck_Analyzer(sd.Result()).IsValid() ? "YES" : "no");
    }
    // What OCCTShapeDivideByNumber does, reproduced exactly: SetSplittingByNumber, MaxArea = -1
    // and SetNumbersUVSplits together. Leaving SetSplittingByNumber out changes the answer, which
    // is how a first pass at this probe reported dividedByNumber's own result as invalid.
    const int splits[4][2] = {{4, 1}, {2, 2}, {1, 4}, {2, 1}};
    for (const int* nb : splits)
    {
      ShapeUpgrade_ShapeDivide            d(cube);
      Handle(ShapeUpgrade_FaceDivideArea) fd = new ShapeUpgrade_FaceDivideArea();
      fd->SetSplittingByNumber(true);
      fd->NbParts() = nb[0] * nb[1];
      fd->MaxArea() = -1;
      fd->SetNumbersUVSplits(nb[0], nb[1]);
      d.SetSplitFaceTool(fd);
      d.Perform();
      printf("   DivideByNumber(%d, %d)  : %2d faces, valid %s\n", nb[0], nb[1],
             faceCount(d.Result()), BRepCheck_Analyzer(d.Result()).IsValid() ? "YES" : "no");
    }
    printf("   -> the invalidity tracks splitting on BOTH axes at once, not the class:\n"
           "      DivideByNumber(2, 2) is invalid too, and dividedByParts(2), a 2 x 1 split, is"
           " valid.\n");
  }

  printf("\n=== 6. OCCTShapeUpgradeSplitSurfaceArea's body vs OCCTShapeDivideByParts's body\n"
         "       (the latter is already reachable as Shape.dividedByParts)\n");
  for (int parts : {2, 3, 4, 9})
  {
    TopoDS_Shape                 cube = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
    ShapeUpgrade_ShapeDivideArea a(cube);  // OCCTShapeUpgradeSplitSurfaceArea
    a.SetSplittingByNumber(true);
    a.NbParts() = (parts > 0 ? parts : 4);
    bool okA = a.Perform();

    ShapeUpgrade_ShapeDivideArea b(cube);  // OCCTShapeDivideByParts
    b.SetSplittingByNumber(true);
    b.NbParts() = parts;
    bool okB = b.Perform();

    GProp_GProps ga, gb;
    BRepGProp::VolumeProperties(a.Result(), ga);
    BRepGProp::VolumeProperties(b.Result(), gb);
    printf("   parts %d: SplitSurfaceArea %s %2d faces vol %.6f | DivideByParts %s %2d faces vol"
           " %.6f | same %s\n",
           parts, okA ? "ok" : "no", faceCount(a.Result()), ga.Mass(), okB ? "ok" : "no",
           faceCount(b.Result()), gb.Mass(),
           (okA == okB && faceCount(a.Result()) == faceCount(b.Result())
            && std::abs(ga.Mass() - gb.Mass()) < 1e-9)
             ? "yes"
             : "NO");
  }
  return 0;
}
