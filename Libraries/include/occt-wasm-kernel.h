// Deliberately empty, and deliberately committed.
//
// The WASI branch of Package.swift declares the `OCCT` target with `path: "Libraries"`, and
// SwiftPM refuses to LOAD a package whose target has no public-headers directory:
//
//     error: public headers ("include") directory path for 'OCCT' is invalid or not contained
//            in the target
//
// `Libraries/` is gitignored in full, so without a tracked file in here a consumer's checkout
// has no such directory and the manifest fails before any wasm flag matters. `Libraries/dummy.c`
// is tracked for the same reason and by the same means (`git add -f`).
//
// The kernel's real headers are in Libraries/occt-headers-wasm/, which Scripts/build-occt-wasm.sh
// populates and which the target reaches with a header search path rather than by making them
// public headers of a module.
