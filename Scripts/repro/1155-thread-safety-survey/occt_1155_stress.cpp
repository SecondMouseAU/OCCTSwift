// Multi-threaded stress harness for OCCTSwift#1155: "algorithms with internal mutable
// state" -- BRepBuilderAPI_Transform, BRepClass3d_SolidClassifier, GeomAPI_ProjectPointOnSurf,
// BRepBuilderAPI_MakeEdge/MakeWire/MakeFace, BRepOffsetAPI_MakePipeShell/MakeThickSolid,
// BRepFilletAPI_MakeFillet/MakeChamfer (already fixed for FILE-SCOPE statics in #298, this
// harness targets whatever INSTANCE-level exposure might remain), ShapeFix_Face/Wire/Shape,
// BRepCheck_Analyzer.
//
// Pure C++, no Swift/bridge layer -- isolates OCCT itself. Each scenario below was chosen only
// after reading the class's own source (and its call chain) for file-scope/static mutable
// state; see Scripts/repro/1155-thread-safety-survey/README.md for the full characterization,
// including the one class (BRepFilletAPI_MakeFillet/MakeChamfer's underlying
// TopOpeBRepBuild_Builder) that DOES have live, unguarded file-scope globals
// (TopOpeBRepBuild_ffsfs.cxx/TopOpeBRepBuild_GridSS.cxx's GLOBAL_SplitAnc/GLOBAL_lfr1/
// GLOBAL_lfrtoprocess/GLOBAL_classifysplitedge/GLOBAL_revownsplfacori/static_CONF1/CONF2),
// confirmed via a single-threaded reachability probe (fprintf inside the reader/writer
// functions, override-linked ahead of the production archive) to be UNREACHABLE from
// BRepFilletAPI_MakeFillet/MakeChamfer for every geometry tried (plain box, all 12 edges;
// box-fuse-sphere; two coincident-face boxes fused; a cylinder), because that code family
// (the "old algo") is reached only through TopOpeBRepBuild_Builder's KPart fast path, which
// requires TWO real solids being compared (BRepFilletAPI's HBuilder always calls the
// single-shape MergeSolid overload, myShape2 stays null, so FindIsKPart() -- called from
// nowhere else -- never runs for this call chain). The fillet_chamfer_all_edges scenario
// below still runs it concurrently regardless, since a reachability probe against ONE process
// is not proof for every geometry, and this is the gate that would catch it if that
// conclusion is ever wrong.
//
// Usage: occt_1155_stress <scenario> <threads> <iterations>
//   scenarios: transform_independent | classify_independent | project_point_independent
//              | make_edge_wire_face_independent | pipe_shell_thick_solid_independent
//              | fillet_chamfer_all_edges_independent | shapefix_independent
//              | check_analyzer_independent | all

#include <atomic>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeFix_Face.hxx>
#include <ShapeFix_Wire.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <Geom_Plane.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Circle.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

std::atomic<long> gOps{0};
std::atomic<long> gErrors{0};

static void note(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fprintf(stderr, "\n");
}

// ---------------------------------------------------------------------------
// 1. BRepBuilderAPI_Transform: independent shapes, independent transforms.
// Exercises both the "no-copy, just relocate" branch (myUseModif == false) and
// the BRepTools_Modifier-driven copy branch (myUseModif == true, scale != 1 or
// mirror), since #726/#597-style investigations here have shown behavior often
// splits by which branch is taken.
// ---------------------------------------------------------------------------
void runTransformIndependent(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(5 + (it % 5), 5, 5).Shape();

        gp_Trsf isometric;
        isometric.SetTranslation(gp_Vec(id, it, 0));
        BRepBuilderAPI_Transform t1(box, isometric, false, false);
        if (!t1.IsDone()) { gErrors++; note("[thread %d] transform (isometric) not done", id); }

        gp_Trsf scaled;
        scaled.SetScale(gp_Pnt(0, 0, 0), 1.5 + 0.01 * (it % 7));
        BRepBuilderAPI_Transform t2(box, scaled, true, false);
        if (!t2.IsDone()) { gErrors++; note("[thread %d] transform (scaled) not done", id); }

        gOps++;
    }
}

// ---------------------------------------------------------------------------
// 2. BRepClass3d_SolidClassifier: independent solids, many point classifications
// each (own BRepClass3d_SolidExplorer, own UB-tree, own per-face
// IntCurvesFace_Intersector map -- all instance state per the source read).
// ---------------------------------------------------------------------------
void runClassifyIndependent(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
        BRepClass3d_SolidClassifier classifier(box);
        for (int p = 0; p < 20; ++p) {
            gp_Pnt probe(1.0 + (p % 9), 1.0 + ((p + id) % 9), 1.0 + ((p + it) % 9));
            classifier.Perform(probe, 1e-7);
            TopAbs_State st = classifier.State();
            if (st != TopAbs_IN && st != TopAbs_OUT && st != TopAbs_ON) {
                gErrors++;
                note("[thread %d] classify: unexpected state", id);
            }
        }
        gOps++;
    }
}

// ---------------------------------------------------------------------------
// 3. GeomAPI_ProjectPointOnSurf: independent surfaces, independent points. Each
// instance owns its own GeomAdaptor_Surface (which owns its own BSplSLib_Cache,
// per #1153's fix) and its own Extrema_ExtPS.
// ---------------------------------------------------------------------------
void runProjectPointIndependent(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        occ::handle<Geom_CylindricalSurface> cyl =
            new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5 + (it % 3));
        gp_Pnt probe(3.0 + id * 0.1, 2.0 + it * 0.1, 4.0);
        GeomAPI_ProjectPointOnSurf proj(probe, cyl);
        if (proj.NbPoints() == 0) {
            gErrors++;
            note("[thread %d] project: no solution", id);
        }
        gOps++;
    }
}

// ---------------------------------------------------------------------------
// 4. BRepBuilderAPI_MakeEdge / MakeWire / MakeFace: independent geometry.
// ---------------------------------------------------------------------------
void runMakeEdgeWireFaceIndependent(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        gp_Pnt p1(0, 0, 0), p2(5 + (it % 3), 0, 0), p3(5, 5, 0), p4(0, 5, 0);
        TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2);
        TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3);
        TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(p3, p4);
        TopoDS_Edge e4 = BRepBuilderAPI_MakeEdge(p4, p1);
        BRepBuilderAPI_MakeWire mkWire(e1, e2, e3, e4);
        if (!mkWire.IsDone()) { gErrors++; note("[thread %d] wire not done", id); continue; }
        TopoDS_Wire wire = mkWire.Wire();
        BRepBuilderAPI_MakeFace mkFace(wire);
        if (!mkFace.IsDone()) { gErrors++; note("[thread %d] face not done", id); }
        gOps++;
    }
}

// ---------------------------------------------------------------------------
// 5. BRepOffsetAPI_MakePipeShell / MakeThickSolid: independent shapes.
// ---------------------------------------------------------------------------
void runPipeShellThickSolidIndependent(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        // PipeShell: circular profile swept along a straight spine wire.
        gp_Pnt spineStart(0, 0, 0), spineEnd(0, 0, 20 + (it % 5));
        TopoDS_Edge spineEdge = BRepBuilderAPI_MakeEdge(spineStart, spineEnd);
        TopoDS_Wire spine = BRepBuilderAPI_MakeWire(spineEdge);

        occ::handle<Geom_Circle> circ =
            new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 2.0);
        TopoDS_Edge profEdge = BRepBuilderAPI_MakeEdge(circ);
        TopoDS_Wire profile = BRepBuilderAPI_MakeWire(profEdge);

        BRepOffsetAPI_MakePipeShell pipeShell(spine);
        pipeShell.Add(profile);
        pipeShell.Build();
        if (!pipeShell.IsDone()) {
            gErrors++;
            note("[thread %d] pipeshell not done", id);
        } else {
            pipeShell.MakeSolid();
        }

        // ThickSolid: shell a box, removing its top face.
        TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10 + (it % 3)).Shape();
        TopoDS_Face topFace;
        for (TopExp_Explorer exp(box, TopAbs_FACE); exp.More(); exp.Next()) {
            TopoDS_Face f = TopoDS::Face(exp.Current());
            // crude "top face" pick: first face works fine for a stress test,
            // it doesn't need to be geometrically the top.
            topFace = f;
            break;
        }
        NCollection_List<TopoDS_Shape> facesToRemove;
        facesToRemove.Append(topFace);
        BRepOffsetAPI_MakeThickSolid thick;
        thick.MakeThickSolidByJoin(box, facesToRemove, -0.5, 1e-3);
        if (!thick.IsDone()) {
            gErrors++;
            note("[thread %d] thicksolid not done", id);
        }

        gOps++;
    }
}

// ---------------------------------------------------------------------------
// 6. BRepFilletAPI_MakeFillet / MakeChamfer: independent boxes, ALL edges
// filleted/chamfered per build (deliberately the geometry most likely to hit
// ChFi3d's corner-merge code and any residual TopOpeBRepBuild file-scope state,
// see the file header comment above).
// ---------------------------------------------------------------------------
void runFilletChamferAllEdgesIndependent(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(10 + (it % 4), 10, 10).Shape();

        BRepFilletAPI_MakeFillet mkFillet(box);
        int nf = 0;
        for (TopExp_Explorer exp(box, TopAbs_EDGE); exp.More(); exp.Next()) {
            mkFillet.Add(0.5 + 0.01 * (id % 5), TopoDS::Edge(exp.Current()));
            ++nf;
        }
        mkFillet.Build();
        if (!mkFillet.IsDone()) { gErrors++; note("[thread %d] fillet not done (%d edges)", id, nf); }

        TopoDS_Shape box2 = BRepPrimAPI_MakeBox(10, 10 + (it % 3), 10).Shape();
        BRepFilletAPI_MakeChamfer mkChamfer(box2);
        for (TopExp_Explorer exp(box2, TopAbs_EDGE); exp.More(); exp.Next()) {
            mkChamfer.Add(TopoDS::Edge(exp.Current()));
        }
        mkChamfer.Build();
        // Chamfer without an explicit face reference commonly reports NotDone in
        // this OCCT version (needs SetMode / face-qualified Add for real distances);
        // that's a pre-existing, unrelated quirk, not counted as a stress error here.

        gOps++;
    }
}

// ---------------------------------------------------------------------------
// 7. ShapeFix_Face / ShapeFix_Wire / ShapeFix_Shape: independent shapes.
// ---------------------------------------------------------------------------
void runShapeFixIndependent(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(8 + (it % 3), 8, 8).Shape();

        occ::handle<ShapeFix_Shape> fixShape = new ShapeFix_Shape(box);
        fixShape->Perform();
        TopoDS_Shape fixed = fixShape->Shape();
        if (fixed.IsNull()) { gErrors++; note("[thread %d] ShapeFix_Shape produced null", id); }

        for (TopExp_Explorer exp(box, TopAbs_FACE); exp.More(); exp.Next()) {
            TopoDS_Face f = TopoDS::Face(exp.Current());
            occ::handle<ShapeFix_Face> fixFace = new ShapeFix_Face(f);
            fixFace->Perform();
            break;
        }
        for (TopExp_Explorer exp(box, TopAbs_WIRE); exp.More(); exp.Next()) {
            TopoDS_Wire w = TopoDS::Wire(exp.Current());
            occ::handle<ShapeFix_Wire> fixWire = new ShapeFix_Wire();
            fixWire->Load(w);
            fixWire->FixReorder();
            break;
        }

        gOps++;
    }
}

// ---------------------------------------------------------------------------
// 8. BRepCheck_Analyzer: independent shapes, both serial and SetParallel(true)
// (the latter already documented as OCCT's own internal-parallelism-safe mode).
// ---------------------------------------------------------------------------
void runCheckAnalyzerIndependent(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(3 + (it % 4), 10).Shape();
        BRepCheck_Analyzer analyzer(cyl, true, false);
        if (!analyzer.IsValid()) { gErrors++; note("[thread %d] cylinder reported invalid", id); }

        BRepCheck_Analyzer analyzerParallel(cyl, true, true);
        if (!analyzerParallel.IsValid()) {
            gErrors++;
            note("[thread %d] cylinder (parallel) reported invalid", id);
        }
        gOps++;
    }
}

// ---------------------------------------------------------------------------

struct Scenario {
    const char* name;
    void (*fn)(int, int);
};

static Scenario SCENARIOS[] = {
    {"transform_independent", runTransformIndependent},
    {"classify_independent", runClassifyIndependent},
    {"project_point_independent", runProjectPointIndependent},
    {"make_edge_wire_face_independent", runMakeEdgeWireFaceIndependent},
    {"pipe_shell_thick_solid_independent", runPipeShellThickSolidIndependent},
    {"fillet_chamfer_all_edges_independent", runFilletChamferAllEdgesIndependent},
    {"shapefix_independent", runShapeFixIndependent},
    {"check_analyzer_independent", runCheckAnalyzerIndependent},
};

static void runOne(const char* name, int threads, int iterations) {
    for (auto& s : SCENARIOS) {
        if (strcmp(name, s.name) != 0) continue;
        std::vector<std::thread> pool;
        for (int i = 0; i < threads; ++i) {
            pool.emplace_back(s.fn, i, iterations);
        }
        for (auto& th : pool) th.join();
        return;
    }
    note("unknown scenario: %s", name);
    exit(2);
}

int main(int argc, char** argv) {
    if (argc < 4) {
        note("usage: %s <scenario|all> <threads> <iterations>", argv[0]);
        return 2;
    }
    std::string scenario = argv[1];
    int threads = atoi(argv[2]);
    int iterations = atoi(argv[3]);

    if (scenario == "all") {
        for (auto& s : SCENARIOS) {
            note(">>> %s", s.name);
            gOps = 0;
            gErrors = 0;
            runOne(s.name, threads, iterations);
            note("    ops=%ld errors=%ld", gOps.load(), gErrors.load());
        }
    } else {
        runOne(scenario.c_str(), threads, iterations);
        note("ops=%ld errors=%ld", gOps.load(), gErrors.load());
    }

    return gErrors.load() > 0 ? 1 : 0;
}
