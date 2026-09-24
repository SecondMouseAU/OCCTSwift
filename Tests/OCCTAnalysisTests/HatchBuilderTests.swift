import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Hatch Builder Tests")
struct HatchBuilderTests {

    @Test func createHatcher() {
        let hatcher = HatchBuilder(tolerance: 1e-6)
        #expect(hatcher != nil)
    }

    @Test func addLinesAndCount() {
        guard let hatcher = HatchBuilder(tolerance: 1e-6) else {
            Issue.record("a hatcher with tolerance 1e-6 builds")
            return
        }
        hatcher.addXLine(0.0)
        hatcher.addXLine(5.0)
        hatcher.addXLine(10.0)
        #expect(hatcher.nbLines == 3)
    }

    @Test func addYLines() {
        guard let hatcher = HatchBuilder(tolerance: 1e-6) else {
            Issue.record("a hatcher with tolerance 1e-6 builds")
            return
        }
        hatcher.addYLine(0.0)
        hatcher.addYLine(5.0)
        #expect(hatcher.nbLines == 2)
    }

    /// The hatcher is unoriented, so an interval needs a pair of crossings. A closed square
    /// from (-1, -1) to (11, 11) crosses each of the three vertical lines twice and leaves one
    /// interval on each; an untrimmed line has none. The earlier form trimmed with a single
    /// diagonal segment, one crossing per line and so zero intervals, and asserted `nInt >= 0`,
    /// which a `trim` that did nothing also satisfied (#766). Counts probed in
    /// `Scripts/repro/766-hatch-builder/transcript.txt`.
    @Test func trimAndIntervals() {
        guard let hatcher = HatchBuilder(tolerance: 1e-6) else {
            Issue.record("a hatcher with tolerance 1e-6 builds")
            return
        }
        hatcher.addXLine(0.0)
        hatcher.addXLine(5.0)
        hatcher.addXLine(10.0)
        #expect(hatcher.nbLines == 3)
        // Stop rather than ask for intervals on a line index the hatcher does not have.
        guard hatcher.nbLines == 3 else { return }
        for line in 1...3 {
            #expect(hatcher.nbIntervals(lineIndex: line) == 0, "line \(line) before trimming")
        }

        hatcher.trim(x1: -1, y1: -1, x2: 11, y2: -1)
        hatcher.trim(x1: 11, y1: -1, x2: 11, y2: 11)
        hatcher.trim(x1: 11, y1: 11, x2: -1, y2: 11)
        hatcher.trim(x1: -1, y1: 11, x2: -1, y2: -1)
        for line in 1...3 {
            #expect(hatcher.nbIntervals(lineIndex: line) == 1, "line \(line) inside the square")
        }
    }
}
