// Eight cases, each returning a sentinel rather than a plausible number, and each one checked.
//
// Every case runs and prints before anything fails. A trap loses whatever is still sitting in the
// stdio buffer, so asserting case by case would hide the results of the cases that ran before the
// first wrong answer, which is exactly what happened while this file was being written.
import ProbeBridge

/// Prints one case and returns a description of the mismatch, or nil when it matched.
func check(_ label: String, _ got: Int32, _ want: Int32, _ meaning: String) -> String? {
    let verdict = got == want ? "ok" : "MISMATCH, expected \(want)"
    print("  \(label)  \(got)  \(verdict)")
    print("      \(meaning)")
    return got == want ? nil : "\(label): expected \(want), got \(got)"
}

print("C++ exceptions on wasm32-unknown-wasip1, in OCCT's shape:")

// Evaluated in order, so the cases run and print in the order written.
let failures: [String] = [
    check("catch by derived type   ", probe_bridge_catch_derived(), 20,
          "a raise crossed a target boundary and its own type caught it"),
    check("catch by base reference ", probe_bridge_catch_base(), 21,
          "std::exception& caught a derived failure, so the type match reached the base"),
    check("catch (...)             ", probe_bridge_catch_ellipsis(), 22,
          "the handler shape every OCCTBridge function's outermost catch uses"),
    check("libc++ raised it, not us", probe_bridge_catch_stdlib(), 23,
          "a std::out_of_range from vector::at crossed the seam between the two libc++ builds"),
    check("through a non-EH frame  ", probe_bridge_unwind_through_noeh(), 10,
          "10 = it propagated, but that frame's destructor did NOT run, so the frame leaked"),
    check("try/catch in a non-EH TU", probe_bridge_try_inside_noeh(), -1,
          "-1 = that catch never fired and the bridge's did, with no diagnostic anywhere"),
    check("setjmp/longjmp          ", probe_bridge_setjmp_roundtrip(), 7,
          "a longjmp arrived back at its setjmp in a TU carrying the exception flags"),
    check("leak on an all-EH path  ", probe_bridge_leak_after_clean_unwind(), 0,
          "0 = every destructor ran when the whole path carried the flags"),
].compactMap { $0 }

probe_bridge_flush()

if failures.isEmpty {
    print("all eight cases matched")
} else {
    for line in failures { print("FAILED: \(line)") }
    probe_bridge_flush()
    fatalError("\(failures.count) case(s) did not match")
}
