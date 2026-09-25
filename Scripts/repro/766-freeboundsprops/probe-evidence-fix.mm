// #766 evidence fix for FreeBoundsPropsTests.performIsIdempotent.
//
// The test builds FreeBoundsProperties on two 10 x 10 rectangles 5 apart (tolerance 0.01), calls
// perform() once and reads closedCount (2), then calls perform() twice more and reads it again.
// The bridge latches the analysis (#504), so the count stays 2. Raw OCCT does not: its Perform()
// appends to the result sequences on every call. probe.mm printed the count after a second
// Perform() (4); this probe repeats the test's exact sequence, three Perform() calls on one
// ShapeAnalysis_FreeBoundsProperties, so the kernel side of the record has the same shape as the
// bridge side.
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRep_Builder.hxx>
#include <ShapeAnalysis_FreeBoundsProperties.hxx>
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

int main()
{
  const double    w = 10, h = 10;
  BRep_Builder    b;
  TopoDS_Compound c;
  b.MakeCompound(c);
  b.Add(c, poly({gp_Pnt(0, 0, 0), gp_Pnt(w, 0, 0), gp_Pnt(w, h, 0), gp_Pnt(0, h, 0)}));
  b.Add(c, poly({gp_Pnt(0, 0, 5), gp_Pnt(w, 0, 5), gp_Pnt(w, h, 5), gp_Pnt(0, h, 5)}));

  ShapeAnalysis_FreeBoundsProperties fbp;
  fbp.Init(c, 0.01);
  for (int call = 1; call <= 3; call++)
  {
    fbp.Perform();
    printf("performIsIdempotent (twoRects 10x10, tol 0.01), Perform() call %d: closed=%d open=%d "
           "total=%d\n",
           call, fbp.NbClosedFreeBounds(), fbp.NbOpenFreeBounds(), fbp.NbFreeBounds());
  }
  return 0;
}
