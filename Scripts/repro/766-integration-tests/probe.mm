// Epic #766, issue #1988: kernel parity for all 19 tests in
// Tests/OCCTIntegrationTests/OCCTIntegrationTests.swift. Each block feeds OCCT the same inputs the
// Swift test does, through the same classes the bridge function calls:
//   OCCTMathKronrodIntegration[Adaptive] -> math_KronrodSingleIntegration
//   OCCTMathGaussMultipleIntegration     -> math_GaussMultipleIntegration
//   OCCTMathGaussSetIntegration          -> math_GaussSetIntegration
//   OCCTShapeCreateBox / BoxAt           -> BRepPrimAPI_MakeBox (centred / at a corner)
//   OCCTShapeUnionEx / SubtractEx        -> BRepAlgoAPI_Fuse / BRepAlgoAPI_Cut (args + tools)
//   OCCTShapeFillet / Chamfer            -> BRepFilletAPI_MakeFillet / MakeChamfer on every edge
//   OCCTShapeDrillHole                   -> BRepPrimAPI_MakeCylinder(gp_Ax2) of 2x bbox diagonal,
//                                           then BRepAlgoAPI_Cut
//   OCCTShapeShell                       -> BRepOffsetAPI_MakeThickSolid::MakeThickSolidBySimple
//   OCCTShapeSectionWiresAtZ             -> BRepAlgoAPI_Section + ConnectEdgesToWires
//   OCCTWireGetLength                    -> GCPnts_AbscissaPoint::Length on BRepAdaptor_CompCurve
//   OCCTWireOffset                       -> BRepBuilderAPI_MakeFace + BRepOffsetAPI_MakeOffset
//   OCCTShapeOrientedBoundingBox         -> BRepBndLib::AddOBB
//   OCCTShapeGetBounds                   -> BRepBndLib::Add (useTriangulation)
//   OCCTSurfaceGetGaussianCurvature      -> GeomLProp_SLProps(order 2, Precision::Confusion())
//   OCCTShapeToBREPString / FromBREPString -> BRepTools::Write / Read on string streams
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <Bnd_Box.hxx>
#include <Bnd_OBB.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GProp_GProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <OSD.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_HSequenceOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <math_Function.hxx>
#include <math_FunctionSet.hxx>
#include <math_GaussMultipleIntegration.hxx>
#include <math_GaussSetIntegration.hxx>
#include <math_IntegerVector.hxx>
#include <math_KronrodSingleIntegration.hxx>
#include <math_MultipleVarFunction.hxx>
#include <math_Vector.hxx>
#include <cmath>
#include <cstdio>
#include <sstream>
#include <string>
#include <vector>
#include <sys/wait.h>
#include <unistd.h>

// ---- helpers mirroring the bridge -----------------------------------------------------------

static double volumeOf(const TopoDS_Shape& s) // OCCTShapeGetVolume (nil when Mass() == 0)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, true);
  return p.Mass();
}

static int countOf(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static void describe(const char* label, bool ok, const TopoDS_Shape& s)
{
  if (!ok)
  {
    printf("%s nil\n", label);
    return;
  }
  printf("%s vol=%.10f valid=%d f=%d e=%d\n",
         label,
         volumeOf(s),
         BRepCheck_Analyzer(s).IsValid() ? 1 : 0,
         countOf(s, TopAbs_FACE),
         countOf(s, TopAbs_EDGE));
}

static TopoDS_Shape boxCentered(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static TopoDS_Shape boxAt(double x, double y, double z, double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(x, y, z), w, h, d).Shape();
}

template <class Op>
static bool boolean(const TopoDS_Shape& a, const TopoDS_Shape& b, TopoDS_Shape& out)
{
  Op                   op;
  TopTools_ListOfShape args, tools;
  args.Append(a);
  tools.Append(b);
  op.SetArguments(args);
  op.SetTools(tools);
  op.SetGlue(BOPAlgo_GlueOff);
  op.Build();
  if (!op.IsDone())
    return false;
  out = op.Shape();
  return true;
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
  catch (Standard_Failure& e)
  {
    printf("  [caught %s: %s]\n", e.ExceptionType(), e.what());
    return false;
  }
  catch (...)
  {
    printf("  [caught non-OCCT exception]\n");
    return false;
  }
}

static bool chamfer(const TopoDS_Shape& s, double d, TopoDS_Shape& out)
{
  try
  {
    BRepFilletAPI_MakeChamfer c(s);
    for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
      c.Add(d, TopoDS::Edge(e.Current()));
    c.Build();
    if (!c.IsDone())
      return false;
    out = c.Shape();
    return true;
  }
  catch (Standard_Failure& e)
  {
    printf("  [caught %s: %s]\n", e.ExceptionType(), e.what());
    return false;
  }
  catch (...)
  {
    printf("  [caught non-OCCT exception]\n");
    return false;
  }
}

// OCCTShapeDrillHole with depth 0: a cylinder along dir of length 2 x bbox diagonal, cut.
static bool drill(const TopoDS_Shape& s, gp_Pnt pos, gp_Dir dir, double r, TopoDS_Shape& out)
{
  try
  {
    Bnd_Box b;
    BRepBndLib::Add(s, b);
    double x0, y0, z0, x1, y1, z1;
    b.Get(x0, y0, z0, x1, y1, z1);
    double          depth = 2 * std::sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0) + (z1 - z0) * (z1 - z0));
    TopoDS_Shape    cyl   = BRepPrimAPI_MakeCylinder(gp_Ax2(pos, dir), r, depth).Shape();
    BRepAlgoAPI_Cut cut(s, cyl);
    cut.Build();
    if (!cut.IsDone())
      return false;
    out = cut.Shape();
    return true;
  }
  catch (Standard_Failure& e)
  {
    printf("  [caught %s: %s]\n", e.ExceptionType(), e.what());
    return false;
  }
  catch (...)
  {
    printf("  [caught non-OCCT exception]\n");
    return false;
  }
}

static bool shell(const TopoDS_Shape& s, double t, TopoDS_Shape& out)
{
  try
  {
    BRepOffsetAPI_MakeThickSolid ts;
    ts.MakeThickSolidBySimple(s, t);
    if (!ts.IsDone())
      return false;
    out = ts.Shape();
    return true;
  }
  catch (Standard_Failure& e)
  {
    printf("  [caught %s: %s]\n", e.ExceptionType(), e.what());
    return false;
  }
  catch (...)
  {
    printf("  [caught non-OCCT exception]\n");
    return false;
  }
}

static double wireLength(const TopoDS_Wire& w)
{
  BRepAdaptor_CompCurve c(w);
  return GCPnts_AbscissaPoint::Length(c, c.FirstParameter(), c.LastParameter());
}

static std::vector<TopoDS_Wire> sectionWires(const TopoDS_Shape& s, double z)
{
  std::vector<TopoDS_Wire> out;
  BRepAlgoAPI_Section      sec(s, gp_Pln(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1)));
  sec.Build();
  if (!sec.IsDone())
    return out;
  Handle(TopTools_HSequenceOfShape) edges = new TopTools_HSequenceOfShape;
  for (TopExp_Explorer e(sec.Shape(), TopAbs_EDGE); e.More(); e.Next())
    edges->Append(e.Current());
  if (edges->Length() == 0)
    return out;
  Handle(TopTools_HSequenceOfShape) wires = new TopTools_HSequenceOfShape;
  ShapeAnalysis_FreeBounds::ConnectEdgesToWires(edges, 1e-6, false, wires);
  for (int i = 1; i <= wires->Length(); i++)
    out.push_back(TopoDS::Wire(wires->Value(i)));
  return out;
}

static void printSection(const char* label, const TopoDS_Shape& s, double z)
{
  std::vector<TopoDS_Wire> w = sectionWires(s, z);
  printf("%s z=%g n=%zu lens=[", label, z, w.size());
  for (size_t i = 0; i < w.size(); i++)
    printf("%s%.12f", i ? ", " : "", wireLength(w[i]));
  printf("]\n");
}

// ---- math adapters, as in OCCTBridge_Spatial_MathSolvers.mm ---------------------------------

class SinFn : public math_Function
{
public:
  bool Value(const double x, double& f) override
  {
    f = std::sin(x);
    return true;
  }
};

class Quad2 : public math_MultipleVarFunction
{
public:
  int NbVariables() const override { return 2; }

  bool Value(const math_Vector& X, double& F) override
  {
    F = X(1) * X(1) + X(2) * X(2);
    return true;
  }
};

class XAndX2 : public math_FunctionSet
{
public:
  int NbVariables() const override { return 1; }

  int NbEquations() const override { return 2; }

  bool Value(const math_Vector& X, math_Vector& F) override
  {
    F(1) = X(1);
    F(2) = X(1) * X(1);
    return true;
  }
};

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  // The Swift process runs this too: occtEnsureSignals() calls OSD::SetSignal(false) on the first
  // boolean, which turns a SIGSEGV inside OCCT into an OSD_SIGSEGV exception the bridge's
  // catch (...) swallows. Without it, the bracket chamfer below kills this probe outright.
  OSD::SetSignal(Standard_False);
  // KronrodIntegration
  {
    SinFn                         f;
    math_KronrodSingleIntegration k(f, 0.0, M_PI, 15);
    printf("integrateSin done=%d value=%.17g err=%.6g\n", k.IsDone(), k.Value(), k.ErrorReached());
    math_KronrodSingleIntegration a(f, 0.0, M_PI, 15, 1e-10, 100);
    printf("adaptive done=%d value=%.17g err=%.6g iter=%d\n",
           a.IsDone(),
           a.Value(),
           a.ErrorReached(),
           a.NbIterReached());
  }
  // GaussMultipleIntegration
  {
    Quad2              f;
    math_Vector        lo(1, 2, 0.0), up(1, 2, 1.0);
    math_IntegerVector ord(1, 2, 10);
    math_GaussMultipleIntegration g(f, lo, up, ord);
    printf("integrate2D done=%d value=%.17g\n", g.IsDone(), g.Value());
  }
  // GaussSetIntegration
  {
    XAndX2                   f;
    math_Vector              lo(1, 1, 0.0), up(1, 1, 2.0);
    math_IntegerVector       ord(1, 1, 10);
    math_GaussSetIntegration g(f, lo, up, ord);
    printf("integrateSet done=%d values=[%.17g, %.17g]\n", g.IsDone(), g.Value()(1), g.Value()(2));
  }

  // Mounting bracket
  {
    TopoDS_Shape base = boxCentered(80, 40, 5), wall = boxAt(-40, -2.5, 2.5, 80, 5, 30), br, cur, t;
    describe("bracket base", true, base);
    describe("bracket wall", true, wall);
    bool ok = boolean<BRepAlgoAPI_Fuse>(base, wall, br);
    describe("bracket union", ok, br);
    cur     = br;
    bool fo = fillet(br, 1.0, t);
    describe("bracket fillet", fo, t);
    if (fo)
      cur = t;
    const double pos[4][2] = {{-30, -12}, {30, -12}, {-30, 12}, {30, 12}};
    for (auto& p : pos)
    {
      bool d = drill(cur, gp_Pnt(p[0], p[1], 5), gp_Dir(0, 0, -1), 3, t);
      char label[64];
      snprintf(label, sizeof label, "bracket drill (%g,%g)", p[0], p[1]);
      describe(label, d, t);
      if (d)
        cur = t;
    }
    bool c = chamfer(cur, 0.5, t);
    describe("bracket chamfer", c, t);
  }

  // Fluent composition chain
  {
    TopoDS_Shape b = boxCentered(20, 20, 10), f, d, c, s;
    describe("fluent box", true, b);
    bool ok = fillet(b, 1.0, f);
    describe("fluent fillet", ok, f);
    ok = ok && drill(f, gp_Pnt(0, 0, 5), gp_Dir(0, 0, -1), 3, d);
    describe("fluent drill", ok, d);
    ok = ok && chamfer(d, 0.3, c);
    describe("fluent chamfer", ok, c);
    bool so = ok && shell(c, -1.0, s);
    describe("fluent shell", so, s);
  }

  // Z-level slicing
  {
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(25, 50).Shape(), t;
    const double pos[3][2] = {{10, 0}, {-10, 0}, {0, 10}};
    for (auto& p : pos)
    {
      bool d = drill(cyl, gp_Pnt(p[0], p[1], 55), gp_Dir(0, 0, -1), 3, t);
      char label[64];
      snprintf(label, sizeof label, "cylholes drill (%g,%g)", p[0], p[1]);
      describe(label, d, t);
      if (d)
        cyl = t;
    }
    for (int i = 1; i <= 10; i++)
      printSection("cylholes", cyl, i * 5.0);
  }

  // Hole detection
  {
    TopoDS_Shape plate = boxCentered(100, 100, 10), t;
    const double pos[4][2] = {{-25, -25}, {25, -25}, {-25, 25}, {25, 25}};
    for (auto& p : pos)
    {
      bool d = drill(plate, gp_Pnt(p[0], p[1], 10), gp_Dir(0, 0, -1), 5, t);
      char label[64];
      snprintf(label, sizeof label, "plate drill (%g,%g)", p[0], p[1]);
      describe(label, d, t);
      if (d)
        plate = t;
    }
    printSection("plate", plate, 0.0);
  }

  // Degenerate resilience
  {
    TopoDS_Shape b10 = boxCentered(10, 10, 10), t;
    bool         ok  = fillet(b10, 20, t);
    describe("oversizedFillet r=20", ok, t);
    for (double r : {4.0, 4.9, 5.0, 5.1, 6.0})
    {
      char label[64];
      snprintf(label, sizeof label, "fillet10 r=%g", r);
      bool o = fillet(b10, r, t);
      describe(label, o, t);
    }
    TopoDS_Shape b20 = boxCentered(20, 20, 20);
    ok               = drill(b20, gp_Pnt(0, 0, 10), gp_Dir(0, 0, -1), 3, t);
    describe("zeroDepthDrill", ok, t);
    ok = boolean<BRepAlgoAPI_Fuse>(b10, b10, t);
    describe("selfUnion", ok, t);
  }

  // OBB tightness
  {
    TopoDS_Shape b = boxCentered(40, 10, 10);
    gp_Trsf      tr;
    tr.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 4);
    TopoDS_Shape r = BRepBuilderAPI_Transform(b, tr, true).Shape();
    Bnd_Box      bb;
    BRepBndLib::Add(r, bb, true);
    double x0, y0, z0, x1, y1, z1;
    bb.Get(x0, y0, z0, x1, y1, z1);
    printf("obb aabb min=(%.10f, %.10f, %.10f) max=(%.10f, %.10f, %.10f) vol=%.6f\n",
           x0, y0, z0, x1, y1, z1,
           (x1 - x0) * (y1 - y0) * (z1 - z0));
    Bnd_OBB obb;
    BRepBndLib::AddOBB(r, obb, true, true, true);
    printf("obb optimal half=(%.10f, %.10f, %.10f) vol=%.6f\n",
           obb.XHSize(), obb.YHSize(), obb.ZHSize(),
           8 * obb.XHSize() * obb.YHSize() * obb.ZHSize());
  }

  // Memory stress: the value the loop reads
  describe("box10x20x30", true, boxCentered(10, 20, 30));

  // Pocket clearing
  {
    TopoDS_Shape ob = boxCentered(100, 100, 30), ib = boxAt(-30, -30, -5, 60, 60, 20), pk;
    describe("pocket outer", true, ob);
    bool ok = boolean<BRepAlgoAPI_Cut>(ob, ib, pk);
    describe("pocket", ok, pk);
    std::vector<TopoDS_Wire> w = sectionWires(pk, 0.0);
    printSection("pocket", pk, 0.0);
    for (size_t i = 0; i < w.size(); i++)
    {
      BRepBuilderAPI_MakeFace fm(w[i], true);
      if (!fm.IsDone())
      {
        printf("pocket offset[%zu] nil (MakeFace)\n", i);
        continue;
      }
      BRepOffsetAPI_MakeOffset mo(fm.Face(), GeomAbs_Arc);
      mo.Perform(-5.0);
      TopExp_Explorer ex;
      if (mo.IsDone())
        ex.Init(mo.Shape(), TopAbs_WIRE);
      if (!mo.IsDone() || !ex.More())
      {
        printf("pocket offset[%zu] nil\n", i);
        continue;
      }
      printf("pocket offset[%zu] len=%.12f\n", i, wireLength(TopoDS::Wire(ex.Current())));
    }
  }

  // Scallop analysis
  {
    Handle(Geom_SphericalSurface) s   = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 20);
    const double                  uv[5][2] = {{0.5, 0.5}, {1.0, 0.8}, {1.5, 1.2}, {2.0, 0.3}, {0.3, 1.5}};
    for (auto& p : uv)
    {
      GeomLProp_SLProps pr(s, p[0], p[1], 2, Precision::Confusion());
      printf("sphereK (%g,%g) defined=%d K=%.17g\n", p[0], p[1], pr.IsCurvatureDefined(), pr.GaussianCurvature());
    }
    const double z[4][4] = {{0, 2, 1, 0}, {1, 5, 3, 1}, {0, 3, 8, 2}, {0, 1, 2, 0}};
    TColgp_Array2OfPnt poles(1, 4, 1, 4);
    for (int i = 0; i < 4; i++)
      for (int j = 0; j < 4; j++)
        poles.SetValue(i + 1, j + 1, gp_Pnt(10.0 * j, 10.0 * i, z[i][j]));
    Handle(Geom_BezierSurface) bz = new Geom_BezierSurface(poles);
    double                     u0, u1, v0, v1;
    bz->Bounds(u0, u1, v0, v1);
    GeomLProp_SLProps g1(bz, u0 + 0.1, v0 + 0.1, 2, Precision::Confusion());
    GeomLProp_SLProps g2(bz, (u0 + u1) / 2, (v0 + v1) / 2, 2, Precision::Confusion());
    printf("bezier domain=(%g,%g,%g,%g) g1 defined=%d K=%.17g g2 defined=%d K=%.17g\n",
           u0, u1, v0, v1,
           g1.IsCurvatureDefined(), g1.GaussianCurvature(),
           g2.IsCurvatureDefined(), g2.GaussianCurvature());
  }

  // Bottle profile
  {
    TopoDS_Shape body = BRepPrimAPI_MakeCylinder(15, 40).Shape();
    gp_Trsf      tr;
    tr.SetTranslation(gp_Vec(0, 0, 40));
    TopoDS_Shape cap = BRepBuilderAPI_Transform(BRepPrimAPI_MakeSphere(15).Shape(), tr, true).Shape(), bot, f, s;
    describe("bottle body", true, body);
    describe("bottle cap", true, cap);
    bool ok = boolean<BRepAlgoAPI_Fuse>(body, cap, bot);
    describe("bottle union", ok, bot);
    bool fo = fillet(bot, 2.0, f);
    describe("bottle fillet", fo, f);
    bool so = shell(fo ? f : bot, -2.0, s);
    describe("bottle shell", so, s);
  }

  // Cross-section regression
  {
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(25, 50).Shape();
    printf("cylsec [");
    for (int i = 1; i <= 20; i++)
    {
      std::vector<TopoDS_Wire> w = sectionWires(cyl, i * (50.0 / 21.0));
      printf("%s%zu:%.12f", i > 1 ? ", " : "", w.size(), w.empty() ? -1.0 : wireLength(w[0]));
    }
    printf("]\n");
  }

  // Tolerance cascade
  {
    TopoDS_Shape b1 = boxAt(0, 0, 0, 10, 10, 10), b2 = boxAt(10, 0, 0, 10, 10, 10),
                 b4 = boxAt(10.000001, 0, 0, 10, 10, 10), t;
    bool ok = boolean<BRepAlgoAPI_Fuse>(b1, b2, t);
    describe("tol shared", ok, t);
    printf("tol shared solids=%d\n", countOf(t, TopAbs_SOLID));
    ok = boolean<BRepAlgoAPI_Fuse>(b1, b4, t);
    describe("tol gapped", ok, t);
    printf("tol gapped solids=%d\n", countOf(t, TopAbs_SOLID));
  }

  // Format fidelity BREP
  {
    TopoDS_Shape s = boxCentered(30, 20, 15), t;
    if (fillet(s, 2.0, t))
      s = t;
    describe("brep fillet", true, s);
    if (drill(s, gp_Pnt(0, 0, 10), gp_Dir(0, 0, -1), 3, t))
      s = t;
    describe("brep drill", true, s);
    GProp_GProps a;
    BRepGProp::SurfaceProperties(s, a);
    printf("brep orig area=%.10f\n", a.Mass());
    std::ostringstream oss;
    BRepTools::Write(s, oss);
    std::istringstream iss(oss.str());
    BRep_Builder       bld;
    TopoDS_Shape       r;
    BRepTools::Read(r, iss, bld);
    describe("brep rt", !r.IsNull(), r);
    GProp_GProps ra;
    BRepGProp::SurfaceProperties(r, ra);
    printf("brep rt area=%.10f len=%zu\n", ra.Mass(), oss.str().size());

    // Side finding from the Red run: a truncated BREP string (first half only) handed to
    // OCCTShapeFromBREPString took the whole test process down. Same read, in a child process.
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0)
    {
      std::istringstream half(oss.str().substr(0, oss.str().size() / 2));
      TopoDS_Shape       h;
      try
      {
        BRepTools::Read(h, half, bld);
        printf("brep truncated read returned, null=%d\n", h.IsNull() ? 1 : 0);
      }
      catch (Standard_Failure& e)
      {
        printf("brep truncated read threw %s: %s\n", e.ExceptionType(), e.what());
      }
      catch (...)
      {
        printf("brep truncated read threw a non-OCCT exception\n");
      }
      fflush(stdout);
      _exit(0);
    }
    int status = 0;
    waitpid(pid, &status, 0);
    if (WIFSIGNALED(status))
      printf("brep truncated read: child killed by signal %d\n", WTERMSIG(status));
    else
      printf("brep truncated read: child exited %d\n", WEXITSTATUS(status));
  }
  return 0;
}
