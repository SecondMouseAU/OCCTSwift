import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_VisMaterialCommon Tests")
struct VisMaterialCommonTests {
    /// OCCT's own default constructor (`XCAFDoc_VisMaterialCommon.hxx`): ambient 0.1, diffuse 0.8,
    /// specular 0.2, emissive 0, shininess 1, transparency 0, defined. Every member is read, so a
    /// default copied from the wrong colour slot shows.
    @Test func defaultValues() {
        let mat = VisMaterialCommon()
        #expect(mat.isDefined)
        for (name, c, expected) in [
            ("ambient", mat.ambientColor, 0.1), ("diffuse", mat.diffuseColor, 0.8),
            ("specular", mat.specularColor, 0.2), ("emissive", mat.emissiveColor, 0.0),
        ] {
            #expect(abs(c.red - expected) < 1e-6, "\(name) red")
            #expect(abs(c.green - expected) < 1e-6, "\(name) green")
            #expect(abs(c.blue - expected) < 1e-6, "\(name) blue")
        }
        #expect(mat.shininess == 1.0)
        #expect(mat.transparency == 0.0)
        #expect(VisMaterialCommon().isEqual(to: mat))
    }

    @Test func setProperties() {
        var mat = VisMaterialCommon()
        mat.diffuseColor = (1.0, 0.25, 0.5)
        mat.shininess = 0.5
        mat.transparency = 0.3
        // Three different channel values, so a swapped channel is seen.
        #expect(mat.diffuseColor.red == 1.0)
        #expect(mat.diffuseColor.green == 0.25)
        #expect(mat.diffuseColor.blue == 0.5)
        #expect(abs(mat.shininess - 0.5) < 1e-6)
        #expect(abs(mat.transparency - 0.3) < 1e-6)
        // The other colours stay at the defaults: setting one does not write through to another.
        #expect(abs(mat.ambientColor.red - 0.1) < 1e-6)
        #expect(abs(mat.specularColor.red - 0.2) < 1e-6)
        #expect(mat.emissiveColor.red == 0.0)
        // And it is no longer the default.
        #expect(!mat.isEqual(to: VisMaterialCommon()))
    }

    @Test func equality() {
        func configured() -> VisMaterialCommon {
            var m = VisMaterialCommon()
            m.diffuseColor = (1.0, 0.0, 0.0)
            m.shininess = 0.5
            m.transparency = 0.3
            return m
        }
        let m1 = configured()
        #expect(m1.isEqual(to: configured()))
        #expect(configured().isEqual(to: m1))
        #expect(m1.isEqual(to: m1))

        // One property at a time: each variant differs from `m1` in that property only, so an
        // equality that ignores a property reads its variant as equal.
        var diffuse = m1
        diffuse.diffuseColor = (0.0, 1.0, 0.0)
        var ambient = m1
        ambient.ambientColor = (0.5, 0.1, 0.1)
        var specular = m1
        specular.specularColor = (0.2, 0.5, 0.2)
        var emissive = m1
        emissive.emissiveColor = (0.0, 0.0, 0.5)
        var shininess = m1
        shininess.shininess = 0.75
        var transparency = m1
        transparency.transparency = 0.6
        var undefined = m1
        undefined.isDefined = false
        let variants: [(String, VisMaterialCommon)] = [
            ("diffuse", diffuse), ("ambient", ambient), ("specular", specular),
            ("emissive", emissive), ("shininess", shininess), ("transparency", transparency),
            ("defined", undefined),
        ]
        for (name, other) in variants {
            #expect(!m1.isEqual(to: other), "differs in \(name) only")
            #expect(!other.isEqual(to: m1), "differs in \(name) only, reversed")
        }

        // OCCT's IsEqual treats two undefined materials as equal whatever they carry, which is
        // the other half of the `defined` row above.
        var undefinedOther = diffuse
        undefinedOther.isDefined = false
        #expect(undefined.isEqual(to: undefinedOther))
    }

    @Test("Common-material roughness fallback uses OCCT's [0,1] Shininess scale (#1508)")
    func commonMaterialRoughnessFromShininess() throws {
        // #1508: OCCTDocumentGetLabelMaterial's HasCommonMaterial() fallback computed
        // `1.0 - (common.Shininess / 100.0)`, treating a [0,1]-range Shininess
        // (XCAFDoc_VisMaterialCommon.hxx's own default ctor, `Shininess(1.0f)`) as if it were on a
        // 0-100 scale, collapsing every legitimate value into [0.99, 1.0] -- a fully glossy
        // material (Shininess 1.0) reported as nearly fully matte.
        //
        // No OCCTSwift entry point writes a Common material directly (OCCTDocumentSetLabelMaterial
        // only ever constructs a PBR one), so this reaches the fallback the same way real callers
        // do: plain OBJ/MTL import. RWObj_CafReader.cxx sets Shininess directly from the .mtl
        // file's `Ns` keyword and never touches PBR; RWObj_MtlReader.cxx normalizes `Ns` to [0,1]
        // via `min(Ns / 1000.0, 1.0)`, so `Ns 300.0` here becomes Shininess 0.3.
        //
        // The `g` group directive is load-bearing, not decoration: RWObj_TriangulationReader binds
        // an unnamed face's material to a Style attribute that RWMesh_CafReader stores on a
        // SubShape label (a per-face color/material override), which the ordinary
        // component/assembly walk `AssemblyNode.children` uses never visits. Naming the face's
        // group gives it a non-empty RWMesh_NodeAttributes.Name, which makes
        // RWMesh_CafReader::addShapeIntoDoc treat the object as an assembly and add the face as a
        // genuine XCAF component instead -- reachable, one level down, via `doc.shapesWithMaterials()`
        // (confirmed empirically: without `g`, `shapesWithMaterials()` returns no material at all,
        // even though the shape itself still imports and reads fine).
        //
        // A specular color with luma intensity >= 0.1 keeps
        // Graphic3d_PBRMaterial::RoughnessFromSpecular's low-intensity correction inert (see
        // OCCTMaterialRoughnessFromSpecular, the helper the fix now reuses), so the expected
        // roughness is exactly `1.0 - Shininess` = 0.7, matching OCCT's own reciprocal conversion
        // (XCAFDoc_VisMaterial.cxx's ConvertToCommonMaterial: `Shininess = 1.0f - Roughness`). The
        // old formula gave 1.0 - (0.3 / 100.0) = 0.997.
        let tmpDir = FileManager.default.temporaryDirectory
        // A name per run: the temp directory is shared with every parallel test in the process.
        let stem = "issue1508_roughness_test_\(UUID().uuidString)"
        let objURL = tmpDir.appendingPathComponent("\(stem).obj")
        let mtlURL = tmpDir.appendingPathComponent("\(stem).mtl")
        defer {
            try? FileManager.default.removeItem(at: objURL)
            try? FileManager.default.removeItem(at: mtlURL)
        }

        let mtlContents = """
            newmtl Issue1508Material
            Ka 0.1 0.1 0.1
            Kd 0.8 0.8 0.8
            Ks 0.8 0.8 0.8
            Ns 300.0
            """
        let objContents = """
            mtllib \(stem).mtl
            g Issue1508Group
            usemtl Issue1508Material
            v 0 0 0
            v 1 0 0
            v 0 1 0
            f 1 2 3
            """
        // `atomically: false` because `atomically: true` cannot work on WASI: it writes a temp
        // file and renames it, and the rename is unsupported there (`NSCocoaErrorDomain Code=3328`).
        // Nothing is lost by dropping it. Atomicity protects a reader from seeing a half-written
        // file after a crash mid-write, and this is a fixture written and consumed by one test in
        // one process. Measured by #2793's wasm run, which failed these tests on the fixture write
        // rather than on anything they assert.
        try mtlContents.write(to: mtlURL, atomically: false, encoding: .utf8)
        try objContents.write(to: objURL, atomically: false, encoding: .utf8)

        let doc = try #require(Document.loadOBJ(from: objURL), "OBJ import returned nil")

        let materials = doc.shapesWithMaterials().compactMap { $0.material }
        // One face, one group, one material: exactly one, and the first of an empty list would
        // be a failure to import rather than a roughness.
        #expect(materials.count == 1)
        let material = try #require(materials.first, "no material reached the document")

        // 1 - 0.3 = 0.7 on the corrected scale; the #1508 formula gave 0.997. Float arithmetic
        // on Ns / 1000 and the 1 - x conversion is exact to about 1e-7, so 1e-4 still leaves the
        // two formulas 0.297 apart.
        #expect(abs(material.roughness - 0.7) < 1e-4)
    }
}
