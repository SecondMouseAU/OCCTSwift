#if os(WASI)

    /// `autoreleasepool`, for a target with no Objective-C runtime to pool anything in.
    ///
    /// `wasm32-unknown-wasip1` has no Objective-C runtime, so Foundation does not declare
    /// `autoreleasepool` there and one call to it was the entire reason `OCCTMiscTests` was excluded
    /// from the wasm suites as a whole target: 6 files and 84 tests for one function (#2928,
    /// measured in `Scripts/repro/2928/`).
    ///
    /// **A no-op body is correct here rather than a weakening.** The one call site,
    /// `constructionContextDoesNotLeakAcrossDocuments` in `OCCTMiscTests.swift`, uses the pool to
    /// make a `Document` die at the end of each loop iteration so the next iteration is likely to
    /// reuse its address, which is what #277's defect needed. `Document` is a Swift class and the
    /// test holds no other reference, so ARC releases it at the end of the iteration's scope with or
    /// without a pool. What a pool adds on Apple is draining the autoreleased Objective-C temporaries
    /// the surrounding Foundation calls may make, and on this target there are none to drain.
    ///
    /// Shadowing a Foundation name is deliberate and cannot collide: the declaration exists only
    /// where Foundation does not provide one, and only inside this test target.
    func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result {
        try body()
    }

#endif
