"""OCCTBridge_Geom2d.mm split config (#1380).

Seven buckets. Dominated by `Geom2d` itself (411 of the file's package-token mentions, its own
curve/point/axis/transform base concern -- Curves, the default_bucket), with genuinely disjoint
sub-concerns: tangency/constraint solving (GccAna/GccEnt/Geom2dGcc), bisector/medial-axis
(Bisector/BRepMAT2d), 2D extrema/intersection (Extrema/IntAna2d/Intf), curve-on-edge adaptors and
local properties (BRepAdaptor_Curve2d/Geom2dAdaptor/Geom2dLProp), conversion/approximation
(GC_Make*/gce_Make*/Geom2dConvert/Geom2dAPI/ShapeUpgrade curve2d), and hatching (Hatch_Hatcher).
"""
from split_bridge_mm import register_domain

BUCKETS = ["Curves", "GccSolver", "Bisector", "Extrema", "Adaptor", "Conversion", "Hatching"]

BUCKET_DESC = {
    "Curves": "Geom2d_* (Circle/Ellipse/Hyperbola/Parabola/Line/OffsetCurve/BSpline/Bezier), "
              "Point2D/Transform2D/AxisPlacement2D/Vector2D -- default_bucket",
    "GccSolver": "GccAna, GccEnt, Geom2dGcc (tangency/constraint-solving constructions)",
    "Bisector": "Bisector_BisecAna/PointOnBis/Inter, BRepMAT2d (medial axis transform)",
    "Extrema": "Extrema_LocateExtCC2d, IntAna2d_Conic, Intf_InterferencePolygon2d",
    "Adaptor": "BRepAdaptor_Curve2d, Geom2dAdaptor, Geom2dLProp/LProp_AnalyticCurInf",
    "Conversion": "GC_Make*, gce_Make*, Geom2dConvert, Geom2dAPI, ShapeUpgrade/ShapeCustom curve2d",
    "Hatching": "Hatch_Hatcher, hatch patterns",
}

NAME_PREFIX_BUCKET = [
    ("Hatch", "Hatching"),
    ("Bisector", "Bisector"),
    ("MedialAxis", "Bisector"),
    ("FairCurve", "Conversion"),
    ("BattenCurve", "Conversion"),
]

BODY_PACKAGE_TO_BUCKET = {
    "Geom2d": "Curves", "gp": "Curves",
    "GccAna": "GccSolver", "GccEnt": "GccSolver", "Geom2dGcc": "GccSolver",
    "Bisector": "Bisector", "BRepMAT2d": "Bisector", "MAT": "Bisector", "MAT2d": "Bisector",
    "Extrema": "Extrema", "IntAna2d": "Extrema", "Intf": "Extrema",
    "BRepAdaptor": "Adaptor", "Geom2dAdaptor": "Adaptor", "Geom2dLProp": "Adaptor",
    "LProp": "Adaptor", "GeomLProp": "Adaptor",
    "GC": "Conversion", "gce": "Conversion", "Geom2dConvert": "Conversion",
    "Geom2dAPI": "Conversion", "ShapeUpgrade": "Conversion", "ShapeCustom": "Conversion",
    "Convert": "Conversion", "Approx": "Conversion", "BRepLib": "Conversion",
    "BRepBuilderAPI": "Conversion", "Geom2dGridEval": "Conversion",
    "Hatch": "Hatching",
}

CLASS_OVERRIDE_BUCKET = {}

NAME_BUCKET_OVERRIDE = {}

register_domain(
    "Geom2d",
    src="Geom2d", header="Geom2d", issue_note="#1380",
    buckets=BUCKETS, bucket_desc=BUCKET_DESC, default_bucket="Curves",
    name_prefix_bucket=NAME_PREFIX_BUCKET,
    body_package_to_bucket=BODY_PACKAGE_TO_BUCKET,
    class_override_bucket=CLASS_OVERRIDE_BUCKET,
    name_bucket_override=NAME_BUCKET_OVERRIDE,
    # OCCTPoint2DTransformed: a redundant in-file forward declaration (already fully declared in
    # the public OCCTBridge_Geom2d.h) immediately followed, ~200 lines later, by its real
    # definition -- nothing between the two calls it, so the forward decl is vestigial, not load-
    # bearing. Both land in Curves (confirmed), so duplicating a harmless bare prototype into the
    # same file as its own definition is valid, redundant C++, same shape as Modeling's own
    # allowed occtArgList overload pair.
    allowed_duplicate_names=("OCCTPoint2DTransformed",),
)
