// Kernel parity probe for Tests/OCCTAnalysisTests/CanonicalRecognitionDetailedTests.swift
// (#1859-#1862). Mirrors OCCTShapeRecognizeCanonicalSurface (IsPlane -> IsCylinder -> IsCone ->
// IsSphere, ClearStatus() between) and OCCTShapeRecognizeCanonicalCurve (IsLine -> ...), both at
// the Swift default tolerance 0.01, on the sub-shapes the tests pick: subShapes(ofType:) is
// TopExp::MapShapes order, so "first face" is map index 1.
#include <BRepAdaptor_Surface.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Sphere.hxx>
#include <cstdio>

static const double tol = 0.01;

static void surface(const char* label, const TopoDS_Shape& f)
{
  ShapeAnalysis_CanonicalRecognition r(f);
  gp_Pln                             pln;
  if (r.IsPlane(tol, pln))
  {
    printf("%s: plane gap=%.3g origin=(%.12g, %.12g, %.12g) dir=(%.12g, %.12g, %.12g)\n", label,
           r.GetGap(), pln.Location().X(), pln.Location().Y(), pln.Location().Z(),
           pln.Axis().Direction().X(), pln.Axis().Direction().Y(), pln.Axis().Direction().Z());
    return;
  }
  r.ClearStatus();
  gp_Cylinder cyl;
  if (r.IsCylinder(tol, cyl))
  {
    printf("%s: cylinder gap=%.3g radius=%.12g dir=(%.12g, %.12g, %.12g)\n", label, r.GetGap(),
           cyl.Radius(), cyl.Axis().Direction().X(), cyl.Axis().Direction().Y(),
           cyl.Axis().Direction().Z());
    return;
  }
  r.ClearStatus();
  gp_Cone cone;
  if (r.IsCone(tol, cone))
  {
    printf("%s: cone refRadius=%.12g\n", label, cone.RefRadius());
    return;
  }
  r.ClearStatus();
  gp_Sphere sph;
  if (r.IsSphere(tol, sph))
  {
    printf("%s: sphere gap=%.3g radius=%.12g centre=(%.12g, %.12g, %.12g)\n", label, r.GetGap(),
           sph.Radius(), sph.Location().X(), sph.Location().Y(), sph.Location().Z());
    return;
  }
  printf("%s: none\n", label);
}

static TopoDS_Shape firstFaceOfType(const TopoDS_Shape& s, GeomAbs_SurfaceType t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_FACE, m);
  for (int i = 1; i <= m.Extent(); ++i)
    if (BRepAdaptor_Surface(TopoDS::Face(m(i))).GetType() == t)
      return m(i);
  return TopoDS_Shape();
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  surface("recognizePlane: box subShapes(.face)[0]", faces(1));

  surface("recognizeCylinder: cylinder r=5 h=20, cylindrical face",
          firstFaceOfType(BRepPrimAPI_MakeCylinder(5, 20).Shape(), GeomAbs_Cylinder));
  surface("recognizeSphere: sphere r=5, spherical face",
          firstFaceOfType(BRepPrimAPI_MakeSphere(5).Shape(), GeomAbs_Sphere));

  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  int lines = 0;
  for (int i = 1; i <= edges.Extent(); ++i)
  {
    ShapeAnalysis_CanonicalRecognition r(edges(i));
    gp_Lin                             lin;
    if (r.IsLine(tol, lin))
    {
      if (lines == 0)
        printf("recognizeEdgeLine: first line at edge %d, origin=(%.12g, %.12g, %.12g) "
               "dir=(%.12g, %.12g, %.12g)\n",
               i - 1, lin.Location().X(), lin.Location().Y(), lin.Location().Z(),
               lin.Direction().X(), lin.Direction().Y(), lin.Direction().Z());
      ++lines;
    }
  }
  printf("recognizeEdgeLine: %d of %d box edges recognised as lines\n", lines, edges.Extent());
  return 0;
}
