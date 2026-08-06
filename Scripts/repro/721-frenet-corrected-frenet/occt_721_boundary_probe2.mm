// #721 discriminator, take 2: the first attempt (occt_721_boundary_probe.mm) used a profile
// normal MEASURED from the actual spine (BRepAdaptor_CompCurve::D1 at FirstParameter) and found
// NO divergence at turns in {1,2,3,6}. That contradicts the shipped, currently-passing test
// Issue598PipeShellFrenetModeTests.cookbookSpringRecipeVolumeInvariant (r=10, pitch=4, turns=5,
// wireRadius=1.5), confirmed via `swift test` to measure .correctedFrenet ~12% high. Isolated
// the difference to the profile's normal being ANALYTIC (normalize(0, r, pitch/2pi)) rather than
// measured off the wire -- reproduced 1.1215 with the analytic normal at turns=5. This probe
// holds the analytic-normal construction fixed and sweeps `turns` densely to find out what
// actually predicts the divergence.
//
// Build and run (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w -O2 \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/721-frenet-corrected-frenet/occt_721_boundary_probe2.mm \
//     -o /tmp/occt_721_boundary_probe2
//   /tmp/occt_721_boundary_probe2

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

static void sweepTurns(double pitch) {
  const double R = 10.0, wireR = 1.5;
  double turnsList[] = {1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 7.0, 8.0};
  printf("=== pitch=%g (analytic-normal profile, matching the confirmed-passing test) ===\n", pitch);
  printf("%6s %6s %12s %12s %8s %12s %8s\n", "turns", "edges", "textbook", "frenet", "ratio",
         "corrFrenet", "ratio");
  for (double turns : turnsList) {
    TopoDS_Wire spine = buildHelixWire(R, pitch, turns);
    if (spine.IsNull()) { printf("turns=%g: spine build failed\n", turns); continue; }

    int nEdges = 0;
    BRepTools_WireExplorer wexp;
    for (wexp.Init(spine); wexp.More(); wexp.Next()) nEdges++;

    double c = pitch / (2.0 * M_PI);
    double lenAnalytic = turns * 2.0 * M_PI * std::sqrt(R * R + c * c);
    double textbook = M_PI * wireR * wireR * lenAnalytic;

    // Analytic profile placement: origin (R,0,0), normal = normalize(0, R, pitch/2pi).
    gp_Pnt origin(R, 0, 0);
    gp_Vec nvec(0, R, c);
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

    printf("%6g %6d %12.4f %12.4f %8.4f %12.4f %8.4f   [doneF=%d doneC=%d]\n", turns, nEdges,
           textbook, vFrenet, doneF ? vFrenet / textbook : -1.0, vCorrected,
           doneC ? vCorrected / textbook : -1.0, doneF, doneC);
  }
  printf("\n");
}

int main() {
  sweepTurns(4.0);
  sweepTurns(12.0);
  return 0;
}
