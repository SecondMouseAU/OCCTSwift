"""OCCTBridge_Topology.mm split config (#1380).

Six buckets: distance/proximity queries (BRepExtrema and its intersection-adjacent siblings),
bounding-box/spatial-classification, adjacency/wire-tools (BRepTools' own large surface),
shape-defect/concavity analysis (ShapeAnalysis/BRepOffset), and a ShapeQueries catch-all for the
BRep_Tool-dominated general topology-query surface that's the file's largest single concern.
"""
from split_bridge_mm import register_domain

BUCKETS = ["Extrema", "BoundingBox", "Adjacency", "Analysis", "ShapeQueries"]

BUCKET_DESC = {
    "Extrema": "BRepExtrema, IntCurvesFace, BRepIntCurveSurface, TopCnx, TopTrans",
    "BoundingBox": "Bnd_OBB/Box/BoundSortBox, BRepClass3d, BRepClass_FClassifier",
    "Adjacency": "BRepTools (WireExplorer, ReShape, Substitution, Adjacency), TopLoc",
    "Analysis": "ShapeAnalysis, BRepOffset_Analyse, ChFiDS, ShapeExtend, ShapeUpgrade",
    "ShapeQueries": "BRep_Tool, BRepLib, BRepBuilderAPI, BRepAdaptor, GCPnts, GProp, BRepLProp "
                     "(the file's dominant, catch-all concern; default_bucket for everything else)",
}

NAME_PREFIX_BUCKET = [
    ("Extrema", "Extrema"),
    ("DistShapeShape", "Extrema"),
    ("DistanceSS", "Extrema"),
    ("DistSS", "Extrema"),
    ("SelfIntersection", "Extrema"),
    ("CurveFace", "Extrema"),
    ("PolyDistance", "Extrema"),
    ("CurveSurfaceInter", "Extrema"),
    ("BRepLib", "ShapeQueries"),
    ("BRepTools", "Adjacency"),
    ("Builder", "ShapeQueries"),
    ("OBB", "BoundingBox"),
    ("BoundingBox", "BoundingBox"),
    ("BoundSortBox", "BoundingBox"),
    ("PointClassif", "BoundingBox"),
    ("WireExplorer", "Adjacency"),
    ("ReShape", "Adjacency"),
    ("Substitution", "Adjacency"),
    ("Adjacen", "Adjacency"),
    ("ContiguousEdges", "Adjacency"),
    ("SubShape", "Adjacency"),
    ("EdgeConcavity", "Analysis"),
    ("EdgeClassification", "Analysis"),
    ("FindSurface", "Analysis"),
    ("PlaneDetection", "Analysis"),
    ("WireAnalysis", "Analysis"),
    ("EdgeAnalysis", "Analysis"),
]

BODY_PACKAGE_TO_BUCKET = {
    "BRepExtrema": "Extrema", "IntCurvesFace": "Extrema", "BRepIntCurveSurface": "Extrema",
    "TopCnx": "Extrema", "TopTrans": "Extrema", "Extrema": "Extrema",
    "Bnd": "BoundingBox", "BRepClass3d": "BoundingBox", "BRepClass": "BoundingBox",
    "BRepTools": "Adjacency", "TopLoc": "Adjacency",
    "ShapeAnalysis": "Analysis", "BRepOffset": "Analysis", "ChFiDS": "Analysis",
    "ShapeExtend": "Analysis", "ShapeUpgrade": "Analysis",
    "BRep": "ShapeQueries", "BRepLib": "ShapeQueries", "BRepBuilderAPI": "ShapeQueries",
    "BRepAdaptor": "ShapeQueries", "GCPnts": "ShapeQueries", "GProp": "ShapeQueries",
    "BRepLProp": "ShapeQueries", "GeomConvert": "ShapeQueries", "Geom2d": "ShapeQueries",
    "BRepMesh": "ShapeQueries", "BRepOffsetAPI": "ShapeQueries", "BRepAlgo": "ShapeQueries",
    "GeomAPI": "ShapeQueries", "GeomAdaptor": "ShapeQueries", "CPnts": "ShapeQueries",
    "math": "ShapeQueries", "TColgp": "ShapeQueries",
}

CLASS_OVERRIDE_BUCKET = {}

NAME_BUCKET_OVERRIDE = {}

register_domain(
    "Topology",
    src="Topology", header="Topology", issue_note="#1380",
    buckets=BUCKETS, bucket_desc=BUCKET_DESC, default_bucket="ShapeQueries",
    name_prefix_bucket=NAME_PREFIX_BUCKET,
    body_package_to_bucket=BODY_PACKAGE_TO_BUCKET,
    class_override_bucket=CLASS_OVERRIDE_BUCKET,
    name_bucket_override=NAME_BUCKET_OVERRIDE,
)
