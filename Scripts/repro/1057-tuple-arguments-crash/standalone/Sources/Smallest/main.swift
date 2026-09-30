// #1057, stage 3: the smallest form that still crashes, and the variations that pin its edges.
//
// From MinimalRepro: swift-testing is not needed, the generic driver is not needed, the task group
// is not needed. What is needed is an `async` function with an `isolated (any Actor)?` parameter
// whose other parameter is a tuple mixing a reference-counted element with a 32-byte builtin
// vector. That is what the `@Test` macro expansion writes (`Testing.__defaultSynchronousIsolationContext`
// is its default), which is why every `@Test(arguments:)` over such a tuple takes it.
//
//     swift run Smallest        # every variant in order
//     swift run Smallest 1      # only variant 1
//
// One process per variant, since the crash is fatal: run-variants.sh does that.

@globalActor actor Iso {
    static let shared = Iso()
}

typealias Mixed = (String, SIMD3<Double>)
let mixed: Mixed = ("+X", SIMD3(1, 0, 0))
let pod: (SIMD3<Double>, SIMD3<Double>) = (SIMD3(1, 0, 0), SIMD3(0, 1, 0))

// V1: the smallest crashing form. A top-level `async` function, one tuple parameter, one
// `isolated` parameter with a default. No nesting, no @Sendable, no generics, no task group.
func v1(_ a: Mixed, _: isolated (any Actor)? = Iso.shared) async { precondition(!a.0.isEmpty) }

// V2: the same with `nil` as the default rather than a real actor.
func v2(_ a: Mixed, _: isolated (any Actor)? = nil) async { precondition(!a.0.isEmpty) }

// V3: the isolated parameter passed explicitly instead of defaulted.
func v3(_ a: Mixed, _: isolated (any Actor)?) async { precondition(!a.0.isEmpty) }

// V4: a non-optional isolated parameter.
func v4(_ a: Mixed, _: isolated any Actor) async { precondition(!a.0.isEmpty) }

// V5: no isolated parameter at all, the control for V1.
func v5(_ a: Mixed) async { precondition(!a.0.isEmpty) }

// V6: V1's shape with the all-POD tuple.
func v6(_ a: (SIMD3<Double>, SIMD3<Double>), _: isolated (any Actor)? = Iso.shared) async {
    precondition(a.0 != a.1)
}

// V7: V1's shape with a reference-counted element and a word-sized one.
func v7(_ a: (String, Int), _: isolated (any Actor)? = Iso.shared) async { precondition(!a.0.isEmpty) }

// V8: V1's shape with the vector alone, no reference-counted element.
func v8(_ a: SIMD3<Double>, _: isolated (any Actor)? = Iso.shared) async { precondition(a != SIMD3()) }

// V9: V1's shape with the reference-counted element alone.
func v9(_ a: String, _: isolated (any Actor)? = Iso.shared) async { precondition(!a.isEmpty) }

// V10: the two members as separate parameters rather than one tuple.
func v10(_ s: String, _ v: SIMD3<Double>, _: isolated (any Actor)? = Iso.shared) async {
    precondition(!s.isEmpty && v != SIMD3())
}

// V11: the isolated parameter first.
func v11(_: isolated (any Actor)? = Iso.shared, _ a: Mixed) async { precondition(!a.0.isEmpty) }

// V12: a nominal struct with the same two members instead of a tuple.
struct Pair: Sendable {
    var name: String
    var v: SIMD3<Double>
}
func v12(_ a: Pair, _: isolated (any Actor)? = Iso.shared) async { precondition(!a.name.isEmpty) }

// V13: V1's tuple with a 16-byte vector instead of a 32-byte one.
func v13(_ a: (String, SIMD2<Double>), _: isolated (any Actor)? = Iso.shared) async {
    precondition(!a.0.isEmpty)
}

// V14: not async. An `isolated` parameter on a synchronous function. It can only be called from
// code already isolated to that actor, so reaching it needs an isolated caller.
func v14(_ a: Mixed, _: isolated (any Actor)? = Iso.shared) { precondition(!a.0.isEmpty) }
@Iso func callV14() { v14(mixed, Iso.shared) }

// V1 to V14 are all clean, so a top-level function with an `isolated` parameter is not the shape.
// The macro expansion nests it: the `isolated` parameter is on a *local* function declared inside
// another `async` function, and that is what V15 onward vary.

// V15: the crashing form. Local `async` function with an `isolated` parameter, taking the mixed
// tuple, called from the enclosing `async` function.
func v15(_ a: Mixed) async {
    @Sendable func local(_ a: Mixed, _: isolated (any Actor)? = Iso.shared) async {
        precondition(!a.0.isEmpty)
    }
    await local(a)
}

// V16: the same with the all-POD tuple.
func v16(_ a: (SIMD3<Double>, SIMD3<Double>)) async {
    @Sendable func local(
        _ a: (SIMD3<Double>, SIMD3<Double>), _: isolated (any Actor)? = Iso.shared
    ) async {
        precondition(a.0 != a.1)
    }
    await local(a)
}

// V17: V15 without `@Sendable` on the local function.
func v17(_ a: Mixed) async {
    func local(_ a: Mixed, _: isolated (any Actor)? = Iso.shared) async {
        precondition(!a.0.isEmpty)
    }
    await local(a)
}

// V18: V15 with the isolated argument passed explicitly rather than defaulted.
func v18(_ a: Mixed) async {
    @Sendable func local(_ a: Mixed, _: isolated (any Actor)?) async {
        precondition(!a.0.isEmpty)
    }
    await local(a, Iso.shared)
}

// V19: V15 without the isolated parameter, the control.
func v19(_ a: Mixed) async {
    @Sendable func local(_ a: Mixed) async {
        precondition(!a.0.isEmpty)
    }
    await local(a)
}

// V20: V15's shape with a 16-byte vector.
func v20(_ a: (String, SIMD2<Double>)) async {
    @Sendable func local(_ a: (String, SIMD2<Double>), _: isolated (any Actor)? = Iso.shared) async {
        precondition(!a.0.isEmpty)
    }
    await local(a)
}

// V21: V15's shape with a nominal struct instead of a tuple.
func v21(_ a: Pair) async {
    @Sendable func local(_ a: Pair, _: isolated (any Actor)? = Iso.shared) async {
        precondition(!a.name.isEmpty)
    }
    await local(a)
}

// V22: V15's shape with the two members as separate parameters.
func v22(_ s: String, _ v: SIMD3<Double>) async {
    @Sendable func local(
        _ s: String, _ v: SIMD3<Double>, _: isolated (any Actor)? = Iso.shared
    ) async {
        precondition(!s.isEmpty && v != SIMD3())
    }
    await local(s, v)
}

// V23: V15's shape with a 32-byte vector of Floats rather than Doubles.
func v23(_ a: (String, SIMD8<Float>)) async {
    @Sendable func local(_ a: (String, SIMD8<Float>), _: isolated (any Actor)? = Iso.shared) async {
        precondition(!a.0.isEmpty)
    }
    await local(a)
}

// V24: V15's shape with a 32-byte, 16-aligned struct that contains no 32-byte vector.
struct Size32Align16: Sendable {
    var a: SIMD2<Double>
    var b: SIMD2<Double>
}
func v24(_ a: (String, Size32Align16)) async {
    @Sendable func local(_ a: (String, Size32Align16), _: isolated (any Actor)? = Iso.shared) async {
        precondition(!a.0.isEmpty)
    }
    await local(a)
}

// V25: V15's shape with the vector alone, no reference-counted element.
func v25(_ a: SIMD3<Double>) async {
    @Sendable func local(_ a: SIMD3<Double>, _: isolated (any Actor)? = Iso.shared) async {
        precondition(a != SIMD3())
    }
    await local(a)
}

// V15 to V25 are clean too, so nesting alone is not it either. The one thing left in
// MinimalRepro's crashing stage 21 that none of the above has is `throws`: both the outer and the
// local function there are `async throws`, which gives the local function an error return
// alongside its `isolated` parameter.

// V26: V15 plus `throws` on both.
func v26(_ a: Mixed) async throws {
    @Sendable func local(_ a: Mixed, _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

// V27: the same with the all-POD tuple.
func v27(_ a: (SIMD3<Double>, SIMD3<Double>)) async throws {
    @Sendable func local(
        _ a: (SIMD3<Double>, SIMD3<Double>), _: isolated (any Actor)? = Iso.shared
    ) async throws {
        precondition(a.0 != a.1)
    }
    try await local(a)
}

// V28: `throws` on the local function only.
func v28(_ a: Mixed) async {
    @Sendable func local(_ a: Mixed, _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try? await local(a)
}

// V29: `throws` on the outer function only.
func v29(_ a: Mixed) async throws {
    @Sendable func local(_ a: Mixed, _: isolated (any Actor)? = Iso.shared) async {
        precondition(!a.0.isEmpty)
    }
    await local(a)
}

// V30: V26 without the isolated parameter, the control for the `throws` pairing.
func v30(_ a: Mixed) async throws {
    @Sendable func local(_ a: Mixed) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

// V31: V26's shape with a 16-byte vector.
func v31(_ a: (String, SIMD2<Double>)) async throws {
    @Sendable func local(
        _ a: (String, SIMD2<Double>), _: isolated (any Actor)? = Iso.shared
    ) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

// V32: V26's shape with a 32-byte, 16-aligned struct containing no 32-byte vector.
func v32(_ a: (String, Size32Align16)) async throws {
    @Sendable func local(
        _ a: (String, Size32Align16), _: isolated (any Actor)? = Iso.shared
    ) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

// V33: V26's shape with a nominal struct instead of a tuple.
func v33(_ a: Pair) async throws {
    @Sendable func local(_ a: Pair, _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.name.isEmpty)
    }
    try await local(a)
}

// V34: V26's shape with the two members as separate parameters.
func v34(_ s: String, _ v: SIMD3<Double>) async throws {
    @Sendable func local(
        _ s: String, _ v: SIMD3<Double>, _: isolated (any Actor)? = Iso.shared
    ) async throws {
        precondition(!s.isEmpty && v != SIMD3())
    }
    try await local(s, v)
}

// V35: V26's shape with the vector alone.
func v35(_ a: SIMD3<Double>) async throws {
    @Sendable func local(_ a: SIMD3<Double>, _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(a != SIMD3())
    }
    try await local(a)
}

// V36: V26 as a top-level function rather than a nested one, to confirm the nesting is required
// once `throws` is present.
func v36Local(_ a: Mixed, _: isolated (any Actor)? = Iso.shared) async throws {
    precondition(!a.0.isEmpty)
}

// V37: V26 without `@Sendable` on the local function.
func v37(_ a: Mixed) async throws {
    func local(_ a: Mixed, _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

// V38: V26 with the isolated argument passed explicitly.
func v38(_ a: Mixed) async throws {
    @Sendable func local(_ a: Mixed, _: isolated (any Actor)?) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a, Iso.shared)
}

// V39: V26 with a `nil` default for the isolated parameter.
func v39(_ a: Mixed) async throws {
    @Sendable func local(_ a: Mixed, _: isolated (any Actor)? = nil) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

// V26 is the crashing form and V27 to V39 pin its edges. V40 onward vary only the element type
// inside it, which is what the swift-testing grid varied.

final class Ref: Sendable { let n: Int; init(_ n: Int) { self.n = n } }

// Each of these is V26 with one element type substituted, written out concretely rather than
// through a generic, because a generic would change the shape as well as the type.

func v40(_ a: (String, SIMD4<Double>)) async throws {
    @Sendable func local(
        _ a: (String, SIMD4<Double>), _: isolated (any Actor)? = Iso.shared
    ) async throws { precondition(!a.0.isEmpty) }
    try await local(a)
}

func v41(_ a: (String, SIMD8<Float>)) async throws {
    @Sendable func local(
        _ a: (String, SIMD8<Float>), _: isolated (any Actor)? = Iso.shared
    ) async throws { precondition(!a.0.isEmpty) }
    try await local(a)
}

func v42(_ a: (String, SIMD4<Float>)) async throws {
    @Sendable func local(
        _ a: (String, SIMD4<Float>), _: isolated (any Actor)? = Iso.shared
    ) async throws { precondition(!a.0.isEmpty) }
    try await local(a)
}

func v43(_ a: (Ref, SIMD3<Double>)) async throws {
    @Sendable func local(
        _ a: (Ref, SIMD3<Double>), _: isolated (any Actor)? = Iso.shared
    ) async throws { precondition(a.0.n > 0) }
    try await local(a)
}

func v44(_ a: ([Int], SIMD3<Double>)) async throws {
    @Sendable func local(
        _ a: ([Int], SIMD3<Double>), _: isolated (any Actor)? = Iso.shared
    ) async throws { precondition(!a.0.isEmpty) }
    try await local(a)
}

func v45(_ a: (SIMD3<Double>, String)) async throws {
    @Sendable func local(
        _ a: (SIMD3<Double>, String), _: isolated (any Actor)? = Iso.shared
    ) async throws { precondition(!a.1.isEmpty) }
    try await local(a)
}

func v46(_ a: (String, SIMD16<Float>)) async throws {
    @Sendable func local(
        _ a: (String, SIMD16<Float>), _: isolated (any Actor)? = Iso.shared
    ) async throws { precondition(!a.0.isEmpty) }
    try await local(a)
}

// V39 (`= nil` as the default) is clean, but `Testing.__defaultSynchronousIsolationContext` reads
// `nil` at runtime in this configuration and swift-testing still crashes. So the discriminator is
// not the actor's value but whether the compiler can see it: a literal `nil` folds away, an opaque
// `(any Actor)?` does not. V48 to V50 test that directly.

@inline(never) func opaqueIsolation() -> (any Actor)? { nil }

// V51 and V52 are the word-sized controls in V26's own shape. The swift-testing grid already had
// them (cells D and P) but under a different shape, and a table that mixes the two is a table
// nobody can check.

// V53 to V56 probe the edge of "an aggregate holding a 32-byte vector". A pre-PR review measured
// `(String, simd_double3x3)` clean, which the rule as first written says should crash. These are
// the same shapes without importing `simd`, so `Smallest` stays dependency-free.

struct Vec1: Sendable { var a: SIMD3<Double> }
struct Vec2: Sendable { var a: SIMD3<Double>; var b: SIMD3<Double> }
struct Vec3: Sendable { var a: SIMD3<Double>; var b: SIMD3<Double>; var c: SIMD3<Double> }

func v53(_ a: (String, Vec1)) async throws {
    @Sendable func local(_ a: (String, Vec1), _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

func v54(_ a: (String, Vec2)) async throws {
    @Sendable func local(_ a: (String, Vec2), _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

func v55(_ a: (String, Vec3)) async throws {
    @Sendable func local(_ a: (String, Vec3), _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

func v56(_ a: (String, (SIMD3<Double>, SIMD3<Double>))) async throws {
    @Sendable func local(
        _ a: (String, (SIMD3<Double>, SIMD3<Double>)), _: isolated (any Actor)? = Iso.shared
    ) async throws { precondition(!a.0.isEmpty) }
    try await local(a)
}

// V57: an integer vector. The census script's first regex only knew about Double and Float
// element types, and the same pre-PR review measured this crashing.
func v57(_ a: (String, SIMD4<Int64>)) async throws {
    @Sendable func local(
        _ a: (String, SIMD4<Int64>), _: isolated (any Actor)? = Iso.shared
    ) async throws { precondition(!a.0.isEmpty) }
    try await local(a)
}

// V55 being clean while V53 and V54 crash says the aggregate's total size decides it, not just
// "contains a 32-byte vector". V58 to V62 walk the parameter size up in 8-byte steps to find where
// it flips, and each prints its own `MemoryLayout` so the table labels itself.

struct Pad1: Sendable { var a: SIMD3<Double>; var b: SIMD3<Double>; var p0: Double }
struct Pad2: Sendable { var a: SIMD3<Double>; var b: SIMD3<Double>; var p0, p1: Double }
struct Pad3: Sendable { var a: SIMD3<Double>; var b: SIMD3<Double>; var p0, p1, p2: Double }
struct Pad4: Sendable { var a: SIMD3<Double>; var b: SIMD3<Double>; var p0, p1, p2, p3: Double }

func v58(_ a: (String, Pad1)) async throws {
    @Sendable func local(_ a: (String, Pad1), _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

func v59(_ a: (String, Pad2)) async throws {
    @Sendable func local(_ a: (String, Pad2), _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

func v60(_ a: (String, Pad3)) async throws {
    @Sendable func local(_ a: (String, Pad3), _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

func v61(_ a: (String, Pad4)) async throws {
    @Sendable func local(_ a: (String, Pad4), _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

// V58 to V61 are clean at 88 bytes and up while V54 and V47 crash at 80, so the aggregate's total
// size looks like the second half of the rule. V63 and V64 test that against vector *count*: one
// vector at 80 bytes, and one vector at 96.

struct One80: Sendable { var a: SIMD3<Double>; var p0, p1, p2, p3: Double }
struct One88: Sendable { var a: SIMD3<Double>; var p0, p1, p2, p3, p4: Double }

func v63(_ a: (String, One80)) async throws {
    @Sendable func local(_ a: (String, One80), _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

func v64(_ a: (String, One88)) async throws {
    @Sendable func local(_ a: (String, One88), _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

func size<T>(_ t: T.Type) -> String { "size=\(MemoryLayout<T>.size) stride=\(MemoryLayout<T>.stride)" }

func v51(_ a: (String, Int)) async throws {
    @Sendable func local(_ a: (String, Int), _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

func v52(_ a: (String, Double)) async throws {
    @Sendable func local(
        _ a: (String, Double), _: isolated (any Actor)? = Iso.shared
    ) async throws { precondition(!a.0.isEmpty) }
    try await local(a)
}

func v48(_ a: Mixed) async throws {
    @Sendable func local(
        _ a: Mixed, _: isolated (any Actor)? = opaqueIsolation()
    ) async throws { precondition(!a.0.isEmpty) }
    try await local(a)
}

func v49(_ a: Mixed) async throws {
    @Sendable func local(_ a: Mixed, _: isolated (any Actor)?) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a, opaqueIsolation())
}

func v50(_ a: Mixed) async throws {
    @Sendable func local(_ a: Mixed, _: isolated (any Actor)?) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a, nil)
}

func v47(_ a: (String, SIMD3<Double>, SIMD3<Double>)) async throws {
    @Sendable func local(
        _ a: (String, SIMD3<Double>, SIMD3<Double>), _: isolated (any Actor)? = Iso.shared
    ) async throws { precondition(!a.0.isEmpty) }
    try await local(a)
}

func variant(_ n: Int, _ label: String, _ work: () async throws -> Void) async {
    let only = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) : nil
    if let only, only != n { return }
    print("v\(n): \(label) ... ", terminator: "")
    do {
        try await work()
        print("clean")
    } catch {
        print("threw \(error)")
    }
}

await variant(1, "(String, SIMD3<Double>) + isolated default") { await v1(mixed) }
await variant(2, "same, isolated default nil") { await v2(mixed) }
await variant(3, "same, isolated passed explicitly") { await v3(mixed, Iso.shared) }
await variant(4, "same, non-optional isolated") { await v4(mixed, Iso.shared) }
await variant(5, "same tuple, no isolated parameter") { await v5(mixed) }
await variant(6, "(SIMD3, SIMD3) + isolated default") { await v6(pod) }
await variant(7, "(String, Int) + isolated default") { await v7(("+X", 1)) }
await variant(8, "bare SIMD3<Double> + isolated default") { await v8(SIMD3(1, 0, 0)) }
await variant(9, "bare String + isolated default") { await v9("+X") }
await variant(10, "String and SIMD3 as separate parameters") { await v10("+X", SIMD3(1, 0, 0)) }
await variant(11, "isolated parameter first") { await v11(Iso.shared, mixed) }
await variant(12, "a struct with the same two members") { await v12(Pair(name: "+X", v: SIMD3(1, 0, 0))) }
await variant(13, "(String, SIMD2<Double>) + isolated default") { await v13(("+X", SIMD2(1, 0))) }
await variant(14, "synchronous function with an isolated parameter") { await callV14() }

await variant(15, "LOCAL func with isolated default, mixed tuple") { await v15(mixed) }
await variant(16, "LOCAL func with isolated default, all-POD tuple") { await v16(pod) }
await variant(17, "V15 without @Sendable on the local func") { await v17(mixed) }
await variant(18, "V15 with the isolated argument passed explicitly") { await v18(mixed) }
await variant(19, "V15 without the isolated parameter") { await v19(mixed) }
await variant(20, "V15's shape with SIMD2<Double>, 16 bytes") { await v20(("+X", SIMD2(1, 0))) }
await variant(21, "V15's shape with a struct instead of a tuple") { await v21(Pair(name: "+X", v: SIMD3(1, 0, 0))) }
await variant(22, "V15's shape with separate parameters") { await v22("+X", SIMD3(1, 0, 0)) }
await variant(23, "V15's shape with SIMD8<Float>, 32 bytes") { await v23(("+X", SIMD8(repeating: 1))) }
await variant(24, "V15's shape with a 32-byte 16-aligned struct, no vector") {
    await v24(("+X", Size32Align16(a: SIMD2(1, 1), b: SIMD2(2, 2))))
}
await variant(25, "V15's shape with the vector alone") { await v25(SIMD3(1, 0, 0)) }

await variant(26, "V15 plus throws on both, mixed tuple") { try await v26(mixed) }
await variant(27, "V15 plus throws on both, all-POD tuple") { try await v27(pod) }
await variant(28, "throws on the local function only") { await v28(mixed) }
await variant(29, "throws on the outer function only") { try await v29(mixed) }
await variant(30, "V26 without the isolated parameter") { try await v30(mixed) }
await variant(31, "V26's shape with SIMD2<Double>, 16 bytes") { try await v31(("+X", SIMD2(1, 0))) }
await variant(32, "V26's shape with a 32-byte 16-aligned struct, no vector") {
    try await v32(("+X", Size32Align16(a: SIMD2(1, 1), b: SIMD2(2, 2))))
}
await variant(33, "V26's shape with a struct instead of a tuple") {
    try await v33(Pair(name: "+X", v: SIMD3(1, 0, 0)))
}
await variant(34, "V26's shape with separate parameters") { try await v34("+X", SIMD3(1, 0, 0)) }
await variant(35, "V26's shape with the vector alone") { try await v35(SIMD3(1, 0, 0)) }
await variant(36, "V26's local function hoisted to the top level") { try await v36Local(mixed) }
await variant(37, "V26 without @Sendable on the local function") { try await v37(mixed) }
await variant(38, "V26 with the isolated argument passed explicitly") { try await v38(mixed) }
await variant(39, "V26 with a nil default for the isolated parameter") { try await v39(mixed) }

await variant(40, "V26 with SIMD4<Double>, 32 bytes") { try await v40(("+X", SIMD4(1, 0, 0, 0))) }
await variant(41, "V26 with SIMD8<Float>, 32 bytes") { try await v41(("+X", SIMD8(repeating: 1))) }
await variant(42, "V26 with SIMD4<Float>, 16 bytes") { try await v42(("+X", SIMD4(1, 0, 0, 0))) }
await variant(43, "V26 with a class instead of String") { try await v43((Ref(1), SIMD3(1, 0, 0))) }
await variant(44, "V26 with an Array instead of String") { try await v44(([1], SIMD3(1, 0, 0))) }
await variant(45, "V26 with the two members swapped") { try await v45((SIMD3(1, 0, 0), "+X")) }
await variant(46, "V26 with SIMD16<Float>, 64 bytes") { try await v46(("+X", SIMD16(repeating: 1))) }
await variant(47, "V26 with a three-element tuple") {
    try await v47(("+X", SIMD3(1, 0, 0), SIMD3(0, 1, 0)))
}

await variant(48, "V26 with an opaque nil isolation as the default") { try await v48(mixed) }
await variant(49, "V26 with an opaque nil isolation passed explicitly") { try await v49(mixed) }
await variant(50, "V26 with a literal nil isolation passed explicitly") { try await v50(mixed) }

await variant(51, "V26 with (String, Int)") { try await v51(("+X", 1)) }
await variant(52, "V26 with (String, Double)") { try await v52(("+X", 1.0)) }
await variant(53, "V26 with a struct of ONE SIMD3<Double>") {
    try await v53(("+X", Vec1(a: SIMD3(1, 0, 0))))
}
await variant(54, "V26 with a struct of TWO SIMD3<Double>") {
    try await v54(("+X", Vec2(a: SIMD3(1, 0, 0), b: SIMD3(0, 1, 0))))
}
await variant(55, "V26 with a struct of THREE SIMD3<Double>, the simd_double3x3 shape") {
    try await v55(("+X", Vec3(a: SIMD3(1, 0, 0), b: SIMD3(0, 1, 0), c: SIMD3(0, 0, 1))))
}
await variant(56, "V26 with a nested tuple of two SIMD3<Double>") {
    try await v56(("+X", (SIMD3(1, 0, 0), SIMD3(0, 1, 0))))
}
await variant(57, "V26 with SIMD4<Int64>, 32 bytes of integers") {
    try await v57(("+X", SIMD4(1, 0, 0, 0)))
}
await variant(58, "V26, two vectors + 1 Double, \(size((String, Pad1).self))") {
    try await v58(("+X", Pad1(a: SIMD3(1, 0, 0), b: SIMD3(0, 1, 0), p0: 0)))
}
await variant(59, "V26, two vectors + 2 Doubles, \(size((String, Pad2).self))") {
    try await v59(("+X", Pad2(a: SIMD3(1, 0, 0), b: SIMD3(0, 1, 0), p0: 0, p1: 0)))
}
await variant(60, "V26, two vectors + 3 Doubles, \(size((String, Pad3).self))") {
    try await v60(("+X", Pad3(a: SIMD3(1, 0, 0), b: SIMD3(0, 1, 0), p0: 0, p1: 0, p2: 0)))
}
await variant(61, "V26, two vectors + 4 Doubles, \(size((String, Pad4).self))") {
    try await v61(("+X", Pad4(a: SIMD3(1, 0, 0), b: SIMD3(0, 1, 0), p0: 0, p1: 0, p2: 0, p3: 0)))
}
await variant(63, "V26, ONE vector padded to \(size((String, One80).self))") {
    try await v63(("+X", One80(a: SIMD3(1, 0, 0), p0: 0, p1: 0, p2: 0, p3: 0)))
}
await variant(64, "V26, ONE vector padded to \(size((String, One88).self))") {
    try await v64(("+X", One88(a: SIMD3(1, 0, 0), p0: 0, p1: 0, p2: 0, p3: 0, p4: 0)))
}
await variant(62, "layouts of every crashing and clean parameter type") {
    print("")
    print("  (String, SIMD3<Double>)                  \(size((String, SIMD3<Double>).self))  crash")
    print("  (String, SIMD4<Int64>)                   \(size((String, SIMD4<Int64>).self))  crash")
    print("  (String, SIMD16<Float>)                  \(size((String, SIMD16<Float>).self))  crash")
    print("  (String, SIMD3<Double>, SIMD3<Double>)   \(size((String, SIMD3<Double>, SIMD3<Double>).self))  crash")
    print("  (String, Vec1)                           \(size((String, Vec1).self))  crash")
    print("  (String, Vec2)                           \(size((String, Vec2).self))  crash")
    print("  (String, Vec3)                           \(size((String, Vec3).self))  clean")
    print("  (String, SIMD2<Double>)                  \(size((String, SIMD2<Double>).self))  clean")
    print("  (String, Size32Align16)                  \(size((String, Size32Align16).self))  clean")
    print("  (SIMD3<Double>, SIMD3<Double>)           \(size((SIMD3<Double>, SIMD3<Double>).self))  clean")
    print("  ", terminator: "")
}

print("all requested variants finished")
