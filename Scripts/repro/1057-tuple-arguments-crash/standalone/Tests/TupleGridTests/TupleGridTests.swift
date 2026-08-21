import Testing

// #1057. Each suite below is one cell of the grid: a `@Test(arguments:)` whose element type is the
// only thing that varies. Every body is trivial and touches nothing but its own argument, so any
// crash is attributable to how the argument is carried, not to what the test does with it.
//
// Run one cell per process, because a crash takes the whole process with it:
//
//     swift test --filter <SuiteStructName>
//
// `run-grid.sh` in the parent directory does that for every cell, N times each.

// MARK: - Element types

/// A plain final class: reference-counted, pointer-sized, 8-byte aligned. Lets the grid ask
/// whether it is `String` specifically or any reference-counted element.
final class Ref: Sendable, CustomStringConvertible {
    let n: Int
    init(_ n: Int) { self.n = n }
    var description: String { "Ref(\(n))" }
}

/// Size 32, alignment 16, built from two 16-byte vectors. Byte-for-byte the same layout as
/// `SIMD3<Double>`, which is how the grid separates "carries a 32-byte vector" from "is 32 bytes".
/// The name predates the layout being measured; `SIMD3<Double>` turns out to be alignment 16 too,
/// so nothing in this file is over-aligned and the interesting axis is the vector's own width.
struct Size32Align16: Sendable {
    var a: SIMD2<Double>
    var b: SIMD2<Double>
    init(_ x: Double) { a = SIMD2(x, x); b = SIMD2(x, x) }
}

/// A nominal struct whose only member is a `SIMD3<Double>`, so it carries a 32-byte builtin vector
/// without itself being one of the stdlib SIMD types. Separates "carries a wide vector" from "is a
/// SIMD type".
///
/// Over-alignment is not the axis, though it is what #1057 first proposed: `@_alignment(32)` is
/// rejected with "cannot increase alignment above maximum alignment of 16", and the `layout` cell
/// measures `SIMD3<Double>` at alignment 16, the runtime's maximum. Nothing here is over-aligned.
struct Vector32Wrapper: Sendable {
    var v: SIMD3<Double>
    init(_ x: Double) { v = SIMD3(x, x, x) }
}

/// A nominal struct with the same two stored properties as the crashing tuple, to ask whether the
/// tuple-ness matters or only the combination of members.
struct NamedPair: Sendable {
    var name: String
    var v: SIMD3<Double>
    init(_ name: String, _ v: SIMD3<Double>) {
        self.name = name
        self.v = v
    }
}

// MARK: - Layout, printed rather than asserted

@Suite("layout") struct L0Layout {
    @Test("print the layout of every element type in the grid")
    func layout() {
        func row<T>(_ label: String, _ t: T.Type) {
            print("\(label): size=\(MemoryLayout<T>.size) stride=\(MemoryLayout<T>.stride) align=\(MemoryLayout<T>.alignment)")
        }
        row("String", String.self)
        row("Ref", Ref.self)
        row("[Int]", [Int].self)
        row("Int", Int.self)
        row("Double", Double.self)
        row("SIMD2<Double>", SIMD2<Double>.self)
        row("SIMD3<Double>", SIMD3<Double>.self)
        row("SIMD4<Double>", SIMD4<Double>.self)
        row("SIMD4<Float>", SIMD4<Float>.self)
        row("SIMD8<Float>", SIMD8<Float>.self)
        row("Size32Align16", Size32Align16.self)
        row("Vector32Wrapper", Vector32Wrapper.self)
        row("NamedPair", NamedPair.self)
        row("(String, SIMD3<Double>)", (String, SIMD3<Double>).self)
        row("(SIMD3<Double>, SIMD3<Double>)", (SIMD3<Double>, SIMD3<Double>).self)
        // The `@Test` macro gives its local function `_: isolated (any Actor)? =
        // Testing.__defaultSynchronousIsolationContext`. This reads `nil`, and a `nil` isolation
        // does not by itself prevent the crash: the standalone narrowing (Smallest) has V50, a
        // *literal* `nil`, clean and V49, an opaque `nil` from an `@inline(never)` function,
        // crashing. So what matters is whether the compiler can fold the argument, and this
        // property is not inlinable. Printed rather than assumed, which is how the difference
        // between V39 and V49 was found in the first place.
        print("__defaultSynchronousIsolationContext: \(String(describing: __defaultSynchronousIsolationContext))")
        #expect(MemoryLayout<SIMD3<Double>>.alignment > 0)
    }
}

// MARK: - The two shapes #1057 reports as crashing

@Suite("A: (String, SIMD3<Double>)") struct A1StringSIMD3 {
    static let cases: [(String, SIMD3<Double>)] = [
        ("+X", SIMD3(1, 0, 0)), ("-X", SIMD3(-1, 0, 0)),
        ("+Y", SIMD3(0, 1, 0)), ("-Y", SIMD3(0, -1, 0)),
        ("+Z", SIMD3(0, 0, 1)), ("-Z", SIMD3(0, 0, -1)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, SIMD3<Double>)) { #expect(!f.0.isEmpty) }
}

@Suite("B: (String, SIMD3<Double>, SIMD3<Double>)") struct B1StringSIMD3SIMD3 {
    static let cases: [(String, SIMD3<Double>, SIMD3<Double>)] = [
        ("+X", SIMD3(1, 0, 0), SIMD3(0, -1, 0)), ("-X", SIMD3(-1, 0, 0), SIMD3(0, -1, 0)),
        ("+Y", SIMD3(0, 1, 0), SIMD3(1, 0, 0)), ("-Y", SIMD3(0, -1, 0), SIMD3(1, 0, 0)),
        ("+Z", SIMD3(0, 0, 1), SIMD3(0, 1, 0)), ("-Z", SIMD3(0, 0, -1), SIMD3(0, 1, 0)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, SIMD3<Double>, SIMD3<Double>)) { #expect(!f.0.isEmpty) }
}

// MARK: - The controls #1057 reports as clean

@Suite("C: (SIMD3<Double>, SIMD3<Double>)") struct C1SIMD3SIMD3 {
    static let cases: [(SIMD3<Double>, SIMD3<Double>)] = [
        (SIMD3(1, 0, 0), SIMD3(0, -1, 0)), (SIMD3(-1, 0, 0), SIMD3(0, -1, 0)),
        (SIMD3(0, 1, 0), SIMD3(1, 0, 0)), (SIMD3(0, -1, 0), SIMD3(1, 0, 0)),
        (SIMD3(0, 0, 1), SIMD3(0, 1, 0)), (SIMD3(0, 0, -1), SIMD3(0, 1, 0)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (SIMD3<Double>, SIMD3<Double>)) { #expect(f.0 != f.1) }
}

@Suite("D: (String, Int)") struct D1StringInt {
    static let cases: [(String, Int)] = [
        ("+X", 1), ("-X", 2), ("+Y", 3), ("-Y", 4), ("+Z", 5), ("-Z", 6),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, Int)) { #expect(!f.0.isEmpty) }
}

@Suite("E: bare SIMD3<Double>") struct E1BareSIMD3 {
    static let cases: [SIMD3<Double>] = [
        SIMD3(1, 0, 0), SIMD3(-1, 0, 0), SIMD3(0, 1, 0),
        SIMD3(0, -1, 0), SIMD3(0, 0, 1), SIMD3(0, 0, -1),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ v: SIMD3<Double>) { #expect(v != SIMD3(0, 0, 0)) }
}

@Suite("F: bare String") struct F1BareString {
    static let cases: [String] = ["+X", "-X", "+Y", "-Y", "+Z", "-Z"]
    @Test("trivial body", arguments: cases)
    func run(_ s: String) { #expect(!s.isEmpty) }
}

// MARK: - Which member is the refcounted one, and does order matter

@Suite("G: (SIMD3<Double>, String), order swapped") struct G1SIMD3String {
    static let cases: [(SIMD3<Double>, String)] = [
        (SIMD3(1, 0, 0), "+X"), (SIMD3(-1, 0, 0), "-X"),
        (SIMD3(0, 1, 0), "+Y"), (SIMD3(0, -1, 0), "-Y"),
        (SIMD3(0, 0, 1), "+Z"), (SIMD3(0, 0, -1), "-Z"),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (SIMD3<Double>, String)) { #expect(!f.1.isEmpty) }
}

@Suite("H: (Ref, SIMD3<Double>), a class not a String") struct H1RefSIMD3 {
    static let cases: [(Ref, SIMD3<Double>)] = [
        (Ref(1), SIMD3(1, 0, 0)), (Ref(2), SIMD3(-1, 0, 0)),
        (Ref(3), SIMD3(0, 1, 0)), (Ref(4), SIMD3(0, -1, 0)),
        (Ref(5), SIMD3(0, 0, 1)), (Ref(6), SIMD3(0, 0, -1)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (Ref, SIMD3<Double>)) { #expect(f.0.n > 0) }
}

@Suite("I: ([Int], SIMD3<Double>), an Array not a String") struct I1ArraySIMD3 {
    static let cases: [([Int], SIMD3<Double>)] = [
        ([1], SIMD3(1, 0, 0)), ([2], SIMD3(-1, 0, 0)),
        ([3], SIMD3(0, 1, 0)), ([4], SIMD3(0, -1, 0)),
        ([5], SIMD3(0, 0, 1)), ([6], SIMD3(0, 0, -1)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: ([Int], SIMD3<Double>)) { #expect(!f.0.isEmpty) }
}

// MARK: - Vector width against aggregate size

@Suite("J: (String, SIMD2<Double>), a 16-byte vector") struct J1StringSIMD2 {
    static let cases: [(String, SIMD2<Double>)] = [
        ("+X", SIMD2(1, 0)), ("-X", SIMD2(-1, 0)), ("+Y", SIMD2(0, 1)),
        ("-Y", SIMD2(0, -1)), ("+Z", SIMD2(1, 1)), ("-Z", SIMD2(-1, -1)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, SIMD2<Double>)) { #expect(!f.0.isEmpty) }
}

@Suite("K: (String, SIMD4<Double>), a 32-byte vector") struct K1StringSIMD4D {
    static let cases: [(String, SIMD4<Double>)] = [
        ("+X", SIMD4(1, 0, 0, 0)), ("-X", SIMD4(-1, 0, 0, 0)), ("+Y", SIMD4(0, 1, 0, 0)),
        ("-Y", SIMD4(0, -1, 0, 0)), ("+Z", SIMD4(0, 0, 1, 0)), ("-Z", SIMD4(0, 0, -1, 0)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, SIMD4<Double>)) { #expect(!f.0.isEmpty) }
}

@Suite("L: (String, SIMD4<Float>), a 16-byte vector") struct L1StringSIMD4F {
    static let cases: [(String, SIMD4<Float>)] = [
        ("+X", SIMD4(1, 0, 0, 0)), ("-X", SIMD4(-1, 0, 0, 0)), ("+Y", SIMD4(0, 1, 0, 0)),
        ("-Y", SIMD4(0, -1, 0, 0)), ("+Z", SIMD4(0, 0, 1, 0)), ("-Z", SIMD4(0, 0, -1, 0)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, SIMD4<Float>)) { #expect(!f.0.isEmpty) }
}

@Suite("M: (String, SIMD8<Float>), a 32-byte vector") struct M1StringSIMD8F {
    static let cases: [(String, SIMD8<Float>)] = [
        ("+X", SIMD8(repeating: 1)), ("-X", SIMD8(repeating: -1)), ("+Y", SIMD8(repeating: 2)),
        ("-Y", SIMD8(repeating: -2)), ("+Z", SIMD8(repeating: 3)), ("-Z", SIMD8(repeating: -3)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, SIMD8<Float>)) { #expect(!f.0.isEmpty) }
}

@Suite("N: (String, Size32Align16), 32 bytes of 16-byte vectors") struct N1StringSize32 {
    static let cases: [(String, Size32Align16)] = [
        ("+X", Size32Align16(1)), ("-X", Size32Align16(2)), ("+Y", Size32Align16(3)),
        ("-Y", Size32Align16(4)), ("+Z", Size32Align16(5)), ("-Z", Size32Align16(6)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, Size32Align16)) { #expect(!f.0.isEmpty) }
}

@Suite("O: (String, Vector32Wrapper), a 32-byte vector inside a struct") struct O1StringVector32 {
    static let cases: [(String, Vector32Wrapper)] = [
        ("+X", Vector32Wrapper(1)), ("-X", Vector32Wrapper(2)), ("+Y", Vector32Wrapper(3)),
        ("-Y", Vector32Wrapper(4)), ("+Z", Vector32Wrapper(5)), ("-Z", Vector32Wrapper(6)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, Vector32Wrapper)) { #expect(!f.0.isEmpty) }
}

@Suite("P: (String, Double), the word-sized POD control") struct P1StringDouble {
    static let cases: [(String, Double)] = [
        ("+X", 1), ("-X", 2), ("+Y", 3), ("-Y", 4), ("+Z", 5), ("-Z", 6),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, Double)) { #expect(!f.0.isEmpty) }
}

// MARK: - Is it the tuple, or the combination of members

@Suite("Q: NamedPair struct, same members as A") struct Q1NamedPair {
    static let cases: [NamedPair] = [
        NamedPair("+X", SIMD3(1, 0, 0)), NamedPair("-X", SIMD3(-1, 0, 0)),
        NamedPair("+Y", SIMD3(0, 1, 0)), NamedPair("-Y", SIMD3(0, -1, 0)),
        NamedPair("+Z", SIMD3(0, 0, 1)), NamedPair("-Z", SIMD3(0, 0, -1)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: NamedPair) { #expect(!f.name.isEmpty) }
}

// MARK: - Case count, the two-sequence form, and the serialized trait

@Suite("R: (String, SIMD3<Double>) with exactly one case") struct R1SingleCase {
    static let cases: [(String, SIMD3<Double>)] = [("+X", SIMD3(1, 0, 0))]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, SIMD3<Double>)) { #expect(!f.0.isEmpty) }
}

@Suite("S: two-sequence arguments:, String x SIMD3<Double>") struct S1TwoSequence {
    @Test("trivial body", arguments: ["+X", "-X", "+Y"], [SIMD3<Double>(1, 0, 0), SIMD3<Double>(0, 1, 0)])
    func run(_ s: String, _ v: SIMD3<Double>) { #expect(!s.isEmpty && v != SIMD3(0, 0, 0)) }
}

@Suite("T: (String, SIMD3<Double>) with .serialized", .serialized) struct T1Serialized {
    static let cases: [(String, SIMD3<Double>)] = [
        ("+X", SIMD3(1, 0, 0)), ("-X", SIMD3(-1, 0, 0)),
        ("+Y", SIMD3(0, 1, 0)), ("-Y", SIMD3(0, -1, 0)),
        ("+Z", SIMD3(0, 0, 1)), ("-Z", SIMD3(0, 0, -1)),
    ]
    @Test("trivial body", arguments: cases)
    func run(_ f: (String, SIMD3<Double>)) { #expect(!f.0.isEmpty) }
}

// MARK: - The workaround the repo uses

/// The claim "it crashes whatever the body does" was made throughout this directory while every
/// cell and variant still had a `precondition` or an `#expect` in it. This cell has neither: the
/// body is empty and the argument is never read. A pre-PR review is what noticed the claim was
/// unevidenced where it was made.
@Suite("V: (String, SIMD3<Double>) with a completely empty body") struct V1EmptyBody {
    static let cases: [(String, SIMD3<Double>)] = [
        ("+X", SIMD3(1, 0, 0)), ("-X", SIMD3(-1, 0, 0)),
        ("+Y", SIMD3(0, 1, 0)), ("-Y", SIMD3(0, -1, 0)),
        ("+Z", SIMD3(0, 0, 1)), ("-Z", SIMD3(0, 0, -1)),
    ]
    @Test("no body at all", arguments: cases)
    func run(_ f: (String, SIMD3<Double>)) {}
}

@Suite("U: one test walking the list, no arguments: at all") struct U1SerialLoop {
    static let cases: [(String, SIMD3<Double>)] = [
        ("+X", SIMD3(1, 0, 0)), ("-X", SIMD3(-1, 0, 0)),
        ("+Y", SIMD3(0, 1, 0)), ("-Y", SIMD3(0, -1, 0)),
        ("+Z", SIMD3(0, 0, 1)), ("-Z", SIMD3(0, 0, -1)),
    ]
    @Test("trivial body")
    func run() {
        for f in Self.cases { #expect(!f.0.isEmpty) }
    }
}
