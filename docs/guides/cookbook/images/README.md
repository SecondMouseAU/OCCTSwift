---
nav_exclude: true
search_exclude: true
---

# Cookbook figures

Figures for the cookbook pages, **rendered headlessly out-of-repo** by the `CookbookRender` example
in [OCCTSwiftViewport](https://github.com/gsdali/OCCTSwiftViewport) (`Examples/CookbookRender`) — its
`OffscreenRenderer` (Metal). OCCTSwift ships no renderer, and can't depend on Viewport/Tools without
a cycle, so the tool lives there. Each PNG is built from the **same OCCTSwift API** its page shows,
so code and figure stay in sync.

Regenerate:
```
cd OCCTSwiftViewport/Examples/CookbookRender
swift run CookbookRender <path-to-OCCTSwift>/docs/guides/cookbook/images
```
See [`../README.md`](../README.md) → "Figures".
