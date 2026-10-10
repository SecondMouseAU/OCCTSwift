// #766 kernel parity: DivideByNumberTests, EncodeRegularityTests, FastSewingTests.
// Same OCCT calls, same inputs as OCCTShapeDivideByNumber, OCCTShapeEncodeRegularity,
// OCCTShapeFastSewn.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepBuilderAPI_FastSewing.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepLib.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_FaceDivideArea.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shell.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <cmath>
#include <cstdio>

static int nfaces(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    n++;
  return n;
}

static void divide(const char* label, const TopoDS_Shape& s, int nbU, int nbV)
{
  ShapeUpgrade_ShapeDivide                divider(s);
  Handle(ShapeUpgrade_FaceDivideArea) fd = new ShapeUpgrade_FaceDivideArea();
  fd->SetSplittingByNumber(true);
  fd->NbParts() = nbU * nbV;
  fd->MaxArea() = -1;
  fd->SetNumbersUVSplits(nbU, nbV);
  divider.SetSplitFaceTool(fd);
  bool ok = divider.Perform();
  printf("%s DivideByNumber(%d,%d): Perform=%d resultFaces=%d\n", label, nbU, nbV, (int)ok,
         divider.Result().IsNull() ? -1 : nfaces(divider.Result()));
}

// Continuity of every edge shared by exactly two faces.
static void continuities(const char* label, const TopoDS_Shape& s)
{
  TopTools_IndexedDataMapOfShapeListOfShape m;
  TopExp::MapShapesAndAncestors(s, TopAbs_EDGE, TopAbs_FACE, m);
  int shared = 0, encoded = 0, c0 = 0, above = 0;
  for (int i = 1; i <= m.Extent(); i++)
  {
    const TopTools_ListOfShape& fl = m(i);
    if (fl.Extent() != 2)
      continue;
    const TopoDS_Edge& e  = TopoDS::Edge(m.FindKey(i));
    const TopoDS_Face& f1 = TopoDS::Face(fl.First());
    const TopoDS_Face& f2 = TopoDS::Face(fl.Last());
    shared++;
    if (BRep_Tool::HasContinuity(e, f1, f2))
    {
      encoded++;
      if (BRep_Tool::Continuity(e, f1, f2) == GeomAbs_C0)
        c0++;
      else
        above++;
    }
  }
  printf("%s: sharedEdges=%d encoded=%d C0=%d aboveC0=%d\n", label, shared, encoded, c0, above);
}

static TopoDS_Shape encode(const TopoDS_Shape& s, double degrees)
{
  BRepBuilderAPI_Copy copier(s);
  TopoDS_Shape        r = copier.Shape();
  BRepLib::EncodeRegularity(r, degrees * M_PI / 180.0);
  return r;
}

// EncodeRegularityTests.nearTangentShell: two planar faces sharing one edge, tilted by theta.
static TopoDS_Shape nearTangentShell(double theta)
{
  const double W = 10.0, H = 1.0e7;
  gp_Pnt       p0(0, 0, 0), p1(W, 0, 0);
  double       y2 = -H * cos(theta), z2 = H * sin(theta);
  TopoDS_Edge  shared = BRepBuilderAPI_MakeEdge(p0, p1);
  TopoDS_Edge  e1b    = BRepBuilderAPI_MakeEdge(p1, gp_Pnt(W, H, 0));
  TopoDS_Edge  e1c    = BRepBuilderAPI_MakeEdge(gp_Pnt(W, H, 0), gp_Pnt(0, H, 0));
  TopoDS_Edge  e1d    = BRepBuilderAPI_MakeEdge(gp_Pnt(0, H, 0), p0);
  BRepBuilderAPI_MakeWire w1;
  w1.Add(shared);
  w1.Add(e1b);
  w1.Add(e1c);
  w1.Add(e1d);
  TopoDS_Face f1  = BRepBuilderAPI_MakeFace(w1.Wire(), Standard_True);
  TopoDS_Edge e2b = BRepBuilderAPI_MakeEdge(p1, gp_Pnt(W, y2, z2));
  TopoDS_Edge e2c = BRepBuilderAPI_MakeEdge(gp_Pnt(W, y2, z2), gp_Pnt(0, y2, z2));
  TopoDS_Edge e2d = BRepBuilderAPI_MakeEdge(gp_Pnt(0, y2, z2), p0);
  BRepBuilderAPI_MakeWire w2;
  w2.Add(TopoDS::Edge(shared.Reversed()));
  w2.Add(TopoDS::Edge(e2d.Reversed()));
  w2.Add(TopoDS::Edge(e2c.Reversed()));
  w2.Add(TopoDS::Edge(e2b.Reversed()));
  TopoDS_Face  f2 = BRepBuilderAPI_MakeFace(w2.Wire(), Standard_True);
  BRep_Builder b;
  TopoDS_Shell sh;
  b.MakeShell(sh);
  b.Add(sh, f1);
  b.Add(sh, f2);
  return sh;
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  divide("box", box, 4, 1);
  divide("box", box, 1, 1);
  divide("cylinder", cyl, 4, 1);

  // encodeRegularityBox: default degrees = 1e-10 rad expressed in degrees
  const double defDeg = 1.0e-10 * 180.0 / M_PI;
  continuities("box before encode", box);
  TopoDS_Shape eb = encode(box, defDeg);
  GProp_GProps p;
  BRepGProp::VolumeProperties(eb, p);
  printf("encoded box volume=%.9f\n", p.Mass());
  continuities("box after encode(default)", eb);

  // encodeRegularityFilleted: fillet every edge r=1 (OCCTShapeFillet), encode at 1 degree
  BRepFilletAPI_MakeFillet mf(box);
  for (TopExp_Explorer e(box, TopAbs_EDGE); e.More(); e.Next())
    mf.Add(1.0, TopoDS::Edge(e.Current()));
  mf.Build();
  TopoDS_Shape fb = mf.Shape();
  printf("filleted box faces=%d\n", nfaces(fb));
  continuities("filleted before encode", fb);
  continuities("filleted after encode(1 deg)", encode(fb, 1.0));

  // near-tangent fixture, theta = 1e-11 rad
  TopoDS_Shape sh = nearTangentShell(1e-11);
  continuities("nearTangent fixture", sh);
  continuities("nearTangent encode(default 1e-10 rad)", encode(sh, defDeg));
  continuities("nearTangent encode(1e-10 deg)", encode(sh, 1e-10));

  // FastSewing
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(10).Shape();
  for (double tol : {1e-6, 0.01})
  {
    BRepBuilderAPI_FastSewing fs(tol);
    bool                      added = fs.Add(sphere);
    fs.Perform();
    TopoDS_Shape r = fs.GetResult();
    GProp_GProps sp;
    if (!r.IsNull())
      BRepGProp::SurfaceProperties(r, sp);
    printf("FastSewing(sphere r10, tol=%g): added=%d null=%d type=%d faces=%d area=%.9f (4 pi r^2 = %.9f)\n", tol,
           (int)added, (int)r.IsNull(), r.IsNull() ? -1 : (int)r.ShapeType(), r.IsNull() ? -1 : nfaces(r),
           r.IsNull() ? 0.0 : sp.Mass(), 4 * M_PI * 100);
  }
  {
    BRepBuilderAPI_FastSewing fs(1e-6);
    bool                      added = fs.Add(box);
    fs.Perform();
    printf("FastSewing(box): added=%d resultNull=%d\n", (int)added, (int)fs.GetResult().IsNull());
  }
  return 0;
}
