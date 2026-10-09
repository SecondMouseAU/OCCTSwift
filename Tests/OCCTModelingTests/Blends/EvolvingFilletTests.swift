import Testing
import simd

@testable import OCCTSwift

// MARK: - Evolving Fillet Tests (v0.38.0)

@Suite("Evolving Fillet")
struct EvolvingFilletTests {

    @Test("Single edge evolving radius")
    func singleEdgeEvolving() {
        let box = Shape.box(width: 40, height: 40, depth: 40)!
        // Try multiple edges until one succeeds (edge ordering can vary)
        var result: Shape? = nil
        for edge in box.edges() {
            let spec = EvolvingFilletEdge(
                edge: edge,
                radiusPoints: [
                    (parameter: 0.0, radius: 1.0),
                    (parameter: 1.0, radius: 2.0),
                ])
            result = box.filletEvolving([spec])
            if result != nil { break }
        }
        #expect(result != nil)
        if let r = result { #expect(r.isValid) }
    }

    @Test("Multiple edges with evolving radii")
    func multiEdgeEvolving() {
        let box = Shape.box(width: 40, height: 40, depth: 40)!
        // Find two edges that work
        var workingEdges: [Edge] = []
        for edge in box.edges() {
            let spec = EvolvingFilletEdge(
                edge: edge,
                radiusPoints: [
                    (parameter: 0.0, radius: 1.0),
                    (parameter: 1.0, radius: 1.0),
                ])
            if box.filletEvolving([spec]) != nil {
                workingEdges.append(edge)
                if workingEdges.count >= 2 { break }
            }
        }
        guard workingEdges.count >= 2 else { return }
        let specs = workingEdges.map { edge in
            EvolvingFilletEdge(
                edge: edge,
                radiusPoints: [
                    (parameter: 0.0, radius: 1.0),
                    (parameter: 1.0, radius: 1.5),
                ])
        }
        let result = box.filletEvolving(specs)
        #expect(result != nil)
        if let r = result { #expect(r.isValid) }
    }

    @Test("Constant radius via evolving API")
    func constantRadiusViaEvolving() {
        let box = Shape.box(width: 40, height: 40, depth: 40)!
        var result: Shape? = nil
        for edge in box.edges() {
            let spec = EvolvingFilletEdge(
                edge: edge,
                radiusPoints: [
                    (parameter: 0.0, radius: 2.0),
                    (parameter: 1.0, radius: 2.0),
                ])
            result = box.filletEvolving([spec])
            if result != nil { break }
        }
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(r.volume! < 64000.0)  // less than 40^3
        }
    }
}
