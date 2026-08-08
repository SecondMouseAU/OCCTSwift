import Testing
import Foundation
@testable import OCCTSwift

/// #784 removed `ThreadBuild.boolean`. `ThreadBuild` is `Codable` with no raw type, so Swift's
/// synthesized encoding is case-keyed (`{"auto":{}}`, `{"direct":{}}`, and, before this release,
/// `{"boolean":{}}`). Removing the case is a source-level compile error for any caller naming
/// `.boolean` in code, which the rest of #784's migration guide covers, but it is a *silent*
/// decode failure for any already-persisted `ThreadBuild.boolean` value (a saved project file, a
/// user-defaults entry, anything a host app wrote while the case still existed): nothing here
/// prevents that from compiling, and without a fix `JSONDecoder` throws `DecodingError` the first
/// time it meets the old payload.
///
/// `ThreadBuild` now carries a custom `init(from:)` that recognises the retired `"boolean"` key
/// and maps it to `.direct` (the value every buildable thread already resolved `.boolean` to
/// before the case was removed, per #254). These tests pin that decode path directly, against a
/// literal legacy payload, not against a value this build can even construct.
@Suite("Issue #784: ThreadBuild.boolean removal stays decodable")
struct Issue784ThreadBuildCodableCompatTests {

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    @Test("A legacy {\"boolean\":{}} payload decodes as .direct")
    func legacyBooleanDecodesAsDirect() throws {
        let legacy = Data("{\"boolean\":{}}".utf8)
        let decoded = try Self.decoder.decode(ThreadBuild.self, from: legacy)
        #expect(decoded == .direct)
    }

    @Test("A legacy payload nested in a container field decodes the same way")
    func legacyBooleanDecodesInsideAWrapper() throws {
        struct SavedChoice: Codable { let build: ThreadBuild }
        let legacy = Data("{\"build\":{\"boolean\":{}}}".utf8)
        let decoded = try Self.decoder.decode(SavedChoice.self, from: legacy)
        #expect(decoded.build == .direct)
    }

    @Test("The surviving cases still round-trip through encode/decode")
    func survivingCasesRoundTrip() throws {
        for value: ThreadBuild in [.auto, .direct] {
            let data = try Self.encoder.encode(value)
            let decoded = try Self.decoder.decode(ThreadBuild.self, from: data)
            #expect(decoded == value, "\(value) failed to round-trip")
        }
    }

    @Test("Encoding never reproduces the retired boolean key")
    func encodingNeverEmitsBoolean() throws {
        for value: ThreadBuild in [.auto, .direct] {
            let data = try Self.encoder.encode(value)
            let text = String(decoding: data, as: UTF8.self)
            #expect(!text.contains("boolean"), "encode(\(value)) unexpectedly wrote \"boolean\": \(text)")
        }
    }

    @Test("An unrecognised key is still rejected, not silently mapped")
    func unknownKeyStillFails() {
        let garbage = Data("{\"notARealCase\":{}}".utf8)
        #expect(throws: (any Error).self) {
            try Self.decoder.decode(ThreadBuild.self, from: garbage)
        }
    }
}

// MARK: - Prove the test fails (okf/policies/prove-the-test-fails.md)
//
// Two injections against `ThreadBuild.init(from:)` in `Sources/OCCTSwift/ThreadFeatures.swift`,
// each run, confirmed to fail, then reverted:
//
// 1. Replaced `if container.contains(.boolean)` with `if false`, disabling legacy recognition.
//    `legacyBooleanDecodesAsDirect` and `legacyBooleanDecodesInsideAWrapper` both failed with
//    `DecodingError.dataCorrupted("... expected one of \"auto\", \"direct\" or the retired
//    \"boolean\"")`, the exact production failure this fix exists to prevent. The other three
//    tests in this file were unaffected, since none of them decode a `"boolean"` payload.
// 2. Replaced the final `else { throw ... }` with `self = .auto`, so an unrecognised key silently
//    defaults instead of failing. `unknownKeyStillFails` failed ("an error was expected but none
//    was thrown and \"auto\" was returned"); the other four tests were unaffected.
//
// All 5 tests were green again after each injection was reverted.
