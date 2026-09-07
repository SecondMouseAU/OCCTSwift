import Testing

@testable import OCCTSwift

@Suite("IntPackedMap Tests")
struct IntPackedMapTests {

    @Test func setAndAdd() {
        guard let doc = Document.create() else { return }
        #expect(doc.setIntPackedMap(tag: 100))
        #expect(doc.intPackedMapAdd(tag: 100, value: 42))
        #expect(doc.intPackedMapAdd(tag: 100, value: 100))
        #expect(doc.intPackedMapContains(tag: 100, value: 42))
        #expect(doc.intPackedMapContains(tag: 100, value: 100))
    }

    @Test func extent() {
        guard let doc = Document.create() else { return }
        doc.setIntPackedMap(tag: 101)
        doc.intPackedMapAdd(tag: 101, value: 1)
        doc.intPackedMapAdd(tag: 101, value: 2)
        doc.intPackedMapAdd(tag: 101, value: 3)
        #expect(doc.intPackedMapCount(tag: 101) == 3)
    }

    @Test func remove() {
        guard let doc = Document.create() else { return }
        doc.setIntPackedMap(tag: 102)
        doc.intPackedMapAdd(tag: 102, value: 10)
        doc.intPackedMapAdd(tag: 102, value: 20)
        #expect(doc.intPackedMapRemove(tag: 102, value: 10))
        #expect(!doc.intPackedMapContains(tag: 102, value: 10))
        #expect(doc.intPackedMapCount(tag: 102) == 1)
    }

    @Test func clearAndEmpty() {
        guard let doc = Document.create() else { return }
        doc.setIntPackedMap(tag: 103)
        doc.intPackedMapAdd(tag: 103, value: 5)
        #expect(!doc.intPackedMapIsEmpty(tag: 103))
        doc.intPackedMapClear(tag: 103)
        #expect(doc.intPackedMapIsEmpty(tag: 103))
        #expect(doc.intPackedMapCount(tag: 103) == 0)
    }

    @Test func getValues() {
        guard let doc = Document.create() else { return }
        doc.setIntPackedMap(tag: 104)
        doc.intPackedMapAdd(tag: 104, value: 7)
        doc.intPackedMapAdd(tag: 104, value: 42)
        doc.intPackedMapAdd(tag: 104, value: 99)
        let values = doc.intPackedMapValues(tag: 104)
        #expect(values.count == 3)
        #expect(values.contains(7))
        #expect(values.contains(42))
        #expect(values.contains(99))
    }

    @Test func changeValues() {
        guard let doc = Document.create() else { return }
        doc.setIntPackedMap(tag: 105)
        doc.intPackedMapAdd(tag: 105, value: 1)
        #expect(doc.intPackedMapSetValues(tag: 105, values: [10, 20, 30, 40, 50]))
        #expect(doc.intPackedMapCount(tag: 105) == 5)
        #expect(doc.intPackedMapContains(tag: 105, value: 30))
        #expect(!doc.intPackedMapContains(tag: 105, value: 1))
    }
}
