#!/usr/bin/env python3
"""#766 XCAF slice: apply the temporary semantic-injection harness.

Every edit here is throwaway. `git checkout -- Sources/` reverts the lot.
Each injection is selected at runtime by the OCCT766_INJECT environment variable,
so the whole matrix needs one build.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path("/Users/elb/Projects/OCCTSwift/.claude/worktrees/agent-ab47633332e4e61a9")
SRC = ROOT / "Sources/OCCTBridge/src"

HELPER = """
// TEMPORARY #766 injection harness. Not for commit.
#include <cstdlib>
static int occt766Inject()
{
  static int v = -1;
  if (v < 0)
  {
    const char* s = getenv("OCCT766_INJECT");
    v             = s ? atoi(s) : 0;
  }
  return v;
}
"""

# (file, anchor, replacement). Anchors must be unique in the file.
EDITS = [
    # ---------------- Document_Functions.mm ----------------
    ("OCCTBridge_Document_Functions.mm",
     """  return occtDocumentNamingTraceImpl<TNaming_NewShapeIterator>(doc,
                                                               accessLabelId,
                                                               shape,
                                                               outShapes,
                                                               maxCount);""",
     """  int32_t n = occtDocumentNamingTraceImpl<TNaming_NewShapeIterator>(doc,
                                                                    accessLabelId,
                                                                    shape,
                                                                    outShapes,
                                                                    maxCount);
  if (occt766Inject() == 1 && shape && n < maxCount)
    outShapes[n++] = new OCCTShape(shape->shape);  // INJ1: forward trace emits the source too
  return n;"""),
    ("OCCTBridge_Document_Functions.mm",
     """  return occtDocumentNamingTraceImpl<TNaming_OldShapeIterator>(doc,
                                                               accessLabelId,
                                                               shape,
                                                               outShapes,
                                                               maxCount);""",
     """  if (occt766Inject() == 2)
    return 0;  // INJ2: backward trace finds nothing
  return occtDocumentNamingTraceImpl<TNaming_OldShapeIterator>(doc,
                                                               accessLabelId,
                                                               shape,
                                                               outShapes,
                                                               maxCount);"""),
    ("OCCTBridge_Document_Functions.mm",
     "    Handle(TNaming_NamedShape) ns;\n"
     "    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))\n"
     "      return true;\n"
     "    return ns->IsEmpty();",
     "    if (occt766Inject() == 15)\n"
     "      return true;  // INJ15: naming always reads as empty\n"
     "    if (occt766Inject() == 16)\n"
     "      return false;  // INJ16: naming never reads as empty\n"
     "    Handle(TNaming_NamedShape) ns;\n"
     "    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))\n"
     "      return true;\n"
     "    return ns->IsEmpty();"),
    ("OCCTBridge_Document_Functions.mm",
     "    return ns->Version();",
     "    if (occt766Inject() == 17)\n"
     "      return 0;  // INJ17: version never updates\n"
     "    return ns->Version();"),
    ("OCCTBridge_Document_Functions.mm",
     "    TopoDS_Shape shape = TNaming_Tool::OriginalShape(ns);",
     "    TopoDS_Shape shape = (occt766Inject() == 18)\n"
     "                           ? TNaming_Tool::CurrentShape(ns)  // INJ18: original reads current\n"
     "                           : TNaming_Tool::OriginalShape(ns);"),
    ("OCCTBridge_Document_Functions.mm",
     "    TDF_Label root = doc->doc->Main();\n    return TNaming_Tool::HasLabel(root, shape->shape);",
     "    if (occt766Inject() == 19)\n"
     "      return true;  // INJ19: every shape reads as labelled\n"
     "    TDF_Label root = doc->doc->Main();\n    return TNaming_Tool::HasLabel(root, shape->shape);"),
    ("OCCTBridge_Document_Functions.mm",
     "    if (!TNaming_Tool::HasLabel(root, shape->shape))\n      return -1;\n    int       transDef = 0;",
     "    if (occt766Inject() == 20)\n"
     "      return 0;  // INJ20: find always answers label 0\n"
     "    if (!TNaming_Tool::HasLabel(root, shape->shape))\n      return -1;\n    int       transDef = 0;"),
    ("OCCTBridge_Document_Functions.mm",
     "    if (!TNaming_Tool::HasLabel(root, shape->shape))\n      return -1;\n"
     "    return TNaming_Tool::ValidUntil(root, shape->shape);",
     "    if (occt766Inject() == 21)\n"
     "      return 0;  // INJ21: validUntil always answers 0\n"
     "    if (!TNaming_Tool::HasLabel(root, shape->shape))\n      return -1;\n"
     "    return TNaming_Tool::ValidUntil(root, shape->shape);"),
    ("OCCTBridge_Document_Functions.mm",
     "    for (TNaming_SameShapeIterator it(shape->shape, root); it.More(); it.Next())\n"
     "      count++;\n    return count;",
     "    for (TNaming_SameShapeIterator it(shape->shape, root); it.More(); it.Next())\n"
     "      count++;\n"
     "    if (occt766Inject() == 22)\n"
     "      count++;  // INJ22: same-shape count off by one\n"
     "    return count;"),
    ("OCCTBridge_Document_Functions.mm",
     "      outLabelIds[i] = labelId;",
     "      outLabelIds[i] = (occt766Inject() == 23) ? 0 : labelId;  // INJ23: all ids collapse to 0"),
    ("OCCTBridge_Document_Functions.mm",
     "    TopoDS_Shape current = TNaming_Tool::CurrentShape(ns);",
     "    if (occt766Inject() == 27)\n"
     "      return new OCCTShape(BRepPrimAPI_MakeBox(1.0, 1.0, 1.0).Shape());  // INJ27\n"
     "    TopoDS_Shape current = TNaming_Tool::CurrentShape(ns);"),
    ("OCCTBridge_Document_Functions.mm",
     "    TopoDS_Shape shape = TNaming_Tool::GetShape(ns);",
     "    if (occt766Inject() == 28)\n"
     "      return new OCCTShape(BRepPrimAPI_MakeBox(1.0, 1.0, 1.0).Shape());  // INJ28\n"
     "    TopoDS_Shape shape = TNaming_Tool::GetShape(ns);"),
    ("OCCTBridge_Document_Functions.mm",
     "    switch (ns->Evolution())\n    {\n      case TNaming_PRIMITIVE:\n        return OCCTNamingPrimitive;",
     "    if (occt766Inject() == 29)\n"
     "      return OCCTNamingPrimitive;  // INJ29: every label reads as primitive\n"
     "    if (occt766Inject() == 30)\n"
     "      return -1;  // INJ30: no label has an evolution\n"
     "    switch (ns->Evolution())\n    {\n      case TNaming_PRIMITIVE:\n        return OCCTNamingPrimitive;"),
    ("OCCTBridge_Document_Functions.mm",
     "        outEntry->hasOldShape    = !it.OldShape().IsNull();",
     "        outEntry->hasOldShape    = (occt766Inject() == 31) ? true : !it.OldShape().IsNull();"),
    # ---------------- Document_DocumentLifecycle.mm ----------------
    ("OCCTBridge_Document_DocumentLifecycle.mm",
     "    doc->shapeTool->GetShapes(shapes);\n    return shapes.Length();",
     "    doc->shapeTool->GetShapes(shapes);\n"
     "    if (occt766Inject() == 3)\n      return 1;  // INJ3: shape count pinned at one\n"
     "    return shapes.Length();"),
    ("OCCTBridge_Document_DocumentLifecycle.mm",
     "    doc->shapeTool->GetFreeShapes(shapes);\n    return shapes.Length();",
     "    doc->shapeTool->GetFreeShapes(shapes);\n"
     "    if (occt766Inject() == 4)\n      return 1;  // INJ4: free-shape count pinned at one\n"
     "    return shapes.Length();"),
    ("OCCTBridge_Document_DocumentLifecycle.mm",
     "    TDF_Label label;\n    bool      found = doc->shapeTool->FindShape(shape->shape, label);",
     "    TDF_Label label;\n"
     "    // INJ5: find descends into sub-shapes, which is SearchShape's job and not its own\n"
     "    bool      found = (occt766Inject() == 5) ? doc->shapeTool->Search(shape->shape, label)\n"
     "                                             : doc->shapeTool->FindShape(shape->shape, label);"),
    ("OCCTBridge_Document_DocumentLifecycle.mm",
     "    return doc->shapeTool->RemoveShape(label);",
     "    if (occt766Inject() == 6)\n      return true;  // INJ6: remove reports success and removes nothing\n"
     "    return doc->shapeTool->RemoveShape(label);"),
    ("OCCTBridge_Document_DocumentLifecycle.mm",
     "    return doc->shapeTool->IsComponent(label);",
     "    if (occt766Inject() == 7)\n      return true;  // INJ7: every label reads as a component\n"
     "    return doc->shapeTool->IsComponent(label);"),
    ("OCCTBridge_Document_DocumentLifecycle.mm",
     "    TDF_Label father = label.Father();",
     "    if (occt766Inject() == 24)\n      return -1;  // INJ24: no label has a father\n"
     "    TDF_Label father = label.Father();"),
    ("OCCTBridge_Document_DocumentLifecycle.mm",
     "    return label.Tag();",
     "    if (occt766Inject() == 25)\n      return 1;  // INJ25: every label reads as tag 1\n"
     "    return label.Tag();"),
    ("OCCTBridge_Document_DocumentLifecycle.mm",
     "    return f->IsKept(guid);",
     "    if (occt766Inject() == 39)\n      return true;  // INJ39: everything reads as kept\n"
     "    return f->IsKept(guid);"),
    ("OCCTBridge_Document_DocumentLifecycle.mm",
     "    return f->IsIgnored(guid);",
     "    if (occt766Inject() == 40)\n      return false;  // INJ40: nothing reads as ignored\n"
     "    return f->IsIgnored(guid);"),
    ("OCCTBridge_Document_DocumentLifecycle.mm",
     "    return f->IgnoreAll();",
     "    if (occt766Inject() == 41)\n      return true;  // INJ41: mode always reads ignore-all\n"
     "    return f->IgnoreAll();"),
    ("OCCTBridge_Document_DocumentLifecycle.mm",
     "    TCollection_AsciiString  id(pathId);\n"
     "    TopoDS_Shape             shape = XCAFPrs_DocumentExplorer::FindShapeFromPathId(doc, id);",
     "    TCollection_AsciiString  id(pathId);\n"
     "    if (occt766Inject() == 11)\n"
     "      id = TCollection_AsciiString(\"0:1:1:1.\");  // INJ11: lookup ignores its argument\n"
     "    TopoDS_Shape             shape = XCAFPrs_DocumentExplorer::FindShapeFromPathId(doc, id);"),
    # ---------------- Document_Assembly.mm ----------------
    ("OCCTBridge_Document_Assembly.mm",
     "    int32_t                  count = 0;\n"
     "    while (explorer.More())\n    {\n      count++;\n      explorer.Next();\n    }\n    return count;",
     "    int32_t                  count = 0;\n"
     "    while (explorer.More())\n    {\n      count++;\n      explorer.Next();\n    }\n"
     "    if (occt766Inject() == 8)\n      return 1;  // INJ8: explorer always reports one node\n"
     "    return count;"),
    ("OCCTBridge_Document_Assembly.mm",
     "      if (i == index)\n      {\n        const XCAFPrs_DocumentNode& node      = explorer.Current();",
     "      if (i == index || occt766Inject() == 9)  // INJ9: shape lookup ignores its index\n"
     "      {\n        const XCAFPrs_DocumentNode& node      = explorer.Current();"),
    ("OCCTBridge_Document_Assembly.mm",
     "        return strdup(explorer.Current().Id.ToCString());",
     "        if (occt766Inject() == 10)\n"
     "        {  // INJ10: path id loses its trailing separator\n"
     "          TCollection_AsciiString trimmed = explorer.Current().Id;\n"
     "          trimmed.RightAdjust();\n"
     "          if (trimmed.EndsWith(\".\"))\n"
     "            trimmed.Trunc(trimmed.Length() - 1);\n"
     "          return strdup(trimmed.ToCString());\n"
     "        }\n"
     "        return strdup(explorer.Current().Id.ToCString());"),
    ("OCCTBridge_Document_Assembly.mm",
     "        return (int32_t)explorer.CurrentDepth();",
     "        if (occt766Inject() == 12)\n          return 0;  // INJ12: depth pinned at zero\n"
     "        if (occt766Inject() == 13)\n          return 7;  // INJ13: depth pinned at seven\n"
     "        return (int32_t)explorer.CurrentDepth();"),
    ("OCCTBridge_Document_Assembly.mm",
     "    return tool->GetMap().Extent();",
     "    if (occt766Inject() == 14)\n      return tool->GetMap().Extent() + 1;  // INJ14: extent off by one\n"
     "    return tool->GetMap().Extent();"),
    ("OCCTBridge_Document_Assembly.mm",
     "    return XCAFDoc_Editor::Expand(doc->doc->Main(), label, recursively);",
     "    if (occt766Inject() == 42)\n      return true;  // INJ42: expand always reports success\n"
     "    return XCAFDoc_Editor::Expand(doc->doc->Main(), label, recursively);"),
    ("OCCTBridge_Document_Assembly.mm",
     "    return XCAFDoc_Editor::RescaleGeometry(label, scaleFactor, forceIfNotRoot);",
     "    if (occt766Inject() == 43)\n      return true;  // INJ43: rescale reports success and scales nothing\n"
     "    return XCAFDoc_Editor::RescaleGeometry(label, scaleFactor, forceIfNotRoot);"),
    ("OCCTBridge_Document_Assembly.mm",
     "    XCAFDoc_AssemblyIterator iter(doc->doc, level);\n    int                      count = 0;",
     "    if (occt766Inject() == 46)\n      return 1;  // INJ46: assembly item count pinned at one\n"
     "    XCAFDoc_AssemblyIterator iter(doc->doc, level);\n    int                      count = 0;"),
    # ---------------- Document_Attributes.mm ----------------
    ("OCCTBridge_Document_Attributes.mm",
     "    Handle(TDataStd_Directory) dir   = TDataStd_Directory::New(label);\n    return !dir.IsNull();",
     "    if (occt766Inject() == 38)\n      return true;  // INJ38: create reports success and creates nothing\n"
     "    Handle(TDataStd_Directory) dir   = TDataStd_Directory::New(label);\n    return !dir.IsNull();"),
    ("OCCTBridge_Document_Attributes.mm",
     "    Handle(TDataStd_Directory) dir;\n    return TDataStd_Directory::Find(label, dir);",
     "    if (occt766Inject() == 35)\n      return true;  // INJ35: every label reads as having a directory\n"
     "    Handle(TDataStd_Directory) dir;\n    return TDataStd_Directory::Find(label, dir);"),
    ("OCCTBridge_Document_Attributes.mm",
     "    return subDir->Label().Tag();",
     "    if (occt766Inject() == 36)\n      return 1;  // INJ36: sub-directory tag pinned at one\n"
     "    return subDir->Label().Tag();"),
    ("OCCTBridge_Document_Attributes.mm",
     "    return objLabel.Tag();",
     "    if (occt766Inject() == 37)\n      return 1;  // INJ37: object-label tag pinned at one\n"
     "    return objLabel.Tag();"),
]

# Injections that live in the Swift layer, same env var.
SWIFT_EDITS = [
    ("Sources/OCCTSwift/Document.swift",
     """        guard let h = OCCTDocumentNamingGetNewShape(handle, node.labelId, Int32(index)) else {
            return nil
        }
        return Shape(handle: h)""",
     """        if ProcessInfo.processInfo.environment["OCCT766_INJECT"] == "32" {
            return Shape.box(width: 1, height: 1, depth: 1)  // INJ32
        }
        guard let h = OCCTDocumentNamingGetNewShape(handle, node.labelId, Int32(index)) else {
            return nil
        }
        return Shape(handle: h)"""),
    ("Sources/OCCTSwift/Document.swift",
     """    public func resolveShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTDocumentNamingResolve(handle, node.labelId) else { return nil }""",
     """    public func resolveShape(on node: AssemblyNode) -> Shape? {
        if ProcessInfo.processInfo.environment["OCCT766_INJECT"] == "44" {
            return Shape.box(width: 10, height: 10, depth: 10)  // INJ44
        }
        guard let h = OCCTDocumentNamingResolve(handle, node.labelId) else { return nil }"""),
    ("Sources/OCCTSwift/Document.swift",
     """    public func selectShape(_ selection: Shape, context: Shape, on node: AssemblyNode) -> Bool {
        OCCTDocumentNamingSelect(handle, node.labelId, selection.handle, context.handle)""",
     """    public func selectShape(_ selection: Shape, context: Shape, on node: AssemblyNode) -> Bool {
        if ProcessInfo.processInfo.environment["OCCT766_INJECT"] == "45" {
            return true  // INJ45: select reports success and writes nothing
        }
        return OCCTDocumentNamingSelect(handle, node.labelId, selection.handle, context.handle)"""),
]


def main():
    files = sorted({f for f, _, _ in EDITS})
    for name in files:
        p = SRC / name
        text = p.read_text()
        # insert the helper after the last top-level #include
        includes = list(re.finditer(r"^#include [<\"][^\n]*\n", text, re.M))
        at = includes[-1].end()
        text = text[:at] + HELPER + text[at:]
        p.write_text(text)

    applied = 0
    for name, old, new in EDITS:
        p = SRC / name
        text = p.read_text()
        n = text.count(old)
        if n != 1:
            print(f"ANCHOR {n} matches in {name}: {old[:70]!r}", file=sys.stderr)
            sys.exit(1)
        p.write_text(text.replace(old, new, 1))
        applied += 1

    for rel, old, new in SWIFT_EDITS:
        p = ROOT / rel
        text = p.read_text()
        n = text.count(old)
        if n != 1:
            print(f"ANCHOR {n} matches in {rel}: {old[:70]!r}", file=sys.stderr)
            sys.exit(1)
        p.write_text(text.replace(old, new, 1))
        applied += 1

    print(f"applied {applied} injection site edit(s) across {len(files) + 1} file(s)")


if __name__ == "__main__":
    main()
