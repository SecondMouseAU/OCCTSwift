import Testing

@testable import OCCTSwift

/// Regression for #3518: `FilletBuilder` read a contour index, or an edge index inside a contour,
/// straight into `BRepFilletAPI_MakeFillet`, which range-checks neither end reliably.
///
/// `Scripts/repro/3518/occt_3518_contour_index_matrix.mm` measured every accessor against the
/// pinned kernel, one forked process per (builder state, accessor, index):
///
/// - `NbEdges(i)`, `Edge(i, j)` and `StripeStatus(i)` check nothing. `ChFi3d_Builder::Value(i)`
///   walks the stripe list `i - 1` times, so `i > NbContours()` steps off the end and a builder
///   with no contour is dereferenced at once: SIGSEGV. `StripeStatus` dereferences the stripe it
///   failed to find.
/// - `Length`, `Radius`, `IsConstant`, `Closed`, `ClosedAndTangent`, `FirstVertex`, `LastVertex`,
///   `Abscissa`, `RelativeAbscissa`, the `SetRadius` family and `ResetContour` test only
///   `i <= NbContours()`. The upper bound is refused; `0` and every negative index pass, reach
///   `Value(i)`, and read or WRITE contour 1 (`ResetContour(0)` resets it, `SetRadius(r, 0, e)`
///   re-radiuses it), or SIGSEGV when the builder holds no contour.
/// - `Edge(1, j)` and `SetRadius(r1, r2, 1, j)` index the spine's edge sequence with `j`
///   unchecked: `0` faults, and `j` past the end reads garbage (a bus error for the extremes).
///
/// Each test below is one accessor, run over every builder state the matrix measured, so an
/// accessor that regressed in one state fails here and not only in the state somebody thought of.
@Suite("FilletBuilder contour and edge indices outside their range")
struct FilletBuilderContourIndexTests {

    // MARK: - States

    /// A 10 mm box and the first two edges `Add()` puts in contours of their own.
    private func boxAndEdges() throws -> (box: Shape, first: Edge, second: Edge) {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        let probe = try #require(FilletBuilder(shape: box))
        let first = try #require(edges.first)
        try #require(probe.addEdge(first, radius: 1))
        let second = try #require(
            edges.dropFirst().first {
                probe.addEdge($0, radius: 1) && probe.contourCount == 2
            }, "no second edge opened a second contour")
        return (box, first, second)
    }

    /// The builder states the matrix measured.
    ///
    /// Each fixture asserts it is the state it names, so a fixture that drifted (a declined build
    /// that started completing, say) cannot read a state the guard is not meant to cover and pass.
    private func states() throws -> [(name: String, builder: FilletBuilder)] {
        let (box, first, second) = try boxAndEdges()
        func fresh() throws -> FilletBuilder { try #require(FilletBuilder(shape: box)) }

        let empty = try fresh()
        #expect(empty.contourCount == 0)

        let noContour = try fresh()
        #expect(noContour.build() == nil, "a build with nothing added must be refused")
        #expect(noContour.contourCount == 0)

        let neverBuilt = try fresh()
        #expect(neverBuilt.addEdge(first, radius: 1))
        #expect(neverBuilt.contourCount == 1)

        let twoContours = try fresh()
        #expect(twoContours.addEdge(first, radius: 1))
        #expect(twoContours.addEdge(second, radius: 1))
        #expect(twoContours.contourCount == 2)

        let declined = try fresh()
        #expect(declined.addEdge(first, radius: 20))
        #expect(declined.build() == nil)
        #expect(declined.faultyContourCount == 1, "the builder itself must have declined it")
        #expect(!declined.hasResult)
        #expect(declined.contourCount == 1)

        let built = try fresh()
        #expect(built.addEdge(first, radius: 1))
        #expect(built.build() != nil)
        #expect(built.contourCount == 1)

        let builtTwo = try fresh()
        #expect(builtTwo.addEdge(first, radius: 1))
        #expect(builtTwo.addEdge(second, radius: 1))
        #expect(builtTwo.build() != nil)
        #expect(builtTwo.contourCount == 2)

        let reset = try fresh()
        #expect(reset.addEdge(first, radius: 1))
        #expect(reset.build() != nil)
        reset.reset()

        return [
            ("fresh", empty),
            ("build with no contour", noContour),
            ("added, never built", neverBuilt),
            ("two contours, never built", twoContours),
            ("declined", declined),
            ("built", built),
            ("two contours, built", builtTwo),
            ("built, then reset", reset),
        ]
    }

    /// Indices that are not in `1...fb.contourCount`, each one a different way to miss: the
    /// 1-based off-by-one, a negative, past the end by one and by a lot. `Int.max` and `Int.min`
    /// are not here: they test the Swift-to-C conversion and have their own test.
    private func badContours(_ fb: FilletBuilder) -> [Int] {
        [0, -1, fb.contourCount + 1, fb.contourCount + 2, 100_000]
    }

    // MARK: - Reads that used to fault

    @Test("edgeCount answers 0 for a contour that does not exist")
    func edgeCount() throws {
        for (name, fb) in try states() {
            for i in badContours(fb) {
                #expect(fb.edgeCount(contour: i) == 0, "\(name), contour \(i)")
            }
        }
    }

    @Test("stripeStatus answers -1 for a contour that does not exist")
    func stripeStatus() throws {
        for (name, fb) in try states() {
            for i in badContours(fb) {
                #expect(fb.stripeStatus(contour: i) == -1, "\(name), contour \(i)")
            }
        }
    }

    @Test("edge answers nil for a contour or an index inside it that does not exist")
    func edge() throws {
        for (name, fb) in try states() {
            for i in badContours(fb) {
                #expect(fb.edge(contour: i, index: 1) == nil, "\(name), contour \(i)")
            }
            // The index inside the contour, for the contours that do exist.
            for c in 1...max(1, fb.contourCount) where c <= fb.contourCount {
                let n = fb.edgeCount(contour: c)
                #expect(n == 1, "\(name), contour \(c) holds one box edge")
                for j in [0, -1, n + 1, n + 2, 100_000] {
                    #expect(
                        fb.edge(contour: c, index: j) == nil, "\(name), contour \(c), edge \(j)")
                }
            }
        }
    }

    // MARK: - Reads that answered contour 1 for 0 and every negative index

    @Test("radius answers -1 for a contour that does not exist, not contour 1's radius")
    func radius() throws {
        for (name, fb) in try states() {
            for i in badContours(fb) {
                #expect(fb.radius(contour: i) == -1, "\(name), contour \(i)")
            }
        }
    }

    @Test("length answers -1 for a contour that does not exist, not contour 1's length")
    func length() throws {
        for (name, fb) in try states() {
            for i in badContours(fb) {
                #expect(fb.length(contour: i) == -1, "\(name), contour \(i)")
            }
        }
    }

    @Test(
        "isConstant, isClosed and isClosedAndTangent answer false for a contour that does not exist"
    )
    func flags() throws {
        for (name, fb) in try states() {
            for i in badContours(fb) {
                #expect(!fb.isConstant(contour: i), "\(name), contour \(i)")
                #expect(!fb.isClosed(contour: i), "\(name), contour \(i)")
                #expect(!fb.isClosedAndTangent(contour: i), "\(name), contour \(i)")
            }
        }
    }

    @Test("firstVertex and lastVertex answer nil for a contour that does not exist")
    func endVertices() throws {
        for (name, fb) in try states() {
            for i in badContours(fb) {
                #expect(fb.firstVertex(contour: i) == nil, "\(name), contour \(i)")
                #expect(fb.lastVertex(contour: i) == nil, "\(name), contour \(i)")
            }
        }
    }

    @Test("abscissa and relativeAbscissa answer -1 for a contour that does not exist")
    func abscissa() throws {
        // A real vertex of a contour, from a builder of its own, so every state below is asked
        // about a vertex that exists and the contour index is the only thing wrong.
        let (box, first, _) = try boxAndEdges()
        let source = try #require(FilletBuilder(shape: box))
        try #require(source.addEdge(first, radius: 1))
        let vertex = try #require(source.firstVertex(contour: 1))

        for (name, fb) in try states() {
            for i in badContours(fb) {
                #expect(fb.abscissa(contour: i, vertex: vertex) == -1, "\(name), contour \(i)")
                #expect(
                    fb.relativeAbscissa(contour: i, vertex: vertex) == -1, "\(name), contour \(i)")
            }
        }
    }

    // MARK: - Writes that landed on contour 1 for 0 and every negative index

    @Test("setRadius on an edge refuses a contour that does not exist and leaves contour 1 alone")
    func setRadiusOnEdge() throws {
        let (_, first, _) = try boxAndEdges()
        for (name, fb) in try states() {
            let before = fb.radius(contour: 1)
            for i in badContours(fb) {
                #expect(!fb.setRadius(7, contour: i, edge: first), "\(name), contour \(i)")
            }
            #expect(
                fb.radius(contour: 1) == before,
                "\(name): contour 1 was written through a bad index")
        }
    }

    @Test("setRadius at a vertex refuses a contour that does not exist and leaves contour 1 alone")
    func setRadiusAtVertex() throws {
        let (box, first, _) = try boxAndEdges()
        let source = try #require(FilletBuilder(shape: box))
        try #require(source.addEdge(first, radius: 1))
        let vertex = try #require(source.firstVertex(contour: 1))

        for (name, fb) in try states() {
            let before = fb.radius(contour: 1)
            for i in badContours(fb) {
                #expect(!fb.setRadius(7, contour: i, vertex: vertex), "\(name), contour \(i)")
            }
            #expect(
                fb.radius(contour: 1) == before,
                "\(name): contour 1 was written through a bad index")
        }
    }

    @Test("setTwoRadii refuses a contour or an edge index that does not exist")
    func setTwoRadii() throws {
        for (name, fb) in try states() {
            let before = fb.radius(contour: 1)
            for i in badContours(fb) {
                #expect(
                    !fb.setTwoRadii(7, 9, contour: i, edgeInContour: 1), "\(name), contour \(i)")
            }
            // The edge index inside a contour that does exist. 0 is OCCT's "absolute abscissa"
            // spelling, not an edge, and the others read past the spine's edge table.
            for c in 1...max(1, fb.contourCount) where c <= fb.contourCount {
                let n = fb.edgeCount(contour: c)
                for j in [0, -1, n + 1, n + 2, 100_000] {
                    #expect(
                        !fb.setTwoRadii(7, 9, contour: c, edgeInContour: j),
                        "\(name), contour \(c), edge \(j)")
                }
            }
            #expect(
                fb.radius(contour: 1) == before,
                "\(name): contour 1 was written through a bad index")
        }
    }

    @Test("resetContour ignores a contour that does not exist and leaves contour 1 alone")
    func resetContour() throws {
        for (name, fb) in try states() {
            let before = fb.radius(contour: 1)
            for i in badContours(fb) {
                fb.resetContour(i)
            }
            #expect(
                fb.radius(contour: 1) == before, "\(name): contour 1 was reset through a bad index")
        }
    }

    // MARK: - Indices that do not fit in the C `int`

    /// An `Int` past `Int32` is converted by clamping and never reaches the bridge as a trap.
    ///
    /// `Int32(contour)` traps for such a value, which is a crash of its own and not the kernel's.
    /// Every method that takes a contour or a fault index goes through `Int32(clamping:)`, so these
    /// are ordinary out-of-range indices by the time they arrive.
    @Test("an index past Int32 is refused like any other, not trapped on")
    func indexBeyondInt32() throws {
        let (box, first, _) = try boxAndEdges()
        let source = try #require(FilletBuilder(shape: box))
        try #require(source.addEdge(first, radius: 1))
        let vertex = try #require(source.firstVertex(contour: 1))
        let law = try #require(
            LawFunction.linear(from: 1, to: 1, parameterRange: 0...1))

        for (name, fb) in try states() {
            for i in [Int.max, Int.min, Int(Int32.max) + 1, Int(Int32.min) - 1] {
                #expect(fb.edgeCount(contour: i) == 0, "\(name), contour \(i)")
                #expect(fb.radius(contour: i) == -1)
                #expect(fb.length(contour: i) == -1)
                #expect(!fb.isConstant(contour: i))
                #expect(!fb.isClosed(contour: i))
                #expect(!fb.isClosedAndTangent(contour: i))
                #expect(fb.firstVertex(contour: i) == nil)
                #expect(fb.lastVertex(contour: i) == nil)
                #expect(fb.abscissa(contour: i, vertex: vertex) == -1)
                #expect(fb.relativeAbscissa(contour: i, vertex: vertex) == -1)
                #expect(fb.edge(contour: i, index: 1) == nil)
                #expect(fb.edge(contour: 1, index: i) == nil)
                #expect(fb.stripeStatus(contour: i) == -1)
                #expect(fb.computedSurfaceCount(contour: i) == 0)
                #expect(!fb.setRadius(7, contour: i, edge: first))
                #expect(!fb.setRadius(7, contour: i, vertex: vertex))
                #expect(!fb.setTwoRadii(7, 9, contour: i, edgeInContour: 1))
                #expect(!fb.setTwoRadii(7, 9, contour: 1, edgeInContour: i))
                #expect(fb.getBounds(contour: i, edge: first) == nil)
                #expect(fb.getLaw(contour: i, edge: first) == nil)
                #expect(!fb.setLaw(contour: i, edge: first, law: law))
                #expect(fb.faultyContour(index: i) == 0)
                #expect(fb.faultyVertex(index: i) == nil)
                fb.resetContour(i)
                fb.simulate(contour: i)
            }
        }
    }

    // MARK: - Controls: a contour that exists still answers what it did

    /// Stops a guard wired to refuse everything.
    ///
    /// Two contours, never built, so the reads that answered before the fix are all there to be
    /// compared against, and contour 2 is the upper edge of the range that `contourCount` names.
    @Test("a contour that exists answers what it did")
    func validContourStillAnswers() throws {
        let (box, first, second) = try boxAndEdges()
        let fb = try #require(FilletBuilder(shape: box))
        try #require(fb.addEdge(first, radius: 1))
        try #require(fb.addEdge(second, radius: 2))
        try #require(fb.contourCount == 2)

        for c in 1...2 {
            #expect(fb.edgeCount(contour: c) == 1)
            #expect(fb.length(contour: c) == 10)
            #expect(fb.isConstant(contour: c))
            #expect(!fb.isClosed(contour: c))
            #expect(!fb.isClosedAndTangent(contour: c))
            #expect(fb.edge(contour: c, index: 1) != nil)
            #expect(fb.stripeStatus(contour: c) == 0)

            let start = try #require(fb.firstVertex(contour: c))
            let end = try #require(fb.lastVertex(contour: c))
            #expect(abs(fb.abscissa(contour: c, vertex: start)) < 1e-9)
            #expect(abs(fb.relativeAbscissa(contour: c, vertex: start)) < 1e-9)
            #expect(abs(fb.abscissa(contour: c, vertex: end) - 10) < 1e-9)
            #expect(abs(fb.relativeAbscissa(contour: c, vertex: end) - 1) < 1e-9)
        }
        #expect(fb.radius(contour: 1) == 1)
        #expect(fb.radius(contour: 2) == 2)

        // The writes reach the contour they name, and only that one.
        #expect(fb.setRadius(5, contour: 2, edge: second))
        #expect(fb.radius(contour: 2) == 5)
        #expect(fb.radius(contour: 1) == 1)

        #expect(fb.setTwoRadii(1, 3, contour: 1, edgeInContour: 1))
        #expect(!fb.isConstant(contour: 1))
        #expect(fb.isConstant(contour: 2))

        // Contour 1 now holds an evolving law and contour 2 a constant 5. Resetting contour 1 takes
        // away its radii and nothing else.
        fb.resetContour(1)
        #expect(!fb.isConstant(contour: 1))
        #expect(fb.isConstant(contour: 2))
        #expect(fb.radius(contour: 2) == 5)
    }

    @Test("a built contour keeps its status and its computed surface")
    func builtContourStillAnswers() throws {
        let (box, first, _) = try boxAndEdges()
        let fb = try #require(FilletBuilder(shape: box))
        try #require(fb.addEdge(first, radius: 1))
        try #require(fb.build() != nil)
        #expect(fb.stripeStatus(contour: 1) == 0)
        #expect(fb.computedSurfaceCount(contour: 1) == 1)
        #expect(fb.edgeCount(contour: 1) == 1)
        #expect(fb.radius(contour: 1) == 1)
    }
}
