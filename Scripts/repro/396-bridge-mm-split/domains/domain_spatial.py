"""OCCTBridge_Spatial.mm split config (#1380).

Five buckets. Dominated by `math` (220 package-token mentions, the file's numerical-methods
theme -- root/minimum finders, matrix decompositions, integration -- MathSolvers, the
default_bucket), with genuinely disjoint sub-concerns: bounding volumes (Bnd/BndLib), intersection/
interval analysis (IntAna/Intrv/Intf), spatial queries (KD-Tree, ray casting), and generic
geometric utilities (Ax3/Quaternion/Trsf/gp_Vec/gp_Dir/Precision).
"""
from split_bridge_mm import register_domain

BUCKETS = ["MathSolvers", "Bounding", "Intersection", "SpatialQueries", "GeometryUtils"]

BUCKET_DESC = {
    "MathSolvers": "math_* (FunctionRoot(s)/FunctionSetRoot, BFGS, Powell, BrentMinimum, PSO, "
                   "GlobOptMin, GaussSingleIntegration, NewtonFunctionSetRoot/Minimum, "
                   "TrigonometricFunctionRoots, Matrix, Gauss, SVD, DirectPolynomialRoots, "
                   "Jacobi, Householder, Crout), MathPoly_Laguerre -- default_bucket",
    "Bounding": "Bnd_Range/Sphere, BndLib (analytic bounding + extras)",
    "Intersection": "IntAna/IntAna_IntQuadQuad, Intrv_Interval(s), Intf_Tool",
    "SpatialQueries": "KD-Tree spatial queries, ray casting",
    "GeometryUtils": "Ax3 utilities, Quaternion SLerp/NLerp, Trsf interpolation/displacement, "
                     "XY/XYZ utils, Polynomial-to-poles, gp_Pln/Lin distance/contains, "
                     "gp_Vec/gp_Dir extras, Precision",
}

NAME_PREFIX_BUCKET = [
    ("KDTree", "SpatialQueries"),
    ("RayCast", "SpatialQueries"),
    ("PolynomialRoots", "MathSolvers"),
    # Package-vote can't route these: gp_/Precision_ are both in the scanner's GENERIC exclusion
    # set (ubiquitous utility types excluded from voting everywhere in this tool), so a function
    # whose body touches only gp_Ax3/gp_Quaternion/gp_Trsf/gp_Vec/gp_Dir gets zero votes and falls
    # to default_bucket (MathSolvers) unless routed by name instead.
    ("Ax3", "GeometryUtils"),
    ("Quaternion", "GeometryUtils"),
    ("TrsfInterp", "GeometryUtils"),
    ("TrsfDisplacement", "GeometryUtils"),
    ("PolesFromPolynomial", "GeometryUtils"),
    ("PlnDistance", "GeometryUtils"),
    ("PlnContains", "GeometryUtils"),
    ("LinDistance", "GeometryUtils"),
    ("LinContains", "GeometryUtils"),
    ("VecExtra", "GeometryUtils"),
    ("DirExtra", "GeometryUtils"),
    ("XYZ", "GeometryUtils"),
]

BODY_PACKAGE_TO_BUCKET = {
    "math": "MathSolvers", "MathPoly": "MathSolvers", "MathInteg": "MathSolvers",
    "Bnd": "Bounding", "BndLib": "Bounding",
    "IntAna": "Intersection", "Intrv": "Intersection", "Intf": "Intersection",
    "gp": "GeometryUtils", "Precision": "GeometryUtils",
}

CLASS_OVERRIDE_BUCKET = {}

NAME_BUCKET_OVERRIDE = {}

register_domain(
    "Spatial",
    src="Spatial", header="Spatial", issue_note="#1380",
    buckets=BUCKETS, bucket_desc=BUCKET_DESC, default_bucket="MathSolvers",
    name_prefix_bucket=NAME_PREFIX_BUCKET,
    body_package_to_bucket=BODY_PACKAGE_TO_BUCKET,
    class_override_bucket=CLASS_OVERRIDE_BUCKET,
    name_bucket_override=NAME_BUCKET_OVERRIDE,
)
