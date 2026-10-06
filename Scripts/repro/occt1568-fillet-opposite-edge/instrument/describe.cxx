#include <BRep_Builder.hxx>
#include <BRepTools.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <GeomAbs_CurveType.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Edge.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <NCollection_IndexedMap.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <NCollection_List.hxx>
#include <GProp_GProps.hxx>
#include <BRepGProp.hxx>
#include <cstdio>
static const char* ST[] = {"Plane","Cylinder","Cone","Sphere","Torus","BezierS","BSplineS","Revolution","Extrusion","Offset","Other"};
static const char* CT[] = {"Line","Circle","Ellipse","Hyperbola","Parabola","BezierC","BSplineC","Offset","Other"};
int main(int argc, char** argv)
{
  TopoDS_Shape s; BRep_Builder b; BRepTools::Read(s, argv[1], b);
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> edges, faces;
  TopExp::MapShapes(s, TopAbs_EDGE, edges); TopExp::MapShapes(s, TopAbs_FACE, faces);
  NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>, TopTools_ShapeMapHasher> e2f;
  TopExp::MapShapesAndAncestors(s, TopAbs_EDGE, TopAbs_FACE, e2f);
  Bnd_Box bb; BRepBndLib::Add(s, bb); double x0,y0,z0,x1,y1,z1; bb.Get(x0,y0,z0,x1,y1,z1);
  printf("faces=%d edges=%d bbox=(%.3f %.3f %.3f)-(%.3f %.3f %.3f)\n", faces.Extent(), edges.Extent(), x0,y0,z0,x1,y1,z1);
  for (int i = 1; i <= faces.Extent(); ++i) { BRepAdaptor_Surface a(TopoDS::Face(faces(i))); GProp_GProps g; BRepGProp::SurfaceProperties(faces(i), g); printf("  face %2d: %-9s area=%8.3f\n", i, ST[(int)a.GetType()], g.Mass()); }
  int want = argc > 2 ? atoi(argv[2]) : 0;
  // DRAW numbering is a TopExp_Explorer-order dedupe; approximate via IsSame scan
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> seen; int n = 0; TopoDS_Edge target;
  seen.Add(s);
  for (TopExp_Explorer ex(s, TopAbs_EDGE); ex.More(); ex.Next()) { if (seen.Add(ex.Current())) { ++n; if (n == want) target = TopoDS::Edge(ex.Current()); } }
  if (!target.IsNull()) {
    BRepAdaptor_Curve c(target); GProp_GProps g; BRepGProp::LinearProperties(target, g);
    printf("DRAW edge %d: %s length=%.4f\n", want, CT[(int)c.GetType()], g.Mass());
    int idx = edges.FindIndex(target); printf("  adjacent faces:");
    for (auto it = e2f.FindFromKey(target).begin(); it != e2f.FindFromKey(target).end(); ++it) { int fi = faces.FindIndex(*it); BRepAdaptor_Surface a(TopoDS::Face(*it)); printf(" f%d(%s)", fi, ST[(int)a.GetType()]); }
    printf("\n");
  }
  return 0;
}
