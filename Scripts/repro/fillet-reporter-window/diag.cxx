// Where is a done-but-invalid fillet result broken?  diag model.brep radius edge [draw|def]
// Prints every sub-shape BRepCheck rejects (with its status list and a location), the free edges of the shell,
// and the edges shorter than 5e-3 (the sliver edges a vertex snap leaves behind).
#include <BRepAdaptor_Curve.hxx>
#include <BRepBndLib.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <ChFi3d_FilletShape.hxx>
#include <GProp_GProps.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <NCollection_List.hxx>
#include <NCollection_Map.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <cstdlib>
#include <cstring>
static const char* ST[] = {"Plane","Cylinder","Cone","Sphere","Torus","BezierS","BSplineS","Revolution","Extrusion","Offset","Other"};
static const char* CT[] = {"Line","Circle","Ellipse","Hyperbola","Parabola","BezierC","BSplineC","Offset","Other"};
static const char* TY[] = {"COMPOUND","COMPSOLID","SOLID","SHELL","FACE","WIRE","EDGE","VERTEX","SHAPE"};
static void loc(const TopoDS_Shape& s) { Bnd_Box b; BRepBndLib::Add(s, b); double a, c, d, e, f, g; b.Get(a, c, d, e, f, g); printf("[%.3f %.3f %.3f]-[%.3f %.3f %.3f]", a, c, d, e, f, g); }
int main(int, char** argv)
{
  TopoDS_Shape s; BRep_Builder b; BRepTools::Read(s, argv[1], b);
  double R = atof(argv[2]); int want = atoi(argv[3]); bool draw = argv[4] && !strcmp(argv[4], "draw");
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> seen; seen.Add(s); int n = 0; TopoDS_Edge E;
  for (TopExp_Explorer ex(s, TopAbs_EDGE); ex.More(); ex.Next()) if (seen.Add(ex.Current())) { if (++n == want) E = TopoDS::Edge(ex.Current()); }
  BRepFilletAPI_MakeFillet mk(s, ChFi3d_Rational);
  if (draw) { mk.SetParams(1e-2, 1e-4, 1e-5, 1e-4, 1e-5, 1e-3); mk.SetContinuity(GeomAbs_C1, 1e-2); }
  mk.Add(R, E); mk.Build();
  if (!mk.IsDone()) { printf("not done\n"); return 0; }
  TopoDS_Shape r = mk.Shape(); BRepCheck_Analyzer an(r);
  printf("valid=%d\n", (int)an.IsValid());
  for (int t = TopAbs_FACE; t <= TopAbs_VERTEX; ++t)
    for (TopExp_Explorer ex(r, (TopAbs_ShapeEnum)t); ex.More(); ex.Next())
    {
      const occ::handle<BRepCheck_Result>& res = an.Result(ex.Current());
      if (res.IsNull()) continue;
      for (const auto& st : res->Status()) if (st != BRepCheck_NoError) { printf("  invalid %s status=%d at ", TY[t], (int)st); loc(ex.Current()); printf("\n"); }
    }
  NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>, TopTools_ShapeMapHasher> e2f; TopExp::MapShapesAndAncestors(r, TopAbs_EDGE, TopAbs_FACE, e2f);
  for (int i = 1; i <= e2f.Extent(); ++i)
  {
    const TopoDS_Edge& e = TopoDS::Edge(e2f.FindKey(i)); BRepAdaptor_Curve c(e); GProp_GProps p; BRepGProp::LinearProperties(e, p);
    int cnt = 0; for (TopExp_Explorer fx(r, TopAbs_FACE); fx.More(); fx.Next()) for (TopExp_Explorer ex2(fx.Current(), TopAbs_EDGE); ex2.More(); ex2.Next()) if (ex2.Current().IsSame(e)) ++cnt;
    bool deg = BRep_Tool::Degenerated(e);
    if ((!deg && cnt < 2) || p.Mass() < 5e-3) { printf("  %s edge %s len=%.6f tol=%.2e faces=%d at ", cnt < 2 && !deg ? "FREE" : "short", CT[(int)c.GetType()], p.Mass(), BRep_Tool::Tolerance(e), cnt); loc(e); printf("\n"); }
  }
}
