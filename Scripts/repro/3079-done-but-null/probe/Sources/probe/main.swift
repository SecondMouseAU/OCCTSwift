// #3079: can any of the 35 `new OCCTShape(builder.Shape())` sites be made to return a non-nil
// Shape whose isNull is true? One case per process (`probe <case>`), because a crash must not
// take the other cases with it; `probe --list` names every case as "<bridge function>/<label>".
// Output of one case: "<case> => nil | VALID ... | NULL-WRAPPED".
import Foundation
import OCCTSwift
import simd

typealias V = SIMD3<Double>

func box(_ w: Double = 10, _ h: Double = 10, _ d: Double = 10) -> Shape { Shape.box(width: w, height: h, depth: d)! }
func boxAt(_ o: V, _ s: Double = 10) -> Shape { Shape.box(origin: o, width: s, height: s, depth: s)! }
func rect(_ w: Double, _ h: Double, z: Double = 0) -> Wire {
    req(Wire.polygon3D([V(-w / 2, -h / 2, z), V(w / 2, -h / 2, z), V(w / 2, h / 2, z), V(-w / 2, h / 2, z)]))
}
func faceOf(_ w: Wire) -> Shape { Shape.face(from: w)! }
func faces(_ s: Shape) -> [Shape] { s.subShapes(ofType: .face) }
var currentCase = ""
/// A degenerate input the constructor itself refuses is a result in its own right (the bridge was never reached).
func req(_ w: Wire?) -> Wire {
    guard let w else { print("\(currentCase) => INPUT-REFUSED"); exit(0) }
    return w
}
/// An empty (not null) compound: the TopAbs_COMPOUND the kernel can build with nothing in it.
func emptyC() -> Shape {
    guard let s = Shape.empty(type: 0) else { print("\(currentCase) => INPUT-REFUSED"); exit(0) }
    return s
}
let nullBox = Shape.box(width: 10, height: 10, depth: 10)!.nullified!
let squareFace = faceOf(req(Wire.rectangle(width: 20, height: 20)))

var cases: [(String, () -> Shape?)] = []
func add(_ name: String, _ f: @escaping () -> Shape?) { cases.append((name, f)) }

// ---- Draft ----
let b = box()
for (l, ang) in ([("angle0", 0.0), ("angle89.9deg", 89.9 * .pi / 180), ("angle90deg", .pi / 2), ("angle-89.9deg", -89.9 * .pi / 180), ("angle180deg", .pi), ("angleNaN", Double.nan), ("angle45deg", .pi / 4)] as [(String, Double)]) {
    add("OCCTShapeDraft/\(l)") {
        b.drafted(faces: [b.faces()[0]], direction: V(0, 0, 1), angle: ang, neutralPlane: (V(0, 0, 0), V(0, 0, 1)))
    }
}
add("OCCTShapeDraft/zeroDirection") { b.drafted(faces: [b.faces()[0]], direction: V(0, 0, 0), angle: 0.1, neutralPlane: (V(0, 0, 0), V(0, 0, 1))) }
add("OCCTShapeDraft/zeroNeutralNormal") { b.drafted(faces: [b.faces()[0]], direction: V(0, 0, 1), angle: 0.1, neutralPlane: (V(0, 0, 0), V(0, 0, 0))) }
add("OCCTShapeDraft/neutralPlaneParallelToDirection") { b.drafted(faces: [b.faces()[0]], direction: V(0, 0, 1), angle: 0.1, neutralPlane: (V(0, 0, 0), V(1, 0, 0))) }
add("OCCTShapeDraft/nullBase") { nullBox.drafted(faces: [b.faces()[0]], direction: V(0, 0, 1), angle: 0.1, neutralPlane: (V(0, 0, 0), V(0, 0, 1))) }
add("OCCTShapeDraft/twoFaces") { b.drafted(faces: [b.faces()[0], b.faces()[5]], direction: V(0, 0, 1), angle: 0.1, neutralPlane: (V(0, 0, 100), V(0, 0, 1))) }
add("OCCTShapeDraft/sphereFace") { let s = Shape.sphere(radius: 5)!; return s.drafted(faces: [s.faces()[0]], direction: V(0, 0, 1), angle: 0.5, neutralPlane: (V(0, 0, 0), V(0, 0, 1))) }

// ---- ConvertToNURBS ----
add("OCCTShapeConvertToNURBS/box") { box().convertedToNURBS() }
add("OCCTShapeConvertToNURBS/sphere") { Shape.sphere(radius: 5)!.convertedToNURBS() }
add("OCCTShapeConvertToNURBS/nullShape") { nullBox.convertedToNURBS() }
add("OCCTShapeConvertToNURBS/emptiedSolid") { box().emptied!.convertedToNURBS() }
add("OCCTShapeConvertToNURBS/emptyCompound") { emptyC().convertedToNURBS() }

// ---- Fuse/CutAndBlend ----
for (fn, op) in ([("OCCTShapeFuseAndBlend", { (a: Shape, o: Shape, r: Double) in a.fusedAndBlended(with: o, radius: r) }), ("OCCTShapeCutAndBlend", { (a: Shape, o: Shape, r: Double) in a.cutAndBlended(with: o, radius: r) })] as [(String, (Shape, Shape, Double) -> Shape?)]) {
    add("\(fn)/overlappingBoxes-r1") { op(box(), boxAt(V(0, 0, 0), 10), 1) }
    add("\(fn)/identicalBoxes-r1") { op(box(), box(), 1) }
    add("\(fn)/disjointBoxes-r1") { op(box(), boxAt(V(100, 0, 0)), 1) }
    add("\(fn)/containedBox-r1") { op(box(), box(2, 2, 2), 1) }
    add("\(fn)/overlapping-hugeRadius") { op(box(), boxAt(V(3, 3, 3)), 1000) }
    add("\(fn)/overlapping-r0.0001") { op(box(), boxAt(V(3, 3, 3)), 1e-4) }
    add("\(fn)/boxSphere-r2") { op(box(), Shape.sphere(center: V(5, 5, 5), radius: 4)!, 2) }
    add("\(fn)/coincidentFaces-r1") { op(box(), boxAt(V(0, 0, 5)), 1) }
    add("\(fn)/nullFirst") { op(nullBox, box(), 1) }
    add("\(fn)/nullSecond") { op(box(), nullBox, 1) }
    add("\(fn)/emptiedSolid") { op(box(), box().emptied!, 1) }
    add("\(fn)/faceOperands") { op(squareFace, squareFace, 1) }
}

// ---- Glue ----
add("OCCTShapeGlue/touchingBoxes") { Shape.glue(boxAt(V(0, 0, 0)), boxAt(V(10, 0, 0))) }
add("OCCTShapeGlue/identicalBoxes") { Shape.glue(box(), box()) }
add("OCCTShapeGlue/disjointBoxes") { Shape.glue(box(), boxAt(V(100, 0, 0))) }
add("OCCTShapeGlue/overlappingBoxes") { Shape.glue(box(), boxAt(V(3, 3, 3))) }
add("OCCTShapeGlue/containedBox") { Shape.glue(box(), box(2, 2, 2)) }
add("OCCTShapeGlue/hugeTolerance") { Shape.glue(boxAt(V(0, 0, 0)), boxAt(V(10, 0, 0)), tolerance: 1000) }
add("OCCTShapeGlue/negativeTolerance") { Shape.glue(boxAt(V(0, 0, 0)), boxAt(V(10, 0, 0)), tolerance: -1) }
add("OCCTShapeGlue/nullFirst") { Shape.glue(nullBox, box()) }
add("OCCTShapeGlue/nullSecond") { Shape.glue(box(), nullBox) }
add("OCCTShapeGlue/bothNull") { Shape.glue(nullBox, nullBox) }
add("OCCTShapeGlue/emptiedSolid") { Shape.glue(box(), box().emptied!) }
add("OCCTShapeGlue/emptyCompounds") { Shape.glue(emptyC(), emptyC()) }

// ---- Union / Subtract / Intersect: no Swift caller (see README); the Swift booleans use the
// *Ex entry points. Subtract is reached from Swift through drillHole.
add("OCCTShapeSubtract/drillHole-zeroDepth") { box().drilled(at: V(0, 0, 5), direction: V(0, 0, -1), radius: 1, depth: 0) }
add("OCCTShapeSubtract/drillHole-hugeRadius") { box().drilled(at: V(0, 0, 5), direction: V(0, 0, -1), radius: 1000, depth: 20) }
add("OCCTShapeSubtract/drillHole-missesBox") { box().drilled(at: V(100, 0, 5), direction: V(0, 0, -1), radius: 1, depth: 20) }
add("OCCTShapeSubtract/drillHole-nullBase") { nullBox.drilled(at: V(0, 0, 5), direction: V(0, 0, -1), radius: 1, depth: 20) }

// The Swift boolean wrappers share the same BRepAlgoAPI calls as the three C entry points.
for (fn, op) in ([("OCCTShapeUnion", { (a: Shape, o: Shape) in a.union(o) }), ("OCCTShapeSubtract", { (a: Shape, o: Shape) in a.subtracting(o) }), ("OCCTShapeIntersect", { (a: Shape, o: Shape) in a.intersection(o) })] as [(String, (Shape, Shape) -> Shape?)]) {
    add("\(fn)/identical") { op(box(), box()) }
    add("\(fn)/disjoint") { op(box(), boxAt(V(100, 0, 0))) }
    add("\(fn)/contained") { op(box(), box(2, 2, 2)) }
    add("\(fn)/containing") { op(box(2, 2, 2), box()) }
    add("\(fn)/touchingFaces") { op(boxAt(V(0, 0, 0)), boxAt(V(10, 0, 0))) }
    add("\(fn)/touchingEdge") { op(boxAt(V(0, 0, 0)), boxAt(V(10, 10, 0))) }
    add("\(fn)/touchingVertex") { op(boxAt(V(0, 0, 0)), boxAt(V(10, 10, 10))) }
    add("\(fn)/nullFirst") { op(nullBox, box()) }
    add("\(fn)/nullSecond") { op(box(), nullBox) }
    add("\(fn)/bothNull") { op(nullBox, nullBox) }
    add("\(fn)/emptiedSolid") { op(box(), box().emptied!) }
    add("\(fn)/emptyCompounds") { op(emptyC(), emptyC()) }
    add("\(fn)/faceVsBox") { op(squareFace, box()) }
}

// ---- Chamfer / Fillet (all edges) ----
for (l, mk) in [("box", { box() }), ("sphere", { Shape.sphere(radius: 5)! }), ("cylinder", { Shape.cylinder(radius: 5, height: 10)! }), ("cone", { Shape.cone(bottomRadius: 5, topRadius: 0, height: 10)! }), ("null", { nullBox }), ("emptiedSolid", { box().emptied! }), ("face", { squareFace }), ("emptyCompound", { emptyC() })] as [(String, () -> Shape)] {
    for r in [0.0, -1.0, 0.001, 4.9, 5.0, 5.1, 100.0, 1e9, Double.nan] {
        add("OCCTShapeFillet/\(l)-r\(r)") { mk().filleted(radius: r) }
        add("OCCTShapeChamfer/\(l)-d\(r)") { mk().chamfered(distance: r) }
    }
}
for (l, d1, d2) in ([("tiny", 0.001, 0.001), ("half", 5.0, 5.0), ("equalWidth", 10.0, 10.0), ("over", 11.0, 11.0), ("huge", 1e6, 1e6), ("zero", 0.0, 0.0), ("negative", -1.0, -1.0), ("asymmetricOver", 1.0, 50.0), ("nan", Double.nan, 1.0)] as [(String, Double, Double)]) {
    add("OCCTShapeChamferTwoDistances/\(l)") { let s = box(); return s.chamferedTwoDistances([(edgeIndex: 0, faceIndex: 0, dist1: d1, dist2: d2)]) }
    add("OCCTShapeChamferTwoDistances/allEdges-\(l)") {
        let s = box(); let e = s.edges().count
        return s.chamferedTwoDistances((0..<e).map { (edgeIndex: $0, faceIndex: 0, dist1: d1, dist2: d2) })
    }
}
add("OCCTShapeChamferTwoDistances/edgeOutOfRange") { box().chamferedTwoDistances([(edgeIndex: 99, faceIndex: 0, dist1: 1, dist2: 1)]) }
add("OCCTShapeChamferTwoDistances/faceNotAdjacent") { box().chamferedTwoDistances([(edgeIndex: 0, faceIndex: 5, dist1: 1, dist2: 1)]) }
add("OCCTShapeChamferTwoDistances/null") { nullBox.chamferedTwoDistances([(edgeIndex: 0, faceIndex: 0, dist1: 1, dist2: 1)]) }
add("OCCTShapeChamferTwoDistances/sphere") { Shape.sphere(radius: 5)!.chamferedTwoDistances([(edgeIndex: 0, faceIndex: 0, dist1: 1, dist2: 1)]) }
for (l, d, a) in ([("tiny", 0.001, 45.0), ("half", 5.0, 45.0), ("over", 11.0, 45.0), ("huge", 1e6, 45.0), ("zeroDist", 0.0, 45.0), ("angle0", 1.0, 0.0), ("angle90", 1.0, 90.0), ("angle89.99", 1.0, 89.99), ("angle0.001", 1.0, 0.001), ("angleNeg", 1.0, -10.0), ("angle180", 1.0, 180.0), ("nan", Double.nan, 45.0), ("steepOver", 9.0, 89.0)] as [(String, Double, Double)]) {
    add("OCCTShapeChamferDistAngle/\(l)") { let s = box(); return s.chamferedDistAngle([(edgeIndex: 0, faceIndex: 0, distance: d, angleDegrees: a)]) }
    add("OCCTShapeChamferDistAngle/allEdges-\(l)") {
        let s = box(); let e = s.edges().count
        return s.chamferedDistAngle((0..<e).map { (edgeIndex: $0, faceIndex: 0, distance: d, angleDegrees: a) })
    }
}
add("OCCTShapeChamferDistAngle/edgeOutOfRange") { box().chamferedDistAngle([(edgeIndex: 99, faceIndex: 0, distance: 1, angleDegrees: 45)]) }
add("OCCTShapeChamferDistAngle/null") { nullBox.chamferedDistAngle([(edgeIndex: 0, faceIndex: 0, distance: 1, angleDegrees: 45)]) }

// ---- Face2DFillet / Face2DChamfer ----
for r in [0.0, -1.0, 0.001, 9.9, 10.0, 10.1, 1000.0, 1e9, Double.nan] {
    add("OCCTFace2DFillet/square20-r\(r)") { squareFace.fillet2D(vertexIndices: [0], radii: [r]) }
    add("OCCTFace2DFillet/square20-all4-r\(r)") { squareFace.fillet2D(vertexIndices: [0, 1, 2, 3], radii: [r, r, r, r]) }
    add("OCCTFace2DChamfer/square20-d\(r)") { squareFace.chamfer2D(edgePairs: [(0, 1)], distances: [r]) }
    add("OCCTFace2DChamfer/square20-all4-d\(r)") { squareFace.chamfer2D(edgePairs: [(0, 1), (1, 2), (2, 3), (3, 0)], distances: [r, r, r, r]) }
}
add("OCCTFace2DFillet/vertexOutOfRange") { squareFace.fillet2D(vertexIndices: [99], radii: [1]) }
add("OCCTFace2DFillet/null") { nullBox.fillet2D(vertexIndices: [0], radii: [1]) }
add("OCCTFace2DFillet/solidNotFace") { box().fillet2D(vertexIndices: [0], radii: [1]) }
add("OCCTFace2DFillet/triangleSliver") { faceOf(req(Wire.polygon3D([V(0, 0, 0), V(100, 0, 0), V(50, 0.001, 0)]))).fillet2D(vertexIndices: [0, 1, 2], radii: [5, 5, 5]) }
add("OCCTFace2DFillet/circleFace") { faceOf(req(Wire.circle(radius: 5))).fillet2D(vertexIndices: [0], radii: [1]) }
add("OCCTFace2DChamfer/edgePairNotAdjacent") { squareFace.chamfer2D(edgePairs: [(0, 2)], distances: [1]) }
add("OCCTFace2DChamfer/edgeOutOfRange") { squareFace.chamfer2D(edgePairs: [(0, 99)], distances: [1]) }
add("OCCTFace2DChamfer/null") { nullBox.chamfer2D(edgePairs: [(0, 1)], distances: [1]) }
add("OCCTFace2DChamfer/solidNotFace") { box().chamfer2D(edgePairs: [(0, 1)], distances: [1]) }

// ---- Solid primitives built from curves / wires / shapes ----
let zAxis = V(0, 0, 1)
for (l, ang) in ([("full", 2 * Double.pi), ("angle0", 0.0), ("angle1e-12", 1e-12), ("angleNeg", -1.0), ("angleHuge", 1e6), ("angleNaN", Double.nan)] as [(String, Double)]) {
    let line = Curve3D.segment(from: V(0, 0, 0), to: V(0, 0, 10))!
    add("OCCTShapeCreateRevolutionFromCurve/segmentOnAxis-\(l)") { Shape.revolution(meridian: line, angle: ang) }
    let off = Curve3D.segment(from: V(5, 0, 0), to: V(5, 0, 10))!
    add("OCCTShapeCreateRevolutionFromCurve/segmentOffAxis-\(l)") { Shape.revolution(meridian: off, angle: ang) }
    add("OCCTShapeCreateRevolution/wireOnAxis-\(l)") { Shape.revolve(profile: req(Wire.polygon3D([V(0, 0, 0), V(0, 0, 10), V(0, 0.0, 5)])), axisOrigin: .zero, axisDirection: zAxis, angle: ang) }
    add("OCCTShapeCreateRevolution/rectOffAxis-\(l)") { Shape.revolve(profile: req(Wire.polygon3D([V(2, 0, 0), V(4, 0, 0), V(4, 0, 5), V(2, 0, 5)])), axisOrigin: .zero, axisDirection: zAxis, angle: ang) }
    add("OCCTShapeCreateRevolutionPartial/faceOffAxis-\(l)") { faceOf(req(Wire.polygon3D([V(2, 0, 0), V(4, 0, 0), V(4, 0, 5), V(2, 0, 5)]))).revolved(axisOrigin: .zero, axisDirection: zAxis, angle: ang) }
}
add("OCCTShapeCreateRevolutionFromCurve/zeroAxis") { Shape.revolution(meridian: Curve3D.segment(from: V(5, 0, 0), to: V(5, 0, 10))!, axisDirection: .zero) }
add("OCCTShapeCreateRevolutionFromCurve/curveIsAxisLine") { Shape.revolution(meridian: Curve3D.line(through: V(0, 0, 0), direction: zAxis)!) }
add("OCCTShapeCreateRevolutionFromCurve/tinyCircle") { Shape.revolution(meridian: Curve3D.circle(center: V(0, 0, 0), normal: V(0, 1, 0), radius: 1e-9)!) }
add("OCCTShapeCreateRevolution/zeroAxis") { Shape.revolve(profile: rect(2, 2), axisOrigin: .zero, axisDirection: .zero) }
add("OCCTShapeCreateRevolution/profileCrossingAxis") { Shape.revolve(profile: req(Wire.polygon3D([V(-2, 0, 0), V(2, 0, 0), V(2, 0, 5), V(-2, 0, 5)])), axisOrigin: .zero, axisDirection: zAxis) }
add("OCCTShapeCreateRevolution/profilePerpendicularThroughAxis") { Shape.revolve(profile: rect(4, 4), axisOrigin: .zero, axisDirection: zAxis) }
add("OCCTShapeCreateRevolution/collinearPolygon") { Wire.polygon3D([V(2, 0, 0), V(3, 0, 0), V(4, 0, 0)]).flatMap { Shape.revolve(profile: $0, axisOrigin: .zero, axisDirection: zAxis) } }
add("OCCTShapeCreateRevolution/nullProfileViaFace") { Shape.revolve(profile: req(Wire.polygon3D([V(0, 0, 0), V(0, 0, 0), V(0, 0, 0)])), axisOrigin: .zero, axisDirection: zAxis) }
add("OCCTShapeCreateRevolutionFull/null") { nullBox.revolved(axisOrigin: .zero, axisDirection: zAxis) }
add("OCCTShapeCreateRevolutionFull/zeroAxis") { squareFace.revolved(axisOrigin: .zero, axisDirection: .zero) }
add("OCCTShapeCreateRevolutionFull/box") { box().revolved(axisOrigin: V(30, 0, 0), axisDirection: zAxis) }
add("OCCTShapeCreateRevolutionFull/boxAcrossAxis") { box().revolved(axisOrigin: V(0, 0, 0), axisDirection: zAxis) }
add("OCCTShapeCreateRevolutionFull/faceOnAxisLine") { faceOf(req(Wire.polygon3D([V(0, 0, 0), V(0, 0, 1), V(0, 0, 2)]))).revolved(axisOrigin: .zero, axisDirection: zAxis) }
add("OCCTShapeCreateRevolutionFull/emptyCompound") { emptyC().revolved(axisOrigin: .zero, axisDirection: zAxis) }
add("OCCTShapeCreateRevolutionPartial/null") { nullBox.revolved(axisOrigin: .zero, axisDirection: zAxis, angle: 1) }
add("OCCTShapeCreateRevolutionPartial/emptyCompound") { emptyC().revolved(axisOrigin: .zero, axisDirection: zAxis, angle: 1) }

for (l, dir, len) in ([("zeroDir", V(0, 0, 0), 5.0), ("len0", zAxis, 0.0), ("lenNeg", zAxis, -5.0), ("lenNaN", zAxis, Double.nan), ("lenTiny", zAxis, 1e-12), ("dirInPlane", V(1, 0, 0), 5.0), ("lenHuge", zAxis, 1e300)] as [(String, V, Double)]) {
    add("OCCTShapeCreateExtrusion/rect-\(l)") { Shape.extrude(profile: rect(4, 4), direction: dir, length: len) }
    add("OCCTShapeCreateExtrusion/collinear-\(l)") { Wire.polygon3D([V(0, 0, 0), V(1, 0, 0), V(2, 0, 0)]).flatMap { Shape.extrude(profile: $0, direction: dir, length: len) } }
}
for (l, v) in ([("zero", V(0, 0, 0)), ("tiny", V(0, 0, 1e-12)), ("nan", V(Double.nan, 0, 0)), ("inPlane", V(1, 0, 0)), ("huge", V(0, 0, 1e300))] as [(String, V)]) {
    add("OCCTShapeCreateExtrusionShape/face-\(l)") { squareFace.extruded(by: v) }
    add("OCCTShapeCreateExtrusionShape/null-\(l)") { nullBox.extruded(by: v) }
    add("OCCTShapeCreateExtrusionShape/emptyCompound-\(l)") { emptyC().extruded(by: v) }
    add("OCCTShapeCreateExtrusionShape/emptiedSolid-\(l)") { box().emptied!.extruded(by: v) }
    add("OCCTShapeCreateExtrusionInfinite/face-\(l)") { squareFace.extrudedInfinite(direction: v) }
    add("OCCTShapeCreateExtrusionInfinite/faceSemi-\(l)") { squareFace.extrudedInfinite(direction: v, infinite: false) }
    add("OCCTShapeCreateExtrusionInfinite/null-\(l)") { nullBox.extrudedInfinite(direction: v) }
    add("OCCTShapeExtrudeSemiInfinite/face-\(l)") { squareFace.extrudedSemiInfinite(direction: v) }
    add("OCCTShapeExtrudeSemiInfinite/faceInfinite-\(l)") { squareFace.extrudedSemiInfinite(direction: v, infinite: true) }
    add("OCCTShapeExtrudeSemiInfinite/null-\(l)") { nullBox.extrudedSemiInfinite(direction: v) }
    add("OCCTShapeExtrudeSemiInfinite/box-\(l)") { box().extrudedSemiInfinite(direction: v) }
}
add("OCCTShapeCreateExtrusionShape/solid") { box().extruded(by: zAxis) }
add("OCCTShapeCreateExtrusionInfinite/solid") { box().extrudedInfinite(direction: zAxis) }
add("OCCTShapeCreateExtrusionInfinite/emptyCompound") { emptyC().extrudedInfinite(direction: zAxis) }
add("OCCTShapeExtrudeSemiInfinite/emptyCompound") { emptyC().extrudedSemiInfinite(direction: zAxis) }

// ---- Sweep ----
add("OCCTShapeMiddlePath/sameFace") { let s = box(); let f = faces(s)[0]; return s.middlePath(start: f, end: f) }
add("OCCTShapeMiddlePath/oppositeFacesOfBox") { let s = box(); let f = faces(s); return s.middlePath(start: f[4], end: f[5]) }
add("OCCTShapeMiddlePath/adjacentFaces") { let s = box(); let f = faces(s); return s.middlePath(start: f[0], end: f[2]) }
add("OCCTShapeMiddlePath/nullBase") { let f = faces(box())[0]; return nullBox.middlePath(start: f, end: f) }
add("OCCTShapeMiddlePath/nullEnds") { box().middlePath(start: nullBox, end: nullBox) }
add("OCCTShapeMiddlePath/unrelatedFaces") { box().middlePath(start: squareFace, end: faceOf(rect(4, 4, z: 50))) }
add("OCCTShapeMiddlePath/sphere") { let s = Shape.sphere(radius: 5)!; let f = faces(s); return s.middlePath(start: f[0], end: f[0]) }
for (a, z) in [(0, 1), (1, 2), (0, 2), (2, 0)] {
    add("OCCTShapeMiddlePath/cylinderFaces\(a)-\(z)") { let s = Shape.cylinder(radius: 2, height: 10)!; let f = faces(s); return s.middlePath(start: f[a], end: f[z]) }
}
add("OCCTShapeMiddlePath/emptyCompound") { let c = emptyC(); return c.middlePath(start: c, end: c) }

let straight = req(Wire.polygon3D([V(0, 0, 0), V(0, 0, 10)], closed: false))
add("OCCTShapeCreatePipeSweep/circleAlongLine") { Shape.sweep(profile: req(Wire.circle(radius: 2)), along: straight) }
add("OCCTShapeCreatePipeSweep/profileCollinearWithPath") { Shape.sweep(profile: req(Wire.polygon3D([V(0, 0, 1), V(0, 0, 2), V(0, 0, 3)], closed: false)), along: straight) }
add("OCCTShapeCreatePipeSweep/profileIsPathItself") { Shape.sweep(profile: straight, along: straight) }
add("OCCTShapeCreatePipeSweep/pathCollapsedToPoint") { Wire.polygon3D([V(0, 0, 0), V(0, 0, 0)], closed: false).flatMap { Shape.sweep(profile: req(Wire.circle(radius: 2)), along: $0) } }
add("OCCTShapeCreatePipeSweep/pathTinyLength") { Shape.sweep(profile: req(Wire.circle(radius: 2)), along: req(Wire.polygon3D([V(0, 0, 0), V(0, 0, 1e-9)], closed: false))) }
add("OCCTShapeCreatePipeSweep/profileCollapsedToPoint") { Wire.polygon3D([V(0, 0, 0), V(0, 0, 0), V(0, 0, 0)]).flatMap { Shape.sweep(profile: $0, along: straight) } }
add("OCCTShapeCreatePipeSweep/profileTinyCircle") { Shape.sweep(profile: req(Wire.circle(radius: 1e-9)), along: straight) }
add("OCCTShapeCreatePipeSweep/radiusExceedsPathBend") { Shape.sweep(profile: req(Wire.circle(radius: 50)), along: req(Wire.arc(center: .zero, radius: 5, startAngle: 0, endAngle: 1.5))) }
add("OCCTShapeCreatePipeSweep/profileParallelToPath") { Shape.sweep(profile: req(Wire.circle(normal: V(1, 0, 0), radius: 2)), along: straight) }
add("OCCTShapeCreatePipeSweep/closedPath") { Shape.sweep(profile: req(Wire.circle(radius: 1)), along: rect(20, 20)) }
add("OCCTShapeCreatePipeSweep/selfIntersectingPath") { Shape.sweep(profile: req(Wire.circle(radius: 0.5)), along: req(Wire.polygon3D([V(0, 0, 0), V(10, 10, 0), V(10, 0, 0), V(0, 10, 0)], closed: false))) }

func loftCase(_ l: String, _ mk: @escaping @autoclosure () -> [Wire], solid: Bool) {
    add("OCCTShapeCreateLoft/\(l)-solid\(solid)") { Shape.loft(profiles: mk(), solid: solid) }
    add("OCCTShapeCreateLoftAdvanced/\(l)-solid\(solid)-smooth") { Shape.loft(profiles: mk(), solid: solid, ruled: false) }
    add("OCCTShapeCreateLoftAdvanced/\(l)-solid\(solid)-ruled") { Shape.loft(profiles: mk(), solid: solid, ruled: true) }
}
for solid in [true, false] {
    loftCase("coincidentProfiles", [rect(4, 4), rect(4, 4)], solid: solid)
    loftCase("coincidentThree", [rect(4, 4), rect(4, 4), rect(4, 4)], solid: solid)
    loftCase("singleProfile", [rect(4, 4)], solid: solid)
    loftCase("noProfiles", [], solid: solid)
    loftCase("collapsedToPointsSameZ", [req(Wire.polygon3D([V(0, 0, 0), V(0, 0, 0), V(0, 0, 0)])), req(Wire.polygon3D([V(0, 0, 0), V(0, 0, 0), V(0, 0, 0)]))], solid: solid)
    loftCase("collinearProfiles", [req(Wire.polygon3D([V(0, 0, 0), V(1, 0, 0), V(2, 0, 0)])), req(Wire.polygon3D([V(0, 0, 5), V(1, 0, 5), V(2, 0, 5)]))], solid: solid)
    loftCase("profileToTinyProfile", [rect(4, 4), rect(1e-9, 1e-9, z: 5)], solid: solid)
    loftCase("twistedAndFlipped", [rect(4, 4), req(Wire.polygon3D([V(2, 2, 5), V(-2, 2, 5), V(-2, -2, 5), V(2, -2, 5)]))], solid: solid)
    loftCase("rectToCircle", [rect(4, 4), req(Wire.circle(origin: V(0, 0, 5), radius: 2))], solid: solid)
    loftCase("perpendicularProfiles", [rect(4, 4), req(Wire.polygon3D([V(0, -2, 5), V(0, 2, 5), V(5, 2, 5), V(5, -2, 5)]))], solid: solid)
    loftCase("sameLineSegments", [req(Wire.line(from: V(0, 0, 0), to: V(1, 0, 0))), req(Wire.line(from: V(0, 0, 0), to: V(1, 0, 0)))], solid: solid)
    loftCase("openThenClosed", [req(Wire.polygon3D([V(0, 0, 0), V(1, 0, 0), V(1, 1, 0)], closed: false)), rect(4, 4, z: 5)], solid: solid)
    loftCase("circlesRadiusHuge", [req(Wire.circle(radius: 1)), req(Wire.circle(origin: V(0, 0, 1e-6), radius: 1e9))], solid: solid)
}
add("OCCTShapeCreateLoftAdvanced/firstVertexOnFirstProfile") { Shape.loft(profiles: [rect(4, 4), rect(4, 4, z: 5)], solid: true, ruled: true, firstVertex: V(0, 0, 0)) }
add("OCCTShapeCreateLoftAdvanced/vertexOnlyNoSecondProfile") { Shape.loft(profiles: [rect(4, 4)], solid: true, ruled: true, firstVertex: V(0, 0, 0), lastVertex: V(0, 0, 5)) }
add("OCCTShapeCreateLoftAdvanced/verticesCoincide") { Shape.loft(profiles: [rect(4, 4)], solid: true, ruled: false, firstVertex: V(0, 0, 3), lastVertex: V(0, 0, 3)) }
add("OCCTShapeCreateLoftAdvanced/vertexInProfilePlane") { Shape.loft(profiles: [rect(4, 4), rect(4, 4, z: 5)], solid: true, ruled: false, lastVertex: V(0, 0, 5)) }

// ---- NonUniformScale ----
for (l, sx, sy, sz) in ([("zeroX", 0.0, 1.0, 1.0), ("zeroAll", 0.0, 0.0, 0.0), ("negX", -1.0, 1.0, 1.0), ("negAll", -1.0, -1.0, -1.0), ("nan", Double.nan, 1.0, 1.0), ("inf", Double.infinity, 1.0, 1.0), ("tiny", 1e-300, 1.0, 1.0), ("huge", 1e300, 1e300, 1e300), ("ok", 2.0, 3.0, 4.0)] as [(String, Double, Double, Double)]) {
    add("OCCTShapeNonUniformScale/box-\(l)") { box().nonUniformScaled(sx: sx, sy: sy, sz: sz) }
    add("OCCTShapeNonUniformScale/sphere-\(l)") { Shape.sphere(radius: 5)!.nonUniformScaled(sx: sx, sy: sy, sz: sz) }
    add("OCCTShapeNonUniformScale/face-\(l)") { squareFace.nonUniformScaled(sx: sx, sy: sy, sz: sz) }
    add("OCCTShapeNonUniformScale/null-\(l)") { nullBox.nonUniformScaled(sx: sx, sy: sy, sz: sz) }
}
add("OCCTShapeNonUniformScale/emptyCompound") { emptyC().nonUniformScaled(sx: 2, sy: 2, sz: 2) }
add("OCCTShapeNonUniformScale/emptiedSolid") { box().emptied!.nonUniformScaled(sx: 2, sy: 2, sz: 2) }
add("OCCTShapeNonUniformScale/cylinderZeroZ") { Shape.cylinder(radius: 5, height: 10)!.nonUniformScaled(sx: 1, sy: 1, sz: 0) }
add("OCCTShapeNonUniformScale/cylinderTinyZ") { Shape.cylinder(radius: 5, height: 10)!.nonUniformScaled(sx: 1, sy: 1, sz: 1e-9) }

// ---- Features on a base: rib, revolution form, draft prism, revol feature ----
let base = box(20, 20, 20)           // centred: top face at z = 10
let topProfile = rect(6, 6, z: 10)
let nonPlanarBase = Shape.cylinder(radius: 10, height: 20)!
for (l, dir, dd) in ([("ok", V(0, 0, 1), V(1, 0, 0)), ("zeroDir", V(0, 0, 0), V(1, 0, 0)), ("zeroDraft", V(0, 0, 1), V(0, 0, 0)), ("dirParallelDraft", V(0, 0, 1), V(0, 0, 1)), ("dirInProfilePlane", V(1, 0, 0), V(0, 1, 0)), ("opposite", V(0, 0, -1), V(1, 0, 0))] as [(String, V, V)]) {
    for fuse in [true, false] {
        add("OCCTShapeAddLinearRib/\(l)-fuse\(fuse)") { base.addingLinearRib(profile: topProfile, direction: dir, draftDirection: dd, fuse: fuse) }
    }
}
add("OCCTShapeAddLinearRib/profileFarFromBase") { base.addingLinearRib(profile: rect(6, 6, z: 100), direction: V(0, 0, 1), draftDirection: V(1, 0, 0)) }
add("OCCTShapeAddLinearRib/profileInsideBase") { base.addingLinearRib(profile: rect(6, 6, z: 0), direction: V(0, 0, 1), draftDirection: V(1, 0, 0), fuse: false) }
add("OCCTShapeAddLinearRib/collinearProfile") { base.addingLinearRib(profile: req(Wire.polygon3D([V(0, 0, 10), V(1, 0, 10), V(2, 0, 10)], closed: false)), direction: V(0, 0, 1), draftDirection: V(1, 0, 0)) }
add("OCCTShapeAddLinearRib/nullBase") { nullBox.addingLinearRib(profile: topProfile, direction: V(0, 0, 1), draftDirection: V(1, 0, 0)) }
add("OCCTShapeAddLinearRib/faceBase") { squareFace.addingLinearRib(profile: rect(6, 6, z: 0), direction: V(0, 0, 1), draftDirection: V(1, 0, 0)) }

for (l, h1, h2) in ([("ok", 3.0, 3.0), ("zeroHeights", 0.0, 0.0), ("negative", -3.0, -3.0), ("hugeHeights", 1e6, 1e6), ("nan", Double.nan, 1.0)] as [(String, Double, Double)]) {
    for fuse in [true, false] {
        add("OCCTShapeAddRevolutionForm/\(l)-fuse\(fuse)") { base.addingRevolutionForm(profile: topProfile, axisOrigin: V(0, 0, 0), axisDirection: V(0, 0, 1), height1: h1, height2: h2, fuse: fuse) }
    }
}
add("OCCTShapeAddRevolutionForm/zeroAxis") { base.addingRevolutionForm(profile: topProfile, axisOrigin: .zero, axisDirection: .zero, height1: 3, height2: 3) }
add("OCCTShapeAddRevolutionForm/axisThroughProfile") { base.addingRevolutionForm(profile: topProfile, axisOrigin: V(0, 0, 10), axisDirection: V(1, 0, 0), height1: 3, height2: 3) }
add("OCCTShapeAddRevolutionForm/nullBase") { nullBox.addingRevolutionForm(profile: topProfile, axisOrigin: .zero, axisDirection: zAxis, height1: 3, height2: 3) }

for (l, ang, h) in ([("ok", 5.0, 5.0), ("angle0", 0.0, 5.0), ("angle90", 90.0, 5.0), ("angle89", 89.0, 5.0), ("angle-5", -5.0, 5.0), ("angle45h1000", 45.0, 1000.0), ("height0", 5.0, 0.0), ("heightNeg", 5.0, -5.0), ("angle80h100", 80.0, 100.0), ("nan", Double.nan, 5.0)] as [(String, Double, Double)]) {
    for fuse in [true, false] {
        add("OCCTShapeDraftPrism/\(l)-fuse\(fuse)") { base.addingDraftPrism(profile: topProfile, sketchFaceIndex: 4, draftAngle: ang, height: h, fuse: fuse) }
    }
}
for face in [0, 1, 2, 3, 4, 5, 99, -1] {
    add("OCCTShapeDraftPrism/sketchFace\(face)") { base.addingDraftPrism(profile: topProfile, sketchFaceIndex: face, draftAngle: 5, height: 5) }
}
add("OCCTShapeDraftPrism/profileNotOnFace") { base.addingDraftPrism(profile: rect(6, 6, z: 50), sketchFaceIndex: 4, draftAngle: 5, height: 5) }
add("OCCTShapeDraftPrism/profileLargerThanFace") { base.addingDraftPrism(profile: rect(60, 60, z: 10), sketchFaceIndex: 4, draftAngle: 5, height: 5) }
add("OCCTShapeDraftPrism/collinearProfile") { base.addingDraftPrism(profile: req(Wire.polygon3D([V(0, 0, 10), V(1, 0, 10), V(2, 0, 10)], closed: false)), sketchFaceIndex: 4, draftAngle: 5, height: 5) }
add("OCCTShapeDraftPrism/nullBase") { nullBox.addingDraftPrism(profile: topProfile, sketchFaceIndex: 0, draftAngle: 5, height: 5) }
add("OCCTShapeDraftPrism/cylinderBase") { nonPlanarBase.addingDraftPrism(profile: rect(6, 6, z: 10), sketchFaceIndex: 0, draftAngle: 5, height: 5) }
for (l, ang) in ([("ok", 5.0), ("angle0", 0.0), ("angle90", 90.0), ("angle45", 45.0), ("angleNeg", -5.0), ("angle80", 80.0), ("nan", Double.nan)] as [(String, Double)]) {
    for fuse in [true, false] {
        add("OCCTShapeDraftPrismThruAll/\(l)-fuse\(fuse)") { base.addingDraftPrismThruAll(profile: topProfile, sketchFaceIndex: 4, draftAngle: ang, fuse: fuse) }
        add("OCCTShapeDraftPrismThruAll/bottomUp-\(l)-fuse\(fuse)") { base.addingDraftPrismThruAll(profile: rect(6, 6, z: -10), sketchFaceIndex: 5, draftAngle: ang, fuse: fuse) }
    }
}
add("OCCTShapeDraftPrismThruAll/profileNotOnFace") { base.addingDraftPrismThruAll(profile: rect(6, 6, z: 50), sketchFaceIndex: 4, draftAngle: 5, fuse: false) }
add("OCCTShapeDraftPrismThruAll/nullBase") { nullBox.addingDraftPrismThruAll(profile: topProfile, sketchFaceIndex: 0, draftAngle: 5) }

let revProfile = req(Wire.polygon3D([V(3, 0, 10), V(6, 0, 10), V(6, 0, 12), V(3, 0, 12)]))
for (l, ang) in ([("ok", 360.0), ("angle0", 0.0), ("angle90", 90.0), ("angleNeg", -90.0), ("angle1e-9", 1e-9), ("angleHuge", 1e6), ("nan", Double.nan)] as [(String, Double)]) {
    for fuse in [true, false] {
        add("OCCTShapeRevolFeature/\(l)-fuse\(fuse)") { base.addingRevolvedFeature(profile: revProfile, sketchFaceIndex: 4, axisOrigin: V(0, 0, 10), axisDirection: V(0, 0, 1), angle: ang, fuse: fuse) }
    }
}
for fuse in [true, false] {
    add("OCCTShapeRevolFeature/axisThroughProfile-fuse\(fuse)") { base.addingRevolvedFeature(profile: revProfile, sketchFaceIndex: 4, axisOrigin: V(4, 0, 10), axisDirection: V(0, 0, 1), angle: 90, fuse: fuse) }
    add("OCCTShapeRevolFeature/zeroAxis-fuse\(fuse)") { base.addingRevolvedFeature(profile: revProfile, sketchFaceIndex: 4, axisOrigin: .zero, axisDirection: .zero, angle: 90, fuse: fuse) }
    add("OCCTShapeRevolFeature/profileOutsideBase-fuse\(fuse)") { base.addingRevolvedFeature(profile: req(Wire.polygon3D([V(50, 0, 10), V(56, 0, 10), V(56, 0, 12), V(50, 0, 12)])), sketchFaceIndex: 4, axisOrigin: V(0, 0, 10), axisDirection: zAxis, angle: 90, fuse: fuse) }
    add("OCCTShapeRevolFeature/profileInsideBase-fuse\(fuse)") { base.addingRevolvedFeature(profile: req(Wire.polygon3D([V(3, 0, 8), V(6, 0, 8), V(6, 0, 10), V(3, 0, 10)])), sketchFaceIndex: 4, axisOrigin: V(0, 0, 10), axisDirection: zAxis, angle: 360, fuse: fuse) }
    add("OCCTShapeRevolFeatureThruAll/ok-fuse\(fuse)") { base.addingRevolvedFeatureThruAll(profile: revProfile, sketchFaceIndex: 4, axisOrigin: V(0, 0, 10), axisDirection: zAxis, fuse: fuse) }
    add("OCCTShapeRevolFeatureThruAll/zeroAxis-fuse\(fuse)") { base.addingRevolvedFeatureThruAll(profile: revProfile, sketchFaceIndex: 4, axisOrigin: .zero, axisDirection: .zero, fuse: fuse) }
    add("OCCTShapeRevolFeatureThruAll/axisThroughProfile-fuse\(fuse)") { base.addingRevolvedFeatureThruAll(profile: revProfile, sketchFaceIndex: 4, axisOrigin: V(4, 0, 10), axisDirection: zAxis, fuse: fuse) }
    add("OCCTShapeRevolFeatureThruAll/profileOutside-fuse\(fuse)") { base.addingRevolvedFeatureThruAll(profile: req(Wire.polygon3D([V(50, 0, 10), V(56, 0, 10), V(56, 0, 12), V(50, 0, 12)])), sketchFaceIndex: 4, axisOrigin: V(0, 0, 10), axisDirection: zAxis, fuse: fuse) }
}
for face in [0, 1, 2, 3, 5, 99, -1] {
    add("OCCTShapeRevolFeature/sketchFace\(face)") { base.addingRevolvedFeature(profile: revProfile, sketchFaceIndex: face, axisOrigin: V(0, 0, 10), axisDirection: zAxis, angle: 90) }
    add("OCCTShapeRevolFeatureThruAll/sketchFace\(face)") { base.addingRevolvedFeatureThruAll(profile: revProfile, sketchFaceIndex: face, axisOrigin: V(0, 0, 10), axisDirection: zAxis) }
}
add("OCCTShapeRevolFeature/nullBase") { nullBox.addingRevolvedFeature(profile: revProfile, sketchFaceIndex: 0, axisOrigin: V(0, 0, 10), axisDirection: zAxis, angle: 90) }
add("OCCTShapeRevolFeatureThruAll/nullBase") { nullBox.addingRevolvedFeatureThruAll(profile: revProfile, sketchFaceIndex: 0, axisOrigin: V(0, 0, 10), axisDirection: zAxis) }

// ---- FromMesh ----
let tri: [(Int32, Int32, Int32)] = [(1, 2, 3)]
add("OCCTShapeFromMesh/empty") { Shape.fromMesh(points: [], triangles: []) }
add("OCCTShapeFromMesh/pointsNoTriangles") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(0, 1, 0)], triangles: []) }
add("OCCTShapeFromMesh/oneTriangle") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(0, 1, 0)], triangles: tri) }
add("OCCTShapeFromMesh/coincidentPoints") { Shape.fromMesh(points: [V(0, 0, 0), V(0, 0, 0), V(0, 0, 0)], triangles: tri) }
add("OCCTShapeFromMesh/collinearPoints") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(2, 0, 0)], triangles: tri) }
add("OCCTShapeFromMesh/repeatedIndex") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(0, 1, 0)], triangles: [(1, 1, 2)]) }
add("OCCTShapeFromMesh/allSameIndex") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(0, 1, 0)], triangles: [(1, 1, 1)]) }
add("OCCTShapeFromMesh/indexZero") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(0, 1, 0)], triangles: [(0, 1, 2)]) }
add("OCCTShapeFromMesh/indexOutOfRange") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(0, 1, 0)], triangles: [(1, 2, 9)]) }
add("OCCTShapeFromMesh/indexNegative") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(0, 1, 0)], triangles: [(-1, 2, 3)]) }
add("OCCTShapeFromMesh/nanPoints") { Shape.fromMesh(points: [V(Double.nan, 0, 0), V(1, 0, 0), V(0, 1, 0)], triangles: tri) }
add("OCCTShapeFromMesh/duplicateTriangles") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(0, 1, 0)], triangles: [(1, 2, 3), (1, 2, 3)]) }
add("OCCTShapeFromMesh/tetrahedron") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)], triangles: [(1, 3, 2), (1, 2, 4), (2, 3, 4), (3, 1, 4)]) }
add("OCCTShapeFromMesh/flatTetrahedron") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(0, 1, 0), V(1, 1, 0)], triangles: [(1, 3, 2), (1, 2, 4), (2, 3, 4), (3, 1, 4)]) }
add("OCCTShapeFromMesh/allTrianglesDegenerate") { Shape.fromMesh(points: [V(0, 0, 0), V(1, 0, 0), V(2, 0, 0), V(3, 0, 0)], triangles: [(1, 2, 3), (2, 3, 4)]) }
add("OCCTShapeFromMesh/hugeCoordinates") { Shape.fromMesh(points: [V(0, 0, 0), V(1e300, 0, 0), V(0, 1e300, 0)], triangles: tri) }

// ---- GeomFillConstrained ----
func edgeOf(_ w: Wire) -> Edge { Shape.fromWire(w)!.edges()[0] }
let e1 = edgeOf(req(Wire.line(from: V(0, 0, 0), to: V(10, 0, 0))))
let e2 = edgeOf(req(Wire.line(from: V(10, 0, 0), to: V(10, 10, 0))))
let e3 = edgeOf(req(Wire.line(from: V(10, 10, 0), to: V(0, 0, 0))))
let e4 = edgeOf(req(Wire.line(from: V(10, 10, 0), to: V(0, 10, 0))))
let e5 = edgeOf(req(Wire.line(from: V(0, 10, 0), to: V(0, 0, 0))))
add("OCCTGeomFillConstrained/triangle") { Shape.constrainedFill(edge1: e1, edge2: e2, edge3: e3) }
add("OCCTGeomFillConstrained/square") { Shape.constrainedFill(edge1: e1, edge2: e2, edge3: e4, edge4: e5) }
add("OCCTGeomFillConstrained/sameEdgeThrice") { Shape.constrainedFill(edge1: e1, edge2: e1, edge3: e1) }
add("OCCTGeomFillConstrained/sameEdgeFour") { Shape.constrainedFill(edge1: e1, edge2: e1, edge3: e1, edge4: e1) }
add("OCCTGeomFillConstrained/collinearTriangle") { Shape.constrainedFill(edge1: e1, edge2: edgeOf(req(Wire.line(from: V(10, 0, 0), to: V(20, 0, 0)))), edge3: edgeOf(req(Wire.line(from: V(20, 0, 0), to: V(0, 0, 0))))) }
add("OCCTGeomFillConstrained/disconnectedEdges") { Shape.constrainedFill(edge1: e1, edge2: edgeOf(req(Wire.line(from: V(50, 50, 0), to: V(60, 50, 0)))), edge3: edgeOf(req(Wire.line(from: V(0, 80, 9), to: V(5, 90, 9))))) }
add("OCCTGeomFillConstrained/degreeZero") { Shape.constrainedFill(edge1: e1, edge2: e2, edge3: e3, maxDegree: 0, maxSegments: 0) }
add("OCCTGeomFillConstrained/degreeOne") { Shape.constrainedFill(edge1: e1, edge2: e2, edge3: e3, maxDegree: 1, maxSegments: 1) }
add("OCCTGeomFillConstrained/degreeHuge") { Shape.constrainedFill(edge1: e1, edge2: e2, edge3: e3, maxDegree: 1000, maxSegments: 100000) }
add("OCCTGeomFillConstrained/negativeLimits") { Shape.constrainedFill(edge1: e1, edge2: e2, edge3: e3, maxDegree: -1, maxSegments: -1) }
add("OCCTGeomFillConstrained/stackedCircles") {
    let c1 = edgeOf(req(Wire.circle(radius: 5))), c2 = edgeOf(req(Wire.circle(origin: V(0, 0, 5), radius: 5))), c3 = edgeOf(req(Wire.circle(origin: V(0, 0, 10), radius: 5)))
    return Shape.constrainedFill(edge1: c1, edge2: c2, edge3: c3)
}
add("OCCTGeomFillConstrained/sameCircleFour") {
    let c1 = edgeOf(req(Wire.circle(radius: 5)))
    return Shape.constrainedFill(edge1: c1, edge2: c1, edge3: c1, edge4: c1)
}

// ---- driver ----
func describe(_ s: Shape?) -> String {
    guard let s else { return "nil" }
    if s.isNull { return "NULL-WRAPPED" }
    return "VALID type=\(s.shapeType) isValid=\(s.isValid)"
}
let args = CommandLine.arguments
if args.count >= 2, args[1] == "--list" {
    for (n, _) in cases { print(n) }
    exit(0)
}
guard args.count >= 2, let c = cases.first(where: { $0.0 == args[1] }) else {
    FileHandle.standardError.write(Data("usage: probe --list | probe <case>\n".utf8)); exit(2)
}
setvbuf(stdout, nil, _IOLBF, 0)
currentCase = c.0
print("\(c.0) => \(describe(c.1()))")
