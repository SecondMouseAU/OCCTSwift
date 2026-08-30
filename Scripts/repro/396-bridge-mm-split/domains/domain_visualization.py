"""OCCTBridge_Visualization.mm split config (#1380).

Four buckets, genuinely disjoint presentation-layer concerns: camera (Graphic3d_Camera),
presentation/drawing (Prs3d/PrsMgr, mesh-aware drawer extraction, and -- measured, not assumed --
every SelectMgr_*-touching function too: none of them has SelectMgr as its OWN top package vote,
so a dedicated Selection bucket was tried and dropped after coming back consistently empty),
appearance (Quantity color/period/date, Graphic3d material/PBR/clip-plane/Z-layer), and assets
(Font_FontMgr, Image_AlienPixMap).
"""
from split_bridge_mm import register_domain

BUCKETS = ["Camera", "Presentation", "Appearance", "Assets"]

BUCKET_DESC = {
    "Camera": "Graphic3d_Camera",
    "Presentation": "Prs3d_Drawer/Presentation, PrsMgr_PresentationManager, drawer-aware mesh "
                    "extraction, SelectMgr_* selector wrappers -- default_bucket",
    "Appearance": "Quantity_Color/ColorRGBA/Period/Date, Graphic3d_MaterialAspect/PBRMaterial/"
                  "ClipPlane/ZLayerSettings",
    "Assets": "Font_FontMgr, Image_AlienPixMap",
}

NAME_PREFIX_BUCKET = [
    ("Camera", "Camera"),
    ("ClipPlane", "Appearance"),
    ("ZLayer", "Appearance"),
    ("Font", "Assets"),
    ("Image", "Assets"),
]

BODY_PACKAGE_TO_BUCKET = {
    "Graphic3d": "Camera",  # overridden per-class below for Material/PBR/ClipPlane/ZLayer
    "Prs3d": "Presentation", "PrsMgr": "Presentation",
    # No "SelectMgr" entry: every SelectMgr_*-touching function co-references a stronger-voting
    # package (or none at all) in this file, so it never wins the top-package vote -- measured
    # (0 items landed under a dedicated Selection bucket before it was removed as unused), not
    # assumed. Kept out rather than pointed at a bucket to avoid silently relocating those
    # functions if that measurement ever stops holding.
    "Quantity": "Appearance",
    "Font": "Assets", "Image": "Assets",
}

CLASS_OVERRIDE_BUCKET = {
    "Graphic3d_MaterialAspect": "Appearance", "Graphic3d_NameOfMaterial": "Appearance",
    "Graphic3d_TypeOfMaterial": "Appearance", "Graphic3d_PBRMaterial": "Appearance",
    "Graphic3d_ClipPlane": "Appearance", "Graphic3d_ZLayerSettings": "Appearance",
    "Graphic3d_Camera": "Camera",
}

NAME_BUCKET_OVERRIDE = {}

register_domain(
    "Visualization",
    src="Visualization", header="Visualization", issue_note="#1380",
    buckets=BUCKETS, bucket_desc=BUCKET_DESC, default_bucket="Presentation",
    name_prefix_bucket=NAME_PREFIX_BUCKET,
    body_package_to_bucket=BODY_PACKAGE_TO_BUCKET,
    class_override_bucket=CLASS_OVERRIDE_BUCKET,
    name_bucket_override=NAME_BUCKET_OVERRIDE,
)
