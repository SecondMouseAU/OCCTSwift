import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_VisMaterialCommon Tests")
struct VisMaterialCommonTests {
    @Test func defaultValues() {
        let mat = VisMaterialCommon()
        #expect(mat.isDefined)
        #expect(abs(mat.diffuseColor.red - 0.8) < 0.02)
    }

    @Test func setProperties() {
        var mat = VisMaterialCommon()
        mat.diffuseColor = (1.0, 0.0, 0.0)
        mat.shininess = 0.5
        mat.transparency = 0.3
        #expect(abs(mat.shininess - 0.5) < 1e-6)
        #expect(abs(mat.transparency - 0.3) < 1e-6)
    }

    @Test func equality() {
        var m1 = VisMaterialCommon()
        m1.diffuseColor = (1.0, 0.0, 0.0)
        m1.shininess = 0.5
        m1.transparency = 0.3
        var m2 = VisMaterialCommon()
        m2.diffuseColor = (1.0, 0.0, 0.0)
        m2.shininess = 0.5
        m2.transparency = 0.3
        #expect(m1.isEqual(to: m2))
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
        let objURL = tmpDir.appendingPathComponent("issue1508_roughness_test.obj")
        let mtlURL = tmpDir.appendingPathComponent("issue1508_roughness_test.mtl")
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
            mtllib issue1508_roughness_test.mtl
            g Issue1508Group
            usemtl Issue1508Material
            v 0 0 0
            v 1 0 0
            v 0 1 0
            f 1 2 3
            """
        try mtlContents.write(to: mtlURL, atomically: true, encoding: .utf8)
        try objContents.write(to: objURL, atomically: true, encoding: .utf8)

        let doc = Document.loadOBJ(from: objURL)
        #expect(doc != nil)
        guard let doc else { return }

        let materials = doc.shapesWithMaterials().compactMap { $0.material }
        #expect(!materials.isEmpty)
        guard let material = materials.first else { return }

        #expect(abs(material.roughness - 0.7) < 0.01)
    }
}
