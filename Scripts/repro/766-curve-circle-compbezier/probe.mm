// Epic #766 (#1978), kernel parity for CirclePropertyTests.swift and CompBezierToBSplineTests.swift.
// CirclePropertyTests exercises Swift-side geometry (Face.revolutionProperties, the internal
// circleThroughThreePoints, Edge.circleProperties), so the kernel counterparts here are what OCCT
// itself says about the same inputs: the cylinder face's radius, gce_MakeCirc through the same three
// points, and the cap edge's Geom_Circle. CompBezierConverter is Convert_CompBezierCurvesToBSplineCurve.
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <Convert_CompBezierCurvesToBSplineCurve.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <gce_MakeCirc.hxx>
#include <cstdio>
#include <vector>

static void comp(const char* name, const std::vector<std::vector<gp_Pnt>>& segs)
{
  Convert_CompBezierCurvesToBSplineCurve conv;
  for (auto& s : segs)
  {
    NCollection_Array1<gp_Pnt> a(1, (int)s.size());
    for (size_t i = 0; i < s.size(); i++)
      a((int)i + 1) = s[i];
    conv.AddCurve(a);
  }
  conv.Perform();
  int                        nb = conv.NbPoles(), nk = conv.NbKnots();
  NCollection_Array1<gp_Pnt> p(1, nb);
  conv.Poles(p);
  NCollection_Array1<double> k(1, nk);
  NCollection_Array1<int>    m(1, nk);
  conv.KnotsAndMults(k, m);
  printf("%s: degree=%d poles=%d knots=%d\n  poles:", name, conv.Degree(), nb, nk);
  for (int i = 1; i <= nb && i <= 8; i++)
    printf(" (%.17g, %.17g, %.17g)", p(i).X(), p(i).Y(), p(i).Z());
  printf("\n  knots:");
  for (int i = 1; i <= nk && i <= 8; i++)
    printf(" %.17g", k(i));
  printf("\n  mults:");
  for (int i = 1; i <= nk && i <= 8; i++)
    printf(" %d", m(i));
  printf("\n");
}

int main()
{
  TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopTools_IndexedMapOfShape fm;
  TopExp::MapShapes(cyl, TopAbs_FACE, fm);
  for (int i = 1; i <= fm.Extent(); i++)
  {
    BRepAdaptor_Surface s(TopoDS::Face(fm(i)));
    if (s.GetType() == GeomAbs_Cylinder)
    {
      gp_Ax1 ax = s.Cylinder().Axis();
      printf("cylinderRevolutionRadius: cylinder face radius=%.17g axis origin=(%g, %g, %g) dir=(%g, %g, %g)\n",
             s.Cylinder().Radius(), ax.Location().X(), ax.Location().Y(), ax.Location().Z(),
             ax.Direction().X(), ax.Direction().Y(), ax.Direction().Z());
    }
  }
  gce_MakeCirc mc(gp_Pnt(1, 0, 0), gp_Pnt(0, 1, 0), gp_Pnt(-1, 0, 0));
  printf("threePointCircle: gce_MakeCirc done=%d centre=(%.17g, %.17g, %.17g) radius=%.17g\n",
         mc.IsDone(), mc.Value().Location().X(), mc.Value().Location().Y(),
         mc.Value().Location().Z(), mc.Value().Radius());
  gce_MakeCirc col(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0), gp_Pnt(2, 0, 0));
  printf("collinearPointsNil: gce_MakeCirc done=%d status=%d (gce_ColinearPoints = %d)\n",
         col.IsDone(), (int)col.Status(), (int)gce_ColinearPoints);
  TopoDS_Shape               cyl3 = BRepPrimAPI_MakeCylinder(3, 8).Shape();
  TopTools_IndexedMapOfShape em;
  TopExp::MapShapes(cyl3, TopAbs_EDGE, em);
  for (int i = 1; i <= em.Extent(); i++)
  {
    BRepAdaptor_Curve a(TopoDS::Edge(em(i)));
    if (a.GetType() == GeomAbs_Circle)
      printf("edgeCirclePropertiesFullCircle: edge[%d] circle radius=%.17g range=[%.17g, %.17g] "
             "centre z=%g\n",
             i - 1, a.Circle().Radius(), a.FirstParameter(), a.LastParameter(),
             a.Circle().Location().Z());
  }

  comp("singleCubicSegment3D",
       {{gp_Pnt(0, 0, 0), gp_Pnt(1, 2, 0), gp_Pnt(2, 2, 0), gp_Pnt(3, 0, 0)}});
  comp("twoCubicSegments3D",
       {{gp_Pnt(0, 0, 0), gp_Pnt(1, 1, 0), gp_Pnt(2, 1, 0), gp_Pnt(3, 0, 0)},
        {gp_Pnt(3, 0, 0), gp_Pnt(4, -1, 0), gp_Pnt(5, -1, 0), gp_Pnt(6, 0, 0)}});
  std::vector<std::vector<gp_Pnt>> many;
  for (int i = 0; i < 60; i++)
  {
    double x = i * 3;
    many.push_back({gp_Pnt(x, 0, 0), gp_Pnt(x + 1, 1, 0), gp_Pnt(x + 2, -1, 0), gp_Pnt(x + 3, 0, 0)});
  }
  comp("manySegmentsExceedingCapacity (60 cubic segments; the bridge caps at 100 poles, 50 knots)",
       many);
  return 0;
}
