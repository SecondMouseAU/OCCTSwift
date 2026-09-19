import Darwin
import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #1442: three defects in OCCTBridge_IO_OSDUtilities.mm.
//
// 1. OCCTDiskSize/OCCTDiskFree returned OSD_Disk::DiskSize()/DiskFree()'s raw 512-byte block
//    count while documented (and wrapped by DiskInfo.size()/.freeSpace()) as KB -- 1 block is
//    0.5 KB, so the old value was exactly 2x the true KB figure.
// 2. OCCTUnicodeConvertToUnicode dropped every converted code unit >= 128 instead of
//    UTF-8-encoding it, so any genuinely non-ASCII SJIS/EUC/GB/ANSI input came back empty or
//    truncated.
// 3. OCCTDiskIsValid treated "construction didn't throw" as "path is valid". OSD_Disk::
//    DiskSize() never throws on failure (it sets the OSD_Error flag and returns 0), so the
//    function returned true for a nonexistent path.
//
// Fixing (3) by itself (checking Failed()) would have made OCCTDiskIsValid return false for
// EVERY path on macOS/iOS/Linux: OSD_Disk(const OSD_Path&) reads OSD_Path::Disk() (the "drive"
// component), which OSD_Path.cxx's UnixExtract never populates, so myDiskName was always empty
// on those platforms and every statvfs() call already failed regardless of the real path's
// validity -- ground-truthed directly against the pinned kernel before writing the fix. The
// bridge fix for all three functions therefore also switches OSD_Disk's construction to the
// const char* overload, which assigns myDiskName from the path string directly.
@Suite("OCCTBridge_IO_OSDUtilities: disk size/free/valid + Unicode UTF-8 encoding (#1442)")
struct Issue1442DiskUnicodeOSDUtilitiesTests {

    // MARK: - Finding 1: DiskSize/DiskFree report KB, not 512-byte blocks

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

    // MARK: - Finding 2: non-ASCII code units are UTF-8 encoded, not dropped

    @Test("A code unit in [0x80,0x7FF] is UTF-8 encoded as 2 bytes, not dropped")
    func twoByteRangeCodeUnitIsUTF8Encoded() throws {
        UnicodeUtils.setFormat(.ansi)
        // ANSI format is a Latin-1-style pass-through (Resource_Unicode.cxx:
        // `TCollection_ExtendedString(theFromStr, /*isMultiByte*/ false)`, confirmed against
        // Standard_ExtCharacter.hxx's ToExtCharacter): each raw byte becomes the identical
        // char16_t code unit. 0xE9 -> U+00E9 (e-acute), UTF-8 0xC3 0xA9.
        let raw: [CChar] = [0x41, CChar(bitPattern: 0xE9), 0x42, 0]  // "A" + U+00E9 + "B"
        let ptr = OCCTUnicodeConvertToUnicode(raw)
        #expect(ptr != nil)
        if let ptr {
            defer { free(ptr) }
            let result = String(cString: ptr)
            #expect(result == "A\u{00E9}B")
        }
    }

    @Test("A code unit in [0x800,0xFFFF] is UTF-8 encoded as 3 bytes, not dropped")
    func threeByteRangeCodeUnitIsUTF8Encoded() throws {
        UnicodeUtils.setFormat(.sjis)
        // SJIS bytes 0x82 0xA0 decode (Resource_Unicode::ConvertSJISToUnicode's lookup table)
        // to U+3042 (hiragana "A"), ground-truthed directly against the pinned OCCT kernel.
        // UTF-8 for U+3042 is 0xE3 0x81 0x82.
        let raw: [CChar] = [CChar(bitPattern: 0x82), CChar(bitPattern: 0xA0), 0]
        let ptr = OCCTUnicodeConvertToUnicode(raw)
        #expect(ptr != nil)
        if let ptr {
            defer { free(ptr) }
            let result = String(cString: ptr)
            #expect(result == "\u{3042}")
        }
    }

    // MARK: - Finding 3: DiskIsValid checks Failed(), not merely whether construction threw

    @Test("A real, accessible path is reported valid")
    func diskIsValidAcceptsRealPath() throws {
        #expect(DiskInfo.isValid(path: "/") == true)
    }

    @Test("A nonexistent path is reported invalid")
    func diskIsValidRejectsNonexistentPath() throws {
        let bogus = "/this/path/does/not/exist/xyz123_\(Int.random(in: 100_000..<999_999))"
        #expect(DiskInfo.isValid(path: bogus) == false)
    }
}
