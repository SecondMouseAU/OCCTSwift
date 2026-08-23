import Foundation

/// The edges of a chosen set of face occurrences, indexed so a boundary edge can be tested for.
/// membership by `TopoDS_Shape::IsSame`.
///
/// Backs ``AAG/detectPockets(tolerance:)``'s enclosure test (#735/#753/#777): a floor's boundary
/// edge borders one of the pocket's covering faces exactly when it is one of that face's own.
/// edges, so the test is built once per pocket over the covering faces rather than once per edge.
/// over the whole shape.
///
/// Its own file rather than appended to `FeatureRecognition.swift`, per.
/// `okf/policies/code-structure.md`: a standalone type is evicted rather than added to a file
/// already past the 900-line report threshold.
///
/// Internal rather than private so Issue777PocketEnclosureCoveringEdgesTests can assert the.
/// membership rule directly instead of only through a pocket verdict.
///
/// `Scripts/repro/harnesses/PocketEnclosureTiming.swift` carries a hand copy of this type, because.
/// the Harnesses target links OCCTSwift normally and cannot see an internal type.
///
/// It labels.
/// its own row "the form that shipped", so a change here that is not mirrored there leaves the.
/// harness reporting a number for something else under that name.
///
/// Keep the two in step.
struct CoveringEdges {
    /// The indexed edges, bucketed by `Shape.hashCode`.
    ///
    /// OCCTShapeHashCode is `std::hash<TopoDS_Shape>` masked to 31 bits
    /// (`OCCTBridge_Topology.mm`), and that hash is the one TopTools_ShapeMapHasher pairs with.
    ///
    /// IsSame (`TopTools_ShapeMapHasher.hxx`), combining TShape and Location with no orientation.
    /// term.
    ///
    /// Two IsSame shapes therefore always land in the same bucket, so a bucket miss is a.
    /// definite non-match.
    ///
    /// The mask can only ADD collisions, never remove a match, which is why.
    /// the IsSame confirmation on a hash hit is load-bearing rather than belt-and-braces.
    private var buckets: [Int: [Shape]] = [:]

    /// Creates the index over the faces at indices.
    ///
    /// indices are subscripted unguarded, as the enclosure test's own `occFaces[floorIndex]`.
    /// already is: `AAG.buildGraph()` keeps nodes and faceOccurrences index-for-index aligned
    /// by construction, so an out-of-range index is a broken graph rather than a case to absorb.
    ///
    /// A face that cannot be wrapped is skipped rather than failing the whole index, which biases.
    /// toward reporting the pocket open, matching the enclosure test's own stated default: do not
    /// claim an enclosure that was never established.
    ///
    /// - Parameters:
    ///   - indices: Occurrence indices into occFaces, walls UNION absorbed junction faces (#762).
    ///   - occFaces: The shape's face occurrences, as ``Shape/orientedFaces()`` returns them.
    init(facesAt indices: [Int], in occFaces: [Face]) {
        for index in indices {
            guard let asShape = Shape.fromFace(occFaces[index]) else { continue }
            for edge in asShape.subShapes(ofType: .edge) {
                buckets[edge.hashCode, default: []].append(edge)
            }
        }
    }

    /// Whether edge is one of the indexed faces' own edges.
    ///
    /// Never reads ``Edge/index``: a floor's outer-wire edges come from ``Wire/edges()``, which
    /// mints them from a throwaway one-off Shape, so their ordinals name a position in that.
    /// shape rather than in the graph's.
    ///
    /// IsSame is the identity the wire-to-shape conversion.
    /// preserves, and is the same rule the enclosure test used before #777.
    func contains(_ edge: Edge) -> Bool {
        guard let wrapped = Shape.fromEdge(edge), let bucket = buckets[wrapped.hashCode] else {
            return false
        }
        return bucket.contains { $0.isSame(as: wrapped) }
    }
}
