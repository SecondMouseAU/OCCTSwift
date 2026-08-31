import Foundation
import OCCTBridge

/// Image pixel map wrapping OCCT Image_AlienPixMap.
///
/// Supports creating, reading, writing, and manipulating pixel images.
///
/// `@unchecked Sendable` reflects that `handle` is a plain bridge handle, not that concurrent use
/// of one instance is safe, it isn't: `initTrash`/`initCopy`/`clear`/`setPixel`/`load`/
/// `adjustGamma` all mutate the underlying `Image_AlienPixMap` handle in place with no lock.
/// Serialize mixed access with `OCCTSerial.withLock { }`.
public final class PixMap: @unchecked Sendable {
    /// Image pixel format.
    public enum Format: Int32, Sendable {
        case gray = 1
        case alpha = 2
        case rgb = 3
        case bgr = 4
        case rgb32 = 5
        case bgr32 = 6
        case rgba = 7
        case bgra = 8

        /// Bytes per pixel for this format.
        public var bytesPerPixel: Int {
            Int(OCCTImageSizePixelBytes(rawValue))
        }
    }

    internal let handle: OCCTImageRef

    /// Create an empty pixel map.
    public init?() {
        guard let h = OCCTImageCreate() else { return nil }
        self.handle = h
    }

    deinit {
        OCCTImageRelease(handle)
    }

    /// Initialize with given format and dimensions (uninitialized data).
    @discardableResult
    public func initTrash(format: Format, width: Int, height: Int) -> Bool {
        OCCTImageInitTrash(handle, format.rawValue, Int32(width), Int32(height))
    }

    /// Copy data from another pixel map.
    @discardableResult
    public func initCopy(from source: PixMap) -> Bool {
        OCCTImageInitCopy(handle, source.handle)
    }

    /// Clear (deallocate) image data.
    public func clear() {
        OCCTImageClear(handle)
    }

    /// Image width in pixels.
    public var width: Int {
        Int(OCCTImageWidth(handle))
    }

    /// Image height in pixels.
    public var height: Int {
        Int(OCCTImageHeight(handle))
    }

    /// Image pixel format.
    public var format: Format {
        Format(rawValue: OCCTImageFormat(handle)) ?? .rgb
    }

    /// Whether the image is empty (no data).
    public var isEmpty: Bool {
        OCCTImageIsEmpty(handle)
    }

    /// Get pixel color at coordinates (RGBA).
    public func pixel(at x: Int, y: Int) -> Color {
        var r: Float = 0
        var g: Float = 0
        var b: Float = 0
        var a: Float = 0
        OCCTImageGetPixel(handle, Int32(x), Int32(y), &r, &g, &b, &a)
        return Color(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }

    /// Set pixel color at coordinates.
    public func setPixel(at x: Int, y: Int, color: Color) {
        OCCTImageSetPixel(
            handle, Int32(x), Int32(y),
            Float(color.red), Float(color.green), Float(color.blue), Float(color.alpha))
    }

    /// Save image to file (format determined by extension: .ppm, .png, .jpg, .bmp, .tga).
    @discardableResult
    public func save(to path: String) -> Bool {
        OCCTImageSave(handle, path)
    }

    /// Load image from file.
    @discardableResult
    public func load(from path: String) -> Bool {
        OCCTImageLoad(handle, path)
    }

    /// Apply gamma correction (1.0 = no change).
    @discardableResult
    public func adjustGamma(_ gamma: Double) -> Bool {
        OCCTImageAdjustGamma(handle, gamma)
    }

    /// Whether top-down is the default row order for the image library.
    public static var isTopDownDefault: Bool {
        OCCTImageIsTopDownDefault()
    }
}
