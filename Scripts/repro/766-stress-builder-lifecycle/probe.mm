// Epic #766, StressBuilderLifecycleTests.swift: kernel parity for the builder tests that have a
// geometric answer. Each block drives the OCCT builder the bridge wraps, with the test's inputs,
// including the second Build() the double-build tests make on the same builder.
#include <BOPAlgo_CellsBuilder.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GProp_GProps.hxx>
#include <Geom_Circle.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
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

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static TopoDS_Wire circle(gp_Pnt c, gp_Dir n, double r)
{
  Handle(Geom_Circle) g = new Geom_Circle(gp_Ax2(c, n), r);
  return BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(g)).Wire();
}

int main()
{
  TopoDS_Shape               box = centredBox(10, 10, 10);
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  TopoDS_Edge e0 = TopoDS::Edge(edges(1)), e1 = TopoDS::Edge(edges(2));

  printf("== FilletBuilder (BRepFilletAPI_MakeFillet)\n");
  {
    BRepFilletAPI_MakeFillet f(box);
    try
    {
      f.Build();
      printf("buildEmpty: IsDone=%d\n", f.IsDone());
    }
    catch (Standard_Failure& ex)
    {
      printf("buildEmpty: Build threw %s\n", ex.GetMessageString());
    }
  }
  {
    BRepFilletAPI_MakeFillet f(box);
    f.Add(1.0, e0);
    f.Build();
    printf("normalCycle: IsDone=%d volume=%.10g contours=%d HasResult=%d\n", f.IsDone(), vol(f.Shape()), f.NbContours(),
           f.HasResult());
    f.Build();
    printf("doubleBuild: second Build IsDone=%d volume=%.10g\n", f.IsDone(), vol(f.Shape()));
  }
  {
    BRepFilletAPI_MakeFillet f(box);
    f.Add(100.0, e0);
    try
    {
      f.Build();
      printf("invalidInput: IsDone=%d\n", f.IsDone());
    }
    catch (Standard_Failure& ex)
    {
      printf("invalidInput: Build threw %s\n", ex.GetMessageString());
    }
  }
  {
    BRepFilletAPI_MakeFillet f(box);
    f.Add(1.0, e0);
    f.Add(2.0, e1);
    f.Build();
    printf("queryContourDetails: IsDone=%d contours=%d", f.IsDone(), f.NbContours());
    for (int c = 1; c <= f.NbContours(); ++c)
      printf(" [r=%g len=%g const=%d]", f.Radius(c), f.Length(c), f.IsConstant(c));
    printf("\n");
  }

  printf("== ChamferBuilder (BRepFilletAPI_MakeChamfer)\n");
  {
    BRepFilletAPI_MakeChamfer c(box);
    try
    {
      c.Build();
      printf("buildEmpty: IsDone=%d\n", c.IsDone());
    }
    catch (Standard_Failure& ex)
    {
      printf("buildEmpty: Build threw %s\n", ex.GetMessageString());
    }
  }
  {
    BRepFilletAPI_MakeChamfer c(box);
    c.Add(1.0, e0);
    c.Build();
    printf("normalCycleSymmetric: IsDone=%d volume=%.10g contours=%d\n", c.IsDone(), vol(c.Shape()), c.NbContours());
    c.Build();
    printf("doubleBuild: second Build IsDone=%d volume=%.10g\n", c.IsDone(), vol(c.Shape()));
  }
  {
    BRepFilletAPI_MakeChamfer c(box);
    c.Add(100.0, e0);
    try
    {
      c.Build();
      printf("invalidInput: IsDone=%d\n", c.IsDone());
    }
    catch (Standard_Failure& ex)
    {
      printf("invalidInput: Build threw %s\n", ex.GetMessageString());
    }
  }
  {
    BRepFilletAPI_MakeChamfer c(box);
    c.Add(2.0, e0);
    c.Build();
    printf("queryContourDetails: contours=%d symmetric=%d distAngle=%d twoDists=%d\n", c.NbContours(), c.IsSymetric(1),
           c.IsDistanceAngle(1), c.IsTwoDistances(1));
  }

  printf("== PipeShellBuilder (BRepOffsetAPI_MakePipeShell, Frenet)\n");
  {
    TopoDS_Wire                 spine = circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 10);
    BRepOffsetAPI_MakePipeShell empty(spine);
    try
    {
      empty.Build();
      printf("buildEmpty: IsDone=%d\n", empty.IsDone());
    }
    catch (Standard_Failure& ex)
    {
      printf("buildEmpty: Build threw %s\n", ex.GetMessageString());
    }
    BRepOffsetAPI_MakePipeShell p(spine);
    p.SetMode(true);
    p.Add(circle(gp_Pnt(10, 0, 0), gp_Dir(0, 1, 0), 2));
    p.Build();
    printf("normalCycle: IsDone=%d faces=%d area=%.10g valid=%d\n", p.IsDone(), count(p.Shape(), TopAbs_FACE),
           area(p.Shape()), BRepCheck_Analyzer(p.Shape()).IsValid());
    TopTools_ListOfShape sections;
    BRepOffsetAPI_MakePipeShell sim(spine);
    sim.SetMode(true);
    sim.Add(circle(gp_Pnt(10, 0, 0), gp_Dir(0, 1, 0), 2));
    sim.Simulate(5, sections);
    printf("simulateBeforeBuild: sections=%d\n", sections.Extent());
  }

  printf("== SewingBuilder (BRepBuilderAPI_Sewing)\n");
  {
    BRepBuilderAPI_Sewing s(1e-6);
    s.Add(box);
    s.Perform();
    printf("normalCycle: type=%d valid=%d volume=%.10g\n", (int)s.SewedShape().ShapeType(),
           BRepCheck_Analyzer(s.SewedShape()).IsValid(), vol(s.SewedShape()));
    BRepBuilderAPI_Sewing two(1e-3);
    two.Add(centredBox(10, 10, 10));
    two.Add(BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 10, 10, 10).Shape());
    two.Perform();
    printf("twoShapes: faces=%d valid=%d\n", count(two.SewedShape(), TopAbs_FACE), BRepCheck_Analyzer(two.SewedShape()).IsValid());
    BRepBuilderAPI_Sewing ext(1e-3);
    ext.Add(box);
    ext.SetNonManifoldMode(false);
    ext.Perform();
    printf("extendedQueries: NbDeletedFaces=%d\n", ext.NbDeletedFaces());
  }

  printf("== WireBuilder (BRepBuilderAPI_MakeWire)\n");
  {
    BRepBuilderAPI_MakeWire mw;
    int                     i = 0;
    for (TopExp_Explorer e(box, TopAbs_EDGE); e.More() && i < 4; e.Next(), ++i)
      mw.Add(TopoDS::Edge(e.Current()));
    printf("normalCycle: first 4 explored edges IsDone=%d edges=%d\n", mw.IsDone(), mw.IsDone() ? count(mw.Wire(), TopAbs_EDGE) : 0);
    BRepBuilderAPI_MakeWire aw;
    aw.Add(TopoDS::Wire(TopExp_Explorer(box, TopAbs_WIRE).Current()));
    printf("addWireShape: IsDone=%d edges=%d\n", aw.IsDone(), count(aw.Wire(), TopAbs_EDGE));
  }

  printf("== UnifySameDomain\n");
  {
    TopoDS_Shape fused = BRepAlgoAPI_Fuse(centredBox(10, 10, 10), BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 10, 10, 10).Shape()).Shape();
    ShapeUpgrade_UnifySameDomain u(fused, true, true, false);
    u.Build();
    printf("normalCycle: fused faces=%d -> unified faces=%d volume=%.10g\n", count(fused, TopAbs_FACE), count(u.Shape(), TopAbs_FACE),
           vol(u.Shape()));
    ShapeUpgrade_UnifySameDomain u2(box, true, true, false);
    u2.Build();
    printf("buildWithoutModification / withTolerances: faces=%d volume=%.10g\n", count(u2.Shape(), TopAbs_FACE), vol(u2.Shape()));
  }

  printf("== ThruSections\n");
  {
    BRepOffsetAPI_ThruSections t(true, false);
    t.AddWire(circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 5));
    t.AddWire(circle(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1), 3));
    t.Build();
    printf("normalCycle: IsDone=%d volume=%.10g (frustum pi*10/3*(25+15+9)=%.10g)\n", t.IsDone(), vol(t.Shape()),
           M_PI * 10 / 3 * 49);
    t.Build();
    printf("doubleBuild: second IsDone=%d volume=%.10g\n", t.IsDone(), vol(t.Shape()));
  }

  printf("== CellsBuilder (BOPAlgo_CellsBuilder)\n");
  {
    BOPAlgo_CellsBuilder cb;
    cb.AddArgument(centredBox(20, 20, 20));
    cb.AddArgument(BRepPrimAPI_MakeSphere(10).Shape());
    cb.Perform();
    cb.AddAllToResult();
    printf("normalCycle: solids=%d volume=%.10g valid=%d\n", count(cb.Shape(), TopAbs_SOLID), vol(cb.Shape()),
           BRepCheck_Analyzer(cb.Shape()).IsValid());
    BOPAlgo_CellsBuilder rb;
    rb.AddArgument(centredBox(10, 10, 10));
    rb.AddArgument(BRepPrimAPI_MakeSphere(5).Shape());
    rb.Perform();
    rb.AddAllToResult();
    rb.RemoveAllFromResult();
    printf("removeAll: faces=%d\n", count(rb.Shape(), TopAbs_FACE));
  }

  printf("== SectionBuilder (BRepAlgoAPI_Section)\n");
  {
    BRepAlgoAPI_Section s(box, BRepPrimAPI_MakeSphere(5).Shape());
    printf("normalCycleTwoShapes / initThenSetShapes / doubleBuild: IsDone=%d edges=%d vertices=%d\n", s.IsDone(),
           count(s.Shape(), TopAbs_EDGE), count(s.Shape(), TopAbs_VERTEX));
    BRepAlgoAPI_Section p(box, gp_Pln(0, 0, 1, 0));
    printf("sectionWithPlane: IsDone=%d edges=%d\n", p.IsDone(), count(p.Shape(), TopAbs_EDGE));
  }

  printf("== ShapeFixer (ShapeFix_Shape)\n");
  {
    ShapeFix_Shape f(box);
    f.SetPrecision(1e-6);
    bool changed = f.Perform();
    printf("normalCycle / fixAlreadyGoodShape: Perform=%d volume=%.10g valid=%d\n", changed, vol(f.Shape()),
           BRepCheck_Analyzer(f.Shape()).IsValid());
  }
  return 0;
}
