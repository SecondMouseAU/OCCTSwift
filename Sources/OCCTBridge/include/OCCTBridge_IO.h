//
//  OCCTBridge_IO.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the IO domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_IO_h
#define OCCTBridge_IO_h

// MARK: - Export

bool OCCTExportSTL(OCCTShapeRef shape, const char* path, double deflection);
bool OCCTExportSTLWithMode(OCCTShapeRef shape, const char* path, double deflection, bool ascii);
bool OCCTExportSTEP(OCCTShapeRef shape, const char* path);
bool OCCTExportSTEPWithName(OCCTShapeRef shape, const char* path, const char* name);

// MARK: - Import

OCCTShapeRef OCCTImportSTEP(const char* path);

// MARK: - Import progress + cancellation (v0.168.0, issue #98)
//
// Wrapper for OCCT's Message_ProgressIndicator. Pass a non-NULL OCCTImportProgress
// struct to the *Progress entry points to receive progress callbacks during
// STEP/IGES TransferRoots and to request cooperative cancellation.
//
// Lifetime: the OCCTImportProgress* must remain valid for the duration of the
// import call. The bridge does not retain it. userData is passed back unchanged.
//
// Cancellation: if shouldCancel returns true, OCCT stops at the next polling
// boundary. The *Progress entry points return NULL and set *outCancelled=true.
// If the import otherwise fails, NULL is returned and *outCancelled stays false.
//
// Both halves of that hold on every exit path, not only at the bridge's own
// checkpoints (#525): a break during a transfer surfaces as zero transferred
// roots, a null shape, a non-Done status or an exception depending on where it
// lands, and each of those is still reported as a cancellation rather than as a
// failure. One true from shouldCancel is also enough -- it is latched, so a
// caller that answers true once and false afterwards still stops the call.

typedef struct OCCTImportProgress
{
  /// Called as the importer advances. fraction is 0.0...1.0; step is a
  /// human-readable name of the current sub-task (may be NULL or empty).
  void (*_Nullable onProgress)(double fraction,
                               const char* _Nullable step,
                               void* _Nullable userData);

  /// Return true to cooperatively cancel the in-flight import.
  bool (*_Nullable shouldCancel)(void* _Nullable userData);

  /// Opaque pointer passed back to onProgress and shouldCancel.
  void* _Nullable userData;
} OCCTImportProgress;

OCCTShapeRef _Nullable OCCTImportSTEPProgress(const char* _Nonnull path,
                                              const OCCTImportProgress* _Nullable ctx,
                                              bool* _Nullable outCancelled);

OCCTShapeRef _Nullable OCCTImportSTEPRobustProgress(const char* _Nonnull path,
                                                    const OCCTImportProgress* _Nullable ctx,
                                                    bool* _Nullable outCancelled);

OCCTShapeRef _Nullable OCCTImportSTEPWithUnitProgress(const char* _Nonnull path,
                                                      double unitInMeters,
                                                      const OCCTImportProgress* _Nullable ctx,
                                                      bool* _Nullable outCancelled);

OCCTShapeRef _Nullable OCCTImportIGESProgress(const char* _Nonnull path,
                                              const OCCTImportProgress* _Nullable ctx,
                                              bool* _Nullable outCancelled);

OCCTShapeRef _Nullable OCCTImportIGESRobustProgress(const char* _Nonnull path,
                                                    const OCCTImportProgress* _Nullable ctx,
                                                    bool* _Nullable outCancelled);

// MARK: - Mesh + export progress (v0.169.0, follow-up to issue #98)
//
// Same OCCTImportProgress channel, different operations. The struct name is
// kept for ABI compatibility; the OperationProgress / ExportProgress / MeshProgress
// Swift typealiases live in the OCCTSwift module.

/// Run BRepMesh_IncrementalMesh on a shape with optional progress + cancellation.
/// Returns the meshed shape (same handle, mutated in place; new OCCTShape wrapping the
/// same TopoDS_Shape) on success, or nullptr on failure / cancellation. Sets
/// *outCancelled=true on cancellation.
OCCTShapeRef _Nullable OCCTShapeIncrementalMeshProgress(OCCTShapeRef _Nonnull shape,
                                                        double linearDeflection,
                                                        double angularDeflection,
                                                        const OCCTImportProgress* _Nullable ctx,
                                                        bool* _Nullable outCancelled);

/// Export a shape to STEP with optional progress + cancellation.
bool OCCTExportSTEPProgress(OCCTShapeRef _Nonnull shape,
                            const char* _Nonnull path,
                            const OCCTImportProgress* _Nullable ctx,
                            bool* _Nullable outCancelled);

/// Export a shape to STEP with explicit model type + progress.
bool OCCTExportSTEPWithModeProgress(OCCTShapeRef _Nonnull shape,
                                    const char* _Nonnull path,
                                    int32_t modelType,
                                    const OCCTImportProgress* _Nullable ctx,
                                    bool* _Nullable outCancelled);

/// Export a shape to IGES with optional progress + cancellation.
bool OCCTExportIGESProgress(OCCTShapeRef _Nonnull shape,
                            const char* _Nonnull path,
                            const OCCTImportProgress* _Nullable ctx,
                            bool* _Nullable outCancelled);

// Document progress entry points are declared further down (after OCCTDocumentRef typedef).

// MARK: - Robust STEP Import

/// Import result structure with diagnostics
typedef struct
{
  OCCTShapeRef shape;
  int  originalType; // TopAbs_ShapeEnum: 0=Compound, 1=CompSolid, 2=Solid, 3=Shell, 4=Face, etc.
  int  resultType;   // Type after processing
  bool sewingApplied;
  bool solidCreated;
  bool healingApplied;
  int  solidsCreated; // How many shells became solids: >1 means a multibody file (#302)
} OCCTSTEPImportResult;

/// Import STEP file with robust handling: sewing, solid creation, and shape healing
OCCTShapeRef OCCTImportSTEPRobust(const char* path);

/// Import STEP file with diagnostic information
OCCTSTEPImportResult OCCTImportSTEPWithDiagnostics(const char* path);

/// Get shape type (TopAbs_ShapeEnum value)
int OCCTShapeGetType(OCCTShapeRef shape);

/// Check if shape is a valid closed solid
bool OCCTShapeIsValidSolid(OCCTShapeRef shape);

OCCTDocumentRef _Nullable OCCTDocumentLoadSTEPProgress(const char* _Nonnull path,
                                                       const OCCTImportProgress* _Nullable ctx,
                                                       bool* _Nullable outCancelled);

OCCTDocumentRef _Nullable OCCTDocumentLoadSTEPWithModesProgress(
  const char* _Nonnull path,
  bool colorMode,
  bool nameMode,
  bool layerMode,
  bool propsMode,
  bool gdtMode,
  bool matMode,
  const OCCTImportProgress* _Nullable ctx,
  bool* _Nullable outCancelled);

/// Write a Document to STEP with optional progress + cancellation.
bool OCCTDocumentWriteSTEPProgress(OCCTDocumentRef _Nonnull doc,
                                   const char* _Nonnull path,
                                   const OCCTImportProgress* _Nullable ctx,
                                   bool* _Nullable outCancelled);

// MARK: - IGES Import/Export (v0.10.0)

/// Import IGES file
/// @param path Path to IGES file
/// @return Shape reference, or NULL on failure
OCCTShapeRef OCCTImportIGES(const char* path);

/// Import IGES file with automatic repair (sewing, healing)
/// @param path Path to IGES file
/// @return Shape reference with healing applied, or NULL on failure
OCCTShapeRef OCCTImportIGESRobust(const char* path);

/// Export shape to IGES file
/// @param shape The shape to export
/// @param path Output file path
/// @return true on success
bool OCCTExportIGES(OCCTShapeRef shape, const char* path);

// MARK: - BREP Native Format (v0.10.0)

/// Import OCCT native BREP file
/// @param path Path to BREP file
/// @return Shape reference, or NULL on failure
OCCTShapeRef OCCTImportBREP(const char* path);

/// Export shape to OCCT native BREP file
/// @param shape The shape to export
/// @param path Output file path
/// @return true on success
bool OCCTExportBREP(OCCTShapeRef shape, const char* path);

/// Export shape to BREP file with options for triangulation
/// @param shape The shape to export
/// @param path Output file path
/// @param withTriangles Include triangulation data
/// @param withNormals Include normal data (only if withTriangles is true)
/// @return true on success
bool OCCTExportBREPWithTriangles(OCCTShapeRef shape,
                                 const char*  path,
                                 bool         withTriangles,
                                 bool         withNormals);

// MARK: - STL Import (v0.17.0)

/// Import an STL file as a shape (sews faces into a shell/solid)
OCCTShapeRef OCCTImportSTL(const char* path);

/// Import an STL file with robust healing (sew + solid creation + heal)
OCCTShapeRef OCCTImportSTLRobust(const char* path, double sewingTolerance);

// MARK: - OBJ Import/Export (v0.17.0)

/// Import an OBJ file as a shape
OCCTShapeRef OCCTImportOBJ(const char* path);

/// Export a shape to OBJ format
bool OCCTExportOBJ(OCCTShapeRef shape, const char* path, double deflection);

// MARK: - PLY Export (v0.17.0)

/// Export a shape to PLY format (Stanford Polygon Format)
bool OCCTExportPLY(OCCTShapeRef shape, const char* path, double deflection);

// MARK: - STEP Optimization (v0.28.0)

/// Optimize a STEP file by merging duplicate entities.
/// Reads a STEP file, deduplicates geometric entities, and writes the result.
/// @param inputPath Path to input STEP file
/// @param outputPath Path to output STEP file
/// @return true on success
bool OCCTStepTidyOptimize(const char* inputPath, const char* outputPath);

// MARK: - STEP Full Coverage — STEPControl_Writer (v0.58.0)

/// Export shape to STEP with specific model type.
/// modelType: 0=AsIs, 1=ManifoldSolidBrep, 2=BrepWithVoids, 3=FacetedBrep,
///            5=ShellBasedSurfaceModel, 6=GeometricCurveSet
bool OCCTExportSTEPWithMode(OCCTShapeRef shape, const char* path, int32_t modelType);

/// Export shape to STEP with model type and tolerance.
bool OCCTExportSTEPWithModeAndTolerance(OCCTShapeRef shape,
                                        const char*  path,
                                        int32_t      modelType,
                                        double       tolerance);

/// Export shape to STEP and clean duplicate entities before writing.
bool OCCTExportSTEPCleanDuplicates(OCCTShapeRef shape, const char* path, int32_t modelType);

// MARK: - STEP Full Coverage — STEPControl_Reader (v0.58.0)

/// Read a STEP file and return the number of transferable roots.
int32_t OCCTSTEPReaderNbRoots(const char* path);

/// Import a specific root from a STEP file (1-based index).
OCCTShapeRef OCCTImportSTEPRoot(const char* path, int32_t rootIndex);

/// Import a STEP file with a specific system length unit (in meters, e.g. 0.001 for mm).
OCCTShapeRef OCCTImportSTEPWithUnit(const char* path, double unitInMeters);

/// Read a STEP file and return the number of shapes after full transfer.
int32_t OCCTSTEPReaderNbShapes(const char* path);

// MARK: - STEP Full Coverage — STEPCAFControl Modes (v0.58.0)

/// Load STEP file into XDE document with individual mode control.
/// All mode flags: true=enabled, false=disabled.
OCCTDocumentRef OCCTDocumentLoadSTEPWithModes(const char* path,
                                              bool        colorMode,
                                              bool        nameMode,
                                              bool        layerMode,
                                              bool        propsMode,
                                              bool        gdtMode,
                                              bool        matMode);

/// Write XDE document to STEP with model type and individual mode control.
/// modelType: 0=AsIs, 1=ManifoldSolidBrep, etc.
bool OCCTDocumentWriteSTEPWithModes(OCCTDocumentRef doc,
                                    const char*     path,
                                    int32_t         modelType,
                                    bool            colorMode,
                                    bool            nameMode,
                                    bool            layerMode,
                                    bool            dimTolMode,
                                    bool            materialMode);

// MARK: - IGES Full Coverage — Reader (v0.59.0)

/// Read an IGES file and return the number of transferable roots.
int32_t OCCTIGESReaderNbRoots(const char* path);

/// Import a specific root from an IGES file (1-based index).
OCCTShapeRef OCCTImportIGESRoot(const char* path, int32_t rootIndex);

/// Read an IGES file and return the number of shapes after full transfer.
int32_t OCCTIGESReaderNbShapes(const char* path);

/// Import only visible entities from an IGES file.
OCCTShapeRef OCCTImportIGESVisible(const char* path);

// MARK: - IGES Full Coverage — Writer (v0.59.0)

/// Export shape to IGES with specific unit. unit: "MM", "IN", "M", "FT", etc.
bool OCCTExportIGESWithUnit(OCCTShapeRef shape, const char* path, const char* unit);

/// Export shape to IGES in BRep mode (vs default Faces mode).
bool OCCTExportIGESBRepMode(OCCTShapeRef shape, const char* path);

/// Export multiple shapes to a single IGES file.
bool OCCTExportIGESMultiShape(const OCCTShapeRef* shapes, int32_t count, const char* path);

// MARK: - OBJ Document I/O (v0.59.0)

/// Load an OBJ file into an XDE document (preserves materials, names).
OCCTDocumentRef OCCTDocumentLoadOBJ(const char* path);

/// Load an OBJ file into an XDE document with options.
/// singlePrecision: true for float, false for double vertex coords.
/// systemLengthUnit: length unit in meters (e.g. 0.001 for mm). 0 = default.
OCCTDocumentRef OCCTDocumentLoadOBJWithOptions(const char* path,
                                               bool        singlePrecision,
                                               double      systemLengthUnit);

/// Write an XDE document to OBJ format.
/// deflection: mesh deflection for tessellation. 0 = skip re-meshing.
bool OCCTDocumentWriteOBJ(OCCTDocumentRef doc, const char* path, double deflection);

// MARK: - PLY Export Expansion (v0.59.0)

/// Export an XDE document to PLY format with options.
bool OCCTDocumentWritePLY(OCCTDocumentRef doc,
                          const char*     path,
                          double          deflection,
                          bool            normals,
                          bool            colors,
                          bool            texCoords);

/// Export a shape to PLY format with normals/colors/texCoords options.
bool OCCTExportPLYWithOptions(OCCTShapeRef shape,
                              const char*  path,
                              double       deflection,
                              bool         normals,
                              bool         colors,
                              bool         texCoords);

// MARK: - RWMesh Coordinate System (v0.59.0)

/// Coordinate system enum values:
/// -1=Undefined, 0=posYfwd_posZup (Blender/Zup), 1=negZfwd_posYup (glTF/Yup)

/// Load an OBJ file into an XDE document with coordinate system conversion.
/// inputCS and outputCS: -1=Undefined, 0=Zup/Blender, 1=Yup/glTF
OCCTDocumentRef OCCTDocumentLoadOBJWithCS(const char* path,
                                          int32_t     inputCS,
                                          int32_t     outputCS,
                                          double      inputLengthUnit,
                                          double      outputLengthUnit);

// --- GeomTools_CurveSet: 3D curve collection with persistence ---
/// Serialize a set of 3D curves to string
const char* _Nullable OCCTGeomToolsCurveSetWrite(const OCCTCurve3DRef _Nonnull* _Nonnull curveRefs,
                                                 int count);

/// Deserialize 3D curves from string; returns array count via outCount
OCCTCurve3DRef _Nullable* _Nullable OCCTGeomToolsCurveSetRead(const char* _Nonnull data,
                                                              int* _Nonnull outCount);

/// Free array of curve refs returned by CurveSetRead
void OCCTGeomToolsCurveSetFreeArray(OCCTCurve3DRef _Nullable* _Nullable array, int count);

// --- GeomTools_Curve2dSet: 2D curve collection with persistence ---
/// Serialize a set of 2D curves to string
const char* _Nullable OCCTGeomToolsCurve2dSetWrite(
  const OCCTCurve2DRef _Nonnull* _Nonnull curveRefs,
  int count);

/// Deserialize 2D curves from string
OCCTCurve2DRef _Nullable* _Nullable OCCTGeomToolsCurve2dSetRead(const char* _Nonnull data,
                                                                int* _Nonnull outCount);

/// Free array of curve2d refs
void OCCTGeomToolsCurve2dSetFreeArray(OCCTCurve2DRef _Nullable* _Nullable array, int count);

// --- GeomTools_SurfaceSet: Surface collection with persistence ---
/// Serialize a set of surfaces to string
const char* _Nullable OCCTGeomToolsSurfaceSetWrite(const OCCTSurfaceRef _Nonnull* _Nonnull surfRefs,
                                                   int count);

/// Deserialize surfaces from string
OCCTSurfaceRef _Nullable* _Nullable OCCTGeomToolsSurfaceSetRead(const char* _Nonnull data,
                                                                int* _Nonnull outCount);

/// Free array of surface refs
void OCCTGeomToolsSurfaceSetFreeArray(OCCTSurfaceRef _Nullable* _Nullable array, int count);

/// Free string returned by GeomTools*Write functions
void OCCTGeomToolsFreeString(const char* _Nullable str);

// =============================================================================
// MARK: - v0.84.0: VrmlAPI, TDataStd Directory/Variable/Expression, TDocStd_XLink,
//         XCAFDimTolObjects_Tool, TPrsStd_DriverTable, TObj_Application
// =============================================================================

// --- VrmlAPI_Writer ---

/// VRML representation mode
typedef enum
{
  OCCTVrmlRepresentationShaded    = 0,
  OCCTVrmlRepresentationWireFrame = 1,
  OCCTVrmlRepresentationBoth      = 2
} OCCTVrmlRepresentation;

/// Write a shape to VRML file (version 1 or 2)
bool OCCTVrmlWriteShape(OCCTShapeRef _Nonnull shape,
                        const char* _Nonnull filePath,
                        int    version,
                        double deflection,
                        int    representation);

/// Write an XDE document to VRML file with scale
bool OCCTVrmlWriteDocument(OCCTDocumentRef _Nonnull document,
                           const char* _Nonnull filePath,
                           double scale);

// =============================================================================
// MARK: - v0.85.0: UnitsAPI, BinTools, Message, RWMesh_CoordinateSystemConverter, TDF_IDFilter
// =============================================================================

// --- UnitsAPI ---

/// Convert value between any two units (e.g., "mm" to "m", "deg" to "rad")
double OCCTUnitsAnyToAny(double value, const char* _Nonnull fromUnit, const char* _Nonnull toUnit);

/// Convert value from any unit to SI base unit
double OCCTUnitsAnyToSI(double value, const char* _Nonnull unit);

/// Convert value from SI base unit to any unit
double OCCTUnitsAnyFromSI(double value, const char* _Nonnull unit);

/// Convert value from any unit to local system
double OCCTUnitsAnyToLS(double value, const char* _Nonnull unit);

/// Convert value from local system to any unit
double OCCTUnitsAnyFromLS(double value, const char* _Nonnull unit);

/// Set local unit system (0=DEFAULT, 1=SI, 2=MDTV)
void OCCTUnitsSetLocalSystem(int system);

/// Get local unit system (0=DEFAULT, 1=SI, 2=MDTV)
int OCCTUnitsGetLocalSystem(void);

// --- BinTools Shape I/O ---

/// Write a shape to binary data, returns data length (caller must free with free())
const void* _Nullable OCCTBinToolsWriteShape(OCCTShapeRef _Nonnull shape, int* _Nonnull outLength);

/// Read a shape from binary data
OCCTShapeRef _Nullable OCCTBinToolsReadShape(const void* _Nonnull data, int length);

/// Write shape to binary file
bool OCCTBinToolsWriteShapeToFile(OCCTShapeRef _Nonnull shape, const char* _Nonnull filePath);

/// Read shape from binary file
OCCTShapeRef _Nullable OCCTBinToolsReadShapeFromFile(const char* _Nonnull filePath);

/// Create a new messenger with default cout printer
OCCTMessengerRef _Nullable OCCTMessengerCreate(void);

/// Release a messenger
void OCCTMessengerRelease(OCCTMessengerRef _Nonnull messenger);

/// Get printer count
int OCCTMessengerPrinterCount(OCCTMessengerRef _Nonnull messenger);

/// Send a message with gravity level (0=Trace, 1=Info, 2=Warning, 3=Alarm, 4=Fail)
void OCCTMessengerSend(OCCTMessengerRef _Nonnull messenger,
                       const char* _Nonnull message,
                       int gravity);

/// Add a file printer to messenger, returns true if added
bool OCCTMessengerAddFilePrinter(OCCTMessengerRef _Nonnull messenger,
                                 const char* _Nonnull filePath,
                                 int gravity);

/// Remove all printers
void OCCTMessengerRemoveAllPrinters(OCCTMessengerRef _Nonnull messenger);

/// Create a new empty report
OCCTReportRef _Nullable OCCTReportCreate(void);

/// Release a report
void OCCTReportRelease(OCCTReportRef _Nonnull report);

/// Set alert limit
void OCCTReportSetLimit(OCCTReportRef _Nonnull report, int limit);

/// Get alert limit
int OCCTReportGetLimit(OCCTReportRef _Nonnull report);

/// Clear all alerts
void OCCTReportClear(OCCTReportRef _Nonnull report);

/// Clear alerts by gravity
void OCCTReportClearByGravity(OCCTReportRef _Nonnull report, int gravity);

/// Dump report to string (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTReportDump(OCCTReportRef _Nonnull report);

/// Dump report by gravity to string (caller must free with OCCTGeomToolsFreeString)
const char* _Nullable OCCTReportDumpByGravity(OCCTReportRef _Nonnull report, int gravity);

/// Create a new timer (stopped).
OCCTTimerRef _Nonnull OCCTTimerCreate(void);

/// Release a timer.
void OCCTTimerRelease(OCCTTimerRef _Nonnull timer);

/// Start the timer.
void OCCTTimerStart(OCCTTimerRef _Nonnull timer);

/// Stop the timer.
void OCCTTimerStop(OCCTTimerRef _Nonnull timer);

/// Reset the timer to zero.
void OCCTTimerReset(OCCTTimerRef _Nonnull timer);

/// Get elapsed wall-clock time in seconds.
double OCCTTimerElapsedTime(OCCTTimerRef _Nonnull timer);

/// Get current wall-clock time in seconds (static).
double OCCTTimerGetWallClockTime(void);

// MARK: - OSD_MemInfo (v0.93.0)

/// Get heap usage in bytes.
int64_t OCCTMemInfoHeapUsage(void);

/// Get working set in bytes.
int64_t OCCTMemInfoWorkingSet(void);

/// Get heap usage in precise MiB.
double OCCTMemInfoHeapUsageMiB(void);

/// Get a full memory info string. Caller must free.
const char* _Nullable OCCTMemInfoString(void);

/// Free a memory info string.
void OCCTMemInfoFreeString(const char* _Nullable str);

// MARK: - OSD_Environment (v0.94.0)

/// Get the value of an environment variable. Caller must free.
const char* _Nullable OCCTEnvironmentGet(const char* _Nonnull name);

/// Set an environment variable. Returns true on success.
bool OCCTEnvironmentSet(const char* _Nonnull name, const char* _Nonnull value);

/// Remove an environment variable.
void OCCTEnvironmentRemove(const char* _Nonnull name);

/// Free an environment string.
void OCCTEnvironmentFreeString(const char* _Nullable str);

// MARK: - OSD_Path (v0.96.0)
//
// The single path-parsing family in the bridge. The TDocStd_PathParser family that used to sit
// alongside it (OCCTPathParserTrek/Name/Extension, v0.90.0) was deleted in #499: it answered the
// same questions in a different string format, and TDocStd_PathParser::Parse() is wrong outright
// for an extension-less path, a dotfile inside a directory, and a dot in a directory name.

/// Parse a path and return the filename (without directory or extension). Caller must free.
const char* _Nullable OCCTOSDPathName(const char* _Nonnull path);

/// Parse a path and return the file extension, leading dot included ("/a/b.step" -> ".step").
/// Caller must free.
const char* _Nullable OCCTOSDPathExtension(const char* _Nonnull path);

/// Parse a path and return the directory in OCCT's *portable* trek syntax, where "/" becomes "|"
/// and ".." becomes "^" ("/home/user/m.step" -> "|home|user|"). This is not a filesystem path;
/// for that, use OCCTOSDPathFolderAndFile. Caller must free.
const char* _Nullable OCCTOSDPathTrek(const char* _Nonnull path);

/// Get the system name (full path). Caller must free.
const char* _Nullable OCCTOSDPathSystemName(const char* _Nonnull path);

/// Split path into folder and filename. Caller must free both.
void OCCTOSDPathFolderAndFile(const char* _Nonnull path,
                              const char* _Nullable* _Nonnull outFolder,
                              const char* _Nullable* _Nonnull outFile);

/// Check if a path is valid.
bool OCCTOSDPathIsValid(const char* _Nonnull path);

/// Check if path is a Unix absolute path.
bool OCCTOSDPathIsUnixPath(const char* _Nonnull path);

/// Check if path is relative.
bool OCCTOSDPathIsRelative(const char* _Nonnull path);

/// Check if path is absolute.
bool OCCTOSDPathIsAbsolute(const char* _Nonnull path);

/// Free an OSD path string.
void OCCTOSDPathFreeString(const char* _Nullable str);

// MARK: - OSD_Chronometer (v0.98.0)

/// Get process CPU time (user + system).
void OCCTGetProcessCPU(double* _Nonnull userSeconds, double* _Nonnull systemSeconds);

/// Get current thread CPU time.
void OCCTGetThreadCPU(double* _Nonnull userSeconds, double* _Nonnull systemSeconds);

// MARK: - OSD_Process (v0.98.0)

/// Get process ID.
int32_t OCCTProcessId(void);

/// Get username. Caller must free.
const char* _Nullable OCCTProcessUserName(void);

/// Get executable path. Caller must free.
const char* _Nullable OCCTProcessExecutablePath(void);

/// Get executable folder. Caller must free.
const char* _Nullable OCCTProcessExecutableFolder(void);

/// Free a process string.
void OCCTProcessFreeString(const char* _Nullable str);

/// Create an OSD_File object for the given path.
OCCTOSDFileRef _Nonnull OCCTFileCreate(const char* _Nonnull path);

/// Create a temporary OSD_File object (path chosen by OCCT).
OCCTOSDFileRef _Nonnull OCCTFileCreateTemporary(void);

/// Release an OSD_File object.
void OCCTFileRelease(OCCTOSDFileRef _Nonnull file);

/// Build (create/truncate) and open the file for reading and writing.
/// @return true on success
bool OCCTFileOpen(OCCTOSDFileRef _Nonnull file);

/// Open an existing file for reading only.
/// @return true on success
bool OCCTFileOpenReadOnly(OCCTOSDFileRef _Nonnull file);

/// Write data to an open file.
/// @param data Pointer to the bytes to write
/// @param length Number of bytes to write
/// @return true on success
bool OCCTFileWrite(OCCTOSDFileRef _Nonnull file, const char* _Nonnull data, int32_t length);

/// Read a line from an open file. Caller must free the returned string.
/// @param bufSize Maximum line buffer size
/// @return Heap-allocated null-terminated string, or NULL on error/EOF
char* _Nullable OCCTFileReadLine(OCCTOSDFileRef _Nonnull file, int32_t bufSize);

/// Read the entire contents of an open file. Caller must free the returned buffer.
/// @param outLength Filled with the number of bytes returned
/// @return Heap-allocated buffer, or NULL on error
char* _Nullable OCCTFileReadAll(OCCTOSDFileRef _Nonnull file, int32_t* _Nonnull outLength);

/// Close the file.
void OCCTFileClose(OCCTOSDFileRef _Nonnull file);

/// Return whether the file is currently open.
bool OCCTFileIsOpen(OCCTOSDFileRef _Nonnull file);

/// Return the size of the file in bytes, or -1 on error.
int64_t OCCTFileSize(OCCTOSDFileRef _Nonnull file);

/// Rewind the file position to the beginning.
void OCCTFileRewind(OCCTOSDFileRef _Nonnull file);

/// Return whether the file position is at the end.
bool OCCTFileIsAtEnd(OCCTOSDFileRef _Nonnull file);

/// Free a string returned by OCCTFileReadLine or OCCTFileReadAll.
void OCCTFileFreeString(char* _Nullable str);

/// Create a STEP header from scratch with the given filename.
OCCTStepHeaderRef _Nullable OCCTStepHeaderCreate(const char* _Nonnull filename);

/// Release a STEP header.
void OCCTStepHeaderRelease(OCCTStepHeaderRef _Nullable header);

/// Check if the header is fully defined.
bool OCCTStepHeaderIsDone(OCCTStepHeaderRef _Nonnull header);

/// Get the file name from the header. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetName(OCCTStepHeaderRef _Nonnull header);

/// Set the file name in the header.
void OCCTStepHeaderSetName(OCCTStepHeaderRef _Nonnull header, const char* _Nonnull name);

/// Get the timestamp. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetTimeStamp(OCCTStepHeaderRef _Nonnull header);

/// Set the timestamp.
void OCCTStepHeaderSetTimeStamp(OCCTStepHeaderRef _Nonnull header, const char* _Nonnull timestamp);

/// Get the first author value. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetAuthor(OCCTStepHeaderRef _Nonnull header);

/// Set the first author value.
void OCCTStepHeaderSetAuthor(OCCTStepHeaderRef _Nonnull header, const char* _Nonnull author);

/// Get the first organization value. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetOrganization(OCCTStepHeaderRef _Nonnull header);

/// Set the first organization value.
void OCCTStepHeaderSetOrganization(OCCTStepHeaderRef _Nonnull header, const char* _Nonnull org);

/// Get the preprocessor version. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetPreprocessorVersion(OCCTStepHeaderRef _Nonnull header);

/// Set the preprocessor version.
void OCCTStepHeaderSetPreprocessorVersion(OCCTStepHeaderRef _Nonnull header,
                                          const char* _Nonnull ppv);

/// Get the originating system. Caller must free() the returned string.
char* _Nullable OCCTStepHeaderGetOriginatingSystem(OCCTStepHeaderRef _Nonnull header);

/// Set the originating system.
void OCCTStepHeaderSetOriginatingSystem(OCCTStepHeaderRef _Nonnull header, const char* _Nonnull os);

/// Create an empty resource manager.
OCCTResourceManagerRef _Nonnull OCCTResourceManagerCreate(void);

/// Release a resource manager.
void OCCTResourceManagerRelease(OCCTResourceManagerRef _Nonnull mgr);

/// Set a string resource.
void OCCTResourceManagerSetString(OCCTResourceManagerRef _Nonnull mgr,
                                  const char* _Nonnull key,
                                  const char* _Nonnull value);

/// Set an integer resource.
void OCCTResourceManagerSetInt(OCCTResourceManagerRef _Nonnull mgr,
                               const char* _Nonnull key,
                               int32_t value);

/// Set a real resource.
void OCCTResourceManagerSetReal(OCCTResourceManagerRef _Nonnull mgr,
                                const char* _Nonnull key,
                                double value);

/// Check if a resource key exists.
bool OCCTResourceManagerFind(OCCTResourceManagerRef _Nonnull mgr, const char* _Nonnull key);

/// Get a string resource value. Caller must free() the returned string.
char* _Nullable OCCTResourceManagerGetString(OCCTResourceManagerRef _Nonnull mgr,
                                             const char* _Nonnull key);

/// Get an integer resource value.
int32_t OCCTResourceManagerGetInt(OCCTResourceManagerRef _Nonnull mgr, const char* _Nonnull key);

/// Get a real resource value.
double OCCTResourceManagerGetReal(OCCTResourceManagerRef _Nonnull mgr, const char* _Nonnull key);

// MARK: - OSD_Host (v0.104.0)

/// Get the hostname. Caller must free() the returned string.
char* _Nullable OCCTHostName(void);

/// Get the OS version string. Caller must free().
char* _Nullable OCCTSystemVersion(void);

/// Get the internet address. Caller must free().
char* _Nullable OCCTInternetAddress(void);
OCCTPerfMeterRef _Nonnull OCCTPerfMeterCreate(const char* _Nonnull name);
void   OCCTPerfMeterRelease(OCCTPerfMeterRef _Nonnull meter);
void   OCCTPerfMeterStart(OCCTPerfMeterRef _Nonnull meter);
void   OCCTPerfMeterStop(OCCTPerfMeterRef _Nonnull meter);
double OCCTPerfMeterElapsed(OCCTPerfMeterRef _Nonnull meter);

// MARK: - OSD_Directory (v0.105.0)

/// Check if a directory exists.
bool OCCTDirectoryExists(const char* _Nonnull path);

/// Create a directory. Returns true on success.
bool OCCTDirectoryCreate(const char* _Nonnull path);

/// Build a temporary directory. Returns path (caller must free).
char* _Nullable OCCTDirectoryBuildTemporary(void);

/// Remove a directory. Returns true on success.
bool OCCTDirectoryRemove(const char* _Nonnull path);

// MARK: - Resource_Unicode (v0.105.0)

/// Set the Resource_Unicode format. 0=SJIS, 1=EUC, 2=GB, 3=ANSI.
void OCCTUnicodeSetFormat(int32_t format);

/// Get the current Resource_Unicode format.
int32_t OCCTUnicodeGetFormat(void);

/// Convert a string from current format to UTF-8. Returns allocated string (caller must free).
char* _Nullable OCCTUnicodeConvertToUnicode(const char* _Nonnull input);

/// Convert from UTF-8 to current format.
/// @param utf8Input The UTF-8 string to convert
/// @param output Output buffer for the converted string (may be NULL if maxSize is 0)
/// @param maxSize Maximum length of the output buffer (use 0 with NULL output to query length)
/// @return Length of the converted string in bytes (not counting the NUL terminator), or -1 on
/// failure.
///         If output is non-NULL and maxSize > 0, the buffer receives a NUL-terminated copy
///         truncated to maxSize-1 bytes. A return value >= maxSize indicates truncation occurred.
int32_t OCCTUnicodeConvertFromUnicode(const char* _Nonnull utf8Input,
                                      char* _Nullable output,
                                      int32_t maxSize);

// MARK: - OSD_DirectoryIterator (v0.106.0)

/// Count directories matching a mask in a path.
int32_t OCCTDirectoryIteratorCount(const char* _Nonnull path, const char* _Nonnull mask);

/// Get directory name at index from directory listing. Caller must free returned string.
char* _Nullable OCCTDirectoryIteratorName(const char* _Nonnull path,
                                          const char* _Nonnull mask,
                                          int32_t index);

/// List directory names matching mask. Returns count of entries written. names array must be
/// pre-allocated.
int32_t OCCTDirectoryList(const char* _Nonnull path,
                          const char* _Nonnull mask,
                          char* _Nullable* _Nonnull names,
                          int32_t maxCount);

// MARK: - OSD_FileIterator (v0.106.0)

/// Count files matching a mask in a path.
int32_t OCCTFileIteratorCount(const char* _Nonnull path, const char* _Nonnull mask);

/// Get file name at index from file listing. Caller must free returned string.
char* _Nullable OCCTFileIteratorName(const char* _Nonnull path,
                                     const char* _Nonnull mask,
                                     int32_t index);

/// List file names matching mask. Returns count of entries written. names array must be
/// pre-allocated.
int32_t OCCTFileList(const char* _Nonnull path,
                     const char* _Nonnull mask,
                     char* _Nullable* _Nonnull names,
                     int32_t maxCount);

// MARK: - OSD_Disk (v0.109.0)

/// Get disk total size in KB for path (0 if unavailable).
int64_t OCCTDiskSize(const char* _Nonnull path);

/// Get disk free space in KB for path (0 if unavailable).
int64_t OCCTDiskFree(const char* _Nonnull path);

/// Check if a disk path is valid/accessible.
bool OCCTDiskIsValid(const char* _Nonnull path);

/// Get the disk/volume name. Caller must free() the result.
char* _Nullable OCCTDiskName(const char* _Nonnull path);

/// Create a shared library handle by name/path.
OCCTSharedLibRef _Nullable OCCTSharedLibCreate(const char* _Nonnull name);

/// Release a shared library handle.
void OCCTSharedLibRelease(OCCTSharedLibRef _Nullable lib);

/// Open (dlopen) the shared library.
bool OCCTSharedLibOpen(OCCTSharedLibRef _Nonnull lib);

/// Close (dlclose) the shared library.
void OCCTSharedLibClose(OCCTSharedLibRef _Nonnull lib);

/// Get the name of the shared library. Caller must free() the result.
char* _Nullable OCCTSharedLibName(OCCTSharedLibRef _Nonnull lib);

// MARK: - Message_Msg (v0.109.0)

/// Create a message from a key and return its text. Caller must free() the result.
char* _Nullable OCCTMessageMsgGet(const char* _Nonnull key);

/// Load message definitions from a file.
bool OCCTMessageMsgFileLoad(const char* _Nonnull fileName);

/// Load OCCT's Shape Healing (ShapeFix) diagnostic message set (issue #1422). Always succeeds:
/// the underlying `ShapeExtend::Init()` falls back to a message set compiled into the OCCT
/// static library when the (rarely set) `CSF_SHMessage` environment variable is absent.
bool OCCTMessageMsgFileLoadDefault(void);

/// Check if a message key is registered.
bool OCCTMessageMsgHasMsg(const char* _Nonnull key);

// MARK: - UnitsMethods (v0.117.0)

/// Get length factor value for IGES unit code.
double OCCTUnitsGetLengthFactor(int32_t unit);

/// Get scale factor between two length units.
double OCCTUnitsGetLengthUnitScale(int32_t fromUnit, int32_t toUnit);

/// Get string name for a length unit enum value.
const char* _Nullable OCCTUnitsDumpLengthUnit(int32_t unit);

// MARK: - v0.119.0: BREP serialization, gp distance/contains, BezierSurface, Curve2D Bezier/BSpline
// extras, BSplineSurface extras

// --- BREP string serialization ---

/// Serialize a shape to BREP format string. Caller must free the returned string with free().
char* _Nullable OCCTShapeToBREPString(OCCTShapeRef _Nonnull shape);

/// Deserialize a shape from a BREP format string.
OCCTShapeRef _Nullable OCCTShapeFromBREPString(const char* _Nonnull brepString);

// MARK: - GLTF Import/Export (v0.121.0)

/// Import a GLTF/GLB file as a shape (mesh-based). Returns NULL on failure.
OCCTShapeRef _Nullable OCCTImportGLTF(const char* _Nonnull path);

/// Export a shape to GLTF format. isBinary=true for GLB, false for GLTF.
/// The shape must be meshed first (call mesh() before exporting).
bool OCCTExportGLTF(OCCTShapeRef _Nonnull shape,
                    const char* _Nonnull path,
                    bool   isBinary,
                    double deflection);

/// Load a GLTF/GLB file into an XDE document (preserves names, materials, colors).
OCCTDocumentRef _Nullable OCCTDocumentLoadGLTF(const char* _Nonnull path);

/// Write an XDE document to GLTF/GLB format.
bool OCCTDocumentWriteGLTF(OCCTDocumentRef _Nonnull doc, const char* _Nonnull path, bool isBinary);

#endif /* OCCTBridge_IO_h */
