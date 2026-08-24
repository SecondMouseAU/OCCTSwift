import Foundation
import OCCTBridge
import simd

/// Analytic intersection algorithms for lines, planes, spheres, tori.
public enum IntAna {

    /// Result of a line-plane or line-sphere intersection.
    public struct ConicQuadResult {
        /// Intersection points.
        public let points: [SIMD3<Double>]
        /// Parameters on the conic for each point.
        public let params: [Double]
        /// Whether the line is parallel to the surface.
        public let isParallel: Bool
    }

    /// Intersect a line with a plane.
    public static func linePlane(
        lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
        planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>
    ) -> ConicQuadResult {
        let r = OCCTIntAnaLineQuad(
            lineOrigin.x, lineOrigin.y, lineOrigin.z,
            lineDir.x, lineDir.y, lineDir.z,
            planeOrigin.x, planeOrigin.y, planeOrigin.z,
            planeNormal.x, planeNormal.y, planeNormal.z)
        var pts: [SIMD3<Double>] = []
        var pars: [Double] = []
        for i in 0..<Int(r.count) {
            pts.append(
                SIMD3(
                    r.points.0 + Double(i * 3), r.points.1 + Double(i * 3),
                    r.points.2 + Double(i * 3)))
            pars.append(
                withUnsafePointer(to: r.params) { p in
                    p.withMemoryRebound(to: Double.self, capacity: 4) { $0[i] }
                })
        }
        // Re-extract properly using tuple access
        let pointTuple = r.points
        let paramTuple = r.params
        pts = []
        pars = []
        withUnsafePointer(to: pointTuple) { pp in
            pp.withMemoryRebound(to: Double.self, capacity: 12) { ptr in
                withUnsafePointer(to: paramTuple) { parp in
                    parp.withMemoryRebound(to: Double.self, capacity: 4) { parPtr in
                        for i in 0..<Int(r.count) {
                            pts.append(SIMD3(ptr[i * 3], ptr[i * 3 + 1], ptr[i * 3 + 2]))
                            pars.append(parPtr[i])
                        }
                    }
                }
            }
        }
        return ConicQuadResult(points: pts, params: pars, isParallel: r.isParallel)
    }

    /// Intersect a line with a sphere.
    public static func lineSphere(
        lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
        sphereCenter: SIMD3<Double>, sphereAxis: SIMD3<Double>,
        radius: Double
    ) -> ConicQuadResult {
        let r = OCCTIntAnaLineSphere(
            lineOrigin.x, lineOrigin.y, lineOrigin.z,
            lineDir.x, lineDir.y, lineDir.z,
            sphereCenter.x, sphereCenter.y, sphereCenter.z,
            sphereAxis.x, sphereAxis.y, sphereAxis.z, radius)
        var pts: [SIMD3<Double>] = []
        var pars: [Double] = []
        withUnsafePointer(to: r.points) { pp in
            pp.withMemoryRebound(to: Double.self, capacity: 12) { ptr in
                withUnsafePointer(to: r.params) { parp in
                    parp.withMemoryRebound(to: Double.self, capacity: 4) { parPtr in
                        for i in 0..<Int(r.count) {
                            pts.append(SIMD3(ptr[i * 3], ptr[i * 3 + 1], ptr[i * 3 + 2]))
                            pars.append(parPtr[i])
                        }
                    }
                }
            }
        }
        return ConicQuadResult(points: pts, params: pars, isParallel: r.isParallel)
    }

    /// Result type for quadric-quadric intersection.
    public struct QuadQuadResult {
        /// Number of solutions found.
        public let count: Int
        /// Intersection lines (origin + direction pairs); populated for plane-plane.
        public let lines: [(origin: SIMD3<Double>, direction: SIMD3<Double>)]
        /// Intersection points; populated for plane-sphere circle center etc.
        public let points: [SIMD3<Double>]
    }

    /// Intersect two planes — result is typically a line.
    public static func planePlane(
        p1Origin: SIMD3<Double>, p1Normal: SIMD3<Double>,
        p2Origin: SIMD3<Double>, p2Normal: SIMD3<Double>
    ) -> QuadQuadResult {
        let r = OCCTIntAnaPlanePlane(
            p1Origin.x, p1Origin.y, p1Origin.z,
            p1Normal.x, p1Normal.y, p1Normal.z,
            p2Origin.x, p2Origin.y, p2Origin.z,
            p2Normal.x, p2Normal.y, p2Normal.z)
        return quadQuadResultFromC(r)
    }

    /// Intersect a plane with a sphere — result is typically a circle.
    public static func planeSphere(
        planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>,
        sphereCenter: SIMD3<Double>, sphereAxis: SIMD3<Double>,
        radius: Double
    ) -> QuadQuadResult {
        let r = OCCTIntAnaPlaneSphere(
            planeOrigin.x, planeOrigin.y, planeOrigin.z,
            planeNormal.x, planeNormal.y, planeNormal.z,
            sphereCenter.x, sphereCenter.y, sphereCenter.z,
            sphereAxis.x, sphereAxis.y, sphereAxis.z, radius)
        return quadQuadResultFromC(r)
    }

    private static func quadQuadResultFromC(_ r: OCCTQuadQuadGeoResult) -> QuadQuadResult {
        let n = Int(r.solutionCount)
        var linesOut: [(origin: SIMD3<Double>, direction: SIMD3<Double>)] = []
        var ptsOut: [SIMD3<Double>] = []
        withUnsafePointer(to: r.lines) { lp in
            lp.withMemoryRebound(to: Double.self, capacity: 24) { ld in
                withUnsafePointer(to: r.points) { pp in
                    pp.withMemoryRebound(to: Double.self, capacity: 12) { pd in
                        for i in 0..<min(n, 4) {
                            linesOut.append(
                                (
                                    SIMD3(ld[i * 6], ld[i * 6 + 1], ld[i * 6 + 2]),
                                    SIMD3(ld[i * 6 + 3], ld[i * 6 + 4], ld[i * 6 + 5])
                                ))
                            ptsOut.append(SIMD3(pd[i * 3], pd[i * 3 + 1], pd[i * 3 + 2]))
                        }
                    }
                }
            }
        }
        return QuadQuadResult(count: n, lines: linesOut, points: ptsOut)
    }

    /// Intersect three planes to find a single point.
    public static func threePlanes(
        p1Origin: SIMD3<Double>, p1Normal: SIMD3<Double>,
        p2Origin: SIMD3<Double>, p2Normal: SIMD3<Double>,
        p3Origin: SIMD3<Double>, p3Normal: SIMD3<Double>
    ) -> SIMD3<Double>? {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        let ok = OCCTIntAna3Planes(
            p1Origin.x, p1Origin.y, p1Origin.z, p1Normal.x, p1Normal.y, p1Normal.z,
            p2Origin.x, p2Origin.y, p2Origin.z, p2Normal.x, p2Normal.y, p2Normal.z,
            p3Origin.x, p3Origin.y, p3Origin.z, p3Normal.x, p3Normal.y, p3Normal.z,
            &x, &y, &z)
        return ok ? SIMD3(x, y, z) : nil
    }

    /// Intersect a line with a torus.
    public static func lineTorus(
        lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
        torusCenter: SIMD3<Double>, torusAxis: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> [SIMD3<Double>] {
        var buffer = [Double](repeating: 0, count: 12)
        let n = buffer.withUnsafeMutableBufferPointer { buf in
            OCCTIntAnaLineTorus(
                lineOrigin.x, lineOrigin.y, lineOrigin.z,
                lineDir.x, lineDir.y, lineDir.z,
                torusCenter.x, torusCenter.y, torusCenter.z,
                torusAxis.x, torusAxis.y, torusAxis.z,
                majorRadius, minorRadius, buf.baseAddress!)
        }
        return unpackSIMD3(buffer, count: Int(n))
    }
}
