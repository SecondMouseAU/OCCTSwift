//
//  OCCTBridge_AIS.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the AIS domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_AIS_h
#define OCCTBridge_AIS_h


/// Kind of dimension measurement.
typedef enum {
    OCCTDimensionKindLength   = 0,
    OCCTDimensionKindRadius   = 1,
    OCCTDimensionKindAngle    = 2,
    OCCTDimensionKindDiameter = 3
} OCCTDimensionKind;

/// Geometry extracted from a dimension for Metal rendering.
typedef struct {
    double firstPoint[3];     ///< First attachment point (on geometry)
    double secondPoint[3];    ///< Second attachment point (on geometry)
    double centerPoint[3];    ///< Angle vertex; or circle center for radius/diameter
    double textPosition[3];   ///< Suggested text placement position
    double circleNormal[3];   ///< Circle axis for radius/diameter dimensions
    double circleRadius;      ///< Circle radius for radius/diameter dimensions
    double value;             ///< Measured value (distance in model units, angle in radians)
    int32_t kind;             ///< OCCTDimensionKind
    bool isValid;             ///< Whether the geometry is valid
} OCCTDimensionGeometry;

/// Info extracted from a text label.
typedef struct {
    double position[3];
    double height;
    char text[256];
} OCCTTextLabelInfo;

// --- Dimension creation ---

/// Create a length dimension between two 3D points.
OCCTDimensionRef OCCTDimensionCreateLengthFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z);

/// Create a length dimension measuring a linear edge.
OCCTDimensionRef OCCTDimensionCreateLengthFromEdge(OCCTShapeRef edge);

/// Create a length dimension between two parallel faces.
OCCTDimensionRef OCCTDimensionCreateLengthFromFaces(
    OCCTShapeRef face1, OCCTShapeRef face2);

/// Create a radius dimension from a shape with circular geometry.
OCCTDimensionRef OCCTDimensionCreateRadiusFromShape(OCCTShapeRef shape);

/// Create an angle dimension between two edges.
OCCTDimensionRef OCCTDimensionCreateAngleFromEdges(
    OCCTShapeRef edge1, OCCTShapeRef edge2);

/// Create an angle dimension from three points (first, vertex, second).
OCCTDimensionRef OCCTDimensionCreateAngleFromPoints(
    double p1x, double p1y, double p1z,
    double cx, double cy, double cz,
    double p2x, double p2y, double p2z);

/// Create an angle dimension between two planar faces.
OCCTDimensionRef OCCTDimensionCreateAngleFromFaces(
    OCCTShapeRef face1, OCCTShapeRef face2);

/// Create a diameter dimension from a shape with circular geometry.
OCCTDimensionRef OCCTDimensionCreateDiameterFromShape(OCCTShapeRef shape);

// --- Dimension common functions ---

/// Release a dimension handle.
void OCCTDimensionRelease(OCCTDimensionRef dim);

/// Get the measured (or custom) value of a dimension.
double OCCTDimensionGetValue(OCCTDimensionRef dim);

/// Get the full dimension geometry for rendering.
bool OCCTDimensionGetGeometry(OCCTDimensionRef dim, OCCTDimensionGeometry* outGeometry);

/// Override the dimension value with a custom number.
void OCCTDimensionSetCustomValue(OCCTDimensionRef dim, double value);

/// Check if the dimension geometry is valid.
bool OCCTDimensionIsValid(OCCTDimensionRef dim);

/// Get the kind of this dimension.
int32_t OCCTDimensionGetKind(OCCTDimensionRef dim);

// --- Text Label ---

/// Create a text label at a 3D position.
OCCTTextLabelRef OCCTTextLabelCreate(const char* text,
                                      double x, double y, double z);

/// Release a text label handle.
void OCCTTextLabelRelease(OCCTTextLabelRef label);

/// Set the label text.
void OCCTTextLabelSetText(OCCTTextLabelRef label, const char* text);

/// Set the label position.
void OCCTTextLabelSetPosition(OCCTTextLabelRef label,
                               double x, double y, double z);

/// Set the label text height.
void OCCTTextLabelSetHeight(OCCTTextLabelRef label, double height);

/// Get label info (text, position, height).
bool OCCTTextLabelGetInfo(OCCTTextLabelRef label, OCCTTextLabelInfo* outInfo);

// --- Point Cloud ---

/// Create a point cloud from xyz coordinate triples.
/// @param coords Array of [x0,y0,z0, x1,y1,z1, ...] (3 * count doubles)
/// @param count Number of points
OCCTPointCloudRef OCCTPointCloudCreate(const double* coords, int32_t count);

/// Create a colored point cloud.
/// @param coords Array of xyz triples (3 * count doubles)
/// @param colors Array of rgb triples (3 * count floats, each in [0,1])
/// @param count Number of points
OCCTPointCloudRef OCCTPointCloudCreateColored(const double* coords,
                                               const float* colors,
                                               int32_t count);

/// Release a point cloud handle.
void OCCTPointCloudRelease(OCCTPointCloudRef cloud);

/// Get the number of points in the cloud.
int32_t OCCTPointCloudGetCount(OCCTPointCloudRef cloud);

/// Get the axis-aligned bounding box.
/// Returns true on success, fills minXYZ[3] and maxXYZ[3].
bool OCCTPointCloudGetBounds(OCCTPointCloudRef cloud,
                              double* outMinXYZ, double* outMaxXYZ);

/// Copy point coordinates into the output buffer.
/// @param outCoords Buffer for xyz triples (must hold at least 3 * count doubles)
/// @param maxCount Maximum number of points to copy
/// @return Number of points copied
int32_t OCCTPointCloudGetPoints(OCCTPointCloudRef cloud,
                                 double* outCoords, int32_t maxCount);

/// Copy point colors into the output buffer.
/// @param outColors Buffer for rgb triples (must hold at least 3 * count floats)
/// @param maxCount Maximum number of colors to copy
/// @return Number of colors copied (0 if uncolored)
int32_t OCCTPointCloudGetColors(OCCTPointCloudRef cloud,
                                 float* outColors, int32_t maxCount);

#endif /* OCCTBridge_AIS_h */
