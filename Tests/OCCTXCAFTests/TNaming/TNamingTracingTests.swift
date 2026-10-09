import Foundation
import Testing

@testable import OCCTSwift

// #766: every test here used to assert `forward.count >= 1`, which a trace returning the source
// shape, the wrong shape, or every shape in the document all satisfy. Each now pins the exact
// arity AND the identity of what came back, measured against the kernel in
// `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.

@Suite("TNaming, Forward and Backward Tracing")
struct TNamingTracingTests {

    /// Volume of `Shape.sphere(radius: 5)`, measured, not derived.
    private static let sphereR5Volume = 523.598_775_598_299
    /// Volume of `Shape.box(width: 10, height: 10, depth: 10)`, measured.
    private static let box10Volume = 999.999_999_999_999_8
    /// Volume of `Shape.cylinder(radius: 3, height: 8)`, measured.
    private static let cylR3H8Volume = 226.194_671_058_465_08

    @Test("Trace forward yields exactly the generated shape")
    func traceForward() throws {
        let doc = try #require(Document.create())
        let label1 = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label1, evolution: .primitive, newShape: box))

        let label2 = try #require(doc.createLabel())
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(
            doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere))

        let forward = doc.tracedForward(from: box, scope: label1)
        // Exactly one generation was recorded, so exactly one shape comes back, and it is the
        // sphere rather than the box the trace started from.
        #expect(forward.count == 1)
        let traced = try #require(forward.first)
        #expect(traced.isSame(as: sphere))
        #expect(!traced.isSame(as: box))
        let volume = try #require(traced.volume)
        #expect(abs(volume - Self.sphereR5Volume) < 1e-9)
    }

    @Test("Trace backward yields exactly the source shape")
    func traceBackward() throws {
        let doc = try #require(Document.create())
        let label1 = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label1, evolution: .primitive, newShape: box))

        let label2 = try #require(doc.createLabel())
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(
            doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere))

        let backward = doc.tracedBackward(from: sphere, scope: label2)
        // The backward direction is the one thing a swapped implementation gets wrong, so pin the
        // box, not just an arity a forward trace would also satisfy.
        #expect(backward.count == 1)
        let traced = try #require(backward.first)
        #expect(traced.isSame(as: box))
        #expect(!traced.isSame(as: sphere))
        let volume = try #require(traced.volume)
        #expect(abs(volume - Self.box10Volume) < 1e-9)
    }

    @Test("Both generations from the same source come back, and only those two")
    func multipleGenerations() throws {
        let doc = try #require(Document.create())
        let label1 = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label1, evolution: .primitive, newShape: box))

        let label2 = try #require(doc.createLabel())
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(
            doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere))

        let label3 = try #require(doc.createLabel())
        let cyl = try #require(Shape.cylinder(radius: 3, height: 8))
        #expect(doc.recordNaming(on: label3, evolution: .generated, oldShape: box, newShape: cyl))

        let forward = doc.tracedForward(from: box, scope: label1)
        #expect(forward.count == 2)
        // Membership, not order: assert each generation appears exactly once, so a trace that
        // returned the same shape twice fails even though its count is right.
        #expect(forward.filter { $0.isSame(as: sphere) }.count == 1)
        #expect(forward.filter { $0.isSame(as: cyl) }.count == 1)
        #expect(forward.filter { $0.isSame(as: box) }.isEmpty)
        // `#expect` does not short-circuit, so take the elements through `first`/`last`
        // rather than by index: a subscript past the end is a fatal error that takes the whole
        // test process down, which is how an injection sweep loses the tests after this one.
        let volumes = forward.compactMap(\.volume).sorted()
        #expect(volumes.count == 2)
        #expect(abs(try #require(volumes.first) - Self.cylR3H8Volume) < 1e-9)
        #expect(abs(try #require(volumes.last) - Self.sphereR5Volume) < 1e-9)
    }

    @Test("A shape the document never saw traces to nothing")
    func emptyTraceForUnrelated() throws {
        let doc = try #require(Document.create())
        let label1 = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label1, evolution: .primitive, newShape: box))

        let unrelated = try #require(Shape.sphere(radius: 7))
        #expect(doc.tracedForward(from: unrelated, scope: label1).isEmpty)
        // The control: the same scope DOES answer for a shape it knows, so an implementation that
        // returns nothing for every input cannot pass this test by being uniformly empty.
        #expect(doc.tracedForward(from: box, scope: label1).isEmpty)
        let sphere = try #require(Shape.sphere(radius: 5))
        let label2 = try #require(doc.createLabel())
        #expect(
            doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere))
        #expect(doc.tracedForward(from: box, scope: label1).count == 1)
        #expect(doc.tracedForward(from: unrelated, scope: label1).isEmpty)
    }

    @Test("A modify evolution traces forward to the modified shape")
    func traceModificationChain() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label, evolution: .primitive, newShape: box))

        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(doc.recordNaming(on: label, evolution: .modify, oldShape: box, newShape: sphere))

        let forward = doc.tracedForward(from: box, scope: label)
        #expect(forward.count == 1)
        let traced = try #require(forward.first)
        #expect(traced.isSame(as: sphere))
        let volume = try #require(traced.volume)
        #expect(abs(volume - Self.sphereR5Volume) < 1e-9)
    }

    @Test("Forward trace does not find source shape")
    func forwardTraceExcludesSource() throws {
        let doc = try #require(Document.create())
        let label1 = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label1, evolution: .primitive, newShape: box))

        let label2 = try #require(doc.createLabel())
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(
            doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere))

        let forward = doc.tracedForward(from: box, scope: label1)
        #expect(forward.count == 1)
        for shape in forward {
            #expect(!shape.isSame(as: box), "Forward trace should not include the source shape")
        }
    }

    @Test("Backward trace does not find generated shape")
    func backwardTraceExcludesGenerated() throws {
        let doc = try #require(Document.create())
        let label1 = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: label1, evolution: .primitive, newShape: box))

        let label2 = try #require(doc.createLabel())
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(
            doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere))

        let backward = doc.tracedBackward(from: sphere, scope: label2)
        #expect(backward.count == 1)
        for shape in backward {
            #expect(
                !shape.isSame(as: sphere), "Backward trace should not include the generated shape")
        }
    }
}
