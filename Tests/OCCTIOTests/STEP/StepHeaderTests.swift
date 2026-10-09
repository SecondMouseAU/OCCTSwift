import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("APIHeaderSection_MakeHeader Tests")
struct StepHeaderTests {

    @Test func createHeader() {
        if let header = StepHeader(filename: "test.stp") {
            #expect(header.isDone)
        }
    }

    @Test func setAndGetName() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.name = "my_model.stp"
        if let name = header.name {
            #expect(name == "my_model.stp")
        }
    }

    @Test func setAndGetTimeStamp() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.timeStamp = "2026-03-24T12:00:00"
        if let ts = header.timeStamp {
            #expect(ts == "2026-03-24T12:00:00")
        }
    }

    @Test func setAndGetAuthor() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.author = "John Doe"
        if let author = header.author {
            #expect(author == "John Doe")
        }
    }

    @Test func setAndGetOrganization() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.organization = "ACME Corp"
        if let org = header.organization {
            #expect(org == "ACME Corp")
        }
    }

    @Test func setAndGetPreprocessorVersion() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.preprocessorVersion = "OCCTSwift v0.100.0"
        if let ppv = header.preprocessorVersion {
            #expect(ppv == "OCCTSwift v0.100.0")
        }
    }

    @Test func setAndGetOriginatingSystem() {
        guard let header = StepHeader(filename: "test.stp") else { return }
        header.originatingSystem = "macOS"
        if let os = header.originatingSystem {
            #expect(os == "macOS")
        }
    }

    @Test func allFieldsRoundTrip() {
        guard let header = StepHeader(filename: "full_test.stp") else { return }
        header.name = "full_test.stp"
        header.timeStamp = "2026-03-24"
        header.author = "Claude"
        header.organization = "Anthropic"
        header.preprocessorVersion = "v0.100.0"
        header.originatingSystem = "OCCTSwift"
        #expect(header.isDone)
        #expect(header.name == "full_test.stp")
        #expect(header.timeStamp == "2026-03-24")
        #expect(header.author == "Claude")
        #expect(header.organization == "Anthropic")
        #expect(header.preprocessorVersion == "v0.100.0")
        #expect(header.originatingSystem == "OCCTSwift")
    }
}
