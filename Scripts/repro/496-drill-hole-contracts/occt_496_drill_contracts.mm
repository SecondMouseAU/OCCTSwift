// Ground truth probe for issue #496: does BRepFeat_MakeCylindricalHole actually
// subsume the boolean-subtraction OCCTShapeDrillHole contract?
//
// Contract of OCCTShapeDrillHole(shape, pos, dir, radius, depth):
//   depth > 0  -> cut a cylinder based at `pos`, along `dir`, length `depth`
//   depth <= 0 -> cut a cylinder based at `pos`, along `dir`, length bboxDiag*2
//
// Candidate BRepFeat counterparts:
//   depth > 0  -> PerformBlind(radius, depth)      (length measured from axis origin)
//   depth <= 0 -> PerformUntilEnd(radius)          (every hole after the axis origin)
//   (Perform(radius) is an INFINITE cylinder both ways -- not the same contract)

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepFeat_MakeCylindricalHole.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBndLib.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <Bnd_Box.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Compound.hxx>
#include <TopExp_Explorer.hxx>
#include <BRep_Builder.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Pnt.hxx>
#include <gp_Dir.hxx>
#include <gp_Trsf.hxx>
#include <Standard_Failure.hxx>

#include <cmath>
#include <cstdio>
#include <string>

static double volumeOf(const TopoDS_Shape& s) {
  if (s.IsNull()) return -1;
  GProp_GProps props;
  BRepGProp::VolumeProperties(s, props);
  return props.Mass();
}

static int faceCount(const TopoDS_Shape& s) {
  if (s.IsNull()) return -1;
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next()) n++;
  return n;
}

static const char* statusName(BRepFeat_Status st) {
  switch (st) {
    case BRepFeat_NoError: return "NoError";
    case BRepFeat_InvalidPlacement: return "InvalidPlacement";
    case BRepFeat_HoleTooLong: return "HoleTooLong";
    default: return "?";
  }
}

// ---- the two implementations under comparison -------------------------------

// Faithful replica of OCCTShapeDrillHole (OCCTBridge_Modeling.mm:3444).
static TopoDS_Shape booleanDrill(const TopoDS_Shape& shape,
                                 gp_Pnt pos, gp_Vec dir,
                                 double radius, double depth,
                                 std::string& err) {
  err.clear();
  try {
    double len = dir.Magnitude();
    if (len < 1e-10) { err = "zero direction"; return TopoDS_Shape(); }
    dir.Normalize();
    double actualDepth = depth;
    if (actualDepth <= 0) {
      Bnd_Box b;
      BRepBndLib::Add(shape, b);
      double x0,y0,z0,x1,y1,z1;
      b.Get(x0,y0,z0,x1,y1,z1);
      double diag = std::sqrt((x1-x0)*(x1-x0)+(y1-y0)*(y1-y0)+(z1-z0)*(z1-z0));
      actualDepth = diag * 2;
    }
    gp_Ax2 ax(pos, gp_Dir(dir));
    BRepPrimAPI_MakeCylinder mk(ax, radius, actualDepth);
    TopoDS_Shape cyl = mk.Shape();
    if (cyl.IsNull()) { err = "cylinder null"; return TopoDS_Shape(); }
    BRepAlgoAPI_Cut cut(shape, cyl);
    if (!cut.IsDone()) { err = "cut not done"; return TopoDS_Shape(); }
    return cut.Shape();
  } catch (const Standard_Failure& f) {
    err = std::string("throw: ") + f.GetMessageString();
    return TopoDS_Shape();
  } catch (...) { err = "throw"; return TopoDS_Shape(); }
}

enum FeatMode { M_PERFORM, M_UNTIL_END, M_THRU_NEXT, M_BLIND };

static TopoDS_Shape featDrill(const TopoDS_Shape& shape,
                              gp_Pnt pos, gp_Vec dir,
                              double radius, double depth,
                              FeatMode mode,
                              std::string& err, BRepFeat_Status& outStatus) {
  err.clear();
  outStatus = BRepFeat_NoError;
  try {
    // No zero-direction guard here on purpose: this mirrors the real
    // OCCTBRepFeatCylindricalHole* bodies, which construct gp_Dir raw.
    gp_Ax1 axis(pos, gp_Dir(dir));
    BRepFeat_MakeCylindricalHole hole;
    hole.Init(shape, axis);
    switch (mode) {
      case M_PERFORM:    hole.Perform(radius); break;
      case M_UNTIL_END:  hole.PerformUntilEnd(radius); break;
      case M_THRU_NEXT:  hole.PerformThruNext(radius); break;
      case M_BLIND:      hole.PerformBlind(radius, depth); break;
    }
    outStatus = hole.Status();
    if (outStatus != BRepFeat_NoError) { err = statusName(outStatus); return TopoDS_Shape(); }
    hole.Build();
    return hole.Shape();
  } catch (const Standard_Failure& f) {
    err = std::string("throw: ") + f.GetMessageString();
    return TopoDS_Shape();
  } catch (...) { err = "throw"; return TopoDS_Shape(); }
}

// ---- reporting --------------------------------------------------------------

static void report(const char* label, const TopoDS_Shape& s, const std::string& err) {
  if (!err.empty()) { printf("    %-14s FAIL   (%s)\n", label, err.c_str()); return; }
  if (s.IsNull())   { printf("    %-14s NULL\n", label); return; }
  BRepCheck_Analyzer an(s);
  printf("    %-14s vol=%12.4f faces=%3d valid=%d\n",
         label, volumeOf(s), faceCount(s), an.IsValid() ? 1 : 0);
}

struct Case {
  const char* name;
  TopoDS_Shape shape;
  gp_Pnt pos;
  gp_Vec dir;
  double radius;
  double depth;   // 0 => through
};

static TopoDS_Shape centeredBox(double w, double h, double d) {
  // Matches Shape.box(): centered at origin.
  return BRepPrimAPI_MakeBox(gp_Pnt(-w/2, -h/2, -d/2), w, h, d).Shape();
}

static TopoDS_Shape twoBoxCompound() {
  TopoDS_Shape a = BRepPrimAPI_MakeBox(gp_Pnt(-25,-25,-10), 50, 50, 20).Shape();
  TopoDS_Shape b = BRepPrimAPI_MakeBox(gp_Pnt(-25,-25, 20), 50, 50, 20).Shape();
  TopoDS_Compound c; BRep_Builder bb; bb.MakeCompound(c);
  bb.Add(c, a); bb.Add(c, b);
  return c;
}

static TopoDS_Shape boxShell() {
  TopoDS_Shape solid = centeredBox(50, 50, 20);
  for (TopExp_Explorer e(solid, TopAbs_SHELL); e.More(); e.Next()) return e.Current();
  return TopoDS_Shape();
}

static TopoDS_Shape singleFace() {
  TopoDS_Shape solid = centeredBox(50, 50, 20);
  for (TopExp_Explorer e(solid, TopAbs_FACE); e.More(); e.Next()) return e.Current();
  return TopoDS_Shape();
}

int main() {
  printf("=== #496 probe: boolean drill vs BRepFeat_MakeCylindricalHole ===\n\n");

  Case cases[] = {
    {"A through-hole, entry above top face (DrillingTests.drillThroughHole)",
      centeredBox(50,50,20), gp_Pnt(0,0,15), gp_Vec(0,0,-1), 5, 0},
    {"B blind hole depth 11 from z=11 (DrillingTests.drillHoleIntoBox)",
      centeredBox(50,50,20), gp_Pnt(0,0,11), gp_Vec(0,0,-1), 5, 11},
    {"C non-Z direction, +X through a bar (#272 regression)",
      BRepPrimAPI_MakeBox(gp_Pnt(-100,-30,-8), 200, 60, 16).Shape(),
      gp_Pnt(-101,0,0), gp_Vec(1,0,0), 6.5, 0},
    {"D axis misses the shape entirely",
      centeredBox(50,50,20), gp_Pnt(100,100,15), gp_Vec(0,0,-1), 5, 0},
    {"E blind depth LONGER than the solid (100 into a 20-thick box)",
      centeredBox(50,50,20), gp_Pnt(0,0,11), gp_Vec(0,0,-1), 5, 100},
    {"F entry point INSIDE the solid, drilling down",
      centeredBox(50,50,20), gp_Pnt(0,0,0), gp_Vec(0,0,-1), 5, 0},
    {"G radius larger than the shape",
      centeredBox(50,50,20), gp_Pnt(0,0,15), gp_Vec(0,0,-1), 100, 0},
    {"H compound of two stacked solids, drill through both",
      twoBoxCompound(), gp_Pnt(0,0,45), gp_Vec(0,0,-1), 5, 0},
    {"I input is a SHELL, not a solid",
      boxShell(), gp_Pnt(0,0,15), gp_Vec(0,0,-1), 5, 0},
    {"J input is a single FACE",
      singleFace(), gp_Pnt(0,0,15), gp_Vec(0,0,-1), 5, 0},
    {"K oblique direction through a sphere",
      BRepPrimAPI_MakeSphere(gp_Pnt(0,0,0), 30).Shape(),
      gp_Pnt(-40,-40,-40), gp_Vec(1,1,1), 4, 0},
    {"L entry exactly ON the surface (z=10, the top face)",
      centeredBox(50,50,20), gp_Pnt(0,0,10), gp_Vec(0,0,-1), 5, 0},
    {"M axis tangent to a corner edge (existing BRepFeat suite's placement)",
      centeredBox(20,20,20), gp_Pnt(10,10,-20), gp_Vec(0,0,1), 3, 0},
  };

  for (const Case& c : cases) {
    printf("%s\n", c.name);
    printf("    %-14s vol=%12.4f faces=%3d\n", "input", volumeOf(c.shape), faceCount(c.shape));

    std::string err; BRepFeat_Status st;
    TopoDS_Shape r;

    r = booleanDrill(c.shape, c.pos, c.dir, c.radius, c.depth, err);
    report("boolean", r, err);

    r = featDrill(c.shape, c.pos, c.dir, c.radius, c.depth, M_PERFORM, err, st);
    report("feat:Perform", r, err);

    r = featDrill(c.shape, c.pos, c.dir, c.radius, c.depth, M_UNTIL_END, err, st);
    report("feat:UntilEnd", r, err);

    r = featDrill(c.shape, c.pos, c.dir, c.radius, c.depth, M_THRU_NEXT, err, st);
    report("feat:ThruNext", r, err);

    if (c.depth > 0) {
      r = featDrill(c.shape, c.pos, c.dir, c.radius, c.depth, M_BLIND, err, st);
      report("feat:Blind", r, err);
    }
    printf("\n");
  }

  // Does Status() alone (no Build) tell us anything the boolean path can't?
  printf("=== status-only probe (what OCCTBRepFeatCylindricalHoleStatus reports) ===\n");
  struct { const char* n; gp_Pnt p; double r; } sc[] = {
    {"on-axis, fits",     gp_Pnt(0,0,15), 5},
    {"misses the solid",  gp_Pnt(100,100,15), 5},
    {"radius too large",  gp_Pnt(0,0,15), 100},
  };
  TopoDS_Shape box = centeredBox(50,50,20);
  for (auto& s : sc) {
    std::string err; BRepFeat_Status st;
    featDrill(box, s.p, gp_Vec(0,0,-1), s.r, 0, M_PERFORM, err, st);
    printf("    %-20s Perform   -> %s\n", s.n, statusName(st));
    featDrill(box, s.p, gp_Vec(0,0,-1), s.r, 0, M_UNTIL_END, err, st);
    printf("    %-20s UntilEnd  -> %s\n", s.n, statusName(st));
    featDrill(box, s.p, gp_Vec(0,0,-1), s.r, 10, M_BLIND, err, st);
    printf("    %-20s Blind(10) -> %s\n", s.n, statusName(st));
  }

  // What does Perform(R, PFrom, PTo) actually bound? Origin (0,0,15) along -Z over a plate
  // z in [-10,10]: the stock occupies axis parameters 5..25, and a full bore removes 1570.796.
  printf("\n=== ranged Perform(R, PFrom, PTo): which parameters bound the hole? ===\n");
  {
    TopoDS_Shape plate = centeredBox(50, 50, 20);
    double full = volumeOf(plate);
    struct { double from, to; } ranges[] = {
      {0, 100}, {5, 25}, {5, 15}, {15, 25}, {0, 15}, {10, 20}, {-100, 100}, {0, 5}, {25, 100},
    };
    for (auto& r : ranges) {
      std::string err; BRepFeat_Status st;
      TopoDS_Shape out;
      try {
        gp_Ax1 axis(gp_Pnt(0,0,15), gp_Dir(0,0,-1));
        BRepFeat_MakeCylindricalHole hole;
        hole.Init(plate, axis);
        hole.Perform(5, r.from, r.to);
        st = hole.Status();
        if (st != BRepFeat_NoError) { err = statusName(st); }
        else { hole.Build(); out = hole.Shape(); }
      } catch (...) { err = "throw"; }
      if (!err.empty()) { printf("    [%7.1f,%7.1f] FAIL (%s)\n", r.from, r.to, err.c_str()); continue; }
      printf("    [%7.1f,%7.1f] removed=%10.4f  (full bore = 1570.7963)\n",
             r.from, r.to, full - volumeOf(out));
    }
  }

  // Same question against a stack with TWO face pairs on the axis: plate A occupies axis
  // parameters 5..25, plate B 45..65 (origin (0,0,15) along -Z; A is z[-10,10], B is z[-50,-30]).
  printf("\n=== ranged Perform over a stack of two plates (A: 5..25, B: 45..65) ===\n");
  {
    TopoDS_Shape a = BRepPrimAPI_MakeBox(gp_Pnt(-25,-25,-10), 50, 50, 20).Shape();
    TopoDS_Shape b = BRepPrimAPI_MakeBox(gp_Pnt(-25,-25,-50), 50, 50, 20).Shape();
    TopoDS_Compound stack; BRep_Builder bb; bb.MakeCompound(stack);
    bb.Add(stack, a); bb.Add(stack, b);
    double full = volumeOf(stack);
    struct { const char* n; double from, to; } ranges[] = {
      {"A only",        0,  30},
      {"B only",       30,  70},
      {"both",          0,  70},
      {"inside A",     10,  20},
      {"the gap",      26,  44},
    };
    for (auto& r : ranges) {
      std::string err; TopoDS_Shape out;
      try {
        gp_Ax1 axis(gp_Pnt(0,0,15), gp_Dir(0,0,-1));
        BRepFeat_MakeCylindricalHole hole;
        hole.Init(stack, axis);
        hole.Perform(5, r.from, r.to);
        if (hole.Status() != BRepFeat_NoError) { err = statusName(hole.Status()); }
        else { hole.Build(); out = hole.Shape(); }
      } catch (...) { err = "throw"; }
      if (!err.empty()) { printf("    %-10s [%5.1f,%5.1f] FAIL (%s)\n", r.n, r.from, r.to, err.c_str()); continue; }
      printf("    %-10s [%5.1f,%5.1f] removed=%10.4f  (one plate's bore = 1570.7963)\n",
             r.n, r.from, r.to, full - volumeOf(out));
    }
  }

  printf("\n=== radius precondition (the pinned kernel is a Release build: No_Exception) ===\n");
  for (double r : {0.0, -5.0, 1e-14}) {
    std::string err; BRepFeat_Status st;
    TopoDS_Shape rb = booleanDrill(box, gp_Pnt(0,0,15), gp_Vec(0,0,-1), r, 0, err);
    printf("    r=%-8g boolean  : %s\n", r,
           err.empty() ? (rb.IsNull() ? "null" : "SHAPE RETURNED") : err.c_str());
    for (auto m : {M_PERFORM, M_UNTIL_END, M_THRU_NEXT}) {
      TopoDS_Shape rf = featDrill(box, gp_Pnt(0,0,15), gp_Vec(0,0,-1), r, 0, m, err, st);
      const char* mn = (m == M_PERFORM) ? "Perform " : (m == M_UNTIL_END) ? "UntilEnd" : "ThruNext";
      if (!err.empty()) { printf("    r=%-8g feat:%s: %s\n", r, mn, err.c_str()); continue; }
      printf("    r=%-8g feat:%s: status=%s vol=%.4f faces=%d  <-- %s\n", r, mn,
             statusName(st), volumeOf(rf), faceCount(rf),
             std::abs(volumeOf(rf) - volumeOf(box)) < 1e-9 ? "NO MATERIAL REMOVED" : "cut");
    }
    TopoDS_Shape rbl = featDrill(box, gp_Pnt(0,0,15), gp_Vec(0,0,-1), r, 10, M_BLIND, err, st);
    printf("    r=%-8g feat:Blind   : %s\n", r,
           err.empty() ? (rbl.IsNull() ? "null" : "SHAPE RETURNED") : err.c_str());
  }

  printf("\n=== zero-direction handling ===\n");
  {
    std::string err; BRepFeat_Status st;
    booleanDrill(box, gp_Pnt(0,0,15), gp_Vec(0,0,0), 5, 0, err);
    printf("    boolean : %s\n", err.empty() ? "(no error!)" : err.c_str());
    featDrill(box, gp_Pnt(0,0,15), gp_Vec(0,0,0), 5, 0, M_PERFORM, err, st);
    printf("    feat    : %s\n", err.empty() ? "(no error!)" : err.c_str());
  }

  printf("\nDONE\n");
  return 0;
}
