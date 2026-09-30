// #1057, stage 2: the same crash with no swift-testing anywhere.
//
// The backtrace from the grid puts the failing `swift_task_dealloc` in a compiler-emitted
// `implicit closure` inside the `@Test` macro expansion, not in any Testing frame. So the shape
// worth isolating is what that expansion reduces to in plain Swift: an `async` function whose one
// parameter is a tuple mixing a reference-counted element with a 32-byte builtin vector, referenced
// as a value and called through a generic higher-order `async` function.
//
// Each stage below prints before and after, so a crash names the stage that produced it. Pass a
// stage number to run just that one:
//
//     swift run MinimalRepro          # all stages in order
//     swift run MinimalRepro 4        # only stage 4

import Driver

typealias Crashing = (String, SIMD3<Double>)
typealias Control = (SIMD3<Double>, SIMD3<Double>)

let crashingCases: [Crashing] = [
    ("+X", SIMD3(1, 0, 0)), ("-X", SIMD3(-1, 0, 0)),
    ("+Y", SIMD3(0, 1, 0)), ("-Y", SIMD3(0, -1, 0)),
    ("+Z", SIMD3(0, 0, 1)), ("-Z", SIMD3(0, 0, -1)),
]
let controlCases: [Control] = [
    (SIMD3(1, 0, 0), SIMD3(0, -1, 0)), (SIMD3(-1, 0, 0), SIMD3(0, -1, 0)),
    (SIMD3(0, 1, 0), SIMD3(1, 0, 0)), (SIMD3(0, -1, 0), SIMD3(1, 0, 0)),
    (SIMD3(0, 0, 1), SIMD3(0, 1, 0)), (SIMD3(0, 0, -1), SIMD3(0, 1, 0)),
]

@Sendable func body(_ arg: Crashing) async throws { precondition(!arg.0.isEmpty) }
@Sendable func controlBody(_ arg: Control) async throws { precondition(arg.0 != arg.1) }

/// Stands in for `Testing.Test.Case.Generator`: generic over the element, stores the test function
/// as a `@Sendable` value, and calls it once per element inside a task group, which is how
/// swift-testing runs parameterised cases.
func drive<Element: Sendable>(
    _ elements: [Element],
    _ f: @escaping @Sendable (Element) async throws -> Void
) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        for e in elements {
            group.addTask { try await f(e) }
        }
        try await group.waitForAll()
    }
}

func stage(_ n: Int, _ label: String, _ work: () async throws -> Void) async {
    let only = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) : nil
    if let only, only != n { return }
    print("stage \(n): \(label) ... ", terminator: "")
    do {
        try await work()
        print("clean")
    } catch {
        print("threw \(error)")
    }
}

await stage(1, "direct await, one crashing tuple") {
    try await body(crashingCases[0])
}

await stage(2, "through a concrete function value") {
    let f: @Sendable (Crashing) async throws -> Void = body
    for c in crashingCases { try await f(c) }
}

await stage(3, "through a generic higher-order function, serially") {
    for c in crashingCases {
        try await drive([c], body)
    }
}

await stage(4, "through a generic higher-order function in a task group, crashing tuple") {
    try await drive(crashingCases, body)
}

await stage(5, "the same, control tuple with no reference-counted element") {
    try await drive(controlCases, controlBody)
}

// Stages 1 to 5 are all clean, so a plain generic higher-order `async` call is not the shape.
// swift-testing's own `Test.Case.Generator.init` is generic over a *parameter pack* whose tuple is
// the sequence element (`where S.Element == (repeat each T)`), and it calls the test function by
// expanding that tuple back into the pack. Stages 6 and 7 are that.

/// Stands in for the real `Test.Case.Generator.init<each T>(sequence:parameters:testFunction:)`:
/// the element type is a tuple, the function takes the corresponding parameter pack, and the call
/// site expands one back into the other.
func packDrive<each T: Sendable>(
    _ elements: [(repeat each T)],
    _ f: @escaping @Sendable (repeat each T) async throws -> Void
) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        for e in elements {
            group.addTask { try await f(repeat each e) }
        }
        try await group.waitForAll()
    }
}

@Sendable func packBody(_ name: String, _ v: SIMD3<Double>) async throws {
    precondition(!name.isEmpty && v != SIMD3(0, 0, 0))
}
@Sendable func packControlBody(_ a: SIMD3<Double>, _ b: SIMD3<Double>) async throws {
    precondition(a != b)
}

await stage(6, "tuple expanded into a parameter pack, crashing tuple") {
    try await packDrive(crashingCases, packBody)
}

await stage(7, "tuple expanded into a parameter pack, control tuple") {
    try await packDrive(controlCases, packControlBody)
}

await stage(8, "parameter pack, crashing tuple, no task group") {
    try await packDrive([crashingCases[0]], packBody)
}

await stage(9, "parameter pack across a resilient module boundary, crashing tuple") {
    try await packDriveAcrossModules(crashingCases, packBody)
}

await stage(10, "parameter pack across a resilient module boundary, control tuple") {
    try await packDriveAcrossModules(controlCases, packControlBody)
}

await stage(11, "parameter pack across a resilient module boundary, serially, crashing tuple") {
    try await packDriveAcrossModulesSerially(crashingCases, packBody)
}

await stage(12, "tuple of two generic parameters across a module boundary, crashing tuple") {
    try await tupleDriveAcrossModules(crashingCases, body)
}

await stage(13, "tuple of two generic parameters across a module boundary, control tuple") {
    try await tupleDriveAcrossModules(controlCases, controlBody)
}

await stage(14, "tuple of two generic parameters, serially, crashing tuple") {
    try await tupleDriveAcrossModulesSerially(crashingCases, body)
}

// Stages 15 and 16 replicate the `@Test` macro expansion itself, read out of
// `macro-expansions.txt` rather than remembered: a `@Sendable private static func` on the suite
// type, wrapping a nested `@Sendable func` that carries an `isolated (any Actor)?` parameter with a
// default value, whose body goes through `__requiringAwait`-style `@autoclosure` helpers.

@_transparent func requiringAwait<T>(_ value: @autoclosure () async throws -> T) async rethrows -> T {
    try await value()
}

@globalActor actor DefaultIsolation {
    static let shared = DefaultIsolation()
}

struct SuiteLikeCrashing: Sendable {
    func run(_ f: Crashing) { precondition(!f.0.isEmpty) }

    @Sendable static func expansion(_ arg0: Crashing) async throws -> Void {
        @Sendable func local(
            _ arg0: Crashing,
            _: isolated (any Actor)? = DefaultIsolation.shared
        ) async throws {
            let suite = try await requiringAwait(SuiteLikeCrashing())
            _ = try await requiringAwait(suite.run(arg0))
        }
        try await local(arg0)
    }
}

struct SuiteLikeControl: Sendable {
    func run(_ f: Control) { precondition(f.0 != f.1) }

    @Sendable static func expansion(_ arg0: Control) async throws -> Void {
        @Sendable func local(
            _ arg0: Control,
            _: isolated (any Actor)? = DefaultIsolation.shared
        ) async throws {
            let suite = try await requiringAwait(SuiteLikeControl())
            _ = try await requiringAwait(suite.run(arg0))
        }
        try await local(arg0)
    }
}

await stage(15, "the full macro-expansion shape, crashing tuple") {
    try await tupleDriveAcrossModules(crashingCases, SuiteLikeCrashing.expansion)
}

await stage(16, "the full macro-expansion shape, control tuple") {
    try await tupleDriveAcrossModules(controlCases, SuiteLikeControl.expansion)
}

// Stage 15 crashes, so the ingredient is somewhere in what it added over stage 12: a static method
// on a struct, a nested `@Sendable func` with an `isolated (any Actor)?` parameter carrying a
// default, and `@autoclosure` helpers. Stages 17 to 22 remove one at a time.

/// Stage 15 minus the `isolated` parameter.
@Sendable func noIsolatedParameter(_ arg0: Crashing) async throws {
    @Sendable func local(_ arg0: Crashing) async throws {
        let suite = try await requiringAwait(SuiteLikeCrashing())
        _ = try await requiringAwait(suite.run(arg0))
    }
    try await local(arg0)
}

/// Stage 15 minus the `@autoclosure` helpers.
@Sendable func noAutoclosure(_ arg0: Crashing) async throws {
    @Sendable func local(
        _ arg0: Crashing,
        _: isolated (any Actor)? = DefaultIsolation.shared
    ) async throws {
        let suite = SuiteLikeCrashing()
        suite.run(arg0)
    }
    try await local(arg0)
}

/// Stage 15 minus everything except the nested `@Sendable func` with an `isolated` parameter.
@Sendable func isolatedParameterOnly(_ arg0: Crashing) async throws {
    @Sendable func local(
        _ arg0: Crashing,
        _: isolated (any Actor)? = DefaultIsolation.shared
    ) async throws {
        precondition(!arg0.0.isEmpty)
    }
    try await local(arg0)
}

/// The same with the control tuple, so the element type is still the only thing that varies.
@Sendable func isolatedParameterOnlyControl(_ arg0: Control) async throws {
    @Sendable func local(
        _ arg0: Control,
        _: isolated (any Actor)? = DefaultIsolation.shared
    ) async throws {
        precondition(arg0.0 != arg0.1)
    }
    try await local(arg0)
}

await stage(17, "stage 15 minus the isolated parameter") {
    try await tupleDriveAcrossModules(crashingCases, noIsolatedParameter)
}

await stage(18, "stage 15 minus the autoclosure helpers") {
    try await tupleDriveAcrossModules(crashingCases, noAutoclosure)
}

await stage(19, "nested func with an isolated parameter, through the driver, crashing tuple") {
    try await tupleDriveAcrossModules(crashingCases, isolatedParameterOnly)
}

await stage(20, "nested func with an isolated parameter, through the driver, control tuple") {
    try await tupleDriveAcrossModules(controlCases, isolatedParameterOnlyControl)
}

await stage(21, "nested func with an isolated parameter, called directly, crashing tuple") {
    for c in crashingCases { try await isolatedParameterOnly(c) }
}

await stage(22, "nested func with an isolated parameter, called directly, control tuple") {
    for c in controlCases { try await isolatedParameterOnlyControl(c) }
}

print("all requested stages finished")
