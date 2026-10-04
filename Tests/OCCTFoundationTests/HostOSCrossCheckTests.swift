import Foundation
import Testing

@testable import OCCTSwift

// For the `getrusage`, `statvfs`, `getpwuid`, `gethostname` and `uname` below. Every suite here
// CROSS-CHECKS an OCCT reading against the host operating system's own answer, which is the second
// construction okf/policies/measure-dont-assume.md asks for, and the host's answer comes from the
// platform C library rather than from Foundation.
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

// The five `OSD_*` suites whose assertions are a comparison against the HOST OS, lifted out of
// `OCCTFoundationTests.swift` by #2928 so that the rest of that file can run for wasm.
//
// NONE IS PORTABLE TO `wasm32-unknown-wasip1` AND NONE SHOULD BE MADE PORTABLE. What makes them
// worth having is that each compares an OCCT reading against an independent one taken from the OS,
// and wasi-libc has no independent one to take:
//
//   `PerfMeterTests.measureTime` bounds `OSD_PerfMeter`'s reading between the process CPU time from
//   `getrusage(RUSAGE_SELF)` and this thread's from `clock_gettime_nsec_np`. wasi-libc has neither,
//   and `clock_gettime_nsec_np` is Darwin's alone.
//
//   `OSDDiskTests` compares `DiskInfo.size()` against `statvfs("/")`'s own block arithmetic exactly.
//   wasi-libc has no `statvfs`, and a WASI preopen is not a filesystem with blocks to report.
//
//   `OSDChronometerTests` brackets `CPUTime.processCPU()` with two `getrusage` readings.
//
//   `OSDProcessTests` reads the passwd entry for `getuid()`, and `OSDHostTests` reads
//   `gethostname(2)` and `uname(3)`. A wasm module has no passwd database, no hostname and no
//   `sysname`/`release` pair to compare against, and wasi-libc declares none of the three.
//
// `OSDProcessTests.processId` would build, since `getpid` is in wasi-libc, and it stays with its own
// suite rather than being split off for one test.
//
// Weakening any of these to `>= 0` or `!= nil` so that it builds here is exactly the assertion #1987
// removed from all five, and the version a bridge returning 0 passes.

@Suite("OSD_PerfMeter Tests")
struct PerfMeterTests {

    // #1987: this asserted `elapsed >= 0` after a 10,000-iteration loop, which a meter that never
    // started also satisfies. Two facts about OSD_PerfMeter shape the replacement
    // (Scripts/repro/766-foundation-osd-io):
    //
    //  - It reads CPU time, not wall time: a sleeping process reads 0.0000.
    //  - It reads the CPU summed over the process's LIVE threads, not the calling thread's. Other
    //    threads inflate a window (three others still running at Stop: 1.03 against 0.26 s of
    //    wall), and a thread that exits inside the window takes its whole CPU history out of the
    //    sum (four workers exited before Stop read 0.193 of the 0.800 s the process used; under
    //    thread churn single windows read as low as -1.17 s, and 72 of 150 fell below the
    //    thread's own CPU).
    //
    // A first version bounded the reading by wall time and failed on the CI runner (0.2156
    // against 0.2101), where thousands of other tests share the process. So both bounds are in
    // CPU time. The reading can never exceed the CPU the whole process used across the window,
    // however loaded, so that bound is checked on every window. The lower bound cannot hold in
    // every window, so it must hold in at least one of up to 20: the window spins until THIS
    // thread has used 0.1 s of CPU, which a live meter must then show. It costs one 0.1 s window
    // in the normal case; a meter that never started, or reports the wrong unit, fails them all.
    @Test func measureTime() {
        func processCPU() -> Double {
            var r = rusage()
            getrusage(RUSAGE_SELF, &r)
            return Double(r.ru_utime.tv_sec) + Double(r.ru_utime.tv_usec) * 1e-6
                + Double(r.ru_stime.tv_sec) + Double(r.ru_stime.tv_usec) * 1e-6
        }
        func threadCPU() -> Double {
            Double(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)) * 1e-9
        }
        var readOwnCPU = false
        var attempt = 0
        while !readOwnCPU && attempt < 20 {
            let cpuBefore = processCPU()
            let meter = PerfMeter(name: "swift_test_766_\(attempt)")
            let threadStart = threadCPU()
            var sum = 0.0
            while threadCPU() - threadStart < 0.1 {
                for i in 0..<1000 { sum += Double(i) }
            }
            meter.stop()
            let cpuAfter = processCPU()
            let elapsed = meter.elapsed
            #expect(sum > 0)
            #expect(elapsed <= cpuAfter - cpuBefore + 0.02)
            readOwnCPU = elapsed >= 0.09
            attempt += 1
        }
        #expect(readOwnCPU)
    }
}

@Suite("OSD_Disk")
struct OSDDiskTests {
    // #1987: `size >= 0` and `free >= 0` passed a bridge returning 0. OSD_Disk::DiskSize() is
    // f_blocks * (f_frsize / 512) 512-byte blocks, which the bridge halves to KB; total size does
    // not move between two reads, so it is compared exactly. Issue1442DiskUnicodeOSDUtilitiesTests
    // holds the finer regression coverage for #1442.
    @Test func diskSize() {
        var vfs = statvfs()
        #expect(statvfs("/", &vfs) == 0)
        let blocks = UInt64(vfs.f_blocks) * (UInt64(vfs.f_frsize) / 512)
        #expect(DiskInfo.size() == Int64(blocks / 2))
    }

    @Test func diskFreeSpace() {
        let free = DiskInfo.freeSpace()
        #expect(free > 0)
        #expect(free <= DiskInfo.size())
    }

    @Test func diskIsValid() {
        let valid = DiskInfo.isValid(path: "/")
        #expect(valid)
    }

    // #1987: `name != nil` passed any string. OSD_Disk built from an OSD_Path, as the bridge
    // does, has an empty name on macOS because OSD_Path never fills its disk component (#1442);
    // pinned to what the kernel returns.
    @Test func diskName() {
        #expect(DiskInfo.name() == "")
    }
}

@Suite("OSD Chronometer Tests")
struct OSDChronometerTests {

    // #1987: `user >= 0` passed a bridge reporting zero. After burning some CPU the process user
    // time must be positive and agree with getrusage(RUSAGE_SELF); OSD_Chronometer reports it in
    // 1/100 s steps (0.060 against getrusage's 0.0611 in the probe), hence the 0.02 s slack.
    @Test func processCPU() {
        var sum = 0.0
        for i in 0..<1_000_000 { sum += Double(i) }
        var before = rusage()
        getrusage(RUSAGE_SELF, &before)
        let cpu = CPUTime.processCPU()
        var after = rusage()
        getrusage(RUSAGE_SELF, &after)
        let lo = Double(before.ru_utime.tv_sec) + Double(before.ru_utime.tv_usec) * 1e-6
        let hi = Double(after.ru_utime.tv_sec) + Double(after.ru_utime.tv_usec) * 1e-6
        #expect(cpu.user > 0)
        #expect(cpu.user >= lo - 0.02)
        #expect(cpu.user <= hi + 0.02)
        #expect(sum > 0)
    }
}

@Suite("OSD Process Tests")
struct OSDProcessTests {

    // #1987: `> 0` and `!= nil` passed any pid and any name. OSD_Process reports getpid() and
    // the passwd entry's name for getuid().
    @Test func processId() {
        #expect(ProcessInfo.processId == Int(getpid()))
    }

    @Test func userName() {
        let expected = getpwuid(getuid()).map { String(cString: $0.pointee.pw_name) }
        #expect(expected != nil)
        #expect(ProcessInfo.userName == expected)
    }
}

@Suite("OSD_Host Tests")
struct OSDHostTests {

    // #1987: this accepted any non-empty string. OSD_Host::HostName() resolves the name through
    // the system resolver, so it can differ from gethostname(2) in form: on the macOS CI runner
    // gethostname gives "<host>.local" and OSD_Host gives "<host>." (trailing dot), while a
    // developer machine gets the identical string from both. Both name the same host, so the two
    // are compared by first DNS label, case-insensitively. That still rejects a bridge that
    // returns a fixed or wrong name.
    @Test func hostName() throws {
        var buf = [CChar](repeating: 0, count: 256)
        #expect(gethostname(&buf, buf.count) == 0)
        let expected = String(cString: buf)
        #expect(!expected.isEmpty)
        func firstLabel(_ name: String) -> String {
            String(name.prefix { $0 != "." }).lowercased()
        }
        let actual = try #require(HostInfo.hostName)
        #expect(!firstLabel(actual).isEmpty)
        #expect(firstLabel(actual) == firstLabel(expected))
    }

    // #1987: OSD_Host::SystemVersion() is uname(3)'s sysname and release joined by a space.
    @Test func systemVersion() {
        var u = utsname()
        #expect(uname(&u) == 0)
        func field(_ raw: UnsafeRawBufferPointer) -> String {
            guard let base = raw.bindMemory(to: CChar.self).baseAddress else { return "" }
            return String(cString: base)
        }
        let sysname = withUnsafeBytes(of: &u.sysname, field)
        let release = withUnsafeBytes(of: &u.release, field)
        #expect(HostInfo.systemVersion == "\(sysname) \(release)")
        // Do not assert on the sysname value; it varies by OS (Darwin, Linux, etc.)
    }

    // #1987: this used to be `let _ = HostInfo.internetAddress`, with no assertion at all. The
    // kernel returns a dotted-quad IPv4 address (the loopback address in one probe run, a LAN
    // address in another), so the result must parse as one.
    @Test func internetAddress() throws {
        let address = try #require(HostInfo.internetAddress)
        var parsed = in_addr()
        #expect(inet_pton(AF_INET, address, &parsed) == 1)
    }
}

// The two #1442 tests whose oracle is `statvfs`, which wasi-libc does not have, lifted out of
// `Issue1442DiskUnicodeOSDUtilitiesTests.swift` by #2928. The suite name is new because they were
// two of six tests in one suite there, and the other four, the two UTF-8 encoding ones and the two
// `DiskInfo.isValid` ones, need no host oracle and run for wasm.
@Suite("#1442 disk size and free space are KB, against statvfs")
struct Issue1442DiskKBAgainstStatvfsTests {

    @Test("Disk total size is reported in KB, matching a direct statvfs computation")
    func diskSizeMatchesStatvfsInKB() throws {
        var vfs = statvfs()
        let rc = statvfs("/", &vfs)
        #expect(rc == 0)
        guard rc == 0 else { return }

        // OSD_Disk::DiskSize() computes total blocks as f_blocks * (f_frsize / 512)
        // (OSD_Disk.cxx); this bridge fn is documented in KB, and 1 block (512 bytes) is
        // 0.5 KB. Total capacity does not fluctuate between the two statvfs-driven reads
        // (ours here, OCCT's inside the bridge call below), so this can be an exact
        // comparison, unlike free space below.
        let blocks = UInt64(vfs.f_blocks) * (UInt64(vfs.f_frsize) / 512)
        let expectedKB = Int64(blocks / 2)

        let actual = DiskInfo.size(path: "/")
        #expect(actual == expectedKB)
        // Directly rules out the original (undivided, raw block count) answer too, for any
        // disk large enough to tell the two apart.
        if blocks > 0 {
            #expect(actual != Int64(blocks))
        }
    }

    @Test("Disk free space is reported in KB, matching a statvfs computation")
    func diskFreeMatchesStatvfsInKB() throws {
        var vfs = statvfs()
        let rc = statvfs("/", &vfs)
        #expect(rc == 0)
        guard rc == 0 else { return }

        let blocks = UInt64(vfs.f_bavail) * (UInt64(vfs.f_frsize) / 512)
        let expectedKB = Int64(blocks / 2)

        let actual = DiskInfo.freeSpace(path: "/")

        // Free space can drift slightly between the two statvfs-driven reads under real disk
        // activity; a 10% tolerance is generous for that while still firmly rejecting the
        // original 2x-too-large (undivided block count) answer.
        let tolerance = max(expectedKB / 10, 1024)
        #expect(abs(actual - expectedKB) <= tolerance)
    }
}
