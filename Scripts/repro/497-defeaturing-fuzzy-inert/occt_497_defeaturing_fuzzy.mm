// #497 ground truth: does BRepAlgoAPI_Defeaturing honour SetFuzzyValue?
//
// The bridge has two shape-based defeaturing wrappers whose ONLY difference is that one
// calls SetFuzzyValue(fuzzyTol). This test asks whether that call does anything at all.
//
// Control: BRepAlgoAPI_Cut, a BOP that genuinely honours the fuzzy value, on the same
// magnitudes -- so a null result for Defeaturing means "ignored", not "too small to matter".

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepTools.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Surface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <gp_Ax2.hxx>
#include <sstream>
#include <string>
#include <cstdio>

static double volumeOf(const TopoDS_Shape& s) {
    GProp_GProps props;
    BRepGProp::VolumeProperties(s, props);
    return props.Mass();
}

static int faceCount(const TopoDS_Shape& s) {
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(s, TopAbs_FACE, m);
    return m.Extent();
}

// A full BREP serialisation: catches any geometric difference the scalars would miss.
static std::string brepOf(const TopoDS_Shape& s) {
    std::ostringstream os;
    BRepTools::Write(s, os);
    return os.str();
}

int main() {
    // --- Build a 10mm box with one filleted edge; the fillet face is the "feature". ---
    TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
    BRepFilletAPI_MakeFillet fillet(box);
    TopExp_Explorer ex(box, TopAbs_EDGE);
    fillet.Add(2.0, TopoDS::Edge(ex.Current()));
    fillet.Build();
    if (!fillet.IsDone()) { printf("FAIL: fillet\n"); return 1; }
    TopoDS_Shape filleted = fillet.Shape();

    // The fillet face is the only cylindrical one.
    TopoDS_Face featureFace;
    for (TopExp_Explorer fe(filleted, TopAbs_FACE); fe.More(); fe.Next()) {
        TopoDS_Face f = TopoDS::Face(fe.Current());
        Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
        if (!surf.IsNull() && surf->IsKind(STANDARD_TYPE(Geom_CylindricalSurface))) {
            featureFace = f;
            break;
        }
    }
    if (featureFace.IsNull()) { printf("FAIL: no fillet face found\n"); return 1; }

    printf("input: volume=%.9f faces=%d\n", volumeOf(filleted), faceCount(filleted));

    // --- Defeature the same face at wildly different fuzzy values. ---
    // 10.0 is the box's whole edge length: any algorithm that honoured a fuzzy value of
    // that magnitude could not possibly return the same shape as one at 0.
    const double fuzz[] = { 0.0, 1e-7, 0.01, 1.0, 10.0, 100.0 };
    std::string baseline;
    bool allIdentical = true;

    for (double f : fuzz) {
        BRepAlgoAPI_Defeaturing df;
        df.SetShape(filleted);
        df.AddFaceToRemove(featureFace);
        if (f > 0) df.SetFuzzyValue(f);
        df.Build();
        if (!df.IsDone()) { printf("  fuzzy=%-8g NOT DONE\n", f); allIdentical = false; continue; }
        TopoDS_Shape r = df.Shape();
        std::string brep = brepOf(r);
        if (baseline.empty()) baseline = brep;
        bool same = (brep == baseline);
        allIdentical = allIdentical && same;
        printf("  fuzzy=%-8g stored=%-10g volume=%.9f faces=%d brep=%s\n",
               f, df.FuzzyValue(), volumeOf(r), faceCount(r), same ? "IDENTICAL" : "DIFFERENT");
    }

    printf("\nDefeaturing: fuzzy value %s\n",
           allIdentical ? "made NO difference at any magnitude" : "changed the result");

    // --- Control: BRepAlgoAPI_Cut on the same magnitudes. ---
    // A fuzzy value this large visibly perturbs an algorithm that honours it.
    printf("\ncontrol (BRepAlgoAPI_Cut, an honouring BOP):\n");
    TopoDS_Shape tool = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(5, 5, -1), gp_Dir(0, 0, 1)),
                                                 2.0, 12.0).Shape();
    std::string cutBaseline;
    bool cutAllIdentical = true;
    for (double f : fuzz) {
        BRepAlgoAPI_Cut cut(box, tool);
        cut.SetFuzzyValue(f > 0 ? f : 0.0);
        cut.Build();
        if (!cut.IsDone()) { printf("  fuzzy=%-8g NOT DONE\n", f); continue; }
        TopoDS_Shape r = cut.Shape();
        std::string brep = brepOf(r);
        if (cutBaseline.empty()) cutBaseline = brep;
        bool same = (brep == cutBaseline);
        cutAllIdentical = cutAllIdentical && same;
        printf("  fuzzy=%-8g stored=%-10g volume=%.9f faces=%d brep=%s\n",
               f, cut.FuzzyValue(), volumeOf(r), faceCount(r), same ? "IDENTICAL" : "DIFFERENT");
    }
    printf("\nCut: fuzzy value %s\n",
           cutAllIdentical ? "made no difference (control INVALID)" : "changed the result (control valid)");

    printf("\nVERDICT: %s\n",
           (allIdentical && !cutAllIdentical)
             ? "SetFuzzyValue is INERT on BRepAlgoAPI_Defeaturing (control proves the magnitudes bite)"
             : "inconclusive");
    return 0;
}
