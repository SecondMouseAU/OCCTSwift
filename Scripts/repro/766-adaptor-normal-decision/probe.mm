// #766 kernel parity for Tests/OCCTAnalysisTests/AdaptorNormalDecisionTests.swift.
// Face.normal: BRepLProp_SLProps(face, uMid, vMid, 1, Precision::Confusion()), reversed on a
// reversed face (OCCTFaceGetNormal). Raycast: IntCurvesFace_ShapeIntersector loaded at the caller's
// tolerance, normals from BRepLProp_SLProps at Precision::Confusion() (OCCTShapeRaycast); the
// "at tol" column is the pre-#529 behaviour of passing the tolerance as the props resolution.
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <Geom_Line.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <IntCurvesFace_ShapeIntersector.hxx>
#include <Precision.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static bool midNormal(const TopoDS_Face& f, double res, gp_Dir& n)
{
  BRepAdaptor_Surface a(f);
  double              u = (a.FirstUParameter() + a.LastUParameter()) / 2;
  double              v = (a.FirstVParameter() + a.LastVParameter()) / 2;
  BRepLProp_SLProps   p(a, u, v, 1, res);
  if (!p.IsNormalDefined())
    return false;
  n = p.Normal();
  if (f.Orientation() == TopAbs_REVERSED)
    n.Reverse();
  return true;
}

static void primitive(const char* name, const TopoDS_Shape& s)
{
  int horizontal = 0, upward = 0, planarNoNormal = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
  {
    TopoDS_Face f = TopoDS::Face(e.Current());
    gp_Dir      n;
    bool        ok = midNormal(f, Precision::Confusion(), n);
    if (!ok && BRepAdaptor_Surface(f).GetType() == GeomAbs_Plane)
      ++planarNoNormal;
    if (ok && std::fabs(n.Z()) > std::cos(0.01))
      ++horizontal;
    if (ok && n.Z() > std::cos(0.01))
      ++upward;
  }
  printf("%s: horizontal=%d upward=%d planarWithoutNormal=%d\n", name, horizontal, upward,
         planarNoNormal);
}

static void raycast(const char* name, const TopoDS_Shape& s, gp_Pnt o, gp_Dir d, double tol)
{
  IntCurvesFace_ShapeIntersector in;
  in.Load(s, tol);
  in.Perform(gp_Lin(o, d), -1e10, 1e10);
  printf("%s tol=%g hits=%d\n", name, tol, in.NbPnt());
  for (int i = 1; i <= in.NbPnt(); ++i)
  {
    TopoDS_Face         f = in.Face(i);
    BRepAdaptor_Surface a(f);
    BRepLProp_SLProps   p(a, in.UParameter(i), in.VParameter(i), 1, Precision::Confusion());
    BRepLProp_SLProps   q(a, in.UParameter(i), in.VParameter(i), 1, tol);
    gp_Pnt              pt = in.Pnt(i);
    printf("  w=%g point=(%.6f,%.6f,%.6f)", in.WParameter(i), pt.X(), pt.Y(), pt.Z());
    if (p.IsNormalDefined())
    {
      gp_Dir n = p.Normal();
      if (f.Orientation() == TopAbs_REVERSED)
        n.Reverse();
      printf(" normal=(%.6f,%.6f,%.6f)", n.X(), n.Y(), n.Z());
    }
    else
      printf(" normal=undefined");
    printf(" | at tol: normalDefined=%d\n", (int)q.IsNormalDefined());
  }
}

int main()
{
  printf("== primitiveFaceNormalsUnchanged\n");
  primitive("box", BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape());
  primitive("cylinder", BRepPrimAPI_MakeCylinder(5, 20).Shape());
  primitive("cone", BRepPrimAPI_MakeCone(5, 0, 12).Shape());
  primitive("sphere", BRepPrimAPI_MakeSphere(7).Shape());

  printf("== skewedExtrusionHasANormal\n");
  double                                    skew = 5e-7;
  occ::handle<Geom_SurfaceOfLinearExtrusion> ext = new Geom_SurfaceOfLinearExtrusion(
    new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), gp_Dir(std::cos(skew), std::sin(skew), 0));
  TopoDS_Face f = BRepBuilderAPI_MakeFace(ext, 0, 10, 0, 10, 1e-6).Face();
  for (double res : {Precision::Confusion(), 1e-6})
  {
    gp_Dir n;
    if (midNormal(f, res, n))
      printf("res=%g normal=(%.17g, %.17g, %.17g)\n", res, n.X(), n.Y(), n.Z());
    else
      printf("res=%g normal=undefined\n", res);
  }

  printf("== raycastNormalsSurviveALooseTolerance\n");
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5).Shape();
  for (double tol : {0.001, 0.1, 1.0, 2.0, 5.0})
    raycast("sphere", sphere, gp_Pnt(-20, 0, 0), gp_Dir(1, 0, 0), tol);

  printf("== raycastKeepsFaceOrientationAtALooseTolerance\n");
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  for (double tol : {0.001, 1.0, 5.0})
    raycast("box", box, gp_Pnt(0, 0, 40), gp_Dir(0, 0, -1), tol);
  return 0;
}
