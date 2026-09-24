import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomLib_LogSample Tests")
struct LogSampleTests {

    @Test func logarithmicSampling() {
        let params = LogSample.sample(from: 1, to: 100, count: 5)
        #expect(params.count == 5)
        // Should be monotonically increasing
        for i in 1..<params.count {
            #expect(params[i] > params[i - 1])
        }
        // Monotonic is not logarithmic: evenly spaced values pass the loop above. These are
        // GeomLib_LogSample(1, 100, 5)'s own values, Scripts/repro/766-math-line-logsample-crout.
        let kernel = [1.0, 6.2842590296848586, 15.75364725297846, 39.491911552175686, 100.0]
        for (got, want) in zip(params, kernel) {
            #expect(abs(got - want) < 1e-9)
        }
    }

    @Test func singleSample() {
        let params = LogSample.sample(from: 1, to: 10, count: 1)
        #expect(params.count == 1)
        // The count is fixed by the Swift wrapper before the bridge runs, so it cannot see a
        // wrong sample. GeomLib_LogSample(1, 10, 1) yields the lower bound.
        if let p = params.first { #expect(abs(p - 1.0) < 1e-12) }
    }
}

