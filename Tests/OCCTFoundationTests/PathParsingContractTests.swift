import Testing
import Foundation
@testable import OCCTSwift

/// `OSDPath`'s own contract (#499). This used to also pin a shared contract against `PathParser`,
/// a `TDocStd_PathParser`-backed forwarder deprecated in favour of `OSDPath` and removed at
/// v2.0.0 (#784); the comparison tests went with it.
@Suite("Path Parsing Contract (#499)")
struct PathParsingContractTests {

    /// The `TCollection_ExtendedString(const char*)` the old `TDocStd_PathParser`-backed bridge
    /// built defaulted to `theIsMultiByte = false`, so UTF-8 input round-tripped back out as
    /// mojibake. `OSD_Path` never had that defect; kept as direct coverage.
    @Test func nonASCIIPathSurvivesParsing() {
        #expect(OSDPath.name("/home/üser/mødel.step") == "mødel")
        #expect(OSDPath.name("/home/user/模型.step") == "模型")
    }

    // MARK: - OSD_Path's own contract, unchanged

    @Test func extensionKeepsItsLeadingDot() {
        #expect(OSDPath.fileExtension("/home/user/model.step") == ".step")
        #expect(OSDPath.fileExtension("/home/user/archive.tar.gz") == ".gz")
        #expect(OSDPath.fileExtension("/home/user/model") == "")
    }

    @Test func nameDropsBothDirectoryAndExtension() {
        #expect(OSDPath.name("/home/user/model.step") == "model")
        #expect(OSDPath.name("/home/user/archive.tar.gz") == "archive.tar")
    }

    /// `OSD_Path::Trek()` is OCCT's *portable* directory syntax, not a filesystem path:
    /// `/` becomes `|` and `..` becomes `^`. This is the one accessor whose result must not
    /// be handed to `FileManager`.
    @Test func trekIsPortableSyntaxNotAFilesystemPath() {
        #expect(OSDPath.trek("/home/user/model.step") == "|home|user|")
        #expect(OSDPath.trek("../up/f.txt") == "^|up|")
        #expect(OSDPath.trek("model.step") == "")
    }

    @Test func folderAndFileSplitOnTheLastSeparator() {
        let result = OSDPath.folderAndFile("/home/user/model.step")
        #expect(result?.folder == "/home/user/")
        #expect(result?.file == "model.step")
    }

    /// `folder(_:)` is the filesystem-usable directory accessor `trek(_:)` is not.
    @Test func folderIsARealPathUnlikeTrek() {
        #expect(OSDPath.folder("/home/user/model.step") == "/home/user/")
        #expect(OSDPath.folder("/home/user/model") == "/home/user/")
        #expect(OSDPath.folder("./sub/f.txt") == "./sub/")
        #expect(OSDPath.folder("model.step") == "")
        #expect(OSDPath.folder("/home/user/model.step") != OSDPath.trek("/home/user/model.step"))
    }

    /// A folder joined back onto its file reproduces the input, which is the property the
    /// portable trek cannot offer.
    @Test func folderAndFileRecomposeTheInput() {
        for path in ["/home/user/model.step", "./sub/f.txt", "model.step", "/home/a.b/model"] {
            let split = OSDPath.folderAndFile(path)
            #expect((split.map { $0.folder + $0.file }) == path, "recompose failed for \(path)")
        }
    }

    @Test func systemNameRoundTripsTheInput() {
        #expect(OSDPath.systemName("/home/user/model.step") == "/home/user/model.step")
        #expect(OSDPath.systemName("./sub/f.txt") == "./sub/f.txt")
    }

    @Test func absoluteAndRelativeAreSyntaxOnly() {
        #expect(OSDPath.isAbsolute("/home/user/model.step"))
        #expect(OSDPath.isRelative("./sub/f.txt"))
        #expect(OSDPath.isRelative("model.step"))
        #expect(OSDPath.isUnixPath("/home/user/model.step"))
        #expect(!OSDPath.isUnixPath("model.step"))
    }

    /// Measured, not assumed: `OSD_Path::IsValid` accepts every string tried, including the
    /// empty one. It is a system-type syntax check, not a "can I open this" test.
    @Test func validityCheckAcceptsAnythingParsable() {
        #expect(OSDPath.isValid("/tmp/test.txt"))
        #expect(OSDPath.isValid(""))
        #expect(OSDPath.isValid("/home/üser/mødel.step"))
    }
}

// Removed `degenerateInputsParseCleanly()`: its only assertions were `OSDPath.name(path) != nil`
// and `OSDPath.fileExtension(path) != nil` for four degenerate paths, with no evidence the
// assertion was ever proven able to fail. Checked directly rather than assumed: the bridge
// (`OCCTBridge_IO.mm`'s `osdPathComponent`) returns `nullptr` only when constructing `OSD_Path`
// or reading `.Name()`/`.Extension()` throws, caught by `catch (...)`. Probed both functions
// against every degenerate/adversarial input reachable from a Swift `String` (empty, "/", ".",
// a trailing slash, thousands of slashes, embedded NUL, control characters, non-ASCII, a 100k
// character string) and none returned `nil`; `nonASCIIPathSurvivesParsing` above already pins one
// of those non-nil results. `OSD_Path`'s own header documents a `ConstructionError` "when the path
// is either null", unreachable from this API, since Swift's `String`-to-C-string bridging never
// produces a null pointer, "or contains characters not in range of ' '...'~'", which the measured
// behavior does not honour for this constructor overload on this platform. With no input found
// that reaches the bridge's `catch` block, the assertion could not be shown to test anything, so
// it is removed rather than left as an unproven claim (okf/policies/prove-the-test-fails.md).
