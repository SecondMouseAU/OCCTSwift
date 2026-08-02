// #578 ground truth: what may a "face to remove" be, and what belongs to the shape?
//
// BRepAlgoAPI_Defeaturing::AddFaceToRemove takes a TopoDS_Shape, and its own documentation calls it
// "the shape to extract the faces for removal" -- so the argument need not be a face, and the header
// says outright that faces which do not belong to the input "will be ignored". The bridge's
// shape-addressed entry point (OCCTShapeDefeature -> Shape.defeature(faces:)) passes the caller's
// shapes straight through, so it inherits both properties: a foreign face is dropped in silence, and
// a compound / shell / whole solid is a legal way to name faces.
//
// The index-addressed spelling (Shape.withoutFeatures(faces:)) fails the whole call on one bad index
// (#497). Before giving the shape-addressed one a matching rule, this probe measures the matrix that
// rule has to cover, on the pinned OCCT 8.0.0p1 kernel:
//
//   1. Which carriers the kernel accepts, and what it does with each.
//   2. Whether a carrier's faces can be checked against the input's own TopExp face map, and whether
//      that map's IsSame-based hashing treats a reversed face as belonging (it must -- the kernel
//      itself accepts one).
//   3. Whether exploding a carrier to its faces up front is the same request as passing the carrier
//      (BREP byte for byte), which is what lets the bridge check membership at all.
//   4. What a carrier that mixes belonging and foreign faces does today.
//
// No fixture files: every shape is built from a primitive.

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepTools.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Surface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <TopLoc_Location.hxx>
#include <sstream>
#include <string>
#include <vector>
#include <cstdio>

static double volumeOf(const TopoDS_Shape& s) {
    if (s.IsNull()) return 0.0;
    GProp_GProps props;
    BRepGProp::VolumeProperties(s, props);
    return props.Mass();
}

static int faceCount(const TopoDS_Shape& s) {
    if (s.IsNull()) return 0;
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(s, TopAbs_FACE, m);
    return m.Extent();
}

// The full BREP text: any difference in geometry, parameterisation or topology order shows here.
static std::string brepOf(const TopoDS_Shape& s) {
    if (s.IsNull()) return "<null>";
    std::ostringstream os;
    BRepTools::Write(s, os);
    return os.str();
}

// A 20mm box with one 2mm fillet: 7 faces, the 7th being the fillet.
static TopoDS_Shape filletedBox(double size, double radius) {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(size, size, size).Shape();
    BRepFilletAPI_MakeFillet fillet(box);
    TopExp_Explorer exp(box, TopAbs_EDGE);
    if (!exp.More()) return TopoDS_Shape();
    fillet.Add(radius, TopoDS::Edge(exp.Current()));
    fillet.Build();
    if (!fillet.IsDone()) return TopoDS_Shape();
    return fillet.Shape();
}

// The face the fillet added: the only cylindrical one on an otherwise planar box. It is not the
// last face in the map -- position in the face map is not a property to rely on.
static TopoDS_Face filletFaceOf(const TopoDS_Shape& filleted) {
    TopTools_IndexedMapOfShape m;
    TopExp::MapShapes(filleted, TopAbs_FACE, m);
    for (int i = 1; i <= m.Extent(); i++) {
        TopoDS_Face f = TopoDS::Face(m(i));
        TopLoc_Location loc;
        Handle(Geom_Surface) surf = BRep_Tool::Surface(f, loc);
        if (!surf.IsNull() && surf->IsKind(STANDARD_TYPE(Geom_CylindricalSurface))) return f;
    }
    return TopoDS_Face();
}

static TopoDS_Shape compoundOf(const std::vector<TopoDS_Shape>& parts) {
    BRep_Builder builder;
    TopoDS_Compound c;
    builder.MakeCompound(c);
    for (const auto& p : parts) builder.Add(c, p);
    return c;
}

struct Outcome {
    bool done = false;
    double volume = 0.0;
    int faces = 0;
    std::string brep;
};

// Driven exactly the way the bridge's occtDefeaturePerform drives it.
static Outcome defeature(const TopoDS_Shape& input, const std::vector<TopoDS_Shape>& carriers) {
    Outcome o;
    try {
        TopTools_ListOfShape list;
        for (const auto& c : carriers) list.Append(c);
        BRepAlgoAPI_Defeaturing op;
        op.SetShape(input);
        op.AddFacesToRemove(list);
        op.Build();
        o.done = op.IsDone();
        if (!o.done) return o;
        TopoDS_Shape r = op.Shape();
        if (r.IsNull()) { o.done = false; return o; }
        o.volume = volumeOf(r);
        o.faces = faceCount(r);
        o.brep = brepOf(r);
    } catch (...) {
        o.done = false;
    }
    return o;
}

// The membership test the bridge would apply: explode the carrier for faces, check each against the
// input's own face map. Reported, not enforced, so the two can be compared side by side.
struct Membership {
    int facesInCarrier = 0;
    int belonging = 0;
    int foreign = 0;
};

static Membership membershipOf(const TopTools_IndexedMapOfShape& inputFaces, const TopoDS_Shape& carrier) {
    Membership m;
    for (TopExp_Explorer exp(carrier, TopAbs_FACE); exp.More(); exp.Next()) {
        m.facesInCarrier++;
        if (inputFaces.Contains(exp.Current())) m.belonging++;
        else m.foreign++;
    }
    return m;
}

static int failures = 0;

static void expectTrue(bool cond, const char* what) {
    if (!cond) { printf("  ** FAILED: %s\n", what); failures++; }
}

int main() {
    const double kSize = 20.0, kRadius = 2.0;

    TopoDS_Shape input = filletedBox(kSize, kRadius);
    if (input.IsNull()) { printf("fixture failed\n"); return 1; }
    TopoDS_Face fillet = filletFaceOf(input);

    TopTools_IndexedMapOfShape inputFaces;
    TopExp::MapShapes(input, TopAbs_FACE, inputFaces);

    printf("fixture: %.0fmm box, %.0fmm fillet -- volume=%.9f faces=%d\n",
           kSize, kRadius, volumeOf(input), inputFaces.Extent());

    // A control: removing the fillet face restores the plain box. Everything below is measured
    // against this, so it has to hold first.
    Outcome control = defeature(input, {fillet});
    printf("control: remove the fillet face -- done=%d volume=%.9f faces=%d\n\n",
           control.done, control.volume, control.faces);
    expectTrue(control.done && control.faces == 6, "control: the fillet face is removable");

    // A second shape, and a separately built twin of the fixture.
    TopoDS_Shape other = BRepPrimAPI_MakeBox(11.0, 11.0, 11.0).Shape();
    TopTools_IndexedMapOfShape otherFaces;
    TopExp::MapShapes(other, TopAbs_FACE, otherFaces);
    TopoDS_Face foreignFace = TopoDS::Face(otherFaces(1));

    TopoDS_Shape twin = filletedBox(kSize, kRadius);
    TopoDS_Face twinFillet = filletFaceOf(twin);

    // The input's own shell, and sub-shapes that carry no face at all.
    TopoDS_Shape inputShell;
    for (TopExp_Explorer exp(input, TopAbs_SHELL); exp.More(); exp.Next()) { inputShell = exp.Current(); break; }
    TopoDS_Shape anEdge;
    for (TopExp_Explorer exp(input, TopAbs_EDGE); exp.More(); exp.Next()) { anEdge = exp.Current(); break; }
    TopoDS_Shape aVertex;
    for (TopExp_Explorer exp(input, TopAbs_VERTEX); exp.More(); exp.Next()) { aVertex = exp.Current(); break; }

    TopoDS_Shape reversedFillet = fillet.Reversed();

    // ---------------------------------------------------------------------------------------
    printf("=== 1. carriers, one at a time: what the kernel does, and what membership says ===\n");
    printf("%-42s  %-28s  %s\n", "carrier", "kernel", "membership (faces/belong/foreign)");

    struct Case { const char* name; TopoDS_Shape carrier; };
    std::vector<Case> cases = {
        { "the fillet face",                        fillet },
        { "the fillet face, reversed",              reversedFillet },
        { "a compound holding the fillet face",     compoundOf({fillet}) },
        { "the input's own shell",                  inputShell },
        { "the whole input solid",                  input },
        { "a face of a different shape",            foreignFace },
        { "the whole different shape",              other },
        { "an identically built twin's face",       twinFillet },
        { "an edge of the input",                   anEdge },
        { "a vertex of the input",                  aVertex },
        { "an empty compound",                      compoundOf({}) },
    };

    for (const auto& c : cases) {
        Outcome o = defeature(input, {c.carrier});
        Membership m = membershipOf(inputFaces, c.carrier);
        char kernel[64];
        if (o.done) snprintf(kernel, sizeof(kernel), "done=1 vol=%.6f faces=%d", o.volume, o.faces);
        else        snprintf(kernel, sizeof(kernel), "done=0");
        printf("  %-40s  %-28s  %d / %d / %d\n", c.name, kernel, m.facesInCarrier, m.belonging, m.foreign);
    }
    printf("\n");

    // The two claims the membership check rests on, asserted rather than eyeballed.
    expectTrue(inputFaces.Contains(reversedFillet),
               "the input's face map contains the reversed fillet face (IsSame hashing)");
    expectTrue(!inputFaces.Contains(twinFillet),
               "the input's face map does not contain an identically built twin's face");

    // ---------------------------------------------------------------------------------------
    printf("=== 2. a carrier that mixes belonging and foreign faces ===\n");
    TopoDS_Shape mixedCarrier = compoundOf({fillet, foreignFace});
    Outcome mixed = defeature(input, {mixedCarrier});
    Membership mixedM = membershipOf(inputFaces, mixedCarrier);
    printf("  compound{fillet face, foreign face}     done=%d vol=%.6f faces=%d   membership %d / %d / %d\n",
           mixed.done, mixed.volume, mixed.faces, mixedM.facesInCarrier, mixedM.belonging, mixedM.foreign);

    Outcome mixedRequest = defeature(input, {fillet, foreignFace});
    printf("  two carriers: fillet face + foreign     done=%d vol=%.6f faces=%d\n",
           mixedRequest.done, mixedRequest.volume, mixedRequest.faces);

    // A carrier that names no face at all is dropped by the same silence, not just a foreign one.
    Outcome withEdge = defeature(input, {fillet, anEdge});
    Outcome withEmpty = defeature(input, {fillet, compoundOf({})});
    printf("  two carriers: fillet face + an edge     done=%d vol=%.6f faces=%d\n",
           withEdge.done, withEdge.volume, withEdge.faces);
    printf("  two carriers: fillet face + empty cmpd  done=%d vol=%.6f faces=%d\n",
           withEmpty.done, withEmpty.volume, withEmpty.faces);
    printf("  ... every one of these removes the fillet and nothing else, silently: %s\n\n",
           (mixed.brep == control.brep && mixedRequest.brep == control.brep &&
            withEdge.brep == control.brep && withEmpty.brep == control.brep) ? "yes" : "NO");
    expectTrue(mixed.brep == control.brep && mixedRequest.brep == control.brep &&
               withEdge.brep == control.brep && withEmpty.brep == control.brep,
               "a mixed request today equals the belonging-faces-only request, BREP for BREP");

    // ---------------------------------------------------------------------------------------
    printf("=== 3. exploding a carrier is the same request as passing it ===\n");
    // This is what makes the check implementable: the bridge can replace each carrier with the faces
    // it explores, and the kernel must not notice.
    struct ExplodeCase { const char* name; TopoDS_Shape carrier; };
    std::vector<ExplodeCase> explodeCases = {
        { "a compound holding the fillet face", compoundOf({fillet}) },
        { "the input's own shell",              inputShell },
        { "the whole input solid",              input },
        { "the fillet face, reversed",          reversedFillet },
    };
    for (const auto& c : explodeCases) {
        std::vector<TopoDS_Shape> exploded;
        for (TopExp_Explorer exp(c.carrier, TopAbs_FACE); exp.More(); exp.Next()) exploded.push_back(exp.Current());
        Outcome asCarrier = defeature(input, {c.carrier});
        Outcome asFaces = defeature(input, exploded);
        bool same = asCarrier.done == asFaces.done && asCarrier.brep == asFaces.brep;
        printf("  %-40s  carrier[done=%d faces=%d]  exploded[done=%d faces=%d]  %s\n",
               c.name, asCarrier.done, asCarrier.faces, asFaces.done, asFaces.faces,
               same ? "IDENTICAL BREP" : "** DIFFERENT **");
        expectTrue(same, "exploding a carrier does not change the request");
    }
    printf("\n");

    // ---------------------------------------------------------------------------------------
    printf("=== 4. the same face named twice, and a carrier naming it twice ===\n");
    Outcome twice = defeature(input, {fillet, fillet});
    Outcome twiceInOne = defeature(input, {compoundOf({fillet, fillet})});
    printf("  two carriers, same face                 done=%d vol=%.6f faces=%d  %s\n",
           twice.done, twice.volume, twice.faces,
           twice.brep == control.brep ? "IDENTICAL BREP" : "** DIFFERENT **");
    printf("  one compound, same face twice           done=%d vol=%.6f faces=%d  %s\n",
           twiceInOne.done, twiceInOne.volume, twiceInOne.faces,
           twiceInOne.brep == control.brep ? "IDENTICAL BREP" : "** DIFFERENT **");
    expectTrue(twice.brep == control.brep && twiceInOne.brep == control.brep,
               "a duplicate face is harmless, however it is named");
    printf("\n");

    // ---------------------------------------------------------------------------------------
    printf("=== 5. removing everything ===\n");
    // The whole-solid carrier is a legal request whose every face belongs, so a membership rule
    // cannot reject it -- worth knowing what it does.
    std::vector<TopoDS_Shape> allFaces;
    for (int i = 1; i <= inputFaces.Extent(); i++) allFaces.push_back(inputFaces(i));
    Outcome everything = defeature(input, allFaces);
    printf("  every face of the input                 done=%d vol=%.6f faces=%d  %s\n",
           everything.done, everything.volume, everything.faces,
           everything.brep == brepOf(input) ? "the input, unchanged" : "changed");
    printf("\n");

    // ---------------------------------------------------------------------------------------
    printf("=== 6. what the chosen rule decides, over the same matrix ===\n");
    // The rule the bridge now applies: every shape in the request must contribute at least one face,
    // and every face it contributes must be a face of the input. Printed against what the kernel
    // does today so the two can be read side by side.
    printf("%-42s  %-10s  %s\n", "request", "today", "chosen rule");

    struct RuleCase { const char* name; std::vector<TopoDS_Shape> carriers; };
    std::vector<RuleCase> ruleCases = {
        { "the fillet face",                        { fillet } },
        { "the fillet face, reversed",              { reversedFillet } },
        { "a compound holding the fillet face",     { compoundOf({fillet}) } },
        { "the input's own shell",                  { inputShell } },
        { "the whole input solid",                  { input } },
        { "the same face named twice",              { fillet, fillet } },
        { "a face of a different shape",            { foreignFace } },
        { "the whole different shape",              { other } },
        { "an identically built twin's face",       { twinFillet } },
        { "an edge of the input",                   { anEdge } },
        { "an empty compound",                      { compoundOf({}) } },
        { "fillet face + a foreign face",           { fillet, foreignFace } },
        { "compound{fillet face, foreign face}",    { compoundOf({fillet, foreignFace}) } },
        { "fillet face + an edge",                  { fillet, anEdge } },
        { "fillet face + an empty compound",        { fillet, compoundOf({}) } },
        { "nothing at all",                         {} },
    };

    for (const auto& c : ruleCases) {
        Outcome o = defeature(input, c.carriers);
        bool accepted = !c.carriers.empty();
        for (const auto& carrier : c.carriers) {
            Membership m = membershipOf(inputFaces, carrier);
            if (m.facesInCarrier == 0 || m.foreign > 0) { accepted = false; break; }
        }
        printf("  %-40s  %-10s  %s\n", c.name,
               o.done ? "succeeds" : "fails",
               accepted ? "accepted" : "REFUSED");
    }
    printf("\n");

    printf(failures == 0 ? "VERDICT: every claim above holds on the pinned kernel\n"
                         : "VERDICT: %d claim(s) FAILED\n", failures);
    return failures == 0 ? 0 : 1;
}
