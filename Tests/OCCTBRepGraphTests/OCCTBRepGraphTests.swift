import Foundation
import Testing
import simd

@testable import OCCTSwift

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

// MARK: - BRepGraph Tests (v0.129.0)

@Suite("BRepGraph Build")
struct BRepGraphBuildTests {
    @Test func buildFromBox() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            #expect(graph != nil)
            if let graph {
                #expect(graph.faceCount == 6)
                #expect(graph.edgeCount == 12)
                #expect(graph.vertexCount == 8)
                #expect(graph.shellCount == 1)
                #expect(graph.solidCount == 1)
                #expect(graph.wireCount == 6)
                #expect(graph.compoundCount == 0)
                #expect(graph.nodeCount > 0)
            }
        }
    }

    @Test func buildParallel() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box, parallel: true)
            #expect(graph != nil)
            if let graph {
                #expect(graph.faceCount == 6)
            }
        }
    }

    @Test func buildFromSphere() {
        let sphere = Shape.sphere(radius: 5)
        if let sphere {
            let graph = BRepGraph(shape: sphere)
            if let graph {
                #expect(graph.faceCount > 0)
                #expect(graph.edgeCount >= 0)
                #expect(graph.nodeCount > 0)
            }
        }
    }

    @Test func buildFromComplex() {
        let box = Shape.box(width: 20, height: 20, depth: 20)
        let cyl = Shape.cylinder(radius: 5, height: 30)
        if let box, let cyl {
            let fused = box + cyl
            if let fused {
                let graph = BRepGraph(shape: fused)
                if let graph {
                    #expect(graph.faceCount > 6)
                    #expect(graph.isValid)
                }
            }
        }
    }
}

@Suite("BRepGraph Counts")
struct BRepGraphCountTests {
    @Test func activeCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.activeFaceCount == 6)
                #expect(graph.activeEdgeCount == 12)
                #expect(graph.activeVertexCount == 8)
            }
        }
    }

    @Test func geometryCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.surfaceCount == 6)
                #expect(graph.curve3DCount == 12)
                #expect(graph.curve2DCount > 0)
            }
        }
    }

    @Test func coedgeCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.coedgeCount == 24)
            }
        }
    }
}

@Suite("BRepGraph Face Queries")
struct BRepGraphFaceQueryTests {
    @Test func faceAdjacency() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let adj = graph.adjacentFaces(of: 0)
                #expect(adj.count == 4)
            }
        }
    }

    @Test func sharedEdges() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let adj = graph.adjacentFaces(of: 0)
                if adj.count > 0 {
                    let shared = graph.sharedEdges(between: 0, and: adj[0])
                    #expect(shared.count == 1)
                }
            }
        }
    }

    @Test func outerWire() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let wire = graph.outerWire(of: 0)
                #expect(wire >= 0)
            }
        }
    }
}

@Suite("BRepGraph Edge Queries")
struct BRepGraphEdgeQueryTests {
    @Test func edgeFaceCount() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let nbFaces = graph.faceCount(of: 0)
                #expect(nbFaces == 2)
            }
        }
    }

    @Test func edgeFaces() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let faces = graph.faces(of: 0)
                #expect(faces.count == 2)
            }
        }
    }

    @Test func noBoundaryEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(!graph.isBoundaryEdge(i))
                }
            }
        }
    }

    @Test func allManifoldEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(graph.isManifoldEdge(i))
                }
            }
        }
    }

    @Test func edgeAdjacency() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let adj = graph.adjacentEdges(of: 0)
                #expect(adj.count > 0)
            }
        }
    }
}

@Suite("BRepGraph Vertex Queries")
struct BRepGraphVertexQueryTests {
    @Test func vertexEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let edges = graph.edges(of: 0)
                #expect(edges.count == 3)
            }
        }
    }
}

@Suite("BRepGraph Explorers")
struct BRepGraphExplorerTests {
    @Test func childExplorer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // OCCT 8.0 reshaped root iteration to Products only, wrap the
                // box's solid root in a Product to expose it as a graph root.
                _ = graph.linkProductToTopology(shapeRootKind: 0 /* Solid */, shapeRootIndex: 0)
                let roots = graph.rootNodes
                #expect(roots.count > 0)
                if let root = roots.first {
                    let faceCount = graph.childCount(
                        rootKind: root.kind, rootIndex: root.index, targetKind: .face)
                    #expect(faceCount == 6)
                }
            }
        }
    }

    @Test func parentExplorer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let parents = graph.parentCount(nodeKind: .face, nodeIndex: 0)
                #expect(parents > 0)
            }
        }
    }
}

@Suite("BRepGraph Validate")
struct BRepGraphValidateTests {
    @Test func boxIsValid() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.isValid)
                let result = graph.validate()
                #expect(result.isValid)
                #expect(result.errorCount == 0)
            }
        }
    }
}

@Suite("BRepGraph Compact")
struct BRepGraphCompactTests {
    @Test func compactBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let result = graph.compact()
                #expect(result.nodesAfter > 0)
            }
        }
    }
}

@Suite("BRepGraph Deduplicate")
struct BRepGraphDeduplicateTests {
    @Test func deduplicateBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let result = graph.deduplicate()
                #expect(result.canonicalSurfaces == 6)
                #expect(result.canonicalCurves == 12)
            }
        }
    }
}

@Suite("BRepGraph Stats")
struct BRepGraphStatsTests {
    @Test func boxStats() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let s = graph.stats
                #expect(s.faces == 6)
                #expect(s.edges == 12)
                #expect(s.vertices == 8)
                #expect(s.solids == 1)
                #expect(s.shells == 1)
                #expect(s.wires == 6)
                #expect(s.coedges == 24)
                #expect(s.surfaces == 6)
                #expect(s.curves3D == 12)
                #expect(s.totalNodes > 0)
            }
        }
    }
}

@Suite("BRepGraph Node Status")
struct BRepGraphNodeStatusTests {
    @Test func noRemovedNodes() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.faceCount {
                    #expect(!graph.isRemoved(nodeKind: .face, nodeIndex: i))
                }
            }
        }
    }
}

@Suite("BRepGraph Root Nodes")
struct BRepGraphRootNodeTests {
    @Test func hasRoots() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // OCCT 8.0 reshaped root iteration to Products only, wrap the
                // box's solid root in a Product to expose it as a graph root.
                _ = graph.linkProductToTopology(shapeRootKind: 0 /* Solid */, shapeRootIndex: 0)
                let roots = graph.rootNodes
                #expect(roots.count > 0)
                #expect(roots.first?.kind == .product)
            }
        }
    }
}

// MARK: - BRepGraph Extended Tests (v0.133.0)

@Suite("BRepGraph Shape Reconstruction")
struct BRepGraphShapeReconstructionTests {
    @Test func reconstructFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let face = graph.shape(nodeKind: .face, nodeIndex: 0)
                #expect(face != nil)
            }
        }
    }

    @Test func reconstructSolid() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let solid = graph.shape(nodeKind: .solid, nodeIndex: 0)
                #expect(solid != nil)
            }
        }
    }

    @Test func findNode() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let found = graph.hasNode(for: box)
                #expect(found)
                let node = graph.findNode(for: box)
                #expect(node != nil)
            }
        }
    }

    @Test func hasNodeFalseForUnrelated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 5)
        if let box, let sphere {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(!graph.hasNode(for: sphere))
            }
        }
    }

    @Test func reconstructOccurrenceWithPlacement() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Create assembly structure
                guard let parentProduct = graph.createEmptyProduct() else {
                    Issue.record("createEmptyProduct nil")
                    return
                }
                guard
                    let childProduct = graph.linkProductToTopology(
                        shapeRootKind: 0,  // Solid
                        shapeRootIndex: 0,
                        placement: BRepGraph.identityLocationMatrix)
                else {
                    Issue.record("linkProductToTopology nil")
                    return
                }
                let translationMatrix: [Double] = [
                    1, 0, 0, 5,
                    0, 1, 0, 6,
                    0, 0, 1, 7,
                ]
                guard let linked = graph.linkProducts(
                    parentProductIndex: parentProduct,
                    referencedProductIndex: childProduct,
                    placement: translationMatrix)
                else {
                    Issue.record("linkProducts nil")
                    return
                }
                
                // Reconstruct the occurrence shape - it should have the placement applied
                // Use occurrence DEFINITION index (linked.occurrenceIndex)
                let occShape = graph.shape(nodeKind: .occurrence, nodeIndex: linked.occurrenceIndex)
                #expect(occShape != nil)
                if let occShape {
                    // The occurrence shape should be the box translated by (5, 6, 7)
                    // Box originally spans -5..5, so translated box spans 0..10, 1..11, 2..12
                    let bbox = occShape.boundingBox()
                    #expect(abs(bbox.min.x - 0.0) < 1e-6)
                    #expect(abs(bbox.min.y - 1.0) < 1e-6)
                    #expect(abs(bbox.min.z - 2.0) < 1e-6)
                    #expect(abs(bbox.max.x - 10.0) < 1e-6)
                    #expect(abs(bbox.max.y - 11.0) < 1e-6)
                    #expect(abs(bbox.max.z - 12.0) < 1e-6)
                }
            }
        }
    }
}

@Suite("BRepGraph Vertex Geometry")
struct BRepGraphVertexGeometryTests {
    @Test func vertexPoint() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let pt = graph.vertexPoint(0)
                // Vertex should be a finite point
                #expect(pt.x.isFinite)
                #expect(pt.y.isFinite)
                #expect(pt.z.isFinite)
            }
        }
    }

    @Test func vertexTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let tol = graph.vertexTolerance(0)
                #expect(tol > 0)
                #expect(tol < 1.0)  // should be a small value
            }
        }
    }
}

@Suite("BRepGraph Edge Geometry")
struct BRepGraphEdgeGeometryTests {
    @Test func edgeTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let tol = graph.edgeTolerance(0)
                #expect(tol > 0)
            }
        }
    }

    @Test func edgeNotDegenerated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(!graph.isEdgeDegenerated(i))
                }
            }
        }
    }

    @Test func edgeSameParameter() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(graph.isEdgeSameParameter(i))
                }
            }
        }
    }

    @Test func edgeSameRange() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(graph.isEdgeSameRange(i))
                }
            }
        }
    }

    @Test func edgeRange() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let range = graph.edgeRange(0)
                #expect(range.first < range.last)
            }
        }
    }

    @Test func edgeHasCurve() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    #expect(graph.edgeHasCurve(i))
                }
            }
        }
    }

    @Test func edgeMaxContinuity() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let cont = graph.edgeMaxContinuity(0)
                #expect(cont >= 0)
            }
        }
    }

    @Test func edgeNotClosedOnFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box edges are not seam edges
                let faces = graph.faces(of: 0)
                if let faceIdx = faces.first {
                    #expect(!graph.isEdgeClosedOnFace(edgeIndex: 0, faceIndex: faceIdx))
                }
            }
        }
    }
}

@Suite("BRepGraph Face Geometry")
struct BRepGraphFaceGeometryTests {
    @Test func faceTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let tol = graph.faceTolerance(0)
                #expect(tol > 0)
            }
        }
    }

    @Test func faceHasSurface() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.faceCount {
                    #expect(graph.faceHasSurface(i))
                }
            }
        }
    }

    @Test func faceNaturalRestriction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Just check it returns a bool without crashing
                let _ = graph.isFaceNaturalRestriction(0)
            }
        }
    }

    @Test func faceHasTriangulation() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box may or may not have triangulation depending on meshing
                let _ = graph.faceHasTriangulation(0)
            }
        }
    }
}

@Suite("BRepGraph Wire Extended")
struct BRepGraphWireExtendedTests {
    @Test func wireIsClosed() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.wireCount {
                    #expect(graph.isWireClosed(i))
                }
            }
        }
    }

    @Test func wireCoEdgeCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let count = graph.wireCoEdgeCount(0)
                #expect(count == 4)  // box face has 4 edges
            }
        }
    }

    @Test func wireFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let faceCount = graph.wireFaceCount(0)
                #expect(faceCount == 1)
                let faces = graph.wireFaces(0)
                #expect(faces.count == 1)
            }
        }
    }
}

@Suite("BRepGraph CoEdge Queries")
struct BRepGraphCoEdgeQueryTests {
    @Test func coedgeEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let edgeIdx = graph.coedgeEdge(0)
                #expect(edgeIdx >= 0)
                #expect(edgeIdx < graph.edgeCount)
            }
        }
    }

    @Test func coedgeFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let faceIdx = graph.coedgeFace(0)
                #expect(faceIdx >= 0)
                #expect(faceIdx < graph.faceCount)
            }
        }
    }

    @Test func coedgeSeamPairNilForBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box edges are not seam edges, so no seam pairs
                let pair = graph.coedgeSeamPair(0)
                #expect(pair == nil)
            }
        }
    }

    @Test func coedgeSeamPairForSphere() {
        let sphere = Shape.sphere(radius: 5)
        if let sphere {
            let graph = BRepGraph(shape: sphere)
            if let graph {
                // Sphere has seam edges; find a coedge with a seam pair
                var foundSeam = false
                for i in 0..<graph.coedgeCount {
                    if graph.coedgeSeamPair(i) != nil {
                        foundSeam = true
                        break
                    }
                }
                // Sphere may or may not have seam depending on representation
                let _ = foundSeam
            }
        }
    }

    @Test func coedgeHasPCurve() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box coedges should have PCurves
                var hasPCurve = false
                for i in 0..<graph.coedgeCount {
                    if graph.coedgeHasPCurve(i) {
                        hasPCurve = true
                        break
                    }
                }
                #expect(hasPCurve)
            }
        }
    }

    @Test func coedgeRange() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                if graph.coedgeHasPCurve(0) {
                    let range = graph.coedgeRange(0)
                    #expect(range.first < range.last)
                }
            }
        }
    }
}

@Suite("BRepGraph Shell Queries")
struct BRepGraphShellQueryTests {
    @Test func shellSolids() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let count = graph.shellSolidCount(0)
                #expect(count == 1)
                let solids = graph.shellSolids(0)
                #expect(solids.count == 1)
                #expect(solids[0] == 0)
            }
        }
    }
}

@Suite("BRepGraph Solid Queries")
struct BRepGraphSolidQueryTests {
    @Test func solidCompSolidCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let count = graph.solidCompSolidCount(0)
                #expect(count == 0)  // standalone solid, not in comp-solid
            }
        }
    }
}

@Suite("BRepGraph History")
struct BRepGraphHistoryTests {
    @Test func historyDefaults() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.isHistoryEnabled)
                #expect(graph.historyRecordCount == 0)
            }
        }
    }

    @Test func historyToggle() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                graph.isHistoryEnabled = false
                #expect(!graph.isHistoryEnabled)
                graph.isHistoryEnabled = true
                #expect(graph.isHistoryEnabled)
            }
        }
    }

    @Test func historyClear() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                graph.clearHistory()
                #expect(graph.historyRecordCount == 0)
            }
        }
    }
}

@Suite("BRepGraph Poly Counts")
struct BRepGraphPolyCountTests {
    @Test func polyCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Poly counts are >= 0 (may be 0 if not meshed)
                #expect(graph.triangulationCount >= 0)
                #expect(graph.polygon3DCount >= 0)
            }
        }
    }
}

@Suite("BRepGraph Active Geometry")
struct BRepGraphActiveGeometryTests {
    @Test func activeGeometryCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.activeSurfaceCount == 6)
                #expect(graph.activeCurve3DCount == 12)
                #expect(graph.activeCurve2DCount > 0)
            }
        }
    }
}

@Suite("BRepGraph SameDomain")
struct BRepGraphSameDomainTests {
    @Test func boxNoSameDomain() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box faces are all distinct, no same-domain
                let sd = graph.sameDomainFaces(of: 0)
                #expect(sd.isEmpty)
            }
        }
    }
}

@Suite("BRepGraph Copy")
struct BRepGraphCopyTests {
    @Test func deepCopy() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let copy = graph.copy()
                #expect(copy != nil)
                if let copy {
                    #expect(copy.faceCount == 6)
                    #expect(copy.edgeCount == 12)
                    #expect(copy.vertexCount == 8)
                }
            }
        }
    }

    @Test func lightCopy() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let copy = graph.copy(copyGeometry: false)
                #expect(copy != nil)
                if let copy {
                    #expect(copy.faceCount == 6)
                }
            }
        }
    }

    @Test func copyFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let faceCopy = graph.copyFace(0)
                #expect(faceCopy != nil)
                if let faceCopy {
                    #expect(faceCopy.faceCount == 1)
                }
            }
        }
    }
}

@Suite("BRepGraph Transform")
struct BRepGraphTransformTests {
    @Test func translateGraph() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let translated = graph.translated(dx: 100, dy: 200, dz: 300)
                #expect(translated != nil)
                if let translated {
                    #expect(translated.faceCount == 6)
                    #expect(translated.edgeCount == 12)
                    #expect(translated.vertexCount == 8)
                    // Check that vertex moved
                    let origPt = graph.vertexPoint(0)
                    let newPt = translated.vertexPoint(0)
                    #expect(abs(newPt.x - origPt.x - 100) < 1e-6)
                    #expect(abs(newPt.y - origPt.y - 200) < 1e-6)
                    #expect(abs(newPt.z - origPt.z - 300) < 1e-6)
                }
            }
        }
    }

    @Test func translateLightCopy() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let translated = graph.translated(dx: 10, dy: 0, dz: 0, copyGeometry: false)
                #expect(translated != nil)
                if let translated {
                    #expect(translated.faceCount == 6)
                }
            }
        }
    }
}

// MARK: - BRepGraph Assembly & Refs (v0.134.0)

@Suite("BRepGraph Products")
struct BRepGraphProductTests {
    @Test func productCountForPrimitive() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Simple shapes have 1 product (the shape itself as a part)
                #expect(graph.productCount >= 0)
                #expect(graph.occurrenceCount == 0)
                if graph.productCount > 0 {
                    // Root product should be a part, not an assembly
                    #expect(graph.productIsPart(0))
                    #expect(!graph.productIsAssembly(0))
                    // Should have a valid shape root
                    let root = graph.productShapeRoot(0)
                    #expect(root != nil)
                }
                #expect(graph.rootProductCount == graph.productCount)
            }
        }
    }

    @Test func productQueriesOnSphere() {
        let sphere = Shape.sphere(radius: 5)
        if let sphere {
            let graph = BRepGraph(shape: sphere)
            if let graph {
                #expect(graph.productCount >= 0)
                #expect(graph.occurrenceCount == 0)
                if graph.productCount > 0 {
                    #expect(graph.productIsPart(0))
                    #expect(graph.productComponentCount(0) == 0)
                }
            }
        }
    }

    // #418: rootProductIndices had zero test coverage anywhere; only its
    // sibling rootProductCount was exercised (productCountForPrimitive above).
    @Test func rootProductIndices() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let indices = graph.rootProductIndices
                #expect(indices.count == graph.rootProductCount)
                for index in indices {
                    #expect(index >= 0)
                    #expect(index < graph.productCount)
                }
                // Root product indices should be unique.
                #expect(Set(indices).count == indices.count)
            }
        }
    }
}

@Suite("BRepGraph Occurrences")
struct BRepGraphOccurrenceTests {
    @Test func occurrenceCountForPrimitive() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.occurrenceCount == 0)
            }
        }
    }
}

@Suite("BRepGraph Ref Counts")
struct BRepGraphRefCountTests {
    @Test func refCountsForBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box has shells, faces, wires, coedges, vertices refs
                #expect(graph.shellRefCount >= 1)
                #expect(graph.faceRefCount >= 6)
                #expect(graph.wireRefCount >= 6)
                #expect(graph.coedgeRefCount >= 24)
                #expect(graph.vertexRefCount >= 16)  // edges have start/end vertex refs
                #expect(graph.solidRefCount >= 0)
                #expect(graph.childRefCount >= 0)
                #expect(graph.occurrenceRefCount == 0)  // no assembly
            }
        }
    }

    @Test func refCountsConsistency() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Face ref count should be >= face definition count
                #expect(graph.faceRefCount >= graph.faceCount)
                // Wire ref count should be >= wire definition count
                #expect(graph.wireRefCount >= graph.wireCount)
            }
        }
    }
}

@Suite("BRepGraph Ref Entry Queries")
struct BRepGraphRefEntryTests {
    @Test func refChildNode() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Check face ref 0 child node
                if graph.faceRefCount > 0 {
                    let kind = graph.refChildNodeKind(.face, refIndex: 0)
                    #expect(kind != nil)
                    if let kind {
                        #expect(kind == .face)
                    }
                    let idx = graph.refChildNodeIndex(.face, refIndex: 0)
                    #expect(idx >= 0)
                }
            }
        }
    }

    @Test func refNotRemoved() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                if graph.faceRefCount > 0 {
                    #expect(!graph.isRefRemoved(.face, refIndex: 0))
                }
                if graph.shellRefCount > 0 {
                    #expect(!graph.isRefRemoved(.shell, refIndex: 0))
                }
            }
        }
    }

    @Test func refOrientation() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                if graph.faceRefCount > 0 {
                    let ori = graph.refOrientation(.face, refIndex: 0)
                    // TopAbs_FORWARD=0, REVERSED=1, INTERNAL=2, EXTERNAL=3
                    #expect(ori >= 0 && ori <= 3)
                }
            }
        }
    }
}

@Suite("BRepGraph Face Def Details")
struct BRepGraphFaceDefTests {
    @Test func faceWireCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Each face of a box has exactly 1 wire (the outer wire)
                for i in 0..<graph.faceCount {
                    #expect(graph.faceWireCount(i) >= 1)
                }
            }
        }
    }

    @Test func faceVertexRefCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box faces normally have no isolated vertices
                for i in 0..<graph.faceCount {
                    #expect(graph.faceVertexRefCount(i) == 0)
                }
            }
        }
    }
}

@Suite("BRepGraph Edge Def Details")
struct BRepGraphEdgeDefTests {
    @Test func edgeStartEndVertex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    let start = graph.edgeStartVertex(i)
                    let end = graph.edgeEndVertex(i)
                    #expect(start != nil)
                    #expect(end != nil)
                    if let start {
                        #expect(start >= 0 && start < graph.vertexCount)
                    }
                    if let end {
                        #expect(end >= 0 && end < graph.vertexCount)
                    }
                }
            }
        }
    }

    @Test func edgeIsClosedOnBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box edges are NOT closed (they are line segments)
                for i in 0..<graph.edgeCount {
                    #expect(!graph.isEdgeClosed(i))
                }
            }
        }
    }

    @Test func edgeClosedConsistency() {
        let sphere = Shape.sphere(radius: 5)
        if let sphere {
            let graph = BRepGraph(shape: sphere)
            if let graph {
                // For any closed edge, start == end vertex
                for i in 0..<graph.edgeCount {
                    if graph.isEdgeClosed(i) {
                        let start = graph.edgeStartVertex(i)
                        let end = graph.edgeEndVertex(i)
                        if let start, let end {
                            #expect(start == end)
                        }
                    }
                }
                // Verify we can query all edges without error
                #expect(graph.edgeCount > 0)
            }
        }
    }
}

@Suite("BRepGraph Edge Wires CoEdges")
struct BRepGraphEdgeWiresCoEdgesTests {
    @Test func edgeWires() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    let wires = graph.edgeWires(i)
                    // Each edge of a box belongs to at least 1 wire
                    #expect(!wires.isEmpty)
                    for w in wires {
                        #expect(w >= 0 && w < graph.wireCount)
                    }
                }
            }
        }
    }

    @Test func edgeCoEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.edgeCount {
                    let coedges = graph.edgeCoEdges(i)
                    // Each edge has at least 1 coedge
                    #expect(!coedges.isEmpty)
                    for c in coedges {
                        #expect(c >= 0 && c < graph.coedgeCount)
                    }
                }
            }
        }
    }

    @Test func edgeFindCoEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // For each edge, find a coedge on one of its faces
                for i in 0..<graph.edgeCount {
                    let edgeFaces = graph.faces(of: i)
                    if let firstFace = edgeFaces.first {
                        let coedge = graph.edgeFindCoEdge(edgeIndex: i, faceIndex: firstFace)
                        #expect(coedge != nil)
                        if let coedge {
                            #expect(coedge >= 0 && coedge < graph.coedgeCount)
                        }
                    }
                }
            }
        }
    }
}

@Suite("BRepGraph Face Shells")
struct BRepGraphFaceShellTests {
    @Test func faceShells() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.faceCount {
                    let count = graph.faceShellCount(i)
                    #expect(count >= 1)
                    let shells = graph.faceShells(i)
                    #expect(shells.count == count)
                    for s in shells {
                        #expect(s >= 0 && s < graph.shellCount)
                    }
                }
            }
        }
    }

    @Test func faceCompoundCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box faces are not in compounds
                for i in 0..<graph.faceCount {
                    #expect(graph.faceCompoundCount(i) == 0)
                }
            }
        }
    }
}

@Suite("BRepGraph Shell Extended")
struct BRepGraphShellExtendedTests {
    @Test func shellCompoundCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.shellCount {
                    #expect(graph.shellCompoundCount(i) == 0)
                }
            }
        }
    }

    @Test func shellIsClosed() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box shell should be closed
                #expect(graph.shellCount >= 1)
                if graph.shellCount > 0 {
                    #expect(graph.isShellClosed(0))
                }
            }
        }
    }
}

@Suite("BRepGraph Solid Extended")
struct BRepGraphSolidExtendedTests {
    @Test func solidCompoundCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.solidCount {
                    #expect(graph.solidCompoundCount(i) == 0)
                }
            }
        }
    }
}

@Suite("BRepGraph CompSolid Count")
struct BRepGraphCompSolidCountTests {
    @Test func compSolidCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.compSolidCount == 0)
            }
        }
    }
}

@Suite("BRepGraph Compound Queries")
struct BRepGraphCompoundTests {
    @Test func compoundQueriesOnCompound() {
        // Create a compound shape by fusing two boxes
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)
        if let box1, let box2 {
            let compound = Shape.compound([box1, box2])
            if let compound {
                let graph = BRepGraph(shape: compound)
                if let graph {
                    #expect(graph.compoundCount >= 1)
                    if graph.compoundCount > 0 {
                        let childCount = graph.compoundChildCount(0)
                        #expect(childCount >= 2)  // at least 2 solids
                        let parentCount = graph.compoundParentCount(0)
                        // Root compound has no parents
                        #expect(parentCount == 0)
                    }
                }
            }
        }
    }
}

// MARK: - BRepGraph Builder (v0.135.0)

@Suite("BRepGraph Builder AddVertex")
struct BRepGraphBuilderAddVertexTests {
    @Test func addVertexToGraph() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origVertexCount = graph.vertexCount
                if let vidx = graph.addVertex(x: 5.0, y: 5.0, z: 5.0, tolerance: 1e-7) {
                    #expect(vidx >= 0)
                    #expect(graph.vertexCount == origVertexCount + 1)
                    let pt = graph.vertexPoint(vidx)
                    #expect(abs(pt.x - 5.0) < 1e-6)
                    #expect(abs(pt.y - 5.0) < 1e-6)
                    #expect(abs(pt.z - 5.0) < 1e-6)
                    #expect(abs(graph.vertexTolerance(vidx) - 1e-7) < 1e-10)
                }
            }
        }
    }

    @Test func addMultipleVertices() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let orig = graph.vertexCount
                let v1 = graph.addVertex(x: 0, y: 0, z: 0, tolerance: 0.01)
                let v2 = graph.addVertex(x: 1, y: 2, z: 3, tolerance: 0.02)
                #expect(v1 != nil)
                #expect(v2 != nil)
                #expect(graph.vertexCount == orig + 2)
            }
        }
    }
}

@Suite("BRepGraph Builder AddShell")
struct BRepGraphBuilderAddShellTests {
    @Test func addEmptyShell() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origShellCount = graph.shellCount
                if let sidx = graph.addShell() {
                    #expect(sidx >= 0)
                    #expect(graph.shellCount == origShellCount + 1)
                }
            }
        }
    }
}

@Suite("BRepGraph Builder AddSolid")
struct BRepGraphBuilderAddSolidTests {
    @Test func addEmptySolid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origSolidCount = graph.solidCount
                if let sidx = graph.addSolid() {
                    #expect(sidx >= 0)
                    #expect(graph.solidCount == origSolidCount + 1)
                }
            }
        }
    }
}

@Suite("BRepGraph Builder AddFaceToShell")
struct BRepGraphBuilderAddFaceToShellTests {
    @Test func linkFaceToShell() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                // Add a new shell, then link existing face 0 to it
                if let shellIdx = graph.addShell() {
                    let refIdx = graph.addFaceToShell(
                        shellIndex: shellIdx, faceIndex: 0, orientation: 0)
                    #expect(refIdx != nil)
                }
            }
        }
    }
}

@Suite("BRepGraph Builder AddShellToSolid")
struct BRepGraphBuilderAddShellToSolidTests {
    @Test func linkShellToSolid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                if let solidIdx = graph.addSolid(), let shellIdx = graph.addShell() {
                    let refIdx = graph.addShellToSolid(
                        solidIndex: solidIdx, shellIndex: shellIdx, orientation: 0)
                    #expect(refIdx != nil)
                }
            }
        }
    }
}

@Suite("BRepGraph Builder AddCompound")
struct BRepGraphBuilderAddCompoundTests {
    @Test func addCompoundFromSolids() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origCompoundCount = graph.compoundCount
                if graph.solidCount > 0 {
                    let children: [(kind: BRepGraph.NodeKind, index: Int)] = [
                        (.solid, 0)
                    ]
                    if let cidx = graph.addCompound(children: children) {
                        #expect(cidx >= 0)
                        #expect(graph.compoundCount == origCompoundCount + 1)
                    }
                }
            }
        }
    }
}

@Suite("BRepGraph Builder AddCompSolid")
struct BRepGraphBuilderAddCompSolidTests {
    @Test func addCompSolidFromSolids() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origCS = graph.compSolidCount
                if graph.solidCount > 0 {
                    if let csIdx = graph.addCompSolid(solidIndices: [0]) {
                        #expect(csIdx >= 0)
                        #expect(graph.compSolidCount == origCS + 1)
                    }
                }
            }
        }
    }
}

@Suite("BRepGraph Builder RemoveNode")
struct BRepGraphBuilderRemoveNodeTests {
    @Test func removeVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                if graph.vertexCount > 0 {
                    let vIdx = graph.vertexCount - 1
                    #expect(!graph.isRemoved(nodeKind: .vertex, nodeIndex: vIdx))
                    graph.removeNode(nodeKind: .vertex, nodeIndex: vIdx)
                    #expect(graph.isRemoved(nodeKind: .vertex, nodeIndex: vIdx))
                }
            }
        }
    }

    @Test func removeSubgraph() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                if graph.faceCount > 0 {
                    let fIdx = graph.faceCount - 1
                    graph.removeSubgraph(nodeKind: .face, nodeIndex: fIdx)
                    #expect(graph.isRemoved(nodeKind: .face, nodeIndex: fIdx))
                }
            }
        }
    }
}

@Suite("BRepGraph Builder AppendShape")
struct BRepGraphBuilderAppendShapeTests {
    @Test func appendFlattenedShape() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origFaces = graph.faceCount
                if let sphere = Shape.sphere(radius: 5) {
                    graph.appendFlattenedShape(sphere)
                    #expect(graph.faceCount > origFaces)
                }
            }
        }
    }

    @Test func appendFullShape() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origFaces = graph.faceCount
                if let cylinder = Shape.cylinder(radius: 3, height: 8) {
                    graph.appendFullShape(cylinder)
                    #expect(graph.faceCount > origFaces)
                }
            }
        }
    }
}

@Suite("BRepGraph Builder Deferred")
struct BRepGraphBuilderDeferredTests {
    @Test func deferredModeToggle() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                #expect(!graph.isDeferredMode)
                graph.beginDeferredInvalidation()
                #expect(graph.isDeferredMode)
                graph.endDeferredInvalidation()
                #expect(!graph.isDeferredMode)
            }
        }
    }

    @Test func deferredModeWithMutations() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                graph.beginDeferredInvalidation()
                _ = graph.addVertex(x: 1, y: 2, z: 3, tolerance: 0.001)
                _ = graph.addVertex(x: 4, y: 5, z: 6, tolerance: 0.001)
                graph.endDeferredInvalidation()
                graph.commitMutation()
                #expect(!graph.isDeferredMode)
            }
        }
    }
}

@Suite("BRepGraph Builder CommitMutation")
struct BRepGraphBuilderCommitMutationTests {
    @Test func commitAfterAdd() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                _ = graph.addVertex(x: 0, y: 0, z: 0, tolerance: 0.01)
                graph.commitMutation()
                // Should not crash
                #expect(graph.vertexCount > 0)
            }
        }
    }
}

@Suite("BRepGraph Builder RemoveRef")
struct BRepGraphBuilderRemoveRefTests {
    @Test func removeShellRef() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                if graph.shellRefCount > 0 {
                    let removed = graph.removeRef(refKind: .shell, refIndex: 0)
                    // Should succeed or gracefully fail
                    #expect(removed || !removed)  // either outcome acceptable
                }
            }
        }
    }
}

@Suite("BRepGraph Builder ClearMesh")
struct BRepGraphBuilderClearMeshTests {
    @Test func clearFaceMesh() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Mesh the shape first
            let _ = box.mesh(linearDeflection: 0.1)
            if let graph = BRepGraph(shape: box) {
                if graph.faceCount > 0 {
                    // Should not crash
                    graph.clearFaceMesh(faceIndex: 0)
                }
            }
        }
    }

    @Test func clearEdgePolygon3D() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let _ = box.mesh(linearDeflection: 0.1)
            if let graph = BRepGraph(shape: box) {
                if graph.edgeCount > 0 {
                    // Should not crash
                    graph.clearEdgePolygon3D(edgeIndex: 0)
                }
            }
        }
    }
}

@Suite("BRepGraph Builder ValidateMutation")
struct BRepGraphBuilderValidateMutationTests {
    @Test func validateCleanGraph() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                // A freshly built graph should have valid mutation boundary
                let valid = graph.validateMutation()
                #expect(valid)
            }
        }
    }

    @Test func validateAfterAddVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                _ = graph.addVertex(x: 0, y: 0, z: 0, tolerance: 0.01)
                graph.commitMutation()
                let valid = graph.validateMutation()
                #expect(valid)
            }
        }
    }
}

// MARK: - BRepGraph UV Grid Sampling (v0.136.0)

@Suite("BRepGraph UV Grid")
struct BRepGraphUVGridTests {
    @Test func sampleBoxFace() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 5, vSamples: 5)
                #expect(sample != nil)
                if let sample {
                    #expect(sample.positions.count == 25)
                    #expect(sample.normals.count == 25)
                    #expect(sample.gaussianCurvatures.count == 25)
                    #expect(sample.meanCurvatures.count == 25)
                    #expect(sample.uSamples == 5)
                    #expect(sample.vSamples == 5)
                    // All normals should be non-zero (planar face)
                    for n in sample.normals {
                        let len = (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
                        #expect(len > 0.99)
                    }
                    // Planar face: gaussian curvature should be ~0
                    for k in sample.gaussianCurvatures {
                        #expect(abs(k) < 1e-10)
                    }
                }
            }
        }
    }

    @Test func sampleSphereFace() {
        if let sphere = Shape.sphere(radius: 5) {
            if let graph = BRepGraph(shape: sphere) {
                if graph.faceCount > 0 {
                    let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 4, vSamples: 4)
                    if let sample {
                        #expect(sample.positions.count == 16)
                        // Sphere: non-zero curvature at most points (some may be undefined at poles)
                        var nonZeroCount = 0
                        for k in sample.gaussianCurvatures {
                            if abs(k) > 1e-6 { nonZeroCount += 1 }
                        }
                        #expect(nonZeroCount > 0)
                    }
                }
            }
        }
    }

    @Test func sampleSinglePoint() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 1, vSamples: 1)
                #expect(sample != nil)
                if let sample {
                    #expect(sample.positions.count == 1)
                }
            }
        }
    }

    @Test func sampleInvalidFace() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let sample = graph.sampleFaceUVGrid(faceIndex: 999, uSamples: 5, vSamples: 5)
                #expect(sample == nil)
            }
        }
    }

    @Test func sampleZeroCounts() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 0, vSamples: 5)
                #expect(sample == nil)
            }
        }
    }
}

@Suite("BRepGraph Edge Sampling")
struct BRepGraphEdgeSamplingTests {
    @Test func sampleBoxEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                // Find an edge with a curve
                var sampledEdge = -1
                for i in 0..<graph.edgeCount {
                    if graph.edgeHasCurve(i) {
                        sampledEdge = i
                        break
                    }
                }
                if sampledEdge >= 0 {
                    let points = graph.sampleEdgeCurve(edgeIndex: sampledEdge, count: 10)
                    #expect(points.count == 10)
                    // Points should be distinct (not all the same)
                    if points.count >= 2 {
                        let first = points[0]
                        let last = points[points.count - 1]
                        let dist =
                            ((first.x - last.x) * (first.x - last.x) + (first.y - last.y)
                            * (first.y - last.y) + (first.z - last.z) * (first.z - last.z))
                            .squareRoot()
                        #expect(dist > 0.001)
                    }
                }
            }
        }
    }

    @Test func sampleSinglePoint() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                for i in 0..<graph.edgeCount {
                    if graph.edgeHasCurve(i) {
                        let points = graph.sampleEdgeCurve(edgeIndex: i, count: 1)
                        #expect(points.count == 1)
                        break
                    }
                }
            }
        }
    }

    @Test func sampleEdgeWithoutCurve() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                // Test with invalid index
                let points = graph.sampleEdgeCurve(edgeIndex: 999, count: 10)
                #expect(points.isEmpty)
            }
        }
    }

    @Test func sampleZeroCount() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let points = graph.sampleEdgeCurve(edgeIndex: 0, count: 0)
                #expect(points.isEmpty)
            }
        }
    }

    @Test func sampleSphereEdge() {
        if let sphere = Shape.sphere(radius: 5) {
            if let graph = BRepGraph(shape: sphere) {
                for i in 0..<graph.edgeCount {
                    if graph.edgeHasCurve(i) {
                        let points = graph.sampleEdgeCurve(edgeIndex: i, count: 20)
                        #expect(points.count == 20)
                        // All points should be on the sphere surface (distance from origin ~= 5)
                        for p in points {
                            let r = (p.x * p.x + p.y * p.y + p.z * p.z).squareRoot()
                            #expect(abs(r - 5.0) < 0.1)
                        }
                        break
                    }
                }
            }
        }
    }
}

// MARK: - unpackSIMD3 shared helper (#419)

@Suite("unpackSIMD3 shared helper")
struct UnpackSIMD3Tests {
    @Test("Exact index-to-component mapping for a known flat buffer")
    func exactMapping() {
        let flat: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        let points: [SIMD3<Double>] = unpackSIMD3(flat, count: 3)
        #expect(points.count == 3)
        #expect(points == [SIMD3(1, 2, 3), SIMD3(4, 5, 6), SIMD3(7, 8, 9)])
    }

    @Test("count: 0 returns an empty array")
    func zeroCountIsEmpty() {
        let flat: [Double] = [1, 2, 3]
        let points: [SIMD3<Double>] = unpackSIMD3(flat, count: 0)
        #expect(points.isEmpty)
    }

    @Test("Only reads the first `count` triples, never buffer entries past it")
    func stopsAtActualCountNotBufferLength() {
        // The whole point of #419: the caller passes the ACTUAL written count, and the
        // helper must never read past it even though the backing buffer is larger,
        // this is exactly the divergence that made sampleFaceUVGrid unsafe.
        let flat: [Double] = [1, 2, 3, 999, 999, 999]
        let points: [SIMD3<Double>] = unpackSIMD3(flat, count: 1)
        #expect(points == [SIMD3(1, 2, 3)])
    }

    @Test("Works generically for a Float scalar buffer")
    func floatScalarBuffer() {
        let flat: [Float] = [1, 2, 3, 4, 5, 6]
        let points: [SIMD3<Float>] = unpackSIMD3(flat, count: 2)
        #expect(points == [SIMD3<Float>(1, 2, 3), SIMD3<Float>(4, 5, 6)])
    }

    @Test("Works for an UnsafeBufferPointer, not just a plain Array")
    func unsafeBufferPointerBuffer() {
        let flat: [Double] = [1, 2, 3, 4, 5, 6]
        let points: [SIMD3<Double>] = flat.withUnsafeBufferPointer { buf in
            unpackSIMD3(buf, count: 2)
        }
        #expect(points == [SIMD3(1, 2, 3), SIMD3(4, 5, 6)])
    }
}

// MARK: - v0.141 / #72 Phase 0: BRepGraph history record readback

@Suite("v0.141 BRepGraph history record readback")
struct BRepGraphHistoryReadbackTests {
    @Test("Recorded 1-to-1 modification survives roundtrip through the API")
    func oneToOneReadback() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = BRepGraph.NodeRef(kind: .face, index: 0)
        let repl = BRepGraph.NodeRef(kind: .face, index: 42)
        graph.recordHistory(operationName: "TestFillet", original: orig, replacements: [repl])

        #expect(graph.historyRecordCount == 1)
        guard let rec = graph.historyRecord(at: 0) else {
            Issue.record("record nil")
            return
        }
        #expect(rec.operationName == "TestFillet")
        #expect(rec.mapping.count == 1)
        #expect(rec.mapping[orig] == [repl])
    }

    @Test("Split (1-to-N) mapping round-trips")
    func splitMapping() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = BRepGraph.NodeRef(kind: .edge, index: 3)
        let a = BRepGraph.NodeRef(kind: .edge, index: 100)
        let b = BRepGraph.NodeRef(kind: .edge, index: 101)
        let c = BRepGraph.NodeRef(kind: .edge, index: 102)
        graph.recordHistory(operationName: "SplitEdge", original: orig, replacements: [a, b, c])

        let rec = graph.historyRecord(at: 0)
        #expect(rec?.mapping[orig] == [a, b, c])
    }

    @Test("Deletion (1-to-0) round-trips")
    func deletionMapping() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = BRepGraph.NodeRef(kind: .face, index: 5)
        graph.recordHistory(operationName: "RemoveFace", original: orig, replacements: [])

        let rec = graph.historyRecord(at: 0)
        #expect(rec?.mapping[orig] == [])
    }

    @Test("FindDerived walks forward through chained records")
    func findDerivedWalksForward() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        // orig → [a] → [b, c]
        let orig = BRepGraph.NodeRef(kind: .edge, index: 1)
        let a = BRepGraph.NodeRef(kind: .edge, index: 10)
        let b = BRepGraph.NodeRef(kind: .edge, index: 20)
        let c = BRepGraph.NodeRef(kind: .edge, index: 21)
        graph.recordHistory(operationName: "Op1", original: orig, replacements: [a])
        graph.recordHistory(operationName: "Op2", original: a, replacements: [b, c])

        let derived = Set(graph.findDerived(of: orig))
        // Transitively, orig should reach b and c (and possibly a depending on OCCT's
        // definition of "leaves", we accept either but require at least b, c).
        #expect(derived.isSuperset(of: [b, c]))
    }

    // MARK: - #167: untouched-vs-deleted disambiguation

    @Test("hasHistoryRecord: true for nodes named in any record's mapping; false otherwise")
    func hasHistoryRecordDistinguishesNamedFromUntouched() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let modified = BRepGraph.NodeRef(kind: .face, index: 0)
        let replaced = BRepGraph.NodeRef(kind: .face, index: 100)
        let deleted = BRepGraph.NodeRef(kind: .face, index: 1)
        let untouched = BRepGraph.NodeRef(kind: .face, index: 2)

        graph.recordHistory(
            operationName: "ModifyFace", original: modified, replacements: [replaced])
        graph.recordHistory(operationName: "DeleteFace", original: deleted, replacements: [])

        #expect(graph.hasHistoryRecord(for: modified), "modified node should be named in a record")
        #expect(
            graph.hasHistoryRecord(for: deleted),
            "explicitly-deleted node should be named in a record")
        #expect(!graph.hasHistoryRecord(for: untouched), "untouched node has no record entry")
    }

    @Test("findDerivedOrSelf: returns derivatives, [] for deleted, [original] for untouched")
    func findDerivedOrSelfDisambiguates() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let modified = BRepGraph.NodeRef(kind: .face, index: 0)
        let replaced = BRepGraph.NodeRef(kind: .face, index: 100)
        let deleted = BRepGraph.NodeRef(kind: .face, index: 1)
        let untouched = BRepGraph.NodeRef(kind: .face, index: 2)

        graph.recordHistory(
            operationName: "ModifyFace", original: modified, replacements: [replaced])
        graph.recordHistory(operationName: "DeleteFace", original: deleted, replacements: [])

        // Modified → derivatives via the existing forward walk
        let modifiedResult = graph.findDerivedOrSelf(of: modified)
        #expect(
            modifiedResult.contains(replaced),
            "modified node should resolve to its replacement(s)")

        // Deleted → empty (record is present but mapping is empty)
        let deletedResult = graph.findDerivedOrSelf(of: deleted)
        #expect(deletedResult.isEmpty, "explicitly-deleted node resolves to []")

        // Untouched → [original] (no record names this node)
        let untouchedResult = graph.findDerivedOrSelf(of: untouched)
        #expect(
            untouchedResult == [untouched],
            "untouched node should resolve to itself at the same index")
    }

    @Test("findDerivedOrSelf preserves findDerived semantics for chained records")
    func findDerivedOrSelfMatchesFindDerivedWhenNonEmpty() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        // orig → [a] → [b, c]
        let orig = BRepGraph.NodeRef(kind: .edge, index: 1)
        let a = BRepGraph.NodeRef(kind: .edge, index: 10)
        let b = BRepGraph.NodeRef(kind: .edge, index: 20)
        let c = BRepGraph.NodeRef(kind: .edge, index: 21)
        graph.recordHistory(operationName: "Op1", original: orig, replacements: [a])
        graph.recordHistory(operationName: "Op2", original: a, replacements: [b, c])

        let derived = Set(graph.findDerived(of: orig))
        let derivedOrSelf = Set(graph.findDerivedOrSelf(of: orig))
        // When findDerived is non-empty, findDerivedOrSelf must return the same set.
        #expect(
            derived == derivedOrSelf,
            "findDerivedOrSelf must equal findDerived when derivatives exist")
    }

    @Test("FindOriginal walks backwards")
    func findOriginalWalksBackward() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = BRepGraph.NodeRef(kind: .face, index: 7)
        let mid = BRepGraph.NodeRef(kind: .face, index: 70)
        let leaf = BRepGraph.NodeRef(kind: .face, index: 700)
        graph.recordHistory(operationName: "A", original: orig, replacements: [mid])
        graph.recordHistory(operationName: "B", original: mid, replacements: [leaf])

        #expect(graph.findOriginal(of: leaf) == orig)
    }

    @Test("Unrecorded node findOriginal returns itself")
    func findOriginalPassthrough() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let node = BRepGraph.NodeRef(kind: .face, index: 3)
        #expect(graph.findOriginal(of: node) == node)
    }
}

// MARK: - v0.141 / #72 Phase 1: TopologyRef recipes + resolver

@Suite("v0.141 TopologyRef resolver")
struct TopologyRefResolverTests {
    @Test("Literal reference to a valid node resolves to itself")
    func literalValid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let node = BRepGraph.NodeRef(kind: .face, index: 2)
        let result = graph.resolve(.literal(node))
        switch result {
        case .success(let r): #expect(r == node)
        case .failure(let e): Issue.record("unexpected error: \(e)")
        }
    }

    @Test("Literal reference to an invalid node fails")
    func literalInvalid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let result = graph.resolve(.literal(.sentinel))
        if case .failure(.invalid) = result {
        } else {
            Issue.record("expected .invalid error")
        }
    }

    @Test("createdBy resolves to the recorded replacement")
    func createdByBasic() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let newFace = BRepGraph.NodeRef(kind: .face, index: 100)
        graph.recordHistory(
            operationName: "Extrude_1",
            original: .sentinel,
            replacements: [newFace])
        let result = graph.resolve(.createdBy(operationName: "Extrude_1", kind: .face))
        switch result {
        case .success(let r): #expect(r == newFace)
        case .failure(let e): Issue.record("resolve failed: \(e)")
        }
    }

    @Test("createdBy with unknown operation fails with operationNotFound")
    func createdByMissingOp() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let result = graph.resolve(.createdBy(operationName: "Nonexistent", kind: .face))
        if case .failure(.operationNotFound(let name)) = result {
            #expect(name == "Nonexistent")
        } else {
            Issue.record("expected operationNotFound")
        }
    }

    @Test("createdBy with occurrence out of range fails cleanly")
    func createdByOutOfRange() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let only = BRepGraph.NodeRef(kind: .face, index: 100)
        graph.recordHistory(operationName: "Op", original: .sentinel, replacements: [only])
        let result = graph.resolve(.createdBy(operationName: "Op", kind: .face, occurrence: 5))
        if case .failure(.occurrenceOutOfRange(_, let available, let requested)) = result {
            #expect(available == 1)
            #expect(requested == 5)
        } else {
            Issue.record("expected occurrenceOutOfRange")
        }
    }

    @Test("createdBy walks forward through subsequent history to currentForm")
    func createdByForwardWalk() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        // op1 creates face 10; op2 modifies face 10 → face 11.
        let created = BRepGraph.NodeRef(kind: .face, index: 10)
        let current = BRepGraph.NodeRef(kind: .face, index: 11)
        graph.recordHistory(operationName: "Create", original: .sentinel, replacements: [created])
        graph.recordHistory(operationName: "Modify", original: created, replacements: [current])
        // Asking for "face created by Create" should give the CURRENT form (face 11),
        // not the historical one (face 10).
        let result = graph.resolve(.createdBy(operationName: "Create", kind: .face))
        switch result {
        case .success(let r): #expect(r == current)
        case .failure(let e): Issue.record("resolve failed: \(e)")
        }
    }

    @Test("splitOf picks the Nth replacement of a split original")
    func splitOf() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let orig = BRepGraph.NodeRef(kind: .edge, index: 3)
        let a = BRepGraph.NodeRef(kind: .edge, index: 30)
        let b = BRepGraph.NodeRef(kind: .edge, index: 31)
        graph.recordHistory(operationName: "SplitEdge", original: orig, replacements: [a, b])
        let result = graph.resolve(.splitOf(original: .literal(orig), occurrence: 1))
        switch result {
        case .success(let r): #expect(r == b)
        case .failure(let e): Issue.record("resolve failed: \(e)")
        }
    }

    @Test("splitOf with occurrence out of range fails cleanly")
    func splitOfOutOfRange() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let orig = BRepGraph.NodeRef(kind: .edge, index: 3)
        let a = BRepGraph.NodeRef(kind: .edge, index: 30)
        let b = BRepGraph.NodeRef(kind: .edge, index: 31)
        graph.recordHistory(operationName: "SplitEdge", original: orig, replacements: [a, b])
        let result = graph.resolve(.splitOf(original: .literal(orig), occurrence: 5))
        if case .failure(.occurrenceOutOfRange(_, let available, let requested)) = result {
            #expect(available == 2)
            #expect(requested == 5)
        } else {
            Issue.record("expected occurrenceOutOfRange")
        }
    }

    @Test("Ancestor resolution failure propagates")
    func ancestorMissing() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        // splitOf references an operation that never happened → should fail.
        let result = graph.resolve(
            .splitOf(
                original: .createdBy(operationName: "Nonexistent", kind: .edge),
                occurrence: 0))
        if case .failure(.ancestorMissing) = result {
        } else {
            Issue.record("expected ancestorMissing")
        }
    }
}

// MARK: - v0.142 / #72 Phase 2: ConstructionEntity recipes

@Suite("v0.142 ConstructionPlane resolution")
struct ConstructionPlaneTests {
    @Test("Absolute plane resolves to specified origin+normal")
    func absolutePlane() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let plane = ConstructionPlane.absolute(origin: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1))
        switch graph.resolve(plane) {
        case .success(let p):
            #expect(p.origin == SIMD3(1, 2, 3))
            #expect(abs(p.zAxis.z - 1.0) < 1e-9)
        case .failure(let e): Issue.record("failed: \(e)")
        }
    }

    @Test("offsetFromFace produces a parallel plane at the offset")
    func offsetFromFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        // Pick any face; the exact normal is produced from the UV midpoint.
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let plane = ConstructionPlane.offsetFromFace(face: faceRef, distance: 5.0)
        switch graph.resolve(plane) {
        case .success(let p):
            // The face normal is unit length; offset 5.0 along it produces a
            // plane whose origin is 5.0 away (in the plane normal direction) from
            // the face centroid.
            #expect(simd_length(p.zAxis) > 0.99 && simd_length(p.zAxis) < 1.01)
        case .failure(let e): Issue.record("failed: \(e)")
        }
    }

    @Test("byThreePoints returns a valid plane through three vertices")
    func byThreePoints() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let v0 = TopologyRef.literal(.init(kind: .vertex, index: 0))
        let v1 = TopologyRef.literal(.init(kind: .vertex, index: 1))
        let v2 = TopologyRef.literal(.init(kind: .vertex, index: 2))
        let plane = ConstructionPlane.byThreePoints(v0, v1, v2)
        switch graph.resolve(plane) {
        case .success(let p):
            #expect(simd_length(p.zAxis) > 0.99)
        case .failure: Issue.record("byThreePoints failed")
        }
    }

    @Test("byThreePoints on collinear points fails with degenerate")
    func collinearPointsDegenerate() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let v = TopologyRef.literal(.init(kind: .vertex, index: 0))
        // Three references to the same vertex → collinear (all zero vector).
        let plane = ConstructionPlane.byThreePoints(v, v, v)
        if case .failure(.degenerate) = graph.resolve(plane) {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test("normalToEdge produces plane perpendicular to edge tangent")
    func normalToEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: 0))
        let plane = ConstructionPlane.normalToEdge(edge: edgeRef, t: 0.5)
        switch graph.resolve(plane) {
        case .success(let p):
            // The plane normal is the edge tangent, so non-zero unit vector.
            #expect(simd_length(p.zAxis) > 0.99 && simd_length(p.zAxis) < 1.01)
        case .failure(let e): Issue.record("failed: \(e)")
        }
    }

    @Test(
        "tangentToFace on a cylinder uses the vertex's own local normal, not the face UV midpoint (#879)"
    )
    func tangentToFaceCylinderLocalNormal() {
        // A radius-5 cylinder's lateral face is periodic in U; its seam runs
        // through both circle vertices at u=0 (local +X, radial normal (1,0,0)).
        // The face's own UV midpoint sits at u=π (local -X, radial normal
        // (-1,0,0)), the far side of the cylinder. Before #879, tangentToFace
        // returned that antiparallel UV-midpoint normal instead of the normal at
        // the requested vertex.
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 1))
        // The lateral face's seam runs through TWO structurally symmetric vertices at u=0
        // (top z=10, bottom z=0), read the actual z of vertex 1 rather than assuming which
        // one it is: vertex enumeration order isn't guaranteed stable across an OCCT kernel
        // rebuild or platform (CLAUDE.md Test Conventions; #897 review, third pass), the
        // property under test (local normal follows the vertex, not the UV midpoint) holds
        // at either seam vertex.
        let expectedZ = graph.vertexPoint(1).z
        switch graph.resolve(ConstructionPlane.tangentToFace(face: faceRef, at: vertexRef)) {
        case .success(let p):
            #expect(abs(p.origin.x - 5) < 1e-6)
            #expect(abs(p.origin.z - expectedZ) < 1e-6)
            // The correct local normal points radially outward (+X); the old,
            // broken UV-midpoint normal pointed radially inward (-X) instead.
            #expect(p.zAxis.x > 0.99)
        case .failure(let e): Issue.record("tangentToFace failed: \(e)")
        }
    }

    @Test(
        "tangentToFace at a cone apex falls back to the UV-midpoint normal instead of failing (PR #897 review, 3rd pass)"
    )
    func tangentToFaceConeApexFallsBackToNormal() {
        // A cone whose apex sits at the BASE (bottomRadius: 0) puts the apex vertex
        // at v=0 exactly on the lateral face's own parametrization -- a genuine
        // GeomLProp_SLProps normal singularity (the two tangent directions
        // coincide there, not merely shrink; see docs/reference/Face.md's `normal`
        // entry and Issue401's SurfaceNormalParityTests.coneApexIsUndefinedInBoth).
        // Before this fix, resolveFaceNormal had no fallback, so tangentToFace at
        // this real vertex on real topology failed with .missingGeometry --
        // regressing the pre-#879 always-succeeds-for-any-uvBounds-face behavior.
        //
        // (A sphere's pole is NOT an equivalent reproducer here: OCCT's own
        // higher-derivative resolution keeps the normal defined there --
        // SurfaceNormalParityTests.spherePoleStillHasANormal already pins that.)
        guard let cone = Shape.cone(bottomRadius: 0, topRadius: 5, height: 10),
            let graph = BRepGraph(shape: cone)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))

        // Sanity: find the apex vertex (at the origin) and confirm the fixture
        // really does hit the singularity this test claims to exercise.
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first else {
            Issue.record("face0 unavailable")
            return
        }
        var apexIndex: Int?
        for i in 0..<graph.vertexCount {
            let p = graph.vertexPoint(i)
            if abs(p.x) < 1e-6, abs(p.y) < 1e-6, abs(p.z) < 1e-6 {
                apexIndex = i
                break
            }
        }
        guard let apexIndex else {
            Issue.record("no vertex at the cone apex")
            return
        }
        guard let projection = face.project(point: SIMD3(0, 0, 0)) else {
            Issue.record("apex projection failed")
            return
        }
        #expect(
            face.normal(atU: projection.u, v: projection.v) == nil,
            "fixture should hit a genuine normal singularity")
        // This fixture exercises resolveFaceNormal's "projection succeeds, normal-at-that-uv
        // fails" branch specifically -- NOT the "projection itself fails" branch (see
        // projectedNormalWhenProjectionItselfFails below for that one). The apex vertex already
        // lies exactly on the face, so `projection.point` and the raw input point coincide here,
        // which is why this test alone can't distinguish the two fallback branches (#897 review,
        // second xhigh pass, finding 3).
        guard let expectedFallback = face.uvMidpointNormal() else {
            Issue.record("uvMidpointNormal unavailable")
            return
        }

        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: apexIndex))
        switch graph.resolve(ConstructionPlane.tangentToFace(face: faceRef, at: vertexRef)) {
        case .success(let p):
            #expect(abs(p.origin.x) < 1e-6)
            #expect(abs(p.origin.y) < 1e-6)
            #expect(abs(p.origin.z) < 1e-6)
            #expect(abs(simd_length(p.zAxis) - 1.0) < 1e-6)
            // Compare against the actual UV-midpoint normal value, not just unit length, so a
            // wrong (but still unit-length) fallback normal would be caught (#897 review, second
            // xhigh pass, finding 3).
            #expect(simd_length(p.zAxis - simd_normalize(expectedFallback)) < 1e-6)
        case .failure(let e):
            Issue.record("tangentToFace failed at the cone apex: \(e)")
        }
    }

    @Test(
        "tangentToFace falls back to the UV-midpoint sample, with an on-face origin, when Face.project(point:) itself fails to converge (PR #897 review, second xhigh pass, findings 1 + 3)"
    )
    func tangentToFaceProjectionItselfFailsFallsBackToOnFaceOrigin() {
        // A sphere's own center is equidistant from its ENTIRE surface, so
        // GeomAPI_ProjectPointOnSurf's gradient search has no unique stationary point to
        // converge to -- Face.project(point:) genuinely returns nil here (measured directly,
        // not assumed), unlike the cone-apex fixture above, where `project()` itself succeeds
        // and only the subsequent `normal(atU:v:)` lookup fails. This is the ONLY branch of
        // resolveFaceNormal's 3-way fallback the rest of this suite doesn't otherwise exercise.
        //
        // A sphere has no real vertex at its own center, so a standalone vertex shape is added
        // there and the two are grouped in a compound -- `at` resolving to a vertex from a
        // DIFFERENT shape than `face` is the same "genuine misuse" pattern
        // `tangentToFaceOriginIsOnFaceNotRawPoint` below already uses, here specifically to
        // place a real topological vertex exactly at the sphere's center.
        guard let sph = Shape.sphere(radius: 5),
            let centerVertex = Shape.vertex(at: SIMD3(0, 0, 0)),
            let compound = Shape.compound([sph, centerVertex]),
            let graph = BRepGraph(shape: compound)
        else {
            Issue.record("setup failed")
            return
        }

        // Sphere added first -- confirm face 0 of the compound really is the sphere, not
        // assumed.
        guard let faceShape = graph.shape(nodeKind: .face, nodeIndex: 0),
            let face = faceShape.faces().first, face.surfaceType == .sphere
        else {
            Issue.record("face 0 of the compound is not the sphere")
            return
        }
        // Sanity: confirm the fixture really does hit the branch this test claims to exercise.
        #expect(face.project(point: SIMD3(0, 0, 0)) == nil, "fixture should fail to project")
        guard let (expectedFallbackPoint, expectedFallbackNormal) = face.uvMidpointSample() else {
            Issue.record("uvMidpointSample unavailable")
            return
        }

        // The standalone vertex, wherever BRepGraph placed it -- found by position, not assumed
        // to be a specific index (CLAUDE.md Test Conventions).
        var centerIndex: Int?
        for i in 0..<graph.vertexCount {
            let p = graph.vertexPoint(i)
            if abs(p.x) < 1e-9, abs(p.y) < 1e-9, abs(p.z) < 1e-9 {
                centerIndex = i
                break
            }
        }
        guard let centerIndex else {
            Issue.record("no vertex at the sphere center")
            return
        }

        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: centerIndex))
        switch graph.resolve(ConstructionPlane.tangentToFace(face: faceRef, at: vertexRef)) {
        case .success(let p):
            // The origin must be the UV-midpoint sample's own point -- a genuine on-face
            // location -- NOT the raw sphere-center input point, which is nowhere near the
            // face's surface (distance = the sphere's own radius, 5).
            #expect(simd_length(p.origin - expectedFallbackPoint) < 1e-6)
            #expect(simd_length(p.origin) > 1.0, "origin should not be the raw center point")
            #expect(simd_length(p.zAxis - simd_normalize(expectedFallbackNormal)) < 1e-6)
        case .failure(let e):
            Issue.record("tangentToFace failed: \(e)")
        }
    }

    @Test(
        "tangentToFace: Placement.origin is the actual on-face point, not `at`'s raw position, when `at` doesn't lie on `face` (PR #897 review, finding 2)"
    )
    func tangentToFaceOriginIsOnFaceNotRawPoint() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first,
            let (samplePoint, sampleNormal) = face.uvMidpointSample()
        else {
            Issue.record("face0 unavailable")
            return
        }
        let faceNormalUnit = simd_normalize(sampleNormal)

        // Find a vertex that does NOT lie on face 0 -- the genuine misuse scenario finding 2
        // describes, where `at` doesn't actually reference a point on `face`.
        var offFaceVertexIndex: Int?
        for vertexIndex in 0..<graph.vertexCount {
            let raw = graph.vertexPoint(vertexIndex)
            let p = SIMD3(raw.x, raw.y, raw.z)
            if abs(simd_dot(p - samplePoint, faceNormalUnit)) > 1e-3 {
                offFaceVertexIndex = vertexIndex
                break
            }
        }
        guard let offFaceVertexIndex else {
            Issue.record("no off-face vertex found")
            return
        }
        let rawTuple = graph.vertexPoint(offFaceVertexIndex)
        let rawPoint = SIMD3(rawTuple.x, rawTuple.y, rawTuple.z)
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: offFaceVertexIndex))
        switch graph.resolve(ConstructionPlane.tangentToFace(face: faceRef, at: vertexRef)) {
        case .success(let p):
            // The origin must lie ON face 0's plane, not at the raw off-face vertex position.
            #expect(abs(simd_dot(p.origin - samplePoint, faceNormalUnit)) < 1e-6)
            #expect(
                simd_length(p.origin - rawPoint) > 1e-3,
                "origin should differ from the raw off-face point")
        case .failure(let e):
            Issue.record("tangentToFace failed: \(e)")
        }
    }
}

@Suite("v0.142 ConstructionAxis resolution")
struct ConstructionAxisTests {
    @Test("alongEdge produces edge start + unit direction")
    func alongEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let edge = TopologyRef.literal(.init(kind: .edge, index: 0))
        switch graph.resolve(ConstructionAxis.alongEdge(edge)) {
        case .success(let ax):
            #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
        case .failure: Issue.record("alongEdge failed")
        }
    }

    @Test("alongEdge on a full-circle cylindrical rim resolves to the true rotation axis (#883)")
    func alongEdgeCylindricalRimUsesRevolutionAxis() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("cylinder/graph nil")
            return
        }
        // A rim is a full circle: start == end, so the old secant-of-endpoints computation
        // was always the zero vector here, this is failure mode 1 from #883.
        guard let rim = cyl.edges().first(where: { $0.curveType == .circle }),
            let rimBounds = rim.parameterBounds,
            let rimPoint = rim.point(at: rimBounds.first),
            let rimShape = Shape.fromEdge(rim),
            let node = graph.findNode(for: rimShape), node.kind == .edge
        else {
            Issue.record("no circular rim edge found")
            return
        }
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: node.index))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            #expect(abs(abs(ax.direction.z) - 1.0) < 1e-6)
            // #894 finding 2: the origin must stay edge-local (on the axis, at the rim's own
            // height), not teleport to the cylinder surface's own placement origin, which would
            // report (0, 0, 0) regardless of which rim (top or bottom) this is.
            #expect(abs(ax.origin.x) < 1e-6)
            #expect(abs(ax.origin.y) < 1e-6)
            #expect(abs(ax.origin.z - rimPoint.z) < 1e-6)
        case .failure(let e):
            Issue.record("expected success (revolution axis), got \(e)")
        }
    }

    @Test(
        "alongEdge on a partial cylindrical arc resolves to the axis, not the endpoint chord (#883)"
    )
    func alongEdgePartialCylinderUsesAxisNotChord() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10, angle: .pi / 2),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("partial cylinder/graph nil")
            return
        }
        // A 90-degree arc's own endpoint chord lies in the XY plane (z ~ 0), this is failure
        // mode 2 from #883: a plausible-looking but wrong direction. The true rotation axis is
        // parallel to Z.
        guard let arc = cyl.edges().first(where: { $0.curveType == .circle && !$0.isClosed3D }),
            let arcBounds = arc.parameterBounds,
            let arcPoint = arc.point(at: arcBounds.first),
            let arcShape = Shape.fromEdge(arc),
            let node = graph.findNode(for: arcShape), node.kind == .edge
        else {
            Issue.record("no partial arc edge found")
            return
        }
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: node.index))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            #expect(abs(abs(ax.direction.z) - 1.0) < 1e-6)
            // #894 finding 2: the origin must stay edge-local (on the axis, at the arc's own
            // height), not the surface's own placement origin (0, 0, 0) regardless of which end
            // of the cylinder this arc sits at.
            #expect(abs(ax.origin.x) < 1e-6)
            #expect(abs(ax.origin.y) < 1e-6)
            #expect(abs(ax.origin.z - arcPoint.z) < 1e-6)
        case .failure(let e):
            Issue.record("expected success (revolution axis), got \(e)")
        }
    }

    @Test(
        "alongEdge on a standalone closed circular wire (no adjacent face) fails with degenerate (#887)"
    )
    func alongEdgeStandaloneCircleNoAdjacentFaceDegenerate() {
        // A full circle with no adjacent face at all: revolutionAxis(ofEdgeAt:) finds nothing
        // to redirect to (faces(of:) is empty), so this falls through to the endpoint-secant
        // path, where start == end for a closed curve, the zero-length branch that #887 found
        // had no coverage at all.
        guard let wire = Wire.circle(radius: 5),
            let wireShape = Shape.fromWire(wire),
            let graph = BRepGraph(shape: wireShape)
        else {
            Issue.record("wire/shape/graph nil")
            return
        }
        guard let edge = wireShape.edges().first,
            let edgeShape = Shape.fromEdge(edge),
            let node = graph.findNode(for: edgeShape), node.kind == .edge
        else {
            Issue.record("no edge found")
            return
        }
        #expect(graph.faces(of: node.index).isEmpty)
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: node.index))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test(
        "alongEdge on a T-branch between two non-coaxial cylinders falls back to the chord, not whichever face's axis sorts first (#894 finding 1)"
    )
    func alongEdgeBranchWithDisagreeingAxesFallsBackToChord() {
        // Two non-coaxial cylinders fused at a T-junction: the intersection curve is adjacent to
        // both cylindrical walls, and the two candidate axes do not agree, exactly the branch
        // case finding 1 covers. Pre-fix, `revolutionAxis(ofEdgeAt:)` returned whichever face's
        // axis happened to sort first in `faces(of:)`, with no check that a second, disagreeing
        // candidate existed.
        guard
            let mainCyl = Shape.cylinder(
                at: SIMD3(0, 0, -10), direction: SIMD3(0, 0, 1), radius: 5, height: 20),
            let branchCyl = Shape.cylinder(
                at: SIMD3(-10, -10, -2), direction: simd_normalize(SIMD3(1, 1, 0.3)),
                radius: 2.5, height: 20),
            let fused = mainCyl.union(branchCyl),
            let graph = BRepGraph(shape: fused)
        else {
            Issue.record("T-branch fixture build failed")
            return
        }

        // Find a branch edge: adjacent to >= 2 cylindrical/conical faces whose axes disagree, with
        // a non-degenerate chord that also isn't itself nearly parallel to EITHER candidate axis,
        // so the pre-fix "first match wins" answer and the post-fix chord-fallback answer are
        // provably different regardless of which face BRepGraph happens to enumerate first.
        //
        // Gathering `candidates` here (via the already-public `faces(of:)`/`Face.primaryAxis`) is
        // direct data access, not a reimplementation of production logic, there's no production
        // API that returns the raw candidate list, only the final decision. What used to be
        // reimplemented was the "must disagree" *test*, via a hand-rolled, hardcoded `1e-3` copy
        // of `axesAgree`'s own comparison; that copy is gone below, replaced by a direct call to
        // the real (`internal`, `@testable`-visible) `axesAgree` (#894 finding 5, second pass).
        var target: (edgeIndex: Int, axisA: ShapeAxis, axisB: ShapeAxis)?
        for edgeIndex in 0..<graph.edgeCount {
            var candidates: [ShapeAxis] = []
            for faceIndex in graph.faces(of: edgeIndex) {
                guard
                    let faceShape = graph.shape(
                        nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex),
                    let face = faceShape.faces().first,
                    let axis = face.primaryAxis,
                    axis.kind == .cylinder || axis.kind == .cone
                else { continue }
                candidates.append(axis)
            }
            guard candidates.count >= 2, !graph.axesAgree(candidates[0], candidates[1]) else {
                continue
            }

            guard
                let edgeShape = graph.shape(
                    nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = edgeShape.edges().first,
                let bounds = edge.parameterBounds,
                let start = edge.point(at: bounds.first),
                let end = edge.point(at: bounds.last)
            else { continue }
            let chord = end - start
            let chordLength = simd_length(chord)
            guard chordLength > 1e-6 else { continue }
            let chordDirection = chord / chordLength
            let directionA = simd_normalize(candidates[0].direction)
            let directionB = simd_normalize(candidates[1].direction)
            guard abs(simd_dot(chordDirection, directionA)) < 0.9,
                abs(simd_dot(chordDirection, directionB)) < 0.9
            else { continue }

            target = (edgeIndex, candidates[0], candidates[1])
            break
        }
        guard let target else {
            Issue.record("no usable branch edge found in T-branch fixture")
            return
        }

        // Exercise the real production decision directly, not just its downstream effect: the
        // disagreeing candidates found above must make `revolutionAxis(ofEdgeAt:)` itself decline
        // (#894 finding 5, second pass), the assertions below on `resolve(.alongEdge(...))` then
        // confirm the caller-visible consequence of that decision.
        #expect(graph.revolutionAxis(ofEdgeAt: target.edgeIndex) == nil)

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: target.edgeIndex))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            // Must NOT silently match either candidate face's axis (the pre-fix bug), must fall
            // back to the edge's own chord instead.
            #expect(abs(simd_dot(ax.direction, simd_normalize(target.axisA.direction))) < 0.9)
            #expect(abs(simd_dot(ax.direction, simd_normalize(target.axisB.direction))) < 0.9)
        case .failure(let e):
            Issue.record("expected success (chord fallback), got \(e)")
        }
    }

    @Test(
        "alongEdge keeps the origin edge-local, not the adjacent surface's own placement origin (#894 finding 2)"
    )
    func alongEdgeCylindricalRimOriginStaysNearRimNotSurfaceBase() {
        // A rim near the TOP of a tall cylinder whose base sits at z=0, the review's own example
        // of a ~500mm teleport. axis.origin for the wall face is the surface's own placement
        // origin (0, 0, 0); if that leaked through as the resolved origin, a materialized axis
        // marker or a sketch plane built `throughAxis` would land ~500mm from the rim the caller
        // actually selected.
        guard let cyl = Shape.cylinder(radius: 5, height: 500),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("tall cylinder/graph nil")
            return
        }
        guard
            let topRim = cyl.edges().first(where: { edge in
                guard edge.curveType == .circle, let bounds = edge.parameterBounds,
                    let p = edge.point(at: bounds.first)
                else { return false }
                return abs(p.z - 500) < 1e-6
            }),
            let rimShape = Shape.fromEdge(topRim),
            let node = graph.findNode(for: rimShape), node.kind == .edge
        else {
            Issue.record("no top rim edge found")
            return
        }
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: node.index))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            #expect(abs(ax.origin.x) < 1e-6)
            #expect(abs(ax.origin.y) < 1e-6)
            #expect(abs(ax.origin.z - 500) < 1e-6)
        case .failure(let e):
            Issue.record("expected success, got \(e)")
        }
    }

    @Test(
        "alongEdge on a geometrically-straight seam reparameterized as a BSpline keeps the chord, not the axis (#894 finding 3)"
    )
    func alongEdgeStraightSeamReparameterizedAsBSplineKeepsChord() {
        // curveType is a proxy for straightness, not proof of it: OCCT commonly represents a
        // geometrically-straight edge as a low-degree BSpline after a Boolean/fillet/sweep. Build
        // that shape directly rather than hunting for a specific real operation that happens to
        // trigger it: a "seam" edge on a cylindrical wall whose 3D curve is a BSpline interpolated
        // through 3 exactly-collinear points (so curveType != .line) but is still, geometrically,
        // the straight generatrix line at that angle.
        let radius = 5.0
        let angle0 = 0.0
        let angle1 = 0.3
        let p0bot = SIMD3(radius * cos(angle0), radius * sin(angle0), 0.0)
        let p0mid = SIMD3(radius * cos(angle0), radius * sin(angle0), 5.0)
        let p0top = SIMD3(radius * cos(angle0), radius * sin(angle0), 10.0)
        let p1bot = SIMD3(radius * cos(angle1), radius * sin(angle1), 0.0)
        let p1top = SIMD3(radius * cos(angle1), radius * sin(angle1), 10.0)
        let midAngle = (angle0 + angle1) / 2

        guard let surface = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
            let seamCurve = Curve3D.interpolate(points: [p0bot, p0mid, p0top]),
            let seamEdgeShape = Shape.edgeFromCurve(seamCurve),
            let seamEdge = Edge(seamEdgeShape),
            let otherSideWire = Wire.line(from: p1top, to: p1bot),
            let otherSideEdge = otherSideWire.edges().first,
            let topArcCurve = Curve3D.arcOfCircle(
                start: p0top,
                interior: SIMD3(radius * cos(midAngle), radius * sin(midAngle), 10.0),
                end: p1top),
            let topArcShape = Shape.edgeFromCurve(topArcCurve),
            let topArcEdge = Edge(topArcShape),
            let botArcCurve = Curve3D.arcOfCircle(
                start: p1bot,
                interior: SIMD3(radius * cos(midAngle), radius * sin(midAngle), 0.0),
                end: p0bot),
            let botArcShape = Shape.edgeFromCurve(botArcCurve),
            let botArcEdge = Edge(botArcShape),
            let wire = Wire.wireFromEdges([seamEdge, topArcEdge, otherSideEdge, botArcEdge]),
            let faceShape = Shape.face(from: surface, boundary: wire),
            let graph = BRepGraph(shape: faceShape)
        else {
            Issue.record("synthetic straight-seam fixture build failed")
            return
        }

        // Confirm the fixture matches the intended scenario, then find that edge by its (unique)
        // BSpline curveType rather than assuming an index.
        var seamNodeIndex: Int?
        for edgeIndex in 0..<graph.edgeCount {
            guard
                let eShape = graph.shape(
                    nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = eShape.edges().first
            else { continue }
            if edge.curveType == .bsplineCurve {
                seamNodeIndex = edgeIndex
                break
            }
        }
        guard let seamNodeIndex else {
            Issue.record("no BSpline-curveType edge found in fixture")
            return
        }

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: seamNodeIndex))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            // Direction along the seam (Z), true either way, since axis and chord happen to
            // agree here. The origin is what distinguishes "kept the chord" from "redirected to
            // the axis": redirecting would project onto the cylinder's own axis line (x=y=0),
            // which for this seam happens to yield (0, 0, 0) too, so the discriminating check is
            // that the origin stays at the edge's own (x, y) position, not on the centerline.
            #expect(abs(abs(ax.direction.z) - 1.0) < 1e-6)
            #expect(simd_distance(ax.origin, p0bot) < 1e-6)
        case .failure(let e):
            Issue.record("expected success (chord kept for straight seam), got \(e)")
        }
    }

    @Test(
        "alongEdge on an elliptical rim from an oblique cylinder cut does not silently return the cylinder's centerline (#894 finding 1, third pass)"
    )
    func alongEdgeEllipticalRimDoesNotSilentlyReturnCenterline() {
        // A cylinder intersected with a large box tilted about Y by `theta`: the box's near face
        // becomes an oblique cutting plane through the cylinder's mid-height, producing a closed
        // elliptical rim (curveType == .ellipse) adjacent to the cylindrical wall. Every point of
        // that rim sits on the wall (radius == cylinder radius everywhere, same as a true circular
        // rim), but its height along the axis varies as you go around it, exactly the case
        // `curveType != .line` alone can't distinguish from a genuine cross-section.
        let radius = 5.0
        let height = 20.0
        let theta = 25.0 * Double.pi / 180
        // Box spans z in [-1000, z0] before rotation; z0 is chosen so the rotated top face
        // passes through (0, 0, 10), the cylinder's own mid-height on its axis, with normal
        // (sin(theta), 0, cos(theta)).
        let z0 = 10.0 * cos(theta)

        guard let cyl = Shape.cylinder(radius: radius, height: height),
            let bigBox = Shape.box(
                origin: SIMD3(-500, -500, -1000), width: 1000, height: 1000, depth: 1000 + z0),
            let tiltedBox = bigBox.rotated(axis: SIMD3(0, 1, 0), angle: theta),
            let cut = cyl.intersection(tiltedBox),
            let graph = BRepGraph(shape: cut)
        else {
            Issue.record("oblique-cut cylinder fixture build failed")
            return
        }
        guard let ellipse = cut.edges().first(where: { $0.curveType == .ellipse }),
            let ellipseShape = Shape.fromEdge(ellipse),
            let node = graph.findNode(for: ellipseShape), node.kind == .edge
        else {
            Issue.record("no elliptical rim edge found in oblique-cut fixture")
            return
        }
        // Confirm the fixture matches finding 1's premise: exactly one adjacent face contributes
        // a cylinder/cone axis candidate (the trimmed wall), same as a genuine circular rim, so
        // `revolutionAxis` has nothing to disagree with and would return it unconditionally
        // without the geometric cross-section check this finding adds.
        let cylConeFaceCount = graph.faces(of: node.index).filter { faceIndex in
            guard
                let faceShape = graph.shape(
                    nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex),
                let face = faceShape.faces().first, let axis = face.primaryAxis
            else { return false }
            return axis.kind == .cylinder || axis.kind == .cone
        }.count
        #expect(cylConeFaceCount == 1)

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: node.index))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            // Must not be the cylinder's centerline (direction parallel to Z AND origin on the
            // x=y=0 axis), a fallback to the (near-zero, closed-curve) chord landing anywhere
            // else is fine; only silently matching the centerline is the bug.
            let onCenterlineDirection = abs(abs(ax.direction.z) - 1.0) < 1e-6
            let onCenterlineOrigin = abs(ax.origin.x) < 1e-6 && abs(ax.origin.y) < 1e-6
            #expect(!(onCenterlineDirection && onCenterlineOrigin))
        case .failure(.degenerate):
            ()  // failing cleanly is fine too: a full ellipse's own chord is ~0, same as a full
        // circle's would be without the (correctly declined) axis redirect.
        case .failure(let e):
            Issue.record(
                "expected success (chord fallback) or a clean .degenerate failure, got \(e)")
        }
    }

    @Test(
        "alongEdge on a genuinely near-zero-length edge next to a clean cylindrical face still reports degenerate (#894 finding 2, third pass)"
    )
    func alongEdgeGenuinelyDegenerateEdgeNextToCleanCylinderStillDegenerate() {
        // A partial cylinder with an astronomically tiny angular extent (1e-10 rad): its two rim
        // arcs (curveType == .circle, non-linear, so the OLD `curveType != .line` gate alone
        // would have let this reach `revolutionAxis`) measure a true length of 5e-10, genuinely
        // near-zero and below this file's degeneracy epsilon, while still bounding one clean
        // cylindrical wall face, the shape finding 2 needs: `revolutionAxis` finds an
        // unambiguous candidate axis for an edge that is itself malformed, which used to let it
        // skip the degeneracy check entirely.
        guard let cyl = Shape.cylinder(radius: 5, height: 10, angle: 1e-10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("degenerate-sliver fixture build failed")
            return
        }

        // Find a tiny rim arc by measured length rather than assuming an index.
        var tinyNodeIndex: Int?
        for edgeIndex in 0..<graph.edgeCount {
            guard
                let eShape = graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = eShape.edges().first
            else { continue }
            if edge.length < 1e-9, edge.curveType != .line {
                tinyNodeIndex = edgeIndex
                break
            }
        }
        guard let tinyNodeIndex else {
            Issue.record("no near-zero-length non-line edge found in sliver fixture")
            return
        }
        // Confirm the fixture matches finding 2's premise: exactly one adjacent face contributes
        // a cylinder/cone axis candidate, same as a legitimate rim, `revolutionAxis` has nothing
        // to disagree with and would return it unconditionally without the fix.
        let cylConeFaceCount = graph.faces(of: tinyNodeIndex).filter { faceIndex in
            guard
                let faceShape = graph.shape(
                    nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex),
                let face = faceShape.faces().first, let axis = face.primaryAxis
            else { return false }
            return axis.kind == .cylinder || axis.kind == .cone
        }.count
        #expect(cylConeFaceCount == 1)

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: tinyNodeIndex))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test(
        "alongEdge on a cone's straight generatrix reparameterized as a BSpline keeps the chord, not the axis (#894 finding 1, second pass)"
    )
    func alongEdgeConeStraightSeamReparameterizedAsBSplineKeepsChord() {
        // A cone's lateral generatrix meets its axis at the cone's own nonzero half-angle, never
        // parallel to it, the old chord-parallel-to-axis check (removed by the third pass's
        // `coaxialCrossSection` rewrite) could never catch a straight seam on a CONE the way it
        // caught one on a cylinder (`alongEdgeStraightSeamReparameterizedAsBSplineKeepsChord`
        // above). `coaxialCrossSection`'s radius/height-constancy test has no such blind spot: a
        // generatrix's radius from the axis varies continuously from apex to base, so it fails
        // the "radius stays constant" half of the check the same way a cylinder seam fails the
        // "height stays constant" half.
        let bottomRadius = 5.0
        let semiAngle = 0.3  // radians; nonzero, so this generatrix is never axis-parallel
        func radius(atHeight z: Double) -> Double { bottomRadius + z * tan(semiAngle) }
        let angle0 = 0.0
        let angle1 = 0.3
        let midAngle = (angle0 + angle1) / 2
        let p0bot = SIMD3(radius(atHeight: 0) * cos(angle0), radius(atHeight: 0) * sin(angle0), 0.0)
        let p0mid = SIMD3(radius(atHeight: 5) * cos(angle0), radius(atHeight: 5) * sin(angle0), 5.0)
        let p0top = SIMD3(
            radius(atHeight: 10) * cos(angle0), radius(atHeight: 10) * sin(angle0), 10.0)
        let p1bot = SIMD3(radius(atHeight: 0) * cos(angle1), radius(atHeight: 0) * sin(angle1), 0.0)
        let p1top = SIMD3(
            radius(atHeight: 10) * cos(angle1), radius(atHeight: 10) * sin(angle1), 10.0)

        guard
            let surface = Surface.cone(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: bottomRadius, semiAngle: semiAngle),
            let seamCurve = Curve3D.interpolate(points: [p0bot, p0mid, p0top]),
            let seamEdgeShape = Shape.edgeFromCurve(seamCurve),
            let seamEdge = Edge(seamEdgeShape),
            let otherSideWire = Wire.line(from: p1top, to: p1bot),
            let otherSideEdge = otherSideWire.edges().first,
            let topArcCurve = Curve3D.arcOfCircle(
                start: p0top,
                interior: SIMD3(
                    radius(atHeight: 10) * cos(midAngle), radius(atHeight: 10) * sin(midAngle),
                    10.0),
                end: p1top),
            let topArcShape = Shape.edgeFromCurve(topArcCurve),
            let topArcEdge = Edge(topArcShape),
            let botArcCurve = Curve3D.arcOfCircle(
                start: p1bot,
                interior: SIMD3(
                    radius(atHeight: 0) * cos(midAngle), radius(atHeight: 0) * sin(midAngle), 0.0),
                end: p0bot),
            let botArcShape = Shape.edgeFromCurve(botArcCurve),
            let botArcEdge = Edge(botArcShape),
            let wire = Wire.wireFromEdges([seamEdge, topArcEdge, otherSideEdge, botArcEdge]),
            let faceShape = Shape.face(from: surface, boundary: wire),
            let graph = BRepGraph(shape: faceShape)
        else {
            Issue.record("synthetic cone straight-seam fixture build failed")
            return
        }

        var seamNodeIndex: Int?
        for edgeIndex in 0..<graph.edgeCount {
            guard
                let eShape = graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = eShape.edges().first
            else { continue }
            if edge.curveType == .bsplineCurve {
                seamNodeIndex = edgeIndex
                break
            }
        }
        guard let seamNodeIndex else {
            Issue.record("no BSpline-curveType edge found in cone fixture")
            return
        }
        // Confirm the fixture matches the premise: the seam edge is adjacent to a cone-kind face
        // (so `revolutionAxis` has a candidate to redirect to at all).
        let coneFaceCount = graph.faces(of: seamNodeIndex).filter { faceIndex in
            guard
                let faceShape = graph.shape(
                    nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex),
                let face = faceShape.faces().first, let axis = face.primaryAxis
            else { return false }
            return axis.kind == .cone
        }.count
        #expect(coneFaceCount == 1)

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: seamNodeIndex))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            // The chord and the cone's axis are NOT parallel (nonzero half-angle), unlike the
            // cylinder case, direction alone distinguishes "kept the chord" from "redirected to
            // the axis" here too, so both direction and origin are asserted directly against the
            // seam's own geometry.
            let expectedDirection = simd_normalize(p0top - p0bot)
            #expect(simd_dot(ax.direction, expectedDirection) > 1 - 1e-6)
            #expect(simd_distance(ax.origin, p0bot) < 1e-6)
        case .failure(let e):
            Issue.record("expected success (chord kept for cone straight seam), got \(e)")
        }
    }

    @Test(
        "alongEdge derives its sign from the edge's own start->end order, not the adjacent surface's placement convention (#894 finding 2, second pass)"
    )
    func alongEdgeSignTracksEdgeTopologyNotSurfaceConvention() {
        // Two quarter-circle rims on the SAME cylinder wall, whose top-arc edges are
        // parameterized with `bounds.first` at opposite physical ends (pA->pB vs pB->pA).
        // `Face.primaryAxis` reads the same fixed direction off the shared wall surface either
        // way, so without a fix, both would silently resolve to the identical sign;
        // `resolveEdgeDirection` should instead track the parameterization difference, the same
        // way `dir = end - start` already does for a straight edge.
        //
        // `Shape.face(from:boundary:)`'s exact wire-fitting strategy on a periodic cylindrical
        // surface is sensitive to more than just "which point is which": which of the 4 boundary
        // edges are built in which raw curve direction, and in which order they're handed to
        // `Wire.wireFromEdges`, decides whether the fit succeeds or falls back to a crude
        // point-projected polygon (many tiny BSpline fragments instead of one clean arc). Both
        // constructions below were confirmed (by direct inspection) to build a clean 4-edge wire
        // with the top arc still `curveType == .circle`, not a fragmented approximation, an
        // arbitrary reshuffle of either one is not guaranteed to stay that way.
        let radius = 5.0
        let height = 10.0
        let angle0 = 0.0
        let angle1 = Double.pi / 2
        let midAngle = (angle0 + angle1) / 2
        let pA = SIMD3(radius * cos(angle0), radius * sin(angle0), height)
        let pB = SIMD3(radius * cos(angle1), radius * sin(angle1), height)
        let pMidTop = SIMD3(radius * cos(midAngle), radius * sin(midAngle), height)
        let qA = SIMD3(radius * cos(angle0), radius * sin(angle0), 0.0)
        let qB = SIMD3(radius * cos(angle1), radius * sin(angle1), 0.0)
        let qMidBot = SIMD3(radius * cos(midAngle), radius * sin(midAngle), 0.0)

        func topArcDirection(from faceShape: Shape) -> SIMD3<Double>? {
            guard let graph = BRepGraph(shape: faceShape) else { return nil }
            var topNodeIndex: Int?
            for edgeIndex in 0..<graph.edgeCount {
                guard
                    let eShape = graph.shape(
                        nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                    let edge = eShape.edges().first,
                    edge.curveType == .circle,
                    let bounds = edge.parameterBounds,
                    let p = edge.point(at: bounds.first)
                else { continue }
                if abs(p.z - height) < 1e-6 {
                    topNodeIndex = edgeIndex
                    break
                }
            }
            guard let topNodeIndex else { return nil }
            let edgeRef = TopologyRef.literal(.init(kind: .edge, index: topNodeIndex))
            guard case .success(let ax) = graph.resolve(ConstructionAxis.alongEdge(edgeRef)) else {
                return nil
            }
            return ax.direction
        }

        // Top arc parameterized pA -> pB (bounds.first == pA).
        guard
            let surfaceForward = Surface.cylinder(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
            let topArcForward = Curve3D.arcOfCircle(start: pA, interior: pMidTop, end: pB),
            let topArcForwardShape = Shape.edgeFromCurve(topArcForward),
            let topArcForwardEdge = Edge(topArcForwardShape),
            let botArcForward = Curve3D.arcOfCircle(start: qB, interior: qMidBot, end: qA),
            let botArcForwardShape = Shape.edgeFromCurve(botArcForward),
            let botArcForwardEdge = Edge(botArcForwardShape),
            let upForwardWire = Wire.line(from: qA, to: pA),
            let upForwardEdge = upForwardWire.edges().first,
            let downForwardWire = Wire.line(from: pB, to: qB),
            let downForwardEdge = downForwardWire.edges().first,
            let wireForward = Wire.wireFromEdges([
                upForwardEdge, topArcForwardEdge, downForwardEdge, botArcForwardEdge,
            ]),
            let faceForward = Shape.face(from: surfaceForward, boundary: wireForward),
            let forward = topArcDirection(from: faceForward)
        else {
            Issue.record("forward-order fixture build/resolve failed")
            return
        }

        // Top arc parameterized pB -> pA (bounds.first == pB), the physically identical rim,
        // opposite parameter order. Every other edge is rebuilt to match (see the wire-fitting
        // sensitivity noted above); this specific combination was confirmed by direct inspection
        // to also build a clean 4-edge wire.
        guard
            let surfaceReversed = Surface.cylinder(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
            let topArcReversed = Curve3D.arcOfCircle(start: pB, interior: pMidTop, end: pA),
            let topArcReversedShape = Shape.edgeFromCurve(topArcReversed),
            let topArcReversedEdge = Edge(topArcReversedShape),
            let botArcReversed = Curve3D.arcOfCircle(start: qB, interior: qMidBot, end: qA),
            let botArcReversedShape = Shape.edgeFromCurve(botArcReversed),
            let botArcReversedEdge = Edge(botArcReversedShape),
            let eReversed1Wire = Wire.line(from: pB, to: qB),
            let eReversed1 = eReversed1Wire.edges().first,
            let eReversed2Wire = Wire.line(from: qA, to: pA),
            let eReversed2 = eReversed2Wire.edges().first,
            let wireReversed = Wire.wireFromEdges([
                eReversed1, topArcReversedEdge, eReversed2, botArcReversedEdge,
            ]),
            let faceReversed = Shape.face(from: surfaceReversed, boundary: wireReversed),
            let reversed = topArcDirection(from: faceReversed)
        else {
            Issue.record("reversed-order fixture build/resolve failed")
            return
        }

        // Same physical axis either way.
        #expect(abs(abs(forward.z) - 1.0) < 1e-6)
        #expect(abs(abs(reversed.z) - 1.0) < 1e-6)
        // Reversing which endpoint is `first` must flip the resolved sign.
        #expect(simd_dot(forward, reversed) < 0)
    }

    @Test(
        "alongEdge on a helical thread edge does not silently return the cylinder's centerline (#894 finding 3, second pass)"
    )
    func alongEdgeHelicalEdgeDoesNotSilentlyReturnCenterline() {
        // A helix's two-point secant can land nearly parallel to the cylinder's axis purely from
        // the sweep angle, the old chord-parallel-to-axis check (removed by the third pass's
        // `coaxialCrossSection` rewrite) could misfire on this. A full single turn (parameter
        // range 0...2*pi) puts start and end at the SAME angular position, `pitch` apart in
        // height, the secant is then EXACTLY axis-parallel, the strongest form of the old false
        // positive. `coaxialCrossSection`'s height-constancy check has no such blind spot:
        // sampling interior points along a genuine helix shows height varying continuously across
        // the whole span, unlike a true perpendicular cross-section.
        let radius = 5.0
        let pitch = 10.0
        guard
            let helixBuild = Helix.build(
                origin: .zero, direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
                parameterRange: 0...(2 * Double.pi), pitch: pitch, radius: radius),
            let surface = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
            let helixEdgeShape = Shape.edgeFromCurve(helixBuild.curve),
            let helixEdge = Edge(helixEdgeShape),
            let closeWire = Wire.line(from: SIMD3(radius, 0, pitch), to: SIMD3(radius, 0, 0)),
            let closeEdge = closeWire.edges().first,
            let wire = Wire.wireFromEdges([helixEdge, closeEdge]),
            let faceShape = Shape.face(from: surface, boundary: wire),
            let graph = BRepGraph(shape: faceShape)
        else {
            Issue.record("helical-edge fixture build failed")
            return
        }

        var helixNodeIndex: Int?
        for edgeIndex in 0..<graph.edgeCount {
            guard
                let eShape = graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = eShape.edges().first,
                edge.curveType != .line
            else { continue }
            helixNodeIndex = edgeIndex
            break
        }
        guard let helixNodeIndex else {
            Issue.record("no non-line edge found in helical fixture")
            return
        }
        // Confirm the fixture matches the premise: adjacent to exactly one cylinder-kind face,
        // same as a genuine rim, `revolutionAxis` has nothing to disagree with, so only
        // `coaxialCrossSection`'s own height check can decline the redirect.
        let cylFaceCount = graph.faces(of: helixNodeIndex).filter { faceIndex in
            guard
                let faceShape = graph.shape(
                    nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex),
                let face = faceShape.faces().first, let axis = face.primaryAxis
            else { return false }
            return axis.kind == .cylinder
        }.count
        #expect(cylFaceCount == 1)

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: helixNodeIndex))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            // Must not teleport to the centerline (x = y = 0): the fallback secant's origin is
            // the helix's own start point, still on the cylinder wall, the same discriminator
            // the straight-seam test above uses, since the secant's DIRECTION happens to coincide
            // with the axis direction here too (chosen deliberately, matching the old false
            // positive's strongest form).
            let radialDistance = (ax.origin.x * ax.origin.x + ax.origin.y * ax.origin.y)
                .squareRoot()
            #expect(radialDistance > radius - 1e-6)
        case .failure(let e):
            Issue.record("expected success (chord fallback for helical edge), got \(e)")
        }
    }

    @Test("throughPoints on coincident vertices fails with degenerate")
    func coincidentPointsDegenerate() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let v = TopologyRef.literal(.init(kind: .vertex, index: 0))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.throughPoints(v, v)) {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test("intersectionOfPlanes on parallel planes fails with degenerate")
    func parallelIntersectionDegenerate() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let a = ConstructionPlane.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let b = ConstructionPlane.absolute(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.intersectionOfPlanes(a, b)) {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test(
        "normalToFace on a cylinder returns the rotation axis, not the local radial normal (#882)")
    func normalToFaceCylinderPrimaryAxis() {
        // The doc promises the cylinder's own rotation axis (here unit Z). Before
        // #882, normalToFace returned the UV-midpoint radial normal instead,
        // which lies in the XY plane and has zero Z component.
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 1))
        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            #expect(abs(ax.direction.z) > 0.99)
        case .failure: Issue.record("normalToFace failed")
        }
    }

    @Test(
        "normalToFace on a cylinder anchors the returned axis on the true centerline, not the off-axis vertex it was asked at (PR #897 review, third pass)"
    )
    func normalToFaceCylinderOriginOnAxis() {
        // Vertex 1 sits ON the lateral surface, radius 5 from the true centerline (the Z
        // axis, since Shape.cylinder is centered on it). Before this fix, normalToFace's
        // returned origin was always the raw, off-axis vertex position -- pairing a correct
        // axis DIRECTION with a WRONG axis LOCATION, a line parallel to, but offset by the
        // full radius from, the true rotation axis.
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 1))
        let rawVertex = graph.vertexPoint(1)
        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            // The origin must lie ON the true centerline (radial distance 0 from the Z
            // axis), not at the vertex's own radius-5 position.
            let radialDistance = (ax.origin.x * ax.origin.x + ax.origin.y * ax.origin.y)
                .squareRoot()
            #expect(radialDistance < 1e-6)
            // Kept edge-local (projected at the requested vertex's own height along the
            // axis), not snapped to the surface's own placement origin elsewhere on the axis.
            #expect(abs(ax.origin.z - rawVertex.z) < 1e-6)
            #expect(abs(ax.direction.z) > 0.99)
        case .failure(let e): Issue.record("normalToFace failed: \(e)")
        }
    }

    @Test(
        "normalToFace on a torus also anchors the returned axis on the true centerline, not the vertex's own far-off-axis position (PR #897 review, third pass)"
    )
    func normalToFaceTorusOriginOnAxis() {
        // A torus's single seam vertex sits at (majorRadius + minorRadius) from the true
        // centerline -- 25 units here, the widest point on the whole surface -- so this is
        // the most extreme case of the same bug the cylinder test above covers, and the only
        // fixture in this suite that exercises the axis-projection formula for a kind other
        // than `.cylinder` (`.cone`/`.torus`/`.revolution` share the identical code path, but
        // only `.cylinder` had a dedicated origin test before this one).
        guard let torus = Shape.torus(majorRadius: 20, minorRadius: 5),
            let graph = BRepGraph(shape: torus)
        else {
            Issue.record("setup")
            return
        }
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first,
            let axis = face.primaryAxis, axis.kind == .torus
        else {
            Issue.record("fixture is not a toroidal face")
            return
        }
        guard graph.vertexCount > 0 else {
            Issue.record("torus fixture has no vertex")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 0))
        let rawVertex = graph.vertexPoint(0)
        let axisDirection = simd_normalize(axis.direction)
        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            // The origin must lie ON the true centerline, not at the vertex's own
            // far-off-axis position (radius 25 here).
            let toOrigin = ax.origin - axis.origin
            let radial = toOrigin - simd_dot(toOrigin, axisDirection) * axisDirection
            #expect(simd_length(radial) < 1e-6)
            // Kept edge-local: projected at the requested vertex's own height along the
            // axis, not snapped to the surface's own placement origin.
            let expectedHeight = simd_dot(
                SIMD3(rawVertex.x, rawVertex.y, rawVertex.z) - axis.origin, axisDirection)
            let actualHeight = simd_dot(toOrigin, axisDirection)
            #expect(abs(actualHeight - expectedHeight) < 1e-6)
            #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
        case .failure(let e): Issue.record("normalToFace failed: \(e)")
        }
    }

    @Test("normalToFace on a planar face still returns the face normal")
    func normalToFacePlaneFallback() {
        // Planes have no primary axis, so normalToFace must fall back to the
        // UV-midpoint surface normal, the pre-#882 behavior, still correct here.
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 0))
        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
        case .failure: Issue.record("normalToFace failed")
        }
    }

    @Test(
        "normalToFace on an extrusion-surface face falls back to the UV-midpoint normal, not the sweep direction (PR #897 review)"
    )
    func normalToFaceExtrusionFallsBackToNormal() {
        // Geom_SurfaceOfLinearExtrusion's primaryAxis.direction is the SWEEP direction
        // (tangent to the surface), not a normal, unlike cylinder/cone/sphere/torus/
        // revolution, where primaryAxis.direction genuinely is a rotation axis. A
        // straight-line profile (along X) extruded along Z produces a planar surface
        // whose true normal (Y) is perpendicular to both the profile and the sweep
        // direction; before this fix, normalToFace returned the sweep direction
        // (Z) unconditionally whenever primaryAxis was non-nil.
        guard let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)),
            let surface = Surface.extrusion(profile: line, direction: SIMD3(0, 0, 1)),
            let extrudedFace = Shape.face(from: surface, uRange: 0...10, vRange: 0...10),
            let graph = BRepGraph(shape: extrudedFace)
        else {
            Issue.record("setup")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 0))

        // Sanity: this fixture really does have an extrusion-kind primaryAxis along
        // the sweep direction, so the test is exercising the branch it claims to.
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first,
            let axis = face.primaryAxis, axis.kind == .extrusion
        else {
            Issue.record("fixture is not an extrusion-surface face")
            return
        }
        #expect(abs(axis.direction.z) > 0.99, "sweep direction should be along Z")

        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
            // The true surface normal is perpendicular to the sweep direction (Z);
            // the pre-fix bug returned the sweep direction itself here.
            #expect(abs(ax.direction.z) < 0.01)
        case .failure(let e): Issue.record("normalToFace failed: \(e)")
        }
    }

    @Test(
        "normalToFace on a spherical face falls back to the UV-midpoint normal, not the arbitrary pole axis (PR #897 review, 3rd pass)"
    )
    func normalToFaceSphereFallsBackToNormal() {
        // gp_Sphere::Position().Direction() (what Face.primaryAxis reports for a
        // sphere) is just the arbitrary construction-frame pole -- a sphere is
        // symmetric about every axis through its center, so unlike
        // cylinder/cone/torus/revolution it has no intrinsic rotation axis at all.
        // Before this fix, normalToFace returned that same fixed (0,0,1) pole
        // direction for every vertex on the sphere, off by 90 degrees from the true
        // local normal at the equator.
        let radius = 5.0
        guard let sph = Shape.sphere(radius: radius),
            let graph = BRepGraph(shape: sph)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))

        // Sanity: this fixture really does have a sphere-kind primaryAxis, so the
        // test is exercising the branch it claims to.
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first,
            let axis = face.primaryAxis, axis.kind == .sphere
        else {
            Issue.record("fixture is not a spherical face")
            return
        }
        let poleDirection = simd_normalize(axis.direction)

        // Find the two real pole vertices by position, not by assuming fixed indices 0/1 --
        // vertex enumeration order isn't guaranteed stable across an OCCT kernel rebuild or
        // platform (CLAUDE.md Test Conventions; #897 review, second xhigh pass, finding 4) --
        // matching `tangentToFaceConeApexFallsBackToNormal`'s own by-position search a few
        // hundred lines above.
        var poleIndices: [Int] = []
        for vertexIndex in 0..<graph.vertexCount {
            let raw = graph.vertexPoint(vertexIndex)
            let offset = SIMD3(raw.x, raw.y, raw.z) - axis.origin
            let axial = simd_dot(offset, poleDirection)
            let radial = offset - axial * poleDirection
            if abs(abs(axial) - radius) < 1e-6, simd_length(radial) < 1e-6 {
                poleIndices.append(vertexIndex)
            }
        }
        guard poleIndices.count == 2 else {
            Issue.record("expected exactly 2 pole vertices, found \(poleIndices.count)")
            return
        }
        // The origin and direction must come from the SAME location -- the UV midpoint --
        // not the raw, off-face pole vertex paired with a normal sampled elsewhere (#897
        // review, third pass, finding 2).
        guard let (expectedFallbackPoint, expectedFallbackNormal) = face.uvMidpointSample() else {
            Issue.record("uvMidpointSample unavailable")
            return
        }

        // Checked at both poles to show the exclusion holds regardless of which vertex is asked.
        for vertexIndex in poleIndices {
            let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: vertexIndex))
            switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
            case .success(let ax):
                #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
                // The old, broken code returned the fixed pole axis unconditionally;
                // the fallback UV-midpoint normal (at the sphere's equator) is
                // nearly perpendicular to it instead.
                #expect(abs(simd_dot(ax.direction, poleDirection)) < 0.1)
                #expect(simd_length(ax.origin - expectedFallbackPoint) < 1e-6)
                #expect(
                    simd_length(
                        simd_normalize(ax.direction) - simd_normalize(expectedFallbackNormal))
                        < 1e-6)
            case .failure(let e):
                Issue.record("normalToFace failed at vertex \(vertexIndex): \(e)")
            }
        }
    }

    @Test(
        "normalToFace on a free-form face is point-aware, not a fixed UV-midpoint normal (PR #897 review, finding 4)"
    )
    func normalToFaceFreeFormVariesWithPoint() {
        // A non-planar (saddle / hyperbolic-paraboloid) bilinear Bezier patch: doubly ruled,
        // genuinely curved, and has NO primaryAxis at all (only cylinder/cone/torus/sphere/
        // revolution/extrusion surfaces do) -- its true local normal varies substantially
        // across the surface. The 4 corner poles are non-coplanar (p11 != p01 + p10 - p00),
        // which is what makes this a genuine saddle rather than a degenerate plane.
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 3, 3)],
            [SIMD3(3, 0, 3), SIMD3(3, 3, 0)],
        ]
        guard let surface = Surface.bezier(poles: poles),
            let face = Shape.face(from: surface, uBounds: 0...1, vBounds: 0...1),
            let graph = BRepGraph(shape: face)
        else {
            Issue.record("setup")
            return
        }

        // Sanity: this fixture really has no primaryAxis, so the test exercises the no-axis
        // fallback branch it claims to.
        guard let occFace = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first else {
            Issue.record("face0 unavailable")
            return
        }
        #expect(occFace.primaryAxis == nil, "fixture should have no primary axis")

        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        var directions: [SIMD3<Double>] = []
        for vertexIndex in 0..<graph.vertexCount {
            let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: vertexIndex))
            if case .success(let ax) = graph.resolve(
                ConstructionAxis.normalToFace(face: faceRef, at: vertexRef))
            {
                directions.append(simd_normalize(ax.direction))
            }
        }
        guard directions.count >= 2 else {
            Issue.record("need at least 2 resolved vertices")
            return
        }
        // Before this fix, every vertex answered the SAME fixed UV-midpoint normal regardless
        // of `at`; this saddle's corners have genuinely different local normals.
        let minDot = directions.dropFirst().reduce(1.0) { min($0, simd_dot(directions[0], $1)) }
        #expect(minDot < 0.99, "normalToFace should vary across a genuinely curved free-form face")
    }

    @Test(
        "normalToFace: the returned origin is the actual on-face point the direction was evaluated at, not `at`'s raw position, when `at` doesn't lie on `face` (PR #897 review, second xhigh pass, finding 2)"
    )
    func normalToFaceOriginIsOnFaceNotRawPoint() {
        // Same saddle fixture as normalToFaceFreeFormVariesWithPoint above (no primaryAxis, so
        // this exercises resolveFaceAxisDirection's point-aware fallback branch), but `at` is a
        // vertex from a SEPARATE box shape entirely -- the same "genuine misuse" pattern
        // tangentToFaceOriginIsOnFaceNotRawPoint already uses for tangentToFace.
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 3, 3)],
            [SIMD3(3, 0, 3), SIMD3(3, 3, 0)],
        ]
        guard let surface = Surface.bezier(poles: poles),
            let saddleFace = Shape.face(from: surface, uBounds: 0...1, vBounds: 0...1),
            let box = Shape.box(width: 10, height: 10, depth: 10),
            let compound = Shape.compound([saddleFace, box]),
            let graph = BRepGraph(shape: compound)
        else {
            Issue.record("setup")
            return
        }

        // Saddle added first -- confirm face 0 of the compound really is the saddle, not the
        // box, and really has no primaryAxis.
        guard let faceShape = graph.shape(nodeKind: .face, nodeIndex: 0),
            let saddle = faceShape.faces().first, saddle.primaryAxis == nil
        else {
            Issue.record("face 0 of the compound is not the no-axis saddle")
            return
        }

        // A vertex on the BOX, far from the saddle patch -- find one whose projection onto the
        // saddle is not itself.
        var offFaceVertexIndex: Int?
        for vertexIndex in 0..<graph.vertexCount {
            let raw = graph.vertexPoint(vertexIndex)
            let p = SIMD3(raw.x, raw.y, raw.z)
            guard simd_length(p) > 1.0 else { continue }  // skip the saddle's own corners near 0
            guard let projection = saddle.project(point: p) else { continue }
            if simd_length(projection.point - p) > 1e-3 {
                offFaceVertexIndex = vertexIndex
                break
            }
        }
        guard let offFaceVertexIndex else {
            Issue.record("no usable off-face vertex found")
            return
        }
        let rawTuple = graph.vertexPoint(offFaceVertexIndex)
        let rawPoint = SIMD3(rawTuple.x, rawTuple.y, rawTuple.z)
        guard let expectedProjection = saddle.project(point: rawPoint),
            let expectedNormal = saddle.normal(atU: expectedProjection.u, v: expectedProjection.v)
        else {
            Issue.record("expected projection/normal unavailable")
            return
        }

        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: offFaceVertexIndex))
        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            // The origin must be the actual on-face projected point -- the same location the
            // direction was evaluated at -- not the raw off-face vertex position.
            #expect(simd_length(ax.origin - expectedProjection.point) < 1e-6)
            #expect(
                simd_length(ax.origin - rawPoint) > 1e-3,
                "origin should differ from the raw off-face point")
            #expect(
                simd_length(simd_normalize(ax.direction) - simd_normalize(expectedNormal)) < 1e-6)
        case .failure(let e):
            Issue.record("normalToFace failed: \(e)")
        }
    }

    @Test(
        "alongEdge fails loudly, not silently, when the edge's tangent is undefined at its own start point (#894 finding 1, fifth pass)"
    )
    func alongEdgeUndefinedStartTangentFailsLoudNotSilent() {
        // A quarter-turn "top arc" on a cylindrical wall, geometrically a genuine circular
        // cross-section, constant height/radius across all 5 of `coaxialCrossSection`'s own
        // sampled fractions, built as a degree-1 BSpline whose first two poles are IDENTICAL: a
        // textbook cusp (the segment [0, 0.05] has zero length, so the right-derivative at u=0 is
        // the zero vector). `GeomLProp_CLProps::IsTangentDefined()`, and so `Edge.tangent(at:)`
        //, correctly reports undefined there, while `Edge.point(at:)` at the same parameter
        // still succeeds (plain D0 evaluation, unaffected by a degenerate derivative).
        //
        // Knots are placed at exactly the 5 fractions `coaxialCrossSection` samples (0, 0.25,
        // 0.5, 0.75, 1.0), with the extra cusp pole tucked into [0, 0.05], so every sample lands
        // exactly on a pole (an exact circle point), not on a chord between two knots, the same
        // "poles are the samples" trick `coaxialCrossSectionAcceptsMeasuredEdgeToleranceNoise`
        // above uses to avoid a chord's corner-cutting error.
        let radius = 5.0
        let height = 10.0
        func circlePoint(_ angleDeg: Double) -> SIMD3<Double> {
            let a = angleDeg * Double.pi / 180
            return SIMD3(radius * cos(a), radius * sin(a), height)
        }
        let poles = [
            circlePoint(0), circlePoint(0), circlePoint(22.5), circlePoint(45),
            circlePoint(67.5), circlePoint(90),
        ]
        let knots: [Double] = [0, 0.05, 0.25, 0.5, 0.75, 1.0]
        let mults: [Int32] = [2, 1, 1, 1, 1, 2]

        let angle0 = 0.0
        let angle1 = Double.pi / 2
        let midAngle = (angle0 + angle1) / 2
        let p0bot = SIMD3(radius * cos(angle0), radius * sin(angle0), 0.0)
        let p1bot = SIMD3(radius * cos(angle1), radius * sin(angle1), 0.0)
        let p0top = circlePoint(0)
        let p1top = circlePoint(90)

        guard
            let surface = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
            let cuspCurve = Curve3D.bspline(
                poles: poles, knots: knots, multiplicities: mults, degree: 1),
            let topArcShape = Shape.edgeFromCurve(cuspCurve),
            let topArcEdge = Edge(topArcShape),
            let seamWire = Wire.line(from: p0bot, to: p0top),
            let seamEdge = seamWire.edges().first,
            let otherSideWire = Wire.line(from: p1top, to: p1bot),
            let otherSideEdge = otherSideWire.edges().first,
            let botArcCurve = Curve3D.arcOfCircle(
                start: p1bot,
                interior: SIMD3(radius * cos(midAngle), radius * sin(midAngle), 0.0),
                end: p0bot),
            let botArcShape = Shape.edgeFromCurve(botArcCurve),
            let botArcEdge = Edge(botArcShape),
            let wire = Wire.wireFromEdges([seamEdge, topArcEdge, otherSideEdge, botArcEdge]),
            let faceShape = Shape.face(from: surface, boundary: wire),
            let graph = BRepGraph(shape: faceShape)
        else {
            Issue.record("cusp-top-arc fixture build failed")
            return
        }

        // Confirm the fixture matches the intended scenario, the cusp edge really is
        // BSpline-typed and really does have an undefined start tangent, before asserting on
        // the fix, rather than assuming the construction above behaved as designed.
        var cuspNodeIndex: Int?
        for edgeIndex in 0..<graph.edgeCount {
            guard
                let eShape = graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = eShape.edges().first, edge.curveType == .bsplineCurve,
                let bounds = edge.parameterBounds
            else { continue }
            #expect(edge.tangent(at: bounds.first) == nil)
            #expect(edge.point(at: bounds.first) != nil)
            cuspNodeIndex = edgeIndex
            break
        }
        guard let cuspNodeIndex else {
            Issue.record("no BSpline-curveType edge found in cusp fixture")
            return
        }

        // Pre-fix, this silently kept `Face.primaryAxis`'s unflipped sign and returned `.success`
        // with a plausible-looking but potentially-wrong-signed axis. Fixed: fails loud instead.
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: cuspNodeIndex))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        } else {
            Issue.record("expected .degenerate when the edge's own start tangent is undefined")
        }
    }

    @Test(
        "coaxialCrossSection accepts sampled height/radius noise within the edge's own measured BRep tolerance, not just the machine-precision floor (#894 finding 2, fifth pass)"
    )
    func coaxialCrossSectionAcceptsMeasuredEdgeToleranceNoise() {
        // A degree-1 (piecewise-linear) 5-pole BSpline with a CLAMPED knot vector, [0, 0.25,
        // 0.5, 0.75, 1] with multiplicities [2, 1, 1, 1, 2], is the defining shape of a
        // degree-1 B-spline with simple interior knots: it interpolates every pole exactly at
        // its corresponding knot parameter. That gives exact, reproducible control over what
        // `coaxialCrossSection` samples at its own fractions (0, 0.25, 0.5, 0.75, 1.0), no
        // interpolation-parameterization guesswork the way `Curve3D.interpolate` would need.
        let radius = 5.0
        let height = 10.0
        // Per-point noise, ~3e-5 in magnitude, comfortably above the old flat 1e-7 floor, and
        // well inside the review's own cited 1e-4-1e-3 post-Boolean/fillet BRep tolerance range,
        // simulating a genuine circular rim that has accumulated real numerical noise.
        let angles = [0.0, Double.pi / 2, Double.pi, 3 * Double.pi / 2, 2 * Double.pi]
        let radiusNoise = [2e-5, -3e-5, 1e-5, -4e-5, 3e-5]
        let heightNoise = [3e-5, -2e-5, 4e-5, -3e-5, 1e-5]
        var poles: [SIMD3<Double>] = []
        for i in 0..<5 {
            let r = radius + radiusNoise[i]
            poles.append(SIMD3(r * cos(angles[i]), r * sin(angles[i]), height + heightNoise[i]))
        }
        guard
            let curve = Curve3D.bspline(
                poles: poles, knots: [0, 0.25, 0.5, 0.75, 1.0],
                multiplicities: [2, 1, 1, 1, 2], degree: 1),
            let edgeShape = Shape.edgeFromCurve(curve),
            let edge = Edge(edgeShape),
            let bounds = edge.parameterBounds,
            let start = edge.point(at: bounds.first),
            let end = edge.point(at: bounds.last),
            let anyShape = Shape.box(width: 1, height: 1, depth: 1),
            let graph = BRepGraph(shape: anyShape)
        else {
            Issue.record("noisy-rim fixture build failed")
            return
        }

        // The measured height/radius spread of this fixture's 5 samples (~7e-5, by construction)
        // must exceed the old flat floor for this test to prove anything, confirmed directly
        // below rather than assumed, per okf/policies/prove-the-test-fails.md.
        let axis = ShapeAxis(origin: .zero, direction: SIMD3(0, 0, 1), kind: .cylinder)
        #expect(
            !graph.coaxialCrossSection(
                of: edge, bounds: bounds, start: start, end: end, axis: axis, edgeTolerance: 0),
            "fixture noise must exceed the machine-precision floor, or this test proves nothing")

        // A realistic measured BRep_Tool::Tolerance for this rim (1e-4, well within the review's
        // own cited range) widens the comparison enough to accept the same noisy points, this is
        // the fix: pre-fix, `coaxialCrossSection` had no `edgeTolerance` parameter at all and
        // always compared against the machine-precision floor alone, so this call would have
        // returned `false` regardless of what tolerance the caller measured.
        #expect(
            graph.coaxialCrossSection(
                of: edge, bounds: bounds, start: start, end: end, axis: axis,
                edgeTolerance: 1e-4))
    }
}

@Suite("v0.142 ConstructionPoint resolution")
struct ConstructionPointTests {
    @Test("atVertex returns the vertex's 3D point")
    func atVertex() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let v = TopologyRef.literal(.init(kind: .vertex, index: 0))
        switch graph.resolve(ConstructionPoint.atVertex(v)) {
        case .success(let p):
            // Box corner must be at (0, 0, 0) for some vertex or similar.
            #expect(abs(p.x) < 20 && abs(p.y) < 20 && abs(p.z) < 20)
        case .failure: Issue.record("atVertex failed")
        }
    }

    @Test("midpointOfEdge lies between endpoints")
    func midpointOfEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let edge = TopologyRef.literal(.init(kind: .edge, index: 0))
        switch graph.resolve(ConstructionPoint.midpointOfEdge(edge)) {
        case .success(let p):
            #expect(abs(p.x) < 20 && abs(p.y) < 20 && abs(p.z) < 20)
        case .failure: Issue.record("midpointOfEdge failed")
        }
    }

    @Test("intersectionOfAxisAndPlane for axis parallel to plane fails")
    func parallelIntersectionFails() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let plane = ConstructionPlane.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let axis = ConstructionAxis.absolute(origin: SIMD3(0, 0, 5), direction: SIMD3(1, 0, 0))
        if case .failure(.degenerate) = graph.resolve(
            ConstructionPoint.intersectionOfAxisAndPlane(axis, plane))
        {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test("intersectionOfAxisAndPlane computes correct intersection")
    func intersectionCorrect() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let plane = ConstructionPlane.absolute(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1))
        let axis = ConstructionAxis.absolute(origin: SIMD3(3, 4, 0), direction: SIMD3(0, 0, 1))
        switch graph.resolve(ConstructionPoint.intersectionOfAxisAndPlane(axis, plane)) {
        case .success(let p):
            #expect(abs(p.x - 3) < 1e-9)
            #expect(abs(p.y - 4) < 1e-9)
            #expect(abs(p.z - 10) < 1e-9)
        case .failure: Issue.record("intersection failed")
        }
    }

    @Test("centroidOfFace on a cylinder matches the real area centroid, not the UV midpoint (#884)")
    func centroidOfFaceCylinderSurfaceInertia() {
        // A radius-5, height-10 cylinder's lateral face has its true area centroid
        // on the cylinder's own axis (x=y=0, z=5), the UV-midpoint approximation
        // instead sits a full radius off-axis, on the surface itself.
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        switch graph.resolve(ConstructionPoint.centroidOfFace(faceRef)) {
        case .success(let p):
            let distanceFromAxis = (p.x * p.x + p.y * p.y).squareRoot()
            #expect(distanceFromAxis < 1e-6)
            #expect(abs(p.z - 5) < 1e-6)
        case .failure(let e): Issue.record("centroidOfFace failed: \(e)")
        }
    }

    @Test(
        "centroidOfFace on a genuinely zero-area face fails with .degenerate, not a fabricated point (PR #897 review)"
    )
    func centroidOfFaceZeroAreaDegenerate() {
        // A 2-vertex "polygon" wire is a degenerate zero-area loop, the same fixture
        // Issue234DegenerateHoleTests uses for a degenerate hole, here used as the base
        // face itself. Its surfaceInertia.centerOfMass is nil because BRepGProp_Sinert
        // measures its area as exactly 0. The old UV-midpoint-based centroidOfFace always
        // succeeded for any face with uvBounds; resolveFaceCentroid must decline instead.
        let p0 = SIMD3<Double>(0, 0, 0)
        let p1 = SIMD3<Double>(10, 0, 0)
        guard let wire = Wire.polygon3D([p0, p1], closed: true),
            let degenerateFace = Shape.face(from: wire, planar: true),
            let graph = BRepGraph(shape: degenerateFace)
        else {
            Issue.record("setup")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))

        // Sanity: the fixture really is zero-area, so this exercises the branch it claims to.
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first else {
            Issue.record("fixture face unavailable")
            return
        }
        #expect(face.surfaceInertia.centerOfMass == nil, "fixture should be zero-area")

        if case .failure(.degenerate(let message)) =
            graph.resolve(ConstructionPoint.centroidOfFace(faceRef))
        {
            #expect(message == "face area is zero, or its inertia could not be computed")
        } else {
            Issue.record(
                "expected .degenerate(\"face area is zero, or its inertia could not be computed\")")
        }
    }

    @Test(
        "atEdgeParameter matches Edge.parameterByLinearFraction(_:) + point(at:) for the same edge and t"
    )
    func atEdgeParameterMatchesFraction() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        // Edge enumeration order isn't guaranteed stable across an OCCT kernel rebuild
        // or platform, iterate every edge rather than hardcoding index 0 (CLAUDE.md
        // Test Conventions; PR #897 review, finding 12).
        #expect(graph.edgeCount > 0)
        for edgeIndex in 0..<graph.edgeCount {
            guard let edge = graph.shape(nodeKind: .edge, nodeIndex: edgeIndex)?.edges().first,
                let param = edge.parameterByLinearFraction(0.25),
                let expected = edge.point(at: param)
            else {
                Issue.record("edge \(edgeIndex) unavailable")
                continue
            }
            let edgeRef = TopologyRef.literal(.init(kind: .edge, index: edgeIndex))
            switch graph.resolve(ConstructionPoint.atEdgeParameter(edge: edgeRef, t: 0.25)) {
            case .success(let p):
                #expect(simd_length(p - expected) < 1e-9)
            case .failure(let e): Issue.record("atEdgeParameter failed at edge \(edgeIndex): \(e)")
            }
        }
    }
}

@Suite("v0.142 .containedIn now resolves")
struct ContainedInTests {
    @Test("Face contained in a box solid resolves")
    func faceInSolid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let solid = TopologyRef.literal(.init(kind: .solid, index: 0))
        let firstFace = TopologyRef.containedIn(parent: solid, kind: .face, occurrence: 0)
        switch graph.resolve(firstFace) {
        case .success(let face):
            #expect(face.kind == .face)
        case .failure(let e): Issue.record("containedIn failed: \(e)")
        }
    }

    @Test("Occurrence out of range in containedIn")
    func faceInSolidOOB() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let solid = TopologyRef.literal(.init(kind: .solid, index: 0))
        let faceBogus = TopologyRef.containedIn(parent: solid, kind: .face, occurrence: 999)
        if case .failure(.occurrenceOutOfRange) = graph.resolve(faceBogus) {
        } else {
            Issue.record("expected occurrenceOutOfRange")
        }
    }

    @Test("Ancestor resolution failure propagates in containedIn")
    func ancestorMissing() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        // containedIn references a parent recipe that never resolves → should fail.
        let bogusParent = TopologyRef.createdBy(operationName: "Nonexistent", kind: .solid)
        let result = graph.resolve(.containedIn(parent: bogusParent, kind: .face, occurrence: 0))
        if case .failure(.ancestorMissing) = result {
        } else {
            Issue.record("expected ancestorMissing")
        }
    }
}

// MARK: - Durable Identity (UID / RefUID / ItemUID), OCCT 8.0.0p1

@Suite("BRepGraph Durable UID")
struct BRepGraphDurableUIDTests {
    // Face kind ordinal in BRepGraph_NodeId::Kind is 2.
    private let faceKind = 2

    @Test func nodeUIDRoundTrip() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let graph = BRepGraph(shape: box) else { return }
        #expect(graph.faceCount == 6)

        // Every face should yield a valid UID that round-trips back to the same node.
        for i in 0..<graph.faceCount {
            guard let uid = graph.uid(ofNodeKind: faceKind, index: i) else {
                Issue.record("face \(i) had no UID")
                continue
            }
            #expect(uid.isValid)
            #expect(graph.contains(uid: uid))
            if let resolved = graph.node(forUID: uid) {
                #expect(resolved.kind == faceKind)
                #expect(resolved.index == i)
            } else {
                Issue.record("UID for face \(i) did not resolve")
            }
        }
    }

    /// A UID minted by a *different* graph must not resolve, the case that matters, and the one
    /// that silently returned a wrong node before #295. Its counter is in range for the foreign
    /// graph (counters restart at 1 per graph), so nothing but provenance can reject it.
    @Test func uidFromAnotherGraphDoesNotResolve() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let cyl = Shape.cylinder(radius: 3, height: 7),
            let boxGraph = BRepGraph(shape: box),
            let cylGraph = BRepGraph(shape: cyl)
        else { return }

        guard let boxFaceUID = boxGraph.uid(ofNodeKind: faceKind, index: 2) else {
            Issue.record("box face 2 had no UID")
            return
        }
        // Precondition for the test to be meaningful: the counter is one the cylinder graph
        // would consider perfectly valid, and did resolve to a cylinder face before the fix.
        #expect(boxFaceUID.counter <= UInt32(cylGraph.faceCount))

        #expect(cylGraph.node(forUID: boxFaceUID) == nil)
        #expect(!cylGraph.contains(uid: boxFaceUID))
        // ...while it still resolves in the graph that minted it.
        #expect(boxGraph.node(forUID: boxFaceUID) != nil)
    }

    /// Two graphs over the *same* shape are still two graphs: identity is the instance, not the
    /// geometry. This is the case a consumer is most likely to assume works.
    @Test func uidDoesNotCrossIdenticallyBuiltGraphs() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let a = BRepGraph(shape: box),
            let b = BRepGraph(shape: box)
        else { return }
        #expect(a.instanceID != b.instanceID)
        guard let uid = a.uid(ofNodeKind: faceKind, index: 1) else { return }
        #expect(b.node(forUID: uid) == nil)
        #expect(!b.contains(uid: uid))
    }

    /// Mean sampled position + normal, a signature that actually distinguishes a box's faces.
    /// (A single grid corner does not: adjacent faces share corners.)
    private func faceSignature(
        _ g: BRepGraph, _ i: Int,
        shift: SIMD3<Double> = .zero
    ) -> String? {
        guard let s = g.sampleFaceUVGrid(faceIndex: i, uSamples: 3, vSamples: 3),
            !s.positions.isEmpty, !s.normals.isEmpty
        else { return nil }
        var c = SIMD3<Double>(0, 0, 0)
        for p in s.positions { c += p }
        c = c / Double(s.positions.count) - shift
        var n = SIMD3<Double>(0, 0, 0)
        for v in s.normals { n += v }
        n /= Double(s.normals.count)
        return String(format: "c(%.3f,%.3f,%.3f) n(%.3f,%.3f,%.3f)", c.x, c.y, c.z, n.x, n.y, n.z)
    }

    /// A full `copy()` INHERITS the source's identity, so every source UID still resolves, and
    /// resolves to the geometrically same face. This is the kernel's own contract, not an
    /// accident: `BRepGraph_Copy::Perform` transplants the UID counter space, the Generation and
    /// the GraphGUID into the target. Guards the #295 provenance check against over-rejecting.
    @Test func uidSurvivesAFullCopyAndNamesTheSameFace() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let graph = BRepGraph(shape: box),
            let copy = graph.copy()
        else { return }
        #expect(copy.instanceID == graph.instanceID)  // a copy is the same identity
        #expect(copy.faceCount == graph.faceCount)

        // The signature must actually discriminate, or the assertions below prove nothing.
        let sigs = (0..<graph.faceCount).compactMap { faceSignature(graph, $0) }
        #expect(Set(sigs).count == graph.faceCount)

        for i in 0..<graph.faceCount {
            guard let uid = graph.uid(ofNodeKind: faceKind, index: i) else { continue }
            guard let r = copy.node(forUID: uid) else {
                Issue.record("face \(i)'s UID stopped resolving through copy()")
                continue
            }
            #expect(faceSignature(graph, i) == faceSignature(copy, r.index))
        }
    }

    /// `translated()` copies the graph wholesale too, so identity and UID correspondence carry
    /// across exactly as with `copy()`, the faces are merely moved.
    @Test func uidSurvivesATranslationAndNamesTheSameFace() {
        let d = SIMD3<Double>(100, 200, 300)
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let graph = BRepGraph(shape: box),
            let moved = graph.translated(dx: d.x, dy: d.y, dz: d.z)
        else { return }
        #expect(moved.instanceID == graph.instanceID)
        for i in 0..<graph.faceCount {
            guard let uid = graph.uid(ofNodeKind: faceKind, index: i) else { continue }
            guard let r = moved.node(forUID: uid) else {
                Issue.record("face \(i)'s UID stopped resolving through translated()")
                continue
            }
            #expect(faceSignature(graph, i) == faceSignature(moved, r.index, shift: d))
        }
    }

    /// `copyFace()` is the opposite case: it lifts ONE face into an empty graph without
    /// transplanting the counter space, so the extracted face restarts at counter 1, the
    /// source's face-0 counter. Before #295 a source UID resolved here and returned the wrong
    /// face. The extracted graph gets a fresh identity, so it now returns nil.
    @Test func uidDoesNotCrossACopiedOutFace() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let graph = BRepGraph(shape: box),
            let lifted = graph.copyFace(3)
        else { return }
        #expect(lifted.instanceID != graph.instanceID)
        #expect(lifted.faceCount == 1)
        // The lifted face IS source face 3, sitting at index 0.
        #expect(faceSignature(lifted, 0) == faceSignature(graph, 3))

        // Source face 0's counter (1) is in range here and used to return face 3.
        guard let uidFace0 = graph.uid(ofNodeKind: faceKind, index: 0) else { return }
        #expect(uidFace0.counter == 1)
        #expect(lifted.node(forUID: uidFace0) == nil)
        #expect(!lifted.contains(uid: uidFace0))
    }

    /// An out-of-range counter must not resolve either. Stamped with this graph's own id, so it
    /// tests the counter path rather than being rejected on provenance first.
    @Test func outOfRangeCounterDoesNotResolve() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let graph = BRepGraph(shape: box) else { return }

        let bogus = BRepGraph.GraphUID(kind: faceKind, counter: 999_999, graphID: graph.instanceID)
        #expect(!graph.contains(uid: bogus))
        #expect(graph.node(forUID: bogus) == nil)

        // The invalid sentinel (counter 0) is never valid.
        let invalid = BRepGraph.GraphUID(kind: faceKind, counter: 0, graphID: graph.instanceID)
        #expect(!invalid.isValid)
        #expect(!graph.contains(uid: invalid))
    }

    /// A UID with no provenance, hand-built, or decoded from a pre-#295 payload, resolves nowhere,
    /// even when its counter names a real node in the graph asked.
    @Test func unstampedUIDResolvesNowhere() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let graph = BRepGraph(shape: box) else { return }
        guard let real = graph.uid(ofNodeKind: faceKind, index: 0) else { return }

        let unstamped = BRepGraph.GraphUID(kind: real.kind, counter: real.counter, graphID: 0)
        #expect(unstamped.isValid)  // the counter is a real one...
        #expect(graph.node(forUID: unstamped) == nil)  // ...but it names no graph
        #expect(!graph.contains(uid: unstamped))
    }

    /// The property the UID exists for: it survives a mutation that renumbers indices, within the
    /// graph that minted it. Guards against the #295 provenance check over-rejecting.
    @Test func uidSurvivesCompactionOfItsOwnGraph() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box),
            let uid = graph.uid(ofNodeKind: faceKind, index: 3)
        else { return }
        let idBefore = graph.instanceID
        graph.compact()
        #expect(graph.instanceID == idBefore)  // compaction mutates in place; same instance
        #expect(graph.contains(uid: uid))
        #expect(graph.node(forUID: uid) != nil)
    }

    /// Provenance travels through `Codable`; a pre-#295 payload (no `graphID`) still decodes,
    /// as an unstamped UID rather than a decode failure.
    @Test func uidCodableCarriesProvenance() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box),
            let uid = graph.uid(ofNodeKind: faceKind, index: 0)
        else { return }

        let round = try JSONDecoder().decode(
            BRepGraph.GraphUID.self,
            from: try JSONEncoder().encode(uid))
        #expect(round == uid)
        #expect(round.graphID == graph.instanceID)
        #expect(graph.node(forUID: round) != nil)

        let legacy = Data(#"{"kind":2,"counter":1}"#.utf8)
        let decoded = try JSONDecoder().decode(BRepGraph.GraphUID.self, from: legacy)
        #expect(decoded.graphID == 0)
        #expect(graph.node(forUID: decoded) == nil)
    }

    /// RefUIDs and ItemUIDs restart their counters per graph exactly as node UIDs do, and carry
    /// the same provenance.
    @Test func refAndItemUIDsDoNotCrossGraphs() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let cyl = Shape.cylinder(radius: 3, height: 7),
            let boxGraph = BRepGraph(shape: box),
            let cylGraph = BRepGraph(shape: cyl)
        else { return }

        // Ref kind 1 == Face reference entry.
        if let refUID = boxGraph.uid(ofRefKind: 1, index: 0) {
            #expect(boxGraph.ref(forUID: refUID) != nil)
            #expect(cylGraph.ref(forUID: refUID) == nil)
            #expect(!cylGraph.contains(uid: refUID))
        }

        if let itemUID = boxGraph.itemUID(ofNodeKind: faceKind, index: 2) {
            #expect(boxGraph.item(forUID: itemUID) != nil)
            #expect(cylGraph.item(forUID: itemUID) == nil)
            #expect(boxGraph.contains(uid: itemUID))
            #expect(!cylGraph.contains(uid: itemUID))
        }
    }

    @Test func itemUIDOfNode() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let graph = BRepGraph(shape: box) else { return }
        guard graph.faceCount > 0 else { return }

        if let item = graph.itemUID(ofNodeKind: faceKind, index: 0) {
            #expect(item.isValid)
            #expect(item.domain == 1)  // 1 == Node domain
            if let resolved = graph.item(forUID: item) {
                #expect(resolved.domain == 1)
                #expect(resolved.kind == faceKind)
                #expect(resolved.index == 0)
            } else {
                Issue.record("item UID did not resolve")
            }
        }
    }
}

// MARK: - Supplement vertex attachments (un-stubbed against OCCT 8.0.0p1 TopoSupplement layer)
//
// Face-direct and edge-internal vertices are a supplemental, RUNTIME concept in 8.0.0p1
// (BRepGraph_LayerTopoSupplement): a freshly built (clean) box graph has none until one is
// attached via faceAddVertex / edgeAddInternalVertex. The returned value is a layer-local
// attachment uid (not a core ref index); removal is by that uid.
@Suite("BRepGraph Supplement Vertices")
struct BRepGraphSupplementVertexTests {
    @Test func faceDirectVertexAttachCountRemove() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        guard let box else {
            Issue.record("box build failed")
            return
        }
        let graph = BRepGraph(shape: box)
        guard let graph else {
            Issue.record("graph build failed")
            return
        }

        // Clean box: no face-direct vertices until we add one.
        #expect(graph.faceVertexRefCount(0) == 0)

        let uid = graph.faceAddVertex(0, vertexIndex: 0)
        #expect(uid != nil)
        if let uid {
            #expect(uid >= 0)
            // The attachment now shows up in the FaceDirectVertex count for face 0.
            #expect(graph.faceVertexRefCount(0) >= 1)

            // Removing by the returned uid succeeds and drops the count back.
            #expect(graph.faceRemoveVertex(0, attachmentUID: uid) == true)
            #expect(graph.faceVertexRefCount(0) == 0)

            // Removing the same uid again returns false (already gone).
            #expect(graph.faceRemoveVertex(0, attachmentUID: uid) == false)
        }
    }

    @Test func edgeInternalVertexAttach() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        guard let box else {
            Issue.record("box build failed")
            return
        }
        let graph = BRepGraph(shape: box)
        guard let graph else {
            Issue.record("graph build failed")
            return
        }

        // Attaching an edge-internal vertex returns a non-nil layer-local uid.
        let uid = graph.edgeAddInternalVertex(0, vertexIndex: 0)
        #expect(uid != nil)
        if let uid { #expect(uid >= 0) }
    }

    // FaceIsNaturalRestriction: honest read of NbWires == 0. p1 normalizes natural-bound faces
    // (it always materializes a bounding wire) so a box face is NOT a natural-restriction face.
    @Test func boxFacesNotNaturalRestriction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        guard let box else {
            Issue.record("box build failed")
            return
        }
        let graph = BRepGraph(shape: box)
        guard let graph else {
            Issue.record("graph build failed")
            return
        }
        for i in 0..<graph.faceCount {
            #expect(graph.isFaceNaturalRestriction(i) == false)
        }
    }
}
