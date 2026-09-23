// Epic #766, BRepClass3dTests.swift, BRepClassFClassifierTests.swift and
// BRepLibExtendedTests.swift: kernel parity for all eleven tests. Same inputs as the Swift tests,
// straight to OCCT: BRepClass3d_SolidClassifier (OCCTShapeClassifyPoint), BRepClass_FClassifier
// over BRepClass_FaceExplorer (OCCTShapeClassifyPoint2D), and the BRepLib statics
// EnsureNormalConsistency, UpdateDeflection, ContinuityOfFaces and SameParameter after the same
// BRepMesh_IncrementalMesh(0.5, false, 0.5) that Shape.mesh(linearDeflection: 0.5) runs.
#include <BRepBndLib.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepClass_FClassifier.hxx>
#include <BRepClass_FaceExplorer.hxx>
#include <BRepLib.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <Poly_Triangulation.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Shape centredBox(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static const char* st(TopAbs_State s)
{
  return s == TopAbs_IN ? "IN" : s == TopAbs_OUT ? "OUT" : s == TopAbs_ON ? "ON" : "UNKNOWN";
}

static void faceBounds(const char* tag, const TopoDS_Face& f)
{
  Bnd_Box b;
  BRepBndLib::Add(f, b, Standard_True);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  TopLoc_Location            loc;
  Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(f, loc);
  printf("%s: triangulation deflection %.17g, face bounds (%.17g, %.17g, %.17g) to (%.17g, "
         "%.17g, %.17g)\n",
         tag, tri.IsNull() ? -1.0 : tri->Deflection(), x0, y0, z0, x1, y1, z1);
}

int main()
{
  TopoDS_Shape cube   = centredBox(10, 10, 10);
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5.0).Shape();
  printf("pointInsideBox: %s\n", st(BRepClass3d_SolidClassifier(cube, gp_Pnt(0, 0, 0), 1e-6).State()));
  printf("pointOutsideBox: %s\n",
         st(BRepClass3d_SolidClassifier(cube, gp_Pnt(20, 20, 20), 1e-6).State()));
  printf("pointInsideSphere: %s\n",
         st(BRepClass3d_SolidClassifier(sphere, gp_Pnt(0, 0, 0), 1e-6).State()));
  printf("pointOutsideSphere: %s\n",
         st(BRepClass3d_SolidClassifier(sphere, gp_Pnt(10, 0, 0), 1e-6).State()));
  printf("pointOnBoxFace: %s\n", st(BRepClass3d_SolidClassifier(cube, gp_Pnt(0, 0, 5), 1e-3).State()));

  {
    TopoDS_Shape               b = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(b, TopAbs_FACE, faces);
    TopoDS_Face f = TopoDS::Face(faces(1));
    double      u0, u1, v0, v1;
    BRepTools::UVBounds(f, u0, u1, v0, v1);
    BRepClass_FaceExplorer ex(f);
    BRepClass_FClassifier  in(ex, gp_Pnt2d((u0 + u1) / 2, (v0 + v1) / 2), 1e-6);
    BRepClass_FaceExplorer ex2(f);
    BRepClass_FClassifier  out(ex2, gp_Pnt2d(100, 100), 1e-6);
    printf("classifyPoint2D: face 0 uv [%.17g, %.17g] x [%.17g, %.17g], mid %s, (100,100) %s\n",
           u0, u1, v0, v1, st(in.State()), st(out.State()));
  }

  {
    TopoDS_Shape b = centredBox(10, 10, 10);
    BRepMesh_IncrementalMesh(b, 0.5, Standard_False, 0.5).Perform();
    bool changed = BRepLib::EnsureNormalConsistency(b, 0.01);
    printf("ensureNormalConsistency(0.01) after mesh 0.5: %d\n", changed);
  }
  {
    TopoDS_Shape b = centredBox(10, 10, 10);
    BRepMesh_IncrementalMesh(b, 0.5, Standard_False, 0.5).Perform();
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(b, TopAbs_FACE, faces);
    faceBounds("updateDeflection before", TopoDS::Face(faces(1)));
    BRepLib::UpdateDeflection(b);
    faceBounds("updateDeflection after", TopoDS::Face(faces(1)));
  }
  {
    TopoDS_Shape                              b = centredBox(10, 10, 10);
    TopTools_IndexedMapOfShape                edges, faces;
    TopTools_IndexedDataMapOfShapeListOfShape ef;
    TopExp::MapShapes(b, TopAbs_EDGE, edges);
    TopExp::MapShapes(b, TopAbs_FACE, faces);
    TopExp::MapShapesAndAncestors(b, TopAbs_EDGE, TopAbs_FACE, ef);
    const TopoDS_Edge& e1 = TopoDS::Edge(edges(1));
    printf("edge 1 faces:");
    for (const TopoDS_Shape& f : ef.FindFromKey(e1))
      printf(" %d", faces.FindIndex(f) - 1);
    printf(" (0-based)\n");
    try
    {
      printf("continuity(edge 0, face 0, face 1): %d\n",
             (int)BRepLib::ContinuityOfFaces(e1, TopoDS::Face(faces(1)), TopoDS::Face(faces(2)), 1e-6));
    }
    catch (...)
    {
      printf("continuity(edge 0, face 0, face 1): threw\n");
    }
    const TopoDS_Face& fa = TopoDS::Face(ef.FindFromKey(e1).First());
    const TopoDS_Face& fb = TopoDS::Face(ef.FindFromKey(e1).Last());
    printf("continuity(edge 0, its two faces): %d\n",
           (int)BRepLib::ContinuityOfFaces(e1, fa, fb, 1e-6));
  }
  {
    ShapeAnalysis_ShapeTolerance sat;
    TopoDS_Shape                 b = centredBox(10, 10, 10);
    BRepLib::SameParameter(b, 1e-5, Standard_False);
    printf("sameParameter(1e-5) fresh box: edge tol max %.17g\n", sat.Tolerance(b, 1, TopAbs_EDGE));
    TopoDS_Shape c = centredBox(10, 10, 10);
    BRepLib::SameParameter(c, 1e-5, Standard_True);
    printf("sameParameter(1e-5, forced) fresh box: edge tol max %.17g\n",
           sat.Tolerance(c, 1, TopAbs_EDGE));
    TopoDS_Shape d = centredBox(10, 10, 10);
    ShapeFix_ShapeTolerance().SetTolerance(d, 0.01);
    BRepLib::SameParameter(d, 1e-5, Standard_False);
    printf("fix 0.01 then sameParameter(1e-5): edge tol max %.17g\n",
           sat.Tolerance(d, 1, TopAbs_EDGE));
    TopoDS_Shape e = centredBox(10, 10, 10);
    ShapeFix_ShapeTolerance().SetTolerance(e, 0.01);
    BRepLib::SameParameter(e, 1e-5, Standard_True);
    printf("fix 0.01 then sameParameter(1e-5, forced): edge tol max %.17g\n",
           sat.Tolerance(e, 1, TopAbs_EDGE));
  }
  return 0;
}
