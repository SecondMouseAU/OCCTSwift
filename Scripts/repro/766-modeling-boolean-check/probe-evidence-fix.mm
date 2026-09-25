// Epic #766 evidence correction and silent-pass fix for PR #2666
// (Tests/OCCTModelingTests/BooleanCheckTests.swift), records singleShapeParityWithBooleanValid and
// pairParityWithBooleanValidWith. The first version of this probe measured one flag for the pair
// (a box and a sphere), and the single-shape record carried two bridge values against one kernel
// value; both records now carry the same keys on both sides.
//
// The two tests compared a wrapper with the call it forwards to (isValidForBoolean ==
// isBooleanValid(), isValidForBoolean(with:) == isBooleanValidWith), which is one bridge function
// called twice, on a box and a sphere for which every setting of the small-edge and
// self-interference tests answers true, so no drift in the forwarded defaults could show. They now
// compare the wrapper with the kernel's own BOPAlgo_ArgumentAnalyzer (Shape.analyzeBoolean,
// OCCTBOPAlgoAnalyzeArguments: SetShape1/SetShape2, OperationType, ArgumentTypeMode = SelfInterMode
// = SmallEdgeMode = true, Perform, !HasFaulty) on shapes that give both verdicts, and a fixture for
// each of the two tests the wrapper turns on: a box 5e-7 thick (its edges are shorter than the
// small-edge tolerance; the self-interference test does not flag it) and a compound of two
// overlapping cubes (the self-interference test flags it; the small-edge test does not).
//
// `valid` is what the bridge's OCCTShapeBooleanCheckSingle / OCCTShapeBooleanCheckPair return:
// BRepAlgoAPI_Check(s, true, true).IsValid() and BRepAlgoAPI_Check(a, b, BOPAlgo_UNKNOWN(5), true,
// true).IsValid(), the Swift defaults. `analyzerValid` is BOPAlgo_ArgumentAnalyzer as above with
// the operation FUSE, the single-shape cases paired with a valid 5 mm sphere as the second argument.
// `validWithout...Test` is the same check with that one test turned off.
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BRepAlgoAPI_Check.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Builder.hxx>
#include <TopoDS_Compound.hxx>
#include <cstdio>

static const char* tf(bool b)
{
  return b ? "true" : "false";
}

static TopoDS_Shape at(double x, double y, double z, double sx, double sy, double sz)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(x, y, z), sx, sy, sz).Shape();
}

// Shape.box(width:height:depth:) is centred on the origin.
static TopoDS_Shape box()
{
  return at(-5, -10, -15, 10, 20, 30);
}

static TopoDS_Shape sphere()
{
  return BRepPrimAPI_MakeSphere(5).Shape();
}

static TopoDS_Shape thin()
{
  return at(0, 0, 0, 10, 10, 5e-7);
}

static TopoDS_Shape overlapping()
{
  BRep_Builder    b;
  TopoDS_Compound c;
  b.MakeCompound(c);
  b.Add(c, at(0, 0, 0, 10, 10, 10));
  b.Add(c, at(5, 5, 5, 10, 10, 10));
  return c;
}

static bool analyzer(const TopoDS_Shape& s1, const TopoDS_Shape& s2)
{
  BOPAlgo_ArgumentAnalyzer a;
  a.SetShape1(s1);
  a.SetShape2(s2);
  a.OperationType()    = BOPAlgo_FUSE;
  a.ArgumentTypeMode() = true;
  a.SelfInterMode()    = true;
  a.SmallEdgeMode()    = true;
  a.Perform();
  return !a.HasFaulty();
}

static bool single(const TopoDS_Shape& s, bool smallEdges = true, bool selfInterference = true)
{
  return BRepAlgoAPI_Check(s, smallEdges, selfInterference).IsValid();
}

static bool pair(const TopoDS_Shape& a, const TopoDS_Shape& b, bool smallEdges = true, bool selfInterference = true)
{
  return BRepAlgoAPI_Check(a, b, static_cast<BOPAlgo_Operation>(5), smallEdges, selfInterference).IsValid();
}

static void shape(const char* name, const TopoDS_Shape& s, const char* extraKey, bool extra)
{
  printf("singleShapeParityWithBooleanValid(%s): valid=%s analyzerValid=%s", name, tf(single(s)),
         tf(analyzer(s, sphere())));
  if (extraKey)
    printf(" %s=%s", extraKey, tf(extra));
  printf("\n");
}

static void pairLine(const char* name, const TopoDS_Shape& a, const TopoDS_Shape& b, const char* extraKey = nullptr,
                     bool extra = false)
{
  printf("pairParityWithBooleanValidWith(%s): valid=%s analyzerValid=%s", name, tf(pair(a, b)), tf(analyzer(a, b)));
  if (extraKey)
    printf(" %s=%s", extraKey, tf(extra));
  printf("\n");
}

int main()
{
  shape("box", box(), nullptr, false);
  shape("sphere", sphere(), nullptr, false);
  shape("thinBox", thin(), "validWithoutSmallEdgeTest", single(thin(), false, true));
  shape("overlappingCompound", overlapping(), "validWithoutSelfInterferenceTest", single(overlapping(), true, false));
  pairLine("boxSphere", box(), sphere());
  pairLine("thinBoxSphere", thin(), sphere(), "validWithoutSmallEdgeTest", pair(thin(), sphere(), false, true));
  pairLine("boxOverlappingCompound", box(), overlapping(), "validWithoutSelfInterferenceTest",
           pair(box(), overlapping(), true, false));
  pairLine("overlappingCompoundSphere", overlapping(), sphere());
  return 0;
}
