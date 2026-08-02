---
type: policy
title: Stay faithful to OCCT — extensions belong downstream
description: OCCTSwift wraps OCCT's own API surface as faithfully as possible; a legitimate feature that isn't a direct wrap of an OCCT operation belongs in a downstream ecosystem package, not here.
tags: [policy, scope, architecture, ecosystem]
timestamp: 2026-08-02
---

# Stay faithful to OCCT — extensions belong downstream

OCCTSwift is the kernel: a Swift wrapper over OpenCASCADE Technology, one bridge function and one
Swift method per OCCT operation. It should track the OCCT API as faithfully as possible — see
"Wrap **everything**" in `CLAUDE.md`'s User Directives — not accumulate capability that OCCT itself
doesn't provide.

Several agents have proposed adding legitimate, well-built features here that don't belong here:
the feature was sound, but the layer was wrong. Before adding new capability, check whether it's a
direct wrap of an OCCT class/method (belongs here) or something built *on top of* OCCT (belongs in
one of the downstream packages — see [`docs/ecosystem.md`](../../docs/ecosystem.md#when-to-use-which)
for the current map):

- File-format-specific glue (STEP/IGES/STL/OBJ/BREP/glTF read-write conveniences) → **OCCTSwiftIO**
- Mesh decimation, smoothing, repair → **OCCTSwiftMesh**
- Viewport/rendering data, picking metadata → **OCCTSwiftTools** / **OCCTSwiftViewport**
- Interactive selection, manipulators, dimension annotations → **OCCTSwiftAIS**
- CLI verbs, scripted/manifest-driven pipelines → **OCCTSwiftScripts**
- AI-agent-facing tools → **OCCTMCP**
- Anything with no existing home → propose a new package rather than folding it into the kernel

The test isn't "is this useful" — most proposed extensions are. It's "does OCCT itself have an
operation this wraps." If the answer is no, it's downstream work, even when it would be convenient
to bolt on here.
