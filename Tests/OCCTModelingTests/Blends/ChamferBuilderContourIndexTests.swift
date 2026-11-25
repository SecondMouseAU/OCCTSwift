import Testing

@testable import OCCTSwift

/// Regression for #3523: `ChamferBuilder` read a contour index, and an edge index inside a contour,
/// straight into `BRepFilletAPI_MakeChamfer`, which range-checks neither end reliably.
///
/// It is the defect #3518 fixed for `FilletBuilder`, over a larger surface.
///
/// `Scripts/repro/3523/occt_3523_chamfer_index_matrix.mm` measured every contour-indexed function
/// the wrapper exposes against the pinned kernel, one forked process per (builder state, accessor,
/// index):
///
/// - `NbEdges(i)`, `Edge(i, j)`, `GetDist`, `Dists`, `GetDistAngle`, `IsSymetric`, `IsTwoDistances`
///   and `IsDistanceAngle` check nothing. `ChFi3d_Builder::Value(i)` walks the stripe list `i - 1`
///   times, so `i > NbContours()` steps off the end and a builder with no contour is dereferenced
///   at once: SIGSEGV. `0` and the negatives run no steps and answer contour 1.
/// - `Length`, `Closed`, `ClosedAndTangent`, `FirstVertex`, `LastVertex`, `Abscissa`,
///   `RelativeAbscissa`, `SetDist`, `SetDists` and `SetDistAngle` test only `i <= NbContours()`.
///   The upper bound is refused; `0` and every negative index pass, reach `Value(i)`, and read or
///   WRITE contour 1, or SIGSEGV when the builder holds no contour.
/// - `Edge(1, j)` indexes the spine's edge sequence with `j` unchecked: `0` faults.
///
/// Each test below is one group of accessors, run over every builder state the matrix measured, so
/// an accessor that regressed in one state fails here and not only in the state somebody thought of.
/// Without the guards the first bad index ends the test process, which is why this is a suite of
/// its own: `swift test --filter ChamferBuilderContourIndexTests` runs it alone.
@Suite("ChamferBuilder contour and edge indices outside their range")
struct ChamferBuilderContourIndexTests {

    // MARK: - States

    /// A 10 mm box, the first two edges `addEdge` puts in contours of their own, a face the first
    /// edge lies on, and a vertex of the first edge.
    ///
    /// Every state below is built on this one box, and the face and the vertex come from it. They
    /// have to: the face-taking setters answer `false` for a face that is not common to the
    /// contour, and `abscissa` answers `-1` for a vertex that is not on it, which are the refusals
    /// a contour index that leaked through would also have produced, so a face or a vertex from
    /// another box leaves those tests unable to tell the guard from its absence.
    private struct Fixture {
        let box: Shape
        let first: Edge
        let second: Edge
        let face: Face
        let vertex: Shape
    }

    private func fixture() throws -> Fixture {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        let probe = try #require(ChamferBuilder(shape: box))
        let first = try #require(edges.first)
        try #require(probe.addEdge(first, distance: 1))
        let second = try #require(
            edges.dropFirst().first {
                probe.addEdge($0, distance: 1) && probe.contourCount == 2
            }, "no second edge opened a second contour")
        let face = try #require(first.adjacentFaces(in: box)?.first)
        let vertex = try #require(probe.firstVertex(contour: 1))
        return Fixture(box: box, first: first, second: second, face: face, vertex: vertex)
    }

    /// The builder states the matrix measured.
    ///
    /// Each fixture asserts it is the state it names, so a fixture that drifted (a declined build
    /// that started completing, say) cannot read a state the guard is not meant to cover and pass.
    private func states(_ fx: Fixture) throws -> [(name: String, builder: ChamferBuilder)] {
        let (box, first, second, face) = (fx.box, fx.first, fx.second, fx.face)
        func fresh() throws -> ChamferBuilder { try #require(ChamferBuilder(shape: box)) }

        let empty = try fresh()
        #expect(empty.contourCount == 0)

        let noContour = try fresh()
        #expect(noContour.build() == nil, "a build with nothing added must be refused")
        #expect(noContour.contourCount == 0)

        let neverBuilt = try fresh()
        #expect(neverBuilt.addEdge(first, distance: 1))
        #expect(neverBuilt.contourCount == 1)

        let twoContours = try fresh()
        #expect(twoContours.addEdge(first, distance: 1))
        #expect(twoContours.addEdge(second, distance: 1))
        #expect(twoContours.contourCount == 2)

        let declined = try fresh()
        #expect(declined.addEdge(first, distance: 20))
        #expect(declined.build() == nil, "a distance of twice the box must be declined")
        #expect(declined.contourCount == 1)

        let built = try fresh()
        #expect(built.addEdge(first, distance: 1))
        #expect(built.build() != nil)
        #expect(built.contourCount == 1)

        let builtTwo = try fresh()
        #expect(builtTwo.addEdge(first, distance: 1))
        #expect(builtTwo.addEdge(second, distance: 1))
        #expect(builtTwo.build() != nil)
        #expect(builtTwo.contourCount == 2)

        let reset = try fresh()
        #expect(reset.addEdge(first, distance: 1))
        #expect(reset.build() != nil)
        reset.reset()

        // Contour 1 in each of the other two modes, so an index that leaked through to it answers
        // `true` or a pair of distances where the refusal is `false` or `-1`.
        let twoDistances = try fresh()
        #expect(twoDistances.addEdge(first, face: face, distance1: 1, distance2: 2))
        #expect(twoDistances.isTwoDistances(contour: 1))

        let distanceAngle = try fresh()
        #expect(distanceAngle.addEdge(first, face: face, distance: 1, angle: 0.5))
        #expect(distanceAngle.isDistanceAngle(contour: 1))

        return [
            ("fresh", empty),
            ("build with no contour", noContour),
            ("added, never built", neverBuilt),
            ("two contours, never built", twoContours),
            ("declined", declined),
            ("built", built),
            ("two contours, built", builtTwo),
            ("built, then reset", reset),
            ("two distances", twoDistances),
            ("distance and angle", distanceAngle),
        ]
    }

    /// Indices that are not in `1...cb.contourCount`, each one a different way to miss: the
    /// 1-based off-by-one, a negative, past the end by one and by a lot. `Int.max` and `Int.min`
    /// are not here: they test the Swift-to-C conversion and have their own test.
    private func badContours(_ cb: ChamferBuilder) -> [Int] {
        [0, -1, cb.contourCount + 1, cb.contourCount + 2, 100_000]
    }

    // MARK: - Reads that used to fault

    @Test("edgeCount answers 0 for a contour that does not exist")
    func edgeCount() throws {
        let fx = try fixture()
        for (name, cb) in try states(fx) {
            for i in badContours(cb) {
                #expect(cb.edgeCount(contour: i) == 0, "\(name), contour \(i)")
            }
        }
    }

    @Test("the mode flags answer false for a contour that does not exist")
    func modeFlags() throws {
        let fx = try fixture()
        for (name, cb) in try states(fx) {
            for i in badContours(cb) {
                #expect(!cb.isDistanceAngle(contour: i), "\(name), contour \(i)")
                #expect(!cb.isSymmetric(contour: i), "\(name), contour \(i)")
                #expect(!cb.isTwoDistances(contour: i), "\(name), contour \(i)")
            }
        }
    }

    @Test("the distance reads answer -1 for a contour that does not exist")
    func distanceReads() throws {
        let fx = try fixture()
        for (name, cb) in try states(fx) {
            for i in badContours(cb) {
                #expect(cb.getDistance(contour: i) == -1, "\(name), contour \(i)")
                let two = cb.getDistances(contour: i)
                #expect(two.d1 == -1 && two.d2 == -1, "\(name), contour \(i)")
                let angled = cb.getDistAngle(contour: i)
                #expect(angled.distance == -1 && angled.angle == -1, "\(name), contour \(i)")
            }
        }
    }

    @Test("edge answers nil for a contour or an index inside it that does not exist")
    func edge() throws {
        let fx = try fixture()
        for (name, cb) in try states(fx) {
            for i in badContours(cb) {
                #expect(cb.edge(contour: i, index: 1) == nil, "\(name), contour \(i)")
            }
            // The index inside the contour, for the contours that do exist.
            for c in 1...max(1, cb.contourCount) where c <= cb.contourCount {
                let n = cb.edgeCount(contour: c)
                #expect(n == 1, "\(name), contour \(c) holds one box edge")
                for j in [0, -1, n + 1, n + 2, 100_000] {
                    #expect(
                        cb.edge(contour: c, index: j) == nil, "\(name), contour \(c), edge \(j)")
                }
            }
        }
    }

    // MARK: - Reads that answered contour 1 for 0 and every negative index

    @Test("length answers -1 for a contour that does not exist, not contour 1's length")
    func length() throws {
        let fx = try fixture()
        for (name, cb) in try states(fx) {
            for i in badContours(cb) {
                #expect(cb.length(contour: i) == -1, "\(name), contour \(i)")
            }
        }
    }

    @Test("isClosed and isClosedAndTangent answer false for a contour that does not exist")
    func closedFlags() throws {
        let fx = try fixture()
        for (name, cb) in try states(fx) {
            for i in badContours(cb) {
                #expect(!cb.isClosed(contour: i), "\(name), contour \(i)")
                #expect(!cb.isClosedAndTangent(contour: i), "\(name), contour \(i)")
            }
        }
    }

    @Test("firstVertex and lastVertex answer nil for a contour that does not exist")
    func endVertices() throws {
        let fx = try fixture()
        for (name, cb) in try states(fx) {
            for i in badContours(cb) {
                #expect(cb.firstVertex(contour: i) == nil, "\(name), contour \(i)")
                #expect(cb.lastVertex(contour: i) == nil, "\(name), contour \(i)")
            }
        }
    }

    @Test("abscissa and relativeAbscissa answer -1 for a contour that does not exist")
    func abscissa() throws {
        // The fixture's vertex is on contour 1 of every state that has one, so contour 1 would
        // answer 0 and the contour index is the only thing wrong with the request.
        let fx = try fixture()
        for (name, cb) in try states(fx) {
            for i in badContours(cb) {
                #expect(cb.abscissa(contour: i, vertex: fx.vertex) == -1, "\(name), contour \(i)")
                #expect(
                    cb.relativeAbscissa(contour: i, vertex: fx.vertex) == -1,
                    "\(name), contour \(i)")
            }
        }
    }

    /// A closed contour, where contour 1 answers `true` and the refusal is `false`.
    ///
    /// A box edge is open, so contour 1 answers `false` to both questions and an index that leaked
    /// through to it is indistinguishable from the refusal. The rim of a cylinder is one closed
    /// edge, and a periodic spine.
    @Test("isClosed and isClosedAndTangent refuse a contour that does not exist, even over a rim")
    func closedContour() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        let rim = try #require(cylinder.edges().first { $0.isCircle })
        let cb = try #require(ChamferBuilder(shape: cylinder))
        try #require(cb.addEdge(rim, distance: 1))
        try #require(cb.contourCount == 1)
        try #require(cb.isClosed(contour: 1), "the rim is a closed contour")
        #expect(cb.isClosedAndTangent(contour: 1))
        for i in badContours(cb) {
            #expect(!cb.isClosed(contour: i), "contour \(i)")
            #expect(!cb.isClosedAndTangent(contour: i), "contour \(i)")
        }
    }

    // MARK: - Writes that landed on contour 1 for 0 and every negative index

    /// What contour 1 reads as, so a write that reached it through a bad index shows.
    private func contourOneFingerprint(_ cb: ChamferBuilder) -> [Double] {
        let two = cb.getDistances(contour: 1)
        let angled = cb.getDistAngle(contour: 1)
        return [
            cb.getDistance(contour: 1), two.d1, two.d2, angled.distance, angled.angle,
            cb.isSymmetric(contour: 1) ? 1 : 0, cb.isTwoDistances(contour: 1) ? 1 : 0,
            cb.isDistanceAngle(contour: 1) ? 1 : 0,
        ]
    }

    @Test("setDistance refuses a contour that does not exist and leaves contour 1 alone")
    func setDistance() throws {
        let fx = try fixture()
        for (name, cb) in try states(fx) {
            let before = contourOneFingerprint(cb)
            for i in badContours(cb) {
                #expect(!cb.setDistance(7, contour: i, face: fx.face), "\(name), contour \(i)")
            }
            #expect(
                contourOneFingerprint(cb) == before,
                "\(name): contour 1 was written through a bad index")
        }
    }

    @Test("setDistances refuses a contour that does not exist and leaves contour 1 alone")
    func setDistances() throws {
        let fx = try fixture()
        for (name, cb) in try states(fx) {
            let before = contourOneFingerprint(cb)
            for i in badContours(cb) {
                #expect(
                    !cb.setDistances(7, 9, contour: i, face: fx.face), "\(name), contour \(i)")
            }
            #expect(
                contourOneFingerprint(cb) == before,
                "\(name): contour 1 was written through a bad index")
        }
    }

    @Test("setDistAngle refuses a contour that does not exist and leaves contour 1 alone")
    func setDistAngle() throws {
        let fx = try fixture()
        for (name, cb) in try states(fx) {
            let before = contourOneFingerprint(cb)
            for i in badContours(cb) {
                #expect(
                    !cb.setDistAngle(distance: 7, angle: 0.5, contour: i, face: fx.face),
                    "\(name), contour \(i)")
            }
            #expect(
                contourOneFingerprint(cb) == before,
                "\(name): contour 1 was written through a bad index")
        }
    }

    // MARK: - Indices that do not fit in the C `int`

    /// An `Int` past `Int32` is converted by clamping and never reaches the bridge as a trap.
    ///
    /// `Int32(contour)` traps for such a value, which is a crash of its own and not the kernel's.
    /// Every method that takes a contour index goes through `Int32(clamping:)`, so these are
    /// ordinary out-of-range indices by the time they arrive.
    @Test("an index past Int32 is refused like any other, not trapped on")
    func indexBeyondInt32() throws {
        let fx = try fixture()
        let (face, vertex) = (fx.face, fx.vertex)

        // `Int` is 32 bits on wasm32, where `Int(Int32.max) + 1` itself overflows and traps. The two
        // values just past `Int32` are built by clamping: the real ones on a 64-bit `Int`, and
        // `Int.max` and `Int.min` again on a 32-bit one.
        let pastInt32 = [
            Int(clamping: Int64(Int32.max) + 1), Int(clamping: Int64(Int32.min) - 1),
        ]

        for (name, cb) in try states(fx) {
            for i in [Int.max, Int.min] + pastInt32 {
                #expect(!cb.isDistanceAngle(contour: i), "\(name), contour \(i)")
                #expect(cb.edgeCount(contour: i) == 0)
                #expect(cb.getDistance(contour: i) == -1)
                #expect(cb.getDistances(contour: i).d1 == -1)
                #expect(cb.getDistAngle(contour: i).distance == -1)
                #expect(!cb.setDistance(7, contour: i, face: face))
                #expect(!cb.setDistances(7, 9, contour: i, face: face))
                #expect(!cb.setDistAngle(distance: 7, angle: 0.5, contour: i, face: face))
                #expect(cb.length(contour: i) == -1)
                #expect(!cb.isClosed(contour: i))
                #expect(!cb.isClosedAndTangent(contour: i))
                #expect(!cb.isSymmetric(contour: i))
                #expect(!cb.isTwoDistances(contour: i))
                #expect(cb.edge(contour: i, index: 1) == nil)
                #expect(cb.edge(contour: 1, index: i) == nil)
                #expect(cb.firstVertex(contour: i) == nil)
                #expect(cb.lastVertex(contour: i) == nil)
                #expect(cb.abscissa(contour: i, vertex: vertex) == -1)
                #expect(cb.relativeAbscissa(contour: i, vertex: vertex) == -1)
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
        let fx = try fixture()
        let (box, first, second, face1) = (fx.box, fx.first, fx.second, fx.face)
        let cb = try #require(ChamferBuilder(shape: box))
        try #require(cb.addEdge(first, distance: 1))
        try #require(cb.addEdge(second, distance: 2))
        try #require(cb.contourCount == 2)

        for c in 1...2 {
            #expect(cb.edgeCount(contour: c) == 1)
            #expect(abs(cb.length(contour: c) - 10) < 1e-9)
            #expect(cb.isSymmetric(contour: c))
            #expect(!cb.isTwoDistances(contour: c))
            #expect(!cb.isDistanceAngle(contour: c))
            #expect(!cb.isClosed(contour: c))
            #expect(!cb.isClosedAndTangent(contour: c))
            #expect(cb.edge(contour: c, index: 1) != nil)

            let start = try #require(cb.firstVertex(contour: c))
            let end = try #require(cb.lastVertex(contour: c))
            #expect(abs(cb.abscissa(contour: c, vertex: start)) < 1e-9)
            #expect(abs(cb.relativeAbscissa(contour: c, vertex: start)) < 1e-9)
            #expect(abs(cb.abscissa(contour: c, vertex: end) - 10) < 1e-9)
            #expect(abs(cb.relativeAbscissa(contour: c, vertex: end) - 1) < 1e-9)
        }
        #expect(cb.getDistance(contour: 1) == 1)
        #expect(cb.getDistance(contour: 2) == 2)

        // The writes reach the contour they name, and only that one.
        let face2 = try #require(second.adjacentFaces(in: box)?.first)
        #expect(cb.setDistance(5, contour: 2, face: face2))
        #expect(cb.getDistance(contour: 2) == 5)
        #expect(cb.getDistance(contour: 1) == 1)

        #expect(cb.setDistances(1, 3, contour: 2, face: face2))
        #expect(cb.isTwoDistances(contour: 2))
        #expect(!cb.isTwoDistances(contour: 1))
        let two = cb.getDistances(contour: 2)
        #expect(Set([two.d1, two.d2]) == [1, 3], "the two distances are 1 and 3, in either order")

        #expect(cb.setDistAngle(distance: 2, angle: 0.5, contour: 1, face: face1))
        #expect(cb.isDistanceAngle(contour: 1))
        #expect(!cb.isDistanceAngle(contour: 2))
    }

    @Test("a built contour keeps its distances and its edge")
    func builtContourStillAnswers() throws {
        let fx = try fixture()
        let cb = try #require(ChamferBuilder(shape: fx.box))
        try #require(cb.addEdge(fx.first, distance: 1))
        try #require(cb.build() != nil)
        #expect(cb.edgeCount(contour: 1) == 1)
        #expect(cb.getDistance(contour: 1) == 1)
        #expect(cb.isSymmetric(contour: 1))
        #expect(cb.edge(contour: 1, index: 1) != nil)
    }
}
