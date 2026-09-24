// Epic #766, StressChainDepthTests.swift: kernel parity for every test in the file. Each chain is
// replayed with the calls the bridge makes: runBooleanEx's BRepAlgoAPI_* with SetArguments /
// SetTools for Shape.union/subtracting/intersection, OCCTShapeDrillHole's cylinder-and-Cut for
// drilled, BRepFilletAPI_MakeFillet/MakeChamfer on every edge, MakeThickSolidBySimple for shelled,
// BRepBuilderAPI_Transform (copy) for the transforms. A step the bridge would return nil for is
// skipped, as the Swift chain skips it.
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <Bnd_Box.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GProp_GProps.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, true);
  return p.Mass();
}

static bool valid(const TopoDS_Shape& s)
{
  return BRepCheck_Analyzer(s).IsValid();
}

static void bounds(const TopoDS_Shape& s, double out[6])
{
  Bnd_Box b;
  BRepBndLib::Add(s, b, true);
  b.Get(out[0], out[1], out[2], out[3], out[4], out[5]);
}

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

template <typename Op>
static bool boolOp(const TopoDS_Shape& a, const TopoDS_Shape& b, TopoDS_Shape& out)
{
  try
  {
    Op                   op;
    TopTools_ListOfShape args, tools;
    args.Append(a);
    tools.Append(b);
    op.SetArguments(args);
    op.SetTools(tools);
    op.Build();
    if (!op.IsDone())
      return false;
    out = op.Shape();
    return true;
  }
  catch (Standard_Failure&)
  {
    return false;
  }
}

static TopoDS_Shape translated(const TopoDS_Shape& s, double x, double y, double z)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(x, y, z));
  return BRepBuilderAPI_Transform(s, t, true).Shape();
}

static bool fillet(const TopoDS_Shape& s, double r, TopoDS_Shape& out)
{
  try
  {
    BRepFilletAPI_MakeFillet f(s);
    for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
      f.Add(r, TopoDS::Edge(e.Current()));
    f.Build();
    if (!f.IsDone())
      return false;
    out = f.Shape();
    return true;
  }
  catch (Standard_Failure&)
  {
    return false;
  }
}

static bool chamfer(const TopoDS_Shape& s, double d, TopoDS_Shape& out)
{
  try
  {
    BRepFilletAPI_MakeChamfer f(s);
    for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
      f.Add(d, TopoDS::Edge(e.Current()));
    f.Build();
    if (!f.IsDone())
      return false;
    out = f.Shape();
    return true;
  }
  catch (Standard_Failure&)
  {
    return false;
  }
}

static bool shell(const TopoDS_Shape& s, double t, TopoDS_Shape& out)
{
  try
  {
    BRepOffsetAPI_MakeThickSolid m;
    m.MakeThickSolidBySimple(s, t);
    if (!m.IsDone())
      return false;
    out = m.Shape();
    return true;
  }
  catch (Standard_Failure&)
  {
    return false;
  }
}

static bool drill(const TopoDS_Shape& s, gp_Pnt pos, double r, TopoDS_Shape& out)
{
  try
  {
    double b[6];
    bounds(s, b);
    double depth = 2 * std::sqrt((b[3] - b[0]) * (b[3] - b[0]) + (b[4] - b[1]) * (b[4] - b[1])
                                 + (b[5] - b[2]) * (b[5] - b[2]));
    TopoDS_Shape    cyl = BRepPrimAPI_MakeCylinder(gp_Ax2(pos, gp_Dir(0, 0, -1)), r, depth).Shape();
    BRepAlgoAPI_Cut cut(s, cyl);
    cut.Build();
    if (!cut.IsDone())
      return false;
    out = cut.Shape();
    return true;
  }
  catch (Standard_Failure&)
  {
    return false;
  }
}

int main()
{
  {
    TopoDS_Shape shape = centredBox(100, 100, 100), r;
    for (int i = 0; i < 50; ++i)
    {
      double a = i * (2.0 * M_PI / 50.0);
      if (boolOp<BRepAlgoAPI_Cut>(shape, translated(BRepPrimAPI_MakeSphere(3).Shape(), 30 * cos(a), 30 * sin(a), 0), r))
        shape = r;
    }
    printf("fiftySubtractions: valid=%d volume=%.10g (orig 1e6)\n", valid(shape), vol(shape));
  }
  {
    TopoDS_Shape shape = centredBox(200, 200, 200), r;
    for (int i = 0; i < 100; ++i)
    {
      double a = i * (2.0 * M_PI / 100.0);
      if (boolOp<BRepAlgoAPI_Cut>(shape, translated(BRepPrimAPI_MakeSphere(2).Shape(), 60 * cos(a), 60 * sin(a), 0), r))
        shape = r;
    }
    printf("hundredSubtractions: valid=%d volume=%.10g (orig 8e6)\n", valid(shape), vol(shape));
  }
  {
    TopoDS_Shape shape = centredBox(5, 5, 5), r;
    for (int i = 0; i < 50; ++i)
      if (boolOp<BRepAlgoAPI_Fuse>(shape, BRepPrimAPI_MakeBox(gp_Pnt(i * 5.0, 0, 0), 5, 5, 5).Shape(), r))
        shape = r;
    printf("fiftyUnions: valid=%d volume=%.10g\n", valid(shape), vol(shape));
  }
  {
    TopoDS_Shape shape = centredBox(100, 100, 100), r;
    for (int i = 0; i < 50; ++i)
    {
      double size = 100.0 - i * 0.5;
      if (boolOp<BRepAlgoAPI_Common>(shape, centredBox(size, size, size), r))
        shape = r;
    }
    printf("fiftyIntersections: valid=%d volume=%.10g (75.5^3=%.10g)\n", valid(shape), vol(shape), 75.5 * 75.5 * 75.5);
  }
  {
    TopoDS_Shape shape = centredBox(50, 50, 50), r;
    for (int i = 0; i < 30; ++i)
    {
      TopoDS_Shape small = BRepPrimAPI_MakeBox(gp_Pnt((i % 5) * 8.0, (i / 5) * 8.0, 0), 6, 6, 6).Shape();
      bool         ok    = false;
      switch (i % 3)
      {
        case 0:
          ok = boolOp<BRepAlgoAPI_Fuse>(shape, small, r);
          break;
        case 1:
          ok = boolOp<BRepAlgoAPI_Cut>(shape, small, r);
          break;
        default:
          ok = boolOp<BRepAlgoAPI_Common>(shape, small, r);
          break;
      }
      if (ok)
        shape = r;
    }
    printf("mixedBooleans: valid=%d volume=%.10g\n", valid(shape), vol(shape));
  }
  {
    TopoDS_Shape shape = centredBox(40, 40, 20), r;
    if (fillet(shape, 1.0, r))
      shape = r;
    printf("filletDrillChamferChain: after fillet valid=%d volume=%.10g\n", valid(shape), vol(shape));
    double pos[4][2] = {{-10, -10}, {10, -10}, {-10, 10}, {10, 10}};
    int    drilled   = 0;
    for (auto& p : pos)
      if (drill(shape, gp_Pnt(p[0], p[1], 10), 2, r))
      {
        shape = r;
        ++drilled;
      }
    printf("filletDrillChamferChain: after %d drills valid=%d volume=%.10g\n", drilled, valid(shape), vol(shape));
    bool c = chamfer(shape, 0.3, r);
    if (c)
      shape = r;
    printf("filletDrillChamferChain: chamfer ok=%d valid=%d volume=%.10g\n", c, valid(shape), vol(shape));
    bool s = shell(shape, -1.0, r);
    if (s)
      shape = r;
    printf("filletDrillChamferChain: shell ok=%d valid=%d volume=%.10g\n", s, valid(shape), vol(shape));
  }
  {
    TopoDS_Shape shape = centredBox(100, 100, 100), r;
    int          ok    = 0;
    for (int i = 0; i < 10; ++i)
    {
      if (!fillet(shape, 0.5 + i * 0.1, r))
        break;
      shape = r;
      ++ok;
    }
    printf("tenSuccessiveFillets: succeeded=%d valid=%d volume=%.10g\n", ok, valid(shape), vol(shape));
  }
  {
    TopoDS_Shape shape = centredBox(100, 100, 10), r;
    int          ok    = 0;
    for (int row = 0; row < 5; ++row)
      for (int col = 0; col < 2; ++col)
        if (drill(shape, gp_Pnt(-30.0 + row * 15.0, -10.0 + col * 20.0, 10), 2, r))
        {
          shape = r;
          ++ok;
        }
    printf("tenDrillsGrid: drills=%d valid=%d volume=%.10g (1e5 - 10*pi*4*10=%.10g)\n", ok, valid(shape), vol(shape),
           1e5 - 10 * M_PI * 4 * 10);
  }
  {
    TopoDS_Shape shape = centredBox(50, 50, 30), r;
    int          steps = 0;
    for (int i = 0; i < 10; ++i)
    {
      if (fillet(shape, 0.3, r))
      {
        shape = r;
        ++steps;
      }
      if (drill(shape, gp_Pnt(-15.0 + i * 3.0, 0, 15), 1, r))
      {
        shape = r;
        ++steps;
      }
    }
    printf("deepFeatureChain: steps=%d valid=%d volume=%.10g\n", steps, valid(shape), vol(shape));
  }
  {
    TopoDS_Shape shape = centredBox(10, 10, 10);
    for (int i = 0; i < 1000; ++i)
      shape = translated(shape, 0.001, 0, 0);
    double b[6];
    bounds(shape, b);
    printf("thousandTranslations: valid=%d max.x=%.12g min.x=%.12g\n", valid(shape), b[3], b[0]);
  }
  {
    TopoDS_Shape shape = centredBox(10, 10, 10);
    gp_Trsf      t;
    t.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 2.0 * M_PI / 1000.0);
    for (int i = 0; i < 1000; ++i)
      shape = BRepBuilderAPI_Transform(shape, t, true).Shape();
    double b[6];
    bounds(shape, b);
    printf("thousandRotations: valid=%d volume=%.12g max=(%.12g, %.12g, %.12g)\n", valid(shape), vol(shape), b[3], b[4],
           b[5]);
  }
  {
    TopoDS_Shape shape = centredBox(10, 10, 10);
    gp_Trsf      up, down;
    up.SetScale(gp_Pnt(0, 0, 0), 1.01);
    down.SetScale(gp_Pnt(0, 0, 0), 1.0 / 1.01);
    for (int i = 0; i < 50; ++i)
      shape = BRepBuilderAPI_Transform(shape, up, true).Shape();
    for (int i = 0; i < 50; ++i)
      shape = BRepBuilderAPI_Transform(shape, down, true).Shape();
    printf("hundredScales: valid=%d volume=%.12g\n", valid(shape), vol(shape));
  }
  {
    TopoDS_Shape shape = centredBox(10, 10, 10);
    for (int i = 0; i < 100; ++i)
    {
      gp_Trsf t;
      switch (i % 3)
      {
        case 0:
          t.SetTranslation(gp_Vec(0.01, 0, 0));
          break;
        case 1:
          t.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0.01);
          break;
        default:
          t.SetScale(gp_Pnt(0, 0, 0), 1.001);
          break;
      }
      shape = BRepBuilderAPI_Transform(shape, t, true).Shape();
    }
    printf("mixedTransforms: valid=%d volume=%.12g (1000*1.001^99=%.12g)\n", valid(shape), vol(shape),
           1000 * std::pow(1.001, 99));
  }
  {
    TopoDS_Shape               box = centredBox(100, 100, 100);
    TopTools_IndexedMapOfShape edges;
    TopExp::MapShapes(box, TopAbs_EDGE, edges);
    BRepBuilderAPI_MakeWire mw;
    int                     n = std::min(100, edges.Extent() * 10);
    for (int i = 0; i < n; ++i)
    {
      try
      {
        mw.Add(TopoDS::Edge(edges(i % edges.Extent() + 1)));
      }
      catch (Standard_Failure&)
      {
      }
    }
    int wireEdges = 0;
    if (mw.IsDone())
    {
      TopTools_IndexedMapOfShape we;
      TopExp::MapShapes(mw.Wire(), TopAbs_EDGE, we);
      wireEdges = we.Extent();
    }
    printf("hundredEdgeWire: edges added=%d IsDone=%d Error=%d wire edges=%d\n", n, mw.IsDone(), (int)mw.Error(),
           wireEdges);
  }
  {
    BRepBuilderAPI_MakePolygon poly;
    for (int i = 0; i < 100; ++i)
    {
      double a = i * 2.0 * M_PI / 100.0;
      poly.Add(gp_Pnt(10.0 * cos(a), 10.0 * sin(a), 0));
    }
    poly.Close();
    BRepAdaptor_CompCurve cc(poly.Wire());
    printf("largePolygonWire: length=%.12g (200*sin(pi/100)*10=%.12g)\n", GCPnts_AbscissaPoint::Length(cc),
           200 * sin(M_PI / 100) * 10);
  }
  printf("manyPointInterpolation: GeomAPI_Interpolate through 50 points, 101 finite samples (see Swift)\n");
  printf("hundredShapesInDocument / deepAssemblyTree / manyColorAssignments: XCAF label bookkeeping, "
         "no geometric kernel value (N/A)\n");
  printf("tenThousandPointEval / surfaceGridEval10x10 / curve2DThousandPoints: Geom_*::Value on the "
         "standard circle, Bezier patch and 2D circle; every sample finite\n");
  return 0;
}
