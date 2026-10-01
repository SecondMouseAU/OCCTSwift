// #2897: the two excluded suites, replayed body for body through the shipped bridge and the
// shipped Swift wrapper.
//
// probe.cpp replays the same sequence against the kernel archive alone and shows the mechanism in
// isolation. This one is the fidelity check: it performs exactly what `TObjApplicationTests` and
// `Issue1588TObjApplicationReleaseTests` perform, in the same order, so a trap here is the test
// suite's trap and not a sequence invented to produce one.
//
// Pass an argument to pick an order: `1588-first` runs the release suite first.

import Foundation
import OCCTBridge
import OCCTSwift

func step(_ s: String) {
    print(s)
    fflush(stdout)
}

// --- TObjApplicationTests ---------------------------------------------------------------------

func getInstance() {
    step("TObjApplicationTests.getInstance")
    precondition(TObjApplication.shared != nil)
}

func verboseFlag() {
    step("TObjApplicationTests.verboseFlag")
    if let app = TObjApplication.shared {
        app.isVerbose = true
        precondition(app.isVerbose)
        app.isVerbose = false
        precondition(!app.isVerbose)
    }
}

func createDocument() {
    step("TObjApplicationTests.createDocument")
    if let app = TObjApplication.shared {
        print("   -> \(app.createDocument() == nil ? "nil" : "a document")")
    }
}

// --- Issue1588TObjApplicationReleaseTests -----------------------------------------------------

func singleGetReleaseRoundTrip() {
    step("Issue1588.singleGetReleaseRoundTrip")
    guard let app = OCCTTObjApplicationGetInstance() else { return }
    OCCTTObjApplicationRelease(app)
    guard let again = OCCTTObjApplicationGetInstance() else { return }
    OCCTTObjApplicationSetVerbose(again, true)
    precondition(OCCTTObjApplicationIsVerbose(again))
    OCCTTObjApplicationRelease(again)
}

func doubleReleaseDoesNotCorruptSingleton() {
    step("Issue1588.doubleReleaseDoesNotCorruptSingleton")
    guard let app = OCCTTObjApplicationGetInstance() else { return }
    OCCTTObjApplicationRelease(app)
    OCCTTObjApplicationRelease(app) // the unmatched one
    guard let again = OCCTTObjApplicationGetInstance() else { return }
    OCCTTObjApplicationSetVerbose(again, false)
    precondition(!OCCTTObjApplicationIsVerbose(again))
    let doc = OCCTTObjApplicationCreateDocument(again)
    print("   -> \(doc == nil ? "nil" : "a document")")
    if let doc { OCCTDocumentRelease(doc) }
    OCCTTObjApplicationRelease(again)
}

func repeatedGetReleaseCyclesDoNotCorruptSingleton() {
    step("Issue1588.repeatedGetReleaseCyclesDoNotCorruptSingleton")
    for i in 0..<500 {
        guard let app = OCCTTObjApplicationGetInstance() else { return }
        OCCTTObjApplicationSetVerbose(app, i % 2 == 0)
        OCCTTObjApplicationRelease(app)
    }
    guard let again = OCCTTObjApplicationGetInstance() else { return }
    if let doc = OCCTTObjApplicationCreateDocument(again) { OCCTDocumentRelease(doc) }
    OCCTTObjApplicationRelease(again)
}

func repeatedSharedAccessDoesNotCorruptSingleton() {
    step("Issue1588.repeatedSharedAccessDoesNotCorruptSingleton")
    for i in 0..<500 {
        guard let app = TObjApplication.shared else { return }
        app.isVerbose = (i % 2 == 0)
    }
    guard let app = TObjApplication.shared else { return }
    app.isVerbose = true
    precondition(app.isVerbose)
    print("   -> \(app.createDocument() == nil ? "nil" : "a document")")
}

// ------------------------------------------------------------------------------------------------

let releaseSuiteFirst = CommandLine.arguments.contains("1588-first")

let xcaf = [getInstance, verboseFlag, createDocument]
let release = [
    singleGetReleaseRoundTrip,
    doubleReleaseDoesNotCorruptSingleton,
    repeatedGetReleaseCyclesDoNotCorruptSingleton,
    repeatedSharedAccessDoesNotCorruptSingleton,
]

for test in releaseSuiteFirst ? release + xcaf : xcaf + release {
    test()
}

print("DONE (no trap)")
