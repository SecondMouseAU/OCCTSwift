// Does `Int(Int32.max) + 1` survive COMPILATION for wasm32 (Int is 32 bits), or is it diagnosed?
// Each case is separately compiled below so one error does not mask the others.

#if CASE1
    func case1() -> Int { return Int(Int32.max) + 1 }
#endif

#if CASE2
    struct S2 { static let pastInt32 = Int(Int32.max) + 1 }
    func case2() -> Int { return S2.pastInt32 }
#endif

#if CASE3
    // An argument list shaped like the ones in the excluded files.
    let list3: [Int] = [-1, 0, 1, Int(Int32.max), Int(Int32.max) + 1, Int.max]
#endif

#if CASE4
    // Written so constant folding cannot see it.
    @inline(never) func plusOne(_ n: Int32) -> Int { return Int(n) + 1 }
    func case4() -> Int { return plusOne(Int32.max) }
#endif

#if CASE5
    // The non-overflowing spelling of "one past the bridge's int32_t ceiling", clamped.
    let case5: Int = Int(Int32.max).addingReportingOverflow(1).partialValue
#endif
