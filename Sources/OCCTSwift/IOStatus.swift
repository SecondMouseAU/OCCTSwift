//
//  IOStatus.swift
//  OCCTSwift
//
//  #1644: OCCT's IFSelect_ReturnStatus, surfaced instead of collapsed to a Bool.
//

import OCCTBridge

/// Why a STEP or IGES read, transfer or write step ended the way it did.
///
/// This is OCCT's own `IFSelect_ReturnStatus`, the five-valued answer every data-exchange step
/// gives, plus one OCCTSwift value for a call that failed before OCCT produced a status at all.
/// Until #1644 the bridge compared it to `IFSelect_RetDone` and discarded the rest, so a missing
/// file, a malformed file and an empty model all reached Swift as the same `nil`.
///
/// The case names are OCCT's, not a translation: `error` and `fail` are near-synonyms in English
/// and are a real distinction here, so renaming them would invent a meaning the kernel does not
/// have. ``description`` carries the plain-English reading.
///
/// ```swift
/// do {
///     let shape = try Shape.loadSTEP(fromPath: path)
///     print(shape.volume)
/// } catch ImportError.readFailed(let path, .error) {
///     print("\(path) is not a STEP file")          // bad input, check the file
/// } catch ImportError.readFailed(let path, .void) {
///     print("\(path) parsed but holds nothing")    // empty model, not a broken file
/// } catch ImportError.readFailed(let path, let status) {
///     print("\(path): \(status)")
/// }
/// ```
public enum IOStatus: Int32, Sendable, CaseIterable {

    /// The call failed before OCCT produced a status: a rejected argument, a null handle, or a
    /// C++ exception the bridge caught. Not one of `IFSelect_ReturnStatus`' own values.
    case notReached = -1

    /// `IFSelect_RetVoid`: nothing to do. The step ran and found no content, an empty model.
    case void = 0

    /// `IFSelect_RetDone`: success.
    case done = 1

    /// `IFSelect_RetError`: bad input. The file is not what it claims to be.
    case error = 2

    /// `IFSelect_RetFail`: the step ran and failed.
    case fail = 3

    /// `IFSelect_RetStop`: interrupted.
    case stop = 4

    /// Maps a bridge status, defaulting to ``notReached`` for a value the kernel has grown since
    /// this enum was written rather than trapping on it.
    init(_ bridge: OCCTReturnStatus) {
        self = IOStatus(rawValue: Int32(bridge.rawValue)) ?? .notReached
    }
}

extension IOStatus: CustomStringConvertible {

    /// A short phrase naming the OCCT constant and what it means.
    ///
    /// ```swift
    /// print(IOStatus.error)   // IFSelect_RetError: bad input, the file is not what it claims to be
    /// ```
    public var description: String {
        switch self {
        case .notReached:
            return "no OCCT status: the call failed before the data-exchange step ran"
        case .void:
            return "IFSelect_RetVoid: nothing to do, the model is empty"
        case .done:
            return "IFSelect_RetDone: success"
        case .error:
            return "IFSelect_RetError: bad input, the file is not what it claims to be"
        case .fail:
            return "IFSelect_RetFail: the step ran and failed"
        case .stop:
            return "IFSelect_RetStop: interrupted"
        }
    }
}
