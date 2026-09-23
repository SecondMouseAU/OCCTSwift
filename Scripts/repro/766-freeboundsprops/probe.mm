// #766 kernel parity for Tests/OCCTAnalysisTests/FreeBoundsPropsTests.swift.
// Same OCCT calls as OCCTFreeBoundsPropsCreate/Perform/Counts/Info/Wire
// (OCCTBridge_Healing_Analysis.mm): ShapeAnalysis_FreeBoundsProperties::Init(shape, tolerance),
// Perform() once, then NbClosedFreeBounds/NbOpenFreeBounds and the ShapeAnalysis_FreeBoundData
// Area/Perimeter/Ratio/Width/NbNotches of each bound. Shapes are built as the Swift fixtures build
// them: an origin-centred box, faces taken in TopTools_IndexedMapOfShape order
// (OCCTShapeGetSubShapes), BRepBuilderAPI_MakePolygon + BRepBuilderAPI_MakeFace for the
// rectangles, BRep_Builder compounds.
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <ShapeAnalysis_FreeBoundData.hxx>
#include <ShapeAnalysis_FreeBoundsProperties.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <cstdio>
#include <vector>

static TopoDS_Face poly(const std::vector<gp_Pnt>& pts)
{
  BRepBuilderAPI_MakePolygon p;
  for (const gp_Pnt& x : pts)
    p.Add(x);
  p.Close();
  return BRepBuilderAPI_MakeFace(p.Wire(), true).Face();
}

static TopoDS_Compound compound(const std::vector<TopoDS_Shape>& shapes)
{
  BRep_Builder    b;
  TopoDS_Compound c;
  b.MakeCompound(c);
  for (const TopoDS_Shape& s : shapes)
    b.Add(c, s);
  return c;
}

static TopoDS_Compound twoRects(double w, double h)
{
  return compound({poly({gp_Pnt(0, 0, 0), gp_Pnt(w, 0, 0), gp_Pnt(w, h, 0), gp_Pnt(0, h, 0)}),
                   poly({gp_Pnt(0, 0, 5), gp_Pnt(w, 0, 5), gp_Pnt(w, h, 5), gp_Pnt(0, h, 5)})});
}

static void run(const char* name, const TopoDS_Shape& s, double tol)
{
  ShapeAnalysis_FreeBoundsProperties fbp;
  fbp.Init(s, tol);
  fbp.Perform();
  printf("%s: tol=%g total=%d closed=%d open=%d\n", name, tol, fbp.NbFreeBounds(),
         fbp.NbClosedFreeBounds(), fbp.NbOpenFreeBounds());
  for (int i = 1; i <= fbp.NbClosedFreeBounds(); ++i)
  {
    Handle(ShapeAnalysis_FreeBoundData) d = fbp.ClosedFreeBound(i);
    printf("  closed[%d] area=%.17g perimeter=%.17g ratio=%.17g width=%.17g notches=%d wireNull=%d\n",
           i - 1, d->Area(), d->Perimeter(), d->Ratio(), d->Width(), d->NbNotches(),
           d->FreeBound().IsNull() ? 1 : 0);
  }
  // A second Perform() on the same object: OCCT appends (#504), which the bridge latches against.
  fbp.Perform();
  printf("  after a second Perform(): closed=%d\n", fbp.NbClosedFreeBounds());
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box, TopAbs_FACE, faces);

  run("boxFaceFreeBounds (faces[0])", faces(1), 1e-7);
  // Context for the single-face result: the same face at a larger sewing tolerance, and at 0
  // (no sewing stage, free edges taken from the shape's shared topology).
  run("single box face, tol 1e-3", faces(1), 1e-3);
  run("single box face, tol 0", faces(1), 0);
  run("shellWithHoleFreeBounds (faces[0..4])",
      compound({faces(1), faces(2), faces(3), faces(4), faces(5)}), 1e-3);
  run("performIsIdempotent / accessorsRunTheAnalysisOnDemand / indexOutOfRange / "
      "squareBoundReportsNoRatioOrWidth (twoRects 10x10)",
      twoRects(10, 10), 0.01);
  run("ratioAndWidthAreAnAspectRatio (twoRects 20x10)", twoRects(20, 10), 0.01);
  TopoDS_Face notched = poly({gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0),
                              gp_Pnt(5.05, 10, 0), gp_Pnt(5.0, 1, 0), gp_Pnt(4.95, 10, 0),
                              gp_Pnt(0, 10, 0)});
  TopoDS_Face plain =
    poly({gp_Pnt(0, 0, 5), gp_Pnt(10, 0, 5), gp_Pnt(10, 10, 5), gp_Pnt(0, 10, 5)});
  run("notchesAreCounted", compound({notched, plain}), 0.01);
  return 0;
}
