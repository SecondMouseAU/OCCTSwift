// #1979 evidence-fix pass for the two parity records of this PR whose bridge and kernel sides carried
// different keys (ProjLibComputeApproxOnPolarSurfaceTests, ProjLibProjectOnSurfaceTests). Lines
// starting "EF " are `EF <record>.<key> = <json>`, read by the record generator.
//
// P2: the OCCT sequence OCCTProjLibComputeApproxOnPolarSurface makes (ProjLib_ComputeApproxOnPolarSurface on the
//     circle edge and the sphere face, then BRepBuilderAPI_MakeEdge on the resulting 2D curve), followed by
//     the bounding box Shape.bounds reads (BRepBndLib::Add, useTriangulation true, no optimal box).
// P3: the OCCT sequence OCCTProjLibProjectOnSurface makes (ProjLib_ProjectOnSurface on the trimmed line and
//     the radius-5 cylinder), domain and first point of the returned B-spline.
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepLib_MakeEdge.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <ProjLib_ComputeApproxOnPolarSurface.hxx>
#include <ProjLib_ProjectOnSurface.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Circ.hxx>
#include <gp_Cylinder.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  {
    TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(15.0).Shape();
    TopoDS_Face  face;
    for (TopExp_Explorer ex(sphere, TopAbs_FACE); ex.More(); ex.Next())
    {
      face = TopoDS::Face(ex.Current());
      break;
    }
    BRepLib_MakeEdge me(gp_Circ(gp_Ax2(gp_Pnt(0, 0, 5), gp_Dir(0, 0, 1)), 10.0), 0.0, M_PI);
    TopoDS_Edge      edge = me.Edge();
    double           f, l;
    Handle(Geom_Curve)   c3d     = BRep_Tool::Curve(edge, f, l);
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
    Handle(GeomAdaptor_Curve)   ca = new GeomAdaptor_Curve(c3d, f, l);
    Handle(GeomAdaptor_Surface) sa = new GeomAdaptor_Surface(surface);
    ProjLib_ComputeApproxOnPolarSurface proj(ca, sa, 1e-3);
    printf("ProjLib_ComputeApproxOnPolarSurface: IsDone=%d\n", proj.IsDone());
    TopoDS_Edge result;
    Handle(Geom2d_BSplineCurve) bsp = proj.BSpline();
    if (!bsp.IsNull())
      result = BRepBuilderAPI_MakeEdge(bsp, surface).Edge();
    else
      result = BRepBuilderAPI_MakeEdge(proj.Curve2d(), surface).Edge();
    Bnd_Box box;
    BRepBndLib::Add(result, box, true);
    double x0, y0, z0, x1, y1, z1;
    box.Get(x0, y0, z0, x1, y1, z1);
    printf("projected edge bounds: min (%.12g, %.12g, %.12g) max (%.12g, %.12g, %.12g)\n", x0, y0, z0, x1, y1, z1);
    printf("analytic radial projection of the circle onto the sphere (the reference the test's 0.05 tolerance is centred on): "
           "radius %.12g, height %.12g\n",
           15.0 * 10.0 / std::sqrt(125.0), 15.0 * 5.0 / std::sqrt(125.0));
    printf("EF P2.bounds_max_x = %.12g\n", x1);
    printf("EF P2.bounds_min_x = %.12g\n", x0);
    printf("EF P2.bounds_min_z = %.12g\n", z0);
    printf("EF P2.bounds_max_z = %.12g\n", z1);
  }
  {
    gp_Cylinder                     cy(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
    Handle(Geom_CylindricalSurface) gcy = new Geom_CylindricalSurface(cy);
    Handle(Geom_Line)               gl  = new Geom_Line(gp_Pnt(5, 0, 0), gp_Dir(0, 1, 1));
    Handle(Geom_TrimmedCurve)       tr  = new Geom_TrimmedCurve(gl, 0, 10);
    ProjLib_ProjectOnSurface        proj;
    proj.Load(new GeomAdaptor_Surface(gcy));
    proj.Load(new GeomAdaptor_Curve(tr), 1e-3);
    printf("ProjLib_ProjectOnSurface: IsDone=%d\n", proj.IsDone());
    Handle(Geom_BSplineCurve) b = proj.BSpline();
    gp_Pnt                    s = b->Value(b->FirstParameter());
    printf("B-spline domain [%.12g, %.12g], value(first) = (%.12g, %.12g, %.12g); poles=%d degree=%d\n", b->FirstParameter(),
           b->LastParameter(), s.X(), s.Y(), s.Z(), b->NbPoles(), b->Degree());
    gp_Pnt mid = b->Value(5.0);
    printf("not asserted by the test: value(5) = (%.12g, %.12g, %.12g), radius %.12g\n", mid.X(), mid.Y(), mid.Z(), std::hypot(mid.X(), mid.Y()));
    printf("EF P3.domain = [%.12g, %.12g]\n", b->FirstParameter(), b->LastParameter());
    printf("EF P3.start = [%.12g, %.12g, %.12g]\n", s.X(), s.Y(), s.Z());
  }
  return 0;
}
