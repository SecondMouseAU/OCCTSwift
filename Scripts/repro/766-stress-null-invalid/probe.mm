// Epic #766, StressNullInvalidTests.swift: kernel parity for every test in the file.
// Each block drives the OCCT calls the bridge function makes, with the test's own inputs.
// Calls the bridge guards against (the ones that crash or throw uncaught) run in a forked child
// so the probe survives them and reports how the child died.
#include <BOPAlgo_CellsBuilder.hxx>
#include <BOPAlgo_MakePeriodic.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffsetAPI_MakeDraft.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Direction.hxx>
#include <Geom_Plane.hxx>
#include <Poly_Triangulation.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <typeinfo>
#include <TopoDS.hxx>
#include <gce_MakeMirror.hxx>
#include <gce_MakeMirror2d.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Pln.hxx>
#include <cmath>
#include <csignal>
#include <cstdio>
#include <functional>
#include <sys/wait.h>
#include <unistd.h>

static bool volumeOf(const TopoDS_Shape& s, double& v)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, true);
  v = p.Mass();
  return v != 0.0 && v >= 0;
}

static double areaOf(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::SurfaceProperties(s, p);
  return p.Mass();
}

static bool validOf(const TopoDS_Shape& s)
{
  return BRepCheck_Analyzer(s).IsValid();
}

static int countOf(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static void describe(const char* label, const TopoDS_Shape& s)
{
  double v  = 0;
  bool   hv = volumeOf(s, v);
  printf("%s: valid=%d volume=%s%.10g faces=%d\n", label, validOf(s), hv ? "" : "nil/", v,
         countOf(s, TopAbs_FACE));
}

// Runs `fn` in a forked child and reports how it ended, for calls a bridge guard exists to keep
// away from the kernel.
static void inChild(const char* label, const std::function<void()>& fn)
{
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    try
    {
      fn();
      printf("%s: child returned normally\n", label);
    }
    catch (Standard_Failure& e)
    {
      printf("%s: child threw %s: %s\n", label, typeid(e).name(), e.GetMessageString());
    }
    catch (...)
    {
      printf("%s: child threw a non-OCCT exception\n", label);
    }
    fflush(stdout);
    _exit(0);
  }
  int status = 0;
  waitpid(pid, &status, 0);
  if (WIFSIGNALED(status))
    printf("%s: child killed by signal %d (%s)\n", label, WTERMSIG(status), strsignal(WTERMSIG(status)));
}

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static TopoDS_Shape filletAll(const TopoDS_Shape& s, double r, bool& done)
{
  BRepFilletAPI_MakeFillet f(s);
  for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
    f.Add(r, TopoDS::Edge(e.Current()));
  f.Build();
  done = f.IsDone();
  return done ? f.Shape() : TopoDS_Shape();
}

static TopoDS_Shape chamferAll(const TopoDS_Shape& s, double d, bool& done)
{
  BRepFilletAPI_MakeChamfer f(s);
  for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
    f.Add(d, TopoDS::Edge(e.Current()));
  f.Build();
  done = f.IsDone();
  return done ? f.Shape() : TopoDS_Shape();
}

template <typename Op>
static TopoDS_Shape boolOp(const TopoDS_Shape& a, const TopoDS_Shape& b, bool& done)
{
  Op                   op;
  TopTools_ListOfShape args, tools;
  args.Append(a);
  tools.Append(b);
  op.SetArguments(args);
  op.SetTools(tools);
  op.Build();
  done = op.IsDone();
  return done ? op.Shape() : TopoDS_Shape();
}

// OCCTShapeDrillHole: cylinder along dir from pos, depth = 2 * bbox diagonal, BRepAlgoAPI_Cut.
static TopoDS_Shape drill(const TopoDS_Shape& s, gp_Pnt pos, gp_Dir dir, double r, bool& done)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  double       depth = 2 * std::sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0) + (z1 - z0) * (z1 - z0));
  TopoDS_Shape cyl   = BRepPrimAPI_MakeCylinder(gp_Ax2(pos, dir), r, depth).Shape();
  BRepAlgoAPI_Cut cut(s, cyl);
  cut.Build();
  done = cut.IsDone();
  return done ? cut.Shape() : TopoDS_Shape();
}

static TopoDS_Shape shellBy(const TopoDS_Shape& s, double t, bool& done)
{
  BRepOffsetAPI_MakeThickSolid m;
  m.MakeThickSolidBySimple(s, t);
  done = m.IsDone();
  return done ? m.Shape() : TopoDS_Shape();
}

static TopoDS_Shape rectWire(double w, double h)
{
  gp_Pnt                  p1(-w / 2, -h / 2, 0), p2(w / 2, -h / 2, 0), p3(w / 2, h / 2, 0), p4(-w / 2, h / 2, 0);
  BRepBuilderAPI_MakeWire mw;
  mw.Add(BRepBuilderAPI_MakeEdge(p1, p2));
  mw.Add(BRepBuilderAPI_MakeEdge(p2, p3));
  mw.Add(BRepBuilderAPI_MakeEdge(p3, p4));
  mw.Add(BRepBuilderAPI_MakeEdge(p4, p1));
  return mw.Wire();
}

#define TRY(label, body)                                                                           \
  try                                                                                              \
  {                                                                                                \
    body                                                                                           \
  }                                                                                                \
  catch (Standard_Failure & e)                                                                     \
  {                                                                                                \
    printf("%s: threw %s: %s\n", label, typeid(e).name(), e.GetMessageString());             \
  }

int main()
{
  TopoDS_Shape box    = centredBox(10, 10, 10);
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5).Shape();
  bool         done   = false;

  printf("== Nil Propagation\n");
  {
    TopoDS_Shape f = filletAll(box, 999, done);
    printf("failedFilletFedToBoolean: fillet(999) IsDone=%d\n", done);
  }
  {
    TopoDS_Shape c = boolOp<BRepAlgoAPI_Cut>(box, sphere, done);
    describe("failedBooleanChain box-sphere", c);
    TopoDS_Shape f = filletAll(c, 0.5, done);
    printf("failedBooleanChain fillet(0.5) IsDone=%d\n", done);
    if (done)
      describe("failedBooleanChain filleted", f);
  }
  {
    TRY("drillAfterFailedShell", {
      TopoDS_Shape s = shellBy(box, -6, done);
      printf("drillAfterFailedShell: shell(-6) IsDone=%d\n", done);
      if (done)
      {
        describe("drillAfterFailedShell shelled", s);
        TopoDS_Shape d = drill(s, gp_Pnt(0, 0, 5), gp_Dir(0, 0, -1), 1, done);
        printf("drillAfterFailedShell drill IsDone=%d\n", done);
        if (done)
          describe("drillAfterFailedShell drilled", d);
      }
    })
  }
  {
    TopoDS_Shape f = filletAll(box, 0.5, done);
    printf("chamferAfterFailedFillet: fillet(0.5) IsDone=%d\n", done);
    describe("chamferAfterFailedFillet filleted", f);
    TRY("chamferAfterFailedFillet chamfer", {
      TopoDS_Shape c = chamferAll(f, 0.3, done);
      printf("chamferAfterFailedFillet: chamfer(0.3) IsDone=%d\n", done);
      if (done)
        describe("chamferAfterFailedFillet chamfered", c);
    })
  }
  describe("unionWithSelf", boolOp<BRepAlgoAPI_Fuse>(box, box, done));
  describe("subtractSelf", boolOp<BRepAlgoAPI_Cut>(box, box, done));
  printf("subtractSelf: IsDone=%d\n", done);
  {
    TopoDS_Shape b1 = centredBox(10, 10, 10);
    TopoDS_Shape b2 = BRepPrimAPI_MakeBox(gp_Pnt(100, 100, 100), 10, 10, 10).Shape();
    TopoDS_Shape r  = boolOp<BRepAlgoAPI_Common>(b1, b2, done);
    printf("intersectDisjoint: IsDone=%d null=%d\n", done, r.IsNull());
    describe("intersectDisjoint", r);
  }

  printf("== Zero-Dimension Shapes\n");
  TRY("zeroBox", { describe("zeroBox", centredBox(0, 0, 0)); })
  TRY("zeroCylinder", { describe("zeroCylinder", BRepPrimAPI_MakeCylinder(0, 0).Shape()); })
  TRY("zeroSphere", { describe("zeroSphere", BRepPrimAPI_MakeSphere(0).Shape()); })
  TRY("zeroCone", { describe("zeroCone", BRepPrimAPI_MakeCone(0, 0, 0).Shape()); })
  TRY("zeroTorus", { describe("zeroTorus", BRepPrimAPI_MakeTorus(0, 0).Shape()); })
  TRY("zeroWidthBox", { describe("zeroWidthBox", centredBox(10, 10, 0)); })
  TRY("queriesOnZeroBox", {
    TopoDS_Shape s = centredBox(0.001, 0.001, 0.001);
    describe("queriesOnZeroBox", s);
    printf("queriesOnZeroBox: area=%.10g edges=%d vertices=%d\n", areaOf(s), countOf(s, TopAbs_EDGE),
           countOf(s, TopAbs_VERTEX));
  })

  printf("== Empty Containers\n");
  {
    BRepBuilderAPI_MakeWire mw;
    printf("emptyWireBuilder: IsDone=%d\n", mw.IsDone());
  }
  inChild("thruSectionsNoSections (unguarded Build with 0 wires)", [] {
    BRepOffsetAPI_ThruSections ts(true, false);
    ts.Build();
    printf("thruSectionsNoSections: IsDone=%d\n", ts.IsDone());
  });
  {
    BRepBuilderAPI_Sewing sew(1e-6);
    sew.Perform();
    printf("sewingNothing: SewedShape null=%d\n", sew.SewedShape().IsNull());
  }
  TRY("sectionBuilderEmpty", {
    BRepAlgoAPI_Section sec;
    sec.Build();
    printf("sectionBuilderEmpty: IsDone=%d\n", sec.IsDone());
  })
  inChild("cellsBuilderEmpty (unguarded Perform with 0 arguments)", [] {
    BOPAlgo_CellsBuilder cb;
    cb.Perform();
    printf("cellsBuilderEmpty: HasErrors=%d\n", cb.HasErrors());
  });
  printf("emptyWireRectangle: 1e-15 < Precision::Confusion()=%g, the bridge refuses before OCCT\n",
         Precision::Confusion());

  printf("== Invalid Parameters\n");
  TRY("negativeBox", { describe("negativeBox", centredBox(-10, -10, -10)); })
  TRY("negativeCylinder", { describe("negativeCylinder", BRepPrimAPI_MakeCylinder(-5, -10).Shape()); })
  TRY("negativeSphere", { describe("negativeSphere", BRepPrimAPI_MakeSphere(-5).Shape()); })
  TRY("negativeFillet", {
    TopoDS_Shape f = filletAll(box, -1, done);
    printf("negativeFillet: IsDone=%d\n", done);
  })
  TRY("negativeChamfer", {
    TopoDS_Shape f = chamferAll(box, -1, done);
    printf("negativeChamfer: IsDone=%d\n", done);
  })
  TRY("negativeShell", {
    TopoDS_Shape s = shellBy(box, 1.0, done);
    printf("negativeShell: shell(+1) IsDone=%d\n", done);
    if (done)
      describe("negativeShell", s);
  })
  inChild("zeroDrill (unguarded, radius 0)", [&] {
    TopoDS_Shape d = drill(box, gp_Pnt(0, 0, 5), gp_Dir(0, 0, -1), 0, done);
    printf("zeroDrill: IsDone=%d\n", done);
  });
  inChild("zeroDirectionVector (unguarded, gp_Dir(0,0,0))", [&] {
    gp_Dir d(0, 0, 0);
    printf("zeroDirectionVector: gp_Dir built (%g,%g,%g)\n", d.X(), d.Y(), d.Z());
  });
  {
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(box, TopAbs_EDGE, m);
    printf("outOfBoundsSubShapeIndex: edge count=%d, index 999 out of range\n", m.Extent());
  }
  {
    Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    gp_Pnt              p = c->Value(c->LastParameter() + 10.0);
    printf("curveEvalOutsideDomain: domain=[%.17g, %.17g] point=(%.17g, %.17g, %.17g)\n",
           c->FirstParameter(), c->LastParameter(), p.X(), p.Y(), p.Z());
  }
  {
    Handle(Geom_Plane) pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Pnt             p  = pl->Value(1e12, -2e12);
    printf("surfaceEvalOutsideDomain: point=(%.17g, %.17g, %.17g)\n", p.X(), p.Y(), p.Z());
  }
  inChild("wireFromZeroLengthLine (unguarded MakeEdge on coincident points)", [] {
    BRepBuilderAPI_MakeEdge me(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 0));
    printf("wireFromZeroLengthLine: MakeEdge IsDone=%d Error=%d\n", me.IsDone(), (int)me.Error());
  });
  describe("booleanIdenticalPosition", boolOp<BRepAlgoAPI_Fuse>(centredBox(10, 10, 10), centredBox(10, 10, 10), done));
  inChild("mirrorAxisZeroDirection (gp_Dir(0,0,0))", [] {
    gce_MakeMirror mm(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 0)));
  });
  inChild("mirror2dAxisZeroDirection (gp_Dir2d(0,0))", [] {
    gce_MakeMirror2d mm(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(0, 0)));
  });
  inChild("mirrorPlaneZeroNormal (gp_Dir(0,0,0))", [] {
    gce_MakeMirror mm(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 0)));
  });
  inChild("geomDirectionZeroVector (Geom_Direction(0,0,0))", [] {
    Handle(Geom_Direction) d = new Geom_Direction(0, 0, 0);
    printf("geomDirectionZeroVector: no exception, coords=(%.17g, %.17g, %.17g)\n", d->X(), d->Y(), d->Z());
  });

  printf("== Post-Operation State\n");
  {
    double       v = 0;
    TopoDS_Shape u = boolOp<BRepAlgoAPI_Fuse>(box, sphere, done);
    describe("shapeReusedAfterBoolean union", u);
    TopoDS_Shape c = boolOp<BRepAlgoAPI_Cut>(box, sphere, done);
    describe("shapeReusedAfterBoolean cut", c);
    volumeOf(sphere, v);
    printf("shapeReusedAfterBoolean: sphere volume=%.10g\n", v);
    describe("shapeQueriesAfterExport box", box);
  }
  {
    for (double d : {0.5, 0.1, 1.0})
    {
      TopoDS_Shape b = centredBox(10, 10, 10);
      BRepMesh_IncrementalMesh m(b, d, false, 0.5);
      int nodes = 0, tris = 0;
      for (TopExp_Explorer e(b, TopAbs_FACE); e.More(); e.Next())
      {
        TopLoc_Location            loc;
        Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), loc);
        if (!t.IsNull())
        {
          nodes += t->NbNodes();
          tris += t->NbTriangles();
        }
      }
      printf("meshRepeatedGeneration: deflection=%g nodes=%d triangles=%d\n", d, nodes, tris);
    }
  }

  printf("== Unusual Input Combinations\n");
  {
    TopoDS_Shape w1 = rectWire(10, 10), w2 = rectWire(5, 5);
    TRY("booleanWireShapes", {
      TopoDS_Shape u = boolOp<BRepAlgoAPI_Fuse>(w1, w2, done);
      printf("booleanWireShapes: fuse IsDone=%d edges=%d\n", done, done ? countOf(u, TopAbs_EDGE) : -1);
      if (done)
        printf("booleanWireShapes: valid=%d\n", validOf(u));
    })
    TRY("filletOnNonSolid", {
      BRepFilletAPI_MakeFillet f(w1);
      for (TopExp_Explorer e(w1, TopAbs_EDGE); e.More(); e.Next())
        f.Add(1.0, TopoDS::Edge(e.Current()));
      f.Build();
      printf("filletOnNonSolid: IsDone=%d\n", f.IsDone());
    })
    double v  = 0;
    bool   hv = volumeOf(w1, v);
    printf("volumeOnWireShape: has=%d volume=%g\n", hv, v);
    BRepMesh_IncrementalMesh m(w1, 0.5, false, 0.5);
    printf("meshOnWireShape: faces=%d (no triangulation to extract)\n", countOf(w1, TopAbs_FACE));
  }
  {
    BRepAlgoAPI_Section sec(box, box, false);
    sec.Build();
    printf("sectionOfSameShape: IsDone=%d edges=%d valid=%d\n", sec.IsDone(),
           sec.IsDone() ? countOf(sec.Shape(), TopAbs_EDGE) : -1, sec.IsDone() ? validOf(sec.Shape()) : 0);
  }
  {
    gp_Trsf t;
    t.SetTranslation(gp_Vec(0, 0, 0));
    describe("translateByZero", BRepBuilderAPI_Transform(box, t, true).Shape());
    gp_Trsf r;
    r.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0);
    describe("rotateByZero", BRepBuilderAPI_Transform(box, r, true).Shape());
    gp_Trsf s;
    s.SetScale(gp_Pnt(0, 0, 0), 1.0);
    describe("scaleByOne", BRepBuilderAPI_Transform(box, s, true).Shape());
    TRY("scaleByZero", {
      gp_Trsf z;
      z.SetScale(gp_Pnt(0, 0, 0), 0.0);
      describe("scaleByZero", BRepBuilderAPI_Transform(box, z, true).Shape());
    })
    TRY("scaleByNegative", {
      gp_Trsf n;
      n.SetScale(gp_Pnt(0, 0, 0), -1.0);
      describe("scaleByNegative", BRepBuilderAPI_Transform(box, n, true).Shape());
    })
  }

  printf("== UnifySameDomainBuilder Null PCurve\n");
  {
    TopoDS_Shape s;
    BRep_Builder bb;
    BRepTools::Read(s, "Tests/OCCTStressTests/Fixtures/unify-crash-mmd-kiha10-body5.brep", bb);
    printf("unify fixture: faces=%d edges=%d\n", countOf(s, TopAbs_FACE), countOf(s, TopAbs_EDGE));
    TRY("unifySameDomainOnMeshSewnSolidWithMissingPCurve", {
      ShapeUpgrade_UnifySameDomain u(s, true, true, false);
      u.SetAngularTolerance(1.0 * M_PI / 180);
      u.Build();
      printf("unifySameDomainOnMeshSewnSolidWithMissingPCurve: result faces=%d edges=%d\n",
             countOf(u.Shape(), TopAbs_FACE), countOf(u.Shape(), TopAbs_EDGE));
    })
  }

  printf("== SolidPrimitives Null Handle Guards\n");
  {
    TopoDS_Shape nul;
    inChild("makePeriodic on a null shape (unguarded)", [&] {
      BOPAlgo_MakePeriodic mp;
      mp.SetShape(nul);
      mp.MakeXPeriodic(true, 10);
      mp.MakeYPeriodic(true, 10);
      mp.MakeZPeriodic(true, 10);
      mp.Perform();
      printf("makePeriodic: HasErrors=%d\n", mp.HasErrors());
    });
    inChild("repeated on a null shape (unguarded)", [&] {
      BOPAlgo_MakePeriodic mp;
      mp.SetShape(nul);
      mp.MakeXPeriodic(true, 10);
      mp.Perform();
      mp.XRepeat(2);
      printf("repeated: HasErrors=%d\n", mp.HasErrors());
    });
    inChild("draft on a null shape (unguarded)", [&] {
      BRepOffsetAPI_MakeDraft d(nul, gp_Dir(0, 0, 1), 0.1);
      d.Perform(5);
      printf("draft: IsDone=%d\n", d.IsDone());
    });
    inChild("revolved full on a null shape (unguarded)", [&] {
      BRepPrimAPI_MakeRevol r(nul, gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
      r.Build();
      printf("revolvedFull: IsDone=%d\n", r.IsDone());
    });
    inChild("revolved partial on a null shape (unguarded)", [&] {
      BRepPrimAPI_MakeRevol r(nul, gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI);
      r.Build();
      printf("revolvedPartial: IsDone=%d\n", r.IsDone());
    });
  }

  printf("== evalAndUpdateTolerance Null PCurve\n");
  {
    TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    TopTools_IndexedMapOfShape boxEdges;
    TopExp::MapShapes(box, TopAbs_EDGE, boxEdges);
    // Shape.subShapes(ofType:) order: TopExp_Explorer order. Use the first explored edge.
    TopExp_Explorer ee(box, TopAbs_EDGE);
    TopoDS_Edge     e = TopoDS::Edge(ee.Current());
    printf("box edge[0] tolerance=%.17g\n", BRep_Tool::Tolerance(e));
    auto evalOn = [&](const char* label, const TopoDS_Shape& other) {
      int i = 0;
      for (TopExp_Explorer fe(other, TopAbs_FACE); fe.More(); fe.Next(), ++i)
      {
        TopoDS_Face          f = TopoDS::Face(fe.Current());
        double               first, last;
        Handle(Geom_Curve)   c3d  = BRep_Tool::Curve(e, first, last);
        Handle(Geom2d_Curve) c2d  = BRep_Tool::CurveOnSurface(e, f, first, last);
        Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
        printf("%s face[%d] %s: c2d null=%d", label, i, typeid(*surf).name(), c2d.IsNull());
        if (c2d.IsNull())
        {
          printf(" -> edge tolerance %.17g\n", BRep_Tool::Tolerance(e));
          continue;
        }
        TRY("evalAndUpdateTol", {
          double t = BRepTools::EvalAndUpdateTol(e, c3d, c2d, surf, first, last);
          printf(" -> EvalAndUpdateTol %.17g\n", t);
        })
      }
    };
    evalOn("edgePairedWithUnrelatedCylindricalFaceDoesNotCrash", cyl);
    // EvalAndUpdateTol raises the edge's stored tolerance, so the second test gets a fresh box,
    // as the Swift test does.
    TopoDS_Shape box2 = centredBox(10, 10, 10);
    e                 = TopoDS::Edge(TopExp_Explorer(box2, TopAbs_EDGE).Current());
    printf("fresh box edge[0] tolerance=%.17g\n", BRep_Tool::Tolerance(e));
    evalOn("edgePairedWithAnUnrelatedPlanarFaceDoesNotCrash", centredBox(3, 3, 3));
    inChild("cylinder lateral face, null pcurve passed on (unguarded)", [&] {
      TopExp_Explorer fe(cyl, TopAbs_FACE);
      TopoDS_Face     f = TopoDS::Face(fe.Current());
      double          first, last;
      Handle(Geom_Curve)   c3d  = BRep_Tool::Curve(e, first, last);
      Handle(Geom2d_Curve) c2d  = BRep_Tool::CurveOnSurface(e, f, first, last);
      Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
      printf("unguarded: c2d null=%d\n", c2d.IsNull());
      fflush(stdout);
      BRepTools::EvalAndUpdateTol(e, c3d, c2d, surf, first, last);
    });
  }
  return 0;
}
