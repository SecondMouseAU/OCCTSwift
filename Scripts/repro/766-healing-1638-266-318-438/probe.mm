// #766 kernel parity: Issue1638ComposeShellGridTests, Issue266FaceHealingControlTests,
// Issue318DegenerateCurveOnSurfaceEdgeTests, Issue438DivideContinuityUnificationTests.
// ShapeFix_ComposeShell over a u x v grid (OCCTShapeFixComposeShell), ShapeFix_Face and
// BRepCheck_Face (OCCTFaceFixer*, OCCTBRepCheckFace*), the #318 BREP fixture's edge/length census
// (OCCTShapeAnalyze), ShapeUpgrade_ShapeDivideContinuity (OCCTShapeDivide) on the #438 surface.
// The #318 fixture is read straight out of the Swift test file so there is one copy of it.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepCheck_Face.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepTools.hxx>
#include <Geom_Plane.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeExtend_CompositeSurface.hxx>
#include <ShapeFix_ComposeShell.hxx>
#include <ShapeFix_Face.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <NCollection_HArray2.hxx>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  if (s.IsNull())
    return -1;
  int n = 0;
  for (TopExp_Explorer e(s, t); e.More(); e.Next())
    n++;
  return n;
}

static TopoDS_Face planar10()
{
  BRepBuilderAPI_MakePolygon p(gp_Pnt(-5, -5, 0), gp_Pnt(5, -5, 0), gp_Pnt(5, 5, 0), gp_Pnt(-5, 5, 0), Standard_True);
  return BRepBuilderAPI_MakeFace(p.Wire());
}

// OCCTShapeFixComposeShell's grid: the face's own surface tiled u x v over its UV box.
static void compose(const char* label, const TopoDS_Face& face, int u, int v)
{
  Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
  double               u0, u1, v0, v1;
  BRepTools::UVBounds(face, u0, u1, v0, v1);
  Handle(NCollection_HArray2<Handle(Geom_Surface)>) grid = new NCollection_HArray2<Handle(Geom_Surface)>(1, u, 1, v);
  for (int i = 1; i <= u; i++)
    for (int j = 1; j <= v; j++)
      grid->SetValue(i, j,
                     new Geom_RectangularTrimmedSurface(surf, u0 + (u1 - u0) * (i - 1) / u, u0 + (u1 - u0) * i / u,
                                                        v0 + (v1 - v0) * (j - 1) / v, v0 + (v1 - v0) * j / v));
  Handle(ShapeExtend_CompositeSurface) comp = new ShapeExtend_CompositeSurface(grid, ShapeExtend_Natural);
  ShapeFix_ComposeShell                csh;
  csh.Init(comp, TopLoc_Location(), face, 1e-6);
  csh.SetContext(new ShapeBuild_ReShape);
  csh.Perform();
  TopoDS_Shape r = csh.Result();
  printf("%s %dx%d: faces=%d areas:", label, u, v, count(r, TopAbs_FACE));
  double total = 0;
  for (TopExp_Explorer e(r, TopAbs_FACE); e.More(); e.Next())
  {
    GProp_GProps g;
    BRepGProp::SurfaceProperties(e.Current(), g);
    total += g.Mass();
    printf(" %.6f", g.Mass());
  }
  printf(" total=%.9f\n", total);
}

static const char* checkName(BRepCheck_Status s)
{
  return s == BRepCheck_NoError ? "NoError" : "error";
}

int main()
{
  // #1638
  TopoDS_Face face = planar10();
  for (auto uv : {std::make_pair(1, 1), std::make_pair(2, 1), std::make_pair(1, 2), std::make_pair(3, 2),
                  std::make_pair(4, 4), std::make_pair(2, 2)})
    compose("planar 10x10", face, uv.first, uv.second);
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopoDS_Face  wall;
  for (TopExp_Explorer e(cyl, TopAbs_FACE); e.More(); e.Next())
    if (BRep_Tool::Surface(TopoDS::Face(e.Current()))->DynamicType()->Name() == std::string("Geom_CylindricalSurface"))
      wall = TopoDS::Face(e.Current());
  GProp_GProps wg;
  BRepGProp::SurfaceProperties(wall, wg);
  printf("cylinder wall area=%.9f\n", wg.Mass());
  compose("cylinder wall", wall, 4, 1);
  compose("cylinder wall", wall, 1, 2);

  // #266: ShapeFix_Face on a clean 10x10 planar face (plane at z=0, polygon 0..10)
  {
    Handle(Geom_Plane)         pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    BRepBuilderAPI_MakePolygon p(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0), Standard_True);
    TopoDS_Face                f = BRepBuilderAPI_MakeFace(pl, p.Wire());
    {
      Handle(ShapeFix_Face) ff = new ShapeFix_Face(f);
      ff->SetContext(new ShapeBuild_ReShape);
      ff->SetPrecision(1e-7);
      ff->FixAddNaturalBoundMode()   = 0;
      ff->FixOrientationMode()       = 1;
      ff->FixIntersectingWiresMode() = -1;
      bool         done = ff->Perform();
      GProp_GProps g;
      BRepGProp::SurfaceProperties(ff->Face(), g);
      printf("ShapeFix_Face.Perform=%d OK=%d DONE=%d FAIL=%d resultNull=%d faceArea=%.9f\n", (int)done,
             (int)ff->Status(ShapeExtend_OK), (int)ff->Status(ShapeExtend_DONE), (int)ff->Status(ShapeExtend_FAIL),
             (int)ff->Result().IsNull(), g.Mass());
    }
    {
      Handle(ShapeFix_Face) ff = new ShapeFix_Face(f);
      ff->SetContext(new ShapeBuild_ReShape);
      ff->SetPrecision(1e-7);
      NCollection_Sequence<TopoDS_Shape> rw;
      printf("individual passes: FixIntersectingWires=%d FixWiresTwoCoincEdges=%d FixLoopWire=%d "
             "FixPeriodicDegenerated=%d faceNull=%d\n",
             (int)ff->FixIntersectingWires(), (int)ff->FixWiresTwoCoincEdges(), (int)ff->FixLoopWire(rw),
             (int)ff->FixPeriodicDegenerated(), (int)ff->Face().IsNull());
    }
    Handle(BRepCheck_Face) c = new BRepCheck_Face(f);
    c->GeometricControls(true);
    BRepCheck_Status iw = c->IntersectWires();
    BRepCheck_Status cw = c->ClassifyWires();
    BRepCheck_Status ow = c->OrientationOfWires();
    printf("BRepCheck_Face: IntersectWires=%s ClassifyWires=%s OrientationOfWires=%s\n", checkName(iw),
           checkName(cw), checkName(ow));
  }

  // #318: the fixture, read out of the Swift test file.
  {
    std::ifstream in("Tests/OCCTShapeHealingTests/Issue318DegenerateCurveOnSurfaceEdgeTests.swift");
    std::string   all((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    size_t        a = all.find("static let fixtureBREP = \"\"\"\n");
    size_t        z = all.find("\"\"\"", a + 30);
    std::string   body = all.substr(a + 29, z - (a + 29)), line, brep;
    std::istringstream ls(body);
    while (std::getline(ls, line))
      brep += (line.size() >= 8 ? line.substr(8) : std::string()) + "\n";
    std::istringstream bs(brep);
    TopoDS_Shape       s;
    BRep_Builder       bb;
    BRepTools::Read(s, bs, bb);
    int degenerate = 0, smallNonDegen = 0, smallAll = 0, edges = 0;
    for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
    {
      edges++;
      const TopoDS_Edge& ed = TopoDS::Edge(e.Current());
      GProp_GProps       g;
      BRepGProp::LinearProperties(ed, g);
      bool small = g.Mass() < 0.11477;
      if (BRep_Tool::Degenerated(ed))
        degenerate++;
      else if (small)
        smallNonDegen++;
      if (small)
        smallAll++;
    }
    printf("#318 fixture: null=%d type=%d faces=%d shells=%d edges(explored)=%d degenerate=%d "
           "small(non-degenerate)=%d small(all, no skip)=%d\n",
           (int)s.IsNull(), s.IsNull() ? -1 : (int)s.ShapeType(), count(s, TopAbs_FACE), count(s, TopAbs_SHELL),
           edges, degenerate, smallNonDegen, smallAll);
  }

  // #438: cubic BSpline surface, knots 0..5 with a mult-3 knot at 2, both directions.
  {
    const int               deg = 3;
    TColStd_Array1OfReal    k(1, 6);
    TColStd_Array1OfInteger m(1, 6);
    for (int i = 0; i <= 5; i++)
    {
      k(i + 1) = i;
      m(i + 1) = (i == 0 || i == 5) ? deg + 1 : (i == 2 ? 3 : 1);
    }
    int                poles = 4 + 1 + 3 + 1 + 1 + 4 - deg - 1;
    TColgp_Array2OfPnt P(1, poles, 1, poles);
    for (int u = 0; u < poles; u++)
      for (int v = 0; v < poles; v++)
        P(u + 1, v + 1) = gp_Pnt(u, v, ((u + v) % 3) * 0.5);
    Handle(Geom_BSplineSurface) bs = new Geom_BSplineSurface(P, k, k, m, m, deg, deg);
    double                      u0, u1, v0, v1;
    bs->Bounds(u0, u1, v0, v1);
    TopoDS_Face f = BRepBuilderAPI_MakeFace(bs, u0, u1, v0, v1, 1e-7);
    const char* names[] = {"C0", "C1", "C2", "C3", "CN", "G1", "G2"};
    GeomAbs_Shape levels[] = {GeomAbs_C0, GeomAbs_C1, GeomAbs_C2, GeomAbs_C3, GeomAbs_CN, GeomAbs_G1, GeomAbs_G2};
    for (int i = 0; i < 7; i++)
    {
      for (int boundaryOnly = 0; boundaryOnly <= 1; boundaryOnly++)
      {
        ShapeUpgrade_ShapeDivideContinuity d(f);
        d.SetBoundaryCriterion(levels[i]);
        if (!boundaryOnly)
        {
          d.SetPCurveCriterion(levels[i]);
          d.SetSurfaceCriterion(levels[i]);
        }
        d.SetTolerance(1e-4);
        d.SetSurfaceSegmentMode(Standard_True);
        bool ok = d.Perform();
        printf("#438 %s%s: Perform=%d faces=%d\n", names[i], boundaryOnly ? " (boundary criterion only)" : "",
               (int)ok, ok ? count(d.Result(), TopAbs_FACE) : -1);
      }
    }
  }
  return 0;
}
