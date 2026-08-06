// #720 review of #703, findings 2 and 9. The review's claim: OCCTEdgeGetConvexity's new
// centroid formula has no degenerate/sliver-face guard, and BRepAlgoAPI routinely produces sliver
// faces at cut boundaries, where CentreOfMass() could be numerically unstable or (per a #605
// finding for the whole-shape VolumeProperties path) silently snap to (0,0,0).
//
// This fuses two 20mm boxes overlapping by a deliberately tiny sliver (0.0005mm in X), the
// textbook way to make a boolean operation emit a genuine sliver face, and inspects every face
// under area 1.0 with both the plain SurfaceProperties overload (what OCCTEdgeGetConvexity called
// before this PR's fix) and the adaptive Eps overload (what OCCTFaceGetAreaCentroid calls now).
//
// Measured: the sliver faces this produces have area ~0.01 (not zero, not garbage), and the two
// overloads agree to machine precision (Eps overload reports 0 relative error). Shrinking the
// overlap further (1e-7mm, below BRepAlgoAPI's own fuzzy tolerance) does not produce a thinner
// sliver: it produces NO sliver at all; the boxes just fuse into a single 10-face box. OCCT's own
// tolerance handling would not let a genuinely near-zero-area face survive as its own topological
// face in the first place, so this specific instability was not reproduced. The
// OCCTFaceGetAreaCentroid guard (reject area < 1e-9) was added anyway, defensively and for free
// while restructuring for finding 7's performance fix, several orders of magnitude below the
// smallest sliver observed here.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <gp_Trsf.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <cstdio>

static void runFusedOverlap(double overlapGapFromTouching) {
    // Box A: 20x20x20 at the origin. Box B: translated so it overlaps Box A by
    // (20 - overlapGapFromTouching) mm in X, i.e. a sliver of that width extends past Box A.
    TopoDS_Shape boxA = BRepPrimAPI_MakeBox(20, 20, 20).Shape();
    gp_Trsf trsf;
    trsf.SetTranslation(gp_Vec(20.0 - overlapGapFromTouching, 0, 0));
    TopoDS_Shape boxB = BRepPrimAPI_MakeBox(20, 20, 20).Shape();
    BRepBuilderAPI_Transform mover(boxB, trsf);
    boxB = mover.Shape();

    BRepAlgoAPI_Fuse fuse(boxA, boxB);
    if (!fuse.IsDone()) { std::printf("FUSE FAILED (gap=%.3g)\n", overlapGapFromTouching); return; }
    TopoDS_Shape fused = fuse.Shape();

    int faceIdx = 0, sliverCount = 0;
    for (TopExp_Explorer ex(fused, TopAbs_FACE); ex.More(); ex.Next(), faceIdx++) {
        TopoDS_Face f = TopoDS::Face(ex.Current());
        GProp_GProps props;
        BRepGProp::SurfaceProperties(f, props);
        double area = props.Mass();
        if (area < 1.0) {
            sliverCount++;
            gp_Pnt c = props.CentreOfMass();
            std::printf("  sliver face %d: [plain]  area=%.12g centroid=(%.6g,%.6g,%.6g)\n",
                        faceIdx, area, c.X(), c.Y(), c.Z());
            GProp_GProps propsEps;
            double err = BRepGProp::SurfaceProperties(f, propsEps, 1e-6);
            gp_Pnt cEps = propsEps.CentreOfMass();
            std::printf("  sliver face %d: [Eps=1e-6] area=%.12g err=%.3g centroid=(%.6g,%.6g,%.6g)\n",
                        faceIdx, propsEps.Mass(), err, cEps.X(), cEps.Y(), cEps.Z());
        }
    }
    std::printf("gap=%.3g: total faces=%d, sliver faces (area<1.0)=%d\n\n",
                overlapGapFromTouching, faceIdx, sliverCount);
}

int main() {
    std::printf("=== overlap gap 0.0005mm (above BRepAlgoAPI's fuzzy tolerance) ===\n");
    runFusedOverlap(0.0005);

    std::printf("=== overlap gap 1e-7mm (at/below BRepAlgoAPI's default fuzzy tolerance) ===\n");
    runFusedOverlap(1e-7);
    return 0;
}
