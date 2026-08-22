import Foundation
import OCCTBridge
import simd

/// A wrapper around OCCT's OSD_File for platform-independent file I/O.
public final class OSDFile {

    @usableFromInline let handle: OCCTOSDFileRef

    /// Create a file object for the given file-system path.
    public init(path: String) {
        handle = OCCTFileCreate(path)
    }

    /// Create a file object for a URL's file path.
    public init(url: URL) {
        handle = OCCTFileCreate(url.path)
    }

    /// Create a temporary file (path chosen by OCCT).
    public init() {
        handle = OCCTFileCreateTemporary()
    }

    deinit {
        OCCTFileRelease(handle)
    }

    /// Build (create/truncate) the file and open it for reading and writing.
    /// - Returns: true on success.
    @discardableResult
    public func open() -> Bool {
        OCCTFileOpen(handle)
    }

    /// Open an existing file for reading only.
    /// - Returns: true on success.
    @discardableResult
    public func openReadOnly() -> Bool {
        OCCTFileOpenReadOnly(handle)
    }

    /// Write a string to the file.
    /// - Returns: true on success.
    @discardableResult
    public func write(_ string: String) -> Bool {
        string.withCString { ptr in
            OCCTFileWrite(handle, ptr, Int32(string.utf8.count))
        }
    }

    /// Write raw bytes to the file.
    /// - Returns: true on success.
    @discardableResult
    public func write(_ bytes: [UInt8]) -> Bool {
        bytes.withUnsafeBufferPointer { buf in
            buf.baseAddress.map { OCCTFileWrite(handle, $0, Int32(bytes.count)) } ?? false
        }
    }

    /// Read one line from the file.
    /// - Parameter bufSize: Maximum line length to read.
    /// - Returns: The line string, or nil at EOF or on error.
    public func readLine(bufSize: Int = 4096) -> String? {
        guard let ptr = OCCTFileReadLine(handle, Int32(bufSize)) else { return nil }
        defer { OCCTFileFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Read the entire remaining content of the file as a string.
    public func readAll() -> String? {
        var length: Int32 = 0
        guard let ptr = OCCTFileReadAll(handle, &length) else { return nil }
        defer { OCCTFileFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Close the file.
    public func close() {
        OCCTFileClose(handle)
    }

    /// Whether the file is currently open.
    public var isOpen: Bool { OCCTFileIsOpen(handle) }

    /// File size in bytes, or nil on error.
    public var fileSize: Int? {
        let sz = OCCTFileSize(handle)
        return sz >= 0 ? Int(sz) : nil
    }

    /// Rewind the file position to the beginning.
    public func rewind() {
        OCCTFileRewind(handle)
    }

    /// Whether the file position is at the end.
    public var isAtEnd: Bool { OCCTFileIsAtEnd(handle) }
}
