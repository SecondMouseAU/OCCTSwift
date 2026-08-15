// Drives the REAL OCCTSectionBuilder* bridge functions, compiled straight from
// Sources/OCCTBridge/src/OCCTBridge_Modeling.mm with no modifications, to prove #916 live at the
// bridge boundary: a builder that already built successfully once keeps built==true through a
// later, cleanly-failed rebuild (BRepAlgoAPI_Section::Build() reporting !IsDone(), no exception) —
// and the unfixed code doesn't just answer with stale data, it SIGSEGVs.
//
// The failure trigger is a hand-constructed OCCTShape wrapping a genuinely NULL TopoDS_Shape,
// verified separately (see section_repro_scenarios.mm / README.md) to be the one input that makes
// BRepAlgoAPI_Section::Build() cleanly report IsDone()==false with no exception on a REUSED
// builder — BOPAlgo_PaveFiller::Init()'s own `if (aIt.Value().IsNull()) { AddError(new
// BOPAlgo_AlertNullInputShapes); return; }` check. This exact null-shape trigger is not reachable
// through OCCTSwift's public Swift API (Shape never wraps a null TopoDS_Shape — see the README's
// 13-scenario sweep), so this probe drives the bridge's own C functions directly, mirroring the
// OCCTShape struct exactly as Sources/OCCTBridge/src/OCCTBridge_Internal.h defines it.
#include <iostream>
#include <OCCTBridge.h>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <TopoDS_Shape.hxx>
#include <TopExp_Explorer.hxx>
#include <TopAbs_ShapeEnum.hxx>

struct OCCTShape {
    TopoDS_Shape shape;
    OCCTShape() {}
    OCCTShape(const TopoDS_Shape& s) : shape(s) {}
};

int main() {
    OCCTShape boxShape(BRepPrimAPI_MakeBox(10, 10, 10).Shape());
    OCCTShape sphereShape(BRepPrimAPI_MakeSphere(6).Shape());
    OCCTShape nullShape; // default TopoDS_Shape() - IsNull() == true

    OCCTSectionBuilderRef builder = OCCTSectionBuilderCreate();
    if (!builder) { std::cout << "FAIL: could not create builder" << std::endl; return 1; }

    OCCTSectionBuilderInit1Shape(builder, (OCCTShapeRef)&boxShape);
    OCCTSectionBuilderInit2Shape(builder, (OCCTShapeRef)&sphereShape);

    OCCTShapeRef firstResult = OCCTSectionBuilderBuild(builder);
    std::cout << "1st build result != nullptr: " << (firstResult != nullptr) << std::endl;

    TopExp_Explorer exp(boxShape.shape, TopAbs_EDGE);
    OCCTShapeRef edgeProbe = nullptr;
    OCCTShape edgeWrap;
    if (exp.More()) {
        edgeWrap = OCCTShape(exp.Current());
        edgeProbe = (OCCTShapeRef)&edgeWrap;
    }

    if (edgeProbe) {
        OCCTShapeRef anc1 = OCCTSectionBuilderAncestorFaceOn1(builder, edgeProbe);
        std::cout << "ancestorFaceOn1 after successful build (informational; this probe uses an "
                     "arbitrary box edge, not necessarily a section edge): "
                  << (anc1 != nullptr) << std::endl;
    }

    // Reuse the SAME builder: rebind arg1 to a genuinely NULL shape (the proven clean-failure
    // trigger) and rebuild.
    OCCTSectionBuilderInit1Shape(builder, (OCCTShapeRef)&nullShape);
    OCCTShapeRef secondResult = OCCTSectionBuilderBuild(builder);
    std::cout << "2nd build (after Init1 with a null shape) result != nullptr "
                 "(should be 0 -- build() should report failure): "
              << (secondResult != nullptr) << std::endl;

    // THE BUG (unfixed code): ancestorFaceOn1/2 are gated on builder->built, which
    // OCCTSectionBuilderBuild only ever sets true on success and never resets on the failed-
    // rebuild path. Pre-fix this SIGSEGVs (BOPAlgo_PaveFiller::Init() bailed before setting its
    // own myDS, so HasAncestorFaceOn1 dereferences it uninitialized). Post-fix it cleanly
    // returns nullptr.
    if (edgeProbe) {
        OCCTShapeRef ancAfterFailedRebuild = OCCTSectionBuilderAncestorFaceOn1(builder, edgeProbe);
        std::cout << "ancestorFaceOn1 after FAILED rebuild (should be 0): "
                  << (ancAfterFailedRebuild != nullptr) << std::endl;
    }

    OCCTSectionBuilderRelease(builder);
    return 0;
}
