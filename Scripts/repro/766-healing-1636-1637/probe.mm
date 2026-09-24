// #766 kernel parity: Issue1636FixedFreeBoundsShapeTests, Issue1637BSplineRestrictionParametersTests.
// ShapeFix_FreeBounds (OCCTShapeFixFreeBounds) and ShapeCustom::BSplineRestriction with a
// ShapeCustom_RestrictionParameters (OCCTShapeCustomBSplineRestriction), same inputs.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <ShapeFix_FreeBounds.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <cstdio>
#include <cstring>
#include <map>
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

static TopoDS_Face rect(double dx)
{
  BRepBuilderAPI_MakePolygon p(gp_Pnt(-5 + dx, -5, 0), gp_Pnt(5 + dx, -5, 0), gp_Pnt(5 + dx, 5, 0),
                               gp_Pnt(-5 + dx, 5, 0), Standard_True);
  return BRepBuilderAPI_MakeFace(p.Wire());
}

static void fix(const char* label, const TopoDS_Shape& s, double sew, double close)
{
  ShapeFix_FreeBounds f(s, sew, close, Standard_True, Standard_True);
  printf("%s (sew %g, close %g): shapeFaces=%d shapeEdges=%d inputEdges=%d closedWires=%d openWires=%d "
         "closedCompoundFaces=%d isSameInput=%d\n",
         label, sew, close, count(f.GetShape(), TopAbs_FACE), count(f.GetShape(), TopAbs_EDGE),
         count(s, TopAbs_EDGE), count(f.GetClosedWires(), TopAbs_WIRE), count(f.GetOpenWires(), TopAbs_WIRE),
         count(f.GetClosedWires(), TopAbs_FACE), (int)f.GetShape().IsSame(s));
}

static void restrict(const char* label, const TopoDS_Shape& s, double tol, bool all, bool cylOnly, bool planeOnly)
{
  Handle(ShapeCustom_RestrictionParameters) p = new ShapeCustom_RestrictionParameters();
  if (all)
  {
    p->ConvertPlane() = p->ConvertBezierSurf() = p->ConvertRevolutionSurf() = p->ConvertExtrusionSurf() =
      p->ConvertOffsetSurf() = p->ConvertCylindricalSurf() = p->ConvertConicalSurf() =
        p->ConvertToroidalSurf() = p->ConvertSphericalSurf() = true;
  }
  if (cylOnly)
    p->ConvertCylindricalSurf() = true;
  if (planeOnly)
    p->ConvertPlane() = true;
  // Swift defaults: maxDegree 8, maxSegments 100, C1/C1, degreePriority true, rational false.
  TopoDS_Shape r = ShapeCustom::BSplineRestriction(s, tol, tol, 8, 100, GeomAbs_C1, GeomAbs_C1, true, false, p);
  std::map<std::string, int> kinds;
  for (TopExp_Explorer e(r, TopAbs_FACE); e.More(); e.Next())
    kinds[BRep_Tool::Surface(TopoDS::Face(e.Current()))->DynamicType()->Name()]++;
  GProp_GProps g;
  BRepGProp::VolumeProperties(r, g);
  printf("%s (tol %g): faces=%d volume=%.9f", label, tol, count(r, TopAbs_FACE), g.Mass());
  for (auto& k : kinds)
    printf(" %s=%d", k.first.c_str(), k.second);
  printf("\n");
}

int main()
{
  BRep_Builder    b;
  TopoDS_Compound two;
  b.MakeCompound(two);
  b.Add(two, rect(0));
  b.Add(two, rect(10));
  fix("two adjacent faces", two, 1e-6, 1e-4);

  TopoDS_Shape    box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Compound open;
  b.MakeCompound(open);
  int i = 0;
  for (TopExp_Explorer e(box, TopAbs_FACE); e.More(); e.Next(), i++)
    if (i < 5)
      b.Add(open, e.Current());
  fix("five box faces (open shell)", open, 1e-6, 1e-4);   // Swift defaults for fixedFreeBounds()

  TopoDS_Compound gap;
  b.MakeCompound(gap);
  b.Add(gap, rect(0));
  b.Add(gap, rect(10.00005));
  fix("two faces 5e-5 apart", gap, 1e-6, 1e-3);
  fix("two faces 5e-5 apart, tolerances swapped (FIXFBTOL)", gap, 1e-3, 1e-6);

  Handle(ShapeCustom_RestrictionParameters) d = new ShapeCustom_RestrictionParameters();
  printf("kernel defaults: plane=%d bezier=%d revolution=%d extrusion=%d offset=%d cylindrical=%d conical=%d "
         "toroidal=%d spherical=%d segment=%d curve3d=%d offset3d=%d curve2d=%d offset2d=%d\n",
         (int)d->ConvertPlane(), (int)d->ConvertBezierSurf(), (int)d->ConvertRevolutionSurf(),
         (int)d->ConvertExtrusionSurf(), (int)d->ConvertOffsetSurf(), (int)d->ConvertCylindricalSurf(),
         (int)d->ConvertConicalSurf(), (int)d->ConvertToroidalSurf(), (int)d->ConvertSphericalSurf(),
         (int)d->SegmentSurfaceMode(), (int)d->ConvertCurve3d(), (int)d->ConvertOffsetCurv3d(),
         (int)d->ConvertCurve2d(), (int)d->ConvertOffsetCurv2d());

  TopoDS_Shape cyl   = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopoDS_Shape sph   = BRepPrimAPI_MakeSphere(5).Shape();
  TopoDS_Shape torus = BRepPrimAPI_MakeTorus(10, 3).Shape();
  GProp_GProps g;
  BRepGProp::VolumeProperties(cyl, g);
  printf("cylinder volume=%.9f\n", g.Mass());
  restrict("cylinder, defaults", cyl, 0.01, false, false, false);
  restrict("cylinder, all kinds", cyl, 0.01, true, false, false);
  restrict("sphere, all kinds", sph, 0.01, true, false, false);
  restrict("torus, all kinds", torus, 0.01, true, false, false);
  restrict("cylinder, cylindrical only", cyl, 0.01, false, true, false);
  restrict("cylinder, planes only", cyl, 0.01, false, false, true);
  restrict("cylinder, all kinds", cyl, 0.001, true, false, false);
  restrict("cylinder, all kinds, tol x1000 (RTOL)", cyl, 1.0, true, false, false);
  return 0;
}
