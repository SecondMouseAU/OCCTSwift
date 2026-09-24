// #766 kernel parity: FreeBoundsPropertiesTests, FreeBoundsSimplifiedTests.
// ShapeAnalysis_FreeBoundsProperties (OCCTFreeBoundsProps*) and ShapeAnalysis_FreeBounds
// (OCCTShapeFreeBoundsClosedCount / Closed / Open) on the same fixtures.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRep_Builder.hxx>
#include <ShapeAnalysis_FreeBoundsProperties.hxx>
#include <ShapeAnalysis_FreeBoundData.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <cstdio>

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  int n = 0;
  for (TopExp_Explorer e(s, t); e.More(); e.Next())
    n++;
  return n;
}

static TopoDS_Face square(double z)
{
  BRepBuilderAPI_MakePolygon p(gp_Pnt(0, 0, z), gp_Pnt(10, 0, z), gp_Pnt(10, 10, z), gp_Pnt(0, 10, z),
                               Standard_True);
  return BRepBuilderAPI_MakeFace(p.Wire());
}

static void props(const char* label, const TopoDS_Shape& s, double tol)
{
  ShapeAnalysis_FreeBoundsProperties fbp;
  fbp.Init(s, tol);
  fbp.Perform();
  printf("%s: total=%d closed=%d open=%d\n", label, (int)fbp.NbFreeBounds(), (int)fbp.NbClosedFreeBounds(),
         (int)fbp.NbOpenFreeBounds());
  for (int i = 1; i <= fbp.NbClosedFreeBounds(); i++)
  {
    Handle(ShapeAnalysis_FreeBoundData) d = fbp.ClosedFreeBound(i);
    TopoDS_Wire                         w = d->FreeBound();
    printf("  closed[%d]: area=%.9f perimeter=%.9f ratio=%.9f width=%.9f notches=%d wireEdges=%d\n", i - 1,
           d->Area(), d->Perimeter(), d->Ratio(), d->Width(), (int)d->NbNotches(), count(w, TopAbs_EDGE));
  }
}

static void simple(const char* label, const TopoDS_Shape& s, double tol)
{
  ShapeAnalysis_FreeBounds a(s, tol);
  TopoDS_Compound          c = a.GetClosedWires(), o = a.GetOpenWires();
  printf("%s tol=%g: closed null=%d wires=%d edges=%d; open null=%d wires=%d\n", label, tol, (int)c.IsNull(),
         c.IsNull() ? -1 : count(c, TopAbs_WIRE), c.IsNull() ? -1 : count(c, TopAbs_EDGE), (int)o.IsNull(),
         o.IsNull() ? -1 : count(o, TopAbs_WIRE));
}

int main()
{
  BRep_Builder    b;
  TopoDS_Compound two;
  b.MakeCompound(two);
  b.Add(two, square(0));
  b.Add(two, square(5));
  props("twoFaces compound", two, 0.01);
  props("lone face", square(0), 0.01);
  // what the lone face would report if wrapped in a compound (the FBWRAP injection)
  TopoDS_Compound one;
  b.MakeCompound(one);
  b.Add(one, square(0));
  props("lone face wrapped in compound", one, 0.01);

  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  simple("box", box, 1e-6);
  TopExp_Explorer fe(box, TopAbs_FACE);
  simple("box first face", fe.Current(), 1e-6);
  // The non-sewing constructor (the FBNOSEW injection) on the same face.
  ShapeAnalysis_FreeBounds ns(fe.Current(), Standard_False, Standard_True, Standard_False);
  printf("box first face, non-sewing ctor: closed wires=%d\n", count(ns.GetClosedWires(), TopAbs_WIRE));
  return 0;
}
