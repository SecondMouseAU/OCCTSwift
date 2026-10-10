// #766 kernel parity: Issue1479HealingFixNullGuardsTests, Issue1491DivideByNumberUVAxesTests,
// Issue1491FixSmallCurvesRemovalTests. ShapeFix_ComposeShell (OCCTShapeFixComposeShell, 1x1 grid),
// ShapeFix_EdgeConnect (OCCTShapeFixEdgeConnect), ShapeUpgrade_ShapeDivide + FaceDivideArea
// (OCCTShapeDivideByNumber), ShapeFix_Wireframe::FixSmallEdges (OCCTShapeFixSmallEdges).
// The two null-pointer tests have no kernel counterpart: a null TopoDS_Shape handed to
// BRep_Tool::Surface is a SIGSEGV, which is what the bridge guards exist to prevent.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Tool.hxx>
#include <BRepTools.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <ShapeExtend_CompositeSurface.hxx>
#include <ShapeFix_ComposeShell.hxx>
#include <ShapeFix_EdgeConnect.hxx>
#include <ShapeFix_Wireframe.hxx>
#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_FaceDivideArea.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <NCollection_HArray2.hxx>
#include <cstdio>

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  int n = 0;
  for (TopExp_Explorer e(s, t); e.More(); e.Next())
    n++;
  return n;
}

static TopoDS_Face centredRect(double w, double h)
{
  BRepBuilderAPI_MakePolygon p(gp_Pnt(-w / 2, -h / 2, 0), gp_Pnt(w / 2, -h / 2, 0), gp_Pnt(w / 2, h / 2, 0),
                               gp_Pnt(-w / 2, h / 2, 0), Standard_True);
  Handle(Geom_Plane) pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  return BRepBuilderAPI_MakeFace(pl, p.Wire());
}

static void divide(const TopoDS_Shape& s, int nbU, int nbV, bool uvSplits)
{
  ShapeUpgrade_ShapeDivide            d(s);
  Handle(ShapeUpgrade_FaceDivideArea) fd = new ShapeUpgrade_FaceDivideArea();
  fd->SetSplittingByNumber(true);
  fd->NbParts() = nbU * nbV;
  fd->MaxArea() = -1;
  if (uvSplits)
    fd->SetNumbersUVSplits(nbU, nbV);
  d.SetSplitFaceTool(fd);
  bool ok = d.Perform();
  printf("elongated 100x1 DivideByNumber(%d,%d) SetNumbersUVSplits=%d: Perform=%d faces=%d\n", nbU, nbV,
         (int)uvSplits, (int)ok, count(d.Result(), TopAbs_FACE));
}

int main()
{
  // composeShellOrdinaryFaceUnaffected: 10x10 face, 1x1 grid (the composeShell() defaults).
  {
    TopoDS_Face          face = centredRect(10, 10);
    Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
    double               u0, u1, v0, v1;
    BRepTools::UVBounds(face, u0, u1, v0, v1);
    Handle(NCollection_HArray2<Handle(Geom_Surface)>) grid =
      new NCollection_HArray2<Handle(Geom_Surface)>(1, 1, 1, 1);
    grid->SetValue(1, 1, new Geom_RectangularTrimmedSurface(surf, u0, u1, v0, v1));
    Handle(ShapeExtend_CompositeSurface) comp = new ShapeExtend_CompositeSurface(grid, ShapeExtend_Natural);
    ShapeFix_ComposeShell                csh;
    csh.Init(comp, TopLoc_Location(), face, 1e-6);
    csh.Perform();
    TopoDS_Shape r = csh.Result();
    GProp_GProps p;
    BRepGProp::SurfaceProperties(r, p);
    printf("ComposeShell(10x10 face, 1x1): null=%d type=%d faces=%d area=%.9f valid=%d\n", (int)r.IsNull(),
           (int)r.ShapeType(), count(r, TopAbs_FACE), p.Mass(), (int)BRepCheck_Analyzer(r).IsValid());
  }
  // edgeConnectOrdinaryShapeUnaffected
  {
    TopoDS_Shape         box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    ShapeFix_EdgeConnect ec;
    ec.Add(box);
    ec.Build();
    GProp_GProps p;
    BRepGProp::VolumeProperties(box, p);
    printf("EdgeConnect(box): faces=%d edges=%d volume=%.9f valid=%d\n", count(box, TopAbs_FACE),
           count(box, TopAbs_EDGE), p.Mass(), (int)BRepCheck_Analyzer(box).IsValid());
    // Which sub-shapes BRepCheck rejects after the in-place EdgeConnect.
    BRepCheck_Analyzer an(box);
    for (TopAbs_ShapeEnum t : {TopAbs_VERTEX, TopAbs_EDGE, TopAbs_WIRE, TopAbs_FACE, TopAbs_SHELL, TopAbs_SOLID})
    {
      int bad = 0, total = 0;
      for (TopExp_Explorer e(box, t); e.More(); e.Next())
      {
        total++;
        if (!an.IsValid(e.Current()))
          bad++;
      }
      printf("  after EdgeConnect: type %d invalid %d of %d\n", (int)t, bad, total);
    }
    TopoDS_Shape fresh = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    printf("fresh box valid=%d\n", (int)BRepCheck_Analyzer(fresh).IsValid());
  }
  // #1491 divide-by-number on the elongated face
  {
    TopoDS_Face face = centredRect(100, 1);
    divide(face, 5, 1, true);
    divide(face, 1, 5, true);
    divide(face, 6, 1, true);
    divide(face, 5, 1, false);
    divide(face, 1, 5, false);
    divide(face, 6, 1, false);
  }
  // #1491 fixSmallEdges: 10x10 face with the bottom side split at x=5 by a 0.1 edge
  {
    gp_Pnt p[] = {gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 0), gp_Pnt(5.1, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0),
                  gp_Pnt(0, 10, 0)};
    BRepBuilderAPI_MakeWire mw;
    for (int i = 0; i < 6; i++)
      mw.Add(BRepBuilderAPI_MakeEdge(p[i], p[(i + 1) % 6]));
    Handle(Geom_Plane) pl   = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    TopoDS_Face        face = BRepBuilderAPI_MakeFace(pl, mw.Wire());
    printf("tiny-edge face edges=%d\n", count(face, TopAbs_EDGE));
    for (double tol : {0.5, 1e-7})
    {
      Handle(ShapeFix_Wireframe) fx = new ShapeFix_Wireframe(face);
      fx->SetPrecision(tol);
      fx->ModeDropSmallEdges() = Standard_True;
      fx->FixSmallEdges();
      printf("FixSmallEdges(tol=%g, drop): edges=%d\n", tol, count(fx->Shape(), TopAbs_EDGE));
    }
  }
  return 0;
}
