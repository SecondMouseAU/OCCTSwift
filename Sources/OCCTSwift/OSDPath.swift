import Foundation
import simd
import OCCTBridge

/// File path parsing and manipulation utilities, wrapping OCCT's `OSD_Path`.
///
/// The single path-parsing surface in OCCTSwift since #499. The `TDocStd_PathParser`-backed
/// ``PathParser`` is now a deprecated forwarder onto this type.
///
/// Parsing is pure string syntax: nothing here touches the filesystem, and no method requires
/// the path to exist.
///
/// ```swift
/// OSDPath.name("/home/user/model.step")          // "model"
/// OSDPath.fileExtension("/home/user/model.step") // ".step"  (leading dot, unlike URL.pathExtension)
/// OSDPath.folder("/home/user/model.step")        // "/home/user/"
/// OSDPath.isAbsolute("/home/user/model.step")    // true
/// ```
public enum OSDPath {

    /// Get the filename, without directory or extension, from a path.
    ///
    /// A basename that is entirely extension yields an empty name:
    /// `OSDPath.name("/home/user/.config")` is `""`, not `".config"`.
    ///
    /// ```swift
    /// OSDPath.name("/home/user/model.step")       // "model"
    /// OSDPath.name("/home/user/archive.tar.gz")   // "archive.tar"  (last dot wins)
    /// OSDPath.name("/home/user/model")            // "model"
    /// ```
    public static func name(_ path: String) -> String? {
        guard let ptr = OCCTOSDPathName(path) else { return nil }
        defer { OCCTOSDPathFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Get the file extension, **leading dot included**, from a path.
    ///
    /// Note the dot: this differs from Foundation's `URL.pathExtension`, which strips it.
    /// A path with no extension gives `""`, and only the last dot in the *basename* counts:
    /// a dot in a directory name never starts an extension.
    ///
    /// ```swift
    /// OSDPath.fileExtension("/home/user/model.step")     // ".step"
    /// OSDPath.fileExtension("/home/user/archive.tar.gz") // ".gz"
    /// OSDPath.fileExtension("/home/user/model")          // ""
    /// OSDPath.fileExtension("/home/a.b/model")           // ""
    /// ```
    public static func fileExtension(_ path: String) -> String? {
        guard let ptr = OCCTOSDPathExtension(path) else { return nil }
        defer { OCCTOSDPathFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Get the directory in OCCT's **portable trek syntax**, where `/` becomes `|` and `..`
    /// becomes `^`.
    ///
    /// This is `OSD_Path`'s system-independent directory representation, not a filesystem
    /// path, so do not hand it to `FileManager`. Use ``folder(_:)`` for a usable directory.
    ///
    /// ```swift
    /// OSDPath.trek("/home/user/model.step")  // "|home|user|"
    /// OSDPath.trek("../up/f.txt")            // "^|up|"
    /// OSDPath.folder("/home/user/model.step")  // "/home/user/"  <- what you usually want
    /// ```
    public static func trek(_ path: String) -> String? {
        guard let ptr = OCCTOSDPathTrek(path) else { return nil }
        defer { OCCTOSDPathFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Get the path re-rendered in the running system's own syntax.
    ///
    /// ```swift
    /// OSDPath.systemName("/home/user/model.step")  // "/home/user/model.step"
    /// ```
    public static func systemName(_ path: String) -> String? {
        guard let ptr = OCCTOSDPathSystemName(path) else { return nil }
        defer { OCCTOSDPathFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Split a path into its directory and its full filename, at the last separator.
    ///
    /// Unlike ``trek(_:)``, the folder is a real path: it keeps its trailing separator, and a
    /// path with no directory part gives `""`.
    ///
    /// ```swift
    /// OSDPath.folderAndFile("/home/user/model.step")  // ("/home/user/", "model.step")
    /// OSDPath.folderAndFile("model.step")             // ("", "model.step")
    /// ```
    public static func folderAndFile(_ path: String) -> (folder: String, file: String)? {
        var folderPtr: UnsafePointer<CChar>?
        var filePtr: UnsafePointer<CChar>?
        OCCTOSDPathFolderAndFile(path, &folderPtr, &filePtr)
        guard let fp = folderPtr, let flp = filePtr else { return nil }
        defer { OCCTOSDPathFreeString(fp); OCCTOSDPathFreeString(flp) }
        return (String(cString: fp), String(cString: flp))
    }

    /// Get the directory part of a path, as a real path with its trailing separator.
    ///
    /// The filesystem-usable counterpart of ``trek(_:)``.
    ///
    /// ```swift
    /// OSDPath.folder("/home/user/model.step")  // "/home/user/"
    /// OSDPath.folder("/home/user/model")       // "/home/user/"
    /// OSDPath.folder("model.step")             // ""
    /// ```
    public static func folder(_ path: String) -> String? {
        folderAndFile(path)?.folder
    }

    /// Check whether a path parses under the running system's syntax.
    ///
    /// A syntax check only. It does not test whether the path exists, and in practice
    /// `OSD_Path` accepts anything a Unix system could name, including the empty string.
    ///
    /// ```swift
    /// OSDPath.isValid("/tmp/test.txt")  // true
    /// ```
    public static func isValid(_ path: String) -> Bool { OCCTOSDPathIsValid(path) }

    /// Check if path is an absolute Unix path (leading `/`).
    ///
    /// ```swift
    /// OSDPath.isUnixPath("/home/user/model.step")  // true
    /// OSDPath.isUnixPath("model.step")             // false
    /// ```
    public static func isUnixPath(_ path: String) -> Bool { OCCTOSDPathIsUnixPath(path) }

    /// Check if path is relative. Pure syntax, no filesystem access.
    ///
    /// ```swift
    /// OSDPath.isRelative("./sub/f.txt")  // true
    /// ```
    public static func isRelative(_ path: String) -> Bool { OCCTOSDPathIsRelative(path) }

    /// Check if path is absolute. Pure syntax, no filesystem access.
    ///
    /// Recognises Unix, DOS, UNC and remote-protocol spellings.
    ///
    /// ```swift
    /// OSDPath.isAbsolute("/home/user/model.step")  // true
    /// ```
    public static func isAbsolute(_ path: String) -> Bool { OCCTOSDPathIsAbsolute(path) }
}
