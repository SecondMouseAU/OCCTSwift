// #536 ground truth: are BRepAlgoAPI_Defeaturing and BOPAlgo_RemoveFeatures one operation?
//
// The bridge wraps both: OCCTShapeDefeature drives BRepAlgoAPI_Defeaturing, OCCTBOPAlgoRemoveFeatures
// drives BOPAlgo_RemoveFeatures, and Swift spells them defeature(faces:) and removeFeatures(faces:).
// BRepAlgoAPI_Defeaturing::Build is a forwarder -- it hands its input shape, its faces, its history
// flag and its parallel flag to a BOPAlgo_RemoveFeatures member and takes that member's result. So
// the question is not "do they agree on a box", it is "is there ANY input on which they can differ".
//
// This probe drives each one exactly the way its bridge wrapper does, over a matrix of fixtures and
// face selections, and compares the full BREP serialisation rather than scalars -- volume and face
// count would not notice a differently-parameterised surface.
//
// It also measures the three places a difference could hide:
//   1. the option defaults each path inherits (history filling, parallel mode),
//   2. the completion test each bridge wrapper uses (IsDone() vs !HasErrors()),
//   3. the requests that are not ordinary: no faces, a face from another shape, an unremovable face.

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BOPAlgo_RemoveFeatures.hxx>
#include <BRepTools.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Surface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <gp_Ax2.hxx>
#include <TopoDS_Compound.hxx>
#include <BRep_Builder.hxx>
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

// --- The two bridge wrappers, transcribed ---
//
// OCCTShapeDefeature (OCCTBridge_Modeling.mm), via occtDefeaturePerform: SetShape, AddFacesToRemove,
// Build, IsDone, then a null check on the result.
struct Outcome {
    bool         accepted = false;   // what the wrapper's own check answered
    TopoDS_Shape shape;
    std::string  brep = "<not run>";
    bool         returnsShape = false;  // what the Swift caller would see: non-nil
};

static Outcome runDefeaturing(const TopoDS_Shape& shape, const TopTools_ListOfShape& faces) {
    Outcome o;
    BRepAlgoAPI_Defeaturing df;
    df.SetShape(shape);
    df.AddFacesToRemove(faces);
    df.Build();
    o.accepted = df.IsDone();
    if (!o.accepted) return o;
    o.shape = df.Shape();
    o.returnsShape = !o.shape.IsNull();
    o.brep = brepOf(o.shape);
    return o;
}

// OCCTBOPAlgoRemoveFeatures (OCCTBridge_Modeling.mm): SetShape, AddFaceToRemove per face, Perform,
// !HasErrors, then a null check on the result.
static Outcome runRemoveFeatures(const TopoDS_Shape& shape, const TopTools_ListOfShape& faces) {
    Outcome o;
    BOPAlgo_RemoveFeatures rf;
    rf.SetShape(shape);
    for (TopTools_ListOfShape::Iterator it(faces); it.More(); it.Next())
        rf.AddFaceToRemove(it.Value());
    rf.Perform();
    o.accepted = !rf.HasErrors();
    if (!o.accepted) return o;
    o.shape = rf.Shape();
    o.returnsShape = !o.shape.IsNull();
    o.brep = brepOf(o.shape);
    return o;
}

static int failures = 0;

static void compare(const char* label, const TopoDS_Shape& shape, const TopTools_ListOfShape& faces) {
    Outcome d = runDefeaturing(shape, faces);
    Outcome r = runRemoveFeatures(shape, faces);

    const bool sameAccept = (d.accepted == r.accepted);
    const bool sameReturn = (d.returnsShape == r.returnsShape);
    const bool sameBrep   = (d.brep == r.brep);
    const bool agree      = sameAccept && sameReturn && sameBrep;
    if (!agree) failures++;

    printf("  %-42s defeature[done=%d shape=%d vol=%.9f faces=%2d]  "
           "removeFeatures[ok=%d shape=%d vol=%.9f faces=%2d]  %s\n",
           label,
           d.accepted, d.returnsShape, volumeOf(d.shape), faceCount(d.shape),
           r.accepted, r.returnsShape, volumeOf(r.shape), faceCount(r.shape),
           agree ? "IDENTICAL BREP" : (sameAccept && sameReturn ? "*** BREP DIFFERS ***"
                                                                : "*** OUTCOME DIFFERS ***"));
}

static TopoDS_Shape filletedBox(double size, double radius) {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(size, size, size).Shape();
    BRepFilletAPI_MakeFillet fillet(box);
    TopExp_Explorer ex(box, TopAbs_EDGE);
    fillet.Add(radius, TopoDS::Edge(ex.Current()));
    fillet.Build();
    if (!fillet.IsDone()) return TopoDS_Shape();
    return fillet.Shape();
}

static TopoDS_Face firstCylindricalFace(const TopoDS_Shape& s) {
    for (TopExp_Explorer fe(s, TopAbs_FACE); fe.More(); fe.Next()) {
        TopoDS_Face f = TopoDS::Face(fe.Current());
        Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
        if (!surf.IsNull() && surf->IsKind(STANDARD_TYPE(Geom_CylindricalSurface))) return f;
    }
    return TopoDS_Face();
}

static TopTools_ListOfShape oneFace(const TopoDS_Shape& f) {
    TopTools_ListOfShape l;
    l.Append(f);
    return l;
}

int main() {
    printf("=== #536: BRepAlgoAPI_Defeaturing vs BOPAlgo_RemoveFeatures ===\n\n");

    // ------------------------------------------------------------------
    // 1. The options each path inherits, before any geometry is involved.
    //    BRepAlgoAPI_Defeaturing::Build forwards exactly these two to its BOPAlgo member; if the
    //    defaults differed, every unconfigured call would already be two different operations.
    // ------------------------------------------------------------------
    {
        BRepAlgoAPI_Defeaturing df;
        BOPAlgo_RemoveFeatures rf;
        printf("option defaults (nothing set on either):\n");
        printf("  history filling : defeaturing=%d removeFeatures=%d  %s\n",
               df.HasHistory(), rf.HasHistory(),
               df.HasHistory() == rf.HasHistory() ? "same" : "*** DIFFER ***");
        printf("  parallel mode   : defeaturing=%d removeFeatures=%d  %s\n",
               df.RunParallel(), rf.RunParallel(),
               df.RunParallel() == rf.RunParallel() ? "same" : "*** DIFFER ***");
        if (df.HasHistory() != rf.HasHistory() || df.RunParallel() != rf.RunParallel()) failures++;
        printf("\n");
    }

    // ------------------------------------------------------------------
    // 2. Ordinary removals, over fixtures whose features differ in kind.
    // ------------------------------------------------------------------
    printf("ordinary removals:\n");

    // 2a. The issue's fixture: a 20mm box, one 2mm fillet, remove the fillet face.
    TopoDS_Shape f20 = filletedBox(20.0, 2.0);
    if (f20.IsNull()) { printf("FAIL: fixture (filleted 20mm box)\n"); return 1; }
    TopoDS_Face fillet20 = firstCylindricalFace(f20);
    if (fillet20.IsNull()) { printf("FAIL: fixture (no fillet face)\n"); return 1; }
    compare("20mm box, remove fillet face", f20, oneFace(fillet20));

    // 2b. Every face of the filleted box in turn -- including the five planar ones the algorithm
    //     will refuse, so the refusal path is measured on both as well.
    {
        TopTools_IndexedMapOfShape faces;
        TopExp::MapShapes(f20, TopAbs_FACE, faces);
        for (int i = 1; i <= faces.Extent(); i++) {
            char label[64];
            snprintf(label, sizeof(label), "20mm box, remove face %d of %d", i, faces.Extent());
            compare(label, f20, oneFace(faces(i)));
        }
    }

    // 2c. A through hole: remove the cylindrical face, the textbook defeaturing case.
    {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(20.0, 20.0, 20.0).Shape();
        TopoDS_Shape drill = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(10, 10, -1), gp_Dir(0, 0, 1)),
                                                      3.0, 22.0).Shape();
        BRepAlgoAPI_Cut cut(box, drill);
        cut.Build();
        if (cut.IsDone()) {
            TopoDS_Shape holed = cut.Shape();
            TopoDS_Face hole = firstCylindricalFace(holed);
            if (!hole.IsNull()) compare("box with through hole, remove hole", holed, oneFace(hole));
        }
    }

    // 2d. A boss: remove all the faces the fuse added, as one multi-face request.
    {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(20.0, 20.0, 20.0).Shape();
        TopoDS_Shape boss = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(10, 10, 20), gp_Dir(0, 0, 1)),
                                                     4.0, 6.0).Shape();
        BRepAlgoAPI_Fuse fuse(box, boss);
        fuse.Build();
        if (fuse.IsDone()) {
            TopoDS_Shape bossed = fuse.Shape();
            TopTools_ListOfShape bossFaces;
            for (TopExp_Explorer fe(bossed, TopAbs_FACE); fe.More(); fe.Next()) {
                TopoDS_Face f = TopoDS::Face(fe.Current());
                Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
                if (!surf.IsNull() && surf->IsKind(STANDARD_TYPE(Geom_CylindricalSurface)))
                    bossFaces.Append(f);
            }
            if (!bossFaces.IsEmpty())
                compare("box with boss, remove boss faces", bossed, bossFaces);
        }
    }

    // 2e. Two features in one request, on one shape.
    {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(30.0, 30.0, 30.0).Shape();
        TopoDS_Shape d1 = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(8, 8, -1), gp_Dir(0, 0, 1)),
                                                   3.0, 32.0).Shape();
        TopoDS_Shape d2 = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(22, 22, -1), gp_Dir(0, 0, 1)),
                                                   3.0, 32.0).Shape();
        BRepAlgoAPI_Cut c1(box, d1);
        c1.Build();
        if (c1.IsDone()) {
            BRepAlgoAPI_Cut c2(c1.Shape(), d2);
            c2.Build();
            if (c2.IsDone()) {
                TopoDS_Shape twoHoles = c2.Shape();
                TopTools_ListOfShape holes;
                for (TopExp_Explorer fe(twoHoles, TopAbs_FACE); fe.More(); fe.Next()) {
                    TopoDS_Face f = TopoDS::Face(fe.Current());
                    Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
                    if (!surf.IsNull() && surf->IsKind(STANDARD_TYPE(Geom_CylindricalSurface)))
                        holes.Append(f);
                }
                if (holes.Extent() >= 2) compare("two holes, both removed at once", twoHoles, holes);
            }
        }
    }

    // ------------------------------------------------------------------
    // 3. The requests that are not ordinary. These are where two independently maintained
    //    wrappers are most likely to have drifted, so they matter more than the happy path.
    // ------------------------------------------------------------------
    printf("\nnon-ordinary requests:\n");

    // 3a. No faces at all. The bridge rejects this before reaching either algorithm, but what the
    //     algorithms themselves do decides whether that rejection is a bridge policy or a kernel one.
    {
        TopTools_ListOfShape none;
        compare("no faces requested", f20, none);
    }

    // 3b. A face that belongs to a different shape. BRepAlgoAPI_Defeaturing.hxx says faces that do
    //     not belong "will be ignored" -- measured here, on both paths, because a request that
    //     removes nothing and reports success is a contract worth stating out loud.
    {
        TopoDS_Shape other = filletedBox(11.0, 1.5);
        TopoDS_Face foreign = firstCylindricalFace(other);
        if (!foreign.IsNull()) compare("face from a different shape", f20, oneFace(foreign));
    }

    // 3c. A face that belongs, mixed with one that does not.
    {
        TopoDS_Shape other = filletedBox(11.0, 1.5);
        TopoDS_Face foreign = firstCylindricalFace(other);
        if (!foreign.IsNull()) {
            TopTools_ListOfShape mixed;
            mixed.Append(fillet20);
            mixed.Append(foreign);
            compare("one real face plus one foreign", f20, mixed);
        }
    }

    // 3d. A shape type the algorithm does not accept: only SOLID/COMPSOLID/COMPOUND-of-solids are
    //     supported, so a bare face must be refused -- by both, the same way.
    {
        TopoDS_Shape justAFace = fillet20;
        compare("input is a face, not a solid", justAFace, oneFace(fillet20));
    }

    // 3e. The same face twice in one request.
    {
        TopTools_ListOfShape twice;
        twice.Append(fillet20);
        twice.Append(fillet20);
        compare("the same face requested twice", f20, twice);
    }

    // ------------------------------------------------------------------
    // 4. What the shape-addressed form does with a face that is not part of the input, when the
    //    request also contains one that is. Both paths agree (section 3c), so this is not a
    //    divergence between them -- it is the surviving entry point's own contract, and #497 made
    //    the index-addressed sibling fail exactly this request.
    // ------------------------------------------------------------------
    printf("\nthe foreign face in a mixed request:\n");
    {
        TopoDS_Shape other = filletedBox(11.0, 1.5);
        TopoDS_Face foreign = firstCylindricalFace(other);
        TopTools_ListOfShape mixed;
        mixed.Append(fillet20);
        mixed.Append(foreign);

        BRepAlgoAPI_Defeaturing df;
        df.SetShape(f20);
        df.AddFacesToRemove(mixed);
        df.Build();
        printf("  done=%d  warnings=%d  volume=%.9f (8000 = the fillet went, nothing else did)\n",
               df.IsDone(), df.HasWarnings(), volumeOf(df.Shape()));
        if (df.HasWarnings()) {
            Standard_SStream ss;
            df.DumpWarnings(ss);
            printf("  warning text: %s", ss.str().c_str());
        } else {
            printf("  no warning of any kind: the unusable face is dropped in silence\n");
        }
    }

    // A face that is geometrically identical but a distinct TShape -- what a membership check
    // would have to treat as foreign, so worth knowing whether the kernel accepts it today.
    {
        TopoDS_Shape twin = filletedBox(20.0, 2.0);
        TopoDS_Face twinFillet = firstCylindricalFace(twin);
        BRepAlgoAPI_Defeaturing df;
        df.SetShape(f20);
        df.AddFaceToRemove(twinFillet);
        df.Build();
        printf("  same geometry, different TShape (a twin fixture's fillet face): done=%d volume=%.9f\n",
               df.IsDone(), volumeOf(df.Shape()));
    }

    // What "a face to remove" is allowed to be. AddFaceToRemove takes a TopoDS_Shape and its own
    // doc calls it "the shape to extract the faces for removal", so the argument is not necessarily
    // a face -- any membership precondition has to know what it would be rejecting.
    printf("\nwhat the request is allowed to contain:\n");
    {
        struct Case { const char* label; TopoDS_Shape requested; };
        std::vector<Case> cases;

        cases.push_back({"the fillet face, as found", fillet20});
        cases.push_back({"the same face, orientation reversed", fillet20.Reversed()});

        // A compound wrapping the fillet face: a caller holding a selection, not a single face.
        {
            TopoDS_Compound comp;
            BRep_Builder b;
            b.MakeCompound(comp);
            b.Add(comp, fillet20);
            cases.push_back({"a compound containing the fillet face", comp});
        }
        // The whole input solid: every face at once.
        cases.push_back({"the entire input solid", f20});
        // An edge of the fillet face: a shape with no faces in it at all.
        {
            TopExp_Explorer ee(fillet20, TopAbs_EDGE);
            if (ee.More()) cases.push_back({"an edge (contains no face)", ee.Current()});
        }

        for (const Case& c : cases) {
            BRepAlgoAPI_Defeaturing df;
            df.SetShape(f20);
            df.AddFaceToRemove(c.requested);
            df.Build();
            printf("  %-40s done=%d volume=%.9f faces=%d\n",
                   c.label, df.IsDone(), volumeOf(df.Shape()), faceCount(df.Shape()));
        }
    }

    printf("\nVERDICT: %s\n",
           failures == 0
             ? "every case agrees, BREP byte for byte -- one operation under two names"
             : "*** the two paths diverge somewhere: see the marked rows ***");
    return failures == 0 ? 0 : 1;
}
