import Foundation
import simd
import OCCTBridge

/// A node in an XDE assembly tree
///
/// Represents a part or sub-assembly in a STEP file with:
/// - Name (if assigned in CAD software)
/// - Transform (position/rotation relative to parent)
/// - Color (if assigned)
/// - PBR Material (if available)
/// - Children (for assemblies)
/// - Shape (for parts)
public final class AssemblyNode: @unchecked Sendable {
    unowned let document: Document

    /// The XCAF label identifier for this node. Stable across calls within a
    /// single `Document` instance; round-trips with `Document.node(at:)`.
    public let labelId: Int64

    internal init(document: Document, labelId: Int64) {
        self.document = document
        self.labelId = labelId
    }

    /// The name of this node (from CAD software)
    public var name: String? {
        guard let cString = OCCTDocumentGetLabelName(document.handle, labelId) else {
            return nil
        }
        let result = String(cString: cString)
        OCCTStringFree(cString)
        return result
    }

    /// Whether this node is an assembly (has children)
    public var isAssembly: Bool {
        OCCTDocumentIsAssembly(document.handle, labelId)
    }

    /// Whether this node is a reference (instance of another shape)
    public var isReference: Bool {
        OCCTDocumentIsReference(document.handle, labelId)
    }

    /// Transform matrix (position/rotation relative to parent)
    public var transform: simd_float4x4 {
        var matrix = [Float](repeating: 0, count: 16)
        OCCTDocumentGetLocation(document.handle, labelId, &matrix)
        return simd_float4x4(
            SIMD4(matrix[0], matrix[1], matrix[2], matrix[3]),
            SIMD4(matrix[4], matrix[5], matrix[6], matrix[7]),
            SIMD4(matrix[8], matrix[9], matrix[10], matrix[11]),
            SIMD4(matrix[12], matrix[13], matrix[14], matrix[15])
        )
    }

    /// Color assigned to this node (if any)
    public var color: Color? {
        // Try surface color first, then generic
        var occtColor = OCCTDocumentGetLabelColor(document.handle, labelId, OCCTColorTypeSurface)
        if !occtColor.isSet {
            occtColor = OCCTDocumentGetLabelColor(document.handle, labelId, OCCTColorTypeGeneric)
        }

        guard occtColor.isSet else { return nil }

        return Color(red: occtColor.r, green: occtColor.g, blue: occtColor.b, alpha: occtColor.a)
    }

    /// Set the surface color on this node.
    ///
    /// - Parameter color: The color to assign
    public func setColor(_ color: Color) {
        OCCTDocumentSetLabelColor(document.handle, labelId, OCCTColorTypeSurface,
                                  color.red, color.green, color.blue)
    }

    /// Set the color on this node with a specific color type.
    ///
    /// - Parameters:
    ///   - color: The color to assign
    ///   - type: Color type — generic (0), surface (1), or curve (2)
    public func setColor(_ color: Color, type: OCCTColorType) {
        OCCTDocumentSetLabelColor(document.handle, labelId, type,
                                  color.red, color.green, color.blue)
    }

    /// Set the PBR material on this node.
    ///
    /// - Parameter material: The material properties to assign
    public func setMaterial(_ material: Material) {
        var occtMat = OCCTMaterial()
        occtMat.baseColor = OCCTColor(r: material.baseColor.red, g: material.baseColor.green,
                                       b: material.baseColor.blue, a: material.baseColor.alpha, isSet: true)
        occtMat.metallic = material.metallic
        occtMat.roughness = material.roughness
        if let emissive = material.emissive {
            occtMat.emissive = OCCTColor(r: emissive.red, g: emissive.green,
                                          b: emissive.blue, a: emissive.alpha, isSet: true)
        } else {
            occtMat.emissive = OCCTColor(r: 0, g: 0, b: 0, a: 1, isSet: false)
        }
        occtMat.transparency = material.transparency
        occtMat.isSet = true
        OCCTDocumentSetLabelMaterial(document.handle, labelId, occtMat)
    }

    /// PBR material assigned to this node (if any)
    public var material: Material? {
        let occtMat = OCCTDocumentGetLabelMaterial(document.handle, labelId)
        guard occtMat.isSet else { return nil }

        let baseColor = Color(
            red: occtMat.baseColor.r,
            green: occtMat.baseColor.g,
            blue: occtMat.baseColor.b,
            alpha: occtMat.baseColor.a
        )

        var emissive: Color? = nil
        if occtMat.emissive.isSet {
            emissive = Color(
                red: occtMat.emissive.r,
                green: occtMat.emissive.g,
                blue: occtMat.emissive.b,
                alpha: occtMat.emissive.a
            )
        }

        return Material(
            baseColor: baseColor,
            metallic: occtMat.metallic,
            roughness: occtMat.roughness,
            emissive: emissive,
            transparency: occtMat.transparency
        )
    }

    /// Child nodes (for assemblies)
    public var children: [AssemblyNode] {
        let count = OCCTDocumentGetChildCount(document.handle, labelId)
        var nodes: [AssemblyNode] = []
        nodes.reserveCapacity(Int(count))

        for i in 0..<count {
            let childLabelId = OCCTDocumentGetChildLabelId(document.handle, labelId, i)
            if childLabelId >= 0 {
                nodes.append(AssemblyNode(document: document, labelId: childLabelId))
            }
        }

        return nodes
    }

    /// The shape geometry (with transform applied)
    ///
    /// Returns nil for pure assemblies that have no direct geometry
    public var shape: Shape? {
        guard let shapeHandle = OCCTDocumentGetShapeWithLocation(document.handle, labelId) else {
            return nil
        }
        return Shape(handle: shapeHandle)
    }

    /// The shape geometry without transform (original definition)
    public var shapeWithoutTransform: Shape? {
        guard let shapeHandle = OCCTDocumentGetShape(document.handle, labelId) else {
            return nil
        }
        return Shape(handle: shapeHandle)
    }

    /// For references, get the referred node
    public var referredNode: AssemblyNode? {
        guard isReference else { return nil }
        let referredLabelId = OCCTDocumentGetReferredLabelId(document.handle, labelId)
        guard referredLabelId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: referredLabelId)
    }
}

extension AssemblyNode {
    /// The tag integer identifying this label among its siblings.
    public var tag: Int32 {
        OCCTDocumentLabelTag(document.handle, labelId)
    }

    /// The depth of this label in the tree (root=0, main=1, etc.).
    public var depth: Int32 {
        OCCTDocumentLabelDepth(document.handle, labelId)
    }

    /// Whether this label is null.
    public var isNull: Bool {
        OCCTDocumentLabelIsNull(document.handle, labelId)
    }

    /// Whether this label is the root label (0:).
    public var isRoot: Bool {
        OCCTDocumentLabelIsRoot(document.handle, labelId)
    }

    /// The parent (father) node of this label, or nil if root.
    public var father: AssemblyNode? {
        let fatherId = OCCTDocumentLabelFather(document.handle, labelId)
        guard fatherId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: fatherId)
    }

    /// The root node of the data framework.
    public var root: AssemblyNode? {
        let rootId = OCCTDocumentLabelRoot(document.handle, labelId)
        guard rootId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: rootId)
    }

    /// Whether this label has any attributes.
    public var hasAttribute: Bool {
        OCCTDocumentLabelHasAttribute(document.handle, labelId)
    }

    /// The number of attributes on this label.
    public var attributeCount: Int32 {
        OCCTDocumentLabelNbAttributes(document.handle, labelId)
    }

    /// Whether this label has any child labels.
    public var hasChild: Bool {
        OCCTDocumentLabelHasChild(document.handle, labelId)
    }

    /// The number of direct child labels.
    public var childCount: Int32 {
        OCCTDocumentLabelNbChildren(document.handle, labelId)
    }

    /// Find or create a child label by tag.
    ///
    /// - Parameters:
    ///   - tag: The tag to search for
    ///   - create: If true, create the child if it doesn't exist
    /// - Returns: The child node, or nil if not found and create is false
    public func findChild(tag: Int32, create: Bool = false) -> AssemblyNode? {
        let childId = OCCTDocumentLabelFindChild(document.handle, labelId, tag, create)
        guard childId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: childId)
    }

    /// Remove all attributes from this label.
    ///
    /// - Parameter clearChildren: If true, also clear attributes from child labels
    public func forgetAllAttributes(clearChildren: Bool = true) {
        OCCTDocumentLabelForgetAllAttributes(document.handle, labelId, clearChildren)
    }

    /// Get all descendant labels.
    ///
    /// - Parameter allLevels: If true, recurse all descendants; if false, direct children only
    /// - Returns: Array of descendant nodes
    public func descendants(allLevels: Bool = false) -> [AssemblyNode] {
        let maxCount: Int32 = 1024
        var labelIds = [Int64](repeating: -1, count: Int(maxCount))
        let count = OCCTDocumentGetDescendantLabels(document.handle, labelId,
                                                      allLevels, &labelIds, maxCount)
        return (0..<Int(count)).map { AssemblyNode(document: document, labelId: labelIds[$0]) }
    }

    /// Set the name (TDataStd_Name) on this label.
    ///
    /// - Parameter name: The name to set
    /// - Returns: true if the name was set successfully
    @discardableResult
    public func setName(_ name: String) -> Bool {
        OCCTDocumentSetLabelName(document.handle, labelId, name)
    }
}

extension AssemblyNode {
    /// Set a TDF_Reference from this label to another label.
    ///
    /// - Parameter target: The target label to reference
    /// - Returns: true if the reference was set
    @discardableResult
    public func setReference(to target: AssemblyNode) -> Bool {
        OCCTDocumentLabelSetReference(document.handle, labelId, target.labelId)
    }

    /// Get the label referenced by a TDF_Reference attribute on this label.
    ///
    /// - Returns: The referenced node, or nil if no reference exists
    public var referencedLabel: AssemblyNode? {
        let targetId = OCCTDocumentLabelGetReference(document.handle, labelId)
        guard targetId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: targetId)
    }
}

extension AssemblyNode {
    /// Set an integer attribute (TDataStd_Integer) on this label.
    @discardableResult
    public func setInteger(_ value: Int32) -> Bool {
        OCCTDocumentSetIntegerAttr(document.handle, labelId, value)
    }

    /// Get the integer attribute from this label.
    public var integer: Int32? {
        var value: Int32 = 0
        guard OCCTDocumentGetIntegerAttr(document.handle, labelId, &value) else { return nil }
        return value
    }

    /// Set a real attribute (TDataStd_Real) on this label.
    @discardableResult
    public func setReal(_ value: Double) -> Bool {
        OCCTDocumentSetRealAttr(document.handle, labelId, value)
    }

    /// Get the real attribute from this label.
    public var real: Double? {
        var value: Double = 0
        guard OCCTDocumentGetRealAttr(document.handle, labelId, &value) else { return nil }
        return value
    }

    /// Set an ASCII string attribute (TDataStd_AsciiString) on this label.
    @discardableResult
    public func setAsciiString(_ value: String) -> Bool {
        OCCTDocumentSetAsciiStringAttr(document.handle, labelId, value)
    }

    /// Get the ASCII string attribute from this label.
    public var asciiString: String? {
        guard let cStr = OCCTDocumentGetAsciiStringAttr(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Set a comment attribute (TDataStd_Comment) on this label.
    @discardableResult
    public func setComment(_ value: String) -> Bool {
        OCCTDocumentSetCommentAttr(document.handle, labelId, value)
    }

    /// Get the comment attribute from this label.
    public var comment: String? {
        guard let cStr = OCCTDocumentGetCommentAttr(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }
}

extension AssemblyNode {
    /// Initialize an integer array attribute on this label.
    ///
    /// - Parameters:
    ///   - lower: Lower bound index
    ///   - upper: Upper bound index
    @discardableResult
    public func initIntegerArray(lower: Int32, upper: Int32) -> Bool {
        OCCTDocumentInitIntegerArray(document.handle, labelId, lower, upper)
    }

    /// Set a value in the integer array attribute.
    @discardableResult
    public func setIntegerArrayValue(at index: Int32, value: Int32) -> Bool {
        OCCTDocumentSetIntegerArrayValue(document.handle, labelId, index, value)
    }

    /// Get a value from the integer array attribute.
    public func integerArrayValue(at index: Int32) -> Int32? {
        var value: Int32 = 0
        guard OCCTDocumentGetIntegerArrayValue(document.handle, labelId, index, &value) else { return nil }
        return value
    }

    /// Get the bounds of the integer array attribute.
    public var integerArrayBounds: (lower: Int32, upper: Int32)? {
        var lower: Int32 = 0, upper: Int32 = 0
        guard OCCTDocumentGetIntegerArrayBounds(document.handle, labelId, &lower, &upper) else { return nil }
        return (lower, upper)
    }
}

extension AssemblyNode {
    /// Initialize a real array attribute on this label.
    ///
    /// - Parameters:
    ///   - lower: Lower bound index
    ///   - upper: Upper bound index
    @discardableResult
    public func initRealArray(lower: Int32, upper: Int32) -> Bool {
        OCCTDocumentInitRealArray(document.handle, labelId, lower, upper)
    }

    /// Set a value in the real array attribute.
    @discardableResult
    public func setRealArrayValue(at index: Int32, value: Double) -> Bool {
        OCCTDocumentSetRealArrayValue(document.handle, labelId, index, value)
    }

    /// Get a value from the real array attribute.
    public func realArrayValue(at index: Int32) -> Double? {
        var value: Double = 0
        guard OCCTDocumentGetRealArrayValue(document.handle, labelId, index, &value) else { return nil }
        return value
    }

    /// Get the bounds of the real array attribute.
    public var realArrayBounds: (lower: Int32, upper: Int32)? {
        var lower: Int32 = 0, upper: Int32 = 0
        guard OCCTDocumentGetRealArrayBounds(document.handle, labelId, &lower, &upper) else { return nil }
        return (lower, upper)
    }
}

extension AssemblyNode {
    /// Set a tree node attribute (TDataStd_TreeNode) on this label.
    @discardableResult
    public func setTreeNode() -> Bool {
        OCCTDocumentSetTreeNode(document.handle, labelId)
    }

    /// Append a child to this tree node.
    @discardableResult
    public func appendTreeChild(_ child: AssemblyNode) -> Bool {
        OCCTDocumentAppendTreeChild(document.handle, labelId, child.labelId)
    }

    /// The father (parent) of this tree node.
    public var treeNodeFather: AssemblyNode? {
        let fatherId = OCCTDocumentTreeNodeFather(document.handle, labelId)
        guard fatherId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: fatherId)
    }

    /// The first child of this tree node.
    public var treeNodeFirstChild: AssemblyNode? {
        let firstId = OCCTDocumentTreeNodeFirst(document.handle, labelId)
        guard firstId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: firstId)
    }

    /// The next sibling of this tree node.
    public var treeNodeNext: AssemblyNode? {
        let nextId = OCCTDocumentTreeNodeNext(document.handle, labelId)
        guard nextId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: nextId)
    }

    /// Whether this tree node has a father.
    public var treeNodeHasFather: Bool {
        OCCTDocumentTreeNodeHasFather(document.handle, labelId)
    }

    /// The depth of this tree node (root=0).
    public var treeNodeDepth: Int32 {
        OCCTDocumentTreeNodeDepth(document.handle, labelId)
    }

    /// The number of children of this tree node.
    public var treeNodeChildCount: Int32 {
        OCCTDocumentTreeNodeNbChildren(document.handle, labelId)
    }
}

extension AssemblyNode {
    /// Set a named integer value on this label.
    @discardableResult
    public func setNamedInteger(_ name: String, value: Int32) -> Bool {
        OCCTDocumentNamedDataSetInteger(document.handle, labelId, name, value)
    }

    /// Get a named integer value from this label.
    public func namedInteger(_ name: String) -> Int32? {
        var value: Int32 = 0
        guard OCCTDocumentNamedDataGetInteger(document.handle, labelId, name, &value) else { return nil }
        return value
    }

    /// Check if a named integer exists on this label.
    public func hasNamedInteger(_ name: String) -> Bool {
        OCCTDocumentNamedDataHasInteger(document.handle, labelId, name)
    }

    /// Set a named real value on this label.
    @discardableResult
    public func setNamedReal(_ name: String, value: Double) -> Bool {
        OCCTDocumentNamedDataSetReal(document.handle, labelId, name, value)
    }

    /// Get a named real value from this label.
    public func namedReal(_ name: String) -> Double? {
        var value: Double = 0
        guard OCCTDocumentNamedDataGetReal(document.handle, labelId, name, &value) else { return nil }
        return value
    }

    /// Check if a named real exists on this label.
    public func hasNamedReal(_ name: String) -> Bool {
        OCCTDocumentNamedDataHasReal(document.handle, labelId, name)
    }

    /// Set a named string value on this label.
    @discardableResult
    public func setNamedString(_ name: String, value: String) -> Bool {
        OCCTDocumentNamedDataSetString(document.handle, labelId, name, value)
    }

    /// Get a named string value from this label.
    public func namedString(_ name: String) -> String? {
        guard let cStr = OCCTDocumentNamedDataGetString(document.handle, labelId, name) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Check if a named string exists on this label.
    public func hasNamedString(_ name: String) -> Bool {
        OCCTDocumentNamedDataHasString(document.handle, labelId, name)
    }
}

/// Geometry type for TDataXtd_Geometry attributes.
public enum GeometryType: Int32 {
    case anyGeom = 0
    case point = 1
    case line = 2
    case circle = 3
    case ellipse = 4
    case spline = 5
    case plane = 6
    case cylinder = 7
}

/// Execution status for TFunction graph nodes.
public enum ExecutionStatus: Int32 {
    case wrongDefinition = 0
    case notExecuted = 1
    case executing = 2
    case succeeded = 3
    case failed = 4
}

extension AssemblyNode {

    // MARK: - TDataXtd Shape Attribute

    /// Set a shape attribute on this label (stores shape via TNaming).
    @discardableResult
    public func setShapeAttribute(_ shape: Shape) -> Bool {
        OCCTDocumentSetShapeAttr(document.handle, labelId, shape.handle)
    }

    /// Get the shape stored in a TDataXtd_Shape attribute on this label.
    public func shapeAttribute() -> Shape? {
        guard let ref = OCCTDocumentGetShapeAttr(document.handle, labelId) else { return nil }
        return Shape(handle: ref)
    }

    /// Check if this label has a TDataXtd_Shape attribute.
    public var hasShapeAttribute: Bool {
        OCCTDocumentHasShapeAttr(document.handle, labelId)
    }

    // MARK: - TDataXtd Position Attribute

    /// Set a position (3D point) attribute on this label.
    @discardableResult
    public func setPositionAttribute(x: Double, y: Double, z: Double) -> Bool {
        OCCTDocumentSetPositionAttr(document.handle, labelId, x, y, z)
    }

    /// Get the position attribute from this label.
    public func positionAttribute() -> (x: Double, y: Double, z: Double)? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTDocumentGetPositionAttr(document.handle, labelId, &x, &y, &z) else { return nil }
        return (x, y, z)
    }

    /// Check if this label has a TDataXtd_Position attribute.
    public var hasPositionAttribute: Bool {
        OCCTDocumentHasPositionAttr(document.handle, labelId)
    }

    // MARK: - TDataXtd Geometry Attribute

    /// Set a geometry type attribute on this label.
    @discardableResult
    public func setGeometryType(_ type: GeometryType) -> Bool {
        OCCTDocumentSetGeometryAttr(document.handle, labelId, type.rawValue)
    }

    /// Get the geometry type from this label.
    public func geometryType() -> GeometryType? {
        let raw = OCCTDocumentGetGeometryType(document.handle, labelId)
        guard raw >= 0 else { return nil }
        return GeometryType(rawValue: raw)
    }

    /// Check if this label has a TDataXtd_Geometry attribute.
    public var hasGeometryAttribute: Bool {
        OCCTDocumentHasGeometryAttr(document.handle, labelId)
    }

    // MARK: - TDataXtd Triangulation Attribute

    /// Set a triangulation attribute on this label by meshing a shape.
    ///
    /// Meshes the shape and stores **every** face's triangulation, merged into one
    /// `Poly_Triangulation` in the shape's own coordinate system: per-face locations are
    /// applied to the nodes, and reversed faces have their winding and node normals flipped
    /// so the stored mesh is consistently outward. Node normals survive only if every
    /// contributing face carries them; per-face UV nodes are dropped, since they index
    /// parameter spaces that no longer mean anything once the faces are pooled.
    ///
    /// - Important: **The stored coordinate frame changed in the same release as the
    ///   every-face fix.** This previously stored one face's nodes in that *face's* local
    ///   frame, discarding its `TopLoc_Location`. It now stores them in the **shape's**
    ///   frame. For a shape with a non-identity location (an assembly component, anything
    ///   from ``Shape/transformed(by:)``) the numbers therefore move, independently of the
    ///   node-count change: a box translated to (100, 200, 300) used to store a node at the
    ///   origin and now stores it at (100, 200, 300). Re-read any persisted OCAF document
    ///   that was written before this change if you compare stored triangulations.
    ///
    /// - Note: Node normals are transformed and reversed here, which
    ///   ``Shape/mesh(linearDeflection:angularDeflection:)`` does not do for its own
    ///   ``Mesh/normals`` (only its winding swap matches). The two therefore disagree for a
    ///   located or reversed face. `BRepMesh_IncrementalMesh` does not produce node normals
    ///   at all, so this only arises for a face carrying a triangulation from elsewhere,
    ///   such as glTF import.
    ///
    /// ```swift
    /// let label = doc.createLabel()!
    /// label.setTriangulationFromShape(Shape.box(width: 10, height: 10, depth: 10)!,
    ///                                 deflection: 1.0)
    /// print(label.triangulationNodeCount)      // 24, all six faces, not 4
    /// print(label.triangulationTriangleCount)  // 12
    /// ```
    ///
    /// - Parameters:
    ///   - shape: The shape to mesh. Faces at any depth are included.
    ///   - deflection: Linear meshing deflection (default: 1.0).
    /// - Returns: `false` if the shape has no face, or if nothing in it meshed.
    @discardableResult
    public func setTriangulationFromShape(_ shape: Shape, deflection: Double = 1.0) -> Bool {
        OCCTDocumentSetTriangulationFromShape(document.handle, labelId, shape.handle, deflection)
    }

    /// Get the number of nodes in the triangulation attribute.
    public var triangulationNodeCount: Int32 {
        OCCTDocumentTriangulationNbNodes(document.handle, labelId)
    }

    /// Get the number of triangles in the triangulation attribute.
    public var triangulationTriangleCount: Int32 {
        OCCTDocumentTriangulationNbTriangles(document.handle, labelId)
    }

    /// Get the deflection of the triangulation attribute.
    public var triangulationDeflection: Double {
        OCCTDocumentTriangulationDeflection(document.handle, labelId)
    }

    /// Read one node of the triangulation attribute, in the frame it was stored in.
    ///
    /// Nodes are numbered from 1, as `Poly_Triangulation` numbers them.
    /// ``setTriangulationFromShape(_:deflection:)`` stores them in the **shape's** coordinate
    /// frame, so a located shape's nodes come back in absolute coordinates.
    ///
    /// ```swift
    /// let moved = Shape.box(width: 10, height: 10, depth: 10)!.moved(dx: 100, dy: 200, dz: 300)!
    /// label.setTriangulationFromShape(moved, deflection: 1.0)
    /// let node = label.triangulationNode(at: 1)!   // absolute, not the box's local frame
    /// ```
    ///
    /// - Parameter index: 1-based node index.
    /// - Returns: The node position, or `nil` if this label has no triangulation attribute or
    ///   `index` is out of range.
    public func triangulationNode(at index: Int32) -> SIMD3<Double>? {
        var xyz = [Double](repeating: 0, count: 3)
        guard OCCTDocumentTriangulationNode(document.handle, labelId, index, &xyz) else {
            return nil
        }
        return SIMD3(xyz[0], xyz[1], xyz[2])
    }

    /// Read one node normal of the triangulation attribute, in the frame it was stored in.
    ///
    /// Node normals only exist when the meshed faces carried them.
    /// `BRepMesh_IncrementalMesh` does not produce any, so this returns `nil` for anything
    /// meshed from B-Rep, and a value for a shape whose faces arrived with a triangulation
    /// from elsewhere, such as glTF import.
    ///
    /// ```swift
    /// let imported = Shape.loadGLTF(from: url)!    // glTF meshes carry vertex normals
    /// label.setTriangulationFromShape(imported, deflection: 1.0)
    /// let n = label.triangulationNode(at: 1).flatMap { _ in label.triangulationNormal(at: 1) }
    /// ```
    ///
    /// - Parameter index: 1-based node index.
    /// - Returns: The unit normal, or `nil` if this label has no triangulation attribute, the
    ///   stored triangulation has no node normals, or `index` is out of range.
    public func triangulationNormal(at index: Int32) -> SIMD3<Double>? {
        var xyz = [Double](repeating: 0, count: 3)
        guard OCCTDocumentTriangulationNormal(document.handle, labelId, index, &xyz) else {
            return nil
        }
        return SIMD3(xyz[0], xyz[1], xyz[2])
    }

    // MARK: - TDataXtd Point/Axis/Plane Attributes

    /// Set a point attribute on this label.
    @discardableResult
    public func setPointAttribute(x: Double, y: Double, z: Double) -> Bool {
        OCCTDocumentSetPointAttr(document.handle, labelId, x, y, z)
    }

    /// Set an axis attribute on this label (origin + direction).
    @discardableResult
    public func setAxisAttribute(originX: Double, originY: Double, originZ: Double,
                                  directionX: Double, directionY: Double, directionZ: Double) -> Bool {
        OCCTDocumentSetAxisAttr(document.handle, labelId, originX, originY, originZ, directionX, directionY, directionZ)
    }

    /// Set a plane attribute on this label (origin + normal).
    @discardableResult
    public func setPlaneAttribute(originX: Double, originY: Double, originZ: Double,
                                   normalX: Double, normalY: Double, normalZ: Double) -> Bool {
        OCCTDocumentSetPlaneAttr(document.handle, labelId, originX, originY, originZ, normalX, normalY, normalZ)
    }
}

extension AssemblyNode {

    /// Create a TFunction_Logbook attribute on this label.
    @discardableResult
    public func setLogbook() -> Bool {
        OCCTDocumentSetLogbook(document.handle, labelId)
    }

    /// Mark a target label as touched in this label's logbook.
    @discardableResult
    public func logbookSetTouched(_ target: AssemblyNode) -> Bool {
        OCCTDocumentLogbookSetTouched(document.handle, labelId, target.labelId)
    }

    /// Mark a target label as impacted in this label's logbook.
    @discardableResult
    public func logbookSetImpacted(_ target: AssemblyNode) -> Bool {
        OCCTDocumentLogbookSetImpacted(document.handle, labelId, target.labelId)
    }

    /// Check if a target label is modified (touched) in this label's logbook.
    public func logbookIsModified(_ target: AssemblyNode) -> Bool {
        OCCTDocumentLogbookIsModified(document.handle, labelId, target.labelId)
    }

    /// Clear this label's logbook.
    @discardableResult
    public func logbookClear() -> Bool {
        OCCTDocumentLogbookClear(document.handle, labelId)
    }

    /// Check if this label's logbook is empty.
    public var logbookIsEmpty: Bool {
        OCCTDocumentLogbookIsEmpty(document.handle, labelId)
    }
}

extension AssemblyNode {

    /// Create a TFunction_GraphNode attribute on this label.
    @discardableResult
    public func setGraphNode() -> Bool {
        OCCTDocumentSetGraphNode(document.handle, labelId)
    }

    /// Add a previous dependency to this graph node (by tag ID).
    @discardableResult
    public func graphNodeAddPrevious(tag: Int32) -> Bool {
        OCCTDocumentGraphNodeAddPrevious(document.handle, labelId, tag)
    }

    /// Add a next dependency to this graph node (by tag ID).
    @discardableResult
    public func graphNodeAddNext(tag: Int32) -> Bool {
        OCCTDocumentGraphNodeAddNext(document.handle, labelId, tag)
    }

    /// Set the execution status of this graph node.
    @discardableResult
    public func setGraphNodeStatus(_ status: ExecutionStatus) -> Bool {
        OCCTDocumentGraphNodeSetStatus(document.handle, labelId, status.rawValue)
    }

    /// Get the execution status of this graph node.
    public func graphNodeStatus() -> ExecutionStatus? {
        let raw = OCCTDocumentGraphNodeGetStatus(document.handle, labelId)
        guard raw >= 0 else { return nil }
        return ExecutionStatus(rawValue: raw)
    }

    /// Remove all previous dependencies from this graph node.
    @discardableResult
    public func graphNodeRemoveAllPrevious() -> Bool {
        OCCTDocumentGraphNodeRemoveAllPrevious(document.handle, labelId)
    }

    /// Remove all next dependencies from this graph node.
    @discardableResult
    public func graphNodeRemoveAllNext() -> Bool {
        OCCTDocumentGraphNodeRemoveAllNext(document.handle, labelId)
    }
}

extension AssemblyNode {

    /// Create a TFunction_Function attribute on this label.
    @discardableResult
    public func setFunctionAttribute() -> Bool {
        OCCTDocumentSetFunctionAttr(document.handle, labelId)
    }

    /// Check if the function attribute on this label has failed.
    public var functionIsFailed: Bool {
        OCCTDocumentFunctionIsFailed(document.handle, labelId)
    }

    /// Get the failure mode of the function attribute on this label.
    public var functionFailure: Int32? {
        let raw = OCCTDocumentFunctionGetFailure(document.handle, labelId)
        guard raw >= 0 else { return nil }
        return raw
    }

    /// Set the failure mode of the function attribute on this label.
    @discardableResult
    public func setFunctionFailure(_ mode: Int32) -> Bool {
        OCCTDocumentFunctionSetFailure(document.handle, labelId, mode)
    }
}

extension AssemblyNode {
    /// Whether this label is top-level.
    public var isTopLevel: Bool {
        OCCTDocumentIsTopLevel(document.handle, labelId)
    }

    /// Whether this label is a component (instance inside an assembly).
    public var isComponent: Bool {
        OCCTDocumentIsComponent(document.handle, labelId)
    }

    /// Whether this label represents a compound shape.
    public var isCompound: Bool {
        OCCTDocumentIsCompound(document.handle, labelId)
    }

    /// Whether this label represents a sub-shape.
    public var isSubShape: Bool {
        OCCTDocumentIsSubShape(document.handle, labelId)
    }

    /// Number of sub-shapes for this label.
    public var subShapeCount: Int32 {
        OCCTDocumentGetSubShapeCount(document.handle, labelId)
    }

    /// Get sub-shape label at index.
    public func subShapeNode(at index: Int32) -> AssemblyNode? {
        let subId = OCCTDocumentGetSubShapeLabelId(document.handle, labelId, index)
        guard subId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: subId)
    }

    /// Number of labels that reference (use) this shape.
    public var userCount: Int32 {
        OCCTDocumentGetShapeUserCount(document.handle, labelId)
    }

    /// Visibility of this label.
    public var isVisible: Bool {
        get { OCCTDocumentGetLabelVisibility(document.handle, labelId) }
        set { OCCTDocumentSetLabelVisibility(document.handle, labelId, newValue) }
    }
}

extension AssemblyNode {
    /// Set area attribute on this label.
    public func setArea(_ area: Double) {
        OCCTDocumentSetArea(document.handle, labelId, area)
    }

    /// Get area attribute from this label.
    /// - Returns: Area value, or nil if not set
    public var area: Double? {
        let val = OCCTDocumentGetArea(document.handle, labelId)
        return val < 0 ? nil : val
    }

    /// Set volume attribute on this label.
    public func setVolume(_ volume: Double) {
        OCCTDocumentSetVolume(document.handle, labelId, volume)
    }

    /// Get volume attribute from this label.
    /// - Returns: Volume value, or nil if not set
    public var volume: Double? {
        let val = OCCTDocumentGetVolume(document.handle, labelId)
        return val < 0 ? nil : val
    }

    /// Set centroid attribute on this label.
    public func setCentroid(x: Double, y: Double, z: Double) {
        OCCTDocumentSetCentroid(document.handle, labelId, x, y, z)
    }

    /// Get centroid attribute from this label.
    /// - Returns: Centroid as (x, y, z), or nil if not set
    public var centroid: (x: Double, y: Double, z: Double)? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        if OCCTDocumentGetCentroid(document.handle, labelId, &x, &y, &z) {
            return (x, y, z)
        }
        return nil
    }
}

extension AssemblyNode {
    /// Set a named layer on this label.
    public func setLayer(_ name: String) {
        OCCTDocumentSetLayer(document.handle, labelId, name)
    }

    /// Check if a specific layer is set on this label.
    public func isLayerSet(_ name: String) -> Bool {
        OCCTDocumentIsLayerSet(document.handle, labelId, name)
    }

    /// Get layer names assigned to this label.
    public var layers: [String] {
        let maxNames: Int32 = 16
        let maxLen: Int32 = 256
        // Allocate C string buffers
        let buffers = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: Int(maxNames))
        defer { buffers.deallocate() }
        for i in 0..<Int(maxNames) {
            let buf = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLen))
            buf[0] = 0
            buffers[i] = buf
        }
        let count = OCCTDocumentGetLabelLayers(document.handle, labelId, buffers, maxNames, maxLen)
        var result: [String] = []
        for i in 0..<Int(count) {
            if let buf = buffers[i] {
                result.append(String(cString: buf))
            }
        }
        for i in 0..<Int(maxNames) {
            buffers[i]?.deallocate()
        }
        return result
    }
}

extension AssemblyNode {
    /// Set a TopLoc_Location (translation) on this label.
    @discardableResult
    public func setLocationTranslation(x: Double, y: Double, z: Double) -> Bool {
        OCCTDocumentSetLocation(document.handle, labelId, x, y, z)
    }

    /// Get the TopLoc_Location translation from this label.
    public var locationTranslation: (x: Double, y: Double, z: Double)? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTDocumentGetLocationTranslation(document.handle, labelId, &x, &y, &z) else { return nil }
        return (x, y, z)
    }

    /// Whether this label has an XCAFDoc_Location attribute.
    public var hasLocationAttribute: Bool {
        OCCTDocumentHasLocation(document.handle, labelId)
    }
}

extension AssemblyNode {
    /// Set an XCAFDoc_GraphNode attribute on this label.
    @discardableResult
    public func setXCAFGraphNode() -> Bool {
        OCCTDocumentSetGraphNodeAttr(document.handle, labelId)
    }

    /// Set a child relationship: this node's graph node gets the child's graph node.
    @discardableResult
    public func xcafGraphNodeSetChild(_ child: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeSetChild(document.handle, labelId, child.labelId)
    }

    /// Set a father relationship: this node's graph node gets the parent's graph node as father.
    @discardableResult
    public func xcafGraphNodeSetFather(_ parent: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeSetFather(document.handle, labelId, parent.labelId)
    }

    /// Unset a child relationship.
    @discardableResult
    public func xcafGraphNodeUnSetChild(_ child: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeUnSetChild(document.handle, labelId, child.labelId)
    }

    /// Unset a father relationship.
    @discardableResult
    public func xcafGraphNodeUnSetFather(_ parent: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeUnSetFather(document.handle, labelId, parent.labelId)
    }

    /// Number of children in the XCAFDoc_GraphNode.
    public var xcafGraphNodeChildCount: Int32 {
        OCCTDocumentGraphNodeNbChildren(document.handle, labelId)
    }

    /// Number of fathers in the XCAFDoc_GraphNode.
    public var xcafGraphNodeFatherCount: Int32 {
        OCCTDocumentGraphNodeNbFathers(document.handle, labelId)
    }

    /// Check if this node is a father of another node in the XCAFDoc_GraphNode.
    public func xcafGraphNodeIsFather(of other: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeIsFather(document.handle, labelId, other.labelId)
    }

    /// Check if this node is a child of another node in the XCAFDoc_GraphNode.
    public func xcafGraphNodeIsChild(of other: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeIsChild(document.handle, labelId, other.labelId)
    }
}

extension AssemblyNode {
    /// Set an XCAFDoc_Color attribute from RGB.
    @discardableResult
    public func setColorAttribute(red: Double, green: Double, blue: Double) -> Bool {
        OCCTDocumentSetColorAttr(document.handle, labelId, red, green, blue)
    }

    /// Set an XCAFDoc_Color attribute from RGBA.
    @discardableResult
    public func setColorAttribute(red: Double, green: Double, blue: Double, alpha: Float) -> Bool {
        OCCTDocumentSetColorRGBAAttr(document.handle, labelId, red, green, blue, alpha)
    }

    /// Set an XCAFDoc_Color attribute from a named color.
    @discardableResult
    public func setColorAttribute(namedColor noc: Int32) -> Bool {
        OCCTDocumentSetColorNOCAttr(document.handle, labelId, noc)
    }

    /// Get the RGB color from an XCAFDoc_Color attribute.
    public var colorAttribute: (red: Double, green: Double, blue: Double)? {
        var r: Double = 0, g: Double = 0, b: Double = 0
        guard OCCTDocumentGetColorAttr(document.handle, labelId, &r, &g, &b) else { return nil }
        return (r, g, b)
    }

    /// Get the RGBA color from an XCAFDoc_Color attribute.
    public var colorRGBAAttribute: (red: Double, green: Double, blue: Double, alpha: Float)? {
        var r: Double = 0, g: Double = 0, b: Double = 0
        var a: Float = 1.0
        guard OCCTDocumentGetColorRGBAAttr(document.handle, labelId, &r, &g, &b, &a) else { return nil }
        return (r, g, b, a)
    }

    /// Get the alpha value from an XCAFDoc_Color attribute.
    public var colorAlphaAttribute: Float {
        OCCTDocumentGetColorAlphaAttr(document.handle, labelId)
    }

    /// Get the named color (NOC) from an XCAFDoc_Color attribute, or -1 if not set.
    public var colorNOCAttribute: Int32 {
        OCCTDocumentGetColorNOCAttr(document.handle, labelId)
    }
}

extension AssemblyNode {
    /// Set an XCAFDoc_Material attribute on this label.
    @discardableResult
    public func setMaterialAttribute(name: String, description: String, density: Double,
                                      densityName: String, densityValueType: String) -> Bool {
        OCCTDocumentSetMaterialAttr(document.handle, labelId, name, description, density, densityName, densityValueType)
    }

    /// Get the material name from an XCAFDoc_Material attribute.
    public var materialAttributeName: String? {
        guard let cStr = OCCTDocumentGetMaterialAttrName(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Get the material description from an XCAFDoc_Material attribute.
    public var materialAttributeDescription: String? {
        guard let cStr = OCCTDocumentGetMaterialAttrDescription(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Get the material density from an XCAFDoc_Material attribute.
    public var materialAttributeDensity: Double? {
        var density: Double = 0
        guard OCCTDocumentGetMaterialAttrDensity(document.handle, labelId, &density) else { return nil }
        return density
    }

    /// Whether this label has an XCAFDoc_Material attribute.
    public var hasMaterialAttribute: Bool {
        OCCTDocumentHasMaterialAttr(document.handle, labelId)
    }
}

extension AssemblyNode {
    /// Set an XCAFDoc_NoteComment attribute on this label.
    @discardableResult
    public func setNoteComment(userName: String, timeStamp: String, comment: String) -> Bool {
        OCCTDocumentSetNoteComment(document.handle, labelId, userName, timeStamp, comment)
    }

    /// Get the comment text from an XCAFDoc_NoteComment attribute.
    public var noteCommentText: String? {
        guard let cStr = OCCTDocumentGetNoteCommentText(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Get the user name from a note attribute.
    public var noteUserName: String? {
        guard let cStr = OCCTDocumentGetNoteUserName(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Set an XCAFDoc_NoteBalloon attribute on this label.
    @discardableResult
    public func setNoteBalloon(userName: String, timeStamp: String, comment: String) -> Bool {
        OCCTDocumentSetNoteBalloon(document.handle, labelId, userName, timeStamp, comment)
    }

    /// Set an XCAFDoc_NoteBinData attribute on this label.
    @discardableResult
    public func setNoteBinData(userName: String, timeStamp: String, title: String,
                                mimeType: String, data: [UInt8]) -> Bool {
        data.withUnsafeBufferPointer { buf in
            OCCTDocumentSetNoteBinData(document.handle, labelId, userName, timeStamp,
                                       title, mimeType, buf.baseAddress!, Int32(data.count))
        }
    }

    /// Get the size of binary data from an XCAFDoc_NoteBinData attribute.
    public var noteBinDataSize: Int32 {
        OCCTDocumentGetNoteBinDataSize(document.handle, labelId)
    }
}

extension AssemblyNode {
    /// Set a ShapeMapTool attribute on this label.
    @discardableResult
    public func setShapeMapTool() -> Bool {
        OCCTDocumentSetShapeMapTool(document.handle, labelId)
    }

    /// Set a shape on the ShapeMapTool.
    @discardableResult
    public func shapeMapToolSetShape(_ shape: Shape) -> Bool {
        OCCTDocumentShapeMapToolSetShape(document.handle, labelId, shape.handle)
    }

    /// Check if a shape is a sub-shape in the ShapeMapTool.
    public func shapeMapToolIsSubShape(_ shape: Shape) -> Bool {
        OCCTDocumentShapeMapToolIsSubShape(document.handle, labelId, shape.handle)
    }

    /// Get the extent (number of entries) of the ShapeMapTool's map.
    public var shapeMapToolExtent: Int32 {
        OCCTDocumentShapeMapToolExtent(document.handle, labelId)
    }
}
