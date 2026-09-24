// Epic #766, OCCTDrawingTests: CylindricalProjectionTests, DiameterDimensionTests.
// Same inputs as the Swift tests, straight to OCCT. CosmeticThreadTests is pure Swift
// (DrawingAnnotation factories and the DXF/PDF/SVG writers) and has no kernel counterpart.
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepProj_Projection.hxx>
#include <Bnd_Box.hxx>
#include <GC_MakeCircle.hxx>
#include <PrsDim_DiameterDimension.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

static void report(const char* tag, const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(s, TopAbs_EDGE, edges);
  Bnd_Box b;
  BRepBndLib::Add(s, b, true);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: edges=%d bbox=(%.9g, %.9g, %.9g)..(%.9g, %.9g, %.9g)\n", tag, edges.Extent(), x0, y0,
         z0, x1, y1, z1);
}

static TopoDS_Wire circleWire(double r)
{
  gp_Circ c(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), r);
  return BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(c)).Wire();
}

int main()
{
  {
    gp_Trsf t;
    t.SetTranslation(gp_Vec(5, 5, 20));
    TopoDS_Shape        circ = BRepBuilderAPI_Transform(circleWire(3), t, true).Shape();
    // Shape.box(width:height:depth:) is centred on the origin (OCCTShapeCreateBox).
    TopoDS_Shape        box  = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -2.5), 10, 10, 5).Shape();
    BRepProj_Projection p(circ, box, gp_Dir(0, 0, -1));
    printf("projectWireOntoBox: IsDone=%d\n", p.IsDone());
    if (p.IsDone())
      report("projectWireOntoBox", p.Shape());
  }
  {
    TopoDS_Wire line =
      BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Pnt(-3, 0, 8), gp_Pnt(3, 0, 8))).Wire();
    TopoDS_Shape        sphere = BRepPrimAPI_MakeSphere(10).Shape();
    BRepProj_Projection p(line, sphere, gp_Dir(0, 0, -1));
    printf("projectEdgeOntoSphere: IsDone=%d\n", p.IsDone());
    if (p.IsDone())
      report("projectEdgeOntoSphere", p.Shape());
  }
  for (double r : {8.0, 5.0})
  {
    Handle(PrsDim_DiameterDimension) d = new PrsDim_DiameterDimension(circleWire(r));
    gp_Circ                          c = d->Circle();
    gp_Pnt                           a = d->AnchorPoint();
    gp_Pnt opp = c.Location().Translated(-gp_Vec(c.Location(), a));
    printf("diameter r=%g: value=%.17g valid=%d circleRadius=%.17g anchor=(%.9g, %.9g, %.9g) "
           "endpointDistance=%.17g\n",
           r, d->GetValue(), d->IsValid(), c.Radius(), a.X(), a.Y(), a.Z(), a.Distance(opp));
    d->SetCustomValue(99.0);
    printf("diameter r=%g: after SetCustomValue(99) value=%.17g\n", r, d->GetValue());
  }
  return 0;
}
