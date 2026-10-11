import Foundation
import Testing

@testable import OCCTSwift

// Issue #1404: TObj_Application::GetInstance() is a process-wide singleton whose lazy-init is
// thread-safe (a C++11 function-local static) but whose own two fields were not synchronized by
// anything, in the kernel or in the bridge.
//
// A. myIsVerbose, reached by isVerbose's getter and setter, is a plain unguarded bool.
// B. myIsError, reached by createDocument(). TObj_Application::CreateNewDocument writes
//    myIsError = false, calls NewDocument(), then returns !myIsError. Two concurrent calls can
//    each clear the other's in-flight error signal, so a failing createDocument() on one thread
//    can be reported as a success because a second thread reset the flag between the write and
//    the read.
//
// Distinct from #341/#344/#349/#353/#371/#374. Every one of those fixed a different class
// (XCAFApp_Application, CDF_Application, CDM_Application, Resource_Manager, Storage_Schema), and
// all of their fixes ship in the pinned kernel as patches 0012/0014/0015/0016. Those cover the
// machinery NewDocument() calls into; TObj_Application's own two fields sit one layer above it.
//
// Fixed bridge-side with tobjApplicationMutex() rather than a carried kernel patch: the class has
// no lock of its own, the API is niche, and upstream has no PR touching TObj_Application (checked
// against Open-Cascade-SAS/OCCT before the fix, per CLAUDE.md's "check upstream first" step).
//
// As with #341/#359/#361's equivalent suites, the concurrent tests here are exercisers through the
// Swift API: they confirm no deadlock, no crash and no functional regression. They are NOT the
// authoritative verification for a data race, which is ThreadSanitizer's job
// (Scripts/tsan-stress.sh). The single-threaded test IS authoritative for its own claim, since
// round-tripping a value through the shared singleton is deterministic rather than a race.
// `.serialized` is load-bearing, not decoration. Every test here mutates the SAME process-wide
// TObj_Application, which is the whole point of the issue, so running them in parallel (Swift
// Testing's default) means they fight each other: the round-trip test asserts that a value it just
// set reads back, while a sibling test is concurrently setting the same field to something else.
// Measured before adding this: the suite failed 1 run in 2 on exactly that assertion. That failure
// is the tests colliding, not the lock failing, and without `.serialized` it would have been a
// permanent flake blamed on the fix.
@Suite("Issue #1404, TObj_Application's own singleton fields are serialized", .serialized)
struct Issue1404TObjApplicationThreadSafetyTests {

    @Test("isVerbose round-trips through the shared singleton")
    func verboseRoundTripsSingleThreaded() throws {
        let app = try #require(TObjApplication.shared)
        let original = app.isVerbose
        defer { app.isVerbose = original }

        app.isVerbose = true
        #expect(app.isVerbose, "the setter must be visible to the getter on the same instance")

        app.isVerbose = false
        #expect(!app.isVerbose)

        // Every .shared is a wrapper around the same underlying TObj_Application, so a write
        // through one instance must be visible through another. This is the property that makes
        // the field shared state rather than per-wrapper state, and therefore a race at all.
        let second = try #require(TObjApplication.shared)
        app.isVerbose = true
        #expect(second.isVerbose, ".shared must wrap the same process-wide singleton")
    }

    @Test("Concurrent isVerbose get/set doesn't crash or deadlock")
    func concurrentVerboseAccessSucceeds() async throws {
        let original = TObjApplication.shared?.isVerbose ?? false
        defer { TObjApplication.shared?.isVerbose = original }

        await withTaskGroup(of: Void.self) { group in
            for taskIndex in 0..<8 {
                group.addTask {
                    for i in 0..<50 {
                        guard let app = TObjApplication.shared else { continue }
                        // Deliberately interleave writes and reads of the shared bool. The value
                        // read back is not asserted on: with eight writers the last write wins and
                        // any of them is a legitimate answer. What is under test is that the
                        // access is serialized, not what it returns.
                        app.isVerbose = (taskIndex + i) % 2 == 0
                        _ = app.isVerbose
                    }
                }
            }
        }
    }

    @Test("Concurrent createDocument() reports success honestly and doesn't deadlock")
    func concurrentCreateDocumentSucceeds() async throws {
        // createDocument() returns nil when CreateNewDocument reports failure via myIsError.
        // Every call here is a valid BinOcaf creation that should succeed, so any nil is either a
        // real failure or the myIsError race reporting one thread's state on another's call.
        let created = await withTaskGroup(of: Int.self) { group -> Int in
            for _ in 0..<8 {
                group.addTask {
                    var ok = 0
                    for _ in 0..<10 {
                        guard let app = TObjApplication.shared else { continue }
                        if app.createDocument() != nil { ok += 1 }
                    }
                    return ok
                }
            }
            var total = 0
            for await ok in group { total += ok }
            return total
        }

        #expect(created == 80, "every concurrent createDocument() should succeed (got \(created))")
    }

    @Test("Concurrent createDocument() and isVerbose together don't deadlock")
    func concurrentMixedAccessSucceeds() async throws {
        let original = TObjApplication.shared?.isVerbose ?? false
        defer { TObjApplication.shared?.isVerbose = original }

        // Both entry points take the same lock, and createDocument() holds it across the whole
        // CreateNewDocument call. Mixing them is what would surface a lock-ordering mistake or a
        // non-reentrancy problem if the lock were ever made recursive or taken twice.
        await withTaskGroup(of: Void.self) { group in
            for taskIndex in 0..<8 {
                group.addTask {
                    for i in 0..<10 {
                        guard let app = TObjApplication.shared else { continue }
                        if (taskIndex + i) % 2 == 0 {
                            _ = app.createDocument()
                        } else {
                            app.isVerbose = i % 2 == 0
                            _ = app.isVerbose
                        }
                    }
                }
            }
        }
    }
}
