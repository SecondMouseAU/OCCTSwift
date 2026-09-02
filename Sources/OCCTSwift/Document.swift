import Foundation
import OCCTBridge
import simd

/// XDE Document for loading STEP files with assembly structure,
/// names, colors, and materials.
///
/// Use `Document` when you need to:.
/// For simple geometry-only import, use `Shape.load(from:)` instead.
///
/// - Preserve assembly hierarchy from STEP files
/// - Access part names and structure
/// - Read colors and PBR materials
/// - Export with metadata preserved
public final class Document: @unchecked Sendable {
    internal let handle: OCCTDocumentRef

    internal init(handle: OCCTDocumentRef) {
        self.handle = handle
    }

    deinit {
        // Must happen before this instance's memory can be recycled, the construction-context
        // association is keyed on the instance pointer (#277).
        releaseConstructionContext()
        OCCTDocumentRelease(handle)
    }

    // MARK: - Loading

    /// Load a STEP file with full XDE support (assembly structure, names, colors, materials).
    ///
    /// - Parameters:
    ///   - url: URL to the STEP file.
    ///   - progress: Optional reporter for read progress and cancellation. Pass `nil` to
    ///     load without progress reporting.
    /// - Returns: Document containing the assembly structure.
    /// - Throws: `DocumentError` if loading fails.
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
    ///
    /// Alias for ``load(from:progress:)`` with explicit naming.
    public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Document {
        try load(from: url, progress: progress)
    }

    /// Write the document to a STEP file with progress + cancellation.
    ///
    /// `ImportError.importFailed` on other failure (the case name reuses.
    /// `ImportError` because we share the cancellation channel, see #98).
    ///
    /// - Throws: `ImportError.cancelled` if cancelled cooperatively,
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

    /// Create a new empty document.
    public static func create() -> Document? {
        guard let handle = OCCTDocumentCreate() else {
            return nil
        }
        return Document(handle: handle)
    }

    // MARK: - Assembly Structure

    /// Get the root nodes (top-level/free shapes) in the document.
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
    /// LabelIds are stable within a single `Document` instance, a labelId.
    /// obtained from `rootNodes` traversal can be passed back here later in.
    /// the same session to recover the corresponding node.
    public func node(at labelId: Int64) -> AssemblyNode? {
        // Warm up the labelId registry. On a freshly-loaded document the
        // table is empty until something walks the assembly, iterating the
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

    /// Get all shapes from the document as a flat list.
    public func allShapes() -> [Shape] {
        var shapes: [Shape] = []
        collectShapes(from: rootNodes, into: &shapes)
        return shapes
    }

    /// Get all shapes with their associated colors.
    public func shapesWithColors() -> [(shape: Shape, color: Color?)] {
        var results: [(Shape, Color?)] = []
        collectShapesWithColors(from: rootNodes, into: &results)
        return results
    }

    /// Get all shapes with their associated PBR materials.
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

    private func collectShapesWithColors(
        from nodes: [AssemblyNode], into results: inout [(Shape, Color?)]
    ) {
        for node in nodes {
            if let shape = node.shape {
                results.append((shape, node.color))
            }
            collectShapesWithColors(from: node.children, into: &results)
        }
    }

    private func collectShapesWithMaterials(
        from nodes: [AssemblyNode], into results: inout [(Shape, Material?)]
    ) {
        for node in nodes {
            if let shape = node.shape {
                results.append((shape, node.material))
            }
            collectShapesWithMaterials(from: node.children, into: &results)
        }
    }

    // MARK: - Writing

    /// Write the document to a STEP file (preserves assembly structure, colors, materials).
    ///
    /// - Parameter url: Output file URL.
    /// - Throws: `DocumentError` if writing fails
    public func write(to url: URL) throws {
        if !OCCTDocumentWriteSTEP(handle, url.path) {
            throw DocumentError.writeFailed(url: url)
        }
    }
}

// MARK: - TNaming: Topological Naming (v0.25.0)

extension Document {

    /// Create a new label for naming history tracking.
    ///
    /// - Parameter parent: Parent node (nil for document root).
    /// - Returns: Assembly node representing the new label, or nil on failure
    public func createLabel(parent: AssemblyNode? = nil) -> AssemblyNode? {
        let parentId = parent?.labelId ?? -1
        let labelId = OCCTDocumentCreateLabel(handle, parentId)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Record a naming evolution on a label.
    ///
    /// - node: The label to record on.
    /// - evolution: Type of topological evolution.
    /// - oldShape: Previous shape (nil for primitive).
    /// - newShape: Result shape (nil for delete).
    ///
    /// - Parameters:
    /// - Returns: true if recording succeeded
    @discardableResult
    public func recordNaming(
        on node: AssemblyNode, evolution: NamingEvolution,
        oldShape: Shape? = nil, newShape: Shape? = nil
    ) -> Bool {
        OCCTDocumentNamingRecord(
            handle, node.labelId,
            OCCTNamingEvolution(UInt32(evolution.rawValue)),
            oldShape?.handle, newShape?.handle)
    }

    /// Get the current (most recent) shape on a label.
    public func currentShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTDocumentNamingGetCurrentShape(handle, node.labelId) else { return nil }
        return Shape(handle: h)
    }

    /// Get the stored shape on a label.
    public func storedShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTDocumentNamingGetShape(handle, node.labelId) else { return nil }
        return Shape(handle: h)
    }

    /// Get the naming evolution type on a label.
    public func namingEvolution(on node: AssemblyNode) -> NamingEvolution? {
        let raw = OCCTDocumentNamingGetEvolution(handle, node.labelId)
        guard raw >= 0 else { return nil }
        return NamingEvolution(rawValue: raw)
    }

    /// Get the full naming history on a label.
    public func namingHistory(on node: AssemblyNode) -> [NamingHistoryEntry] {
        let count = OCCTDocumentNamingHistoryCount(handle, node.labelId)
        guard count > 0 else { return [] }

        var entries: [NamingHistoryEntry] = []
        entries.reserveCapacity(Int(count))

        for i in 0..<count {
            var entry = OCCTNamingHistoryEntry()
            if OCCTDocumentNamingGetHistoryEntry(handle, node.labelId, i, &entry) {
                entries.append(
                    NamingHistoryEntry(
                        evolution: NamingEvolution(rawValue: Int32(entry.evolution.rawValue))
                            ?? .primitive,
                        hasOldShape: entry.hasOldShape,
                        hasNewShape: entry.hasNewShape,
                        isModification: entry.isModification
                    ))
            }
        }

        return entries
    }

    /// Get the old (input) shape from a history entry.
    public func oldShape(on node: AssemblyNode, at index: Int) -> Shape? {
        guard let h = OCCTDocumentNamingGetOldShape(handle, node.labelId, Int32(index)) else {
            return nil
        }
        return Shape(handle: h)
    }

    /// Get the new (result) shape from a history entry.
    public func newShape(on node: AssemblyNode, at index: Int) -> Shape? {
        guard let h = OCCTDocumentNamingGetNewShape(handle, node.labelId, Int32(index)) else {
            return nil
        }
        return Shape(handle: h)
    }

    /// Trace forward: find shapes generated/modified from the given shape.
    ///
    /// - shape: The source shape to trace from.
    /// - scope: A label providing document scope for the search.
    ///
    /// - Parameters:
    /// - Returns: Array of shapes that were generated/modified from the source
    public func tracedForward(from shape: Shape, scope: AssemblyNode) -> [Shape] {
        let maxCount: Int32 = 64
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(maxCount))
        let count = OCCTDocumentNamingTraceForward(
            handle, scope.labelId, shape.handle,
            &handles, maxCount)
        return (0..<Int(count)).compactMap { handles[$0].map { Shape(handle: $0) } }
    }

    /// Trace backward: find shapes that generated/preceded the given shape.
    ///
    /// - shape: The shape to trace back from.
    /// - scope: A label providing document scope for the search.
    ///
    /// - Parameters:
    /// - Returns: Array of shapes that preceded the given shape
    public func tracedBackward(from shape: Shape, scope: AssemblyNode) -> [Shape] {
        let maxCount: Int32 = 64
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(maxCount))
        let count = OCCTDocumentNamingTraceBackward(
            handle, scope.labelId, shape.handle,
            &handles, maxCount)
        return (0..<Int(count)).compactMap { handles[$0].map { Shape(handle: $0) } }
    }

    /// Create a persistent named selection.
    ///
    /// - selection: The shape to select.
    /// - context: The context shape containing the selection.
    /// - node: The label to store the selection on.
    ///
    /// - Parameters:
    /// - Returns: true if selection succeeded
    @discardableResult
    public func selectShape(_ selection: Shape, context: Shape, on node: AssemblyNode) -> Bool {
        OCCTDocumentNamingSelect(handle, node.labelId, selection.handle, context.handle)
    }

    /// Resolve a previously selected shape after modifications.
    ///
    /// - Parameter node: The label containing the selection.
    /// - Returns: The resolved shape, or nil on failure
    public func resolveShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTDocumentNamingResolve(handle, node.labelId) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - C string buffers

extension Document {
    /// Decode a NUL-terminated buffer a bridge accessor filled.
    ///
    /// Shared by every `Document` accessor that reads a string through a `char` buffer, so the
    /// decode is written once rather than once per call site. It lives in its own section rather
    /// than beside any one of them, because a helper filed under a domain is a helper the next
    /// domain's author does not find.
    static func string(fromCString buffer: [CChar]) -> String {
        buffer.withUnsafeBufferPointer { ptr in
            String(
                decoding: ptr.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
                as: UTF8.self)
        }
    }
}

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
        return LengthUnit(scale: scale, name: Self.string(fromCString: nameBuf))
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
    /// - Parameter index: Zero-based layer index.
    /// - Returns: Layer name, or nil if index is out of range
    public func layerName(at index: Int) -> String? {
        let len = OCCTDocumentGetLayerName(handle, Int32(index), nil, 0)
        guard len >= 0 else { return nil }
        var buf = [CChar](repeating: 0, count: Int(len) + 1)
        let actualLen = OCCTDocumentGetLayerName(handle, Int32(index), &buf, Int32(buf.count))
        guard actualLen >= 0 else { return nil }
        return Self.string(fromCString: buf)
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
    /// - Parameter index: Zero-based material index.
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

// MARK: - TDF CopyLabel (v0.54.0)

extension Document {
    /// Copy a label and all its attributes to a destination label.
    ///
    /// - source: The source label to copy from.
    /// - destination: The destination label to copy to.
    ///
    /// - Parameters:
    /// - Returns: true if the copy succeeded
    @discardableResult
    public func copyLabel(from source: AssemblyNode, to destination: AssemblyNode) -> Bool {
        OCCTDocumentCopyLabel(handle, source.labelId, destination.labelId)
    }
}

// MARK: - Document Main Label (v0.54.0)

extension Document {
    /// The main label (0:1) of the document, the root of the user data tree.
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
    /// Must be called before any transactions.
    ///
    /// Set to 0 to disable undo.
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

    /// Save the OCAF document to a file.
    ///
    ///
    /// Format is determined by storage format.
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

    /// Load an OCAF document from a file.
    ///
    ///
    /// Registers all format drivers automatically.
    public static func loadOCAF(from path: String) -> (document: Document?, status: ReaderStatus) {
        var statusRaw: Int32 = -1
        guard let ref = OCCTDocumentLoadOCAF(path, &statusRaw) else {
            return (nil, ReaderStatus(rawValue: statusRaw) ?? .openError)
        }
        return (Document(handle: ref), ReaderStatus(rawValue: statusRaw) ?? .ok)
    }

    /// Create a new document with a specific OCAF format.
    ///
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

    /// The storage format of the document (e.g.
    ///
    ///
    /// "MDTV-XCAF", "BinOcaf").
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
    /// Unlike `Document.load(from:)` which enables all modes, this allows fine-grained.
    /// control over which data types are imported from the STEP file.
    /// - url: URL to the STEP file.
    /// - modes: Reader mode flags controlling which data to import.
    ///
    /// - Parameters:
    /// - Returns: Document with the requested data, or nil on failure
    public static func loadSTEP(from url: URL, modes: STEPReaderModes) -> Document? {
        guard
            let ref = OCCTDocumentLoadSTEPWithModes(
                url.path,
                modes.color, modes.name, modes.layer,
                modes.props, modes.gdt, modes.material)
        else { return nil }
        return Document(handle: ref)
    }

    /// Load a STEP file with individual mode control for what data to import.
    public static func loadSTEP(fromPath path: String, modes: STEPReaderModes) -> Document? {
        guard
            let ref = OCCTDocumentLoadSTEPWithModes(
                path,
                modes.color, modes.name, modes.layer,
                modes.props, modes.gdt, modes.material)
        else { return nil }
        return Document(handle: ref)
    }

    /// Load a STEP file with individual mode control plus progress + cancellation.
    ///
    /// Throws `ImportError.cancelled` if cancelled, `ImportError.importFailed` on other failure.
    public static func loadSTEP(from url: URL, modes: STEPReaderModes, progress: ImportProgress?)
        throws -> Document
    {
        var cancelled: Bool = false
        let handle: OCCTDocumentRef? = withImportProgress(progress) { ctx in
            OCCTDocumentLoadSTEPWithModesProgress(
                url.path,
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
    /// - url: Output file URL.
    /// - modelType: STEP representation type (default: .asIs).
    /// - modes: Writer mode flags controlling which data to export.
    ///
    /// - Parameters:
    /// - Returns: true on success
    @discardableResult
    public func writeSTEP(
        to url: URL, modelType: StepModelType = .asIs, modes: STEPWriterModes = STEPWriterModes()
    ) -> Bool {
        OCCTDocumentWriteSTEPWithModes(
            handle, url.path,
            modelType.rawValue,
            modes.color, modes.name, modes.layer,
            modes.dimTol, modes.material)
    }

    /// Write the document to a STEP file with model type and mode control.
    @discardableResult
    public func writeSTEP(
        toPath path: String, modelType: StepModelType = .asIs,
        modes: STEPWriterModes = STEPWriterModes()
    ) -> Bool {
        OCCTDocumentWriteSTEPWithModes(
            handle, path,
            modelType.rawValue,
            modes.color, modes.name, modes.layer,
            modes.dimTol, modes.material)
    }
}

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
    /// - url: URL to the OBJ file.
    /// - singlePrecision: Use single precision for vertex data (default: false).
    /// - systemLengthUnit: System length unit in meters (e.g.
    ///
    /// 0.001 for mm).
    ///
    /// 0 = default.
    ///
    /// - Parameters:
    public static func loadOBJ(from url: URL, singlePrecision: Bool, systemLengthUnit: Double = 0)
        -> Document?
    {
        guard let ref = OCCTDocumentLoadOBJWithOptions(url.path, singlePrecision, systemLengthUnit)
        else { return nil }
        return Document(handle: ref)
    }

    /// Load an OBJ file with coordinate system conversion.
    ///
    /// - url: URL to the OBJ file.
    /// - inputCS: Input coordinate system.
    /// - outputCS: Output coordinate system.
    /// - inputLengthUnit: Input length unit in meters (0 = default).
    /// - outputLengthUnit: Output length unit in meters (0 = default).
    ///
    /// - Parameters:
    public static func loadOBJ(
        from url: URL, inputCS: MeshCoordinateSystem, outputCS: MeshCoordinateSystem,
        inputLengthUnit: Double = 0, outputLengthUnit: Double = 0
    ) -> Document? {
        guard
            let ref = OCCTDocumentLoadOBJWithCS(
                url.path,
                inputCS.rawValue, outputCS.rawValue,
                inputLengthUnit, outputLengthUnit)
        else { return nil }
        return Document(handle: ref)
    }

    /// Write the document to an OBJ file.
    ///
    /// - url: Output file URL.
    /// - deflection: Mesh deflection for tessellation (0 = skip re-meshing).
    ///
    /// - Parameters:
    /// - Returns: true on success
    @discardableResult
    public func writeOBJ(to url: URL, deflection: Double = 1.0) -> Bool {
        OCCTDocumentWriteOBJ(handle, url.path, deflection)
    }

    /// Write the document to a PLY file with options.
    ///
    /// - url: Output file URL.
    /// - deflection: Mesh deflection for tessellation (0 = skip re-meshing).
    /// - normals: Include normals (default: true).
    /// - colors: Include colors (default: false).
    /// - texCoords: Include texture coordinates (default: false).
    ///
    /// - Parameters:
    /// - Returns: true on success
    @discardableResult
    public func writePLY(
        to url: URL, deflection: Double = 1.0,
        normals: Bool = true, colors: Bool = false, texCoords: Bool = false
    ) -> Bool {
        OCCTDocumentWritePLY(handle, url.path, deflection, normals, colors, texCoords)
    }
}

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
    ///
    /// - shape: The shape to add.
    /// - makeAssembly: If true, compound shapes become assemblies.
    ///
    /// - Parameters:
    /// - Returns: Label ID of the added shape, or -1 on failure
    @discardableResult
    public func addShape(_ shape: Shape, makeAssembly: Bool = true) -> Int64 {
        OCCTDocumentAddShape(handle, shape.handle, makeAssembly)
    }

    /// Create a new empty shape label.
    ///
    /// - Returns: Label ID of the new label, or -1 on failure
    public func newShapeLabel() -> Int64 {
        OCCTDocumentNewShape(handle)
    }

    /// Remove a shape from the document.
    ///
    /// - Parameter labelId: Label ID of the shape to remove.
    /// - Returns: true if removed successfully
    @discardableResult
    public func removeShape(labelId: Int64) -> Bool {
        OCCTDocumentRemoveShape(handle, labelId)
    }

    /// Find label ID for a given shape in the document.
    ///
    /// - Returns: Label ID, or -1 if not found
    public func findShape(_ shape: Shape) -> Int64 {
        OCCTDocumentFindShape(handle, shape.handle)
    }

    /// Search for a shape in the document (including sub-shapes).
    ///
    /// - Returns: Label ID, or -1 if not found
    public func searchShape(_ shape: Shape) -> Int64 {
        OCCTDocumentSearchShape(handle, shape.handle)
    }

    /// Add a component to an assembly with translation.
    ///
    /// - assemblyLabelId: Assembly label ID.
    /// - shapeLabelId: Shape to add as component.
    /// - translation: Translation (tx, ty, tz).
    ///
    /// - Parameters:
    /// - Returns: Component label ID, or -1 on failure
    @discardableResult
    public func addComponent(
        assemblyLabelId: Int64, shapeLabelId: Int64,
        translation: (Double, Double, Double) = (0, 0, 0)
    ) -> Int64 {
        OCCTDocumentAddComponent(
            handle, assemblyLabelId, shapeLabelId,
            translation.0, translation.1, translation.2)
    }

    /// Add a component occurrence with a FULL placement, from a 12-element GROUPED matrix.
    ///
    /// `[r00 r01 r02 r10 r11 r12 r20 r21 r22 tx ty tz]`: the nine rotation values, then the three
    /// translations. This is ``Matrix12Grouped``'s layout, not ``TransformMatrix3D``'s.
    ///
    /// A reflection is accepted and applied, which is the opposite of what this doc comment said
    /// until #1009 measured it: `gp_Trsf::SetValues` names a null determinant as its only
    /// precondition, not orthonormality, and it is compiled inside OCCT's Release library where
    /// that precondition is removed outright. See #174 for the original request.
    ///
    /// ```swift
    /// // Mirror a part in X, then place the mirrored occurrence in an assembly.
    /// let doc = Document.create()!
    /// let part = doc.addShape(Shape.box(width: 10, height: 10, depth: 10)!, makeAssembly: false)
    /// let assembly = doc.newShapeLabel()
    /// doc.addComponent(assemblyLabelId: assembly, shapeLabelId: part, matrix: [
    ///     -1, 0, 0,   // r00 r01 r02, negative determinant: a mirror in X
    ///      0, 1, 0,   // r10 r11 r12
    ///      0, 0, 1,   // r20 r21 r22
    ///      0, 0, 0    // tx  ty  tz
    /// ])
    /// doc.updateAssemblies()
    /// ```
    ///
    /// - Parameters:
    ///   - assemblyLabelId: The parent assembly label.
    ///   - shapeLabelId: The shape to instantiate.
    ///   - matrix: Twelve doubles in GROUPED order.
    /// - Returns: The component label id, or -1 if `matrix` does not hold exactly twelve values or
    ///   the component could not be created.
    @discardableResult
    public func addComponent(assemblyLabelId: Int64, shapeLabelId: Int64, matrix: [Double]) -> Int64
    {
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
    ///
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

// MARK: - XDE ColorTool by Shape (v0.60.0)

extension Document {
    /// Set color on a shape directly (not by label).
    ///
    /// `color.alpha` is preserved (#763), previously it was silently dropped, so a subsequent.
    /// ``shapeColor(_:type:)`` always reported fully opaque regardless of what was set here.
    /// - shape: The shape to color.
    /// - color: The color to set.
    /// - type: Color type, generic (0), surface (1), or curve (2).
    /// ```swift.
    /// let doc = Document.create()!.
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!.
    /// doc.addShape(box).
    /// doc.setShapeColor(box, color: Color(red: 1, green: 0, blue: 0, alpha: 0.5)).
    /// let readBack = doc.shapeColor(box).
    /// // readBack?.alpha == 0.5.
    /// ```.
    ///
    /// - Parameters:
    public func setShapeColor(
        _ shape: Shape, color: Color, type: OCCTColorType = OCCTColorTypeSurface
    ) {
        OCCTDocumentSetShapeColorRGBA(
            handle, shape.handle, Int32(type.rawValue),
            color.red, color.green, color.blue, Float(color.alpha))
    }

    /// Get color for a shape (not by label).
    ///
    /// `alpha` reflects the real stored value (#763), a shape colored via.
    /// ``setShapeColor(_:color:type:)`` or imported from a file with a transparent surface style.
    /// reports its actual alpha, rather than always 1.0.
    /// - shape: The shape to query.
    /// - type: Color type, generic (0), surface (1), or curve (2).
    ///
    /// - Parameters:
    /// - Returns: Color if set, nil otherwise
    public func shapeColor(_ shape: Shape, type: OCCTColorType = OCCTColorTypeSurface) -> Color? {
        let c = OCCTDocumentGetShapeColor(handle, shape.handle, Int32(type.rawValue))
        guard c.isSet else { return nil }
        return Color(red: c.r, green: c.g, blue: c.b, alpha: c.a)
    }

    /// Check if color is set on a shape.
    public func isShapeColorSet(_ shape: Shape, type: OCCTColorType = OCCTColorTypeSurface) -> Bool
    {
        OCCTDocumentIsShapeColorSet(handle, shape.handle, Int32(type.rawValue))
    }
}

// MARK: - XDE LayerTool Expansion (v0.60.0)

extension Document {
    /// Find a layer label by name.
    ///
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
    ///
    /// - labelId: Label of the compound to expand.
    /// - recursively: If true, expand recursively.
    ///
    /// - Parameters:
    /// - Returns: true if expanded successfully
    @discardableResult
    public func editorExpand(labelId: Int64, recursively: Bool = true) -> Bool {
        OCCTDocumentEditorExpand(handle, labelId, recursively)
    }

    /// Rescale geometry on a label.
    ///
    /// - labelId: Label to rescale.
    /// - scaleFactor: Scale factor.
    /// - forceIfNotRoot: Force rescale even if label is not root.
    ///
    /// - Parameters:
    /// - Returns: true on success; false if the document holds a datum OCCT cannot read without
    ///   crashing (#1030), in which case nothing is rescaled.
    @discardableResult
    public func rescaleGeometry(labelId: Int64, scaleFactor: Double, forceIfNotRoot: Bool = false)
        -> Bool
    {
        OCCTDocumentEditorRescaleGeometry(handle, labelId, scaleFactor, forceIfNotRoot)
    }
}

// MARK: - XCAFDoc_NotesTool (v0.83.0)

extension Document {
    /// Get the number of notes via NotesTool.
    public var notesToolNoteCount: Int32 {
        OCCTDocumentNotesToolNbNotes(handle)
    }

    /// Create a comment note via NotesTool.
    ///
    ///
    /// Returns the note label node.
    public func notesToolCreateComment(userName: String, timeStamp: String, comment: String)
        -> AssemblyNode?
    {
        let labelId = OCCTDocumentNotesToolCreateComment(handle, userName, timeStamp, comment)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Create a balloon note via NotesTool.
    ///
    ///
    /// Returns the note label node.
    public func notesToolCreateBalloon(userName: String, timeStamp: String, comment: String)
        -> AssemblyNode?
    {
        let labelId = OCCTDocumentNotesToolCreateBalloon(handle, userName, timeStamp, comment)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Create a binary data note via NotesTool.
    ///
    ///
    /// Returns the note label node.
    public func notesToolCreateBinData(
        userName: String, timeStamp: String, title: String,
        mimeType: String, data: [UInt8]
    ) -> AssemblyNode? {
        let labelId = data.withUnsafeBufferPointer { buf in
            OCCTDocumentNotesToolCreateBinData(
                handle, userName, timeStamp,
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

    /// Delete all notes.
    ///
    ///
    /// Returns the number of deleted notes.
    @discardableResult
    public func notesToolDeleteAllNotes() -> Int32 {
        OCCTDocumentNotesToolDeleteAllNotes(handle)
    }

    /// Get the number of orphan notes.
    public var notesToolOrphanNoteCount: Int32 {
        OCCTDocumentNotesToolNbOrphanNotes(handle)
    }

    /// Delete all orphan notes.
    ///
    ///
    /// Returns the number of deleted notes.
    @discardableResult
    public func notesToolDeleteOrphanNotes() -> Int32 {
        OCCTDocumentNotesToolDeleteOrphanNotes(handle)
    }
}

// MARK: - XCAFDoc_ClippingPlaneTool (v0.83.0)

extension Document {
    /// Add a clipping plane.
    ///
    ///
    /// Returns the clipping plane label node.
    public func clippingPlaneToolAdd(
        originX: Double, originY: Double, originZ: Double,
        normalX: Double, normalY: Double, normalZ: Double,
        name: String, capping: Bool
    ) -> AssemblyNode? {
        let labelId = OCCTDocumentClipPlaneToolAdd(
            handle,
            originX, originY, originZ,
            normalX, normalY, normalZ,
            name, capping)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Get a clipping plane from a label.
    public func clippingPlaneToolGet(_ node: AssemblyNode) -> (
        originX: Double, originY: Double, originZ: Double,
        normalX: Double, normalY: Double, normalZ: Double,
        capping: Bool
    )? {
        var ox: Double = 0
        var oy: Double = 0
        var oz: Double = 0
        var nx: Double = 0
        var ny: Double = 0
        var nz: Double = 0
        var cap = false
        guard OCCTDocumentClipPlaneToolGet(handle, node.labelId, &ox, &oy, &oz, &nx, &ny, &nz, &cap)
        else { return nil }
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

// MARK: - VrmlAPI_Writer

extension Document {
    /// Write XDE document to VRML file with scale.
    ///
    /// - url: File URL to write to (.wrl extension).
    /// - scale: Scale factor (default 1.0).
    ///
    /// - Parameters:
    /// - Returns: true if successful
    @discardableResult
    public func writeVRML(to url: URL, scale: Double = 1.0) -> Bool {
        OCCTVrmlWriteDocument(handle, url.path, scale)
    }
}

// MARK: - TDataStd_Directory

extension Document {
    /// Create a new directory attribute on a label.
    ///
    /// - Parameter labelTag: Label child tag (0 = main label).
    /// - Returns: `true` when a `TDataStd_Directory` attribute was created on the
    ///   label; `false` if OCCT returned a null handle or raised.
    @discardableResult
    public func createDirectory(at labelTag: Int = 0) -> Bool {
        OCCTDocumentDirectoryNew(handle, Int32(labelTag))
    }

    /// Check if a directory attribute exists on a label.
    public func hasDirectory(at labelTag: Int = 0) -> Bool {
        OCCTDocumentDirectoryFind(handle, Int32(labelTag))
    }

    /// Add a sub-directory under an existing directory.
    ///
    /// - Returns: Child label tag, or nil if failed
    public func addSubDirectory(under parentLabelTag: Int = 0) -> Int? {
        let tag = OCCTDocumentDirectoryAddSubDirectory(handle, Int32(parentLabelTag))
        return tag >= 0 ? Int(tag) : nil
    }

    /// Make an object label under a directory.
    ///
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
        guard let cStr = OCCTDocumentExpressionGetString(handle, Int32(labelTag)) else {
            return nil
        }
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
        guard let cStr = OCCTDocumentXLinkGetDocumentEntry(handle, Int32(labelTag)) else {
            return nil
        }
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
    ///
    /// `0` when any datum attached to a tolerance is one OCCT cannot read without crashing
    /// (#1030), which is indistinguishable from a document with no tolerances; see
    /// `docs/reference/Annotation.md`.
    public var dimTolToolToleranceCount: Int {
        Int(OCCTDocumentDimTolToleranceCount(handle))
    }
}

// MARK: - TDataStd_BooleanArray

extension Document {
    /// Set a boolean array attribute on a label.
    public func setBooleanArray(tag: Int, values: [Bool]) -> Bool {
        let cValues = values.map { $0 }
        return cValues.withUnsafeBufferPointer { buf in
            OCCTDocumentSetBooleanArray(
                handle, Int32(tag), 1, Int32(values.count),
                buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a boolean array attribute from a label.
    public func booleanArray(tag: Int) -> [Bool]? {
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
    public func hasBooleanArray(tag: Int) -> Bool {
        OCCTDocumentHasBooleanArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_BooleanList

extension Document {
    /// Set a boolean list attribute on a label.
    public func setBooleanList(tag: Int, values: [Bool]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetBooleanList(handle, Int32(tag), buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a boolean list attribute from a label.
    public func booleanList(tag: Int) -> [Bool]? {
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
    public func booleanListAppend(tag: Int, value: Bool) -> Bool {
        OCCTDocumentBooleanListAppend(handle, Int32(tag), value)
    }

    /// Clear a boolean list attribute.
    public func booleanListClear(tag: Int) -> Bool {
        OCCTDocumentBooleanListClear(handle, Int32(tag))
    }

    /// Check if a label has a boolean list attribute.
    public func hasBooleanList(tag: Int) -> Bool {
        OCCTDocumentHasBooleanList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ByteArray

extension Document {
    /// Set a byte array attribute on a label.
    public func setByteArray(tag: Int, values: [UInt8]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetByteArray(
                handle, Int32(tag), 0, Int32(values.count - 1),
                buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a byte array attribute from a label.
    public func byteArray(tag: Int) -> [UInt8]? {
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
    public func hasByteArray(tag: Int) -> Bool {
        OCCTDocumentHasByteArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_IntegerList

extension Document {
    /// Set an integer list attribute on a label.
    public func setIntegerList(tag: Int, values: [Int32]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetIntegerList(handle, Int32(tag), buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get an integer list attribute from a label.
    public func integerList(tag: Int) -> [Int32]? {
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
    public func integerListAppend(tag: Int, value: Int32) -> Bool {
        OCCTDocumentIntegerListAppend(handle, Int32(tag), value)
    }

    /// Clear an integer list attribute.
    public func integerListClear(tag: Int) -> Bool {
        OCCTDocumentIntegerListClear(handle, Int32(tag))
    }

    /// Check if a label has an integer list attribute.
    public func hasIntegerList(tag: Int) -> Bool {
        OCCTDocumentHasIntegerList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_RealList

extension Document {
    /// Set a real list attribute on a label.
    public func setRealList(tag: Int, values: [Double]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetRealList(handle, Int32(tag), buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a real list attribute from a label.
    public func realList(tag: Int) -> [Double]? {
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
    public func realListAppend(tag: Int, value: Double) -> Bool {
        OCCTDocumentRealListAppend(handle, Int32(tag), value)
    }

    /// Clear a real list attribute.
    public func realListClear(tag: Int) -> Bool {
        OCCTDocumentRealListClear(handle, Int32(tag))
    }

    /// Check if a label has a real list attribute.
    public func hasRealList(tag: Int) -> Bool {
        OCCTDocumentHasRealList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ExtStringArray

extension Document {
    /// Set an extended string array attribute on a label.
    public func setExtStringArray(tag: Int, values: [String]) -> Bool {
        var result = false
        let count = values.count
        let cStrings: [UnsafePointer<CChar>] = values.map { str in
            (str as NSString).utf8String!
        }
        cStrings.withUnsafeBufferPointer { buf in
            result = OCCTDocumentSetExtStringArray(
                handle, Int32(tag), 1, Int32(count),
                buf.baseAddress!, Int32(count))
        }
        return result
    }

    /// Get an extended string array element by index (1-based).
    public func extStringArrayValue(tag: Int, index: Int) -> String? {
        guard let cStr = OCCTDocumentGetExtStringArrayValue(handle, Int32(tag), Int32(index)) else {
            return nil
        }
        defer { free(cStr) }
        return String(cString: cStr)
    }

    /// Get the length of an extended string array.
    public func extStringArrayLength(tag: Int) -> Int? {
        let len = OCCTDocumentGetExtStringArrayLength(handle, Int32(tag))
        return len >= 0 ? Int(len) : nil
    }

    /// Check if a label has an extended string array attribute.
    public func hasExtStringArray(tag: Int) -> Bool {
        OCCTDocumentHasExtStringArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ExtStringList

extension Document {
    /// Set an extended string list attribute on a label.
    public func setExtStringList(tag: Int, values: [String]) -> Bool {
        var result = false
        let count = values.count
        let cStrings: [UnsafePointer<CChar>] = values.map { str in
            (str as NSString).utf8String!
        }
        cStrings.withUnsafeBufferPointer { buf in
            result = OCCTDocumentSetExtStringList(
                handle, Int32(tag),
                buf.baseAddress!, Int32(count))
        }
        return result
    }

    /// Get the count of an extended string list.
    public func extStringListCount(tag: Int) -> Int? {
        let count = OCCTDocumentGetExtStringListCount(handle, Int32(tag))
        return count >= 0 ? Int(count) : nil
    }

    /// Get an extended string list element by index (0-based).
    public func extStringListValue(tag: Int, index: Int) -> String? {
        guard let cStr = OCCTDocumentGetExtStringListValue(handle, Int32(tag), Int32(index)) else {
            return nil
        }
        defer { free(cStr) }
        return String(cString: cStr)
    }

    /// Append a string to an extended string list attribute.
    public func extStringListAppend(tag: Int, value: String) -> Bool {
        OCCTDocumentExtStringListAppend(handle, Int32(tag), value)
    }

    /// Clear an extended string list attribute.
    public func extStringListClear(tag: Int) -> Bool {
        OCCTDocumentExtStringListClear(handle, Int32(tag))
    }

    /// Check if a label has an extended string list attribute.
    public func hasExtStringList(tag: Int) -> Bool {
        OCCTDocumentHasExtStringList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ReferenceArray

extension Document {
    /// Set a reference array attribute on a label (array of label tags).
    public func setReferenceArray(tag: Int, refTags: [Int32]) -> Bool {
        refTags.withUnsafeBufferPointer { buf in
            OCCTDocumentSetReferenceArray(
                handle, Int32(tag), 1, Int32(refTags.count),
                buf.baseAddress!, Int32(refTags.count))
        }
    }

    /// Get a reference array from a label (array of label tags).
    public func referenceArray(tag: Int) -> [Int32]? {
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
    public func hasReferenceArray(tag: Int) -> Bool {
        OCCTDocumentHasReferenceArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ReferenceList

extension Document {
    /// Set a reference list attribute on a label (list of label tags).
    public func setReferenceList(tag: Int, refTags: [Int32]) -> Bool {
        refTags.withUnsafeBufferPointer { buf in
            OCCTDocumentSetReferenceList(
                handle, Int32(tag),
                buf.baseAddress!, Int32(refTags.count))
        }
    }

    /// Get a reference list from a label (list of label tags).
    public func referenceList(tag: Int) -> [Int32]? {
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
    public func referenceListAppend(tag: Int, refTag: Int32) -> Bool {
        OCCTDocumentReferenceListAppend(handle, Int32(tag), refTag)
    }

    /// Clear a reference list attribute.
    public func referenceListClear(tag: Int) -> Bool {
        OCCTDocumentReferenceListClear(handle, Int32(tag))
    }

    /// Check if a label has a reference list attribute.
    public func hasReferenceList(tag: Int) -> Bool {
        OCCTDocumentHasReferenceList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_Relation

extension Document {
    /// Set a relation string on a label.
    public func setRelation(tag: Int, relation: String) -> Bool {
        OCCTDocumentSetRelation(handle, Int32(tag), relation)
    }

    /// Get a relation string from a label.
    public func relation(tag: Int) -> String? {
        guard let cStr = OCCTDocumentGetRelation(handle, Int32(tag)) else { return nil }
        defer { free(cStr) }
        return String(cString: cStr)
    }

    /// Check if a label has a relation attribute.
    public func hasRelation(tag: Int) -> Bool {
        OCCTDocumentHasRelation(handle, Int32(tag))
    }
}

// MARK: - TDataStd_Tick

extension Document {
    /// Set a tick (boolean flag) attribute on a label.
    public func setTick(tag: Int) -> Bool {
        OCCTDocumentSetTick(handle, Int32(tag))
    }

    /// Check if a label has a tick attribute.
    public func hasTick(tag: Int) -> Bool {
        OCCTDocumentHasTick(handle, Int32(tag))
    }

    /// Remove a tick attribute from a label.
    public func removeTick(tag: Int) -> Bool {
        OCCTDocumentRemoveTick(handle, Int32(tag))
    }
}

// MARK: - TDataStd_Current

extension Document {
    /// Set a label as the current label in the document.
    public func setCurrentLabel(tag: Int) -> Bool {
        OCCTDocumentSetCurrentLabel(handle, Int32(tag))
    }

    /// Get the current label tag, or nil if none set.
    public func currentLabel() -> Int? {
        let tag = OCCTDocumentGetCurrentLabel(handle)
        return tag >= 0 ? Int(tag) : nil
    }

    /// Check if the document has a current label set.
    public func hasCurrentLabel() -> Bool {
        OCCTDocumentHasCurrentLabel(handle)
    }
}

// MARK: - TNaming Extensions (v0.88.0)

extension Document {

    /// Check if a TNaming_NamedShape on a label is empty.
    public func namingIsEmpty(on node: AssemblyNode) -> Bool {
        OCCTNamingIsEmpty(handle, node.labelId)
    }

    /// Get the version of a TNaming_NamedShape attribute.
    public func namingVersion(on node: AssemblyNode) -> Int {
        Int(OCCTNamingGetVersion(handle, node.labelId))
    }

    /// Set the version of a TNaming_NamedShape attribute.
    @discardableResult
    public func setNamingVersion(on node: AssemblyNode, version: Int) -> Bool {
        OCCTNamingSetVersion(handle, node.labelId, Int32(version))
    }

    /// Get the original (old) shape from a named shape attribute.
    public func namingOriginalShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTNamingOriginalShape(handle, node.labelId) else { return nil }
        return Shape(handle: h)
    }

    /// Check if a shape has a label in the document's naming framework.
    public func namingHasLabel(shape: Shape) -> Bool {
        OCCTNamingHasLabel(handle, shape.handle)
    }

    /// Find the label for a shape in the document's naming framework.
    public func namingFindLabel(shape: Shape) -> AssemblyNode? {
        let labelId = OCCTNamingFindLabel(handle, shape.handle)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Get the valid-until transaction number for a shape.
    public func namingValidUntil(shape: Shape) -> Int {
        Int(OCCTNamingValidUntil(handle, shape.handle))
    }

    /// Get count of labels containing the same shape.
    public func sameShapeCount(shape: Shape) -> Int {
        Int(OCCTNamingSameShapeCount(handle, shape.handle))
    }

    /// Get all labels containing the same shape.
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

    /// Set (create) an IntPackedMap attribute on a label.
    @discardableResult
    public func setIntPackedMap(tag: Int, isDelta: Bool = false) -> Bool {
        OCCTIntPackedMapSet(handle, Int32(tag), isDelta)
    }

    /// Add a value to the IntPackedMap.
    @discardableResult
    public func intPackedMapAdd(tag: Int, value: Int) -> Bool {
        OCCTIntPackedMapAdd(handle, Int32(tag), Int32(value))
    }

    /// Remove a value from the IntPackedMap.
    @discardableResult
    public func intPackedMapRemove(tag: Int, value: Int) -> Bool {
        OCCTIntPackedMapRemove(handle, Int32(tag), Int32(value))
    }

    /// Check if the IntPackedMap contains a value.
    public func intPackedMapContains(tag: Int, value: Int) -> Bool {
        OCCTIntPackedMapContains(handle, Int32(tag), Int32(value))
    }

    /// Get the count of elements in the IntPackedMap.
    public func intPackedMapCount(tag: Int) -> Int {
        Int(OCCTIntPackedMapExtent(handle, Int32(tag)))
    }

    /// Clear all elements from the IntPackedMap.
    @discardableResult
    public func intPackedMapClear(tag: Int) -> Bool {
        OCCTIntPackedMapClear(handle, Int32(tag))
    }

    /// Check if the IntPackedMap is empty.
    public func intPackedMapIsEmpty(tag: Int) -> Bool {
        OCCTIntPackedMapIsEmpty(handle, Int32(tag))
    }

    /// Get all values from the IntPackedMap.
    public func intPackedMapValues(tag: Int) -> [Int] {
        var ptr: UnsafeMutablePointer<Int32>?
        let count = OCCTIntPackedMapGetValues(handle, Int32(tag), &ptr)
        guard count > 0, let ptr = ptr else { return [] }
        defer { OCCTIntPackedMapFreeValues(ptr) }
        return (0..<Int(count)).map { Int(ptr[$0]) }
    }

    /// Replace all values in the IntPackedMap.
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

    /// Create a NoteBook attribute on a label.
    @discardableResult
    public func setNoteBook(tag: Int) -> Bool {
        OCCTNoteBookNew(handle, Int32(tag))
    }

    /// Append a real value to the NoteBook, returns the child label tag or nil.
    public func noteBookAppendReal(tag: Int, value: Double) -> Int? {
        let result = OCCTNoteBookAppendReal(handle, Int32(tag), value)
        return result >= 0 ? Int(result) : nil
    }

    /// Append an integer value to the NoteBook, returns the child label tag or nil.
    public func noteBookAppendInteger(tag: Int, value: Int) -> Int? {
        let result = OCCTNoteBookAppendInteger(handle, Int32(tag), Int32(value))
        return result >= 0 ? Int(result) : nil
    }

    /// Check if a NoteBook exists on a label (searches up hierarchy).
    public func noteBookExists(tag: Int) -> Bool {
        OCCTNoteBookFind(handle, Int32(tag))
    }
}

// MARK: - TDataStd_UAttribute (v0.88.0)

extension Document {

    /// Set a UAttribute with a GUID string on a label.
    @discardableResult
    public func setUAttribute(tag: Int, guid: String) -> Bool {
        OCCTUAttributeSet(handle, Int32(tag), guid)
    }

    /// Check if a UAttribute with a given GUID exists on a label.
    public func hasUAttribute(tag: Int, guid: String) -> Bool {
        OCCTUAttributeHas(handle, Int32(tag), guid)
    }

    /// Get the GUID string of a UAttribute on a label.
    public func uAttributeID(tag: Int, guid: String) -> String? {
        guard let ptr = OCCTUAttributeGetID(handle, Int32(tag), guid) else { return nil }
        defer { OCCTUAttributeFreeGUID(ptr) }
        return String(cString: ptr)
    }
}

// MARK: - TDataStd_ChildNodeIterator (v0.88.0)

extension Document {

    /// Get count of child tree nodes on a label.
    public func childNodeCount(tag: Int, allLevels: Bool = false) -> Int {
        Int(OCCTChildNodeIteratorCount(handle, Int32(tag), allLevels))
    }
}

// MARK: - TDF_Transaction Named (v0.89.0)

extension Document {

    /// Open a transaction whose name is recorded on the delta its commit produces.
    ///
    /// - Parameter name: Name to record on the committed transaction, readable afterwards as
    ///   `TransactionDelta.name`.
    /// - Returns: The number of the transaction just opened, or 0 if none opened.
    @discardableResult
    public func openNamedTransaction(_ name: String) -> Int {
        Int(OCCTDocumentOpenNamedTransaction(handle, name))
    }

    /// The number of the currently open transaction, or 0 when none is open.
    ///
    /// A document holds at most one transaction, so this is never greater than 1; use
    /// `hasOpenTransaction` when the open/closed state is all that is wanted.
    public var transactionNumber: Int {
        Int(OCCTDocumentGetTransactionNumber(handle))
    }

    /// Commit the current transaction and return the delta it recorded.
    ///
    /// Undo is disabled until `setUndoLimit(_:)` is called, and a document with undo disabled
    /// records no deltas.
    ///
    /// - Returns: The committed delta, or nil if the commit recorded none.
    public func commitWithDelta() -> TransactionDelta? {
        guard let ptr = OCCTDocumentCommitWithDelta(handle) else { return nil }
        return TransactionDelta(handle: ptr)
    }
}

// MARK: - TDF_ComparisonTool (v0.89.0)

extension Document {

    /// Check if a label's references are all contained within its descendants.
    ///
    /// - Parameter labelId: The label to check.
    /// - Returns: true if self-contained
    public func isSelfContained(labelId: Int64) -> Bool {
        OCCTDocumentIsSelfContained(handle, labelId)
    }
}

// MARK: - TDocStd_XLinkTool (v0.89.0)

extension Document {

    /// Copy a label and its attributes to another label (simple copy).
    ///
    /// - targetLabelId: Destination label.
    /// - sourceLabelId: Source label.
    ///
    /// - Parameters:
    /// - Returns: true on success
    @discardableResult
    public func xlinkCopy(targetLabelId: Int64, sourceLabelId: Int64) -> Bool {
        OCCTDocumentXLinkCopy(handle, targetLabelId, sourceLabelId)
    }

    /// Copy a label with an XLink attribute for cross-document reference tracking.
    ///
    /// - targetLabelId: Destination label.
    /// - sourceLabelId: Source label.
    ///
    /// - Parameters:
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
    ///
    /// Automatically creates a TFunction_Scope if not present.
    /// - labelId: Label to attach the function to.
    /// - guid: GUID string identifying the function type.
    ///
    /// - Parameters:
    /// - Returns: true on success
    @discardableResult
    public func newFunction(labelId: Int64, guid: String) -> Bool {
        OCCTDocumentNewFunction(handle, labelId, guid)
    }

    /// Delete a function from a label.
    ///
    /// - Parameter labelId: Label with the function.
    /// - Returns: true on success
    @discardableResult
    public func deleteFunction(labelId: Int64) -> Bool {
        OCCTDocumentDeleteFunction(handle, labelId)
    }

    /// Get the execution status of a function.
    ///
    /// - Parameter labelId: Label with the function.
    /// - Returns: The execution status, or nil if no function found
    public func functionExecStatus(labelId: Int64) -> FunctionExecutionStatus? {
        let raw = OCCTDocumentFunctionGetExecStatus(handle, labelId)
        if raw < 0 { return nil }
        return FunctionExecutionStatus(rawValue: raw)
    }

    /// Set the execution status of a function.
    ///
    /// - labelId: Label with the function.
    /// - status: The new execution status.
    ///
    /// - Parameters:
    /// - Returns: true on success
    @discardableResult
    public func setFunctionExecStatus(labelId: Int64, status: FunctionExecutionStatus) -> Bool {
        OCCTDocumentFunctionSetExecStatus(handle, labelId, status.rawValue)
    }
}

// MARK: - TFunction_Scope (v0.89.0)

extension Document {

    /// Set (find or create) a function scope on the document root.
    ///
    /// Required before using function mechanism operations.
    ///
    /// - Returns: true on success
    @discardableResult
    public func setFunctionScope() -> Bool {
        OCCTDocumentSetFunctionScope(handle)
    }

    /// Add a label to the function scope.
    ///
    /// - Parameter labelId: Label to register as a function.
    /// - Returns: true on success
    @discardableResult
    public func functionScopeAdd(labelId: Int64) -> Bool {
        OCCTDocumentFunctionScopeAdd(handle, labelId)
    }

    /// Remove a label from the function scope.
    ///
    /// - Parameter labelId: Label to unregister.
    /// - Returns: true on success
    @discardableResult
    public func functionScopeRemove(labelId: Int64) -> Bool {
        OCCTDocumentFunctionScopeRemove(handle, labelId)
    }

    /// Check if a label is registered in the function scope.
    ///
    /// - Parameter labelId: Label to check.
    /// - Returns: true if in scope
    public func functionScopeHas(labelId: Int64) -> Bool {
        OCCTDocumentFunctionScopeHas(handle, labelId)
    }

    /// Remove all functions from the scope.
    ///
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
    ///
    /// - labelId: Label to inspect.
    /// - withoutForgotten: If true (default), skip forgotten attributes.
    ///
    /// - Parameters:
    /// - Returns: Number of attributes
    public func attributeCount(labelId: Int64, withoutForgotten: Bool = true) -> Int {
        Int(OCCTDocumentAttributeCount(handle, labelId, withoutForgotten))
    }

    /// Check if a label has any content in a DataSet context.
    ///
    /// Returns false if the label is not empty (has been added to the data framework).
    public func dataSetIsEmpty(labelId: Int64) -> Bool {
        OCCTDocumentDataSetIsEmpty(handle, labelId)
    }
}

// MARK: - TDF_ChildIDIterator (v0.90.0)

extension Document {

    /// Count child labels that have an attribute with the given GUID.
    ///
    /// - labelId: Parent label to search.
    /// - guid: GUID string of the attribute type.
    /// - allLevels: If true, recurse into all descendants.
    ///
    /// - Parameters:
    /// - Returns: Number of matching children
    public func childIDCount(labelId: Int64, guid: String, allLevels: Bool = false) -> Int {
        Int(OCCTDocumentChildIDCount(handle, labelId, guid, allLevels))
    }
}

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

    /// Get the color of a presentation.
    ///
    ///
    /// Returns nil if no own color.
    public func presentationGetColor(labelId: Int64) -> Int32? {
        let v = OCCTDocumentPresentationGetColor(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Set the transparency of a presentation [0.0, 1.0].
    @discardableResult
    public func presentationSetTransparency(labelId: Int64, value: Double) -> Bool {
        OCCTDocumentPresentationSetTransparency(handle, labelId, value)
    }

    /// Get the transparency.
    ///
    ///
    /// Returns nil if no own transparency.
    public func presentationGetTransparency(labelId: Int64) -> Double? {
        let v = OCCTDocumentPresentationGetTransparency(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Set the line width of a presentation.
    @discardableResult
    public func presentationSetWidth(labelId: Int64, width: Double) -> Bool {
        OCCTDocumentPresentationSetWidth(handle, labelId, width)
    }

    /// Get the line width.
    ///
    ///
    /// Returns nil if no own width.
    public func presentationGetWidth(labelId: Int64) -> Double? {
        let v = OCCTDocumentPresentationGetWidth(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Set the display mode of a presentation (0=wireframe, 1=shaded, etc.).
    @discardableResult
    public func presentationSetMode(labelId: Int64, mode: Int32) -> Bool {
        OCCTDocumentPresentationSetMode(handle, labelId, mode)
    }

    /// Get the display mode.
    ///
    ///
    /// Returns nil if no own mode.
    public func presentationGetMode(labelId: Int64) -> Int32? {
        let v = OCCTDocumentPresentationGetMode(handle, labelId)
        return v >= 0 ? v : nil
    }
}

// MARK: - XCAFDoc_AssemblyIterator (v0.90.0)

extension Document {

    /// Count the number of assembly items in the document.
    ///
    /// - Parameter maxDepth: Maximum traversal depth (0 = unlimited).
    /// - Returns: The number of items `XCAFDoc_AssemblyIterator` visits, `0` if the document is
    ///   null or OCCT raised, and `nil` when the walk hit its 100,000-item bound so the number
    ///   would be a floor rather than a count (#964).
    ///
    /// The bound exists because `XCAFDoc_AssemblyIterator` keeps no visited set, so a malformed
    /// self-referencing assembly would iterate to `INT_MAX` depth. It is reported rather than
    /// returned silently: before #964 a document with more items answered `100001`,
    /// indistinguishable from one that genuinely had that many.
    public func assemblyItemCount(maxDepth: Int = 0) -> Int? {
        var truncated = false
        let count = Int(OCCTDocumentAssemblyItemCount(handle, Int32(maxDepth), &truncated))
        return truncated ? nil : count
    }
}

// MARK: - XCAFDoc_DimTol (v0.90.0)

extension Document {

    /// Set a dimension/tolerance attribute on a label.
    ///
    /// - labelId: Label to set on.
    /// - kind: Dimension/tolerance type code.
    /// - values: Array of numeric values.
    /// - name: Name string.
    /// - description: Description string.
    ///
    /// - Parameters:
    @discardableResult
    public func setDimTol(
        labelId: Int64, kind: Int32, values: [Double],
        name: String, description: String
    ) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetDimTol(
                handle, labelId, kind,
                buf.baseAddress!, Int32(values.count),
                name, description)
        }
    }

    /// Get the kind of a DimTol attribute.
    ///
    ///
    /// Returns nil if not found.
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

// MARK: - TDataXtd_Constraint (v0.92.0)

extension Document {

    /// Constraint type enum matching TDataXtd_ConstraintEnum.
    public enum ConstraintType: Int32 {
        case radius = 0
        case diameter, minorRadius, majorRadius
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

    /// Get the constraint type.
    ///
    ///
    /// Returns nil if not found.
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

    /// Get pattern signature.
    ///
    ///
    /// Returns nil if not found.
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

    /// Get subshape index.
    ///
    ///
    /// Returns nil if not set.
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

// MARK: - XCAFPrs_DocumentExplorer extensions (v0.105.0)

extension Document {
    /// Get the depth of a document explorer node at given index.
    public func explorerDepth(at index: Int) -> Int {
        Int(OCCTDocumentExplorerDepth(handle, Int32(index)))
    }

    /// Whether the explorer node at `index` is an assembly node. Always `false`.
    ///
    /// This shares the same flat index as `explorerShape(at:)`/`explorerDepth(at:)`/
    /// `explorerLocation(at:)`, all built by walking with
    /// `XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes`, so no index this family can be asked about
    /// is ever an assembly node. To detect an assembly, use ``AssemblyNode/isAssembly`` (via
    /// ``node(at:)``), which walks the real free-shape/component label tree instead of this
    /// flat leaf-only list. #1480.
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

// MARK: - GLTF Import/Export (v0.121.0)

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
    ///
    /// - url: Output file URL (.gltf or .glb).
    /// - binary: If true, writes binary GLB.
    ///
    /// If false, writes text GLTF.
    ///
    /// - Parameters:
    public func writeGLTF(to url: URL, binary: Bool = true) -> Bool {
        OCCTDocumentWriteGLTF(handle, url.path, binary)
    }
}

// MARK: - XCAFDoc_ColorTool and ShapeTool completions (v0.126.0)

extension Document {
    /// Add a color to the document color table.
    ///
    ///
    /// Returns label tag or -1 on failure.
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

    /// Unset color of a specific type from a label.
    ///
    ///
    /// type: 0=generic, 1=surface, 2=curve.
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

    /// Find a color in the color table.
    ///
    ///
    /// Returns label tag or -1 if not found.
    public func colorToolFindColor(r: Double, g: Double, b: Double) -> Int64 {
        OCCTDocumentColorToolFindColor(handle, r, g, b)
    }

    /// Set instance color on a shape component.
    @discardableResult
    public func colorToolSetInstanceColor(
        shape: Shape, colorType: Int, r: Double, g: Double, b: Double
    ) -> Bool {
        OCCTDocumentColorToolSetInstanceColor(handle, shape.handle, Int32(colorType), r, g, b)
    }

    /// Get instance color of a shape component.
    ///
    ///
    /// Returns (r,g,b) or nil.
    public func colorToolGetInstanceColor(shape: Shape, colorType: Int) -> (
        r: Double, g: Double, b: Double
    )? {
        var r = 0.0
        var g = 0.0
        var b = 0.0
        guard
            OCCTDocumentColorToolGetInstanceColor(
                handle, shape.handle, Int32(colorType), &r, &g, &b)
        else { return nil }
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
    ///
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
