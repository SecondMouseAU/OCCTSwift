// #766 kernel parity: Issue702SolidDemotion, Issue772SelfIntersectionAnalysis,
// Issue837FixDetailedModeFlagsTests, Issue839SmallEdgeToleranceAlignmentTests,
// Issue849ShapeFixStatusTests, Issue870ShapeExtendShapeTypeFailureTests, Issue999OuterBoundTests.
// Same OCCT calls, same inputs as the bridge functions those tests reach.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Face.hxx>
#include <BRep_Builder.hxx>
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <Geom_Plane.hxx>
#include <ShapeAnalysis_Shell.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeExtend.hxx>
#include <ShapeExtend_Explorer.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeFix_Solid.hxx>
#include <ShapeFix_Wireframe.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <Precision.hxx>
#include <cstdio>

static int unique(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static TopoDS_Shape openShell(double x)
{
  TopoDS_Shape    box = BRepPrimAPI_MakeBox(gp_Pnt(x - 5, -5, -5), 10, 10, 10).Shape();
  BRep_Builder    b;
  TopoDS_Compound c;
  b.MakeCompound(c);
  int i = 0;
  for (TopExp_Explorer e(box, TopAbs_FACE); e.More(); e.Next(), i++)
    if (i > 0) // sewnBoxMissingOneFace drops the first face
      b.Add(c, e.Current());
  BRepBuilderAPI_Sewing sw(1e-6);
  sw.Add(c);
  sw.Perform();
  return sw.SewedShape();
}

static int freeEdges(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_SHELL); e.More(); e.Next())
  {
    ShapeAnalysis_Shell sas;
    sas.LoadShells(e.Current());
    sas.CheckOrientedShells(e.Current(), Standard_True);
    n += unique(sas.FreeEdges(), TopAbs_EDGE);
  }
  return n;
}

static int selfInter(const TopoDS_Shape& s)
{
  BOPAlgo_ArgumentAnalyzer aa;
  aa.SetShape1(s);
  aa.ArgumentTypeMode() = true;
  aa.SelfInterMode()    = true;
  aa.StopOnFirstFaulty() = true;
  aa.SetRunParallel(false);
  aa.Perform();
  for (NCollection_List<BOPAlgo_CheckResult>::Iterator it(aa.GetCheckResult()); it.More(); it.Next())
    if (it.Value().GetCheckStatus() == BOPAlgo_SelfIntersect)
      return 1;
  return 0;
}

int main()
{
  // #702
  TopoDS_Shape shell = openShell(0);
  printf("#702 open shell: type=%d faces=%d closed=%d freeEdges=%d\n", (int)shell.ShapeType(), unique(shell, TopAbs_FACE),
         (int)shell.Closed(), freeEdges(shell));
  BRepBuilderAPI_MakeSolid ms(TopoDS::Shell(shell));
  TopoDS_Shape             fake = ms.Solid();
  printf("#702 fake solid: type=%d BRepCheck valid=%d\n", (int)fake.ShapeType(), (int)BRepCheck_Analyzer(fake).IsValid());
  ShapeFix_Solid fs(TopoDS::Solid(fake));
  fs.Perform();
  printf("#702 ShapeFix_Solid: type=%d valid=%d freeEdges=%d\n", (int)fs.Shape().ShapeType(),
         (int)BRepCheck_Analyzer(fs.Shape()).IsValid(), freeEdges(fs.Shape()));
  ShapeFix_Shape fx(fake);
  fx.Perform();
  printf("#702 ShapeFix_Shape: type=%d valid=%d\n", (int)fx.Shape().ShapeType(), (int)BRepCheck_Analyzer(fx.Shape()).IsValid());
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  printf("#702 box: freeEdges=%d valid=%d\n", freeEdges(box), (int)BRepCheck_Analyzer(box).IsValid());
  BRep_Builder    b;
  TopoDS_Compound two;
  b.MakeCompound(two);
  b.Add(two, openShell(0));
  b.Add(two, openShell(30));
  printf("#702 two open shells: freeEdges=%d shells=%d\n", freeEdges(two), unique(two, TopAbs_SHELL));

  // #772
  TopoDS_Compound ov;
  b.MakeCompound(ov);
  b.Add(ov, BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape());
  b.Add(ov, BRepPrimAPI_MakeBox(gp_Pnt(5, 0, 0), 10, 10, 10).Shape());
  printf("#772 self-intersection: box=%d overlapping compound=%d\n", selfInter(box), selfInter(ov));

  // #837: 10x10 face with a FORWARD (not reversed) 2x2 hole
  {
    BRepBuilderAPI_MakePolygon po(gp_Pnt(-5, -5, 0), gp_Pnt(5, -5, 0), gp_Pnt(5, 5, 0), gp_Pnt(-5, 5, 0), true);
    TopoDS_Face                f = BRepBuilderAPI_MakeFace(po.Wire());
    TopoDS_Wire                hole;
    b.MakeWire(hole);
    gp_Pnt hp[] = {gp_Pnt(-1, -1, 0), gp_Pnt(1, -1, 0), gp_Pnt(1, 1, 0), gp_Pnt(-1, 1, 0)};
    for (int i = 0; i < 4; i++)
      b.Add(hole, BRepBuilderAPI_MakeEdge(hp[i], hp[(i + 1) % 4]).Edge());
    b.Add(f, hole);
    Handle(BRepCheck_Face) c = new BRepCheck_Face(f);
    c->GeometricControls(true);
    printf("#837 fixture OrientationOfWires=%d (NoError=%d)\n", (int)c->OrientationOfWires(), (int)BRepCheck_NoError);
    for (int mode = 0; mode <= 1; mode++)
    {
      TopoDS_Compound comp;
      b.MakeCompound(comp);
      b.Add(comp, f);
      Handle(ShapeFix_Shape) sf = new ShapeFix_Shape(comp);
      sf->SetPrecision(1e-6);
      sf->FixSolidMode() = 1;
      sf->FixFreeShellMode() = 1;
      sf->FixFreeFaceMode() = mode;
      sf->FixFreeWireMode() = 1;
      sf->Perform();
      TopoDS_Face r = TopoDS::Face(TopExp_Explorer(sf->Shape(), TopAbs_FACE).Current());
      Handle(BRepCheck_Face) rc = new BRepCheck_Face(r);
      rc->GeometricControls(true);
      printf("#837 FixFreeFaceMode=%d: OrientationOfWires=%d\n", mode, (int)rc->OrientationOfWires());
    }
  }
  // #839: ShapeFix_Wireframe small edges, 10x10 face, bottom split at x=5 by an edge of `len`
  for (double len : {3e-7, 0.1})
  {
    gp_Pnt p[] = {gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 0), gp_Pnt(5 + len, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0),
                  gp_Pnt(0, 10, 0)};
    BRepBuilderAPI_MakeWire mw;
    for (int i = 0; i < 6; i++)
      mw.Add(BRepBuilderAPI_MakeEdge(p[i], p[(i + 1) % 6]).Edge());
    Handle(Geom_Plane) pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    TopoDS_Face        face = BRepBuilderAPI_MakeFace(pl, mw.Wire());
    printf("#839 edge %g: fixture edges=%d", len, unique(face, TopAbs_EDGE));
    for (double tol : {1e-7, 1e-6, 0.5})
    {
      Handle(ShapeFix_Wireframe) w = new ShapeFix_Wireframe(face);
      w->SetPrecision(tol);
      w->ModeDropSmallEdges() = true;
      w->FixSmallEdges();
      printf("; tol %g -> %d", tol, unique(w->Shape(), TopAbs_EDGE));
    }
    printf("\n");
  }
  // #849
  printf("#849 ShapeExtend_Status: OK=%d DONE1=%d DONE8=%d DONE=%d FAIL1=%d FAIL8=%d FAIL=%d\n", (int)ShapeExtend_OK,
         (int)ShapeExtend_DONE1, (int)ShapeExtend_DONE8, (int)ShapeExtend_DONE, (int)ShapeExtend_FAIL1,
         (int)ShapeExtend_FAIL8, (int)ShapeExtend_FAIL);
  {
    Handle(ShapeFix_Shape) sf = new ShapeFix_Shape(box);
    sf->Perform();
    printf("#849 ShapeFix_Shape(box): OK=%d DONE=%d FAIL=%d\n", (int)sf->Status(ShapeExtend_OK),
           (int)sf->Status(ShapeExtend_DONE), (int)sf->Status(ShapeExtend_FAIL));
  }
  // #870
  {
    ShapeExtend_Explorer ex;
    TopoDS_Shape         v = BRepBuilderAPI_MakeVertex(gp_Pnt(1, 2, 3)).Vertex();
    printf("#870 ShapeExtend_Explorer::ShapeType: box=%d vertex=%d (TopAbs_SOLID=%d TopAbs_VERTEX=%d)\n",
           (int)ex.ShapeType(box, true), (int)ex.ShapeType(v, true), (int)TopAbs_SOLID, (int)TopAbs_VERTEX);
  }
  // #999: panel (10x10, 4x4 centred hole), CheckOuterBound per wire
  {
    Handle(Geom_Plane)         pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    BRepBuilderAPI_MakePolygon po(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0), true);
    BRepBuilderAPI_MakePolygon ph(gp_Pnt(3, 3, 0), gp_Pnt(7, 3, 0), gp_Pnt(7, 7, 0), gp_Pnt(3, 7, 0), true);
    BRepBuilderAPI_MakeFace    mf(pl, po.Wire());
    TopoDS_Wire                h = ph.Wire();
    h.Reverse();
    mf.Add(h);
    TopoDS_Face panel = mf.Face();
    printf("#999 panel CheckOuterBound per wire:");
    for (TopExp_Explorer e(panel, TopAbs_WIRE); e.More(); e.Next())
    {
      ShapeAnalysis_Wire saw;
      saw.Init(TopoDS::Wire(e.Current()), panel, Precision::Confusion());
      printf(" %d", (int)saw.CheckOuterBound());
    }
    BRepBuilderAPI_MakeFace sf(pl, po.Wire());
    ShapeAnalysis_Wire      saw;
    saw.Init(TopoDS::Wire(TopExp_Explorer(sf.Face(), TopAbs_WIRE).Current()), sf.Face(), Precision::Confusion());
    printf("; single-wire face: %d\n", (int)saw.CheckOuterBound());
  }
  return 0;
}
