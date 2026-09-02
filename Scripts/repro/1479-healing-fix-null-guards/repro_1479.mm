// #1479: OCCTShapeFixComposeShell had no guard at all (uncatchable SIGSEGV on a nullified
// shape); OCCTShapeFixEdgeConnect had no `if (!shape) return nullptr;` (uncatchable SIGSEGV
// on a genuinely-null OCCTShapeRef pointer).
//
// This is a standalone repro, not the real bridge: OCCTShapeFixComposeShell and
// OCCTShapeFixEdgeConnect are `static`-linked into the OCCTBridge object files, so the only
// way to exercise the exact pre-fix and post-fix bodies side by side in one process is to
// reproduce both bodies here verbatim (see BUGGY_* / FIXED_* below) rather than override-link
// a single translation unit against the archive, which is the technique this project's other
// single-function guard repros use when the function in question is easy to isolate.
//
// Usage: repro_1479 <mode>
//   composeshell-buggy   -- OCCTShapeFixComposeShell body with no guard, on a nullified shape
//                            (expect SIGSEGV / uncatchable crash, exit 139)
//   composeshell-fixed   -- same body, `occtShapeIsPresent`-equivalent guard added
//                            (expect a clean nullptr return, exit 0)
//   edgeconnect-buggy    -- OCCTShapeFixEdgeConnect body with no guard, on a null pointer
//                            (expect SIGSEGV / uncatchable crash, exit 139)
//   edgeconnect-fixed    -- same body, `if (!shape) return nullptr;` added
//                            (expect a clean nullptr return, exit 0)
//
// Compile (from the repo root, or point -I/-L at any checkout's xcframework):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1479-healing-fix-null-guards/repro_1479.mm -o /tmp/repro_1479
//
// Run all four modes and print exit codes:
//   for m in composeshell-buggy composeshell-fixed edgeconnect-buggy edgeconnect-fixed; do
//     /tmp/repro_1479 "$m"; echo "$m -> exit $?"
//   done

#include <BRep_Tool.hxx>
#include <Geom_Surface.hxx>
#include <NCollection_HArray2.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeExtend_CompositeSurface.hxx>
#include <ShapeFix_ComposeShell.hxx>
#include <ShapeFix_EdgeConnect.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <cstdio>
#include <cstring>

// Minimal stand-in for the real bridge's `struct OCCTShape` (OCCTBridge_Internal.h).
struct OCCTShape {
  TopoDS_Shape shape;
  OCCTShape() {}
  OCCTShape(const TopoDS_Shape &s) : shape(s) {}
};
typedef OCCTShape *OCCTShapeRef;

static bool occtShapeIsPresentLike(OCCTShapeRef shape) { return shape && !shape->shape.IsNull(); }

// --- OCCTShapeFixComposeShell, pre-#1479 body (no guard) ---
static OCCTShapeRef composeShellBuggy(OCCTShapeRef faceRef, double precision) {
  try {
    const TopoDS_Shape &shape = *(const TopoDS_Shape *)faceRef;
    TopoDS_Face face = TopoDS::Face(shape);
    Handle(Geom_Surface) surf = BRep_Tool::Surface(face); // crash point on a nullified shape
    if (surf.IsNull())
      return nullptr;
    Handle(NCollection_HArray2<Handle(Geom_Surface)>) grid =
        new NCollection_HArray2<Handle(Geom_Surface)>(1, 1, 1, 1);
    grid->SetValue(1, 1, surf);
    Handle(ShapeExtend_CompositeSurface) compSurf = new ShapeExtend_CompositeSurface(grid);
    Handle(ShapeFix_ComposeShell) cs = new ShapeFix_ComposeShell();
    cs->SetContext(new ShapeBuild_ReShape());
    cs->Init(compSurf, TopLoc_Location(), face, precision);
    bool ok = cs->Perform();
    if (ok) {
      const TopoDS_Shape &result = cs->Result();
      if (!result.IsNull())
        return (OCCTShapeRef) new TopoDS_Shape(result);
    }
    return nullptr;
  } catch (...) {
    return nullptr;
  }
}

// --- OCCTShapeFixComposeShell, post-#1479 body (occtShapeIsPresent guard added) ---
static OCCTShapeRef composeShellFixed(OCCTShapeRef faceRef, double precision) {
  if (!occtShapeIsPresentLike(faceRef))
    return nullptr;
  return composeShellBuggy(faceRef, precision);
}

// --- OCCTShapeFixEdgeConnect, pre-#1479 body (no guard) ---
static OCCTShapeRef edgeConnectBuggy(OCCTShapeRef shape) {
  try {
    ShapeFix_EdgeConnect connector;
    connector.Add(shape->shape); // crash point on a null pointer
    connector.Build();
    auto *ref = new OCCTShape();
    ref->shape = shape->shape;
    return ref;
  } catch (...) {
    return nullptr;
  }
}

// --- OCCTShapeFixEdgeConnect, post-#1479 body (`if (!shape) return nullptr;` added) ---
static OCCTShapeRef edgeConnectFixed(OCCTShapeRef shape) {
  if (!shape)
    return nullptr;
  return edgeConnectBuggy(shape);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: %s <composeshell-buggy|composeshell-fixed|edgeconnect-buggy|edgeconnect-fixed>\n",
            argv[0]);
    return 2;
  }
  const char *mode = argv[1];

  if (strcmp(mode, "composeshell-buggy") == 0 || strcmp(mode, "composeshell-fixed") == 0) {
    // A non-null OCCTShapeRef wrapping a null TopoDS_Shape, exactly what `Shape.nullified`
    // produces via `TopoDS_Shape::Nullify()`.
    TopoDS_Shape nulled;
    nulled.Nullify();
    OCCTShape wrapper(nulled);
    OCCTShapeRef ref = &wrapper;

    OCCTShapeRef result = (strcmp(mode, "composeshell-buggy") == 0) ? composeShellBuggy(ref, 1e-6)
                                                                     : composeShellFixed(ref, 1e-6);
    printf("%s: result = %p (expected: 0x0)\n", mode, (void *)result);
    return result == nullptr ? 0 : 1;
  }

  if (strcmp(mode, "edgeconnect-buggy") == 0 || strcmp(mode, "edgeconnect-fixed") == 0) {
    // A genuinely-null OCCTShapeRef pointer.
    OCCTShapeRef nullRef = nullptr;
    OCCTShapeRef result =
        (strcmp(mode, "edgeconnect-buggy") == 0) ? edgeConnectBuggy(nullRef) : edgeConnectFixed(nullRef);
    printf("%s: result = %p (expected: 0x0)\n", mode, (void *)result);
    return result == nullptr ? 0 : 1;
  }

  fprintf(stderr, "unknown mode: %s\n", mode);
  return 2;
}
