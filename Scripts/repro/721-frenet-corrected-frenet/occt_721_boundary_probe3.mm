// #721 discriminator, take 3. probe2 showed the shipped-test/issue construction
// (origin=(R,0,0), normal=normalize(0,R,pitch/2pi)) reproduces the divergence, while probe1's
// construction (origin = the wire's OWN start vertex, normal MEASURED via
// BRepAdaptor_CompCurve::D1) shows none. Comparing the two directly: v1 (the real start vertex)
// is (-R,0,0), NOT (R,0,0) -- Wire.helix's clockwise=false reverses the build axis to -Z, so the
// wire's own local "theta=0" lands at global -X, not +X -- and the measured tangent's Z-component
// has the OPPOSITE SIGN from the "textbook" analytic formula's (the spine descends in -Z, the
// formula assumes ascent in +Z). Both the issue's own round-2 measurement and the shipped
// Issue598PipeShellFrenetModeTests.cookbookSpringRecipeVolumeInvariant test use the "textbook"
// formula, i.e. a profile that is NOT positioned on or tangent to the real spine at its start.
//
// This probe isolates which of the two mismatches (origin, or tangent Z-sign) actually drives
// the divergence, by testing all four combinations at a fixed pitch/turns, then sweeping turns
// for whichever variant(s) turn out to matter.
//
// Build and run (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w -O2 \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/721-frenet-corrected-frenet/occt_721_boundary_probe3.mm \
//     -o /tmp/occt_721_boundary_probe3
//   /tmp/occt_721_boundary_probe3

#include <cmath>
#include <cstdio>

#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <GProp_GProps.hxx>
#include <HelixBRep_BuilderHelix.hxx>
#include <NCollection_Array1.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

static TopoDS_Wire buildHelixWire(double radius, double pitch, double turns) {
  gp_Pnt origin(0, 0, 0);
  gp_Dir dir(0, 0, 1);
  dir.Reverse(); // clockwise == false
  gp_Ax3 axis(origin, dir);
  double diameter = radius * 2.0;
  NCollection_Array1<double> pitchArr(1, 1);
  pitchArr.SetValue(1, pitch);
  NCollection_Array1<double> nbTurnsArr(1, 1);
  nbTurnsArr.SetValue(1, turns);
  HelixBRep_BuilderHelix builder;
  builder.SetParameters(axis, diameter, pitchArr, nbTurnsArr);
  builder.Perform();
  if (builder.ErrorStatus() != 0) return TopoDS_Wire();
  return TopoDS::Wire(builder.Shape());
}

static double volumeOf(const TopoDS_Shape& s) {
  GProp_GProps props;
  BRepGProp::VolumeProperties(s, props);
  return props.Mass();
}

static void run(const char* label, double R, double pitch, double turns, double wireR,
                 double originX, double normalY, double normalZ) {
  TopoDS_Wire spine = buildHelixWire(R, pitch, turns);
  if (spine.IsNull()) { printf("%s: spine build failed\n", label); return; }

  double c = pitch / (2.0 * M_PI);
  double lenAnalytic = turns * 2.0 * M_PI * std::sqrt(R * R + c * c);
  double textbook = M_PI * wireR * wireR * lenAnalytic;

  gp_Pnt origin(originX, 0, 0);
  gp_Vec nvec(0, normalY, normalZ);
  gp_Dir normal(nvec);
  gp_Circ circ(gp_Ax2(origin, normal), wireR);
  TopoDS_Edge e = BRepBuilderAPI_MakeEdge(circ).Edge();
  TopoDS_Wire profile = BRepBuilderAPI_MakeWire(e).Wire();

  double vFrenet = 0, vCorrected = 0;
  bool doneF = false, doneC = false;
  {
    BRepOffsetAPI_MakePipeShell mkPipe(spine);
    mkPipe.SetMode(true);
    mkPipe.Add(profile);
    mkPipe.Build();
    doneF = mkPipe.IsDone();
    if (doneF) { mkPipe.MakeSolid(); vFrenet = volumeOf(mkPipe.Shape()); }
  }
  {
    BRepOffsetAPI_MakePipeShell mkPipe(spine);
    mkPipe.SetMode(false);
    mkPipe.Add(profile);
    mkPipe.Build();
    doneC = mkPipe.IsDone();
    if (doneC) { mkPipe.MakeSolid(); vCorrected = volumeOf(mkPipe.Shape()); }
  }
  printf("%-28s origin=(%+5.1f,0,0) normal=(0,%.4f,%+.4f)  frenetRatio=%.4f  corrRatio=%.4f  [doneF=%d doneC=%d]\n",
         label, originX, normalY, normalZ,
         doneF ? vFrenet / textbook : -1.0, doneC ? vCorrected / textbook : -1.0, doneF, doneC);
}

int main() {
  double R = 10.0, wireR = 1.5;
  printf("=== isolating origin vs tangent-sign, pitch=12, turns=3 (issue's own worst case) ===\n");
  {
    double pitch = 12.0, turns = 3.0, c = pitch / (2 * M_PI);
    run("A: textbook (as shipped)", R, pitch, turns, wireR, +R, R, +c);
    run("B: flip normal Z only",     R, pitch, turns, wireR, +R, R, -c);
    run("C: flip origin only",       R, pitch, turns, wireR, -R, R, +c);
    run("D: flip both (= measured)", R, pitch, turns, wireR, -R, R, -c);
  }
  printf("\n=== same isolation, pitch=4, turns=5 (the shipped-test fixture) ===\n");
  {
    double pitch = 4.0, turns = 5.0, c = pitch / (2 * M_PI);
    run("A: textbook (as shipped)", R, pitch, turns, wireR, +R, R, +c);
    run("B: flip normal Z only",     R, pitch, turns, wireR, +R, R, -c);
    run("C: flip origin only",       R, pitch, turns, wireR, -R, R, +c);
    run("D: flip both (= measured)", R, pitch, turns, wireR, -R, R, -c);
  }
  return 0;
}
