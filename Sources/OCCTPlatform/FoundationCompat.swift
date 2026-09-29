//  A neutral spelling for the handful of Foundation APIs that FoundationEssentials does not carry.
//
//  #2761's saving requires that NO linked file imports full Foundation: one that does pulls the
//  internationalisation data back into the wasm module, which is about 10 MB brotli. A few APIs the
//  Swift layer uses live only in full Foundation, so each gets one name here with two
//  implementations.
//
//  ON APPLE PLATFORMS EVERY ONE OF THESE DELEGATES TO THE FOUNDATION API IT REPLACES, so behaviour,
//  formatting and locale handling are exactly what they were. The call sites change spelling; they
//  do not change meaning.
//
//  The wasm implementations are deliberately locale-INDEPENDENT, and so are the Foundation calls
//  they stand in for. These outputs feed STEP, DXF, SVG and PDF writers, where a decimal comma from
//  a European locale would produce a malformed file rather than a differently formatted one.

extension String {
    /// `String(format:)`, spelled so both platforms can provide it.
    ///
    /// On Apple this *is* `String(format:)`. On wasm it goes through the C library's `vsnprintf`,
    /// which is where Foundation's implementation ends up too, so the bytes match.
    public init(cFormat format: String, _ arguments: CVarArg...) {
        #if canImport(FoundationEssentials)
            // Measure first, then format: C99 has `vsnprintf` return the length it WOULD have
            // written and write nothing when the buffer is null and the size zero, so the second
            // call cannot truncate. A fixed buffer would have been large enough for every call
            // site in this package today, which is exactly the kind of assumption a later call
            // site breaks silently.
            let needed = withVaList(arguments) { vsnprintf(nil, 0, format, $0) }
            guard needed >= 0 else {
                self = ""
                return
            }
            var buffer = [CChar](repeating: 0, count: Int(needed) + 1)
            _ = withVaList(arguments) { vaList in
                buffer.withUnsafeMutableBufferPointer { out in
                    vsnprintf(out.baseAddress!, out.count, format, vaList)
                }
            }
            self = buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        #else
            self = String(format: format, arguments: arguments)
        #endif
    }

    /// `replacingOccurrences(of:with:)` for a literal needle.
    public func replacingLiteral(_ needle: String, with replacement: String) -> String {
        #if canImport(FoundationEssentials)
            guard !needle.isEmpty else { return self }
            var result = ""
            var rest = Substring(self)
            // `firstRange(of:)` is the standard library's search; `range(of:)` is Foundation's and
            // is not on this path, which the wasm build caught here rather than at a call site.
            while let found = rest.firstRange(of: needle) {
                result += rest[rest.startIndex..<found.lowerBound]
                result += replacement
                rest = rest[found.upperBound...]
            }
            result += rest
            return result
        #else
            return replacingOccurrences(of: needle, with: replacement)
        #endif
    }
}

extension StringProtocol {
    /// `trimmingCharacters(in: .whitespaces)`.
    ///
    /// Named for what it does rather than taking a character set, because `CharacterSet` is not
    /// available on the wasm path and every call site in this package passes `.whitespaces`.
    public func trimmingWhitespace() -> String {
        #if canImport(FoundationEssentials)
            guard let first = self.firstIndex(where: { !$0.isWhitespace }),
                let last = self.lastIndex(where: { !$0.isWhitespace })
            else { return "" }
            return String(self[first...last])
        #else
            return trimmingCharacters(in: .whitespaces)
        #endif
    }

    /// The whitespace-separated fields of the receiver, dropping empties.
    ///
    /// Stands in for `components(separatedBy: .whitespaces)` at the one site that uses it.
    public func whitespaceSeparatedFields() -> [String] {
        // Spelled through `Substring` rather than on `Self`: `StringProtocol` inherits two
        // `split(whereSeparator:)` overloads and the call is ambiguous without pinning one.
        Substring(self).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }
}

extension Error {
    /// The description an export error carries into its thrown message.
    ///
    /// On Apple this is `localizedDescription`. On wasm it is the same interpolation Foundation
    /// itself produces for a Swift error that does not conform to `LocalizedError`, which is what
    /// every error reaching these call sites is.
    public var exportDescription: String {
        #if canImport(FoundationEssentials)
            return String(describing: self)
        #else
            return localizedDescription
        #endif
    }
}
