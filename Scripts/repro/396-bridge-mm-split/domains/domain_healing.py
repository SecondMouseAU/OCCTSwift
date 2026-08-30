"""OCCTBridge_Healing.mm split config (#1380).

Seven buckets: repair (ShapeFix, the file's dominant concern and its default_bucket), diagnosis
(ShapeAnalysis/BRepCheck), conversion/simplification (ShapeUpgrade/ShapeCustom), two concerns that
turn out to live in this file despite not being "healing" proper -- edge blends (ChFi2d/ChFi3d/
BRepFilletAPI) and surface filling (GeomPlate/BRepOffsetAPI_MakeFilling, #430/#434) -- plus sewing
and a Misc catch-all for the low-level ShapeBuild/ShapeExtend helpers.
"""
from split_bridge_mm import register_domain

BUCKETS = ["Fix", "Analysis", "Upgrade", "Blends", "Filling", "Sewing", "Misc"]

BUCKET_DESC = {
    "Fix": "ShapeFix_* (Solid, Wire, Face, Edge, Wireframe, IntersectionTool, EdgeProjAux, "
           "SplitTool, ComposeShell, EdgeConnect) -- the file's dominant concern, default_bucket",
    "Analysis": "ShapeAnalysis_* (Wire, Edge, Shell, WireOrder, WireVertex, Geom, FreeBounds*, "
                "CanonicalRecognition), BRepCheck_* validators + Analyzer",
    "Upgrade": "ShapeUpgrade_* (Divide*, SplitSurface*, ConvertToBezier, FaceDivide/WireDivide), "
               "ShapeCustom_* (BSplineRestriction, ConvertToBSpline, DirectFaces)",
    "Blends": "ChFi2d/ChFi3d/BRepFilletAPI edge blends (variable fillet, 2D wire fillet/chamfer)",
    "Filling": "GeomPlate/BRepOffsetAPI_MakeFilling surface filling (#430/#434)",
    "Sewing": "BRepBuilderAPI_Sewing, BRepTools_Substitution + ShapeUpgrade_ShellSewing",
    "Misc": "ShapeBuild_*, ShapeExtend_Explorer, NURBS conversion, BRepLib_ValidateEdge, "
            "BRepAlgo_FaceRestrictor",
}

NAME_PREFIX_BUCKET = [
    ("ShapeFilletVariable", "Blends"),
    ("WireFillet", "Blends"),
    ("WireChamfer", "Blends"),
    ("ShapeBlendEdges", "Blends"),
    ("ShapeFillConstraints", "Filling"),
    ("ShapeFillWithSupport", "Filling"),
    ("ShapeFill", "Filling"),
    ("ShapePlatePoints", "Filling"),
    ("ShapePlateCurves", "Filling"),
    ("FastSewing", "Sewing"),
    ("Sewing", "Sewing"),
    ("ShellSewing", "Sewing"),
    ("Substitution", "Sewing"),
    ("NURBSConversion", "Misc"),
    ("ValidateEdge", "Misc"),
    ("FaceRestrictor", "Misc"),
    ("WireFixer", "Fix"),
    ("FaceFixer", "Fix"),
    ("ShapeFixer", "Fix"),
    ("WireAnalyzer", "Analysis"),
    ("FreeBoundsProps", "Analysis"),
    ("ShellOrientationScan", "Analysis"),
]

BODY_PACKAGE_TO_BUCKET = {
    "ShapeFix": "Fix",
    "ShapeAnalysis": "Analysis", "BRepCheck": "Analysis",
    "ShapeUpgrade": "Upgrade", "ShapeCustom": "Upgrade",
    "ChFi2d": "Blends", "ChFi3d": "Blends", "ChFiDS": "Blends", "BRepFilletAPI": "Blends",
    "GeomPlate": "Filling", "BRepOffsetAPI": "Filling", "GeomFill": "Filling",
    "BRepBuilderAPI": "Sewing", "BRepTools": "Sewing",
    "ShapeBuild": "Misc", "ShapeExtend": "Misc", "BRep": "Misc", "BRepLib": "Misc",
    "BRepAlgo": "Misc", "GeomConvert": "Misc",
}

CLASS_OVERRIDE_BUCKET = {}

NAME_BUCKET_OVERRIDE = {}

register_domain(
    "Healing",
    src="Healing", header="Healing", issue_note="#1380",
    buckets=BUCKETS, bucket_desc=BUCKET_DESC, default_bucket="Fix",
    name_prefix_bucket=NAME_PREFIX_BUCKET,
    body_package_to_bucket=BODY_PACKAGE_TO_BUCKET,
    class_override_bucket=CLASS_OVERRIDE_BUCKET,
    name_bucket_override=NAME_BUCKET_OVERRIDE,
)
