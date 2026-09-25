// Epic #766 silent-pass fix for PR #2688 (Tests/OCCTModelingTests/BooleanToleranceTests.swift).
// The first version of this probe, and of the tests, measured booleans whose fixtures never
// reached the mode they were named for: Shape.box(width:height:depth:) is CENTRED, so the second
// cube of fuseWithTolerance / fuseWithGlue sat clear of the first and the commons and the cut met
// at a single corner. Every fixture below is corner-based (a centred 20 mm cube is written out as
// its -10 corner), and every result is measured next to a control run with the option off,
// because the difference between the two is what a bridge that dropped the argument would lose.
//
//   fuzzy tolerance : Shape.fused / subtracted / intersected(tolerance:) reach OCCTShapeUnionEx /
//                     SubtractEx / IntersectEx -> runBooleanEx: BRepAlgoAPI_Fuse / Cut / Common
//                     with SetArguments/SetTools and SetFuzzyValue when > 0.
//   glue            : the (glue:) forms reach the same driver with SetGlue(GlueShift / GlueFull).
//                     On genuinely coincident faces every glue mode returned the identical shape
//                     (measured while writing this), so the only observable signature of the glue
//                     argument is what it does to arguments that DO interpenetrate: it declares
//                     them non-interfering and the face/face intersection is skipped.
//
// One `label: key=value ...` line per test, every double at %.17g and every flag as true/false.
// `signedVolume` is the raw BRepGProp::VolumeProperties mass; Shape.volume reports the same mass
// for a solid and is nil for an empty result, where the raw mass is 0. `control*` keys are the
// same operation with the option off (tolerance 0 = no SetFuzzyValue, glue off).
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <cstdio>

// Shape.box(origin:width:height:depth:) is a corner-based box; Shape.box(width:height:depth:) is
// centred on the origin. Every measurement builds its own two boxes: a fuzzy boolean raises the
// tolerance of the arguments' own sub-shapes in place (they share TShapes), so a control run on
// boxes an earlier run already touched is not a control. Measured while writing this: the same
// cut gave 999.9 on fresh boxes and 999.99999999999977 on boxes a fuzzy 0.01 cut had used.
struct Box
{
  double x, y, z, sx, sy, sz;
};

static TopoDS_Shape make(const Box& b)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(b.x, b.y, b.z), b.sx, b.sy, b.sz).Shape();
}

struct Measured
{
  bool   done   = false;
  bool   valid  = false;
  int    solids = 0;
  int    faces  = 0;
  double volume = 0;
};

template <typename Op>
static Measured measure(const Box& a, const Box& b, double fuzzy, BOPAlgo_GlueEnum glue)
{
  Op                   op;
  TopTools_ListOfShape args, tools;
  args.Append(make(a));
  tools.Append(make(b));
  op.SetArguments(args);
  op.SetTools(tools);
  if (fuzzy > 0)
    op.SetFuzzyValue(fuzzy);
  op.SetGlue(glue);
  op.Build();
  Measured m;
  m.done = op.IsDone();
  if (m.done)
  {
    GProp_GProps p;
    BRepGProp::VolumeProperties(op.Shape(), p);
    TopTools_IndexedMapOfShape solids, faces;
    TopExp::MapShapes(op.Shape(), TopAbs_SOLID, solids);
    TopExp::MapShapes(op.Shape(), TopAbs_FACE, faces);
    m.valid  = BRepCheck_Analyzer(op.Shape()).IsValid();
    m.solids = solids.Extent();
    m.faces  = faces.Extent();
    m.volume = p.Mass();
  }
  return m;
}

static const char* tf(bool v)
{
  return v ? "true" : "false";
}

static void print(const char* label, const Measured& m, const Measured& c)
{
  printf("%s: done=%s valid=%s solids=%d faces=%d signedVolume=%.17g controlSolids=%d controlFaces=%d "
         "controlSignedVolume=%.17g\n",
         label, tf(m.done), tf(m.valid), m.solids, m.faces, m.volume, c.solids, c.faces, c.volume);
}

int main()
{
  // fuseWithTolerance: 10 mm cubes with a 0.001 gap between coincident-plane faces, fuzzy 0.01.
  {
    Box a{0, 0, 0, 10, 10, 10}, b{10.001, 0, 0, 10, 10, 10};
    print("fuseWithTolerance", measure<BRepAlgoAPI_Fuse>(a, b, 0.01, BOPAlgo_GlueOff),
          measure<BRepAlgoAPI_Fuse>(a, b, 0, BOPAlgo_GlueOff));
  }
  // cutWithTolerance: a tool slab whose lower face is 0.001 below the top face of the cube, fuzzy 0.01.
  {
    Box a{0, 0, 0, 10, 10, 10}, b{-1, -1, 9.999, 12, 12, 2};
    print("cutWithTolerance", measure<BRepAlgoAPI_Cut>(a, b, 0.01, BOPAlgo_GlueOff),
          measure<BRepAlgoAPI_Cut>(a, b, 0, BOPAlgo_GlueOff));
  }
  // commonWithTolerance: 10 mm cubes overlapping by a 0.001 sliver, fuzzy 0.01.
  {
    Box a{0, 0, 0, 10, 10, 10}, b{9.999, 0, 0, 10, 10, 10};
    print("commonWithTolerance", measure<BRepAlgoAPI_Common>(a, b, 0.01, BOPAlgo_GlueOff),
          measure<BRepAlgoAPI_Common>(a, b, 0, BOPAlgo_GlueOff));
  }
  // fuseWithGlue: interpenetrating 10 mm cubes (overlap 5 x 5 x 5), GlueShift against glue off.
  {
    Box a{0, 0, 0, 10, 10, 10}, b{5, 5, 5, 10, 10, 10};
    print("fuseWithGlue", measure<BRepAlgoAPI_Fuse>(a, b, 0, BOPAlgo_GlueShift),
          measure<BRepAlgoAPI_Fuse>(a, b, 0, BOPAlgo_GlueOff));
  }
  // cutWithGlue: centred 20 mm cube (Shape.box(width: 20, ...) spans -10..10) minus the 10 mm cube
  // at (5,5,5) (overlap 5 x 5 x 5), GlueFull against glue off.
  {
    Box a{-10, -10, -10, 20, 20, 20}, b{5, 5, 5, 10, 10, 10};
    print("cutWithGlue", measure<BRepAlgoAPI_Cut>(a, b, 0, BOPAlgo_GlueFull),
          measure<BRepAlgoAPI_Cut>(a, b, 0, BOPAlgo_GlueOff));
  }
  // commonWithGlue: interpenetrating 10 mm cubes (overlap 5 x 5 x 5), GlueShift against glue off.
  {
    Box a{0, 0, 0, 10, 10, 10}, b{5, 5, 5, 10, 10, 10};
    print("commonWithGlue", measure<BRepAlgoAPI_Common>(a, b, 0, BOPAlgo_GlueShift),
          measure<BRepAlgoAPI_Common>(a, b, 0, BOPAlgo_GlueOff));
  }
  return 0;
}
