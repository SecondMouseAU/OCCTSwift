import Foundation
import simd

// MARK: - ISO 5457 / 7200 / 5456-2 drawing sheet scaffolding (#76, v0.145)
//
// Every technical drawing has the same structural boilerplate: a trimmed-sheet
// frame with the correct ISO 5457 margins, an ISO 7200 title block, and an
// ISO 5456-2 projection-angle symbol. This file encodes all of that so
// downstream consumers don't re-implement it.
//
// Usage pattern:
//
//   let sheet = Sheet(size: .a3, orientation: .landscape,
//                     projection: .first,
//                     title: TitleBlock(title: "Bracket", drawingNumber: "B-001"))
//   let writer = DXFWriter()
//   sheet.render(into: writer)
//   for (view, placement) in multiView {
//       writer.collectFromDrawing(view.transformed(translate: placement.offset,
//                                                   scale: placement.scale))
//   }
//   try writer.write(to: url)

// MARK: - ISO 5457 paper sizes

public enum PaperSize: String, Sendable, Hashable, CaseIterable {
    case a0, a1, a2, a3, a4

    /// ISO 5457 trimmed-sheet dimensions in mm, landscape orientation.
    public var dimensions: SIMD2<Double> {
        switch self {
        case .a0: return SIMD2(1189, 841)
        case .a1: return SIMD2(841, 594)
        case .a2: return SIMD2(594, 420)
        case .a3: return SIMD2(420, 297)
        case .a4: return SIMD2(297, 210)
        }
    }

    public func size(in orientation: Orientation) -> SIMD2<Double> {
        switch orientation {
        case .landscape: return dimensions
        case .portrait: return SIMD2(dimensions.y, dimensions.x)
        }
    }
}

public enum Orientation: String, Sendable, Hashable {
    case landscape
    case portrait
}

/// ISO 5456-2 projection-angle convention.
public enum ProjectionAngle: String, Sendable, Hashable {
    case first  // ISO / Europe: top view below front view
    case third  // ANSI / USA: top view above front view
}

// MARK: - ISO 7200 title block

public struct TitleBlock: Sendable, Hashable {
    // ISO 7200 mandatory fields
    public var title: String
    public var drawingNumber: String?
    public var owner: String?
    public var creator: String?
    public var approver: String?
    public var documentType: String?
    public var dateOfIssue: String?  // ISO 8601 recommended

    // ISO 7200 optional fields commonly present
    public var revision: String?
    public var sheetNumber: String?
    public var language: String?
    public var material: String?
    public var weight: String?
    public var scale: String?

    public init(
        title: String,
        drawingNumber: String? = nil,
        owner: String? = nil,
        creator: String? = nil,
        approver: String? = nil,
        documentType: String? = nil,
        dateOfIssue: String? = nil,
        revision: String? = nil,
        sheetNumber: String? = nil,
        language: String? = nil,
        material: String? = nil,
        weight: String? = nil,
        scale: String? = nil
    ) {
        self.title = title
        self.drawingNumber = drawingNumber
        self.owner = owner
        self.creator = creator
        self.approver = approver
        self.documentType = documentType
        self.dateOfIssue = dateOfIssue
        self.revision = revision
        self.sheetNumber = sheetNumber
        self.language = language
        self.material = material
        self.weight = weight
        self.scale = scale
    }
}

// MARK: - Sheet

public struct Sheet: Sendable, Hashable {
    public var size: PaperSize
    public var orientation: Orientation
    public var projection: ProjectionAngle
    public var title: TitleBlock?
    public var scale: String

    public init(
        size: PaperSize,
        orientation: Orientation = .landscape,
        projection: ProjectionAngle = .first,
        title: TitleBlock? = nil,
        scale: String = "1:1"
    ) {
        self.size = size
        self.orientation = orientation
        self.projection = projection
        self.title = title
        self.scale = scale
    }

    /// Overall sheet dimensions in mm.
    public var dimensions: SIMD2<Double> { size.size(in: orientation) }

    /// The drawable area inside the border (the "inner frame"). ISO 5457
    /// specifies a 20 mm binding margin on the left and 10 mm on the other
    /// three edges for A0-A3; 7 mm / 7 mm / 7 mm / 10 mm for A4.
    public var inset: (left: Double, right: Double, top: Double, bottom: Double) {
        switch size {
        case .a0, .a1, .a2, .a3:
            return (left: 20, right: 10, top: 10, bottom: 10)
        case .a4:
            return (left: 20, right: 10, top: 10, bottom: 10)
        }
    }

    /// Inner drawable rectangle corners.
    public var innerFrame: (min: SIMD2<Double>, max: SIMD2<Double>) {
        let d = dimensions
        let ins = inset
        return (
            min: SIMD2(ins.left, ins.bottom),
            max: SIMD2(d.x - ins.right, d.y - ins.top)
        )
    }

    /// Render the border + centring marks + title block + projection symbol
    /// onto the writer. Uses BORDER, TITLE, TEXT, and CENTER layers.
    public func render(into writer: DXFWriter) {
        let d = dimensions
        // Outer trimmed sheet edge
        let outer: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(d.x, 0), SIMD2(d.x, d.y), SIMD2(0, d.y),
        ]
        writer.addPolyline(outer, closed: true, layer: "BORDER")

        // Inner frame (drawable area)
        let frame = innerFrame
        let inner: [SIMD2<Double>] = [
            SIMD2(frame.min.x, frame.min.y),
            SIMD2(frame.max.x, frame.min.y),
            SIMD2(frame.max.x, frame.max.y),
            SIMD2(frame.min.x, frame.max.y),
        ]
        writer.addPolyline(inner, closed: true, layer: "BORDER")

        // Centring marks at the midpoints of each inner-frame edge — short
        // ticks projecting from the outer edge inward.
        let tickLen = 5.0
        for mark in [
            SIMD2(frame.min.x + (frame.max.x - frame.min.x) / 2, 0),  // bottom
            SIMD2(frame.min.x + (frame.max.x - frame.min.x) / 2, d.y),  // top
            SIMD2(0, frame.min.y + (frame.max.y - frame.min.y) / 2),  // left
            SIMD2(d.x, frame.min.y + (frame.max.y - frame.min.y) / 2),  // right
        ] {
            if mark.x == 0 {
                writer.addLine(from: mark, to: SIMD2(tickLen, mark.y), layer: "CENTER")
            } else if mark.x == d.x {
                writer.addLine(from: mark, to: SIMD2(d.x - tickLen, mark.y), layer: "CENTER")
            } else if mark.y == 0 {
                writer.addLine(from: mark, to: SIMD2(mark.x, tickLen), layer: "CENTER")
            } else {
                writer.addLine(from: mark, to: SIMD2(mark.x, d.y - tickLen), layer: "CENTER")
            }
        }

        // Title block in the bottom-right.
        if let title = title {
            renderTitleBlock(title, into: writer, frame: frame)
        }

        // Projection symbol above the title block.
        let symbolOrigin = SIMD2(frame.max.x - 40, frame.min.y + 65)
        ProjectionSymbol.render(projection, at: symbolOrigin, into: writer)
    }

    private func renderTitleBlock(
        _ tb: TitleBlock,
        into writer: DXFWriter,
        frame: (min: SIMD2<Double>, max: SIMD2<Double>)
    ) {
        // Simplified ISO 7200 title block: a 170x55 mm rectangle in the
        // bottom-right of the drawable frame, divided into fields.
        let tbWidth = 170.0
        let tbHeight = 55.0
        let origin = SIMD2(frame.max.x - tbWidth, frame.min.y)
        let outer: [SIMD2<Double>] = [
            origin,
            SIMD2(origin.x + tbWidth, origin.y),
            SIMD2(origin.x + tbWidth, origin.y + tbHeight),
            SIMD2(origin.x, origin.y + tbHeight),
        ]
        writer.addPolyline(outer, closed: true, layer: "TITLE")

        // Field labels and values. Simplified two-column layout: labels left
        // of each row, values on the right of the row.
        let labelH = 2.5
        let valueH = 3.5
        let rowH = tbHeight / 4

        func addField(row: Int, col: Int, label: String, value: String?) {
            let x = origin.x + 5 + Double(col) * (tbWidth / 2)
            let y = origin.y + tbHeight - rowH * Double(row + 1) + 2
            writer.addText(label, at: SIMD2(x, y + 5), height: labelH, layer: "TEXT")
            if let value = value {
                writer.addText(value, at: SIMD2(x, y), height: valueH, layer: "TEXT")
            }
        }

        addField(row: 0, col: 0, label: "TITLE", value: tb.title)
        addField(row: 0, col: 1, label: "DWG NO", value: tb.drawingNumber)
        addField(row: 1, col: 0, label: "OWNER", value: tb.owner)
        addField(row: 1, col: 1, label: "SCALE", value: tb.scale ?? self.scale)
        addField(row: 2, col: 0, label: "CREATED BY", value: tb.creator)
        addField(row: 2, col: 1, label: "DATE", value: tb.dateOfIssue)
        addField(row: 3, col: 0, label: "DOC TYPE", value: tb.documentType)
        addField(row: 3, col: 1, label: "REV", value: tb.revision)
    }
}

// MARK: - ISO 5456-2 projection symbol

public enum ProjectionSymbol {
    /// Render a projection-angle symbol at the given 2D origin.
    /// First-angle symbol: truncated-cone front view on the left, circle side
    ///                     view on the right.
    /// Third-angle symbol: circle side view on the left, truncated-cone front
    ///                     view on the right.
    public static func render(
        _ angle: ProjectionAngle,
        at origin: SIMD2<Double>,
        into writer: DXFWriter
    ) {
        // Symbol is 30mm wide, 15mm tall — two shapes separated by a gap.
        let frontFaceW = 12.0
        let frontFaceH = 10.0
        let circleR = 5.0
        let gap = 3.0

        // Truncated-cone front view: rectangle with sloped edges.
        // Front face (the small disc's projection as a rectangle).
        let coneLeft: Double
        let coneRight: Double
        let circleCentreX: Double
        switch angle {
        case .first:
            coneLeft = origin.x
            coneRight = origin.x + frontFaceW
            circleCentreX = coneRight + gap + circleR
        case .third:
            circleCentreX = origin.x + circleR
            coneLeft = circleCentreX + circleR + gap
            coneRight = coneLeft + frontFaceW
        }

        let coneBase = origin.y + (frontFaceH / 2 - 2)
        let coneTop = origin.y + (frontFaceH / 2 + 2)
        // Outer "base" circle (truncated-cone base, rendered as a tall rectangle here)
        writer.addLine(
            from: SIMD2(coneLeft, coneBase),
            to: SIMD2(coneLeft, coneTop), layer: "TEXT")
        writer.addLine(
            from: SIMD2(coneLeft, coneBase),
            to: SIMD2(coneRight, coneBase - 1), layer: "TEXT")
        writer.addLine(
            from: SIMD2(coneLeft, coneTop),
            to: SIMD2(coneRight, coneTop + 1), layer: "TEXT")
        writer.addLine(
            from: SIMD2(coneRight, coneBase - 1),
            to: SIMD2(coneRight, coneTop + 1), layer: "TEXT")

        // Circle side view
        writer.addCircle(
            centre: SIMD2(circleCentreX, origin.y + frontFaceH / 2),
            radius: circleR, layer: "TEXT")
        writer.addCircle(
            centre: SIMD2(circleCentreX, origin.y + frontFaceH / 2),
            radius: circleR * 0.4, layer: "TEXT")
    }
}
