// #1980 evidence correction: the kernel side of three Analysis records that had none.
// Shape Measurements::cylinderTopBottomCentroidsAreOnAxis: Shape.measure() finds each face's area with
// Face.area -> OCCTFaceGetArea (BRepGProp::SurfaceProperties, tolerance 1e-6) and its centroid with
// Face.surfaceInertia -> OCCTBRepGPropSinert (BRepGProp_Face + BRepGProp_Sinert at origin).
// IntCurvesFace Intersection::Line-face intersection and ::Line parallel to a face: Shape.intersectLine
// -> OCCTLocOpeCSIntersectLine (LocOpe_CSIntersector over one face, one gp_Lin).
// IntTools_EdgeFace Tests::Edge crossing face produces intersection: Shape.edgeFaceIntersection ->
// OCCTIntToolsEdgeFace (IntTools_EdgeFace with SetRange, #1631); for a VERTEX part the bridge reports
// IntTools_CommonPrt::VertexParameter1() as the parameter, not Range1() (fillCommonPart).
// Faces are taken in TopExp::MapShapes order, the order OCCTShapeGetFaces uses for Shape.faces().
#include <BRepAdaptor_Surface.hxx>
#include <BRepGProp.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepGProp_Sinert.hxx>
#include <BRepLib_MakeEdge.hxx>
#include <BRep_Tool.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_EdgeFace.hxx>
#include <IntTools_Range.hxx>
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

    // IntToolsEdgeFaceTests.edgeFaceIntersection: the 10-box (centred), the edge (-10,1,2)-(0,1,2) against faces()[0].
    TopoDS_Shape box10 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    TopTools_IndexedMapOfShape faces10;
    TopExp::MapShapes(box10, TopAbs_FACE, faces10);
    TopoDS_Edge       edge = BRepLib_MakeEdge(gp_Pnt(-10, 1, 2), gp_Pnt(0, 1, 2)).Edge();
    IntTools_EdgeFace ef;
    ef.SetEdge(edge);
    ef.SetFace(TopoDS::Face(faces10(1)));
    double first = 0, last = 0;
    BRep_Tool::Range(edge, first, last);
    ef.SetRange(IntTools_Range(first, last));
    ef.Perform();
    printf("edge (-10,1,2)-(0,1,2) vs faces()[0]: IsDone=%d NbCommonParts=%d\n", ef.IsDone() ? 1 : 0,
           ef.CommonParts().Length());
    for (int k = 1; k <= ef.CommonParts().Length(); k++)
    {
      const IntTools_CommonPrt& cp = ef.CommonParts()(k);
      gp_Pnt                    p1, p2;
      cp.BoundingPoints(p1, p2);
      printf("  part %d: type=%s VertexParameter1=%.17g range1=(%.17g, %.17g) midpoint=(%.17g, %.17g, %.17g)\n",
             k, cp.Type() == TopAbs_VERTEX ? "VERTEX" : "EDGE", cp.VertexParameter1(), cp.Range1().First(),
             cp.Range1().Last(), (p1.X() + p2.X()) / 2, (p1.Y() + p2.Y()) / 2, (p1.Z() + p2.Z()) / 2);
    }
  }
  return 0;
}
