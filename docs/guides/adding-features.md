# Adding Features to OCCTSwift

This guide explains how to add new OCCT functionality to the OCCTSwift wrapper.

## Overview

Adding a feature requires changes at three layers:

1. **OCCTBridge.h** - C function declaration
2. **OCCTBridge.mm** - Objective-C++ implementation
3. **Swift API** - Swift wrapper class/method

## Step-by-Step Example: Adding Chamfer by Edge Selection

Let's add a feature to chamfer specific edges rather than all edges.

### Step 1: Understand the OCCT API

First, research the OCCT classes involved:

```cpp
// OCCT classes for chamfering
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

// Basic usage:
BRepFilletAPI_MakeChamfer chamfer(shape);
chamfer.Add(distance, edge);  // Add specific edge
TopoDS_Shape result = chamfer.Shape();
```

Key documentation:
- [BRepFilletAPI_MakeChamfer](https://dev.opencascade.org/doc/refman/html/class_b_rep_fillet_a_p_i___make_chamfer.html)

### Step 2: Design the C Interface

Add to `Sources/OCCTBridge/include/OCCTBridge.h`:

```c
// Edge handle type (if not already defined)
typedef struct OCCTEdge* OCCTEdgeRef;

// Get edges from a shape
int32_t OCCTShapeGetEdgeCount(OCCTShapeRef shape);
OCCTEdgeRef OCCTShapeGetEdge(OCCTShapeRef shape, int32_t index);
void OCCTEdgeRelease(OCCTEdgeRef edge);

// Chamfer specific edges
OCCTShapeRef OCCTShapeChamferEdges(
    OCCTShapeRef shape,
    const OCCTEdgeRef* edges,
    int32_t edgeCount,
    double distance
);
```

**Design considerations:**

- Use opaque handles for OCCT objects
- Pass arrays as pointer + count
- Return new shape (don't modify input)
- Keep C interface simple - complex logic in implementation

### Step 3: Implement in Objective-C++

Add to `Sources/OCCTBridge/src/OCCTBridge.mm`:

```objc
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>

// Internal edge structure
struct OCCTEdge {
    TopoDS_Edge edge;
};

int32_t OCCTShapeGetEdgeCount(OCCTShapeRef shape) {
    if (!shape) return 0;

    int32_t count = 0;
    TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
    while (explorer.More()) {
        count++;
        explorer.Next();
    }
    return count;
}

OCCTEdgeRef OCCTShapeGetEdge(OCCTShapeRef shape, int32_t index) {
    if (!shape) return nullptr;

    TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
    for (int32_t i = 0; i < index && explorer.More(); i++) {
        explorer.Next();
    }

    if (!explorer.More()) return nullptr;

    auto edge = new OCCTEdge();
    edge->edge = TopoDS::Edge(explorer.Current());
    return edge;
}

void OCCTEdgeRelease(OCCTEdgeRef edge) {
    delete edge;
}

OCCTShapeRef OCCTShapeChamferEdges(
    OCCTShapeRef shape,
    const OCCTEdgeRef* edges,
    int32_t edgeCount,
    double distance
) {
    if (!shape || !edges || edgeCount == 0) return nullptr;

    try {
        BRepFilletAPI_MakeChamfer chamfer(shape->shape);

        for (int32_t i = 0; i < edgeCount; i++) {
            if (edges[i]) {
                chamfer.Add(distance, edges[i]->edge);
            }
        }

        chamfer.Build();

        if (!chamfer.IsDone()) {
            return nullptr;
        }

        auto result = new OCCTShape();
        result->shape = chamfer.Shape();
        return result;

    } catch (const Standard_Failure& e) {
        // OCCT exception - operation failed
        return nullptr;
    }
}
```

**Implementation notes:**

- Wrap OCCT calls in try/catch for Standard_Failure
- Return nullptr on failure (let Swift handle it)
- Use `TopExp_Explorer` to traverse topology
- Use `TopoDS::Edge()` to downcast from TopoDS_Shape

### Step 4: Add Swift Wrapper

Add `Edge` type to `Sources/OCCTSwift/Edge.swift`:

```swift
import Foundation
import OCCTBridge

/// Represents an edge (bounded curve) of a shape
public struct Edge: ~Copyable {
    internal let handle: OCCTEdgeRef

    internal init(handle: OCCTEdgeRef) {
        self.handle = handle
    }

    deinit {
        OCCTEdgeRelease(handle)
    }
}
```

Add edge methods to `Sources/OCCTSwift/Shape.swift`:

```swift
extension Shape {
    /// Number of edges in this shape
    public var edgeCount: Int {
        Int(OCCTShapeGetEdgeCount(handle))
    }

    /// Get edge at index
    public func edge(at index: Int) -> Edge? {
        guard let handle = OCCTShapeGetEdge(self.handle, Int32(index)) else {
            return nil
        }
        return Edge(handle: handle)
    }

    /// Get all edges
    public var edges: [Edge] {
        (0..<edgeCount).compactMap { edge(at: $0) }
    }

    /// Chamfer specific edges
    public func chamfered(edges: [Edge], distance: Double) -> Shape? {
        let handles = edges.map { $0.handle }

        guard let resultHandle = handles.withUnsafeBufferPointer({ buffer in
            OCCTShapeChamferEdges(
                self.handle,
                buffer.baseAddress,
                Int32(edges.count),
                distance
            )
        }) else {
            return nil
        }

        return Shape(handle: resultHandle)
    }
}
```

### Step 5: Add Tests

Create the suite in the matching per-domain target — chamfer is a modeling op, so `Tests/OCCTModelingTests/ChamferTests.swift`:

```swift
import XCTest
@testable import OCCTSwift

final class ChamferTests: XCTestCase {

    func testChamferAllEdges() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let chamfered = box.chamfered(distance: 1.0)

        XCTAssertTrue(chamfered.isValid)
    }

    func testChamferSpecificEdges() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)

        // Get first 4 edges (top face)
        let edges = Array(box.edges.prefix(4))
        XCTAssertEqual(edges.count, 4)

        let chamfered = box.chamfered(edges: edges, distance: 1.0)
        XCTAssertNotNil(chamfered)
        XCTAssertTrue(chamfered!.isValid)
    }

    func testChamferInvalidRadius() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)

        // Radius too large - should fail gracefully
        let chamfered = box.chamfered(distance: 20.0)

        // Either returns nil or invalid shape
        if let shape = chamfered {
            XCTAssertFalse(shape.isValid)
        }
    }
}
```

### Step 6: Add Documentation

Add to `docs/api/shape.md`:

```markdown
### Edge Selection

#### `edgeCount: Int`

Returns the number of edges in the shape.

#### `edge(at: Int) -> Edge?`

Returns the edge at the given index, or nil if out of bounds.

#### `edges: [Edge]`

Returns all edges in the shape.

#### `chamfered(edges: [Edge], distance: Double) -> Shape?`

Chamfers the specified edges with the given distance.

**Parameters:**
- `edges`: Array of edges to chamfer
- `distance`: Chamfer distance (size of the bevel)

**Returns:** New shape with chamfered edges, or nil if operation fails.

**Example:**
```swift
let box = Shape.box(width: 10, height: 10, depth: 10)

// Chamfer only the top edges
let topEdges = box.edges.filter { /* selection logic */ }
if let chamfered = box.chamfered(edges: topEdges, distance: 1.0) {
    // Use chamfered shape
}
```
```

## Common Patterns

### Handling OCCT Exceptions

```objc
try {
    // OCCT operations
} catch (const Standard_Failure& e) {
    // Log error if debugging
    #ifdef DEBUG
    NSLog(@"OCCT error: %s", e.GetMessageString());
    #endif
    return nullptr;
}
```

### Iterating Topology

```objc
// Iterate all faces
TopExp_Explorer faceExplorer(shape->shape, TopAbs_FACE);
while (faceExplorer.More()) {
    TopoDS_Face face = TopoDS::Face(faceExplorer.Current());
    // Process face
    faceExplorer.Next();
}

// Iterate edges of a specific face
TopExp_Explorer edgeExplorer(face, TopAbs_EDGE);
while (edgeExplorer.More()) {
    TopoDS_Edge edge = TopoDS::Edge(edgeExplorer.Current());
    // Process edge
    edgeExplorer.Next();
}
```

### Creating Geometry

```objc
#include <gp_Pnt.hxx>
#include <gp_Dir.hxx>
#include <gp_Ax2.hxx>
#include <GC_MakeCircle.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>

// Create a circle wire
gp_Pnt center(0, 0, 0);
gp_Dir normal(0, 0, 1);
gp_Ax2 axis(center, normal);

Handle(Geom_Circle) circle = GC_MakeCircle(axis, radius).Value();
TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(circle).Edge();
TopoDS_Wire wire = BRepBuilderAPI_MakeWire(edge).Wire();
```

### Memory Management

```objc
// OCCT uses handles (smart pointers) internally
// Our structs own the TopoDS_Shape which contains handles
// When struct is deleted, handles are released automatically

struct OCCTShape {
    TopoDS_Shape shape;  // Contains Handle<> internally

    // No explicit destructor needed - TopoDS_Shape handles cleanup
};
```

## Checklist for New Features

- [ ] Research OCCT API and test in isolation
- [ ] Add C function declarations to `OCCTBridge.h`
- [ ] Implement in `OCCTBridge.mm` with error handling
- [ ] Add Swift wrapper with documentation comments
- [ ] Add unit tests
- [ ] Update API documentation
- [ ] Test with actual use case

## Debugging Tips

### Print OCCT Shape Info

```objc
#include <BRepTools.hxx>

void debugPrintShape(OCCTShapeRef shape) {
    std::ostringstream stream;
    BRepTools::Dump(shape->shape, stream);
    NSLog(@"Shape: %s", stream.str().c_str());
}
```

### Visualize in Draw

If you have OCCT's Draw test harness:

```cpp
// Save shape to file
BRepTools::Write(shape, "debug_shape.brep");

// Load in Draw:
// restore debug_shape.brep s
// vdisplay s
```

### Check Shape Validity

```objc
#include <BRepCheck_Analyzer.hxx>

bool isShapeValid(OCCTShapeRef shape) {
    BRepCheck_Analyzer analyzer(shape->shape);
    return analyzer.IsValid();
}
```
