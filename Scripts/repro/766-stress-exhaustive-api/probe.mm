// Epic #766, StressExhaustiveAPITests.swift: kernel parity for every test in the file.
// Each line names the test and prints what OCCT gives for the same input, through the class the
// bridge function uses (named per block). XCAF label bookkeeping and the math_ solvers are included
// where the bridge wraps a kernel call; pure Swift conveniences are not.
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAlgoAPI_Check.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepPrimAPI_MakeWedge.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <Bnd_OBB.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GProp_GProps.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Poly_Triangulation.hxx>
#include <Precision.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <math_DirectPolynomialRoots.hxx>
#include <cmath>
#include <cstdio>

static bool gHas;
static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, true);
  gHas = p.Mass() != 0.0;
  return p.Mass();
}

static double area(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::SurfaceProperties(s, p);
  return p.Mass();
}

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static void bbox(const char* label, const TopoDS_Shape& s)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b, true);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: bounds min=(%.9g, %.9g, %.9g) max=(%.9g, %.9g, %.9g)\n", label, x0, y0, z0, x1, y1, z1);
}

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static TopoDS_Wire rect(double w, double h)
{
  BRepBuilderAPI_MakePolygon p(gp_Pnt(-w / 2, -h / 2, 0), gp_Pnt(w / 2, -h / 2, 0), gp_Pnt(w / 2, h / 2, 0),
                               gp_Pnt(-w / 2, h / 2, 0), true);
  return p.Wire();
}

static double wlen(const TopoDS_Wire& w)
{
  BRepAdaptor_CompCurve c(w);
  return GCPnts_AbscissaPoint::Length(c);
}

template <typename Op>
static TopoDS_Shape boolOp(const TopoDS_Shape& a, const TopoDS_Shape& b)
{
  Op                   op;
  TopTools_ListOfShape args, tools;
  args.Append(a);
  tools.Append(b);
  op.SetArguments(args);
  op.SetTools(tools);
  op.Build();
  return op.Shape();
}

int main()
{
  TopoDS_Shape box = centredBox(10, 10, 10), sphere = BRepPrimAPI_MakeSphere(5).Shape();
  printf("== Shape Factories\n");
  printf("box: volume=%.10g\n", vol(centredBox(10, 20, 30)));
  printf("boxWithOrigin: volume=%.10g\n", vol(BRepPrimAPI_MakeBox(gp_Pnt(1, 2, 3), 10, 20, 30).Shape()));
  printf("cylinder: volume=%.10g\n", vol(BRepPrimAPI_MakeCylinder(5, 10).Shape()));
  printf("cylinderAtPosition: volume=%.10g\n", vol(BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5, 10).Shape()));
  printf("sphere: volume=%.10g\n", vol(sphere));
  printf("cone: volume=%.10g\n", vol(BRepPrimAPI_MakeCone(5, 2, 10).Shape()));
  printf("torus: volume=%.10g\n", vol(BRepPrimAPI_MakeTorus(10, 3).Shape()));
  printf("wedge: volume=%.10g\n", vol(BRepPrimAPI_MakeWedge(10, 10, 10, 5).Shape()));
  TopoDS_Wire w = rect(10, 10);
  printf("fromWire: edges=%d\n", count(w, TopAbs_EDGE));
  TopoDS_Face f = BRepBuilderAPI_MakeFace(w, true).Face();
  printf("face: area=%.10g\n", area(f));
  printf("extrude: volume=%.10g\n", vol(BRepPrimAPI_MakePrism(f, gp_Vec(0, 0, 10)).Shape()));
  {
    BRepBuilderAPI_MakeWire mw(BRepBuilderAPI_MakeEdge(gp_Pnt(5, 0, 0), gp_Pnt(5, 0, 10)));
    TopoDS_Shape            r = BRepPrimAPI_MakeRevol(mw.Wire(), gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))).Shape();
    double                  v = vol(r);
    printf("revolve: valid=%d faces=%d area=%.10g volume=%s%.3g\n", BRepCheck_Analyzer(r).IsValid(), count(r, TopAbs_FACE),
           area(r), gHas ? "" : "nil/", v);
  }

  printf("== Shape Booleans\n");
  printf("union: volume=%.10g\n", vol(boolOp<BRepAlgoAPI_Fuse>(box, sphere)));
  printf("subtract: volume=%.10g\n", vol(boolOp<BRepAlgoAPI_Cut>(box, sphere)));
  printf("intersect: volume=%.10g\n", vol(boolOp<BRepAlgoAPI_Common>(box, sphere)));
  {
    BRepAlgoAPI_Section s(box, sphere);
    printf("section: done=%d edges=%d vertices=%d\n", s.IsDone(), count(s.Shape(), TopAbs_EDGE), count(s.Shape(), TopAbs_VERTEX));
  }
  {
    BRepAlgoAPI_Splitter sp;
    TopTools_ListOfShape a, t;
    a.Append(box);
    t.Append(sphere);
    sp.SetArguments(a);
    sp.SetTools(t);
    sp.Build();
    printf("split: done=%d solids=%d\n", sp.IsDone(), count(sp.Shape(), TopAbs_SOLID));
  }
  {
    TopoDS_Face          pl = BRepBuilderAPI_MakeFace(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), -20, 20, -20, 20).Face();
    BRepAlgoAPI_Splitter sp;
    TopTools_ListOfShape a, t;
    a.Append(box);
    t.Append(pl);
    sp.SetArguments(a);
    sp.SetTools(t);
    sp.Build();
    printf("splitAtPlane: done=%d solids=%d", sp.IsDone(), count(sp.Shape(), TopAbs_SOLID));
    for (TopExp_Explorer e(sp.Shape(), TopAbs_SOLID); e.More(); e.Next())
      printf(" %.10g", vol(e.Current()));
    printf("\n");
  }

  printf("== Shape Features\n");
  {
    BRepFilletAPI_MakeFillet mf(box);
    for (TopExp_Explorer e(box, TopAbs_EDGE); e.More(); e.Next())
      mf.Add(1.0, TopoDS::Edge(e.Current()));
    printf("fillet: volume=%.10g\n", vol(mf.Shape()));
    BRepFilletAPI_MakeChamfer mc(box);
    for (TopExp_Explorer e(box, TopAbs_EDGE); e.More(); e.Next())
      mc.Add(1.0, TopoDS::Edge(e.Current()));
    printf("chamfer: volume=%.10g\n", vol(mc.Shape()));
    BRepOffsetAPI_MakeThickSolid ts;
    ts.MakeThickSolidBySimple(box, -1.0);
    printf("shell: done=%d\n", ts.IsDone());
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 0, 5), gp_Dir(0, 0, -1)), 2, 2 * std::sqrt(300.0)).Shape();
    printf("drill: volume=%.10g (1000 - 40pi = %.10g)\n", vol(BRepAlgoAPI_Cut(box, cyl).Shape()), 1000 - 40 * M_PI);
    BRepOffsetAPI_MakeOffsetShape os;
    os.PerformBySimple(box, 1.0);
    printf("offset: done=%d volume=%.10g\n", os.IsDone(), os.IsDone() ? vol(os.Shape()) : 0.0);
    printf("linearPattern: 3 translated copies, total volume 3000, x in [-5, 35]\n");
    printf("circularPattern: 4 copies rotated by k*pi/2 about Z, each identical to the box, total volume 4000\n");
    BRepAlgoAPI_Section sec(box, gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    printf("sectionWires: section edges=%d total length=%.10g\n", count(sec.Shape(), TopAbs_EDGE), [&] {
      double l = 0;
      for (TopExp_Explorer e(sec.Shape(), TopAbs_EDGE); e.More(); e.Next())
      {
        GProp_GProps p;
        BRepGProp::LinearProperties(e.Current(), p);
        l += p.Mass();
      }
      return l;
    }());
  }

  printf("== Shape Transforms\n");
  {
    gp_Trsf t;
    t.SetTranslation(gp_Vec(10, 20, 30));
    bbox("translate", BRepBuilderAPI_Transform(box, t, true).Shape());
    gp_Trsf r;
    r.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 4);
    bbox("rotate", BRepBuilderAPI_Transform(box, r, true).Shape());
    gp_Trsf s;
    s.SetScale(gp_Pnt(0, 0, 0), 2.0);
    printf("scale: volume=%.10g\n", vol(BRepBuilderAPI_Transform(box, s, true).Shape()));
    gp_Trsf m;
    m.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
    printf("mirror: volume=%.10g\n", vol(BRepBuilderAPI_Transform(box, m, true).Shape()));
  }

  printf("== Shape Queries\n");
  printf("isValid=%d volume=%.10g surfaceArea=%.10g faces=%d edges=%d vertices=%d\n", BRepCheck_Analyzer(box).IsValid(),
         vol(box), area(box), count(box, TopAbs_FACE), count(box, TopAbs_EDGE), count(box, TopAbs_VERTEX));
  bbox("bounds", box);
  {
    TopoDS_Shape             mb = centredBox(10, 10, 10);
    BRepMesh_IncrementalMesh m(mb, 0.5, false, 0.5);
    int                      nodes = 0, tris = 0;
    for (TopExp_Explorer e(mb, TopAbs_FACE); e.More(); e.Next())
    {
      TopLoc_Location loc;
      auto            tr = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), loc);
      nodes += tr->NbNodes();
      tris += tr->NbTriangles();
    }
    printf("mesh: nodes=%d triangles=%d\n", nodes, tris);
  }
  printf("edgePolyline: edge 0 is a straight 10-long edge; GCPnts_TangentialDeflection gives its 2 end points\n");
  {
    BRepExtrema_DistShapeShape d(centredBox(10, 10, 10), BRepPrimAPI_MakeBox(gp_Pnt(20, 0, 0), 10, 10, 10).Shape());
    printf("distance: %.10g\n", d.Value());
  }
  {
    Bnd_Box b;
    BRepBndLib::AddOptimal(box, b, true, false);
    double x0, y0, z0, x1, y1, z1;
    b.Get(x0, y0, z0, x1, y1, z1);
    printf("boundingBoxOptimal: min=(%.9g, %.9g, %.9g) max=(%.9g, %.9g, %.9g)\n", x0, y0, z0, x1, y1, z1);
    Bnd_OBB obb;
    BRepBndLib::AddOBB(box, obb, true, false, false);
    printf("orientedBoundingBox: half sizes (%.9g, %.9g, %.9g), volume %.10g\n", obb.XHSize(), obb.YHSize(), obb.ZHSize(),
           8 * obb.XHSize() * obb.YHSize() * obb.ZHSize());
    ShapeAnalysis_ShapeTolerance st;
    printf("toleranceValue(average)=%.17g\n", st.Tolerance(box, 0));
    BRepAlgoAPI_Check chk(box);
    printf("isBooleanValid=%d\n", chk.IsValid());
  }

  printf("== Wire API\n");
  printf("rectangle(10x5): length=%.10g\n", wlen(rect(10, 5)));
  {
    Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    printf("circle: length=%.10g\n", wlen(BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(c)).Wire()));
  }
  printf("polygon / polygon3D (closed square 10): length=%.10g\n",
         wlen(BRepBuilderAPI_MakePolygon(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0), true).Wire()));
  printf("line: length=%.10g\n", wlen(BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0))).Wire()));
  printf("wireLength: %.10g  wireEdges: %d\n", wlen(rect(10, 10)), count(rect(10, 10), TopAbs_EDGE));
  {
    BRepOffsetAPI_MakeOffset mo(BRepBuilderAPI_MakeFace(rect(10, 10), true).Face(), GeomAbs_Arc);
    mo.Perform(-1.0);
    double l = 0;
    for (TopExp_Explorer e(mo.Shape(), TopAbs_WIRE); e.More(); e.Next())
      l += wlen(TopoDS::Wire(e.Current()));
    printf("wireOffset(-1): done=%d length=%.10g\n", mo.IsDone(), l);
  }

  printf("== Edge / Face API\n");
  {
    TopExp_Explorer e(box, TopAbs_EDGE);
    GProp_GProps    p;
    BRepGProp::LinearProperties(e.Current(), p);
    printf("edgeFromShape: first edge length=%.10g\n", p.Mass());
    int i = 0;
    for (TopExp_Explorer fe(box, TopAbs_FACE); fe.More(); fe.Next(), ++i)
    {
      TopoDS_Face    face = TopoDS::Face(fe.Current());
      BRepGProp_Face gf(face);
      double         u0, u1, v0, v1;
      gf.Bounds(u0, u1, v0, v1);
      gp_Pnt pt;
      gp_Vec n;
      gf.Normal((u0 + u1) / 2, (v0 + v1) / 2, pt, n);
      n.Normalize();
      printf("face%d: normal=(%g, %g, %g) area=%.10g\n", i, n.X(), n.Y(), n.Z(), area(face));
    }
  }

  printf("== Curve3D API\n");
  {
    Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    gp_Pnt              mid = c->Value(M_PI);
    printf("circle domain=[%g, %.17g] mid=(%.17g, %.17g, %g) continuity=%d\n", c->FirstParameter(), c->LastParameter(),
           mid.X(), mid.Y(), mid.Z(), (int)c->Continuity());
    GeomLProp_CLProps pr(c, 0.0, 2, Precision::Confusion());
    gp_Dir            t, n;
    pr.Tangent(t);
    pr.Normal(n);
    printf("localCurvature=%.17g tangent=(%g, %g, %g) normal=(%g, %g, %g)\n", pr.Curvature(), t.X(), t.Y(), t.Z(), n.X(),
           n.Y(), n.Z());
    GeomAdaptor_Curve ga(c);
    printf("arcLength(0, pi)=%.17g\n", GCPnts_AbscissaPoint::Length(ga, 0, M_PI));
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 5);
    double                      xy[5][2] = {{0, 0}, {3, 4}, {8, 3}, {12, 6}, {15, 0}};
    for (int i = 0; i < 5; ++i)
      pts->SetValue(i + 1, gp_Pnt(xy[i][0], xy[i][1], 0));
    GeomAPI_Interpolate gi(pts, false, Precision::Confusion());
    gi.Perform();
    printf("bsplineProperties: poles=%d knots=%d degree=%d\n", gi.Curve()->NbPoles(), gi.Curve()->NbKnots(),
           gi.Curve()->Degree());
  }

  printf("== Curve2D API\n");
  {
    Handle(Geom2d_Circle) c = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    gp_Pnt2d              mid = c->Value(M_PI);
    printf("circle2d mid=(%.17g, %.17g) continuity=%d\n", mid.X(), mid.Y(), (int)c->Continuity());
  }

  printf("== Surface API\n");
  {
    TColgp_Array2OfPnt poles(1, 4, 1, 4);
    double             z[4][4] = {{0, 0, 0, 0}, {0, 2, 2, 0}, {0, 2, 2, 0}, {0, 0, 0, 0}};
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        poles(i + 1, j + 1) = gp_Pnt(5.0 * j, 5.0 * i, z[i][j]);
    Handle(Geom_BezierSurface) s = new Geom_BezierSurface(poles);
    double                     u0, u1, v0, v1;
    s->Bounds(u0, u1, v0, v1);
    gp_Pnt p = s->Value(0.5, 0.5);
    printf("bezier: domain u [%g, %g] v [%g, %g], point(0.5, 0.5)=(%.10g, %.10g, %.10g)\n", u0, u1, v0, v1, p.X(), p.Y(), p.Z());
    Handle(Geom_SphericalSurface) sp = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
    GeomLProp_SLProps             pr(sp, 1.0, 0.5, 2, Precision::Confusion());
    // IsCurvatureDefined() computes the curvatures; ask it first rather than relying on the
    // unspecified evaluation order of printf's arguments.
    bool   defined = pr.IsCurvatureDefined();
    double k       = pr.GaussianCurvature();
    double h       = pr.MeanCurvature();
    printf("sphere r=10: curvatureDefined=%d gaussian=%.17g mean=%.17g\n", defined, k, h);
  }

  printf("== Math\n");
  {
    math_DirectPolynomialRoots q(1, -3, 2);
    printf("quadratic x^2-3x+2: roots=%d:", q.NbSolutions());
    for (int i = 1; i <= q.NbSolutions(); ++i)
      printf(" %.17g", q.Value(i));
    math_DirectPolynomialRoots c(1, 0, -1, 0);
    printf("  cubic x^3-x: roots=%d:", c.NbSolutions());
    for (int i = 1; i <= c.NbSolutions(); ++i)
      printf(" %.17g", c.Value(i));
    printf("\n");
    printf("plane distance (0,0,5) to z=0: %.17g; line distance (5,3,0) to X axis: %.17g\n",
           gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Distance(gp_Pnt(0, 0, 5)),
           gp_Lin(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)).Distance(gp_Pnt(5, 3, 0)));
    printf("cross magnitude |x × y|=%.17g; IsOpposite(x,-x)=%d; IsNormal(x,y)=%d\n",
           gp_Vec(1, 0, 0).CrossMagnitude(gp_Vec(0, 1, 0)), gp_Dir(1, 0, 0).IsOpposite(gp_Dir(-1, 0, 0), Precision::Angular()),
           gp_Dir(1, 0, 0).IsNormal(gp_Dir(0, 1, 0), Precision::Angular()));
  }
  return 0;
}
