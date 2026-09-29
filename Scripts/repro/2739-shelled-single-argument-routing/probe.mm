// Ground truth for #2739: which BRepOffsetAPI_MakeThickSolid entry point OCCTShapeShell should
// call for a closed solid, and what the negative volumes #2739 records actually are.
//
// Compile (from the repo root, in a worktree with no Libraries/OCCT.xcframework, so the pinned
// v4.0.0-kernel.2 asset SwiftPM resolved is what gets linked):
//
//   XCF=$(find .build/artifacts -maxdepth 4 -name OCCT.xcframework)
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"$XCF/macos-arm64/Headers" -L"$XCF/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2739-shelled-single-argument-routing/probe.mm -o /tmp/occt_probe_2739

#include <BRepCheck_Analyzer.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GProp_GProps.hxx>
#include <Precision.hxx>
#include <TopAbs.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>

static double volumeOf(const TopoDS_Shape& s)
{
  GProp_GProps props;
  BRepGProp::VolumeProperties(s, props);
  return props.Mass();
}

static int countOf(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  int             n = 0;
  TopExp_Explorer exp(s, t);
  for (; exp.More(); exp.Next())
    n++;
  return n;
}

static void report(const char* label, BRepOffsetAPI_MakeThickSolid& maker)
{
  if (!maker.IsDone())
  {
    printf("%-62s IsDone=0\n", label);
    return;
  }
  const TopoDS_Shape& r = maker.Shape();
  if (r.IsNull())
  {
    printf("%-62s IsDone=1 shape=NULL\n", label);
    return;
  }
  BRepCheck_Analyzer checker(r);
  printf("%-62s IsDone=1 type=%d solids=%d shells=%d faces=%d valid=%d volume=%.6f\n",
         label,
         (int)r.ShapeType(),
         countOf(r, TopAbs_SOLID),
         countOf(r, TopAbs_SHELL),
         countOf(r, TopAbs_FACE),
         checker.IsValid() ? 1 : 0,
         volumeOf(r));
}

// OCCT's own ThickSolid_Cylinder_Baseline / ThickSolid_Sphere_Baseline argument set,
// src/ModelingAlgorithms/TKOffset/GTests/BRepOffset_MakeOffset_Test.cxx:766 and :799.
static void byJoinEmpty(const char* what, const TopoDS_Shape& s, double t)
{
  char label[256];
  snprintf(label, sizeof(label), "ByJoin(%s, EMPTY faces, %+.1f)", what, t);
  TopTools_ListOfShape         none;
  BRepOffsetAPI_MakeThickSolid maker;
  maker
    .MakeThickSolidByJoin(s, none, t, 1.0e-3, BRepOffset_Skin, false, false, GeomAbs_Intersection);
  maker.Build();
  report(label, maker);
}

static void bySimple(const char* what, const TopoDS_Shape& s, double t)
{
  char label[256];
  snprintf(label, sizeof(label), "BySimple(%s, %+.1f)", what, t);
  BRepOffsetAPI_MakeThickSolid maker;
  maker.MakeThickSolidBySimple(s, t);
  maker.Build();
  report(label, maker);
}

// OCCT's own HollowBox argument set, GTests/BRepOffsetAPI_MakeThickSolid_Test.cxx:46.
static void byJoinOneFaceRemoved(const char* what, const TopoDS_Shape& s, double t)
{
  char label[256];
  snprintf(label, sizeof(label), "ByJoin(%s, 1 face removed, %+.1f)", what, t);
  TopExp_Explorer exp(s, TopAbs_FACE);
  if (!exp.More())
    return;
  TopTools_ListOfShape remove;
  remove.Append(exp.Current());
  BRepOffsetAPI_MakeThickSolid maker;
  maker.MakeThickSolidByJoin(s, remove, t, Precision::Confusion());
  maker.Build();
  report(label, maker);
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(20.0, 20.0, 20.0).Shape();
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(10.0, 20.0).Shape();
  TopoDS_Shape sph = BRepPrimAPI_MakeSphere(10.0).Shape();

  printf("closed box(20) volume=%.6f cylinder(r10,h20)=%.6f sphere(r10)=%.6f\n",
         volumeOf(box),
         volumeOf(cyl),
         volumeOf(sph));

  printf("\n--- what the bridge does today: MakeThickSolidBySimple on a closed solid ---\n");
  for (double t : {2.0, -2.0, 0.1, -0.1})
  {
    bySimple("closed box", box, t);
    bySimple("closed cylinder", cyl, t);
    bySimple("closed sphere", sph, t);
  }

  printf("\n--- what OCCT's own callers do: MakeThickSolidByJoin, empty removal list ---\n");
  for (double t : {2.0, -2.0, 0.1, -0.1})
  {
    byJoinEmpty("closed box", box, t);
    byJoinEmpty("closed cylinder", cyl, t);
    byJoinEmpty("closed sphere", sph, t);
  }

  printf("\n--- the two negative volumes #2739 records ---\n");
  {
    // (a) BySimple on an open face, the only input OCCT's own gtest gives it.
    TopExp_Explorer exp(BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape(), TopAbs_FACE);
    TopoDS_Face     face = TopoDS::Face(exp.Current());
    bySimple("single open face of a 10-box", face, 2.0);
    bySimple("single open face of a 10-box", face, -2.0);
    printf("  (OCCT's own ThickSolidLargerVolume reads this volume through std::abs:\n"
           "   GTests/BRepOffsetAPI_MakeThickSolid_Test.cxx:143)\n");
  }
  {
    // (b) ByJoin with an empty list on a closed solid, #2739's "-13587" observation, next to
    // OCCT's own HollowBox call, which uses a negative offset and one removed face.
    byJoinOneFaceRemoved("closed box", box, -1.0);
    byJoinOneFaceRemoved("closed box", box, 1.0);
  }

  printf("\n--- control: is VolumeProperties simply reporting a signed mass? ---\n");
  {
    TopoDS_Shape rev = box.Reversed();
    printf("box volume=%.6f  box.Reversed() volume=%.6f\n", volumeOf(box), volumeOf(rev));
  }

  printf("\n--- second construction: is ByJoin-with-an-empty-list just Shape.offset(by:)? ---\n");
  for (double t : {2.0, -2.0})
  {
    BRepOffsetAPI_MakeOffsetShape off;
    off.PerformByJoin(box, t, 1.0e-3, BRepOffset_Skin, false, false, GeomAbs_Intersection);
    off.Build();
    if (!off.IsDone())
    {
      printf("MakeOffsetShape::PerformByJoin(closed box, %+.1f) IsDone=0\n", t);
      continue;
    }
    const TopoDS_Shape& r = off.Shape();
    printf("MakeOffsetShape::PerformByJoin(closed box, %+.1f) type=%d solids=%d shells=%d "
           "faces=%d volume=%.6f\n",
           t,
           (int)r.ShapeType(),
           countOf(r, TopAbs_SOLID),
           countOf(r, TopAbs_SHELL),
           countOf(r, TopAbs_FACE),
           volumeOf(r));
  }

  printf("\n--- the domain BySimple does accept: an open shell and a single face ---\n");
  {
    // A 20-box with one face dropped: an open shell, which is what the header says to pass.
    TopoDS_Shell openShell;
    BRep_Builder builder;
    builder.MakeShell(openShell);
    int             kept = 0;
    TopExp_Explorer exp(box, TopAbs_FACE);
    for (; exp.More(); exp.Next())
    {
      if (kept++ == 0)
        continue;
      builder.Add(openShell, exp.Current());
    }
    printf("open shell: faces=%d closed=%d\n",
           countOf(openShell, TopAbs_FACE),
           BRep_Tool::IsClosed(openShell) ? 1 : 0);
    bySimple("open shell (20-box minus one face)", openShell, 2.0);
    bySimple("open shell (20-box minus one face)", openShell, -2.0);
  }

  printf("\n--- would BRep_Tool::IsClosed separate the accepted domain from the refused one? ---\n");
  {
    TopExp_Explorer shellExp(box, TopAbs_SHELL);
    TopoDS_Shape    closedShell = shellExp.Current();
    TopExp_Explorer faceExp(box, TopAbs_FACE);
    TopoDS_Shape    oneFace = faceExp.Current();

    TopoDS_Shell openShell;
    BRep_Builder builder;
    builder.MakeShell(openShell);
    int             kept = 0;
    TopExp_Explorer exp(box, TopAbs_FACE);
    for (; exp.More(); exp.Next())
    {
      if (kept++ == 0)
        continue;
      builder.Add(openShell, exp.Current());
    }

    struct Case
    {
      const char*  name;
      TopoDS_Shape shape;
    };
    Case cases[] = {{"closed solid (box)", box},
                    {"closed shell of that box", closedShell},
                    {"open shell (box minus a face)", openShell},
                    {"single face", oneFace},
                    {"closed solid (cylinder)", cyl},
                    {"closed solid (sphere)", sph}};
    for (const Case& c : cases)
    {
      BRepOffsetAPI_MakeThickSolid maker;
      maker.MakeThickSolidBySimple(c.shape, 2.0);
      maker.Build();
      printf("%-32s type=%d IsClosed=%d  BySimple(+2.0) IsDone=%d\n",
             c.name,
             (int)c.shape.ShapeType(),
             BRep_Tool::IsClosed(c.shape) ? 1 : 0,
             maker.IsDone() ? 1 : 0);
    }
  }
  return 0;
}
