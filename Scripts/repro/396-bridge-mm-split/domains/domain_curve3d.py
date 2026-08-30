"""OCCTBridge_Curve3D.mm split config (#1380).

Six buckets, same shape as Geom2d's: dominated by `Geom` itself (curve/point/axis/transform base
concern -- Curves, the default_bucket), with disjoint sub-concerns: curve-on-edge adaptors
(BRepAdaptor/GeomAdaptor), 3D extrema (Extrema_ExtCC/ExtCS), arc-length sampling (GCPnts/CPnts),
conversion (GC_Make*/gce_Make*/GeomConvert/Convert_*/GeomAPI/ShapeUpgrade curve3d), and
approximation (Approx_*/LocalAnalysis_CurveContinuity/GeomLib).
"""
from split_bridge_mm import register_domain

BUCKETS = ["Curves", "Adaptor", "Extrema", "ArcLength", "Conversion", "Approximation"]

BUCKET_DESC = {
    "Curves": "Geom_* (Circle/Ellipse/Hyperbola/Parabola/Line/OffsetCurve/BSpline/Bezier/"
              "TrimmedCurve), CartesianPoint/Direction/Vector/Axis1+2/Transformation, "
              "gp_Quaternion, ElCLib -- default_bucket",
    "Adaptor": "BRepAdaptor, GeomAdaptor",
    "Extrema": "Extrema_ExtCC/ExtCS/LocateExtCC",
    "ArcLength": "GCPnts (UniformAbscissa, QuasiUniform, TangentialDeflection, "
                 "UniformDeflection), CPnts",
    "Conversion": "GC_Make*, gce_Make*, GeomConvert, Convert_*, GeomAPI, ShapeUpgrade/"
                  "ShapeConstruct curve3d",
    "Approximation": "Approx_* (Curve3d, CurveOnSurface, CurvilinearParameter, SameParameter, "
                      "ApproxCurve), LocalAnalysis_CurveContinuity, GeomLib",
}

NAME_PREFIX_BUCKET = [
    ("QuasiUniform", "ArcLength"),
    ("UniformDeflection", "ArcLength"),
    ("UniformAbscissa", "ArcLength"),
]

BODY_PACKAGE_TO_BUCKET = {
    "Geom": "Curves", "gp": "Curves", "ElCLib": "Curves",
    "BRepAdaptor": "Adaptor", "GeomAdaptor": "Adaptor",
    "Extrema": "Extrema",
    "GCPnts": "ArcLength", "CPnts": "ArcLength",
    "GC": "Conversion", "gce": "Conversion", "GeomConvert": "Conversion", "Convert": "Conversion",
    "GeomAPI": "Conversion", "ShapeUpgrade": "Conversion", "ShapeConstruct": "Conversion",
    "ShapeAnalysis": "Conversion",
    "Approx": "Approximation", "LocalAnalysis": "Approximation", "GeomLib": "Approximation",
    "GeomEval": "Approximation",
}

CLASS_OVERRIDE_BUCKET = {}

NAME_BUCKET_OVERRIDE = {}

register_domain(
    "Curve3D",
    src="Curve3D", header="Curve3D", issue_note="#1380",
    buckets=BUCKETS, bucket_desc=BUCKET_DESC, default_bucket="Curves",
    name_prefix_bucket=NAME_PREFIX_BUCKET,
    body_package_to_bucket=BODY_PACKAGE_TO_BUCKET,
    class_override_bucket=CLASS_OVERRIDE_BUCKET,
    name_bucket_override=NAME_BUCKET_OVERRIDE,
)
