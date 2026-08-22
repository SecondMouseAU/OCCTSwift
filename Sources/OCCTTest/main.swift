import Foundation
import OCCTSwift

print("OCCTSwift Test Runner")
print("=====================")
print()

// Test 1: Create primitives
print("1. Creating primitives...")
let box = Shape.box(width: 10, height: 5, depth: 3)!
print("   - Box: \(box.isValid ? "valid" : "invalid")")

let cylinder = Shape.cylinder(radius: 2, height: 8)!
print("   - Cylinder: \(cylinder.isValid ? "valid" : "invalid")")

let sphere = Shape.sphere(radius: 3)!
print("   - Sphere: \(sphere.isValid ? "valid" : "invalid")")

// Test 2: Boolean operations
print()
print("2. Boolean operations...")
let combined = box.union(cylinder.translated(by: [5, 0, 0])!)!
print("   - Union: \(combined.isValid ? "valid" : "invalid")")

let subtracted = box.subtracting(sphere)!
print("   - Subtraction: \(subtracted.isValid ? "valid" : "invalid")")

// Test 3: Wire creation
print()
print("3. Wire creation...")
guard let rect = Wire.rectangle(width: 5, height: 3) else {
    print("   - Rectangle wire creation failed!")
    exit(1)
}
print("   - Rectangle wire created")

guard
    let profile = Wire.polygon(
        [
            SIMD2(0, 0),
            SIMD2(2, 0),
            SIMD2(2, 1),
            SIMD2(1, 1),
            SIMD2(1, 5),
            SIMD2(0, 5),
        ], closed: true)
else {
    print("   - Rail profile wire creation failed!")
    exit(1)
}
print("   - Rail profile wire created")

// Test 4: Sweep operations
print()
print("4. Sweep operations...")
guard let path = Wire.line(from: .zero, to: SIMD3(100, 0, 0)) else {
    print("   - Path wire creation failed!")
    exit(1)
}
let swept = Shape.sweep(profile: rect, along: path)!
print("   - Pipe sweep: \(swept.isValid ? "valid" : "invalid")")

let extruded = Shape.extrude(profile: rect, direction: [0, 0, 1], length: 10)!
print("   - Extrusion: \(extruded.isValid ? "valid" : "invalid")")

// Test 5: Meshing
print()
print("5. Mesh generation...")
let mesh = box.mesh(linearDeflection: 0.1)!
print("   - Vertices: \(mesh.vertices.count)")
print("   - Triangles: \(mesh.indices.count / 3)")

// Test 6: Rail sweep (like RailwayCAD would do)
print()
print("6. Rail sweep simulation...")
guard
    let railProfile = Wire.railProfile(
        headWidth: 2.0,
        headHeight: 1.0,
        webThickness: 0.5,
        baseWidth: 3.0,
        baseHeight: 0.5,
        totalHeight: 5.0
    )
else {
    print("   - Rail profile creation failed!")
    exit(1)
}
print("   - Rail profile created")

guard
    let trackPath = Wire.arc(
        center: SIMD3(0, 500, 0),
        radius: 500,
        startAngle: 0,
        endAngle: .pi / 4,
        normal: SIMD3(0, 0, 1)
    )
else {
    print("   - Track path creation failed!")
    exit(1)
}
print("   - Track curve created (500mm radius, 45 degrees)")

let rail = Shape.sweep(profile: railProfile, along: trackPath)!
print("   - Rail solid: \(rail.isValid ? "valid" : "invalid")")

let railMesh = rail.mesh(linearDeflection: 0.05)!
print(
    "   - Rail mesh: \(railMesh.vertices.count) vertices, \(railMesh.indices.count / 3) triangles")

print()
print("All tests completed successfully!")
