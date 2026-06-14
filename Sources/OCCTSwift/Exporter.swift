import Foundation
import OCCTBridge

/// Export shapes to various file formats.
///
/// ## Supported Formats
///
/// - **STL**: Standard Tessellation Language - for 3D printing
/// - **STEP**: Standard for Exchange of Product Data - for CAD interoperability
///
/// ## STL Export
///
/// ```swift
/// let shape = Shape.box(width: 10, height: 5, depth: 3)
/// try Exporter.writeSTL(
///     shape: shape,
///     to: URL(fileURLWithPath: "box.stl"),
///     deflection: 0.05
/// )
/// ```
///
/// ## STEP Export
///
/// ```swift
/// try Exporter.writeSTEP(
///     shape: trackAssembly,
///     to: URL(fileURLWithPath: "track.step"),
///     name: "TrackSection"
/// )
/// ```
public enum Exporter {

    // MARK: - STL Export

    /// Export errors
    public enum ExportError: Error, LocalizedError {
        case exportFailed(String)
        case invalidPath
        case invalidShape
        /// The export was cancelled cooperatively via `ImportProgress.shouldCancel()`.
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .exportFailed(let message):
                return "Export failed: \(message)"
            case .invalidPath:
                return "Invalid file path"
            case .invalidShape:
                return "Shape is invalid or empty"
            case .cancelled:
                return "Export cancelled"
            }
        }
    }

    /// Export a shape to STL format for 3D printing.
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - url: Destination file URL (should end in .stl)
    ///   - deflection: Tessellation quality - smaller = finer mesh (default: 0.1)
    ///   - ascii: If true, write ASCII STL; if false, write binary (default: false)
    ///
    /// - Throws: `ExportError` if export fails
    ///
    /// ## Deflection Guidelines
    ///
    /// | Use Case | Deflection | Notes |
    /// |----------|------------|-------|
    /// | Preview | 0.5 | Fast, low detail |
    /// | FDM printing | 0.1 | Good for 0.2mm layers |
    /// | High detail FDM | 0.05 | For 0.1mm layers |
    /// | SLA printing | 0.02 | High detail |
    ///
    /// ## Example
    ///
    /// ```swift
    /// let rail = Shape.sweep(profile: railProfile, along: trackPath)
    ///
    /// // For 3D printing
    /// try Exporter.writeSTL(
    ///     shape: rail,
    ///     to: documentsURL.appendingPathComponent("rail.stl"),
    ///     deflection: 0.05
    /// )
    /// ```
    public static func writeSTL(
        shape: Shape,
        to url: URL,
        deflection: Double = 0.1,
        ascii: Bool = false
    ) throws {
        guard shape.isValid else {
            throw ExportError.invalidShape
        }

        let path = url.path
        guard !path.isEmpty else {
            throw ExportError.invalidPath
        }

        let success = OCCTExportSTLWithMode(shape.handle, path, deflection, ascii)
        if !success {
            throw ExportError.exportFailed("STL export to \(url.lastPathComponent) failed")
        }
    }

    /// Export a shape to STL and return the data.
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - deflection: Tessellation quality
    ///
    /// - Returns: STL file data
    /// - Throws: `ExportError` if export fails
    ///
    /// Useful for sharing without writing to disk:
    ///
    /// ```swift
    /// let data = try Exporter.stlData(shape: myShape)
    /// // Share via AirDrop, email, etc.
    /// ```
    public static func stlData(
        shape: Shape,
        deflection: Double = 0.1
    ) throws -> Data {
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("stl")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try writeSTL(shape: shape, to: tempURL, deflection: deflection)
        return try Data(contentsOf: tempURL)
    }

    // MARK: - STEP Export

    /// Export a shape to STEP format for CAD interoperability.
    ///
    /// STEP (Standard for the Exchange of Product Data) is the industry
    /// standard format for exchanging CAD data between different software.
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - url: Destination file URL (should end in .step or .stp)
    ///   - name: Optional name for the shape in the STEP file
    ///
    /// - Throws: `ExportError` if export fails
    ///
    /// ## Use Cases
    ///
    /// - Import into Fusion 360, SolidWorks, FreeCAD
    /// - CNC machining workflows
    /// - Archiving exact geometry (not tessellated)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let turnout = buildTurnoutAssembly()
    ///
    /// try Exporter.writeSTEP(
    ///     shape: turnout,
    ///     to: projectURL.appendingPathComponent("turnout_8.step"),
    ///     name: "Number8Turnout"
    /// )
    /// ```
    ///
    /// ## Notes
    ///
    /// - STEP preserves exact B-Rep geometry (not tessellated)
    /// - File sizes are typically larger than STL
    /// - Includes topological information (faces, edges, vertices)
    public static func writeSTEP(
        shape: Shape,
        to url: URL,
        name: String? = nil
    ) throws {
        guard shape.isValid else {
            throw ExportError.invalidShape
        }

        let path = url.path
        guard !path.isEmpty else {
            throw ExportError.invalidPath
        }

        let success: Bool
        if let name = name {
            success = OCCTExportSTEPWithName(shape.handle, path, name)
        } else {
            success = OCCTExportSTEP(shape.handle, path)
        }

        if !success {
            throw ExportError.exportFailed("STEP export to \(url.lastPathComponent) failed")
        }
    }

    /// Export a shape to STEP with progress + cancellation.
    ///
    /// - Throws: `ExportError.cancelled` if cancelled cooperatively, `ExportError.exportFailed`
    ///   on other failure, `ExportError.invalidShape` / `.invalidPath` on bad inputs.
    public static func writeSTEP(
        shape: Shape,
        to url: URL,
        progress: ImportProgress?
    ) throws {
        guard shape.isValid else { throw ExportError.invalidShape }
        let path = url.path
        guard !path.isEmpty else { throw ExportError.invalidPath }

        var cancelled: Bool = false
        let success: Bool = withImportProgress(progress) { ctx in
            OCCTExportSTEPProgress(shape.handle, path, ctx, &cancelled)
        }
        if cancelled { throw ExportError.cancelled }
        if !success {
            throw ExportError.exportFailed("STEP export to \(url.lastPathComponent) failed")
        }
    }

    /// Export a shape to IGES with progress + cancellation.
    public static func writeIGES(
        shape: Shape,
        to url: URL,
        progress: ImportProgress?
    ) throws {
        guard shape.isValid else { throw ExportError.invalidShape }
        let path = url.path
        guard !path.isEmpty else { throw ExportError.invalidPath }

        var cancelled: Bool = false
        let success: Bool = withImportProgress(progress) { ctx in
            OCCTExportIGESProgress(shape.handle, path, ctx, &cancelled)
        }
        if cancelled { throw ExportError.cancelled }
        if !success {
            throw ExportError.exportFailed("IGES export to \(url.lastPathComponent) failed")
        }
    }

    /// Export a shape to STEP and return the data.
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - name: Optional name for the shape
    ///
    /// - Returns: STEP file data
    /// - Throws: `ExportError` if export fails
    public static func stepData(
        shape: Shape,
        name: String? = nil
    ) throws -> Data {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("step")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try writeSTEP(shape: shape, to: tempURL, name: name)
        return try Data(contentsOf: tempURL)
    }

    // MARK: - IGES Export (v0.10.0)

    /// Export a shape to IGES format.
    ///
    /// IGES (Initial Graphics Exchange Specification) is a legacy CAD format
    /// still commonly used in manufacturing and older CAD systems.
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - url: Destination file URL (should end in .igs or .iges)
    ///
    /// - Throws: `ExportError` if export fails
    ///
    /// ## Use Cases
    ///
    /// - Legacy CAD system compatibility
    /// - CNC machines with IGES-only post processors
    /// - Exchanging data with older software
    public static func writeIGES(
        shape: Shape,
        to url: URL
    ) throws {
        guard shape.isValid else {
            throw ExportError.invalidShape
        }

        let path = url.path
        guard !path.isEmpty else {
            throw ExportError.invalidPath
        }

        let success = OCCTExportIGES(shape.handle, path)
        if !success {
            throw ExportError.exportFailed("IGES export to \(url.lastPathComponent) failed")
        }
    }

    /// Export a shape to IGES and return the data.
    public static func igesData(shape: Shape) throws -> Data {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("igs")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try writeIGES(shape: shape, to: tempURL)
        return try Data(contentsOf: tempURL)
    }

    // MARK: - IGES Export Expansion (v0.59.0)

    /// Export a shape to IGES with a specific unit.
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - url: Destination file URL
    ///   - unit: Unit string ("MM", "IN", "M", "FT", etc.)
    public static func writeIGES(shape: Shape, to url: URL, unit: String) throws {
        let path = url.path
        guard !path.isEmpty else { throw ExportError.invalidPath }
        if !OCCTExportIGESWithUnit(shape.handle, path, unit) {
            throw ExportError.exportFailed("IGES export with unit \(unit) failed")
        }
    }

    /// Export a shape to IGES in BRep mode (exact geometry, not tessellated faces).
    public static func writeIGESBRep(shape: Shape, to url: URL) throws {
        let path = url.path
        guard !path.isEmpty else { throw ExportError.invalidPath }
        if !OCCTExportIGESBRepMode(shape.handle, path) {
            throw ExportError.exportFailed("IGES BRep export failed")
        }
    }

    /// Export multiple shapes to a single IGES file.
    public static func writeIGES(shapes: [Shape], to url: URL) throws {
        let path = url.path
        guard !path.isEmpty else { throw ExportError.invalidPath }
        var handles: [OCCTShapeRef?] = shapes.map { $0.handle }
        let success = handles.withUnsafeMutableBufferPointer { buffer in
            OCCTExportIGESMultiShape(buffer.baseAddress, Int32(buffer.count), path)
        }
        if !success {
            throw ExportError.exportFailed("IGES multi-shape export failed")
        }
    }

    // MARK: - PLY Export Expansion (v0.59.0)

    /// Export a shape to PLY with control over normals, colors, and texture coordinates.
    public static func writePLY(shape: Shape, to url: URL, deflection: Double,
                                 normals: Bool = true, colors: Bool = false, texCoords: Bool = false) throws {
        let path = url.path
        guard !path.isEmpty else { throw ExportError.invalidPath }
        if !OCCTExportPLYWithOptions(shape.handle, path, deflection, normals, colors, texCoords) {
            throw ExportError.exportFailed("PLY export with options failed")
        }
    }

    // MARK: - BREP Export (v0.10.0)

    /// Export a shape to OCCT's native BREP format.
    ///
    /// BREP is OCCT's native format for exact B-Rep geometry. Benefits:
    /// - Preserves full precision of the geometry
    /// - Fast read/write (no format conversion)
    /// - Includes all topological information
    /// - Can optionally include triangulation data
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - url: Destination file URL (should end in .brep)
    ///   - withTriangles: Include triangulation data (default: true)
    ///   - withNormals: Include normals with triangulation (default: false)
    ///
    /// - Throws: `ExportError` if export fails
    ///
    /// ## Use Cases
    ///
    /// - Fast caching of intermediate geometry results
    /// - Debugging geometry issues
    /// - Archiving exact geometry for later processing
    public static func writeBREP(
        shape: Shape,
        to url: URL,
        withTriangles: Bool = true,
        withNormals: Bool = false
    ) throws {
        guard shape.isValid else {
            throw ExportError.invalidShape
        }

        let path = url.path
        guard !path.isEmpty else {
            throw ExportError.invalidPath
        }

        let success = OCCTExportBREPWithTriangles(shape.handle, path, withTriangles, withNormals)
        if !success {
            throw ExportError.exportFailed("BREP export to \(url.lastPathComponent) failed")
        }
    }

    /// Export a shape to BREP and return the data.
    public static func brepData(
        shape: Shape,
        withTriangles: Bool = true,
        withNormals: Bool = false
    ) throws -> Data {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("brep")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try writeBREP(shape: shape, to: tempURL, withTriangles: withTriangles, withNormals: withNormals)
        return try Data(contentsOf: tempURL)
    }

    // MARK: - OBJ Export (v0.17.0)

    /// Export a shape to OBJ format.
    ///
    /// OBJ (Wavefront) is a widely supported mesh format for 3D visualization
    /// and modeling applications.
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - url: Destination file URL (should end in .obj)
    ///   - deflection: Tessellation quality - smaller = finer mesh (default: 0.1)
    ///
    /// - Throws: `ExportError` if export fails
    public static func writeOBJ(
        shape: Shape,
        to url: URL,
        deflection: Double = 0.1
    ) throws {
        guard shape.isValid else {
            throw ExportError.invalidShape
        }

        let path = url.path
        guard !path.isEmpty else {
            throw ExportError.invalidPath
        }

        let success = OCCTExportOBJ(shape.handle, path, deflection)
        if !success {
            throw ExportError.exportFailed("OBJ export to \(url.lastPathComponent) failed")
        }
    }

    // MARK: - PLY Export (v0.17.0)

    /// Export a shape to PLY format (Stanford Polygon Format).
    ///
    /// PLY is a simple mesh format commonly used for 3D scanning data
    /// and point cloud applications.
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - url: Destination file URL (should end in .ply)
    ///   - deflection: Tessellation quality - smaller = finer mesh (default: 0.1)
    ///
    /// - Throws: `ExportError` if export fails
    public static func writePLY(
        shape: Shape,
        to url: URL,
        deflection: Double = 0.1
    ) throws {
        guard shape.isValid else {
            throw ExportError.invalidShape
        }

        let path = url.path
        guard !path.isEmpty else {
            throw ExportError.invalidPath
        }

        let success = OCCTExportPLY(shape.handle, path, deflection)
        if !success {
            throw ExportError.exportFailed("PLY export to \(url.lastPathComponent) failed")
        }
    }

    // MARK: - STEP Export with Model Type (v0.58.0)

    /// Export a shape to STEP with a specific model type.
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - url: Destination file URL
    ///   - modelType: STEP representation type
    public static func writeSTEP(shape: Shape, to url: URL, modelType: StepModelType) throws {
        let path = url.path
        guard !path.isEmpty else { throw ExportError.invalidPath }
        if !OCCTExportSTEPWithMode(shape.handle, path, modelType.rawValue) {
            throw ExportError.exportFailed("STEP export with mode \(modelType) failed")
        }
    }

    /// Export a shape to STEP with a specific model type and tolerance.
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - url: Destination file URL
    ///   - modelType: STEP representation type
    ///   - tolerance: Geometric tolerance for the transfer
    public static func writeSTEP(shape: Shape, to url: URL, modelType: StepModelType, tolerance: Double) throws {
        let path = url.path
        guard !path.isEmpty else { throw ExportError.invalidPath }
        if !OCCTExportSTEPWithModeAndTolerance(shape.handle, path, modelType.rawValue, tolerance) {
            throw ExportError.exportFailed("STEP export with mode and tolerance failed")
        }
    }

    /// Export a shape to STEP with duplicate entity cleanup.
    ///
    /// This merges duplicate geometric entities during export, reducing file size.
    ///
    /// - Parameters:
    ///   - shape: The shape to export
    ///   - url: Destination file URL
    ///   - modelType: STEP representation type (default: .asIs)
    public static func writeSTEPCleanDuplicates(shape: Shape, to url: URL, modelType: StepModelType = .asIs) throws {
        let path = url.path
        guard !path.isEmpty else { throw ExportError.invalidPath }
        if !OCCTExportSTEPCleanDuplicates(shape.handle, path, modelType.rawValue) {
            throw ExportError.exportFailed("STEP export with clean duplicates failed")
        }
    }

    // MARK: - Instanced Assembly STEP Export (#173)

    /// Write an XCAF `Document` as a **product-structured STEP assembly**.
    ///
    /// Unlike `writeSTEP(shape:to:)`, which flattens geometry, this preserves the document's
    /// assembly tree: each unique part label is written once as a STEP product
    /// (`PRODUCT` / `PRODUCT_DEFINITION`) and is referenced by its located component
    /// occurrences (`NEXT_ASSEMBLY_USAGE_OCCURRENCE` + each component's `TopLoc_Location`).
    /// File size therefore scales with the number of *unique parts*, not total placements —
    /// a part placed N times stores one `MANIFOLD_SOLID_BREP`, not N copies — and the file
    /// opens as an editable assembly in standard CAD viewers. Component names and colors set
    /// on the document are written too.
    ///
    /// Build the assembly with `Document.addShape(_:makeAssembly:)` for the part prototypes
    /// and `Document.addComponent(assemblyLabelId:shapeLabelId:matrix:)` for each full-rigid
    /// (rotation + translation) placement, then call this. The output uses the AP214 schema,
    /// matching the rest of the STEP writers.
    ///
    /// - Parameters:
    ///   - document: The XCAF document holding the assembly tree.
    ///   - url: Destination file URL.
    /// - Throws: `ExportError.invalidPath` for an empty path, `ExportError.exportFailed`
    ///   if the STEP transfer/write fails.
    public static func writeSTEPAssembly(_ document: Document, to url: URL) throws {
        guard !url.path.isEmpty else { throw ExportError.invalidPath }
        if !document.writeSTEP(to: url) {
            throw ExportError.exportFailed("STEP assembly export to \(url.lastPathComponent) failed")
        }
    }

    // MARK: - STEP Optimization (v0.28.0)

    /// Optimize a STEP file by merging duplicate geometric entities.
    ///
    /// Reads a STEP file, deduplicates shared geometry (surfaces, curves, etc.),
    /// and writes the optimized result. This can significantly reduce file size
    /// for models with repeated geometry.
    ///
    /// - Parameters:
    ///   - input: URL of the input STEP file
    ///   - output: URL for the optimized output STEP file
    /// - Throws: `ExportError` if optimization fails
    public static func optimizeSTEP(input: URL, output: URL) throws {
        let inPath = input.path
        let outPath = output.path
        guard !inPath.isEmpty, !outPath.isEmpty else {
            throw ExportError.invalidPath
        }
        if !OCCTStepTidyOptimize(inPath, outPath) {
            throw ExportError.exportFailed("STEP optimization failed")
        }
    }
}

// MARK: - Convenience Extensions

extension Shape {
    /// Export this shape to STL format.
    ///
    /// Convenience method equivalent to `Exporter.writeSTL(shape: self, ...)`.
    ///
    /// - Parameters:
    ///   - url: Destination file URL
    ///   - deflection: Tessellation quality (default: 0.1)
    public func writeSTL(to url: URL, deflection: Double = 0.1) throws {
        try Exporter.writeSTL(shape: self, to: url, deflection: deflection)
    }

    /// Export this shape to STEP format.
    ///
    /// Convenience method equivalent to `Exporter.writeSTEP(shape: self, ...)`.
    ///
    /// - Parameters:
    ///   - url: Destination file URL
    ///   - name: Optional name for the shape
    public func writeSTEP(to url: URL, name: String? = nil) throws {
        try Exporter.writeSTEP(shape: self, to: url, name: name)
    }

    // MARK: - STEP Export with Model Type (v0.58.0)

    /// Export this shape to STEP with a specific model type.
    public func writeSTEP(to url: URL, modelType: StepModelType) throws {
        try Exporter.writeSTEP(shape: self, to: url, modelType: modelType)
    }

    /// Export this shape to STEP with a specific model type and tolerance.
    public func writeSTEP(to url: URL, modelType: StepModelType, tolerance: Double) throws {
        try Exporter.writeSTEP(shape: self, to: url, modelType: modelType, tolerance: tolerance)
    }

    /// Export this shape to STEP with duplicate entity cleanup.
    public func writeSTEPCleanDuplicates(to url: URL, modelType: StepModelType = .asIs) throws {
        try Exporter.writeSTEPCleanDuplicates(shape: self, to: url, modelType: modelType)
    }

    /// Get STL data for this shape.
    ///
    /// - Parameter deflection: Tessellation quality (default: 0.1)
    /// - Returns: STL file data
    public func stlData(deflection: Double = 0.1) throws -> Data {
        try Exporter.stlData(shape: self, deflection: deflection)
    }

    /// Get STEP data for this shape.
    ///
    /// - Parameter name: Optional name for the shape
    /// - Returns: STEP file data
    public func stepData(name: String? = nil) throws -> Data {
        try Exporter.stepData(shape: self, name: name)
    }

    // MARK: - IGES Export (v0.10.0)

    /// Export this shape to IGES format.
    ///
    /// - Parameter url: Destination file URL
    public func writeIGES(to url: URL) throws {
        try Exporter.writeIGES(shape: self, to: url)
    }

    /// Get IGES data for this shape.
    public func igesData() throws -> Data {
        try Exporter.igesData(shape: self)
    }

    // MARK: - IGES Export Expansion (v0.59.0)

    /// Export this shape to IGES with a specific unit.
    public func writeIGES(to url: URL, unit: String) throws {
        try Exporter.writeIGES(shape: self, to: url, unit: unit)
    }

    /// Export this shape to IGES in BRep mode.
    public func writeIGESBRep(to url: URL) throws {
        try Exporter.writeIGESBRep(shape: self, to: url)
    }

    // MARK: - PLY Export Expansion (v0.59.0)

    /// Export this shape to PLY with options.
    public func writePLY(to url: URL, deflection: Double,
                          normals: Bool = true, colors: Bool = false, texCoords: Bool = false) throws {
        try Exporter.writePLY(shape: self, to: url, deflection: deflection,
                               normals: normals, colors: colors, texCoords: texCoords)
    }

    // MARK: - BREP Export (v0.10.0)

    /// Export this shape to OCCT's native BREP format.
    ///
    /// - Parameters:
    ///   - url: Destination file URL
    ///   - withTriangles: Include triangulation data (default: true)
    ///   - withNormals: Include normals with triangulation (default: false)
    public func writeBREP(to url: URL, withTriangles: Bool = true, withNormals: Bool = false) throws {
        try Exporter.writeBREP(shape: self, to: url, withTriangles: withTriangles, withNormals: withNormals)
    }

    /// Get BREP data for this shape.
    ///
    /// - Parameters:
    ///   - withTriangles: Include triangulation data (default: true)
    ///   - withNormals: Include normals with triangulation (default: false)
    public func brepData(withTriangles: Bool = true, withNormals: Bool = false) throws -> Data {
        try Exporter.brepData(shape: self, withTriangles: withTriangles, withNormals: withNormals)
    }

    // MARK: - OBJ Export (v0.17.0)

    /// Export this shape to OBJ format.
    ///
    /// - Parameters:
    ///   - url: Destination file URL
    ///   - deflection: Tessellation quality (default: 0.1)
    public func writeOBJ(to url: URL, deflection: Double = 0.1) throws {
        try Exporter.writeOBJ(shape: self, to: url, deflection: deflection)
    }

    // MARK: - PLY Export (v0.17.0)

    /// Export this shape to PLY format.
    ///
    /// - Parameters:
    ///   - url: Destination file URL
    ///   - deflection: Tessellation quality (default: 0.1)
    public func writePLY(to url: URL, deflection: Double = 0.1) throws {
        try Exporter.writePLY(shape: self, to: url, deflection: deflection)
    }
}
