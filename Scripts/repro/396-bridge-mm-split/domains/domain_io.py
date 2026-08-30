"""OCCTBridge_IO.mm split config (#396/#1378-follow-on).

Seven buckets: three by CAD interchange format (STEP/IGES/mesh-formats), one for
native/persistence formats OCCT itself defines (BinTools/GeomTools/BREP/VRML), one for the
progress+cancellation channel (#98) that's genuinely cross-format (a BridgeProgressIndicator used
by STEP/IGES/mesh progress variants alike -- it's a `class`, so it's SHARED automatically, not
single-bucketed), one for diagnostics (Message_*/UnitsAPI), and one for the large cluster of pure
OS/runtime-abstraction wrappers (OSD_*, Resource_Manager, Resource_Unicode) that live in this file
only because that's where file-I/O-adjacent utility wrapping has always landed, not because they
share any CAD-format concern with the rest.
"""
from split_bridge_mm import register_domain

BUCKETS = ["StepFormat", "IgesFormat", "MeshFormats", "NativeFormats", "Diagnostics", "OSDUtilities", "Misc"]

BUCKET_DESC = {
    "StepFormat": "STEPControl, STEPCAFControl, APIHeaderSection (STEP header)",
    "IgesFormat": "IGESControl",
    "MeshFormats": "StlAPI, RWObj, RWPly, RWGltf, RWMesh, BRepMesh, IMeshTools",
    "NativeFormats": "BinTools, GeomTools persistence, BREP native/string, VrmlAPI",
    "Diagnostics": "Message_Messenger/Report/Msg, UnitsAPI, UnitsMethods",
    "OSDUtilities": "OSD_Timer/MemInfo/Environment/Path/Process/File/Host/PerfMeter/Directory/Disk/SharedLibrary, Resource_Manager, Resource_Unicode",
    "Misc": "Progress/cancellation dispatch and anything not cleanly one format",
}

NAME_PREFIX_BUCKET = [
    ("STEP", "StepFormat"),
    ("IGES", "IgesFormat"),
    ("STL", "MeshFormats"),
    ("Obj", "MeshFormats"),
    ("OBJ", "MeshFormats"),
    ("Ply", "MeshFormats"),
    ("PLY", "MeshFormats"),
    ("Gltf", "MeshFormats"),
    ("GLTF", "MeshFormats"),
    ("IncrementalMesh", "MeshFormats"),
    ("BinTools", "NativeFormats"),
    ("BrepString", "NativeFormats"),
    ("BREPString", "NativeFormats"),
    ("Vrml", "NativeFormats"),
    ("GeomToolsCurve", "NativeFormats"),
    ("GeomToolsSurface", "NativeFormats"),
    ("Units", "Diagnostics"),
    ("Message", "Diagnostics"),
    ("OSD", "OSDUtilities"),
    ("Timer", "OSDUtilities"),
    ("MemInfo", "OSDUtilities"),
    ("Environment", "OSDUtilities"),
    ("PerfMeter", "OSDUtilities"),
    ("Chronometer", "OSDUtilities"),
    ("Resource", "OSDUtilities"),
    ("SharedLibrary", "OSDUtilities"),
]

BODY_PACKAGE_TO_BUCKET = {
    "STEPControl": "StepFormat", "STEPCAFControl": "StepFormat", "APIHeaderSection": "StepFormat",
    "IGESControl": "IgesFormat",
    "StlAPI": "MeshFormats", "RWObj": "MeshFormats", "RWPly": "MeshFormats", "RWGltf": "MeshFormats",
    "RWMesh": "MeshFormats", "BRepMesh": "MeshFormats", "IMeshTools": "MeshFormats",
    "BinTools": "NativeFormats", "GeomTools": "NativeFormats", "VrmlAPI": "NativeFormats",
    "Message": "Diagnostics", "UnitsAPI": "Diagnostics", "UnitsMethods": "Diagnostics",
    "OSD": "OSDUtilities", "Resource": "OSDUtilities",
    "IFSelect": "StepFormat", "Interface": "StepFormat",
}

CLASS_OVERRIDE_BUCKET = {}

NAME_BUCKET_OVERRIDE = {
    # "Step"/"Iges" mixed-case (not "STEP"/"IGES" all-caps) prefix families -- the bridge's own
    # naming is inconsistent about which casing an acronym gets.
    "OCCTStepHeaderCreate": "StepFormat", "OCCTStepHeaderRelease": "StepFormat",
    "OCCTStepHeaderIsDone": "StepFormat", "OCCTStepHeaderGetName": "StepFormat",
    "OCCTStepHeaderSetName": "StepFormat", "OCCTStepHeaderGetTimeStamp": "StepFormat",
    "OCCTStepHeaderSetTimeStamp": "StepFormat", "OCCTStepHeaderGetAuthor": "StepFormat",
    "OCCTStepHeaderSetAuthor": "StepFormat", "OCCTStepHeaderGetOrganization": "StepFormat",
    "OCCTStepHeaderSetOrganization": "StepFormat",
    "OCCTStepHeaderGetPreprocessorVersion": "StepFormat",
    "OCCTStepHeaderSetPreprocessorVersion": "StepFormat",
    "OCCTStepHeaderGetOriginatingSystem": "StepFormat",
    "OCCTStepHeaderSetOriginatingSystem": "StepFormat",
    # OSD_File/OSD_SharedLibrary/OSD_Process wrappers whose bodies call only their own struct's
    # methods, no OCCT package token in the body to vote with.
    "OCCTFileCreateTemporary": "OSDUtilities", "OCCTFileRelease": "OSDUtilities",
    "OCCTFileWrite": "OSDUtilities", "OCCTFileReadLine": "OSDUtilities",
    "OCCTFileReadAll": "OSDUtilities", "OCCTFileClose": "OSDUtilities",
    "OCCTFileIsOpen": "OSDUtilities", "OCCTFileSize": "OSDUtilities",
    "OCCTFileRewind": "OSDUtilities", "OCCTFileIsAtEnd": "OSDUtilities",
    "OCCTFileFreeString": "OSDUtilities", "OCCTProcessFreeString": "OSDUtilities",
    "OCCTSharedLibCreate": "OSDUtilities", "OCCTSharedLibRelease": "OSDUtilities",
    "OCCTSharedLibClose": "OSDUtilities", "OCCTSharedLibName": "OSDUtilities",
    # GeomTools_CurveSet/Curve2dSet/SurfaceSet's own free-string helper.
    "OCCTGeomToolsFreeString": "NativeFormats",
    # BREP is OCCT's own native shape-persistence format (BRepTools::Read/Write), same family as
    # BinTools/GeomTools persistence.
    "OCCTImportBREP": "NativeFormats", "OCCTExportBREP": "NativeFormats",
    "OCCTExportBREPWithTriangles": "NativeFormats",
    # igesMutex(): non-static (declared in OCCTBridge_Internal.h, external linkage -- the file's
    # own comment says so, "so per-area TUs share the same underlying mutex via the linker"), same
    # shape as Modeling's occtDefeaturingFacesFromShapes/occtDefeaturePerform (#396/#1378). Must
    # NOT go SHARED (would duplicate an externally-linked definition across every split file and
    # fail to link); single-bucketed with the IGES operations it serializes.
    "igesMutex": "IgesFormat",
    # Generic shape queries with no format affiliation; historically placed here by proximity to
    # import success-checking, not by any I/O concern of their own.
    "OCCTShapeGetType": "Misc", "OCCTShapeIsValidSolid": "Misc",
}

register_domain(
    "IO",
    src="IO", header="IO", issue_note="#396/#1378-follow-on",
    buckets=BUCKETS, bucket_desc=BUCKET_DESC,
    name_prefix_bucket=NAME_PREFIX_BUCKET,
    body_package_to_bucket=BODY_PACKAGE_TO_BUCKET,
    class_override_bucket=CLASS_OVERRIDE_BUCKET,
    name_bucket_override=NAME_BUCKET_OVERRIDE,
)
