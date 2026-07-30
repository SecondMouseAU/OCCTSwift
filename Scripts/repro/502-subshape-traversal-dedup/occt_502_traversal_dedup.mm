// #502 ground truth: TopExp_Explorer vs TopExp::MapShapes as sub-shape enumerators.
//
// The bridge enumerates sub-shapes two ways. OCCTShapeGetSolids/Shells/Wires drive a bare
// TopExp_Explorer; OCCTShapeGetSubShapeCount/ByTypeIndex build a TopTools_IndexedMapOfShape
// through TopExp::MapShapes. #502 asserts the two disagree because the map deduplicates.
//
// This probe asks three things the headers alone cannot answer:
//
//   1. Do the counts actually diverge, and on what geometry? A construction nobody writes is
//      not a defect worth changing an API over.
//   2. When they diverge, WHICH occurrence does the map keep, and is anything lost beyond
//      the count (orientation, location)?
//   3. Is the map path's order the explorer's order, so that one implementation could serve
//      both without renumbering anyone's indices?
//
// No fixture files: every case builds its geometry from a primitive.

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRep_Builder.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_CompSolid.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>
#include <TopAbs.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pln.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <cstdio>
#include <string>
#include <vector>

// ---------------------------------------------------------------------------
// The two enumerators, transcribed from the bridge.
// ---------------------------------------------------------------------------

// OCCTShapeGetSolidCount / GetSolids / GetShellCount / GetShells / GetWireCount / GetWires
static std::vector<TopoDS_Shape> explorerWalk(const TopoDS_Shape& s, TopAbs_ShapeEnum t) {
    std::vector<TopoDS_Shape> out;
    for (TopExp_Explorer ex(s, t); ex.More(); ex.Next()) out.push_back(ex.Current());
    return out;
}

// OCCTShapeGetSubShapeCount / GetSubShapeByTypeIndex
static std::vector<TopoDS_Shape> mapWalk(const TopoDS_Shape& s, TopAbs_ShapeEnum t) {
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(s, t, m);
    std::vector<TopoDS_Shape> out;
    for (int i = 1; i <= m.Extent(); ++i) out.push_back(m(i));
    return out;
}

static const char* typeName(TopAbs_ShapeEnum t) {
    switch (t) {
        case TopAbs_COMPOUND:  return "COMPOUND";
        case TopAbs_COMPSOLID: return "COMPSOLID";
        case TopAbs_SOLID:     return "SOLID";
        case TopAbs_SHELL:     return "SHELL";
        case TopAbs_FACE:      return "FACE";
        case TopAbs_WIRE:      return "WIRE";
        case TopAbs_EDGE:      return "EDGE";
        case TopAbs_VERTEX:    return "VERTEX";
        default:               return "SHAPE";
    }
}

static const char* oriName(TopAbs_Orientation o) {
    switch (o) {
        case TopAbs_FORWARD:  return "FWD";
        case TopAbs_REVERSED: return "REV";
        case TopAbs_INTERNAL: return "INT";
        default:              return "EXT";
    }
}

// What the map dropped, and why it was allowed to: IsSame ignores orientation, IsEqual does not.
static void reportDrops(const std::vector<TopoDS_Shape>& exp, const std::vector<TopoDS_Shape>& map) {
    for (size_t i = 0; i < exp.size(); ++i) {
        bool kept = false;
        for (const TopoDS_Shape& k : map) {
            if (k.IsEqual(exp[i])) { kept = true; break; }
        }
        if (kept) continue;
        // Find the occurrence that absorbed it.
        for (size_t j = 0; j < map.size(); ++j) {
            if (!map[j].IsSame(exp[i])) continue;
            printf("      dropped occurrence #%zu (%s) -> collapsed into index %zu (%s); "
                   "sameTShape=1 sameLocation=%d sameOrientation=%d\n",
                   i, oriName(exp[i].Orientation()), j, oriName(map[j].Orientation()),
                   map[j].Location().IsEqual(exp[i].Location()) ? 1 : 0,
                   map[j].Orientation() == exp[i].Orientation() ? 1 : 0);
            break;
        }
    }
}

static void compare(const char* fixture, const TopoDS_Shape& s,
                    const std::vector<TopAbs_ShapeEnum>& types) {
    printf("  %s\n", fixture);
    for (TopAbs_ShapeEnum t : types) {
        std::vector<TopoDS_Shape> exp = explorerWalk(s, t);
        std::vector<TopoDS_Shape> map = mapWalk(s, t);

        // Is the map a prefix-preserving subsequence of the explorer walk? If it is, one
        // traversal can serve both and no existing index moves.
        bool orderPreserved = true;
        size_t k = 0;
        for (size_t i = 0; i < exp.size() && k < map.size(); ++i) {
            if (map[k].IsEqual(exp[i])) ++k;
        }
        if (k != map.size()) orderPreserved = false;

        printf("    %-9s explorer=%-3zu map=%-3zu %s  order=%s\n",
               typeName(t), exp.size(), map.size(),
               exp.size() == map.size() ? "agree " : "DIVERGE",
               orderPreserved ? "same" : "RENUMBERED");
        if (exp.size() != map.size()) reportDrops(exp, map);
    }
}

// ---------------------------------------------------------------------------

static TopoDS_Shape compoundOf(const std::vector<TopoDS_Shape>& members) {
    TopoDS_Compound c;
    BRep_Builder b;
    b.MakeCompound(c);
    for (const TopoDS_Shape& m : members) b.Add(c, m);
    return c;
}

static TopoDS_Shape planarFace(double z, double side) {
    BRepBuilderAPI_MakePolygon poly(gp_Pnt(0, 0, z), gp_Pnt(side, 0, z),
                                    gp_Pnt(side, side, z), gp_Pnt(0, side, z), true);
    return BRepBuilderAPI_MakeFace(poly.Wire()).Face();
}

int main() {
    const std::vector<TopAbs_ShapeEnum> all = {TopAbs_SOLID, TopAbs_SHELL, TopAbs_FACE,
                                               TopAbs_WIRE, TopAbs_EDGE, TopAbs_VERTEX};

    printf("=== 1. Shapes with no sharing: the two paths must agree ===\n");
    TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
    compare("box(10,10,10)", box, all);
    compare("sphere(r=5)", BRepPrimAPI_MakeSphere(5.0).Shape(), all);
    compare("cylinder(r=3,h=8)", BRepPrimAPI_MakeCylinder(3.0, 8.0).Shape(), all);

    // A hollow solid: two shells, one boundary + one cavity. Real geometry, real multi-shell.
    TopoDS_Shape cavity = BRepPrimAPI_MakeBox(gp_Pnt(3, 3, 3), 4.0, 4.0, 4.0).Shape();
    TopoDS_Shape hollow = BRepAlgoAPI_Cut(box, cavity).Shape();
    compare("box minus inner box (hollow, 2 shells)", hollow, all);

    // Two bodies far apart: distinct TShapes throughout.
    TopoDS_Shape farBox = BRepPrimAPI_MakeBox(gp_Pnt(50, 0, 0), 10.0, 10.0, 10.0).Shape();
    compare("compound(box, distinct box)", compoundOf({box, farBox}), all);

    printf("\n=== 2. The same sub-shape reachable twice ===\n");

    // (a) The identical solid added to one compound twice. Shape.compound([s, s]).
    compare("compound(box, THE SAME box)", compoundOf({box, box}), all);

    // (b) Two instances of one body at different locations (assembly instancing).
    gp_Trsf move;
    move.SetTranslation(gp_Vec(50, 0, 0));
    compare("compound(box, box.Moved(+50x))", compoundOf({box, box.Moved(TopLoc_Location(move))}), all);

    // (c) Same body, opposite orientation: differs only in a bit IsSame ignores.
    compare("compound(box, box.Reversed())", compoundOf({box, box.Reversed()}), all);

    // (d) The issue's own case: one shell handle reused across two solid constructions,
    //     then both solids put in one compound (Issue442FixSolidMultiBodyTests pattern).
    {
        TopoDS_Shell shell;
        for (TopExp_Explorer ex(box, TopAbs_SHELL); ex.More(); ex.Next()) {
            shell = TopoDS::Shell(ex.Current());
            break;
        }
        BRep_Builder b;
        TopoDS_Solid s1, s2;
        b.MakeSolid(s1);
        b.Add(s1, shell);
        b.MakeSolid(s2);
        b.Add(s2, shell);  // the same shell, in a second solid
        compare("compound(solidFromShells(sh), solidFromShells(THE SAME sh))",
                compoundOf({s1, s2}), all);
    }

    // (e) One wire used to build two different faces: the WIRE case specifically.
    {
        BRepBuilderAPI_MakePolygon poly(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0),
                                        gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0), true);
        TopoDS_Wire w = poly.Wire();
        TopoDS_Face f1 = BRepBuilderAPI_MakeFace(w).Face();
        TopoDS_Face f2 = BRepBuilderAPI_MakeFace(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), w).Face();
        compare("compound(face(w), otherFace(THE SAME w))", compoundOf({f1, f2}), all);
    }

    printf("\n=== 3. Sharing that arises from ordinary modelling, not hand-built topology ===\n");

    // Two boxes sewn along a common plane: the shared face/edges/vertices are one TShape
    // reachable from both sides.
    {
        TopoDS_Shape lower = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10.0, 10.0, 5.0).Shape();
        TopoDS_Shape upper = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 5), 10.0, 10.0, 5.0).Shape();
        BRepBuilderAPI_Sewing sewing(1e-6);
        sewing.Add(lower);
        sewing.Add(upper);
        sewing.Perform();
        compare("sewn(box, stacked box)", sewing.SewedShape(), all);
    }

    // A compsolid of two solids glued on a shared face.
    {
        TopoDS_Shape lower = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10.0, 10.0, 5.0).Shape();
        TopoDS_Shape upper = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 5), 10.0, 10.0, 5.0).Shape();
        TopoDS_CompSolid cs;
        BRep_Builder b;
        b.MakeCompSolid(cs);
        for (TopExp_Explorer ex(lower, TopAbs_SOLID); ex.More(); ex.Next()) b.Add(cs, ex.Current());
        for (TopExp_Explorer ex(upper, TopAbs_SOLID); ex.More(); ex.Next()) b.Add(cs, ex.Current());
        compare("compsolid(lower, upper)", cs, all);
    }

    // A shell whose two faces share a wire? They cannot: a wire belongs to one face. But a
    // face and its own reversed copy in one shell CAN, and that is what a self-folded sheet
    // looks like after a bad sew.
    {
        TopoDS_Face f = TopoDS::Face(planarFace(0.0, 10.0));
        TopoDS_Shell sh;
        BRep_Builder b;
        b.MakeShell(sh);
        b.Add(sh, f);
        b.Add(sh, f.Reversed());
        compare("shell(face, face.Reversed())", sh, all);
    }

    printf("\n=== 4. Argument-domain edges of the generic type+index API ===\n");
    // ShapeType has a `.unknown = -1` case and a `.compound = 0` case, both reachable from
    // Swift as subShapeCount(ofType:). TopExp_Explorer's header says the type to find
    // "cannot be SHAPE" (= 8). What do the paths do with each?
    {
        TopoDS_Shape c = compoundOf({box, farBox});
        for (int raw : {0, 1, 8, 9, -1}) {
            TopAbs_ShapeEnum t = static_cast<TopAbs_ShapeEnum>(raw);
            int expCount = -1, mapCount = -1;
            std::string expErr, mapErr;
            try { expCount = static_cast<int>(explorerWalk(c, t).size()); }
            catch (const Standard_Failure& f) { expErr = f.GetMessageString() ? f.GetMessageString() : "Standard_Failure"; }
            catch (...) { expErr = "unknown throw"; }
            try { mapCount = static_cast<int>(mapWalk(c, t).size()); }
            catch (const Standard_Failure& f) { mapErr = f.GetMessageString() ? f.GetMessageString() : "Standard_Failure"; }
            catch (...) { mapErr = "unknown throw"; }
            printf("    raw type %-3d (%-9s) explorer=%-3d %-24s map=%-3d %s\n",
                   raw, typeName(t), expCount, expErr.empty() ? "" : ("threw: " + expErr).c_str(),
                   mapCount, mapErr.empty() ? "" : ("threw: " + mapErr).c_str());
        }
    }

    printf("\n=== 5. Does either path ever yield the shape itself? ===\n");
    // Matters for solidCount on a bare solid, and for shellCount on a bare shell.
    {
        TopoDS_Shape solid;
        for (TopExp_Explorer ex(box, TopAbs_SOLID); ex.More(); ex.Next()) { solid = ex.Current(); break; }
        printf("    solid, asked for SOLID:  explorer=%zu map=%zu\n",
               explorerWalk(solid, TopAbs_SOLID).size(), mapWalk(solid, TopAbs_SOLID).size());
        TopoDS_Shape shell;
        for (TopExp_Explorer ex(box, TopAbs_SHELL); ex.More(); ex.Next()) { shell = ex.Current(); break; }
        printf("    shell, asked for SHELL:  explorer=%zu map=%zu\n",
               explorerWalk(shell, TopAbs_SHELL).size(), mapWalk(shell, TopAbs_SHELL).size());
        printf("    box,   asked for COMPOUND: explorer=%zu map=%zu\n",
               explorerWalk(box, TopAbs_COMPOUND).size(), mapWalk(box, TopAbs_COMPOUND).size());
    }

    printf("\ndone\n");
    return 0;
}
