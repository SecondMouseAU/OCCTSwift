#!/usr/bin/env python3
"""The gated edits to a tracked file that a bridge shadow cannot make.

`BRepGraph+Attributes.swift` is pure Swift, so there is no bridge symbol to shadow. Each edit
below wraps one statement in `SX.on("A_...")` (SX lives in the shadow file, same module). Every
anchor is asserted to occur exactly once before anything is written
(okf/references/injection-sweep-mechanics.md, "Resolve every anchor uniquely").

usage: python3 inject.py apply        (run from the repo root)
Restore with `git checkout -- Sources/OCCTSwift/BRepGraph+Attributes.swift Sources/OCCTSwift/GDTWrite.swift`, never by reverse
replacement.
"""
import pathlib
import sys

PATH = pathlib.Path("Sources/OCCTSwift/BRepGraph+Attributes.swift")
GDT_PATH = pathlib.Path("Sources/OCCTSwift/GDTWrite.swift")
GDT_EDITS = [
    ("            OCCTDocumentSetDimensionModifiers(", "            SXWSetDimensionModifiers("),
    ("            OCCTDocumentSetGeomToleranceModifiers(", "            SXWSetGeomToleranceModifiers("),
    ("            OCCTDocumentSetDatumModifiers(", "            SXWSetDatumModifiers("),
]

EDITS = [
    # store.set
    (
        "        storage[node, default: [:]][key] = value\n",
        "        if SX.on(\"A_SET_NOOP\") { return }\n"
        "        if SX.on(\"A_SET_FIRST_WINS\"), storage[node]?[key] != nil { return }\n"
        "        if SX.on(\"A_SET_BOOL_AS_INT\"), case .bool(let b) = value {\n"
        "            storage[node, default: [:]][key] = .int(b ? 1 : 0)\n            return\n        }\n"
        "        if SX.on(\"A_SET_DOUBLE_TRUNC\"), case .double(let d) = value {\n"
        "            storage[node, default: [:]][key] = .double(d.rounded(.towardZero))\n            return\n        }\n"
        "        if SX.on(\"A_SET_REPLACES_NODE\") { storage[node] = [key: value]; return }\n"
        "        storage[node, default: [:]][key] = value\n",
    ),
    # store.value
    (
        "        storage[node]?[key]\n    }\n\n    /// Set one attribute.",
        "        if SX.on(\"A_VALUE_NIL\") { return nil }\n"
        "        if SX.on(\"A_VALUE_IGNORES_KIND\") {\n"
        "            return storage.first { $0.key.index == node.index && $0.value[key] != nil }?.value[key]\n        }\n"
        "        if SX.on(\"A_VALUE_ANY_KEY\") { return storage[node]?[key] ?? storage[node]?.values.first }\n"
        "        if SX.on(\"A_VALUE_IGNORES_INDEX\") {\n"
        "            return storage.first { $0.key.kind == node.kind && $0.value[key] != nil }?.value[key]\n        }\n"
        "        return storage[node]?[key]\n    }\n\n    /// Set one attribute.",
    ),
    # store.clear
    (
        "        guard var attrs = storage[node] else { return }\n        attrs[key] = nil\n        storage[node] = attrs.isEmpty ? nil : attrs\n",
        "        if SX.on(\"A_CLEAR_NOOP\") { return }\n"
        "        if SX.on(\"A_CLEAR_ALL_OF_NODE\") { storage[node] = nil; return }\n"
        "        guard var attrs = storage[node] else { return }\n        attrs[key] = nil\n"
        "        if SX.on(\"A_CLEAR_KEEP_EMPTY\") { storage[node] = attrs; return }\n"
        "        if SX.on(\"A_CLEAR_ALL_NODES_KEY\") {\n"
        "            for n in Array(storage.keys) {\n                storage[n]?[key] = nil\n                if storage[n]?.isEmpty == true { storage[n] = nil }\n            }\n            return\n        }\n"
        "        storage[node] = attrs.isEmpty ? nil : attrs\n",
    ),
    # removeAll
    (
        "    public mutating func removeAll(for node: BRepGraph.NodeRef) {\n        storage[node] = nil\n",
        "    public mutating func removeAll(for node: BRepGraph.NodeRef) {\n"
        "        if SX.on(\"A_REMOVEALL_NOOP\") { return }\n"
        "        if SX.on(\"A_REMOVEALL_EVERYTHING\") { storage = [:]; return }\n"
        "        storage[node] = nil\n",
    ),
    # count
    (
        "    public var annotatedNodeCount: Int { storage.count }\n",
        "    public var annotatedNodeCount: Int {\n"
        "        if SX.on(\"A_COUNT_ATTRS\") { return storage.values.reduce(0) { $0 + $1.count } }\n"
        "        if SX.on(\"A_COUNT_PLUS1\") { return storage.count + 1 }\n"
        "        if SX.on(\"A_COUNT_MINUS1\") { return max(storage.count - 1, 0) }\n"
        "        if SX.on(\"A_COUNT_FACES_ONLY\") { return storage.keys.filter { $0.kind == .face }.count }\n"
        "        return storage.count\n    }\n",
    ),
    # encode ordering
    (
        "        var container = encoder.singleValueContainer()\n        try container.encode(entries)\n",
        "        var container = encoder.singleValueContainer()\n"
        "        if SX.on(\"A_ENC_NODE_REVERSE\") { try container.encode(Array(entries.reversed())); return }\n"
        "        if SX.on(\"A_ENC_KEY_REVERSE\") {\n"
        "            try container.encode(entries.map { Entry(node: $0.node, attrs: Array($0.attrs.reversed())) })\n            return\n        }\n"
        "        if SX.on(\"A_ENC_INDEX_FIRST\") {\n"
        "            try container.encode(entries.sorted { ($0.node.index, $0.node.kind.rawValue) < ($1.node.index, $1.node.kind.rawValue) })\n            return\n        }\n"
        "        if SX.on(\"A_ENC_DROP_LAST\") { try container.encode(Array(entries.dropLast())); return }\n"
        "        try container.encode(entries)\n",
    ),
    # decode
    (
        "        let entries = try container.decode([Entry].self)\n",
        "        var entries = try container.decode([Entry].self)\n"
        "        if SX.on(\"A_DEC_DROP_LAST\") && !entries.isEmpty { entries.removeLast() }\n"
        "        if SX.on(\"A_DEC_DROP_FIRST\") && !entries.isEmpty { entries.removeFirst() }\n",
    ),
    # canonical encoder
    (
        "        encoder.outputFormatting = [.sortedKeys]\n",
        "        encoder.outputFormatting = SX.on(\"A_CANON_UNSORTED\") ? [] : [.sortedKeys]\n",
    ),
    # snapshot()
    (
        "        return GraphSnapshot(brep: brep, attributes: attributes)\n",
        "        if SX.on(\"A_SNAP_NO_ATTRS\") { return GraphSnapshot(brep: brep, attributes: NodeAttributeStore()) }\n"
        "        if SX.on(\"A_SNAP_BAD_VERSION\") {\n"
        "            return GraphSnapshot(brep: brep, attributes: attributes, formatVersion: GraphSnapshot.currentFormatVersion + 1)\n        }\n"
        "        return GraphSnapshot(brep: brep, attributes: attributes)\n",
    ),
    # init(snapshot:)
    (
        "        guard snapshot.formatVersion <= GraphSnapshot.currentFormatVersion else {\n            throw GraphSnapshotError.unsupportedFormatVersion(snapshot.formatVersion)\n        }\n        guard let shape = Shape.fromBREPString(snapshot.brep) else {\n            throw GraphSnapshotError.invalidBREP\n        }\n        guard let handle = OCCTBRepGraphCreate(shape.handle, false) else {\n            throw GraphSnapshotError.graphBuildFailed\n        }\n        self.init(borrowedHandle: handle)\n        self.sourceBREP = snapshot.brep\n        self.attributes = snapshot.attributes\n",
        "        if SX.on(\"A_VER_WRONG_ERROR\") && snapshot.formatVersion > GraphSnapshot.currentFormatVersion {\n            throw GraphSnapshotError.invalidBREP\n        }\n"
        "        if SX.on(\"A_VER_WRONG_PAYLOAD\") && snapshot.formatVersion > GraphSnapshot.currentFormatVersion {\n            throw GraphSnapshotError.unsupportedFormatVersion(GraphSnapshot.currentFormatVersion)\n        }\n"
        "        let versionOK: Bool\n"
        "        if SX.on(\"A_VER_LT\") { versionOK = snapshot.formatVersion < GraphSnapshot.currentFormatVersion }\n"
        "        else if SX.on(\"A_VER_OFF\") { versionOK = true }\n"
        "        else if SX.on(\"A_VER_PLUS1_OK\") { versionOK = snapshot.formatVersion <= GraphSnapshot.currentFormatVersion + 1 }\n"
        "        else { versionOK = snapshot.formatVersion <= GraphSnapshot.currentFormatVersion }\n"
        "        guard versionOK else {\n            throw GraphSnapshotError.unsupportedFormatVersion(snapshot.formatVersion)\n        }\n"
        "        guard let shape = Shape.fromBREPString(snapshot.brep) else {\n            throw SX.on(\"A_BREP_WRONG_ERROR\") ? GraphSnapshotError.graphBuildFailed : GraphSnapshotError.invalidBREP\n        }\n"
        "        guard let handle = OCCTBRepGraphCreate(shape.handle, SX.on(\"A_RESTORE_PARALLEL\")) else {\n            throw GraphSnapshotError.graphBuildFailed\n        }\n"
        "        self.init(borrowedHandle: handle)\n"
        "        if !SX.on(\"A_RESTORE_NO_SOURCE\") { self.sourceBREP = snapshot.brep }\n"
        "        if !SX.on(\"A_RESTORE_NO_ATTRS\") { self.attributes = snapshot.attributes }\n"
        "        if SX.on(\"A_RESTORE_FIRST_NODE_ONLY\"), let k = snapshot.attributes.storage.keys.sorted(by: { ($0.kind.rawValue, $0.index) < ($1.kind.rawValue, $1.index) }).first {\n"
        "            self.attributes = NodeAttributeStore(storage: [k: snapshot.attributes.storage[k] ?? [:]])\n        }\n",
    ),
]


def main():
    if sys.argv[1:] != ["apply"]:
        sys.exit(__doc__)
    text = PATH.read_text(encoding="utf-8")
    for i, (old, _new) in enumerate(EDITS):
        n = text.count(old)
        if n != 1:
            sys.exit(f"edit {i}: anchor matches {n} times, expected 1: {old[:70]!r}")
    for old, new in EDITS:
        text = text.replace(old, new)
    PATH.write_text(text, encoding="utf-8")
    print(f"applied {len(EDITS)} edits to {PATH}")
    gdt = GDT_PATH.read_text(encoding="utf-8")
    for old, _new in GDT_EDITS:
        n = gdt.count(old)
        if n != 1:
            sys.exit(f"GDT anchor matches {n} times, expected 1: {old!r}")
    for old, new in GDT_EDITS:
        gdt = gdt.replace(old, new)
    GDT_PATH.write_text(gdt, encoding="utf-8")
    print(f"applied {len(GDT_EDITS)} edits to {GDT_PATH}")


main()
