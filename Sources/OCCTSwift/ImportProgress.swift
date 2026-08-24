// Copyright (c) gsdali. Licensed under LGPL 2.1.
//
// Wraps OCCT's Message_ProgressIndicator into a Swift protocol so callers of
// loadSTEP / loadIGES can subscribe to progress updates and cooperatively
// cancel long-running imports.
//
// Driver: issue #98 / OCCTSwiftTools' CADFileLoader.load(from:format:) async
// API needs a progress + cancel channel for GUI consumers.

import Foundation
import OCCTBridge

/// Progress + cancellation channel for long-running OCCT import operations.
///
/// Pass an `ImportProgress` to the `progress:` parameter on `Shape.load(from:)`,
/// `Shape.loadSTEP(from:unitInMeters:)`, `Shape.loadIGES(from:)`,
/// `Shape.loadIGESRobust(from:)`, `Document.load(from:)`, and
/// `Document.loadSTEP(from:modes:)` to receive progress callbacks during the
/// reader's `TransferRoots` phase, and to request cooperative cancellation.
///
/// `progress(fraction:step:)` is called on whatever thread the import runs on
/// — typically the calling thread for synchronous loaders, or the executor of
/// a `Task.detached`. UI updates should hop to the main actor.
///
/// `shouldCancel()` is polled at OCCT's progress-checkpoint boundaries
/// (typically once per transferred entity in STEP/IGES). Returning `true` aborts
/// the in-flight import; the loader throws `ImportError.cancelled`.
///
/// ## What a cancelled call reports
///
/// One `true` is enough, and it is remembered: the answer is not re-asked into a different
/// outcome by the polls that follow, so a one-shot flag or an already-consumed
/// `Task.isCancelled` works as a canceller.
///
/// A cancelled call always throws `ImportError.cancelled` (`ExportError.cancelled` for the
/// exporters), whichever phase the cancellation lands in — a break during a STEP transfer
/// leaves the reader reporting zero transferred roots, which the bridge used to pass on as
/// `ImportError.importFailed` for an import the caller had explicitly stopped (#525).
///
/// ```swift
/// final class Cancel: ImportProgress, @unchecked Sendable {
///     private let flag = NSLock()
///     private var stop = false
///     func cancel() { flag.lock(); stop = true; flag.unlock() }
///     func progress(fraction: Double, step: String) {}
///     func shouldCancel() -> Bool { flag.lock(); defer { flag.unlock() }; return stop }
/// }
///
/// let canceller = Cancel()
/// do {
///     let shape = try Shape.loadRobust(from: stepURL, progress: canceller)
///     print(shape.faceCount)
/// } catch ImportError.cancelled {
///     print("stopped")   // never .importFailed, whichever phase was running
/// }
/// ```
public protocol ImportProgress: AnyObject, Sendable {
    /// Called as the importer advances. `fraction` is `0.0...1.0`. `step` is a
    /// human-readable name of the current sub-task (may be empty).
    func progress(fraction: Double, step: String)

    /// Return `true` to cooperatively cancel the in-flight import. Polled at
    /// each progress checkpoint. The loader throws `ImportError.cancelled` on
    /// the next boundary after this returns `true`, and later polls returning
    /// `false` do not undo that.
    func shouldCancel() -> Bool
}

/// Default no-op cancellation. Callers can adopt `ImportProgress` and only
/// implement `progress(fraction:step:)` to get a progress-only channel.
extension ImportProgress {
    public func shouldCancel() -> Bool { false }
}

// MARK: - Bridge plumbing

/// Box that holds an `ImportProgress` reference at a stable address so the C
/// callback can recover it from `userData`.
private final class ImportProgressBox {
    let progress: ImportProgress
    init(_ progress: ImportProgress) { self.progress = progress }
}

/// Run `body` with an `OCCTImportProgress*` pointing to a struct that forwards
/// to the given Swift `ImportProgress`.
///
/// The pointer is valid only for the duration of `body`. Pass nil if `progress` is nil.
internal func withImportProgress<T>(
    _ progress: ImportProgress?,
    _ body: (UnsafePointer<OCCTImportProgress>?) -> T
) -> T {
    guard let progress else {
        return body(nil)
    }
    let box = ImportProgressBox(progress)
    let userData = Unmanaged.passUnretained(box).toOpaque()
    var ctx = OCCTImportProgress(
        onProgress: { fraction, step, userData in
            guard let userData else { return }
            let box = Unmanaged<ImportProgressBox>.fromOpaque(userData).takeUnretainedValue()
            let stepStr = step.map { String(cString: $0) } ?? ""
            box.progress.progress(fraction: fraction, step: stepStr)
        },
        shouldCancel: { userData in
            guard let userData else { return false }
            let box = Unmanaged<ImportProgressBox>.fromOpaque(userData).takeUnretainedValue()
            return box.progress.shouldCancel()
        },
        userData: userData
    )
    return withExtendedLifetime(box) {
        withUnsafePointer(to: &ctx) { body($0) }
    }
}
