// #721: Frenet and corrected-Frenet pipe sweeps disagree by up to 27% on a rotationally
// symmetric (circular) profile, where the two trihedron laws should agree exactly (they differ
// only by a rotation about the tangent, a symmetry of a circular section).
//
// This probe:
//   1. Reproduces the reported volumes (BRepOffsetAPI_MakePipeShell, SetMode(true/false)) for
//      Wire.helix(radius: 10, pitch: p, turns: 3) swept with a r=1.5 circular profile, exactly
//      matching OCCTWireCreateHelix's construction (HelixBRep_BuilderHelix, axis reversed for
//      the default clockwise=false).
//   2. Dumps the wire's own structure: edge count, curve type/degree, and confirms the wire's
//      OWN length (via BRepAdaptor_CompCurve + a 40000-panel Gauss reference) against the
//      textbook helix length, ruling out #603-class arc-length error as the cause.
//   3. Evaluates GeomFill_Frenet::D0 and GeomFill_CorrectedFrenet::D0 directly on each spine
//      EDGE (mimicking BRepFill_Edge3DLaw, which drives a PER-EDGE GeomAdaptor_Curve, not a
//      composite curve for the whole wire) and reports, at each sample:
//        - Tangent, Normal, BiNormal
//        - T.Dot(N), T.Dot(B), N.Dot(B)      (should be ~0: orthonormality)
//        - N.Dot(axis), B.Dot(axis)          (axis = (0,0,-1), matching the wire's own build
//                                              direction) -- the geometric fact under test:
//          a circular helix's Frenet principal normal is ALWAYS horizontal (N.axis == 0)
//          regardless of pitch, so that alone is not diagnostic. But BiNormal tilts with pitch:
//          B.axis should equal cos(pitchAngle) = R/sqrt(R^2+(pitch/2pi)^2), NOT +-1 constant.
//
// Build and run (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w -O2 \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/721-frenet-corrected-frenet/occt_721_probe.mm -o /tmp/occt_721_probe
//   /tmp/occt_721_probe

#include <cmath>
#include <cstdio>
#include <vector>

#include <BRep_Tool.hxx>
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <GProp_GProps.hxx>
#include <Geom_BSplineCurve.hxx>
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

// ------------------------------------------------------------------------------------------
// Build the same wire OCCTWireCreateHelix builds (OCCTBridge_Modeling.mm), given
// clockwise = false (Wire.helix's own default), axis = (0,0,1), origin = (0,0,0).
// ------------------------------------------------------------------------------------------
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
// Part 1+2: reproduce reported volumes; dump wire structure.
// ------------------------------------------------------------------------------------------
static void reproduceVolumes() {
  printf("=== Part 1: volume reproduction (radius=10, turns=3, wireRadius=1.5) ===\n");
  printf("%6s %12s %12s %8s %12s %8s\n", "pitch", "textbook", "frenet", "ratio", "corrFrenet", "ratio");

  const double R = 10.0, turns = 3.0, wireR = 1.5;
  double pitches[] = {1.0, 4.0, 12.0, 30.0};

  for (double pitch : pitches) {
    TopoDS_Wire spine = buildHelixWire(R, pitch, turns);
    if (spine.IsNull()) { printf("pitch=%g: spine build failed\n", pitch); continue; }

    // Structure dump
    int nEdges = 0;
    BRepTools_WireExplorer wexp;
    for (wexp.Init(spine); wexp.More(); wexp.Next()) nEdges++;
    printf("  [pitch=%g] wire has %d edges\n", pitch, nEdges);

    int idx = 0;
    for (wexp.Init(spine); wexp.More(); wexp.Next()) {
      idx++;
      TopoDS_Edge e = TopoDS::Edge(wexp.Current());
      double f, l;
      occ::handle<Geom_Curve> c = BRep_Tool::Curve(e, f, l);
      GeomAdaptor_Curve ac(c, f, l);
      const char* typeName = "?";
      switch (ac.GetType()) {
        case GeomAbs_Line: typeName = "Line"; break;
        case GeomAbs_Circle: typeName = "Circle"; break;
        case GeomAbs_BSplineCurve: typeName = "BSpline"; break;
        case GeomAbs_BezierCurve: typeName = "Bezier"; break;
        default: typeName = "Other"; break;
      }
      int degree = -1, nbPoles = -1, nbKnots = -1;
      if (ac.GetType() == GeomAbs_BSplineCurve) {
        occ::handle<Geom_BSplineCurve> bs = ac.BSpline();
        degree = bs->Degree();
        nbPoles = bs->NbPoles();
        nbKnots = bs->NbKnots();
      }
      printf("    edge %d: type=%s degree=%d poles=%d knots=%d range=[%.6f,%.6f] orient=%s\n",
             idx, typeName, degree, nbPoles, nbKnots, f, l,
             e.Orientation() == TopAbs_FORWARD ? "FWD" : "REV");
    }

    // Wire length via BRepAdaptor_CompCurve (already #603-fixed at the Swift layer; here we
    // just want a ground-truth check independent of the bridge).
    BRepAdaptor_CompCurve cc(spine);
    // Coarse composite-Simpson length reference (not the adaptive #603 algorithm -- just an
    // independent numerical check).
    int N = 200000;
    double u0 = cc.FirstParameter(), u1 = cc.LastParameter();
    double h = (u1 - u0) / N;
    double lenRef = 0;
    gp_Pnt p; gp_Vec d1;
    for (int i = 0; i <= N; ++i) {
      double u = u0 + i * h;
      cc.D1(u, p, d1);
      double w = (i == 0 || i == N) ? 0.5 : 1.0;
      lenRef += w * d1.Magnitude();
    }
    lenRef *= h;
    double c = pitch / (2.0 * M_PI);
    double lenAnalytic = turns * 2.0 * M_PI * std::sqrt(R * R + c * c);
    printf("  [pitch=%g] length: refIntegral=%.6f analytic=%.6f (diff %.2e)\n",
           pitch, lenRef, lenAnalytic, lenRef - lenAnalytic);

    double textbook = M_PI * wireR * wireR * lenAnalytic;

    // Profile: circle at the helix start point/tangent (matching
    // Issue598PipeShellFrenetModeTests.cookbookSpringRecipeVolumeInvariant's construction, but
    // adapted to this axis convention: axis dir = (0,0,-1)).
    TopoDS_Vertex v1, v2;
    TopExp::Vertices(spine, v1, v2);
    gp_Pnt startPnt = BRep_Tool::Pnt(v1);
    BRepAdaptor_CompCurve ccStart(spine);
    gp_Pnt p0; gp_Vec t0;
    ccStart.D1(ccStart.FirstParameter(), p0, t0);
    gp_Dir profileNormal(t0);
    TopoDS_Wire profile = buildCircleProfile(startPnt, profileNormal, wireR);

    double vFrenet = 0, vCorrected = 0;
    {
      BRepOffsetAPI_MakePipeShell mkPipe(spine);
      mkPipe.SetMode(true); // Frenet
      mkPipe.Add(profile);
      mkPipe.Build();
      if (mkPipe.IsDone()) {
        mkPipe.MakeSolid();
        vFrenet = volumeOf(mkPipe.Shape());
      } else {
        printf("  [pitch=%g] Frenet sweep NOT done\n", pitch);
      }
    }
    {
      BRepOffsetAPI_MakePipeShell mkPipe(spine);
      mkPipe.SetMode(false); // Corrected Frenet
      mkPipe.Add(profile);
      mkPipe.Build();
      if (mkPipe.IsDone()) {
        mkPipe.MakeSolid();
        vCorrected = volumeOf(mkPipe.Shape());
      } else {
        printf("  [pitch=%g] CorrectedFrenet sweep NOT done\n", pitch);
      }
    }

    double flatLen = turns * 2.0 * M_PI * R;
    double flatVolumePrediction = M_PI * wireR * wireR * flatLen;
    double cosPitchAngle = R / std::sqrt(R * R + c * c);

    printf("%6g %12.4f %12.4f %8.4f %12.4f %8.4f   [flat-circle predicts frenet=%.4f, ratio=%.4f]\n",
           pitch, textbook, vFrenet, vFrenet / textbook, vCorrected, vCorrected / textbook,
           flatVolumePrediction, cosPitchAngle);
  }
  printf("\n");
}

// ------------------------------------------------------------------------------------------
// Part 3: direct trihedron perpendicularity/orientation probe, per-edge (matching
// BRepFill_Edge3DLaw's own per-edge GeomAdaptor_Curve construction).
// ------------------------------------------------------------------------------------------
static void probeTrihedron(double pitch) {
  const double R = 10.0, turns = 3.0;
  printf("=== Part 3: trihedron probe, pitch=%g ===\n", pitch);
  TopoDS_Wire spine = buildHelixWire(R, pitch, turns);
  if (spine.IsNull()) { printf("  spine build failed\n"); return; }

  double c = pitch / (2.0 * M_PI);
  double L = std::sqrt(R * R + c * c);
  double expectedBz = R / L; // cos(pitch angle): what a CORRECT tilted binormal should show
  printf("  R=%g pitch=%g -> c=%g L=%g  expected correct B.axis = cos(pitchAngle) = %.6f\n",
         R, pitch, c, L, expectedBz);
  printf("  (a WRONG, pitch-blind frame would show B.axis constant ~ +-1 regardless of pitch)\n");

  gp_Dir axis(0, 0, -1); // matches buildHelixWire's axis direction

  int edgeIdx = 0;
  BRepTools_WireExplorer wexp;
  for (wexp.Init(spine); wexp.More(); wexp.Next()) {
    edgeIdx++;
    TopoDS_Edge e = TopoDS::Edge(wexp.Current());
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

    printf("  -- edge %d (orient=%s, param [%.6f, %.6f]) --\n", edgeIdx,
           orient == TopAbs_FORWARD ? "FWD" : "REV", ff, ll);

    GeomFill_Frenet frenet;
    frenet.SetCurve(adaptor);
    GeomFill_CorrectedFrenet corrected;
    corrected.SetCurve(adaptor);

    int nSamples = 9;
    for (int i = 0; i < nSamples; ++i) {
      double u = ff + (ll - ff) * (double)i / (nSamples - 1);
      gp_Vec T, N, B;
      bool ok = frenet.D0(u, T, N, B);
      gp_Vec Tc, Nc, Bc;
      bool okc = corrected.D0(u, Tc, Nc, Bc);

      double tn = T.Dot(N), tb = T.Dot(B), nb = N.Dot(B);
      double naxis = N.Dot(gp_Vec(axis));
      double baxis = B.Dot(gp_Vec(axis));
      double taxis = T.Dot(gp_Vec(axis));

      double tnC = Tc.Dot(Nc), naxisC = Nc.Dot(gp_Vec(axis)), baxisC = Bc.Dot(gp_Vec(axis));

      printf("    u=%.4f  FRENET ok=%d T=(%.4f,%.4f,%.4f) N.ax=%.4f B.ax=%.4f T.ax=%.4f  "
             "orth[T.N=%.1e T.B=%.1e N.B=%.1e]   ||  CORRECTED ok=%d N.ax=%.4f B.ax=%.4f T.N=%.1e\n",
             u, ok, T.X(), T.Y(), T.Z(), naxis, baxis, taxis, tn, tb, nb,
             okc, naxisC, baxisC, tnC);
    }
  }
  printf("\n");
}

// ------------------------------------------------------------------------------------------
// Part 4: what if the profile is the NAIVE Wire.circle(radius: 1.5) -- centered at the
// GLOBAL origin, flat in the XY plane, exactly as `Wire.circle(radius:)`'s defaults produce,
// with NO manual repositioning onto the spine's own start point/tangent? This is what "a
// circular profile of radius 1.5" reads as if the caller did not do the manual placement the
// shipped Issue598 cookbook test does.
// ------------------------------------------------------------------------------------------
static void reproduceWithNaiveProfile() {
  printf("=== Part 4: naive profile = Wire.circle(radius: 1.5) at ORIGIN, untouched ===\n");
  printf("%6s %12s %12s %8s %12s %8s\n", "pitch", "textbook", "frenet", "ratio", "corrFrenet", "ratio");
  const double R = 10.0, turns = 3.0, wireR = 1.5;
  double pitches[] = {1.0, 4.0, 12.0, 30.0};
  for (double pitch : pitches) {
    TopoDS_Wire spine = buildHelixWire(R, pitch, turns);
    if (spine.IsNull()) { printf("pitch=%g: spine build failed\n", pitch); continue; }

    double c = pitch / (2.0 * M_PI);
    double lenAnalytic = turns * 2.0 * M_PI * std::sqrt(R * R + c * c);
    double textbook = M_PI * wireR * wireR * lenAnalytic;

    // Naive profile: circle of radius 1.5 at the ORIGIN, normal = +Z (Wire.circle's defaults).
    TopoDS_Wire profile = buildCircleProfile(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), wireR);

    double vFrenet = 0, vCorrected = 0;
    bool doneF = false, doneC = false;
    {
      BRepOffsetAPI_MakePipeShell mkPipe(spine);
      mkPipe.SetMode(true);
      mkPipe.Add(profile, Standard_False, Standard_False);
      mkPipe.Build();
      doneF = mkPipe.IsDone();
      if (doneF) { mkPipe.MakeSolid(); vFrenet = volumeOf(mkPipe.Shape()); }
    }
    {
      BRepOffsetAPI_MakePipeShell mkPipe(spine);
      mkPipe.SetMode(false);
      mkPipe.Add(profile, Standard_False, Standard_False);
      mkPipe.Build();
      doneC = mkPipe.IsDone();
      if (doneC) { mkPipe.MakeSolid(); vCorrected = volumeOf(mkPipe.Shape()); }
    }
    printf("%6g %12.4f %12.4f %8.4f %12.4f %8.4f   [doneF=%d doneC=%d]\n",
           pitch, textbook, vFrenet, vFrenet / textbook, vCorrected, vCorrected / textbook,
           doneF, doneC);
  }
  printf("\n");
}

int main() {
  reproduceVolumes();
  reproduceWithNaiveProfile();
  probeTrihedron(4.0);
  probeTrihedron(30.0);
  return 0;
}
