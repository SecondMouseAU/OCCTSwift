// #1980 evidence correction: the kernel side of three Analysis records that had none.
// Shape Measurements::cylinderTopBottomCentroidsAreOnAxis: Shape.measure() finds each face's area with
// Face.area -> OCCTFaceGetArea (BRepGProp::SurfaceProperties, tolerance 1e-6) and its centroid with
// Face.surfaceInertia -> OCCTBRepGPropSinert (BRepGProp_Face + BRepGProp_Sinert at origin).
// IntCurvesFace Intersection::Line-face intersection and ::Line parallel to a face: Shape.intersectLine
// -> OCCTLocOpeCSIntersectLine (LocOpe_CSIntersector over one face, one gp_Lin).
// Faces are taken in TopExp::MapShapes order, the order OCCTShapeGetFaces uses for Shape.faces().
#include <BRepAdaptor_Surface.hxx>
#include <BRepGProp.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepGProp_Sinert.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <LocOpe_CSIntersector.hxx>
#include <LocOpe_PntFace.hxx>
#include <NCollection_Sequence.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <GProp_GProps.hxx>
#include <cstdio>
#include <gp_Lin.hxx>

static void intersect(const char* label, const TopoDS_Shape& face, gp_Pnt origin, gp_Dir dir)
{
  LocOpe_CSIntersector         intersector(face);
  NCollection_Sequence<gp_Lin> lines;
  lines.Append(gp_Lin(origin, dir));
  intersector.Perform(lines);
  int n = intersector.NbPoints(1);
  printf("%s: NbPoints=%d\n", label, n);
  for (int i = 1; i <= n; i++)
  {
    const LocOpe_PntFace& pf = intersector.Point(1, i);
    printf("  [%d] point=(%.17g, %.17g, %.17g) parameter=%.17g\n", i, pf.Pnt().X(), pf.Pnt().Y(),
           pf.Pnt().Z(), pf.Parameter());
  }
}

int main()
{
  // Shape.cylinder(radius: 5, height: 10): OCCTShapeCreateCylinder, BRepPrimAPI_MakeCylinder(5, 10).
  {
    TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(cyl, TopAbs_FACE, faces);
    const double capArea = M_PI * 25.0;
    int          caps    = 0;
    double       maxX = 0, maxY = 0;
    printf("cylinder r=5 h=10: %d faces, cap area pi*25 = %.17g\n", faces.Extent(), capArea);
    for (int i = 1; i <= faces.Extent(); i++)
    {
      GProp_GProps area;
      BRepGProp::SurfaceProperties(TopoDS::Face(faces(i)), area, 1e-6);
      BRepGProp_Face   gf(TopoDS::Face(faces(i)));
      BRepGProp_Sinert s;
      s.SetLocation(gp_Pnt(0, 0, 0));
      s.Perform(gf);
      gp_Pnt cm = s.CentreOfMass();
      printf("  face[%d] area=%.17g centroid=(%.17g, %.17g, %.17g)\n", i - 1, area.Mass(), cm.X(),
             cm.Y(), cm.Z());
      if (std::fabs(area.Mass() - capArea) < 1e-3)
      {
        caps++;
        maxX = std::fmax(maxX, std::fabs(cm.X()));
        maxY = std::fmax(maxY, std::fabs(cm.Y()));
      }
    }
    printf("cap faces (|area - pi*25| < 1e-3): %d, max |centroid x| = %.17g, max |centroid y| = %.17g\n",
           caps, maxX, maxY);
  }

  // Shape.box(width: 10, height: 20, depth: 30) is centred on the origin (OCCTShapeCreateBox).
  {
    TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(box, TopAbs_FACE, faces);
    printf("box 10x20x30: %d faces\n", faces.Extent());
    for (int i = 1; i <= faces.Extent(); i++)
    {
      BRepAdaptor_Surface s(TopoDS::Face(faces(i)));
      gp_Pln              pl = s.Plane();
      printf("  face[%d] plane origin=(%.17g, %.17g, %.17g) axis=(%.17g, %.17g, %.17g)\n", i - 1,
             pl.Location().X(), pl.Location().Y(), pl.Location().Z(), pl.Axis().Direction().X(),
             pl.Axis().Direction().Y(), pl.Axis().Direction().Z());
    }
    // faces()[4] is the z = -15 cap, faces()[0] the x = -5 plane (IntCurvesFaceTests.swift).
    intersect("z cap faces()[4], +Z ray from (0, 0, -50)", faces(5), gp_Pnt(0, 0, -50), gp_Dir(0, 0, 1));
    intersect("x cap faces()[0], +Z ray from (0, 0, -50)", faces(1), gp_Pnt(0, 0, -50), gp_Dir(0, 0, 1));
  }
  return 0;
}
