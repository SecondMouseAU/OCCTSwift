import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Text Label and Point Cloud")
struct TextLabelAndPointCloudTests {

    @Test("Create text label")
    func createTextLabel() {
        let label = TextLabel(text: "Hello", position: SIMD3(1, 2, 3))
        #expect(label != nil)
        #expect(label!.text == "Hello")
    }

    @Test("Text label position")
    func textLabelPosition() {
        let label = TextLabel(text: "Test", position: SIMD3(10, 20, 30))!
        let pos = label.position
        #expect(abs(pos.x - 10) < 1e-6)
        #expect(abs(pos.y - 20) < 1e-6)
        #expect(abs(pos.z - 30) < 1e-6)
    }

    @Test("Update text label text")
    func updateText() {
        let label = TextLabel(text: "Original", position: .zero)!
        label.text = "Updated"
        #expect(label.text == "Updated")
    }

    @Test("Update text label position")
    func updatePosition() {
        let label = TextLabel(text: "Test", position: .zero)!
        label.position = SIMD3(5, 10, 15)
        let pos = label.position
        #expect(abs(pos.x - 5) < 1e-6)
        #expect(abs(pos.y - 10) < 1e-6)
    }

    @Test("Text label default height matches OCCT's own default (#1417)")
    func textLabelDefaultHeightMatchesOCCT() {
        // Prs3d_TextAspect's own default constructor is myHeight(16.0)
        // (Prs3d_TextAspect.cxx:29,40), not the 12.0 this used to hardcode unconditionally.
        let label = TextLabel(text: "Test", position: .zero)!
        var info = OCCTTextLabelInfo()
        #expect(OCCTTextLabelGetInfo(label.handle, &info))
        #expect(abs(info.height - 16.0) < 1e-6)
    }

    @Test("Text label height round-trips through setHeight (#1417)")
    func textLabelHeightRoundTrips() {
        let label = TextLabel(text: "Test", position: .zero)!
        label.setHeight(30.0)
        var info = OCCTTextLabelInfo()
        #expect(OCCTTextLabelGetInfo(label.handle, &info))
        #expect(abs(info.height - 30.0) < 1e-6)
    }

    @Test("Create point cloud")
    func createPointCloud() {
        let pts = [SIMD3<Double>(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)]
        let cloud = PointCloud(points: pts)
        #expect(cloud != nil)
        #expect(cloud!.count == 3)
    }

    @Test("Point cloud bounds")
    func pointCloudBounds() {
        let pts = [SIMD3<Double>(1, 2, 3), SIMD3(4, 5, 6), SIMD3(-1, 0, 1)]
        let cloud = PointCloud(points: pts)!
        let bounds = cloud.bounds
        #expect(bounds != nil)
        if let b = bounds {
            #expect(abs(b.min.x - (-1)) < 1e-6)
            #expect(abs(b.max.x - 4) < 1e-6)
            #expect(abs(b.min.y - 0) < 1e-6)
            #expect(abs(b.max.y - 5) < 1e-6)
        }
    }

    @Test("Point cloud retrieval")
    func pointCloudRetrieval() {
        let pts = [SIMD3<Double>(1, 2, 3), SIMD3(4, 5, 6)]
        let cloud = PointCloud(points: pts)!
        let retrieved = cloud.points
        #expect(retrieved.count == 2)
        #expect(abs(retrieved[0].x - 1) < 1e-6)
        #expect(abs(retrieved[1].z - 6) < 1e-6)
    }

    @Test("Colored point cloud")
    func coloredPointCloud() {
        let pts = [SIMD3<Double>(0, 0, 0), SIMD3(1, 1, 1)]
        let cols = [SIMD3<Float>(1, 0, 0), SIMD3(0, 1, 0)]
        let cloud = PointCloud(points: pts, colors: cols)
        #expect(cloud != nil)
        #expect(cloud!.count == 2)
        let retrievedColors = cloud!.colors
        #expect(retrievedColors.count == 2)
        #expect(abs(retrievedColors[0].x - 1.0) < 1e-4, "First color should be red")
        #expect(abs(retrievedColors[1].y - 1.0) < 1e-4, "Second color should be green")
    }

    @Test("Empty point cloud returns nil")
    func emptyPointCloud() {
        let cloud = PointCloud(points: [])
        #expect(cloud == nil)
    }
}
