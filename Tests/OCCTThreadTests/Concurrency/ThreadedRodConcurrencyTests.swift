import Foundation
import Testing

@testable import OCCTSwift

@Suite("TMPSTRESS threaded rod concurrency")
struct TmpStressThreadedRodConcurrencyTests {
    @Test("TMPSTRESS concurrent threadedShaft")
    func stress() async {
        let pitches = [1.0, 1.25, 1.5, 1.75, 0.8, 2.0]
        let built = await withTaskGroup(of: Int.self) { group -> Int in
            for i in 0..<24 {
                group.addTask {
                    var n = 0
                    for _ in 0..<4 {
                        guard let blank = Shape.cylinder(radius: 6, height: 18) else { continue }
                        let spec = ThreadSpec(
                            form: .iso68, nominalDiameter: 12, pitch: pitches[i % pitches.count])
                        if blank.threadedShaft(
                            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec,
                            length: 16) != nil
                        {
                            n += 1
                        }
                    }
                    return n
                }
            }
            var total = 0
            for await n in group { total += n }
            return total
        }
        #expect(built > 0)
    }
}
