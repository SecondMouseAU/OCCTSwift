// Epic #766, OCCTDrawingTests: RadiusDimensionTests (RadialDiameterSharedPayloadTests is pure
// Swift, the 2D DrawingDimension.Circular payload, and has no kernel counterpart).
// PrsDim_RadiusDimension built from a shape as OCCTDimensionCreateRadiusFromShape does: on the
// same circle wires, and on the centred 10-unit box the "non-circular" test uses.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <PrsDim_RadiusDimension.hxx>
#include <cstdio>

static void radius(const char* tag, const TopoDS_Shape& s)
{
  try
  {
    Handle(PrsDim_RadiusDimension) d = new PrsDim_RadiusDimension(s);
    gp_Circ                        c = d->Circle();
    printf("%s: value=%.17g valid=%d circleRadius=%.17g centre=(%g, %g, %g)\n", tag, d->GetValue(),
           d->IsValid(), c.Radius(), c.Location().X(), c.Location().Y(), c.Location().Z());
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", tag, e.GetMessageString());
  }
}

static TopoDS_Shape circleWire(double r)
{
  return BRepBuilderAPI_MakeWire(
           BRepBuilderAPI_MakeEdge(gp_Circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), r)))
    .Wire();
}

int main()
{
  radius("circleRadius r7", circleWire(7));
  radius("radiusGeometry r5", circleWire(5));
  radius("nonCircularFails box", BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape());
  return 0;
}
