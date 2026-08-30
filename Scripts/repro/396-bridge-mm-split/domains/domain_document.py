"""OCCTBridge_Document.mm split config (#1380). Largest file in this backlog.

Seven buckets. `XCAFDoc` (359 mentions) is the single biggest package but spans genuinely
different concerns through its many concrete classes (ShapeTool vs ColorTool vs DimTolTool vs
DocumentTool are not the same thing), so it's routed by CLASS_OVERRIDE_BUCKET per concrete class,
not by package vote. `TDataStd`/`TDataXtd` (generic OCAF attribute storage) is Attributes,
`TDF` (label/transaction/delta machinery) is its own bucket, `TFunction`/`TNaming` (dependency
graph + topological naming) is Functions, and document-lifecycle concerns (transactions,
undo/redo, persistence, layers, length unit) are DocumentLifecycle, the default_bucket.
"""
from split_bridge_mm import register_domain

BUCKETS = ["Assembly", "Appearance", "GDT", "Attributes", "Functions", "DocumentLifecycle"]

BUCKET_DESC = {
    "Assembly": "XDE assembly traversal/transforms, XCAFDoc_ShapeTool/ShapeMapTool/Location/"
                "Editor/AssemblyItemRef/AssemblyItemId/AssemblyIterator, XCAFPrs_DocumentExplorer",
    "Appearance": "XDE colors/materials (PBR), XCAFDoc_Color/ColorTool/Material/VisMaterial*/"
                  "ClippingPlaneTool",
    "GDT": "XDE GD&T/Dimension Tolerance, XCAFDoc_Datum/DimTol/DimTolTool/GeomTolerance/"
           "Dimension/GraphNode, XCAFDimTolObjects",
    "Attributes": "TDataStd_* (scalar/array/list attributes, TreeNode, NamedData), TDataXtd_* "
                  "(Shape/Position/Geometry/Triangulation/Point/Axis/Plane/Placement/Presentation/"
                  "Constraint/PatternStd). No dedicated TDF bucket: TDF_Label-touching functions "
                  "(properties/name, Reference, CopyLabel, IDFilter, Delta, ComparisonTool, "
                  "Transaction, AttributeIterator, DataSet) all co-reference a stronger-voting "
                  "package here and land in Attributes or DocumentLifecycle instead",
    "Functions": "TFunction_* (Logbook, GraphNode, Function, IFunction, Scope, DriverTable), "
                 "TNaming_* (topological naming history, CopyShape, Extensions, Scope, "
                 "Translator, Naming, SameShapeIterator)",
    "DocumentLifecycle": "Document main label/transactions/undo-redo/modified labels/length "
                         "unit/layers, XCAFDoc_DocumentTool/LayerTool/NotesTool/Note*, OCAF "
                         "persistence, TDocStd_XLinkTool -- default_bucket",
}

NAME_PREFIX_BUCKET = [
    ("Notebook", "DocumentLifecycle"),
    ("NoteBinData", "DocumentLifecycle"),
    ("NoteBalloon", "DocumentLifecycle"),
    ("NoteComment", "DocumentLifecycle"),
]

BODY_PACKAGE_TO_BUCKET = {
    "TDataStd": "Attributes", "TDataXtd": "Attributes",
    # No "TDF" entry: TDF_Label-touching functions all co-reference a stronger-voting package
    # (TDataStd/TDataXtd/XCAFDoc) in this file, so nothing's TOP vote is ever bare "TDF" --
    # measured (0 items landed under a dedicated TDF bucket before this bucket was removed as
    # unused), not assumed. Kept out rather than pointed at a real bucket to avoid silently
    # relocating those functions if that measurement ever stops holding; a future TDF-dominant
    # function would show up as unclassified instead of being mis-routed.
    "TFunction": "Functions", "TNaming": "Functions",
    "XCAFPrs": "Assembly",
    "Quantity": "Appearance",
    "XCAFDimTolObjects": "GDT",
    "TDocStd": "DocumentLifecycle", "TCollection": "DocumentLifecycle",
}

CLASS_OVERRIDE_BUCKET = {
    "XCAFDoc_ShapeTool": "Assembly", "XCAFDoc_ShapeMapTool": "Assembly",
    "XCAFDoc_Location": "Assembly", "XCAFDoc_Editor": "Assembly",
    "XCAFDoc_AssemblyItemRef": "Assembly", "XCAFDoc_AssemblyItemId": "Assembly",
    "XCAFDoc_AssemblyIterator": "Assembly",
    "XCAFDoc_Color": "Appearance", "XCAFDoc_ColorTool": "Appearance",
    "XCAFDoc_ColorType": "Appearance", "XCAFDoc_Material": "Appearance",
    "XCAFDoc_VisMaterialPBR": "Appearance", "XCAFDoc_VisMaterialCommon": "Appearance",
    "XCAFDoc_ClippingPlaneTool": "Appearance", "XCAFDoc_MaterialTool": "Appearance",
    "XCAFDoc_Datum": "GDT", "XCAFDoc_DimTol": "GDT", "XCAFDoc_DimTolTool": "GDT",
    "XCAFDoc_GeomTolerance": "GDT", "XCAFDoc_Dimension": "GDT", "XCAFDoc_GraphNode": "GDT",
    "XCAFDoc_DocumentTool": "DocumentLifecycle", "XCAFDoc_LayerTool": "DocumentLifecycle",
    "XCAFDoc_NotesTool": "DocumentLifecycle", "XCAFDoc_NoteComment": "DocumentLifecycle",
    "XCAFDoc_NoteBinData": "DocumentLifecycle", "XCAFDoc_NoteBalloon": "DocumentLifecycle",
}

NAME_BUCKET_OVERRIDE = {}

register_domain(
    "Document",
    src="Document", header="Document", issue_note="#1380",
    buckets=BUCKETS, bucket_desc=BUCKET_DESC, default_bucket="DocumentLifecycle",
    name_prefix_bucket=NAME_PREFIX_BUCKET,
    body_package_to_bucket=BODY_PACKAGE_TO_BUCKET,
    class_override_bucket=CLASS_OVERRIDE_BUCKET,
    name_bucket_override=NAME_BUCKET_OVERRIDE,
)
