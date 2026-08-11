// The ShapeExtend_Status flag space shared by ShapeFixer and FaceFixer.
//
// ShapeFix_Shape and ShapeFix_Face (both ShapeFix_Root subclasses) report their fix results
// through the same 19-value OCCT enum, ShapeExtend_Status, and each assigns its own meaning to
// the DONE1...DONE8 / FAIL1...FAIL8 slots (#849). Before this file, the two Swift call sites were
// two independent, and independently wrong, encodings of it:
//
//   - `ShapeFixer.status(_ type: Int)` exposed only 3 of the 19 ordinals, via an undocumented
//     1/2/3 -> OK/DONE/FAIL remap, and silently returned `false` for anything else.
//   - `FaceFixer`'s own local `Status` enum tried to expose the full space but got everything
//     from `.fail1` through `.done` wrong: it never accounted for the combined `ShapeExtend_DONE`
//     flag OCCT places between `DONE8` and `FAIL1`, so every case from there on read one ordinal
//     off — `.done` (meant to read "something was fixed") actually queried `ShapeExtend_FAIL8`.
//
// `ShapeFixStatus` mirrors the real ordinals exactly (verified against ShapeExtend_Status.hxx,
// pinned V8_0_1) and is the one type both classes use now, each with its own meaning table for
// the per-class DONEi/FAILi slots: see `ShapeFixer.status(_:)` and `FaceFixer.status(_:)`.

/// A status flag from OCCT's `ShapeExtend_Status` enum — the flag space every `ShapeFix_Root`
/// subclass (`ShapeFix_Shape`, `ShapeFix_Face`, `ShapeFix_Wire`, ...) reports its fix result
/// through. `DONE1`...`DONE8` and `FAIL1`...`FAIL8` are per-class: each subclass assigns its own
/// meaning to the numbered slots, and a slot it does not use is simply never set. See
/// ``ShapeFixer/status(_:)`` and ``FaceFixer/status(_:)`` for each class's own meaning table.
///
/// Raw values mirror the real OCCT ordinals exactly (`ShapeExtend_Status.hxx`, pinned V8_0_1):
/// `OK`=0, `DONE1`...`DONE8`=1...8, the combined `DONE`=9, `FAIL1`...`FAIL8`=10...17, the combined
/// `FAIL`=18. (#849 — a previous, per-class-local encoding shifted everything from `.fail1`
/// onward by one ordinal; this type replaces it.)
///
/// ```swift
/// let fixer = FaceFixer(face: badFace)
/// fixer?.perform()
/// if fixer?.status(.done) == true {
///     // something was fixed — ask which pass, per ShapeFix_Face's own DONEi meanings
///     print(fixer?.status(.done3) == true ? "a missing seam was added" : "some other pass fired")
/// }
/// ```
public enum ShapeFixStatus: Int32, Sendable, CaseIterable {
    /// Nothing needed fixing.
    case ok = 0
    case done1 = 1, done2, done3, done4, done5, done6, done7, done8
    /// Any `DONE1`...`DONE8` flag is set: something was fixed.
    case done = 9
    case fail1 = 10, fail2, fail3, fail4, fail5, fail6, fail7, fail8
    /// Any `FAIL1`...`FAIL8` flag is set: some pass failed.
    case fail = 18
}
