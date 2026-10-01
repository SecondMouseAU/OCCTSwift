// Epic #766 evidence correction for PR #2687 (Tests/OCCTModelingTests/BooleanExpansionTests.swift).
// probe.mm printed the kernel side at %.10g and under keys the bridge side did not share. This
// probe repeats the same OCCT calls and prints every double at %.17g and every flag as true/false,
// one `label: key=value ...` line per test, so a record's kernel data is read from the transcript.
// Same inputs as the Swift tests, straight to the OCCT classes the bridge calls:
// BRepAlgoAPI_Section + SetFuzzyValue (OCCTBooleanSectionWithTolerance), BRepAlgoAPI_Splitter
// (OCCTBooleanSplitMulti), BRepAlgoAPI_Cut with SetArguments/SetTools (OCCTBooleanCutWithHistory),
// BRepFilletAPI_MakeFillet on every explorer edge (OCCTShapeFillet) and BRepAlgoAPI_Defeaturing
// (OCCTShapeDefeature).
//
// Silent-pass revision (#766): sectionWithTolerance measured a corner touch (one vertex, no edge),
// and cutWithHistory measured one fixture whose three history flags are all true, so it could not
// tell a bridge that reports the kernel's flags from one that reports true. sectionWithTolerance is
// now a 0.001 gap between coincident-plane faces, measured at fuzzy 0.01 and at 0 (the fuzzy value is
// what turns an empty section into a 4-edge outline); splitMulti also reads the two solid volumes;
// cutWithHistory measures three tools that give three different flag patterns. Every operation
// builds its own boxes: a fuzzy boolean raises the tolerance of its arguments' sub-shapes in place,
// so a second run on boxes an earlier one used is not a control. The defeature line is unchanged.
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <algorithm>
#include <cstdio>
#include <vector>

static const char* tf(bool b) { return b ? "true" : "false"; }

static TopoDS_Shape centred(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static TopoDS_Shape at(double x, double y, double z, double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(x, y, z), w, h, d).Shape();
}

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}

// BRepAlgoAPI_Section as OCCTBooleanSectionWithTolerance drives it: SetFuzzyValue(fuzzy) always.
static void section(double fuzzy, int& edges, int& vertices, bool& done)
{
  BRepAlgoAPI_Section sec(at(0, 0, 0, 10, 10, 10), at(10.001, 0, 0, 10, 10, 10), Standard_False);
  sec.SetFuzzyValue(fuzzy);
  sec.Build();
  done     = sec.IsDone();
  edges    = count(sec.Shape(), TopAbs_EDGE);
  vertices = count(sec.Shape(), TopAbs_VERTEX);
}

// BRepAlgoAPI_Cut of the 20 mm cube (-10..10) by a tool box, as OCCTBooleanCutWithHistory drives it.
static void cutHistory(const char* label, double tx, double ty, double tz, double ts)
{
  BRepAlgoAPI_Cut      cut;
  TopTools_ListOfShape args, tools;
  args.Append(centred(20, 20, 20));
  tools.Append(at(tx, ty, tz, ts, ts, ts));
  cut.SetArguments(args);
  cut.SetTools(tools);
  cut.Build();
  printf("%s: done=%s valid=%s volume=%.17g hasDeleted=%s hasModified=%s hasGenerated=%s\n", label,
         tf(cut.IsDone()), tf(BRepCheck_Analyzer(cut.Shape()).IsValid()), volume(cut.Shape()),
         tf(cut.HasDeleted()), tf(cut.HasModified()), tf(cut.HasGenerated()));
}

int main()
{
  {
    int  edges, vertices, controlEdges, controlVertices;
    bool done, controlDone;
    section(0.01, edges, vertices, done);
    section(0, controlEdges, controlVertices, controlDone);
    printf("sectionWithTolerance: done=%s edges=%d vertices=%d controlEdges=%d controlVertices=%d\n",
           tf(done && controlDone), edges, vertices, controlEdges, controlVertices);
  }
  {
    BRepAlgoAPI_Splitter sp;
    TopTools_ListOfShape args, tools;
    args.Append(centred(20, 20, 20));
    tools.Append(at(5, 5, 5, 10, 10, 10));
    sp.SetArguments(args);
    sp.SetTools(tools);
    sp.Build();
    std::vector<double> volumes;
    for (TopExp_Explorer ex(sp.Shape(), TopAbs_SOLID); ex.More(); ex.Next())
      volumes.push_back(volume(ex.Current()));
    std::sort(volumes.begin(), volumes.end());
    printf("splitMulti: done=%s solids=%d volume=%.17g smallSolidVolume=%.17g largeSolidVolume=%.17g\n",
           tf(sp.IsDone()), count(sp.Shape(), TopAbs_SOLID), volume(sp.Shape()),
           volumes.empty() ? 0.0 : volumes.front(), volumes.empty() ? 0.0 : volumes.back());
  }
  cutHistory("cutWithHistory(overlap)", 5, 5, 5, 10);
  cutHistory("cutWithHistory(clear)", 100, 0, 0, 10);
  cutHistory("cutWithHistory(buried)", -2, -2, -2, 4);
  {
    TopoDS_Shape             box = centred(20, 20, 20);
    BRepFilletAPI_MakeFillet mf(box);
    for (TopExp_Explorer ex(box, TopAbs_EDGE); ex.More(); ex.Next())
      mf.Add(2.0, TopoDS::Edge(ex.Current()));
    mf.Build();
    TopoDS_Shape               f = mf.Shape();
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(f, TopAbs_FACE, faces);
    TopTools_ListOfShape remove;
    remove.Append(faces(7)); // Swift: faces.suffix(from: 6).prefix(2), i.e. ordinals 6 and 7
    remove.Append(faces(8));
    BRepAlgoAPI_Defeaturing df;
    df.SetShape(f);
    df.AddFacesToRemove(remove);
    df.Build();
    // One line: filleted faces and volume, then the defeatured result and the volume growth.
    printf("defeature: filletDone=%s filletedFaces=%d filletedVolume=%.17g done=%s", tf(mf.IsDone()),
           faces.Extent(), volume(f), tf(df.IsDone()));
    if (df.IsDone())
      printf(" valid=%s resultFaces=%d resultVolume=%.17g volumeDelta=%.17g",
             tf(BRepCheck_Analyzer(df.Shape()).IsValid()), count(df.Shape(), TopAbs_FACE), volume(df.Shape()),
             volume(df.Shape()) - volume(f));
    printf("\n");
  }
  return 0;
}
