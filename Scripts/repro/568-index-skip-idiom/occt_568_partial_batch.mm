// OCCTSwift#568 ground truth: what the four builders behind the surviving skip-an-out-of-range-index
// sites do when the batch they are handed is only partly the batch the caller asked for.
//
// Every one of those sites resolves a caller-supplied index array against a TopExp map and drops
// the entries that name nothing, so the builder never learns that anything was asked for and
// dropped. The question this probe answers is what the caller then gets back: whether the builder
// itself notices (fails IsDone, throws, returns a null shape), or whether the partial result is
// reported exactly like the complete one.
//
// Pass the case name as argv[1]. Each case runs in its own process because a builder handed an
// empty batch is exactly the shape that SIGSEGV'd in #520.
//
//   BRepFilletAPI_MakeChamfer     OCCTShapeHistoryFromChamferEdges  chamfer-{full,partial,none}
//   BRepOffsetAPI_DraftAngle      OCCTShapeDraft                    draft-{full,partial,none}
//   BRepOffsetAPI_MakeThickSolid  OCCTShapeShellWithOpenFaces       thick-{full,partial}
//   BRepFilletAPI_MakeFillet2d    OCCTFace2DFillet                  fillet2d-{full,partial,none}
//                                 OCCTFace2DChamfer                 chamfer2d-{full,partial,none}
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet2d.hxx>
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <Standard_Failure.hxx>
#include <gp_Pln.hxx>
#include <cstdio>
#include <cstring>

static TopoDS_Shape box(double side) { return BRepPrimAPI_MakeBox(side, side, side).Shape(); }

// A single planar face: a 40x30 rectangle in Z=0, the shape Shape.fillet2D/chamfer2D are meant for.
static TopoDS_Face rectangleFace() {
    BRepBuilderAPI_MakePolygon poly;
    poly.Add(gp_Pnt(0, 0, 0));
    poly.Add(gp_Pnt(40, 0, 0));
    poly.Add(gp_Pnt(40, 30, 0));
    poly.Add(gp_Pnt(0, 30, 0));
    poly.Close();
    return BRepBuilderAPI_MakeFace(poly.Wire(), true).Face();
}

static int32_t countOf(const TopoDS_Shape& s, TopAbs_ShapeEnum type) {
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(s, type, map);
    return map.Extent();
}

// The report every case ends with: what a bridge caller can actually observe about the result.
static void report(bool isDone, const TopoDS_Shape& result, bool solid) {
    printf("  IsDone=%d", (int)isDone);
    if (!isDone) { printf("\n"); return; }
    printf(" IsNull=%d", (int)result.IsNull());
    if (result.IsNull()) { printf("\n"); return; }
    GProp_GProps props;
    if (solid) BRepGProp::VolumeProperties(result, props);
    else BRepGProp::SurfaceProperties(result, props);
    printf(" %s=%.6f edges=%d vertices=%d valid=%d\n",
           solid ? "volume" : "area", props.Mass(),
           countOf(result, TopAbs_EDGE), countOf(result, TopAbs_VERTEX),
           (int)BRepCheck_Analyzer(result).IsValid());
}

// === BRepFilletAPI_MakeChamfer: OCCTShapeHistoryFromChamferEdges ===
// The bridge asks for `count` edges and adds only the ones whose index resolves.
static void chamferCase(int32_t added) {
    TopoDS_Shape s = box(20);
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(s, TopAbs_EDGE, edgeMap);
    printf("chamfer: requested 3 edges, %d resolved (edge map holds %d)\n", added, edgeMap.Extent());
    try {
        BRepFilletAPI_MakeChamfer op(s);
        for (int32_t i = 0; i < added; i++) op.Add(2.0, TopoDS::Edge(edgeMap(i + 1)));
        op.Build();
        report(op.IsDone(), op.IsDone() ? op.Shape() : TopoDS_Shape(), true);
    } catch (Standard_Failure& f) {
        printf("  THREW: %s\n", f.GetMessageString());
    }
}

// === BRepOffsetAPI_DraftAngle: OCCTShapeDraft ===
// Faces 0..3 of a box are its four sides, all draftable against a Z pull and a Z=0 neutral plane.
static void draftCase(int32_t added) {
    TopoDS_Shape s = box(20);
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(s, TopAbs_FACE, faceMap);
    gp_Dir pull(0, 0, 1);
    gp_Pln neutral(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    printf("draft: requested 4 faces, %d resolved (face map holds %d)\n", added, faceMap.Extent());
    try {
        BRepOffsetAPI_DraftAngle draft(s);
        int32_t drafted = 0;
        for (int32_t i = 1; i <= faceMap.Extent() && drafted < added; i++) {
            TopoDS_Face f = TopoDS::Face(faceMap(i));
            // Skip the two faces normal to the pull direction: they are not draftable at all, and
            // that is a different refusal from the one being measured.
            gp_Dir n = gp_Pln(BRepAdaptor_Surface(f).Plane()).Axis().Direction();
            if (n.IsParallel(pull, 1e-7)) continue;
            draft.Add(f, pull, 0.0873, neutral);   // 5 degrees
            drafted++;
        }
        draft.Build();
        report(draft.IsDone(), draft.IsDone() ? draft.Shape() : TopoDS_Shape(), true);
    } catch (Standard_Failure& f) {
        printf("  THREW: %s\n", f.GetMessageString());
    }
}

// === BRepOffsetAPI_MakeThickSolid: OCCTShapeShellWithOpenFaces ===
// Two opposite faces of a box asked to be left open, against one.
static void thickCase(int32_t added) {
    TopoDS_Shape s = box(20);
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(s, TopAbs_FACE, faceMap);
    printf("thick: requested 2 open faces, %d resolved (face map holds %d)\n", added, faceMap.Extent());
    try {
        TopTools_ListOfShape open;
        if (added >= 1) open.Append(faceMap(1));
        if (added >= 2) open.Append(faceMap(2));
        BRepOffsetAPI_MakeThickSolid op;
        op.MakeThickSolidByJoin(s, open, -2.0, 1e-6);
        report(op.IsDone(), op.IsDone() ? op.Shape() : TopoDS_Shape(), true);
    } catch (Standard_Failure& f) {
        printf("  THREW: %s\n", f.GetMessageString());
    }
}

// === BRepFilletAPI_MakeFillet2d: OCCTFace2DFillet ===
static void fillet2dCase(int32_t added) {
    TopoDS_Face f = rectangleFace();
    TopTools_IndexedMapOfShape vertMap;
    TopExp::MapShapes(f, TopAbs_VERTEX, vertMap);
    printf("fillet2d: requested 4 vertices, %d resolved (vertex map holds %d)\n",
           added, vertMap.Extent());
    try {
        BRepFilletAPI_MakeFillet2d fillet(f);
        for (int32_t i = 0; i < added; i++) fillet.AddFillet(TopoDS::Vertex(vertMap(i + 1)), 5.0);
        fillet.Build();
        report(fillet.IsDone(), fillet.IsDone() ? fillet.Shape() : TopoDS_Shape(), false);
    } catch (Standard_Failure& e) {
        printf("  THREW: %s\n", e.GetMessageString());
    }
}

// === BRepFilletAPI_MakeFillet2d: OCCTFace2DChamfer ===
// The pair case: each entry names TWO edges, and either being out of range drops the pair.
static void chamfer2dCase(int32_t added) {
    TopoDS_Face f = rectangleFace();
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(f, TopAbs_EDGE, edgeMap);
    printf("chamfer2d: requested 2 pairs, %d resolved (edge map holds %d)\n", added, edgeMap.Extent());
    try {
        BRepFilletAPI_MakeFillet2d chamfer(f);
        if (added >= 1) chamfer.AddChamfer(TopoDS::Edge(edgeMap(1)), TopoDS::Edge(edgeMap(2)), 4.0, 4.0);
        if (added >= 2) chamfer.AddChamfer(TopoDS::Edge(edgeMap(3)), TopoDS::Edge(edgeMap(4)), 4.0, 4.0);
        chamfer.Build();
        report(chamfer.IsDone(), chamfer.IsDone() ? chamfer.Shape() : TopoDS_Shape(), false);
    } catch (Standard_Failure& e) {
        printf("  THREW: %s\n", e.GetMessageString());
    }
}

int main(int argc, const char** argv) {
    const char* c = argc > 1 ? argv[1] : "";
    if (!strcmp(c, "chamfer-full")) chamferCase(3);
    else if (!strcmp(c, "chamfer-partial")) chamferCase(2);
    else if (!strcmp(c, "chamfer-none")) chamferCase(0);
    else if (!strcmp(c, "draft-full")) draftCase(4);
    else if (!strcmp(c, "draft-partial")) draftCase(2);
    else if (!strcmp(c, "draft-none")) draftCase(0);
    else if (!strcmp(c, "thick-full")) thickCase(2);
    else if (!strcmp(c, "thick-partial")) thickCase(1);
    else if (!strcmp(c, "fillet2d-full")) fillet2dCase(4);
    else if (!strcmp(c, "fillet2d-partial")) fillet2dCase(2);
    else if (!strcmp(c, "fillet2d-none")) fillet2dCase(0);
    else if (!strcmp(c, "chamfer2d-full")) chamfer2dCase(2);
    else if (!strcmp(c, "chamfer2d-partial")) chamfer2dCase(1);
    else if (!strcmp(c, "chamfer2d-none")) chamfer2dCase(0);
    else { printf("unknown case: %s\n", c); return 2; }
    return 0;
}
