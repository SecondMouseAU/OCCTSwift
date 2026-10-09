// Geometry of the reporter's model (OCCT#1568) at the faulting fillet: for a DRAW-numbered edge, which
// vertices of each adjacent planar face lie exactly one radius from the edge, measured in the face and
// perpendicular to the edge. That is where the blend's contact line on that face would pass through an
// existing vertex, which is what "the blend meets something exactly" means for a constant-radius fillet.
//   geom1568 model.brep <draw edge number> <radius>
#include <BRep_Builder.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <NCollection_IndexedMap.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <NCollection_Map.hxx>
#include <NCollection_List.hxx>
#include <gp_Pln.hxx>
#include <cstdio>
#include <cmath>
static const char* ST[] = {"Plane","Cylinder","Cone","Sphere","Torus","BezierS","BSplineS","Revolution","Extrusion","Offset","Other"};
static const char* CT[] = {"Line","Circle","Ellipse","Hyperbola","Parabola","BezierC","BSplineC","Offset","Other"};
int main(int argc, char** argv)
{
  TopoDS_Shape s; BRep_Builder b; BRepTools::Read(s, argv[1], b);
  int want = atoi(argv[2]); double R = atof(argv[3]);
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> faces, verts;
  TopExp::MapShapes(s, TopAbs_FACE, faces); TopExp::MapShapes(s, TopAbs_VERTEX, verts);
  NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>, TopTools_ShapeMapHasher> e2f, v2e;
  TopExp::MapShapesAndAncestors(s, TopAbs_EDGE, TopAbs_FACE, e2f);
  TopExp::MapShapesAndAncestors(s, TopAbs_VERTEX, TopAbs_EDGE, v2e);
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> seen; seen.Add(s);
  int n = 0; TopoDS_Edge E;
  for (TopExp_Explorer ex(s, TopAbs_EDGE); ex.More(); ex.Next()) if (seen.Add(ex.Current())) { if (++n == want) E = TopoDS::Edge(ex.Current()); }
  BRepAdaptor_Curve ec(E); gp_Pnt p0 = ec.Value(ec.FirstParameter()), p1 = ec.Value(ec.LastParameter());
  gp_Vec t(p0, p1); t.Normalize();
  printf("edge %d: %s, ends (%.4f %.4f %.4f) -> (%.4f %.4f %.4f), radius under test %.9g\n", want, CT[(int)ec.GetType()], p0.X(), p0.Y(), p0.Z(), p1.X(), p1.Y(), p1.Z(), R);
  for (auto it = e2f.FindFromKey(E).begin(); it != e2f.FindFromKey(E).end(); ++it)
  {
    TopoDS_Face F = TopoDS::Face(*it); BRepAdaptor_Surface a(F);
    printf(" adjacent face f%d (%s)\n", faces.FindIndex(F), ST[(int)a.GetType()]);
    if (a.GetType() != GeomAbs_Plane) continue;
    gp_Dir nrm = a.Plane().Axis().Direction(); if (F.Orientation() == TopAbs_REVERSED) nrm.Reverse();
    gp_Vec u = gp_Vec(nrm).Crossed(t); u.Normalize();       // in-plane, perpendicular to the edge
    // orient u into the face: the average of the face's vertices
    double sum = 0; int cnt = 0;
    for (TopExp_Explorer v(F, TopAbs_VERTEX); v.More(); v.Next()) { gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(v.Current())); sum += gp_Vec(p0, p).Dot(u); ++cnt; }
    if (sum < 0) u.Reverse();
    NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> done;
    for (TopExp_Explorer v(F, TopAbs_VERTEX); v.More(); v.Next())
    {
      if (!done.Add(v.Current())) continue;
      gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(v.Current()));
      double d = gp_Vec(p0, p).Dot(u), along = gp_Vec(p0, p).Dot(t);
      printf("   vertex v%-2d  inward distance from the edge %9.5f   along the edge %9.4f%s\n", verts.FindIndex(v.Current()), d, along,
             std::fabs(d - R) < 1e-6 ? "   <== exactly the radius" : "");
      if (std::fabs(d - R) < 1e-6)
        for (auto it2 = v2e.FindFromKey(v.Current()).begin(); it2 != v2e.FindFromKey(v.Current()).end(); ++it2)
        {
          BRepAdaptor_Curve c(TopoDS::Edge(*it2)); printf("        edge %s", CT[(int)c.GetType()]);
          if (c.GetType() == GeomAbs_Circle) printf(" radius %.4f", c.Circle().Radius());
          printf(" faces:"); for (auto jt = e2f.FindFromKey(*it2).begin(); jt != e2f.FindFromKey(*it2).end(); ++jt) { BRepAdaptor_Surface a2(TopoDS::Face(*jt)); printf(" f%d(%s)", faces.FindIndex(*jt), ST[(int)a2.GetType()]); }
          printf("\n");
        }
    }
  }
  for (TopExp_Explorer v(E, TopAbs_VERTEX); v.More(); v.Next())
  {
    printf(" end vertex v%d: edges meeting there:\n", verts.FindIndex(v.Current()));
    for (auto it = v2e.FindFromKey(v.Current()).begin(); it != v2e.FindFromKey(v.Current()).end(); ++it)
    {
      BRepAdaptor_Curve c(TopoDS::Edge(*it)); printf("    %s", CT[(int)c.GetType()]);
      if (c.GetType() == GeomAbs_Circle) printf(" radius %.6f", c.Circle().Radius());
      printf(" faces:"); for (auto jt = e2f.FindFromKey(*it).begin(); jt != e2f.FindFromKey(*it).end(); ++jt) { BRepAdaptor_Surface a(TopoDS::Face(*jt)); printf(" f%d(%s)", faces.FindIndex(*jt), ST[(int)a.GetType()]); }
      printf("\n");
    }
  }
}
