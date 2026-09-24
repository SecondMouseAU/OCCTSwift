// Epic #766, ApproxCurveOnSurfaceTests.swift: kernel parity. BRepPrimAPI_MakeCylinder(10, 20),
// faces and edges enumerated with TopExp::MapShapes as OCCTShapeGetFaces / Shape.edges() do,
// then for every edge on face 1 the OCCTApproxCurveOnSurface chain: BRep_Tool::CurveOnSurface,
// Approx_CurveOnSurface(pcurve, surface, first, last, 1e-4).Perform(10, 8, GeomAbs_C2), and the
// length and end points of the resulting 3D curve.
#include <Approx_CurveOnSurface.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Geom_BSplineCurve.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(10, 20).Shape();
  TopTools_IndexedMapOfShape faces, edges;
  TopExp::MapShapes(cyl, TopAbs_FACE, faces);
  TopExp::MapShapes(cyl, TopAbs_EDGE, edges);
  TopoDS_Face f = TopoDS::Face(faces(1));
  printf("faces=%d edges=%d face1 surface=%s\n", faces.Extent(), edges.Extent(),
         BRep_Tool::Surface(f)->DynamicType()->Name());
  for (int k = 1; k <= edges.Extent(); k++)
  {
    TopoDS_Edge          e = TopoDS::Edge(edges(k));
    double               first, last;
    Handle(Geom2d_Curve) pc = BRep_Tool::CurveOnSurface(e, f, first, last);
    if (pc.IsNull())
    {
      printf("edge[%d]: no pcurve on face 1\n", k - 1);
      continue;
    }
    Approx_CurveOnSurface approx(new Geom2dAdaptor_Curve(pc, first, last),
                                 new GeomAdaptor_Surface(BRep_Tool::Surface(f)), first, last, 1e-4);
    approx.Perform(10, 8, GeomAbs_C2);
    if (!approx.IsDone() || !approx.HasResult())
    {
      printf("edge[%d]: approx not done\n", k - 1);
      continue;
    }
    Handle(Geom_BSplineCurve) c3 = approx.Curve3d();
    TopoDS_Edge               out = BRepBuilderAPI_MakeEdge(c3).Edge();
    GProp_GProps              g, gsrc;
    BRepGProp::LinearProperties(out, g);
    BRepGProp::LinearProperties(e, gsrc);
    gp_Pnt a = c3->Value(c3->FirstParameter()), b = c3->Value(c3->LastParameter());
    printf("edge[%d]: source length=%.17g approx length=%.17g start=(%.9g, %.9g, %.9g) end=(%.9g, %.9g, %.9g) maxError3d=%.3g\n",
           k - 1, gsrc.Mass(), g.Mass(), a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z(), approx.MaxError3d());
  }
  return 0;
}
