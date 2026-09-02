//
//  OCCTBridge_Document.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Document domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_Document_h
#define OCCTBridge_Document_h

/// Create a new empty XDE document
OCCTDocumentRef OCCTDocumentCreate(void);

/// Load STEP file into XDE document with assembly structure, names, colors, materials
/// @param path Path to STEP file
/// @return Document reference, or NULL on failure
OCCTDocumentRef OCCTDocumentLoadSTEP(const char* path);

/// Write document to STEP file (preserves assembly structure, colors, materials)
/// @param doc Document to write
/// @param path Output file path
/// @return true on success
bool OCCTDocumentWriteSTEP(OCCTDocumentRef doc, const char* path);

/// Release document and all internal resources
void OCCTDocumentRelease(OCCTDocumentRef doc);

// MARK: - XDE Assembly Traversal

/// Get number of root (top-level/free) shapes in document
int32_t OCCTDocumentGetRootCount(OCCTDocumentRef doc);

/// Get label ID for root shape at index
/// @param doc Document
/// @param index Root index (0-based)
/// @return Label ID, or -1 if index out of bounds
int64_t OCCTDocumentGetRootLabelId(OCCTDocumentRef doc, int32_t index);

/// Get name for a label
/// @param doc Document
/// @param labelId Label identifier
/// @return Name string (caller must free with OCCTStringFree), or NULL if no name
const char* OCCTDocumentGetLabelName(OCCTDocumentRef doc, int64_t labelId);

/// Check if label represents an assembly (has components)
bool OCCTDocumentIsAssembly(OCCTDocumentRef doc, int64_t labelId);

/// Check if label is a reference (instance of another shape)
bool OCCTDocumentIsReference(OCCTDocumentRef doc, int64_t labelId);

/// Get number of child components for an assembly label
int32_t OCCTDocumentGetChildCount(OCCTDocumentRef doc, int64_t labelId);

/// Get child label ID at index
/// @param doc Document
/// @param parentLabelId Parent assembly label
/// @param index Child index (0-based)
/// @return Child label ID, or -1 if index out of bounds
int64_t OCCTDocumentGetChildLabelId(OCCTDocumentRef doc, int64_t parentLabelId, int32_t index);

/// Get the referred shape label for a reference
/// @param doc Document
/// @param refLabelId Reference label ID
/// @return Referred label ID, or -1 if not a reference
int64_t OCCTDocumentGetReferredLabelId(OCCTDocumentRef doc, int64_t refLabelId);

/// Get shape for a label (without location transform applied)
/// @param doc Document
/// @param labelId Label identifier
/// @return Shape reference (caller must release), or NULL on failure
OCCTShapeRef OCCTDocumentGetShape(OCCTDocumentRef doc, int64_t labelId);

/// Get shape with location transform applied
/// @param doc Document
/// @param labelId Label identifier
/// @return Shape reference with transform applied (caller must release), or NULL on failure
OCCTShapeRef OCCTDocumentGetShapeWithLocation(OCCTDocumentRef doc, int64_t labelId);

// MARK: - XDE Transforms

/// Get location transform as 4x4 matrix (column-major, suitable for simd_float4x4)
/// @param doc Document
/// @param labelId Label identifier
/// @param outMatrix16 Output array for 16 floats (column-major 4x4 matrix)
void OCCTDocumentGetLocation(OCCTDocumentRef doc, int64_t labelId, float* outMatrix16);

// MARK: - XDE Colors

/// Color type (matches XCAFDoc_ColorType)
typedef enum
{
  OCCTColorTypeGeneric = 0, // Generic color
  OCCTColorTypeSurface = 1, // Surface color (overrides generic)
  OCCTColorTypeCurve   = 2  // Curve color (overrides generic)
} OCCTColorType;

/// RGBA color with set flag
typedef struct
{
  double r, g, b, a;
  bool   isSet;
} OCCTColor;

/// Get color for a label
/// @param doc Document
/// @param labelId Label identifier
/// @param colorType Type of color to retrieve
/// @return Color structure (check isSet to see if color was assigned)
OCCTColor OCCTDocumentGetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType);

/// Set color for a label
/// @param doc Document
/// @param labelId Label identifier
/// @param colorType Type of color to set
/// @param r, g, b RGB values (0.0-1.0)
void OCCTDocumentSetLabelColor(OCCTDocumentRef doc,
                               int64_t         labelId,
                               OCCTColorType   colorType,
                               double          r,
                               double          g,
                               double          b);

// MARK: - XDE Materials (PBR)

/// PBR Material properties
typedef struct
{
  OCCTColor baseColor;
  double    metallic;  // 0.0-1.0
  double    roughness; // 0.0-1.0
  OCCTColor emissive;
  double    transparency; // 0.0-1.0
  bool      isSet;
} OCCTMaterial;

/// Get PBR material for a label
/// @param doc Document
/// @param labelId Label identifier
/// @return Material structure (check isSet to see if material was assigned)
OCCTMaterial OCCTDocumentGetLabelMaterial(OCCTDocumentRef doc, int64_t labelId);

/// Set PBR material for a label
/// @param doc Document
/// @param labelId Label identifier
/// @param material Material properties to set
void OCCTDocumentSetLabelMaterial(OCCTDocumentRef doc, int64_t labelId, OCCTMaterial material);

// MARK: - XDE Utility

/// Free a string returned by OCCTDocumentGetLabelName
void OCCTStringFree(const char* str);

// MARK: - XDE GD&T / Dimension Tolerance (v0.21.0)

/// Get count of dimension labels in document
int32_t OCCTDocumentGetDimensionCount(OCCTDocumentRef doc);

/// Get count of geometric tolerance labels in document
int32_t OCCTDocumentGetGeomToleranceCount(OCCTDocumentRef doc);

/// Get count of datum labels in document
int32_t OCCTDocumentGetDatumCount(OCCTDocumentRef doc);

/// Number of dimensions referencing the shape at shapeLabelId, via
/// XCAFDoc_DimTolTool::GetRefDimensionLabels. Returns 0 if shapeLabelId does not resolve to a
/// label. A single-shape dimension created via OCCTDocumentCreateDimension /
/// OCCTDocumentCreateDimensionWithTolerance must appear here exactly once, not twice (#1481: the
/// create path used to pass the same shape label as both SetDimension() sequence arguments,
/// double-registering it as both the DimensionRefFirstGUID and DimensionRefSecondGUID graph-node
/// father).
int32_t OCCTDocumentGetRefDimensionCount(OCCTDocumentRef doc, int64_t shapeLabelId);

/// How a dimension's values array encodes its magnitude, taken from OCCT's own predicates
/// (XCAFDimTolObjects_DimensionObject::IsDimWithRange / IsDimWithPlusMinusTolerance). The array is
/// 0, 1, 2 or 3 long, and which accessors mean anything follows from that (#996).
typedef enum
{
  OCCTDimensionBoundsUnset     = 0, ///< No values array at all
  OCCTDimensionBoundsSimple    = 1, ///< One element: a nominal value, no tolerance
  OCCTDimensionBoundsRange     = 2, ///< Two elements: lower and upper bound
  OCCTDimensionBoundsPlusMinus = 3  ///< Three elements: value, lower tol, upper tol
} OCCTDimensionBoundsKind;

/// Dimension info result.
///
/// boundsKind decides which of value/lowerBound/upperBound/lowerTol/upperTol carry an answer, and
/// nothing else does: OCCT returns a flat 0 from every accessor that does not apply to the kind at
/// hand, so a caller reading them unconditionally cannot tell an unset tolerance from a range
/// dimension. Before #996 this struct had no discriminator and reported a 10..12 range as
/// value=10 with both tolerances 0.
///
/// hasDecimalPlaces is the same shape one level down. GetNbOfDecimalPlaces() has no predicate
/// beside it, and XCAFDoc_Dimension::SetObject stores the pair only when `theL > 0 || theR > 0`,
/// so that expression IS the presence test rather than an approximation of one; anything else
/// would report an unstored pair as a measured (0,0) (#1004).
typedef struct
{
  int32_t type;                // XCAFDimTolObjects_DimensionType enum
  int32_t boundsKind;          // OCCTDimensionBoundsKind
  double  value;               // GetValue(): the nominal value, or a range's midpoint; 0 when Unset
  double  lowerBound;          // GetLowerBound(), Range only
  double  upperBound;          // GetUpperBound(), Range only
  double  lowerTol;            // GetLowerTolValue(), PlusMinus only
  double  upperTol;            // GetUpperTolValue(), PlusMinus only
  bool    hasClassOfTolerance; // IsDimWithClassOfTolerance(), independent of boundsKind
  bool    classOfToleranceIsHole; // GetClassOfTolerance()'s theHole out-parameter
  int32_t formVariance;           // XCAFDimTolObjects_DimensionFormVariance enum
  int32_t grade;                  // XCAFDimTolObjects_DimensionGrade enum
  int32_t qualifier;              // XCAFDimTolObjects_DimensionQualifier enum, _None when absent
  int32_t angularQualifier;       // XCAFDimTolObjects_AngularQualifier enum, _None when absent
  bool    hasDecimalPlaces;       // see below; false leaves the two counts at 0
  int32_t decimalPlacesLeft;      // GetNbOfDecimalPlaces()'s theL out-parameter
  int32_t decimalPlacesRight;     // GetNbOfDecimalPlaces()'s theR out-parameter
  int32_t modifierCount; // GetModifiers().Length(), index with OCCTDocumentGetDimensionModifier
  bool    isValid;
} OCCTDimensionInfo;

/// Get dimension info at index
OCCTDimensionInfo OCCTDocumentGetDimensionInfo(OCCTDocumentRef doc, int32_t index);

/// One modifier of the dimension at dimensionIndex, as an XCAFDimTolObjects_DimensionModif value.
/// GetModifiers() returns a sequence rather than a scalar, so it crosses the bridge as this
/// count-plus-index pair with OCCTDimensionInfo::modifierCount. modifierIndex is zero-based;
/// returns -1 for either index out of range (#1004).
int32_t OCCTDocumentGetDimensionModifier(OCCTDocumentRef _Nonnull doc,
                                         int32_t dimensionIndex,
                                         int32_t modifierIndex);

/// XCAFDimTolObjects_DimensionObject::IsDimensionalLocation / IsDimensionalSize, which are static
/// classifiers of the type code and need no dimension object. type is an
/// XCAFDimTolObjects_DimensionType value; both return false for a value outside that enum.
bool OCCTDimensionTypeIsDimensionalLocation(int32_t type);
bool OCCTDimensionTypeIsDimensionalSize(int32_t type);

/// Geometric tolerance info result.
///
/// Each of the three modifier enums carries its own _None member at ordinal 0, so those cross the
/// bridge as-is and absence needs no separate flag. The two doubles have no such member and no
/// predicate beside them, so they follow XCAFDoc_GeomTolerance::SetObject's own store condition,
/// `> 0`, which is what separates an unstored value from a measured zero: measured, an unstored one
/// reads back as the fresh object's unassigned member, which is also 0 (#1004).
typedef struct
{
  int32_t type;                 // XCAFDimTolObjects_GeomToleranceType enum
  double  value;                // tolerance value
  int32_t typeOfValue;          // XCAFDimTolObjects_GeomToleranceTypeValue, _None when absent
  int32_t materialRequirement;  // XCAFDimTolObjects_GeomToleranceMatReqModif, _None when absent
  int32_t zoneModifier;         // XCAFDimTolObjects_GeomToleranceZoneModif, _None when absent
  bool    hasZoneModifierValue; // GetValueOfZoneModifier() > 0
  double  zoneModifierValue;
  bool    hasMaxValueModifier; // GetMaxValueModifier() > 0
  double  maxValueModifier;
  int32_t modifierCount; // GetModifiers().Length(), with OCCTDocumentGetGeomToleranceModifier
  bool    isValid;
} OCCTGeomToleranceInfo;

/// Get geometric tolerance info at index
OCCTGeomToleranceInfo OCCTDocumentGetGeomToleranceInfo(OCCTDocumentRef doc, int32_t index);

/// One modifier of the tolerance at toleranceIndex, as an XCAFDimTolObjects_GeomToleranceModif
/// value. modifierIndex is zero-based; returns -1 for either index out of range (#1004).
int32_t OCCTDocumentGetGeomToleranceModifier(OCCTDocumentRef _Nonnull doc,
                                             int32_t toleranceIndex,
                                             int32_t modifierIndex);

/// Datum info result.
///
/// position is the datum's place in its geometric tolerance's reference frame, which is what makes
/// A|B|C ordered rather than a set. It is 1-based: STEPCAFControl_Reader's frame counter starts at
/// 0 and is incremented before each datum is written, so 0 is never assigned by an import and
/// hasPosition reports `> 0` (#1004).
///
/// The datum-target group is gated twice over, matching XCAFDoc_Datum::SetObject's own nesting.
/// targetType and targetNumber mean something only when isDatumTarget holds; targetLength only when
/// hasTargetParams holds AND the type is not Point; targetWidth only when hasTargetParams holds AND
/// the type is Rectangle. Measured per type in Scripts/repro/1004-gdt-accessors/.
///
/// The name is NOT here. It used to be a `char name[64]` this struct copied into with strncpy,
/// which silently returned 63 bytes of a longer identifier while OCCTDocumentCreateDatum wrote the
/// whole string, so a name a caller had just written did not compare equal to the one it read back
/// and nothing in the chain said why (#1055). Read it with OCCTDocumentGetDatumName below, which
/// reports the length it needs and so cannot truncate without saying so.
typedef struct
{
  bool    hasPosition;       // GetPosition() > 0
  int32_t position;          // place in the related tolerance's reference frame, 1-based
  int32_t modifierWithValue; // XCAFDimTolObjects_DatumModifWithValue, _None when absent
  double  modifierValue;     // meaningful only when modifierWithValue is not _None
  int32_t modifierCount;     // GetModifiers().Length(), with OCCTDocumentGetDatumModifier
  bool    isDatumTarget;     // IsDatumTarget()
  int32_t targetType;        // XCAFDimTolObjects_DatumTargetType, isDatumTarget only
  int32_t targetNumber;      // isDatumTarget only
  bool    hasTargetParams;   // HasDatumTargetParams()
  bool    hasTargetLength;   // hasTargetParams and targetType is not _Point
  double  targetLength;
  bool    hasTargetWidth; // hasTargetParams and targetType is _Rectangle
  double  targetWidth;
  bool    isValid;
} OCCTDatumInfo;

/// Get datum info at index
OCCTDatumInfo OCCTDocumentGetDatumInfo(OCCTDocumentRef doc, int32_t index);

/// Copy the datum's identifier into a caller-sized buffer, NUL-terminated.
///
/// Returns the length of the whole identifier in bytes, not counting the terminator, or -1 for a
/// datum that cannot be read (index out of range, no attribute, or the #1030 refusal). A return of
/// maxLen or more means outName holds a truncated copy: allocate that many bytes plus one and call
/// again. outName may be NULL with maxLen 0, which asks for the length alone and writes nothing,
/// so a caller with no fixed bound sizes its buffer in one extra call rather than guessing (#1055).
int32_t OCCTDocumentGetDatumName(OCCTDocumentRef _Nonnull doc,
                                 int32_t index,
                                 char* _Nullable outName,
                                 int32_t maxLen);

/// One modifier of the datum at datumIndex, as an XCAFDimTolObjects_DatumSingleModif value.
/// modifierIndex is zero-based; returns -1 for either index out of range (#1004).
int32_t OCCTDocumentGetDatumModifier(OCCTDocumentRef _Nonnull doc,
                                     int32_t datumIndex,
                                     int32_t modifierIndex);

// MARK: - GD&T Write Path (v0.140)

/// Create a dimension attribute on the document and attach it to a shape label.
/// type: XCAFDimTolObjects_DimensionType enum
/// value: primary measured value
/// Returns -1 on failure, else the index of the new dimension (usable with
/// OCCTDocumentGetDimensionInfo).
int32_t OCCTDocumentCreateDimension(OCCTDocumentRef _Nonnull doc,
                                    int64_t shapeLabelId,
                                    int32_t type,
                                    double  value);

/// Create a dimension carrying a plus/minus tolerance pair, in one step.
///
/// Same as OCCTDocumentCreateDimension plus SetLowerTolValue / SetUpperTolValue, with one
/// difference that is the whole point of the entry point: the tolerance is applied to the object
/// BEFORE any label is created, so a pair the object will not take (a NaN, say, which the readback
/// rejects) returns -1 having created nothing. Applying it afterwards leaves a dimension the caller
/// was handed an index for whose tolerance was dropped, which is what a discarded
/// OCCTDocumentSetDimensionTolerance result produced (#1056).
/// Returns -1 on failure, else the index of the new dimension.
int32_t OCCTDocumentCreateDimensionWithTolerance(OCCTDocumentRef _Nonnull doc,
                                                 int64_t shapeLabelId,
                                                 int32_t type,
                                                 double  value,
                                                 double  lowerTol,
                                                 double  upperTol);

/// Create a geometric tolerance attribute on the document and attach it to a shape.
/// type: XCAFDimTolObjects_GeomToleranceType enum
/// Returns -1 on failure, else the index of the new tolerance.
int32_t OCCTDocumentCreateGeomTolerance(OCCTDocumentRef _Nonnull doc,
                                        int64_t shapeLabelId,
                                        int32_t type,
                                        double  value);

/// Create a datum attribute on the document with the given identifier.
/// Returns -1 on failure, else the index of the new datum.
int32_t OCCTDocumentCreateDatum(OCCTDocumentRef _Nonnull doc, const char* _Nonnull name);

/// Set tolerance bounds (lower + upper, relative to the primary value) on an existing dimension,
/// making it OCCTDimensionBoundsPlusMinus. Returns the conjunction of OCCT's two setter results,
/// both of which are false for a dimension that is already a range and is therefore left unchanged
/// (#996; before that this returned true regardless).
bool OCCTDocumentSetDimensionTolerance(OCCTDocumentRef _Nonnull doc,
                                       int32_t dimensionIndex,
                                       double  lowerTol,
                                       double  upperTol);

/// Turn an existing dimension into a range dimension with the given bounds, via
/// XCAFDimTolObjects_DimensionObject::SetLowerBound / SetUpperBound. Returns true on success. This
/// is the only way to author the kind OCCTDimensionBoundsRange reports (#996).
bool OCCTDocumentSetDimensionBounds(OCCTDocumentRef _Nonnull doc,
                                    int32_t dimensionIndex,
                                    double  lowerBound,
                                    double  upperBound);

/// Set the ISO 286 tolerance class of an existing dimension, via
/// XCAFDimTolObjects_DimensionObject::SetClassOfTolerance. Independent of the values array, so a
/// range or plus/minus dimension can carry one too. formVariance is
/// XCAFDimTolObjects_DimensionFormVariance, grade is XCAFDimTolObjects_DimensionGrade. Returns
/// false if either names no enumerator, since an out-of-range formVariance is stored verbatim and
/// additionally makes IsDimWithClassOfTolerance() true. Returns true on success (#996, #1037).
bool OCCTDocumentSetDimensionClassOfTolerance(OCCTDocumentRef _Nonnull doc,
                                              int32_t dimensionIndex,
                                              bool    isHole,
                                              int32_t formVariance,
                                              int32_t grade);

/// Set the dimension's qualifier (min / max / average), via
/// XCAFDimTolObjects_DimensionObject::SetQualifier. qualifier is an
/// XCAFDimTolObjects_DimensionQualifier value; _None clears it. Returns true on success (#1004).
bool OCCTDocumentSetDimensionQualifier(OCCTDocumentRef _Nonnull doc,
                                       int32_t dimensionIndex,
                                       int32_t qualifier);

/// Set the dimension's angular qualifier (small / large / equal), via
/// XCAFDimTolObjects_DimensionObject::SetAngularQualifier. angularQualifier is an
/// XCAFDimTolObjects_AngularQualifier value; _None clears it. Returns true on success (#1004).
bool OCCTDocumentSetDimensionAngularQualifier(OCCTDocumentRef _Nonnull doc,
                                              int32_t dimensionIndex,
                                              int32_t angularQualifier);

/// Set the number of decimal places left and right of the point, via
/// XCAFDimTolObjects_DimensionObject::SetNbOfDecimalPlaces. Both zero clears the pair, matching the
/// condition XCAFDoc_Dimension::SetObject stores it under. Returns true on success (#1004).
bool OCCTDocumentSetDimensionDecimalPlaces(OCCTDocumentRef _Nonnull doc,
                                           int32_t dimensionIndex,
                                           int32_t left,
                                           int32_t right);

/// Replace the dimension's modifier sequence with the given XCAFDimTolObjects_DimensionModif
/// values, via SetModifiers. Passing count 0 clears the sequence. Returns false if the index is out
/// of range, if count is negative, if modifiers is NULL with a positive count, or if any value
/// names no enumerator, in which case nothing at all is stored (#1004, #1037).
bool OCCTDocumentSetDimensionModifiers(OCCTDocumentRef _Nonnull doc,
                                       int32_t dimensionIndex,
                                       const int32_t* _Nullable modifiers,
                                       int32_t count);

/// Set the tolerance's value type (linear, diameter, spherical diameter), via
/// XCAFDimTolObjects_GeomToleranceObject::SetTypeOfValue. _None clears it. Returns true on success
/// (#1004).
bool OCCTDocumentSetGeomToleranceTypeOfValue(OCCTDocumentRef _Nonnull doc,
                                             int32_t toleranceIndex,
                                             int32_t typeOfValue);

/// Set the tolerance's material requirement (MMC / LMC), via SetMaterialRequirementModifier. _None
/// clears it. Returns true on success (#1004).
bool OCCTDocumentSetGeomToleranceMaterialRequirement(OCCTDocumentRef _Nonnull doc,
                                                     int32_t toleranceIndex,
                                                     int32_t materialRequirement);

/// Set the tolerance zone modifier and its associated value together, via SetZoneModifier and
/// SetValueOfZoneModifier. They are one call because the value only means something under a
/// modifier, and OCCT stores the value only when it is positive. A _None modifier stores no value
/// either, so clearing the modifier clears the number with it rather than leaving a projected-zone
/// length on a tolerance that has no projected zone (#1056); this matches
/// OCCTDocumentSetDatumModifierWithValue. Returns true on success (#1004).
bool OCCTDocumentSetGeomToleranceZoneModifier(OCCTDocumentRef _Nonnull doc,
                                              int32_t toleranceIndex,
                                              int32_t zoneModifier,
                                              double  value);

/// Set the maximal upper tolerance value for a tolerance with modifiers, via SetMaxValueModifier.
/// A value of 0 or less clears it, matching the condition SetObject stores it under. Returns true
/// on success (#1004).
bool OCCTDocumentSetGeomToleranceMaxValueModifier(OCCTDocumentRef _Nonnull doc,
                                                  int32_t toleranceIndex,
                                                  double  value);

/// Replace the tolerance's modifier sequence with the given XCAFDimTolObjects_GeomToleranceModif
/// values. Passing count 0 clears the sequence. Returns false if the index is out of range, if
/// count is negative, if modifiers is NULL with a positive count, or if any value names no
/// enumerator, in which case nothing at all is stored (#1004, #1037).
bool OCCTDocumentSetGeomToleranceModifiers(OCCTDocumentRef _Nonnull doc,
                                           int32_t toleranceIndex,
                                           const int32_t* _Nullable modifiers,
                                           int32_t count);

/// Set the datum's place in its geometric tolerance's reference frame, via SetPosition. Positions
/// are 1-based; 0 or less clears it. Returns true on success (#1004).
bool OCCTDocumentSetDatumPosition(OCCTDocumentRef _Nonnull doc,
                                  int32_t datumIndex,
                                  int32_t position);

/// Replace the datum's modifier sequence with the given XCAFDimTolObjects_DatumSingleModif values.
/// Passing count 0 clears the sequence. Returns false if the index is out of range, if count is
/// negative, if modifiers is NULL with a positive count, or if any value names no enumerator, in
/// which case nothing at all is stored (#1004, #1037).
bool OCCTDocumentSetDatumModifiers(OCCTDocumentRef _Nonnull doc,
                                   int32_t datumIndex,
                                   const int32_t* _Nullable modifiers,
                                   int32_t count);

/// Set the datum's single valued modifier and its value together, via SetModifierWithValue.
/// modifier is an XCAFDimTolObjects_DatumModifWithValue value; _None clears the pair. Returns true
/// on success (#1004).
bool OCCTDocumentSetDatumModifierWithValue(OCCTDocumentRef _Nonnull doc,
                                           int32_t datumIndex,
                                           int32_t modifier,
                                           double  value);

/// Mark the datum as a datum target and set its type and number, via IsDatumTarget(bool),
/// SetDatumTargetType and SetDatumTargetNumber. Passing isTarget false clears the flag and leaves
/// the type and number alone, since neither is readable without it. type is an
/// XCAFDimTolObjects_DatumTargetType value. Returns true on success (#1004).
bool OCCTDocumentSetDatumTarget(OCCTDocumentRef _Nonnull doc,
                                int32_t datumIndex,
                                bool    isTarget,
                                int32_t type,
                                int32_t number);

/// Set the datum target's placement axis, length and width together, via SetDatumTargetAxis,
/// SetDatumTargetLength and SetDatumTargetWidth. All three are one call because each of the three
/// setters raises the same HasDatumTargetParams() flag, so writing one alone would report the other
/// two as present while leaving them unassigned. The axis is a location plus a normal plus a
/// reference direction, three doubles each. Which of length and width then survives a round trip
/// depends on the target type; see OCCTDatumInfo. Requires the datum to already be a datum target
/// of a type other than Area, because XCAFDoc_Datum::SetObject stores the axis only under
/// IsDatumTarget() and only on its non-Area branch: call OCCTDocumentSetDatumTarget first, or this
/// returns false rather than reporting success for a call that persisted nothing. Returns true on
/// success (#1004, #1038).
bool OCCTDocumentSetDatumTargetPlacement(OCCTDocumentRef _Nonnull doc,
                                         int32_t datumIndex,
                                         const double* _Nonnull location,
                                         const double* _Nonnull normal,
                                         const double* _Nonnull reference,
                                         double length,
                                         double width);

// MARK: - TNaming: Topological Naming History (v0.25.0)

/// Evolution type for TNaming history records.
typedef enum
{
  OCCTNamingPrimitive = 0, ///< New entity created (old=NULL, new=shape)
  OCCTNamingGenerated = 1, ///< Entity generated from another (old=generator, new=result)
  OCCTNamingModify    = 2, ///< Entity modified (old=before, new=after)
  OCCTNamingDelete    = 3, ///< Entity deleted (old=shape, new=NULL)
  OCCTNamingSelected  = 4  ///< Named selection (old=context, new=selected)
} OCCTNamingEvolution;

/// A single entry in the naming history of a label.
typedef struct
{
  OCCTNamingEvolution evolution;
  bool                hasOldShape;
  bool                hasNewShape;
  bool                isModification;
} OCCTNamingHistoryEntry;

/// Create a new child label under the given parent label.
/// Pass parentLabelId = -1 to create under the document root.
/// Returns the new label's ID, or -1 on failure.
int64_t OCCTDocumentCreateLabel(OCCTDocumentRef doc, int64_t parentLabelId);

/// Record a naming evolution on a label.
/// For PRIMITIVE: oldShape=NULL, newShape=the created shape.
/// For GENERATED: oldShape=generator, newShape=generated result.
/// For MODIFY: oldShape=before, newShape=after.
/// For DELETE: oldShape=deleted shape, newShape=NULL.
/// For SELECTED: oldShape=context, newShape=selected shape.
/// Returns true on success.
bool OCCTDocumentNamingRecord(OCCTDocumentRef     doc,
                              int64_t             labelId,
                              OCCTNamingEvolution evolution,
                              OCCTShapeRef        oldShape,
                              OCCTShapeRef        newShape);

/// Get the current (most recent) shape stored on a label via TNaming.
/// Uses TNaming_Tool::CurrentShape. Returns NULL if no naming exists.
OCCTShapeRef OCCTDocumentNamingGetCurrentShape(OCCTDocumentRef doc, int64_t labelId);

/// Get the shape stored in the NamedShape attribute on a label.
/// Uses TNaming_Tool::GetShape. Returns NULL if no naming exists.
OCCTShapeRef OCCTDocumentNamingGetShape(OCCTDocumentRef doc, int64_t labelId);

/// Get the number of history entries (old/new pairs) on a label.
int32_t OCCTDocumentNamingHistoryCount(OCCTDocumentRef doc, int64_t labelId);

/// Get a specific history entry by index (0-based).
/// Returns true on success.
bool OCCTDocumentNamingGetHistoryEntry(OCCTDocumentRef         doc,
                                       int64_t                 labelId,
                                       int32_t                 index,
                                       OCCTNamingHistoryEntry* outEntry);

/// Get the old shape from a specific history entry (0-based index).
/// Returns NULL if the entry has no old shape.
OCCTShapeRef OCCTDocumentNamingGetOldShape(OCCTDocumentRef doc, int64_t labelId, int32_t index);

/// Get the new shape from a specific history entry (0-based index).
/// Returns NULL if the entry has no new shape.
OCCTShapeRef OCCTDocumentNamingGetNewShape(OCCTDocumentRef doc, int64_t labelId, int32_t index);

/// Trace forward: find all shapes generated/modified from the given shape.
/// Uses TNaming_NewShapeIterator. accessLabelId provides the label scope.
/// Returns the number of shapes written to outShapes (up to maxCount).
/// Caller must release each returned shape.
int32_t OCCTDocumentNamingTraceForward(OCCTDocumentRef doc,
                                       int64_t         accessLabelId,
                                       OCCTShapeRef    shape,
                                       OCCTShapeRef*   outShapes,
                                       int32_t         maxCount);

/// Trace backward: find all shapes that generated/preceded the given shape.
/// Uses TNaming_OldShapeIterator. accessLabelId provides the label scope.
/// Returns the number of shapes written to outShapes (up to maxCount).
/// Caller must release each returned shape.
int32_t OCCTDocumentNamingTraceBackward(OCCTDocumentRef doc,
                                        int64_t         accessLabelId,
                                        OCCTShapeRef    shape,
                                        OCCTShapeRef*   outShapes,
                                        int32_t         maxCount);

/// Select a shape for persistent naming.
/// Creates a TNaming_Selector on the label and selects the shape within context.
/// Returns true on success.
bool OCCTDocumentNamingSelect(OCCTDocumentRef doc,
                              int64_t         labelId,
                              OCCTShapeRef    selection,
                              OCCTShapeRef    context);

/// Resolve a previously selected shape after modifications.
/// Uses TNaming_Selector::Solve to update the selection.
/// Returns the resolved shape, or NULL on failure.
OCCTShapeRef OCCTDocumentNamingResolve(OCCTDocumentRef doc, int64_t labelId);

/// Get the evolution type of the NamedShape attribute on a label.
/// Returns -1 if no NamedShape exists on the label.
int32_t OCCTDocumentNamingGetEvolution(OCCTDocumentRef doc, int64_t labelId);

// MARK: - Document Length Unit (v0.30.0)

/// Get the length unit information from an XDE document.
/// @param doc The document to query
/// @param unitScale Output: the scale factor relative to mm (e.g. 1.0 for mm, 10.0 for cm)
/// @param unitName Output: buffer for unit name string
/// @param maxNameLen Maximum length of the unitName buffer
/// @return true if length unit information was found
bool OCCTDocumentGetLengthUnit(OCCTDocumentRef doc,
                               double*         unitScale,
                               char*           unitName,
                               int32_t         maxNameLen);

// MARK: - Document Layers (v0.31.0)

/// Get the number of layers in a document.
/// @param doc The document to query
/// @return Number of layers, or 0 on failure
int32_t OCCTDocumentGetLayerCount(OCCTDocumentRef doc);

/// Get the name of a layer by index.
/// @param doc The document to query
/// @param index Zero-based layer index
/// @param outName Output buffer for the layer name (may be NULL if maxLen is 0)
/// @param maxLen Maximum length of the output buffer (use 0 with NULL outName to query length)
/// @return Length of the layer name in bytes (not counting the NUL terminator), or -1 on failure.
///         If outName is non-NULL and maxLen > 0, the buffer receives a NUL-terminated copy
///         truncated to maxLen-1 bytes. A return value >= maxLen indicates truncation occurred.
int32_t OCCTDocumentGetLayerName(OCCTDocumentRef doc,
                                 int32_t         index,
                                 char* _Nullable outName,
                                 int32_t maxLen);

// MARK: - Document Materials (v0.31.0)

/// Material info structure returned by OCCTDocumentGetMaterialInfo.
typedef struct
{
  char   name[128];
  char   description[256];
  double density;
} OCCTMaterialInfo;

/// Get the number of materials in a document.
/// @param doc The document to query
/// @return Number of materials, or 0 on failure
int32_t OCCTDocumentGetMaterialCount(OCCTDocumentRef doc);

/// Get material information by index.
/// @param doc The document to query
/// @param index Zero-based material index
/// @param outInfo Output material info structure
/// @return true if the material info was retrieved successfully
bool OCCTDocumentGetMaterialInfo(OCCTDocumentRef doc, int32_t index, OCCTMaterialInfo* outInfo);

// MARK: - TDF Label Properties (v0.54.0)

/// Get the tag of a label.
/// @return Tag integer, or -1 if label is invalid
int32_t OCCTDocumentLabelTag(OCCTDocumentRef doc, int64_t labelId);

/// Get the depth of a label in the tree.
/// @return Depth (root=0, main=1, etc.), or -1 if invalid
int32_t OCCTDocumentLabelDepth(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label is null.
bool OCCTDocumentLabelIsNull(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label is the root label (0:).
bool OCCTDocumentLabelIsRoot(OCCTDocumentRef doc, int64_t labelId);

/// Get the father (parent) label of a label.
/// @return Parent labelId, or -1 if root or invalid
int64_t OCCTDocumentLabelFather(OCCTDocumentRef doc, int64_t labelId);

/// Get the root label of a label's data framework.
/// @return Root labelId
int64_t OCCTDocumentLabelRoot(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label has any attributes.
bool OCCTDocumentLabelHasAttribute(OCCTDocumentRef doc, int64_t labelId);

/// Get the number of attributes on a label.
int32_t OCCTDocumentLabelNbAttributes(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label has any child labels.
bool OCCTDocumentLabelHasChild(OCCTDocumentRef doc, int64_t labelId);

/// Get the number of direct child labels.
int32_t OCCTDocumentLabelNbChildren(OCCTDocumentRef doc, int64_t labelId);

/// Find or create a child label by tag.
/// @param tag The tag to find
/// @param create If true, create the child if it doesn't exist
/// @return Child labelId, or -1 if not found and create is false
int64_t OCCTDocumentLabelFindChild(OCCTDocumentRef doc, int64_t labelId, int32_t tag, bool create);

/// Remove all attributes from a label.
/// @param clearChildren If true, also clears attributes from child labels
void OCCTDocumentLabelForgetAllAttributes(OCCTDocumentRef doc, int64_t labelId, bool clearChildren);

/// Get all descendant labels using TDF_ChildIterator.
/// @param allLevels If true, iterate all descendants; if false, direct children only
/// @param outLabelIds Output array of labelIds
/// @param maxCount Maximum number of labels to return
/// @return Number of labels found
int32_t OCCTDocumentGetDescendantLabels(OCCTDocumentRef doc,
                                        int64_t         labelId,
                                        bool            allLevels,
                                        int64_t*        outLabelIds,
                                        int32_t         maxCount);

// MARK: - TDF Label Name (v0.54.0)

/// Set the name (TDataStd_Name) on a label.
/// @param name The name string to set
/// @return true on success
bool OCCTDocumentSetLabelName(OCCTDocumentRef doc, int64_t labelId, const char* name);

// MARK: - TDF Reference (v0.54.0)

/// Set a TDF_Reference attribute on a label, pointing to another label.
/// @param labelId The label to set the reference on
/// @param targetLabelId The label being referenced
/// @return true on success
bool OCCTDocumentLabelSetReference(OCCTDocumentRef doc, int64_t labelId, int64_t targetLabelId);

/// Get the referenced label from a TDF_Reference attribute.
/// @return Referenced labelId, or -1 if no reference attribute
int64_t OCCTDocumentLabelGetReference(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDF CopyLabel (v0.54.0)

/// Copy a label and its attributes to a destination label.
/// @param sourceLabelId Source label to copy from
/// @param destLabelId Destination label to copy to
/// @return true if copy succeeded
bool OCCTDocumentCopyLabel(OCCTDocumentRef doc, int64_t sourceLabelId, int64_t destLabelId);

// MARK: - Document Main Label (v0.54.0)

/// Get the main label (0:1) of the document.
/// @return Main labelId
int64_t OCCTDocumentGetMainLabel(OCCTDocumentRef doc);

// MARK: - Document Transactions (v0.54.0)

/// Open a new transaction (command) on the document.
void OCCTDocumentOpenTransaction(OCCTDocumentRef doc);

/// Commit the current transaction.
/// @return true if committed successfully
bool OCCTDocumentCommitTransaction(OCCTDocumentRef doc);

/// Abort the current transaction, undoing all changes since OpenTransaction.
void OCCTDocumentAbortTransaction(OCCTDocumentRef doc);

/// Check if a transaction is currently open.
bool OCCTDocumentHasOpenTransaction(OCCTDocumentRef doc);

// MARK: - Document Undo/Redo (v0.54.0)

/// Set the maximum number of undo steps.
void OCCTDocumentSetUndoLimit(OCCTDocumentRef doc, int32_t limit);

/// Get the maximum number of undo steps.
int32_t OCCTDocumentGetUndoLimit(OCCTDocumentRef doc);

/// Perform undo.
/// @return true if undo was performed
bool OCCTDocumentUndo(OCCTDocumentRef doc);

/// Perform redo.
/// @return true if redo was performed
bool OCCTDocumentRedo(OCCTDocumentRef doc);

/// Get the number of available undo steps.
int32_t OCCTDocumentGetAvailableUndos(OCCTDocumentRef doc);

/// Get the number of available redo steps.
int32_t OCCTDocumentGetAvailableRedos(OCCTDocumentRef doc);

// MARK: - Document Modified Labels (v0.54.0)

/// Mark a label as modified.
void OCCTDocumentSetModified(OCCTDocumentRef doc, int64_t labelId);

/// Clear all modification marks.
void OCCTDocumentClearModified(OCCTDocumentRef doc);

/// Check if a label is marked as modified (via the TDocStd_Modified attribute on the root label).
bool OCCTDocumentIsLabelModified(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataStd Scalar Attributes (v0.55.0)

/// Set an integer attribute (TDataStd_Integer) on a label.
bool OCCTDocumentSetIntegerAttr(OCCTDocumentRef doc, int64_t labelId, int32_t value);

/// Get the integer attribute from a label.
bool OCCTDocumentGetIntegerAttr(OCCTDocumentRef doc, int64_t labelId, int32_t* outValue);

/// Set a real attribute (TDataStd_Real) on a label.
bool OCCTDocumentSetRealAttr(OCCTDocumentRef doc, int64_t labelId, double value);

/// Get the real attribute from a label.
bool OCCTDocumentGetRealAttr(OCCTDocumentRef doc, int64_t labelId, double* outValue);

/// Set an ASCII string attribute (TDataStd_AsciiString) on a label.
bool OCCTDocumentSetAsciiStringAttr(OCCTDocumentRef doc, int64_t labelId, const char* value);

/// Get the ASCII string attribute from a label. Caller must free with OCCTStringFree.
const char* OCCTDocumentGetAsciiStringAttr(OCCTDocumentRef doc, int64_t labelId);

/// Set a comment attribute (TDataStd_Comment) on a label.
bool OCCTDocumentSetCommentAttr(OCCTDocumentRef doc, int64_t labelId, const char* value);

/// Get the comment attribute from a label. Caller must free with OCCTStringFree.
const char* OCCTDocumentGetCommentAttr(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataStd Integer Array (v0.55.0)

/// Initialize an integer array attribute on a label.
bool OCCTDocumentInitIntegerArray(OCCTDocumentRef doc,
                                  int64_t         labelId,
                                  int32_t         lower,
                                  int32_t         upper);

/// Set a value in an integer array attribute.
bool OCCTDocumentSetIntegerArrayValue(OCCTDocumentRef doc,
                                      int64_t         labelId,
                                      int32_t         index,
                                      int32_t         value);

/// Get a value from an integer array attribute.
bool OCCTDocumentGetIntegerArrayValue(OCCTDocumentRef doc,
                                      int64_t         labelId,
                                      int32_t         index,
                                      int32_t*        outValue);

/// Get the bounds of an integer array attribute.
bool OCCTDocumentGetIntegerArrayBounds(OCCTDocumentRef doc,
                                       int64_t         labelId,
                                       int32_t*        outLower,
                                       int32_t*        outUpper);

// MARK: - TDataStd Real Array (v0.55.0)

/// Initialize a real array attribute on a label.
bool OCCTDocumentInitRealArray(OCCTDocumentRef doc, int64_t labelId, int32_t lower, int32_t upper);

/// Set a value in a real array attribute.
bool OCCTDocumentSetRealArrayValue(OCCTDocumentRef doc,
                                   int64_t         labelId,
                                   int32_t         index,
                                   double          value);

/// Get a value from a real array attribute.
bool OCCTDocumentGetRealArrayValue(OCCTDocumentRef doc,
                                   int64_t         labelId,
                                   int32_t         index,
                                   double*         outValue);

/// Get the bounds of a real array attribute.
bool OCCTDocumentGetRealArrayBounds(OCCTDocumentRef doc,
                                    int64_t         labelId,
                                    int32_t*        outLower,
                                    int32_t*        outUpper);

// MARK: - TDataStd TreeNode (v0.55.0)

/// Set a tree node attribute (TDataStd_TreeNode) on a label.
bool OCCTDocumentSetTreeNode(OCCTDocumentRef doc, int64_t labelId);

/// Append a child tree node under a parent tree node.
bool OCCTDocumentAppendTreeChild(OCCTDocumentRef doc, int64_t parentLabelId, int64_t childLabelId);

/// Get the father (parent) of a tree node.
int64_t OCCTDocumentTreeNodeFather(OCCTDocumentRef doc, int64_t labelId);

/// Get the first child of a tree node.
int64_t OCCTDocumentTreeNodeFirst(OCCTDocumentRef doc, int64_t labelId);

/// Get the next sibling of a tree node.
int64_t OCCTDocumentTreeNodeNext(OCCTDocumentRef doc, int64_t labelId);

/// Check if a tree node has a father.
bool OCCTDocumentTreeNodeHasFather(OCCTDocumentRef doc, int64_t labelId);

/// Get the depth of a tree node (root=0).
int32_t OCCTDocumentTreeNodeDepth(OCCTDocumentRef doc, int64_t labelId);

/// Get the number of children of a tree node.
int32_t OCCTDocumentTreeNodeNbChildren(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataStd NamedData (v0.55.0)

/// Set an integer value in a NamedData attribute.
bool OCCTDocumentNamedDataSetInteger(OCCTDocumentRef doc,
                                     int64_t         labelId,
                                     const char*     name,
                                     int32_t         value);

/// Get an integer value from a NamedData attribute.
bool OCCTDocumentNamedDataGetInteger(OCCTDocumentRef doc,
                                     int64_t         labelId,
                                     const char*     name,
                                     int32_t*        outValue);

/// Check if a named integer exists in a NamedData attribute.
bool OCCTDocumentNamedDataHasInteger(OCCTDocumentRef doc, int64_t labelId, const char* name);

/// Set a real value in a NamedData attribute.
bool OCCTDocumentNamedDataSetReal(OCCTDocumentRef doc,
                                  int64_t         labelId,
                                  const char*     name,
                                  double          value);

/// Get a real value from a NamedData attribute.
bool OCCTDocumentNamedDataGetReal(OCCTDocumentRef doc,
                                  int64_t         labelId,
                                  const char*     name,
                                  double*         outValue);

/// Check if a named real exists in a NamedData attribute.
bool OCCTDocumentNamedDataHasReal(OCCTDocumentRef doc, int64_t labelId, const char* name);

/// Set a string value in a NamedData attribute.
bool OCCTDocumentNamedDataSetString(OCCTDocumentRef doc,
                                    int64_t         labelId,
                                    const char*     name,
                                    const char*     value);

/// Get a string value from a NamedData attribute. Caller must free with OCCTStringFree.
const char* OCCTDocumentNamedDataGetString(OCCTDocumentRef doc, int64_t labelId, const char* name);

/// Check if a named string exists in a NamedData attribute.
bool OCCTDocumentNamedDataHasString(OCCTDocumentRef doc, int64_t labelId, const char* name);

// MARK: - TDataXtd Shape Attribute (v0.56.0)

/// Set a shape attribute on a label (stores shape via TNaming).
bool OCCTDocumentSetShapeAttr(OCCTDocumentRef doc, int64_t labelId, OCCTShapeRef shape);

/// Get the shape stored in a TDataXtd_Shape attribute on a label.
OCCTShapeRef OCCTDocumentGetShapeAttr(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label has a TDataXtd_Shape attribute.
bool OCCTDocumentHasShapeAttr(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataXtd Position Attribute (v0.56.0)

/// Set a position (3D point) attribute on a label.
bool OCCTDocumentSetPositionAttr(OCCTDocumentRef doc,
                                 int64_t         labelId,
                                 double          x,
                                 double          y,
                                 double          z);

/// Get the position attribute from a label.
bool OCCTDocumentGetPositionAttr(OCCTDocumentRef doc,
                                 int64_t         labelId,
                                 double*         outX,
                                 double*         outY,
                                 double*         outZ);

/// Check if a label has a TDataXtd_Position attribute.
bool OCCTDocumentHasPositionAttr(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataXtd Geometry Attribute (v0.56.0)

/// Set a geometry type attribute on a label. Type values:
/// 0=ANY_GEOM, 1=POINT, 2=LINE, 3=CIRCLE, 4=ELLIPSE, 5=SPLINE, 6=PLANE, 7=CYLINDER
bool OCCTDocumentSetGeometryAttr(OCCTDocumentRef doc, int64_t labelId, int32_t geometryType);

/// Get the geometry type from a label. Returns -1 if not found.
int32_t OCCTDocumentGetGeometryType(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label has a TDataXtd_Geometry attribute.
bool OCCTDocumentHasGeometryAttr(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TDataXtd Triangulation Attribute (v0.56.0)

/// Set a triangulation attribute on a label by meshing a shape. Stores EVERY face's
/// triangulation merged into one Poly_Triangulation, not just the first face's (#443).
/// Returns false if the shape has no face, or if nothing in it meshed.
bool OCCTDocumentSetTriangulationFromShape(OCCTDocumentRef doc,
                                           int64_t         labelId,
                                           OCCTShapeRef    shape,
                                           double          deflection);

/// Get the number of nodes in a triangulation attribute.
int32_t OCCTDocumentTriangulationNbNodes(OCCTDocumentRef doc, int64_t labelId);

/// Get the number of triangles in a triangulation attribute.
int32_t OCCTDocumentTriangulationNbTriangles(OCCTDocumentRef doc, int64_t labelId);

/// Get the deflection of a triangulation attribute.
double OCCTDocumentTriangulationDeflection(OCCTDocumentRef doc, int64_t labelId);

/// Read one node of a triangulation attribute, in the coordinate frame it was stored in.
/// @param index 1-based node index, as Poly_Triangulation numbers them.
/// @param outXYZ receives x, y, z. Untouched when the call returns false.
/// @return false if the label has no triangulation attribute or the index is out of range.
bool OCCTDocumentTriangulationNode(OCCTDocumentRef doc,
                                   int64_t         labelId,
                                   int32_t         index,
                                   double*         outXYZ);

/// Read one node normal of a triangulation attribute, in the frame it was stored in.
/// Node normals exist only when the meshed faces carried them; BRepMesh_IncrementalMesh does
/// not produce any, so this is false for anything meshed from B-Rep and true for e.g. an
/// imported glTF mesh.
/// @param index 1-based node index.
/// @param outXYZ receives the normal. Untouched when the call returns false.
/// @return false if there is no attribute, no node normals, or the index is out of range.
bool OCCTDocumentTriangulationNormal(OCCTDocumentRef doc,
                                     int64_t         labelId,
                                     int32_t         index,
                                     double*         outXYZ);

// MARK: - TDataXtd Point/Axis/Plane Attributes (v0.56.0)

/// Set a point attribute on a label.
bool OCCTDocumentSetPointAttr(OCCTDocumentRef doc, int64_t labelId, double x, double y, double z);

/// Set an axis attribute on a label (origin + direction).
bool OCCTDocumentSetAxisAttr(OCCTDocumentRef doc,
                             int64_t         labelId,
                             double          ox,
                             double          oy,
                             double          oz,
                             double          dx,
                             double          dy,
                             double          dz);

/// Set a plane attribute on a label (origin + normal).
bool OCCTDocumentSetPlaneAttr(OCCTDocumentRef doc,
                              int64_t         labelId,
                              double          ox,
                              double          oy,
                              double          oz,
                              double          nx,
                              double          ny,
                              double          nz);

// MARK: - TFunction Logbook (v0.56.0)

/// Create a TFunction_Logbook attribute on a label.
bool OCCTDocumentSetLogbook(OCCTDocumentRef doc, int64_t labelId);

/// Mark a label as touched in the logbook.
bool OCCTDocumentLogbookSetTouched(OCCTDocumentRef doc,
                                   int64_t         logbookLabelId,
                                   int64_t         targetLabelId);

/// Mark a label as impacted in the logbook.
bool OCCTDocumentLogbookSetImpacted(OCCTDocumentRef doc,
                                    int64_t         logbookLabelId,
                                    int64_t         targetLabelId);

/// Check if a label is modified (touched) in the logbook.
bool OCCTDocumentLogbookIsModified(OCCTDocumentRef doc,
                                   int64_t         logbookLabelId,
                                   int64_t         targetLabelId);

/// Clear the logbook.
bool OCCTDocumentLogbookClear(OCCTDocumentRef doc, int64_t logbookLabelId);

/// Check if the logbook is empty.
bool OCCTDocumentLogbookIsEmpty(OCCTDocumentRef doc, int64_t logbookLabelId);

// MARK: - TFunction GraphNode (v0.56.0)

/// Create a TFunction_GraphNode attribute on a label.
bool OCCTDocumentSetGraphNode(OCCTDocumentRef doc, int64_t labelId);

/// Add a previous dependency to a graph node (by tag ID).
bool OCCTDocumentGraphNodeAddPrevious(OCCTDocumentRef doc, int64_t labelId, int32_t prevTag);

/// Add a next dependency to a graph node (by tag ID).
bool OCCTDocumentGraphNodeAddNext(OCCTDocumentRef doc, int64_t labelId, int32_t nextTag);

/// Set the execution status of a graph node.
/// 0=WrongDefinition, 1=NotExecuted, 2=Executing, 3=Succeeded, 4=Failed
bool OCCTDocumentGraphNodeSetStatus(OCCTDocumentRef doc, int64_t labelId, int32_t status);

/// Get the execution status of a graph node. Returns -1 if not found.
int32_t OCCTDocumentGraphNodeGetStatus(OCCTDocumentRef doc, int64_t labelId);

/// Remove all previous dependencies from a graph node.
bool OCCTDocumentGraphNodeRemoveAllPrevious(OCCTDocumentRef doc, int64_t labelId);

/// Remove all next dependencies from a graph node.
bool OCCTDocumentGraphNodeRemoveAllNext(OCCTDocumentRef doc, int64_t labelId);

// MARK: - TFunction Function Attribute (v0.56.0)

/// Create a TFunction_Function attribute on a label.
bool OCCTDocumentSetFunctionAttr(OCCTDocumentRef doc, int64_t labelId);

/// Check if a function attribute has failed.
bool OCCTDocumentFunctionIsFailed(OCCTDocumentRef doc, int64_t labelId);

/// Get the failure mode of a function attribute. Returns -1 if not found.
int32_t OCCTDocumentFunctionGetFailure(OCCTDocumentRef doc, int64_t labelId);

/// Set the failure mode of a function attribute.
bool OCCTDocumentFunctionSetFailure(OCCTDocumentRef doc, int64_t labelId, int32_t mode);

// MARK: - TNaming CopyShape (v0.56.0)

/// Deep copy a shape (creates independent copy with new topology).
OCCTShapeRef OCCTShapeDeepCopy(OCCTShapeRef shape);

// MARK: - OCAF Persistence, Format Registration (v0.57.0)

/// Register binary OCAF format drivers (BinOcaf).
void OCCTDocumentDefineFormatBin(OCCTDocumentRef doc);

/// Register lite binary OCAF format drivers (BinLOcaf).
void OCCTDocumentDefineFormatBinL(OCCTDocumentRef doc);

/// Register XML OCAF format drivers (XmlOcaf).
void OCCTDocumentDefineFormatXml(OCCTDocumentRef doc);

/// Register lite XML OCAF format drivers (XmlLOcaf).
void OCCTDocumentDefineFormatXmlL(OCCTDocumentRef doc);

/// Register binary XCAF format drivers (BinXCAF).
void OCCTDocumentDefineFormatBinXCAF(OCCTDocumentRef doc);

/// Register XML XCAF format drivers (XmlXCAF).
void OCCTDocumentDefineFormatXmlXCAF(OCCTDocumentRef doc);

// MARK: - OCAF Persistence, Save/Load (v0.57.0)

/// Save OCAF document to file. Returns PCDM_StoreStatus (0=OK).
/// Format is determined by the document's storage format.
int32_t OCCTDocumentSaveOCAF(OCCTDocumentRef doc, const char* path);

/// Load OCAF document from file. Returns a new document ref, or NULL on failure.
/// The outStatus receives PCDM_ReaderStatus (0=OK).
OCCTDocumentRef OCCTDocumentLoadOCAF(const char* path, int32_t* outStatus);

/// Save current OCAF document in-place (to previously saved path).
/// Returns PCDM_StoreStatus (0=OK), or -1 if not previously saved.
int32_t OCCTDocumentSaveOCAFInPlace(OCCTDocumentRef doc);

// MARK: - OCAF Document Metadata (v0.57.0)

/// Check if the document has been saved.
bool OCCTDocumentIsSaved(OCCTDocumentRef doc);

/// Get the storage format of the document. Caller must free with OCCTStringFree.
const char* OCCTDocumentGetStorageFormat(OCCTDocumentRef doc);

/// Change the storage format of the document.
bool OCCTDocumentSetStorageFormat(OCCTDocumentRef doc, const char* format);

/// Get the number of documents in the application.
int32_t OCCTDocumentNbDocuments(OCCTDocumentRef doc);

/// Get the list of available reading formats. Returns count.
/// Each format string is written to outFormats (up to maxFormats). Caller must free strings with
/// OCCTStringFree.
int32_t OCCTDocumentReadingFormats(OCCTDocumentRef doc,
                                   const char**    outFormats,
                                   int32_t         maxFormats);

/// Get the list of available writing formats. Returns count.
int32_t OCCTDocumentWritingFormats(OCCTDocumentRef doc,
                                   const char**    outFormats,
                                   int32_t         maxFormats);

/// Create a new OCAF document with a specific format. Returns a new document ref.
/// Supported formats: "BinOcaf", "XmlOcaf", "BinLOcaf", "XmlLOcaf", "BinXCAF", "XmlXCAF".
OCCTDocumentRef OCCTDocumentCreateWithFormat(const char* format);

// MARK: - XDE ShapeTool Expansion (v0.60.0)

/// Get total number of shapes in the document (all levels).
int32_t OCCTDocumentGetShapeCount(OCCTDocumentRef doc);

/// Get label ID for a shape at index (from GetShapes sequence).
int64_t OCCTDocumentGetShapeLabelId(OCCTDocumentRef doc, int32_t index);

/// Get total number of free (top-level) shapes.
int32_t OCCTDocumentGetFreeShapeCount(OCCTDocumentRef doc);

/// Get label ID for a free shape at index.
int64_t OCCTDocumentGetFreeShapeLabelId(OCCTDocumentRef doc, int32_t index);

/// Check if a label is top-level.
bool OCCTDocumentIsTopLevel(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label is a component (instance inside an assembly).
bool OCCTDocumentIsComponent(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label represents a compound shape.
bool OCCTDocumentIsCompound(OCCTDocumentRef doc, int64_t labelId);

/// Check if a label represents a sub-shape of a top-level shape.
bool OCCTDocumentIsSubShape(OCCTDocumentRef doc, int64_t labelId);

/// Find label ID for a given shape in the document.
/// @return Label ID, or -1 if not found
int64_t OCCTDocumentFindShape(OCCTDocumentRef doc, OCCTShapeRef shape);

/// Search for a shape in the document (including sub-shapes).
/// @return Label ID, or -1 if not found
int64_t OCCTDocumentSearchShape(OCCTDocumentRef doc, OCCTShapeRef shape);

/// Get number of sub-shapes for a label.
int32_t OCCTDocumentGetSubShapeCount(OCCTDocumentRef doc, int64_t labelId);

/// Get sub-shape label ID at index.
int64_t OCCTDocumentGetSubShapeLabelId(OCCTDocumentRef doc, int64_t labelId, int32_t index);

/// Add a shape to the document.
/// @param makeAssembly If true, compound shapes become assemblies
/// @return Label ID of the added shape
int64_t OCCTDocumentAddShape(OCCTDocumentRef doc, OCCTShapeRef shape, bool makeAssembly);

/// Create a new empty shape label.
int64_t OCCTDocumentNewShape(OCCTDocumentRef doc);

/// Remove a shape from the document.
bool OCCTDocumentRemoveShape(OCCTDocumentRef doc, int64_t labelId);

/// Add a component to an assembly with transform.
/// @param assemblyLabelId Assembly to add to
/// @param shapeLabelId Shape to add as component
/// @param tx, ty, tz Translation
/// @return Label ID of the new component, or -1 on failure
int64_t OCCTDocumentAddComponent(OCCTDocumentRef doc,
                                 int64_t         assemblyLabelId,
                                 int64_t         shapeLabelId,
                                 double          tx,
                                 double          ty,
                                 double          tz);

// Add a component with a FULL rigid placement from a 12-element row-major matrix
// [r00 r01 r02 r10 r11 r12 r20 r21 r22 tx ty tz]. Returns -1 if the matrix is not a proper rigid
// transform (e.g. a reflection: gp_Trsf can't represent it; the caller should bake a mirrored
// product instead). Issue #174.
int64_t OCCTDocumentAddComponentMatrix(OCCTDocumentRef doc,
                                       int64_t         assemblyLabelId,
                                       int64_t         shapeLabelId,
                                       const double* _Nonnull matrix12);

/// Remove a component from an assembly.
void OCCTDocumentRemoveComponent(OCCTDocumentRef doc, int64_t componentLabelId);

/// Get number of components in an assembly.
int32_t OCCTDocumentGetComponentCount(OCCTDocumentRef doc, int64_t assemblyLabelId);

/// Get component label ID at index.
int64_t OCCTDocumentGetComponentLabelId(OCCTDocumentRef doc,
                                        int64_t         assemblyLabelId,
                                        int32_t         index);

/// Get the referred (original) shape label for a component.
/// @return Referred label ID, or -1 if not a reference
int64_t OCCTDocumentGetComponentReferredLabelId(OCCTDocumentRef doc, int64_t componentLabelId);

/// Get number of labels that use (reference) a given shape.
int32_t OCCTDocumentGetShapeUserCount(OCCTDocumentRef doc, int64_t shapeLabelId);

/// Update all assemblies (recompute compounds from components).
void OCCTDocumentUpdateAssemblies(OCCTDocumentRef doc);

/// Expand a compound shape into an assembly (ShapeTool::Expand).
bool OCCTDocumentExpandShape(OCCTDocumentRef doc, int64_t labelId);

// MARK: - XDE ColorTool by Shape (v0.60.0)

/// Set color on a shape (not by label).
/// @param colorType 0=generic, 1=surface, 2=curve
void OCCTDocumentSetShapeColor(OCCTDocumentRef doc,
                               OCCTShapeRef    shape,
                               int32_t         colorType,
                               double          r,
                               double          g,
                               double          b);

/// Set RGBA color on a shape (not by label), preserving alpha (#763).
/// `OCCTDocumentSetShapeColor` above stores through the RGB-only
/// `XCAFDoc_ColorTool::SetColor` overload, so alpha is unrecoverable afterwards; this uses the
/// RGBA overload so a subsequent `OCCTDocumentGetShapeColor` reports the real value.
/// @param colorType 0=generic, 1=surface, 2=curve
void OCCTDocumentSetShapeColorRGBA(OCCTDocumentRef doc,
                                   OCCTShapeRef    shape,
                                   int32_t         colorType,
                                   double          r,
                                   double          g,
                                   double          b,
                                   float           alpha);

/// Get color for a shape (not by label).
/// @return OCCTColor with isSet=true if color was found. `a` is the color's real alpha (#763):
///   1.0 for a color stored via the RGB-only `SetColor` overload, and the stored value otherwise
///   (e.g. a STEP import with a transparent surface style, or `OCCTDocumentSetShapeColorRGBA`).
OCCTColor OCCTDocumentGetShapeColor(OCCTDocumentRef doc, OCCTShapeRef shape, int32_t colorType);

/// Check if color is set on a shape.
bool OCCTDocumentIsShapeColorSet(OCCTDocumentRef doc, OCCTShapeRef shape, int32_t colorType);

/// Set visibility for a label.
void OCCTDocumentSetLabelVisibility(OCCTDocumentRef doc, int64_t labelId, bool visible);

/// Get visibility for a label.
bool OCCTDocumentGetLabelVisibility(OCCTDocumentRef doc, int64_t labelId);

// MARK: - XDE Area / Volume / Centroid (v0.60.0)

/// Set area attribute on a label.
void OCCTDocumentSetArea(OCCTDocumentRef doc, int64_t labelId, double area);

/// Get area attribute from a label. Returns -1 if not set.
double OCCTDocumentGetArea(OCCTDocumentRef doc, int64_t labelId);

/// Set volume attribute on a label.
void OCCTDocumentSetVolume(OCCTDocumentRef doc, int64_t labelId, double volume);

/// Get volume attribute from a label. Returns -1 if not set.
double OCCTDocumentGetVolume(OCCTDocumentRef doc, int64_t labelId);

/// Set centroid attribute on a label.
void OCCTDocumentSetCentroid(OCCTDocumentRef doc, int64_t labelId, double x, double y, double z);

/// Get centroid attribute from a label. Returns false if not set.
bool OCCTDocumentGetCentroid(OCCTDocumentRef doc,
                             int64_t         labelId,
                             double*         outX,
                             double*         outY,
                             double*         outZ);

// MARK: - XDE LayerTool Expansion (v0.60.0)

/// Set a named layer on a label.
void OCCTDocumentSetLayer(OCCTDocumentRef doc, int64_t labelId, const char* layerName);

/// Check if a specific layer is set on a label.
bool OCCTDocumentIsLayerSet(OCCTDocumentRef doc, int64_t labelId, const char* layerName);

/// Get layers on a label. Returns count. Fills outNames (caller-allocated array of buffers).
/// Each buffer must be at least maxLen chars.
int32_t OCCTDocumentGetLabelLayers(OCCTDocumentRef doc,
                                   int64_t         labelId,
                                   char**          outNames,
                                   int32_t         maxNames,
                                   int32_t         maxLen);

/// Find a layer label by name. Returns label ID or -1 if not found.
int64_t OCCTDocumentFindLayer(OCCTDocumentRef doc, const char* layerName);

/// Set visibility for a layer label.
void OCCTDocumentSetLayerVisibility(OCCTDocumentRef doc, int64_t layerLabelId, bool visible);

/// Get visibility for a layer label.
bool OCCTDocumentGetLayerVisibility(OCCTDocumentRef doc, int64_t layerLabelId);

// MARK: - XDE Editor (v0.60.0)

/// Expand a compound shape label into an assembly using XCAFDoc_Editor::Expand.
/// @param recursively If true, expand recursively
/// @return true if expanded successfully
bool OCCTDocumentEditorExpand(OCCTDocumentRef doc, int64_t labelId, bool recursively);

/// Rescale geometry on a label.
/// @param labelId Label to rescale
/// @param scaleFactor Scale factor
/// @param forceIfNotRoot Force rescale even if label is not root
/// @return true on success
bool OCCTDocumentEditorRescaleGeometry(OCCTDocumentRef doc,
                                       int64_t         labelId,
                                       double          scaleFactor,
                                       bool            forceIfNotRoot);

// MARK: - v0.83.0: XDE Attributes: Location, GraphNode, Color, Material, Notes, Views, Styles

// --- XCAFDoc_Location ---

/// Set a TopLoc_Location (translation) on a label
bool OCCTDocumentSetLocation(OCCTDocumentRef doc, int64_t labelId, double tx, double ty, double tz);

/// Get the TopLoc_Location translation from a label
bool OCCTDocumentGetLocationTranslation(OCCTDocumentRef doc,
                                        int64_t         labelId,
                                        double* _Nonnull outX,
                                        double* _Nonnull outY,
                                        double* _Nonnull outZ);

/// Check if a label has an XCAFDoc_Location attribute
bool OCCTDocumentHasLocation(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_GraphNode ---

/// Set an XCAFDoc_GraphNode attribute on a label (creates or retrieves it)
bool OCCTDocumentSetGraphNodeAttr(OCCTDocumentRef doc, int64_t labelId);

/// Set a child relationship: parent's graph node gets child's graph node
bool OCCTDocumentGraphNodeSetChild(OCCTDocumentRef doc,
                                   int64_t         parentLabelId,
                                   int64_t         childLabelId);

/// Set a father relationship: child's graph node gets parent's graph node
bool OCCTDocumentGraphNodeSetFather(OCCTDocumentRef doc,
                                    int64_t         childLabelId,
                                    int64_t         parentLabelId);

/// Unset a child relationship
bool OCCTDocumentGraphNodeUnSetChild(OCCTDocumentRef doc,
                                     int64_t         parentLabelId,
                                     int64_t         childLabelId);

/// Unset a father relationship
bool OCCTDocumentGraphNodeUnSetFather(OCCTDocumentRef doc,
                                      int64_t         childLabelId,
                                      int64_t         parentLabelId);

/// Get number of children of a graph node
int32_t OCCTDocumentGraphNodeNbChildren(OCCTDocumentRef doc, int64_t labelId);

/// Get number of fathers of a graph node
int32_t OCCTDocumentGraphNodeNbFathers(OCCTDocumentRef doc, int64_t labelId);

/// Check if node is father of another
bool OCCTDocumentGraphNodeIsFather(OCCTDocumentRef doc, int64_t labelId, int64_t otherLabelId);

/// Check if node is child of another
bool OCCTDocumentGraphNodeIsChild(OCCTDocumentRef doc, int64_t labelId, int64_t otherLabelId);

// --- XCAFDoc_Color ---

/// Set color attribute from RGB on a label
bool OCCTDocumentSetColorAttr(OCCTDocumentRef doc, int64_t labelId, double r, double g, double b);

/// Set color attribute from RGBA on a label
bool OCCTDocumentSetColorRGBAAttr(OCCTDocumentRef doc,
                                  int64_t         labelId,
                                  double          r,
                                  double          g,
                                  double          b,
                                  float           alpha);

/// Set color attribute from named color on a label
bool OCCTDocumentSetColorNOCAttr(OCCTDocumentRef doc, int64_t labelId, int32_t noc);

/// Get color from XCAFDoc_Color attribute on a label
bool OCCTDocumentGetColorAttr(OCCTDocumentRef doc,
                              int64_t         labelId,
                              double* _Nonnull outR,
                              double* _Nonnull outG,
                              double* _Nonnull outB);

/// Get RGBA from XCAFDoc_Color attribute on a label
bool OCCTDocumentGetColorRGBAAttr(OCCTDocumentRef doc,
                                  int64_t         labelId,
                                  double* _Nonnull outR,
                                  double* _Nonnull outG,
                                  double* _Nonnull outB,
                                  float* _Nonnull outAlpha);

/// Get alpha from XCAFDoc_Color attribute
float OCCTDocumentGetColorAlphaAttr(OCCTDocumentRef doc, int64_t labelId);

/// Get named color from XCAFDoc_Color attribute
int32_t OCCTDocumentGetColorNOCAttr(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_Material ---

/// Set material attribute on a label
bool OCCTDocumentSetMaterialAttr(OCCTDocumentRef doc,
                                 int64_t         labelId,
                                 const char* _Nonnull name,
                                 const char* _Nonnull description,
                                 double density,
                                 const char* _Nonnull densName,
                                 const char* _Nonnull densValType);

/// Get material name from attribute. Caller must free with OCCTStringFree.
const char* _Nullable OCCTDocumentGetMaterialAttrName(OCCTDocumentRef doc, int64_t labelId);

/// Get material description. Caller must free with OCCTStringFree.
const char* _Nullable OCCTDocumentGetMaterialAttrDescription(OCCTDocumentRef doc, int64_t labelId);

/// Get material density from attribute
bool OCCTDocumentGetMaterialAttrDensity(OCCTDocumentRef doc,
                                        int64_t         labelId,
                                        double* _Nonnull outDensity);

/// Check if label has XCAFDoc_Material attribute
bool OCCTDocumentHasMaterialAttr(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_NoteComment ---

/// Set a NoteComment attribute on a label
bool OCCTDocumentSetNoteComment(OCCTDocumentRef doc,
                                int64_t         labelId,
                                const char* _Nonnull userName,
                                const char* _Nonnull timeStamp,
                                const char* _Nonnull comment);

/// Get comment text from NoteComment. Caller must free with OCCTStringFree.
const char* _Nullable OCCTDocumentGetNoteCommentText(OCCTDocumentRef doc, int64_t labelId);

/// Get note user name. Caller must free with OCCTStringFree.
const char* _Nullable OCCTDocumentGetNoteUserName(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_NoteBalloon ---

/// Set a NoteBalloon attribute on a label
bool OCCTDocumentSetNoteBalloon(OCCTDocumentRef doc,
                                int64_t         labelId,
                                const char* _Nonnull userName,
                                const char* _Nonnull timeStamp,
                                const char* _Nonnull comment);

// --- XCAFDoc_NoteBinData ---

/// Set a NoteBinData attribute on a label (binary data from byte array)
bool OCCTDocumentSetNoteBinData(OCCTDocumentRef doc,
                                int64_t         labelId,
                                const char* _Nonnull userName,
                                const char* _Nonnull timeStamp,
                                const char* _Nonnull title,
                                const char* _Nonnull mimeType,
                                const uint8_t* _Nonnull data,
                                int32_t dataSize);

/// Get binary data size from NoteBinData
int32_t OCCTDocumentGetNoteBinDataSize(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_NotesTool ---

/// Get or create NotesTool on document, returns number of notes (≥0) or -1 on error
int32_t OCCTDocumentNotesToolNbNotes(OCCTDocumentRef doc);

/// Create a comment note via NotesTool. Returns label ID of created note.
int64_t OCCTDocumentNotesToolCreateComment(OCCTDocumentRef doc,
                                           const char* _Nonnull userName,
                                           const char* _Nonnull timeStamp,
                                           const char* _Nonnull comment);

/// Create a balloon note via NotesTool. Returns label ID of created note.
int64_t OCCTDocumentNotesToolCreateBalloon(OCCTDocumentRef doc,
                                           const char* _Nonnull userName,
                                           const char* _Nonnull timeStamp,
                                           const char* _Nonnull comment);

/// Create a binary data note via NotesTool. Returns label ID of created note.
int64_t OCCTDocumentNotesToolCreateBinData(OCCTDocumentRef doc,
                                           const char* _Nonnull userName,
                                           const char* _Nonnull timeStamp,
                                           const char* _Nonnull title,
                                           const char* _Nonnull mimeType,
                                           const uint8_t* _Nonnull data,
                                           int32_t dataSize);

/// Delete a note by label ID. Returns true on success.
bool OCCTDocumentNotesToolDeleteNote(OCCTDocumentRef doc, int64_t noteLabelId);

/// Delete all notes. Returns the number of deleted notes.
int32_t OCCTDocumentNotesToolDeleteAllNotes(OCCTDocumentRef doc);

/// Get number of orphan notes.
int32_t OCCTDocumentNotesToolNbOrphanNotes(OCCTDocumentRef doc);

/// Delete all orphan notes. Returns number of deleted notes.
int32_t OCCTDocumentNotesToolDeleteOrphanNotes(OCCTDocumentRef doc);

// --- XCAFDoc_ClippingPlaneTool ---

/// Add a clipping plane. Returns label ID of created plane or -1 on error.
int64_t OCCTDocumentClipPlaneToolAdd(OCCTDocumentRef doc,
                                     double          planeOrigX,
                                     double          planeOrigY,
                                     double          planeOrigZ,
                                     double          planeNormX,
                                     double          planeNormY,
                                     double          planeNormZ,
                                     const char* _Nonnull name,
                                     bool capping);

/// Get clipping plane from label.
bool OCCTDocumentClipPlaneToolGet(OCCTDocumentRef doc,
                                  int64_t         labelId,
                                  double* _Nonnull origX,
                                  double* _Nonnull origY,
                                  double* _Nonnull origZ,
                                  double* _Nonnull normX,
                                  double* _Nonnull normY,
                                  double* _Nonnull normZ,
                                  bool* _Nonnull capping);

/// Check if label is a clipping plane
bool OCCTDocumentClipPlaneToolIsClipPlane(OCCTDocumentRef doc, int64_t labelId);

/// Remove a clipping plane
bool OCCTDocumentClipPlaneToolRemove(OCCTDocumentRef doc, int64_t labelId);

// --- XCAFDoc_ShapeMapTool ---

/// Set ShapeMapTool attribute on a label
bool OCCTDocumentSetShapeMapTool(OCCTDocumentRef doc, int64_t labelId);

/// Set shape on ShapeMapTool
bool OCCTDocumentShapeMapToolSetShape(OCCTDocumentRef doc, int64_t labelId, OCCTShapeRef shape);

/// Check if shape is a sub-shape in the ShapeMapTool
bool OCCTDocumentShapeMapToolIsSubShape(OCCTDocumentRef doc, int64_t labelId, OCCTShapeRef shape);

/// Get the extent (number of entries) of the ShapeMapTool's map
int32_t OCCTDocumentShapeMapToolExtent(OCCTDocumentRef doc, int64_t labelId);

/// Create an assembly graph from a document
OCCTAssemblyGraphRef OCCTAssemblyGraphCreate(OCCTDocumentRef doc);

/// Release assembly graph
void OCCTAssemblyGraphRelease(OCCTAssemblyGraphRef ref);

/// Number of nodes in the assembly graph
int32_t OCCTAssemblyGraphNbNodes(OCCTAssemblyGraphRef ref);

/// Number of links in the assembly graph
int32_t OCCTAssemblyGraphNbLinks(OCCTAssemblyGraphRef ref);

/// Number of root nodes in the assembly graph
int32_t OCCTAssemblyGraphNbRoots(OCCTAssemblyGraphRef ref);

/// Get node type (0=node, 1=occurrence, 2=part, 3=instance, 4=subshape, 5=free)
int32_t OCCTAssemblyGraphGetNodeType(OCCTAssemblyGraphRef ref, int32_t nodeIndex);

// --- XCAFDoc_AssemblyItemId ---

/// Create an AssemblyItemId from string, check if valid. Returns true if valid.
bool OCCTAssemblyItemIdIsValid(const char* _Nonnull str);

/// Get path count from an AssemblyItemId string
int32_t OCCTAssemblyItemIdPathCount(const char* _Nonnull str);

/// Check equality of two AssemblyItemId strings
bool OCCTAssemblyItemIdIsEqual(const char* _Nonnull str1, const char* _Nonnull str2);

/// Create a new XCAFView_Object
OCCTViewObjectRef OCCTViewObjectCreate(void);

/// Release view object
void OCCTViewObjectRelease(OCCTViewObjectRef ref);

/// Set projection type (0=central, 1=parallel)
void OCCTViewObjectSetType(OCCTViewObjectRef ref, int32_t type);

/// Get projection type (0=central, 1=parallel)
int32_t OCCTViewObjectGetType(OCCTViewObjectRef ref);

/// Set view direction
void OCCTViewObjectSetViewDirection(OCCTViewObjectRef ref, double x, double y, double z);

/// Get view direction
void OCCTViewObjectGetViewDirection(OCCTViewObjectRef ref,
                                    double* _Nonnull x,
                                    double* _Nonnull y,
                                    double* _Nonnull z);

/// Set up direction
void OCCTViewObjectSetUpDirection(OCCTViewObjectRef ref, double x, double y, double z);

/// Get up direction
void OCCTViewObjectGetUpDirection(OCCTViewObjectRef ref,
                                  double* _Nonnull x,
                                  double* _Nonnull y,
                                  double* _Nonnull z);

/// Set window horizontal size
void OCCTViewObjectSetWindowHSize(OCCTViewObjectRef ref, double size);

/// Get window horizontal size
double OCCTViewObjectGetWindowHSize(OCCTViewObjectRef ref);

/// Set window vertical size
void OCCTViewObjectSetWindowVSize(OCCTViewObjectRef ref, double size);

/// Get window vertical size
double OCCTViewObjectGetWindowVSize(OCCTViewObjectRef ref);

/// Set front plane distance (enables front clipping)
void OCCTViewObjectSetFrontPlaneDistance(OCCTViewObjectRef ref, double dist);

/// Get front plane distance
double OCCTViewObjectGetFrontPlaneDistance(OCCTViewObjectRef ref);

/// Has front plane clipping
bool OCCTViewObjectHasFrontPlaneClipping(OCCTViewObjectRef ref);

/// Unset front plane clipping
void OCCTViewObjectUnsetFrontPlaneClipping(OCCTViewObjectRef ref);

/// Set back plane distance (enables back clipping)
void OCCTViewObjectSetBackPlaneDistance(OCCTViewObjectRef ref, double dist);

/// Get back plane distance
double OCCTViewObjectGetBackPlaneDistance(OCCTViewObjectRef ref);

/// Has back plane clipping
bool OCCTViewObjectHasBackPlaneClipping(OCCTViewObjectRef ref);

/// Unset back plane clipping
void OCCTViewObjectUnsetBackPlaneClipping(OCCTViewObjectRef ref);

/// Set name. Pass empty string for no name.
void OCCTViewObjectSetName(OCCTViewObjectRef ref, const char* _Nonnull name);

/// Get name. Caller must free with OCCTStringFree.
const char* _Nullable OCCTViewObjectGetName(OCCTViewObjectRef ref);

/// Create a new NoteObject
OCCTNoteObjectRef OCCTNoteObjectCreate(void);

/// Release note object
void OCCTNoteObjectRelease(OCCTNoteObjectRef ref);

/// Has plane
bool OCCTNoteObjectHasPlane(OCCTNoteObjectRef ref);

/// Has point
bool OCCTNoteObjectHasPoint(OCCTNoteObjectRef ref);

/// Has point text
bool OCCTNoteObjectHasPointText(OCCTNoteObjectRef ref);

/// Set plane (origin + normal)
void OCCTNoteObjectSetPlane(OCCTNoteObjectRef ref,
                            double            origX,
                            double            origY,
                            double            origZ,
                            double            normX,
                            double            normY,
                            double            normZ);

/// Get plane origin
void OCCTNoteObjectGetPlane(OCCTNoteObjectRef ref,
                            double* _Nonnull origX,
                            double* _Nonnull origY,
                            double* _Nonnull origZ);

/// Set point
void OCCTNoteObjectSetPoint(OCCTNoteObjectRef ref, double x, double y, double z);

/// Get point
void OCCTNoteObjectGetPoint(OCCTNoteObjectRef ref,
                            double* _Nonnull x,
                            double* _Nonnull y,
                            double* _Nonnull z);

/// Set presentation shape
void OCCTNoteObjectSetPresentation(OCCTNoteObjectRef ref, OCCTShapeRef shape);

/// Get presentation shape (returns null if not set)
OCCTShapeRef OCCTNoteObjectGetPresentation(OCCTNoteObjectRef ref);

/// Reset all data
void OCCTNoteObjectReset(OCCTNoteObjectRef ref);

// --- XCAFPrs_Style ---

/// XCAFPrs_Style data as a struct
typedef struct
{
  double surfR, surfG, surfB;
  float  surfAlpha;
  bool   hasSurfColor;
  double curvR, curvG, curvB;
  bool   hasCurvColor;
  bool   isVisible;
  bool   isEmpty;
} OCCTXCAFPrsStyle;

/// Create a default (empty) style
OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreate(void);

/// Create a style with surface color
OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreateWithSurfColor(double r, double g, double b, float alpha);

/// Create a style with surface and curve colors
OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreateFull(double surfR,
                                            double surfG,
                                            double surfB,
                                            float  surfAlpha,
                                            double curvR,
                                            double curvG,
                                            double curvB,
                                            bool   visible);

/// Check if two styles are equal
bool OCCTXCAFPrsStyleIsEqual(const OCCTXCAFPrsStyle* _Nonnull s1,
                             const OCCTXCAFPrsStyle* _Nonnull s2);

// --- XCAFDoc_VisMaterialCommon ---

/// Phong material data struct
typedef struct
{
  double diffuseR, diffuseG, diffuseB;
  double ambientR, ambientG, ambientB;
  double specularR, specularG, specularB;
  double emissiveR, emissiveG, emissiveB;
  float  shininess;
  float  transparency;
  bool   isDefined;
} OCCTVisMaterialCommon;

/// Get default VisMaterialCommon values
OCCTVisMaterialCommon OCCTVisMaterialCommonDefault(void);

/// Check equality of two VisMaterialCommon
bool OCCTVisMaterialCommonIsEqual(const OCCTVisMaterialCommon* _Nonnull a,
                                  const OCCTVisMaterialCommon* _Nonnull b);

// --- XCAFDoc_VisMaterialPBR ---

/// PBR material data struct
typedef struct
{
  double baseColorR, baseColorG, baseColorB;
  float  baseColorAlpha;
  float  metallic;
  float  roughness;
  float  refractionIndex;
  double emissionR, emissionG, emissionB;
  bool   isDefined;
} OCCTVisMaterialPBR;

/// Get default VisMaterialPBR values
OCCTVisMaterialPBR OCCTVisMaterialPBRDefault(void);

/// Check equality of two VisMaterialPBR
bool OCCTVisMaterialPBRIsEqual(const OCCTVisMaterialPBR* _Nonnull a,
                               const OCCTVisMaterialPBR* _Nonnull b);

// --- TDataStd_Directory ---

/// Create a new directory attribute on a document label
/// labelTag: 0 = main label, >0 = child tag
bool OCCTDocumentDirectoryNew(OCCTDocumentRef _Nonnull document, int labelTag);

/// Find a directory attribute on a label
bool OCCTDocumentDirectoryFind(OCCTDocumentRef _Nonnull document, int labelTag);

/// Add a sub-directory under an existing directory, returns child label tag
int OCCTDocumentDirectoryAddSubDirectory(OCCTDocumentRef _Nonnull document, int parentLabelTag);

/// Make an object label under a directory, returns child label tag
int OCCTDocumentDirectoryMakeObjectLabel(OCCTDocumentRef _Nonnull document, int parentLabelTag);

// --- TDataStd_Variable ---

/// Set a variable attribute on a label
bool OCCTDocumentVariableSet(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set variable name
bool OCCTDocumentVariableSetName(OCCTDocumentRef _Nonnull document,
                                 int labelTag,
                                 const char* _Nonnull name);

/// Get variable name (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentVariableGetName(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set variable value
bool OCCTDocumentVariableSetValue(OCCTDocumentRef _Nonnull document, int labelTag, double value);

/// Get variable value
double OCCTDocumentVariableGetValue(OCCTDocumentRef _Nonnull document, int labelTag);

/// Check if variable is valued
bool OCCTDocumentVariableIsValued(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set variable unit
bool OCCTDocumentVariableSetUnit(OCCTDocumentRef _Nonnull document,
                                 int labelTag,
                                 const char* _Nonnull unit);

/// Get variable unit (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentVariableGetUnit(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set variable constant flag
bool OCCTDocumentVariableSetConstant(OCCTDocumentRef _Nonnull document,
                                     int  labelTag,
                                     bool isConstant);

/// Get variable constant flag
bool OCCTDocumentVariableIsConstant(OCCTDocumentRef _Nonnull document, int labelTag);

// --- TDataStd_Expression ---

/// Set an expression attribute on a label
bool OCCTDocumentExpressionSet(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set expression string
bool OCCTDocumentExpressionSetString(OCCTDocumentRef _Nonnull document,
                                     int labelTag,
                                     const char* _Nonnull expression);

/// Get expression string (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentExpressionGetString(OCCTDocumentRef _Nonnull document,
                                                      int labelTag);

/// Get expression name (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentExpressionGetName(OCCTDocumentRef _Nonnull document,
                                                    int labelTag);

/// Assign expression to variable on same label (creates expression if needed)
bool OCCTDocumentVariableAssignExpression(OCCTDocumentRef _Nonnull document, int labelTag);

/// Remove expression assignment from variable
bool OCCTDocumentVariableDesassignExpression(OCCTDocumentRef _Nonnull document, int labelTag);

/// Check if variable has assigned expression
bool OCCTDocumentVariableIsAssigned(OCCTDocumentRef _Nonnull document, int labelTag);

// --- TDocStd_XLink ---

/// Set an external link attribute on a label
bool OCCTDocumentXLinkSet(OCCTDocumentRef _Nonnull document, int labelTag);

/// Set XLink document entry path
bool OCCTDocumentXLinkSetDocumentEntry(OCCTDocumentRef _Nonnull document,
                                       int labelTag,
                                       const char* _Nonnull entry);

/// Get XLink document entry path (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentXLinkGetDocumentEntry(OCCTDocumentRef _Nonnull document,
                                                        int labelTag);

/// Set XLink label entry string
bool OCCTDocumentXLinkSetLabelEntry(OCCTDocumentRef _Nonnull document,
                                    int labelTag,
                                    const char* _Nonnull entry);

/// Get XLink label entry string (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTDocumentXLinkGetLabelEntry(OCCTDocumentRef _Nonnull document,
                                                     int labelTag);

// --- XCAFDimTolObjects_Tool ---

/// Get count of dimension objects in XDE document
int OCCTDocumentDimTolDimensionCount(OCCTDocumentRef _Nonnull document);

/// Get count of geometric tolerance objects in XDE document
int OCCTDocumentDimTolToleranceCount(OCCTDocumentRef _Nonnull document);

// --- TPrsStd_DriverTable ---

/// Initialize global presentation driver table with standard drivers
void OCCTDriverTableInitStandard(void);

/// Check if global driver table exists
bool OCCTDriverTableExists(void);

/// Clear all drivers from global table
void OCCTDriverTableClear(void);

/// Get singleton TObj_Application instance
OCCTTObjAppRef _Nullable OCCTTObjApplicationGetInstance(void);

/// Set verbose flag on TObj_Application
void OCCTTObjApplicationSetVerbose(OCCTTObjAppRef _Nonnull app, bool verbose);

/// Get verbose flag from TObj_Application
bool OCCTTObjApplicationIsVerbose(OCCTTObjAppRef _Nonnull app);

/// Create a new document via TObj_Application
OCCTDocumentRef _Nullable OCCTTObjApplicationCreateDocument(OCCTTObjAppRef _Nonnull app);

/// Create an ID filter (ignoreAll=true: ignore all except kept; false: keep all except ignored)
OCCTIDFilterRef _Nullable OCCTIDFilterCreate(bool ignoreAll);

/// Release an ID filter
void OCCTIDFilterRelease(OCCTIDFilterRef _Nonnull filter);

/// Check if filter is in ignore-all mode
bool OCCTIDFilterIgnoreAll(OCCTIDFilterRef _Nonnull filter);

/// Set ignore-all mode
void OCCTIDFilterSetIgnoreAll(OCCTIDFilterRef _Nonnull filter, bool ignoreAll);

/// Keep a GUID (in ignore-all mode, this marks the GUID as kept)
void OCCTIDFilterKeep(OCCTIDFilterRef _Nonnull filter, const char* _Nonnull guidString);

/// Ignore a GUID (in keep-all mode, this marks the GUID as ignored)
void OCCTIDFilterIgnore(OCCTIDFilterRef _Nonnull filter, const char* _Nonnull guidString);

/// Check if a GUID is kept
bool OCCTIDFilterIsKept(OCCTIDFilterRef _Nonnull filter, const char* _Nonnull guidString);

/// Check if a GUID is ignored
bool OCCTIDFilterIsIgnored(OCCTIDFilterRef _Nonnull filter, const char* _Nonnull guidString);

// MARK: - TDataStd_BooleanArray

/// Set a boolean array attribute on a label (1-based indices)
bool OCCTDocumentSetBooleanArray(OCCTDocumentRef _Nonnull document,
                                 int tag,
                                 int lower,
                                 int upper,
                                 const bool* _Nonnull values,
                                 int count);

/// Get a boolean array attribute from a label. Returns count, fills values buffer.
int OCCTDocumentGetBooleanArray(OCCTDocumentRef _Nonnull document,
                                int tag,
                                bool* _Nullable values,
                                int maxCount);

/// Check if a label has a boolean array attribute
bool OCCTDocumentHasBooleanArray(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_BooleanList

/// Set a boolean list attribute on a label
bool OCCTDocumentSetBooleanList(OCCTDocumentRef _Nonnull document,
                                int tag,
                                const bool* _Nonnull values,
                                int count);

/// Get a boolean list attribute from a label. Returns count, fills values buffer.
int OCCTDocumentGetBooleanList(OCCTDocumentRef _Nonnull document,
                               int tag,
                               bool* _Nullable values,
                               int maxCount);

/// Append a value to a boolean list attribute
bool OCCTDocumentBooleanListAppend(OCCTDocumentRef _Nonnull document, int tag, bool value);

/// Clear a boolean list attribute
bool OCCTDocumentBooleanListClear(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has a boolean list attribute
bool OCCTDocumentHasBooleanList(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_ByteArray

/// Set a byte array attribute on a label (0-based indices)
bool OCCTDocumentSetByteArray(OCCTDocumentRef _Nonnull document,
                              int tag,
                              int lower,
                              int upper,
                              const uint8_t* _Nonnull values,
                              int count);

/// Get a byte array attribute from a label. Returns count, fills values buffer.
int OCCTDocumentGetByteArray(OCCTDocumentRef _Nonnull document,
                             int tag,
                             uint8_t* _Nullable values,
                             int maxCount);

/// Check if a label has a byte array attribute
bool OCCTDocumentHasByteArray(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_IntegerList

/// Set an integer list attribute on a label
bool OCCTDocumentSetIntegerList(OCCTDocumentRef _Nonnull document,
                                int tag,
                                const int* _Nonnull values,
                                int count);

/// Get an integer list attribute from a label. Returns count, fills values buffer.
int OCCTDocumentGetIntegerList(OCCTDocumentRef _Nonnull document,
                               int tag,
                               int* _Nullable values,
                               int maxCount);

/// Append a value to an integer list attribute
bool OCCTDocumentIntegerListAppend(OCCTDocumentRef _Nonnull document, int tag, int value);

/// Clear an integer list attribute
bool OCCTDocumentIntegerListClear(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has an integer list attribute
bool OCCTDocumentHasIntegerList(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_RealList

/// Set a real list attribute on a label
bool OCCTDocumentSetRealList(OCCTDocumentRef _Nonnull document,
                             int tag,
                             const double* _Nonnull values,
                             int count);

/// Get a real list attribute from a label. Returns count, fills values buffer.
int OCCTDocumentGetRealList(OCCTDocumentRef _Nonnull document,
                            int tag,
                            double* _Nullable values,
                            int maxCount);

/// Append a value to a real list attribute
bool OCCTDocumentRealListAppend(OCCTDocumentRef _Nonnull document, int tag, double value);

/// Clear a real list attribute
bool OCCTDocumentRealListClear(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has a real list attribute
bool OCCTDocumentHasRealList(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_ExtStringArray

/// Set an extended string array attribute on a label (1-based indices)
bool OCCTDocumentSetExtStringArray(OCCTDocumentRef _Nonnull document,
                                   int tag,
                                   int lower,
                                   int upper,
                                   const char* _Nonnull const* _Nonnull values,
                                   int count);

/// Get an extended string array element by index (1-based). Caller must free() the result.
char* _Nullable OCCTDocumentGetExtStringArrayValue(OCCTDocumentRef _Nonnull document,
                                                   int tag,
                                                   int index);

/// Get the bounds of an extended string array. Returns length, or -1 if not found.
int OCCTDocumentGetExtStringArrayLength(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has an extended string array attribute
bool OCCTDocumentHasExtStringArray(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_ExtStringList

/// Set an extended string list attribute on a label
bool OCCTDocumentSetExtStringList(OCCTDocumentRef _Nonnull document,
                                  int tag,
                                  const char* _Nonnull const* _Nonnull values,
                                  int count);

/// Get extended string list count from a label. Returns count, or -1 if not found.
int OCCTDocumentGetExtStringListCount(OCCTDocumentRef _Nonnull document, int tag);

/// Get extended string list element by index (0-based). Caller must free() the result.
char* _Nullable OCCTDocumentGetExtStringListValue(OCCTDocumentRef _Nonnull document,
                                                  int tag,
                                                  int index);

/// Append a string to an extended string list attribute
bool OCCTDocumentExtStringListAppend(OCCTDocumentRef _Nonnull document,
                                     int tag,
                                     const char* _Nonnull value);

/// Clear an extended string list attribute
bool OCCTDocumentExtStringListClear(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has an extended string list attribute
bool OCCTDocumentHasExtStringList(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_ReferenceArray

/// Set a reference array attribute on a label (array of label tags)
bool OCCTDocumentSetReferenceArray(OCCTDocumentRef _Nonnull document,
                                   int tag,
                                   int lower,
                                   int upper,
                                   const int* _Nonnull refTags,
                                   int count);

/// Get a reference array from a label. Returns count, fills refTags buffer with tags.
int OCCTDocumentGetReferenceArray(OCCTDocumentRef _Nonnull document,
                                  int tag,
                                  int* _Nullable refTags,
                                  int maxCount);

/// Check if a label has a reference array attribute
bool OCCTDocumentHasReferenceArray(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_ReferenceList

/// Set a reference list attribute on a label (list of label tags)
bool OCCTDocumentSetReferenceList(OCCTDocumentRef _Nonnull document,
                                  int tag,
                                  const int* _Nonnull refTags,
                                  int count);

/// Get a reference list from a label. Returns count, fills refTags buffer with tags.
int OCCTDocumentGetReferenceList(OCCTDocumentRef _Nonnull document,
                                 int tag,
                                 int* _Nullable refTags,
                                 int maxCount);

/// Append a reference to a reference list attribute
bool OCCTDocumentReferenceListAppend(OCCTDocumentRef _Nonnull document, int tag, int refTag);

/// Clear a reference list attribute
bool OCCTDocumentReferenceListClear(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has a reference list attribute
bool OCCTDocumentHasReferenceList(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_Relation

/// Set a relation string on a label
bool OCCTDocumentSetRelation(OCCTDocumentRef _Nonnull document,
                             int tag,
                             const char* _Nonnull relation);

/// Get a relation string from a label. Caller must free() the result.
char* _Nullable OCCTDocumentGetRelation(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has a relation attribute
bool OCCTDocumentHasRelation(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_Tick

/// Set a tick (boolean flag) attribute on a label
bool OCCTDocumentSetTick(OCCTDocumentRef _Nonnull document, int tag);

/// Check if a label has a tick attribute
bool OCCTDocumentHasTick(OCCTDocumentRef _Nonnull document, int tag);

/// Remove a tick attribute from a label
bool OCCTDocumentRemoveTick(OCCTDocumentRef _Nonnull document, int tag);

// MARK: - TDataStd_Current

/// Set a label as the current label in the document
bool OCCTDocumentSetCurrentLabel(OCCTDocumentRef _Nonnull document, int tag);

/// Get the current label tag. Returns -1 if no current label.
int OCCTDocumentGetCurrentLabel(OCCTDocumentRef _Nonnull document);

/// Check if the document has a current label set
bool OCCTDocumentHasCurrentLabel(OCCTDocumentRef _Nonnull document);

// MARK: - TNaming Extensions (v0.88.0)

/// Check if a TNaming_NamedShape exists and is not empty on a label (by labelId)
bool OCCTNamingIsEmpty(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the version of a TNaming_NamedShape attribute
int OCCTNamingGetVersion(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the version of a TNaming_NamedShape attribute
bool OCCTNamingSetVersion(OCCTDocumentRef _Nonnull doc, int64_t labelId, int version);

/// Get the original (old) shape from a named shape attribute
OCCTShapeRef _Nullable OCCTNamingOriginalShape(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a shape has a label in the document
bool OCCTNamingHasLabel(OCCTDocumentRef _Nonnull doc, OCCTShapeRef _Nonnull shape);

/// Find the label ID for a shape in the document; returns -1 if not found
int64_t OCCTNamingFindLabel(OCCTDocumentRef _Nonnull doc, OCCTShapeRef _Nonnull shape);

/// Get the valid-until transaction number for a shape
int OCCTNamingValidUntil(OCCTDocumentRef _Nonnull doc, OCCTShapeRef _Nonnull shape);

// MARK: - TNaming_SameShapeIterator

/// Get count of labels that contain the same shape
int32_t OCCTNamingSameShapeCount(OCCTDocumentRef _Nonnull doc, OCCTShapeRef _Nonnull shape);

/// Get label IDs that contain the same shape (up to maxCount)
/// Returns actual count written to outLabelIds. Caller provides pre-allocated buffer.
int32_t OCCTNamingSameShapeLabels(OCCTDocumentRef _Nonnull doc,
                                  OCCTShapeRef _Nonnull shape,
                                  int64_t* _Nonnull outLabelIds,
                                  int32_t maxCount);

// MARK: - TDataStd_IntPackedMap

/// Set (find or create) an IntPackedMap attribute on a label
bool OCCTIntPackedMapSet(OCCTDocumentRef _Nonnull doc, int tag, bool isDelta);

/// Add an integer to the IntPackedMap
bool OCCTIntPackedMapAdd(OCCTDocumentRef _Nonnull doc, int tag, int value);

/// Remove an integer from the IntPackedMap
bool OCCTIntPackedMapRemove(OCCTDocumentRef _Nonnull doc, int tag, int value);

/// Check if the IntPackedMap contains an integer
bool OCCTIntPackedMapContains(OCCTDocumentRef _Nonnull doc, int tag, int value);

/// Get the count of elements in the IntPackedMap
int OCCTIntPackedMapExtent(OCCTDocumentRef _Nonnull doc, int tag);

/// Clear all elements from the IntPackedMap
bool OCCTIntPackedMapClear(OCCTDocumentRef _Nonnull doc, int tag);

/// Check if the IntPackedMap is empty
bool OCCTIntPackedMapIsEmpty(OCCTDocumentRef _Nonnull doc, int tag);

/// Get all values from the IntPackedMap
/// Returns count; caller must free the values array
int OCCTIntPackedMapGetValues(OCCTDocumentRef _Nonnull doc,
                              int tag,
                              int* _Nullable* _Nonnull values);

/// Free values array from OCCTIntPackedMapGetValues
void OCCTIntPackedMapFreeValues(int* _Nullable values);

/// Replace all values in the IntPackedMap
bool OCCTIntPackedMapChangeValues(OCCTDocumentRef _Nonnull doc,
                                  int tag,
                                  const int* _Nonnull values,
                                  int count);

// MARK: - TDataStd_NoteBook

/// Create a NoteBook attribute on a label
bool OCCTNoteBookNew(OCCTDocumentRef _Nonnull doc, int tag);

/// Append a real value to the NoteBook, returns the child label tag or -1
int OCCTNoteBookAppendReal(OCCTDocumentRef _Nonnull doc, int tag, double value);

/// Append an integer value to the NoteBook, returns the child label tag or -1
int OCCTNoteBookAppendInteger(OCCTDocumentRef _Nonnull doc, int tag, int value);

/// Check if a NoteBook exists on a label (searches up hierarchy)
bool OCCTNoteBookFind(OCCTDocumentRef _Nonnull doc, int tag);

// MARK: - TDataStd_UAttribute

/// Set a UAttribute with a GUID string on a label
bool OCCTUAttributeSet(OCCTDocumentRef _Nonnull doc, int tag, const char* _Nonnull guidString);

/// Check if a UAttribute with a given GUID exists on a label
bool OCCTUAttributeHas(OCCTDocumentRef _Nonnull doc, int tag, const char* _Nonnull guidString);

/// Get the GUID string of a UAttribute on a label (caller must free the string)
const char* _Nullable OCCTUAttributeGetID(OCCTDocumentRef _Nonnull doc,
                                          int tag,
                                          const char* _Nonnull guidString);

/// Free a GUID string returned by OCCTUAttributeGetID
void OCCTUAttributeFreeGUID(const char* _Nullable guidString);

// MARK: - TDataStd_ChildNodeIterator

/// Get child node count for a TreeNode on a label
int OCCTChildNodeIteratorCount(OCCTDocumentRef _Nonnull doc, int tag, bool allLevels);

// MARK: - TDF_Transaction Named (v0.89.0)

/// Open a named transaction on the document data.
/// @return Transaction index (>= 1 on success, 0 on error)
int32_t OCCTDocumentOpenNamedTransaction(OCCTDocumentRef _Nonnull doc, const char* _Nonnull name);

/// Commit the current transaction and return a delta for undo.
/// The returned delta can be queried with OCCTDelta* functions.
/// @return Opaque delta pointer (NULL if no changes or error). Caller must free with
/// OCCTDeltaRelease.
void* _Nullable OCCTDocumentCommitWithDelta(OCCTDocumentRef _Nonnull doc);

/// Get the transaction number of the current open transaction.
/// @return Transaction number, or 0 if no transaction is open
int32_t OCCTDocumentGetTransactionNumber(OCCTDocumentRef _Nonnull doc);

// MARK: - TDF_Delta (v0.89.0)

/// Check if a delta is empty (no attribute changes recorded).
bool OCCTDeltaIsEmpty(void* _Nonnull delta);

/// Get the begin time of a delta.
int32_t OCCTDeltaBeginTime(void* _Nonnull delta);

/// Get the end time of a delta.
int32_t OCCTDeltaEndTime(void* _Nonnull delta);

/// Get the number of attribute deltas in a delta.
int32_t OCCTDeltaAttributeDeltaCount(void* _Nonnull delta);

/// Set the name of a delta.
void OCCTDeltaSetName(void* _Nonnull delta, const char* _Nonnull name);

/// Get the name of a delta. Caller must free the returned string.
const char* _Nullable OCCTDeltaGetName(void* _Nonnull delta);

/// Free a delta name string.
void OCCTDeltaFreeName(const char* _Nullable name);

/// Release a delta object.
void OCCTDeltaRelease(void* _Nonnull delta);

// MARK: - TDF_ComparisonTool (v0.89.0)

/// Check if a label's references are all contained within its descendants.
/// @return true if self-contained
bool OCCTDocumentIsSelfContained(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - TDocStd_XLinkTool (v0.89.0)

/// Copy a label to another label using TDocStd_XLinkTool (simple copy without link).
/// @return true on success
bool OCCTDocumentXLinkCopy(OCCTDocumentRef _Nonnull doc, int64_t tgtLabelId, int64_t srcLabelId);

/// Copy a label to another label with an XLink attribute for cross-document references.
/// @return true on success
bool OCCTDocumentXLinkCopyWithLink(OCCTDocumentRef _Nonnull doc,
                                   int64_t tgtLabelId,
                                   int64_t srcLabelId);

// MARK: - TFunction_IFunction (v0.89.0)

/// Create a new function at a label with a given GUID.
/// Requires TFunction_Scope to be set on the document root.
/// @return true on success
bool OCCTDocumentNewFunction(OCCTDocumentRef _Nonnull doc,
                             int64_t labelId,
                             const char* _Nonnull guidString);

/// Delete a function from a label.
/// @return true on success
bool OCCTDocumentDeleteFunction(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the execution status of a function.
/// 0=WrongDefinition, 1=NotExecuted, 2=Executing, 3=Succeeded, 4=Failed
/// @return status value, or -1 if no function found
int32_t OCCTDocumentFunctionGetExecStatus(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the execution status of a function via IFunction.
/// @return true on success
bool OCCTDocumentFunctionSetExecStatus(OCCTDocumentRef _Nonnull doc,
                                       int64_t labelId,
                                       int32_t status);

// MARK: - TFunction_Scope (v0.89.0)

/// Set (find or create) a TFunction_Scope on the document root.
/// @return true on success
bool OCCTDocumentSetFunctionScope(OCCTDocumentRef _Nonnull doc);

/// Add a label to the function scope.
/// @return true on success
bool OCCTDocumentFunctionScopeAdd(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Remove a label from the function scope.
/// @return true on success
bool OCCTDocumentFunctionScopeRemove(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is in the function scope.
bool OCCTDocumentFunctionScopeHas(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Remove all functions from the scope.
/// @return true on success
bool OCCTDocumentFunctionScopeRemoveAll(OCCTDocumentRef _Nonnull doc);

/// Get the number of functions in the scope.
int32_t OCCTDocumentFunctionScopeCount(OCCTDocumentRef _Nonnull doc);

/// Get the free (next available) function ID from the scope.
int32_t OCCTDocumentFunctionScopeGetFreeID(OCCTDocumentRef _Nonnull doc);

// MARK: - TDF_AttributeIterator (v0.89.0)

/// Count the number of attributes on a label.
/// @param withoutForgotten If true, skip forgotten (deleted) attributes
int32_t OCCTDocumentAttributeCount(OCCTDocumentRef _Nonnull doc,
                                   int64_t labelId,
                                   bool    withoutForgotten);

// MARK: - TDF_DataSet (v0.89.0)

/// Check if a DataSet containing a label is empty after adding it.
/// (Utility to verify label has content)
bool OCCTDocumentDataSetIsEmpty(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - TDF_ChildIDIterator (v0.90.0)

/// Count child labels that have an attribute with the given GUID string.
/// @param allLevels If true, recurse into all descendants
int32_t OCCTDocumentChildIDCount(OCCTDocumentRef _Nonnull doc,
                                 int64_t labelId,
                                 const char* _Nonnull guidString,
                                 bool allLevels);

// MARK: - TFunction_DriverTable (v0.90.0)

/// Check if a function driver with the given GUID is registered.
bool OCCTFunctionDriverTableHasDriver(const char* _Nonnull guidString);

/// Clear all registered function drivers.
void OCCTFunctionDriverTableClear(void);

// MARK: - TNaming_Scope (v0.90.0)

/// Mark a label as valid in a naming scope context.
/// @return true on success
bool OCCTDocumentNamingScopeValid(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Mark a label and its children as valid.
/// @return true on success
bool OCCTDocumentNamingScopeValidChildren(OCCTDocumentRef _Nonnull doc,
                                          int64_t labelId,
                                          bool    withRoot);

/// Check if a label is valid in the naming scope.
bool OCCTDocumentNamingScopeIsValid(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Invalidate (unvalid) a label in the naming scope.
/// @return true on success
bool OCCTDocumentNamingScopeUnvalid(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Clear all valid labels in the naming scope.
void OCCTDocumentNamingScopeClear(OCCTDocumentRef _Nonnull doc);

/// Get the count of valid labels in the naming scope.
int32_t OCCTDocumentNamingScopeValidCount(OCCTDocumentRef _Nonnull doc);

// MARK: - TNaming_Translator (v0.90.0)

/// Deep-copy a shape using TNaming_Translator.
/// @return New copied shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeTranslatorCopy(OCCTShapeRef _Nonnull shape);

/// Check if two shapes are the same TShape (identity check).
bool OCCTShapeIsSame(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2);

// MARK: - TDataXtd_Placement (v0.90.0)

/// Set a TDataXtd_Placement marker attribute on a label.
/// @return true on success
bool OCCTDocumentSetPlacement(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label has a TDataXtd_Placement attribute.
bool OCCTDocumentHasPlacement(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - TDataXtd_Presentation (v0.90.0)

/// Set a TDataXtd_Presentation attribute on a label with a driver GUID.
/// @return true on success
bool OCCTDocumentSetPresentation(OCCTDocumentRef _Nonnull doc,
                                 int64_t labelId,
                                 const char* _Nonnull driverGUID);

/// Remove a TDataXtd_Presentation attribute from a label.
void OCCTDocumentUnsetPresentation(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a presentation attribute exists on a label.
bool OCCTDocumentHasPresentation(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the display state of a presentation.
bool OCCTDocumentPresentationSetDisplayed(OCCTDocumentRef _Nonnull doc,
                                          int64_t labelId,
                                          bool    displayed);

/// Get the display state of a presentation.
bool OCCTDocumentPresentationIsDisplayed(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the color of a presentation (Quantity_NameOfColor as int).
bool OCCTDocumentPresentationSetColor(OCCTDocumentRef _Nonnull doc,
                                      int64_t labelId,
                                      int32_t colorIndex);

/// Get the color of a presentation. Returns -1 if no own color.
int32_t OCCTDocumentPresentationGetColor(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the transparency of a presentation [0.0, 1.0].
bool OCCTDocumentPresentationSetTransparency(OCCTDocumentRef _Nonnull doc,
                                             int64_t labelId,
                                             double  value);

/// Get the transparency. Returns -1.0 if no own transparency.
double OCCTDocumentPresentationGetTransparency(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the line width of a presentation.
bool OCCTDocumentPresentationSetWidth(OCCTDocumentRef _Nonnull doc, int64_t labelId, double width);

/// Get the line width. Returns -1.0 if no own width.
double OCCTDocumentPresentationGetWidth(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the display mode of a presentation (0=wireframe, 1=shaded, etc.).
bool OCCTDocumentPresentationSetMode(OCCTDocumentRef _Nonnull doc, int64_t labelId, int32_t mode);

/// Get the display mode. Returns -1 if no own mode.
int32_t OCCTDocumentPresentationGetMode(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - XCAFDoc_AssemblyIterator (v0.90.0)

/// Count the number of assembly items in a document.
/// @param maxDepth Maximum depth to traverse (0 = unlimited)
/// Count assembly items, depth-first, to `maxDepth` levels (0 = unlimited).
///
/// The walk is bounded at 100,000 items because `XCAFDoc_AssemblyIterator` keeps no visited
/// set, so a malformed self-referencing assembly would otherwise iterate to `INT_MAX` depth.
/// `outTruncated` is set true when that bound is reached, in which case the return value is a
/// floor rather than a count (#964). Pass NULL if you do not care.
int32_t OCCTDocumentAssemblyItemCount(OCCTDocumentRef _Nonnull doc,
                                      int32_t maxDepth,
                                      bool* _Nullable outTruncated);

// MARK: - XCAFDoc_DimTol (v0.90.0)

/// Set a DimTol attribute on a label.
/// @param kind Dimension/tolerance type code
/// @param values Array of numeric values
/// @param valueCount Number of values
/// @param name Name string
/// @param description Description string
/// @return true on success
bool OCCTDocumentSetDimTol(OCCTDocumentRef _Nonnull doc,
                           int64_t labelId,
                           int32_t kind,
                           const double* _Nonnull values,
                           int32_t valueCount,
                           const char* _Nonnull name,
                           const char* _Nonnull description);

/// Get the kind of a DimTol attribute. Returns -1 if not found.
int32_t OCCTDocumentGetDimTolKind(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the name of a DimTol attribute. Caller must free.
const char* _Nullable OCCTDocumentGetDimTolName(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the description of a DimTol attribute. Caller must free.
const char* _Nullable OCCTDocumentGetDimTolDescription(OCCTDocumentRef _Nonnull doc,
                                                       int64_t labelId);

/// Get the values of a DimTol attribute.
/// @param outValues Output buffer for values
/// @param maxCount Maximum values to return
/// @return Number of values written
int32_t OCCTDocumentGetDimTolValues(OCCTDocumentRef _Nonnull doc,
                                    int64_t labelId,
                                    double* _Nonnull outValues,
                                    int32_t maxCount);

/// Free a DimTol string (name or description).
void OCCTDocumentFreeDimTolString(const char* _Nullable str);

// MARK: - TDataXtd_Constraint (v0.92.0)

/// Set a TDataXtd_Constraint attribute on a label.
bool OCCTDocumentSetConstraint(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the constraint type. Types: 0=RADIUS..22=FROM
bool OCCTDocumentConstraintSetType(OCCTDocumentRef _Nonnull doc, int64_t labelId, int32_t type);

/// Get the constraint type. Returns -1 if not found.
int32_t OCCTDocumentConstraintGetType(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the number of geometries in the constraint.
int32_t OCCTDocumentConstraintNbGeometries(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if constraint is planar (2D).
bool OCCTDocumentConstraintIsPlanar(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if constraint is a dimension (has value).
bool OCCTDocumentConstraintIsDimension(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set the verified flag on a constraint.
bool OCCTDocumentConstraintSetVerified(OCCTDocumentRef _Nonnull doc,
                                       int64_t labelId,
                                       bool    verified);

/// Get the verified flag.
bool OCCTDocumentConstraintGetVerified(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Clear all geometries from a constraint.
bool OCCTDocumentConstraintClearGeometries(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - TDataXtd_PatternStd (v0.93.0)

/// Set a TDataXtd_PatternStd attribute on a label.
bool OCCTDocumentSetPatternStd(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set pattern signature (1=linear, 2=circular, 3=rectangular, 4=radial, 5=mirror).
bool OCCTDocumentPatternSetSignature(OCCTDocumentRef _Nonnull doc,
                                     int64_t labelId,
                                     int32_t signature);

/// Get pattern signature. Returns -1 if not found.
int32_t OCCTDocumentPatternGetSignature(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get number of transforms in the pattern.
int32_t OCCTDocumentPatternNbTrsfs(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label has a pattern attribute.
bool OCCTDocumentHasPattern(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - XCAFDoc_AssemblyItemRef (v0.96.0)

/// Set an assembly item reference on a label.
bool OCCTDocumentSetAssemblyItemRef(OCCTDocumentRef _Nonnull doc,
                                    int64_t labelId,
                                    const char* _Nonnull itemPath);

/// Get the assembly item path string. Caller must free.
const char* _Nullable OCCTDocumentGetAssemblyItemRef(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set subshape index on an assembly item ref.
bool OCCTDocumentAssemblyItemRefSetSubshape(OCCTDocumentRef _Nonnull doc,
                                            int64_t labelId,
                                            int32_t index);

/// Get subshape index. Returns -1 if not set.
int32_t OCCTDocumentAssemblyItemRefGetSubshape(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if assembly item ref has extra reference (GUID or subshape).
bool OCCTDocumentAssemblyItemRefHasExtra(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Clear extra reference from assembly item ref.
bool OCCTDocumentAssemblyItemRefClearExtra(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if assembly item ref points to orphan (nonexistent item).
bool OCCTDocumentAssemblyItemRefIsOrphan(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Free an assembly item ref string.
void OCCTDocumentFreeAssemblyItemRefString(const char* _Nullable str);

// MARK: - TNaming_Naming (v0.97.0)

/// Insert a TNaming_Naming attribute on a label.
bool OCCTDocumentInsertNaming(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a naming attribute is defined on a label.
bool OCCTDocumentNamingIsDefined(OCCTDocumentRef _Nonnull doc, int64_t labelId);

// MARK: - XCAFPrs_DocumentExplorer (v0.104.0)

/// Count leaf shape nodes in a document.
int32_t OCCTDocumentExplorerCount(OCCTDocumentRef _Nonnull doc);

/// Get shape at index from document explorer (0-based). Returns shape ref.
OCCTShapeRef _Nullable OCCTDocumentExplorerShape(OCCTDocumentRef _Nonnull doc, int32_t index);

/// Get path ID at index from document explorer. Caller must free().
char* _Nullable OCCTDocumentExplorerPathId(OCCTDocumentRef _Nonnull doc, int32_t index);

/// Find shape from path ID string.
OCCTShapeRef _Nullable OCCTDocumentExplorerFindShape(OCCTDocumentRef _Nonnull doc,
                                                     const char* _Nonnull pathId);

// MARK: - XCAFPrs_DocumentExplorer extensions (v0.105.0)

/// Get the depth of a document explorer node at given index.
int32_t OCCTDocumentExplorerDepth(OCCTDocumentRef _Nonnull doc, int32_t index);

/// Check if a document explorer node is an assembly.
bool OCCTDocumentExplorerIsAssembly(OCCTDocumentRef _Nonnull doc, int32_t index);

/// Get the location matrix (12 doubles, row-major 3x4) for a document explorer node.
void OCCTDocumentExplorerLocation(OCCTDocumentRef _Nonnull doc,
                                  int32_t index,
                                  double* _Nonnull matrix12);

// --- XCAFDoc_ColorTool completions ---

/// Add a color to the document color table. Returns label id.
int64_t OCCTDocumentColorToolAddColor(OCCTDocumentRef _Nonnull doc, double r, double g, double b);

/// Remove a color from the document color table by label id.
bool OCCTDocumentColorToolRemoveColor(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the number of colors in the color table.
int32_t OCCTDocumentColorToolGetColorCount(OCCTDocumentRef _Nonnull doc);

/// Unset color of a specific type from a label.
bool OCCTDocumentColorToolUnSetColor(OCCTDocumentRef _Nonnull doc,
                                     int64_t labelId,
                                     int32_t colorType);

/// Check if a label is visible.
bool OCCTDocumentColorToolIsVisible(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set visibility of a label.
bool OCCTDocumentColorToolSetVisibility(OCCTDocumentRef _Nonnull doc,
                                        int64_t labelId,
                                        bool    visible);

/// Check if color is defined by layer.
bool OCCTDocumentColorToolIsColorByLayer(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Set color-by-layer flag on a label.
bool OCCTDocumentColorToolSetColorByLayer(OCCTDocumentRef _Nonnull doc,
                                          int64_t labelId,
                                          bool    isByLayer);

/// Find a color in the color table. Returns label id or -1 if not found.
int64_t OCCTDocumentColorToolFindColor(OCCTDocumentRef _Nonnull doc, double r, double g, double b);

/// Set instance color on a shape component. Returns false if shape not found.
bool OCCTDocumentColorToolSetInstanceColor(OCCTDocumentRef _Nonnull doc,
                                           OCCTShapeRef _Nonnull shape,
                                           int32_t colorType,
                                           double  r,
                                           double  g,
                                           double  b);

/// Get instance color of a shape component. Returns false if not set.
bool OCCTDocumentColorToolGetInstanceColor(OCCTDocumentRef _Nonnull doc,
                                           OCCTShapeRef _Nonnull shape,
                                           int32_t colorType,
                                           double* _Nonnull r,
                                           double* _Nonnull g,
                                           double* _Nonnull b);

// --- XCAFDoc_ColorTool completions ---

/// Get all color labels in the document. Returns array of label IDs. Caller must free with free().
int32_t OCCTDocumentColorToolGetAllColors(OCCTDocumentRef _Nonnull doc,
                                          int64_t* _Nullable* _Nonnull outLabelIds);

#endif /* OCCTBridge_Document_h */
