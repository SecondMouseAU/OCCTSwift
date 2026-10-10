// #766 kernel parity: LocationPurgeTests, NearestPlaneTests, NURBSConversionTests,
// RemoveLocationsTests, SameParameterTests. BRepTools_PurgeLocations (OCCTShapePurgeLocations),
// ShapeAnalysis_Geom::NearestPlane (OCCTShapeNearestPlane), BRepBuilderAPI_NurbsConvert
// (OCCTShapeConvertToNURBS), ShapeUpgrade_RemoveLocations (OCCTShapeRemoveLocations),
// BRepLib::SameParameter on a copy (OCCTShapeSameParameter). Inputs built as the Swift
// constructors build them (BRepBuilderAPI_Transform with copy for mirror/translate/rotate).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBuilderAPI_NurbsConvert.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepTools_PurgeLocations.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepLib.hxx>
#include <ShapeAnalysis_Geom.hxx>
#include <ShapeUpgrade_RemoveLocations.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static int unique(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  return g.Mass();
}

static void bounds(const char* label, const TopoDS_Shape& s)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("%s bounds=(%.4f, %.4f, %.4f)-(%.4f, %.4f, %.4f)\n", label, x0, y0, z0, x1, y1, z1);
}

static int located(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    if (!e.Current().Location().IsIdentity())
      n++;
  return n;
}

static int bsplineFaces(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    if (BRepAdaptor_Surface(TopoDS::Face(e.Current())).GetType() == GeomAbs_BSplineSurface)
      n++;
  return n;
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  {
    BRepTools_PurgeLocations p;
    p.Perform(box);
    printf("purge box: IsDone=%d faces=%d\n", (int)p.IsDone(), p.IsDone() ? unique(p.GetResult(), TopAbs_FACE) : -1);
    gp_Trsf m;
    m.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
    TopoDS_Shape mir = BRepBuilderAPI_Transform(box, m, true).Shape();
    BRepTools_PurgeLocations p2;
    p2.Perform(mir);
    printf("purge mirrored box: locatedFacesBefore=%d IsDone=%d faces=%d locatedFacesAfter=%d volume=%.6f\n", located(mir),
           (int)p2.IsDone(), p2.IsDone() ? unique(p2.GetResult(), TopAbs_FACE) : -1,
           p2.IsDone() ? located(p2.GetResult()) : -1, p2.IsDone() ? vol(p2.GetResult()) : 0.0);
  }
  {
    TColgp_Array1OfPnt pts(1, 4);
    pts(1) = gp_Pnt(0, 0, 0);
    pts(2) = gp_Pnt(10, 0, 0.1);
    pts(3) = gp_Pnt(10, 10, -0.1);
    pts(4) = gp_Pnt(0, 10, 0.05);
    gp_Pln pl;
    double dmax = 0;
    bool   ok   = ShapeAnalysis_Geom::NearestPlane(pts, pl, dmax);
    gp_Dir n    = pl.Axis().Direction();
    printf("NearestPlane: ok=%d maxDeviation=%.9f normal=(%.9f, %.9f, %.9f)\n", (int)ok, dmax, n.X(), n.Y(), n.Z());
  }
  {
    TopoDS_Shape             b2 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -2.5, -1.5), 10, 5, 3).Shape();
    TopoDS_Shape             sp = BRepPrimAPI_MakeSphere(5).Shape();
    BRepFilletAPI_MakeFillet mf(box);
    for (TopExp_Explorer e(box, TopAbs_EDGE); e.More(); e.Next())
      mf.Add(1.0, TopoDS::Edge(e.Current()));
    mf.Build();
    const char*  names[] = {"box 10x5x3", "sphere r5", "filleted box"};
    TopoDS_Shape in[]    = {b2, sp, mf.Shape()};
    for (int i = 0; i < 3; i++)
    {
      BRepBuilderAPI_NurbsConvert nc(in[i]);
      TopoDS_Shape                r = nc.Shape();
      printf("NurbsConvert %s: valid=%d faces=%d bsplineFaces=%d volume=%.6f (input %.6f)\n", names[i],
             (int)BRepCheck_Analyzer(r).IsValid(), unique(r, TopAbs_FACE), bsplineFaces(r), vol(r), vol(in[i]));
    }
  }
  {
    gp_Trsf t;
    t.SetTranslation(gp_Vec(100, 200, 300));
    TopoDS_Shape moved = BRepBuilderAPI_Transform(box, t, true).Shape();
    ShapeUpgrade_RemoveLocations rl;
    rl.Remove(moved);
    TopoDS_Shape r = rl.GetResult();
    printf("RemoveLocations(translated box): locatedBefore=%d locatedAfter=%d valid=%d volume=%.6f\n", located(moved),
           located(r), (int)BRepCheck_Analyzer(r).IsValid(), vol(r));
    bounds("  result", r);
    // Shape.moved(dx:dy:dz:) (OCCTShapeMoved) carries the translation as a TopLoc_Location.
    TopoDS_Shape                 locd = box.Moved(TopLoc_Location(t));
    ShapeUpgrade_RemoveLocations rl3;
    rl3.Remove(locd);
    TopoDS_Shape r3 = rl3.GetResult();
    printf("RemoveLocations(located box via Moved): rootLocationIdentity before=%d after=%d locatedFacesAfter=%d valid=%d volume=%.6f\n",
           (int)locd.Location().IsIdentity(), (int)r3.Location().IsIdentity(), located(r3),
           (int)BRepCheck_Analyzer(r3).IsValid(), vol(r3));
    bounds("  result", r3);
    bounds("  located input with its location dropped (REMLOCDROP)", locd.Located(TopLoc_Location()));
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    gp_Trsf      rt;
    rt.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), M_PI / 4);
    TopoDS_Shape rot = BRepBuilderAPI_Transform(cyl, rt, true).Shape();
    ShapeUpgrade_RemoveLocations rl2;
    rl2.Remove(rot);
    printf("RemoveLocations(rotated cylinder): valid=%d volume=%.6f\n", (int)BRepCheck_Analyzer(rl2.GetResult()).IsValid(),
           vol(rl2.GetResult()));
    bounds("  result", rl2.GetResult());
  }
  {
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    for (int k = 0; k < 2; k++)
    {
      BRepBuilderAPI_Copy c(k == 0 ? box : cyl);
      TopoDS_Shape        r = c.Shape();
      BRepLib::SameParameter(r, 1e-6);
      printf("SameParameter(%s, 1e-6): valid=%d volume=%.9f\n", k == 0 ? "box" : "cylinder",
             (int)BRepCheck_Analyzer(r).IsValid(), vol(r));
    }
  }
  return 0;
}
