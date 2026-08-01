// Ground truth probe for OCCTSwift#532:
// BRepFeat_MakeCylindricalHole's part-selection modes drive BRepFeat_Builder with the WRONG
// operation, so the list they select from is the cut result rather than the split tool.
//
// Every mode that selects parts (PerformThruNext, PerformUntilEnd, the ranged Perform,
// PerformBlind) does:
//
//     SetOperation(Fuse);        // -> BOPAlgo_CUT
//     BOPAlgo_BOP::Perform();    // myShape := object CUT tool
//     PartsOfTool(parts);        // explores myShape for SOLIDs
//     ... KeepPart(chosen) ...
//
// but PartsOfTool() is only meaningful after the COMMON pass. BRepFeat_Form (:806) and
// BRepFeat_RibSlot (:224) — the kernel's other two users of the same builder — both call the
// two-argument SetOperation(myFuse, bFlag) with bFlag true so that myShape holds the tool split
// by the object. BRepFeat_MakeCylindricalHole calls the one-argument overload at all five sites.
//
// This probe prints, for each request, what PartsOfTool() actually hands the selection loop, and
// what the operation then removes. Compile it once against the stock archive and once with a
// patched BRepFeat_MakeCylindricalHole.cxx override-linked in front, and diff.
//
// A "boolean" column (BRepPrimAPI_MakeCylinder + BRepAlgoAPI_Cut, the same recipe as OCCTSwift's
// Shape.drilled) gives the expected answer where the mode's own contract says it should agree.

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepFeat_MakeCylindricalHole.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepBndLib.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <Bnd_Box.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Compound.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <Geom_Curve.hxx>
#include <ElCLib.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Pnt.hxx>
#include <gp_Dir.hxx>
#include <LocOpe_CurveShapeIntersector.hxx>
#include <LocOpe_PntFace.hxx>
#include <NCollection_List.hxx>
#include <Standard_Failure.hxx>

#include <cmath>
#include <cstdio>
#include <string>
#include <vector>

// ---- helpers ----------------------------------------------------------------

static double volumeOf(const TopoDS_Shape& s) {
  if (s.IsNull()) return -1;
  GProp_GProps props;
  BRepGProp::VolumeProperties(s, props);
  return props.Mass();
}

static int countOf(const TopoDS_Shape& s, TopAbs_ShapeEnum t) {
  if (s.IsNull()) return -1;
  int n = 0;
  for (TopExp_Explorer e(s, t); e.More(); e.Next()) n++;
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

// Verbatim copy of the file-local Baryc() the kernel's own selection loops use, so the parameters
// printed here are the ones those loops compare.
static void Baryc(const TopoDS_Shape& S, gp_Pnt& B) {
  TopExp_Explorer exp(S, TopAbs_EDGE);
  gp_XYZ Bar(0., 0., 0.);
  TopLoc_Location L;
  occ::handle<Geom_Curve> C;
  double prm, First, Last;
  int i, nbp = 0;
  for (; exp.More(); exp.Next()) {
    const TopoDS_Edge& E = TopoDS::Edge(exp.Current());
    if (!BRep_Tool::Degenerated(E)) {
      C = BRep_Tool::Curve(E, L, First, Last);
      if (C.IsNull()) continue;
      C = occ::down_cast<Geom_Curve>(C->Transformed(L.Transformation()));
      for (i = 1; i <= 11; i++) {
        prm = ((11 - i) * First + (i - 1) * Last) / 10.;
        Bar += C->Value(prm).XYZ();
        nbp++;
      }
    }
  }
  if (nbp == 0) { B.SetXYZ(gp_XYZ(0,0,0)); return; }
  Bar.Divide((double)nbp);
  B.SetXYZ(Bar);
}

// The same recipe as OCCTSwift's Shape.drilled: a finite cylinder, cut away.
static double booleanRemoved(const TopoDS_Shape& shape, gp_Pnt pos, gp_Dir dir, double radius) {
  try {
    Bnd_Box b; BRepBndLib::Add(shape, b);
    double x0,y0,z0,x1,y1,z1; b.Get(x0,y0,z0,x1,y1,z1);
    double diag = std::sqrt((x1-x0)*(x1-x0)+(y1-y0)*(y1-y0)+(z1-z0)*(z1-z0));
    BRepPrimAPI_MakeCylinder mk(gp_Ax2(pos, dir), radius, diag * 2);
    BRepAlgoAPI_Cut cut(shape, mk.Shape());
    if (!cut.IsDone()) return -1;
    return volumeOf(shape) - volumeOf(cut.Shape());
  } catch (...) { return -1; }
}

// ---- the stock under test ---------------------------------------------------

static TopoDS_Shape plate() {   // axis params 5..25
  return BRepPrimAPI_MakeBox(gp_Pnt(-25,-25,-10), 50, 50, 20).Shape();
}

static TopoDS_Shape twoPlateStack() {   // A 5..25, B 45..65
  TopoDS_Shape a = BRepPrimAPI_MakeBox(gp_Pnt(-25,-25,-10), 50, 50, 20).Shape();
  TopoDS_Shape b = BRepPrimAPI_MakeBox(gp_Pnt(-25,-25,-50), 50, 50, 20).Shape();
  TopoDS_Compound c; BRep_Builder bb; bb.MakeCompound(c);
  bb.Add(c, a); bb.Add(c, b);
  return c;
}

static TopoDS_Shape threePlateStack() {   // 5..25, 45..65, 85..105
  TopoDS_Compound c; BRep_Builder bb; bb.MakeCompound(c);
  bb.Add(c, BRepPrimAPI_MakeBox(gp_Pnt(-25,-25,-10),  50, 50, 20).Shape());
  bb.Add(c, BRepPrimAPI_MakeBox(gp_Pnt(-25,-25,-50),  50, 50, 20).Shape());
  bb.Add(c, BRepPrimAPI_MakeBox(gp_Pnt(-25,-25,-90),  50, 50, 20).Shape());
  return c;
}

// ONE solid, two spans of material on the axis: a channel whose web is cut away, so the drill
// passes through the top flange, the void, then the bottom flange. Not a compound — this is the
// case where "more than one body on the axis" and "one solid" are both true.
static TopoDS_Shape channelOneSolid() {
  TopoDS_Shape outer = BRepPrimAPI_MakeBox(gp_Pnt(-25,-25,-50), 50, 50, 60).Shape();  // z[-50,10]
  TopoDS_Shape slot  = BRepPrimAPI_MakeBox(gp_Pnt(-15,-25,-30), 30, 50, 20).Shape();  // z[-30,-10]
  BRepAlgoAPI_Cut cut(outer, slot);
  return cut.Shape();
}

// ONE solid the bore SEVERS: a bar narrower than the hole. Before the fix this is the single-body
// case that did reach the nbparts >= 2 branch, because the CUT result has two solids.
static TopoDS_Shape narrowBar() {
  return BRepPrimAPI_MakeBox(gp_Pnt(-4,-25,-10), 8, 50, 20).Shape();   // 8 wide, r=5 severs it
}

// ONE solid, four crossings: a hollow box. The drill passes through the top wall, the cavity and
// the bottom wall, so the tool splits into two parts under COMMON.
static TopoDS_Shape hollowBox() {
  TopoDS_Shape outer = BRepPrimAPI_MakeBox(gp_Pnt(-25,-25,-25), 50, 50, 50).Shape();  // z[-25,25]
  TopoDS_Shape inner = BRepPrimAPI_MakeBox(gp_Pnt(-20,-20,-20), 40, 40, 40).Shape();  // z[-20,20]
  BRepAlgoAPI_Cut cut(outer, inner);
  return cut.Shape();
}

// ---- the probe --------------------------------------------------------------

enum Mode { THROUGH_ALL, UNTIL_END, THRU_NEXT, BLIND, RANGE };

static const char* modeName(Mode m) {
  switch (m) {
    case THROUGH_ALL: return "Perform(R)      ";
    case UNTIL_END:   return "PerformUntilEnd ";
    case THRU_NEXT:   return "PerformThruNext ";
    case BLIND:       return "PerformBlind    ";
    case RANGE:       return "Perform(R,Pf,Pt)";
  }
  return "?";
}

static void run(const TopoDS_Shape& stock, const char* stockName,
                gp_Pnt origin, gp_Dir dir, double radius,
                Mode mode, double p0, double p1, bool showParts) {
  double v0 = volumeOf(stock);
  gp_Ax1 axis(origin, dir);

  char req[128];
  if (mode == RANGE)      snprintf(req, sizeof(req), "%s [%.0f,%.0f]", modeName(mode), p0, p1);
  else if (mode == BLIND) snprintf(req, sizeof(req), "%s len=%.0f", modeName(mode), p0);
  else                    snprintf(req, sizeof(req), "%s", modeName(mode));

  try {
    BRepFeat_MakeCylindricalHole hole;
    hole.Init(stock, axis);
    switch (mode) {
      case THROUGH_ALL: hole.Perform(radius); break;
      case UNTIL_END:   hole.PerformUntilEnd(radius); break;
      case THRU_NEXT:   hole.PerformThruNext(radius); break;
      case BLIND:       hole.PerformBlind(radius, p0); break;
      case RANGE:       hole.Perform(radius, p0, p1); break;
    }
    if (hole.Status() != BRepFeat_NoError) {
      printf("  %-24s %-18s\n", req, statusName(hole.Status()));
      return;
    }

    NCollection_List<TopoDS_Shape> parts;
    hole.PartsOfTool(parts);
    int nbparts = (int)parts.Size();

    hole.Build();
    TopoDS_Shape out = hole.Shape();
    double removed = out.IsNull() ? -1 : v0 - volumeOf(out);

    printf("  %-24s %-18s nbparts=%d removed=%11.4f  faces %d->%d  solids %d->%d  valid=%s\n",
           req, statusName(hole.Status()), nbparts, removed,
           countOf(stock, TopAbs_FACE), countOf(out, TopAbs_FACE),
           countOf(stock, TopAbs_SOLID), countOf(out, TopAbs_SOLID),
           out.IsNull() ? "null" : (BRepCheck_Analyzer(out).IsValid() ? "yes" : "NO"));

    if (showParts) {
      int idx = 0;
      for (NCollection_List<TopoDS_Shape>::Iterator it(parts); it.More(); it.Next(), idx++) {
        gp_Pnt bar; Baryc(it.Value(), bar);
        printf("      part %d: vol=%11.4f  baryParam=%9.4f  faces=%d\n",
               idx, volumeOf(it.Value()), ElCLib::LineParameter(axis, bar),
               countOf(it.Value(), TopAbs_FACE));
      }
    }
  } catch (const Standard_Failure& f) {
    printf("  %-24s THROW: %s\n", req, f.GetMessageString());
  } catch (...) {
    printf("  %-24s THROW\n", req);
  }
}

static void section(const TopoDS_Shape& stock, const char* name,
                    gp_Pnt origin, gp_Dir dir, double radius,
                    const std::vector<std::pair<double,double>>& ranges,
                    double blindLen, bool showParts) {
  printf("\n=== %s ===\n", name);
  printf("  volume=%.4f  faces=%d  solids=%d   boolean drill removes %.4f\n",
         volumeOf(stock), countOf(stock, TopAbs_FACE), countOf(stock, TopAbs_SOLID),
         booleanRemoved(stock, origin, dir, radius));
  {
    LocOpe_CurveShapeIntersector asi(gp_Ax1(origin, dir), stock);
    printf("  axis crossings:");
    for (int i = 1; i <= asi.NbPoints(); i++)
      printf(" %.2f%s", asi.Point(i).Parameter(),
             asi.Point(i).Orientation() == TopAbs_FORWARD ? "in" : "out");
    printf("\n");
  }
  run(stock, name, origin, dir, radius, THROUGH_ALL, 0, 0, false);
  run(stock, name, origin, dir, radius, UNTIL_END,   0, 0, showParts);
  run(stock, name, origin, dir, radius, THRU_NEXT,   0, 0, false);
  if (blindLen > 0) run(stock, name, origin, dir, radius, BLIND, blindLen, 0, false);
  for (auto& r : ranges) run(stock, name, origin, dir, radius, RANGE, r.first, r.second, false);
}

int main() {
  printf("OCCTSwift#532 — BRepFeat_MakeCylindricalHole part selection\n");
  printf("drill r=5 from (0,0,15) along -Z unless noted; one 20mm bore removes 1570.7963\n");

  const gp_Pnt org(0, 0, 15);
  const gp_Dir dwn(0, 0, -1);

  section(plate(), "one plate (axis 5..25)", org, dwn, 5,
          {{0, 30}, {10, 20}}, 20, false);

  section(twoPlateStack(), "compound: two plates (5..25, 45..65)", org, dwn, 5,
          {{0, 70}, {0, 30}, {30, 70}, {26, 44}}, 20, true);

  section(threePlateStack(), "compound: three plates (5..25, 45..65, 85..105)", org, dwn, 5,
          {{0, 110}, {0, 70}}, 20, true);

  section(channelOneSolid(), "ONE solid, two spans on the axis (channel)", org, dwn, 5,
          {{0, 70}, {0, 30}}, 20, true);

  section(narrowBar(), "ONE solid the bore severs (8mm bar, r=5)", org, dwn, 5,
          {{0, 30}}, 20, true);

  // Origin above the box, so both walls lie at positive axis parameters (5..10 and 50..55) and
  // "every hole after the origin" spans them both.
  section(hollowBox(), "ONE solid, four crossings (hollow box, origin z=30)",
          gp_Pnt(0, 0, 30), dwn, 5, {{0, 60}}, 20, true);

  return 0;
}
