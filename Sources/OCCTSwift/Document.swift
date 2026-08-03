import Foundation
import simd
import OCCTBridge

/// XDE Document for loading STEP files with assembly structure, names, colors, and materials
///
/// Use `Document` when you need to:
/// - Preserve assembly hierarchy from STEP files
/// - Access part names and structure
/// - Read colors and PBR materials
/// - Export with metadata preserved
///
/// For simple geometry-only import, use `Shape.load(from:)` instead.
public final class Document: @unchecked Sendable {
    internal let handle: OCCTDocumentRef

    internal init(handle: OCCTDocumentRef) {
        self.handle = handle
    }

    deinit {
        // Must happen before this instance's memory can be recycled — the construction-context
        // association is keyed on the instance pointer (#277).
        releaseConstructionContext()
        OCCTDocumentRelease(handle)
    }

    // MARK: - Loading

    /// Load a STEP file with full XDE support (assembly structure, names, colors, materials)
    ///
    /// - Parameter url: URL to the STEP file
    /// - Returns: Document containing the assembly structure
    /// - Throws: `DocumentError` if loading fails
    public static func load(from url: URL, progress: ImportProgress? = nil) throws -> Document {
        var cancelled: Bool = false
        let handle: OCCTDocumentRef? = withImportProgress(progress) { ctx in
            OCCTDocumentLoadSTEPProgress(url.path, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        guard let handle else {
            throw DocumentError.loadFailed(url: url)
        }
        return Document(handle: handle)
    }

    /// Load a STEP file as an XCAF document with optional progress + cancellation.
    /// Alias for ``load(from:progress:)`` with explicit naming.
    public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Document {
        try load(from: url, progress: progress)
    }

    /// Write the document to a STEP file with progress + cancellation.
    ///
    /// - Throws: `ImportError.cancelled` if cancelled cooperatively,
    ///   `ImportError.importFailed` on other failure (the case name reuses
    ///   `ImportError` because we share the cancellation channel — see #98).
    public func writeSTEP(to url: URL, progress: ImportProgress?) throws {
        var cancelled: Bool = false
        let success: Bool = withImportProgress(progress) { ctx in
            OCCTDocumentWriteSTEPProgress(handle, url.path, ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        if !success {
            throw ImportError.importFailed("STEP write to \(url.lastPathComponent) failed")
        }
    }

    /// Create a new empty document
    public static func create() -> Document? {
        guard let handle = OCCTDocumentCreate() else {
            return nil
        }
        return Document(handle: handle)
    }

    // MARK: - Assembly Structure

    /// Get the root nodes (top-level/free shapes) in the document
    public var rootNodes: [AssemblyNode] {
        let count = OCCTDocumentGetRootCount(handle)
        var nodes: [AssemblyNode] = []
        nodes.reserveCapacity(Int(count))

        for i in 0..<count {
            let labelId = OCCTDocumentGetRootLabelId(handle, i)
            if labelId >= 0 {
                nodes.append(AssemblyNode(document: self, labelId: labelId))
            }
        }

        return nodes
    }

    /// Look up an `AssemblyNode` by its XCAF labelId.
    ///
    /// Returns `nil` if `labelId` does not refer to a label in this document.
    /// LabelIds are stable within a single `Document` instance — a labelId
    /// obtained from `rootNodes` traversal can be passed back here later in
    /// the same session to recover the corresponding node.
    public func node(at labelId: Int64) -> AssemblyNode? {
        // Warm up the labelId registry. On a freshly-loaded document the
        // table is empty until something walks the assembly — iterating the
        // roots here registers the top-level labels so callers don't have
        // to know to touch `rootNodes` first. Deep child labelIds are
        // expected to have been registered earlier by an explicit traversal
        // (e.g. via `node.children`); this method only guarantees that
        // labelIds reachable from the roots resolve correctly.
        let rootCount = OCCTDocumentGetRootCount(handle)
        for i in 0..<rootCount {
            _ = OCCTDocumentGetRootLabelId(handle, i)
        }
        guard !OCCTDocumentLabelIsNull(handle, labelId) else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    // MARK: - Convenience Methods

    /// Get all shapes from the document as a flat list
    public func allShapes() -> [Shape] {
        var shapes: [Shape] = []
        collectShapes(from: rootNodes, into: &shapes)
        return shapes
    }

    /// Get all shapes with their associated colors
    public func shapesWithColors() -> [(shape: Shape, color: Color?)] {
        var results: [(Shape, Color?)] = []
        collectShapesWithColors(from: rootNodes, into: &results)
        return results
    }

    /// Get all shapes with their associated PBR materials
    public func shapesWithMaterials() -> [(shape: Shape, material: Material?)] {
        var results: [(Shape, Material?)] = []
        collectShapesWithMaterials(from: rootNodes, into: &results)
        return results
    }

    private func collectShapes(from nodes: [AssemblyNode], into shapes: inout [Shape]) {
        for node in nodes {
            if let shape = node.shape {
                shapes.append(shape)
            }
            collectShapes(from: node.children, into: &shapes)
        }
    }

    private func collectShapesWithColors(from nodes: [AssemblyNode], into results: inout [(Shape, Color?)]) {
        for node in nodes {
            if let shape = node.shape {
                results.append((shape, node.color))
            }
            collectShapesWithColors(from: node.children, into: &results)
        }
    }

    private func collectShapesWithMaterials(from nodes: [AssemblyNode], into results: inout [(Shape, Material?)]) {
        for node in nodes {
            if let shape = node.shape {
                results.append((shape, node.material))
            }
            collectShapesWithMaterials(from: node.children, into: &results)
        }
    }

    // MARK: - Writing

    /// Write the document to a STEP file (preserves assembly structure, colors, materials)
    ///
    /// - Parameter url: Output file URL
    /// - Throws: `DocumentError` if writing fails
    public func write(to url: URL) throws {
        if !OCCTDocumentWriteSTEP(handle, url.path) {
            throw DocumentError.writeFailed(url: url)
        }
    }
}

// MARK: - AssemblyNode


// MARK: - GD&T / Dimensions and Tolerances (v0.21.0)




extension Document {
    /// Number of dimensions defined in this document
    public var dimensionCount: Int {
        Int(OCCTDocumentGetDimensionCount(handle))
    }

    /// Number of geometric tolerances defined in this document
    public var geomToleranceCount: Int {
        Int(OCCTDocumentGetGeomToleranceCount(handle))
    }

    /// Number of datums defined in this document
    public var datumCount: Int {
        Int(OCCTDocumentGetDatumCount(handle))
    }

    /// Get dimension info at the given index
    public func dimension(at index: Int) -> DimensionInfo? {
        let info = OCCTDocumentGetDimensionInfo(handle, Int32(index))
        guard info.isValid else { return nil }
        return DimensionInfo(type: info.type, value: info.value,
                             lowerTolerance: info.lowerTol,
                             upperTolerance: info.upperTol)
    }

    /// Get geometric tolerance info at the given index
    public func geomTolerance(at index: Int) -> GeomToleranceInfo? {
        let info = OCCTDocumentGetGeomToleranceInfo(handle, Int32(index))
        guard info.isValid else { return nil }
        return GeomToleranceInfo(type: info.type, value: info.value)
    }

    /// Get datum info at the given index
    public func datum(at index: Int) -> DatumInfo? {
        var info = OCCTDocumentGetDatumInfo(handle, Int32(index))
        guard info.isValid else { return nil }
        let name = withUnsafeBytes(of: &info.name) { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return "" }
            let charPtr = baseAddress.assumingMemoryBound(to: CChar.self)
            return String(cString: charPtr)
        }
        return DatumInfo(name: name)
    }

    /// All dimensions in this document
    public var dimensions: [DimensionInfo] {
        (0..<dimensionCount).compactMap { dimension(at: $0) }
    }

    /// All geometric tolerances in this document
    public var geomTolerances: [GeomToleranceInfo] {
        (0..<geomToleranceCount).compactMap { geomTolerance(at: $0) }
    }

    /// All datums in this document
    public var datums: [DatumInfo] {
        (0..<datumCount).compactMap { datum(at: $0) }
    }
}

// MARK: - TNaming: Topological Naming (v0.25.0)



extension Document {

    /// Create a new label for naming history tracking
    ///
    /// - Parameter parent: Parent node (nil for document root)
    /// - Returns: Assembly node representing the new label, or nil on failure
    public func createLabel(parent: AssemblyNode? = nil) -> AssemblyNode? {
        let parentId = parent?.labelId ?? -1
        let labelId = OCCTDocumentCreateLabel(handle, parentId)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Record a naming evolution on a label
    ///
    /// - Parameters:
    ///   - node: The label to record on
    ///   - evolution: Type of topological evolution
    ///   - oldShape: Previous shape (nil for primitive)
    ///   - newShape: Result shape (nil for delete)
    /// - Returns: true if recording succeeded
    @discardableResult
    public func recordNaming(on node: AssemblyNode, evolution: NamingEvolution,
                             oldShape: Shape? = nil, newShape: Shape? = nil) -> Bool {
        OCCTDocumentNamingRecord(handle, node.labelId,
                                OCCTNamingEvolution(UInt32(evolution.rawValue)),
                                oldShape?.handle, newShape?.handle)
    }

    /// Get the current (most recent) shape on a label
    public func currentShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTDocumentNamingGetCurrentShape(handle, node.labelId) else { return nil }
        return Shape(handle: h)
    }

    /// Get the stored shape on a label
    public func storedShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTDocumentNamingGetShape(handle, node.labelId) else { return nil }
        return Shape(handle: h)
    }

    /// Get the naming evolution type on a label
    public func namingEvolution(on node: AssemblyNode) -> NamingEvolution? {
        let raw = OCCTDocumentNamingGetEvolution(handle, node.labelId)
        guard raw >= 0 else { return nil }
        return NamingEvolution(rawValue: raw)
    }

    /// Get the full naming history on a label
    public func namingHistory(on node: AssemblyNode) -> [NamingHistoryEntry] {
        let count = OCCTDocumentNamingHistoryCount(handle, node.labelId)
        guard count > 0 else { return [] }

        var entries: [NamingHistoryEntry] = []
        entries.reserveCapacity(Int(count))

        for i in 0..<count {
            var entry = OCCTNamingHistoryEntry()
            if OCCTDocumentNamingGetHistoryEntry(handle, node.labelId, i, &entry) {
                entries.append(NamingHistoryEntry(
                    evolution: NamingEvolution(rawValue: Int32(entry.evolution.rawValue)) ?? .primitive,
                    hasOldShape: entry.hasOldShape,
                    hasNewShape: entry.hasNewShape,
                    isModification: entry.isModification
                ))
            }
        }

        return entries
    }

    /// Get the old (input) shape from a history entry
    public func oldShape(on node: AssemblyNode, at index: Int) -> Shape? {
        guard let h = OCCTDocumentNamingGetOldShape(handle, node.labelId, Int32(index)) else { return nil }
        return Shape(handle: h)
    }

    /// Get the new (result) shape from a history entry
    public func newShape(on node: AssemblyNode, at index: Int) -> Shape? {
        guard let h = OCCTDocumentNamingGetNewShape(handle, node.labelId, Int32(index)) else { return nil }
        return Shape(handle: h)
    }

    /// Trace forward: find shapes generated/modified from the given shape
    ///
    /// - Parameters:
    ///   - shape: The source shape to trace from
    ///   - scope: A label providing document scope for the search
    /// - Returns: Array of shapes that were generated/modified from the source
    public func tracedForward(from shape: Shape, scope: AssemblyNode) -> [Shape] {
        let maxCount: Int32 = 64
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(maxCount))
        let count = OCCTDocumentNamingTraceForward(handle, scope.labelId, shape.handle,
                                                    &handles, maxCount)
        return (0..<Int(count)).compactMap { handles[$0].map { Shape(handle: $0) } }
    }

    /// Trace backward: find shapes that generated/preceded the given shape
    ///
    /// - Parameters:
    ///   - shape: The shape to trace back from
    ///   - scope: A label providing document scope for the search
    /// - Returns: Array of shapes that preceded the given shape
    public func tracedBackward(from shape: Shape, scope: AssemblyNode) -> [Shape] {
        let maxCount: Int32 = 64
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(maxCount))
        let count = OCCTDocumentNamingTraceBackward(handle, scope.labelId, shape.handle,
                                                     &handles, maxCount)
        return (0..<Int(count)).compactMap { handles[$0].map { Shape(handle: $0) } }
    }

    /// Create a persistent named selection
    ///
    /// - Parameters:
    ///   - selection: The shape to select
    ///   - context: The context shape containing the selection
    ///   - node: The label to store the selection on
    /// - Returns: true if selection succeeded
    @discardableResult
    public func selectShape(_ selection: Shape, context: Shape, on node: AssemblyNode) -> Bool {
        OCCTDocumentNamingSelect(handle, node.labelId, selection.handle, context.handle)
    }

    /// Resolve a previously selected shape after modifications
    ///
    /// - Parameter node: The label containing the selection
    /// - Returns: The resolved shape, or nil on failure
    public func resolveShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTDocumentNamingResolve(handle, node.labelId) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Errors


// MARK: - Length Unit (v0.30.0)


extension Document {
    /// Get the length unit of this document.
    ///
    /// Returns the unit scale and name stored in the STEP file.
    /// Common values: 1.0 = mm, 10.0 = cm, 1000.0 = m, 25.4 = inch.
    public var lengthUnit: LengthUnit? {
        var scale: Double = 0
        var nameBuf = [CChar](repeating: 0, count: 64)
        guard OCCTDocumentGetLengthUnit(handle, &scale, &nameBuf, 64) else { return nil }
        let name = nameBuf.withUnsafeBufferPointer { buf in
            String(decoding: buf.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        return LengthUnit(scale: scale, name: name)
    }
}

// MARK: - Layers (v0.31.0)

extension Document {
    /// Number of layers in this document.
    public var layerCount: Int {
        Int(OCCTDocumentGetLayerCount(handle))
    }

    /// Get the name of a layer by index.
    ///
    /// - Parameter index: Zero-based layer index
    /// - Returns: Layer name, or nil if index is out of range
    public func layerName(at index: Int) -> String? {
        var buf = [CChar](repeating: 0, count: 256)
        guard OCCTDocumentGetLayerName(handle, Int32(index), &buf, 256) else { return nil }
        return buf.withUnsafeBufferPointer { ptr in
            String(decoding: ptr.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
    }

    /// All layer names in this document.
    public var layerNames: [String] {
        (0..<layerCount).compactMap { layerName(at: $0) }
    }
}

// MARK: - Materials (v0.31.0)


extension Document {
    /// Number of materials in this document.
    public var materialCount: Int {
        Int(OCCTDocumentGetMaterialCount(handle))
    }

    /// Get material info by index.
    ///
    /// - Parameter index: Zero-based material index
    /// - Returns: Material info, or nil if index is out of range
    public func materialInfo(at index: Int) -> MaterialInfo? {
        var info = OCCTMaterialInfo()
        guard OCCTDocumentGetMaterialInfo(handle, Int32(index), &info) else { return nil }
        let name = withUnsafePointer(to: info.name) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 128) { buf in
                String(cString: buf)
            }
        }
        let desc = withUnsafePointer(to: info.description) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 256) { buf in
                String(cString: buf)
            }
        }
        return MaterialInfo(name: name, description: desc, density: info.density)
    }

    /// All materials in this document.
    public var materials: [MaterialInfo] {
        (0..<materialCount).compactMap { materialInfo(at: $0) }
    }
}

// MARK: - TDF Label Properties (v0.54.0)


// MARK: - TDF Reference (v0.54.0)


// MARK: - TDF CopyLabel (v0.54.0)

extension Document {
    /// Copy a label and all its attributes to a destination label.
    ///
    /// - Parameters:
    ///   - source: The source label to copy from
    ///   - destination: The destination label to copy to
    /// - Returns: true if the copy succeeded
    @discardableResult
    public func copyLabel(from source: AssemblyNode, to destination: AssemblyNode) -> Bool {
        OCCTDocumentCopyLabel(handle, source.labelId, destination.labelId)
    }
}

// MARK: - Document Main Label (v0.54.0)

extension Document {
    /// The main label (0:1) of the document — the root of the user data tree.
    public var mainLabel: AssemblyNode? {
        let labelId = OCCTDocumentGetMainLabel(handle)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }
}

// MARK: - Document Transactions (v0.54.0)

extension Document {
    /// Open a new transaction (command) on the document.
    ///
    /// All changes made after this call can be committed or aborted.
    public func openTransaction() {
        OCCTDocumentOpenTransaction(handle)
    }

    /// Commit the current transaction.
    ///
    /// - Returns: true if committed successfully
    @discardableResult
    public func commitTransaction() -> Bool {
        OCCTDocumentCommitTransaction(handle)
    }

    /// Abort the current transaction, undoing all changes since openTransaction().
    public func abortTransaction() {
        OCCTDocumentAbortTransaction(handle)
    }

    /// Whether a transaction is currently open.
    public var hasOpenTransaction: Bool {
        OCCTDocumentHasOpenTransaction(handle)
    }
}

// MARK: - Document Undo/Redo (v0.54.0)

extension Document {
    /// Set the maximum number of undo steps.
    ///
    /// Must be called before any transactions. Set to 0 to disable undo.
    public func setUndoLimit(_ limit: Int) {
        OCCTDocumentSetUndoLimit(handle, Int32(limit))
    }

    /// The maximum number of undo steps.
    public var undoLimit: Int {
        Int(OCCTDocumentGetUndoLimit(handle))
    }

    /// Perform undo (reverses the last committed transaction).
    ///
    /// - Returns: true if undo was performed
    @discardableResult
    public func undo() -> Bool {
        OCCTDocumentUndo(handle)
    }

    /// Perform redo (reapplies the last undone transaction).
    ///
    /// - Returns: true if redo was performed
    @discardableResult
    public func redo() -> Bool {
        OCCTDocumentRedo(handle)
    }

    /// The number of available undo steps.
    public var availableUndos: Int {
        Int(OCCTDocumentGetAvailableUndos(handle))
    }

    /// The number of available redo steps.
    public var availableRedos: Int {
        Int(OCCTDocumentGetAvailableRedos(handle))
    }
}

// MARK: - Document Modified Labels (v0.54.0)

extension Document {
    /// Mark a label as modified.
    public func setModified(_ node: AssemblyNode) {
        OCCTDocumentSetModified(handle, node.labelId)
    }

    /// Clear all modification marks.
    public func clearModified() {
        OCCTDocumentClearModified(handle)
    }

    /// Check if a label is marked as modified.
    public func isModified(_ node: AssemblyNode) -> Bool {
        OCCTDocumentIsLabelModified(handle, node.labelId)
    }
}

// MARK: - TDataStd Scalar Attributes (v0.55.0)


// MARK: - TDataStd Integer Array (v0.55.0)


// MARK: - TDataStd Real Array (v0.55.0)


// MARK: - TDataStd TreeNode (v0.55.0)


// MARK: - TDataStd NamedData (v0.55.0)


// MARK: - TDataXtd Shape Attribute (v0.56.0)




// MARK: - TFunction Logbook (v0.56.0)


// MARK: - TFunction GraphNode (v0.56.0)


// MARK: - TFunction Function Attribute (v0.56.0)


// MARK: - TNaming CopyShape (v0.56.0)

extension Shape {

    /// Create a deep copy of this shape (independent copy with new topology).
    public func deepCopy() -> Shape? {
        guard let ref = OCCTShapeDeepCopy(handle) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - PCDM Status Enums (v0.57.0)



// MARK: - OCAF Persistence (v0.57.0)

extension Document {

    // MARK: - Format Registration

    /// Register binary OCAF format drivers (BinOcaf).
    public func defineFormatBin() {
        OCCTDocumentDefineFormatBin(handle)
    }

    /// Register lite binary OCAF format drivers (BinLOcaf).
    public func defineFormatBinL() {
        OCCTDocumentDefineFormatBinL(handle)
    }

    /// Register XML OCAF format drivers (XmlOcaf).
    public func defineFormatXml() {
        OCCTDocumentDefineFormatXml(handle)
    }

    /// Register lite XML OCAF format drivers (XmlLOcaf).
    public func defineFormatXmlL() {
        OCCTDocumentDefineFormatXmlL(handle)
    }

    /// Register binary XCAF format drivers (BinXCAF).
    public func defineFormatBinXCAF() {
        OCCTDocumentDefineFormatBinXCAF(handle)
    }

    /// Register XML XCAF format drivers (XmlXCAF).
    public func defineFormatXmlXCAF() {
        OCCTDocumentDefineFormatXmlXCAF(handle)
    }

    /// Register all available persistence format drivers.
    public func defineAllFormats() {
        defineFormatBin()
        defineFormatBinL()
        defineFormatXml()
        defineFormatXmlL()
        defineFormatBinXCAF()
        defineFormatXmlXCAF()
    }

    // MARK: - Save/Load

    /// Save the OCAF document to a file. Format is determined by storage format.
    /// Call `defineAllFormats()` or specific format registration before saving.
    public func saveOCAF(to path: String) -> StoreStatus {
        let raw = OCCTDocumentSaveOCAF(handle, path)
        return StoreStatus(rawValue: raw) ?? .failure
    }

    /// Save the OCAF document to the path it was previously saved to.
    public func saveOCAFInPlace() -> StoreStatus {
        let raw = OCCTDocumentSaveOCAFInPlace(handle)
        return StoreStatus(rawValue: raw) ?? .failure
    }

    /// Load an OCAF document from a file. Registers all format drivers automatically.
    public static func loadOCAF(from path: String) -> (document: Document?, status: ReaderStatus) {
        var statusRaw: Int32 = -1
        guard let ref = OCCTDocumentLoadOCAF(path, &statusRaw) else {
            return (nil, ReaderStatus(rawValue: statusRaw) ?? .openError)
        }
        return (Document(handle: ref), ReaderStatus(rawValue: statusRaw) ?? .ok)
    }

    /// Create a new document with a specific OCAF format.
    /// Supported: "BinOcaf", "XmlOcaf", "BinLOcaf", "XmlLOcaf", "BinXCAF", "XmlXCAF".
    public static func create(format: String) -> Document? {
        guard let ref = OCCTDocumentCreateWithFormat(format) else { return nil }
        return Document(handle: ref)
    }

    // MARK: - Document Metadata

    /// Whether the document has been previously saved.
    public var isSaved: Bool {
        OCCTDocumentIsSaved(handle)
    }

    /// The storage format of the document (e.g. "MDTV-XCAF", "BinOcaf").
    public var storageFormat: String? {
        guard let cStr = OCCTDocumentGetStorageFormat(handle) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Change the storage format of the document.
    @discardableResult
    public func setStorageFormat(_ format: String) -> Bool {
        OCCTDocumentSetStorageFormat(handle, format)
    }

    /// Number of documents in the application session.
    public var documentCount: Int32 {
        OCCTDocumentNbDocuments(handle)
    }

    /// Get the list of available reading formats.
    public var readingFormats: [String] {
        var buffers = [UnsafePointer<CChar>?](repeating: nil, count: 20)
        let count = OCCTDocumentReadingFormats(handle, &buffers, 20)
        var result: [String] = []
        for i in 0..<Int(count) {
            if let cStr = buffers[i] {
                result.append(String(cString: cStr))
                OCCTStringFree(cStr)
            }
        }
        return result
    }

    /// Get the list of available writing formats.
    public var writingFormats: [String] {
        var buffers = [UnsafePointer<CChar>?](repeating: nil, count: 20)
        let count = OCCTDocumentWritingFormats(handle, &buffers, 20)
        var result: [String] = []
        for i in 0..<Int(count) {
            if let cStr = buffers[i] {
                result.append(String(cString: cStr))
                OCCTStringFree(cStr)
            }
        }
        return result
    }

    // MARK: - STEP Mode-Controlled Import/Export (v0.58.0)

    /// Load a STEP file with individual mode control for what data to import.
    ///
    /// Unlike `Document.load(from:)` which enables all modes, this allows fine-grained
    /// control over which data types are imported from the STEP file.
    ///
    /// - Parameters:
    ///   - url: URL to the STEP file
    ///   - modes: Reader mode flags controlling which data to import
    /// - Returns: Document with the requested data, or nil on failure
    public static func loadSTEP(from url: URL, modes: STEPReaderModes) -> Document? {
        guard let ref = OCCTDocumentLoadSTEPWithModes(url.path,
            modes.color, modes.name, modes.layer,
            modes.props, modes.gdt, modes.material) else { return nil }
        return Document(handle: ref)
    }

    /// Load a STEP file with individual mode control for what data to import.
    public static func loadSTEP(fromPath path: String, modes: STEPReaderModes) -> Document? {
        guard let ref = OCCTDocumentLoadSTEPWithModes(path,
            modes.color, modes.name, modes.layer,
            modes.props, modes.gdt, modes.material) else { return nil }
        return Document(handle: ref)
    }

    /// Load a STEP file with individual mode control plus progress + cancellation.
    ///
    /// Throws `ImportError.cancelled` if cancelled, `ImportError.importFailed` on other failure.
    public static func loadSTEP(from url: URL, modes: STEPReaderModes, progress: ImportProgress?) throws -> Document {
        var cancelled: Bool = false
        let handle: OCCTDocumentRef? = withImportProgress(progress) { ctx in
            OCCTDocumentLoadSTEPWithModesProgress(url.path,
                modes.color, modes.name, modes.layer,
                modes.props, modes.gdt, modes.material,
                ctx, &cancelled)
        }
        if cancelled { throw ImportError.cancelled }
        guard let handle else {
            throw ImportError.importFailed("Failed to load STEP document: \(url.lastPathComponent)")
        }
        return Document(handle: handle)
    }

    /// Write the document to a STEP file with model type and mode control.
    ///
    /// - Parameters:
    ///   - url: Output file URL
    ///   - modelType: STEP representation type (default: .asIs)
    ///   - modes: Writer mode flags controlling which data to export
    /// - Returns: true on success
    @discardableResult
    public func writeSTEP(to url: URL, modelType: StepModelType = .asIs, modes: STEPWriterModes = STEPWriterModes()) -> Bool {
        OCCTDocumentWriteSTEPWithModes(handle, url.path,
            modelType.rawValue,
            modes.color, modes.name, modes.layer,
            modes.dimTol, modes.material)
    }

    /// Write the document to a STEP file with model type and mode control.
    @discardableResult
    public func writeSTEP(toPath path: String, modelType: StepModelType = .asIs, modes: STEPWriterModes = STEPWriterModes()) -> Bool {
        OCCTDocumentWriteSTEPWithModes(handle, path,
            modelType.rawValue,
            modes.color, modes.name, modes.layer,
            modes.dimTol, modes.material)
    }
}

// MARK: - STEP Model Type (v0.58.0)


// MARK: - STEP Reader/Writer Modes (v0.58.0)



// MARK: - OBJ/PLY Document I/O (v0.59.0)

extension Document {

    /// Load an OBJ file into an XDE document (preserves materials, names).
    public static func loadOBJ(from url: URL) -> Document? {
        guard let ref = OCCTDocumentLoadOBJ(url.path) else { return nil }
        return Document(handle: ref)
    }

    /// Load an OBJ file into an XDE document (preserves materials, names).
    public static func loadOBJ(fromPath path: String) -> Document? {
        guard let ref = OCCTDocumentLoadOBJ(path) else { return nil }
        return Document(handle: ref)
    }

    /// Load an OBJ file with options.
    ///
    /// - Parameters:
    ///   - url: URL to the OBJ file
    ///   - singlePrecision: Use single precision for vertex data (default: false)
    ///   - systemLengthUnit: System length unit in meters (e.g. 0.001 for mm). 0 = default.
    public static func loadOBJ(from url: URL, singlePrecision: Bool, systemLengthUnit: Double = 0) -> Document? {
        guard let ref = OCCTDocumentLoadOBJWithOptions(url.path, singlePrecision, systemLengthUnit) else { return nil }
        return Document(handle: ref)
    }

    /// Load an OBJ file with coordinate system conversion.
    ///
    /// - Parameters:
    ///   - url: URL to the OBJ file
    ///   - inputCS: Input coordinate system
    ///   - outputCS: Output coordinate system
    ///   - inputLengthUnit: Input length unit in meters (0 = default)
    ///   - outputLengthUnit: Output length unit in meters (0 = default)
    public static func loadOBJ(from url: URL, inputCS: MeshCoordinateSystem, outputCS: MeshCoordinateSystem,
                                inputLengthUnit: Double = 0, outputLengthUnit: Double = 0) -> Document? {
        guard let ref = OCCTDocumentLoadOBJWithCS(url.path,
            inputCS.rawValue, outputCS.rawValue,
            inputLengthUnit, outputLengthUnit) else { return nil }
        return Document(handle: ref)
    }

    /// Write the document to an OBJ file.
    ///
    /// - Parameters:
    ///   - url: Output file URL
    ///   - deflection: Mesh deflection for tessellation (0 = skip re-meshing)
    /// - Returns: true on success
    @discardableResult
    public func writeOBJ(to url: URL, deflection: Double = 1.0) -> Bool {
        OCCTDocumentWriteOBJ(handle, url.path, deflection)
    }

    /// Write the document to a PLY file with options.
    ///
    /// - Parameters:
    ///   - url: Output file URL
    ///   - deflection: Mesh deflection for tessellation (0 = skip re-meshing)
    ///   - normals: Include normals (default: true)
    ///   - colors: Include colors (default: false)
    ///   - texCoords: Include texture coordinates (default: false)
    /// - Returns: true on success
    @discardableResult
    public func writePLY(to url: URL, deflection: Double = 1.0,
                          normals: Bool = true, colors: Bool = false, texCoords: Bool = false) -> Bool {
        OCCTDocumentWritePLY(handle, url.path, deflection, normals, colors, texCoords)
    }
}

// MARK: - Mesh Coordinate System (v0.59.0)


// MARK: - XDE ShapeTool Expansion (v0.60.0)

extension Document {
    /// Total number of shapes in the document (all levels).
    public var shapeCount: Int32 {
        OCCTDocumentGetShapeCount(handle)
    }

    /// Get label ID for a shape at index (from all shapes).
    public func shapeLabelId(at index: Int32) -> Int64 {
        OCCTDocumentGetShapeLabelId(handle, index)
    }

    /// Number of free (top-level) shapes.
    public var freeShapeCount: Int32 {
        OCCTDocumentGetFreeShapeCount(handle)
    }

    /// Get label ID for a free shape at index.
    public func freeShapeLabelId(at index: Int32) -> Int64 {
        OCCTDocumentGetFreeShapeLabelId(handle, index)
    }

    /// Add a shape to the document.
    /// - Parameters:
    ///   - shape: The shape to add
    ///   - makeAssembly: If true, compound shapes become assemblies
    /// - Returns: Label ID of the added shape, or -1 on failure
    @discardableResult
    public func addShape(_ shape: Shape, makeAssembly: Bool = true) -> Int64 {
        OCCTDocumentAddShape(handle, shape.handle, makeAssembly)
    }

    /// Create a new empty shape label.
    /// - Returns: Label ID of the new label, or -1 on failure
    public func newShapeLabel() -> Int64 {
        OCCTDocumentNewShape(handle)
    }

    /// Remove a shape from the document.
    /// - Parameter labelId: Label ID of the shape to remove
    /// - Returns: true if removed successfully
    @discardableResult
    public func removeShape(labelId: Int64) -> Bool {
        OCCTDocumentRemoveShape(handle, labelId)
    }

    /// Find label ID for a given shape in the document.
    /// - Returns: Label ID, or -1 if not found
    public func findShape(_ shape: Shape) -> Int64 {
        OCCTDocumentFindShape(handle, shape.handle)
    }

    /// Search for a shape in the document (including sub-shapes).
    /// - Returns: Label ID, or -1 if not found
    public func searchShape(_ shape: Shape) -> Int64 {
        OCCTDocumentSearchShape(handle, shape.handle)
    }

    /// Add a component to an assembly with translation.
    /// - Parameters:
    ///   - assemblyLabelId: Assembly label ID
    ///   - shapeLabelId: Shape to add as component
    ///   - translation: Translation (tx, ty, tz)
    /// - Returns: Component label ID, or -1 on failure
    @discardableResult
    public func addComponent(assemblyLabelId: Int64, shapeLabelId: Int64,
                              translation: (Double, Double, Double) = (0, 0, 0)) -> Int64 {
        OCCTDocumentAddComponent(handle, assemblyLabelId, shapeLabelId,
                                  translation.0, translation.1, translation.2)
    }

    /// Add a component occurrence with a FULL rigid placement, from a 12-element row-major matrix
    /// `[r00 r01 r02 r10 r11 r12 r20 r21 r22 tx ty tz]`. Returns the component label id, or -1 if the
    /// matrix isn't a proper rigid transform (a reflection — bake a mirrored product instead). #174.
    @discardableResult
    public func addComponent(assemblyLabelId: Int64, shapeLabelId: Int64, matrix: [Double]) -> Int64 {
        guard matrix.count == 12 else { return -1 }
        return matrix.withUnsafeBufferPointer {
            OCCTDocumentAddComponentMatrix(handle, assemblyLabelId, shapeLabelId, $0.baseAddress!)
        }
    }

    /// Remove a component from an assembly.
    public func removeComponent(labelId: Int64) {
        OCCTDocumentRemoveComponent(handle, labelId)
    }

    /// Get number of components in an assembly.
    public func componentCount(assemblyLabelId: Int64) -> Int32 {
        OCCTDocumentGetComponentCount(handle, assemblyLabelId)
    }

    /// Get component label ID at index.
    public func componentLabelId(assemblyLabelId: Int64, at index: Int32) -> Int64 {
        OCCTDocumentGetComponentLabelId(handle, assemblyLabelId, index)
    }

    /// Get the referred (original) shape label for a component.
    /// - Returns: Referred label ID, or -1 if not a reference
    public func componentReferredLabelId(_ componentLabelId: Int64) -> Int64 {
        OCCTDocumentGetComponentReferredLabelId(handle, componentLabelId)
    }

    /// Get number of labels that reference a given shape.
    public func shapeUserCount(shapeLabelId: Int64) -> Int32 {
        OCCTDocumentGetShapeUserCount(handle, shapeLabelId)
    }

    /// Update all assemblies (recompute compounds from components).
    public func updateAssemblies() {
        OCCTDocumentUpdateAssemblies(handle)
    }

    /// Expand a compound shape into an assembly (ShapeTool::Expand).
    @discardableResult
    public func expandShape(labelId: Int64) -> Bool {
        OCCTDocumentExpandShape(handle, labelId)
    }
}

// MARK: - XDE Label Queries (v0.60.0)


// MARK: - XDE ColorTool by Shape (v0.60.0)

extension Document {
    /// Set color on a shape directly (not by label).
    /// - Parameters:
    ///   - shape: The shape to color
    ///   - color: The color to set
    ///   - type: Color type — generic (0), surface (1), or curve (2)
    public func setShapeColor(_ shape: Shape, color: Color, type: OCCTColorType = OCCTColorTypeSurface) {
        OCCTDocumentSetShapeColor(handle, shape.handle, Int32(type.rawValue),
                                   color.red, color.green, color.blue)
    }

    /// Get color for a shape (not by label).
    /// - Parameters:
    ///   - shape: The shape to query
    ///   - type: Color type — generic (0), surface (1), or curve (2)
    /// - Returns: Color if set, nil otherwise
    public func shapeColor(_ shape: Shape, type: OCCTColorType = OCCTColorTypeSurface) -> Color? {
        let c = OCCTDocumentGetShapeColor(handle, shape.handle, Int32(type.rawValue))
        guard c.isSet else { return nil }
        return Color(red: c.r, green: c.g, blue: c.b, alpha: c.a)
    }

    /// Check if color is set on a shape.
    public func isShapeColorSet(_ shape: Shape, type: OCCTColorType = OCCTColorTypeSurface) -> Bool {
        OCCTDocumentIsShapeColorSet(handle, shape.handle, Int32(type.rawValue))
    }
}

// MARK: - XDE Area / Volume / Centroid (v0.60.0)


// MARK: - XDE LayerTool Expansion (v0.60.0)


extension Document {
    /// Find a layer label by name.
    /// - Returns: Label ID, or -1 if not found
    public func findLayer(_ name: String) -> Int64 {
        OCCTDocumentFindLayer(handle, name)
    }

    /// Set visibility for a layer label.
    public func setLayerVisibility(layerLabelId: Int64, visible: Bool) {
        OCCTDocumentSetLayerVisibility(handle, layerLabelId, visible)
    }

    /// Get visibility for a layer label.
    public func layerVisibility(layerLabelId: Int64) -> Bool {
        OCCTDocumentGetLayerVisibility(handle, layerLabelId)
    }
}

// MARK: - XDE Editor (v0.60.0)

extension Document {
    /// Expand a compound shape label into an assembly using XCAFDoc_Editor.
    /// - Parameters:
    ///   - labelId: Label of the compound to expand
    ///   - recursively: If true, expand recursively
    /// - Returns: true if expanded successfully
    @discardableResult
    public func editorExpand(labelId: Int64, recursively: Bool = true) -> Bool {
        OCCTDocumentEditorExpand(handle, labelId, recursively)
    }

    /// Rescale geometry on a label.
    /// - Parameters:
    ///   - labelId: Label to rescale
    ///   - scaleFactor: Scale factor
    ///   - forceIfNotRoot: Force rescale even if label is not root
    /// - Returns: true on success
    @discardableResult
    public func rescaleGeometry(labelId: Int64, scaleFactor: Double, forceIfNotRoot: Bool = false) -> Bool {
        OCCTDocumentEditorRescaleGeometry(handle, labelId, scaleFactor, forceIfNotRoot)
    }
}

// MARK: - XCAFDoc_Location (v0.83.0)


// MARK: - XCAFDoc_GraphNode (v0.83.0)


// MARK: - XCAFDoc_Color (v0.83.0)


// MARK: - XCAFDoc_Material (v0.83.0)


// MARK: - XCAFDoc_NoteComment / NoteBalloon / NoteBinData (v0.83.0)


// MARK: - XCAFDoc_NotesTool (v0.83.0)

extension Document {
    /// Get the number of notes via NotesTool.
    public var notesToolNoteCount: Int32 {
        OCCTDocumentNotesToolNbNotes(handle)
    }

    /// Create a comment note via NotesTool. Returns the note label node.
    public func notesToolCreateComment(userName: String, timeStamp: String, comment: String) -> AssemblyNode? {
        let labelId = OCCTDocumentNotesToolCreateComment(handle, userName, timeStamp, comment)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Create a balloon note via NotesTool. Returns the note label node.
    public func notesToolCreateBalloon(userName: String, timeStamp: String, comment: String) -> AssemblyNode? {
        let labelId = OCCTDocumentNotesToolCreateBalloon(handle, userName, timeStamp, comment)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Create a binary data note via NotesTool. Returns the note label node.
    public func notesToolCreateBinData(userName: String, timeStamp: String, title: String,
                                        mimeType: String, data: [UInt8]) -> AssemblyNode? {
        let labelId = data.withUnsafeBufferPointer { buf in
            OCCTDocumentNotesToolCreateBinData(handle, userName, timeStamp,
                                                title, mimeType, buf.baseAddress!, Int32(data.count))
        }
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Delete a note by its label node.
    @discardableResult
    public func notesToolDeleteNote(_ node: AssemblyNode) -> Bool {
        OCCTDocumentNotesToolDeleteNote(handle, node.labelId)
    }

    /// Delete all notes. Returns the number of deleted notes.
    @discardableResult
    public func notesToolDeleteAllNotes() -> Int32 {
        OCCTDocumentNotesToolDeleteAllNotes(handle)
    }

    /// Get the number of orphan notes.
    public var notesToolOrphanNoteCount: Int32 {
        OCCTDocumentNotesToolNbOrphanNotes(handle)
    }

    /// Delete all orphan notes. Returns the number of deleted notes.
    @discardableResult
    public func notesToolDeleteOrphanNotes() -> Int32 {
        OCCTDocumentNotesToolDeleteOrphanNotes(handle)
    }
}

// MARK: - XCAFDoc_ClippingPlaneTool (v0.83.0)

extension Document {
    /// Add a clipping plane. Returns the clipping plane label node.
    public func clippingPlaneToolAdd(originX: Double, originY: Double, originZ: Double,
                                      normalX: Double, normalY: Double, normalZ: Double,
                                      name: String, capping: Bool) -> AssemblyNode? {
        let labelId = OCCTDocumentClipPlaneToolAdd(handle,
                                                     originX, originY, originZ,
                                                     normalX, normalY, normalZ,
                                                     name, capping)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Get a clipping plane from a label.
    public func clippingPlaneToolGet(_ node: AssemblyNode) -> (originX: Double, originY: Double, originZ: Double,
                                                                normalX: Double, normalY: Double, normalZ: Double,
                                                                capping: Bool)? {
        var ox: Double = 0, oy: Double = 0, oz: Double = 0
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        var cap = false
        guard OCCTDocumentClipPlaneToolGet(handle, node.labelId, &ox, &oy, &oz, &nx, &ny, &nz, &cap) else { return nil }
        return (ox, oy, oz, nx, ny, nz, cap)
    }

    /// Check if a label is a clipping plane.
    public func clippingPlaneToolIsClipPlane(_ node: AssemblyNode) -> Bool {
        OCCTDocumentClipPlaneToolIsClipPlane(handle, node.labelId)
    }

    /// Remove a clipping plane.
    @discardableResult
    public func clippingPlaneToolRemove(_ node: AssemblyNode) -> Bool {
        OCCTDocumentClipPlaneToolRemove(handle, node.labelId)
    }
}

// MARK: - XCAFDoc_ShapeMapTool (v0.83.0)


// MARK: - XCAFDoc_AssemblyGraph (v0.83.0)


// MARK: - XCAFDoc_AssemblyItemId (v0.83.0)


// MARK: - XCAFView_Object (v0.83.0)


// MARK: - XCAFNoteObjects_NoteObject (v0.83.0)


// MARK: - XCAFPrs_Style (v0.83.0)


// MARK: - XCAFDoc_VisMaterialCommon (v0.83.0)


// MARK: - XCAFDoc_VisMaterialPBR (v0.83.0)


// =============================================================================
// MARK: - VrmlAPI, Directory, Variable, Expression, XLink, DimTol, DriverTable, TObj (v0.84.0)
// =============================================================================

// MARK: - VrmlAPI_Writer


extension Shape {
    /// Write shape to VRML file.
    /// - Parameters:
    ///   - url: File URL to write to (.wrl extension)
    ///   - version: VRML version (1 or 2, default 2)
    ///   - deflection: Mesh deflection for triangulation (default 0.01)
    ///   - representation: Visual representation mode (default .shaded)
    /// - Returns: true if successful
    @discardableResult
    public func writeVRML(to url: URL,
                          version: Int = 2,
                          deflection: Double = 0.01,
                          representation: VrmlRepresentation = .shaded) -> Bool {
        OCCTVrmlWriteShape(handle, url.path, Int32(version), deflection, representation.rawValue)
    }
}

extension Document {
    /// Write XDE document to VRML file with scale.
    /// - Parameters:
    ///   - url: File URL to write to (.wrl extension)
    ///   - scale: Scale factor (default 1.0)
    /// - Returns: true if successful
    @discardableResult
    public func writeVRML(to url: URL, scale: Double = 1.0) -> Bool {
        OCCTVrmlWriteDocument(handle, url.path, scale)
    }
}

// MARK: - TDataStd_Directory

extension Document {
    /// Create a new directory attribute on a label.
    /// - Parameter labelTag: Label child tag (0 = main label)
    @discardableResult
    public func createDirectory(at labelTag: Int = 0) -> Bool {
        OCCTDocumentDirectoryNew(handle, Int32(labelTag))
    }

    /// Check if a directory attribute exists on a label.
    public func hasDirectory(at labelTag: Int = 0) -> Bool {
        OCCTDocumentDirectoryFind(handle, Int32(labelTag))
    }

    /// Add a sub-directory under an existing directory.
    /// - Returns: Child label tag, or nil if failed
    public func addSubDirectory(under parentLabelTag: Int = 0) -> Int? {
        let tag = OCCTDocumentDirectoryAddSubDirectory(handle, Int32(parentLabelTag))
        return tag >= 0 ? Int(tag) : nil
    }

    /// Make an object label under a directory.
    /// - Returns: Child label tag, or nil if failed
    public func makeObjectLabel(under parentLabelTag: Int = 0) -> Int? {
        let tag = OCCTDocumentDirectoryMakeObjectLabel(handle, Int32(parentLabelTag))
        return tag >= 0 ? Int(tag) : nil
    }
}

// MARK: - TDataStd_Variable

extension Document {
    /// Set a variable attribute on a label.
    @discardableResult
    public func setVariable(at labelTag: Int) -> Bool {
        OCCTDocumentVariableSet(handle, Int32(labelTag))
    }

    /// Set variable name.
    @discardableResult
    public func setVariableName(_ name: String, at labelTag: Int) -> Bool {
        OCCTDocumentVariableSetName(handle, Int32(labelTag), name)
    }

    /// Get variable name.
    public func variableName(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentVariableGetName(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Set variable value.
    @discardableResult
    public func setVariableValue(_ value: Double, at labelTag: Int) -> Bool {
        OCCTDocumentVariableSetValue(handle, Int32(labelTag), value)
    }

    /// Get variable value.
    public func variableValue(at labelTag: Int) -> Double {
        OCCTDocumentVariableGetValue(handle, Int32(labelTag))
    }

    /// Check if variable has a value.
    public func variableIsValued(at labelTag: Int) -> Bool {
        OCCTDocumentVariableIsValued(handle, Int32(labelTag))
    }

    /// Set variable unit string.
    @discardableResult
    public func setVariableUnit(_ unit: String, at labelTag: Int) -> Bool {
        OCCTDocumentVariableSetUnit(handle, Int32(labelTag), unit)
    }

    /// Get variable unit string.
    public func variableUnit(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentVariableGetUnit(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Set variable constant flag.
    @discardableResult
    public func setVariableConstant(_ isConstant: Bool, at labelTag: Int) -> Bool {
        OCCTDocumentVariableSetConstant(handle, Int32(labelTag), isConstant)
    }

    /// Check if variable is constant.
    public func variableIsConstant(at labelTag: Int) -> Bool {
        OCCTDocumentVariableIsConstant(handle, Int32(labelTag))
    }

    /// Assign expression to variable on same label.
    @discardableResult
    public func assignExpression(at labelTag: Int) -> Bool {
        OCCTDocumentVariableAssignExpression(handle, Int32(labelTag))
    }

    /// Remove expression from variable.
    @discardableResult
    public func desassignExpression(at labelTag: Int) -> Bool {
        OCCTDocumentVariableDesassignExpression(handle, Int32(labelTag))
    }

    /// Check if variable has an assigned expression.
    public func variableIsAssigned(at labelTag: Int) -> Bool {
        OCCTDocumentVariableIsAssigned(handle, Int32(labelTag))
    }
}

// MARK: - TDataStd_Expression

extension Document {
    /// Set an expression attribute on a label.
    @discardableResult
    public func setExpression(at labelTag: Int) -> Bool {
        OCCTDocumentExpressionSet(handle, Int32(labelTag))
    }

    /// Set expression string.
    @discardableResult
    public func setExpressionString(_ expression: String, at labelTag: Int) -> Bool {
        OCCTDocumentExpressionSetString(handle, Int32(labelTag), expression)
    }

    /// Get expression string.
    public func expressionString(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentExpressionGetString(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Get expression name.
    public func expressionName(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentExpressionGetName(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }
}

// MARK: - TDocStd_XLink

extension Document {
    /// Set an external link attribute on a label.
    @discardableResult
    public func setXLink(at labelTag: Int) -> Bool {
        OCCTDocumentXLinkSet(handle, Int32(labelTag))
    }

    /// Set XLink document entry path.
    @discardableResult
    public func setXLinkDocumentEntry(_ entry: String, at labelTag: Int) -> Bool {
        OCCTDocumentXLinkSetDocumentEntry(handle, Int32(labelTag), entry)
    }

    /// Get XLink document entry path.
    public func xLinkDocumentEntry(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentXLinkGetDocumentEntry(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Set XLink label entry string.
    @discardableResult
    public func setXLinkLabelEntry(_ entry: String, at labelTag: Int) -> Bool {
        OCCTDocumentXLinkSetLabelEntry(handle, Int32(labelTag), entry)
    }

    /// Get XLink label entry string.
    public func xLinkLabelEntry(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentXLinkGetLabelEntry(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }
}

// MARK: - XCAFDimTolObjects_Tool

extension Document {
    /// Count of dimension objects via XCAFDimTolObjects_Tool.
    public var dimTolToolDimensionCount: Int {
        Int(OCCTDocumentDimTolDimensionCount(handle))
    }

    /// Count of geometric tolerance objects via XCAFDimTolObjects_Tool.
    public var dimTolToolToleranceCount: Int {
        Int(OCCTDocumentDimTolToleranceCount(handle))
    }
}

// MARK: - TPrsStd_DriverTable


// MARK: - TObj_Application


// =============================================================================
// MARK: - UnitsAPI, BinTools, Message, CoordSystem, IDFilter (v0.85.0)
// =============================================================================

// MARK: - UnitsAPI


// MARK: - BinTools Shape I/O

extension Shape {
    /// Write shape to binary data.
    public func toBinaryData() -> Data? {
        var length: Int32 = 0
        guard let ptr = OCCTBinToolsWriteShape(handle, &length) else { return nil }
        let data = Data(bytes: ptr, count: Int(length))
        free(UnsafeMutableRawPointer(mutating: ptr))
        return data
    }

    /// Read shape from binary data.
    public static func fromBinaryData(_ data: Data) -> Shape? {
        data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return nil }
            guard let ref = OCCTBinToolsReadShape(ptr, Int32(data.count)) else { return nil }
            return Shape(handle: ref)
        }
    }

    /// Write shape to binary file.
    @discardableResult
    public func writeBinary(to url: URL) -> Bool {
        OCCTBinToolsWriteShapeToFile(handle, url.path)
    }

    /// Read shape from binary file.
    public static func loadBinary(from url: URL) -> Shape? {
        guard let ref = OCCTBinToolsReadShapeFromFile(url.path) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - Message_Messenger


// MARK: - Message_Report


// MARK: - RWMesh_CoordinateSystemConverter




// MARK: - TDF_IDFilter


// MARK: - TDataStd_BooleanArray

public extension Document {
    /// Set a boolean array attribute on a label.
    func setBooleanArray(tag: Int, values: [Bool]) -> Bool {
        let cValues = values.map { $0 }
        return cValues.withUnsafeBufferPointer { buf in
            OCCTDocumentSetBooleanArray(handle, Int32(tag), 1, Int32(values.count),
                                         buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a boolean array attribute from a label.
    func booleanArray(tag: Int) -> [Bool]? {
        let count = OCCTDocumentGetBooleanArray(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var values = [Bool](repeating: false, count: Int(count))
        _ = values.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetBooleanArray(handle, Int32(tag), buf.baseAddress!, count)
        }
        return values
    }

    /// Check if a label has a boolean array attribute.
    func hasBooleanArray(tag: Int) -> Bool {
        OCCTDocumentHasBooleanArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_BooleanList

public extension Document {
    /// Set a boolean list attribute on a label.
    func setBooleanList(tag: Int, values: [Bool]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetBooleanList(handle, Int32(tag), buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a boolean list attribute from a label.
    func booleanList(tag: Int) -> [Bool]? {
        let count = OCCTDocumentGetBooleanList(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var values = [Bool](repeating: false, count: Int(count))
        _ = values.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetBooleanList(handle, Int32(tag), buf.baseAddress!, count)
        }
        return values
    }

    /// Append a value to a boolean list attribute.
    func booleanListAppend(tag: Int, value: Bool) -> Bool {
        OCCTDocumentBooleanListAppend(handle, Int32(tag), value)
    }

    /// Clear a boolean list attribute.
    func booleanListClear(tag: Int) -> Bool {
        OCCTDocumentBooleanListClear(handle, Int32(tag))
    }

    /// Check if a label has a boolean list attribute.
    func hasBooleanList(tag: Int) -> Bool {
        OCCTDocumentHasBooleanList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ByteArray

public extension Document {
    /// Set a byte array attribute on a label.
    func setByteArray(tag: Int, values: [UInt8]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetByteArray(handle, Int32(tag), 0, Int32(values.count - 1),
                                      buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a byte array attribute from a label.
    func byteArray(tag: Int) -> [UInt8]? {
        let count = OCCTDocumentGetByteArray(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var values = [UInt8](repeating: 0, count: Int(count))
        _ = values.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetByteArray(handle, Int32(tag), buf.baseAddress!, count)
        }
        return values
    }

    /// Check if a label has a byte array attribute.
    func hasByteArray(tag: Int) -> Bool {
        OCCTDocumentHasByteArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_IntegerList

public extension Document {
    /// Set an integer list attribute on a label.
    func setIntegerList(tag: Int, values: [Int32]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetIntegerList(handle, Int32(tag), buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get an integer list attribute from a label.
    func integerList(tag: Int) -> [Int32]? {
        let count = OCCTDocumentGetIntegerList(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var values = [Int32](repeating: 0, count: Int(count))
        _ = values.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetIntegerList(handle, Int32(tag), buf.baseAddress!, count)
        }
        return values
    }

    /// Append a value to an integer list attribute.
    func integerListAppend(tag: Int, value: Int32) -> Bool {
        OCCTDocumentIntegerListAppend(handle, Int32(tag), value)
    }

    /// Clear an integer list attribute.
    func integerListClear(tag: Int) -> Bool {
        OCCTDocumentIntegerListClear(handle, Int32(tag))
    }

    /// Check if a label has an integer list attribute.
    func hasIntegerList(tag: Int) -> Bool {
        OCCTDocumentHasIntegerList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_RealList

public extension Document {
    /// Set a real list attribute on a label.
    func setRealList(tag: Int, values: [Double]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetRealList(handle, Int32(tag), buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a real list attribute from a label.
    func realList(tag: Int) -> [Double]? {
        let count = OCCTDocumentGetRealList(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var values = [Double](repeating: 0, count: Int(count))
        _ = values.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetRealList(handle, Int32(tag), buf.baseAddress!, count)
        }
        return values
    }

    /// Append a value to a real list attribute.
    func realListAppend(tag: Int, value: Double) -> Bool {
        OCCTDocumentRealListAppend(handle, Int32(tag), value)
    }

    /// Clear a real list attribute.
    func realListClear(tag: Int) -> Bool {
        OCCTDocumentRealListClear(handle, Int32(tag))
    }

    /// Check if a label has a real list attribute.
    func hasRealList(tag: Int) -> Bool {
        OCCTDocumentHasRealList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ExtStringArray

public extension Document {
    /// Set an extended string array attribute on a label.
    func setExtStringArray(tag: Int, values: [String]) -> Bool {
        var result = false
        let count = values.count
        let cStrings: [UnsafePointer<CChar>] = values.map { str in
            (str as NSString).utf8String!
        }
        cStrings.withUnsafeBufferPointer { buf in
            result = OCCTDocumentSetExtStringArray(handle, Int32(tag), 1, Int32(count),
                                                    buf.baseAddress!, Int32(count))
        }
        return result
    }

    /// Get an extended string array element by index (1-based).
    func extStringArrayValue(tag: Int, index: Int) -> String? {
        guard let cStr = OCCTDocumentGetExtStringArrayValue(handle, Int32(tag), Int32(index)) else { return nil }
        defer { free(cStr) }
        return String(cString: cStr)
    }

    /// Get the length of an extended string array.
    func extStringArrayLength(tag: Int) -> Int? {
        let len = OCCTDocumentGetExtStringArrayLength(handle, Int32(tag))
        return len >= 0 ? Int(len) : nil
    }

    /// Check if a label has an extended string array attribute.
    func hasExtStringArray(tag: Int) -> Bool {
        OCCTDocumentHasExtStringArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ExtStringList

public extension Document {
    /// Set an extended string list attribute on a label.
    func setExtStringList(tag: Int, values: [String]) -> Bool {
        var result = false
        let count = values.count
        let cStrings: [UnsafePointer<CChar>] = values.map { str in
            (str as NSString).utf8String!
        }
        cStrings.withUnsafeBufferPointer { buf in
            result = OCCTDocumentSetExtStringList(handle, Int32(tag),
                                                   buf.baseAddress!, Int32(count))
        }
        return result
    }

    /// Get the count of an extended string list.
    func extStringListCount(tag: Int) -> Int? {
        let count = OCCTDocumentGetExtStringListCount(handle, Int32(tag))
        return count >= 0 ? Int(count) : nil
    }

    /// Get an extended string list element by index (0-based).
    func extStringListValue(tag: Int, index: Int) -> String? {
        guard let cStr = OCCTDocumentGetExtStringListValue(handle, Int32(tag), Int32(index)) else { return nil }
        defer { free(cStr) }
        return String(cString: cStr)
    }

    /// Append a string to an extended string list attribute.
    func extStringListAppend(tag: Int, value: String) -> Bool {
        OCCTDocumentExtStringListAppend(handle, Int32(tag), value)
    }

    /// Clear an extended string list attribute.
    func extStringListClear(tag: Int) -> Bool {
        OCCTDocumentExtStringListClear(handle, Int32(tag))
    }

    /// Check if a label has an extended string list attribute.
    func hasExtStringList(tag: Int) -> Bool {
        OCCTDocumentHasExtStringList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ReferenceArray

public extension Document {
    /// Set a reference array attribute on a label (array of label tags).
    func setReferenceArray(tag: Int, refTags: [Int32]) -> Bool {
        refTags.withUnsafeBufferPointer { buf in
            OCCTDocumentSetReferenceArray(handle, Int32(tag), 1, Int32(refTags.count),
                                           buf.baseAddress!, Int32(refTags.count))
        }
    }

    /// Get a reference array from a label (array of label tags).
    func referenceArray(tag: Int) -> [Int32]? {
        let count = OCCTDocumentGetReferenceArray(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var tags = [Int32](repeating: 0, count: Int(count))
        _ = tags.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetReferenceArray(handle, Int32(tag), buf.baseAddress!, count)
        }
        return tags
    }

    /// Check if a label has a reference array attribute.
    func hasReferenceArray(tag: Int) -> Bool {
        OCCTDocumentHasReferenceArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ReferenceList

public extension Document {
    /// Set a reference list attribute on a label (list of label tags).
    func setReferenceList(tag: Int, refTags: [Int32]) -> Bool {
        refTags.withUnsafeBufferPointer { buf in
            OCCTDocumentSetReferenceList(handle, Int32(tag),
                                          buf.baseAddress!, Int32(refTags.count))
        }
    }

    /// Get a reference list from a label (list of label tags).
    func referenceList(tag: Int) -> [Int32]? {
        let count = OCCTDocumentGetReferenceList(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var tags = [Int32](repeating: 0, count: Int(count))
        _ = tags.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetReferenceList(handle, Int32(tag), buf.baseAddress!, count)
        }
        return tags
    }

    /// Append a reference to a reference list attribute.
    func referenceListAppend(tag: Int, refTag: Int32) -> Bool {
        OCCTDocumentReferenceListAppend(handle, Int32(tag), refTag)
    }

    /// Clear a reference list attribute.
    func referenceListClear(tag: Int) -> Bool {
        OCCTDocumentReferenceListClear(handle, Int32(tag))
    }

    /// Check if a label has a reference list attribute.
    func hasReferenceList(tag: Int) -> Bool {
        OCCTDocumentHasReferenceList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_Relation

public extension Document {
    /// Set a relation string on a label.
    func setRelation(tag: Int, relation: String) -> Bool {
        OCCTDocumentSetRelation(handle, Int32(tag), relation)
    }

    /// Get a relation string from a label.
    func relation(tag: Int) -> String? {
        guard let cStr = OCCTDocumentGetRelation(handle, Int32(tag)) else { return nil }
        defer { free(cStr) }
        return String(cString: cStr)
    }

    /// Check if a label has a relation attribute.
    func hasRelation(tag: Int) -> Bool {
        OCCTDocumentHasRelation(handle, Int32(tag))
    }
}

// MARK: - ShapeFix_Solid

public extension Shape {
    /// Fix a solid shape (topology and orientation), using `ShapeFix_Solid`.
    ///
    /// Every solid in the receiver is healed, not just the first: a single-body input
    /// comes back as a solid, a multi-body one as a compound of one result per input body,
    /// in exploration order. A compound result is not new to this call — `ShapeFix_Solid`
    /// already returns one when a single solid's shells resolve into several bodies.
    ///
    /// Only the receiver's *solids* are visited. Loose shells, faces or wires sitting
    /// alongside them in a compound are not carried over, and an input holding no solid at
    /// all returns `nil`. To heal a whole shape of mixed content instead, use
    /// ``Shape/fixed(tolerance:fixSolid:fixShell:fixFace:fixWire:)``, which wraps
    /// `ShapeFix_Shape` and preserves everything it is given.
    ///
    /// - Warning: A result body is usually a healed solid, but **not always**, and no body
    ///   is ever dropped to make that true. `ShapeFix_Solid` hands back a **shell** when it
    ///   cannot close one into a solid, and a solid it fails to heal outright is returned
    ///   **unhealed** rather than discarded. So `result.solids.count` can be lower than the
    ///   number of input bodies even though nothing was lost.
    ///
    ///   To spot an unclosed body, walk the result's **direct children** — not
    ///   ``Shape/subShapes(ofType:)``, which maps at every depth and so reports one shell
    ///   for every *healthy* solid too (a compound of two healed solids has two shells, and
    ///   a single healed solid has one):
    ///
    ///   ```swift
    ///   let healed = part.fixSolid()!
    ///   let bodies = (0..<healed.nbChildren).compactMap { healed.child(at: $0) }
    ///   let unclosed = bodies.filter { $0.shapeType == .shell }
    ///   ```
    ///
    ///   When a single body came back, the result is that body rather than a compound, so
    ///   `healed.shapeType == .shell` answers it directly. A body that came back *unhealed*
    ///   is still a solid — use ``Shape/isValid`` for that.
    ///
    /// ```swift
    /// let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)!
    /// let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)!
    /// let part = Shape.compound([a, b])!
    ///
    /// let healed = part.fixSolid()!
    /// print(healed.solids.count)   // 2 — both bodies, not just the first
    /// print(healed.volume!)        // 2000.0
    /// ```
    ///
    /// - Returns: The repaired body, or a compound of one result per input body for
    ///   multi-body input, or `nil` if the receiver holds no solid.
    func fixSolid() -> Shape? {
        guard let ref = OCCTShapeFixSolid(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a solid from a shell shape using `ShapeFix_Solid`, orienting it to enclose
    /// a finite volume.
    ///
    /// One solid is built per *body-bounding* shell, not just the first shell found: every
    /// shell that an **even** number of the other shells in its group enclose, where a group
    /// is one solid's own shells, or all the shells belonging to no solid (the usual shape
    /// of sewing output). A single body comes back as a solid, several as a compound in
    /// exploration order.
    ///
    /// *Cavity* shells are deliberately skipped: a hole is not a body, and building it as a
    /// positive solid would yield a compound whose volume double-counts the part. So a
    /// hollow solid produces one solid bounded by its outer shell, with the cavity filled,
    /// and so does that same body after sewing has left its two shells free. A body nested
    /// inside another body's cavity is enclosed twice, so it is still read as a body. To
    /// rebuild a solid that keeps its cavities, use ``Shape/solidFromShells(_:)`` with the
    /// outer shell first.
    ///
    /// ```swift
    /// let quilt = Shape.compound([shellA, shellB])!   // e.g. two sewn bodies
    /// let solids = quilt.solidFromShellFixed()!
    /// print(solids.solids.count)   // 2 — one solid per shell
    /// ```
    ///
    /// - Important: An **open** shell is not rejected. `ShapeFix_Solid::SolidFromShell`
    ///   builds its solid before classifying anything and never returns a null one, so a
    ///   shell with gaps comes back as a solid that is not closed rather than as `nil`.
    ///   Check ``Shape/isValid`` or sew first if the input may be open.
    ///
    /// - Returns: A solid, a compound of solids for multi-body input, or `nil` only if the
    ///   receiver holds no shell at all.
    func solidFromShellFixed() -> Shape? {
        guard let ref = OCCTShapeSolidFromShell(handle) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - ShapeFix_EdgeConnect

public extension Shape {
    /// Connect edges in a shape by extending/trimming to match.
    func fixEdgeConnect() -> Shape? {
        guard let ref = OCCTShapeFixEdgeConnect(handle) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - BRepOffsetAPI_FindContigousEdges

public extension Shape {
    /// Result of contiguous edge finding.
    struct ContigousEdgeResult: Sendable {
        public let contigousEdgeCount: Int
        public let degeneratedShapeCount: Int
    }

    /// Find contiguous edges in a shape.
    func findContigousEdges(tolerance: Double = 1.0e-6) -> ContigousEdgeResult {
        let result = OCCTShapeFindContigousEdges(handle, tolerance)
        return ContigousEdgeResult(
            contigousEdgeCount: Int(result.contigousEdgeCount),
            degeneratedShapeCount: Int(result.degeneratedShapeCount)
        )
    }
}

// MARK: - TDataStd_Tick

public extension Document {
    /// Set a tick (boolean flag) attribute on a label.
    func setTick(tag: Int) -> Bool {
        OCCTDocumentSetTick(handle, Int32(tag))
    }

    /// Check if a label has a tick attribute.
    func hasTick(tag: Int) -> Bool {
        OCCTDocumentHasTick(handle, Int32(tag))
    }

    /// Remove a tick attribute from a label.
    func removeTick(tag: Int) -> Bool {
        OCCTDocumentRemoveTick(handle, Int32(tag))
    }
}

// MARK: - TDataStd_Current

public extension Document {
    /// Set a label as the current label in the document.
    func setCurrentLabel(tag: Int) -> Bool {
        OCCTDocumentSetCurrentLabel(handle, Int32(tag))
    }

    /// Get the current label tag, or nil if none set.
    func currentLabel() -> Int? {
        let tag = OCCTDocumentGetCurrentLabel(handle)
        return tag >= 0 ? Int(tag) : nil
    }

    /// Check if the document has a current label set.
    func hasCurrentLabel() -> Bool {
        OCCTDocumentHasCurrentLabel(handle)
    }
}

// MARK: - ShapeAnalysis_Shell

public extension Shape {
    /// Result of shell analysis.
    struct ShellAnalysisResult: Sendable {
        public let hasOrientationProblems: Bool
        public let hasFreeEdges: Bool
        public let hasBadEdges: Bool
        public let hasConnectedEdges: Bool
        public let freeEdgeCount: Int
    }

    /// Analyze shell orientation and edge connectivity.
    func analyzeShell() -> ShellAnalysisResult {
        let r = OCCTShapeAnalyzeShell(handle)
        return ShellAnalysisResult(
            hasOrientationProblems: r.hasOrientationProblems,
            hasFreeEdges: r.hasFreeEdges,
            hasBadEdges: r.hasBadEdges,
            hasConnectedEdges: r.hasConnectedEdges,
            freeEdgeCount: Int(r.freeEdgeCount)
        )
    }
}

// MARK: - ShapeAnalysis_CanonicalRecognition (detailed)

public extension Shape {
    /// Canonical geometry type for detailed recognition.
    enum CanonicalGeometryType: Int, Sendable {
        case none = 0
        case plane = 1
        case cylinder = 2
        case cone = 3
        case sphere = 4
        case line = 5
        case circle = 6
        case ellipse = 7
    }

    /// Detailed canonical recognition result with geometry parameters.
    struct CanonicalRecognitionResult: Sendable {
        public let type: CanonicalGeometryType
        public let gap: Double
        public let origin: (x: Double, y: Double, z: Double)
        public let direction: (x: Double, y: Double, z: Double)
        public let param1: Double
        public let param2: Double
    }

    /// Recognize canonical surface geometry from a face with detailed parameters.
    func recognizeCanonicalSurface(tolerance: Double = 0.01) -> CanonicalRecognitionResult {
        let r = OCCTShapeRecognizeCanonicalSurface(handle, tolerance)
        return CanonicalRecognitionResult(
            type: CanonicalGeometryType(rawValue: Int(r.type.rawValue)) ?? .none,
            gap: r.gap,
            origin: (r.originX, r.originY, r.originZ),
            direction: (r.dirX, r.dirY, r.dirZ),
            param1: r.param1,
            param2: r.param2
        )
    }

    /// Recognize canonical curve geometry from an edge with detailed parameters.
    func recognizeCanonicalCurve(tolerance: Double = 0.01) -> CanonicalRecognitionResult {
        let r = OCCTShapeRecognizeCanonicalCurve(handle, tolerance)
        return CanonicalRecognitionResult(
            type: CanonicalGeometryType(rawValue: Int(r.type.rawValue)) ?? .none,
            gap: r.gap,
            origin: (r.originX, r.originY, r.originZ),
            direction: (r.dirX, r.dirY, r.dirZ),
            param1: r.param1,
            param2: r.param2
        )
    }
}

// MARK: - Geom_Transformation


// MARK: - Geom_OffsetCurve

public extension Curve3D {
    /// Create an offset curve.
    static func offset(basis: Curve3D, offset: Double,
                       dirX: Double, dirY: Double, dirZ: Double) -> Curve3D? {
        guard let ref = OCCTCurve3DCreateOffset(basis.handle, offset, dirX, dirY, dirZ) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Get the offset value (returns 0 if not an offset curve).
    var offsetValue: Double {
        OCCTCurve3DOffsetValue(handle)
    }

    /// Get the offset direction (returns nil if not an offset curve).
    var offsetDirection: (x: Double, y: Double, z: Double)? {
        var dx: Double = 0, dy: Double = 0, dz: Double = 0
        if OCCTCurve3DOffsetDirection(handle, &dx, &dy, &dz) {
            return (dx, dy, dz)
        }
        return nil
    }
}

// MARK: - Geom_RectangularTrimmedSurface

public extension Surface {
    /// Create a rectangular trimmed surface.
    static func rectangularTrimmed(basis: Surface,
                                    u1: Double, u2: Double,
                                    v1: Double, v2: Double) -> Surface? {
        guard let ref = OCCTSurfaceCreateRectangularTrimmed(basis.handle, u1, u2, v1, v2) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a surface trimmed in U direction only.
    static func trimmedInU(basis: Surface, param1: Double, param2: Double) -> Surface? {
        guard let ref = OCCTSurfaceCreateTrimmedInU(basis.handle, param1, param2) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a surface trimmed in V direction only.
    static func trimmedInV(basis: Surface, param1: Double, param2: Double) -> Surface? {
        guard let ref = OCCTSurfaceCreateTrimmedInV(basis.handle, param1, param2) else { return nil }
        return Surface(handle: ref)
    }
}

// MARK: - TNaming Extensions (v0.88.0)

extension Document {

    /// Check if a TNaming_NamedShape on a label is empty
    public func namingIsEmpty(on node: AssemblyNode) -> Bool {
        OCCTNamingIsEmpty(handle, node.labelId)
    }

    /// Get the version of a TNaming_NamedShape attribute
    public func namingVersion(on node: AssemblyNode) -> Int {
        Int(OCCTNamingGetVersion(handle, node.labelId))
    }

    /// Set the version of a TNaming_NamedShape attribute
    @discardableResult
    public func setNamingVersion(on node: AssemblyNode, version: Int) -> Bool {
        OCCTNamingSetVersion(handle, node.labelId, Int32(version))
    }

    /// Get the original (old) shape from a named shape attribute
    public func namingOriginalShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTNamingOriginalShape(handle, node.labelId) else { return nil }
        return Shape(handle: h)
    }

    /// Check if a shape has a label in the document's naming framework
    public func namingHasLabel(shape: Shape) -> Bool {
        OCCTNamingHasLabel(handle, shape.handle)
    }

    /// Find the label for a shape in the document's naming framework
    public func namingFindLabel(shape: Shape) -> AssemblyNode? {
        let labelId = OCCTNamingFindLabel(handle, shape.handle)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Get the valid-until transaction number for a shape
    public func namingValidUntil(shape: Shape) -> Int {
        Int(OCCTNamingValidUntil(handle, shape.handle))
    }

    /// Get count of labels containing the same shape
    public func sameShapeCount(shape: Shape) -> Int {
        Int(OCCTNamingSameShapeCount(handle, shape.handle))
    }

    /// Get all labels containing the same shape
    public func sameShapeLabels(shape: Shape) -> [AssemblyNode] {
        let count = OCCTNamingSameShapeCount(handle, shape.handle)
        guard count > 0 else { return [] }
        var ids = [Int64](repeating: 0, count: Int(count))
        let actual = OCCTNamingSameShapeLabels(handle, shape.handle, &ids, count)
        return (0..<Int(actual)).map { AssemblyNode(document: self, labelId: ids[$0]) }
    }
}

// MARK: - TDataStd_IntPackedMap (v0.88.0)

extension Document {

    /// Set (create) an IntPackedMap attribute on a label
    @discardableResult
    public func setIntPackedMap(tag: Int, isDelta: Bool = false) -> Bool {
        OCCTIntPackedMapSet(handle, Int32(tag), isDelta)
    }

    /// Add a value to the IntPackedMap
    @discardableResult
    public func intPackedMapAdd(tag: Int, value: Int) -> Bool {
        OCCTIntPackedMapAdd(handle, Int32(tag), Int32(value))
    }

    /// Remove a value from the IntPackedMap
    @discardableResult
    public func intPackedMapRemove(tag: Int, value: Int) -> Bool {
        OCCTIntPackedMapRemove(handle, Int32(tag), Int32(value))
    }

    /// Check if the IntPackedMap contains a value
    public func intPackedMapContains(tag: Int, value: Int) -> Bool {
        OCCTIntPackedMapContains(handle, Int32(tag), Int32(value))
    }

    /// Get the count of elements in the IntPackedMap
    public func intPackedMapCount(tag: Int) -> Int {
        Int(OCCTIntPackedMapExtent(handle, Int32(tag)))
    }

    /// Clear all elements from the IntPackedMap
    @discardableResult
    public func intPackedMapClear(tag: Int) -> Bool {
        OCCTIntPackedMapClear(handle, Int32(tag))
    }

    /// Check if the IntPackedMap is empty
    public func intPackedMapIsEmpty(tag: Int) -> Bool {
        OCCTIntPackedMapIsEmpty(handle, Int32(tag))
    }

    /// Get all values from the IntPackedMap
    public func intPackedMapValues(tag: Int) -> [Int] {
        var ptr: UnsafeMutablePointer<Int32>?
        let count = OCCTIntPackedMapGetValues(handle, Int32(tag), &ptr)
        guard count > 0, let ptr = ptr else { return [] }
        defer { OCCTIntPackedMapFreeValues(ptr) }
        return (0..<Int(count)).map { Int(ptr[$0]) }
    }

    /// Replace all values in the IntPackedMap
    @discardableResult
    public func intPackedMapSetValues(tag: Int, values: [Int]) -> Bool {
        let int32Values = values.map { Int32($0) }
        return int32Values.withUnsafeBufferPointer { buf in
            OCCTIntPackedMapChangeValues(handle, Int32(tag), buf.baseAddress!, Int32(values.count))
        }
    }
}

// MARK: - TDataStd_NoteBook (v0.88.0)

extension Document {

    /// Create a NoteBook attribute on a label
    @discardableResult
    public func setNoteBook(tag: Int) -> Bool {
        OCCTNoteBookNew(handle, Int32(tag))
    }

    /// Append a real value to the NoteBook, returns the child label tag or nil
    public func noteBookAppendReal(tag: Int, value: Double) -> Int? {
        let result = OCCTNoteBookAppendReal(handle, Int32(tag), value)
        return result >= 0 ? Int(result) : nil
    }

    /// Append an integer value to the NoteBook, returns the child label tag or nil
    public func noteBookAppendInteger(tag: Int, value: Int) -> Int? {
        let result = OCCTNoteBookAppendInteger(handle, Int32(tag), Int32(value))
        return result >= 0 ? Int(result) : nil
    }

    /// Check if a NoteBook exists on a label (searches up hierarchy)
    public func noteBookExists(tag: Int) -> Bool {
        OCCTNoteBookFind(handle, Int32(tag))
    }
}

// MARK: - TDataStd_UAttribute (v0.88.0)

extension Document {

    /// Set a UAttribute with a GUID string on a label
    @discardableResult
    public func setUAttribute(tag: Int, guid: String) -> Bool {
        OCCTUAttributeSet(handle, Int32(tag), guid)
    }

    /// Check if a UAttribute with a given GUID exists on a label
    public func hasUAttribute(tag: Int, guid: String) -> Bool {
        OCCTUAttributeHas(handle, Int32(tag), guid)
    }

    /// Get the GUID string of a UAttribute on a label
    public func uAttributeID(tag: Int, guid: String) -> String? {
        guard let ptr = OCCTUAttributeGetID(handle, Int32(tag), guid) else { return nil }
        defer { OCCTUAttributeFreeGUID(ptr) }
        return String(cString: ptr)
    }
}

// MARK: - TDataStd_ChildNodeIterator (v0.88.0)

extension Document {

    /// Get count of child tree nodes on a label
    public func childNodeCount(tag: Int, allLevels: Bool = false) -> Int {
        Int(OCCTChildNodeIteratorCount(handle, Int32(tag), allLevels))
    }
}

// MARK: - TDF_Transaction Named (v0.89.0)

extension Document {

    /// Open a named transaction on the document.
    /// - Parameter name: Transaction name for identification
    /// - Returns: Transaction number (>= 1 on success), or 0 on error
    @discardableResult
    public func openNamedTransaction(_ name: String) -> Int {
        Int(OCCTDocumentOpenNamedTransaction(handle, name))
    }

    /// Get the current transaction number.
    public var transactionNumber: Int {
        Int(OCCTDocumentGetTransactionNumber(handle))
    }

    /// Commit the current transaction and return a delta for inspection.
    /// The delta must be released when no longer needed.
    /// - Returns: An opaque delta handle, or nil if no changes
    public func commitWithDelta() -> TransactionDelta? {
        guard let ptr = OCCTDocumentCommitWithDelta(handle) else { return nil }
        return TransactionDelta(handle: ptr)
    }
}


// MARK: - TDF_ComparisonTool (v0.89.0)

extension Document {

    /// Check if a label's references are all contained within its descendants.
    /// - Parameter labelId: The label to check
    /// - Returns: true if self-contained
    public func isSelfContained(labelId: Int64) -> Bool {
        OCCTDocumentIsSelfContained(handle, labelId)
    }
}

// MARK: - TDocStd_XLinkTool (v0.89.0)

extension Document {

    /// Copy a label and its attributes to another label (simple copy).
    /// - Parameters:
    ///   - targetLabelId: Destination label
    ///   - sourceLabelId: Source label
    /// - Returns: true on success
    @discardableResult
    public func xlinkCopy(targetLabelId: Int64, sourceLabelId: Int64) -> Bool {
        OCCTDocumentXLinkCopy(handle, targetLabelId, sourceLabelId)
    }

    /// Copy a label with an XLink attribute for cross-document reference tracking.
    /// - Parameters:
    ///   - targetLabelId: Destination label
    ///   - sourceLabelId: Source label
    /// - Returns: true on success
    @discardableResult
    public func xlinkCopyWithLink(targetLabelId: Int64, sourceLabelId: Int64) -> Bool {
        OCCTDocumentXLinkCopyWithLink(handle, targetLabelId, sourceLabelId)
    }
}

// MARK: - TFunction_IFunction (v0.89.0)

extension Document {

    /// Execution status for a function in the function mechanism.
    public enum FunctionExecutionStatus: Int32 {
        case wrongDefinition = 0
        case notExecuted = 1
        case executing = 2
        case succeeded = 3
        case failed = 4
    }

    /// Create a new function at a label with a given GUID.
    /// Automatically creates a TFunction_Scope if not present.
    /// - Parameters:
    ///   - labelId: Label to attach the function to
    ///   - guid: GUID string identifying the function type
    /// - Returns: true on success
    @discardableResult
    public func newFunction(labelId: Int64, guid: String) -> Bool {
        OCCTDocumentNewFunction(handle, labelId, guid)
    }

    /// Delete a function from a label.
    /// - Parameter labelId: Label with the function
    /// - Returns: true on success
    @discardableResult
    public func deleteFunction(labelId: Int64) -> Bool {
        OCCTDocumentDeleteFunction(handle, labelId)
    }

    /// Get the execution status of a function.
    /// - Parameter labelId: Label with the function
    /// - Returns: The execution status, or nil if no function found
    public func functionExecStatus(labelId: Int64) -> FunctionExecutionStatus? {
        let raw = OCCTDocumentFunctionGetExecStatus(handle, labelId)
        if raw < 0 { return nil }
        return FunctionExecutionStatus(rawValue: raw)
    }

    /// Set the execution status of a function.
    /// - Parameters:
    ///   - labelId: Label with the function
    ///   - status: The new execution status
    /// - Returns: true on success
    @discardableResult
    public func setFunctionExecStatus(labelId: Int64, status: FunctionExecutionStatus) -> Bool {
        OCCTDocumentFunctionSetExecStatus(handle, labelId, status.rawValue)
    }
}

// MARK: - TFunction_Scope (v0.89.0)

extension Document {

    /// Set (find or create) a function scope on the document root.
    /// Required before using function mechanism operations.
    /// - Returns: true on success
    @discardableResult
    public func setFunctionScope() -> Bool {
        OCCTDocumentSetFunctionScope(handle)
    }

    /// Add a label to the function scope.
    /// - Parameter labelId: Label to register as a function
    /// - Returns: true on success
    @discardableResult
    public func functionScopeAdd(labelId: Int64) -> Bool {
        OCCTDocumentFunctionScopeAdd(handle, labelId)
    }

    /// Remove a label from the function scope.
    /// - Parameter labelId: Label to unregister
    /// - Returns: true on success
    @discardableResult
    public func functionScopeRemove(labelId: Int64) -> Bool {
        OCCTDocumentFunctionScopeRemove(handle, labelId)
    }

    /// Check if a label is registered in the function scope.
    /// - Parameter labelId: Label to check
    /// - Returns: true if in scope
    public func functionScopeHas(labelId: Int64) -> Bool {
        OCCTDocumentFunctionScopeHas(handle, labelId)
    }

    /// Remove all functions from the scope.
    /// - Returns: true on success
    @discardableResult
    public func functionScopeRemoveAll() -> Bool {
        OCCTDocumentFunctionScopeRemoveAll(handle)
    }

    /// Number of functions in the scope.
    public var functionScopeCount: Int {
        Int(OCCTDocumentFunctionScopeCount(handle))
    }

    /// The next available function ID in the scope.
    public var functionScopeFreeID: Int {
        Int(OCCTDocumentFunctionScopeGetFreeID(handle))
    }
}

// MARK: - TDF_AttributeIterator (v0.89.0)

extension Document {

    /// Count the number of attributes on a label.
    /// - Parameters:
    ///   - labelId: Label to inspect
    ///   - withoutForgotten: If true (default), skip forgotten attributes
    /// - Returns: Number of attributes
    public func attributeCount(labelId: Int64, withoutForgotten: Bool = true) -> Int {
        Int(OCCTDocumentAttributeCount(handle, labelId, withoutForgotten))
    }

    /// Check if a label has any content in a DataSet context.
    /// Returns false if the label is not empty (has been added to the data framework).
    public func dataSetIsEmpty(labelId: Int64) -> Bool {
        OCCTDocumentDataSetIsEmpty(handle, labelId)
    }
}

// MARK: - TDF_ChildIDIterator (v0.90.0)

extension Document {

    /// Count child labels that have an attribute with the given GUID.
    /// - Parameters:
    ///   - labelId: Parent label to search
    ///   - guid: GUID string of the attribute type
    ///   - allLevels: If true, recurse into all descendants
    /// - Returns: Number of matching children
    public func childIDCount(labelId: Int64, guid: String, allLevels: Bool = false) -> Int {
        Int(OCCTDocumentChildIDCount(handle, labelId, guid, allLevels))
    }
}

// MARK: - TDocStd_PathParser (v0.90.0, folded into OSDPath in #499)


// MARK: - TFunction_DriverTable (v0.90.0)


// MARK: - TNaming_Scope (v0.90.0)

extension Document {

    /// Mark a label as valid in the naming scope.
    @discardableResult
    public func namingScopeValid(labelId: Int64) -> Bool {
        OCCTDocumentNamingScopeValid(handle, labelId)
    }

    /// Mark a label and its children as valid in the naming scope.
    @discardableResult
    public func namingScopeValidChildren(labelId: Int64, withRoot: Bool = true) -> Bool {
        OCCTDocumentNamingScopeValidChildren(handle, labelId, withRoot)
    }

    /// Check if a label is valid in the naming scope.
    public func namingScopeIsValid(labelId: Int64) -> Bool {
        OCCTDocumentNamingScopeIsValid(handle, labelId)
    }

    /// Remove a label from the valid set in the naming scope.
    @discardableResult
    public func namingScopeUnvalid(labelId: Int64) -> Bool {
        OCCTDocumentNamingScopeUnvalid(handle, labelId)
    }

    /// Clear all valid labels in the naming scope.
    public func namingScopeClear() {
        OCCTDocumentNamingScopeClear(handle)
    }

    /// Number of valid labels in the naming scope.
    public var namingScopeValidCount: Int {
        Int(OCCTDocumentNamingScopeValidCount(handle))
    }
}

// MARK: - TNaming_Translator (v0.90.0)

extension Shape {

    /// Create a deep copy of this shape using TNaming_Translator.
    /// The copy has independent topology (different TShape pointers).
    public func translatorCopy() -> Shape? {
        guard let ref = OCCTShapeTranslatorCopy(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Check if two shapes share the same underlying TShape.
    public func isSame(as other: Shape) -> Bool {
        OCCTShapeIsSame(handle, other.handle)
    }
}

// MARK: - TDataXtd_Placement (v0.90.0)

extension Document {

    /// Set a placement marker attribute on a label.
    @discardableResult
    public func setPlacement(labelId: Int64) -> Bool {
        OCCTDocumentSetPlacement(handle, labelId)
    }

    /// Check if a label has a placement marker attribute.
    public func hasPlacement(labelId: Int64) -> Bool {
        OCCTDocumentHasPlacement(handle, labelId)
    }
}

// MARK: - TDataXtd_Presentation (v0.90.0)

extension Document {

    /// Set a presentation attribute on a label with a driver GUID.
    @discardableResult
    public func setPresentation(labelId: Int64, driverGUID: String) -> Bool {
        OCCTDocumentSetPresentation(handle, labelId, driverGUID)
    }

    /// Remove a presentation attribute from a label.
    public func unsetPresentation(labelId: Int64) {
        OCCTDocumentUnsetPresentation(handle, labelId)
    }

    /// Check if a label has a presentation attribute.
    public func hasPresentation(labelId: Int64) -> Bool {
        OCCTDocumentHasPresentation(handle, labelId)
    }

    /// Set the display state of a presentation.
    @discardableResult
    public func presentationSetDisplayed(labelId: Int64, displayed: Bool) -> Bool {
        OCCTDocumentPresentationSetDisplayed(handle, labelId, displayed)
    }

    /// Get the display state of a presentation.
    public func presentationIsDisplayed(labelId: Int64) -> Bool {
        OCCTDocumentPresentationIsDisplayed(handle, labelId)
    }

    /// Set the color of a presentation (Quantity_NameOfColor index).
    @discardableResult
    public func presentationSetColor(labelId: Int64, colorIndex: Int32) -> Bool {
        OCCTDocumentPresentationSetColor(handle, labelId, colorIndex)
    }

    /// Get the color of a presentation. Returns nil if no own color.
    public func presentationGetColor(labelId: Int64) -> Int32? {
        let v = OCCTDocumentPresentationGetColor(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Set the transparency of a presentation [0.0, 1.0].
    @discardableResult
    public func presentationSetTransparency(labelId: Int64, value: Double) -> Bool {
        OCCTDocumentPresentationSetTransparency(handle, labelId, value)
    }

    /// Get the transparency. Returns nil if no own transparency.
    public func presentationGetTransparency(labelId: Int64) -> Double? {
        let v = OCCTDocumentPresentationGetTransparency(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Set the line width of a presentation.
    @discardableResult
    public func presentationSetWidth(labelId: Int64, width: Double) -> Bool {
        OCCTDocumentPresentationSetWidth(handle, labelId, width)
    }

    /// Get the line width. Returns nil if no own width.
    public func presentationGetWidth(labelId: Int64) -> Double? {
        let v = OCCTDocumentPresentationGetWidth(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Set the display mode of a presentation (0=wireframe, 1=shaded, etc.).
    @discardableResult
    public func presentationSetMode(labelId: Int64, mode: Int32) -> Bool {
        OCCTDocumentPresentationSetMode(handle, labelId, mode)
    }

    /// Get the display mode. Returns nil if no own mode.
    public func presentationGetMode(labelId: Int64) -> Int32? {
        let v = OCCTDocumentPresentationGetMode(handle, labelId)
        return v >= 0 ? v : nil
    }
}

// MARK: - XCAFDoc_AssemblyIterator (v0.90.0)

extension Document {

    /// Count the number of assembly items in the document.
    /// - Parameter maxDepth: Maximum traversal depth (0 = unlimited)
    public func assemblyItemCount(maxDepth: Int = 0) -> Int {
        Int(OCCTDocumentAssemblyItemCount(handle, Int32(maxDepth)))
    }
}

// MARK: - XCAFDoc_DimTol (v0.90.0)

extension Document {

    /// Set a dimension/tolerance attribute on a label.
    /// - Parameters:
    ///   - labelId: Label to set on
    ///   - kind: Dimension/tolerance type code
    ///   - values: Array of numeric values
    ///   - name: Name string
    ///   - description: Description string
    @discardableResult
    public func setDimTol(labelId: Int64, kind: Int32, values: [Double],
                          name: String, description: String) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetDimTol(handle, labelId, kind,
                                  buf.baseAddress!, Int32(values.count),
                                  name, description)
        }
    }

    /// Get the kind of a DimTol attribute. Returns nil if not found.
    public func dimTolKind(labelId: Int64) -> Int32? {
        let v = OCCTDocumentGetDimTolKind(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Get the name of a DimTol attribute.
    public func dimTolName(labelId: Int64) -> String? {
        guard let ptr = OCCTDocumentGetDimTolName(handle, labelId) else { return nil }
        defer { OCCTDocumentFreeDimTolString(ptr) }
        return String(cString: ptr)
    }

    /// Get the description of a DimTol attribute.
    public func dimTolDescription(labelId: Int64) -> String? {
        guard let ptr = OCCTDocumentGetDimTolDescription(handle, labelId) else { return nil }
        defer { OCCTDocumentFreeDimTolString(ptr) }
        return String(cString: ptr)
    }

    /// Get the values of a DimTol attribute.
    public func dimTolValues(labelId: Int64) -> [Double]? {
        var buffer = [Double](repeating: 0, count: 32)
        let count = buffer.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetDimTolValues(handle, labelId, buf.baseAddress!, 32)
        }
        if count <= 0 { return nil }
        return Array(buffer.prefix(Int(count)))
    }
}

// MARK: - IntTools_Tools (v0.90.0)


// MARK: - ElCLib — Elementary Curve Library (v0.91.0)


// MARK: - ElSLib — Elementary Surface Library (v0.91.0)


// MARK: - gp_Quaternion (v0.91.0)


// MARK: - OSD_Timer (v0.91.0)


// MARK: - Bnd_OBB — Oriented Bounding Box (v0.92.0)


// MARK: - Bnd_Range — 1D Range (v0.92.0)


// MARK: - BRepClass3d — Point Classification (v0.92.0)

extension Shape {

    /// Classification state for a point relative to a solid.
    public enum PointState: Int32 {
        case inside = 0
        case outside = 1
        case on = 2
        case unknown = 3
    }

    /// Classify a 3D point relative to this solid shape.
    /// - Parameters:
    ///   - point: The 3D point to classify
    ///   - tolerance: Classification tolerance
    /// - Returns: The classification state
    public func classifyPoint(_ point: SIMD3<Double>, tolerance: Double = 1e-6) -> PointState {
        let raw = OCCTShapeClassifyPoint(handle, point.x, point.y, point.z, tolerance)
        return PointState(rawValue: raw) ?? .unknown
    }
}

// MARK: - TDataXtd_Constraint (v0.92.0)

extension Document {

    /// Constraint type enum matching TDataXtd_ConstraintEnum.
    public enum ConstraintType: Int32 {
        case radius = 0, diameter, minorRadius, majorRadius
        case tangent, parallel, perpendicular, concentric
        case coincident, distance, angle, equalRadius
        case symmetry, midPoint, equalDistance, fix
        case rigid, from
    }

    /// Set a constraint attribute on a label.
    @discardableResult
    public func setConstraint(labelId: Int64) -> Bool {
        OCCTDocumentSetConstraint(handle, labelId)
    }

    /// Set the constraint type.
    @discardableResult
    public func constraintSetType(labelId: Int64, type: ConstraintType) -> Bool {
        OCCTDocumentConstraintSetType(handle, labelId, type.rawValue)
    }

    /// Get the constraint type. Returns nil if not found.
    public func constraintGetType(labelId: Int64) -> ConstraintType? {
        let raw = OCCTDocumentConstraintGetType(handle, labelId)
        if raw < 0 { return nil }
        return ConstraintType(rawValue: raw)
    }

    /// Number of geometries in the constraint.
    public func constraintNbGeometries(labelId: Int64) -> Int {
        Int(OCCTDocumentConstraintNbGeometries(handle, labelId))
    }

    /// Check if constraint is planar (2D).
    public func constraintIsPlanar(labelId: Int64) -> Bool {
        OCCTDocumentConstraintIsPlanar(handle, labelId)
    }

    /// Check if constraint is a dimension (has value).
    public func constraintIsDimension(labelId: Int64) -> Bool {
        OCCTDocumentConstraintIsDimension(handle, labelId)
    }

    /// Set the verified flag.
    @discardableResult
    public func constraintSetVerified(labelId: Int64, verified: Bool) -> Bool {
        OCCTDocumentConstraintSetVerified(handle, labelId, verified)
    }

    /// Get the verified flag.
    public func constraintGetVerified(labelId: Int64) -> Bool {
        OCCTDocumentConstraintGetVerified(handle, labelId)
    }

    /// Clear all geometries from a constraint.
    @discardableResult
    public func constraintClearGeometries(labelId: Int64) -> Bool {
        OCCTDocumentConstraintClearGeometries(handle, labelId)
    }
}

// MARK: - OSD_MemInfo (v0.93.0)


// MARK: - ShapeFix_EdgeProjAux (v0.93.0)

extension Shape {

    /// Project edge endpoints onto face pcurve.
    /// - Parameters:
    ///   - faceIndex: Index of the face (0-based)
    ///   - edgeIndex: Index of the edge within the face (0-based)
    ///   - precision: Projection precision
    /// - Returns: (firstParam, lastParam) or nil if projection fails
    public func edgeProjAux(faceIndex: Int, edgeIndex: Int, precision: Double = 1e-6) -> (first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard OCCTShapeFixEdgeProjAux(handle, Int32(faceIndex), Int32(edgeIndex), precision, &first, &last) else {
            return nil
        }
        return (first, last)
    }
}

// MARK: - Geom2dAPI_Interpolate (v0.93.0)

extension Curve2D {

    /// Interpolate a 2D BSpline curve through points.
    /// - Parameters:
    ///   - points: Array of 2D points (x, y)
    ///   - periodic: If true, create a periodic (closed) curve
    ///   - tolerance: Interpolation tolerance
    /// - Returns: The interpolated curve, or nil on failure
    public static func interpolate2D(points: [(Double, Double)], periodic: Bool = false, tolerance: Double = 1e-6) -> Curve2D? {
        let xs = points.map(\.0)
        let ys = points.map(\.1)
        return xs.withUnsafeBufferPointer { xBuf in
            ys.withUnsafeBufferPointer { yBuf in
                guard let ref = OCCTCurve2DInterpolate2D(xBuf.baseAddress!, yBuf.baseAddress!,
                                                         Int32(points.count), periodic, tolerance) else {
                    return nil
                }
                return Curve2D(handle: ref)
            }
        }
    }
}

// MARK: - Geom2dAPI_PointsToBSpline (v0.93.0)

extension Curve2D {

    /// Approximate a 2D BSpline curve through points.
    /// - Parameter points: Array of 2D points (x, y)
    /// - Returns: The approximated curve, or nil on failure
    public static func approximate2D(points: [(Double, Double)]) -> Curve2D? {
        let xs = points.map(\.0)
        let ys = points.map(\.1)
        return xs.withUnsafeBufferPointer { xBuf in
            ys.withUnsafeBufferPointer { yBuf in
                guard let ref = OCCTCurve2DApproximate2D(xBuf.baseAddress!, yBuf.baseAddress!,
                                                          Int32(points.count)) else {
                    return nil
                }
                return Curve2D(handle: ref)
            }
        }
    }
}

// MARK: - TDataXtd_PatternStd (v0.93.0)

extension Document {

    /// Pattern type for TDataXtd_PatternStd.
    public enum PatternSignature: Int32 {
        case linear = 1
        case circular = 2
        case rectangular = 3
        case radialCircular = 4
        case mirror = 5
    }

    /// Set a pattern attribute on a label.
    @discardableResult
    public func setPattern(labelId: Int64) -> Bool {
        OCCTDocumentSetPatternStd(handle, labelId)
    }

    /// Check if a label has a pattern attribute.
    public func hasPattern(labelId: Int64) -> Bool {
        OCCTDocumentHasPattern(handle, labelId)
    }

    /// Set pattern signature (type).
    @discardableResult
    public func patternSetSignature(labelId: Int64, signature: PatternSignature) -> Bool {
        OCCTDocumentPatternSetSignature(handle, labelId, signature.rawValue)
    }

    /// Get pattern signature. Returns nil if not found.
    public func patternGetSignature(labelId: Int64) -> PatternSignature? {
        let raw = OCCTDocumentPatternGetSignature(handle, labelId)
        if raw < 0 { return nil }
        return PatternSignature(rawValue: raw)
    }

    /// Number of transforms in the pattern.
    public func patternNbTrsfs(labelId: Int64) -> Int {
        Int(OCCTDocumentPatternNbTrsfs(handle, labelId))
    }
}

// MARK: - BRepAlgo_FaceRestrictor (v0.93.0)

extension Shape {

    /// Restrict a face to its wires using BRepAlgo_FaceRestrictor.
    /// - Parameter faceIndex: Index of the face (0-based)
    /// - Returns: Number of result faces
    public func faceRestrictAlgo(faceIndex: Int) -> Int {
        Int(OCCTShapeFaceRestrictAlgo(handle, Int32(faceIndex), nil, 0))
    }
}

// MARK: - math_Matrix (v0.94.0)


// MARK: - math_Gauss (v0.94.0)


// MARK: - math_SVD (v0.94.0)


// MARK: - math_DirectPolynomialRoots (v0.94.0)


// MARK: - math_Jacobi (v0.94.0)


// MARK: - Convert_CircleToBSplineCurve (v0.94.0)

extension Curve2D {

    /// Convert a 2D circle arc to a BSpline curve.
    ///
    /// - Parameter radius: circle radius. Must be greater than zero.
    /// - Returns: the converted curve, or `nil` if the circle is degenerate.
    ///
    /// ```swift
    /// if let c = Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 5, u1: 0, u2: .pi) {
    ///     print(c.degree)
    /// }
    /// ```
    public static func fromCircleArc(centerX: Double, centerY: Double, radius: Double,
                                      u1: Double, u2: Double) -> Curve2D? {
        guard let ref = OCCTConvertCircleToBSpline2D(centerX, centerY, radius, u1, u2) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - Convert_SphereToBSplineSurface (v0.94.0)

extension Surface {

    /// Convert a sphere to a BSpline surface.
    public static func fromSphere(origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double) -> Surface? {
        guard let ref = OCCTConvertSphereToBSplineSurface(origin.x, origin.y, origin.z,
                                                           axis.x, axis.y, axis.z, radius) else { return nil }
        return Surface(handle: ref)
    }
}

// MARK: - OSD_Environment (v0.94.0)


// MARK: - Convert Conic Curves to BSpline (v0.95.0)

extension Curve2D {

    /// Convert a 2D ellipse arc to a BSpline curve.
    ///
    /// - Parameters:
    ///   - majorRadius: semi-major axis. Must be greater than zero.
    ///   - minorRadius: semi-minor axis. Must be greater than zero and no larger than
    ///     `majorRadius`; equal radii are a circle and are valid.
    /// - Returns: the converted curve, or `nil` if the ellipse is degenerate.
    ///
    /// ```swift
    /// if let c = Curve2D.fromEllipseArc(centerX: 0, centerY: 0,
    ///                                   majorRadius: 20, minorRadius: 10,
    ///                                   u1: 0, u2: .pi) {
    ///     print(c.degree)
    /// }
    /// ```
    public static func fromEllipseArc(centerX: Double, centerY: Double,
                                       majorRadius: Double, minorRadius: Double,
                                       u1: Double, u2: Double) -> Curve2D? {
        guard let ref = OCCTConvertEllipseToBSpline2D(centerX, centerY, majorRadius, minorRadius, u1, u2) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Convert a 2D hyperbola arc to a BSpline curve.
    ///
    /// - Parameters:
    ///   - majorRadius: major radius. Must be greater than zero.
    ///   - minorRadius: minor radius. Must be greater than zero. A hyperbola puts no ordering on
    ///     its radii, so a minor radius larger than the major is an ordinary hyperbola.
    /// - Returns: the converted curve, or `nil` if the hyperbola is degenerate.
    ///
    /// ```swift
    /// if let c = Curve2D.fromHyperbolaArc(centerX: 0, centerY: 0,
    ///                                     majorRadius: 10, minorRadius: 5,
    ///                                     u1: -1, u2: 1) {
    ///     print(c.degree)
    /// }
    /// ```
    public static func fromHyperbolaArc(centerX: Double, centerY: Double,
                                         majorRadius: Double, minorRadius: Double,
                                         u1: Double, u2: Double) -> Curve2D? {
        guard let ref = OCCTConvertHyperbolaToBSpline2D(centerX, centerY, majorRadius, minorRadius, u1, u2) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Convert a 2D parabola arc to a BSpline curve.
    ///
    /// - Parameter focal: focal length. Must be greater than zero: OCCT converts a focal length of
    ///   zero without complaint, into a curve whose poles are all NaN.
    /// - Returns: the converted curve, or `nil` if the parabola is degenerate.
    ///
    /// ```swift
    /// if let c = Curve2D.fromParabolaArc(centerX: 0, centerY: 0, focal: 5, u1: -2, u2: 2) {
    ///     print(c.degree)
    /// }
    /// ```
    public static func fromParabolaArc(centerX: Double, centerY: Double, focal: Double,
                                        u1: Double, u2: Double) -> Curve2D? {
        guard let ref = OCCTConvertParabolaToBSpline2D(centerX, centerY, focal, u1, u2) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - Convert Elementary Surfaces to BSpline (v0.95.0)

extension Surface {

    /// Convert a cylinder patch to a BSpline surface.
    public static func fromCylinder(origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double,
                                     u1: Double, u2: Double, v1: Double, v2: Double) -> Surface? {
        guard let ref = OCCTConvertCylinderToBSplineSurface(origin.x, origin.y, origin.z,
                                                              axis.x, axis.y, axis.z, radius,
                                                              u1, u2, v1, v2) else { return nil }
        return Surface(handle: ref)
    }

    /// Convert a cone patch to a BSpline surface.
    public static func fromCone(origin: SIMD3<Double>, axis: SIMD3<Double>,
                                 semiAngle: Double, refRadius: Double,
                                 u1: Double, u2: Double, v1: Double, v2: Double) -> Surface? {
        guard let ref = OCCTConvertConeToBSplineSurface(origin.x, origin.y, origin.z,
                                                          axis.x, axis.y, axis.z,
                                                          semiAngle, refRadius,
                                                          u1, u2, v1, v2) else { return nil }
        return Surface(handle: ref)
    }

    /// Convert a full torus to a BSpline surface.
    public static func fromTorus(origin: SIMD3<Double>, axis: SIMD3<Double>,
                                  majorRadius: Double, minorRadius: Double) -> Surface? {
        guard let ref = OCCTConvertTorusToBSplineSurface(origin.x, origin.y, origin.z,
                                                           axis.x, axis.y, axis.z,
                                                           majorRadius, minorRadius) else { return nil }
        return Surface(handle: ref)
    }
}

// MARK: - math_Householder (v0.95.0)


// MARK: - math_Crout (v0.95.0)


// MARK: - ShapeFix_IntersectionTool (v0.95.0)

extension Shape {

    /// Fix intersecting wires on a face of this shape.
    /// - Parameters:
    ///   - faceIndex: Index of the face (0-based)
    ///   - precision: Fix precision
    /// - Returns: true if fixes were applied
    @discardableResult
    public func fixIntersectingWires(faceIndex: Int, precision: Double = 1e-6) -> Bool {
        OCCTShapeFixIntersectingWires(handle, Int32(faceIndex), precision)
    }
}

// MARK: - XCAFDoc_AssemblyItemRef (v0.96.0)

extension Document {

    /// Set an assembly item reference on a label.
    @discardableResult
    public func setAssemblyItemRef(labelId: Int64, itemPath: String) -> Bool {
        OCCTDocumentSetAssemblyItemRef(handle, labelId, itemPath)
    }

    /// Get the assembly item reference path string.
    public func assemblyItemRefPath(labelId: Int64) -> String? {
        guard let ptr = OCCTDocumentGetAssemblyItemRef(handle, labelId) else { return nil }
        defer { OCCTDocumentFreeAssemblyItemRefString(ptr) }
        return String(cString: ptr)
    }

    /// Set subshape index on an assembly item ref.
    @discardableResult
    public func assemblyItemRefSetSubshape(labelId: Int64, index: Int32) -> Bool {
        OCCTDocumentAssemblyItemRefSetSubshape(handle, labelId, index)
    }

    /// Get subshape index. Returns nil if not set.
    public func assemblyItemRefGetSubshape(labelId: Int64) -> Int32? {
        let v = OCCTDocumentAssemblyItemRefGetSubshape(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Check if assembly item ref has extra reference.
    public func assemblyItemRefHasExtra(labelId: Int64) -> Bool {
        OCCTDocumentAssemblyItemRefHasExtra(handle, labelId)
    }

    /// Clear extra reference from assembly item ref.
    @discardableResult
    public func assemblyItemRefClearExtra(labelId: Int64) -> Bool {
        OCCTDocumentAssemblyItemRefClearExtra(handle, labelId)
    }

    /// Check if assembly item ref is orphan.
    public func assemblyItemRefIsOrphan(labelId: Int64) -> Bool {
        OCCTDocumentAssemblyItemRefIsOrphan(handle, labelId)
    }
}

// MARK: - BRepAlgo_Image (v0.96.0)


// MARK: - OSD_Path (v0.96.0)


// MARK: - BRepClass_FClassifier (v0.96.0)

extension Shape {

    /// Classify a 2D point on a face (in UV parameter space).
    /// - Parameters:
    ///   - faceIndex: Face index (0-based)
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - tolerance: Classification tolerance
    /// - Returns: Classification state
    public func classifyPoint2D(faceIndex: Int, u: Double, v: Double, tolerance: Double = 1e-6) -> PointState {
        let raw = OCCTShapeClassifyPoint2D(handle, Int32(faceIndex), u, v, tolerance)
        return PointState(rawValue: raw) ?? .unknown
    }

    /// Build loops (wires) from edges on a face.
    /// - Returns: Number of result wires, or -1 on error
    public func buildLoops(faceIndex: Int) -> Int {
        Int(OCCTShapeBuildLoops(handle, Int32(faceIndex)))
    }

    /// Count boundary edges of a face using BRepGProp_Domain.
    public func faceDomainEdgeCount(faceIndex: Int) -> Int {
        Int(OCCTShapeFaceDomainEdgeCount(handle, Int32(faceIndex)))
    }
}

// MARK: - Bnd_BoundSortBox (v0.97.0)


// MARK: - TNaming_Naming (v0.97.0)

extension Document {

    /// Insert a TNaming_Naming attribute on a label.
    @discardableResult
    public func insertNaming(labelId: Int64) -> Bool {
        OCCTDocumentInsertNaming(handle, labelId)
    }

    /// Check if a naming attribute is defined on a label.
    public func namingIsDefined(labelId: Int64) -> Bool {
        OCCTDocumentNamingIsDefined(handle, labelId)
    }
}

// MARK: - Precision Constants (v0.97.0)


// MARK: - IntAna Analytic Intersections (v0.98.0)


// MARK: - OSD_Chronometer (v0.98.0)


// MARK: - OSD_Process (v0.98.0)


// MARK: - Draft_Modification (v0.98.0)

extension Shape {

    /// Apply a draft angle modification to a face.
    /// - Parameters:
    ///   - faceIndex: Index of the face to draft
    ///   - direction: Draft direction
    ///   - angle: Draft angle in radians
    ///   - neutralPlaneOrigin: Origin of the neutral plane
    ///   - neutralPlaneNormal: Normal of the neutral plane
    /// - Returns: Modified shape, or nil on failure
    public func draftModification(faceIndex: Int, direction: SIMD3<Double>, angle: Double,
                                   neutralPlaneOrigin: SIMD3<Double>,
                                   neutralPlaneNormal: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTShapeDraftModification(handle, Int32(faceIndex),
                                                     direction.x, direction.y, direction.z, angle,
                                                     neutralPlaneOrigin.x, neutralPlaneOrigin.y, neutralPlaneOrigin.z,
                                                     neutralPlaneNormal.x, neutralPlaneNormal.y, neutralPlaneNormal.z) else {
            return nil
        }
        return Shape(handle: ref)
    }
}

// MARK: - Convert_CompBezierCurvesToBSplineCurve (v0.99.0)




// MARK: - Geom_OffsetSurface Extensions (v0.99.0)

extension Surface {

    /// Get the offset distance of this surface (only valid if it is an offset surface).
    public var offsetValue: Double {
        OCCTSurfaceOffsetValue(handle)
    }

    /// Set the offset distance of this surface (only has effect on offset surfaces).
    public func setOffsetValue(_ value: Double) {
        OCCTSurfaceSetOffsetValue(handle, value)
    }

    /// Get the basis (underlying) surface of an offset surface.
    /// Returns nil if this surface is not an offset surface.
    public var offsetBasis: Surface? {
        guard let ref = OCCTSurfaceOffsetBasis(handle) else { return nil }
        return Surface(handle: ref)
    }
}

// MARK: - OSD_File (v0.99.0)


// MARK: - ShapeFix_Wireframe Extensions (v0.99.0)

extension Shape {

    /// Fix only wire gaps in the shape (no small-edge removal).
    /// - Parameter tolerance: Precision for gap detection.
    /// - Returns: Fixed shape, or nil on failure.
    public func fixWireGaps(tolerance: Double = 1e-7) -> Shape? {
        guard let ref = OCCTShapeFixWireGaps(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Fix only small edges in the shape (no gap repair).
    /// - Parameters:
    ///   - tolerance: Precision for small-edge detection.
    ///   - dropSmall: If true, remove small edges; if false, merge them with neighbours.
    ///   - limitAngle: Maximum tangent angle for merging (radians). Pass -1 for no limit.
    /// - Returns: Fixed shape, or nil on failure.
    public func fixSmallEdges(tolerance: Double = 1e-7,
                               dropSmall: Bool = false,
                               limitAngle: Double = -1) -> Shape? {
        guard let ref = OCCTShapeFixSmallEdges(handle, tolerance, dropSmall, limitAngle) else {
            return nil
        }
        return Shape(handle: ref)
    }
}

// MARK: - RWStl, ShapeAnalysis_Curve statics, BRepExtrema_SelfIntersection pairs, (v0.100.0)
//                    Geom_OffsetCurve basis, APIHeaderSection_MakeHeader, ShapeAnalysis_FreeBounds simplified

// --- RWStl direct binary/ASCII STL I/O ---

extension Shape {

    /// Write this shape's triangulation to a binary STL file.
    /// The shape is meshed automatically.
    /// - Parameters:
    ///   - filePath: Output file path.
    ///   - deflection: Linear mesh deflection (mm) for the auto-triangulation. Default `0.1`.
    /// - Returns: true on success.
    public func writeSTLBinary(to filePath: String, deflection: Double = 0.1) -> Bool {
        OCCTShapeWriteSTLBinary(handle, filePath, deflection)
    }

    /// Write this shape's triangulation to an ASCII STL file.
    /// The shape is meshed automatically.
    /// - Parameters:
    ///   - filePath: Output file path.
    ///   - deflection: Linear mesh deflection (mm) for the auto-triangulation. Default `0.1`.
    /// - Returns: true on success.
    public func writeSTLAscii(to filePath: String, deflection: Double = 0.1) -> Bool {
        OCCTShapeWriteSTLAscii(handle, filePath, deflection)
    }

    /// Read an STL file and return as a triangulated shape.
    /// - Parameter filePath: Input STL file path.
    /// - Returns: Shape with triangulation, or nil on failure.
    public static func readSTL(from filePath: String) -> Shape? {
        guard let ref = OCCTShapeReadSTL(filePath) else { return nil }
        return Shape(handle: ref)
    }
}

// --- ShapeAnalysis_Curve static methods ---

extension Curve3D {

    /// Check if this curve is closed within the given precision.
    /// Uses ShapeAnalysis_Curve::IsClosed (static method).
    /// - Parameter precision: Tolerance for closure check.
    /// - Returns: true if the curve endpoints coincide within precision.
    public func isClosedWithPrecision(_ precision: Double) -> Bool {
        OCCTCurve3DIsClosedWithPreci(handle, precision)
    }

    /// Check if this curve is periodic using ShapeAnalysis_Curve::IsPeriodic.
    /// More robust than the basic isPeriodic property.
    public var isPeriodicSA: Bool {
        OCCTCurve3DIsPeriodicSA(handle)
    }

}

// --- BRepExtrema_SelfIntersection face pair reporting ---

extension Shape {

    /// A pair of overlapping face indices detected by self-intersection analysis.
    public struct OverlapPair: Sendable {
        public let faceIndex1: Int
        public let faceIndex2: Int
    }

    /// Detect self-intersecting face pairs in this shape.
    /// The shape is meshed automatically.
    /// - Parameters:
    ///   - tolerance: Overlap tolerance (default: 0.0).
    ///   - maxPairs: Output *capacity* (default: 100), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    ///   - deflection: Linear mesh deflection (mm) for the detection triangulation. Default `0.1`.
    /// - Returns: Array of overlapping face index pairs, empty if none found.
    public func selfIntersectionPairs(tolerance: Double = 0.0,
                                       maxPairs: Int = 100,
                                       deflection: Double = 0.1) -> [OverlapPair] {
        let maxPairs = Sampling.capacity(maxPairs)
        guard maxPairs > 0 else { return [] }
        var idx1 = [Int32](repeating: 0, count: maxPairs)
        var idx2 = [Int32](repeating: 0, count: maxPairs)
        let count = OCCTShapeSelfIntersectionPairs(handle, tolerance, &idx1, &idx2, Int32(maxPairs), deflection)
        guard count > 0 else { return [] }
        return (0..<Int(count)).map {
            OverlapPair(faceIndex1: Int(idx1[$0]), faceIndex2: Int(idx2[$0]))
        }
    }
}

// --- Geom_OffsetCurve basis curve ---

extension Curve3D {

    /// Get the basis curve of this offset curve.
    /// - Returns: The basis curve, or nil if this is not an offset curve.
    public var offsetBasisCurve: Curve3D? {
        guard let ref = OCCTCurve3DOffsetBasis(handle) else { return nil }
        return Curve3D(handle: ref)
    }
}

// --- APIHeaderSection_MakeHeader ---


// --- ShapeAnalysis_FreeBounds simplified API ---

extension Shape {

    /// Count the number of closed free-boundary wires.
    /// - Parameter tolerance: Sewing tolerance for boundary detection.
    /// - Returns: Number of closed free-boundary wires.
    public func freeBoundsClosedCount(tolerance: Double = 1e-6) -> Int {
        Int(OCCTShapeFreeBoundsClosedCount(handle, tolerance))
    }

    /// Get the compound of closed free-boundary wires.
    /// - Parameter tolerance: Sewing tolerance for boundary detection.
    /// - Returns: Compound shape of closed wires, or nil if none.
    public func freeBoundsClosedWires(tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeFreeBoundsClosed(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Get the compound of open free-boundary wires.
    /// - Parameter tolerance: Sewing tolerance for boundary detection.
    /// - Returns: Compound shape of open wires, or nil if none.
    public func freeBoundsOpenWires(tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeFreeBoundsOpen(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - Geom_TrimmedCurve (v0.101.0)

extension Curve3D {

    /// Create a trimmed curve from this curve between parameters u1 and u2.
    public func trimmed(u1: Double, u2: Double) -> Curve3D? {
        guard let ref = OCCTCurve3DTrimmed(handle, u1, u2) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Get the basis curve of a trimmed curve (nil if not trimmed).
    public var trimmedBasis: Curve3D? {
        guard let ref = OCCTCurve3DTrimmedBasis(handle) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Change the trim parameters on a trimmed curve.
    @discardableResult
    public func setTrim(u1: Double, u2: Double) -> Bool {
        OCCTCurve3DSetTrim(handle, u1, u2)
    }
}

// MARK: - BRepLib_FindSurface (v0.101.0)

extension Shape {

    /// Find a surface (typically plane) through the edges of this shape.
    public func findSurface(tolerance: Double = -1, onlyPlane: Bool = false) -> Surface? {
        guard let ref = OCCTFindSurface(handle, tolerance, onlyPlane) else { return nil }
        return Surface(handle: ref)
    }

    /// Find surface tolerance reached.
    public func findSurfaceTolerance(tolerance: Double = -1, onlyPlane: Bool = false) -> Double? {
        let tol = OCCTFindSurfaceTolerance(handle, tolerance, onlyPlane)
        return tol >= 0 ? tol : nil
    }

    /// Check if a surface already existed on the shape edges.
    public func findSurfaceExisted(tolerance: Double = -1, onlyPlane: Bool = false) -> Bool {
        OCCTFindSurfaceExisted(handle, tolerance, onlyPlane)
    }
}

// MARK: - ShapeAnalysis_Surface (v0.101.0)

extension Surface {

    /// Project a 3D point onto this surface using ShapeAnalysis_Surface, returning UV parameters and gap.
    /// Unlike `projectPoint(_:)` (GeomAPI), this uses ShapeAnalysis for robust projection.
    public func projectPointUV(_ point: SIMD3<Double>, precision: Double = 1e-6) -> (u: Double, v: Double, gap: Double) {
        var u = 0.0, v = 0.0
        let gap = OCCTSurfaceProjectPointUV(handle, point.x, point.y, point.z, precision, &u, &v)
        return (u, v, gap)
    }

    /// Check if surface has singularities using ShapeAnalysis_Surface at the given precision.
    public func hasSingularitiesSA(precision: Double = 1e-6) -> Bool {
        OCCTSurfaceHasSingularities(handle, precision)
    }

    /// Number of singularities using ShapeAnalysis_Surface.
    public func singularityCountSA(precision: Double = 1e-6) -> Int {
        Int(OCCTSurfaceNbSingularities(handle, precision))
    }

    /// Check if surface is spatially U-closed using ShapeAnalysis_Surface.
    public func isUClosedSA(precision: Double = -1) -> Bool {
        OCCTSurfaceIsUClosedSA(handle, precision)
    }

    /// Check if surface is spatially V-closed using ShapeAnalysis_Surface.
    public func isVClosedSA(precision: Double = -1) -> Bool {
        OCCTSurfaceIsVClosedSA(handle, precision)
    }
}

// MARK: - Resource_Manager (v0.101.0)


// MARK: - TopExp Adjacency (v0.102.0)

extension Shape {

    /// Get the first (FORWARD) vertex position of an edge shape.
    public func edgeFirstVertex() -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTEdgeFirstVertex(handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Get the last (REVERSED) vertex position of an edge shape.
    public func edgeLastVertex() -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTEdgeLastVertex(handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Get both vertex positions of an edge shape.
    public func edgeVertices() -> (first: SIMD3<Double>, last: SIMD3<Double>)? {
        var x1 = 0.0, y1 = 0.0, z1 = 0.0, x2 = 0.0, y2 = 0.0, z2 = 0.0
        guard OCCTEdgeVertices(handle, &x1, &y1, &z1, &x2, &y2, &z2) else { return nil }
        return (SIMD3(x1, y1, z1), SIMD3(x2, y2, z2))
    }

    /// Get first and last vertex positions of a wire shape. For closed wires, both are the same.
    public func wireVertices() -> (first: SIMD3<Double>, last: SIMD3<Double>)? {
        var x1 = 0.0, y1 = 0.0, z1 = 0.0, x2 = 0.0, y2 = 0.0, z2 = 0.0
        guard OCCTWireVertices(handle, &x1, &y1, &z1, &x2, &y2, &z2) else { return nil }
        return (SIMD3(x1, y1, z1), SIMD3(x2, y2, z2))
    }

    /// Find common vertex between two edge shapes. Returns nil if no shared vertex.
    public func commonVertex(with other: Shape) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTEdgeCommonVertex(handle, other.handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Build edge→face adjacency. Returns array where each element is the number of faces sharing that edge.
    public func edgeFaceAdjacency() -> [Int] {
        let count = Int(OCCTEdgeFaceAdjacency(handle, nil))
        guard count > 0 else { return [] }
        var counts = [Int32](repeating: 0, count: count)
        _ = OCCTEdgeFaceAdjacency(handle, &counts)
        return counts.map { Int($0) }
    }

    /// Build vertex→edge adjacency. Returns array where each element is the number of edges sharing that vertex.
    public func vertexEdgeAdjacency() -> [Int] {
        let count = Int(OCCTVertexEdgeAdjacency(handle, nil))
        guard count > 0 else { return [] }
        var counts = [Int32](repeating: 0, count: count)
        _ = OCCTVertexEdgeAdjacency(handle, &counts)
        return counts.map { Int($0) }
    }

    /// The 0-based indices of the faces adjacent to `edge` within this shape.
    ///
    /// The indices address the same enumeration ``Shape/face(at:)`` reads, so they can be handed
    /// straight to it. They used to be 1-based, which named the face before the intended one and
    /// could never name face 0 (#541).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let edge = box.subShapes(ofType: .edge).first!
    /// for i in box.adjacentFaces(forEdge: edge) {
    ///     print(box.face(at: i)!.area())   // the two faces meeting at that edge
    /// }
    /// ```
    public func adjacentFaces(forEdge edge: Shape) -> [Int] {
        var indices = [Int32](repeating: 0, count: 64)
        let count = Int(OCCTEdgeAdjacentFaces(handle, edge.handle, &indices, 64))
        return indices.prefix(count).map { Int($0) }
    }

    /// The 0-based indices of the edges meeting `vertex` within this shape.
    ///
    /// The indices address the same enumeration ``Shape/subShape(type:index:)`` reads for
    /// `.edge`. They used to be 1-based (#541).
    public func adjacentEdges(forVertex vertex: Shape) -> [Int] {
        var indices = [Int32](repeating: 0, count: 64)
        let count = Int(OCCTVertexAdjacentEdges(handle, vertex.handle, &indices, 64))
        return indices.prefix(count).map { Int($0) }
    }
}

// MARK: - Poly_Connect Mesh Adjacency (v0.102.0)

extension Shape {

    /// Get adjacent triangles for a triangle in a meshed face.
    /// The three triangles adjacent to one triangle of a face's triangulation.
    ///
    /// `faceIndex` is 0-based, like ``Face/index`` and every other face index in this API (#541).
    /// `triangleIndex` and the returned neighbour indices are `Poly_Triangulation`'s own 1-based
    /// triangle numbers; 0 means no neighbour on that side.
    public func meshTriangleAdjacency(faceIndex: Int, triangleIndex: Int) -> (Int, Int, Int)? {
        var a1: Int32 = 0, a2: Int32 = 0, a3: Int32 = 0
        guard OCCTMeshTriangleAdjacency(handle, Int32(faceIndex), Int32(triangleIndex), &a1, &a2, &a3) else {
            return nil
        }
        return (Int(a1), Int(a2), Int(a3))
    }

    /// A triangle containing the given node of a face's triangulation.
    ///
    /// `faceIndex` is 0-based (#541); `nodeIndex` and the returned triangle index are
    /// `Poly_Triangulation`'s own 1-based numbers.
    public func meshNodeTriangle(faceIndex: Int, nodeIndex: Int) -> Int? {
        let idx = Int(OCCTMeshNodeTriangle(handle, Int32(faceIndex), Int32(nodeIndex)))
        return idx > 0 ? idx : nil
    }

    /// Count triangles sharing a node (triangle fan count).
    ///
    /// `faceIndex` is 0-based (#541); `nodeIndex` is `Poly_Triangulation`'s own 1-based number.
    public func meshNodeTriangleCount(faceIndex: Int, nodeIndex: Int) -> Int {
        Int(OCCTMeshNodeTriangleCount(handle, Int32(faceIndex), Int32(nodeIndex)))
    }
}

// MARK: - BRepOffset_Analyse Edge Classification (v0.102.0)

extension Shape {

    /// Concavity classification for edges.
    public enum ConcavityType: Int, Sendable {
        case convex = 0
        case concave = 1
        case tangent = 2
        case freeBound = 3
        case other = 4
    }

    /// Analyze edge concavity for all edges. angle is the tangency threshold in radians.
    public func analyseEdgeConcavity(angle: Double = .pi / 6.0) -> [ConcavityType] {
        let count = Int(OCCTAnalyseEdgeConcavity(handle, angle, nil))
        guard count > 0 else { return [] }
        var types = [Int32](repeating: 0, count: count)
        _ = OCCTAnalyseEdgeConcavity(handle, angle, &types)
        return types.map { ConcavityType(rawValue: Int($0)) ?? .other }
    }

    /// Explode shape into groups of faces connected by edges of a given concavity type.
    public func analyseExplode(angle: Double = .pi / 6.0, type: ConcavityType) -> Shape? {
        guard let ref = OCCTAnalyseExplode(handle, angle, Int32(type.rawValue)) else { return nil }
        return Shape(handle: ref)
    }

    /// Count edges of a given concavity type on a specific face.
    public func analyseEdgesOnFace(_ face: Shape, angle: Double = .pi / 6.0, type: ConcavityType) -> Int {
        Int(OCCTAnalyseEdgesOnFace(handle, angle, face.handle, Int32(type.rawValue)))
    }

    /// Count ancestor faces for an edge in offset analysis.
    public func analyseAncestorCount(edge: Shape, angle: Double = .pi / 6.0) -> Int {
        Int(OCCTAnalyseAncestorCount(handle, angle, edge.handle))
    }

    /// Count tangent edges at a vertex along a given edge.
    public func analyseTangentEdgeCount(edge: Shape, vertex: Shape, angle: Double = .pi / 6.0) -> Int {
        Int(OCCTAnalyseTangentEdgeCount(handle, angle, edge.handle, vertex.handle))
    }
}

// MARK: - BRepTools_WireExplorer Extensions (v0.102.0)

extension Shape {

    /// Edge orientation from wire explorer.
    public enum EdgeOrientation: Int, Sendable {
        case forward = 0
        case reversed = 1
        case `internal` = 2
        case external = 3
    }

    /// Get edge orientations within a wire, optionally with face context.
    public func wireEdgeOrientations(face: Shape? = nil) -> [EdgeOrientation] {
        let count = Int(OCCTWireExplorerOrientations(handle, face?.handle, nil))
        guard count > 0 else { return [] }
        var orientations = [Int32](repeating: 0, count: count)
        _ = OCCTWireExplorerOrientations(handle, face?.handle, &orientations)
        return orientations.map { EdgeOrientation(rawValue: Int($0)) ?? .forward }
    }

    /// Get connecting vertex positions from wire explorer (vertex between consecutive edges).
    public func wireExplorerVertices(face: Shape? = nil) -> [SIMD3<Double>] {
        let count = Int(OCCTWireExplorerVertices(handle, face?.handle, nil, nil, nil))
        guard count > 0 else { return [] }
        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)
        var zs = [Double](repeating: 0, count: count)
        _ = OCCTWireExplorerVertices(handle, face?.handle, &xs, &ys, &zs)
        return (0..<count).map { SIMD3(xs[$0], ys[$0], zs[$0]) }
    }
}

// MARK: - BndLib Analytic Bounding (v0.104.0)



// MARK: - OSD_Host (v0.104.0)


// MARK: - OSD_PerfMeter (v0.104.0)


// MARK: - GProp Cylinder/Cone (v0.104.0)


// MARK: - IntAna_IntQuadQuad (v0.104.0)


// MARK: - XCAFPrs_DocumentExplorer (v0.104.0)

extension Document {
    /// Count leaf shape nodes in the document.
    public var explorerNodeCount: Int {
        Int(OCCTDocumentExplorerCount(handle))
    }

    /// Get shape at index from document explorer (0-based).
    public func explorerShape(at index: Int) -> Shape? {
        guard let ref = OCCTDocumentExplorerShape(handle, Int32(index)) else { return nil }
        return Shape(handle: ref)
    }

    /// Get path ID at index from document explorer.
    public func explorerPathId(at index: Int) -> String? {
        guard let ptr = OCCTDocumentExplorerPathId(handle, Int32(index)) else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    /// Find shape from path ID string.
    public func explorerFindShape(pathId: String) -> Shape? {
        guard let ref = OCCTDocumentExplorerFindShape(handle, pathId) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - gce Transform Factories (v0.103.0)





// MARK: - GProp Element Properties (v0.103.0)


// MARK: - Plate Constraint Extensions (v0.103.0)

extension PlateSolver {
    /// Load a plane constraint at UV point.
    @discardableResult
    public func loadPlaneConstraint(u: Double, v: Double, planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>) -> Bool {
        OCCTPlateLoadPlaneConstraint(handle, u, v,
                                      planePoint.x, planePoint.y, planePoint.z,
                                      planeNormal.x, planeNormal.y, planeNormal.z)
    }

    /// Load a line constraint at UV point.
    @discardableResult
    public func loadLineConstraint(u: Double, v: Double, linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>) -> Bool {
        OCCTPlateLoadLineConstraint(handle, u, v,
                                     linePoint.x, linePoint.y, linePoint.z,
                                     lineDirection.x, lineDirection.y, lineDirection.z)
    }

    /// Load a free G1 continuity constraint at UV point.
    @discardableResult
    public func loadFreeG1Constraint(u: Double, v: Double, du: SIMD3<Double>, dv: SIMD3<Double>) -> Bool {
        OCCTPlateLoadFreeG1Constraint(handle, u, v, du.x, du.y, du.z, dv.x, dv.y, dv.z)
    }
}

// MARK: - Law_Interpolate (v0.103.0)

extension LawFunction {
    /// Create an interpolated law function from values.
    public static func interpolated(values: [Double], parameters: [Double]? = nil, periodic: Bool = false) -> LawFunction? {
        let ref: OCCTLawFunctionRef?
        if let params = parameters {
            ref = params.withUnsafeBufferPointer { paramBuf in
                values.withUnsafeBufferPointer { valBuf in
                    OCCTLawInterpolate(valBuf.baseAddress!, Int32(values.count), paramBuf.baseAddress!, periodic)
                }
            }
        } else {
            ref = values.withUnsafeBufferPointer { valBuf in
                OCCTLawInterpolate(valBuf.baseAddress!, Int32(values.count), nil, periodic)
            }
        }
        guard let r = ref else { return nil }
        return LawFunction(handle: r)
    }
}

// MARK: - Bnd_Sphere (v0.103.0)


// MARK: - GC_MakeCircle (v0.105.0)

extension Curve3D {
    /// Create a 3D circle from axis (center + normal) and radius.
    public static func gcCircle(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeCircle(center.x, center.y, center.z,
                                          normal.x, normal.y, normal.z, radius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D circle through 3 points.
    public static func gcCircle(p1: SIMD3<Double>, p2: SIMD3<Double>, p3: SIMD3<Double>) -> Curve3D? {
        guard let ref = OCCTGCMakeCircle3Points(p1.x, p1.y, p1.z,
                                                  p2.x, p2.y, p2.z,
                                                  p3.x, p3.y, p3.z) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D circle from center, normal, and radius (alias).
    public static func gcCircleCenterNormal(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeCircleCenterNormal(center.x, center.y, center.z,
                                                       normal.x, normal.y, normal.z, radius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D circle parallel to an existing circle at given distance.
    public static func gcCircleParallel(center: SIMD3<Double>, normal: SIMD3<Double>,
                                         radius: Double, distance: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeCircleParallel(center.x, center.y, center.z,
                                                   normal.x, normal.y, normal.z,
                                                   radius, distance) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - GC_MakeEllipse (v0.105.0)

extension Curve3D {
    /// Create a 3D ellipse from axis and major/minor radii.
    ///
    /// - Parameters:
    ///   - center: Ellipse centre.
    ///   - normal: Normal of the plane the ellipse lies in.
    ///   - majorRadius: Major radius. Must be `> 0`.
    ///   - minorRadius: Minor radius. Must be `> 0` and no larger than `majorRadius`.
    /// - Returns: The ellipse, or `nil` if the radii do not describe one.
    ///
    /// `GC_MakeEllipse` reports `!IsDone()` for negative and inverted radii on its own, but
    /// accepts zero; the radii are checked here so every route to an ellipse enforces the same
    /// contract as `Curve3D.ellipse(center:normal:majorRadius:minorRadius:)`.
    ///
    /// ```swift
    /// let e = Curve3D.gcEllipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                           majorRadius: 10, minorRadius: 5)
    /// #expect(e != nil)
    /// #expect(Curve3D.gcEllipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                           majorRadius: 10, minorRadius: 0) == nil)
    /// ```
    public static func gcEllipse(center: SIMD3<Double>, normal: SIMD3<Double>,
                                  majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeEllipse(center.x, center.y, center.z,
                                            normal.x, normal.y, normal.z,
                                            majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D ellipse from 3 points (S1, S2, center).
    public static func gcEllipse(s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>) -> Curve3D? {
        guard let ref = OCCTGCMakeEllipse3Points(s1.x, s1.y, s1.z,
                                                    s2.x, s2.y, s2.z,
                                                    center.x, center.y, center.z) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D ellipse from full Ax2 (center + normal + X direction) and radii.
    ///
    /// Same radius contract as `gcEllipse(center:normal:majorRadius:minorRadius:)`; this overload
    /// only adds control over where the major axis points.
    ///
    /// ```swift
    /// let e = Curve3D.gcEllipse(center: .zero, normal: SIMD3(0, 0, 1),
    ///                           xDirection: SIMD3(1, 0, 0),
    ///                           majorRadius: 10, minorRadius: 5)
    /// #expect(e != nil)
    /// ```
    public static func gcEllipse(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                                  majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeEllipseFromElips(center.x, center.y, center.z,
                                                      normal.x, normal.y, normal.z,
                                                      xDirection.x, xDirection.y, xDirection.z,
                                                      majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - GC_MakeHyperbola (v0.105.0)

extension Curve3D {
    /// Create a 3D hyperbola from axis and major/minor radii.
    ///
    /// - Parameters:
    ///   - center: Hyperbola centre.
    ///   - normal: Normal of the plane the hyperbola lies in.
    ///   - majorRadius: Major radius. Must be `> 0`.
    ///   - minorRadius: Minor radius. Must be `> 0`. No ordering constraint against the major.
    /// - Returns: The hyperbola, or `nil` if either radius is `<= 0`.
    ///
    /// ```swift
    /// let h = Curve3D.gcHyperbola(center: .zero, normal: SIMD3(0, 0, 1),
    ///                             majorRadius: 8, minorRadius: 3)
    /// #expect(h != nil)
    /// #expect(Curve3D.gcHyperbola(center: .zero, normal: SIMD3(0, 0, 1),
    ///                             majorRadius: 0, minorRadius: 3) == nil)
    /// ```
    public static func gcHyperbola(center: SIMD3<Double>, normal: SIMD3<Double>,
                                    majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeHyperbola(center.x, center.y, center.z,
                                              normal.x, normal.y, normal.z,
                                              majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D hyperbola from 3 points (S1, S2, center).
    public static func gcHyperbola(s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>) -> Curve3D? {
        guard let ref = OCCTGCMakeHyperbola3Points(s1.x, s1.y, s1.z,
                                                      s2.x, s2.y, s2.z,
                                                      center.x, center.y, center.z) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - GC_MakeCircle2d (v0.105.0)

extension Curve2D {
    /// Create a 2D circle from center and radius.
    public static func gceCircle(center: SIMD2<Double>, radius: Double) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeCircleCenterRadius(center.x, center.y, radius) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle through 3 points.
    public static func gceCircle(p1: SIMD2<Double>, p2: SIMD2<Double>, p3: SIMD2<Double>) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeCircle3Points(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle from center and point on circle.
    public static func gceCircle(center: SIMD2<Double>, pointOn: SIMD2<Double>) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeCircleCenterPoint(center.x, center.y, pointOn.x, pointOn.y) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle parallel to existing circle at distance.
    public static func gceCircleParallel(center: SIMD2<Double>, direction: SIMD2<Double>,
                                          radius: Double, distance: Double) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeCircleParallel(center.x, center.y,
                                                      direction.x, direction.y,
                                                      radius, distance) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle from axis and radius.
    public static func gceCircle(axisCenter: SIMD2<Double>, axisDirection: SIMD2<Double>,
                                  radius: Double) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeCircleAxis(axisCenter.x, axisCenter.y,
                                                  axisDirection.x, axisDirection.y,
                                                  radius) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - GC_MakeEllipse2d (v0.105.0)

extension Curve2D {
    /// Create a 2D ellipse from axis and radii.
    public static func gceEllipse(center: SIMD2<Double>, xDirection: SIMD2<Double>,
                                   majorRadius: Double, minorRadius: Double) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeEllipse(center.x, center.y,
                                               xDirection.x, xDirection.y,
                                               majorRadius, minorRadius) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D ellipse from 3 points (S1, S2, center).
    public static func gceEllipse(s1: SIMD2<Double>, s2: SIMD2<Double>, center: SIMD2<Double>) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeEllipse3Points(s1.x, s1.y, s2.x, s2.y,
                                                      center.x, center.y) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D ellipse from full Ax22d and radii.
    public static func gceEllipse(center: SIMD2<Double>, xDirection: SIMD2<Double>,
                                   yDirection: SIMD2<Double>,
                                   majorRadius: Double, minorRadius: Double) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeEllipseAxis22d(center.x, center.y,
                                                      xDirection.x, xDirection.y,
                                                      yDirection.x, yDirection.y,
                                                      majorRadius, minorRadius) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - GC_MakeHyperbola2d (v0.105.0)

extension Curve2D {
    /// Create a 2D hyperbola from axis and radii.
    public static func gceHyperbola(center: SIMD2<Double>, xDirection: SIMD2<Double>,
                                     majorRadius: Double, minorRadius: Double) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeHyperbola(center.x, center.y,
                                                 xDirection.x, xDirection.y,
                                                 majorRadius, minorRadius) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D hyperbola from 3 points (S1, S2, center).
    public static func gceHyperbola(s1: SIMD2<Double>, s2: SIMD2<Double>, center: SIMD2<Double>) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeHyperbola3Points(s1.x, s1.y, s2.x, s2.y,
                                                        center.x, center.y) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - GC_MakeParabola2d (v0.105.0)

extension Curve2D {
    /// Create a 2D parabola from axis and focal distance.
    public static func gceParabola(center: SIMD2<Double>, direction: SIMD2<Double>,
                                    focalDistance: Double) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeParabola(center.x, center.y,
                                                direction.x, direction.y, focalDistance) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D parabola from directrix and focus.
    public static func gceParabola(directrixPoint: SIMD2<Double>, directrixDirection: SIMD2<Double>,
                                    focus: SIMD2<Double>) -> Curve2D? {
        guard let ref = OCCTCurve2DMakeParabolaDirectrixFocus(directrixPoint.x, directrixPoint.y,
                                                              directrixDirection.x, directrixDirection.y,
                                                              focus.x, focus.y) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - GCPnts_UniformAbscissa (v0.105.0)

extension Shape {
    /// Uniformly sample an edge by point count. Returns parameter values.
    ///
    /// - Parameter pointCount: Desired number of samples, honoured within `2...`
    ///   ``Sampling/maximumSampleCount``, else `nil`. OCCT's sampler documents the lower bound but
    ///   cannot enforce it in a Release kernel, and used to answer a request for zero with five
    ///   parameters (#501); the upper bound is this layer's, since `pointCount` is cast to the
    ///   bridge's `int32_t` and used to abort the process past it (#558).
    public func uniformAbscissa(pointCount: Int) -> [Double]? {
        guard let pointCount = Sampling.requested(pointCount) else { return nil }
        let n = Int(OCCTUniformAbscissaByCount(handle, Int32(pointCount), nil))
        guard n > 0 else { return nil }
        var params = [Double](repeating: 0, count: n)
        _ = OCCTUniformAbscissaByCount(handle, Int32(pointCount), &params)
        return params
    }

    /// Uniformly sample an edge by arc distance. Returns parameter values.
    public func uniformAbscissa(distance: Double) -> [Double]? {
        let n = Int(OCCTUniformAbscissaByDistance(handle, distance, nil))
        guard n > 0 else { return nil }
        var params = [Double](repeating: 0, count: n)
        _ = OCCTUniformAbscissaByDistance(handle, distance, &params)
        return params
    }

    /// Uniformly sample an edge by point count within parameter range.
    ///
    /// - Parameter pointCount: Desired number of samples, honoured within `2...`
    ///   ``Sampling/maximumSampleCount``, else `nil` (#501, #558).
    public func uniformAbscissa(pointCount: Int, u1: Double, u2: Double) -> [Double]? {
        guard let pointCount = Sampling.requested(pointCount) else { return nil }
        let n = Int(OCCTUniformAbscissaByCountRange(handle, Int32(pointCount), u1, u2, nil))
        guard n > 0 else { return nil }
        var params = [Double](repeating: 0, count: n)
        _ = OCCTUniformAbscissaByCountRange(handle, Int32(pointCount), u1, u2, &params)
        return params
    }

    /// Uniformly sample an edge by arc distance within parameter range.
    public func uniformAbscissa(distance: Double, u1: Double, u2: Double) -> [Double]? {
        let n = Int(OCCTUniformAbscissaByDistanceRange(handle, distance, u1, u2, nil))
        guard n > 0 else { return nil }
        var params = [Double](repeating: 0, count: n)
        _ = OCCTUniformAbscissaByDistanceRange(handle, distance, u1, u2, &params)
        return params
    }
}

// MARK: - GeomConvert_CompCurveToBSplineCurve (v0.105.0)

extension Curve3D {
    /// Concatenate multiple bounded 3D curves into a single BSpline.
    public static func concatenate(_ curves: [Curve3D], tolerance: Double = 1e-4) -> Curve3D? {
        guard !curves.isEmpty else { return nil }
        var handles = curves.map { $0.handle as OCCTCurve3DRef }
        guard let ref = OCCTConcatenateCurves3D(&handles, Int32(curves.count), tolerance) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - Geom2dConvert_CompCurveToBSplineCurve (v0.105.0)

extension Curve2D {
    /// Concatenate multiple bounded 2D curves into a single BSpline.
    public static func concatenate(_ curves: [Curve2D], tolerance: Double = 1e-4) -> Curve2D? {
        guard !curves.isEmpty else { return nil }
        var handles = curves.map { $0.handle as OCCTCurve2DRef }
        guard let ref = OCCTConcatenateCurves2D(&handles, Int32(curves.count), tolerance) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - Knot splitting, the v0.105.0 spellings (deprecated, #562)

// These five entry points were added over `GeomConvert_BSplineSurfaceKnotSplitting` and
// `Geom2dConvert_BSplineCurveKnotSplitting` three releases after `Surface.knotSplitting` and
// `Curve2D.splitIndicesAtDiscontinuities` already wrapped those same two analyzers. Nothing
// reconciled them, so the same question had two spellings that could not be asked to differ:
// both of these take one continuity for both parametric directions where the surface's canonical
// call takes one per direction, and neither reaches a knot the canonical call cannot.
//
// Each now forwards to its canonical sibling. Their own five bridge functions are gone.
// `continuity` is the same derivative-order ContinuityRange throughout: a knot splits only when
// `degree - multiplicity < continuity`, so the meaningful range is 0...degree and it saturates
// there (#480).

extension Surface {
    /// Get number of U-direction knot splits for a BSpline surface at given continuity.
    @available(*, deprecated,
               message: "Use knotSplitting(uContinuity:vContinuity:).uSplitCount, which asks the same analyzer once instead of three times and can ask U and V different questions (#562)")
    public func bsplineKnotSplitsU(continuity: ParametricContinuity) -> Int {
        knotSplitting(uContinuity: continuity, vContinuity: continuity).uSplitCount
    }

    /// Get number of V-direction knot splits for a BSpline surface at given continuity.
    @available(*, deprecated,
               message: "Use knotSplitting(uContinuity:vContinuity:).vSplitCount, which asks the same analyzer once instead of three times and can ask U and V different questions (#562)")
    public func bsplineKnotSplitsV(continuity: ParametricContinuity) -> Int {
        knotSplitting(uContinuity: continuity, vContinuity: continuity).vSplitCount
    }

    /// Get U and V knot split index arrays.
    @available(*, deprecated,
               message: "Use knotSplitting(uContinuity:vContinuity:), whose uSplitIndices/vSplitIndices are these same indices and which also gives you the parameters they resolve to (#562)")
    public func bsplineKnotSplitValues(continuity: ParametricContinuity) -> (uSplits: [Int32], vSplits: [Int32]) {
        let result = knotSplitting(uContinuity: continuity, vContinuity: continuity)
        return (result.uSplitIndices.map(Int32.init), result.vSplitIndices.map(Int32.init))
    }
}

extension Curve2D {
    /// Get number of knot splits for a 2D BSpline curve at given continuity.
    @available(*, deprecated,
               message: "Use splitIndicesAtDiscontinuities(continuity:)?.count, the same analyzer under one spelling (#562)")
    public func bsplineKnotSplits(continuity: ParametricContinuity) -> Int {
        splitIndicesAtDiscontinuities(continuity: continuity)?.count ?? 0
    }

    /// Get knot split indices for a 2D BSpline curve at given continuity.
    @available(*, deprecated,
               message: "Use splitIndicesAtDiscontinuities(continuity:), which returns these same indices as [Int] and nil rather than [] for a non-BSpline curve (#562)")
    public func bsplineKnotSplitValues(continuity: ParametricContinuity) -> [Int32] {
        splitIndicesAtDiscontinuities(continuity: continuity)?.map(Int32.init) ?? []
    }
}

// MARK: - BndLib extras (v0.105.0)


// MARK: - GProp Torus (v0.105.0)


// MARK: - BRepTools_ReShape (v0.105.0)


// MARK: - BRepTools_Substitution (v0.105.0)

extension Shape {
    /// Substitute a subshape with a list of new shapes. Pass empty array to remove.
    public func substitute(oldSubShape: Shape, newSubShapes: [Shape]) -> Shape? {
        if newSubShapes.isEmpty {
            return withUnsafePointer(to: Optional<OCCTShapeRef>.none) { _ in
                guard let h = OCCTShapeSubstitute(handle, oldSubShape.handle, nil, 0) else { return nil }
                return Shape(handle: h)
            }
        }
        var handles = newSubShapes.map { $0.handle as OCCTShapeRef? }
        return handles.withUnsafeMutableBufferPointer { buf in
            guard let h = OCCTShapeSubstitute(handle, oldSubShape.handle, buf.baseAddress, Int32(newSubShapes.count)) else {
                return nil
            }
            return Shape(handle: h)
        }
    }

    /// Check if a subshape was copied during substitution.
    public func substitutionIsCopied(subshape: Shape) -> Bool {
        OCCTSubstitutionIsCopied(handle, subshape.handle)
    }
}

// MARK: - BRepLib_MakeVertex (v0.105.0)

extension Shape {
    /// Create a vertex shape at the given point using BRepLib_MakeVertex.
    public static func makeVertex(at point: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTMakeVertex(point.x, point.y, point.z) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - BRepFill_PipeShell (v0.105.0)



// MARK: - OSD_Directory (v0.105.0)


// MARK: - IntAna Cone-Sphere extensions (v0.105.0)


// MARK: - XCAFPrs_DocumentExplorer extensions (v0.105.0)

extension Document {
    /// Get the depth of a document explorer node at given index.
    public func explorerDepth(at index: Int) -> Int {
        Int(OCCTDocumentExplorerDepth(handle, Int32(index)))
    }

    /// Check if a document explorer node is an assembly.
    public func explorerIsAssembly(at index: Int) -> Bool {
        OCCTDocumentExplorerIsAssembly(handle, Int32(index))
    }

    /// Get the location matrix (12 doubles, row-major 3x4) for a document explorer node.
    public func explorerLocation(at index: Int) -> [Double] {
        var matrix = [Double](repeating: 0, count: 12)
        OCCTDocumentExplorerLocation(handle, Int32(index), &matrix)
        return matrix
    }
}

// MARK: - Resource_Unicode (v0.105.0)



// MARK: - GProp weighted point sets (v0.105.0)


// MARK: - Draft info types (v0.105.0)


// MARK: - GeomLib_LogSample (v0.105.0)


// MARK: - GC_MakeConicalSurface (v0.106.0)

extension Surface {
    /// Create a conical surface from axis (center+normal), semi-angle, and reference radius.
    public static func gcConicalSurface(center: SIMD3<Double>, normal: SIMD3<Double>,
                                         semiAngle: Double, radius: Double) -> Surface? {
        guard let h = OCCTGCMakeConicalSurface(center.x, center.y, center.z,
                                                normal.x, normal.y, normal.z,
                                                semiAngle, radius) else { return nil }
        return Surface(handle: h)
    }

    /// Create a conical surface from 2 points and 2 radii.
    public static func gcConicalSurface2Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                             r1: Double, r2: Double) -> Surface? {
        guard let h = OCCTGCMakeConicalSurface2Pts(p1.x, p1.y, p1.z,
                                                    p2.x, p2.y, p2.z,
                                                    r1, r2) else { return nil }
        return Surface(handle: h)
    }

    /// Create a conical surface from 4 points (2 on each circle).
    public static func gcConicalSurface4Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                             p3: SIMD3<Double>, p4: SIMD3<Double>) -> Surface? {
        guard let h = OCCTGCMakeConicalSurface4Pts(p1.x, p1.y, p1.z,
                                                    p2.x, p2.y, p2.z,
                                                    p3.x, p3.y, p3.z,
                                                    p4.x, p4.y, p4.z) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - GC_MakeCylindricalSurface (v0.106.0)

extension Surface {
    /// Create a cylindrical surface from axis (center+normal) and radius (GC variant).
    public static func gcCylindricalSurface(center: SIMD3<Double>, normal: SIMD3<Double>,
                                              radius: Double) -> Surface? {
        guard let h = OCCTGCMakeCylindricalSurface(center.x, center.y, center.z,
                                                     normal.x, normal.y, normal.z,
                                                     radius) else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface from 3 points (GC variant).
    public static func gcCylindricalSurface3Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                                  p3: SIMD3<Double>) -> Surface? {
        guard let h = OCCTGCMakeCylindricalSurface3Pts(p1.x, p1.y, p1.z,
                                                        p2.x, p2.y, p2.z,
                                                        p3.x, p3.y, p3.z) else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface from a circle (center+normal+radius).
    public static func gcCylindricalSurfaceFromCircle(center: SIMD3<Double>, normal: SIMD3<Double>,
                                                       radius: Double) -> Surface? {
        guard let h = OCCTGCMakeCylindricalSurfaceFromCircle(center.x, center.y, center.z,
                                                               normal.x, normal.y, normal.z,
                                                               radius) else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface parallel to another at a given distance.
    public static func gcCylindricalSurfaceParallel(center: SIMD3<Double>, normal: SIMD3<Double>,
                                                      radius: Double, distance: Double) -> Surface? {
        guard let h = OCCTGCMakeCylindricalSurfaceParallel(center.x, center.y, center.z,
                                                             normal.x, normal.y, normal.z,
                                                             radius, distance) else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface from axis (point+direction) and radius.
    public static func gcCylindricalSurfaceAxis(point: SIMD3<Double>, direction: SIMD3<Double>,
                                                  radius: Double) -> Surface? {
        guard let h = OCCTGCMakeCylindricalSurfaceAxis(point.x, point.y, point.z,
                                                         direction.x, direction.y, direction.z,
                                                         radius) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - GC_MakeTrimmedCone (v0.106.0)

extension Surface {
    /// Create a trimmed cone from 2 points and 2 radii.
    public static func gcTrimmedCone2Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                          r1: Double, r2: Double) -> Surface? {
        guard let h = OCCTGCMakeTrimmedCone2Pts(p1.x, p1.y, p1.z,
                                                 p2.x, p2.y, p2.z,
                                                 r1, r2) else { return nil }
        return Surface(handle: h)
    }

    /// Create a trimmed cone from 4 points.
    public static func gcTrimmedCone4Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                          p3: SIMD3<Double>, p4: SIMD3<Double>) -> Surface? {
        guard let h = OCCTGCMakeTrimmedCone4Pts(p1.x, p1.y, p1.z,
                                                 p2.x, p2.y, p2.z,
                                                 p3.x, p3.y, p3.z,
                                                 p4.x, p4.y, p4.z) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - GC_MakeTrimmedCylinder (v0.106.0)

extension Surface {
    /// Create a trimmed cylinder from a circle (center+normal+radius) and height.
    public static func gcTrimmedCylinderCircle(center: SIMD3<Double>, normal: SIMD3<Double>,
                                                radius: Double, height: Double) -> Surface? {
        guard let h = OCCTGCMakeTrimmedCylinderCircle(center.x, center.y, center.z,
                                                       normal.x, normal.y, normal.z,
                                                       radius, height) else { return nil }
        return Surface(handle: h)
    }

    /// Create a trimmed cylinder from axis (point+direction), radius, and height.
    public static func gcTrimmedCylinderAxis(point: SIMD3<Double>, direction: SIMD3<Double>,
                                              radius: Double, height: Double) -> Surface? {
        guard let h = OCCTGCMakeTrimmedCylinderAxis(point.x, point.y, point.z,
                                                     direction.x, direction.y, direction.z,
                                                     radius, height) else { return nil }
        return Surface(handle: h)
    }

    /// Create a trimmed cylinder from 3 points.
    public static func gcTrimmedCylinder3Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                              p3: SIMD3<Double>) -> Surface? {
        guard let h = OCCTGCMakeTrimmedCylinder3Pts(p1.x, p1.y, p1.z,
                                                     p2.x, p2.y, p2.z,
                                                     p3.x, p3.y, p3.z) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - BRepLib_MakeEdge2d extensions (v0.106.0)

extension Shape {
    /// Create a 2D edge from a full circle.
    ///
    /// - Parameter radius: circle radius. Must be greater than zero.
    /// - Returns: the edge, or `nil` if the circle is degenerate.
    ///
    /// ```swift
    /// if let e = Shape.edge2dFullCircle(center: .zero, direction: SIMD2(1, 0), radius: 5) {
    ///     print(e.edges().count)   // 1
    /// }
    /// ```
    public static func edge2dFullCircle(center: SIMD2<Double>, direction: SIMD2<Double>,
                                         radius: Double) -> Shape? {
        guard let h = OCCTMakeEdge2dFullCircle(center.x, center.y,
                                                direction.x, direction.y,
                                                radius) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from an ellipse.
    ///
    /// - Parameters:
    ///   - majorRadius: semi-major axis. Must be greater than zero.
    ///   - minorRadius: semi-minor axis. Must be greater than zero and no larger than
    ///     `majorRadius`; equal radii are a circle and are valid.
    /// - Returns: the edge, or `nil` if the ellipse is degenerate. OCCT builds a zero-length edge
    ///   from a zero-radius ellipse, and a doubled-back segment from a zero minor radius.
    ///
    /// ```swift
    /// if let e = Shape.edge2dEllipse(center: .zero, direction: SIMD2(1, 0),
    ///                                majorRadius: 5, minorRadius: 3) {
    ///     print(e.edges().count)   // 1
    /// }
    /// ```
    public static func edge2dEllipse(center: SIMD2<Double>, direction: SIMD2<Double>,
                                      majorRadius: Double, minorRadius: Double) -> Shape? {
        guard let h = OCCTMakeEdge2dEllipse(center.x, center.y,
                                             direction.x, direction.y,
                                             majorRadius, minorRadius) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from an ellipse arc.
    ///
    /// - Parameters:
    ///   - majorRadius: semi-major axis. Must be greater than zero.
    ///   - minorRadius: semi-minor axis. Must be greater than zero and no larger than
    ///     `majorRadius`; equal radii are a circle and are valid.
    /// - Returns: the edge, or `nil` if the ellipse is degenerate.
    ///
    /// ```swift
    /// if let e = Shape.edge2dEllipseArc(center: .zero, direction: SIMD2(1, 0),
    ///                                   majorRadius: 5, minorRadius: 3, u1: 0, u2: .pi) {
    ///     print(e.edges().count)   // 1
    /// }
    /// ```
    public static func edge2dEllipseArc(center: SIMD2<Double>, direction: SIMD2<Double>,
                                         majorRadius: Double, minorRadius: Double,
                                         u1: Double, u2: Double) -> Shape? {
        guard let h = OCCTMakeEdge2dEllipseArc(center.x, center.y,
                                                direction.x, direction.y,
                                                majorRadius, minorRadius,
                                                u1, u2) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from a Curve2D.
    public static func edge2dFromCurve(_ curve: Curve2D) -> Shape? {
        guard let h = OCCTMakeEdge2dCurve(curve.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from a Curve2D with parameter range.
    public static func edge2dFromCurve(_ curve: Curve2D, u1: Double, u2: Double) -> Shape? {
        guard let h = OCCTMakeEdge2dCurveRange(curve.handle, u1, u2) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - ShapeAnalysis_Wire (v0.106.0)


// MARK: - ShapeAnalysis_Edge (v0.106.0)


// MARK: - OSD_DirectoryIterator (v0.106.0)


// MARK: - OSD_FileIterator (v0.106.0)


// MARK: - BRepFill_PipeShell extensions (v0.106.0)


// MARK: - Shape topology extensions (v0.106.0)

extension Shape {
    /// Shape orientation values.
    public enum Orientation: Int32, Sendable {
        case forward = 0
        case reversed = 1
        case `internal` = 2
        case external = 3
    }

    /// Get shape orientation.
    public var orientation: Orientation {
        Orientation(rawValue: OCCTShapeGetOrientation(handle)) ?? .forward
    }

    /// Set shape orientation.
    public func setOrientation(_ orient: Orientation) {
        OCCTShapeSetOrientation(handle, orient.rawValue)
    }

    /// Get a reversed copy of the shape.
    public var reversed: Shape? {
        guard let h = OCCTShapeReversed(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Get a complemented copy of the shape (reversed orientation).
    public var complemented: Shape? {
        guard let h = OCCTShapeComplemented(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Compose with another orientation.
    public func composed(with orient: Orientation) -> Shape? {
        guard let h = OCCTShapeComposed(handle, orient.rawValue) else { return nil }
        return Shape(handle: h)
    }

    /// Check if the shape's Free flag is set.
    public var isFree: Bool {
        OCCTShapeIsFree(handle)
    }

    /// Check if the shape's Modified flag is set.
    public var isModified: Bool {
        OCCTShapeIsModified(handle)
    }

    /// Check if the shape's Checked flag is set.
    public var isChecked: Bool {
        OCCTShapeIsChecked(handle)
    }

    /// Check if the shape's Orientable flag is set.
    public var isOrientable: Bool {
        OCCTShapeIsOrientable(handle)
    }

    /// Check if the shape's Infinite flag is set.
    public var isInfinite: Bool {
        OCCTShapeIsInfinite(handle)
    }

    /// Check if the shape's Convex flag is set.
    public var isConvex: Bool {
        OCCTShapeIsConvex(handle)
    }

    /// Check if the shape is empty (null underlying shape).
    public var isEmptyShape: Bool {
        OCCTShapeIsEmpty(handle)
    }

    /// Check if two shapes are partners (same TShape).
    public func isPartner(with other: Shape) -> Bool {
        OCCTShapeIsPartner(handle, other.handle)
    }

    /// Check if two shapes are equal (same TShape + same location + same orientation).
    public func isEqual(to other: Shape) -> Bool {
        OCCTShapeIsEqual(handle, other.handle)
    }

    /// Get the number of direct children sub-shapes.
    public var nbChildren: Int {
        Int(OCCTShapeNbChildren(handle))
    }

    /// Get the hash code of a shape.
    public var hashCode: Int {
        Int(OCCTShapeHashCode(handle))
    }
}

// MARK: - Curve3D continuity (v0.106.0)

extension Curve3D {
    /// Measured global continuity of the 3D curve, as a raw `GeomAbs_Shape` ordinal.
    ///
    /// The ordinals are `GeomAbs_Shape`'s own declared order — `0=C0, 1=G1, 2=C1, 3=G2,
    /// 4=C2, 5=C3, 6=CN` — not a 0/1/2 order. Prefer ``continuityClass``, which names them.
    ///
    /// ```swift
    /// // A cubic BSpline with a doubled interior knot is C1, which is ordinal 2 (not 1).
    /// print(bspline.continuity)        // 2
    /// print(bspline.continuityClass)   // .c1
    /// ```
    ///
    /// - Warning: This is the migration target for the retired `continuityOrder`, but it is not a
    ///   drop-in one: `continuityOrder` used to answer a different set of numbers
    ///   (`C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3`). A threshold moved across unchanged
    ///   reads as one class too low — `>= 2` accepts C1 here and accepted C2 there — and `== 99`
    ///   is now unreachable. Prefer ``continuityClass`` and ``ContinuityClass/satisfies(_:)``,
    ///   which cannot be compared against the wrong constant at all (#619).
    public var continuity: Int {
        Int(OCCTCurve3DGetContinuity(handle))
    }

    /// Measured global continuity of the 3D curve.
    ///
    /// ```swift
    /// let line = Curve3D.line(origin: .zero, direction: SIMD3(1, 0, 0))
    /// print(line?.continuityClass)                  // .cN
    /// print(line?.continuityClass.satisfies(.c3))   // true
    /// ```
    public var continuityClass: ContinuityClass {
        ContinuityClass(rawValue: OCCTCurve3DGetContinuity(handle)) ?? .c0
    }
}

// MARK: - Curve2D continuity (v0.106.0)

extension Curve2D {
    /// Measured global continuity of the 2D curve, as a raw `GeomAbs_Shape` ordinal.
    ///
    /// The ordinals are `GeomAbs_Shape`'s own declared order — `0=C0, 1=G1, 2=C1, 3=G2,
    /// 4=C2, 5=C3, 6=CN` — not a 0/1/2 order. Prefer ``continuityClass``, which names them.
    ///
    /// - Warning: The migration target for the retired `continuityOrder`, but not a drop-in one —
    ///   see ``Curve3D/continuity`` for the constants that shift (#619).
    public var continuity: Int {
        Int(OCCTCurve2DGetContinuity(handle))
    }

    /// Measured global continuity of the 2D curve.
    ///
    /// ```swift
    /// let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))
    /// print(segment?.continuityClass)   // .cN
    /// ```
    public var continuityClass: ContinuityClass {
        ContinuityClass(rawValue: OCCTCurve2DGetContinuity(handle)) ?? .c0
    }
}

// MARK: - Surface continuity (v0.106.0)

extension Surface {
    /// Measured global continuity of the surface, as a raw `GeomAbs_Shape` ordinal.
    ///
    /// The ordinals are `GeomAbs_Shape`'s own declared order — `0=C0, 1=G1, 2=C1, 3=G2,
    /// 4=C2, 5=C3, 6=CN` — not a 0/1/2 order. Prefer ``continuityClass``, which names them.
    ///
    /// - Warning: The migration target for the retired `surfaceContinuityOrder`, but not a
    ///   drop-in one — see ``Curve3D/continuity`` for the constants that shift (#619).
    public var continuity: Int {
        Int(OCCTSurfaceGetContinuity(handle))
    }

    /// Get number of UV bound spans for the surface.
    public var nBounds: (uSpans: Int, vSpans: Int) {
        var u: Int32 = 0, v: Int32 = 0
        OCCTSurfaceGetNBounds(handle, &u, &v)
        return (Int(u), Int(v))
    }
}

// MARK: - Geom_BSplineCurve Methods (v0.107.0)

extension Curve3D {

    /// BSpline-specific operations. Returns nil values if the curve is not a BSpline.
    public struct BSpline {
        let curve: Curve3D

        /// Number of knots (0 if not a BSpline).
        public var knotCount: Int { Int(OCCTCurve3DBSplineKnotCount(curve.handle)) }

        /// Number of poles/control points (0 if not a BSpline).
        public var poleCount: Int { Int(OCCTCurve3DBSplinePoleCount(curve.handle)) }

        /// Degree (0 if not a BSpline).
        public var degree: Int { Int(OCCTCurve3DBSplineDegree(curve.handle)) }

        /// Whether the BSpline is rational.
        public var isRational: Bool { OCCTCurve3DBSplineIsRational(curve.handle) }

        /// Get all knot values.
        public var knots: [Double] {
            let n = knotCount
            guard n > 0 else { return [] }
            var arr = [Double](repeating: 0, count: n)
            OCCTCurve3DBSplineGetKnots(curve.handle, &arr)
            return arr
        }

        /// Get all knot multiplicities.
        public var multiplicities: [Int] {
            let n = knotCount
            guard n > 0 else { return [] }
            var arr = [Int32](repeating: 0, count: n)
            OCCTCurve3DBSplineGetMults(curve.handle, &arr)
            return arr.map { Int($0) }
        }

        /// Get a pole at 1-based index.
        public func pole(at index: Int) -> SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DBSplineGetPole(curve.handle, Int32(index), &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// Set a pole at 1-based index.
        @discardableResult
        public func setPole(at index: Int, to point: SIMD3<Double>) -> Bool {
            OCCTCurve3DBSplineSetPole(curve.handle, Int32(index), point.x, point.y, point.z)
        }

        /// Get the weight at 1-based index.
        public func weight(at index: Int) -> Double {
            OCCTCurve3DBSplineGetWeight(curve.handle, Int32(index))
        }

        /// Set the weight at 1-based index.
        @discardableResult
        public func setWeight(at index: Int, to weight: Double) -> Bool {
            OCCTCurve3DBSplineSetWeight(curve.handle, Int32(index), weight)
        }

        /// Insert a knot at parameter u with given multiplicity.
        @discardableResult
        public func insertKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool {
            OCCTCurve3DBSplineInsertKnot(curve.handle, u, Int32(multiplicity), tolerance)
        }

        /// Remove a knot at 1-based index down to given multiplicity.
        @discardableResult
        public func removeKnot(at index: Int, multiplicity: Int, tolerance: Double) -> Bool {
            OCCTCurve3DBSplineRemoveKnot(curve.handle, Int32(index), Int32(multiplicity), tolerance)
        }

        /// Segment the BSpline to [u1, u2].
        @discardableResult
        public func segment(u1: Double, u2: Double) -> Bool {
            OCCTCurve3DBSplineSegment(curve.handle, u1, u2)
        }

        /// Increase the degree to the given value.
        @discardableResult
        public func increaseDegree(to degree: Int) -> Bool {
            OCCTCurve3DBSplineIncreaseDegree(curve.handle, Int32(degree))
        }

        /// Compute parametric resolution for a given 3D tolerance.
        public func resolution(tolerance3d: Double) -> Double {
            OCCTCurve3DBSplineResolution(curve.handle, tolerance3d)
        }

        /// Set periodic or non-periodic.
        @discardableResult
        public func setPeriodic(_ periodic: Bool) -> Bool {
            OCCTCurve3DBSplineSetPeriodic(curve.handle, periodic)
        }
    }

    /// Access BSpline-specific operations. Works only if the underlying curve is a Geom_BSplineCurve.
    public var bspline: BSpline { BSpline(curve: self) }
}

// MARK: - Geom_BSplineSurface Methods (v0.107.0)

extension Surface {

    /// BSpline-specific surface operations.
    public struct BSpline {
        let surface: Surface

        /// Number of U knots.
        public var nbUKnots: Int { Int(OCCTSurfaceBSplineNbUKnots(surface.handle)) }

        /// Number of V knots.
        public var nbVKnots: Int { Int(OCCTSurfaceBSplineNbVKnots(surface.handle)) }

        /// Number of U poles.
        public var nbUPoles: Int { Int(OCCTSurfaceBSplineNbUPoles(surface.handle)) }

        /// Number of V poles.
        public var nbVPoles: Int { Int(OCCTSurfaceBSplineNbVPoles(surface.handle)) }

        /// U degree.
        public var uDegree: Int { Int(OCCTSurfaceBSplineUDegree(surface.handle)) }

        /// V degree.
        public var vDegree: Int { Int(OCCTSurfaceBSplineVDegree(surface.handle)) }

        /// Whether the surface is U-rational.
        public var isURational: Bool { OCCTSurfaceBSplineIsURational(surface.handle) }

        /// Whether the surface is V-rational.
        public var isVRational: Bool { OCCTSurfaceBSplineIsVRational(surface.handle) }

        /// Get a pole at (uIndex, vIndex) — both 1-based.
        public func pole(uIndex: Int, vIndex: Int) -> SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTSurfaceBSplineGetPole(surface.handle, Int32(uIndex), Int32(vIndex), &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// Set a pole at (uIndex, vIndex) — both 1-based.
        @discardableResult
        public func setPole(uIndex: Int, vIndex: Int, to point: SIMD3<Double>) -> Bool {
            OCCTSurfaceBSplineSetPole(surface.handle, Int32(uIndex), Int32(vIndex), point.x, point.y, point.z)
        }

        /// Set the weight at (uIndex, vIndex).
        @discardableResult
        public func setWeight(uIndex: Int, vIndex: Int, to weight: Double) -> Bool {
            OCCTSurfaceBSplineSetWeight(surface.handle, Int32(uIndex), Int32(vIndex), weight)
        }

        /// Insert a U knot.
        @discardableResult
        public func insertUKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool {
            OCCTSurfaceBSplineInsertUKnot(surface.handle, u, Int32(multiplicity), tolerance)
        }

        /// Insert a V knot.
        @discardableResult
        public func insertVKnot(v: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool {
            OCCTSurfaceBSplineInsertVKnot(surface.handle, v, Int32(multiplicity), tolerance)
        }

        /// Segment the surface to [u1,u2] x [v1,v2].
        @discardableResult
        public func segment(u1: Double, u2: Double, v1: Double, v2: Double) -> Bool {
            OCCTSurfaceBSplineSegment(surface.handle, u1, u2, v1, v2)
        }

        /// Increase the degree to (uDeg, vDeg).
        @discardableResult
        public func increaseDegree(uDeg: Int, vDeg: Int) -> Bool {
            OCCTSurfaceBSplineIncreaseDegree(surface.handle, Int32(uDeg), Int32(vDeg))
        }

        /// Exchange U and V directions.
        @discardableResult
        public func exchangeUV() -> Bool {
            OCCTSurfaceBSplineExchangeUV(surface.handle)
        }
    }

    /// Access BSpline-specific surface operations. Works only if the underlying surface is a Geom_BSplineSurface.
    public var bsplineSurface: BSpline { BSpline(surface: self) }
}

// MARK: - Geom2d_BSplineCurve Methods (v0.107.0)

extension Curve2D {

    /// BSpline-specific 2D curve operations.
    public struct BSpline {
        let curve: Curve2D

        /// Number of knots.
        public var knotCount: Int { Int(OCCTCurve2DBSplineKnotCount(curve.handle)) }

        /// Number of poles.
        public var poleCount: Int { Int(OCCTCurve2DBSplinePoleCount(curve.handle)) }

        /// Degree.
        public var degree: Int { Int(OCCTCurve2DBSplineDegree(curve.handle)) }

        /// Whether rational.
        public var isRational: Bool { OCCTCurve2DBSplineIsRational(curve.handle) }

        /// Get a pole at 1-based index.
        public func pole(at index: Int) -> SIMD2<Double> {
            var x = 0.0, y = 0.0
            OCCTCurve2DBSplineGetPole(curve.handle, Int32(index), &x, &y)
            return SIMD2(x, y)
        }

        /// Set a pole at 1-based index.
        @discardableResult
        public func setPole(at index: Int, to point: SIMD2<Double>) -> Bool {
            OCCTCurve2DBSplineSetPole(curve.handle, Int32(index), point.x, point.y)
        }

        /// Set the weight at 1-based index.
        @discardableResult
        public func setWeight(at index: Int, to weight: Double) -> Bool {
            OCCTCurve2DBSplineSetWeight(curve.handle, Int32(index), weight)
        }

        /// Insert a knot.
        @discardableResult
        public func insertKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool {
            OCCTCurve2DBSplineInsertKnot(curve.handle, u, Int32(multiplicity), tolerance)
        }

        /// Remove a knot at 1-based index.
        @discardableResult
        public func removeKnot(at index: Int, multiplicity: Int, tolerance: Double) -> Bool {
            OCCTCurve2DBSplineRemoveKnot(curve.handle, Int32(index), Int32(multiplicity), tolerance)
        }

        /// Segment to [u1, u2].
        @discardableResult
        public func segment(u1: Double, u2: Double) -> Bool {
            OCCTCurve2DBSplineSegment(curve.handle, u1, u2)
        }

        /// Increase degree.
        @discardableResult
        public func increaseDegree(to degree: Int) -> Bool {
            OCCTCurve2DBSplineIncreaseDegree(curve.handle, Int32(degree))
        }

        /// Compute parametric resolution for a given tolerance.
        public func resolution(tolerance: Double) -> Double {
            OCCTCurve2DBSplineResolution(curve.handle, tolerance)
        }
    }

    /// Access BSpline-specific operations. Works only if the underlying curve is a Geom2d_BSplineCurve.
    public var bspline: BSpline { BSpline(curve: self) }
}

// MARK: - Bezier Curve Methods (v0.107.0)

extension Curve3D {

    /// Bezier-specific operations.
    public struct Bezier {
        let curve: Curve3D

        /// Get a pole at 1-based index.
        public func pole(at index: Int) -> SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DBezierGetPole(curve.handle, Int32(index), &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// Set a pole at 1-based index.
        @discardableResult
        public func setPole(at index: Int, to point: SIMD3<Double>) -> Bool {
            OCCTCurve3DBezierSetPole(curve.handle, Int32(index), point.x, point.y, point.z)
        }

        /// Set the weight at 1-based index.
        @discardableResult
        public func setWeight(at index: Int, to weight: Double) -> Bool {
            OCCTCurve3DBezierSetWeight(curve.handle, Int32(index), weight)
        }

        /// Insert a pole after given index.
        @discardableResult
        public func insertPoleAfter(index: Int, point: SIMD3<Double>) -> Bool {
            OCCTCurve3DBezierInsertPoleAfter(curve.handle, Int32(index), point.x, point.y, point.z)
        }

        /// Remove a pole at given index.
        @discardableResult
        public func removePole(at index: Int) -> Bool {
            OCCTCurve3DBezierRemovePole(curve.handle, Int32(index))
        }

        /// Segment to [u1, u2].
        @discardableResult
        public func segment(u1: Double, u2: Double) -> Bool {
            OCCTCurve3DBezierSegment(curve.handle, u1, u2)
        }

        /// Increase degree.
        @discardableResult
        public func increaseDegree(to degree: Int) -> Bool {
            OCCTCurve3DBezierIncreaseDegree(curve.handle, Int32(degree))
        }

        /// Whether the Bezier is rational.
        public var isRational: Bool { OCCTCurve3DBezierIsRational(curve.handle) }

        /// Degree.
        public var degree: Int { Int(OCCTCurve3DBezierDegree(curve.handle)) }

        /// Number of poles.
        public var poleCount: Int { Int(OCCTCurve3DBezierPoleCount(curve.handle)) }
    }

    /// Access Bezier-specific operations. Works only if the underlying curve is a Geom_BezierCurve.
    public var bezier: Bezier { Bezier(curve: self) }
}

// MARK: - BRepTools/BRepLib Utilities (v0.107.0)

extension Shape {

    /// Clean all tessellation data from the shape.
    public func clean() {
        OCCTShapeClean(handle)
    }

    /// Clean geometry (PCurves etc.) from the shape.
    public func cleanGeometry() {
        OCCTShapeCleanGeometry(handle)
    }

    /// Remove unused PCurves from edges.
    public func removeUnusedPCurves() {
        OCCTShapeRemoveUnusedPCurves(handle)
    }

    /// Update BRep data structures.
    public func updateShape() {
        OCCTShapeUpdate(handle)
    }

    /// Check if an edge has same-range parametrisation.
    public static func checkSameRange(edge: Shape) -> Bool {
        OCCTBRepLibCheckSameRange(edge.handle)
    }

    /// Ensure edge has same-range parametrisation.
    @discardableResult
    public static func sameRange(edge: Shape, tolerance: Double = 1e-6) -> Bool {
        OCCTBRepLibSameRange(edge.handle, tolerance)
    }

    /// Build 3D curve for an edge from PCurves.
    @discardableResult
    public static func buildCurve3d(edge: Shape, tolerance: Double = 1e-6) -> Bool {
        OCCTBRepLibBuildCurve3d(edge.handle, tolerance)
    }

    /// Update tolerances of all sub-shapes.
    public func updateTolerances() {
        OCCTBRepLibUpdateTolerances(handle)
    }

    /// Update inner tolerances of all sub-shapes.
    public func updateInnerTolerances() {
        OCCTBRepLibUpdateInnerTolerances(handle)
    }

    /// Update tolerance of a specific edge.
    @discardableResult
    public static func updateEdgeTolerance(edge: Shape, tolerance: Double) -> Bool {
        OCCTBRepLibUpdateEdgeTolerance(edge.handle, tolerance)
    }
}

// MARK: - MakeFace Extras (v0.107.0)

extension Shape {

    /// Create a face from a sphere with UV bounds.
    public static func faceFromSphere(center: SIMD3<Double> = .zero, radius: Double,
                                       uMin: Double, uMax: Double, vMin: Double, vMax: Double) -> Shape? {
        guard let ref = OCCTMakeFaceFromSphere(center.x, center.y, center.z, radius, uMin, uMax, vMin, vMax) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a torus with UV bounds.
    public static func faceFromTorus(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0, 0, 1),
                                      majorRadius: Double, minorRadius: Double,
                                      uMin: Double, uMax: Double, vMin: Double, vMax: Double) -> Shape? {
        guard let ref = OCCTMakeFaceFromTorus(center.x, center.y, center.z, normal.x, normal.y, normal.z,
                                               majorRadius, minorRadius, uMin, uMax, vMin, vMax) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a cone with UV bounds.
    public static func faceFromCone(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0, 0, 1),
                                     semiAngle: Double, radius: Double,
                                     uMin: Double, uMax: Double, vMin: Double, vMax: Double) -> Shape? {
        guard let ref = OCCTMakeFaceFromCone(center.x, center.y, center.z, normal.x, normal.y, normal.z,
                                              semiAngle, radius, uMin, uMax, vMin, vMax) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a surface trimmed by a wire.
    public static func faceFromSurface(_ surface: Surface, wire: Shape, inside: Bool = true) -> Shape? {
        guard let ref = OCCTMakeFaceFromSurfaceWire(surface.handle, wire.handle, inside) else { return nil }
        return Shape(handle: ref)
    }

    /// Add a hole (inner wire) to a face.
    ///
    /// The hole wire may be **polygonal or curved** (a `Wire.circle`, an arc, joined arcs) and may
    /// wind either way: the wire is reoriented as needed so the hole always *removes* area, and the
    /// holed face extrudes into a valid solid with a real through hole.
    ///
    /// ```swift
    /// let plate = Shape.face(from: Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(20, 0, 0),
    ///                                              SIMD3(20, 20, 0), SIMD3(0, 20, 0)],
    ///                                             closed: true)!, planar: true)!
    /// let bore = Shape.fromWire(Wire.circle(origin: SIMD3(10, 10, 0),
    ///                                       normal: SIMD3(0, 0, 1), radius: 3)!)!
    /// let holed = Shape.faceAddHole(face: plate, wire: bore)!
    /// holed.surfaceArea          // 400 - pi*9
    /// holed.extruded(by: SIMD3(0, 0, 5))!.isValidSolid   // true, hole runs through
    /// ```
    ///
    /// - Returns: The face with the hole added, or nil if the wire cannot serve as a hole for this
    ///   face — it encloses no area (see #234), or it does not lie inside the face's boundary, so
    ///   neither winding yields a valid face. A degenerate or unusable hole is declined rather than
    ///   returned as an invalid face, which is what breaks callers downstream.
    public static func faceAddHole(face: Shape, wire: Shape) -> Shape? {
        guard let ref = OCCTMakeFaceAddHole(face.handle, wire.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Copy a face.
    public static func faceCopy(_ face: Shape) -> Shape? {
        guard let ref = OCCTMakeFaceCopy(face.handle) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - Sewing (v0.107.0)


// MARK: - Hatch_Hatcher (v0.107.0)


// MARK: - Edge/Face Extraction (v0.107.0)

extension Shape {

    /// Extract the 3D curve from an edge shape. Returns (curve, firstParam, lastParam) or nil.
    public func extractEdgeCurve3D() -> (curve: Curve3D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let ref = OCCTEdgeExtractCurve3D(handle, &first, &last) else { return nil }
        return (Curve3D(handle: ref), first, last)
    }

    /// Extract the PCurve of an edge on a face. Returns (curve, firstParam, lastParam) or nil.
    public func extractEdgePCurve(onFace face: Shape) -> (curve: Curve2D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let ref = OCCTEdgeExtractPCurve(handle, face.handle, &first, &last) else { return nil }
        return (Curve2D(handle: ref), first, last)
    }

    /// Get the tolerance of an edge shape.
    public var edgeTolerance: Double { OCCTEdgeGetTolerance(handle) }

    /// Check if an edge is degenerated.
    public var isEdgeDegenerated: Bool { OCCTEdgeIsDegenerated(handle) }

    /// Extract the surface from a face shape.
    public func extractFaceSurface() -> Surface? {
        guard let ref = OCCTFaceExtractSurface(handle) else { return nil }
        return Surface(handle: ref)
    }

    /// Get the tolerance of a face shape.
    public var faceTolerance: Double { OCCTFaceGetTolerance(handle) }

    /// Get the number of wires on a face shape.
    public var faceWireCount: Int { Int(OCCTFaceWireCount(handle)) }

    /// Get the tolerance of a vertex shape.
    public var vertexTolerance: Double { OCCTVertexGetTolerance(handle) }

    /// Get the point of a vertex shape.
    public var vertexPoint: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTVertexGetPoint(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }
}

// MARK: - Extrema Elementary Distances (v0.109.0)







// MARK: - math_TrigonometricFunctionRoots (v0.109.0)


// MARK: - IntAna2d_Conic (v0.109.0)


// MARK: - BRepAlgo_NormalProjection (v0.109.0)


// MARK: - OSD_Disk (v0.109.0)


// MARK: - OSD_SharedLibrary (v0.109.0)


// MARK: - Message_Msg (v0.109.0)


// MARK: - Plate Constraint Extensions (v0.109.0)

extension PlateSolver {

    /// Load a global translation constraint.
    /// All sample points are constrained to translate by the same unknown displacement.
    @discardableResult
    public func loadGlobalTranslation(uvPoints: [SIMD2<Double>]) -> Bool {
        let uvs = uvPoints.flatMap { [$0.x, $0.y] }
        return OCCTPlateLoadGlobalTranslation(handle, uvs, Int32(uvPoints.count))
    }

    /// Load a linear XYZ constraint.
    @discardableResult
    public func loadLinearXYZ(
        uvPoints: [SIMD2<Double>],
        targets: [SIMD3<Double>],
        coefficients: [Double]
    ) -> Bool {
        let uvs = uvPoints.flatMap { [$0.x, $0.y] }
        let tgts = targets.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTPlateLoadLinearXYZ(handle, uvs, tgts, coefficients, Int32(uvPoints.count))
    }
}

// MARK: - Shape Topology Extras (v0.109.0)

extension Shape {

    /// Get the shape type as a string ("compound", "solid", "face", etc.).
    public var shapeTypeString: String {
        guard let cstr = OCCTShapeTypeString(handle) else { return "unknown" }
        let result = String(cString: cstr)
        free(cstr)
        return result
    }
}

// MARK: - Curve3D Extras (v0.109.0)

extension Curve3D {

    /// Reverse the curve in-place.
    @discardableResult
    public func reverse() -> Bool {
        OCCTCurve3DReverse(handle)
    }

    /// Create a deep copy of this curve.
    public func copy() -> Curve3D? {
        guard let ref = OCCTCurve3DCopy(handle) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - Curve2D Extras (v0.109.0)

extension Curve2D {

    /// Reverse the curve in-place.
    @discardableResult
    public func reverse() -> Bool {
        OCCTCurve2DReverse(handle)
    }

    /// Create a deep copy of this curve.
    public func copy() -> Curve2D? {
        guard let ref = OCCTCurve2DCopy(handle) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - Surface Extras (v0.109.0)

extension Surface {

    /// Get the parameter bounds of the surface.
    public var parameterBounds: (uMin: Double, uMax: Double, vMin: Double, vMax: Double) {
        var uMin = 0.0, uMax = 0.0, vMin = 0.0, vMax = 0.0
        OCCTSurfaceBounds(handle, &uMin, &uMax, &vMin, &vMax)
        return (uMin, uMax, vMin, vMax)
    }

    /// Unavailable: this `Int` reported a hand-invented encoding, and the numbers changed
    /// underneath it. Use ``continuityClass`` (named cases) or ``continuity`` (raw ordinal).
    ///
    /// Same retirement, same reasons, as ``Curve3D/continuityOrder``: the pre-#485 encoding was
    /// `C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3` and the value is now the real
    /// `GeomAbs_Shape` ordinal (`C0=0, G1=1, C1=2, G2=3, C2=4, C3=5, CN=6`), so every threshold
    /// check kept compiling and quietly changed meaning (#619).
    ///
    /// ```swift
    /// // Before: `2` was C2. After: `2` is C1, and an analytic surface answers 6, never 99.
    /// if surface.surfaceContinuityOrder >= 2 { offsetSafely() }
    ///
    /// // Ask it so it cannot drift again:
    /// if surface.continuityClass.satisfies(.c2) { offsetSafely() }
    /// ```
    @available(*, unavailable, message: """
        surfaceContinuityOrder reported a hand-invented encoding (C0=0, C1=1, C2=2, C3=3, CN=99, \
        G1=-2, G2=-3) and #485 changed it to the real GeomAbs_Shape ordinal (C0=0, G1=1, C1=2, \
        G2=3, C2=4, C3=5, CN=6), so every threshold check silently changed meaning. Use \
        continuityClass.satisfies(_:) for a continuity floor, continuityClass == .cN for the \
        analytic fast path, or continuity for the raw ordinal — after re-checking the constant \
        you compare against. Note there is no longer an error sentinel: this returned -1 for a \
        null or unreadable handle, whereas continuity returns 0, which is an ordinary C0, so a \
        migrated `< 0` error check can never fire (#619).
        """)
    public var surfaceContinuityOrder: Int { Int(OCCTSurfaceGetContinuity(handle)) }

    /// Create a deep copy of this surface.
    public func copy() -> Surface? {
        guard let ref = OCCTSurfaceCopy(handle) else { return nil }
        return Surface(handle: ref)
    }
}

// MARK: - Math Solvers (v0.110.0)


// MARK: - PolynomialSolver Laguerre Extensions (v0.111.0)

extension PolynomialSolver {

    /// Find real roots of a polynomial of any degree using Laguerre's method.
    ///
    /// Coefficients are in ascending order (constant first):
    /// for polynomial a0 + a1*x + a2*x^2 + ... + an*x^n, pass [a0, a1, ..., an].
    /// - Parameter coefficients: Polynomial coefficients in ascending order
    /// - Returns: Array of real roots (sorted)
    public static func laguerreRoots(coefficients: [Double]) -> [Double] {
        let degree = coefficients.count - 1
        guard degree >= 1 else { return [] }
        var roots = [Double](repeating: 0, count: 20)
        let n = OCCTPolyLaguerreRoots(coefficients, Int32(degree), &roots, 20)
        return Array(roots.prefix(Int(n)))
    }

    /// Find complex roots of a polynomial using Laguerre's method.
    ///
    /// - Parameter coefficients: Polynomial coefficients in ascending order (constant first)
    /// - Returns: Array of (real, imaginary) pairs for complex roots
    public static func laguerreComplexRoots(coefficients: [Double]) -> [(real: Double, imaginary: Double)] {
        let degree = coefficients.count - 1
        guard degree >= 1 else { return [] }
        var realParts = [Double](repeating: 0, count: 20)
        var imagParts = [Double](repeating: 0, count: 20)
        let n = OCCTPolyLaguerreComplexRoots(coefficients, Int32(degree), &realParts, &imagParts, 20)
        return (0..<Int(n)).map { (realParts[$0], imagParts[$0]) }
    }

    /// Find real roots of a quintic polynomial: a*x^5 + b*x^4 + c*x^3 + d*x^2 + e*x + f = 0.
    ///
    /// - Returns: Array of real roots (sorted)
    public static func quinticRoots(a: Double, b: Double, c: Double, d: Double, e: Double, f: Double) -> [Double] {
        var roots = [Double](repeating: 0, count: 5)
        let n = OCCTPolyQuinticRoots(a, b, c, d, e, f, &roots, 5)
        return Array(roots.prefix(Int(n)))
    }
}

// MARK: - BRepLProp Edge Extensions (v0.111.0)
//
// These read an edge through a `BRepAdaptor_Curve`, where `Curve3D.localCurvature` and friends read
// the curve underneath directly. Since #529 both spellings decide whether a quantity exists at the
// same resolution (`Precision::Confusion()`), so they agree about definedness at every parameter of
// every edge; they still differ in the last bits of the values themselves, because the adaptor
// evaluates a Bezier or BSpline through a cache the raw handle does not use.

extension Shape {

    /// Point on an edge at `param`, through the edge's own adaptor (`BRepLProp_CLProps`).
    ///
    /// Returns nil for a parameter the edge cannot be evaluated at. Before #529 it returned
    /// `(0, 0, 0)` there, wrapped in a non-nil optional.
    ///
    /// ```swift
    /// let edge = Shape.box(width: 10, height: 10, depth: 10)!.subShapes(ofType: .edge)[0]
    /// if let p = edge.edgeLPropValue(at: 5.0) {
    ///     print("point at t=5: \(p)")
    /// }
    /// ```
    public func edgeLPropValue(at param: Double) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        let ok = OCCTEdgeLPropValue(handle, param, &x, &y, &z)
        return ok ? SIMD3(x, y, z) : nil
    }

    /// Get tangent direction on an edge at parameter. Returns nil if tangent is undefined.
    public func edgeTangent(at param: Double) -> SIMD3<Double>? {
        var dx = 0.0, dy = 0.0, dz = 0.0
        let ok = OCCTEdgeLPropTangent(handle, param, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }

    /// Curvature on an edge at `param`, through the edge's own adaptor.
    ///
    /// - Parameter param: Parameter on the edge's curve.
    /// - Returns: The curvature, or `nil` where this `Shape` is not an edge, the parameter cannot
    ///   be evaluated, or the tangent is undefined there. That last case used to be `0`, which is
    ///   also a straight edge's real curvature (#595). It is not exotic: a sphere carries a
    ///   **degenerate edge at each pole**, with no 3D curve at all, and edge traversal does not
    ///   skip them.
    ///
    /// `Double.greatestFiniteMagnitude` (OCCT's `RealLast()`, meaning infinite curvature) is still
    /// reported at a cusp — an answer, not an absence — matching ``Curve3D/curvature(at:)`` on the
    /// curve underneath.
    ///
    /// ```swift
    /// let arc = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 4)!
    /// let edge = Shape.edgeFromCurve(arc)!
    /// let k = edge.edgeCurvatureLP(at: 0.5)   // 0.25, the reciprocal of the radius
    /// ```
    public func edgeCurvatureLP(at param: Double) -> Double? {
        var k = 0.0
        guard OCCTEdgeLPropCurvature(handle, param, &k) else { return nil }
        return k
    }

    /// Normal direction on an edge at `param`.
    ///
    /// Returns nil where the curvature cannot be inverted into a direction: a straight stretch has
    /// no normal, and neither does a cusp. Before #529 both cases returned `(0, 0, 0)`, which is
    /// not a direction.
    ///
    /// ```swift
    /// let arc = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 4)!
    /// let edge = Shape.edgeFromCurve(arc)!
    /// if let n = edge.edgeNormalLP(at: 0) { print("points at the centre: \(n)") }
    /// ```
    public func edgeNormalLP(at param: Double) -> SIMD3<Double>? {
        var dx = 0.0, dy = 0.0, dz = 0.0
        let ok = OCCTEdgeLPropNormal(handle, param, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }

    /// Centre of curvature on an edge at `param` — the centre of the circle that osculates the edge
    /// there.
    ///
    /// Returns nil wherever there is no such circle, on the same terms as ``edgeNormalLP(at:)``.
    /// Before #529 a near-cusp returned `(nan, inf, nan)` as though it were a point.
    ///
    /// ```swift
    /// let arc = Curve3D.circle(center: SIMD3(1, 2, 0), normal: SIMD3(0, 0, 1), radius: 4)!
    /// let edge = Shape.edgeFromCurve(arc)!
    /// if let c = edge.edgeCentreOfCurvature(at: 0) { print(c) }   // ~ (1, 2, 0)
    /// ```
    public func edgeCentreOfCurvature(at param: Double) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        let ok = OCCTEdgeLPropCentreOfCurvature(handle, param, &x, &y, &z)
        return ok ? SIMD3(x, y, z) : nil
    }

    /// First derivative on an edge at `param`. Returns nil for a parameter the edge cannot be
    /// evaluated at.
    public func edgeLPropD1(at param: Double) -> SIMD3<Double>? {
        var d1x = 0.0, d1y = 0.0, d1z = 0.0
        let ok = OCCTEdgeLPropD1(handle, param, &d1x, &d1y, &d1z)
        return ok ? SIMD3(d1x, d1y, d1z) : nil
    }
}

// MARK: - BRepLProp Face Extensions (v0.111.0)

extension Shape {

    /// Point on a face at (u, v), through the face's own adaptor (`BRepLProp_SLProps`).
    ///
    /// Returns nil if the receiver is not a single face, the same contract
    /// ``faceLPropMeanCurvature(u:v:)`` and its siblings use, except that the point does not depend
    /// on the curvature gate, so it is still reported at a cone apex or a sphere pole. Before #583
    /// a non-face `Shape` came back as `(0, 0, 0)`, which is a real point of most surfaces.
    ///
    /// ```swift
    /// let cylinder = Shape.cylinder(radius: 3, height: 12)!
    /// if let p = cylinder.subShapes(ofType: .face)[0].faceLPropValue(u: 1.1, v: 6) {
    ///     print(p)
    /// }
    /// ```
    public func faceLPropValue(u: Double, v: Double) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        let ok = OCCTFaceLPropValue(handle, u, v, &x, &y, &z)
        return ok ? SIMD3(x, y, z) : nil
    }

    /// Get normal on a face at (u, v). Returns nil if normal is undefined.
    public func faceLPropNormal(u: Double, v: Double) -> SIMD3<Double>? {
        var dx = 0.0, dy = 0.0, dz = 0.0
        let ok = OCCTFaceLPropNormal(handle, u, v, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }

    /// Maximum principal curvature on a face at (u, v), or nil where curvature is undefined.
    ///
    /// Nil is a cone apex, a sphere pole, or a receiver that is not a face. `0` is a value in its
    /// own right: it is the maximum curvature at every point of a cylinder or a cone. Before #583
    /// the two were the same answer.
    ///
    /// ```swift
    /// let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
    /// let kMax = cylinder.faceLPropMaxCurvature(u: 1.1, v: 6)   // 0, along the axis, not nil
    /// ```
    public func faceLPropMaxCurvature(u: Double, v: Double) -> Double? {
        var curvature = 0.0
        let ok = OCCTFaceLPropMaxCurvature(handle, u, v, &curvature)
        return ok ? curvature : nil
    }

    /// Minimum principal curvature on a face at (u, v), or nil where curvature is undefined.
    ///
    /// Nil on the same terms as ``faceLPropMaxCurvature(u:v:)``.
    ///
    /// ```swift
    /// let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
    /// let kMin = cylinder.faceLPropMinCurvature(u: 1.1, v: 6)   // -1/3, the reciprocal radius
    /// ```
    public func faceLPropMinCurvature(u: Double, v: Double) -> Double? {
        var curvature = 0.0
        let ok = OCCTFaceLPropMinCurvature(handle, u, v, &curvature)
        return ok ? curvature : nil
    }

    /// Mean curvature on a face at (u, v), or nil where curvature is undefined.
    ///
    /// The adaptor-backed counterpart of ``Face/meanCurvature(atU:v:)``, which has always been
    /// optional; since #529 the two agree about where curvature exists, and since #583 both can
    /// say so.
    ///
    /// ```swift
    /// let sphere = Shape.sphere(radius: 5)!.subShapes(ofType: .face)[0]
    /// if let h = sphere.faceLPropMeanCurvature(u: 0, v: 0) { print(h) }   // -0.2, i.e. -1/r
    /// ```
    public func faceLPropMeanCurvature(u: Double, v: Double) -> Double? {
        var curvature = 0.0
        let ok = OCCTFaceLPropMeanCurvature(handle, u, v, &curvature)
        return ok ? curvature : nil
    }

    /// Gaussian curvature on a face at (u, v), or nil where curvature is undefined.
    ///
    /// The adaptor-backed counterpart of ``Face/gaussianCurvature(atU:v:)``. `0` is the answer at
    /// every point of any developable surface (a cylinder, a cone, a plane), so this getter
    /// returned the pre-#583 "undefined" sentinel for whole faces at a time.
    ///
    /// ```swift
    /// let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
    /// #expect(cylinder.faceLPropGaussianCurvature(u: 1.1, v: 6) == 0)   // defined, and zero
    /// ```
    public func faceLPropGaussianCurvature(u: Double, v: Double) -> Double? {
        var curvature = 0.0
        let ok = OCCTFaceLPropGaussianCurvature(handle, u, v, &curvature)
        return ok ? curvature : nil
    }

    /// Whether a face is umbilic at (u, v), meaning both principal curvatures are equal, or nil
    /// where there are no principal curvatures to compare.
    ///
    /// OCCT's test is one ULP wide rather than a geometric tolerance, so a plane qualifies
    /// everywhere but an analytically-umbilic sphere qualifies only where the two computed values
    /// round to the same `Double`. Before #583 a cone apex answered `false`, claiming the two
    /// curvatures differ there.
    ///
    /// ```swift
    /// let cylinder = Shape.cylinder(radius: 3, height: 12)!.subShapes(ofType: .face)[0]
    /// #expect(cylinder.faceLPropIsUmbilic(u: 1.1, v: 6) == false)   // defined, and not umbilic
    /// ```
    public func faceLPropIsUmbilic(u: Double, v: Double) -> Bool? {
        var isUmbilic = false
        let ok = OCCTFaceLPropIsUmbilic(handle, u, v, &isUmbilic)
        return ok ? isUmbilic : nil
    }

    /// Get tangent in U direction on a face at (u, v). Returns nil if tangent is undefined.
    public func faceLPropTangentU(u: Double, v: Double) -> SIMD3<Double>? {
        var dx = 0.0, dy = 0.0, dz = 0.0
        let ok = OCCTFaceLPropTangentU(handle, u, v, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }

    /// Get tangent in V direction on a face at (u, v) — the second axis of the tangent plane
    /// (companion to ``faceLPropTangentU(u:v:)``). Returns nil if the V tangent is undefined.
    public func faceLPropTangentV(u: Double, v: Double) -> SIMD3<Double>? {
        var dx = 0.0, dy = 0.0, dz = 0.0
        let ok = OCCTFaceLPropTangentV(handle, u, v, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }
}

// MARK: - GridEval Extensions (v0.111.0)
//
// #486: these six methods were a third Swift spelling of batch evaluation, over a third
// generation of bridge functions (OCCTGridEvalCurveD0/D1, OCCTGridEvalCurve2dD0/D1,
// OCCTGridEvalSurfaceD0/D1) that called the same OCCT evaluators as the v0.28.0/v0.29.0 ones.
// Those bridge functions are gone; each method below now forwards to its canonical sibling,
// which is the spelling to use. The Surface pair matters most, because the flat arrays these
// return say nothing about whether u or v runs fastest, and OCCTGridEvalSurfaceD0 disagreed
// with OCCTSurfaceEvaluateGrid about exactly that.

extension Curve3D {

    /// Evaluate curve at multiple parameters (batch D0).
    @available(*, deprecated, renamed: "evaluateGrid(_:)",
               message: "Use evaluateGrid(_:): same OCCT batch evaluator, one spelling (#486)")
    public func gridEvalD0(params: [Double]) -> [SIMD3<Double>] {
        evaluateGrid(params)
    }

    /// Evaluate curve at multiple parameters (batch D1).
    @available(*, deprecated,
               message: "Use evaluateGridD1(_:): same OCCT batch evaluator, one spelling; its tuple labels the derivative `tangent` (#486)")
    public func gridEvalD1(params: [Double]) -> [(point: SIMD3<Double>, d1: SIMD3<Double>)] {
        evaluateGridD1(params).map { (point: $0.point, d1: $0.tangent) }
    }
}

extension Curve2D {

    /// Evaluate 2D curve at multiple parameters (batch D0).
    @available(*, deprecated, renamed: "evaluateGrid(_:)",
               message: "Use evaluateGrid(_:): same OCCT batch evaluator, one spelling (#486)")
    public func gridEvalD0(params: [Double]) -> [SIMD2<Double>] {
        evaluateGrid(params)
    }

    /// Evaluate 2D curve at multiple parameters (batch D1).
    @available(*, deprecated,
               message: "Use evaluateGridD1(_:): same OCCT batch evaluator, one spelling; its tuple labels the derivative `tangent` (#486)")
    public func gridEvalD1(params: [Double]) -> [(point: SIMD2<Double>, d1: SIMD2<Double>)] {
        evaluateGridD1(params).map { (point: $0.point, d1: $0.tangent) }
    }
}

extension Surface {

    /// Evaluate surface at a grid of (u, v) parameters (batch D0).
    ///
    /// - Returns: A flat array, **U-major**: `result[u * vParams.count + v]`. Empty if either
    ///   input is empty or the evaluation fails (it used to return a grid of zeroes instead).
    @available(*, deprecated,
               message: "Use evaluateGrid(uParameters:vParameters:), which returns a SurfaceGrid indexed .at(u:v:) instead of a flat array whose major order you have to know (#486)")
    public func gridEvalD0(uParams: [Double], vParams: [Double]) -> [SIMD3<Double>] {
        let grid = evaluateGrid(uParameters: uParams, vParameters: vParams)
        return (0..<grid.uCount).flatMap { u in (0..<grid.vCount).map { v in grid.at(u: u, v: v) } }
    }

    /// Evaluate surface and its first partial derivatives at a grid of (u, v) parameters (batch D1).
    ///
    /// - Returns: A flat array, **U-major**: `result[u * vParams.count + v]`. Empty if either
    ///   input is empty or the evaluation fails (it used to return a grid of zeroes instead).
    @available(*, deprecated,
               message: "Use evaluateGridD1(uParameters:vParameters:), which returns a SurfaceGridD1 indexed .at(u:v:) instead of a flat array whose major order you have to know (#486)")
    public func gridEvalD1(uParams: [Double], vParams: [Double]) -> [(point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>)] {
        let grid = evaluateGridD1(uParameters: uParams, vParameters: vParams)
        return (0..<grid.uCount).flatMap { u in (0..<grid.vCount).map { v in grid.at(u: u, v: v) } }
    }
}

// MARK: - Curve3D Evaluation (v0.110.0)

extension Curve3D {

    /// Evaluate the curve point at parameter u.
    public func evalD0(at u: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTCurve3DEvalD0(handle, u, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate the curve point and first derivative at parameter u.
    public func evalD1(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1x = 0.0, d1y = 0.0, d1z = 0.0
        OCCTCurve3DEvalD1(handle, u, &px, &py, &pz, &d1x, &d1y, &d1z)
        return (SIMD3(px, py, pz), SIMD3(d1x, d1y, d1z))
    }

    /// Evaluate the curve point, first and second derivatives at parameter u.
    public func evalD2(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1x = 0.0, d1y = 0.0, d1z = 0.0
        var d2x = 0.0, d2y = 0.0, d2z = 0.0
        OCCTCurve3DEvalD2(handle, u, &px, &py, &pz, &d1x, &d1y, &d1z, &d2x, &d2y, &d2z)
        return (SIMD3(px, py, pz), SIMD3(d1x, d1y, d1z), SIMD3(d2x, d2y, d2z))
    }

    /// Evaluate the curve point, first, second, and third derivatives at parameter u.
    public func evalD3(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>, d3: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1x = 0.0, d1y = 0.0, d1z = 0.0
        var d2x = 0.0, d2y = 0.0, d2z = 0.0
        var d3x = 0.0, d3y = 0.0, d3z = 0.0
        OCCTCurve3DEvalD3(handle, u, &px, &py, &pz, &d1x, &d1y, &d1z, &d2x, &d2y, &d2z, &d3x, &d3y, &d3z)
        return (SIMD3(px, py, pz), SIMD3(d1x, d1y, d1z), SIMD3(d2x, d2y, d2z), SIMD3(d3x, d3y, d3z))
    }

    /// Evaluate curve points at multiple parameters (batch D0).
    ///
    /// - Note: #486. This used to call `Geom_Curve::EvalD0` once per parameter, bypassing the
    ///   batch evaluator ``evaluateGrid(_:)`` was already using. It now forwards there, so
    ///   results can differ from the old per-point loop by ~1e-13 on a BSpline.
    @available(*, deprecated, renamed: "evaluateGrid(_:)",
               message: "Use evaluateGrid(_:): same OCCT batch evaluator, one spelling (#486)")
    public func evalBatchD0(params: [Double]) -> [SIMD3<Double>] {
        evaluateGrid(params)
    }

    /// Evaluate curve points and first derivatives at multiple parameters (batch D1).
    ///
    /// - Note: #486. This used to call `Geom_Curve::EvalD1` once per parameter, bypassing the
    ///   batch evaluator ``evaluateGridD1(_:)`` was already using. It now forwards there, so
    ///   results can differ from the old per-point loop by ~1e-13 on a BSpline.
    @available(*, deprecated,
               message: "Use evaluateGridD1(_:): same OCCT batch evaluator, one spelling; its tuple labels the derivative `tangent` (#486)")
    public func evalBatchD1(params: [Double]) -> [(point: SIMD3<Double>, d1: SIMD3<Double>)] {
        evaluateGridD1(params).map { (point: $0.point, d1: $0.tangent) }
    }
}

// MARK: - Curve2D Evaluation (v0.110.0)

extension Curve2D {

    /// Evaluate the 2D curve point at parameter u.
    public func evalD0(at u: Double) -> SIMD2<Double> {
        var x = 0.0, y = 0.0
        OCCTCurve2DEvalD0(handle, u, &x, &y)
        return SIMD2(x, y)
    }

    /// Evaluate the 2D curve point and first derivative at parameter u.
    public func evalD1(at u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>) {
        var px = 0.0, py = 0.0, d1x = 0.0, d1y = 0.0
        OCCTCurve2DEvalD1(handle, u, &px, &py, &d1x, &d1y)
        return (SIMD2(px, py), SIMD2(d1x, d1y))
    }

    /// Evaluate the 2D curve point, first and second derivatives at parameter u.
    public func evalD2(at u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>, d2: SIMD2<Double>) {
        var px = 0.0, py = 0.0, d1x = 0.0, d1y = 0.0, d2x = 0.0, d2y = 0.0
        OCCTCurve2DEvalD2(handle, u, &px, &py, &d1x, &d1y, &d2x, &d2y)
        return (SIMD2(px, py), SIMD2(d1x, d1y), SIMD2(d2x, d2y))
    }

    /// Evaluate 2D curve points at multiple parameters (batch D0).
    ///
    /// - Note: #486. This used to call `Geom2d_Curve::EvalD0` once per parameter, bypassing the
    ///   batch evaluator ``evaluateGrid(_:)`` was already using. It now forwards there, so
    ///   results can differ from the old per-point loop by ~1e-13 on a BSpline.
    @available(*, deprecated, renamed: "evaluateGrid(_:)",
               message: "Use evaluateGrid(_:): same OCCT batch evaluator, one spelling (#486)")
    public func evalBatchD0(params: [Double]) -> [SIMD2<Double>] {
        evaluateGrid(params)
    }

    /// Evaluate 2D curve points and first derivatives at multiple parameters (batch D1).
    ///
    /// - Note: #486. This used to call `Geom2d_Curve::EvalD1` once per parameter, bypassing the
    ///   batch evaluator ``evaluateGridD1(_:)`` was already using. It now forwards there, so
    ///   results can differ from the old per-point loop by ~1e-13 on a BSpline.
    @available(*, deprecated,
               message: "Use evaluateGridD1(_:): same OCCT batch evaluator, one spelling; its tuple labels the derivative `tangent` (#486)")
    public func evalBatchD1(params: [Double]) -> [(point: SIMD2<Double>, d1: SIMD2<Double>)] {
        evaluateGridD1(params).map { (point: $0.point, d1: $0.tangent) }
    }
}

// MARK: - Surface Evaluation (v0.110.0)

extension Surface {

    /// Evaluate the surface point at (u, v).
    public func evalD0(u: Double, v: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTSurfaceEvalD0(handle, u, v, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate the surface point and first partial derivatives at (u, v).
    public func evalD1(u: Double, v: Double) -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1ux = 0.0, d1uy = 0.0, d1uz = 0.0
        var d1vx = 0.0, d1vy = 0.0, d1vz = 0.0
        OCCTSurfaceEvalD1(handle, u, v, &px, &py, &pz, &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz)
        return (SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz))
    }

    /// Evaluate the surface point, first and second partial derivatives at (u, v).
    public func evalD2(u: Double, v: Double) -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>, d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1ux = 0.0, d1uy = 0.0, d1uz = 0.0
        var d1vx = 0.0, d1vy = 0.0, d1vz = 0.0
        var d2ux = 0.0, d2uy = 0.0, d2uz = 0.0
        var d2vx = 0.0, d2vy = 0.0, d2vz = 0.0
        var d2uvx = 0.0, d2uvy = 0.0, d2uvz = 0.0
        OCCTSurfaceEvalD2(handle, u, v, &px, &py, &pz,
                            &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz,
                            &d2ux, &d2uy, &d2uz, &d2vx, &d2vy, &d2vz,
                            &d2uvx, &d2uvy, &d2uvz)
        return (SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz),
                SIMD3(d2ux, d2uy, d2uz), SIMD3(d2vx, d2vy, d2vz), SIMD3(d2uvx, d2uvy, d2uvz))
    }
}

// MARK: - math_NewtonMinimum (v0.111.1)


// MARK: - RWMesh iterators, Intf_Tool, BRepAlgo_AsDes, BiTgte, Shape extras, Extrema (v0.112.0)

// --- RWMesh_FaceIterator ---


// --- RWMesh_VertexIterator ---


// --- Intf_Tool ---


// --- BRepAlgo_AsDes ---


// --- BiTgte_CurveOnEdge ---


// --- Additional Shape operations (v0.112.0) ---

extension Shape {

    /// Get child shape at 0-based index.
    public func child(at index: Int) -> Shape? {
        guard let ref = OCCTShapeChild(handle, Int32(index)) else { return nil }
        return Shape(handle: ref)
    }

    /// Whether the shape is locked.
    public var isLocked: Bool {
        get { OCCTShapeIsLocked(handle) }
    }

    /// Set locked state on the shape.
    public func setLocked(_ locked: Bool) {
        OCCTShapeSetLocked(handle, locked)
    }

    /// Create a copy with an applied location transform (4x3 row-major matrix).
    public func located(matrix: [Double]) -> Shape? {
        guard matrix.count >= 12 else { return nil }
        guard let ref = matrix.withUnsafeBufferPointer({ buf in
            OCCTShapeLocated(handle, buf.baseAddress!)
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// Get the current location as a 4x3 row-major matrix.
    public var locationMatrix: [Double] {
        var m = [Double](repeating: 0, count: 12)
        OCCTShapeGetLocation(handle, &m)
        return m
    }

    /// Set location transform in-place (4x3 row-major matrix).
    public func setLocation(matrix: [Double]) {
        guard matrix.count >= 12 else { return }
        matrix.withUnsafeBufferPointer { buf in
            OCCTShapeSetLocation(handle, buf.baseAddress!)
        }
    }

    /// Create a shape with specific orientation (0=FWD, 1=REV, 2=INT, 3=EXT).
    public func oriented(_ orientation: Int) -> Shape? {
        guard let ref = OCCTShapeOriented(handle, Int32(orientation)) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an empty shape of given type (0=COMPOUND, 2=SOLID, 3=SHELL, 5=WIRE).
    public static func empty(type: Int) -> Shape? {
        guard let ref = OCCTShapeEmpty(Int32(type)) else { return nil }
        return Shape(handle: ref)
    }

    /// Whether the shape is a compound.
    public var isCompound: Bool { OCCTShapeIsCompound(handle) }

    /// Whether the shape is a solid.
    public var isSolid: Bool { OCCTShapeIsSolid(handle) }

    /// Whether the shape is a shell.
    public var isShell: Bool { OCCTShapeIsShell(handle) }

    /// Whether the shape is a face.
    public var isFace: Bool { OCCTShapeIsFace(handle) }

    /// Whether the shape is an edge.
    public var isEdge: Bool { OCCTShapeIsEdge(handle) }

    /// Create a wire from an array of edge shapes.
    public static func wireFromEdges(_ edges: [Shape]) -> Shape? {
        let refs = edges.map { $0.handle as OCCTShapeRef }
        guard let ref = refs.withUnsafeBufferPointer({ buf in
            OCCTMakeWireFromEdges(buf.baseAddress!, Int32(edges.count))
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a shell from an array of face shapes.
    public static func shellFromFaces(_ faces: [Shape]) -> Shape? {
        let refs = faces.map { $0.handle as OCCTShapeRef }
        guard let ref = refs.withUnsafeBufferPointer({ buf in
            OCCTMakeShell(buf.baseAddress!, Int32(faces.count))
        }) else { return nil }
        return Shape(handle: ref)
    }

    // --- BRepCheck extended (v0.112.0) ---

    /// Check status of a face within this shape. Returns BRepCheck_Status (0=NoError).
    public func checkFaceStatus(face: Shape) -> Int {
        Int(OCCTCheckFaceStatus(handle, face.handle))
    }

    /// Check status of an edge within this shape.
    public func checkEdgeStatus(edge: Shape) -> Int {
        Int(OCCTCheckEdgeStatus(handle, edge.handle))
    }

    /// Check status of a vertex within this shape.
    public func checkVertexStatus(vertex: Shape) -> Int {
        Int(OCCTCheckVertexStatus(handle, vertex.handle))
    }

    /// Max tolerance of sub-shapes of given type (0=vertex, 1=edge, 2=face).
    public func maxTolerance(type: Int) -> Double {
        OCCTShapeMaxTolerance(handle, Int32(type))
    }

    /// Min tolerance of sub-shapes of given type.
    public func minTolerance(type: Int) -> Double {
        OCCTShapeMinTolerance(handle, Int32(type))
    }

    /// Average tolerance of sub-shapes of given type.
    public func avgTolerance(type: Int) -> Double {
        OCCTShapeAvgTolerance(handle, Int32(type))
    }

    /// Fix tolerance on the shape to specified value.
    @discardableResult
    public func fixTolerance(_ tolerance: Double) -> Bool {
        OCCTShapeFixTolerance(handle, tolerance)
    }

    /// Limit max tolerance on the shape.
    @discardableResult
    public func limitMaxTolerance(_ maxTol: Double) -> Bool {
        OCCTShapeLimitMaxTolerance(handle, maxTol)
    }
}

// --- Curve3D extras (v0.112.0) ---

extension Curve3D {

    /// The geometric curve type (0=Line, 1=Circle, 2=Ellipse, 3=Hyperbola, 4=Parabola, 5=BezierCurve, 6=BSplineCurve, 7=OtherCurve).
    public var curveType: Int {
        Int(OCCTCurve3DCurveType(handle))
    }

    /// Find parameter on curve nearest to a 3D point.
    @available(*, deprecated, message: """
        No Double can signal failure here: every value is a legitimate parameter on some curve, \
        and this used to return the curve's firstParameter, right or maximally wrong depending \
        only on which end the point fell off. Use nearestParameter(to:), which returns an Optional.
        """)
    public func parameterAtPoint(_ point: SIMD3<Double>) -> Double {
        nearestParameter(to: point) ?? .nan
    }
}

// --- Curve2D extras (v0.112.0) ---

extension Curve2D {

    /// The geometric curve type.
    public var curveType: Int {
        Int(OCCTCurve2DCurveType(handle))
    }

    /// Find parameter on 2D curve nearest to a 2D point.
    @available(*, deprecated, message: """
        No Double can signal failure here: every value is a legitimate parameter on some curve, \
        and this used to return the curve's firstParameter, right or maximally wrong depending \
        only on which end the point fell off. Use nearestParameter(to:), which returns an Optional.
        """)
    public func parameterAtPoint(_ point: SIMD2<Double>) -> Double {
        nearestParameter(to: point) ?? .nan
    }
}

// --- Surface extras (v0.112.0) ---

extension Surface {

    /// The geometric surface type (0=Plane, 1=Cylinder, 2=Cone, 3=Sphere, 4=Torus, ..., 10=OtherSurface).
    public var surfaceType: Int {
        Int(OCCTSurfaceGetType(handle))
    }
}

// --- Extrema extras (v0.112.0) ---

extension Curve3D {

    /// Local point-on-curve search from an initial parameter guess. Returns `(parameter, distance)`.
    ///
    /// Searches a window of ±10% of the domain around `initParam` and reports the
    /// **lowest-distance extremum inside that window**. `initParam` bounds the window; it does not
    /// rank what is found in it, so the extremum you get back is not necessarily the one nearest
    /// your guess — where a window holds several, the one closest to the *query point* wins.
    ///
    /// The window is what makes the answer local, and a windowed minimum can still be a global
    /// *maximum*: on a half circle of radius 5 queried from `(0, -6, 0)` with a guess of `.pi / 2`,
    /// the window holds the far side of the arc and this reports 11, where the nearest point on the
    /// curve is 7.81 away. Use ``nearestParameter(to:)`` or ``projectPoint(_:precision:)`` when you
    /// want the global answer.
    ///
    /// When the window holds no extremum at all, the search falls back to the whole curve — and,
    /// since #615, to the whole curve's true nearest point, which is what those two report. Before
    /// #615 the fallback reported an extremum instead, so a guess sitting *on* the nearest point
    /// returned the point diametrically opposite it, and a bounded segment queried from past its own
    /// end returned `nil` for every guess.
    ///
    /// ```swift
    /// let arc = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
    ///     .trimmed(from: 0, to: .pi)!
    ///
    /// // Guess 0: no extremum nearby, so the whole curve is searched, correctly.
    /// #expect(arc.locateNearestPoint(SIMD3(0, -6, 0), initParam: 0)?.parameter == 0)
    ///
    /// // Guess .pi / 2: an extremum IS nearby, and it is the far side of the arc.
    /// #expect(arc.locateNearestPoint(SIMD3(0, -6, 0), initParam: .pi / 2)?.distance == 11)
    /// ```
    ///
    /// - Returns: `nil` only when the curve cannot be read.
    public func locateNearestPoint(_ point: SIMD3<Double>, initParam: Double, tolerance: Double = 1e-6) -> (parameter: Double, distance: Double)? {
        var param = 0.0, dist = 0.0
        let ok = OCCTExtremaLocateOnCurve(handle, point.x, point.y, point.z,
                                          initParam, tolerance, &param, &dist)
        return ok ? (param, dist) : nil
    }

    /// Global point-to-curve projection returning all extrema. Returns array of (parameter, distance).
    ///
    /// - Parameter maxResults: Output *capacity* (default 10), clamped into `0...`
    ///   ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    public func projectPointAll(_ point: SIMD3<Double>, maxResults: Int = 10) -> [(parameter: Double, distance: Double)] {
        let maxResults = Sampling.capacity(maxResults)
        guard maxResults > 0 else { return [] }
        var params = [Double](repeating: 0, count: maxResults)
        var distances = [Double](repeating: 0, count: maxResults)
        let n = Int(OCCTExtremaPointCurve(handle, point.x, point.y, point.z,
                                          &params, &distances, Int32(maxResults)))
        return (0..<n).map { (params[$0], distances[$0]) }
    }
}

extension Surface {

    /// Local point-on-surface search from initial (u,v) guess. Returns (u, v, distance).
    public func locateNearestPoint(_ point: SIMD3<Double>, initU: Double, initV: Double, tolerance: Double = 1e-6) -> (u: Double, v: Double, distance: Double)? {
        var u = 0.0, v = 0.0, dist = 0.0
        let ok = OCCTExtremaLocateOnSurface(handle, point.x, point.y, point.z,
                                            initU, initV, tolerance, &u, &v, &dist)
        return ok ? (u, v, dist) : nil
    }

    /// Global point-to-surface projection returning all extrema. Returns array of (u, v, distance).
    ///
    /// - Parameter maxResults: Output *capacity* (default 10), clamped into `0...`
    ///   ``Sampling/maximumSampleCount``; 0 or less returns empty (#622).
    public func projectPointAll(_ point: SIMD3<Double>, maxResults: Int = 10) -> [(u: Double, v: Double, distance: Double)] {
        let maxResults = Sampling.capacity(maxResults)
        guard maxResults > 0 else { return [] }
        var us = [Double](repeating: 0, count: maxResults)
        var vs = [Double](repeating: 0, count: maxResults)
        var distances = [Double](repeating: 0, count: maxResults)
        let n = Int(OCCTExtremaPointSurface(handle, point.x, point.y, point.z,
                                            &us, &vs, &distances, Int32(maxResults)))
        return (0..<n).map { (us[$0], vs[$0], distances[$0]) }
    }
}

// MARK: - MakeEdge completions, ProjOnCurve/Surf, DistShapeShape, ShapeFix_Wire/Face, (v0.113.0)
//                    MakeFace extras, IntCS, BSplineCurve/Surface mutations

// --- BRepBuilderAPI_MakeEdge completions ---

extension Shape {

    /// Create a full ellipse edge.
    ///
    /// - Parameters:
    ///   - center: Ellipse centre.
    ///   - normal: Normal of the plane the ellipse lies in.
    ///   - majorRadius: Major radius. Must be `> 0`.
    ///   - minorRadius: Minor radius. Must be `> 0` and no larger than `majorRadius`.
    /// - Returns: The edge, or `nil` if the radii do not describe an ellipse.
    ///
    /// `BRepBuilderAPI_MakeEdge` reports `IsDone()` for a degenerate conic, so without the radius
    /// check this returned a live edge carrying a curve that is really a point (#554).
    ///
    /// ```swift
    /// let e = Shape.edgeFromEllipse(majorRadius: 10, minorRadius: 5)
    /// #expect(e != nil)
    /// #expect(Shape.edgeFromEllipse(majorRadius: 10, minorRadius: 0) == nil)
    /// ```
    public static func edgeFromEllipse(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0,0,1),
                                        majorRadius: Double, minorRadius: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeFromEllipse(center.x, center.y, center.z,
                                                  normal.x, normal.y, normal.z,
                                                  majorRadius, minorRadius) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an ellipse arc edge.
    ///
    /// Same radius contract as `edgeFromEllipse(center:normal:majorRadius:minorRadius:)`.
    ///
    /// ```swift
    /// let e = Shape.edgeFromEllipseArc(majorRadius: 10, minorRadius: 5, u1: 0, u2: .pi)
    /// #expect(e != nil)
    /// #expect(Shape.edgeFromEllipseArc(majorRadius: 10, minorRadius: 0, u1: 0, u2: .pi) == nil)
    /// ```
    public static func edgeFromEllipseArc(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0,0,1),
                                           majorRadius: Double, minorRadius: Double,
                                           u1: Double, u2: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeFromEllipseArc(center.x, center.y, center.z,
                                                      normal.x, normal.y, normal.z,
                                                      majorRadius, minorRadius, u1, u2) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a hyperbola arc edge.
    ///
    /// Both radii must be `> 0`, with no ordering constraint between them.
    ///
    /// ```swift
    /// let e = Shape.edgeFromHyperbolaArc(majorRadius: 8, minorRadius: 3, u1: 0, u2: 1)
    /// #expect(e != nil)
    /// #expect(Shape.edgeFromHyperbolaArc(majorRadius: 8, minorRadius: 0, u1: 0, u2: 1) == nil)
    /// ```
    public static func edgeFromHyperbolaArc(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0,0,1),
                                             majorRadius: Double, minorRadius: Double,
                                             u1: Double, u2: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeFromHyperbolaArc(center.x, center.y, center.z,
                                                        normal.x, normal.y, normal.z,
                                                        majorRadius, minorRadius, u1, u2) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a parabola arc edge.
    ///
    /// `focalLength` must be `> 0`; at zero the parabola is a straight line along its own axis.
    ///
    /// ```swift
    /// let e = Shape.edgeFromParabolaArc(focalLength: 4, u1: 0, u2: 1)
    /// #expect(e != nil)
    /// #expect(Shape.edgeFromParabolaArc(focalLength: 0, u1: 0, u2: 1) == nil)
    /// ```
    public static func edgeFromParabolaArc(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0,0,1),
                                            focalLength: Double, u1: Double, u2: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeFromParabolaArc(center.x, center.y, center.z,
                                                       normal.x, normal.y, normal.z,
                                                       focalLength, u1, u2) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an edge from a 3D curve (full domain).
    public static func edgeFromCurve(_ curve: Curve3D) -> Shape? {
        guard let ref = OCCTMakeEdgeFromCurve(curve.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an edge from a 3D curve with parameter bounds.
    public static func edgeFromCurve(_ curve: Curve3D, u1: Double, u2: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeFromCurveParams(curve.handle, u1, u2) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an edge from a 3D curve with point bounds.
    public static func edgeFromCurve(_ curve: Curve3D, from p1: SIMD3<Double>, to p2: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTMakeEdgeFromCurvePoints(curve.handle, p1.x, p1.y, p1.z,
                                                       p2.x, p2.y, p2.z) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an edge from a 2D pcurve on a surface (full domain).
    public static func edgeOnSurface(pcurve: Curve2D, surface: Surface) -> Shape? {
        guard let ref = OCCTMakeEdgeOnSurface(pcurve.handle, surface.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an edge from a 2D pcurve on a surface with parameter bounds.
    public static func edgeOnSurface(pcurve: Curve2D, surface: Surface, u1: Double, u2: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeOnSurfaceParams(pcurve.handle, surface.handle, u1, u2) else { return nil }
        return Shape(handle: ref)
    }

    /// Get the first vertex point of an edge.
    public func edgeVertex1() -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTEdgeVertex1(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get the last vertex point of an edge.
    public func edgeVertex2() -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTEdgeVertex2(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Create a face from a surface with UV bounds and tolerance.
    public static func face(from surface: Surface, uBounds: ClosedRange<Double>, vBounds: ClosedRange<Double>,
                             tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTMakeFaceFromSurfaceUV(surface.handle,
                                                     uBounds.lowerBound, uBounds.upperBound,
                                                     vBounds.lowerBound, vBounds.upperBound, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a gp_Plane with UV bounds.
    public static func faceFromPlane(origin: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0,0,1),
                                      uBounds: ClosedRange<Double>, vBounds: ClosedRange<Double>) -> Shape? {
        guard let ref = OCCTMakeFaceFromGpPlane(origin.x, origin.y, origin.z,
                                                   normal.x, normal.y, normal.z,
                                                   uBounds.lowerBound, uBounds.upperBound,
                                                   vBounds.lowerBound, vBounds.upperBound) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a gp_Cylinder with UV bounds.
    public static func faceFromCylinder(origin: SIMD3<Double> = .zero, axis: SIMD3<Double> = SIMD3(0,0,1),
                                         radius: Double,
                                         uBounds: ClosedRange<Double>, vBounds: ClosedRange<Double>) -> Shape? {
        guard let ref = OCCTMakeFaceFromGpCylinder(origin.x, origin.y, origin.z,
                                                      axis.x, axis.y, axis.z, radius,
                                                      uBounds.lowerBound, uBounds.upperBound,
                                                      vBounds.lowerBound, vBounds.upperBound) else { return nil }
        return Shape(handle: ref)
    }
}

// --- ProjectionOnCurve class ---


// --- ProjectionOnSurface class ---


// --- ShapeDistance class ---



// --- WireFixer class ---


// --- FaceFixer class ---


// --- IntCSResult class ---


// --- BSplineCurve remaining mutations ---

extension Curve3D {

    /// Set the knot value at a given index (1-based).
    public func bsplineSetKnot(index: Int, value: Double) -> Bool {
        OCCTCurve3DBSplineSetKnot(handle, Int32(index), value)
    }

    /// Get the full knot sequence (with multiplicities expanded).
    public func bsplineKnotSequence() -> [Double] {
        let maxSize = 1024
        var seq = [Double](repeating: 0, count: maxSize)
        var count: Int32 = 0
        OCCTCurve3DBSplineGetKnotSequence(handle, &seq, &count)
        return Array(seq.prefix(Int(count)))
    }

    /// Get all weights (one per pole).
    public func bsplineWeights() -> [Double] {
        let nPoles = Int(OCCTCurve3DBSplinePoleCount(handle))
        guard nPoles > 0 else { return [] }
        var weights = [Double](repeating: 0, count: nPoles)
        OCCTCurve3DBSplineGetWeights(handle, &weights)
        return weights
    }

    /// Insert multiple knots at once.
    public func bsplineInsertKnots(_ knots: [Double], multiplicities: [Int], tolerance: Double = 1e-10) -> Bool {
        let count = min(knots.count, multiplicities.count)
        guard count > 0 else { return false }
        let mults = multiplicities.map { Int32($0) }
        return OCCTCurve3DBSplineInsertKnots(handle, knots, mults, Int32(count), tolerance)
    }

    /// Move a point on the BSpline curve to a new position.
    public func bsplineMovePoint(u: Double, to point: SIMD3<Double>, poleRange: ClosedRange<Int>) -> Bool {
        OCCTCurve3DBSplineMovePoint(handle, u, point.x, point.y, point.z,
                                     Int32(poleRange.lowerBound), Int32(poleRange.upperBound))
    }

    /// Evaluate the curve locally within a knot span.
    public func bsplineLocalValue(u: Double, fromKnot: Int, toKnot: Int) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTCurve3DBSplineLocalValue(handle, u, Int32(fromKnot), Int32(toKnot), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on BSpline curve within knot span [fromKnot, toKnot].
    public func bsplineLocalD0(u: Double, fromKnot: Int, toKnot: Int) -> SIMD3<Double> {
        var px = 0.0, py = 0.0, pz = 0.0
        OCCTCurve3DBSplineLocalD0(handle, u, Int32(fromKnot), Int32(toKnot), &px, &py, &pz)
        return SIMD3(px, py, pz)
    }

    /// Evaluate point + 1st derivative on BSpline curve within knot span.
    public func bsplineLocalD1(u: Double, fromKnot: Int, toKnot: Int)
        -> (point: SIMD3<Double>, d1: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var vx = 0.0, vy = 0.0, vz = 0.0
        OCCTCurve3DBSplineLocalD1(handle, u, Int32(fromKnot), Int32(toKnot),
                                   &px, &py, &pz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(vx, vy, vz))
    }

    /// Evaluate point + 1st + 2nd derivative on BSpline curve within knot span.
    public func bsplineLocalD2(u: Double, fromKnot: Int, toKnot: Int)
        -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var v1x = 0.0, v1y = 0.0, v1z = 0.0
        var v2x = 0.0, v2y = 0.0, v2z = 0.0
        OCCTCurve3DBSplineLocalD2(handle, u, Int32(fromKnot), Int32(toKnot),
                                   &px, &py, &pz, &v1x, &v1y, &v1z, &v2x, &v2y, &v2z)
        return (SIMD3(px, py, pz), SIMD3(v1x, v1y, v1z), SIMD3(v2x, v2y, v2z))
    }

    /// Evaluate point + 1st + 2nd + 3rd derivative on BSpline curve within knot span.
    public func bsplineLocalD3(u: Double, fromKnot: Int, toKnot: Int)
        -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>, d3: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var v1x = 0.0, v1y = 0.0, v1z = 0.0
        var v2x = 0.0, v2y = 0.0, v2z = 0.0
        var v3x = 0.0, v3y = 0.0, v3z = 0.0
        OCCTCurve3DBSplineLocalD3(handle, u, Int32(fromKnot), Int32(toKnot),
                                   &px, &py, &pz, &v1x, &v1y, &v1z,
                                   &v2x, &v2y, &v2z, &v3x, &v3y, &v3z)
        return (SIMD3(px, py, pz), SIMD3(v1x, v1y, v1z),
                SIMD3(v2x, v2y, v2z), SIMD3(v3x, v3y, v3z))
    }

    /// Evaluate Nth derivative on BSpline curve within knot span.
    public func bsplineLocalDN(u: Double, fromKnot: Int, toKnot: Int, n: Int) -> SIMD3<Double> {
        var vx = 0.0, vy = 0.0, vz = 0.0
        OCCTCurve3DBSplineLocalDN(handle, u, Int32(fromKnot), Int32(toKnot), Int32(n),
                                   &vx, &vy, &vz)
        return SIMD3(vx, vy, vz)
    }

    /// Maximum BSpline degree supported (static).
    public static var bsplineMaxDegree: Int { Int(OCCTCurve3DBSplineMaxDegree()) }

    /// Locate the knot span containing parameter u.
    public func bsplineLocateU(_ u: Double, tolerance: Double = 1e-10) -> Int {
        Int(OCCTCurve3DBSplineLocateU(handle, u, tolerance))
    }
}

// --- BSplineSurface remaining mutations ---

extension Surface {

    /// Set U knot at given index (1-based).
    public func bsplineSetUKnot(index: Int, value: Double) -> Bool {
        OCCTSurfaceBSplineSetUKnot(handle, Int32(index), value)
    }

    /// Set V knot at given index (1-based).
    public func bsplineSetVKnot(index: Int, value: Double) -> Bool {
        OCCTSurfaceBSplineSetVKnot(handle, Int32(index), value)
    }

    /// Get all U knots.
    public func bsplineUKnots() -> [Double] {
        let n = Int(OCCTSurfaceBSplineNbUKnots(handle))
        guard n > 0 else { return [] }
        var knots = [Double](repeating: 0, count: n)
        OCCTSurfaceBSplineGetUKnots(handle, &knots)
        return knots
    }

    /// Get all V knots.
    public func bsplineVKnots() -> [Double] {
        let n = Int(OCCTSurfaceBSplineNbVKnots(handle))
        guard n > 0 else { return [] }
        var knots = [Double](repeating: 0, count: n)
        OCCTSurfaceBSplineGetVKnots(handle, &knots)
        return knots
    }

    /// Get all weights (row-major, NbUPoles x NbVPoles).
    public func bsplineWeights() -> (weights: [Double], rows: Int, cols: Int) {
        let maxSize = 10000
        var weights = [Double](repeating: 0, count: maxSize)
        var rows: Int32 = 0, cols: Int32 = 0
        OCCTSurfaceBSplineGetWeights(handle, &weights, &rows, &cols)
        return (Array(weights.prefix(Int(rows) * Int(cols))), Int(rows), Int(cols))
    }

    /// Remove a U knot. Returns true if successful.
    public func bsplineRemoveUKnot(index: Int, multiplicity: Int, tolerance: Double) -> Bool {
        OCCTSurfaceBSplineRemoveUKnot(handle, Int32(index), Int32(multiplicity), tolerance)
    }
}

// MARK: - TopoDS_Builder, ShapeContents expanded, FreeBoundsProperties, WireBuilder, (v0.114.0)
//                    Boolean tolerances, Offset wire/face, ThickSolid, BRepLib, Mass properties, isBounded

// --- TopoDS_Builder ---

extension Shape {

    /// Create an empty wire via TopoDS_Builder.
    public static func builderMakeWire() -> Shape? {
        guard let ref = OCCTBuilderMakeWire() else { return nil }
        return Shape(handle: ref)
    }

    /// Create an empty shell via TopoDS_Builder.
    public static func builderMakeShell() -> Shape? {
        guard let ref = OCCTBuilderMakeShell() else { return nil }
        return Shape(handle: ref)
    }

    /// Create an empty solid via TopoDS_Builder.
    public static func builderMakeSolid() -> Shape? {
        guard let ref = OCCTBuilderMakeSolid() else { return nil }
        return Shape(handle: ref)
    }

    /// Create an empty compound via TopoDS_Builder.
    public static func builderMakeCompound() -> Shape? {
        guard let ref = OCCTBuilderMakeCompound() else { return nil }
        return Shape(handle: ref)
    }

    /// Create an empty comp-solid via TopoDS_Builder.
    public static func builderMakeCompSolid() -> Shape? {
        guard let ref = OCCTBuilderMakeCompSolid() else { return nil }
        return Shape(handle: ref)
    }

    /// Add child shape into this shape using TopoDS_Builder.
    @discardableResult
    public func builderAdd(_ child: Shape) -> Bool {
        OCCTBuilderAdd(handle, child.handle)
    }

    /// Remove child shape from this shape using TopoDS_Builder.
    @discardableResult
    public func builderRemove(_ child: Shape) -> Bool {
        OCCTBuilderRemove(handle, child.handle)
    }
}

// --- ShapeAnalysis_ShapeContents expanded ---


extension Shape {

    /// Get extended shape contents analysis.
    public func contentsExtended() -> ShapeContentsExtended {
        let c = OCCTShapeGetContentsExtended(handle)
        return ShapeContentsExtended(
            nbSolids: Int(c.nbSolids), nbShells: Int(c.nbShells),
            nbFaces: Int(c.nbFaces), nbWires: Int(c.nbWires),
            nbEdges: Int(c.nbEdges), nbVertices: Int(c.nbVertices),
            nbFreeEdges: Int(c.nbFreeEdges), nbFreeWires: Int(c.nbFreeWires),
            nbFreeFaces: Int(c.nbFreeFaces), nbSolidsWithVoids: Int(c.nbSolidsWithVoids),
            nbBigSplines: Int(c.nbBigSplines), nbC0Surfaces: Int(c.nbC0Surfaces),
            nbC0Curves: Int(c.nbC0Curves), nbOffsetSurf: Int(c.nbOffsetSurf),
            nbIndirectSurf: Int(c.nbIndirectSurf), nbOffsetCurves: Int(c.nbOffsetCurves),
            nbTrimmedCurve2d: Int(c.nbTrimmedCurve2d), nbTrimmedCurve3d: Int(c.nbTrimmedCurve3d),
            nbBSplineSurf: Int(c.nbBSplineSurf), nbBezierSurf: Int(c.nbBezierSurf),
            nbTrimSurf: Int(c.nbTrimSurf), nbWireWithSeam: Int(c.nbWireWithSeam),
            nbWireWithSevSeams: Int(c.nbWireWithSevSeams), nbFaceWithSevWires: Int(c.nbFaceWithSevWires),
            nbNoPCurve: Int(c.nbNoPCurve), nbSharedSolids: Int(c.nbSharedSolids),
            nbSharedShells: Int(c.nbSharedShells), nbSharedFaces: Int(c.nbSharedFaces),
            nbSharedWires: Int(c.nbSharedWires), nbSharedEdges: Int(c.nbSharedEdges),
            nbSharedVertices: Int(c.nbSharedVertices)
        )
    }
}

// --- ShapeAnalysis_FreeBoundsProperties ---


// --- BRepBuilderAPI_MakeWire (incremental) ---


// --- Boolean operations with tolerance ---

extension Shape {

    /// Fuse two shapes with fuzzy tolerance.
    public func fused(with other: Shape, tolerance: Double) -> Shape? {
        guard let ref = OCCTBooleanFuseWithTolerance(handle, other.handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Cut another shape from this shape with fuzzy tolerance.
    public func subtracted(_ other: Shape, tolerance: Double) -> Shape? {
        guard let ref = OCCTBooleanCutWithTolerance(handle, other.handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Common of two shapes with fuzzy tolerance.
    public func intersected(with other: Shape, tolerance: Double) -> Shape? {
        guard let ref = OCCTBooleanCommonWithTolerance(handle, other.handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Glue mode for boolean operations.
    public enum GlueMode: Int32, Sendable {
        case shift = 0
        case full = 1
        case off = 2
    }

    /// Fuse two shapes with glue mode.
    public func fused(with other: Shape, glue: GlueMode) -> Shape? {
        guard let ref = OCCTBooleanFuseGlue(handle, other.handle, glue.rawValue) else { return nil }
        return Shape(handle: ref)
    }

    /// Cut another shape with glue mode.
    public func subtracted(_ other: Shape, glue: GlueMode) -> Shape? {
        guard let ref = OCCTBooleanCutGlue(handle, other.handle, glue.rawValue) else { return nil }
        return Shape(handle: ref)
    }

    /// Common of two shapes with glue mode.
    public func intersected(with other: Shape, glue: GlueMode) -> Shape? {
        guard let ref = OCCTBooleanCommonGlue(handle, other.handle, glue.rawValue) else { return nil }
        return Shape(handle: ref)
    }
}

// --- BRepOffsetAPI_MakeOffset expansion ---

extension Shape {

    /// Join type for offset operations.
    public enum OffsetJoinType: Int32, Sendable {
        case arc = 0
        case tangent = 1
        case intersection = 2
    }

    /// Offset a wire on a plane.
    public func offsetWireOnPlane(distance: Double, joinType: OffsetJoinType = .arc) -> Shape? {
        guard let ref = OCCTOffsetWireOnPlane(handle, distance, joinType.rawValue) else { return nil }
        return Shape(handle: ref)
    }

    /// Offset a face.
    public func offsetFace(distance: Double, joinType: OffsetJoinType = .arc) -> Shape? {
        guard let ref = OCCTOffsetFace(handle, distance, joinType.rawValue) else { return nil }
        return Shape(handle: ref)
    }
}

// --- BRepOffsetAPI_MakeThickSolid expansion ---

extension Shape {

    /// Create a thick solid by removing faces and offsetting.
    public func thickSolid(facesToRemove: [Shape], offset: Double,
                           tolerance: Double = 1e-3,
                           joinType: OffsetJoinType = .arc) -> Shape? {
        var faceRefs: [OCCTShapeRef] = facesToRemove.map { $0.handle }
        guard let ref = OCCTThickSolidWithOptions(handle, &faceRefs, Int32(faceRefs.count),
                                                    offset, tolerance, joinType.rawValue) else { return nil }
        return Shape(handle: ref)
    }
}

// --- BRepLib utilities ---

extension Shape {

    /// Orient a closed solid so that face normals point outward.
    @discardableResult
    public func orientClosedSolid() -> Bool {
        OCCTBRepLibOrientClosedSolid(handle)
    }

    /// Build a 3D curve for every edge of this shape that has only pcurves.
    ///
    /// Edges from a loft, a sweep, or a surface-based face can carry a 2D curve on their support
    /// surface and no 3D curve at all. Anything that walks edge geometry — discretisation, length,
    /// export — needs the 3D curve, so this fills them in. Edges that already have one are left
    /// exactly as they are, so calling it twice costs nothing the second time.
    ///
    /// ```swift
    /// // An edge built from a pcurve on a cylinder has no 3D curve until this runs.
    /// let cylinder = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 10)!
    /// let pcurve = Curve2D.line(through: SIMD2(0.2, -3), direction: SIMD2(0.6, 0.8))!
    /// let edge = Shape.edgeOnSurface(pcurve: pcurve, surface: cylinder, u1: 0, u2: 2)!
    ///
    /// print(edge.extractEdgeCurve3D() == nil)   // true
    /// print(edge.buildCurves3d())               // true
    /// print(edge.extractEdgeCurve3D() != nil)   // true — a BSpline approximating the helix
    /// print(edge.edgeTolerance)                 // 1e-05 — the tolerance lands on the edge
    /// ```
    ///
    /// - Parameter tolerance: Approximation tolerance, and also the rebuilt edge's tolerance floor
    ///   (OCCT sets the edge tolerance to this value, not to the deviation it actually achieved).
    ///   The default is OCCT's own default for the operation. A tighter value buys a closer curve
    ///   for a pole or two more — measured on a helix, `1e-5` deviates from the exact curve by
    ///   2.6e-6 and `1e-7` by 9.0e-8 — but it also claims an edge tolerance the approximation may
    ///   not be able to keep on hard geometry. Ignored when the pcurve lies on a plane: that case
    ///   is analytic and exact.
    /// - Returns: `false` if any single edge could not be given a 3D curve (a degenerate edge with
    ///   no planar pcurve, or one stripped of every representation). The edges that did succeed are
    ///   still modified, so `false` means "partially built", not "nothing happened".
    @discardableResult
    public func buildCurves3d(tolerance: Double = 1e-5) -> Bool {
        OCCTBRepLibBuildCurves3dForShape(handle, tolerance)
    }

    /// Sort faces by decreasing area.
    public func sortedFaces() -> Shape? {
        guard let ref = OCCTBRepLibSortFaces(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Sort faces by increasing area.
    public func reverseSortedFaces() -> Shape? {
        guard let ref = OCCTBRepLibReverseSortFaces(handle) else { return nil }
        return Shape(handle: ref)
    }
}

// --- Shape mass properties expansion ---

extension Shape {

    /// Linear properties result (length + center of mass).
    public struct LinearProperties: Sendable {
        public let length: Double
        public let centerOfMass: SIMD3<Double>
    }

    /// Get linear properties (total length and center of mass) for edges/wires.
    ///
    /// Nil for a shape with no edges, such as a lone vertex. The centre of mass reported there was
    /// the shape's location origin, not a recognisable zero (#609).
    ///
    /// - Warning: `length` here comes from `BRepGProp::LinearProperties`, which runs its own
    ///   integrator — one fixed-order Gauss rule per span, the defect #603 fixed everywhere else.
    ///   On an elliptical edge it reports 41.243158 against a true 40.639742 (+1.485%) and so
    ///   **disagrees with ``Shape/edgeArcLength``**, which measures 40.639742. Before #603 both
    ///   were wrong together. Use ``Shape/edgeArcLength`` or ``Wire/length`` when you want the
    ///   length; this call remains the way to get the centre of mass.
    ///
    /// ```swift
    /// let wire = Shape.fromWire(Wire.rectangle(width: 10, height: 20)!)!
    /// wire.linearProperties()?.length   // 60
    ///
    /// let vertex = Shape.box(width: 10, height: 10, depth: 10)!.subShapes(ofType: .vertex)[0]
    /// vertex.linearProperties()         // nil, a vertex has no length and no centroid
    /// ```
    public func linearProperties() -> LinearProperties? {
        var length = 0.0, cx = 0.0, cy = 0.0, cz = 0.0
        guard OCCTShapeLinearProperties(handle, &length, &cx, &cy, &cz) else { return nil }
        return LinearProperties(length: length, centerOfMass: SIMD3(cx, cy, cz))
    }

    /// Inertia tensor result.
    public struct InertiaTensor: Sendable {
        public let ixx: Double, iyy: Double, izz: Double
        public let ixy: Double, ixz: Double, iyz: Double
    }

    /// Get the inertia tensor (moment of inertia matrix) for a volumetric shape.
    ///
    /// Nil for a shape with no closed volume, where the tensor is identically zero and
    /// indistinguishable from a real answer for a shape that happens to have no moments (#609).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 20, depth: 30)!
    /// box.momentOfInertia()?.ixx                          // 650000
    /// Shape.fromFace(box.faces()[0])?.momentOfInertia()   // nil, a face has no volume
    /// ```
    public func momentOfInertia() -> InertiaTensor? {
        var ixx = 0.0, iyy = 0.0, izz = 0.0
        var ixy = 0.0, ixz = 0.0, iyz = 0.0
        guard OCCTShapeMomentOfInertia(handle, &ixx, &iyy, &izz, &ixy, &ixz, &iyz) else { return nil }
        return InertiaTensor(ixx: ixx, iyy: iyy, izz: izz, ixy: ixy, ixz: ixz, iyz: iyz)
    }

    /// Principal axes of inertia (3 direction vectors).
    public struct PrincipalAxes: Sendable {
        public let axis1: SIMD3<Double>
        public let axis2: SIMD3<Double>
        public let axis3: SIMD3<Double>
    }

    /// Get the principal axes of inertia.
    ///
    /// Nil for a shape with no closed volume. It used to return three orthonormal unit vectors
    /// there, which look like a real answer but are just the identity basis that OCCT's Jacobi
    /// eigensolver returns for the zero inertia matrix (#609).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 20, depth: 30)!
    /// box.principalAxes()?.axis1                       // a real principal direction
    /// Shape.fromFace(box.faces()[0])?.principalAxes()  // nil, was (0,0,1)/(1,0,0)/(0,1,0)
    /// ```
    public func principalAxes() -> PrincipalAxes? {
        var axes = [Double](repeating: 0, count: 9)
        guard OCCTShapePrincipalAxes(handle, &axes) else { return nil }
        return PrincipalAxes(
            axis1: SIMD3(axes[0], axes[1], axes[2]),
            axis2: SIMD3(axes[3], axes[4], axes[5]),
            axis3: SIMD3(axes[6], axes[7], axes[8])
        )
    }

    /// Get the radius of gyration about an axis defined by a point and direction.
    ///
    /// Nil for a shape with no closed volume. OCCT computes this as `sqrt(momentOfInertia / mass)`
    /// with no guard, so it used to return **NaN** there, which propagates silently through any
    /// arithmetic that consumes it (#609).
    ///
    /// ```swift
    /// let cyl = Shape.cylinder(radius: 3, height: 10)!
    /// cyl.radiusOfGyration(axisOrigin: .zero, direction: SIMD3(0, 0, 1))   // 2.12
    ///
    /// let sheet = Shape.fromFace(cyl.faces()[0])!
    /// sheet.radiusOfGyration(axisOrigin: .zero, direction: SIMD3(0, 0, 1)) // nil, was NaN
    /// ```
    public func radiusOfGyration(axisOrigin: SIMD3<Double>, direction: SIMD3<Double>) -> Double? {
        var radius = 0.0
        guard OCCTShapeRadiusOfGyration(handle,
                                        axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                        direction.x, direction.y, direction.z,
                                        &radius) else { return nil }
        return radius
    }
}

// --- Curve isBounded ---

extension Curve3D {

    /// Whether this curve is bounded (Geom_BoundedCurve subclass).
    public var isBounded: Bool { OCCTCurve3DIsBounded(handle) }
}

extension Curve2D {

    /// Whether this curve is bounded (Geom2d_BoundedCurve subclass).
    public var isBounded: Bool { OCCTCurve2DIsBounded(handle) }
}

// --- Quantity_Color named color count ---

extension Color {

    /// The total number of named colors available in OCCT.
    public static var namedColorCount: Int { Int(OCCTNamedColorCount()) }
}

// --- BRep_Tool queries on Shape ---

extension Shape {

    /// Get the 3D curve from an edge shape with parameter range.
    public func edgeCurveWithParams() -> (curve: Curve3D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let ref = OCCTShapeEdgeCurve(handle, &first, &last) else { return nil }
        return (Curve3D(handle: ref), first, last)
    }

    /// Get the surface from a face shape.
    public func faceSurfaceGeom() -> Surface? {
        guard let ref = OCCTShapeFaceSurface(handle) else { return nil }
        return Surface(handle: ref)
    }

    /// Whether this shape is closed (wire or shell).
    public var isClosedShape: Bool { OCCTShapeIsClosed(handle) }
}

// --- Unique sub-shape counts ---
//
// Older spellings of the counts on `subShapeCount(ofType:)`, kept because they are public. The
// "unique" in the name is not a distinction: every sub-shape count in this API reads the one
// deduplicated enumeration, so these agree with `edgeCount`, `faceCount`, `vertexCount` and
// `subShapeCount(ofType:)` by construction rather than by coincidence. (#502)

extension Shape {

    /// Number of unique edges in this shape. Same value as ``edgeCount``.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.uniqueEdgeCount == box.edgeCount)   // true, 12 either way
    /// ```
    public var uniqueEdgeCount: Int { Int(OCCTShapeUniqueEdgeCount(handle)) }

    /// Number of unique faces in this shape. Same value as ``faceCount``.
    public var uniqueFaceCount: Int { Int(OCCTShapeUniqueFaceCount(handle)) }

    /// Number of unique vertices in this shape. Same value as ``vertexCount``.
    public var uniqueVertexCount: Int { Int(OCCTShapeUniqueVertexCount(handle)) }

    /// Count unique sub-shapes of a specific type. Same value as ``subShapeCount(ofType:)``.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.uniqueSubShapeCount(ofType: .wire))   // 6
    /// ```
    public func uniqueSubShapeCount(ofType type: ShapeType) -> Int {
        Int(OCCTShapeUniqueSubShapeCount(handle, Int32(type.rawValue)))
    }
}

// --- Shape empty copy ---

extension Shape {

    /// Create an empty copy of this shape (same TShape, no sub-shapes).
    public func emptyCopied() -> Shape? {
        guard let ref = OCCTShapeEmptyCopied(handle) else { return nil }
        return Shape(handle: ref)
    }
}

// --- Curve/Surface DN (arbitrary derivative) ---

extension Curve3D {

    /// Evaluate the N-th derivative at parameter u.
    public func dn(at u: Double, order n: Int) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTCurve3DDN(handle, u, Int32(n), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// The type name of this curve (e.g. "Geom_Line", "Geom_Circle").
    public var typeName: String? {
        guard let ptr = OCCTCurve3DTypeName(handle) else { return nil }
        return String(cString: ptr)
    }
}

extension Curve2D {

    /// Evaluate the N-th derivative at parameter u.
    public func dn(at u: Double, order n: Int) -> SIMD2<Double> {
        var x = 0.0, y = 0.0
        OCCTCurve2DDN(handle, u, Int32(n), &x, &y)
        return SIMD2(x, y)
    }

    /// The type name of this curve (e.g. "Geom2d_Line", "Geom2d_Circle").
    public var typeName: String? {
        guard let ptr = OCCTCurve2DTypeName(handle) else { return nil }
        return String(cString: ptr)
    }
}

extension Surface {

    /// Evaluate the (Nu, Nv) partial derivative at (u, v).
    public func dn(u: Double, v: Double, nu: Int, nv: Int) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTSurfaceDN(handle, u, v, Int32(nu), Int32(nv), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// The type name of this surface (e.g. "Geom_Plane", "Geom_BSplineSurface").
    public var typeName: String? {
        guard let ptr = OCCTSurfaceTypeName(handle) else { return nil }
        return String(cString: ptr)
    }
}

// MARK: - HelixGeom, gp_Ax3, gp_GTrsf2d, gp_Mat2d, Quaternion Interpolation, XY/XYZ, Math Solvers (v0.116.0)

// MARK: - HelixGeom (v0.116.0)


// MARK: - CoordinateSystem3D (gp_Ax3) (v0.116.0)


// MARK: - GeneralTransform2D (gp_GTrsf2d) (v0.116.0)


// MARK: - Matrix2D (gp_Mat2d) (v0.116.0)


// MARK: - Quaternion Interpolation (v0.116.0)


// MARK: - XY/XYZ Utilities (v0.116.0)



// MARK: - MathSolver Extensions (v0.116.0)


// MARK: - PolynomialSolver rc4 Extensions (v0.117.0)

extension PolynomialSolver {

    /// Solve linear equation: ax + b = 0 using MathPoly rc4 solver.
    public static func linearRc4(a: Double, b: Double) -> [Double]? {
        var roots = [Double](repeating: 0, count: 1)
        let n = OCCTMathPolyLinear(a, b, &roots, 1)
        return n >= 0 ? Array(roots.prefix(Int(n))) : nil
    }

    /// Solve quadratic equation: ax^2 + bx + c = 0 using MathPoly rc4 solver.
    public static func quadraticRc4(a: Double, b: Double, c: Double) -> [Double]? {
        var roots = [Double](repeating: 0, count: 2)
        let n = OCCTMathPolyQuadratic(a, b, c, &roots, 2)
        return n >= 0 ? Array(roots.prefix(Int(n))) : nil
    }

    /// Solve cubic equation: ax^3 + bx^2 + cx + d = 0 using MathPoly rc4 solver.
    public static func cubicRc4(a: Double, b: Double, c: Double, d: Double) -> [Double]? {
        var roots = [Double](repeating: 0, count: 3)
        let n = OCCTMathPolyCubic(a, b, c, d, &roots, 3)
        return n >= 0 ? Array(roots.prefix(Int(n))) : nil
    }

    /// Solve quartic equation: ax^4 + bx^3 + cx^2 + dx + e = 0 using MathPoly rc4 solver.
    public static func quarticRc4(a: Double, b: Double, c: Double, d: Double, e: Double) -> [Double]? {
        var roots = [Double](repeating: 0, count: 4)
        let n = OCCTMathPolyQuartic(a, b, c, d, e, &roots, 4)
        return n >= 0 ? Array(roots.prefix(Int(n))) : nil
    }
}

// MARK: - MathInteg rc4 Extensions (v0.117.0)


// MARK: - UnitsConversion (v0.117.0)



// MARK: - Curve3D LProp3d Extensions (v0.117.0)

extension Curve3D {

    /// The curvature of the curve at a parameter value.
    ///
    /// Not merely equivalent to ``Curve3D/curvature(at:)`` — since #494 gave the two the same
    /// resolution it *is* the same call, and measured over the same curves the two never disagreed
    /// on any row, degenerate ones included. So this spelling forwards rather than duplicating, and
    /// the bridge function behind it is gone (#595).
    ///
    /// - Parameter u: Curve parameter.
    /// - Returns: Curvature (1/radius), `nil` where the curve has no defined tangent, and
    ///   `Double.greatestFiniteMagnitude` at a cusp, where OCCT reports curvature as infinite.
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
    /// let k = circle.curvature(at: 0)   // 0.2, i.e. 1/5
    /// ```
    @available(*, deprecated, renamed: "curvature(at:)")
    public func localCurvature(at u: Double) -> Double? {
        curvature(at: u)
    }

    /// The unit tangent direction at a parameter value.
    ///
    /// Equivalent to ``Curve3D/tangentDirection(at:)``.
    ///
    /// - Parameter u: Curve parameter.
    /// - Returns: The unit tangent, or `nil` where every derivative up to order 3 is null.
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
    /// if let t = circle.localTangent(at: 0) { print(t) }   // (0, 1, 0)
    /// ```
    public func localTangent(at u: Double) -> SIMD3<Double>? {
        var tx = 0.0, ty = 0.0, tz = 0.0
        var isDefined = false
        OCCTCurve3DLocalTangent(handle, u, &tx, &ty, &tz, &isDefined)
        return isDefined ? SIMD3(tx, ty, tz) : nil
    }

    /// The principal normal direction at a parameter value.
    ///
    /// Equivalent to ``Curve3D/normal(at:)``.
    ///
    /// - Parameter u: Curve parameter.
    /// - Returns: The normal, or `nil` where the curvature is zero (a straight stretch, or an
    ///   inflection) or infinite (a cusp) — a normal needs a curvature to point away from.
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
    /// let n = circle.localNormal(at: 0)                    // points at the centre
    /// let straight = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))!
    /// #expect(straight.localNormal(at: 0) == nil)          // no curvature, no normal
    /// ```
    public func localNormal(at u: Double) -> SIMD3<Double>? {
        var nx = 0.0, ny = 0.0, nz = 0.0
        var isDefined = false
        OCCTCurve3DLocalNormal(handle, u, &nx, &ny, &nz, &isDefined)
        return isDefined ? SIMD3(nx, ny, nz) : nil
    }

    /// The centre of the osculating circle at a parameter value.
    ///
    /// Equivalent to ``Curve3D/centerOfCurvature(at:)``.
    ///
    /// - Parameter u: Curve parameter.
    /// - Returns: The centre of curvature, or `nil` where the curvature cannot be inverted into a
    ///   radius: zero (straight or inflecting) or infinite (a cusp). Both cases used to return a
    ///   point built from `NaN` and infinity rather than `nil` (#494).
    ///
    /// ```swift
    /// let circle = Curve3D.circle(center: SIMD3(1, 2, 0), normal: SIMD3(0, 0, 1), radius: 5)!
    /// let c = circle.localCentreOfCurvature(at: 0)   // (1, 2, 0), the circle's own centre
    /// ```
    public func localCentreOfCurvature(at u: Double) -> SIMD3<Double>? {
        var cx = 0.0, cy = 0.0, cz = 0.0
        var isDefined = false
        OCCTCurve3DLocalCentreOfCurvature(handle, u, &cx, &cy, &cz, &isDefined)
        return isDefined ? SIMD3(cx, cy, cz) : nil
    }
}

// MARK: - Surface LProp3d Extensions (v0.117.0)

extension Surface {

    /// Surface curvature result at a point.
    public struct LocalCurvatures: Sendable {
        public let gaussian: Double
        public let mean: Double
        public let maxCurvature: Double
        public let minCurvature: Double
    }

    /// All four curvature scalars at a surface point, in one call.
    ///
    /// The same quantities ``Surface/curvatures(u:v:)``, ``Surface/gaussianCurvature(atU:v:)``,
    /// ``Surface/meanCurvature(atU:v:)`` and ``Surface/principalCurvatures(atU:v:)`` report, and
    /// now at the same tolerance — this used to ask at a 1000x tighter resolution, so it could
    /// report curvature near a degeneracy that every one of those called undefined (#494).
    ///
    /// - Parameters:
    ///   - u: Surface U parameter.
    ///   - v: Surface V parameter.
    /// - Returns: Gaussian, mean, max and min curvature, or `nil` where curvature is undefined —
    ///   a cone's apex, a sphere's pole, or any point whose surface normal is not defined.
    ///
    /// ```swift
    /// let sphere = Surface.sphere(center: .zero, radius: 10)!
    /// if let c = sphere.localCurvatures(u: 0, v: 0.5) {
    ///     print(c.gaussian)      // 1/R^2 = 0.01
    ///     print(abs(c.mean))     // 1/R   = 0.1
    /// }
    ///
    /// // A cone's apex has no defined curvature.
    /// let cone = Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 0, semiAngle: .pi / 6)!
    /// #expect(cone.localCurvatures(u: 0, v: 0) == nil)
    /// ```
    public func localCurvatures(u: Double, v: Double) -> LocalCurvatures? {
        var gaussian = 0.0, mean = 0.0, maxC = 0.0, minC = 0.0
        var isDefined = false
        OCCTSurfaceLocalCurvatures(handle, u, v, &gaussian, &mean, &maxC, &minC, &isDefined)
        return isDefined ? LocalCurvatures(gaussian: gaussian, mean: mean,
                                           maxCurvature: maxC, minCurvature: minC) : nil
    }

    /// Curvature direction result.
    public struct CurvatureDirections: Sendable {
        public let maxDirection: SIMD3<Double>
        public let minDirection: SIMD3<Double>
    }

    /// The principal curvature directions at a surface point.
    ///
    /// Shares its tolerance with ``Surface/principalCurvatures(atU:v:)``, which reports the same
    /// two directions alongside their curvatures; the two used to disagree about where curvature
    /// exists at all (#494).
    ///
    /// - Parameters:
    ///   - u: Surface U parameter.
    ///   - v: Surface V parameter.
    /// - Returns: The max- and min-curvature directions, or `nil` where curvature is undefined
    ///   **or** the point is umbilic, since equal principal curvatures single out no pair of
    ///   directions.
    ///
    /// Umbilic detection is OCCT's, and it is stricter than the geometry suggests: the two
    /// principal curvatures must land within one ULP of each other. A plane qualifies (both are
    /// exactly zero); an analytically-umbilic sphere qualifies only where the two computed values
    /// round to the same `Double`, which varies with radius and parameter. Treat a non-`nil`
    /// result on a sphere as normal, not as a bug.
    ///
    /// ```swift
    /// // A cylinder is not umbilic: one direction follows the axis, the other wraps around it.
    /// let cylinder = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5)!
    /// if let d = cylinder.localCurvatureDirections(u: 0, v: 0) {
    ///     print(d.maxDirection, d.minDirection)
    /// }
    ///
    /// // A plane is umbilic everywhere, so it has directions nowhere — but its curvature is
    /// // perfectly well defined (all four scalars are zero).
    /// let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
    /// #expect(plane.localCurvatures(u: 1, v: 2) != nil)
    /// #expect(plane.localCurvatureDirections(u: 1, v: 2) == nil)
    /// ```
    public func localCurvatureDirections(u: Double, v: Double) -> CurvatureDirections? {
        var maxDx = 0.0, maxDy = 0.0, maxDz = 0.0
        var minDx = 0.0, minDy = 0.0, minDz = 0.0
        var isDefined = false
        OCCTSurfaceLocalCurvatureDirections(handle, u, v,
                                            &maxDx, &maxDy, &maxDz,
                                            &minDx, &minDy, &minDz, &isDefined)
        return isDefined ? CurvatureDirections(maxDirection: SIMD3(maxDx, maxDy, maxDz),
                                               minDirection: SIMD3(minDx, minDy, minDz)) : nil
    }
}

// MARK: - ProjLib (v0.117.0)


// MARK: - BRepBndLib extensions (v0.118.0)

extension Shape {
    /// Axis-aligned bounding box of the shape.
    public var boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>)? {
        var xmin = 0.0, ymin = 0.0, zmin = 0.0, xmax = 0.0, ymax = 0.0, zmax = 0.0
        OCCTShapeBoundingBox(handle, &xmin, &ymin, &zmin, &xmax, &ymax, &zmax)
        if xmin == 0 && ymin == 0 && zmin == 0 && xmax == 0 && ymax == 0 && zmax == 0 {
            return nil
        }
        return (min: SIMD3(xmin, ymin, zmin), max: SIMD3(xmax, ymax, zmax))
    }

    /// Optimal (tight) axis-aligned bounding box using precise geometry.
    public func boundingBoxOptimal(useShapeTolerance: Bool = false) -> (min: SIMD3<Double>, max: SIMD3<Double>)? {
        var xmin = 0.0, ymin = 0.0, zmin = 0.0, xmax = 0.0, ymax = 0.0, zmax = 0.0
        OCCTShapeBoundingBoxOptimal(handle, useShapeTolerance, &xmin, &ymin, &zmin, &xmax, &ymax, &zmax)
        if xmin == 0 && ymin == 0 && zmin == 0 && xmax == 0 && ymax == 0 && zmax == 0 {
            return nil
        }
        return (min: SIMD3(xmin, ymin, zmin), max: SIMD3(xmax, ymax, zmax))
    }

    /// Oriented bounding box with axes and half-sizes.
    public struct DetailedOBB: Sendable {
        public let center: SIMD3<Double>
        public let xDirection: SIMD3<Double>
        public let yDirection: SIMD3<Double>
        public let zDirection: SIMD3<Double>
        public let xHalfSize: Double
        public let yHalfSize: Double
        public let zHalfSize: Double
    }

    /// Compute oriented bounding box with detailed axis information.
    public func orientedBoundingBoxDetailed(optimal: Bool = false) -> DetailedOBB? {
        var cx = 0.0, cy = 0.0, cz = 0.0
        var xDx = 0.0, xDy = 0.0, xDz = 0.0
        var yDx = 0.0, yDy = 0.0, yDz = 0.0
        var zDx = 0.0, zDy = 0.0, zDz = 0.0
        var xHS = 0.0, yHS = 0.0, zHS = 0.0
        var isVoid = false
        OCCTShapeOrientedBoundingBoxDetailed(handle, optimal,
            &cx, &cy, &cz,
            &xDx, &xDy, &xDz,
            &yDx, &yDy, &yDz,
            &zDx, &zDy, &zDz,
            &xHS, &yHS, &zHS,
            &isVoid)
        if isVoid { return nil }
        return DetailedOBB(
            center: SIMD3(cx, cy, cz),
            xDirection: SIMD3(xDx, xDy, xDz),
            yDirection: SIMD3(yDx, yDy, yDz),
            zDirection: SIMD3(zDx, zDy, zDz),
            xHalfSize: xHS, yHalfSize: yHS, zHalfSize: zHS)
    }
}

// MARK: - ShapeAnalysis_ShapeTolerance extensions (v0.118.0)

extension Shape {
    /// Tolerance mode for shape tolerance queries.
    public enum ToleranceMode: Int32, Sendable {
        case average = 0
        case maximum = 1
        case minimum = -1
    }

    /// Get the tolerance value of the shape's sub-shapes.
    /// subShapeType: 8=all(SHAPE), 7=VERTEX, 6=EDGE, 4=FACE, 3=SHELL
    public func toleranceValue(mode: ToleranceMode, subShapeType: Int32 = 8) -> Double {
        OCCTShapeToleranceValue(handle, mode.rawValue, subShapeType)
    }

    /// Count sub-shapes with tolerance over a given value.
    /// subShapeType: 8=all(SHAPE), 7=VERTEX, 6=EDGE, 4=FACE
    public func toleranceOverCount(value: Double, subShapeType: Int32 = 8) -> Int {
        Int(OCCTShapeToleranceOverCount(handle, value, subShapeType))
    }

    /// Count sub-shapes with tolerance in a given range.
    /// subShapeType: 8=all(SHAPE), 7=VERTEX, 6=EDGE, 4=FACE
    public func toleranceInRangeCount(min: Double, max: Double, subShapeType: Int32 = 8) -> Int {
        Int(OCCTShapeToleranceInRangeCount(handle, min, max, subShapeType))
    }
}

// MARK: - BRepAlgoAPI_Check extensions (v0.118.0)

extension Shape {
    /// Check shape validity for boolean operations (small edges, self-interference).
    public func isBooleanValid(testSmallEdges: Bool = true, testSelfInterference: Bool = true) -> Bool {
        OCCTShapeBooleanCheckSingle(handle, testSmallEdges, testSelfInterference)
    }

    /// Check if two shapes are valid for a boolean operation.
    /// Operation: 0=unknown, 1=common, 2=fuse, 3=cut, 4=section.
    public func isBooleanValidWith(_ other: Shape, operation: Int32 = 0,
                                    testSmallEdges: Bool = true,
                                    testSelfInterference: Bool = true) -> Bool {
        OCCTShapeBooleanCheckPair(handle, other.handle, operation, testSmallEdges, testSelfInterference)
    }
}

// MARK: - BRepAlgoAPI_Defeaturing extensions (v0.118.0)

extension Shape {
    /// Remove feature faces from a solid shape (e.g., fillets, holes).
    ///
    /// The canonical defeaturing call. `withoutFeatures(faces:)` is the same operation addressing
    /// its faces by index instead of by shape, and `defeaturedWithFullHistory(faces:)` is the same
    /// operation again with the removal history retained; all three run one shared
    /// `BRepAlgoAPI_Defeaturing` path in the bridge. `removeFeatures(faces:)` was a fourth spelling
    /// of this call, reaching the same algorithm one OCCT layer down, and is deprecated in favour
    /// of this one (#536).
    ///
    /// Returns `nil` when `faces` is empty, and when the operation itself fails — defeaturing
    /// cannot always reconnect the surrounding topology, so a `nil` here is an ordinary outcome,
    /// not necessarily a caller error.
    ///
    /// ## What may be named, and what must belong
    ///
    /// Each element of `faces` names faces rather than having to be one: a compound of faces, a
    /// shell, or this whole shape all name the faces they contain, and naming a carrier is the same
    /// request as naming the faces it holds. The rule every element must satisfy:
    ///
    /// > Every element must name at least one face, and every face it names must be a face of this
    /// > shape. Otherwise the whole call returns `nil` and nothing is removed.
    ///
    /// So a request that mixes this shape's faces with another shape's fails, as does one carrying
    /// an edge or a vertex, which name no face at all. Membership is by identity, not by geometry:
    /// the same face measured off an identically-built shape is foreign, while the same face
    /// reversed is not — orientation is not identity.
    ///
    /// Until #578 a foreign face was dropped from the request and the rest proceeded, which is
    /// OCCT's own documented rule ("those that do not belong will be ignored"). That answered a
    /// success, with no warning, on a shape still carrying the feature the caller asked to remove —
    /// indistinguishable from a real removal. The index-addressed ``Shape/withoutFeatures(faces:)``
    /// has failed the whole call on one bad index since #497; both spellings now agree.
    ///
    /// ```swift
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// let filleted = box.filleted(radius: 2.0)!
    ///
    /// // The fillet added faces beyond the box's own six; remove one of them again.
    /// let filletFaces = Array(filleted.subShapes(ofType: .face).dropFirst(6).prefix(1))
    /// if let plain = filleted.defeature(faces: filletFaces) {
    ///     print(plain.volume ?? 0)   // back to 8000.0, the unfilleted box
    /// }
    ///
    /// // A face from somewhere else fails the request rather than being ignored.
    /// let elsewhere = Shape.box(width: 11, height: 11, depth: 11)!.subShapes(ofType: .face)[0]
    /// print(filleted.defeature(faces: filletFaces + [elsewhere]) == nil)   // true
    /// ```
    ///
    /// - Parameter faces: The faces to remove — each element either a face of this shape, or a
    ///   shape whose faces all belong to this shape.
    /// - Returns: The defeatured shape, or `nil` on failure, including when the request names a
    ///   face this shape does not have.
    public func defeature(faces: [Shape]) -> Shape? {
        let faceHandles = faces.map { $0.handle as OCCTShapeRef? }
        return faceHandles.withUnsafeBufferPointer { buf -> Shape? in
            guard let baseAddress = buf.baseAddress else { return nil }
            // Need to cast from UnsafePointer<OCCTShapeRef?> to UnsafePointer<OCCTShapeRef>
            let ptr = UnsafeRawPointer(baseAddress).assumingMemoryBound(to: OCCTShapeRef.self)
            guard let result = OCCTShapeDefeature(handle, ptr, Int32(faces.count)) else { return nil }
            return Shape(handle: result)
        }
    }
}

// MARK: - Convert_CompPolynomialToPoles (v0.118.0)


// MARK: - gp_Trsf extras (v0.118.0)

extension Shape {
    /// Transform shape using a 3x4 matrix (row-major: [a11..a14, a21..a24, a31..a34]).
    public func transformed(byMatrix matrix: [Double]) -> Shape? {
        guard matrix.count == 12 else { return nil }
        var result: OCCTShapeRef?
        OCCTShapeTransformFromMatrix(handle,
            matrix[0], matrix[1], matrix[2], matrix[3],
            matrix[4], matrix[5], matrix[6], matrix[7],
            matrix[8], matrix[9], matrix[10], matrix[11],
            &result)
        guard let r = result else { return nil }
        return Shape(handle: r)
    }

    /// Check if the shape's location transform has negative determinant (mirror/reflection).
    public var isTransformNegative: Bool {
        OCCTShapeTransformIsNegative(handle)
    }
}


// MARK: - TopExp extras (v0.118.0)

extension Shape {
    /// Find the common vertex between two edges.
    public static func commonVertex(edge1: Shape, edge2: Shape) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        if OCCTEdgesCommonVertex(edge1.handle, edge2.handle, &x, &y, &z) {
            return SIMD3(x, y, z)
        }
        return nil
    }
}

// MARK: - BRep_Tool extras (v0.118.0)

extension Shape {
    /// Check if edge has SameParameter flag (3D curve matches pcurves parametrically).
    public var edgeSameParameter: Bool {
        OCCTEdgeSameParameter(handle)
    }

    /// Check if edge has SameRange flag (all representations share the same range).
    public var edgeSameRange: Bool {
        OCCTEdgeSameRange(handle)
    }

    /// Check if face has NaturalRestriction (bounded by its own parametric bounds).
    public var faceNaturalRestriction: Bool {
        OCCTFaceNaturalRestriction(handle)
    }

    /// Check if edge has geometric representation (3D curve or curve on surface).
    public var edgeIsGeometric: Bool {
        OCCTEdgeIsGeometric(handle)
    }

    /// Check if face has geometric representation (underlying surface).
    public var faceIsGeometric: Bool {
        OCCTFaceIsGeometric(handle)
    }
}

// MARK: - Sewing extras (v0.118.0)


// MARK: - BREP serialization, gp distance/contains, BezierSurface, Curve2D extras, BSplineSurface extras (v0.119.0)

// --- BREP string serialization ---

extension Shape {
    /// Serialize this shape to a BREP format string.
    public func toBREPString() -> String? {
        guard let cstr = OCCTShapeToBREPString(handle) else { return nil }
        let result = String(cString: cstr)
        free(cstr)
        return result
    }

    /// Deserialize a shape from a BREP format string.
    public static func fromBREPString(_ brep: String) -> Shape? {
        guard let ref = OCCTShapeFromBREPString(brep) else { return nil }
        return Shape(handle: ref)
    }
}

// --- gp_Pln distance/contains ---


// --- gp_Lin distance/contains ---


// --- Geom_BezierSurface ---

extension Surface {
    /// Bezier surface properties (meaningful only when the underlying surface is Geom_BezierSurface).
    public struct BezierProperties: @unchecked Sendable {
        fileprivate let handle: OCCTSurfaceRef

        /// Number of U poles.
        public var nbUPoles: Int { Int(OCCTSurfaceBezierNbUPoles(handle)) }

        /// Number of V poles.
        public var nbVPoles: Int { Int(OCCTSurfaceBezierNbVPoles(handle)) }

        /// U degree.
        public var uDegree: Int { Int(OCCTSurfaceBezierUDegree(handle)) }

        /// V degree.
        public var vDegree: Int { Int(OCCTSurfaceBezierVDegree(handle)) }

        /// Whether the surface is rational in U.
        public var isURational: Bool { OCCTSurfaceBezierIsURational(handle) }

        /// Whether the surface is rational in V.
        public var isVRational: Bool { OCCTSurfaceBezierIsVRational(handle) }

        /// Get a pole (1-based indices).
        public func pole(uIndex: Int, vIndex: Int) -> SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTSurfaceBezierGetPole(handle, Int32(uIndex), Int32(vIndex), &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// Set a pole (1-based indices).
        @discardableResult
        public func setPole(uIndex: Int, vIndex: Int, point: SIMD3<Double>) -> Bool {
            OCCTSurfaceBezierSetPole(handle, Int32(uIndex), Int32(vIndex), point.x, point.y, point.z)
        }

        /// Set a weight (1-based indices).
        @discardableResult
        public func setWeight(uIndex: Int, vIndex: Int, weight: Double) -> Bool {
            OCCTSurfaceBezierSetWeight(handle, Int32(uIndex), Int32(vIndex), weight)
        }

        /// Extract a segment of the Bezier surface.
        @discardableResult
        public func segment(u1: Double, u2: Double, v1: Double, v2: Double) -> Bool {
            OCCTSurfaceBezierSegment(handle, u1, u2, v1, v2)
        }

        /// Exchange U and V parametric directions.
        @discardableResult
        public func exchangeUV() -> Bool {
            OCCTSurfaceBezierExchangeUV(handle)
        }
    }

    /// Bezier-surface-specific properties.
    public var bezierProperties: BezierProperties { BezierProperties(handle: handle) }

    // --- BSplineSurface extras ---

    /// Compute U and V parameter resolution for a given 3D tolerance (BSpline surface).
    public func bsplineResolution(tolerance3d: Double) -> (uResolution: Double, vResolution: Double) {
        var ur = 0.0, vr = 0.0
        OCCTSurfaceBSplineResolution(handle, tolerance3d, &ur, &vr)
        return (ur, vr)
    }

    /// Set U periodicity on a BSpline surface.
    @discardableResult
    public func bsplineSetUPeriodic(_ periodic: Bool) -> Bool {
        OCCTSurfaceBSplineSetUPeriodic(handle, periodic)
    }

    /// Set V periodicity on a BSpline surface.
    @discardableResult
    public func bsplineSetVPeriodic(_ periodic: Bool) -> Bool {
        OCCTSurfaceBSplineSetVPeriodic(handle, periodic)
    }

    /// Get a weight from a BSpline surface (1-based indices).
    public func bsplineWeight(uIndex: Int, vIndex: Int) -> Double {
        OCCTSurfaceBSplineGetWeight(handle, Int32(uIndex), Int32(vIndex))
    }
}

// --- Curve2D Bezier ---

extension Curve2D {
    /// 2D Bezier curve properties (meaningful only when the underlying curve is Geom2d_BezierCurve).
    public struct BezierProperties: @unchecked Sendable {
        fileprivate let handle: OCCTCurve2DRef

        /// Degree of the Bezier curve.
        public var degree: Int { Int(OCCTCurve2DBezierDegree(handle)) }

        /// Number of poles.
        public var poleCount: Int { Int(OCCTCurve2DBezierPoleCount(handle)) }

        /// Whether the Bezier curve is rational.
        public var isRational: Bool { OCCTCurve2DBezierIsRational(handle) }

        /// Get a pole (1-based index).
        public func pole(at index: Int) -> SIMD2<Double> {
            var x = 0.0, y = 0.0
            OCCTCurve2DBezierGetPole(handle, Int32(index), &x, &y)
            return SIMD2(x, y)
        }

        /// Set a pole (1-based index).
        @discardableResult
        public func setPole(at index: Int, point: SIMD2<Double>) -> Bool {
            OCCTCurve2DBezierSetPole(handle, Int32(index), point.x, point.y)
        }

        /// Set a weight (1-based index).
        @discardableResult
        public func setWeight(at index: Int, weight: Double) -> Bool {
            OCCTCurve2DBezierSetWeight(handle, Int32(index), weight)
        }

        /// Compute parameter resolution from 2D tolerance.
        public func resolution(tolerance: Double) -> Double {
            OCCTCurve2DBezierResolution(handle, tolerance)
        }
    }

    /// 2D Bezier curve-specific properties.
    public var bezierProperties: BezierProperties { BezierProperties(handle: handle) }

    // --- Curve2D BSpline extras ---

    /// Set periodic/non-periodic on a 2D BSpline curve.
    @discardableResult
    public func bsplineSetPeriodic(_ periodic: Bool) -> Bool {
        OCCTCurve2DBSplineSetPeriodic(handle, periodic)
    }

    /// Get weight at index (1-based) from a 2D BSpline curve.
    public func bsplineWeight(at index: Int) -> Double {
        OCCTCurve2DBSplineGetWeight(handle, Int32(index))
    }

    /// Get all weights from a 2D BSpline curve.
    public func bsplineWeights() -> [Double] {
        let count = Int(OCCTCurve2DBSplinePoleCount(handle))
        guard count > 0 else { return [] }
        var weights = [Double](repeating: 0, count: count)
        weights.withUnsafeMutableBufferPointer { buf in
            OCCTCurve2DBSplineGetWeights(handle, buf.baseAddress!)
        }
        return weights
    }
}

// MARK: - Final cleanup — IsCN, ReversedParameter, ParametricTransformation, (v0.120.0)
//                    gp extras, surface reversed copies, BSpline/Bezier MaxDegree/Resolution

// --- Curve3D continuity and parameter extras ---

extension Curve3D {

    /// Unavailable: this `Int` reported a hand-invented encoding, and the numbers changed
    /// underneath it. Use ``continuityClass`` (named cases) or ``continuity`` (raw ordinal).
    ///
    /// Until #485 this property answered `C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3` — a
    /// scheme of OCCTSwift's own invention that matched neither `GeomAbs_Shape` nor its own doc
    /// comment, and disagreed with ``continuity`` on the same curve for every class except C0.
    /// #485 replaced it with the real `GeomAbs_Shape` ordinal (`C0=0, G1=1, C1=2, G2=3, C2=4,
    /// C3=5, CN=6`).
    ///
    /// Every existing threshold check kept compiling across that change and quietly changed
    /// meaning, which is why the spelling is retired rather than reinterpreted (#619):
    ///
    /// ```swift
    /// // Before: `2` was C2. After: `2` is C1, so a merely tangent-continuous curve passed.
    /// if curve.continuityOrder >= 2 { useAsC2Spline() }
    ///
    /// // The question that idiom meant to ask, asked so it cannot drift again:
    /// if curve.continuityClass.satisfies(.c2) { useAsC2Spline() }
    ///
    /// // And the old `== 99` fast path for analytic geometry, which can never fire again:
    /// if curve.continuityClass == .cN { useAnalyticFastPath() }
    /// ```
    ///
    /// ``continuity`` is the same `Int` under an honest name if a raw ordinal is genuinely what
    /// you want — but it is the *new* ordinal, so re-check any constant compared against it.
    ///
    /// - Important: The retired encoding had an eighth value the tables above do not show. It
    ///   signalled failure out of band, returning `-1` from its `default:` branch and for a null
    ///   or unreadable handle. ``continuity`` has no such sentinel: it returns `0` in the same
    ///   situations, and `0` is an ordinary C0 measurement. A migrated
    ///   `if continuityOrder < 0 { handleError() }` becomes a branch that can never be taken, and
    ///   an unreadable curve now reads as a genuinely C0 one. There is no in-band way to tell the
    ///   two apart; check the handle before asking.
    @available(*, unavailable, message: """
        continuityOrder reported a hand-invented encoding (C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, \
        G2=-3) and #485 changed it to the real GeomAbs_Shape ordinal (C0=0, G1=1, C1=2, G2=3, \
        C2=4, C3=5, CN=6), so every threshold check silently changed meaning. Use \
        continuityClass.satisfies(_:) for a continuity floor, continuityClass == .cN for the \
        analytic fast path, or continuity for the raw ordinal — after re-checking the constant \
        you compare against. Note there is no longer an error sentinel: this returned -1 for a \
        null or unreadable handle, whereas continuity returns 0, which is an ordinary C0, so a \
        migrated `< 0` error check can never fire (#619).
        """)
    public var continuityOrder: Int { Int(OCCTCurve3DGetContinuity(handle)) }

    /// Check if this curve has at least Cn continuity.
    public func isCN(_ n: Int) -> Bool {
        OCCTCurve3DIsCN(handle, Int32(n))
    }

    /// Get the parameter on the reversed curve corresponding to parameter u on this curve.
    public func reversedParameter(_ u: Double) -> Double {
        OCCTCurve3DReversedParameter(handle, u)
    }

    /// Get the parametric transformation scale factor under a geometric transform.
    /// The transform is specified as a 3x3 rotation matrix (row-major) + 3 translation values.
    public func parametricTransformation(rotation: [Double], translation: SIMD3<Double>) -> Double {
        guard rotation.count == 9 else { return 1.0 }
        let trsf12 = rotation + [translation.x, translation.y, translation.z]
        return trsf12.withUnsafeBufferPointer { buf in
            OCCTCurve3DParametricTransformation(handle, buf.baseAddress!)
        }
    }

    /// Resolution for 3D Bezier curves.
    public func bezierResolution(tolerance3d: Double) -> Double {
        OCCTCurve3DBezierResolution(handle, tolerance3d)
    }

    /// Maximum degree for 3D Bezier curves (static).
    public static var bezierMaxDegree: Int { Int(OCCTCurve3DBezierMaxDegree()) }

}

// --- Curve2D continuity and parameter extras ---

extension Curve2D {

    /// Unavailable: this `Int` reported a hand-invented encoding, and the numbers changed
    /// underneath it. Use ``continuityClass`` (named cases) or ``continuity`` (raw ordinal).
    ///
    /// Same retirement, same reasons, as ``Curve3D/continuityOrder``: the pre-#485 encoding was
    /// `C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3` and the value is now the real
    /// `GeomAbs_Shape` ordinal (`C0=0, G1=1, C1=2, G2=3, C2=4, C3=5, CN=6`), so every threshold
    /// check kept compiling and quietly changed meaning (#619).
    ///
    /// ```swift
    /// // Before: `2` was C2. After: `2` is C1.
    /// if pcurve.continuityOrder >= 2 { treatAsC2() }
    ///
    /// // Ask it so it cannot drift again:
    /// if pcurve.continuityClass.satisfies(.c2) { treatAsC2() }
    /// ```
    @available(*, unavailable, message: """
        continuityOrder reported a hand-invented encoding (C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, \
        G2=-3) and #485 changed it to the real GeomAbs_Shape ordinal (C0=0, G1=1, C1=2, G2=3, \
        C2=4, C3=5, CN=6), so every threshold check silently changed meaning. Use \
        continuityClass.satisfies(_:) for a continuity floor, continuityClass == .cN for the \
        analytic fast path, or continuity for the raw ordinal — after re-checking the constant \
        you compare against. Note there is no longer an error sentinel: this returned -1 for a \
        null or unreadable handle, whereas continuity returns 0, which is an ordinary C0, so a \
        migrated `< 0` error check can never fire (#619).
        """)
    public var continuityOrder: Int { Int(OCCTCurve2DGetContinuity(handle)) }

    /// Check if this curve has at least Cn continuity.
    public func isCN(_ n: Int) -> Bool {
        OCCTCurve2DIsCN(handle, Int32(n))
    }

    /// Get the parameter on the reversed curve corresponding to parameter u on this curve.
    public func reversedParameter(_ u: Double) -> Double {
        OCCTCurve2DReversedParameter(handle, u)
    }

    /// Maximum degree for 2D Bezier curves (static).
    public static var bezierMaxDegree: Int { Int(OCCTCurve2DBezierMaxDegree()) }

    /// Maximum degree for 2D BSpline curves (static).
    public static var bsplineMaxDegree: Int { Int(OCCTCurve2DBSplineMaxDegree()) }
}

// --- Surface continuity, reversed copies, parameter extras ---

extension Surface {

    /// Check if this surface has at least Cn continuity in the U direction.
    public func isCNu(_ n: Int) -> Bool {
        OCCTSurfaceIsCNu(handle, Int32(n))
    }

    /// Check if this surface has at least Cn continuity in the V direction.
    public func isCNv(_ n: Int) -> Bool {
        OCCTSurfaceIsCNv(handle, Int32(n))
    }

    /// Create a U-reversed copy of this surface.
    public func uReversed() -> Surface? {
        guard let ref = OCCTSurfaceUReversed(handle) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a V-reversed copy of this surface.
    public func vReversed() -> Surface? {
        guard let ref = OCCTSurfaceVReversed(handle) else { return nil }
        return Surface(handle: ref)
    }

    /// Get the reversed U parameter value.
    public func uReversedParameter(_ u: Double) -> Double {
        OCCTSurfaceUReversedParameter(handle, u)
    }

    /// Get the reversed V parameter value.
    public func vReversedParameter(_ v: Double) -> Double {
        OCCTSurfaceVReversedParameter(handle, v)
    }

    /// Remove a V knot from a BSpline surface. Returns true if successful.
    @discardableResult
    public func bsplineRemoveVKnot(index: Int, mult: Int, tolerance: Double) -> Bool {
        OCCTSurfaceBSplineRemoveVKnot(handle, Int32(index), Int32(mult), tolerance)
    }

    /// Resolution for Bezier surfaces (U and V).
    public func bezierResolution(tolerance3d: Double) -> (u: Double, v: Double) {
        var ur = 0.0, vr = 0.0
        OCCTSurfaceBezierResolution(handle, tolerance3d, &ur, &vr)
        return (ur, vr)
    }

    /// Maximum degree for Bezier surfaces (static).
    public static var bezierMaxDegree: Int { Int(OCCTSurfaceBezierMaxDegree()) }

    /// Maximum degree for BSpline surfaces (static).
    public static var bsplineMaxDegree: Int { Int(OCCTSurfaceBSplineMaxDegree()) }
}

// --- gp_Vec extras ---

extension Shape {

    /// Compute the magnitude of the cross product of two vectors.
    public static func vecCrossMagnitude(_ v1: SIMD3<Double>, _ v2: SIMD3<Double>) -> Double {
        OCCTVecCrossMagnitude(v1.x, v1.y, v1.z, v2.x, v2.y, v2.z)
    }

    /// Compute the square magnitude of the cross product of two vectors.
    public static func vecCrossSquareMagnitude(_ v1: SIMD3<Double>, _ v2: SIMD3<Double>) -> Double {
        OCCTVecCrossSquareMagnitude(v1.x, v1.y, v1.z, v2.x, v2.y, v2.z)
    }

    /// Check if two directions are opposite within angular tolerance (radians).
    public static func dirIsOpposite(_ d1: SIMD3<Double>, _ d2: SIMD3<Double>,
                                     tolerance: Double = 1e-10) -> Bool {
        OCCTDirIsOpposite(d1.x, d1.y, d1.z, d2.x, d2.y, d2.z, tolerance)
    }

    /// Check if two directions are normal (perpendicular) within angular tolerance (radians).
    public static func dirIsNormal(_ d1: SIMD3<Double>, _ d2: SIMD3<Double>,
                                   tolerance: Double = 1e-10) -> Bool {
        OCCTDirIsNormal(d1.x, d1.y, d1.z, d2.x, d2.y, d2.z, tolerance)
    }
}

// =============================================================================
// MARK: - BSpline completions, FilletBuilder, ChamferBuilder (v0.121.0)
// =============================================================================

// --- BSplineSurface completions ---

extension Surface {

    /// Remove U periodicity from BSpline surface.
    @discardableResult
    public func bsplineSetUNotPeriodic() -> Bool {
        OCCTSurfaceBSplineSetUNotPeriodic(handle)
    }

    /// Remove V periodicity from BSpline surface.
    @discardableResult
    public func bsplineSetVNotPeriodic() -> Bool {
        OCCTSurfaceBSplineSetVNotPeriodic(handle)
    }

    /// Set origin knot index in U direction (1-based).
    @discardableResult
    public func bsplineSetUOrigin(index: Int) -> Bool {
        OCCTSurfaceBSplineSetUOrigin(handle, Int32(index))
    }

    /// Set origin knot index in V direction (1-based).
    @discardableResult
    public func bsplineSetVOrigin(index: Int) -> Bool {
        OCCTSurfaceBSplineSetVOrigin(handle, Int32(index))
    }

    /// Increase U multiplicity at knot index to at least mult (1-based).
    @discardableResult
    public func bsplineIncreaseUMultiplicity(index: Int, multiplicity: Int) -> Bool {
        OCCTSurfaceBSplineIncreaseUMultiplicity(handle, Int32(index), Int32(multiplicity))
    }

    /// Increase V multiplicity at knot index to at least mult (1-based).
    @discardableResult
    public func bsplineIncreaseVMultiplicity(index: Int, multiplicity: Int) -> Bool {
        OCCTSurfaceBSplineIncreaseVMultiplicity(handle, Int32(index), Int32(multiplicity))
    }

    /// Batch insert U knots with multiplicities.
    @discardableResult
    public func bsplineInsertUKnots(_ knots: [Double], multiplicities: [Int], tolerance: Double = 1e-10) -> Bool {
        let count = min(knots.count, multiplicities.count)
        guard count > 0 else { return false }
        let mults = multiplicities.map { Int32($0) }
        return OCCTSurfaceBSplineInsertUKnots(handle, knots, mults, Int32(count), tolerance)
    }

    /// Batch insert V knots with multiplicities.
    @discardableResult
    public func bsplineInsertVKnots(_ knots: [Double], multiplicities: [Int], tolerance: Double = 1e-10) -> Bool {
        let count = min(knots.count, multiplicities.count)
        guard count > 0 else { return false }
        let mults = multiplicities.map { Int32($0) }
        return OCCTSurfaceBSplineInsertVKnots(handle, knots, mults, Int32(count), tolerance)
    }

    /// Move BSpline surface to pass through point at (u,v), adjusting poles in range.
    @discardableResult
    public func bsplineMovePoint(u: Double, v: Double, to point: SIMD3<Double>,
                                 uPoleRange: ClosedRange<Int>, vPoleRange: ClosedRange<Int>) -> Bool {
        OCCTSurfaceBSplineMovePoint(handle, u, v, point.x, point.y, point.z,
                                     Int32(uPoleRange.lowerBound), Int32(uPoleRange.upperBound),
                                     Int32(vPoleRange.lowerBound), Int32(vPoleRange.upperBound))
    }

    /// Set an entire column of poles (all U poles at vIndex, 1-based). coords is [x,y,z,...] with count = NbUPoles.
    @discardableResult
    public func bsplineSetPoleCol(vIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let coords = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBSplineSetPoleCol(handle, Int32(vIndex), coords, Int32(poles.count))
    }

    /// Set an entire row of poles (all V poles at uIndex, 1-based). coords is [x,y,z,...] with count = NbVPoles.
    @discardableResult
    public func bsplineSetPoleRow(uIndex: Int, poles: [SIMD3<Double>]) -> Bool {
        let coords = poles.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTSurfaceBSplineSetPoleRow(handle, Int32(uIndex), coords, Int32(poles.count))
    }

    // --- v0.129.0 BSplineSurface completions ---

    /// Set a column of weights on BSpline surface. vIndex is 1-based, count = NbUPoles.
    @discardableResult
    public func bsplineSetWeightCol(vIndex: Int, weights: [Double]) -> Bool {
        OCCTSurfaceBSplineSetWeightCol(handle, Int32(vIndex), weights, Int32(weights.count))
    }

    /// Set a row of weights on BSpline surface. uIndex is 1-based, count = NbVPoles.
    @discardableResult
    public func bsplineSetWeightRow(uIndex: Int, weights: [Double]) -> Bool {
        OCCTSurfaceBSplineSetWeightRow(handle, Int32(uIndex), weights, Int32(weights.count))
    }

    /// Increment U knot multiplicities in range [fromIndex, toIndex] by step.
    @discardableResult
    public func bsplineIncrementUMultiplicity(fromIndex: Int, toIndex: Int, step: Int) -> Bool {
        OCCTSurfaceBSplineIncrementUMultiplicity(handle, Int32(fromIndex), Int32(toIndex), Int32(step))
    }

    /// Increment V knot multiplicities in range [fromIndex, toIndex] by step.
    @discardableResult
    public func bsplineIncrementVMultiplicity(fromIndex: Int, toIndex: Int, step: Int) -> Bool {
        OCCTSurfaceBSplineIncrementVMultiplicity(handle, Int32(fromIndex), Int32(toIndex), Int32(step))
    }

    /// First U knot index of BSpline surface.
    public var bsplineFirstUKnotIndex: Int { Int(OCCTSurfaceBSplineFirstUKnotIndex(handle)) }

    /// Last U knot index of BSpline surface.
    public var bsplineLastUKnotIndex: Int { Int(OCCTSurfaceBSplineLastUKnotIndex(handle)) }

    /// First V knot index of BSpline surface.
    public var bsplineFirstVKnotIndex: Int { Int(OCCTSurfaceBSplineFirstVKnotIndex(handle)) }

    /// Last V knot index of BSpline surface.
    public var bsplineLastVKnotIndex: Int { Int(OCCTSurfaceBSplineLastVKnotIndex(handle)) }

    /// Validate parameter ranges and segment the BSpline surface.
    @discardableResult
    public func bsplineCheckAndSegment(u1: Double, u2: Double, v1: Double, v2: Double,
                                        uTolerance: Double = 1e-10, vTolerance: Double = 1e-10) -> Bool {
        OCCTSurfaceBSplineCheckAndSegment(handle, u1, u2, v1, v2, uTolerance, vTolerance)
    }
}

// --- BSplineCurve 3D completions ---

extension Curve3D {

    /// Remove periodicity from BSpline curve.
    @discardableResult
    public func bsplineSetNotPeriodic() -> Bool {
        OCCTCurve3DBSplineSetNotPeriodic(handle)
    }

    /// Set origin knot index (1-based) on periodic BSpline curve.
    @discardableResult
    public func bsplineSetOrigin(index: Int) -> Bool {
        OCCTCurve3DBSplineSetOrigin(handle, Int32(index))
    }

    /// Increase multiplicity of knot at index to at least mult (1-based).
    @discardableResult
    public func bsplineIncreaseMultiplicity(index: Int, multiplicity: Int) -> Bool {
        OCCTCurve3DBSplineIncreaseMultiplicity(handle, Int32(index), Int32(multiplicity))
    }

    /// Increment multiplicity of all knots from index1 to index2 by step (1-based).
    @discardableResult
    public func bsplineIncrementMultiplicity(from: Int, to: Int, step: Int = 1) -> Bool {
        OCCTCurve3DBSplineIncrementMultiplicity(handle, Int32(from), Int32(to), Int32(step))
    }

    /// Set all knot values at once (count must match NbKnots).
    @discardableResult
    public func bsplineSetKnots(_ knots: [Double]) -> Bool {
        OCCTCurve3DBSplineSetKnots(handle, knots, Int32(knots.count))
    }

    /// Reverse parameterization of BSpline curve.
    @discardableResult
    public func bsplineReverse() -> Bool {
        OCCTCurve3DBSplineReverse(handle)
    }

    /// Move point and tangent at parameter u on BSpline curve.
    @discardableResult
    public func bsplineMovePointAndTangent(u: Double, point: SIMD3<Double>, tangent: SIMD3<Double>,
                                           tolerance: Double, poleRange: ClosedRange<Int>) -> Bool {
        OCCTCurve3DBSplineMovePointAndTangent(handle, u, point.x, point.y, point.z,
                                               tangent.x, tangent.y, tangent.z,
                                               tolerance,
                                               Int32(poleRange.lowerBound), Int32(poleRange.upperBound))
    }
}

// --- BSplineCurve 2D completions ---

extension Curve2D {

    /// Remove periodicity from 2D BSpline curve.
    @discardableResult
    public func bsplineSetNotPeriodic() -> Bool {
        OCCTCurve2DBSplineSetNotPeriodic(handle)
    }

    /// Set origin knot index (1-based) on periodic 2D BSpline curve.
    @discardableResult
    public func bsplineSetOrigin(index: Int) -> Bool {
        OCCTCurve2DBSplineSetOrigin(handle, Int32(index))
    }

    /// Increase multiplicity of knot at index to at least mult (1-based).
    @discardableResult
    public func bsplineIncreaseMultiplicity(index: Int, multiplicity: Int) -> Bool {
        OCCTCurve2DBSplineIncreaseMultiplicity(handle, Int32(index), Int32(multiplicity))
    }

    /// Increment multiplicity of all knots from index1 to index2 by step (1-based).
    @discardableResult
    public func bsplineIncrementMultiplicity(from: Int, to: Int, step: Int = 1) -> Bool {
        OCCTCurve2DBSplineIncrementMultiplicity(handle, Int32(from), Int32(to), Int32(step))
    }

    /// Set all knot values at once (count must match NbKnots).
    @discardableResult
    public func bsplineSetKnots(_ knots: [Double]) -> Bool {
        OCCTCurve2DBSplineSetKnots(handle, knots, Int32(knots.count))
    }

    /// Reverse parameterization of 2D BSpline curve.
    @discardableResult
    public func bsplineReverse() -> Bool {
        OCCTCurve2DBSplineReverse(handle)
    }

    /// Move point and tangent at parameter u on 2D BSpline curve.
    @discardableResult
    public func bsplineMovePointAndTangent(u: Double, point: SIMD2<Double>, tangent: SIMD2<Double>,
                                           tolerance: Double, poleRange: ClosedRange<Int>) -> Bool {
        OCCTCurve2DBSplineMovePointAndTangent(handle, u, point.x, point.y,
                                               tangent.x, tangent.y,
                                               tolerance,
                                               Int32(poleRange.lowerBound), Int32(poleRange.upperBound))
    }
}

// --- FilletBuilder ---


// --- ChamferBuilder ---


// MARK: - ChamferBuilder completions, FilletBuilder completions, WireAnalyzer (v0.124.0)

// --- ChamferBuilder completions ---


// --- FilletBuilder completions ---


// --- WireAnalyzer (ShapeAnalysis_Wire) ---


// MARK: - GLTF Import/Export (v0.121.0)

extension Shape {
    /// Load a shape from a GLTF or GLB file.
    public static func loadGLTF(fromPath path: String) -> Shape? {
        guard let ref = OCCTImportGLTF(path) else { return nil }
        return Shape(handle: ref)
    }

    /// Load a shape from a GLTF or GLB file URL.
    public static func loadGLTF(from url: URL) -> Shape? {
        loadGLTF(fromPath: url.path)
    }
}

extension Exporter {
    /// Export a shape to GLTF or GLB format.
    /// - Parameters:
    ///   - shape: Shape to export (will be meshed internally).
    ///   - url: Output file URL (.gltf or .glb).
    ///   - binary: If true, writes binary GLB. If false, writes text GLTF.
    ///   - deflection: Mesh deflection tolerance.
    public static func writeGLTF(shape: Shape, to url: URL, binary: Bool = true, deflection: Double = 0.1) throws {
        let ok = OCCTExportGLTF(shape.handle, url.path, binary, deflection)
        if !ok { throw Exporter.ExportError.exportFailed("GLTF export to \(url.lastPathComponent) failed") }
    }
}

extension Document {
    /// Load a GLTF/GLB file into an XDE document (preserves names, materials, colors).
    public static func loadGLTF(fromPath path: String) -> Document? {
        guard let ref = OCCTDocumentLoadGLTF(path) else { return nil }
        return Document(handle: ref)
    }

    /// Load a GLTF/GLB file into an XDE document.
    public static func loadGLTF(from url: URL) -> Document? {
        loadGLTF(fromPath: url.path)
    }

    /// Write this XDE document to GLTF/GLB format.
    /// - Parameters:
    ///   - url: Output file URL (.gltf or .glb).
    ///   - binary: If true, writes binary GLB. If false, writes text GLTF.
    public func writeGLTF(to url: URL, binary: Bool = true) -> Bool {
        OCCTDocumentWriteGLTF(handle, url.path, binary)
    }
}

// MARK: - WireFixer extended, ShapeFix_Edge, BRepTools/BRepLib statics, History extended, Sewing extended (v0.122.0)

// --- WireFixer extended ---


// --- ShapeFix_Edge extended ---

extension Shape {
    /// Add missing 3D curve to an edge. Returns true if fixed.
    public static func fixEdgeAddCurve3d(_ edge: Shape) -> Bool {
        OCCTShapeFixEdgeAddCurve3d(edge.handle)
    }

    /// Add missing PCurve to an edge on a face.
    public static func fixEdgeAddPCurve(_ edge: Shape, face: Shape, isSeam: Bool = false) -> Bool {
        OCCTShapeFixEdgeAddPCurve(edge.handle, face.handle, isSeam)
    }

    /// Remove 3D curve from an edge.
    public static func fixEdgeRemoveCurve3d(_ edge: Shape) -> Bool {
        OCCTShapeFixEdgeRemoveCurve3d(edge.handle)
    }

    /// Remove PCurve from an edge on a face.
    public static func fixEdgeRemovePCurve(_ edge: Shape, face: Shape) -> Bool {
        OCCTShapeFixEdgeRemovePCurve(edge.handle, face.handle)
    }

    /// Fix reversed 2D curve on an edge/face pair.
    public static func fixEdgeReversed2d(_ edge: Shape, face: Shape) -> Bool {
        OCCTShapeFixEdgeFixReversed2d(edge.handle, face.handle)
    }
}

// --- BRepTools statics ---

extension Shape {
    /// Remove triangulation from this shape (BRepTools::Clean).
    public func cleanTriangulation() {
        OCCTBRepToolsCleanTriangulation(handle)
    }

    /// Remove internal edges/vertices from this shape (BRepTools::RemoveInternals).
    public func removeInternals() {
        OCCTBRepToolsRemoveInternals(handle)
    }

    /// Detect if this face is closed in U and/or V.
    /// Returns (isClosedU, isClosedV).
    public func detectClosedness() -> (isClosedU: Bool, isClosedV: Bool) {
        var u = false, v = false
        OCCTBRepToolsDetectClosedness(handle, &u, &v)
        return (u, v)
    }

    /// Evaluate and update tolerance of an edge on a face. Returns the new tolerance.
    public static func evalAndUpdateTolerance(edge: Shape, face: Shape) -> Double {
        OCCTBRepToolsEvalAndUpdateTol(edge.handle, face.handle)
    }

    /// Count 3D edges in this shape.
    public var map3DEdgeCount: Int {
        Int(OCCTBRepToolsMap3DEdgeCount(handle))
    }

    /// Update face UV points.
    public func updateFaceUVPoints() {
        OCCTBRepToolsUpdateFaceUVPoints(handle)
    }

    /// Compare two vertices for geometric equality.
    public static func compareVertices(_ v1: Shape, _ v2: Shape) -> Bool {
        OCCTBRepToolsCompareVertices(v1.handle, v2.handle)
    }

    /// Compare two edges for geometric equality.
    public static func compareEdges(_ e1: Shape, _ e2: Shape) -> Bool {
        OCCTBRepToolsCompareEdges(e1.handle, e2.handle)
    }

    /// Check if an edge is really closed on a face.
    public static func isReallyClosed(edge: Shape, face: Shape) -> Bool {
        OCCTBRepToolsIsReallyClosed(edge.handle, face.handle)
    }

    /// Update a shape topology (BRepTools::Update).
    public func updateTopology() {
        OCCTBRepToolsUpdate(handle)
    }
}

// --- BRepLib extended statics ---

extension Shape {
    /// Ensure normal consistency of triangulated shape. Returns true if normals were fixed.
    @discardableResult
    public func ensureNormalConsistency(maxAngle: Double = 0.001) -> Bool {
        OCCTBRepLibEnsureNormalConsistency(handle, maxAngle)
    }

    /// Update deflection information of this shape.
    public func updateDeflection() {
        OCCTBRepLibUpdateDeflection(handle)
    }

    /// The continuity of the surface across an edge between two faces.
    ///
    /// A sharp join reports ``ContinuityClass/c0``, a fillet's tangent join
    /// ``ContinuityClass/g1``, and a seam edge on an elementary surface (a cylinder's or
    /// sphere's) ``ContinuityClass/cN`` — `BRepLib::ContinuityOfFaces` short-circuits to CN for
    /// those, and promotes any elementary pair that measures C2 to CN as well. ``ContinuityClass/c3``
    /// is the one class it never returns.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let faces = box.faces(), edges = box.edges()
    /// Shape.continuityClassOfFaces(edge: edges[0], face1: faces[0], face2: faces[1])  // .c0
    /// ```
    ///
    /// - Returns: The measured class, or nil if the arguments are not an edge and two faces that
    ///   share it (OCCT throwing, or a null handle).
    public static func continuityClassOfFaces(edge: Shape, face1: Shape, face2: Shape,
                                              tolerance: Double = 1e-6) -> ContinuityClass? {
        ContinuityClass(rawValue:
            OCCTBRepLibContinuityOfFaces(edge.handle, face1.handle, face2.handle, tolerance))
    }

    /// The continuity across an edge, as a raw `GeomAbs_Shape` ordinal (-1 on failure).
    ///
    /// This spelling's doc comment claimed `5=CN` for years. It is wrong twice over: CN is
    /// ordinal 6, and 5 (C3) is a value `BRepLib::ContinuityOfFaces` cannot return at all. The
    /// function itself was always right — it casts the enum straight through — so a caller who
    /// matched `5` for "smooth" never matched anything, and one who received `6` had no
    /// documented meaning for it. ``continuityClassOfFaces(edge:face1:face2:tolerance:)`` returns
    /// the same measurement as a ``ContinuityClass``, where the ordinals cannot be misread. #495.
    @available(*, deprecated, renamed: "continuityClassOfFaces(edge:face1:face2:tolerance:)")
    public static func continuityOfFaces(edge: Shape, face1: Shape, face2: Shape,
                                          tolerance: Double = 1e-6) -> Int {
        Int(OCCTBRepLibContinuityOfFaces(edge.handle, face1.handle, face2.handle, tolerance))
    }

    /// Build 3D curves for all edges in a shape.
    ///
    /// This was a second wrapper over a second C entry point whose body was byte-identical to the
    /// one behind ``buildCurves3d(tolerance:)`` — the same `BRepLib::BuildCurves3d` overload with
    /// the same two arguments, re-wrapped eight releases later under a new name. Because nothing
    /// connected them, the two defaults drifted 100x apart: on a pcurve-only edge on a cylinder,
    /// `buildCurves3d()` and `buildCurves3dAll()` produced curves 2.6e-6 apart and edges whose
    /// tolerance differed by the same 100x. Both names now run the same call with the same default.
    /// #498.
    @available(*, deprecated, renamed: "buildCurves3d(tolerance:)")
    @discardableResult
    public func buildCurves3dAll(tolerance: Double = 1e-5) -> Bool {
        buildCurves3d(tolerance: tolerance)
    }

    /// Same-parameter all edges in a shape.
    public func sameParameterAll(tolerance: Double = 1e-5, forced: Bool = false) {
        OCCTBRepLibSameParameterAll(handle, tolerance, forced)
    }
}

// --- History extended ---

extension Shape.History {
    /// Merge another history into this one.
    public func merge(_ other: Shape.History) {
        OCCTHistoryMerge(historyRef, other.historyRef)
    }

    /// Replace a generated entry.
    public func replaceGenerated(initial: Shape, generated: Shape) {
        OCCTHistoryReplaceGenerated(historyRef, initial.handle, generated.handle)
    }

    /// Replace a modified entry.
    public func replaceModified(initial: Shape, modified: Shape) {
        OCCTHistoryReplaceModified(historyRef, initial.handle, modified.handle)
    }

    /// Get the shapes that the given initial shape was modified to.
    public func modifiedShapes(of initial: Shape) -> [Shape] {
        let maxCount: Int32 = 64
        var refs = [OCCTShapeRef?](repeating: nil, count: Int(maxCount))
        let count = refs.withUnsafeMutableBufferPointer { buf in
            OCCTHistoryGetModifiedShapes(historyRef, initial.handle, buf.baseAddress!, maxCount)
        }
        return (0..<Int(count)).compactMap { i -> Shape? in
            guard let ref = refs[i] else { return nil }
            return Shape(handle: ref)
        }
    }

    /// Get the shapes generated from the given initial shape.
    public func generatedShapes(of initial: Shape) -> [Shape] {
        let maxCount: Int32 = 64
        var refs = [OCCTShapeRef?](repeating: nil, count: Int(maxCount))
        let count = refs.withUnsafeMutableBufferPointer { buf in
            OCCTHistoryGetGeneratedShapes(historyRef, initial.handle, buf.baseAddress!, maxCount)
        }
        return (0..<Int(count)).compactMap { i -> Shape? in
            guard let ref = refs[i] else { return nil }
            return Shape(handle: ref)
        }
    }
}

// --- Sewing extended ---


// MARK: - Builder extensions, Section ops, Curve/Surface queries (v0.123.0)

// --- ThruSections extensions ---

extension ThruSectionsBuilder {
    /// Enable/disable wire compatibility checking (reorders wires to avoid twists).
    public func checkCompatibility(_ check: Bool = true) {
        OCCTThruSectionsCheckCompatibility(ref, check)
    }

    /// Set parameterization type.
    /// - Parameter type: 0=ChordLength, 1=Centripetal, 2=IsoParametric
    public func setParType(_ type: Int) {
        OCCTThruSectionsSetParType(ref, Int32(type))
    }

    /// Set criterium weights for the approximation algorithm.
    public func setCriteriumWeight(w1: Double, w2: Double, w3: Double) {
        OCCTThruSectionsSetCriteriumWeight(ref, w1, w2, w3)
    }

    /// Get the face generated from an edge after building.
    public func generatedFace(from edge: Shape) -> Shape? {
        guard let h = OCCTThruSectionsGeneratedFace(ref, edge.handle) else { return nil }
        return Shape(handle: h)
    }
}

// --- CellsBuilder extensions ---

extension CellsBuilder {
    /// Add cells to result selectively: cells present in all take shapes but none of avoid shapes.
    public func addToResult(take: [Shape], avoid: [Shape] = [], material: Int32 = 0, update: Bool = false) {
        let takePtrs: [OCCTShapeRef] = take.map { $0.handle }
        let avoidPtrs: [OCCTShapeRef] = avoid.map { $0.handle }
        takePtrs.withUnsafeBufferPointer { takeBuf in
            avoidPtrs.withUnsafeBufferPointer { avoidBuf in
                OCCTCellsBuilderAddToResultSelective(handle,
                    takeBuf.baseAddress!, Int32(takeBuf.count),
                    avoidBuf.baseAddress ?? UnsafePointer(bitPattern: 1)!, Int32(avoidBuf.count),
                    material, update)
            }
        }
    }

    /// Remove cells from result: cells present in all take shapes but none of avoid shapes.
    public func removeFromResult(take: [Shape], avoid: [Shape] = []) {
        let takePtrs: [OCCTShapeRef] = take.map { $0.handle }
        let avoidPtrs: [OCCTShapeRef] = avoid.map { $0.handle }
        takePtrs.withUnsafeBufferPointer { takeBuf in
            avoidPtrs.withUnsafeBufferPointer { avoidBuf in
                OCCTCellsBuilderRemoveFromResult(handle,
                    takeBuf.baseAddress!, Int32(takeBuf.count),
                    avoidBuf.baseAddress ?? UnsafePointer(bitPattern: 1)!, Int32(avoidBuf.count))
            }
        }
    }

    /// Get all split parts (before any result composition).
    public func allParts() -> Shape? {
        guard let h = OCCTCellsBuilderGetAllParts(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Make containers (wires from edges, shells from faces, etc.).
    public func makeContainers() {
        OCCTCellsBuilderMakeContainers(handle)
    }
}

// --- PipeShell extensions ---



// --- UnifySameDomain builder ---


// --- BRepAlgoAPI_Section extended ---

extension Shape {
    /// Compute section between two shapes with approximation and pcurve options.
    public static func sectionWithOptions(_ shape1: Shape, _ shape2: Shape,
                                           approximation: Bool = false,
                                           computePCurve1: Bool = false,
                                           computePCurve2: Bool = false) -> Shape? {
        guard let h = OCCTShapeSectionWithOptions(shape1.handle, shape2.handle,
                                                    approximation, computePCurve1, computePCurve2) else { return nil }
        return Shape(handle: h)
    }

    /// Get the ancestor face on shape1 for a section edge.
    public static func sectionAncestorFaceOn1(_ shape1: Shape, _ shape2: Shape, edge: Shape,
                                               approximation: Bool = false,
                                               computePCurve1: Bool = false,
                                               computePCurve2: Bool = false) -> Shape? {
        guard let h = OCCTSectionAncestorFaceOn1(shape1.handle, shape2.handle, edge.handle,
                                                    approximation, computePCurve1, computePCurve2) else { return nil }
        return Shape(handle: h)
    }

    /// Get the ancestor face on shape2 for a section edge.
    public static func sectionAncestorFaceOn2(_ shape1: Shape, _ shape2: Shape, edge: Shape,
                                               approximation: Bool = false,
                                               computePCurve1: Bool = false,
                                               computePCurve2: Bool = false) -> Shape? {
        guard let h = OCCTSectionAncestorFaceOn2(shape1.handle, shape2.handle, edge.handle,
                                                    approximation, computePCurve1, computePCurve2) else { return nil }
        return Shape(handle: h)
    }
}

// --- Curve3D queries ---

extension Curve3D {
    /// Get the first parameter of the curve.
    public var firstParameter: Double {
        OCCTCurve3DFirstParameter(handle)
    }

    /// Get the last parameter of the curve.
    public var lastParameter: Double {
        OCCTCurve3DLastParameter(handle)
    }
}

// --- Additional Shape queries ---

extension Shape {
    /// Get a nullified copy of the shape.
    public var nullified: Shape? {
        guard let h = OCCTShapeNullified(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Get the shape type as a string name.
    public var typeName: String? {
        guard let cstr = OCCTShapeTypeName(handle) else { return nil }
        return String(cString: cstr)
    }

    /// Check if this shape is NOT equal to another.
    public func isNotEqual(to other: Shape) -> Bool {
        OCCTShapeIsNotEqual(handle, other.handle)
    }

    /// Get an emptied copy of the shape (no sub-shapes).
    public var emptied: Shape? {
        guard let h = OCCTShapeEmptied(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Move the shape by a translation vector. Returns a new shape.
    public func moved(dx: Double, dy: Double, dz: Double) -> Shape? {
        guard let h = OCCTShapeMoved(handle, dx, dy, dz) else { return nil }
        return Shape(handle: h)
    }

    /// Get the orientation value as integer (0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL).
    public var orientationValue: Int {
        Int(OCCTShapeOrientationValue(handle))
    }

    /// Get the number of edges in this shape.
    public var nbEdges: Int {
        Int(OCCTShapeNbEdges(handle))
    }

    /// Get the number of faces in this shape.
    public var nbFaces: Int {
        Int(OCCTShapeNbFaces(handle))
    }

    /// Get the number of vertices in this shape.
    public var nbVertices: Int {
        Int(OCCTShapeNbVertices(handle))
    }
}

// MARK: - XCAFDoc_ColorTool and ShapeTool completions (v0.126.0)

extension Document {
    /// Add a color to the document color table. Returns label tag or -1 on failure.
    public func colorToolAddColor(r: Double, g: Double, b: Double) -> Int64 {
        OCCTDocumentColorToolAddColor(handle, r, g, b)
    }

    /// Remove a color from the document color table by label id.
    @discardableResult
    public func colorToolRemoveColor(labelId: Int64) -> Bool {
        OCCTDocumentColorToolRemoveColor(handle, labelId)
    }

    /// Get the number of colors in the color table.
    public var colorToolColorCount: Int {
        Int(OCCTDocumentColorToolGetColorCount(handle))
    }

    /// Unset color of a specific type from a label. type: 0=generic, 1=surface, 2=curve.
    @discardableResult
    public func colorToolUnSetColor(labelId: Int64, colorType: Int) -> Bool {
        OCCTDocumentColorToolUnSetColor(handle, labelId, Int32(colorType))
    }

    /// Check if a label is visible.
    public func colorToolIsVisible(labelId: Int64) -> Bool {
        OCCTDocumentColorToolIsVisible(handle, labelId)
    }

    /// Set visibility of a label.
    @discardableResult
    public func colorToolSetVisibility(labelId: Int64, visible: Bool) -> Bool {
        OCCTDocumentColorToolSetVisibility(handle, labelId, visible)
    }

    /// Check if color is defined by layer.
    public func colorToolIsColorByLayer(labelId: Int64) -> Bool {
        OCCTDocumentColorToolIsColorByLayer(handle, labelId)
    }

    /// Set color-by-layer flag on a label.
    @discardableResult
    public func colorToolSetColorByLayer(labelId: Int64, isByLayer: Bool) -> Bool {
        OCCTDocumentColorToolSetColorByLayer(handle, labelId, isByLayer)
    }

    /// Find a color in the color table. Returns label tag or -1 if not found.
    public func colorToolFindColor(r: Double, g: Double, b: Double) -> Int64 {
        OCCTDocumentColorToolFindColor(handle, r, g, b)
    }

    /// Set instance color on a shape component.
    @discardableResult
    public func colorToolSetInstanceColor(shape: Shape, colorType: Int, r: Double, g: Double, b: Double) -> Bool {
        OCCTDocumentColorToolSetInstanceColor(handle, shape.handle, Int32(colorType), r, g, b)
    }

    /// Get instance color of a shape component. Returns (r,g,b) or nil.
    public func colorToolGetInstanceColor(shape: Shape, colorType: Int) -> (r: Double, g: Double, b: Double)? {
        var r = 0.0, g = 0.0, b = 0.0
        guard OCCTDocumentColorToolGetInstanceColor(handle, shape.handle, Int32(colorType), &r, &g, &b) else { return nil }
        return (r, g, b)
    }

    // --- ShapeTool completions ---

    /// Check if a label is a free shape (top-level, not referenced by other shapes).
    public func shapeToolIsFree(labelId: Int64) -> Bool {
        OCCTDocumentShapeToolIsFree(handle, labelId)
    }

    /// Check if a label is a simple shape (not assembly, not compound).
    public func shapeToolIsSimpleShape(labelId: Int64) -> Bool {
        OCCTDocumentShapeToolIsSimpleShape(handle, labelId)
    }

    /// Check if a label is a component (reference to another shape).
    public func shapeToolIsComponent(labelId: Int64) -> Bool {
        OCCTDocumentShapeToolIsComponent(handle, labelId)
    }

    /// Check if a label is a compound shape.
    public func shapeToolIsCompound(labelId: Int64) -> Bool {
        OCCTDocumentShapeToolIsCompound(handle, labelId)
    }

    /// Check if a label is a sub-shape.
    public func shapeToolIsSubShape(labelId: Int64) -> Bool {
        OCCTDocumentShapeToolIsSubShape(handle, labelId)
    }

    /// Check if a label is an external reference.
    public func shapeToolIsExternRef(labelId: Int64) -> Bool {
        OCCTDocumentShapeToolIsExternRef(handle, labelId)
    }

    /// Get the number of users (references) of a shape label.
    public func shapeToolGetUsers(labelId: Int64) -> Int {
        Int(OCCTDocumentShapeToolGetUsers(handle, labelId))
    }

    /// Compute shapes (update internal state) for a label.
    public func shapeToolComputeShapes(labelId: Int64) {
        OCCTDocumentShapeToolComputeShapes(handle, labelId)
    }

    /// Get the number of components of a label.
    public func shapeToolNbComponents(labelId: Int64, getSubChildren: Bool = false) -> Int {
        Int(OCCTDocumentShapeToolNbComponents(handle, labelId, getSubChildren))
    }

    // MARK: - v0.127.0: ColorTool completions

    /// Get all color labels in the document.
    /// Returns an array of label IDs for all colors defined in the color tool.
    public func colorToolGetAllColors() -> [Int64] {
        var idsPtr: UnsafeMutablePointer<Int64>?
        let count = OCCTDocumentColorToolGetAllColors(handle, &idsPtr)
        guard count > 0, let ids = idsPtr else { return [] }
        defer { free(ids) }
        var result = [Int64]()
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            result.append(ids[i])
        }
        return result
    }
}

// MARK: - FilletBuilder history queries (v0.127.0)


// MARK: - ChamferBuilder history & extras (v0.128.0)


// MARK: - SectionBuilder (BRepAlgoAPI_Section) (v0.128.0)


// MARK: - GeomEval Standalone Evaluators (v0.130.0)


// MARK: - Geom2dEval Standalone Evaluators (v0.130.0)


// PointSetLib was added in OCCT 8.0.0 beta1 and removed before GA.
// Wrapper deleted in OCCTSwift v1.0.0 to follow upstream.
