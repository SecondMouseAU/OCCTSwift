// #1990 (epic #766): kernel parity for Tests/OCCTThreadTests/ThreadFormsTests.swift.
//
// The five geometry tests thread a cylinder or annulus through ThreadFeatures.swift: the direct
// external build (Swift composition of OCCTShapeCreateLoftAdvanced ruled=false and OCCTShapeSew)
// or the cut path (a screw-loft cutter from OCCTShapeCreateLoftAdvanced, then
// OCCTShapeSubtractEx). Neither is a single OCCT algorithm a probe can call with the same inputs,
// so this probe does two things:
//
//   Part A: builds each stock (BRepPrimAPI cylinder, and the annulus as a BRepAlgoAPI_Cut of two
//           cylinders) in pure OCCT and reports its volume, the quantity every test compares
//           the threaded result against.
//   Part B: reads each threaded result the Swift run exported as BREP (argv[1] = directory,
//           argv[2..] = names) and re-measures it with the kernel calls the Swift accessors wrap:
//           BRepGProp::VolumeProperties OnlyClosed=true (Shape.volume via OCCTShapeGetVolume)
//           and BRepCheck_Analyzer (Shape.isValid via OCCTShapeIsValid).
//
// The three pure-Swift tests (profile validation, form geometry, parser) have no kernel call.
//
// Build: see CLAUDE.md "Compile a Ground Truth C++ Test" (-I/-L at the resolved xcframework).

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <cmath>
#include <cstdio>
#include <string>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, Standard_True);
  return p.Mass();
}

static int valid(const TopoDS_Shape& s) { return BRepCheck_Analyzer(s).IsValid() ? 1 : 0; }

static int nfaces(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    ++n;
  return n;
}

// Minor diameters the tests bore to, ThreadSpec.minorDiameter = 12 - 2 * cutDepth at P = 2.
static void annulus(const char* form, double cutDepth)
{
  const double minor = 12 - 2 * cutDepth;
  TopoDS_Shape outer = BRepPrimAPI_MakeCylinder(12, 16).Shape();
  TopoDS_Shape bore  = BRepPrimAPI_MakeCylinder(minor / 2, 16).Shape();
  TopoDS_Shape a     = BRepAlgoAPI_Cut(outer, bore).Shape();
  printf("annulus_%-12s minor=%.9f vol=%.9f valid=%d faces=%d\n", form, minor, vol(a), valid(a),
         nfaces(a));
}

int main(int argc, char** argv)
{
  printf("== Part A: stock volumes in pure OCCT ==\n");
  TopoDS_Shape s6  = BRepPrimAPI_MakeCylinder(6, 24).Shape();
  TopoDS_Shape s8  = BRepPrimAPI_MakeCylinder(8, 24).Shape();
  TopoDS_Shape s20 = BRepPrimAPI_MakeCylinder(6, 20).Shape();
  printf("shank6     r6 h24 vol=%.9f\n", vol(s6));
  printf("shank8     r8 h24 vol=%.9f\n", vol(s8));
  printf("shank6h20  r6 h20 vol=%.9f\n", vol(s20));
  const double P = 2.0;
  annulus("iso68", P * std::sqrt(3.0) / 2 * 5 / 8);
  annulus("whitworth", 0.640327 * P);
  annulus("acme", 0.5 * P);
  annulus("square", 0.5 * P);
  annulus("buttress", 0.86777 * P);
  annulus("knuckle", 0.55 * P);

  if (argc > 1)
  {
    printf("== Part B: kernel re-measure of the shapes the Swift run exported ==\n");
    for (int i = 2; i < argc; ++i)
    {
      TopoDS_Shape s;
      BRep_Builder bb;
      std::string  path = std::string(argv[1]) + "/" + argv[i] + ".brep";
      if (!BRepTools::Read(s, path.c_str(), bb))
      {
        printf("%-22s (no file)\n", argv[i]);
        continue;
      }
      printf("%-22s vol=%.9f valid=%d faces=%d\n", argv[i], vol(s), valid(s), nfaces(s));
    }
  }
  return 0;
}
