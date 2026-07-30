import Testing
import Foundation
@testable import OCCTSwift

/// One path-parsing contract, pinned across both public spellings (#499).
///
/// `PathParser` and `OSDPath` used to wrap two different OCCT classes, `TDocStd_PathParser` and
/// `OSD_Path`, behind identically-named methods that answered the same question differently.
/// These tests pin the single contract both spellings now share, and cover the four cases where
/// `TDocStd_PathParser` was measurably wrong rather than merely differently formatted.
@Suite("Path Parsing Contract (#499)")
struct PathParsingContractTests {

    // MARK: - The two spellings agree

    @available(*, deprecated, message: "Exercises the deprecated PathParser forwarders on purpose.")
    @Test func bothSpellingsReportTheSameExtension() {
        for path in ["/home/user/model.step", "model.step", "/home/user/archive.tar.gz",
                     "/home/user/model", "./sub/f.txt"] {
            #expect(PathParser.fileExtension(path) == OSDPath.fileExtension(path),
                    "extension disagreement for \(path)")
        }
    }

    @available(*, deprecated, message: "Exercises the deprecated PathParser forwarders on purpose.")
    @Test func bothSpellingsReportTheSameName() {
        for path in ["/home/user/model.step", "model.step", "/home/user/archive.tar.gz",
                     "/home/user/model", "./sub/f.txt"] {
            #expect(PathParser.name(path) == OSDPath.name(path),
                    "name disagreement for \(path)")
        }
    }

    @available(*, deprecated, message: "Exercises the deprecated PathParser forwarders on purpose.")
    @Test func bothSpellingsReportTheSameDirectory() {
        for path in ["/home/user/model.step", "model.step", "./sub/f.txt", "/home/user/model"] {
            #expect(PathParser.trek(path) == OSDPath.folderAndFile(path)?.folder,
                    "directory disagreement for \(path)")
        }
    }

    // MARK: - The four TDocStd_PathParser defects, by case

    /// `TDocStd_PathParser::Parse()` returns early when the path has no dot, leaving *both*
    /// name and trek empty, so an extension-less path used to parse to nothing at all.
    @available(*, deprecated, message: "Exercises the deprecated PathParser forwarders on purpose.")
    @Test func extensionlessPathStillHasANameAndDirectory() {
        #expect(PathParser.name("/home/user/model") == "model")
        #expect(PathParser.trek("/home/user/model") == "/home/user/")
        #expect(PathParser.fileExtension("/home/user/model") == "")
    }

    /// A basename that begins with a dot drove `Parse()` into a `Split` past the end of the
    /// string; the bridge's `catch (...)` turned that into `nil` from every accessor.
    @available(*, deprecated, message: "Exercises the deprecated PathParser forwarders on purpose.")
    @Test func dotfileInsideADirectoryParses() {
        #expect(PathParser.fileExtension("/home/user/.config") == ".config")
        #expect(PathParser.name("/home/user/.config") == "")
        #expect(PathParser.trek("/home/user/.config") == "/home/user/")
    }

    /// `Parse()` searched the whole path for the last dot with no awareness of the separator,
    /// so a dot in a *directory* name was read as the start of the file's extension.
    @available(*, deprecated, message: "Exercises the deprecated PathParser forwarders on purpose.")
    @Test func dotInADirectoryNameIsNotAnExtension() {
        #expect(PathParser.fileExtension("/home/a.b/model") == "")
        #expect(PathParser.name("/home/a.b/model") == "model")
        #expect(PathParser.trek("/home/a.b/model") == "/home/a.b/")
    }

    /// The `TCollection_ExtendedString(const char*)` the bridge built defaults to
    /// `theIsMultiByte = false`, so UTF-8 input round-tripped back out as mojibake.
    @available(*, deprecated, message: "Exercises the deprecated PathParser forwarders on purpose.")
    @Test func nonASCIIPathSurvivesParsing() {
        #expect(PathParser.name("/home/üser/mødel.step") == "mødel")
        #expect(PathParser.name("/home/user/模型.step") == "模型")
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

    // MARK: - Degenerate input is one outcome, not two

    @available(*, deprecated, message: "Exercises the deprecated PathParser forwarders on purpose.")
    @Test func degenerateInputsAgreeAcrossSpellings() {
        for path in ["", "/", ".", "/home/user/"] {
            #expect(PathParser.name(path) == OSDPath.name(path), "name disagreement for \"\(path)\"")
            #expect(PathParser.fileExtension(path) == OSDPath.fileExtension(path),
                    "extension disagreement for \"\(path)\"")
        }
    }
}
