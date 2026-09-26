// #2765: does OCCTShapeConvertToBezier's `if (!converter.Perform()) return nullptr;` reject a
// shape that converted fine, or one that needed no conversion at all?
//
// Runs the bridge function's exact converter configuration against several inputs and prints,
// per input, Perform()'s return value, whether Result() is null, and whether Result() differs
// from the input. A row with perform=false and result non-null is a shape the bridge turns into
// nil today.
//
// Compile line: Scripts/repro/2765-convert-to-bezier-perform/README.md

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <GC_MakeSegment.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BezierSurface.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>

// The exact mode set of OCCTShapeConvertToBezier (OCCTBridge_Healing_Upgrade.mm).
static void configure(ShapeUpgrade_ShapeConvertToBezier& c)
{
  c.Set2dConversion(true);
  c.Set3dConversion(true);
  c.SetSurfaceConversion(true);
  c.Set3dLineConversion(true);
  c.Set3dCircleConversion(true);
  c.Set3dConicConversion(true);
  c.SetPlaneMode(true);
  c.SetRevolutionMode(true);
  c.SetExtrusionMode(true);
  c.SetBSplineMode(true);
}

static int countFaces(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    n++;
  return n;
}

static int nonBezierSurfaces(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
  {
    TopLoc_Location      loc;
    Handle(Geom_Surface) surf = BRep_Tool::Surface(TopoDS::Face(e.Current()), loc);
    if (surf.IsNull() || !surf->IsKind(STANDARD_TYPE(Geom_BezierSurface)))
      n++;
  }
  return n;
}

static int nonBezierCurves(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
  {
    double             f = 0, l = 0;
    Handle(Geom_Curve) c = BRep_Tool::Curve(TopoDS::Edge(e.Current()), f, l);
    if (c.IsNull() || !c->IsKind(STANDARD_TYPE(Geom_BezierCurve)))
      n++;
  }
  return n;
}

// Returns Result(), so a caller can feed a converted shape straight back in.
static TopoDS_Shape run(const char* label, const TopoDS_Shape& in)
{
  ShapeUpgrade_ShapeConvertToBezier converter(in);
  configure(converter);
  const bool         perform = converter.Perform();
  const TopoDS_Shape out     = converter.Result();
  printf("%-36s perform=%-5s result-null=%-5s differs=%-5s "
         "faces=%d non-bezier-surf=%d non-bezier-curv=%d  -> bridge today: %s\n",
         label,
         perform ? "true" : "false",
         out.IsNull() ? "true" : "false",
         (out.IsNull() || out.IsSame(in)) ? "false" : "true",
         out.IsNull() ? -1 : countFaces(out),
         out.IsNull() ? -1 : nonBezierSurfaces(out),
         out.IsNull() ? -1 : nonBezierCurves(out),
         (!perform || out.IsNull()) ? "nil" : "shape");
  return out;
}

int main()
{
  printf("#2765 probe: ShapeUpgrade_ShapeConvertToBezier::Perform() as a success flag\n\n");

  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  printf("box input : faces=%d non-bezier-surf=%d non-bezier-curv=%d\n",
         countFaces(box),
         nonBezierSurfaces(box),
         nonBezierCurves(box));
  TopoDS_Shape box1 = run("box, 1st conversion", box);
  if (!box1.IsNull())
  {
    TopoDS_Shape box2 = run("box, 2nd conversion", box1);
    if (!box2.IsNull())
      run("box, 3rd conversion", box2);
  }
  printf("\n");

  TopoDS_Shape cyl  = BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape();
  TopoDS_Shape cyl1 = run("cylinder, 1st conversion", cyl);
  if (!cyl1.IsNull())
    run("cylinder, 2nd conversion", cyl1);
  printf("\n");

  TopoDS_Shape sph  = BRepPrimAPI_MakeSphere(5.0).Shape();
  TopoDS_Shape sph1 = run("sphere, 1st conversion", sph);
  if (!sph1.IsNull())
    run("sphere, 2nd conversion", sph1);
  printf("\n");

  // Shapes with no geometry the converter can touch.
  TopoDS_Shape vertex = BRepBuilderAPI_MakeVertex(gp_Pnt(1, 2, 3)).Shape();
  run("single vertex", vertex);

  TopoDS_Shape edge =
    BRepBuilderAPI_MakeEdge(GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0)).Value()).Shape();
  TopoDS_Shape edge1 = run("free line edge, 1st conversion", edge);
  if (!edge1.IsNull())
    run("free line edge, 2nd conversion", edge1);

  return 0;
}
