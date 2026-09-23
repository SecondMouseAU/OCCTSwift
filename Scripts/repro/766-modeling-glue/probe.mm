// Epic #766, Tests/OCCTModelingTests/GlueTests.swift: kernel parity for its one test.
// OCCTShapeGlue is BRepAlgoAPI_Fuse with SetGlue(BOPAlgo_GlueShift), SetFuzzyValue(tol), the two
// shapes as arguments, Build(). Same input: two 10 mm boxes, the second shifted +10 in x so they
// share a face, tolerance 1e-6.
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <cstdio>

static void variant(const TopoDS_Shape& a, const TopoDS_Shape& b, BOPAlgo_GlueEnum g, double fuzzy)
{
  BRepAlgoAPI_Fuse     f;
  TopTools_ListOfShape args;
  args.Append(a);
  args.Append(b);
  f.SetGlue(g);
  if (fuzzy > 0)
    f.SetFuzzyValue(fuzzy);
  f.SetArguments(args);
  f.Build();
  printf("  variant glue=%d fuzzy=%g: done=%d hasErrors=%d\n", (int)g, fuzzy, f.IsDone(), f.HasErrors());
}

int main()
{
  TopoDS_Shape         a = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape         b = BRepPrimAPI_MakeBox(gp_Pnt(5, -5, -5), 10, 10, 10).Shape();
  BRepAlgoAPI_Fuse     fuse;
  TopTools_ListOfShape args;
  args.Append(a);
  args.Append(b);
  fuse.SetGlue(BOPAlgo_GlueShift);
  fuse.SetFuzzyValue(1e-6);
  fuse.SetArguments(args);
  fuse.Build();
  printf("glue fuse: done=%d hasErrors=%d null=%d\n", fuse.IsDone(), fuse.HasErrors(), fuse.Shape().IsNull());
  if (!fuse.IsDone() || fuse.Shape().IsNull())
  {
    // OCCTShapeGlue falls back to a plain BRepAlgoAPI_Fuse when the glue build is not done.
    BRepAlgoAPI_Fuse plain(a, b);
    GProp_GProps     pp;
    BRepGProp::VolumeProperties(plain.Shape(), pp);
    TopTools_IndexedMapOfShape f2;
    TopExp::MapShapes(plain.Shape(), TopAbs_FACE, f2);
    printf("plain fuse fallback: done=%d valid=%d volume=%.10g faces=%d\n", plain.IsDone(),
           BRepCheck_Analyzer(plain.Shape()).IsValid(), pp.Mass(), f2.Extent());
    // Diagnosis only, not what the bridge does: which glue settings build on this input.
    variant(a, b, BOPAlgo_GlueShift, 0);
    variant(a, b, BOPAlgo_GlueFull, 1e-6);
    variant(a, b, BOPAlgo_GlueFull, 0);
    variant(a, b, BOPAlgo_GlueOff, 1e-6);
    // The same glue with b passed as a tool, which a Boolean operation requires.
    BRepAlgoAPI_Fuse     g;
    TopTools_ListOfShape ga, gt;
    ga.Append(a);
    gt.Append(b);
    g.SetGlue(BOPAlgo_GlueShift);
    g.SetFuzzyValue(1e-6);
    g.SetArguments(ga);
    g.SetTools(gt);
    g.Build();
    GProp_GProps gp;
    if (g.IsDone())
      BRepGProp::VolumeProperties(g.Shape(), gp);
    TopTools_IndexedMapOfShape gf;
    if (g.IsDone())
      TopExp::MapShapes(g.Shape(), TopAbs_FACE, gf);
    printf("glue with arguments={a} tools={b}: done=%d valid=%d volume=%.10g faces=%d\n", g.IsDone(),
           g.IsDone() ? BRepCheck_Analyzer(g.Shape()).IsValid() : 0, gp.Mass(), gf.Extent());
    return 0;
  }
  GProp_GProps p;
  BRepGProp::VolumeProperties(fuse.Shape(), p);
  TopTools_IndexedMapOfShape faces, solids;
  TopExp::MapShapes(fuse.Shape(), TopAbs_FACE, faces);
  TopExp::MapShapes(fuse.Shape(), TopAbs_SOLID, solids);
  printf("glueTwoBoxes: done=%d valid=%d volume=%.10g faces=%d solids=%d\n", fuse.IsDone(),
         BRepCheck_Analyzer(fuse.Shape()).IsValid(), p.Mass(), faces.Extent(), solids.Extent());
  return 0;
}
