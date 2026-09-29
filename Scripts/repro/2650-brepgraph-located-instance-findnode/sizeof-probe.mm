// #2833 review of #2650: what one entry in `OCCTBRepGraph::locatedInputSubShapes` costs, measured
// rather than reasoned about, so the comment on that member can carry a number.
//
// `TopTools_MapOfShape` is `NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher>`, whose storage is
// a bucket array of pointers plus one `NCollection_TListNode<TopoDS_Shape>` per entry. So the per
// entry cost is sizeof(node), and the fixed cost is one pointer per bucket, with the bucket count
// growing to roughly the entry count.
//
// Built against the pinned v4.0.0-kernel.2 asset SwiftPM resolves, so the slice directory carries
// the scratch name of whatever checkout ran it. `-framework AppKit` and `-framework CoreGraphics` are
// needed on top of CLAUDE.md's line, because the archive drags in Cocoa_Window.mm.o.
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I".build/artifacts/<scratch>/OCCT/OCCT.xcframework/macos-arm64/Headers" \
//     -L".build/artifacts/<scratch>/OCCT/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -framework CoreGraphics -lz -lc++ \
//     Scripts/repro/2650-brepgraph-located-instance-findnode/sizeof-probe.mm -o /tmp/occt_sizeof
//   /tmp/occt_sizeof
//
// Measured 2026-09-29, arm64 macOS:
//
//   sizeof(TopoDS_Shape)                        = 24
//   sizeof(TopLoc_Location)                     = 8
//   sizeof(NCollection_TListNode<TopoDS_Shape>) = 32
//   sizeof(TopTools_MapOfShape)                 = 56
//   sizeof(void*)                               = 8
//
// So one located sub-shape costs 32 bytes of node plus one 8-byte bucket pointer, about 40 bytes
// before the allocator's own per-block rounding, and the map itself is 56 bytes empty. A shape is a
// handle, a location and an orientation: the map holds no geometry and copies none.

#include <NCollection_TListNode.hxx>
#include <TopTools_MapOfShape.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>

int main()
{
  std::printf("sizeof(TopoDS_Shape)                        = %zu\n", sizeof(TopoDS_Shape));
  std::printf("sizeof(TopLoc_Location)                     = %zu\n", sizeof(TopLoc_Location));
  std::printf("sizeof(NCollection_TListNode<TopoDS_Shape>) = %zu\n",
              sizeof(NCollection_TListNode<TopoDS_Shape>));
  std::printf("sizeof(TopTools_MapOfShape)                 = %zu\n", sizeof(TopTools_MapOfShape));
  std::printf("sizeof(void*)                               = %zu\n", sizeof(void*));
  return 0;
}
