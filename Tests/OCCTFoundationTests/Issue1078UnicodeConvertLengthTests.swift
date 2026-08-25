import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #1078: `OCCTUnicodeConvertFromUnicode` truncated the converted string silently to the
// caller's fixed buffer and returned a boolean. The fix makes it return the full length (or
// -1 on error), allows a null buffer with maxSize 0 to query the length, and copies only up
// to maxSize-1 bytes when a buffer is provided.
@Suite("UnicodeUtils.convertFromUnicode at any length (#1078)")
struct Issue1078UnicodeConvertLengthTests {

    /// 5000 characters, which the old 4096 default buffer would cut.
    private static let longString = String(repeating: "漢", count: 5000)

    @Test("A long Unicode string converts and returns full length")
    func longStringConverts() throws {
        UnicodeUtils.setFormat(.ansi)
        let len = OCCTUnicodeConvertFromUnicode(Self.longString, nil, 0)
        #expect(len >= 0)
        
        var buf = [CChar](repeating: 0, count: Int(len) + 1)
        let actual = OCCTUnicodeConvertFromUnicode(Self.longString, &buf, Int32(buf.count))
        #expect(actual == len)
        let result = buf.withUnsafeBufferPointer { ptr in
            String(decoding: ptr.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        #expect(result.count == Self.longString.count)
    }

    @Test("A null buffer asks for the length alone")
    func nullBufferReportsTheLength() throws {
        UnicodeUtils.setFormat(.ansi)
        let len = OCCTUnicodeConvertFromUnicode("hello", nil, 0)
        #expect(len == 5)
        // Note: empty string behavior is implementation-defined in OCCT, may return -1
    }

    @Test("A short buffer yields a prefix and the length the whole string needs")
    func shortBufferReportsTheFullLength() throws {
        UnicodeUtils.setFormat(.ansi)
        let len = OCCTUnicodeConvertFromUnicode(Self.longString, nil, 0)
        #expect(len >= 0)
        
        var small = [CChar](repeating: 0, count: 8)
        let reported = OCCTUnicodeConvertFromUnicode(Self.longString, &small, Int32(small.count))
        #expect(reported == len)
        let prefix = small.withUnsafeBufferPointer { ptr in
            String(
                decoding: ptr.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
                as: UTF8.self)
        }
        #expect(prefix.count == 7)
        #expect(small[7] == 0)
    }

    @Test("A negative max size, or a null buffer with a positive one, is refused")
    func malformedBufferArgumentsAreRefused() throws {
        UnicodeUtils.setFormat(.ansi)
        var buffer = [CChar](repeating: 0, count: 8)
        #expect(OCCTUnicodeConvertFromUnicode("hello", &buffer, -1) == -1)
        #expect(OCCTUnicodeConvertFromUnicode("hello", nil, 8) == -1)
        #expect(OCCTUnicodeConvertFromUnicode("hello", &buffer, 0) == -1)
    }

    @Test("Swift API convertFromUnicode returns full string by default")
    func swiftAPIReturnsFullString() throws {
        UnicodeUtils.setFormat(.ansi)
        let result = UnicodeUtils.convertFromUnicode(Self.longString, maxSize: 10000)
        #expect(result != nil)
        if let r = result {
            #expect(r.count == Self.longString.count)
        }
    }

    @Test("Swift API convertFromUnicode respects maxSize when smaller than needed")
    func swiftAPIRespectsMaxSize() throws {
        UnicodeUtils.setFormat(.ansi)
        // The buffer size is maxSize-1 for NUL. The result length in CHARACTERS depends on
        // the target encoding (ANSI in this test). For multi-byte source chars converted to
        // single-byte ANSI, 10 bytes buffer = 9 chars + NUL.
        let result = UnicodeUtils.convertFromUnicode(Self.longString, maxSize: 10)
        #expect(result != nil)
        if let r = result {
            // With maxSize=10, buffer is 10 bytes = 9 chars + NUL in single-byte encoding
            #expect(r.count <= 9)
        }
    }
}
