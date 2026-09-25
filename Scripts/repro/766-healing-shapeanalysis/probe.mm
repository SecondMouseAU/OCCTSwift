// #766 kernel parity: ShapeAnalysisCurveStaticTests, ShapeAnalysisSurfaceTests, ShapeAnalysisTests,
// ShapeAnalysisTransferParametersProjTests. ShapeAnalysis_Curve::IsClosed/IsPeriodic/IsPlanar
// (OCCTCurve3DIsClosedWithPreci / IsPeriodicSA / IsPlanar), ShapeAnalysis_Surface
// (OCCTSurfaceProjectPointUV / HasSingularities / NbSingularities / IsUClosed / IsVClosed),
// OCCTShapeAnalyze's per-wire gap count and small-edge/face counts, and
// ShapeAnalysis_TransferParametersProj (OCCTShapeAnalysisTransferParam).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Builder.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <ShapeAnalysis_Surface.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeAnalysis_TransferParametersProj.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

// OCCTShapeAnalyze's small-edge/face and gap counts.
static void analyze(const char* label, const TopoDS_Shape& s, double tol)
{
  int small = 0, smallF = 0, gaps = 0;
  for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
  {
    if (BRep_Tool::Degenerated(TopoDS::Edge(e.Current())))
      continue;
    GProp_GProps g;
    BRepGProp::LinearProperties(e.Current(), g);
    if (g.Mass() < tol)
      small++;
  }
  for (TopExp_Explorer f(s, TopAbs_FACE); f.More(); f.Next())
  {
    GProp_GProps g;
    BRepGProp::SurfaceProperties(f.Current(), g);
    if (g.Mass() < tol * tol)
      smallF++;
  }
  for (TopExp_Explorer w(s, TopAbs_WIRE); w.More(); w.Next())
  {
    TopoDS_Face face;
    for (TopExp_Explorer f(s, TopAbs_FACE); f.More() && face.IsNull(); f.Next())
      for (TopExp_Explorer iw(f.Current(), TopAbs_WIRE); iw.More(); iw.Next())
        if (iw.Current().IsSame(w.Current()))
        {
          face = TopoDS::Face(f.Current());
          break;
        }
    if (face.IsNull())
      continue;
    ShapeAnalysis_Wire wa(TopoDS::Wire(w.Current()), face, tol);
    for (int i = 1; i <= wa.NbEdges(); i++)
      if (wa.CheckGap3d(i))
        gaps++;
  }
  printf("%s (tol %g): smallEdges=%d smallFaces=%d gaps=%d BRepCheck valid=%d\n", label, tol, small, smallF, gaps,
         (int)BRepCheck_Analyzer(s).IsValid());
}

int main()
{
  ShapeAnalysis_Curve sac;
  Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  Handle(Geom_Line)   line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  gp_XYZ              n1, n2;
  bool                p1 = sac.IsPlanar(circ, n1, 1e-6), p2 = sac.IsPlanar(line, n2, 1e-6);
  printf("circle: IsClosed=%d IsPeriodic=%d IsPlanar=%d normal=(%g, %g, %g)\n", (int)ShapeAnalysis_Curve::IsClosed(circ, 1e-6),
         (int)ShapeAnalysis_Curve::IsPeriodic(circ), (int)p1, n1.X(), n1.Y(), n1.Z());
  printf("line: IsClosed=%d IsPeriodic=%d IsPlanar=%d normal=(%g, %g, %g)\n", (int)ShapeAnalysis_Curve::IsClosed(line, 1e-6),
         (int)ShapeAnalysis_Curve::IsPeriodic(line), (int)p2, n2.X(), n2.Y(), n2.Z());

  Handle(Geom_Plane)    pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  ShapeAnalysis_Surface sas(pl);
  gp_Pnt2d              uv = sas.ValueOfUV(gp_Pnt(5, 3, 0), 1e-7);
  printf("plane ValueOfUV(5,3,0)=(%g, %g) gap=%.3e\n", uv.X(), uv.Y(), sas.Gap());
  uv = sas.ValueOfUV(gp_Pnt(0, 0, 10), 1e-7);
  printf("plane ValueOfUV(0,0,10)=(%g, %g) gap=%.9f\n", uv.X(), uv.Y(), sas.Gap());
  printf("plane HasSingularities=%d NbSingularities=%d IsUClosed=%d IsVClosed=%d\n", (int)sas.HasSingularities(1e-7),
         sas.NbSingularities(1e-7), (int)sas.IsUClosed(1e-7), (int)sas.IsVClosed(1e-7));

  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  analyze("box", box, 0.001);
  analyze("box", box, 1e-6);
  {
    // #1438 gappy face: three line edges with a 1.0 and a 0.5 gap, planar face on them
    BRep_Builder b;
    TopoDS_Wire  w;
    b.MakeWire(w);
    b.Add(w, BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge());
    b.Add(w, BRepBuilderAPI_MakeEdge(gp_Pnt(10, 1, 0), gp_Pnt(5, 10, 0)).Edge());
    b.Add(w, BRepBuilderAPI_MakeEdge(gp_Pnt(5.5, 10, 0), gp_Pnt(0, 0, 0)).Edge());
    BRepBuilderAPI_MakeFace mf(w, true);
    printf("gappy face built=%d\n", (int)mf.IsDone());
    if (mf.IsDone())
      analyze("gappy face", mf.Face(), 0.01);
  }
  {
    TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(10, 20).Shape();
    TopTools_IndexedMapOfShape edges, faces;
    TopExp::MapShapes(cyl, TopAbs_EDGE, edges);
    TopExp::MapShapes(cyl, TopAbs_FACE, faces);
    ShapeAnalysis_TransferParametersProj t(TopoDS::Edge(edges(1)), TopoDS::Face(faces(1)));
    printf("TransferParametersProj(cyl edge1, face1): toFace(1.0)=%.9f fromFace(1.0)=%.9f\n", t.Perform(1.0, true),
           t.Perform(1.0, false));
  }
  return 0;
}
