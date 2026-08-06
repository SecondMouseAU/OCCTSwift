// #721 discriminator: does .correctedFrenet's volume divergence from .frenet require an
// internal wire boundary (Wire.helix(turns: n) produces n edges, BRepFill_Edge3DLaw builds an
// independent GeomFill_CorrectedFrenet per edge), or does it appear even on a single edge?
//
// Method: same fixture as the issue (radius=10, wireRadius=1.5, correctly-placed circular
// profile at the spine's own start point/tangent), sweep `turns` across {1, 2, 3, 6} (0, 1, 2, 5
// internal boundaries respectively) at three pitches, and separately instrument
// GeomFill_CorrectedFrenet::D0 directly on ONE edge (turns=1) to see whether the correction
// angle drifts away from zero WITHIN that single edge (no boundary involved at all).
//
// RESULT: no divergence at any turns count tested, at any pitch -- both Frenet and corrected
// Frenet match the textbook volume to ~1e-6 relative. This appears to contradict the issue's own
// reproduction (which used what looked like the same "correctly-placed" construction); see
// occt_721_boundary_probe2.mm and occt_721_boundary_probe3.mm, and this directory's README, for
// how that's resolved: the issue's own profile placement was not actually on the spine.
//
// Build and run (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w -O2 \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/721-frenet-corrected-frenet/occt_721_boundary_probe.mm \
//     -o /tmp/occt_721_boundary_probe
//   /tmp/occt_721_boundary_probe

#include <cmath>
#include <cstdio>
#include <vector>

#include <BRep_Tool.hxx>
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <GProp_GProps.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAbs_CurveType.hxx>
#include <GeomFill_CorrectedFrenet.hxx>
#include <GeomFill_Frenet.hxx>
#include <HelixBRep_BuilderHelix.hxx>
#include <NCollection_Array1.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Vertex.hxx>
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
  dir.Reverse(); // clockwise == false, matches OCCTWireCreateHelix
  gp_Ax3 axis(origin, dir);

  double diameter = radius * 2.0;
  NCollection_Array1<double> pitchArr(1, 1);
  pitchArr.SetValue(1, pitch);
  NCollection_Array1<double> nbTurnsArr(1, 1);
  nbTurnsArr.SetValue(1, turns);

  HelixBRep_BuilderHelix builder;
  builder.SetParameters(axis, diameter, pitchArr, nbTurnsArr);
  builder.Perform();
  if (builder.ErrorStatus() != 0) {
    printf("  !! HelixBRep_BuilderHelix ErrorStatus=%d\n", builder.ErrorStatus());
    return TopoDS_Wire();
  }
  return TopoDS::Wire(builder.Shape());
}

static TopoDS_Wire buildCircleProfile(const gp_Pnt& origin, const gp_Dir& normal, double radius) {
  gp_Ax2 ax2(origin, normal);
  gp_Circ circ(ax2, radius);
  TopoDS_Edge e = BRepBuilderAPI_MakeEdge(circ).Edge();
  return BRepBuilderAPI_MakeWire(e).Wire();
}

static double volumeOf(const TopoDS_Shape& s) {
  GProp_GProps props;
  BRepGProp::VolumeProperties(s, props);
  return props.Mass();
}

// ------------------------------------------------------------------------------------------
// Part 1: volume sweep varying `turns` (hence internal-boundary count) at fixed pitch.
// ------------------------------------------------------------------------------------------
static void sweepTurns(double pitch) {
  const double R = 10.0, wireR = 1.5;
  double turnsList[] = {1.0, 2.0, 3.0, 6.0};
  printf("=== pitch=%g ===\n", pitch);
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

    TopoDS_Vertex v1, v2;
    TopExp::Vertices(spine, v1, v2);
    gp_Pnt startPnt = BRep_Tool::Pnt(v1);
    BRepAdaptor_CompCurve ccStart(spine);
    gp_Pnt p0; gp_Vec t0;
    ccStart.D1(ccStart.FirstParameter(), p0, t0);
    gp_Dir profileNormal(t0);
    TopoDS_Wire profile = buildCircleProfile(startPnt, profileNormal, wireR);

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

// ------------------------------------------------------------------------------------------
// Part 2: does the correction angle drift away from zero WITHIN a single edge (turns=1, one
// full 2*pi turn, no internal boundary at all)? Mimics BRepFill_Edge3DLaw's own construction:
// build a fresh GeomAdaptor_Curve for the edge and drive GeomFill_CorrectedFrenet directly.
// ------------------------------------------------------------------------------------------
static void probeSingleEdgeDrift(double pitch) {
  const double R = 10.0;
  printf("=== single-edge (turns=1) correction-angle drift probe, pitch=%g ===\n", pitch);
  TopoDS_Wire spine = buildHelixWire(R, pitch, 1.0);
  if (spine.IsNull()) { printf("  spine build failed\n"); return; }

  int nEdges = 0;
  BRepTools_WireExplorer wexp;
  TopoDS_Edge e;
  for (wexp.Init(spine); wexp.More(); wexp.Next()) { nEdges++; e = TopoDS::Edge(wexp.Current()); }
  printf("  wire has %d edge(s)\n", nEdges);
  if (nEdges != 1) { printf("  !! expected exactly 1 edge for turns=1, skipping\n"); return; }

  double f, l;
  occ::handle<Geom_Curve> curveGeom = BRep_Tool::Curve(e, f, l);
  TopAbs_Orientation orient = e.Orientation();
  occ::handle<Geom_Curve> curveForAdaptor = curveGeom;
  double ff = f, ll = l;
  if (orient == TopAbs_REVERSED) {
    occ::handle<Geom_TrimmedCurve> rev = new Geom_TrimmedCurve(curveGeom, f, l);
    rev->Reverse();
    curveForAdaptor = rev;
    ff = curveForAdaptor->FirstParameter();
    ll = curveForAdaptor->LastParameter();
  }
  occ::handle<GeomAdaptor_Curve> adaptor = new GeomAdaptor_Curve(curveForAdaptor, ff, ll);
  printf("  edge param range [%.6f, %.6f]\n", ff, ll);

  GeomFill_Frenet frenet;
  frenet.SetCurve(adaptor);
  GeomFill_CorrectedFrenet corrected;
  bool isFrenetFlag = corrected.SetCurve(adaptor);
  printf("  GeomFill_CorrectedFrenet::SetCurve returned isFrenet=%d (true means NO correction "
         "will ever be applied by D0 -- it degenerates to plain Frenet)\n", isFrenetFlag);

  int nSamples = 21;
  for (int i = 0; i < nSamples; ++i) {
    double u = ff + (ll - ff) * (double)i / (nSamples - 1);
    gp_Vec T, N, B;
    frenet.D0(u, T, N, B);
    gp_Vec Tc, Nc, Bc;
    corrected.D0(u, Tc, Nc, Bc);
    // Angle between the plain-Frenet normal and the corrected normal at the SAME parameter:
    // this is exactly the extra rotation GeomFill_CorrectedFrenet::D0 applies around T.
    double dotNNc = N.Normalized().Dot(Nc.Normalized());
    dotNNc = std::max(-1.0, std::min(1.0, dotNNc));
    double angleDeg = std::acos(dotNNc) * 180.0 / M_PI;
    // signed: project the rotation onto T to get a sign
    gp_Vec cross = N.Crossed(Nc);
    double sign = cross.Dot(T) < 0 ? -1.0 : 1.0;
    printf("    u=%.4f (frac=%.3f)  angle(N_frenet, N_corrected) = %+8.4f deg\n", u,
           (u - ff) / (ll - ff), sign * angleDeg);
  }
  printf("\n");
}

int main() {
  sweepTurns(4.0);
  sweepTurns(12.0);
  sweepTurns(30.0);
  probeSingleEdgeDrift(4.0);
  probeSingleEdgeDrift(12.0);
  probeSingleEdgeDrift(30.0);
  return 0;
}
