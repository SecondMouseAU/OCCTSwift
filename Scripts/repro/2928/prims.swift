import Foundation

// Which of the primitives `Package.swift` names as the reason for the five whole-target exclusions
// actually fail to COMPILE for wasm32-unknown-wasip1? One case per -D so one failure does not mask
// the rest.

#if P_NSLOCK
    func pNSLock() {
        let l = NSLock()
        l.lock()
        l.unlock()
    }
#endif

#if P_DISPATCHQUEUE
    func pDispatchQueue() { DispatchQueue.global().async {} }
#endif

#if P_DISPATCHGROUP
    func pDispatchGroup() {
        let g = DispatchGroup()
        g.enter()
        g.leave()
        g.wait()
    }
#endif

#if P_DISPATCHSEMAPHORE
    func pDispatchSemaphore() {
        let s = DispatchSemaphore(value: 0)
        _ = s.wait(timeout: .now() + 1)
    }
#endif

#if P_PROCESSINFO
    func pProcessInfo() -> Int { ProcessInfo.processInfo.activeProcessorCount }
#endif

#if P_AUTORELEASEPOOL
    func pAutoreleasepool() { autoreleasepool { _ = 1 } }
#endif

#if P_TASKGROUP
    func pTaskGroup() async {
        await withTaskGroup(of: Int.self) { group in
            group.addTask { 1 }
            for await _ in group {}
        }
    }
#endif

#if P_THREAD
    func pThread() { Thread.sleep(forTimeInterval: 0.01) }
#endif
