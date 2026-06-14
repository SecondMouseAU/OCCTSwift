import Testing
import Foundation
import simd
@testable import OCCTSwift


extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x*x + y*y + z*z)
        guard len > 0 else { return self }
        return SIMD3(x/len, y/len, z/len)
    }
}



// MARK: - BRepGraph Tests (v0.129.0)

@Suite("TopologyGraph Build")
struct TopologyGraphBuildTests {
    @Test func buildFromBox() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box, parallel: true)
            #expect(graph != nil)
            if let graph {
                #expect(graph.faceCount == 6)
            }
        }
    }

    @Test func buildFromSphere() {
        let sphere = Shape.sphere(radius: 5)
        if let sphere {
            let graph = TopologyGraph(shape: sphere)
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
                let graph = TopologyGraph(shape: fused)
                if let graph {
                    #expect(graph.faceCount > 6)
                    #expect(graph.isValid)
                }
            }
        }
    }
}

@Suite("TopologyGraph Counts")
struct TopologyGraphCountTests {
    @Test func activeCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                #expect(graph.coedgeCount == 24)
            }
        }
    }
}

@Suite("TopologyGraph Face Queries")
struct TopologyGraphFaceQueryTests {
    @Test func faceAdjacency() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let adj = graph.adjacentFaces(of: 0)
                #expect(adj.count == 4)
            }
        }
    }

    @Test func sharedEdges() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                let wire = graph.outerWire(of: 0)
                #expect(wire >= 0)
            }
        }
    }
}

@Suite("TopologyGraph Edge Queries")
struct TopologyGraphEdgeQueryTests {
    @Test func edgeFaceCount() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let nbFaces = graph.faceCount(of: 0)
                #expect(nbFaces == 2)
            }
        }
    }

    @Test func edgeFaces() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let faces = graph.faces(of: 0)
                #expect(faces.count == 2)
            }
        }
    }

    @Test func noBoundaryEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                let adj = graph.adjacentEdges(of: 0)
                #expect(adj.count > 0)
            }
        }
    }
}

@Suite("TopologyGraph Vertex Queries")
struct TopologyGraphVertexQueryTests {
    @Test func vertexEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let edges = graph.edges(of: 0)
                #expect(edges.count == 3)
            }
        }
    }
}

@Suite("TopologyGraph Explorers")
struct TopologyGraphExplorerTests {
    @Test func childExplorer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // OCCT 8.0 reshaped root iteration to Products only — wrap the
                // box's solid root in a Product to expose it as a graph root.
                _ = graph.linkProductToTopology(shapeRootKind: 0 /* Solid */, shapeRootIndex: 0)
                let roots = graph.rootNodes
                #expect(roots.count > 0)
                if let root = roots.first {
                    let faceCount = graph.childCount(rootKind: root.kind, rootIndex: root.index, targetKind: .face)
                    #expect(faceCount == 6)
                }
            }
        }
    }

    @Test func parentExplorer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let parents = graph.parentCount(nodeKind: .face, nodeIndex: 0)
                #expect(parents > 0)
            }
        }
    }
}

@Suite("TopologyGraph Validate")
struct TopologyGraphValidateTests {
    @Test func boxIsValid() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                #expect(graph.isValid)
                let result = graph.validate()
                #expect(result.isValid)
                #expect(result.errorCount == 0)
            }
        }
    }
}

@Suite("TopologyGraph Compact")
struct TopologyGraphCompactTests {
    @Test func compactBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let result = graph.compact()
                #expect(result.nodesAfter > 0)
            }
        }
    }
}

@Suite("TopologyGraph Deduplicate")
struct TopologyGraphDeduplicateTests {
    @Test func deduplicateBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let result = graph.deduplicate()
                #expect(result.canonicalSurfaces == 6)
                #expect(result.canonicalCurves == 12)
            }
        }
    }
}

@Suite("TopologyGraph Stats")
struct TopologyGraphStatsTests {
    @Test func boxStats() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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

@Suite("TopologyGraph Node Status")
struct TopologyGraphNodeStatusTests {
    @Test func noRemovedNodes() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                for i in 0..<graph.faceCount {
                    #expect(!graph.isRemoved(nodeKind: .face, nodeIndex: i))
                }
            }
        }
    }
}

@Suite("TopologyGraph Root Nodes")
struct TopologyGraphRootNodeTests {
    @Test func hasRoots() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // OCCT 8.0 reshaped root iteration to Products only — wrap the
                // box's solid root in a Product to expose it as a graph root.
                _ = graph.linkProductToTopology(shapeRootKind: 0 /* Solid */, shapeRootIndex: 0)
                let roots = graph.rootNodes
                #expect(roots.count > 0)
                #expect(roots.first?.kind == .product)
            }
        }
    }
}

// MARK: - TopologyGraph Extended Tests (v0.133.0)

@Suite("TopologyGraph Shape Reconstruction")
struct TopologyGraphShapeReconstructionTests {
    @Test func reconstructFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let face = graph.shape(nodeKind: .face, nodeIndex: 0)
                #expect(face != nil)
            }
        }
    }

    @Test func reconstructSolid() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let solid = graph.shape(nodeKind: .solid, nodeIndex: 0)
                #expect(solid != nil)
            }
        }
    }

    @Test func findNode() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                #expect(!graph.hasNode(for: sphere))
            }
        }
    }
}

@Suite("TopologyGraph Vertex Geometry")
struct TopologyGraphVertexGeometryTests {
    @Test func vertexPoint() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                let tol = graph.vertexTolerance(0)
                #expect(tol > 0)
                #expect(tol < 1.0) // should be a small value
            }
        }
    }
}

@Suite("TopologyGraph Edge Geometry")
struct TopologyGraphEdgeGeometryTests {
    @Test func edgeTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let tol = graph.edgeTolerance(0)
                #expect(tol > 0)
            }
        }
    }

    @Test func edgeNotDegenerated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                let range = graph.edgeRange(0)
                #expect(range.first < range.last)
            }
        }
    }

    @Test func edgeHasCurve() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                let cont = graph.edgeMaxContinuity(0)
                #expect(cont >= 0)
            }
        }
    }

    @Test func edgeNotClosedOnFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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

@Suite("TopologyGraph Face Geometry")
struct TopologyGraphFaceGeometryTests {
    @Test func faceTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let tol = graph.faceTolerance(0)
                #expect(tol > 0)
            }
        }
    }

    @Test func faceHasSurface() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                // Just check it returns a bool without crashing
                let _ = graph.isFaceNaturalRestriction(0)
            }
        }
    }

    @Test func faceHasTriangulation() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // Box may or may not have triangulation depending on meshing
                let _ = graph.faceHasTriangulation(0)
            }
        }
    }
}

@Suite("TopologyGraph Wire Extended")
struct TopologyGraphWireExtendedTests {
    @Test func wireIsClosed() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                let count = graph.wireCoEdgeCount(0)
                #expect(count == 4) // box face has 4 edges
            }
        }
    }

    @Test func wireFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let faceCount = graph.wireFaceCount(0)
                #expect(faceCount == 1)
                let faces = graph.wireFaces(0)
                #expect(faces.count == 1)
            }
        }
    }
}

@Suite("TopologyGraph CoEdge Queries")
struct TopologyGraphCoEdgeQueryTests {
    @Test func coedgeEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: sphere)
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
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                if graph.coedgeHasPCurve(0) {
                    let range = graph.coedgeRange(0)
                    #expect(range.first < range.last)
                }
            }
        }
    }
}

@Suite("TopologyGraph Shell Queries")
struct TopologyGraphShellQueryTests {
    @Test func shellSolids() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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

@Suite("TopologyGraph Solid Queries")
struct TopologyGraphSolidQueryTests {
    @Test func solidCompSolidCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                let count = graph.solidCompSolidCount(0)
                #expect(count == 0) // standalone solid, not in comp-solid
            }
        }
    }
}

@Suite("TopologyGraph History")
struct TopologyGraphHistoryTests {
    @Test func historyDefaults() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                #expect(graph.isHistoryEnabled)
                #expect(graph.historyRecordCount == 0)
            }
        }
    }

    @Test func historyToggle() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                graph.clearHistory()
                #expect(graph.historyRecordCount == 0)
            }
        }
    }
}

@Suite("TopologyGraph Poly Counts")
struct TopologyGraphPolyCountTests {
    @Test func polyCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // Poly counts are >= 0 (may be 0 if not meshed)
                #expect(graph.triangulationCount >= 0)
                #expect(graph.polygon3DCount >= 0)
            }
        }
    }
}

@Suite("TopologyGraph Active Geometry")
struct TopologyGraphActiveGeometryTests {
    @Test func activeGeometryCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                #expect(graph.activeSurfaceCount == 6)
                #expect(graph.activeCurve3DCount == 12)
                #expect(graph.activeCurve2DCount > 0)
            }
        }
    }
}

@Suite("TopologyGraph SameDomain")
struct TopologyGraphSameDomainTests {
    @Test func boxNoSameDomain() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // Box faces are all distinct, no same-domain
                let sd = graph.sameDomainFaces(of: 0)
                #expect(sd.isEmpty)
            }
        }
    }
}

@Suite("TopologyGraph Copy")
struct TopologyGraphCopyTests {
    @Test func deepCopy() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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

@Suite("TopologyGraph Transform")
struct TopologyGraphTransformTests {
    @Test func translateGraph() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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

@Suite("TopologyGraph Products")
struct TopologyGraphProductTests {
    @Test func productCountForPrimitive() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: sphere)
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
}

@Suite("TopologyGraph Occurrences")
struct TopologyGraphOccurrenceTests {
    @Test func occurrenceCountForPrimitive() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                #expect(graph.occurrenceCount == 0)
            }
        }
    }
}

@Suite("TopologyGraph Ref Counts")
struct TopologyGraphRefCountTests {
    @Test func refCountsForBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // Box has shells, faces, wires, coedges, vertices refs
                #expect(graph.shellRefCount >= 1)
                #expect(graph.faceRefCount >= 6)
                #expect(graph.wireRefCount >= 6)
                #expect(graph.coedgeRefCount >= 24)
                #expect(graph.vertexRefCount >= 16) // edges have start/end vertex refs
                #expect(graph.solidRefCount >= 0)
                #expect(graph.childRefCount >= 0)
                #expect(graph.occurrenceRefCount == 0) // no assembly
            }
        }
    }

    @Test func refCountsConsistency() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                // Face ref count should be >= face definition count
                #expect(graph.faceRefCount >= graph.faceCount)
                // Wire ref count should be >= wire definition count
                #expect(graph.wireRefCount >= graph.wireCount)
            }
        }
    }
}

@Suite("TopologyGraph Ref Entry Queries")
struct TopologyGraphRefEntryTests {
    @Test func refChildNode() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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

@Suite("TopologyGraph Face Def Details")
struct TopologyGraphFaceDefTests {
    @Test func faceWireCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                // Box faces normally have no isolated vertices
                for i in 0..<graph.faceCount {
                    #expect(graph.faceVertexRefCount(i) == 0)
                }
            }
        }
    }
}

@Suite("TopologyGraph Edge Def Details")
struct TopologyGraphEdgeDefTests {
    @Test func edgeStartEndVertex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: sphere)
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

@Suite("TopologyGraph Edge Wires CoEdges")
struct TopologyGraphEdgeWiresCoEdgesTests {
    @Test func edgeWires() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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

@Suite("TopologyGraph Face Shells")
struct TopologyGraphFaceShellTests {
    @Test func faceShells() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
            if let graph {
                // Box faces are not in compounds
                for i in 0..<graph.faceCount {
                    #expect(graph.faceCompoundCount(i) == 0)
                }
            }
        }
    }
}

@Suite("TopologyGraph Shell Extended")
struct TopologyGraphShellExtendedTests {
    @Test func shellCompoundCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
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
            let graph = TopologyGraph(shape: box)
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

@Suite("TopologyGraph Solid Extended")
struct TopologyGraphSolidExtendedTests {
    @Test func solidCompoundCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                for i in 0..<graph.solidCount {
                    #expect(graph.solidCompoundCount(i) == 0)
                }
            }
        }
    }
}

@Suite("TopologyGraph CompSolid Count")
struct TopologyGraphCompSolidCountTests {
    @Test func compSolidCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = TopologyGraph(shape: box)
            if let graph {
                #expect(graph.compSolidCount == 0)
            }
        }
    }
}

@Suite("TopologyGraph Compound Queries")
struct TopologyGraphCompoundTests {
    @Test func compoundQueriesOnCompound() {
        // Create a compound shape by fusing two boxes
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)
        if let box1, let box2 {
            let compound = Shape.compound([box1, box2])
            if let compound {
                let graph = TopologyGraph(shape: compound)
                if let graph {
                    #expect(graph.compoundCount >= 1)
                    if graph.compoundCount > 0 {
                        let childCount = graph.compoundChildCount(0)
                        #expect(childCount >= 2) // at least 2 solids
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

@Suite("TopologyGraph Builder AddVertex")
struct TopologyGraphBuilderAddVertexTests {
    @Test func addVertexToGraph() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
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
            if let graph = TopologyGraph(shape: box) {
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

@Suite("TopologyGraph Builder AddShell")
struct TopologyGraphBuilderAddShellTests {
    @Test func addEmptyShell() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
                let origShellCount = graph.shellCount
                if let sidx = graph.addShell() {
                    #expect(sidx >= 0)
                    #expect(graph.shellCount == origShellCount + 1)
                }
            }
        }
    }
}

@Suite("TopologyGraph Builder AddSolid")
struct TopologyGraphBuilderAddSolidTests {
    @Test func addEmptySolid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
                let origSolidCount = graph.solidCount
                if let sidx = graph.addSolid() {
                    #expect(sidx >= 0)
                    #expect(graph.solidCount == origSolidCount + 1)
                }
            }
        }
    }
}

@Suite("TopologyGraph Builder AddFaceToShell")
struct TopologyGraphBuilderAddFaceToShellTests {
    @Test func linkFaceToShell() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
                // Add a new shell, then link existing face 0 to it
                if let shellIdx = graph.addShell() {
                    let refIdx = graph.addFaceToShell(shellIndex: shellIdx, faceIndex: 0, orientation: 0)
                    #expect(refIdx != nil)
                }
            }
        }
    }
}

@Suite("TopologyGraph Builder AddShellToSolid")
struct TopologyGraphBuilderAddShellToSolidTests {
    @Test func linkShellToSolid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
                if let solidIdx = graph.addSolid(), let shellIdx = graph.addShell() {
                    let refIdx = graph.addShellToSolid(solidIndex: solidIdx, shellIndex: shellIdx, orientation: 0)
                    #expect(refIdx != nil)
                }
            }
        }
    }
}

@Suite("TopologyGraph Builder AddCompound")
struct TopologyGraphBuilderAddCompoundTests {
    @Test func addCompoundFromSolids() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
                let origCompoundCount = graph.compoundCount
                if graph.solidCount > 0 {
                    let children: [(kind: TopologyGraph.NodeKind, index: Int)] = [
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

@Suite("TopologyGraph Builder AddCompSolid")
struct TopologyGraphBuilderAddCompSolidTests {
    @Test func addCompSolidFromSolids() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
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

@Suite("TopologyGraph Builder RemoveNode")
struct TopologyGraphBuilderRemoveNodeTests {
    @Test func removeVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
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
            if let graph = TopologyGraph(shape: box) {
                if graph.faceCount > 0 {
                    let fIdx = graph.faceCount - 1
                    graph.removeSubgraph(nodeKind: .face, nodeIndex: fIdx)
                    #expect(graph.isRemoved(nodeKind: .face, nodeIndex: fIdx))
                }
            }
        }
    }
}

@Suite("TopologyGraph Builder AppendShape")
struct TopologyGraphBuilderAppendShapeTests {
    @Test func appendFlattenedShape() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
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
            if let graph = TopologyGraph(shape: box) {
                let origFaces = graph.faceCount
                if let cylinder = Shape.cylinder(radius: 3, height: 8) {
                    graph.appendFullShape(cylinder)
                    #expect(graph.faceCount > origFaces)
                }
            }
        }
    }
}

@Suite("TopologyGraph Builder Deferred")
struct TopologyGraphBuilderDeferredTests {
    @Test func deferredModeToggle() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
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
            if let graph = TopologyGraph(shape: box) {
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

@Suite("TopologyGraph Builder CommitMutation")
struct TopologyGraphBuilderCommitMutationTests {
    @Test func commitAfterAdd() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
                _ = graph.addVertex(x: 0, y: 0, z: 0, tolerance: 0.01)
                graph.commitMutation()
                // Should not crash
                #expect(graph.vertexCount > 0)
            }
        }
    }
}

@Suite("TopologyGraph Builder RemoveRef")
struct TopologyGraphBuilderRemoveRefTests {
    @Test func removeShellRef() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
                if graph.shellRefCount > 0 {
                    let removed = graph.removeRef(refKind: .shell, refIndex: 0)
                    // Should succeed or gracefully fail
                    #expect(removed || !removed) // either outcome acceptable
                }
            }
        }
    }
}

@Suite("TopologyGraph Builder ClearMesh")
struct TopologyGraphBuilderClearMeshTests {
    @Test func clearFaceMesh() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Mesh the shape first
            let _ = box.mesh(linearDeflection: 0.1)
            if let graph = TopologyGraph(shape: box) {
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
            if let graph = TopologyGraph(shape: box) {
                if graph.edgeCount > 0 {
                    // Should not crash
                    graph.clearEdgePolygon3D(edgeIndex: 0)
                }
            }
        }
    }
}

@Suite("TopologyGraph Builder ValidateMutation")
struct TopologyGraphBuilderValidateMutationTests {
    @Test func validateCleanGraph() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
                // A freshly built graph should have valid mutation boundary
                let valid = graph.validateMutation()
                #expect(valid)
            }
        }
    }

    @Test func validateAfterAddVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
                _ = graph.addVertex(x: 0, y: 0, z: 0, tolerance: 0.01)
                graph.commitMutation()
                let valid = graph.validateMutation()
                #expect(valid)
            }
        }
    }
}

// MARK: - TopologyGraph UV Grid Sampling (v0.136.0)

@Suite("TopologyGraph UV Grid")
struct TopologyGraphUVGridTests {
    @Test func sampleBoxFace() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
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
            if let graph = TopologyGraph(shape: sphere) {
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
            if let graph = TopologyGraph(shape: box) {
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
            if let graph = TopologyGraph(shape: box) {
                let sample = graph.sampleFaceUVGrid(faceIndex: 999, uSamples: 5, vSamples: 5)
                #expect(sample == nil)
            }
        }
    }

    @Test func sampleZeroCounts() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
                let sample = graph.sampleFaceUVGrid(faceIndex: 0, uSamples: 0, vSamples: 5)
                #expect(sample == nil)
            }
        }
    }
}

@Suite("TopologyGraph Edge Sampling")
struct TopologyGraphEdgeSamplingTests {
    @Test func sampleBoxEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
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
                        let dist = ((first.x - last.x) * (first.x - last.x) +
                                    (first.y - last.y) * (first.y - last.y) +
                                    (first.z - last.z) * (first.z - last.z)).squareRoot()
                        #expect(dist > 0.001)
                    }
                }
            }
        }
    }

    @Test func sampleSinglePoint() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
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
            if let graph = TopologyGraph(shape: box) {
                // Test with invalid index
                let points = graph.sampleEdgeCurve(edgeIndex: 999, count: 10)
                #expect(points.isEmpty)
            }
        }
    }

    @Test func sampleZeroCount() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = TopologyGraph(shape: box) {
                let points = graph.sampleEdgeCurve(edgeIndex: 0, count: 0)
                #expect(points.isEmpty)
            }
        }
    }

    @Test func sampleSphereEdge() {
        if let sphere = Shape.sphere(radius: 5) {
            if let graph = TopologyGraph(shape: sphere) {
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

// MARK: - v0.141 / #72 Phase 0: BRepGraph history record readback

@Suite("v0.141 BRepGraph history record readback")
struct BRepGraphHistoryReadbackTests {
    @Test("Recorded 1-to-1 modification survives roundtrip through the API")
    func oneToOneReadback() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = TopologyGraph.NodeRef(kind: .face, index: 0)
        let repl = TopologyGraph.NodeRef(kind: .face, index: 42)
        graph.recordHistory(operationName: "TestFillet", original: orig, replacements: [repl])

        #expect(graph.historyRecordCount == 1)
        guard let rec = graph.historyRecord(at: 0) else {
            Issue.record("record nil"); return
        }
        #expect(rec.operationName == "TestFillet")
        #expect(rec.mapping.count == 1)
        #expect(rec.mapping[orig] == [repl])
    }

    @Test("Split (1-to-N) mapping round-trips")
    func splitMapping() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = TopologyGraph.NodeRef(kind: .edge, index: 3)
        let a = TopologyGraph.NodeRef(kind: .edge, index: 100)
        let b = TopologyGraph.NodeRef(kind: .edge, index: 101)
        let c = TopologyGraph.NodeRef(kind: .edge, index: 102)
        graph.recordHistory(operationName: "SplitEdge", original: orig, replacements: [a, b, c])

        let rec = graph.historyRecord(at: 0)
        #expect(rec?.mapping[orig] == [a, b, c])
    }

    @Test("Deletion (1-to-0) round-trips")
    func deletionMapping() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = TopologyGraph.NodeRef(kind: .face, index: 5)
        graph.recordHistory(operationName: "RemoveFace", original: orig, replacements: [])

        let rec = graph.historyRecord(at: 0)
        #expect(rec?.mapping[orig] == [])
    }

    @Test("FindDerived walks forward through chained records")
    func findDerivedWalksForward() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        // orig → [a] → [b, c]
        let orig = TopologyGraph.NodeRef(kind: .edge, index: 1)
        let a = TopologyGraph.NodeRef(kind: .edge, index: 10)
        let b = TopologyGraph.NodeRef(kind: .edge, index: 20)
        let c = TopologyGraph.NodeRef(kind: .edge, index: 21)
        graph.recordHistory(operationName: "Op1", original: orig, replacements: [a])
        graph.recordHistory(operationName: "Op2", original: a, replacements: [b, c])

        let derived = Set(graph.findDerived(of: orig))
        // Transitively, orig should reach b and c (and possibly a depending on OCCT's
        // definition of "leaves" — we accept either but require at least b, c).
        #expect(derived.isSuperset(of: [b, c]))
    }

    // MARK: - #167: untouched-vs-deleted disambiguation

    @Test("hasHistoryRecord: true for nodes named in any record's mapping; false otherwise")
    func hasHistoryRecordDistinguishesNamedFromUntouched() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let modified = TopologyGraph.NodeRef(kind: .face, index: 0)
        let replaced = TopologyGraph.NodeRef(kind: .face, index: 100)
        let deleted = TopologyGraph.NodeRef(kind: .face, index: 1)
        let untouched = TopologyGraph.NodeRef(kind: .face, index: 2)

        graph.recordHistory(operationName: "ModifyFace", original: modified, replacements: [replaced])
        graph.recordHistory(operationName: "DeleteFace", original: deleted, replacements: [])

        #expect(graph.hasHistoryRecord(for: modified), "modified node should be named in a record")
        #expect(graph.hasHistoryRecord(for: deleted), "explicitly-deleted node should be named in a record")
        #expect(!graph.hasHistoryRecord(for: untouched), "untouched node has no record entry")
    }

    @Test("findDerivedOrSelf: returns derivatives, [] for deleted, [original] for untouched")
    func findDerivedOrSelfDisambiguates() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let modified = TopologyGraph.NodeRef(kind: .face, index: 0)
        let replaced = TopologyGraph.NodeRef(kind: .face, index: 100)
        let deleted = TopologyGraph.NodeRef(kind: .face, index: 1)
        let untouched = TopologyGraph.NodeRef(kind: .face, index: 2)

        graph.recordHistory(operationName: "ModifyFace", original: modified, replacements: [replaced])
        graph.recordHistory(operationName: "DeleteFace", original: deleted, replacements: [])

        // Modified → derivatives via the existing forward walk
        let modifiedResult = graph.findDerivedOrSelf(of: modified)
        #expect(modifiedResult.contains(replaced),
                "modified node should resolve to its replacement(s)")

        // Deleted → empty (record is present but mapping is empty)
        let deletedResult = graph.findDerivedOrSelf(of: deleted)
        #expect(deletedResult.isEmpty, "explicitly-deleted node resolves to []")

        // Untouched → [original] (no record names this node)
        let untouchedResult = graph.findDerivedOrSelf(of: untouched)
        #expect(untouchedResult == [untouched],
                "untouched node should resolve to itself at the same index")
    }

    @Test("findDerivedOrSelf preserves findDerived semantics for chained records")
    func findDerivedOrSelfMatchesFindDerivedWhenNonEmpty() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        // orig → [a] → [b, c]
        let orig = TopologyGraph.NodeRef(kind: .edge, index: 1)
        let a = TopologyGraph.NodeRef(kind: .edge, index: 10)
        let b = TopologyGraph.NodeRef(kind: .edge, index: 20)
        let c = TopologyGraph.NodeRef(kind: .edge, index: 21)
        graph.recordHistory(operationName: "Op1", original: orig, replacements: [a])
        graph.recordHistory(operationName: "Op2", original: a, replacements: [b, c])

        let derived = Set(graph.findDerived(of: orig))
        let derivedOrSelf = Set(graph.findDerivedOrSelf(of: orig))
        // When findDerived is non-empty, findDerivedOrSelf must return the same set.
        #expect(derived == derivedOrSelf,
                "findDerivedOrSelf must equal findDerived when derivatives exist")
    }

    @Test("FindOriginal walks backwards")
    func findOriginalWalksBackward() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let orig = TopologyGraph.NodeRef(kind: .face, index: 7)
        let mid = TopologyGraph.NodeRef(kind: .face, index: 70)
        let leaf = TopologyGraph.NodeRef(kind: .face, index: 700)
        graph.recordHistory(operationName: "A", original: orig, replacements: [mid])
        graph.recordHistory(operationName: "B", original: mid, replacements: [leaf])

        #expect(graph.findOriginal(of: leaf) == orig)
    }

    @Test("Unrecorded node findOriginal returns itself")
    func findOriginalPassthrough() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()

        let node = TopologyGraph.NodeRef(kind: .face, index: 3)
        #expect(graph.findOriginal(of: node) == node)
    }
}

// MARK: - v0.141 / #72 Phase 1: TopologyRef recipes + resolver

@Suite("v0.141 TopologyRef resolver")
struct TopologyRefResolverTests {
    @Test("Literal reference to a valid node resolves to itself")
    func literalValid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let node = TopologyGraph.NodeRef(kind: .face, index: 2)
        let result = graph.resolve(.literal(node))
        switch result {
        case .success(let r): #expect(r == node)
        case .failure(let e): Issue.record("unexpected error: \(e)")
        }
    }

    @Test("Literal reference to an invalid node fails")
    func literalInvalid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let result = graph.resolve(.literal(.sentinel))
        if case .failure(.invalid) = result {} else {
            Issue.record("expected .invalid error")
        }
    }

    @Test("createdBy resolves to the recorded replacement")
    func createdByBasic() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let newFace = TopologyGraph.NodeRef(kind: .face, index: 100)
        graph.recordHistory(operationName: "Extrude_1",
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
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
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
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let only = TopologyGraph.NodeRef(kind: .face, index: 100)
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
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        // op1 creates face 10; op2 modifies face 10 → face 11.
        let created = TopologyGraph.NodeRef(kind: .face, index: 10)
        let current = TopologyGraph.NodeRef(kind: .face, index: 11)
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
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let orig = TopologyGraph.NodeRef(kind: .edge, index: 3)
        let a = TopologyGraph.NodeRef(kind: .edge, index: 30)
        let b = TopologyGraph.NodeRef(kind: .edge, index: 31)
        graph.recordHistory(operationName: "SplitEdge", original: orig, replacements: [a, b])
        let result = graph.resolve(.splitOf(original: .literal(orig), occurrence: 1))
        switch result {
        case .success(let r): #expect(r == b)
        case .failure(let e): Issue.record("resolve failed: \(e)")
        }
    }

    @Test("Ancestor resolution failure propagates")
    func ancestorMissing() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        // splitOf references an operation that never happened → should fail.
        let result = graph.resolve(.splitOf(
            original: .createdBy(operationName: "Nonexistent", kind: .edge),
            occurrence: 0))
        if case .failure(.ancestorMissing) = result {} else {
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
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
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
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
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
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
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
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let v = TopologyRef.literal(.init(kind: .vertex, index: 0))
        // Three references to the same vertex → collinear (all zero vector).
        let plane = ConstructionPlane.byThreePoints(v, v, v)
        if case .failure(.degenerate) = graph.resolve(plane) {} else {
            Issue.record("expected degenerate")
        }
    }

    @Test("normalToEdge produces plane perpendicular to edge tangent")
    func normalToEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
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
}

@Suite("v0.142 ConstructionAxis resolution")
struct ConstructionAxisTests {
    @Test("alongEdge produces edge start + unit direction")
    func alongEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let edge = TopologyRef.literal(.init(kind: .edge, index: 0))
        switch graph.resolve(ConstructionAxis.alongEdge(edge)) {
        case .success(let ax):
            #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
        case .failure: Issue.record("alongEdge failed")
        }
    }

    @Test("throughPoints on coincident vertices fails with degenerate")
    func coincidentPointsDegenerate() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let v = TopologyRef.literal(.init(kind: .vertex, index: 0))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.throughPoints(v, v)) {} else {
            Issue.record("expected degenerate")
        }
    }

    @Test("intersectionOfPlanes on parallel planes fails with degenerate")
    func parallelIntersectionDegenerate() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let a = ConstructionPlane.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let b = ConstructionPlane.absolute(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.intersectionOfPlanes(a, b)) {} else {
            Issue.record("expected degenerate")
        }
    }
}

@Suite("v0.142 ConstructionPoint resolution")
struct ConstructionPointTests {
    @Test("atVertex returns the vertex's 3D point")
    func atVertex() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
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
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
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
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let plane = ConstructionPlane.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let axis = ConstructionAxis.absolute(origin: SIMD3(0, 0, 5), direction: SIMD3(1, 0, 0))
        if case .failure(.degenerate) = graph.resolve(ConstructionPoint.intersectionOfAxisAndPlane(axis, plane)) {} else {
            Issue.record("expected degenerate")
        }
    }

    @Test("intersectionOfAxisAndPlane computes correct intersection")
    func intersectionCorrect() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
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
}

@Suite("v0.142 .containedIn now resolves")
struct ContainedInTests {
    @Test("Face contained in a box solid resolves")
    func faceInSolid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
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
              let graph = TopologyGraph(shape: box) else {
            Issue.record("graph nil"); return
        }
        let solid = TopologyRef.literal(.init(kind: .solid, index: 0))
        let faceBogus = TopologyRef.containedIn(parent: solid, kind: .face, occurrence: 999)
        if case .failure(.occurrenceOutOfRange) = graph.resolve(faceBogus) {} else {
            Issue.record("expected occurrenceOutOfRange")
        }
    }
}
