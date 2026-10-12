import Testing

@testable import OCCTSwift

@Suite("Edge Split Tests")
struct EdgeSplitTests {
    // #3332: the old body looped to the first line edge, split it under two `if let`s and asserted
    // `e1.length > 0` and `e2.length > 0`, so a split that returned the edge twice, or a sliver
    // and the whole, passed. The 10 mm edges of the cube split into two pieces that add up to the
    // original, meet at the split point, and carry its endpoints between them: 5 + 5 at the
    // midpoint, 2.5 + 7.5 at the quarter point.
    @Test("Split edge at midpoint")
    func splitAtMidpoint() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let lines = box.edges().filter { $0.isLine }
        #expect(lines.count == 12)
        let edge = try #require(lines.first)
        let bounds = try #require(edge.parameterBounds)
        let start = try #require(edge.point(at: bounds.first))
        let end = try #require(edge.point(at: bounds.last))
        let originalLength = edge.length
        #expect(abs(originalLength - 10) < 1e-9)

        func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
            let d = a - b
            return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
        }

        for fraction in [0.5, 0.25] {
            let parameter = bounds.first + (bounds.last - bounds.first) * fraction
            let split = try #require(edge.point(at: parameter))
            let (first, second) = try #require(edge.split(at: parameter, vertex: split))
            #expect(abs(first.length - 10 * fraction) < 1e-9, "fraction \(fraction)")
            #expect(abs(second.length - 10 * (1 - fraction)) < 1e-9, "fraction \(fraction)")
            #expect(abs(first.length + second.length - originalLength) < 1e-9)

            // The first piece runs from the original start to the split point, the second from
            // the split point to the original end.
            let firstBounds = try #require(first.parameterBounds)
            let secondBounds = try #require(second.parameterBounds)
            let firstStart = try #require(first.point(at: firstBounds.first))
            let firstEnd = try #require(first.point(at: firstBounds.last))
            let secondStart = try #require(second.point(at: secondBounds.first))
            let secondEnd = try #require(second.point(at: secondBounds.last))
            #expect(distance(firstStart, start) < 1e-9)
            #expect(distance(firstEnd, split) < 1e-9)
            #expect(distance(secondStart, split) < 1e-9)
            #expect(distance(secondEnd, end) < 1e-9)
        }
    }
}
