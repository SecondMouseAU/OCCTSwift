// #766 kernel parity for the four face/edge tests in
// Tests/OCCTAnalysisTests/CanonicalRecognitionTests.swift (the two whole-solid tests are #2234's).
// Runs OCCTShapeRecognizeCanonical's own sequence, IsPlane -> IsCylinder -> IsCone -> IsSphere ->
// IsLine -> IsCircle -> IsEllipse on one ShapeAnalysis_CanonicalRecognition at tolerance 1e-4,
// with ClearStatus() between checks (the bridge) and without it (the #1509 defect).
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <Geom_Line.hxx>
#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void recognize(const char* label, const TopoDS_Shape& s, bool clear)
{
  const double                       tol = 1e-4;
  ShapeAnalysis_CanonicalRecognition r(s);
  const char*                        type = "unknown";
  double                             radius = 0;
  gp_Pln                             pln;
  gp_Cylinder                        cyl;
  gp_Cone                            cone;
  gp_Sphere                          sph;
  gp_Lin                             lin;
  gp_Circ                            circ;
  gp_Elips                           el;
  if (r.IsPlane(tol, pln))
    type = "plane";
  else
  {
    if (clear)
      r.ClearStatus();
    if (r.IsCylinder(tol, cyl))
      type = "cylinder", radius = cyl.Radius();
    else
    {
      if (clear)
        r.ClearStatus();
      if (r.IsCone(tol, cone))
        type = "cone", radius = cone.RefRadius();
      else
      {
        if (clear)
          r.ClearStatus();
        if (r.IsSphere(tol, sph))
          type = "sphere", radius = sph.Radius();
        else
        {
          if (clear)
            r.ClearStatus();
          if (r.IsLine(tol, lin))
            type = "line";
          else
          {
            if (clear)
              r.ClearStatus();
            if (r.IsCircle(tol, circ))
              type = "circle", radius = circ.Radius();
            else
            {
              if (clear)
                r.ClearStatus();
              if (r.IsEllipse(tol, el))
                type = "ellipse";
            }
          }
        }
      }
    }
  }
  printf("%s %s: type=%s radius=%.17g gap=%.3g\n", label,
         clear ? "with ClearStatus" : "without ClearStatus", type, radius, r.GetGap());
}

static TopoDS_Face faceOfType(const TopoDS_Shape& s, GeomAbs_SurfaceType t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_FACE, m);
  for (int i = 1; i <= m.Extent(); ++i)
    if (BRepAdaptor_Surface(TopoDS::Face(m(i))).GetType() == t)
      return TopoDS::Face(m(i));
  return TopoDS_Face();
}

int main()
{
  TopoDS_Face cyl  = faceOfType(BRepPrimAPI_MakeCylinder(5, 10).Shape(), GeomAbs_Cylinder);
  TopoDS_Face cone = faceOfType(BRepPrimAPI_MakeCone(5, 0, 10).Shape(), GeomAbs_Cone);
  TopoDS_Face sph  = faceOfType(BRepPrimAPI_MakeSphere(5).Shape(), GeomAbs_Sphere);
  TopoDS_Edge line =
    BRepBuilderAPI_MakeEdge(new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 0, 10).Edge();
  for (bool clear : {true, false})
  {
    recognize("cylindrical face", cyl, clear);
    recognize("conical face", cone, clear);
    recognize("spherical face", sph, clear);
    recognize("line edge", line, clear);
  }
  return 0;
}
