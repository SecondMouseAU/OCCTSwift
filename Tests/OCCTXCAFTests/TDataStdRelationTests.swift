import Testing

@testable import OCCTSwift

@Suite("Relation Tests")
struct RelationTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        #expect(doc.setRelation(tag: 390, relation: "x + y = z"))
        if let rel = doc.relation(tag: 390) {
            #expect(rel == "x + y = z")
        }
    }

    @Test func hasRelation() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasRelation(tag: 391))
        _ = doc.setRelation(tag: 391, relation: "a = b")
        #expect(doc.hasRelation(tag: 391))
    }
}
