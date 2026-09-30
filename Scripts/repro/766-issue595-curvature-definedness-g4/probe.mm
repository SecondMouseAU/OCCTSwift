// #766 kernel parity for the seven Issue595CurvatureDefinednessTests tests other than
// curve3DCurvatureSeparatesZeroFromAbsent (covered by #2239). Every figure is the OCCT call the
// reached bridge function makes, at the bridge's own resolution (Precision::Confusion()).
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepLProp_CLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_Circle.hxx>
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

static const double R = Precision::Confusion();

static void curve3d(const char* label, const Handle(Geom_Curve)& c, double u)
{
  GeomLProp_CLProps p(c, u, 2, R);
  printf("%s u=%g: IsTangentDefined=%d", label, u, p.IsTangentDefined());
  if (p.IsTangentDefined())
    printf(" Curvature=%.17g", p.Curvature());
  printf("\n");
}

static void curve2d(const char* label, const Handle(Geom2d_Curve)& c, double u)
{
  GeomLProp_CLProps2d p(c, u, 2, R);
  printf("%s u=%g: IsTangentDefined=%d", label, u, p.IsTangentDefined());
  if (p.IsTangentDefined())
    printf(" Curvature=%.17g", p.Curvature());
  printf("\n");
}

static void surface(const char* label, const Handle(Geom_Surface)& s, double u, double v)
{
  GeomLProp_SLProps p(s, u, v, 2, R);
  printf("%s (u=%g, v=%g): IsCurvatureDefined=%d", label, u, v, p.IsCurvatureDefined());
  if (p.IsCurvatureDefined())
    printf(" Gaussian=%.17g Mean=%.17g", p.GaussianCurvature(), p.MeanCurvature());
  printf("\n");
}

// OCCTCurve3DGetTorsion: (d1 x d2) . d3 / |d1 x d2|^2, refused when |d1 x d2|^2 < Confusion.
static void torsion(const char* label, const Handle(Geom_Curve)& c, double u)
{
  gp_Pnt p;
  gp_Vec d1, d2, d3;
  c->D3(u, p, d1, d2, d3);
  gp_Vec x = d1.Crossed(d2);
  printf("%s u=%g: |d1xd2|^2=%.17g", label, u, x.SquareMagnitude());
  if (x.SquareMagnitude() >= R)
    printf(" torsion=%.17g", x.Dot(d3) / x.SquareMagnitude());
  else
    printf(" torsion undefined");
  printf("\n");
}

// OCCTWireGetCurvatureAt: normalised parameter over BRepAdaptor_CompCurve, |d1 x d2| / |d1|^3.
static void wire(const char* label, const TopoDS_Wire& w, double t)
{
  BRepAdaptor_CompCurve c(w);
  double                u = c.FirstParameter() + t * (c.LastParameter() - c.FirstParameter());
  gp_Pnt                p;
  gp_Vec                d1, d2;
  c.D2(u, p, d1, d2);
  printf("%s t=%g: |d1|=%.17g", label, t, d1.Magnitude());
  if (d1.Magnitude() >= 1e-10)
    printf(" curvature=%.17g", d1.Crossed(d2).Magnitude() / std::pow(d1.Magnitude(), 3));
  else
    printf(" curvature undefined");
  printf("\n");
}

int main()
{
  // curve3DCuspKeepsTheSentinel
  NCollection_Array1<gp_Pnt> cusp(1, 4);
  cusp(1) = gp_Pnt(0, 0, 0);
  cusp(2) = gp_Pnt(0, 0, 0);
  cusp(3) = gp_Pnt(1, 1, 0);
  cusp(4) = gp_Pnt(2, 0, 0);
  Handle(Geom_BezierCurve) cusp3 = new Geom_BezierCurve(cusp);
  curve3d("Curve3D cusp bezier", cusp3, 0);
  printf("  RealLast()=%.17g\n", RealLast());

  // curve2DCurvatureSeparatesZeroFromAbsent
  curve2d("Curve2D segment (0,0)-(10,0)", GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)).Value(), 5);
  NCollection_Array1<gp_Pnt2d> dead2(1, 4);
  for (int i = 1; i <= 4; i++)
    dead2(i) = gp_Pnt2d(0, 0);
  curve2d("Curve2D dead bezier", new Geom2d_BezierCurve(dead2), 0.5);
  curve2d("Curve2D circle r4", new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 4), 1);
  NCollection_Array1<gp_Pnt2d> cusp2(1, 4);
  cusp2(1) = gp_Pnt2d(0, 0);
  cusp2(2) = gp_Pnt2d(0, 0);
  cusp2(3) = gp_Pnt2d(1, 1);
  cusp2(4) = gp_Pnt2d(2, 0);
  curve2d("Curve2D cusp bezier", new Geom2d_BezierCurve(cusp2), 0);

  // edgeCurvatureLPSeparatesZeroFromAbsent: BRepLProp_CLProps over BRepAdaptor_Curve
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    int          n = 0, zero = 0;
    for (TopExp_Explorer ex(box, TopAbs_EDGE); ex.More(); ex.Next(), n++)
    {
      BRepAdaptor_Curve ac(TopoDS::Edge(ex.Current()));
      BRepLProp_CLProps p(ac, 5.0, 2, R);
      if (p.IsTangentDefined() && p.Curvature() == 0.0)
        zero++;
    }
    printf("box edge occurrences=%d with tangent defined and curvature exactly 0 at u=5: %d\n", n, zero);
    TopoDS_Shape sph = BRepPrimAPI_MakeSphere(gp_Pnt(0, 0, 0), 5).Shape();
    for (TopExp_Explorer ex(sph, TopAbs_EDGE); ex.More(); ex.Next())
    {
      TopoDS_Edge e = TopoDS::Edge(ex.Current());
      if (!BRep_Tool::Degenerated(e))
        continue;
      try
      {
        BRepAdaptor_Curve ac(e);
        BRepLProp_CLProps p(ac, 0.5, 2, R);
        printf("sphere degenerated edge: IsTangentDefined=%d\n", p.IsTangentDefined());
      }
      catch (const Standard_Failure& f)
      {
        printf("sphere degenerated edge: threw %s\n", f.what());
      }
    }
    try
    {
      TopoDS::Edge(box);
      printf("TopoDS::Edge(solid) did not throw\n");
    }
    catch (const Standard_Failure& f)
    {
      printf("TopoDS::Edge(solid) threw %s\n", f.what());
    }
  }

  // surfaceCurvatureSeparatesZeroFromAbsent / surfaceCurvaturesPairAgreesOnDefinedness
  Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  surface("plane", plane, 3, 4);
  surface("cylinder r3", new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3), 1.1, 6);
  Handle(Geom_ConicalSurface) cone =
    new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 6, 0);
  surface("cone r0 semi pi/6", cone, 0, 1);
  surface("cone r0 semi pi/6", cone, 0, 0);
  surface("sphere r5", new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5), 0, M_PI / 2);

  // torsionSeparatesZeroFromAbsent
  torsion("circle r4", new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4), 1);
  torsion("line X", new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 5);
  NCollection_Array1<gp_Pnt> hx(1, 5);
  for (int i = 0; i < 5; i++)
  {
    double t  = i * 0.6;
    hx(i + 1) = gp_Pnt(std::cos(t), std::sin(t), 0.4 * t);
  }
  torsion("helix-like bezier", new Geom_BezierCurve(hx), 0.5);

  // wireCurvatureSeparatesZeroFromAbsent
  wire("straight wire (0,0,0)-(10,0,0)",
       BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge()).Wire(), 0.5);
  wire("circle wire r10",
       BRepBuilderAPI_MakeWire(
         BRepBuilderAPI_MakeEdge(gp_Circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10)).Edge())
         .Wire(),
       0.5);
  wire("cusp wire", BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(cusp3).Edge()).Wire(), 0);
  return 0;
}
