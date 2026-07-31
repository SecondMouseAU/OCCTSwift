// #541 ground truth: what a "face index" addresses, on the pinned OCCT 8.0.0p1 kernel.
//
// #502 established that TopExp::MapShapes is a TopExp_Explorer walk piped into an
// IndexedMap, so the map's sequence is the explorer's sequence with later repeats removed.
// #541 is about the consequence for FACE indices specifically, which #502 left alone because
// they are an addressing token the Swift API hands out and takes back.
//
// The bridge answers "which face is index i" three different ways:
//
//   A. explorer walk, 0-based   -- OCCTShapeGetFaces (Shape.faces(), which writes Face.index),
//                                  and 14 face-index consumers
//   B. MapShapes, 0-based       -- OCCTShapeGetFaceCount / GetFaceAtIndex (Shape.faceCount,
//                                  Shape.face(at:)), and ~16 face-index consumers
//   C. MapShapes, 1-based       -- OCCTShapeOffsetPerFace, OCCTLocOpeBuildWires,
//                                  OCCTLocOpeSplitByWireOnFace, the Poly_Connect mesh family,
//                                  and the OCCTEdgeAdjacentFaces / OCCTVertexAdjacentEdges
//                                  index *outputs*
//
// This probe asks the four things the headers cannot answer:
//
//   1. Does the A/B divergence arise from ORDINARY modelling, or only from hand-built
//      topology? #502's face-divergent fixture was a hand-assembled shell of a face and its
//      own reverse. If a compsolid or a glued boolean shares a face, the defect is routine.
//   2. When A and B diverge, from which index onwards do they disagree? An index that only
//      moves past the duplicate is a much narrower break than one that shifts everything.
//   3. Do A and B ever address DIFFERENT faces at an index both accept, or does A merely run
//      longer? These are different defects: silently operating on the wrong face vs.
//      returning nil.
//   4. Is the map's face order the explorer's order for the ordinary shapes the fix has to
//      not disturb, so that converging A onto B moves no index on any shape anyone has?
//
// No fixture files: every case builds its geometry from a primitive.

#include <ShapeAnalysis_ShapeContents.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRep_Builder.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_CompSolid.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>
#include <TopTools_ListOfShape.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <cstdio>
#include <string>
#include <vector>

// ---------------------------------------------------------------------------
// The three addressing schemes, transcribed from the bridge.
// ---------------------------------------------------------------------------

// A: OCCTShapeGetFaces -- a bare explorer walk, one entry per occurrence, 0-based.
static std::vector<TopoDS_Shape> schemeA(const TopoDS_Shape& s) {
    std::vector<TopoDS_Shape> out;
    for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next()) out.push_back(e.Current());
    return out;
}

// B: OCCTShapeGetFaceAtIndex -- occtSubShapeAt, one entry per distinct face, 0-based.
static std::vector<TopoDS_Shape> schemeB(const TopoDS_Shape& s) {
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(s, TopAbs_FACE, m);
    std::vector<TopoDS_Shape> out;
    for (int i = 1; i <= m.Extent(); i++) out.push_back(m(i));
    return out;
}

// C is B shifted by one; it addresses the same set, so it is measured as an offset rather
// than walked separately.

// IsSame ignores orientation; IsEqual does not. Both are reported so "the same face" is
// attributed to a specific bit rather than assumed.
static const char* sameness(const TopoDS_Shape& a, const TopoDS_Shape& b) {
    if (a.IsEqual(b)) return "identical";
    if (a.IsSame(b))  return "same-but-reversed";
    return "DIFFERENT";
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

struct Fixture {
    std::string name;
    std::string provenance;   // "ordinary" = produced by a modelling op, "hand-built" = assembled
    TopoDS_Shape shape;
};

static TopoDS_Shape box(double dx, double dy, double dz, double ox = 0, double oy = 0, double oz = 0) {
    return BRepPrimAPI_MakeBox(gp_Pnt(ox, oy, oz), dx, dy, dz).Shape();
}

static TopoDS_Shape firstFace(const TopoDS_Shape& s) {
    TopExp_Explorer e(s, TopAbs_FACE);
    return e.More() ? e.Current() : TopoDS_Shape();
}

static std::vector<Fixture> buildFixtures() {
    std::vector<Fixture> f;

    // --- Ordinary modelling: no face is reachable twice, so A and B must agree. ---
    f.push_back({"box", "ordinary", box(10, 10, 10)});
    f.push_back({"cylinder", "ordinary", BRepPrimAPI_MakeCylinder(5, 10).Shape()});
    f.push_back({"sphere", "ordinary", BRepPrimAPI_MakeSphere(5).Shape()});
    f.push_back({"torus", "ordinary", BRepPrimAPI_MakeTorus(10, 3).Shape()});

    // A hollow solid: two shells, twelve faces, nothing shared.
    {
        TopoDS_Shape outer = box(20, 20, 20);
        TopoDS_Shape inner = box(8, 8, 8, 6, 6, 6);
        f.push_back({"hollow solid (cut)", "ordinary", BRepAlgoAPI_Cut(outer, inner).Shape()});
    }

    // Booleans of two touching boxes. The interface face is the interesting one: does the
    // result share one face between two solids, or duplicate it?
    {
        TopoDS_Shape a = box(10, 10, 10);
        TopoDS_Shape b = box(10, 10, 10, 10, 0, 0);
        f.push_back({"fuse of two touching boxes", "ordinary", BRepAlgoAPI_Fuse(a, b).Shape()});
        f.push_back({"common of two overlapping boxes", "ordinary",
                     BRepAlgoAPI_Common(box(10, 10, 10), box(10, 10, 10, 5, 0, 0)).Shape()});
    }

    // Two halves cut from a common block and assembled into a compsolid. Each Common ran
    // separately, so the wall is two coincident faces rather than one shared one -- the
    // control for the fixture below.
    {
        TopoDS_Shape whole = box(20, 10, 10);
        TopoDS_Shape left  = BRepAlgoAPI_Common(whole, box(10, 10, 10)).Shape();
        TopoDS_Shape right = BRepAlgoAPI_Common(whole, box(10, 10, 10, 10, 0, 0)).Shape();
        TopoDS_CompSolid cs;
        BRep_Builder bb;
        bb.MakeCompSolid(cs);
        for (TopExp_Explorer e(left, TopAbs_SOLID); e.More(); e.Next())  bb.Add(cs, e.Current());
        for (TopExp_Explorer e(right, TopAbs_SOLID); e.More(); e.Next()) bb.Add(cs, e.Current());
        f.push_back({"compsolid of two separately-cut halves", "ordinary", cs});
    }

    // The real ordinary-modelling candidate: ONE splitter run cuts a box with a plane, so
    // both resulting solids share the single cut face. This is what an assembly split, a
    // slicing operation or an imprint produces -- nobody hand-builds it.
    {
        TopoDS_Shape target = box(20, 10, 10);
        TopoDS_Shape tool = BRepBuilderAPI_MakeFace(
            gp_Pln(gp_Pnt(10, 0, 0), gp_Dir(1, 0, 0)), -50, 50, -50, 50).Face();
        BRepAlgoAPI_Splitter splitter;
        TopTools_ListOfShape args, tools;
        args.Append(target);
        tools.Append(tool);
        splitter.SetArguments(args);
        splitter.SetTools(tools);
        splitter.Build();
        if (splitter.IsDone()) {
            f.push_back({"box split by a plane (one splitter run)", "ordinary", splitter.Shape()});
        }
    }

    // A sewn stack: two independently-built faces sewn along a shared edge.
    {
        BRepBuilderAPI_MakePolygon p1(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0),
                                      gp_Pnt(0, 10, 0), true);
        BRepBuilderAPI_MakePolygon p2(gp_Pnt(10, 0, 0), gp_Pnt(20, 0, 0), gp_Pnt(20, 10, 0),
                                      gp_Pnt(10, 10, 0), true);
        BRepBuilderAPI_Sewing sew(1e-6);
        sew.Add(BRepBuilderAPI_MakeFace(p1.Wire()).Face());
        sew.Add(BRepBuilderAPI_MakeFace(p2.Wire()).Face());
        sew.Perform();
        f.push_back({"sewn two-face sheet", "ordinary", sew.SewedShape()});
    }

    // --- Constructions that put one face in two places. ---

    // #541's own minimal reproduction: Shape.compound([face, face]).
    {
        TopoDS_Shape fc = firstFace(box(10, 10, 10));
        TopoDS_Compound c;
        BRep_Builder bb;
        bb.MakeCompound(c);
        bb.Add(c, fc);
        bb.Add(c, fc);
        f.push_back({"compound(face, THE SAME face)", "hand-built", c});
    }

    // The same face and its own reverse -- what a self-folded sheet looks like after a bad
    // sew. IsSame ignores orientation, so the map keeps one.
    {
        TopoDS_Shape fc = firstFace(box(10, 10, 10));
        TopoDS_Shell sh;
        BRep_Builder bb;
        bb.MakeShell(sh);
        bb.Add(sh, fc);
        bb.Add(sh, fc.Reversed());
        f.push_back({"shell(face, face.Reversed())", "hand-built", sh});
    }

    // One whole solid compounded with itself: every one of its faces is reachable twice.
    {
        TopoDS_Shape b = box(10, 10, 10);
        TopoDS_Compound c;
        BRep_Builder bb;
        bb.MakeCompound(c);
        bb.Add(c, b);
        bb.Add(c, b);
        f.push_back({"compound(box, THE SAME box)", "hand-built", c});
    }

    // A solid compounded with a MOVED copy of itself. IsSame compares the location, so this
    // must NOT collapse -- the control that says the map is not merging instances.
    {
        TopoDS_Shape b = box(10, 10, 10);
        gp_Trsf t;
        t.SetTranslation(gp_Vec(50, 0, 0));
        TopoDS_Compound c;
        BRep_Builder bb;
        bb.MakeCompound(c);
        bb.Add(c, b);
        bb.Add(c, b.Moved(TopLoc_Location(t)));
        f.push_back({"compound(box, box.Moved())", "hand-built", c});
    }

    // One face used by two different parents in one compound: a face and a shell that
    // contains it.
    {
        TopoDS_Shape b = box(10, 10, 10);
        TopoDS_Shape fc = firstFace(b);
        TopoDS_Compound c;
        BRep_Builder bb;
        bb.MakeCompound(c);
        bb.Add(c, b);
        bb.Add(c, fc);
        f.push_back({"compound(box, one of its own faces)", "hand-built", c});
    }

    return f;
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

int main() {
    printf("#541 face-index contract probe -- OCCT 8.0.0p1 (pinned)\n");
    printf("========================================================\n\n");

    auto fixtures = buildFixtures();

    printf("%-38s %-11s %9s %9s  %s\n", "fixture", "provenance", "explorer", "map", "verdict");
    printf("%-38s %-11s %9s %9s  %s\n", "--------------------------------------",
           "-----------", "--------", "---", "-------");

    int divergent = 0;
    std::vector<const Fixture*> divergentFixtures;
    std::vector<std::pair<size_t, size_t>> divergentCounts;

    for (const auto& fx : fixtures) {
        auto a = schemeA(fx.shape);
        auto b = schemeB(fx.shape);
        bool same = (a.size() == b.size());
        printf("%-38s %-11s %9zu %9zu  %s\n", fx.name.c_str(), fx.provenance.c_str(),
               a.size(), b.size(), same ? "agree" : "DIVERGE");
        if (!same) {
            divergent++;
            divergentFixtures.push_back(&fx);
            divergentCounts.push_back({a.size(), b.size()});
        }
    }

    printf("\n%d of %zu fixtures diverge.\n\n", divergent, fixtures.size());

    // ---- Q2/Q3: where do they start disagreeing, and do they ever name different faces? ----
    printf("Per-index addressing on the divergent fixtures\n");
    printf("----------------------------------------------\n");
    printf("For each index both schemes accept, is it the same face?\n\n");

    for (size_t k = 0; k < divergentFixtures.size(); k++) {
        const Fixture& fx = *divergentFixtures[k];
        auto a = schemeA(fx.shape);
        auto b = schemeB(fx.shape);
        printf("  %s  (explorer %zu, map %zu)\n", fx.name.c_str(), a.size(), b.size());

        size_t shared = a.size() < b.size() ? a.size() : b.size();
        int firstMismatch = -1;
        for (size_t i = 0; i < shared; i++) {
            const char* s = sameness(a[i], b[i]);
            bool bad = (std::string(s) == "DIFFERENT");
            if (bad && firstMismatch < 0) firstMismatch = (int)i;
            printf("     index %2zu: %s%s\n", i, s, bad ? "   <-- wrong face" : "");
        }
        for (size_t i = shared; i < a.size(); i++) {
            printf("     index %2zu: explorer has a face here, map does not"
                   "  <-- Face.index that face(at:) answers nil for\n", i);
        }
        if (firstMismatch < 0) {
            printf("     => every shared index names the same face; the explorer merely runs "
                   "%zu entries longer\n", a.size() - b.size());
        } else {
            printf("     => the two schemes name DIFFERENT faces from index %d onwards\n",
                   firstMismatch);
        }
        printf("\n");
    }

    // ---- Q4: order preservation on the shapes the fix must not disturb ----
    printf("Order check on the agreeing fixtures\n");
    printf("------------------------------------\n");
    printf("Converging faces() onto the map must move no index on any shape that does not\n");
    printf("share a face. Each index is compared face-by-face, not just by count.\n\n");

    int orderBreaks = 0;
    for (const auto& fx : fixtures) {
        auto a = schemeA(fx.shape);
        auto b = schemeB(fx.shape);
        if (a.size() != b.size()) continue;
        bool ok = true;
        for (size_t i = 0; i < a.size(); i++) {
            if (!a[i].IsEqual(b[i])) { ok = false; break; }
        }
        if (!ok) orderBreaks++;
        printf("  %-38s %s\n", fx.name.c_str(),
               ok ? "identical at every index" : "ORDER DIFFERS");
    }
    printf("\n%d order break(s) across the agreeing fixtures.\n\n", orderBreaks);

    // ---- The 1-based schemes ----
    printf("The 1-based scheme (C)\n");
    printf("----------------------\n");
    printf("C indexes the same map as B, from 1. So on any shape, C(i) == B(i-1), C(0) is\n");
    printf("never a face, and B's last index is unreachable through C. Measured on the box:\n\n");
    {
        TopoDS_Shape probeBox = box(10, 10, 10);
        auto b = schemeB(probeBox);
        TopTools_IndexedMapOfShape m;
        TopExp::MapShapes(probeBox, TopAbs_FACE, m);
        printf("     face count: %d\n", m.Extent());
        printf("     C(0)      : out of range -- rejected, or silently skipped\n");
        printf("     C(1)      : %s as B(0)\n", sameness(m(1), b[0]));
        printf("     C(%d)      : %s as B(%zu)  <-- C's last valid index\n",
               m.Extent(), sameness(m(m.Extent()), b[b.size() - 1]), b.size() - 1);
        printf("     B(%zu)      : reachable through C only as C(%zu)\n",
               b.size() - 1, b.size());
        printf("\n     A caller holding Face.index (0-based) and calling a C-scheme entry\n"
               "     point addresses the face BEFORE the one it named, and can never name\n"
               "     the last face at all.\n");
    }

    // ---- The third counting mechanism ----
    printf("\nShapeAnalysis_ShapeContents, the third census\n");
    printf("---------------------------------------------\n");
    printf("Shape.contents does not read either scheme above. Which of its two face numbers,\n");
    printf("if either, is the one faceCount reports?\n\n");
    printf("%-38s %9s %9s %9s %9s\n", "fixture", "explorer", "map", "NbFaces", "NbShared");
    for (const auto& fx : fixtures) {
        ShapeAnalysis_ShapeContents sc;
        sc.Perform(fx.shape);
        printf("%-38s %9zu %9zu %9d %9d\n", fx.name.c_str(),
               schemeA(fx.shape).size(), schemeB(fx.shape).size(),
               sc.NbFaces(), sc.NbSharedFaces());
    }
    printf("\n  NbFaces tracks the explorer (occurrences). NbSharedFaces is a THIRD rule: it\n"
           "  strips the location before adding to its map (ShapeAnalysis_ShapeContents.cxx:167,\n"
           "  `face.Location(TopLoc_Location())`), so unlike IsSame it also collapses two\n"
           "  placements of one face. Neither column is faceCount's answer on every fixture.\n");

    printf("\ndone.\n");
    return 0;
}
