//
//  OCCTBridge_Visualization.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Visualization domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_Visualization_h
#define OCCTBridge_Visualization_h


OCCTCameraRef OCCTCameraCreate(void);
void          OCCTCameraDestroy(OCCTCameraRef cam);

void OCCTCameraSetEye(OCCTCameraRef cam, double x, double y, double z);
void OCCTCameraGetEye(OCCTCameraRef cam, double* x, double* y, double* z);
void OCCTCameraSetCenter(OCCTCameraRef cam, double x, double y, double z);
void OCCTCameraGetCenter(OCCTCameraRef cam, double* x, double* y, double* z);
void OCCTCameraSetUp(OCCTCameraRef cam, double x, double y, double z);
void OCCTCameraGetUp(OCCTCameraRef cam, double* x, double* y, double* z);

void OCCTCameraSetProjectionType(OCCTCameraRef cam, int type);
int  OCCTCameraGetProjectionType(OCCTCameraRef cam);
void OCCTCameraSetFOV(OCCTCameraRef cam, double degrees);
double OCCTCameraGetFOV(OCCTCameraRef cam);
void OCCTCameraSetScale(OCCTCameraRef cam, double scale);
double OCCTCameraGetScale(OCCTCameraRef cam);
void OCCTCameraSetZRange(OCCTCameraRef cam, double zNear, double zFar);
void OCCTCameraGetZRange(OCCTCameraRef cam, double* zNear, double* zFar);
void OCCTCameraSetAspect(OCCTCameraRef cam, double aspect);
double OCCTCameraGetAspect(OCCTCameraRef cam);

void OCCTCameraGetProjectionMatrix(OCCTCameraRef cam, float* out16);
void OCCTCameraGetViewMatrix(OCCTCameraRef cam, float* out16);

void OCCTCameraProject(OCCTCameraRef cam, double wX, double wY, double wZ,
                       double* sX, double* sY, double* sZ);
void OCCTCameraUnproject(OCCTCameraRef cam, double sX, double sY, double sZ,
                         double* wX, double* wY, double* wZ);

void OCCTCameraFitBBox(OCCTCameraRef cam, double xMin, double yMin, double zMin,
                       double xMax, double yMax, double zMax);

// MARK: - Presentation Mesh (Metal Visualization)

typedef struct {
    float* vertices;
    int32_t vertexCount;
    int32_t* indices;
    int32_t triangleCount;
} OCCTShadedMeshData;

typedef struct {
    float* vertices;
    int32_t vertexCount;
    int32_t* segmentStarts;
    int32_t segmentCount;
} OCCTEdgeMeshData;

bool OCCTShapeGetShadedMesh(OCCTShapeRef shape, double deflection, OCCTShadedMeshData* out);
void OCCTShadedMeshDataFree(OCCTShadedMeshData* data);

bool OCCTShapeGetEdgeMesh(OCCTShapeRef shape, double deflection, OCCTEdgeMeshData* out);
void OCCTEdgeMeshDataFree(OCCTEdgeMeshData* data);

typedef struct {
    int32_t shapeId;
    double depth;
    double pointX, pointY, pointZ;
    int32_t subShapeType;   // TopAbs_ShapeEnum: 7=VERTEX, 6=EDGE, 5=WIRE, 4=FACE, 8=SHAPE
    int32_t subShapeIndex;  // 0-based index of sub-shape within parent, -1 if whole shape (#541)
} OCCTPickResult;

OCCTSelectorRef OCCTSelectorCreate(void);
void            OCCTSelectorDestroy(OCCTSelectorRef sel);

bool OCCTSelectorAddShape(OCCTSelectorRef sel, OCCTShapeRef shape, int32_t shapeId);
bool OCCTSelectorRemoveShape(OCCTSelectorRef sel, int32_t shapeId);
void OCCTSelectorClear(OCCTSelectorRef sel);

/// Activate a selection mode for a shape (0=shape, 1=vertex, 2=edge, 3=wire, 4=face).
/// Mode 0 is activated automatically when adding a shape.
void OCCTSelectorActivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode);

/// Deactivate a selection mode for a shape. Pass -1 to deactivate all modes.
void OCCTSelectorDeactivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode);

/// Check if a selection mode is active for a shape.
bool OCCTSelectorIsModeActive(OCCTSelectorRef sel, int32_t shapeId, int32_t mode);

/// Set pixel tolerance for picking near edges/vertices (default 2).
void OCCTSelectorSetPixelTolerance(OCCTSelectorRef sel, int32_t tolerance);
int32_t OCCTSelectorGetPixelTolerance(OCCTSelectorRef sel);

int32_t OCCTSelectorPick(OCCTSelectorRef sel, OCCTCameraRef cam,
                         double viewW, double viewH,
                         double pixelX, double pixelY,
                         OCCTPickResult* out, int32_t maxResults);

int32_t OCCTSelectorPickRect(OCCTSelectorRef sel, OCCTCameraRef cam,
                             double viewW, double viewH,
                             double xMin, double yMin, double xMax, double yMax,
                             OCCTPickResult* out, int32_t maxResults);

/// Polyline (lasso) pick: select shapes within a closed polygon defined by 2D pixel points.
/// polyXY is an array of x,y pairs (length = pointCount * 2).
int32_t OCCTSelectorPickPoly(OCCTSelectorRef sel, OCCTCameraRef cam,
                             double viewW, double viewH,
                             const double* polyXY, int32_t pointCount,
                             OCCTPickResult* out, int32_t maxResults);

/// Extract shaded mesh using a DisplayDrawer for tessellation control.
bool OCCTShapeGetShadedMeshWithDrawer(OCCTShapeRef shape, OCCTDrawerRef drawer, OCCTShadedMeshData* out);
bool OCCTShapeGetEdgeMeshWithDrawer(OCCTShapeRef shape, OCCTDrawerRef drawer, OCCTEdgeMeshData* out);

// MARK: - Display Drawer (Metal Visualization)

OCCTDrawerRef OCCTDrawerCreate(void);
void OCCTDrawerDestroy(OCCTDrawerRef drawer);

/// Chordal deviation coefficient (relative to bounding box). Default ~0.001.
void OCCTDrawerSetDeviationCoefficient(OCCTDrawerRef drawer, double coeff);
double OCCTDrawerGetDeviationCoefficient(OCCTDrawerRef drawer);

/// Angular deviation in radians. Default 20 degrees (M_PI/9).
void OCCTDrawerSetDeviationAngle(OCCTDrawerRef drawer, double angle);
double OCCTDrawerGetDeviationAngle(OCCTDrawerRef drawer);

/// Maximal chordal deviation (absolute). Applies when type of deflection is absolute.
void OCCTDrawerSetMaximalChordialDeviation(OCCTDrawerRef drawer, double deviation);
double OCCTDrawerGetMaximalChordialDeviation(OCCTDrawerRef drawer);

/// Type of deflection: 0=relative (default), 1=absolute.
void OCCTDrawerSetTypeOfDeflection(OCCTDrawerRef drawer, int32_t type);
int32_t OCCTDrawerGetTypeOfDeflection(OCCTDrawerRef drawer);

/// Auto-triangulation on/off. Default true.
void OCCTDrawerSetAutoTriangulation(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetAutoTriangulation(OCCTDrawerRef drawer);

/// Number of iso-parameter lines (U and V). Default 1.
void OCCTDrawerSetIsoOnTriangulation(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetIsoOnTriangulation(OCCTDrawerRef drawer);

/// Discretisation (number of points for curves). Default 30.
void OCCTDrawerSetDiscretisation(OCCTDrawerRef drawer, int32_t value);
int32_t OCCTDrawerGetDiscretisation(OCCTDrawerRef drawer);

/// Face boundary display on/off. Default false.
void OCCTDrawerSetFaceBoundaryDraw(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetFaceBoundaryDraw(OCCTDrawerRef drawer);

/// Wire frame display on/off. Default true.
void OCCTDrawerSetWireDraw(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetWireDraw(OCCTDrawerRef drawer);

/// Create a clip plane from an equation Ax + By + Cz + D = 0
OCCTClipPlaneRef OCCTClipPlaneCreate(double a, double b, double c, double d);
void OCCTClipPlaneDestroy(OCCTClipPlaneRef plane);

void OCCTClipPlaneSetEquation(OCCTClipPlaneRef plane, double a, double b, double c, double d);
void OCCTClipPlaneGetEquation(OCCTClipPlaneRef plane, double* a, double* b, double* c, double* d);

/// Get the reversed equation (for back-face clipping)
void OCCTClipPlaneGetReversedEquation(OCCTClipPlaneRef plane, double* a, double* b, double* c, double* d);

void OCCTClipPlaneSetOn(OCCTClipPlaneRef plane, bool on);
bool OCCTClipPlaneIsOn(OCCTClipPlaneRef plane);

void OCCTClipPlaneSetCapping(OCCTClipPlaneRef plane, bool on);
bool OCCTClipPlaneIsCapping(OCCTClipPlaneRef plane);

void OCCTClipPlaneSetCappingColor(OCCTClipPlaneRef plane, double r, double g, double b);
void OCCTClipPlaneGetCappingColor(OCCTClipPlaneRef plane, double* r, double* g, double* b);

/// Set capping hatch style (see Aspect_HatchStyle values)
void OCCTClipPlaneSetCappingHatch(OCCTClipPlaneRef plane, int32_t style);
int32_t OCCTClipPlaneGetCappingHatch(OCCTClipPlaneRef plane);
void OCCTClipPlaneSetCappingHatchOn(OCCTClipPlaneRef plane, bool on);
bool OCCTClipPlaneIsCappingHatchOn(OCCTClipPlaneRef plane);

/// Probe a point against the clip plane chain. Returns: 0=Out, 1=In, 2=On
int32_t OCCTClipPlaneProbePoint(OCCTClipPlaneRef plane, double x, double y, double z);

/// Probe an axis-aligned bounding box against the clip plane chain. Returns: 0=Out, 1=In, 2=On
int32_t OCCTClipPlaneProbeBox(OCCTClipPlaneRef plane,
                               double xMin, double yMin, double zMin,
                               double xMax, double yMax, double zMax);

/// Chain another plane for logical AND clipping (conjunction)
void OCCTClipPlaneSetChainNext(OCCTClipPlaneRef plane, OCCTClipPlaneRef next);
/// Get the number of planes in the forward chain (including this one)
int32_t OCCTClipPlaneChainLength(OCCTClipPlaneRef plane);

OCCTZLayerSettingsRef OCCTZLayerSettingsCreate(void);
void OCCTZLayerSettingsDestroy(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetName(OCCTZLayerSettingsRef settings, const char* name);

void OCCTZLayerSettingsSetDepthTest(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetDepthTest(OCCTZLayerSettingsRef settings);
void OCCTZLayerSettingsSetDepthWrite(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetDepthWrite(OCCTZLayerSettingsRef settings);
void OCCTZLayerSettingsSetClearDepth(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetClearDepth(OCCTZLayerSettingsRef settings);

/// Set polygon offset: mode (0=Off,1=Fill,2=Line,4=Point,7=All), factor, units
void OCCTZLayerSettingsSetPolygonOffset(OCCTZLayerSettingsRef settings, int32_t mode, float factor, float units);
void OCCTZLayerSettingsGetPolygonOffset(OCCTZLayerSettingsRef settings, int32_t* mode, float* factor, float* units);

/// Convenience: set minimal positive depth offset (factor=1, units=1)
void OCCTZLayerSettingsSetDepthOffsetPositive(OCCTZLayerSettingsRef settings);
/// Convenience: set minimal negative depth offset (factor=1, units=-1)
void OCCTZLayerSettingsSetDepthOffsetNegative(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetImmediate(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetImmediate(OCCTZLayerSettingsRef settings);
void OCCTZLayerSettingsSetRaytracable(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetRaytracable(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetEnvironmentTexture(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetEnvironmentTexture(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetRenderInDepthPrepass(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetRenderInDepthPrepass(OCCTZLayerSettingsRef settings);

/// Set culling distance (set to negative or zero to disable)
void OCCTZLayerSettingsSetCullingDistance(OCCTZLayerSettingsRef settings, double distance);
double OCCTZLayerSettingsGetCullingDistance(OCCTZLayerSettingsRef settings);

/// Set culling size (set to negative or zero to disable)
void OCCTZLayerSettingsSetCullingSize(OCCTZLayerSettingsRef settings, double size);
double OCCTZLayerSettingsGetCullingSize(OCCTZLayerSettingsRef settings);

/// Set layer origin (for coordinate precision in large scenes)
void OCCTZLayerSettingsSetOrigin(OCCTZLayerSettingsRef settings, double x, double y, double z);
void OCCTZLayerSettingsGetOrigin(OCCTZLayerSettingsRef settings, double* x, double* y, double* z);

// MARK: - v0.81.0: Visualization — Quantity_Color, Quantity_ColorRGBA, Graphic3d_MaterialAspect, Graphic3d_PBRMaterial

// --- Quantity_Color ---

/// HLS color components
typedef struct {
    double hue;
    double lightness;
    double saturation;
} OCCTColorHLS;

/// CIE Lab color components
typedef struct {
    double l;
    double a;
    double b;
} OCCTColorLab;

/// Create color from named color string (e.g., "RED", "BLUE")
/// Returns false if name not recognized
bool OCCTColorFromName(const char *_Nonnull name,
                       double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB);

/// Create color from hex string (e.g., "#FF0000")
/// Returns false if parse fails
bool OCCTColorFromHex(const char *_Nonnull hex,
                      double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB);

/// Convert linear RGB color to hex string. Caller must free returned string with OCCTGeomToolsFreeString.
const char *_Nullable OCCTColorToHex(double r, double g, double b, bool useSRGB);

/// Euclidean distance between two colors in linear RGB space
double OCCTColorDistance(double r1, double g1, double b1,
                         double r2, double g2, double b2);

/// Square distance between two colors in linear RGB space
double OCCTColorSquareDistance(double r1, double g1, double b1,
                                double r2, double g2, double b2);

/// CIE DeltaE2000 perceptual color difference
double OCCTColorDeltaE2000(double r1, double g1, double b1,
                            double r2, double g2, double b2);

/// Convert linear RGB to HLS
OCCTColorHLS OCCTColorToHLS(double r, double g, double b);

/// Create linear RGB color from HLS values
void OCCTColorFromHLS(double h, double l, double s,
                      double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB);

/// Modify color intensity (lightness delta)
void OCCTColorChangeIntensity(double *_Nonnull r, double *_Nonnull g, double *_Nonnull b, double delta);

/// Modify color contrast (saturation percentage delta)
void OCCTColorChangeContrast(double *_Nonnull r, double *_Nonnull g, double *_Nonnull b, double delta);

/// Convert linear RGB to sRGB
void OCCTColorLinearToSRGB(float inR, float inG, float inB,
                            float *_Nonnull outR, float *_Nonnull outG, float *_Nonnull outB);

/// Convert sRGB to linear RGB
void OCCTColorSRGBToLinear(float inR, float inG, float inB,
                            float *_Nonnull outR, float *_Nonnull outG, float *_Nonnull outB);

/// Convert linear RGB to CIE Lab
OCCTColorLab OCCTColorToLab(double r, double g, double b);

/// Get string name for a named color index (0-based)
const char *_Nullable OCCTColorStringName(int index);

/// Color comparison epsilon
double OCCTColorEpsilon(void);

// --- Quantity_ColorRGBA ---

/// Create RGBA color from hex string with alpha (e.g., "#FF000080")
bool OCCTColorRGBAFromHex(const char *_Nonnull hex,
                           double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB,
                           double *_Nonnull outA);

/// Convert RGBA color to hex string (with alpha). Caller must free with OCCTGeomToolsFreeString.
const char *_Nullable OCCTColorRGBAToHex(double r, double g, double b, double a, bool useSRGB);

// --- Graphic3d_MaterialAspect ---

/// Material properties struct
typedef struct {
    double ambientR, ambientG, ambientB;
    double diffuseR, diffuseG, diffuseB;
    double specularR, specularG, specularB;
    double emissiveR, emissiveG, emissiveB;
    float transparency;
    float shininess;
    float refractionIndex;
    bool isPhysic;  // true = PHYSIC, false = ASPECT
    // PBR properties
    float pbrMetallic;
    float pbrRoughness;
    float pbrIOR;
    float pbrAlpha;
    float pbrEmissionR, pbrEmissionG, pbrEmissionB;
} OCCTMaterialProperties;

/// Number of predefined materials
int OCCTMaterialNumberOfMaterials(void);

/// Get name of predefined material by 1-based index. Caller must free with OCCTGeomToolsFreeString.
const char *_Nullable OCCTMaterialName(int index);

/// Get properties of a predefined material by name
bool OCCTMaterialFromName(const char *_Nonnull name, OCCTMaterialProperties *_Nonnull outProps);

/// Get properties of a predefined material by 1-based index
bool OCCTMaterialFromIndex(int index, OCCTMaterialProperties *_Nonnull outProps);

// --- Graphic3d_PBRMaterial ---

/// Minimum roughness value
float OCCTMaterialMinRoughness(void);

/// Compute roughness from specular color and shininess
float OCCTMaterialRoughnessFromSpecular(double specR, double specG, double specB, double shininess);

/// Compute metallic factor from specular color
float OCCTMaterialMetallicFromSpecular(double specR, double specG, double specB);

// MARK: - v0.82.0: Quantity_Period, Quantity_Date, Font_FontMgr, Image_AlienPixMap

// --- Quantity_Period ---

/// Period components
typedef struct {
    int days;
    int hours;
    int minutes;
    int seconds;
    int milliseconds;
    int microseconds;
} OCCTPeriodComponents;

/// Create a period from days/hours/minutes/seconds/ms/us
/// Returns false if values are invalid
bool OCCTPeriodCreate(int dd, int hh, int mn, int ss, int mis, int mics,
                      int *_Nonnull outSec, int *_Nonnull outUSec);

/// Create a period from total seconds and microseconds
/// Returns false if values are invalid
bool OCCTPeriodCreateFromSeconds(int ss, int mics,
                                  int *_Nonnull outSec, int *_Nonnull outUSec);

/// Decompose period into components
OCCTPeriodComponents OCCTPeriodValues(int sec, int usec);

/// Get total seconds and microseconds from period
void OCCTPeriodTotalSeconds(int sec, int usec, int *_Nonnull outSec, int *_Nonnull outUSec);

/// Add two periods
void OCCTPeriodAdd(int sec1, int usec1, int sec2, int usec2,
                    int *_Nonnull outSec, int *_Nonnull outUSec);

/// Subtract period2 from period1
void OCCTPeriodSubtract(int sec1, int usec1, int sec2, int usec2,
                         int *_Nonnull outSec, int *_Nonnull outUSec);

/// Compare two periods: returns -1 (shorter), 0 (equal), 1 (longer)
int OCCTPeriodCompare(int sec1, int usec1, int sec2, int usec2);

/// Check if period values are valid
bool OCCTPeriodIsValid(int dd, int hh, int mn, int ss, int mis, int mics);

/// Check if period seconds are valid
bool OCCTPeriodIsValidSeconds(int ss, int mics);

// --- Quantity_Date ---

/// Date components
typedef struct {
    int month;
    int day;
    int year;
    int hour;
    int minute;
    int second;
    int millisecond;
    int microsecond;
} OCCTDateComponents;

/// Create a date and return its internal representation
/// Returns false if date is invalid
bool OCCTDateCreate(int mm, int dd, int yyyy, int hh, int mn, int ss, int mis, int mics,
                     int *_Nonnull outSec, int *_Nonnull outUSec);

/// Get default date (Jan 1, 1979)
void OCCTDateDefault(int *_Nonnull outSec, int *_Nonnull outUSec);

/// Decompose date into components
OCCTDateComponents OCCTDateValues(int sec, int usec);

/// Add period to date
void OCCTDateAddPeriod(int dateSec, int dateUSec, int periodSec, int periodUSec,
                        int *_Nonnull outSec, int *_Nonnull outUSec);

/// Subtract period from date
bool OCCTDateSubtractPeriod(int dateSec, int dateUSec, int periodSec, int periodUSec,
                             int *_Nonnull outSec, int *_Nonnull outUSec);

/// Difference between two dates (returns period)
void OCCTDateDifference(int sec1, int usec1, int sec2, int usec2,
                         int *_Nonnull outPeriodSec, int *_Nonnull outPeriodUSec);

/// Compare two dates: returns -1 (earlier), 0 (equal), 1 (later)
int OCCTDateCompare(int sec1, int usec1, int sec2, int usec2);

/// Check if date is valid
bool OCCTDateIsValid(int mm, int dd, int yyyy, int hh, int mn, int ss, int mis, int mics);

/// Check if year is a leap year
bool OCCTDateIsLeap(int year);

// --- Font_FontMgr ---

/// Initialize the system font database
void OCCTFontMgrInitDatabase(void);

/// Get number of available fonts
int OCCTFontMgrFontCount(void);

/// Get font name by 0-based index. Caller must free with OCCTGeomToolsFreeString.
const char *_Nullable OCCTFontMgrFontName(int index);

/// Get font path for a given font index and aspect (0=Regular, 1=Bold, 2=Italic, 3=BoldItalic)
/// Caller must free with OCCTGeomToolsFreeString.
const char *_Nullable OCCTFontMgrFontPath(int index, int aspect);

/// Check if font has a given aspect (0=Regular, 1=Bold, 2=Italic, 3=BoldItalic)
bool OCCTFontMgrFontHasAspect(int index, int aspect);

/// Get font aspect as string ("regular", "bold", "italic", "bold-italic")
const char *_Nonnull OCCTFontMgrAspectToString(int aspect);

/// Create an empty image
OCCTImageRef OCCTImageCreate(void);

/// Release image
void OCCTImageRelease(OCCTImageRef ref);

/// Initialize image with given format and dimensions
/// format: 0=Gray, 1=Alpha, 2=RGB, 3=BGR, 4=RGB32, 5=BGR32, 6=RGBA, 7=BGRA
bool OCCTImageInitTrash(OCCTImageRef ref, int format, int width, int height);

/// Copy image from another
bool OCCTImageInitCopy(OCCTImageRef dst, OCCTImageRef src);

/// Clear image data
void OCCTImageClear(OCCTImageRef ref);

/// Get image width
int OCCTImageWidth(OCCTImageRef ref);

/// Get image height
int OCCTImageHeight(OCCTImageRef ref);

/// Get image format
int OCCTImageFormat(OCCTImageRef ref);

/// Check if image is empty
bool OCCTImageIsEmpty(OCCTImageRef ref);

/// Get pixel color (RGBA) at coordinates
void OCCTImageGetPixel(OCCTImageRef ref, int x, int y,
                        float *_Nonnull r, float *_Nonnull g, float *_Nonnull b, float *_Nonnull a);

/// Set pixel color (RGBA) at coordinates
void OCCTImageSetPixel(OCCTImageRef ref, int x, int y, float r, float g, float b, float a);

/// Save image to file (format determined by extension)
bool OCCTImageSave(OCCTImageRef ref, const char *_Nonnull filePath);

/// Load image from file
bool OCCTImageLoad(OCCTImageRef ref, const char *_Nonnull filePath);

/// Apply gamma correction
bool OCCTImageAdjustGamma(OCCTImageRef ref, double gamma);

/// Get size of a single pixel in bytes for a given format
int OCCTImageSizePixelBytes(int format);

/// Check if top-down is default row order
bool OCCTImageIsTopDownDefault(void);

// --- Quantity_Color named color count ---

/// Get the total number of named colors in OCCT.
int32_t OCCTNamedColorCount(void);

#endif /* OCCTBridge_Visualization_h */
