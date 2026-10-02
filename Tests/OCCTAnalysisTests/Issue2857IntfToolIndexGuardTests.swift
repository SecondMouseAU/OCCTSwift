import Foundation
import Testing
import simd

@testable import OCCTSwift

//
//  Issue2857IntfToolIndexGuardTests.swift
//  #2857: IntfTool.beginParam / endParam refuse an out-of-range segment index, and
//  IntfTool.segmentCount exists so a caller can stay inside the valid range.
//
//  Intf_Tool::BeginParam and EndParam index beginOnCurve and endOnCurve, raw double[6] members
//  (Intf_Tool.hxx:78-79), behind a Standard_OutOfRange_Raise_if that sits in Intf_Tool.cxx and is
//  therefore absent from the kernel this package links, per
//  okf/policies/occt-validation-is-compiled-out.md. A C array has no container beneath it, so unlike
//  the NCollection cases there was no inline check to survive at any depth.
//
//  The index to look at twice is 7, and it is why this suite asserts a refusal rather than the
//  absence of a crash. Measured on a clip with NbSegments() == 1 (Scripts/repro/2801-sweep-index/,
//  against the pinned v4.0.0-kernel.2 asset): beginParam(segment: 7) returned 11, which is
//  endOnCurve[0], the genuine END parameter of segment 1, handed back as the BEGIN parameter of a
//  segment that does not exist. A plausible number, in the right units, from the right object, and
//  wrong. Index 6 returned 0.0, inside the array but past nbSeg; index 1000000000 was a SIGBUS and
//  -1000000000 a SIGSEGV. So the same call fabricated for a small out-of-range index and faulted for
//  a large one, and only the second would have been caught by a crash-shaped test.
//
@Suite("#2857 IntfTool segment index guard")
struct Issue2857IntfToolIndexGuardTests {

    /// A line along +X through the middle of the unit box, the clip the transcript in #2857 used:
    /// it produces exactly one segment, with begin 10 and end 11.
    private func clippedTool() -> IntfTool {
        let tool = IntfTool()
        tool.clipLineToBox(
            lineOrigin: SIMD3(-10, 0.5, 0.5),
            lineDirection: SIMD3(1, 0, 0),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(1, 1, 1))
        return tool
    }

    @Test("segmentCount reports the bound the documented 1-based index is checked against")
    func segmentCountReportsTheBound() {
        // Intf_Tool::NbSegments() had no wrapper at all before #2857, which is why a caller could
        // not know that 7 was out of range. A fresh tool has clipped nothing.
        #expect(IntfTool().segmentCount == 0)

        let tool = clippedTool()
        #expect(tool.segmentCount == 1)

        // And a line that misses the box entirely clips to nothing, so every index is invalid.
        let miss = IntfTool()
        let n = miss.clipLineToBox(
            lineOrigin: SIMD3(100, 100, 100),
            lineDirection: SIMD3(0, 1, 0),
            boxMin: SIMD3(0, 0, 0),
            boxMax: SIMD3(1, 1, 1))
        #expect(miss.segmentCount == n)
        #expect(miss.beginParam(segment: 1) == nil)
        #expect(miss.endParam(segment: 1) == nil)
    }

    @Test("beginParam and endParam return the real parameters for the one valid index")
    func validIndexStillMeasures() {
        // The other half of the guard: refusing 7 is only correct if 1 still answers.
        let tool = clippedTool()
        guard let begin = tool.beginParam(segment: 1), let end = tool.endParam(segment: 1) else {
            Issue.record("segment 1 was refused after a clip that produced one segment")
            return
        }
        #expect(abs(begin - 10.0) < 1e-9, "begin was \(begin)")
        #expect(abs(end - 11.0) < 1e-9, "end was \(end)")
        #expect(end > begin)
    }

    @Test("beginParam(segment: 7) is refused rather than returning endOnCurve[0]")
    func indexSevenIsRefusedRatherThanFabricated() {
        // The single most important assertion in this file. Before the guard this returned 11.0,
        // which is the value endParam(segment: 1) correctly returns, so the two calls agreed on a
        // number that described different things. Asserting `!= 11.0` would pass for the wrong
        // reason if the fabricated slot ever changed; asserting nil is the contract.
        let tool = clippedTool()
        #expect(tool.segmentCount == 1)
        #expect(tool.beginParam(segment: 7) == nil)
        #expect(tool.endParam(segment: 7) == nil)
    }

    @Test("every out-of-range index is refused, inside the double[6] and far outside it")
    func everyOutOfRangeIndexIsRefused() {
        // One test walking a list rather than @Test(arguments:), which is the house rule wherever a
        // case element could pair a reference-counted member with a builtin vector of 32 bytes or
        // more (swiftlang/swift#91639, #1057). Plain Ints here, and kept as a list so the shape does
        // not invite a String or SIMD3 case later.
        let tool = clippedTool()
        #expect(tool.segmentCount == 1)
        var badIndices: [Int] = [
            0,  // beginOnCurve[-1]: measured 4.24399e-314
            2,  // past nbSeg, still inside the array
            6,  // last slot of the double[6]: measured 0.0
            7,  // one past the array: measured 11, i.e. endOnCurve[0]
            100_000_000,  // measured -5.38862e-110
            1_000_000_000,  // measured SIGBUS
            -1_000_000_000,  // measured SIGSEGV
            Int(Int32.min) + 1,  // SegmentNum - 1 is itself a signed overflow: measured SIGSEGV
            Int(Int32.max),
            Int.min,
            Int.max,
        ]
        // Beyond int32_t entirely, so the wrapper has to refuse rather than trap converting. The
        // case is ABSENT rather than skipped where `Int` is 32 bits (wasm32), because there is no
        // such `Int` there: `Int.max` IS `Int32.max`, two entries above already cover the largest
        // index the platform can express, and `Int(Int32.max) + 1` would overflow on evaluation
        // (#2928). Appended rather than written into the literal so nothing about the 64-bit list
        // changes.
        if Int.bitWidth > 32 { badIndices.append(Int(Int32.max) + 1) }
        for index in badIndices {
            #expect(
                tool.beginParam(segment: index) == nil, "beginParam(segment: \(index)) returned")
            #expect(tool.endParam(segment: index) == nil, "endParam(segment: \(index)) returned")
        }
        // The refusals left the tool usable.
        #expect(tool.beginParam(segment: 1) != nil)
    }

    @Test("asking for a parameter before any clip is refused rather than reading a memset zero")
    func unclippedToolRefusesEveryIndex() {
        // Intf_Tool's constructor memsets all seven member arrays, so an unclipped tool used to
        // return a clean 0.0 for any index: a legitimate-looking curve parameter for a clip that
        // never happened. segmentCount is 0, so every index is now out of range.
        let tool = IntfTool()
        #expect(tool.segmentCount == 0)
        for index in [0, 1, 2, 6, 7] {
            #expect(tool.beginParam(segment: index) == nil)
            #expect(tool.endParam(segment: index) == nil)
        }
    }
}
