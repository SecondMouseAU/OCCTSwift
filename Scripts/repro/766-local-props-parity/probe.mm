// #766 kernel parity for LocalPropsParityTests.swift (#494).
//
// Every bridge function on both sides of each pair the suite compares builds its props through
// occtSurfaceLocalProps / occtCurveLocalProps, i.e. GeomLProp_SLProps / GeomLProp_CLProps at
// Precision::Confusion(). This probe evaluates those props on the suite's fixtures and, for the
// tolerance-window tests, the same props at the pre-#494 resolutions (1e-10 for the Local*
// family, 1e-6 for Shape.curveLocalProps / surfaceLocalProps), which is what the tests exist to
// tell apart.
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
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>
#include <typeinfo>

static void surf(const char* label, const Handle(Geom_Surface)& s, double u, double v, double res)
{
  GeomLProp_SLProps p(s, u, v, 2, res);
  bool              def = p.IsCurvatureDefined();
  printf("%s u=%g v=%.17g res=%g: curvatureDefined=%d", label, u, v, res, def);
  if (def)
    printf(" K=%.17g H=%.17g kmax=%.17g kmin=%.17g umbilic=%d", p.GaussianCurvature(),
           p.MeanCurvature(), p.MaxCurvature(), p.MinCurvature(), p.IsUmbilic());
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

static void curve(const char* label, const Handle(Geom_Curve)& c, double u, double res)
{
  GeomLProp_CLProps p(c, u, 2, res);
  printf("%s u=%g res=%g: tangentDefined=%d", label, u, res, p.IsTangentDefined());
  if (p.IsTangentDefined())
  {
    gp_Dir t;
    p.Tangent(t);
    double k = p.Curvature();
    printf(" tangent=(%.6g, %.6g, %.6g) curvature=%.17g%s", t.X(), t.Y(), t.Z(), k,
           k == RealLast() ? " (RealLast)" : "");
    try
    {
      gp_Pnt c0;
      p.CentreOfCurvature(c0);
      printf(" raw CentreOfCurvature=(%g, %g, %g)", c0.X(), c0.Y(), c0.Z());
    }
    catch (const Standard_Failure& ex)
    {
      printf(" raw CentreOfCurvature raises %s", typeid(ex).name());
    }
  }
  printf("\n");
}

int main()
{
  const double C = Precision::Confusion();
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
  surf("sphere r=5", sphere5, 0, 0.3, C);
  surf("cylinder r=3", cyl3, 1.2, -0.8, C);
  surf("apex cone", apex, 0, 0.01, C);
  surf("plane", plane, 1, 2, C);
  printf("--- surfaceToleranceWindowAgrees: the window where 1e-10 and Confusion() disagree\n");
  for (double v : {1e-9, 1e-8, 1e-7, 3e-7, 1e-6})
  {
    surf("apex cone", apex, 0, v, C);
    surf("apex cone", apex, 0, v, 1e-10);
  }
  for (double d : {1e-9, 1e-8, 1e-7})
  {
    surf("sphere r=3 pole-", sphere3, 0, M_PI / 2 - d, C);
    surf("sphere r=3 pole-", sphere3, 0, M_PI / 2 - d, 1e-10);
  }
  printf("--- degenerateSurfacePointsAgree\n");
  surf("apex cone", apex, 0, 0, C);
  surf("sphere r=3 pole", sphere3, 0, M_PI / 2, C);
  surf("sphere r=3 pole", sphere3, 0, -M_PI / 2, C);

  printf("--- wellConditionedCurvesAgree\n");
  Handle(Geom_Circle) circle = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  Handle(Geom_Line)   line   = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  curve("circle r=5", circle, 0.7, C);
  curve("line", line, 1.0, C);
  curve("bezier spacing=1", cusp(1.0), 0.25, C);
  printf("--- curveToleranceWindowAgrees / cuspCentreOfCurvatureIsUndefined / NonFinite\n");
  for (double s : {0.0, 1e-14, 1e-12, 1e-11, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-3})
  {
    curve("cusp bezier", cusp(s), 0, C);
    curve("cusp bezier", cusp(s), 0, 1e-10);
  }

  printf("--- curveLocalPropsAgreesWithEdge / surfaceLocalPropsAgreesWithFace (1e-6 vs Confusion)\n");
  TopoDS_Shape cylShape = BRepPrimAPI_MakeCylinder(10, 5).Shape();
  int          i        = 0;
  for (TopExp_Explorer e(cylShape, TopAbs_EDGE); e.More(); e.Next(), i++)
  {
    double             f, l;
    Handle(Geom_Curve) c = BRep_Tool::Curve(TopoDS::Edge(e.Current()), f, l);
    if (c.IsNull())
    {
      printf("cylinder edge %d: no 3D curve\n", i);
      continue;
    }
    char label[64];
    snprintf(label, sizeof label, "cylinder edge %d", i);
    curve(label, c, 0.5, C);
  }
  i = 0;
  for (TopExp_Explorer e(cylShape, TopAbs_FACE); e.More(); e.Next(), i++)
  {
    char label[64];
    snprintf(label, sizeof label, "cylinder face %d", i);
    surf(label, BRep_Tool::Surface(TopoDS::Face(e.Current())), 0.5, 1.0, C);
  }
  printf("--- surfaceLocalPropsAgreesNearConeApex (1e-6 vs Confusion)\n");
  TopoDS_Shape coneShape = BRepPrimAPI_MakeCone(5, 0, 10).Shape();
  for (TopExp_Explorer e(coneShape, TopAbs_FACE); e.More(); e.Next())
  {
    Handle(Geom_Surface) s = BRep_Tool::Surface(TopoDS::Face(e.Current()));
    if (s->DynamicType() != STANDARD_TYPE(Geom_ConicalSurface))
      continue;
    // The v values the test samples: v = 0 is the base circle (radius 5), not the apex.
    for (double v : {1e-8, 1e-7, 5e-7, 1e-6, 1e-5})
    {
      surf("cone lateral", s, 0, v, C);
      surf("cone lateral", s, 0, v, 1e-6);
    }
    // Where the apex really is on this face, and the window just short of it.
    Handle(Geom_ConicalSurface) cs    = Handle(Geom_ConicalSurface)::DownCast(s);
    double                      vApex = -cs->RefRadius() / std::sin(cs->SemiAngle());
    printf("cone lateral: RefRadius=%.17g SemiAngle=%.17g apex at v=%.17g, apex point (%g, %g, %g)\n",
           cs->RefRadius(), cs->SemiAngle(), vApex, cs->Apex().X(), cs->Apex().Y(), cs->Apex().Z());
    for (double d : {1e-8, 1e-7, 5e-7, 1e-6, 2e-6, 1e-5})
    {
      surf("cone lateral near apex", s, 0, vApex - d, C);
      surf("cone lateral near apex", s, 0, vApex - d, 1e-6);
    }
  }
  return 0;
}
