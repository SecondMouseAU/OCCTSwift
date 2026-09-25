// #766 evidence re-measurement for LocalPropsParityTests.swift (#494).
//
// probe.mm printed several kernel values at 6 significant digits (tangents) or at v values that are
// not the test's (the cone-apex sweep took the apex from -RefRadius / sin(SemiAngle), the test takes
// (5*5 + 10*10).squareRoot(), and H there moves by about 2e-9 relative for a 2e-15 change in v).
// This probe prints every value a parity record carries, at %.17g, at the test's own parameters, at
// Precision::Confusion(), the resolution occtSurfaceLocalProps / occtCurveLocalProps use.
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <NCollection_Array1.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>
#include <typeinfo>

static const double C = Precision::Confusion();

static void surf(const char* label, const Handle(Geom_Surface)& s, double u, double v)
{
  GeomLProp_SLProps p(s, u, v, 2, C);
  bool              def = p.IsCurvatureDefined();
  printf("%s u=%.17g v=%.17g: defined=%d", label, u, v, def);
  if (def)
    printf(" kmax=%.17g kmin=%.17g K=%.17g H=%.17g umbilic=%d", p.MaxCurvature(), p.MinCurvature(),
           p.GaussianCurvature(), p.MeanCurvature(), p.IsUmbilic());
  printf("\n");
}

static Handle(Geom_BezierCurve) cusp(double spacing)
{
  NCollection_Array1<gp_Pnt> poles(1, 4);
  poles(1) = gp_Pnt(0, 0, 0);
  poles(2) = gp_Pnt(spacing, 0, 0);
  poles(3) = gp_Pnt(1, 1, 0);
  poles(4) = gp_Pnt(2, 0, 0);
  return new Geom_BezierCurve(poles);
}

// One curve point: tangent and curvature, and the raw CentreOfCurvature (which the bridge refuses
// to return when the curvature is RealLast or 0).
static void curve(const char* label, const Handle(Geom_Curve)& c, double u)
{
  GeomLProp_CLProps p(c, u, 2, C);
  printf("%s u=%.17g: tangentDefined=%d", label, u, p.IsTangentDefined());
  if (p.IsTangentDefined())
  {
    gp_Dir t;
    p.Tangent(t);
    double k = p.Curvature();
    printf(" tangent=(%.17g, %.17g, %.17g) curvature=%.17g%s", t.X(), t.Y(), t.Z(), k,
           k == RealLast() ? " (RealLast)" : "");
    try
    {
      gp_Pnt c0;
      p.CentreOfCurvature(c0);
      printf(" rawCentre=(%.17g, %.17g, %.17g)", c0.X(), c0.Y(), c0.Z());
    }
    catch (const Standard_Failure& ex)
    {
      printf(" rawCentre raises %s", typeid(ex).name());
    }
  }
  printf("\n");
}

// The raw kernel side of "no entry point returns a non-finite number": every value the four
// curve quantities return for a defined tangent, counted, and every non-finite one named.
static int g_returned    = 0;
static int g_nonFinite   = 0;
static int g_raised      = 0;
static void note(const char* what, double v)
{
  ++g_returned;
  if (!std::isfinite(v))
  {
    ++g_nonFinite;
    printf("    non-finite %s = %.17g\n", what, v);
  }
}

static void rawCurveSweep(const char* label, const Handle(Geom_Curve)& c, double u)
{
  GeomLProp_CLProps p(c, u, 2, C);
  printf("  %s u=%.17g\n", label, u);
  if (!p.IsTangentDefined())
    return;
  gp_Dir t;
  p.Tangent(t);
  note("tangent.x", t.X());
  note("tangent.y", t.Y());
  note("tangent.z", t.Z());
  note("curvature", p.Curvature());
  try
  {
    gp_Dir n;
    p.Normal(n);
    note("normal.x", n.X());
    note("normal.y", n.Y());
    note("normal.z", n.Z());
  }
  catch (const Standard_Failure&)
  {
    ++g_raised;
  }
  try
  {
    gp_Pnt c0;
    p.CentreOfCurvature(c0);
    note("centre.x", c0.X());
    note("centre.y", c0.Y());
    note("centre.z", c0.Z());
  }
  catch (const Standard_Failure&)
  {
    ++g_raised;
  }
}

int main()
{
  Handle(Geom_SphericalSurface) sphere5 =
    new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
  Handle(Geom_CylindricalSurface) cyl3 =
    new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3);
  Handle(Geom_ConicalSurface) apex =
    new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 6, 0);
  Handle(Geom_SphericalSurface) sphere3 =
    new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 3);
  Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

  printf("--- wellConditionedSurfacesAgree\n");
  surf("sphere r=5", sphere5, 0, 0.3);
  surf("cylinder r=3", cyl3, 1.2, -0.8);
  surf("apex cone", apex, 0, 0.01);
  surf("plane", plane, 1, 2);

  printf("--- surfaceToleranceWindowAgrees\n");
  for (double v : {1e-9, 1e-8, 1e-7, 3e-7, 1e-6})
    surf("apex cone", apex, 0, v);
  for (double d : {1e-9, 1e-8, 1e-7})
    surf("sphere r=3 pole-", sphere3, 0, M_PI / 2 - d);

  printf("--- degenerateSurfacePointsAgree\n");
  surf("apex cone", apex, 0, 0);
  surf("sphere r=3 pole", sphere3, 0, M_PI / 2);
  surf("sphere r=3 pole", sphere3, 0, -M_PI / 2);

  printf("--- wellConditionedCurvesAgree\n");
  Handle(Geom_Circle) circle = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  Handle(Geom_Line)   line   = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  curve("circle r=5", circle, 0.7);
  curve("line", line, 1.0);
  curve("bezier spacing=1", cusp(1.0), 0.25);

  printf("--- curveToleranceWindowAgrees\n");
  for (double s : {1e-8, 1e-7})
    curve("cusp bezier", cusp(s), 0);

  printf("--- curveLocalPropsAgreesWithEdge (unique edges of the radius-10 height-5 cylinder)\n");
  TopoDS_Shape               cylShape = BRepPrimAPI_MakeCylinder(10, 5).Shape();
  TopTools_IndexedMapOfShape edges, faces;
  TopExp::MapShapes(cylShape, TopAbs_EDGE, edges);
  TopExp::MapShapes(cylShape, TopAbs_FACE, faces);
  for (int i = 1; i <= edges.Extent(); ++i)
  {
    double             f, l;
    Handle(Geom_Curve) c = BRep_Tool::Curve(TopoDS::Edge(edges(i)), f, l);
    char               label[96];
    snprintf(label, sizeof label, "edge %d (%s)", i - 1, c.IsNull() ? "no 3D curve" : c->DynamicType()->Name());
    if (c.IsNull())
      continue;
    for (double u : {0.0, 0.5, 1.0, 2.0})
      curve(label, c, u);
  }

  printf("--- curveLocalPropsAgreesOnCusp\n");
  for (double s : {0.0, 1e-12, 1e-9, 1e-8, 1e-7})
    curve("cusp bezier", cusp(s), 0);

  printf("--- surfaceLocalPropsAgreesWithFace\n");
  for (int i = 1; i <= faces.Extent(); ++i)
  {
    Handle(Geom_Surface) s = BRep_Tool::Surface(TopoDS::Face(faces(i)));
    char                 label[96];
    snprintf(label, sizeof label, "face %d (%s)", i - 1, s->DynamicType()->Name());
    for (auto uv : {std::pair<double, double>(0.0, 0.0), {0.5, 1.0}, {1.2, 2.0}})
      surf(label, s, uv.first, uv.second);
  }

  printf("--- surfaceLocalPropsAgreesNearConeApex (the test's v: (5*5 + 10*10).squareRoot() - delta)\n");
  TopoDS_Shape coneShape = BRepPrimAPI_MakeCone(5, 0, 10).Shape();
  const double vApex     = std::sqrt(5.0 * 5.0 + 10.0 * 10.0);
  printf("vApex=%.17g\n", vApex);
  TopTools_IndexedMapOfShape coneFaces;
  TopExp::MapShapes(coneShape, TopAbs_FACE, coneFaces);
  for (int i = 1; i <= coneFaces.Extent(); ++i)
  {
    Handle(Geom_Surface) s = BRep_Tool::Surface(TopoDS::Face(coneFaces(i)));
    if (s->DynamicType() != STANDARD_TYPE(Geom_ConicalSurface))
      continue;
    for (double d : {1e-8, 1e-7, 5e-7, 1e-6, 2e-6, 1e-5, 1.0})
      surf("cone lateral near apex", s, 0, vApex - d);
  }

  printf("--- cuspCentreOfCurvatureIsUndefined\n");
  for (double s : {0.0, 1e-14, 1e-12, 1e-11})
    curve("cusp bezier", cusp(s), 0);

  printf("--- localPropsNeverReturnNonFinite: raw kernel values over the test's curve sweep\n");
  const Handle(Geom_Curve) sweep[]  = {cusp(0), cusp(1e-12), cusp(1e-8), circle, line};
  const char*              names[] = {"cusp d=0", "cusp d=1e-12", "cusp d=1e-8", "circle", "line"};
  for (int i = 0; i < 5; ++i)
    for (double u : {0.0, 1e-9, 0.5, 1.0})
      rawCurveSweep(names[i], sweep[i], u);
  printf("raw curve sweep: %d values returned, %d non-finite, %d calls raised\n", g_returned,
         g_nonFinite, g_raised);
  return 0;
}
