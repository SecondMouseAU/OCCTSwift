// Epic #766, StressBoundaryConditionTests.swift: kernel parity for every test in the file.
// Each block drives the calls the bridge makes (see 766-stress-chain-depth/probe.mm for the
// mapping), with the test's own inputs. A thrown Standard_Failure is what the bridge's catch turns
// into nil.
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_Circle.hxx>
#include <Poly_Triangulation.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>
#include <functional>

static bool   gHas;
static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, true);
  gHas = p.Mass() != 0.0 && p.Mass() >= 0;
  return p.Mass();
}

static int faces(const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_FACE, m);
  return m.Extent();
}

static void describe(const char* label, const TopoDS_Shape& s)
{
  double v = vol(s);
  printf("%s: valid=%d volume=%s%.12g faces=%d\n", label, BRepCheck_Analyzer(s).IsValid(), gHas ? "" : "nil/", v,
         faces(s));
}

static void attempt(const char* label, const std::function<bool(TopoDS_Shape&)>& fn)
{
  TopoDS_Shape out;
  try
  {
    if (fn(out))
      describe(label, out);
    else
      printf("%s: not done (nil)\n", label);
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw (nil): %s\n", label, e.GetMessageString());
  }
}

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

template <typename Op>
static bool boolOp(const TopoDS_Shape& a, const TopoDS_Shape& b, TopoDS_Shape& out)
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

static bool fillet(const TopoDS_Shape& s, double r, TopoDS_Shape& out)
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

static bool chamfer(const TopoDS_Shape& s, double d, TopoDS_Shape& out)
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

static bool shell(const TopoDS_Shape& s, double t, TopoDS_Shape& out)
{
  BRepOffsetAPI_MakeThickSolid m;
  m.MakeThickSolidBySimple(s, t);
  if (!m.IsDone())
    return false;
  out = m.Shape();
  return true;
}

static bool drill(const TopoDS_Shape& s, gp_Pnt pos, gp_Dir dir, double r, double depth, TopoDS_Shape& out)
{
  if (r <= Precision::Confusion())
  {
    printf("  (radius %g refused by occtValidDrillRadius)\n", r);
    return false;
  }
  if (depth <= 0)
  {
    Bnd_Box b;
    BRepBndLib::Add(s, b);
    double x0, y0, z0, x1, y1, z1;
    b.Get(x0, y0, z0, x1, y1, z1);
    depth = 2 * std::sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0) + (z1 - z0) * (z1 - z0));
  }
  TopoDS_Shape    cyl = BRepPrimAPI_MakeCylinder(gp_Ax2(pos, dir), r, depth).Shape();
  BRepAlgoAPI_Cut cut(s, cyl);
  cut.Build();
  if (!cut.IsDone())
    return false;
  out = cut.Shape();
  return true;
}

static TopoDS_Shape xform(const TopoDS_Shape& s, const gp_Trsf& t)
{
  return BRepBuilderAPI_Transform(s, t, true).Shape();
}

static int meshNodes(const TopoDS_Shape& s, double defl)
{
  BRepMesh_IncrementalMesh m(s, defl, false, 0.5);
  int                      n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
  {
    TopLoc_Location loc;
    auto            t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), loc);
    n += t.IsNull() ? 0 : t->NbNodes();
  }
  return n;
}

int main()
{
  TopoDS_Shape box = centredBox(10, 10, 10);
  printf("== Micro\n");
  attempt("microBox1e6", [](TopoDS_Shape& o) { o = centredBox(1e-6, 1e-6, 1e-6); return true; });
  attempt("microBox1e9", [](TopoDS_Shape& o) { o = centredBox(1e-9, 1e-9, 1e-9); return true; });
  attempt("microCylinder", [](TopoDS_Shape& o) { o = BRepPrimAPI_MakeCylinder(1e-6, 1e-6).Shape(); return true; });
  attempt("microSphere", [](TopoDS_Shape& o) { o = BRepPrimAPI_MakeSphere(1e-6).Shape(); return true; });
  attempt("microBoolean", [](TopoDS_Shape& o) {
    return boolOp<BRepAlgoAPI_Cut>(centredBox(1e-4, 1e-4, 1e-4), centredBox(0.5e-4, 0.5e-4, 0.5e-4), o);
  });
  attempt("microFillet", [](TopoDS_Shape& o) { return fillet(centredBox(1e-3, 1e-3, 1e-3), 1e-4, o); });
  printf("microMesh: nodes=%d\n", meshNodes(centredBox(1e-4, 1e-4, 1e-4), 1e-5));

  printf("== Macro\n");
  attempt("macroBox1e6", [](TopoDS_Shape& o) { o = centredBox(1e6, 1e6, 1e6); return true; });
  attempt("macroBox1e9", [](TopoDS_Shape& o) { o = centredBox(1e9, 1e9, 1e9); return true; });
  attempt("macroCylinder", [](TopoDS_Shape& o) { o = BRepPrimAPI_MakeCylinder(1e6, 1e6).Shape(); return true; });
  attempt("macroSphere", [](TopoDS_Shape& o) { o = BRepPrimAPI_MakeSphere(1e6).Shape(); return true; });
  attempt("macroBoolean", [](TopoDS_Shape& o) {
    return boolOp<BRepAlgoAPI_Cut>(centredBox(1e6, 1e6, 1e6), centredBox(0.5e6, 0.5e6, 0.5e6), o);
  });
  attempt("macroFillet", [](TopoDS_Shape& o) { return fillet(centredBox(1e4, 1e4, 1e4), 100, o); });

  printf("== Mixed\n");
  attempt("largeBoxTinyHole", [](TopoDS_Shape& o) {
    return drill(centredBox(1000, 1000, 1000), gp_Pnt(0, 0, 500), gp_Dir(0, 0, -1), 0.01, 0, o);
  });
  attempt("largeBoxMicroFillet", [](TopoDS_Shape& o) { return fillet(centredBox(1000, 1000, 1000), 0.001, o); });
  {
    gp_Trsf t;
    t.SetTranslation(gp_Vec(1e6, 1e6, 1e6));
    TopoDS_Shape s = xform(centredBox(1, 1, 1), t);
    Bnd_Box      b;
    BRepBndLib::Add(s, b, true);
    double x0, y0, z0, x1, y1, z1;
    b.Get(x0, y0, z0, x1, y1, z1);
    describe("tinyBoxLargeOffset", s);
    printf("tinyBoxLargeOffset: max.x=%.12g min.x=%.12g\n", x1, x0);
  }
  attempt("largeBoxSmallSubtract", [](TopoDS_Shape& o) {
    return boolOp<BRepAlgoAPI_Cut>(centredBox(100, 100, 100), centredBox(0.1, 0.1, 0.1), o);
  });

  printf("== Coincident\n");
  attempt("identicalBoxUnion", [&](TopoDS_Shape& o) { return boolOp<BRepAlgoAPI_Fuse>(box, centredBox(10, 10, 10), o); });
  attempt("identicalBoxSubtract", [&](TopoDS_Shape& o) { return boolOp<BRepAlgoAPI_Cut>(box, centredBox(10, 10, 10), o); });
  attempt("identicalBoxIntersect",
          [&](TopoDS_Shape& o) { return boolOp<BRepAlgoAPI_Common>(box, centredBox(10, 10, 10), o); });
  TopoDS_Shape right = BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 10, 10, 10).Shape();
  attempt("touchingFaceUnion", [&](TopoDS_Shape& o) { return boolOp<BRepAlgoAPI_Fuse>(box, right, o); });
  attempt("touchingFaceSubtract", [&](TopoDS_Shape& o) { return boolOp<BRepAlgoAPI_Cut>(box, right, o); });
  TopoDS_Shape ovl = BRepPrimAPI_MakeBox(gp_Pnt(5, 5, 5), 10, 10, 10).Shape();
  attempt("overlappingBoxes union", [&](TopoDS_Shape& o) { return boolOp<BRepAlgoAPI_Fuse>(box, ovl, o); });
  attempt("overlappingBoxes cut", [&](TopoDS_Shape& o) { return boolOp<BRepAlgoAPI_Cut>(box, ovl, o); });
  attempt("overlappingBoxes common", [&](TopoDS_Shape& o) { return boolOp<BRepAlgoAPI_Common>(box, ovl, o); });
  attempt("nestedSpheres", [](TopoDS_Shape& o) {
    return boolOp<BRepAlgoAPI_Cut>(BRepPrimAPI_MakeSphere(10).Shape(), BRepPrimAPI_MakeSphere(5).Shape(), o);
  });
  printf("nestedSpheres: expected 4/3*pi*875=%.12g\n", 4.0 / 3.0 * M_PI * 875);
  attempt("concentricCylinders", [](TopoDS_Shape& o) {
    return boolOp<BRepAlgoAPI_Cut>(BRepPrimAPI_MakeCylinder(10, 20).Shape(), BRepPrimAPI_MakeCylinder(5, 20).Shape(), o);
  });
  printf("concentricCylinders: pi*(100-25)*20=%.12g\n", M_PI * 75 * 20);

  printf("== Degenerate\n");
  attempt("filletRadiusEqualsHalfEdge", [&](TopoDS_Shape& o) { return fillet(box, 5.0, o); });
  attempt("filletRadiusExceedsEdge", [&](TopoDS_Shape& o) { return fillet(box, 6.0, o); });
  attempt("shellThicknessEqualsHalf", [&](TopoDS_Shape& o) { return shell(box, -5.0, o); });
  attempt("shellThicknessExceedsHalf", [&](TopoDS_Shape& o) { return shell(box, -6.0, o); });
  {
    gp_Trsf t;
    t.SetTranslation(gp_Vec(0, 0, 0));
    describe("offsetByZero", xform(box, t));
    gp_Trsf r;
    r.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 2 * M_PI);
    describe("rotateByTwoPi", xform(box, r));
    gp_Trsf r2;
    r2.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1000.0 * M_PI);
    describe("rotateByLargeAngle", xform(box, r2));
    gp_Trsf s1;
    s1.SetScale(gp_Pnt(0, 0, 0), 1e-10);
    describe("scaleByVerySmall", xform(box, s1));
    gp_Trsf s2;
    s2.SetScale(gp_Pnt(0, 0, 0), 1e10);
    describe("scaleByVeryLarge", xform(box, s2));
  }
  attempt("drillRadiusLargerThanBox",
          [&](TopoDS_Shape& o) { return drill(box, gp_Pnt(0, 0, 5), gp_Dir(0, 0, -1), 20, 0, o); });
  attempt("drillOutsideBox", [&](TopoDS_Shape& o) { return drill(box, gp_Pnt(100, 100, 5), gp_Dir(0, 0, -1), 1, 5, o); });

  printf("== Near-degenerate\n");
  attempt("veryThinBox", [](TopoDS_Shape& o) { o = centredBox(100, 100, 0.001); return true; });
  attempt("verySmallFillet", [&](TopoDS_Shape& o) { return fillet(box, 1e-5, o); });
  attempt("verySmallChamfer", [&](TopoDS_Shape& o) { return chamfer(box, 1e-5, o); });
  attempt("nearlyTouchingBoxes", [&](TopoDS_Shape& o) {
    return boolOp<BRepAlgoAPI_Fuse>(box, BRepPrimAPI_MakeBox(gp_Pnt(10.000001, 0, 0), 10, 10, 10).Shape(), o);
  });
  attempt("nearlyCoincidentSubtract", [&](TopoDS_Shape& o) {
    return boolOp<BRepAlgoAPI_Cut>(box, BRepPrimAPI_MakeBox(gp_Pnt(1e-8, 1e-8, 1e-8), 10, 10, 10).Shape(), o);
  });
  attempt("veryThinShell", [&](TopoDS_Shape& o) { return shell(box, -0.001, o); });
  attempt("verySmallDrill", [&](TopoDS_Shape& o) { return drill(box, gp_Pnt(0, 0, 5), gp_Dir(0, 0, -1), 1e-5, 0, o); });

  printf("== Curve/Surface\n");
  {
    Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    gp_Pnt              a = c->Value(c->FirstParameter()), b = c->Value(c->LastParameter());
    printf("curveEvalAtDomainBounds: start=(%.12g, %.12g) end=(%.12g, %.12g)\n", a.X(), a.Y(), b.X(), b.Y());
    gp_Pnt p1 = c->Value(-0.001), p2 = c->Value(c->LastParameter() + 0.001);
    printf("curveEvalSlightlyOutside: p1=(%.17g, %.17g, %g) p2=(%.17g, %.17g, %g)\n", p1.X(), p1.Y(), p1.Z(), p2.X(),
           p2.Y(), p2.Z());
    printf("periodicCurveAtPeriodBoundary: |start-end|=%.3g\n", a.Distance(b));
  }
  {
    TColgp_Array2OfPnt poles(1, 4, 1, 4);
    double             z[4][4] = {{0, 0, 0, 0}, {0, 2, 2, 0}, {0, 2, 2, 0}, {0, 0, 0, 0}};
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        poles(i + 1, j + 1) = gp_Pnt(5.0 * j, 5.0 * i, z[i][j]);
    Handle(Geom_BezierSurface) s = new Geom_BezierSurface(poles);
    printf("surfaceEvalAtDomainCorners: corners (0,0)=(%g,%g,%g) (1,1)=(%g,%g,%g)\n", s->Value(0, 0).X(),
           s->Value(0, 0).Y(), s->Value(0, 0).Z(), s->Value(1, 1).X(), s->Value(1, 1).Y(), s->Value(1, 1).Z());
    GeomLProp_SLProps a(s, 0, 0, 2, Precision::Confusion()), b(s, 1, 1, 2, Precision::Confusion());
    printf("surfaceCurvatureAtBounds: curvatureDefined(0,0)=%d gaussian=%.12g curvatureDefined(1,1)=%d mean=%.12g\n",
           a.IsCurvatureDefined(), a.IsCurvatureDefined() ? a.GaussianCurvature() : NAN, b.IsCurvatureDefined(),
           b.IsCurvatureDefined() ? b.MeanCurvature() : NAN);
  }
  {
    Handle(Geom2d_Circle) c = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    gp_Pnt2d              a = c->Value(c->FirstParameter()), b = c->Value(c->LastParameter());
    printf("curve2DEvalAtDomainBounds: start=(%.12g, %.12g) end=(%.12g, %.12g)\n", a.X(), a.Y(), b.X(), b.Y());
  }
  {
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 5);
    pts->SetValue(1, gp_Pnt(0, 0, 0));
    pts->SetValue(2, gp_Pnt(3, 4, 0));
    pts->SetValue(3, gp_Pnt(8, 3, 0));
    pts->SetValue(4, gp_Pnt(12, 6, 0));
    pts->SetValue(5, gp_Pnt(15, 0, 0));
    GeomAPI_Interpolate interp(pts, false, Precision::Confusion());
    interp.Perform();
    Handle(Geom_BSplineCurve) bs = interp.Curve();
    GeomLProp_CLProps         a(bs, bs->FirstParameter(), 2, Precision::Confusion());
    GeomLProp_CLProps         b(bs, bs->LastParameter(), 2, Precision::Confusion());
    printf("curveCurvatureAtBounds: domain=[%g, %.12g] k(first)=%.12g k(last)=%.12g\n", bs->FirstParameter(),
           bs->LastParameter(), a.Curvature(), b.Curvature());
  }
  return 0;
}
