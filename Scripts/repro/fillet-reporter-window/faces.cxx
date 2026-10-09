// Dump every face of a brep: type, analytic parameters, UV bounds; every edge's curve type/ends/tolerance; vertex tolerances.
#include <BRep_Builder.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <NCollection_IndexedMap.hxx>
#include <gp_Torus.hxx>
#include <gp_Cylinder.hxx>
#include <cstdio>
static const char* ST[] = {"Plane","Cylinder","Cone","Sphere","Torus","BezierS","BSplineS","Revolution","Extrusion","Offset","Other"};
static const char* CT[] = {"Line","Circle","Ellipse","Hyperbola","Parabola","BezierC","BSplineC","Offset","Other"};
int main(int, char** argv)
{
  TopoDS_Shape s; BRep_Builder b; BRepTools::Read(s, argv[1], b);
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> F, E, V; TopExp::MapShapes(s, TopAbs_FACE, F); TopExp::MapShapes(s, TopAbs_EDGE, E); TopExp::MapShapes(s, TopAbs_VERTEX, V);
  for (int i = 1; i <= F.Extent(); ++i)
  {
    TopoDS_Face f = TopoDS::Face(F(i)); BRepAdaptor_Surface a(f); double u0, u1, v0, v1; BRepTools::UVBounds(f, u0, u1, v0, v1);
    printf("f%-2d %-9s tol %.2e uv[%.4f %.4f]x[%.4f %.4f]", i, ST[(int)a.GetType()], BRep_Tool::Tolerance(f), u0, u1, v0, v1);
    if (a.GetType() == GeomAbs_Torus) { gp_Torus t = a.Torus(); gp_Pnt c = t.Location(); gp_Dir d = t.Axis().Direction(); printf(" R=%.4f r=%.4f centre(%.3f %.3f %.3f) axis(%.3f %.3f %.3f)", t.MajorRadius(), t.MinorRadius(), c.X(), c.Y(), c.Z(), d.X(), d.Y(), d.Z()); }
    if (a.GetType() == GeomAbs_Cylinder) { gp_Cylinder t = a.Cylinder(); gp_Pnt c = t.Location(); gp_Dir d = t.Axis().Direction(); printf(" r=%.4f centre(%.3f %.3f %.3f) axis(%.3f %.3f %.3f)", t.Radius(), c.X(), c.Y(), c.Z(), d.X(), d.Y(), d.Z()); }
    if (a.GetType() == GeomAbs_Plane) { gp_Dir d = a.Plane().Axis().Direction(); gp_Pnt c = a.Plane().Location(); printf(" n(%.3f %.3f %.3f) o(%.3f %.3f %.3f) %s", d.X(), d.Y(), d.Z(), c.X(), c.Y(), c.Z(), f.Orientation() == TopAbs_REVERSED ? "REV" : "FWD"); }
    printf("\n");
  }
  for (int i = 1; i <= E.Extent(); ++i)
  {
    TopoDS_Edge e = TopoDS::Edge(E(i)); BRepAdaptor_Curve c(e); gp_Pnt p0 = c.Value(c.FirstParameter()), p1 = c.Value(c.LastParameter());
    printf("e%-2d %-7s tol %.2e (%.3f %.3f %.3f)->(%.3f %.3f %.3f)", i, CT[(int)c.GetType()], BRep_Tool::Tolerance(e), p0.X(), p0.Y(), p0.Z(), p1.X(), p1.Y(), p1.Z());
    if (c.GetType() == GeomAbs_Circle) printf(" R=%.4f", c.Circle().Radius());
    printf("\n");
  }
  for (int i = 1; i <= V.Extent(); ++i) { gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(V(i))); printf("v%-2d tol %.2e (%.4f %.4f %.4f)\n", i, BRep_Tool::Tolerance(TopoDS::Vertex(V(i))), p.X(), p.Y(), p.Z()); }
}
