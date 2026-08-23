import Foundation
import simd

// MARK: - Bill of materials + balloon callouts (#87, v0.150)
//
// A `BillOfMaterials` is a pure-Swift value type, the caller populates the
// item rows (manually or from a parts catalog) and the writer renders a table
// onto the drawing. XCAF-backed auto-derivation from an assembly is a future
// follow-up, not scoped into this release.
//
// Balloons (the numbered circles that point at parts and key into BOM rows)
// live in `DrawingAnnotation.balloon`, see the typed `.balloon` case added
// in the same v0.150 arc.

public struct BillOfMaterials: Sendable, Hashable, Codable {
    public var items: [Item]
    public var title: String?

    public struct Item: Sendable, Hashable, Codable {
        public var number: Int
        public var partNumber: String?
        public var description: String
        public var quantity: Int
        public var material: String?
        public var mass: Double?
        public var notes: String?

        public init(
            number: Int,
            partNumber: String? = nil,
            description: String,
            quantity: Int = 1,
            material: String? = nil,
            mass: Double? = nil,
            notes: String? = nil
        ) {
            self.number = number
            self.partNumber = partNumber
            self.description = description
            self.quantity = quantity
            self.material = material
            self.mass = mass
            self.notes = notes
        }
    }

    public init(items: [Item], title: String? = nil) {
        self.items = items
        self.title = title
    }

    /// Column order used by `render(into:at:)`.
    public enum Column: String, Sendable, CaseIterable {
        case item, partNumber, description, quantity, material, mass, notes

        public var header: String {
            switch self {
            case .item: return "ITEM"
            case .partNumber: return "PART NO"
            case .description: return "DESCRIPTION"
            case .quantity: return "QTY"
            case .material: return "MAT"
            case .mass: return "MASS"
            case .notes: return "NOTES"
            }
        }

        public var defaultWidth: Double {
            switch self {
            case .item: return 12
            case .partNumber: return 25
            case .description: return 60
            case .quantity: return 10
            case .material: return 25
            case .mass: return 15
            case .notes: return 30
            }
        }
    }

    /// Render the BOM as a table onto the writer.
    ///
    /// origin is the **bottom-right** corner of the table; the table grows up and.
    /// to the left.
    ///
    /// This matches the idiomatic placement directly above a title.
    /// block.
    ///
    /// Returns the top-right corner of the rendered table, so callers can.
    /// chain subsequent annotations above the BOM.
    @discardableResult
    public func render(
        into writer: DXFWriter,
        at origin: SIMD2<Double>,
        rowHeight: Double = 6,
        columnWidths: [Double]? = nil
    ) -> SIMD2<Double> {
        let columns = Column.allCases
        let widths = columnWidths ?? columns.map(\.defaultWidth)
        guard widths.count == columns.count else { return origin }
        let totalWidth = widths.reduce(0, +)
        let rowCount = items.count + 1  // header + one row per item
        let totalHeight = Double(rowCount) * rowHeight
        let left = origin.x - totalWidth
        let right = origin.x
        let bottom = origin.y
        let top = origin.y + totalHeight

        // Horizontal separators (bottom + between-rows + top).
        for i in 0...rowCount {
            let y = bottom + Double(i) * rowHeight
            writer.addLine(from: SIMD2(left, y), to: SIMD2(right, y), layer: "BORDER")
        }
        // Vertical separators.
        var x = left
        writer.addLine(from: SIMD2(x, bottom), to: SIMD2(x, top), layer: "BORDER")
        for w in widths {
            x += w
            writer.addLine(from: SIMD2(x, bottom), to: SIMD2(x, top), layer: "BORDER")
        }

        // Header row at the top.
        renderRow(
            textsIn: columns.map(\.header),
            widths: widths,
            leftX: left,
            baselineY: top - rowHeight * 0.7,
            into: writer)

        // Data rows descending from the header.
        for (idx, item) in items.enumerated() {
            let rowTextY = top - Double(idx + 2) * rowHeight + rowHeight * 0.3
            let values: [String] = [
                String(item.number),
                item.partNumber ?? "",
                item.description,
                String(item.quantity),
                item.material ?? "",
                item.mass.map { String(format: "%.2f", $0) } ?? "",
                item.notes ?? "",
            ]
            renderRow(
                textsIn: values,
                widths: widths,
                leftX: left,
                baselineY: rowTextY,
                into: writer)
        }

        return SIMD2(right, top)
    }

    private func renderRow(
        textsIn values: [String],
        widths: [Double],
        leftX: Double,
        baselineY: Double,
        into writer: DXFWriter
    ) {
        var x = leftX
        for (i, value) in values.enumerated() {
            let cellLeftPad = 1.5
            writer.addText(
                value, at: SIMD2(x + cellLeftPad, baselineY),
                height: 2.5, layer: "TEXT")
            x += widths[i]
        }
    }
}

extension Sheet {
    /// Draw a BOM in the top-right of the sheet above the title block.
    ///
    /// When origin is nil, the BOM is placed just below the inner frame's top.
    /// edge, right-aligned to the inner frame.
    @discardableResult
    public func renderBOM(
        _ bom: BillOfMaterials,
        into writer: DXFWriter,
        at origin: SIMD2<Double>? = nil,
        rowHeight: Double = 6,
        columnWidths: [Double]? = nil
    ) -> SIMD2<Double> {
        let frame = innerFrame
        let anchor =
            origin ?? SIMD2(frame.max.x, frame.max.y - Double(bom.items.count + 1) * rowHeight)
        return bom.render(
            into: writer, at: anchor, rowHeight: rowHeight, columnWidths: columnWidths)
    }
}
