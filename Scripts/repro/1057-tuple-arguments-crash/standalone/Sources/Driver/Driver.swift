// #1057, stage 9 onward: the generic parameter-pack driver, in its own module.
//
// Stages 6 to 8 kept the driver in the same file as its caller, so the optimiser could specialise
// the pack expansion away. swift-testing's `Test.Case.Generator` lives in a different module
// (Testing.framework), built with library evolution, so the expansion the caller reaches is the
// unspecialised one. This module is that boundary.

/// Same shape as `Testing.Test.Case.Generator.init<each T>(sequence:parameters:testFunction:)`:
/// generic over a parameter pack whose tuple is the sequence element, calling the function by
/// expanding the tuple back into the pack.
public func packDriveAcrossModules<each T: Sendable>(
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

/// The same, serially, so a crash can be attributed to the expansion rather than to the group.
public func packDriveAcrossModulesSerially<each T: Sendable>(
    _ elements: [(repeat each T)],
    _ f: @escaping @Sendable (repeat each T) async throws -> Void
) async throws {
    for e in elements {
        try await f(repeat each e)
    }
}

// The parameter-pack shape above is not what swift-testing actually declares. Read from
// `Testing.framework`'s own `arm64-apple-macos.swiftinterface`, the overload a one-collection
// tuple-element test selects is:
//
//   static func __function<C, E1, E2>(
//     ..., arguments collection: @escaping @Sendable () async throws -> C, ...,
//     testFunction: @escaping @Sendable ((E1, E2)) async throws -> Void
//   ) -> Test where C: Collection & Sendable, E1: Sendable, E2: Sendable, C.Element == (E1, E2)
//
// So the callee's parameter is a **tuple of two abstract generic parameters**, and the caller's
// concrete function has to be reabstracted into it. That is the shape below.

/// Matches `Test.__function<C, E1, E2>`: the element is a tuple of two generic parameters, and the
/// function takes that whole tuple as its single argument.
public func tupleDriveAcrossModules<C, E1, E2>(
    _ collection: C,
    _ f: @escaping @Sendable ((E1, E2)) async throws -> Void
) async throws where C: Collection & Sendable, E1: Sendable, E2: Sendable, C.Element == (E1, E2) {
    try await withThrowingTaskGroup(of: Void.self) { group in
        for e in collection {
            group.addTask { try await f(e) }
        }
        try await group.waitForAll()
    }
}

/// The same, serially.
public func tupleDriveAcrossModulesSerially<C, E1, E2>(
    _ collection: C,
    _ f: @escaping @Sendable ((E1, E2)) async throws -> Void
) async throws where C: Collection & Sendable, E1: Sendable, E2: Sendable, C.Element == (E1, E2) {
    for e in collection {
        try await f(e)
    }
}
