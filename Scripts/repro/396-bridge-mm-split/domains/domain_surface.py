"""OCCTBridge_Surface.mm split config (#1380).

Seven buckets. Dominated by `GeomFill` (193 mentions, sweep/trihedron/Coons/Gordon/network surface
construction -- Fill) and `Geom` itself (surface construction/query -- Surfaces, the
default_bucket), with disjoint sub-concerns: surface-surface/curve-surface intersection
(Contap/GeomInt), surface analysis (ShapeAnalysis_Surface/LocalAnalysis/GeomLib), curve-on-surface
adaptors (Adaptor3d/BRepAdaptor/GeomAdaptor), point/surface extrema (Extrema_ExtPS/ExtSS/ExtElSS/
ExtPElS), and conversion/approximation (GeomConvert/ShapeCustom/GeomAPI_ProjectPointOnSurf).
"""
from split_bridge_mm import register_domain

BUCKETS = ["Surfaces", "Fill", "Intersection", "Analysis", "Adaptor", "Extrema", "Conversion"]

BUCKET_DESC = {
    "Surfaces": "Geom_* (RectangularTrimmedSurface, OffsetSurface, Plane, Spherical, Toroidal, "
                "Cylindrical, Conical, SurfaceOfRevolution, Swept, BSpline, Bezier), gce_Make, "
                "GC_Make*, ElSLib -- default_bucket",
    "Fill": "GeomFill_* (Sweep, NSections, Trihedron laws, Coons, Generator, Gordon, "
            "NetworkSurface, DegeneratedBound, Profiler, Stretch, LocationDraft, GuideTrihedron*, "
            "SectionPlacement, AppSurf, ConstrainedFilling, EvolvedSection, CoonsAlgPatch)",
    "Intersection": "Contap_* (Contour), GeomInt_IntSS, GeomAPI_IntCS",
    "Analysis": "ShapeAnalysis_Surface, LocalAnalysis_SurfaceContinuity, GeomLib, "
                "GeomConvert_SurfToAnaSurf",
    "Adaptor": "Adaptor3d_IsoCurve, BRepAdaptor, GeomAdaptor",
    "Extrema": "Extrema_ExtPS/ExtSS/ExtElSS/ExtPElS",
    "Conversion": "GeomConvert_ApproxSurface, ShapeCustom_Surface, KnotSplitting/"
                  "JoinBezierPatches/ConvertToAnalytical/SplitByContinuity/GridEval, "
                  "GeomAPI_ProjectPointOnSurf, BiTgte_CurveOnEdge",
}

NAME_PREFIX_BUCKET = [
    ("Contap", "Intersection"),
    ("SurfaceSurfaceIntersection", "Intersection"),
    ("CurveSurfaceIntersection", "Intersection"),
    ("CanonicalRecognition", "Analysis"),
    ("SurfaceSingularity", "Analysis"),
    ("BiTgteCurveOnEdge", "Conversion"),
]

BODY_PACKAGE_TO_BUCKET = {
    "Geom": "Surfaces", "gp": "Surfaces", "gce": "Surfaces", "GC": "Surfaces", "ElSLib": "Surfaces",
    "Convert": "Surfaces",
    "GeomFill": "Fill",
    "Contap": "Intersection", "GeomInt": "Intersection",
    "ShapeAnalysis": "Analysis", "LocalAnalysis": "Analysis", "GeomLib": "Analysis",
    "GeomConvert": "Analysis",
    "Adaptor3d": "Adaptor", "BRepAdaptor": "Adaptor", "GeomAdaptor": "Adaptor",
    "Extrema": "Extrema",
    "ShapeCustom": "Conversion", "GeomAPI": "Conversion", "BiTgte": "Conversion",
    "GeomGridEval": "Conversion", "GeomEval": "Conversion",
}

CLASS_OVERRIDE_BUCKET = {
    # GeomConvert has two genuinely different concerns in this file: ApproxSurface/knot-splitting
    # utility (Conversion) vs SurfToAnaSurf's analytic-surface RECOGNITION, which is an analysis
    # question, not a conversion one. Package-vote alone can't tell them apart since both are the
    # same "GeomConvert" prefix; the specific class does.
    "GeomConvert_SurfToAnaSurf": "Analysis",
}

NAME_BUCKET_OVERRIDE = {}

register_domain(
    "Surface",
    src="Surface", header="Surface", issue_note="#1380",
    buckets=BUCKETS, bucket_desc=BUCKET_DESC, default_bucket="Surfaces",
    name_prefix_bucket=NAME_PREFIX_BUCKET,
    body_package_to_bucket=BODY_PACKAGE_TO_BUCKET,
    class_override_bucket=CLASS_OVERRIDE_BUCKET,
    name_bucket_override=NAME_BUCKET_OVERRIDE,
    # buildSurfaceFromElementary: a forward declaration (needed because
    # OCCTConvertSphereToBSplineSurface calls it before its real definition appears in the file),
    # not two competing definitions -- same shape as Geom2d's own allowed
    # OCCTPoint2DTransformed. Both the forward decl and the definition are `static`, so both route
    # SHARED automatically; confirmed same bucket before allowing.
    allowed_duplicate_names=("buildSurfaceFromElementary",),
)
