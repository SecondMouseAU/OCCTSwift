//  The one file in this package that knows which platform it is building for.
//
//  Every other file in `OCCTSwift` writes `import OCCTPlatform` and gets the right Foundation and
//  the right C library, with no `#if` of its own. Before this module existed the alternative was a
//  five-line Foundation conditional in 221 files and a ten-line C library conditional in 34, about
//  1,371 lines of scaffolding that every contributor would read past forever.
//
//  WHY `@_exported` AND NOT AN ACCESS LEVEL. SE-0409's `public import`, `package import` and
//  `internal import` control who may see that an API mentions a type. They do NOT re-export, and
//  re-export is what this module needs: a file writing `import OCCTPlatform` has to get `Data` and
//  `sqrt` in scope. Measured, all three, including `package import` (both targets are in this
//  package, so it was the plausible one): each fails with `cannot find 'Data' in scope`.
//  `@_exported` is underscored and is the only spelling of re-export there is.
//
//  If that ever changes, this is the single file to revisit.

#if canImport(FoundationEssentials)
    // The wasm build. FoundationEssentials leaves out Foundation's internationalisation data, which
    // is about 10 MB brotli of the module and nothing in this package uses. #2761 has the
    // measurements. The saving is ALL OR NOTHING PER LINKED MODULE, so a single file importing full
    // Foundation, including one in the CONSUMER'S own code, brings it all back.
    @_exported import FoundationEssentials
#else
    @_exported import Foundation
#endif

// The platform C library, for the `free`, `sin`, `cos`, `sqrt`, `hypot` and `atan2` this package
// calls directly. `import Foundation` re-exports it on Apple platforms, so those were in scope by
// accident rather than by declaration, and FoundationEssentials does not, which is how #2761 found
// 130 of them at once. This ordering is the one swift.org's own WebAssembly porting guide publishes.
#if canImport(Darwin)
    @_exported import Darwin
#elseif canImport(Glibc)
    @_exported import Glibc
#elseif canImport(WASILibc)
    @_exported import WASILibc
#endif
