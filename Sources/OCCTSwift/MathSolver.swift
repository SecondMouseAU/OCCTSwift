import Foundation
import simd
import OCCTBridge

/// Numerical solver infrastructure using OCCT's math library.
/// Bridges Swift closures to OCCT's abstract C++ function classes via C callback adapters.
public enum MathSolver {

    // MARK: - Context helper

    /// Wraps a Swift closure in a reference type for passing through C void* context pointers.
    private final class ClosureBox<T> {
        let closure: T
        init(_ c: T) { closure = c }
    }

    // MARK: - 1D Root Finding

    /// Find a root of f(x)=0 near `guess` using Newton-Raphson with derivatives.
    ///
    /// The closure takes x and returns (value, derivative).
    /// - Parameters:
    ///   - guess: Initial guess for the root
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum Newton iterations (default 100)
    ///   - function: Closure returning (f(x), f'(x))
    /// - Returns: The root value, or nil if the solver did not converge
    public static func findRoot(
        near guess: Double,
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> Double? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var isDone = false
        let result = OCCTMathFunctionRoot(callback, ptr, guess, tolerance, Int32(maxIterations), &isDone)
        return isDone ? result : nil
    }

    /// Find a root of f(x)=0 near `guess` within bounds [a, b].
    public static func findRoot(
        near guess: Double,
        in range: ClosedRange<Double>,
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> Double? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var isDone = false
        let result = OCCTMathFunctionRootBounded(callback, ptr, guess, tolerance,
                                                   range.lowerBound, range.upperBound, Int32(maxIterations), &isDone)
        return isDone ? result : nil
    }

    /// Find a root of f(x)=0 in [a, b] using bisection+Newton hybrid method.
    public static func findRootBisection(
        in range: ClosedRange<Double>,
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> Double? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var isDone = false
        let result = OCCTMathBissecNewton(callback, ptr,
                                            range.lowerBound, range.upperBound, tolerance, Int32(maxIterations), &isDone)
        return isDone ? result : nil
    }

    // MARK: - System of Equations

    /// Solve a system of equations using Newton's method.
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - equations: Number of equations
    ///   - startPoint: Initial guess (array of `variables` values)
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum iterations (default 100)
    ///   - values: Closure taking [Double] of length `variables`, returning [Double] of length `equations`
    ///   - jacobian: Closure taking [Double] of length `variables`, returning row-major Jacobian [Double] of length `equations * variables`
    /// - Returns: Solution point, or nil if the solver did not converge
    ///
    /// `variables` and `equations` must both be positive, and `startPoint.count` must equal
    /// `variables` (#640). Neither was checked before: a negative `variables` reached
    /// `Array(repeating:count:)` and trapped, and a positive `variables` that did not match
    /// `startPoint`'s real length reached the bridge's unconditional `startPoint[i]` loop and
    /// read out of bounds -- silently, since the loop has no way to fail other than reading
    /// whatever memory happens to follow `startPoint`.
    public static func solveSystem(
        variables: Int,
        equations: Int,
        startPoint: [Double],
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        values: @escaping ([Double]) -> [Double],
        jacobian: @escaping ([Double]) -> [Double]
    ) -> [Double]? {
        guard variables > 0, equations > 0, startPoint.count == variables else { return nil }
        typealias ValuesClosure = ([Double]) -> [Double]
        typealias JacobianClosure = ([Double]) -> [Double]
        let valBox = ClosureBox(values)
        let jacBox = ClosureBox(jacobian)
        // Pack both closures into one context
        let pair = ClosureBox((valBox, jacBox))
        let ptr = Unmanaged.passRetained(pair).toOpaque()
        defer { Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ptr).release() }

        let valCallback: OCCTMathFuncSetCallback = { x, nVars, vals, nEqs, context in
            guard let ctx = context else { return false }
            let pair = Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ctx).takeUnretainedValue()
            let n = Int(nVars)
            var input = [Double](repeating: 0, count: n)
            for i in 0..<n { input[i] = x[i] }
            let result = pair.closure.0.closure(input)
            let m = Int(nEqs)
            for i in 0..<m { vals[i] = result[i] }
            return true
        }

        let derivCallback: OCCTMathFuncSetDerivCallback = { x, nVars, jac, nEqs, context in
            guard let ctx = context else { return false }
            let pair = Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ctx).takeUnretainedValue()
            let n = Int(nVars)
            var input = [Double](repeating: 0, count: n)
            for i in 0..<n { input[i] = x[i] }
            let result = pair.closure.1.closure(input)
            let total = Int(nEqs) * n
            for i in 0..<total { jac[i] = result[i] }
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        let ok = OCCTMathFunctionSetRoot(Int32(variables), Int32(equations),
                                          valCallback, derivCallback, ptr,
                                          startPoint, tolerance, Int32(maxIterations), &result)
        return ok ? result : nil
    }

    // MARK: - BFGS Minimization

    /// Minimize a multivariate function using BFGS quasi-Newton method.
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - startPoint: Initial guess (array of `variables` values)
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum iterations (default 200)
    ///   - function: Closure taking [Double], returning (value, gradient)
    /// - Returns: (point, minimum) tuple, or nil if the solver did not converge
    ///
    /// `variables` must be positive and equal `startPoint.count` (#640): neither was checked
    /// before, so a mismatched positive `variables` reached the bridge's unconditional
    /// `startPoint[i]` loop and read out of bounds.
    public static func minimize(
        variables: Int,
        startPoint: [Double],
        tolerance: Double = 1e-8,
        maxIterations: Int = 200,
        function: @escaping ([Double]) -> (value: Double, gradient: [Double])
    ) -> (point: [Double], minimum: Double)? {
        guard variables > 0, startPoint.count == variables else { return nil }
        typealias Fn = ([Double]) -> (value: Double, gradient: [Double])
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<Fn>>.fromOpaque(ptr).release() }

        let callback: OCCTMathMultiVarGradCallback = { x, n, value, gradient, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<Fn>>.fromOpaque(ctx).takeUnretainedValue()
            let nv = Int(n)
            var input = [Double](repeating: 0, count: nv)
            for i in 0..<nv { input[i] = x[i] }
            let result = box.closure(input)
            value.pointee = result.value
            for i in 0..<nv { gradient[i] = result.gradient[i] }
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        var minimum = 0.0
        let ok = OCCTMathBFGS(Int32(variables), callback, ptr,
                                startPoint, tolerance, Int32(maxIterations), &result, &minimum)
        return ok ? (result, minimum) : nil
    }

    // MARK: - Powell Minimization

    /// Minimize a multivariate function using Powell's method (derivative-free).
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - startPoint: Initial guess
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum iterations (default 200)
    ///   - function: Closure taking [Double], returning scalar value
    /// - Returns: (point, minimum) tuple, or nil if the solver did not converge
    ///
    /// Same guard as `minimize`, and for the same reason (#640): `variables` must be positive
    /// and equal `startPoint.count`.
    public static func minimizePowell(
        variables: Int,
        startPoint: [Double],
        tolerance: Double = 1e-8,
        maxIterations: Int = 200,
        function: @escaping ([Double]) -> Double
    ) -> (point: [Double], minimum: Double)? {
        guard variables > 0, startPoint.count == variables else { return nil }
        typealias Fn = ([Double]) -> Double
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<Fn>>.fromOpaque(ptr).release() }

        let callback: OCCTMathMultiVarCallback = { x, n, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<Fn>>.fromOpaque(ctx).takeUnretainedValue()
            let nv = Int(n)
            var input = [Double](repeating: 0, count: nv)
            for i in 0..<nv { input[i] = x[i] }
            value.pointee = box.closure(input)
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        var minimum = 0.0
        let ok = OCCTMathPowell(Int32(variables), callback, ptr,
                                  startPoint, tolerance, Int32(maxIterations), &result, &minimum)
        return ok ? (result, minimum) : nil
    }

    // MARK: - Brent Minimization

    /// Minimize a 1D function using Brent's method.
    ///
    /// The bracket [ax, cx] must contain a minimum, with bx as the initial interior point.
    /// - Parameters:
    ///   - ax: Left bracket bound
    ///   - bx: Interior point (initial guess for minimum)
    ///   - cx: Right bracket bound
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum iterations (default 100)
    ///   - function: Closure returning (value, derivative) at x
    /// - Returns: (location, minimum) tuple, or nil if the solver did not converge
    public static func minimizeBrent(
        ax: Double, bx: Double, cx: Double,
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> (location: Double, minimum: Double)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var location = 0.0, minimum = 0.0
        let ok = OCCTMathBrentMinimum(callback, ptr, ax, bx, cx, tolerance, Int32(maxIterations), &location, &minimum)
        return ok ? (location, minimum) : nil
    }

    // MARK: - Particle Swarm Optimization (v0.111.0)

    /// Minimize a multivariate function using Particle Swarm Optimization.
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - lower: Lower bounds for each variable
    ///   - upper: Upper bounds for each variable
    ///   - steps: Step sizes for each variable
    ///   - particles: Number of particles (default 64)
    ///   - iterations: Number of iterations (default 100)
    ///   - function: Closure taking [Double], returning scalar value
    /// - Returns: (point, minimum) tuple, or nil on failure
    ///
    /// `variables` must be positive and `lower`/`upper`/`steps` must each have `variables`
    /// elements (#640): none of this was checked before, so the bridge's unconditional
    /// `lower[i]`/`upper[i]`/`steps[i]` loop read out of bounds on a mismatch.
    public static func particleSwarm(
        variables: Int,
        lower: [Double],
        upper: [Double],
        steps: [Double],
        particles: Int = 64,
        iterations: Int = 100,
        function: @escaping ([Double]) -> Double
    ) -> (point: [Double], minimum: Double)? {
        guard variables > 0, lower.count == variables, upper.count == variables,
              steps.count == variables else { return nil }
        typealias Fn = ([Double]) -> Double
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<Fn>>.fromOpaque(ptr).release() }

        let callback: OCCTMathMultiVarCallback = { x, n, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<Fn>>.fromOpaque(ctx).takeUnretainedValue()
            let nv = Int(n)
            var input = [Double](repeating: 0, count: nv)
            for i in 0..<nv { input[i] = x[i] }
            value.pointee = box.closure(input)
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        var minimum = 0.0
        let ok = OCCTMathPSO(Int32(variables), callback, ptr,
                               lower, upper, steps,
                               Int32(particles), Int32(iterations), &result, &minimum)
        return ok ? (result, minimum) : nil
    }

    // MARK: - Global Minimization (v0.111.0)

    /// Find the global minimum of a multivariate function using Lipschitz optimization.
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - lower: Lower bounds for each variable
    ///   - upper: Upper bounds for each variable
    ///   - function: Closure taking [Double], returning scalar value
    /// - Returns: (point, minimum) tuple, or nil on failure
    ///
    /// `variables` must be positive and `lower`/`upper` must each have `variables` elements
    /// (#640), for the same reason as `particleSwarm`.
    public static func globalMinimize(
        variables: Int,
        lower: [Double],
        upper: [Double],
        function: @escaping ([Double]) -> Double
    ) -> (point: [Double], minimum: Double)? {
        guard variables > 0, lower.count == variables, upper.count == variables else { return nil }
        typealias Fn = ([Double]) -> Double
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<Fn>>.fromOpaque(ptr).release() }

        let callback: OCCTMathMultiVarCallback = { x, n, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<Fn>>.fromOpaque(ctx).takeUnretainedValue()
            let nv = Int(n)
            var input = [Double](repeating: 0, count: nv)
            for i in 0..<nv { input[i] = x[i] }
            value.pointee = box.closure(input)
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        var minimum = 0.0
        let ok = OCCTMathGlobOptMin(Int32(variables), callback, ptr, lower, upper, &result, &minimum)
        return ok ? (result, minimum) : nil
    }

    // MARK: - Find All Roots (v0.111.0)

    /// Find all roots of f(x)=0 in a given range using derivative-based search.
    ///
    /// - Parameters:
    ///   - range: The search interval
    ///   - samples: Number of sample subdivisions (default 20)
    ///   - function: Closure returning (value, derivative) at x
    /// - Returns: Array of root values found
    ///
    /// `samples` is a sampler by name and by role, not a problem dimension (#640): it belongs
    /// to #558's `Sampling` contract like every other subdivision count in this library, and
    /// is bounded the same way rather than left to trap `Int32(samples)` past `Int32.max`.
    public static func findAllRoots(
        in range: ClosedRange<Double>,
        samples: Int = 20,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> [Double] {
        guard let samples = Sampling.requested(samples) else { return [] }
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var roots = [Double](repeating: 0, count: 100)
        let n = OCCTMathFunctionRoots(callback, ptr, range.lowerBound, range.upperBound,
                                        Int32(samples), &roots, 100)
        return Array(roots.prefix(Int(n)))
    }

    // MARK: - Gauss Integration (v0.111.0)

    /// Integrate a function from lower to upper using Gauss quadrature.
    ///
    /// - Parameters:
    ///   - from: Lower bound of integration
    ///   - to: Upper bound of integration
    ///   - order: Order of Gauss quadrature (default 10)
    ///   - function: Closure returning f(x) at x
    /// - Returns: The integral value
    public static func integrate(
        from lower: Double,
        to upper: Double,
        order: Int = 10,
        function: @escaping (Double) -> Double
    ) -> Double {
        typealias Fn = (Double) -> Double
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<Fn>>.fromOpaque(ptr).release() }

        let callback: OCCTMathSimpleFuncCallback = { x, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<Fn>>.fromOpaque(ctx).takeUnretainedValue()
            value.pointee = box.closure(x)
            return true
        }

        return OCCTMathGaussIntegrate(callback, ptr, lower, upper, Int32(order))
    }

    // MARK: - Newton System Solver (v0.111.0)

    /// Solve a system of equations using Newton's method (NewtonFunctionSetRoot variant).
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - equations: Number of equations
    ///   - startPoint: Initial guess
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum iterations (default 100)
    ///   - values: Closure returning equation values
    ///   - jacobian: Closure returning row-major Jacobian
    /// - Returns: Solution point, or nil if not converged
    ///
    /// Same guard as `solveSystem`, and for the same reason (#640).
    public static func solveSystemNewton(
        variables: Int,
        equations: Int,
        startPoint: [Double],
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        values: @escaping ([Double]) -> [Double],
        jacobian: @escaping ([Double]) -> [Double]
    ) -> [Double]? {
        guard variables > 0, equations > 0, startPoint.count == variables else { return nil }
        typealias ValuesClosure = ([Double]) -> [Double]
        typealias JacobianClosure = ([Double]) -> [Double]
        let valBox = ClosureBox(values)
        let jacBox = ClosureBox(jacobian)
        let pair = ClosureBox((valBox, jacBox))
        let ptr = Unmanaged.passRetained(pair).toOpaque()
        defer { Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ptr).release() }

        let valCallback: OCCTMathFuncSetCallback = { x, nVars, vals, nEqs, context in
            guard let ctx = context else { return false }
            let pair = Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ctx).takeUnretainedValue()
            let n = Int(nVars)
            var input = [Double](repeating: 0, count: n)
            for i in 0..<n { input[i] = x[i] }
            let result = pair.closure.0.closure(input)
            let m = Int(nEqs)
            for i in 0..<m { vals[i] = result[i] }
            return true
        }

        let derivCallback: OCCTMathFuncSetDerivCallback = { x, nVars, jac, nEqs, context in
            guard let ctx = context else { return false }
            let pair = Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ctx).takeUnretainedValue()
            let n = Int(nVars)
            var input = [Double](repeating: 0, count: n)
            for i in 0..<n { input[i] = x[i] }
            let result = pair.closure.1.closure(input)
            let total = Int(nEqs) * n
            for i in 0..<total { jac[i] = result[i] }
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        let ok = OCCTMathNewtonFuncSetRoot(Int32(variables), Int32(equations),
                                             valCallback, derivCallback, ptr,
                                             startPoint, tolerance, Int32(maxIterations), &result)
        return ok ? result : nil
    }
}

extension MathSolver {

    /// Minimize using Newton's method with Hessian (second derivatives).
    /// The closure takes x[n] and returns (value, gradient[n], hessian[n*n] row-major).
    /// This is the most precise minimizer when the Hessian is available.
    ///
    /// `n` must be positive and equal `startPoint.count` (#640), for the same reason as
    /// `minimize`.
    public static func minimizeNewton(
        variables n: Int,
        startPoint: [Double],
        tolerance: Double = 1e-8,
        maxIterations: Int = 40,
        function: @escaping ([Double]) -> (value: Double, gradient: [Double], hessian: [Double])
    ) -> (point: [Double], minimum: Double)? {
        guard n > 0, startPoint.count == n else { return nil }
        typealias Closure = ([Double]) -> (value: Double, gradient: [Double], hessian: [Double])
        class Box { let fn: Closure; init(_ f: @escaping Closure) { fn = f } }
        let box = Box(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<Box>.fromOpaque(ptr).release() }

        let callback: OCCTMathHessianCallback = { x, nVars, value, gradient, hessian, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<Box>.fromOpaque(ctx).takeUnretainedValue()
            let n = Int(nVars)
            let input = Array(UnsafeBufferPointer(start: x, count: n))
            let result = box.fn(input)
            value.pointee = result.value
            for i in 0..<n { gradient[i] = result.gradient[i] }
            for i in 0..<(n*n) { hessian[i] = result.hessian[i] }
            return true
        }

        var result = [Double](repeating: 0, count: n)
        var minimum = 0.0
        let ok = OCCTMathNewtonMinimum(Int32(n), callback, ptr,
                                        startPoint, tolerance, Int32(maxIterations),
                                        &result, &minimum)
        return ok ? (result, minimum) : nil
    }
}

extension MathSolver {

    /// Spherical linear interpolation (SLERP) between two quaternions.
    public static func quaternionSlerp(
        from q1: SIMD4<Double>, to q2: SIMD4<Double>, t: Double
    ) -> SIMD4<Double> {
        var rx = 0.0, ry = 0.0, rz = 0.0, rw = 0.0
        OCCTQuaternionSLerp(q1.x, q1.y, q1.z, q1.w,
                            q2.x, q2.y, q2.z, q2.w,
                            t, &rx, &ry, &rz, &rw)
        return SIMD4(rx, ry, rz, rw)
    }

    /// Linear interpolation (NLERP) between two quaternions (result normalized).
    public static func quaternionNlerp(
        from q1: SIMD4<Double>, to q2: SIMD4<Double>, t: Double
    ) -> SIMD4<Double> {
        var rx = 0.0, ry = 0.0, rz = 0.0, rw = 0.0
        OCCTQuaternionNLerp(q1.x, q1.y, q1.z, q1.w,
                            q2.x, q2.y, q2.z, q2.w,
                            t, &rx, &ry, &rz, &rw)
        return SIMD4(rx, ry, rz, rw)
    }

    /// Interpolate between two transforms (translation + rotation via NLerp).
    public static func transformInterpolate(
        from: (translation: SIMD3<Double>, quaternion: SIMD4<Double>),
        to: (translation: SIMD3<Double>, quaternion: SIMD4<Double>),
        t: Double
    ) -> (translation: SIMD3<Double>, quaternion: SIMD4<Double>) {
        var rtx = 0.0, rty = 0.0, rtz = 0.0
        var rqx = 0.0, rqy = 0.0, rqz = 0.0, rqw = 0.0
        OCCTTrsfInterpolate(from.translation.x, from.translation.y, from.translation.z,
                            from.quaternion.x, from.quaternion.y, from.quaternion.z, from.quaternion.w,
                            to.translation.x, to.translation.y, to.translation.z,
                            to.quaternion.x, to.quaternion.y, to.quaternion.z, to.quaternion.w,
                            t, &rtx, &rty, &rtz, &rqx, &rqy, &rqz, &rqw)
        return (SIMD3(rtx, rty, rtz), SIMD4(rqx, rqy, rqz, rqw))
    }
}

extension MathSolver {

    /// Find root of f(x)=0 in [bound1, bound2] using Brent's method (no derivative needed internally, but callback provides it).
    public static func bracketedRoot(
        in range: ClosedRange<Double>,
        tolerance: Double = 1e-10,
        maxIterations: Int = 100,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> (root: Double, iterations: Int)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var isDone = false
        var nbIter: Int32 = 0
        let result = OCCTMathBracketedRoot(callback, ptr, range.lowerBound, range.upperBound,
                                           tolerance, Int32(maxIterations), &isDone, &nbIter)
        return isDone ? (result, Int(nbIter)) : nil
    }

    /// Bracket a minimum of f(x) starting from two points.
    public static func bracketMinimum(
        a: Double, b: Double,
        function: @escaping (Double) -> Double
    ) -> (a: Double, b: Double, c: Double, fa: Double, fb: Double, fc: Double)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ptr).release() }

        let callback: OCCTMathSimpleFuncCallback = { x, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ctx).takeUnretainedValue()
            value.pointee = box.closure(x)
            return true
        }

        var ra = 0.0, rb = 0.0, rc = 0.0
        var fa = 0.0, fb = 0.0, fc = 0.0
        guard OCCTMathBracketMinimum(callback, ptr, a, b, &ra, &rb, &rc, &fa, &fb, &fc) else { return nil }
        return (ra, rb, rc, fa, fb, fc)
    }

    /// Minimize using Fletcher-Reeves-Polak-Ribiere conjugate gradient.
    public static func minimizeFRPR(
        startPoint: [Double],
        tolerance: Double = 1e-8,
        maxIterations: Int = 200,
        function: @escaping ([Double]) -> (value: Double, gradient: [Double])
    ) -> (location: [Double], minimum: Double, iterations: Int)? {
        let nVars = startPoint.count
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<([Double]) -> (value: Double, gradient: [Double])>>.fromOpaque(ptr).release() }

        let callback: OCCTMathMultiVarGradCallback = { x, n, value, gradient, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<([Double]) -> (value: Double, gradient: [Double])>>.fromOpaque(ctx).takeUnretainedValue()
            let input = Array(UnsafeBufferPointer(start: x, count: Int(n)))
            let result = box.closure(input)
            value.pointee = result.value
            for i in 0..<Int(n) { gradient[i] = result.gradient[i] }
            return true
        }

        var result = [Double](repeating: 0, count: nVars)
        var minimum = 0.0
        var nbIter: Int32 = 0
        guard OCCTMathFRPR(Int32(nVars), callback, ptr, startPoint, tolerance,
                           Int32(maxIterations), &result, &minimum, &nbIter) else { return nil }
        return (result, minimum, Int(nbIter))
    }

    /// Find all roots of f(x)=0 in a range using sampling + refinement.
    ///
    /// `samples` is bounded the same way as the other `findAllRoots` overload's, and for the
    /// same reason (#640).
    public static func findAllRoots(
        in range: ClosedRange<Double>,
        samples: Int = 100,
        epsX: Double = 1e-8,
        epsF: Double = 1e-8,
        epsNul: Double = 1e-8,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> [Double] {
        guard let samples = Sampling.requested(samples) else { return [] }
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var roots = [Double](repeating: 0, count: 1000)
        let n = OCCTMathFunctionAllRoots(callback, ptr, range.lowerBound, range.upperBound,
                                         Int32(samples), epsX, epsF, epsNul, &roots, 1000)
        return Array(roots.prefix(Int(n)))
    }

    /// Solve overdetermined linear system Ax=b in least-squares sense.
    ///
    /// `rows` and `cols` must both be positive and match `matrix`/`rhs`'s real lengths
    /// exactly (#640). Before this guard there was no consistency check at all -- unlike
    /// `MathSVD.solve`/`MathHouseholder.solve`, which already checked `matrix.count ==
    /// rows * cols` -- so a positive `rows`/`cols` that did not match `matrix`/`rhs`'s real
    /// length reached the bridge's unconditional `matA[i*nCols+j]`/`b[i]` loops and read out
    /// of bounds: not a trap, a silent wrong answer built from whatever memory happened to
    /// follow the two arrays.
    public static func leastSquares(
        matrix: [Double], rows: Int, cols: Int,
        rhs: [Double]
    ) -> [Double]? {
        guard rows > 0, cols > 0, matrix.count == rows * cols, rhs.count == rows else { return nil }
        var x = [Double](repeating: 0, count: cols)
        guard OCCTMathGaussLeastSquare(matrix, Int32(rows), Int32(cols), rhs, &x) else { return nil }
        return x
    }

    /// Find root using Newton's method from a guess.
    public static func newtonRoot(
        guess: Double,
        epsX: Double = 1e-10,
        epsF: Double = 1e-10,
        maxIterations: Int = 100,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> (root: Double, derivative: Double, iterations: Int)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var isDone = false
        var deriv = 0.0
        var nbIter: Int32 = 0
        let root = OCCTMathNewtonFunctionRoot(callback, ptr, guess, epsX, epsF,
                                              Int32(maxIterations), &isDone, &deriv, &nbIter)
        return isDone ? (root, deriv, Int(nbIter)) : nil
    }

    /// Solve constrained optimization via Uzawa method.
    /// Minimize ||x||^2 subject to constraintMatrix * x = constraintRHS.
    ///
    /// `nConstraints` and `nVars` must both be positive, and `constraintMatrix`/
    /// `constraintRHS`/`startPoint` must each match them exactly (#640): none of this was
    /// checked before, so the bridge's unconditional `contData[i*nVars+j]`/`secont[i]`/
    /// `startPoint[i]` loops read out of bounds on any mismatch.
    public static func uzawa(
        constraintMatrix: [Double], nConstraints: Int, nVars: Int,
        constraintRHS: [Double],
        startPoint: [Double],
        epsLix: Double = 1e-6, epsLic: Double = 1e-6,
        maxIterations: Int = 500
    ) -> (result: [Double], iterations: Int)? {
        guard nConstraints > 0, nVars > 0,
              constraintMatrix.count == nConstraints * nVars,
              constraintRHS.count == nConstraints,
              startPoint.count == nVars
        else { return nil }
        var result = [Double](repeating: 0, count: nVars)
        var nbIter: Int32 = 0
        guard OCCTMathUzawa(constraintMatrix, Int32(nConstraints), Int32(nVars),
                            constraintRHS, startPoint, epsLix, epsLic, Int32(maxIterations),
                            &result, &nbIter) else { return nil }
        return (result, Int(nbIter))
    }

    /// Find eigenvalues of a symmetric tridiagonal matrix.
    /// diagonal and subdiagonal must be same length (last subdiagonal element unused).
    ///
    /// That "must" was only ever documentation until #640: the bridge loops
    /// `subdiagonal[i]` for `i in 0..<diagonal.count` unconditionally, so a shorter
    /// `subdiagonal` read out of bounds rather than failing.
    public static func eigenvalues(
        diagonal: [Double], subdiagonal: [Double]
    ) -> [Double]? {
        guard subdiagonal.count == diagonal.count else { return nil }
        let n = diagonal.count
        var eigenvalues = [Double](repeating: 0, count: n)
        let count = OCCTMathEigenValues(diagonal, subdiagonal, Int32(n), &eigenvalues)
        return count > 0 ? Array(eigenvalues.prefix(Int(count))) : nil
    }

    /// Find eigenvalues and eigenvectors of a symmetric tridiagonal matrix.
    ///
    /// Same guard as `eigenvalues`, and for the same reason (#640).
    public static func eigenvaluesAndVectors(
        diagonal: [Double], subdiagonal: [Double]
    ) -> (eigenvalues: [Double], eigenvectors: [[Double]])? {
        guard subdiagonal.count == diagonal.count else { return nil }
        let n = diagonal.count
        var eigenvalues = [Double](repeating: 0, count: n)
        var eigenvectors = [Double](repeating: 0, count: n * n)
        let count = OCCTMathEigenValuesAndVectors(diagonal, subdiagonal, Int32(n), &eigenvalues, &eigenvectors)
        guard count > 0 else { return nil }
        let evs = (0..<Int(count)).map { i in Array(eigenvectors[(i*n)..<(i*n+n)]) }
        return (Array(eigenvalues.prefix(Int(count))), evs)
    }

    /// Gauss-Kronrod integration of f(x) over an interval.
    public static func kronrodIntegrate(
        over range: ClosedRange<Double>,
        points: Int = 15,
        function: @escaping (Double) -> Double
    ) -> (value: Double, error: Double)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ptr).release() }

        let callback: OCCTMathSimpleFuncCallback = { x, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ctx).takeUnretainedValue()
            value.pointee = box.closure(x)
            return true
        }

        var isDone = false
        var error = 0.0
        let result = OCCTMathKronrodIntegration(callback, ptr, range.lowerBound, range.upperBound,
                                                Int32(points), &isDone, &error)
        return isDone ? (result, error) : nil
    }

    /// Adaptive Gauss-Kronrod integration with tolerance.
    public static func kronrodIntegrateAdaptive(
        over range: ClosedRange<Double>,
        points: Int = 15,
        tolerance: Double = 1e-10,
        maxIterations: Int = 100,
        function: @escaping (Double) -> Double
    ) -> (value: Double, error: Double, iterations: Int)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ptr).release() }

        let callback: OCCTMathSimpleFuncCallback = { x, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ctx).takeUnretainedValue()
            value.pointee = box.closure(x)
            return true
        }

        var isDone = false
        var error = 0.0
        var nbIter: Int32 = 0
        let result = OCCTMathKronrodIntegrationAdaptive(callback, ptr, range.lowerBound, range.upperBound,
                                                        Int32(points), tolerance, Int32(maxIterations),
                                                        &isDone, &error, &nbIter)
        return isDone ? (result, error, Int(nbIter)) : nil
    }

    /// Multi-dimensional Gauss-Legendre integration.
    ///
    /// `upper` and `order` must have the same length as `lower` (#640): the bridge derives
    /// `nVars` from `lower.count` alone and then loops `upper[i]`/`order[i]` for
    /// `i in 0..<nVars` unconditionally, so a shorter `upper` or `order` read out of bounds.
    public static func gaussMultipleIntegration(
        lower: [Double], upper: [Double], order: [Int],
        function: @escaping ([Double]) -> Double
    ) -> Double? {
        guard upper.count == lower.count, order.count == lower.count else { return nil }
        let nVars = lower.count
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<([Double]) -> Double>>.fromOpaque(ptr).release() }

        let callback: OCCTMathMultiVarCallback = { x, n, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<([Double]) -> Double>>.fromOpaque(ctx).takeUnretainedValue()
            let input = Array(UnsafeBufferPointer(start: x, count: Int(n)))
            value.pointee = box.closure(input)
            return true
        }

        var isDone = false
        let ord = order.map { Int32($0) }
        let result = OCCTMathGaussMultipleIntegration(callback, ptr, Int32(nVars), lower, upper, ord, &isDone)
        return isDone ? result : nil
    }

    /// Gauss-Legendre integration for function sets.
    ///
    /// `nEquations` must be positive, and `upper`/`order` must have the same length as
    /// `lower` (#640): the first was an `Array(repeating:count:)` trap on a negative
    /// `nEquations`, and the second is the same unguarded `upper[i]`/`order[i]` read as
    /// `gaussMultipleIntegration`.
    public static func gaussSetIntegration(
        nEquations: Int,
        lower: [Double], upper: [Double], order: [Int],
        function: @escaping ([Double]) -> [Double]
    ) -> [Double]? {
        guard nEquations > 0, upper.count == lower.count, order.count == lower.count
        else { return nil }
        let nVars = lower.count
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<([Double]) -> [Double]>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncSetCallback = { x, nv, values, ne, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<([Double]) -> [Double]>>.fromOpaque(ctx).takeUnretainedValue()
            let input = Array(UnsafeBufferPointer(start: x, count: Int(nv)))
            let result = box.closure(input)
            for i in 0..<Int(ne) { values[i] = result[i] }
            return true
        }

        var result = [Double](repeating: 0, count: nEquations)
        let ord = order.map { Int32($0) }
        guard OCCTMathGaussSetIntegration(callback, ptr, Int32(nVars), Int32(nEquations),
                                          lower, upper, ord, &result) else { return nil }
        return result
    }
}

extension MathSolver {

    /// Gauss-Legendre quadrature using rc4 MathInteg templates.
    public static func integGauss(
        over range: ClosedRange<Double>,
        points: Int = 15,
        function: @escaping (Double) -> Double
    ) -> (value: Double, error: Double)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ptr).release() }

        let callback: OCCTMathSimpleFuncCallback = { x, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ctx).takeUnretainedValue()
            value.pointee = box.closure(x)
            return true
        }

        var isDone = false
        var error = 0.0
        let result = OCCTMathIntegGauss(callback, ptr, range.lowerBound, range.upperBound,
                                        Int32(points), &isDone, &error)
        return isDone ? (result, error) : nil
    }

    /// Adaptive Gauss-Legendre using rc4 MathInteg templates.
    public static func integGaussAdaptive(
        over range: ClosedRange<Double>,
        tolerance: Double = 1e-10,
        maxIterations: Int = 100,
        function: @escaping (Double) -> Double
    ) -> (value: Double, error: Double, iterations: Int)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ptr).release() }

        let callback: OCCTMathSimpleFuncCallback = { x, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ctx).takeUnretainedValue()
            value.pointee = box.closure(x)
            return true
        }

        var isDone = false
        var error = 0.0
        var nbIter: Int32 = 0
        let result = OCCTMathIntegGaussAdaptive(callback, ptr, range.lowerBound, range.upperBound,
                                                tolerance, Int32(maxIterations),
                                                &isDone, &error, &nbIter)
        return isDone ? (result, error, Int(nbIter)) : nil
    }

    /// Gauss-Kronrod rule using rc4 MathInteg templates.
    public static func integKronrod(
        over range: ClosedRange<Double>,
        gaussPoints: Int = 7,
        function: @escaping (Double) -> Double
    ) -> (value: Double, error: Double)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ptr).release() }

        let callback: OCCTMathSimpleFuncCallback = { x, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ctx).takeUnretainedValue()
            value.pointee = box.closure(x)
            return true
        }

        var isDone = false
        var error = 0.0
        let result = OCCTMathIntegKronrod(callback, ptr, range.lowerBound, range.upperBound,
                                          Int32(gaussPoints), &isDone, &error)
        return isDone ? (result, error) : nil
    }

    /// Adaptive Gauss-Kronrod using rc4 MathInteg templates.
    public static func integKronrodAdaptive(
        over range: ClosedRange<Double>,
        gaussPoints: Int = 7,
        tolerance: Double = 1e-10,
        maxIterations: Int = 100,
        function: @escaping (Double) -> Double
    ) -> (value: Double, error: Double, iterations: Int)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ptr).release() }

        let callback: OCCTMathSimpleFuncCallback = { x, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ctx).takeUnretainedValue()
            value.pointee = box.closure(x)
            return true
        }

        var isDone = false
        var error = 0.0
        var nbIter: Int32 = 0
        let result = OCCTMathIntegKronrodAdaptive(callback, ptr, range.lowerBound, range.upperBound,
                                                  Int32(gaussPoints), tolerance, Int32(maxIterations),
                                                  &isDone, &error, &nbIter)
        return isDone ? (result, error, Int(nbIter)) : nil
    }

    /// Tanh-Sinh (double exponential) quadrature using rc4 MathInteg templates.
    public static func integTanhSinh(
        over range: ClosedRange<Double>,
        tolerance: Double = 1e-10,
        maxLevels: Int = 6,
        function: @escaping (Double) -> Double
    ) -> (value: Double, error: Double, iterations: Int)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ptr).release() }

        let callback: OCCTMathSimpleFuncCallback = { x, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> Double>>.fromOpaque(ctx).takeUnretainedValue()
            value.pointee = box.closure(x)
            return true
        }

        var isDone = false
        var error = 0.0
        var nbIter: Int32 = 0
        let result = OCCTMathIntegTanhSinh(callback, ptr, range.lowerBound, range.upperBound,
                                           tolerance, Int32(maxLevels),
                                           &isDone, &error, &nbIter)
        return isDone ? (result, error, Int(nbIter)) : nil
    }
}
