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
    }

    @Test func singleSample() {
        let params = LogSample.sample(from: 1, to: 10, count: 1)
        #expect(params.count == 1)
    }
}

