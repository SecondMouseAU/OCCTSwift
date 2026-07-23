//
//  OCCTBridge_Visualization.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  Visualization cluster (camera, presentation mesh, headless selector,
//  display drawer, drawer-aware mesh extraction, clip plane, z-layer):
//
//  - OCCTCamera: Graphic3d_Camera wrapper with projection + frustum
//    helpers
//  - Presentation mesh: AIS-style triangulation traversal for rendering
//  - Headless selector: SelectMgr_ViewerSelector subclass that runs
//    without a V3d_View (CPU-side ray + frustum picking against
//    BRepSelectable owners)
//  - Display drawer: Prs3d_Drawer wrapper (linewidth, color, deflection)
//  - Drawer-aware mesh extraction: deflection-controlled meshing
//  - Clip planes: Graphic3d_ClipPlane wrapper
//  - Z-layer settings: Graphic3d_ZLayerSettings wrapper
//
//  All five internal struct types (OCCTCamera / OCCTSelector / OCCTDrawer
//  / OCCTClipPlane / OCCTZLayerSettings) plus the SelectMgr subclasses
//  (OCCTBRepSelectable / OCCTHeadlessSelector) live here — they are not
//  referenced from any other TU, so there is no need to lift them into
//  OCCTBridge_Internal.h.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <Bnd_Box.hxx>
#include <Poly_Triangulation.hxx>
#include <Poly_PolygonOnTriangulation.hxx>

#include <Aspect_HatchStyle.hxx>
#include <Aspect_PolygonOffsetMode.hxx>
#include <Aspect_TypeOfDeflection.hxx>

#include <Graphic3d_Camera.hxx>
#include <Graphic3d_ClipPlane.hxx>
#include <Graphic3d_PolygonOffset.hxx>
#include <Graphic3d_Vec3.hxx>
#include <Graphic3d_Vec4.hxx>
#include <Graphic3d_ZLayerSettings.hxx>
#include <Graphic3d_BndBox4f.hxx>
#include <Graphic3d_Mat4.hxx>

#include <Prs3d_Drawer.hxx>
#include <Prs3d_Presentation.hxx>
#include <PrsMgr_PresentationManager.hxx>

#include <SelectMgr_EntityOwner.hxx>
#include <SelectMgr_SelectableObject.hxx>
#include <SelectMgr_SelectingVolumeManager.hxx>
#include <SelectMgr_Selection.hxx>
#include <SelectMgr_SelectionManager.hxx>
#include <SelectMgr_SortCriterion.hxx>
#include <SelectMgr_ViewerSelector.hxx>
#include <StdSelect_BRepOwner.hxx>
#include <StdSelect_BRepSelectionTool.hxx>

#include <Quantity_Color.hxx>

#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <gp_XYZ.hxx>

#include <TColgp_Array1OfPnt2d.hxx>
#include <TColStd_Array1OfInteger.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

// MARK: - Camera Implementation

struct OCCTCamera {
    Handle(Graphic3d_Camera) camera;

    OCCTCamera() {
        camera = new Graphic3d_Camera();
        camera->SetZeroToOneDepth(Standard_True);
    }
};

OCCTCameraRef OCCTCameraCreate(void) {
    try {
        return new OCCTCamera();
    } catch (...) {
        return nullptr;
    }
}

void OCCTCameraDestroy(OCCTCameraRef cam) {
    delete cam;
}

void OCCTCameraSetEye(OCCTCameraRef cam, double x, double y, double z) {
    if (!cam) return;
    cam->camera->SetEye(gp_Pnt(x, y, z));
}

void OCCTCameraGetEye(OCCTCameraRef cam, double* x, double* y, double* z) {
    if (!cam || !x || !y || !z) return;
    gp_Pnt eye = cam->camera->Eye();
    *x = eye.X(); *y = eye.Y(); *z = eye.Z();
}

void OCCTCameraSetCenter(OCCTCameraRef cam, double x, double y, double z) {
    if (!cam) return;
    cam->camera->SetCenter(gp_Pnt(x, y, z));
}

void OCCTCameraGetCenter(OCCTCameraRef cam, double* x, double* y, double* z) {
    if (!cam || !x || !y || !z) return;
    gp_Pnt center = cam->camera->Center();
    *x = center.X(); *y = center.Y(); *z = center.Z();
}

void OCCTCameraSetUp(OCCTCameraRef cam, double x, double y, double z) {
    if (!cam) return;
    try { cam->camera->SetUp(gp_Dir(x, y, z)); } catch (...) {}
}

void OCCTCameraGetUp(OCCTCameraRef cam, double* x, double* y, double* z) {
    if (!cam || !x || !y || !z) return;
    gp_Dir up = cam->camera->Up();
    *x = up.X(); *y = up.Y(); *z = up.Z();
}

void OCCTCameraSetProjectionType(OCCTCameraRef cam, int type) {
    if (!cam) return;
    cam->camera->SetProjectionType(
        type == 1 ? Graphic3d_Camera::Projection_Orthographic
                  : Graphic3d_Camera::Projection_Perspective
    );
}

int OCCTCameraGetProjectionType(OCCTCameraRef cam) {
    if (!cam) return 0;
    return cam->camera->ProjectionType() == Graphic3d_Camera::Projection_Orthographic ? 1 : 0;
}

void OCCTCameraSetFOV(OCCTCameraRef cam, double degrees) {
    if (!cam) return;
    cam->camera->SetFOVy(degrees);
}

double OCCTCameraGetFOV(OCCTCameraRef cam) {
    if (!cam) return 45.0;
    return cam->camera->FOVy();
}

void OCCTCameraSetScale(OCCTCameraRef cam, double scale) {
    if (!cam) return;
    cam->camera->SetScale(scale);
}

double OCCTCameraGetScale(OCCTCameraRef cam) {
    if (!cam) return 1.0;
    return cam->camera->Scale();
}

void OCCTCameraSetZRange(OCCTCameraRef cam, double zNear, double zFar) {
    if (!cam) return;
    cam->camera->SetZRange(zNear, zFar);
}

void OCCTCameraGetZRange(OCCTCameraRef cam, double* zNear, double* zFar) {
    if (!cam || !zNear || !zFar) return;
    *zNear = cam->camera->ZNear();
    *zFar = cam->camera->ZFar();
}

void OCCTCameraSetAspect(OCCTCameraRef cam, double aspect) {
    if (!cam) return;
    cam->camera->SetAspect(aspect);
}

double OCCTCameraGetAspect(OCCTCameraRef cam) {
    if (!cam) return 1.0;
    return cam->camera->Aspect();
}

void OCCTCameraGetProjectionMatrix(OCCTCameraRef cam, float* out16) {
    if (!cam || !out16) return;
    const Graphic3d_Mat4& mat = cam->camera->ProjectionMatrixF();
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            out16[j * 4 + i] = mat.GetValue(i, j);
}

void OCCTCameraGetViewMatrix(OCCTCameraRef cam, float* out16) {
    if (!cam || !out16) return;
    const Graphic3d_Mat4& mat = cam->camera->OrientationMatrixF();
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            out16[j * 4 + i] = mat.GetValue(i, j);
}

void OCCTCameraProject(OCCTCameraRef cam, double wX, double wY, double wZ,
                       double* sX, double* sY, double* sZ) {
    if (!cam || !sX || !sY || !sZ) return;
    try {
        gp_Pnt projected = cam->camera->Project(gp_Pnt(wX, wY, wZ));
        *sX = projected.X(); *sY = projected.Y(); *sZ = projected.Z();
    } catch (...) {
        *sX = *sY = *sZ = 0;
    }
}

void OCCTCameraUnproject(OCCTCameraRef cam, double sX, double sY, double sZ,
                         double* wX, double* wY, double* wZ) {
    if (!cam || !wX || !wY || !wZ) return;
    try {
        gp_Pnt unprojected = cam->camera->UnProject(gp_Pnt(sX, sY, sZ));
        *wX = unprojected.X(); *wY = unprojected.Y(); *wZ = unprojected.Z();
    } catch (...) {
        *wX = *wY = *wZ = 0;
    }
}

void OCCTCameraFitBBox(OCCTCameraRef cam, double xMin, double yMin, double zMin,
                       double xMax, double yMax, double zMax) {
    if (!cam) return;
    try {
        Bnd_Box bbox;
        bbox.Update(xMin, yMin, zMin, xMax, yMax, zMax);
        cam->camera->FitMinMax(bbox, 0.01, false);
    } catch (...) {}
}

// MARK: - Presentation Mesh Implementation

bool OCCTShapeGetShadedMesh(OCCTShapeRef shape, double deflection, OCCTShadedMeshData* out) {
    if (!shape || !out) return false;

    out->vertices = nullptr;
    out->vertexCount = 0;
    out->indices = nullptr;
    out->triangleCount = 0;

    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        // First pass: count vertices and triangles
        int32_t totalVerts = 0;
        int32_t totalTris = 0;

        for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next()) {
            TopoDS_Face face = TopoDS::Face(faceExp.Current());
            TopLoc_Location loc;
            Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
            if (tri.IsNull()) continue;
            totalVerts += tri->NbNodes();
            totalTris += tri->NbTriangles();
        }

        if (totalVerts == 0 || totalTris == 0) return false;

        // Allocate buffers: interleaved position + normal (6 floats per vertex)
        out->vertices = (float*)malloc(totalVerts * 6 * sizeof(float));
        out->indices = (int32_t*)malloc(totalTris * 3 * sizeof(int32_t));
        if (!out->vertices || !out->indices) {
            free(out->vertices); free(out->indices);
            out->vertices = nullptr; out->indices = nullptr;
            return false;
        }

        int32_t vertexOffset = 0;
        int32_t triOffset = 0;

        for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next()) {
            TopoDS_Face face = TopoDS::Face(faceExp.Current());
            TopLoc_Location loc;
            Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
            if (tri.IsNull()) continue;

            gp_Trsf transform;
            if (!loc.IsIdentity()) {
                transform = loc.Transformation();
            }

            bool reversed = (face.Orientation() == TopAbs_REVERSED);
            bool hasNormals = tri->HasNormals();

            // Write vertex positions and normals
            for (int i = 1; i <= tri->NbNodes(); i++) {
                gp_Pnt node = tri->Node(i);
                if (!loc.IsIdentity()) node.Transform(transform);

                float* vPtr = out->vertices + (vertexOffset + i - 1) * 6;
                vPtr[0] = (float)node.X();
                vPtr[1] = (float)node.Y();
                vPtr[2] = (float)node.Z();

                if (hasNormals) {
                    gp_Dir normal = tri->Normal(i);
                    if (!loc.IsIdentity()) normal.Transform(transform);
                    if (reversed) normal.Reverse();
                    vPtr[3] = (float)normal.X();
                    vPtr[4] = (float)normal.Y();
                    vPtr[5] = (float)normal.Z();
                } else {
                    vPtr[3] = 0; vPtr[4] = 0; vPtr[5] = 0;
                }
            }

            // Compute normals from triangles if not available
            if (!hasNormals) {
                for (int i = 1; i <= tri->NbTriangles(); i++) {
                    int n1, n2, n3;
                    tri->Triangle(i).Get(n1, n2, n3);
                    if (reversed) std::swap(n2, n3);

                    gp_Pnt p1 = tri->Node(n1), p2 = tri->Node(n2), p3 = tri->Node(n3);
                    if (!loc.IsIdentity()) {
                        p1.Transform(transform); p2.Transform(transform); p3.Transform(transform);
                    }

                    gp_Vec v1(p1, p2), v2(p1, p3);
                    gp_Vec fn = v1.Crossed(v2);
                    double mag = fn.Magnitude();
                    if (mag > 1e-10) {
                        fn.Divide(mag);
                        for (int idx : {n1, n2, n3}) {
                            float* nPtr = out->vertices + (vertexOffset + idx - 1) * 6 + 3;
                            nPtr[0] += (float)fn.X();
                            nPtr[1] += (float)fn.Y();
                            nPtr[2] += (float)fn.Z();
                        }
                    }
                }
                // Normalize accumulated normals
                for (int i = 0; i < tri->NbNodes(); i++) {
                    float* nPtr = out->vertices + (vertexOffset + i) * 6 + 3;
                    float len = sqrtf(nPtr[0]*nPtr[0] + nPtr[1]*nPtr[1] + nPtr[2]*nPtr[2]);
                    if (len > 1e-6f) {
                        nPtr[0] /= len; nPtr[1] /= len; nPtr[2] /= len;
                    }
                }
            }

            // Triangle indices
            for (int i = 1; i <= tri->NbTriangles(); i++) {
                int n1, n2, n3;
                tri->Triangle(i).Get(n1, n2, n3);
                if (reversed) std::swap(n2, n3);

                int32_t* tPtr = out->indices + triOffset * 3;
                tPtr[0] = vertexOffset + n1 - 1;
                tPtr[1] = vertexOffset + n2 - 1;
                tPtr[2] = vertexOffset + n3 - 1;
                triOffset++;
            }

            vertexOffset += tri->NbNodes();
        }

        out->vertexCount = totalVerts;
        out->triangleCount = totalTris;
        return true;
    } catch (...) {
        free(out->vertices); free(out->indices);
        out->vertices = nullptr; out->indices = nullptr;
        out->vertexCount = 0; out->triangleCount = 0;
        return false;
    }
}

void OCCTShadedMeshDataFree(OCCTShadedMeshData* data) {
    if (!data) return;
    free(data->vertices);
    free(data->indices);
    data->vertices = nullptr;
    data->indices = nullptr;
    data->vertexCount = 0;
    data->triangleCount = 0;
}

bool OCCTShapeGetEdgeMesh(OCCTShapeRef shape, double deflection, OCCTEdgeMeshData* out) {
    if (!shape || !out) return false;

    out->vertices = nullptr;
    out->vertexCount = 0;
    out->segmentStarts = nullptr;
    out->segmentCount = 0;

    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        std::vector<float> allVerts;
        std::vector<int32_t> segStarts;

        // Use indexed map to get unique edges (TopExp_Explorer visits each edge
        // once per adjacent face, causing duplicates)
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        for (int ei = 1; ei <= edgeMap.Extent(); ei++) {
            TopoDS_Edge edge = TopoDS::Edge(edgeMap(ei));
            bool foundPolyline = false;

            // Try PolygonOnTriangulation first
            for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next()) {
                TopoDS_Face face = TopoDS::Face(faceExp.Current());
                TopLoc_Location loc;
                Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
                if (tri.IsNull()) continue;

                Handle(Poly_PolygonOnTriangulation) polyOnTri;
                TopLoc_Location edgeLoc;
                polyOnTri = BRep_Tool::PolygonOnTriangulation(edge, tri, edgeLoc);
                if (polyOnTri.IsNull()) continue;

                gp_Trsf transform;
                if (!loc.IsIdentity()) transform = loc.Transformation();

                const TColStd_Array1OfInteger& nodeIndices = polyOnTri->Nodes();
                if (nodeIndices.Length() < 2) continue;

                segStarts.push_back((int32_t)(allVerts.size() / 3));

                for (int i = nodeIndices.Lower(); i <= nodeIndices.Upper(); i++) {
                    gp_Pnt pt = tri->Node(nodeIndices(i));
                    if (!loc.IsIdentity()) pt.Transform(transform);
                    allVerts.push_back((float)pt.X());
                    allVerts.push_back((float)pt.Y());
                    allVerts.push_back((float)pt.Z());
                }

                foundPolyline = true;
                break;
            }

            if (!foundPolyline) {
                // Try Polygon3D
                TopLoc_Location loc;
                Handle(Poly_Polygon3D) poly3d = BRep_Tool::Polygon3D(edge, loc);
                if (!poly3d.IsNull() && poly3d->NbNodes() >= 2) {
                    gp_Trsf transform;
                    if (!loc.IsIdentity()) transform = loc.Transformation();

                    segStarts.push_back((int32_t)(allVerts.size() / 3));

                    for (int i = 1; i <= poly3d->NbNodes(); i++) {
                        gp_Pnt pt = poly3d->Nodes().Value(i);
                        if (!loc.IsIdentity()) pt.Transform(transform);
                        allVerts.push_back((float)pt.X());
                        allVerts.push_back((float)pt.Y());
                        allVerts.push_back((float)pt.Z());
                    }
                } else {
                    // Fall back to curve discretization
                    try {
                        BRepAdaptor_Curve curve(edge);
                        GCPnts_TangentialDeflection disc(curve, deflection, 0.1);
                        if (disc.NbPoints() >= 2) {
                            segStarts.push_back((int32_t)(allVerts.size() / 3));
                            for (int i = 1; i <= disc.NbPoints(); i++) {
                                gp_Pnt pt = disc.Value(i);
                                allVerts.push_back((float)pt.X());
                                allVerts.push_back((float)pt.Y());
                                allVerts.push_back((float)pt.Z());
                            }
                        }
                    } catch (...) {}
                }
            }
        }

        if (allVerts.empty()) return false;

        int32_t vertCount = (int32_t)(allVerts.size() / 3);
        int32_t segCount = (int32_t)segStarts.size();

        out->vertices = (float*)malloc(allVerts.size() * sizeof(float));
        out->segmentStarts = (int32_t*)malloc((segCount + 1) * sizeof(int32_t));
        if (!out->vertices || !out->segmentStarts) {
            free(out->vertices); free(out->segmentStarts);
            out->vertices = nullptr; out->segmentStarts = nullptr;
            return false;
        }

        memcpy(out->vertices, allVerts.data(), allVerts.size() * sizeof(float));
        memcpy(out->segmentStarts, segStarts.data(), segCount * sizeof(int32_t));
        out->segmentStarts[segCount] = vertCount; // sentinel

        out->vertexCount = vertCount;
        out->segmentCount = segCount;
        return true;
    } catch (...) {
        free(out->vertices); free(out->segmentStarts);
        out->vertices = nullptr; out->segmentStarts = nullptr;
        out->vertexCount = 0; out->segmentCount = 0;
        return false;
    }
}

void OCCTEdgeMeshDataFree(OCCTEdgeMeshData* data) {
    if (!data) return;
    free(data->vertices);
    free(data->segmentStarts);
    data->vertices = nullptr;
    data->segmentStarts = nullptr;
    data->vertexCount = 0;
    data->segmentCount = 0;
}

// MARK: - Selector Implementation

// Map selection mode integers to TopAbs_ShapeEnum:
// 0=SHAPE, 1=VERTEX, 2=EDGE, 3=WIRE, 4=FACE
static TopAbs_ShapeEnum OCCTModeToShapeEnum(Standard_Integer mode) {
    switch (mode) {
        case 1: return TopAbs_VERTEX;
        case 2: return TopAbs_EDGE;
        case 3: return TopAbs_WIRE;
        case 4: return TopAbs_FACE;
        default: return TopAbs_SHAPE;
    }
}

class OCCTBRepSelectable : public SelectMgr_SelectableObject {
    DEFINE_STANDARD_RTTI_INLINE(OCCTBRepSelectable, SelectMgr_SelectableObject)
public:
    OCCTBRepSelectable(const TopoDS_Shape& shape) : myShape(shape) {}

    const TopoDS_Shape& Shape() const { return myShape; }

private:
    void Compute(const Handle(PrsMgr_PresentationManager)&,
                 const Handle(Prs3d_Presentation)&,
                 const Standard_Integer) override {}

    void ComputeSelection(const Handle(SelectMgr_Selection)& sel,
                          const Standard_Integer mode) override {
        TopAbs_ShapeEnum type = OCCTModeToShapeEnum(mode);
        StdSelect_BRepSelectionTool::Load(sel, this, myShape,
                                          type, 0.05, 0.5, Standard_True);
    }

    TopoDS_Shape myShape;
};

// Subclass to expose the protected TraverseSensitives method so we can
// pick with a camera directly, bypassing the V3d_View requirement.
class OCCTHeadlessSelector : public SelectMgr_ViewerSelector {
    DEFINE_STANDARD_RTTI_INLINE(OCCTHeadlessSelector, SelectMgr_ViewerSelector)
public:
    OCCTHeadlessSelector() : SelectMgr_ViewerSelector() {}

    void PickPoint(double pixelX, double pixelY,
                   const Handle(Graphic3d_Camera)& cam,
                   int width, int height) {
        SelectMgr_SelectingVolumeManager& mgr = GetManager();
        mgr.InitPointSelectingVolume(gp_Pnt2d(pixelX, pixelY));
        mgr.SetCamera(cam);
        mgr.SetWindowSize(width, height);
        mgr.SetPixelTolerance(PixelTolerance());
        mgr.BuildSelectingVolume();
        TraverseSensitives();
    }

    void PickBox(double xMin, double yMin, double xMax, double yMax,
                 const Handle(Graphic3d_Camera)& cam,
                 int width, int height) {
        SelectMgr_SelectingVolumeManager& mgr = GetManager();
        mgr.InitBoxSelectingVolume(gp_Pnt2d(xMin, yMin), gp_Pnt2d(xMax, yMax));
        mgr.SetCamera(cam);
        mgr.SetWindowSize(width, height);
        mgr.SetPixelTolerance(PixelTolerance());
        mgr.BuildSelectingVolume();
        TraverseSensitives();
    }

    void PickPoly(const TColgp_Array1OfPnt2d& polyPoints,
                  const Handle(Graphic3d_Camera)& cam,
                  int width, int height) {
        SelectMgr_SelectingVolumeManager& mgr = GetManager();
        mgr.InitPolylineSelectingVolume(polyPoints);
        mgr.SetCamera(cam);
        mgr.SetWindowSize(width, height);
        mgr.SetPixelTolerance(PixelTolerance());
        mgr.BuildSelectingVolume();
        TraverseSensitives();
    }
};

struct OCCTSelector {
    Handle(OCCTHeadlessSelector) selector;
    Handle(SelectMgr_SelectionManager) selMgr;
    NCollection_DataMap<int32_t, Handle(OCCTBRepSelectable)> objects;

    OCCTSelector() {
        selector = new OCCTHeadlessSelector();
        selMgr = new SelectMgr_SelectionManager(selector);
    }
};

OCCTSelectorRef OCCTSelectorCreate(void) {
    try {
        return new OCCTSelector();
    } catch (...) {
        return nullptr;
    }
}

void OCCTSelectorDestroy(OCCTSelectorRef sel) {
    delete sel;
}

bool OCCTSelectorAddShape(OCCTSelectorRef sel, OCCTShapeRef shape, int32_t shapeId) {
    if (!sel || !shape) return false;
    try {
        if (sel->objects.IsBound(shapeId)) {
            Handle(OCCTBRepSelectable) old = sel->objects.Find(shapeId);
            sel->selMgr->Remove(old);
            sel->objects.UnBind(shapeId);
        }

        Handle(OCCTBRepSelectable) selectable = new OCCTBRepSelectable(shape->shape);
        sel->objects.Bind(shapeId, selectable);
        // Load and activate mode 0 (whole shape) by default
        sel->selMgr->Load(selectable, 0);
        sel->selMgr->Activate(selectable, 0);
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTSelectorRemoveShape(OCCTSelectorRef sel, int32_t shapeId) {
    if (!sel) return false;
    try {
        if (!sel->objects.IsBound(shapeId)) return false;
        Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
        sel->selMgr->Remove(obj);
        sel->objects.UnBind(shapeId);
        return true;
    } catch (...) {
        return false;
    }
}

void OCCTSelectorClear(OCCTSelectorRef sel) {
    if (!sel) return;
    try {
        for (NCollection_DataMap<int32_t, Handle(OCCTBRepSelectable)>::Iterator it(sel->objects);
             it.More(); it.Next()) {
            sel->selMgr->Remove(it.Value());
        }
        sel->objects.Clear();
    } catch (...) {}
}

void OCCTSelectorActivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode) {
    if (!sel || !sel->objects.IsBound(shapeId)) return;
    try {
        Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
        sel->selMgr->Activate(obj, mode);
    } catch (...) {}
}

void OCCTSelectorDeactivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode) {
    if (!sel || !sel->objects.IsBound(shapeId)) return;
    try {
        Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
        sel->selMgr->Deactivate(obj, mode);
    } catch (...) {}
}

bool OCCTSelectorIsModeActive(OCCTSelectorRef sel, int32_t shapeId, int32_t mode) {
    if (!sel || !sel->objects.IsBound(shapeId)) return false;
    try {
        Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
        return sel->selMgr->IsActivated(obj, mode) == Standard_True;
    } catch (...) {
        return false;
    }
}

void OCCTSelectorSetPixelTolerance(OCCTSelectorRef sel, int32_t tolerance) {
    if (!sel) return;
    sel->selector->SetPixelTolerance(tolerance);
}

int32_t OCCTSelectorGetPixelTolerance(OCCTSelectorRef sel) {
    if (!sel) return 2;
    Standard_Integer custom = sel->selector->CustomPixelTolerance();
    return custom >= 0 ? custom : 2;
}

static int32_t OCCTSelectorCollectResults(OCCTSelectorRef sel, OCCTPickResult* out, int32_t maxResults) {
    int32_t count = 0;
    for (int i = 1; i <= sel->selector->NbPicked() && count < maxResults; i++) {
        Handle(SelectMgr_EntityOwner) owner = sel->selector->Picked(i);
        if (owner.IsNull()) continue;

        Handle(OCCTBRepSelectable) selectable =
            Handle(OCCTBRepSelectable)::DownCast(owner->Selectable());
        if (selectable.IsNull()) continue;

        int32_t foundId = -1;
        for (NCollection_DataMap<int32_t, Handle(OCCTBRepSelectable)>::Iterator it(sel->objects);
             it.More(); it.Next()) {
            if (it.Value() == selectable) {
                foundId = it.Key();
                break;
            }
        }
        if (foundId < 0) continue;

        const SelectMgr_SortCriterion& criterion = sel->selector->PickedData(i);

        out[count].shapeId = foundId;
        out[count].depth = criterion.Depth;
        out[count].pointX = criterion.Point.X();
        out[count].pointY = criterion.Point.Y();
        out[count].pointZ = criterion.Point.Z();

        // Extract sub-shape information from BRepOwner
        out[count].subShapeType = static_cast<int32_t>(TopAbs_SHAPE);
        out[count].subShapeIndex = 0;

        Handle(StdSelect_BRepOwner) brepOwner =
            Handle(StdSelect_BRepOwner)::DownCast(owner);
        if (!brepOwner.IsNull() && brepOwner->HasShape()) {
            const TopoDS_Shape& subShape = brepOwner->Shape();
            out[count].subShapeType = static_cast<int32_t>(subShape.ShapeType());

            // Find 1-based index of sub-shape within parent shape
            if (brepOwner->ComesFromDecomposition()) {
                TopTools_IndexedMapOfShape map;
                TopExp::MapShapes(selectable->Shape(), subShape.ShapeType(), map);
                int idx = map.FindIndex(subShape);
                out[count].subShapeIndex = (idx > 0) ? idx : 0;
            }
        }

        count++;
    }
    return count;
}

int32_t OCCTSelectorPick(OCCTSelectorRef sel, OCCTCameraRef cam,
                         double viewW, double viewH,
                         double pixelX, double pixelY,
                         OCCTPickResult* out, int32_t maxResults) {
    if (!sel || !cam || !out || maxResults <= 0) return 0;
    try {
        Handle(Graphic3d_Camera) pickCam = new Graphic3d_Camera(*cam->camera);
        pickCam->SetAspect(viewW / viewH);

        sel->selector->PickPoint(pixelX, pixelY, pickCam,
                                 (int)viewW, (int)viewH);

        return OCCTSelectorCollectResults(sel, out, maxResults);
    } catch (...) {
        return 0;
    }
}

int32_t OCCTSelectorPickRect(OCCTSelectorRef sel, OCCTCameraRef cam,
                             double viewW, double viewH,
                             double xMin, double yMin, double xMax, double yMax,
                             OCCTPickResult* out, int32_t maxResults) {
    if (!sel || !cam || !out || maxResults <= 0) return 0;
    try {
        Handle(Graphic3d_Camera) pickCam = new Graphic3d_Camera(*cam->camera);
        pickCam->SetAspect(viewW / viewH);

        sel->selector->PickBox(xMin, yMin, xMax, yMax, pickCam,
                               (int)viewW, (int)viewH);

        return OCCTSelectorCollectResults(sel, out, maxResults);
    } catch (...) {
        return 0;
    }
}

int32_t OCCTSelectorPickPoly(OCCTSelectorRef sel, OCCTCameraRef cam,
                             double viewW, double viewH,
                             const double* polyXY, int32_t pointCount,
                             OCCTPickResult* out, int32_t maxResults) {
    if (!sel || !cam || !out || !polyXY || pointCount < 3 || maxResults <= 0) return 0;
    try {
        Handle(Graphic3d_Camera) pickCam = new Graphic3d_Camera(*cam->camera);
        pickCam->SetAspect(viewW / viewH);

        TColgp_Array1OfPnt2d polyPoints(1, pointCount);
        for (int i = 0; i < pointCount; i++) {
            polyPoints.SetValue(i + 1, gp_Pnt2d(polyXY[i * 2], polyXY[i * 2 + 1]));
        }

        sel->selector->PickPoly(polyPoints, pickCam, (int)viewW, (int)viewH);

        return OCCTSelectorCollectResults(sel, out, maxResults);
    } catch (...) {
        return 0;
    }
}

// MARK: - Display Drawer Implementation

struct OCCTDrawer {
    Handle(Prs3d_Drawer) drawer;
    OCCTDrawer() {
        drawer = new Prs3d_Drawer();
    }
};

OCCTDrawerRef OCCTDrawerCreate(void) {
    try {
        return new OCCTDrawer();
    } catch (...) {
        return nullptr;
    }
}

void OCCTDrawerDestroy(OCCTDrawerRef d) {
    delete d;
}

void OCCTDrawerSetDeviationCoefficient(OCCTDrawerRef d, double coeff) {
    if (!d) return;
    try { d->drawer->SetDeviationCoefficient(coeff); } catch (...) {}
}

double OCCTDrawerGetDeviationCoefficient(OCCTDrawerRef d) {
    if (!d) return 0.001;
    try { return d->drawer->DeviationCoefficient(); } catch (...) { return 0.001; }
}

void OCCTDrawerSetDeviationAngle(OCCTDrawerRef d, double angle) {
    if (!d) return;
    try { d->drawer->SetDeviationAngle(angle); } catch (...) {}
}

double OCCTDrawerGetDeviationAngle(OCCTDrawerRef d) {
    if (!d) return 20.0 * M_PI / 180.0;
    try { return d->drawer->DeviationAngle(); } catch (...) { return 20.0 * M_PI / 180.0; }
}

void OCCTDrawerSetMaximalChordialDeviation(OCCTDrawerRef d, double deviation) {
    if (!d) return;
    try { d->drawer->SetMaximalChordialDeviation(deviation); } catch (...) {}
}

double OCCTDrawerGetMaximalChordialDeviation(OCCTDrawerRef d) {
    if (!d) return 0.1;
    try { return d->drawer->MaximalChordialDeviation(); } catch (...) { return 0.1; }
}

void OCCTDrawerSetTypeOfDeflection(OCCTDrawerRef d, int32_t type) {
    if (!d) return;
    try { d->drawer->SetTypeOfDeflection(type == 1 ? Aspect_TOD_ABSOLUTE : Aspect_TOD_RELATIVE); } catch (...) {}
}

int32_t OCCTDrawerGetTypeOfDeflection(OCCTDrawerRef d) {
    if (!d) return 0;
    try { return d->drawer->TypeOfDeflection() == Aspect_TOD_ABSOLUTE ? 1 : 0; } catch (...) { return 0; }
}

void OCCTDrawerSetAutoTriangulation(OCCTDrawerRef d, bool on) {
    if (!d) return;
    try { d->drawer->SetAutoTriangulation(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTDrawerGetAutoTriangulation(OCCTDrawerRef d) {
    if (!d) return true;
    try { return d->drawer->IsAutoTriangulation() == Standard_True; } catch (...) { return true; }
}

void OCCTDrawerSetIsoOnTriangulation(OCCTDrawerRef d, bool on) {
    if (!d) return;
    try { d->drawer->SetIsoOnTriangulation(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTDrawerGetIsoOnTriangulation(OCCTDrawerRef d) {
    if (!d) return false;
    try { return d->drawer->IsoOnTriangulation() == Standard_True; } catch (...) { return false; }
}

void OCCTDrawerSetDiscretisation(OCCTDrawerRef d, int32_t value) {
    if (!d) return;
    try { d->drawer->SetDiscretisation(value); } catch (...) {}
}

int32_t OCCTDrawerGetDiscretisation(OCCTDrawerRef d) {
    if (!d) return 30;
    try { return d->drawer->Discretisation(); } catch (...) { return 30; }
}

void OCCTDrawerSetFaceBoundaryDraw(OCCTDrawerRef d, bool on) {
    if (!d) return;
    try { d->drawer->SetFaceBoundaryDraw(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTDrawerGetFaceBoundaryDraw(OCCTDrawerRef d) {
    if (!d) return false;
    try { return d->drawer->FaceBoundaryDraw() == Standard_True; } catch (...) { return false; }
}

void OCCTDrawerSetWireDraw(OCCTDrawerRef d, bool on) {
    if (!d) return;
    try { d->drawer->SetWireDraw(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTDrawerGetWireDraw(OCCTDrawerRef d) {
    if (!d) return true;
    try { return d->drawer->WireDraw() == Standard_True; } catch (...) { return true; }
}

// MARK: - Drawer-Aware Mesh Extraction

static double OCCTDrawerGetEffectiveDeflection(OCCTDrawerRef drawer) {
    if (!drawer) return 0.1;
    if (drawer->drawer->TypeOfDeflection() == Aspect_TOD_RELATIVE) {
        return drawer->drawer->DeviationCoefficient();
    } else {
        return drawer->drawer->MaximalChordialDeviation();
    }
}

bool OCCTShapeGetShadedMeshWithDrawer(OCCTShapeRef shape, OCCTDrawerRef drawer, OCCTShadedMeshData* out) {
    if (!shape || !drawer || !out) return false;
    double deflection = OCCTDrawerGetEffectiveDeflection(drawer);
    double angle = drawer->drawer->DeviationAngle();

    out->vertices = nullptr;
    out->vertexCount = 0;
    out->indices = nullptr;
    out->triangleCount = 0;

    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection, Standard_False, angle);
        mesher.Perform();

        return OCCTShapeGetShadedMesh(shape, deflection, out);
    } catch (...) {
        return false;
    }
}

bool OCCTShapeGetEdgeMeshWithDrawer(OCCTShapeRef shape, OCCTDrawerRef drawer, OCCTEdgeMeshData* out) {
    if (!shape || !drawer || !out) return false;
    double deflection = OCCTDrawerGetEffectiveDeflection(drawer);
    double angle = drawer->drawer->DeviationAngle();

    out->vertices = nullptr;
    out->vertexCount = 0;
    out->segmentStarts = nullptr;
    out->segmentCount = 0;

    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection, Standard_False, angle);
        mesher.Perform();

        return OCCTShapeGetEdgeMesh(shape, deflection, out);
    } catch (...) {
        return false;
    }
}

// MARK: - Clip Plane Implementation

struct OCCTClipPlane {
    Handle(Graphic3d_ClipPlane) plane;
};

OCCTClipPlaneRef OCCTClipPlaneCreate(double a, double b, double c, double d) {
    try {
        auto* cp = new OCCTClipPlane();
        cp->plane = new Graphic3d_ClipPlane(Graphic3d_Vec4d(a, b, c, d));
        return cp;
    } catch (...) {
        return nullptr;
    }
}

void OCCTClipPlaneDestroy(OCCTClipPlaneRef plane) {
    delete plane;
}

void OCCTClipPlaneSetEquation(OCCTClipPlaneRef plane, double a, double b, double c, double d) {
    if (!plane) return;
    try { plane->plane->SetEquation(Graphic3d_Vec4d(a, b, c, d)); } catch (...) {}
}

void OCCTClipPlaneGetEquation(OCCTClipPlaneRef plane, double* a, double* b, double* c, double* d) {
    if (!plane || !a || !b || !c || !d) return;
    try {
        const Graphic3d_Vec4d& eq = plane->plane->GetEquation();
        *a = eq.x();
        *b = eq.y();
        *c = eq.z();
        *d = eq.w();
    } catch (...) {}
}

void OCCTClipPlaneGetReversedEquation(OCCTClipPlaneRef plane, double* a, double* b, double* c, double* d) {
    if (!plane || !a || !b || !c || !d) return;
    try {
        const Graphic3d_Vec4d& eq = plane->plane->ReversedEquation();
        *a = eq.x();
        *b = eq.y();
        *c = eq.z();
        *d = eq.w();
    } catch (...) {}
}

void OCCTClipPlaneSetOn(OCCTClipPlaneRef plane, bool on) {
    if (!plane) return;
    try { plane->plane->SetOn(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTClipPlaneIsOn(OCCTClipPlaneRef plane) {
    if (!plane) return false;
    try { return plane->plane->IsOn() == Standard_True; } catch (...) { return false; }
}

void OCCTClipPlaneSetCapping(OCCTClipPlaneRef plane, bool on) {
    if (!plane) return;
    try { plane->plane->SetCapping(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTClipPlaneIsCapping(OCCTClipPlaneRef plane) {
    if (!plane) return false;
    try { return plane->plane->IsCapping() == Standard_True; } catch (...) { return false; }
}

void OCCTClipPlaneSetCappingColor(OCCTClipPlaneRef plane, double r, double g, double b) {
    if (!plane) return;
    try { plane->plane->SetCappingColor(Quantity_Color(r, g, b, Quantity_TOC_RGB)); } catch (...) {}
}

void OCCTClipPlaneGetCappingColor(OCCTClipPlaneRef plane, double* r, double* g, double* b) {
    if (!plane || !r || !g || !b) return;
    try {
        // Read InteriorColor directly from the aspect, matching what SetCappingColor writes.
        // CappingColor() may return the material color if material type != MATERIAL_ASPECT.
        Quantity_Color color = plane->plane->CappingAspect()->InteriorColor();
        *r = color.Red();
        *g = color.Green();
        *b = color.Blue();
    } catch (...) {}
}

void OCCTClipPlaneSetCappingHatch(OCCTClipPlaneRef plane, int32_t style) {
    if (!plane) return;
    try { plane->plane->SetCappingHatch(static_cast<Aspect_HatchStyle>(style)); } catch (...) {}
}

int32_t OCCTClipPlaneGetCappingHatch(OCCTClipPlaneRef plane) {
    if (!plane) return 0;
    try { return static_cast<int32_t>(plane->plane->CappingHatch()); } catch (...) { return 0; }
}

void OCCTClipPlaneSetCappingHatchOn(OCCTClipPlaneRef plane, bool on) {
    if (!plane) return;
    try {
        if (on) {
            plane->plane->SetCappingHatchOn();
        } else {
            plane->plane->SetCappingHatchOff();
        }
    } catch (...) {}
}

bool OCCTClipPlaneIsCappingHatchOn(OCCTClipPlaneRef plane) {
    if (!plane) return false;
    try { return plane->plane->IsHatchOn() == Standard_True; } catch (...) { return false; }
}

int32_t OCCTClipPlaneProbePoint(OCCTClipPlaneRef plane, double x, double y, double z) {
    if (!plane) return 0;
    try {
        Graphic3d_Vec4d pt(x, y, z, 1.0);
        Graphic3d_ClipState worst = Graphic3d_ClipState_In;
        for (Handle(Graphic3d_ClipPlane) p = plane->plane; !p.IsNull(); p = p->ChainNextPlane()) {
            Graphic3d_ClipState state = p->ProbePointHalfspace(pt);
            if (state == Graphic3d_ClipState_Out) {
                return static_cast<int32_t>(Graphic3d_ClipState_Out);
            }
            if (state == Graphic3d_ClipState_On) {
                worst = Graphic3d_ClipState_On;
            }
        }
        return static_cast<int32_t>(worst);
    } catch (...) { return 0; }
}

int32_t OCCTClipPlaneProbeBox(OCCTClipPlaneRef plane,
                               double xMin, double yMin, double zMin,
                               double xMax, double yMax, double zMax) {
    if (!plane) return 0;
    try {
        Graphic3d_BndBox3d box;
        box.Add(Graphic3d_Vec3d(xMin, yMin, zMin));
        box.Add(Graphic3d_Vec3d(xMax, yMax, zMax));
        Graphic3d_ClipState worst = Graphic3d_ClipState_In;
        for (Handle(Graphic3d_ClipPlane) p = plane->plane; !p.IsNull(); p = p->ChainNextPlane()) {
            Graphic3d_ClipState state = p->ProbeBoxHalfspace(box);
            if (state == Graphic3d_ClipState_Out) {
                return static_cast<int32_t>(Graphic3d_ClipState_Out);
            }
            if (state == Graphic3d_ClipState_On) {
                worst = Graphic3d_ClipState_On;
            }
        }
        return static_cast<int32_t>(worst);
    } catch (...) { return 0; }
}

void OCCTClipPlaneSetChainNext(OCCTClipPlaneRef plane, OCCTClipPlaneRef next) {
    if (!plane) return;
    try {
        if (next) {
            plane->plane->SetChainNextPlane(next->plane);
        } else {
            plane->plane->SetChainNextPlane(Handle(Graphic3d_ClipPlane)());
        }
    } catch (...) {}
}

int32_t OCCTClipPlaneChainLength(OCCTClipPlaneRef plane) {
    if (!plane) return 0;
    try { return plane->plane->NbChainNextPlanes(); } catch (...) { return 0; }
}

// MARK: - Z-Layer Settings Implementation

struct OCCTZLayerSettings {
    Graphic3d_ZLayerSettings settings;
};

OCCTZLayerSettingsRef OCCTZLayerSettingsCreate(void) {
    try {
        return new OCCTZLayerSettings();
    } catch (...) {
        return nullptr;
    }
}

void OCCTZLayerSettingsDestroy(OCCTZLayerSettingsRef s) {
    delete s;
}

void OCCTZLayerSettingsSetName(OCCTZLayerSettingsRef s, const char* name) {
    if (!s || !name) return;
    try { s->settings.SetName(TCollection_AsciiString(name)); } catch (...) {}
}

void OCCTZLayerSettingsSetDepthTest(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetEnableDepthTest(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetDepthTest(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.ToEnableDepthTest() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetDepthWrite(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetEnableDepthWrite(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetDepthWrite(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.ToEnableDepthWrite() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetClearDepth(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetClearDepth(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetClearDepth(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.ToClearDepth() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetPolygonOffset(OCCTZLayerSettingsRef s, int32_t mode, float factor, float units) {
    if (!s) return;
    try {
        Graphic3d_PolygonOffset offset;
        offset.Mode = static_cast<Aspect_PolygonOffsetMode>(mode);
        offset.Factor = factor;
        offset.Units = units;
        s->settings.SetPolygonOffset(offset);
    } catch (...) {}
}

void OCCTZLayerSettingsGetPolygonOffset(OCCTZLayerSettingsRef s, int32_t* mode, float* factor, float* units) {
    if (!s || !mode || !factor || !units) return;
    try {
        const Graphic3d_PolygonOffset& offset = s->settings.PolygonOffset();
        *mode = static_cast<int32_t>(offset.Mode);
        *factor = offset.Factor;
        *units = offset.Units;
    } catch (...) {}
}

void OCCTZLayerSettingsSetDepthOffsetPositive(OCCTZLayerSettingsRef s) {
    if (!s) return;
    try { s->settings.SetDepthOffsetPositive(); } catch (...) {}
}

void OCCTZLayerSettingsSetDepthOffsetNegative(OCCTZLayerSettingsRef s) {
    if (!s) return;
    try { s->settings.SetDepthOffsetNegative(); } catch (...) {}
}

void OCCTZLayerSettingsSetImmediate(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetImmediate(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetImmediate(OCCTZLayerSettingsRef s) {
    if (!s) return false;
    try { return s->settings.IsImmediate() == Standard_True; } catch (...) { return false; }
}

void OCCTZLayerSettingsSetRaytracable(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetRaytracable(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetRaytracable(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.IsRaytracable() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetEnvironmentTexture(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetEnvironmentTexture(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetEnvironmentTexture(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.UseEnvironmentTexture() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetRenderInDepthPrepass(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetRenderInDepthPrepass(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetRenderInDepthPrepass(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.ToRenderInDepthPrepass() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetCullingDistance(OCCTZLayerSettingsRef s, double distance) {
    if (!s) return;
    try { s->settings.SetCullingDistance(distance); } catch (...) {}
}

double OCCTZLayerSettingsGetCullingDistance(OCCTZLayerSettingsRef s) {
    if (!s) return 0.0;
    try { return s->settings.CullingDistance(); } catch (...) { return 0.0; }
}

void OCCTZLayerSettingsSetCullingSize(OCCTZLayerSettingsRef s, double size) {
    if (!s) return;
    try { s->settings.SetCullingSize(size); } catch (...) {}
}

double OCCTZLayerSettingsGetCullingSize(OCCTZLayerSettingsRef s) {
    if (!s) return 0.0;
    try { return s->settings.CullingSize(); } catch (...) { return 0.0; }
}

void OCCTZLayerSettingsSetOrigin(OCCTZLayerSettingsRef s, double x, double y, double z) {
    if (!s) return;
    try { s->settings.SetOrigin(gp_XYZ(x, y, z)); } catch (...) {}
}

void OCCTZLayerSettingsGetOrigin(OCCTZLayerSettingsRef s, double* x, double* y, double* z) {
    if (!s || !x || !y || !z) return;
    try {
        const gp_XYZ& origin = s->settings.Origin();
        *x = origin.X();
        *y = origin.Y();
        *z = origin.Z();
    } catch (...) {}
}



// MARK: - v0.81-v0.82: Quantity_Color/RGBA, Graphic3d Material+PBR, Quantity_Period/Date, Font_FontMgr, Image_AlienPixMap
// MARK: - v0.81.0: Visualization — Quantity_Color, Quantity_ColorRGBA, Graphic3d_MaterialAspect, Graphic3d_PBRMaterial

#include <Quantity_Color.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <Quantity_NameOfColor.hxx>
#include <Quantity_TypeOfColor.hxx>
#include <Graphic3d_MaterialAspect.hxx>
#include <Graphic3d_NameOfMaterial.hxx>
#include <Graphic3d_TypeOfMaterial.hxx>
#include <Graphic3d_PBRMaterial.hxx>

// --- Quantity_Color ---

bool OCCTColorFromName(const char *_Nonnull name,
                       double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB) {
    try {
        Quantity_Color c;
        if (!Quantity_Color::ColorFromName(name, c)) return false;
        *outR = c.Red();
        *outG = c.Green();
        *outB = c.Blue();
        return true;
    } catch (...) { return false; }
}

bool OCCTColorFromHex(const char *_Nonnull hex,
                      double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB) {
    try {
        Quantity_Color c;
        if (!Quantity_Color::ColorFromHex(hex, c)) return false;
        *outR = c.Red();
        *outG = c.Green();
        *outB = c.Blue();
        return true;
    } catch (...) { return false; }
}

const char *_Nullable OCCTColorToHex(double r, double g, double b, bool useSRGB) {
    try {
        Quantity_Color c(r, g, b, Quantity_TOC_RGB);
        TCollection_AsciiString hex = Quantity_Color::ColorToHex(c, !useSRGB);
        char *result = (char *)malloc(hex.Length() + 1);
        if (!result) return nullptr;
        memcpy(result, hex.ToCString(), hex.Length() + 1);
        return result;
    } catch (...) { return nullptr; }
}

double OCCTColorDistance(double r1, double g1, double b1,
                         double r2, double g2, double b2) {
    try {
        Quantity_Color c1(r1, g1, b1, Quantity_TOC_RGB);
        Quantity_Color c2(r2, g2, b2, Quantity_TOC_RGB);
        return c1.Distance(c2);
    } catch (...) { return -1.0; }
}

double OCCTColorSquareDistance(double r1, double g1, double b1,
                                double r2, double g2, double b2) {
    try {
        Quantity_Color c1(r1, g1, b1, Quantity_TOC_RGB);
        Quantity_Color c2(r2, g2, b2, Quantity_TOC_RGB);
        return c1.SquareDistance(c2);
    } catch (...) { return -1.0; }
}

double OCCTColorDeltaE2000(double r1, double g1, double b1,
                            double r2, double g2, double b2) {
    try {
        Quantity_Color c1(r1, g1, b1, Quantity_TOC_RGB);
        Quantity_Color c2(r2, g2, b2, Quantity_TOC_RGB);
        return c1.DeltaE2000(c2);
    } catch (...) { return -1.0; }
}

OCCTColorHLS OCCTColorToHLS(double r, double g, double b) {
    OCCTColorHLS result = {0, 0, 0};
    try {
        Quantity_Color c(r, g, b, Quantity_TOC_RGB);
        result.hue = c.Hue();
        result.lightness = c.Light();
        result.saturation = c.Saturation();
    } catch (...) {}
    return result;
}

void OCCTColorFromHLS(double h, double l, double s,
                      double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB) {
    try {
        Quantity_Color c(h, l, s, Quantity_TOC_HLS);
        *outR = c.Red();
        *outG = c.Green();
        *outB = c.Blue();
    } catch (...) {
        *outR = 0; *outG = 0; *outB = 0;
    }
}

void OCCTColorChangeIntensity(double *_Nonnull r, double *_Nonnull g, double *_Nonnull b, double delta) {
    try {
        Quantity_Color c(*r, *g, *b, Quantity_TOC_RGB);
        c.ChangeIntensity(delta);
        *r = c.Red();
        *g = c.Green();
        *b = c.Blue();
    } catch (...) {}
}

void OCCTColorChangeContrast(double *_Nonnull r, double *_Nonnull g, double *_Nonnull b, double delta) {
    try {
        Quantity_Color c(*r, *g, *b, Quantity_TOC_RGB);
        c.ChangeContrast(delta);
        *r = c.Red();
        *g = c.Green();
        *b = c.Blue();
    } catch (...) {}
}

void OCCTColorLinearToSRGB(float inR, float inG, float inB,
                            float *_Nonnull outR, float *_Nonnull outG, float *_Nonnull outB) {
    try {
        NCollection_Vec3<float> linear(inR, inG, inB);
        NCollection_Vec3<float> srgb = Quantity_Color::Convert_LinearRGB_To_sRGB(linear);
        *outR = srgb.r();
        *outG = srgb.g();
        *outB = srgb.b();
    } catch (...) {
        *outR = inR; *outG = inG; *outB = inB;
    }
}

void OCCTColorSRGBToLinear(float inR, float inG, float inB,
                            float *_Nonnull outR, float *_Nonnull outG, float *_Nonnull outB) {
    try {
        NCollection_Vec3<float> srgb(inR, inG, inB);
        NCollection_Vec3<float> linear = Quantity_Color::Convert_sRGB_To_LinearRGB(srgb);
        *outR = linear.r();
        *outG = linear.g();
        *outB = linear.b();
    } catch (...) {
        *outR = inR; *outG = inG; *outB = inB;
    }
}

OCCTColorLab OCCTColorToLab(double r, double g, double b) {
    OCCTColorLab result = {0, 0, 0};
    try {
        float fr = (float)r, fg = (float)g, fb = (float)b;
        NCollection_Vec3<float> linear(fr, fg, fb);
        NCollection_Vec3<float> lab = Quantity_Color::Convert_LinearRGB_To_Lab(linear);
        result.l = lab.x();
        result.a = lab.y();
        result.b = lab.z();
    } catch (...) {}
    return result;
}

const char *_Nullable OCCTColorStringName(int index) {
    try {
        if (index < 0 || index >= (int)Quantity_NOC_WHITE + 1) return nullptr;
        TCollection_AsciiString name = Quantity_Color::StringName((Quantity_NameOfColor)index);
        char *result = (char *)malloc(name.Length() + 1);
        if (!result) return nullptr;
        memcpy(result, name.ToCString(), name.Length() + 1);
        return result;
    } catch (...) { return nullptr; }
}

double OCCTColorEpsilon(void) {
    return Quantity_Color::Epsilon();
}

// --- Quantity_ColorRGBA ---

bool OCCTColorRGBAFromHex(const char *_Nonnull hex,
                           double *_Nonnull outR, double *_Nonnull outG, double *_Nonnull outB,
                           double *_Nonnull outA) {
    try {
        Quantity_ColorRGBA c;
        if (!Quantity_ColorRGBA::ColorFromHex(hex, c)) return false;
        *outR = c.GetRGB().Red();
        *outG = c.GetRGB().Green();
        *outB = c.GetRGB().Blue();
        *outA = double(c.Alpha());
        return true;
    } catch (...) { return false; }
}

const char *_Nullable OCCTColorRGBAToHex(double r, double g, double b, double a, bool useSRGB) {
    try {
        Quantity_Color rgb(r, g, b, Quantity_TOC_RGB);
        Quantity_ColorRGBA c(rgb, float(a));
        TCollection_AsciiString hex = Quantity_ColorRGBA::ColorToHex(c, !useSRGB);
        char *result = (char *)malloc(hex.Length() + 1);
        if (!result) return nullptr;
        memcpy(result, hex.ToCString(), hex.Length() + 1);
        return result;
    } catch (...) { return nullptr; }
}

// --- Graphic3d_MaterialAspect ---

static void fillMaterialProps(const Graphic3d_MaterialAspect& mat, OCCTMaterialProperties *props) {
    Quantity_Color ac = mat.AmbientColor();
    props->ambientR = ac.Red(); props->ambientG = ac.Green(); props->ambientB = ac.Blue();
    Quantity_Color dc = mat.DiffuseColor();
    props->diffuseR = dc.Red(); props->diffuseG = dc.Green(); props->diffuseB = dc.Blue();
    Quantity_Color sc = mat.SpecularColor();
    props->specularR = sc.Red(); props->specularG = sc.Green(); props->specularB = sc.Blue();
    Quantity_Color ec = mat.EmissiveColor();
    props->emissiveR = ec.Red(); props->emissiveG = ec.Green(); props->emissiveB = ec.Blue();
    props->transparency = mat.Transparency();
    props->shininess = mat.Shininess();
    props->refractionIndex = mat.RefractionIndex();
    props->isPhysic = (mat.MaterialType() == Graphic3d_MATERIAL_PHYSIC);
    // PBR
    Graphic3d_PBRMaterial pbr = mat.PBRMaterial();
    props->pbrMetallic = pbr.Metallic();
    props->pbrRoughness = pbr.Roughness();
    props->pbrIOR = pbr.IOR();
    props->pbrAlpha = pbr.Alpha();
    NCollection_Vec3<float> em = pbr.Emission();
    props->pbrEmissionR = em.x(); props->pbrEmissionG = em.y(); props->pbrEmissionB = em.z();
}

int OCCTMaterialNumberOfMaterials(void) {
    return Graphic3d_MaterialAspect::NumberOfMaterials();
}

const char *_Nullable OCCTMaterialName(int index) {
    try {
        if (index < 1 || index > Graphic3d_MaterialAspect::NumberOfMaterials()) return nullptr;
        TCollection_AsciiString name = Graphic3d_MaterialAspect::MaterialName(index);
        char *result = (char *)malloc(name.Length() + 1);
        if (!result) return nullptr;
        memcpy(result, name.ToCString(), name.Length() + 1);
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTMaterialFromName(const char *_Nonnull name, OCCTMaterialProperties *_Nonnull outProps) {
    try {
        Graphic3d_NameOfMaterial nom;
        if (!Graphic3d_MaterialAspect::MaterialFromName(name, nom)) return false;
        Graphic3d_MaterialAspect mat(nom);
        fillMaterialProps(mat, outProps);
        return true;
    } catch (...) { return false; }
}

bool OCCTMaterialFromIndex(int index, OCCTMaterialProperties *_Nonnull outProps) {
    try {
        if (index < 1 || index > Graphic3d_MaterialAspect::NumberOfMaterials()) return false;
        // Get name then construct
        Graphic3d_NameOfMaterial nom = (Graphic3d_NameOfMaterial)(index - 1);
        Graphic3d_MaterialAspect mat(nom);
        fillMaterialProps(mat, outProps);
        return true;
    } catch (...) { return false; }
}

// --- Graphic3d_PBRMaterial ---

float OCCTMaterialMinRoughness(void) {
    return Graphic3d_PBRMaterial::MinRoughness();
}

float OCCTMaterialRoughnessFromSpecular(double specR, double specG, double specB, double shininess) {
    try {
        Quantity_Color spec(specR, specG, specB, Quantity_TOC_RGB);
        return Graphic3d_PBRMaterial::RoughnessFromSpecular(spec, shininess);
    } catch (...) { return 0.5f; }
}

float OCCTMaterialMetallicFromSpecular(double specR, double specG, double specB) {
    try {
        Quantity_Color spec(specR, specG, specB, Quantity_TOC_RGB);
        return Graphic3d_PBRMaterial::MetallicFromSpecular(spec);
    } catch (...) { return 0.0f; }
}

// MARK: - v0.82.0: Quantity_Period, Quantity_Date, Font_FontMgr, Image_AlienPixMap

#include <Quantity_Period.hxx>
#include <Quantity_Date.hxx>
#include <Font_FontMgr.hxx>
#include <Font_SystemFont.hxx>
#include <Font_FontAspect.hxx>
#include <Image_AlienPixMap.hxx>
#include <Image_Format.hxx>

// --- Quantity_Period ---

bool OCCTPeriodCreate(int dd, int hh, int mn, int ss, int mis, int mics,
                      int *outSec, int *outUSec) {
    try {
        if (!Quantity_Period::IsValid(dd, hh, mn, ss, mis, mics)) return false;
        Quantity_Period p(dd, hh, mn, ss, mis, mics);
        p.Values(*outSec, *outUSec);
        return true;
    } catch (...) { return false; }
}

bool OCCTPeriodCreateFromSeconds(int ss, int mics, int *outSec, int *outUSec) {
    try {
        if (!Quantity_Period::IsValid(ss, mics)) return false;
        Quantity_Period p(ss, mics);
        p.Values(*outSec, *outUSec);
        return true;
    } catch (...) { return false; }
}

OCCTPeriodComponents OCCTPeriodValues(int sec, int usec) {
    OCCTPeriodComponents result = {0, 0, 0, 0, 0, 0};
    try {
        Quantity_Period p(sec, usec);
        p.Values(result.days, result.hours, result.minutes, result.seconds,
                 result.milliseconds, result.microseconds);
    } catch (...) {}
    return result;
}

void OCCTPeriodTotalSeconds(int sec, int usec, int *outSec, int *outUSec) {
    try {
        Quantity_Period p(sec, usec);
        p.Values(*outSec, *outUSec);
    } catch (...) {
        *outSec = 0; *outUSec = 0;
    }
}

void OCCTPeriodAdd(int sec1, int usec1, int sec2, int usec2, int *outSec, int *outUSec) {
    try {
        Quantity_Period p1(sec1, usec1);
        Quantity_Period p2(sec2, usec2);
        Quantity_Period sum = p1 + p2;
        sum.Values(*outSec, *outUSec);
    } catch (...) {
        *outSec = 0; *outUSec = 0;
    }
}

void OCCTPeriodSubtract(int sec1, int usec1, int sec2, int usec2, int *outSec, int *outUSec) {
    try {
        Quantity_Period p1(sec1, usec1);
        Quantity_Period p2(sec2, usec2);
        Quantity_Period diff = p1 - p2;
        diff.Values(*outSec, *outUSec);
    } catch (...) {
        *outSec = 0; *outUSec = 0;
    }
}

int OCCTPeriodCompare(int sec1, int usec1, int sec2, int usec2) {
    try {
        Quantity_Period p1(sec1, usec1);
        Quantity_Period p2(sec2, usec2);
        if (p1 == p2) return 0;
        if (p1 < p2) return -1;
        return 1;
    } catch (...) { return 0; }
}

bool OCCTPeriodIsValid(int dd, int hh, int mn, int ss, int mis, int mics) {
    return Quantity_Period::IsValid(dd, hh, mn, ss, mis, mics);
}

bool OCCTPeriodIsValidSeconds(int ss, int mics) {
    return Quantity_Period::IsValid(ss, mics);
}

// --- Quantity_Date ---

bool OCCTDateCreate(int mm, int dd, int yyyy, int hh, int mn, int ss, int mis, int mics,
                     int *outSec, int *outUSec) {
    try {
        if (!Quantity_Date::IsValid(mm, dd, yyyy, hh, mn, ss, mis, mics)) return false;
        Quantity_Date d(mm, dd, yyyy, hh, mn, ss, mis, mics);
        // Store as difference from epoch
        Quantity_Date epoch;
        Quantity_Period diff = d.Difference(epoch);
        diff.Values(*outSec, *outUSec);
        // Need to know direction - if d > epoch, sec is positive
        if (d < epoch) { *outSec = -(*outSec); }
        return true;
    } catch (...) { return false; }
}

void OCCTDateDefault(int *outSec, int *outUSec) {
    *outSec = 0;
    *outUSec = 0;
}

OCCTDateComponents OCCTDateValues(int sec, int usec) {
    OCCTDateComponents result = {1, 1, 1979, 0, 0, 0, 0, 0};
    try {
        Quantity_Date epoch;
        if (sec > 0 || (sec == 0 && usec > 0)) {
            Quantity_Period p(sec, usec);
            Quantity_Date d = epoch + p;
            d.Values(result.month, result.day, result.year,
                     result.hour, result.minute, result.second,
                     result.millisecond, result.microsecond);
        }
    } catch (...) {}
    return result;
}

void OCCTDateAddPeriod(int dateSec, int dateUSec, int periodSec, int periodUSec,
                        int *outSec, int *outUSec) {
    try {
        Quantity_Date epoch;
        Quantity_Date d = epoch;
        if (dateSec > 0 || dateUSec > 0) {
            d = epoch + Quantity_Period(dateSec, dateUSec);
        }
        Quantity_Period p(periodSec, periodUSec);
        Quantity_Date result = d + p;
        Quantity_Period diff = result.Difference(epoch);
        diff.Values(*outSec, *outUSec);
    } catch (...) {
        *outSec = 0; *outUSec = 0;
    }
}

bool OCCTDateSubtractPeriod(int dateSec, int dateUSec, int periodSec, int periodUSec,
                             int *outSec, int *outUSec) {
    try {
        Quantity_Date epoch;
        Quantity_Date d = epoch;
        if (dateSec > 0 || dateUSec > 0) {
            d = epoch + Quantity_Period(dateSec, dateUSec);
        }
        Quantity_Period p(periodSec, periodUSec);
        Quantity_Date result = d - p;
        Quantity_Period diff = result.Difference(epoch);
        diff.Values(*outSec, *outUSec);
        return true;
    } catch (...) {
        *outSec = 0; *outUSec = 0;
        return false;
    }
}

void OCCTDateDifference(int sec1, int usec1, int sec2, int usec2,
                         int *outPeriodSec, int *outPeriodUSec) {
    try {
        Quantity_Date epoch;
        Quantity_Date d1 = epoch;
        Quantity_Date d2 = epoch;
        if (sec1 > 0 || usec1 > 0) d1 = epoch + Quantity_Period(sec1, usec1);
        if (sec2 > 0 || usec2 > 0) d2 = epoch + Quantity_Period(sec2, usec2);
        Quantity_Period diff = d1.Difference(d2);
        diff.Values(*outPeriodSec, *outPeriodUSec);
    } catch (...) {
        *outPeriodSec = 0; *outPeriodUSec = 0;
    }
}

int OCCTDateCompare(int sec1, int usec1, int sec2, int usec2) {
    if (sec1 < sec2) return -1;
    if (sec1 > sec2) return 1;
    if (usec1 < usec2) return -1;
    if (usec1 > usec2) return 1;
    return 0;
}

bool OCCTDateIsValid(int mm, int dd, int yyyy, int hh, int mn, int ss, int mis, int mics) {
    return Quantity_Date::IsValid(mm, dd, yyyy, hh, mn, ss, mis, mics);
}

bool OCCTDateIsLeap(int year) {
    return Quantity_Date::IsLeap(year);
}

// --- Font_FontMgr ---

static NCollection_List<Handle(Font_SystemFont)> g_fontList;
static bool g_fontListPopulated = false;

// #361: g_fontList/g_fontListPopulated are shared process-wide with no internal
// synchronization, and OCCTFontMgrInitDatabase() can reassign both at any time —
// every access below (population and read) is serialized on fontListMutex().
std::mutex& fontListMutex() {
    static std::mutex mutex;
    return mutex;
}

// Caller must hold fontListMutex().
static void ensureFontListLocked() {
    if (!g_fontListPopulated) {
        Handle(Font_FontMgr) mgr = Font_FontMgr::GetInstance();
        mgr->InitFontDataBase();
        g_fontList = mgr->GetAvailableFonts();
        g_fontListPopulated = true;
    }
}

void OCCTFontMgrInitDatabase(void) {
    try {
        std::lock_guard<std::mutex> fontLock(fontListMutex());
        Handle(Font_FontMgr) mgr = Font_FontMgr::GetInstance();
        mgr->InitFontDataBase();
        g_fontList = mgr->GetAvailableFonts();
        g_fontListPopulated = true;
    } catch (...) {}
}

int OCCTFontMgrFontCount(void) {
    try {
        std::lock_guard<std::mutex> fontLock(fontListMutex());
        ensureFontListLocked();
        return static_cast<int>(g_fontList.Size());
    } catch (...) { return 0; }
}

const char *_Nullable OCCTFontMgrFontName(int index) {
    try {
        std::lock_guard<std::mutex> fontLock(fontListMutex());
        ensureFontListLocked();
        int i = 0;
        for (auto it = g_fontList.cbegin(); it != g_fontList.cend(); ++it, ++i) {
            if (i == index) {
                TCollection_AsciiString name = (*it)->FontName();
                char *result = (char *)malloc(name.Length() + 1);
                if (!result) return nullptr;
                memcpy(result, name.ToCString(), name.Length() + 1);
                return result;
            }
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

const char *_Nullable OCCTFontMgrFontPath(int index, int aspect) {
    try {
        std::lock_guard<std::mutex> fontLock(fontListMutex());
        ensureFontListLocked();
        if (aspect < 0 || aspect > 3) return nullptr;
        Font_FontAspect fa = (Font_FontAspect)aspect;
        int i = 0;
        for (auto it = g_fontList.cbegin(); it != g_fontList.cend(); ++it, ++i) {
            if (i == index) {
                TCollection_AsciiString path = (*it)->FontPath(fa);
                if (path.IsEmpty()) return nullptr;
                char *result = (char *)malloc(path.Length() + 1);
                if (!result) return nullptr;
                memcpy(result, path.ToCString(), path.Length() + 1);
                return result;
            }
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

bool OCCTFontMgrFontHasAspect(int index, int aspect) {
    try {
        std::lock_guard<std::mutex> fontLock(fontListMutex());
        ensureFontListLocked();
        if (aspect < 0 || aspect > 3) return false;
        Font_FontAspect fa = (Font_FontAspect)aspect;
        int i = 0;
        for (auto it = g_fontList.cbegin(); it != g_fontList.cend(); ++it, ++i) {
            if (i == index) {
                return (*it)->HasFontAspect(fa);
            }
        }
        return false;
    } catch (...) { return false; }
}

const char *_Nonnull OCCTFontMgrAspectToString(int aspect) {
    return Font_FontMgr::FontAspectToString((Font_FontAspect)aspect);
}

// --- Image_AlienPixMap ---

struct OCCTImage {
    Handle(Image_AlienPixMap) image;
};

OCCTImageRef OCCTImageCreate(void) {
    try {
        return (OCCTImageRef)new OCCTImage{new Image_AlienPixMap()};
    } catch (...) { return nullptr; }
}

void OCCTImageRelease(OCCTImageRef ref) {
    delete (OCCTImage *)ref;
}

bool OCCTImageInitTrash(OCCTImageRef ref, int format, int width, int height) {
    if (!ref) return false;
    try {
        OCCTImage *img = (OCCTImage *)ref;
        return img->image->InitTrash((Image_Format)format, width, height);
    } catch (...) { return false; }
}

bool OCCTImageInitCopy(OCCTImageRef dst, OCCTImageRef src) {
    if (!dst || !src) return false;
    try {
        OCCTImage *d = (OCCTImage *)dst;
        OCCTImage *s = (OCCTImage *)src;
        return d->image->InitCopy(*s->image);
    } catch (...) { return false; }
}

void OCCTImageClear(OCCTImageRef ref) {
    if (!ref) return;
    try {
        ((OCCTImage *)ref)->image->Clear();
    } catch (...) {}
}

int OCCTImageWidth(OCCTImageRef ref) {
    if (!ref) return 0;
    return (int)((OCCTImage *)ref)->image->SizeX();
}

int OCCTImageHeight(OCCTImageRef ref) {
    if (!ref) return 0;
    return (int)((OCCTImage *)ref)->image->SizeY();
}

int OCCTImageFormat(OCCTImageRef ref) {
    if (!ref) return 0;
    return (int)((OCCTImage *)ref)->image->Format();
}

bool OCCTImageIsEmpty(OCCTImageRef ref) {
    if (!ref) return true;
    return ((OCCTImage *)ref)->image->IsEmpty();
}

void OCCTImageGetPixel(OCCTImageRef ref, int x, int y,
                        float *r, float *g, float *b, float *a) {
    if (!ref) { *r = 0; *g = 0; *b = 0; *a = 0; return; }
    try {
        Quantity_ColorRGBA c = ((OCCTImage *)ref)->image->PixelColor(x, y);
        *r = (float)c.GetRGB().Red();
        *g = (float)c.GetRGB().Green();
        *b = (float)c.GetRGB().Blue();
        *a = c.Alpha();
    } catch (...) { *r = 0; *g = 0; *b = 0; *a = 0; }
}

void OCCTImageSetPixel(OCCTImageRef ref, int x, int y, float r, float g, float b, float a) {
    if (!ref) return;
    try {
        Quantity_ColorRGBA c(r, g, b, a);
        ((OCCTImage *)ref)->image->SetPixelColor(x, y, c);
    } catch (...) {}
}

bool OCCTImageSave(OCCTImageRef ref, const char *filePath) {
    if (!ref) return false;
    try {
        return ((OCCTImage *)ref)->image->Save(TCollection_AsciiString(filePath));
    } catch (...) { return false; }
}

bool OCCTImageLoad(OCCTImageRef ref, const char *filePath) {
    if (!ref) return false;
    try {
        return ((OCCTImage *)ref)->image->Load(TCollection_AsciiString(filePath));
    } catch (...) { return false; }
}

bool OCCTImageAdjustGamma(OCCTImageRef ref, double gamma) {
    if (!ref) return false;
    try {
        return ((OCCTImage *)ref)->image->AdjustGamma(gamma);
    } catch (...) { return false; }
}

int OCCTImageSizePixelBytes(int format) {
    return (int)Image_PixMap::SizePixelBytes((Image_Format)format);
}

bool OCCTImageIsTopDownDefault(void) {
    return Image_AlienPixMap::IsTopDownDefault();
}

// MARK: - v0.114: Quantity_Color named color count
// --- Quantity_Color named color count ---

int32_t OCCTNamedColorCount() {
    // Quantity_NOC_WHITE is the last named color before Quantity_NOC_NB
    return (int32_t)Quantity_NOC_WHITE + 1;
}
