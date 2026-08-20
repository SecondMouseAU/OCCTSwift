/// Wraps one sub-shape enumeration's handles in order, or refuses the whole enumeration.
///
/// A position in a sub-shape enumeration is an ordinal, not just a place in a list, so a hole is
/// not representable: skipping a missing element shifts every later one down and each then answers
/// for its neighbour. See `docs/API_REFERENCE.md`, "Sub-Shape Extraction" (#979).
///
/// - Parameters:
///   - handles: One optional handle per ordinal, in enumeration order.
///   - wrap: Builds the object taking ownership of the handle at an ordinal.
///   - release: Releases a handle no object took ownership of.
/// - Returns: One element per ordinal, or an empty array if any handle was missing.
func wrapSubShapeEnumeration<Handle, Element>(
    _ handles: [Handle?],
    wrap: (Handle, Int) -> Element,
    release: (Handle) -> Void
) -> [Element] {
    var elements: [Element] = []
    elements.reserveCapacity(handles.count)

    for (ordinal, handle) in handles.enumerated() {
        guard let handle else {
            // Elements already built release their own handles; nothing owns the rest.
            for stray in handles[ordinal...] {
                if let stray { release(stray) }
            }
            return []
        }
        elements.append(wrap(handle, ordinal))
    }

    return elements
}
