// Epic #766, OCCTDrawingTests: DrawingAutoCentrelinesTests (DrawingAppendTests is pure Swift,
// the annotation and dimension stores, and has no kernel counterpart).
// Revolution axes walk faces with BRepAdaptor_Surface as OCCTShapeRevolutionAxes does; the view
// frame is gp_Ax2(origin, view), the frame OCCTDrawingCreate's HLRAlgo_Projector uses.
#include <BRepAdaptor_Surface.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void axes(const TopoDS_Shape& s, const char* tag)
{
  int n = 0;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    BRepAdaptor_Surface a(TopoDS::Face(ex.Current()));
    if (a.GetType() != GeomAbs_Cylinder)
      continue;
    gp_Ax1 ax = a.Cylinder().Axis();
    printf("%s: cylinder axis origin=(%g, %g, %g) dir=(%g, %g, %g)\n", tag, ax.Location().X(),
           ax.Location().Y(), ax.Location().Z(), ax.Direction().X(), ax.Direction().Y(),
           ax.Direction().Z());
    n++;
  }
  printf("%s: revolution faces=%d\n", tag, n);
}

int main()
{
  axes(BRepPrimAPI_MakeCylinder(5, 20).Shape(), "cylinder");
  axes(BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(), "boxNoCentrelines");
  for (gp_Dir v : {gp_Dir(0, 0, 1), gp_Dir(0, 1, 0)})
  {
    gp_Ax2 f(gp_Pnt(0, 0, 0), v);
    gp_Vec X(f.XDirection()), Y(f.YDirection()), axis(0, 0, 1);
    printf("view (%g, %g, %g): X=(%g, %g, %g) Y=(%g, %g, %g) cylinder axis projects to (%.17g, %.17g)\n",
           v.X(), v.Y(), v.Z(), X.X(), X.Y(), X.Z(), Y.X(), Y.Y(), Y.Z(), axis.Dot(X), axis.Dot(Y));
  }
  // Down +Y the axis projects to (1, 0) through the origin; clipped to x in [-50, 50] and pushed
  // out by the default 5 overshoot, the centreline is (-55, 0) to (55, 0).
  return 0;
}
