//
//  OCCTBridge_Visualization_Presentation.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Visualization.mm (#1380): Prs3d_Drawer/Presentation,
//  PrsMgr_PresentationManager, drawer-aware mesh extraction, SelectMgr_* selector wrappers --
//  default_bucket. Public C surface unchanged; every sibling file imports the same headers this one
//  does (the shared preamble below). No symbol changes, pure file move -- see
//  Scripts/repro/396-bridge-mm-split/ for how.
//

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

// Additional includes gathered from throughout the original file (#1380):
#include <Quantity_ColorRGBA.hxx>
#include <Quantity_NameOfColor.hxx>
#include <Quantity_TypeOfColor.hxx>
#include <Graphic3d_MaterialAspect.hxx>
#include <Graphic3d_NameOfMaterial.hxx>
#include <Graphic3d_TypeOfMaterial.hxx>
#include <Graphic3d_PBRMaterial.hxx>
#include <Quantity_Period.hxx>
#include <Quantity_Date.hxx>
#include <Font_FontMgr.hxx>
#include <Font_SystemFont.hxx>
#include <Font_FontAspect.hxx>
#include <Image_AlienPixMap.hxx>
#include <Image_Format.hxx>

// Shared private structs/helpers (#1380): every split file gets this identical block,
// compiled independently per TU -- see this split's own README for why.

struct OCCTCamera
{
  Handle(Graphic3d_Camera) camera;

  OCCTCamera()
  {
    camera = new Graphic3d_Camera();
    camera->SetZeroToOneDepth(Standard_True);
  }
};

// Map selection mode integers to TopAbs_ShapeEnum:
// 0=SHAPE, 1=VERTEX, 2=EDGE, 3=WIRE, 4=FACE
static TopAbs_ShapeEnum OCCTModeToShapeEnum(Standard_Integer mode)
{
  switch (mode)
  {
    case 1:
      return TopAbs_VERTEX;
    case 2:
      return TopAbs_EDGE;
    case 3:
      return TopAbs_WIRE;
    case 4:
      return TopAbs_FACE;
    default:
      return TopAbs_SHAPE;
  }
}

class OCCTBRepSelectable : public SelectMgr_SelectableObject
{
  DEFINE_STANDARD_RTTI_INLINE(OCCTBRepSelectable, SelectMgr_SelectableObject)
public:
  OCCTBRepSelectable(const TopoDS_Shape& shape)
      : myShape(shape)
  {
  }

  const TopoDS_Shape& Shape() const { return myShape; }

private:
  void Compute(const Handle(PrsMgr_PresentationManager)&,
               const Handle(Prs3d_Presentation)&,
               const Standard_Integer) override
  {
  }

  void ComputeSelection(const Handle(SelectMgr_Selection)& sel,
                        const Standard_Integer             mode) override
  {
    TopAbs_ShapeEnum type = OCCTModeToShapeEnum(mode);
    StdSelect_BRepSelectionTool::Load(sel, this, myShape, type, 0.05, 0.5, Standard_True);
  }

  TopoDS_Shape myShape;
};

// Subclass to expose the protected TraverseSensitives method so we can
// pick with a camera directly, bypassing the V3d_View requirement.
class OCCTHeadlessSelector : public SelectMgr_ViewerSelector
{
  DEFINE_STANDARD_RTTI_INLINE(OCCTHeadlessSelector, SelectMgr_ViewerSelector)
public:
  OCCTHeadlessSelector()
      : SelectMgr_ViewerSelector()
  {
  }

  void PickPoint(double                          pixelX,
                 double                          pixelY,
                 const Handle(Graphic3d_Camera)& cam,
                 int                             width,
                 int                             height)
  {
    SelectMgr_SelectingVolumeManager& mgr = GetManager();
    mgr.InitPointSelectingVolume(gp_Pnt2d(pixelX, pixelY));
    mgr.SetCamera(cam);
    mgr.SetWindowSize(width, height);
    mgr.SetPixelTolerance(PixelTolerance());
    mgr.BuildSelectingVolume();
    TraverseSensitives();
  }

  void PickBox(double                          xMin,
               double                          yMin,
               double                          xMax,
               double                          yMax,
               const Handle(Graphic3d_Camera)& cam,
               int                             width,
               int                             height)
  {
    SelectMgr_SelectingVolumeManager& mgr = GetManager();
    mgr.InitBoxSelectingVolume(gp_Pnt2d(xMin, yMin), gp_Pnt2d(xMax, yMax));
    mgr.SetCamera(cam);
    mgr.SetWindowSize(width, height);
    mgr.SetPixelTolerance(PixelTolerance());
    mgr.BuildSelectingVolume();
    TraverseSensitives();
  }

  void PickPoly(const TColgp_Array1OfPnt2d&     polyPoints,
                const Handle(Graphic3d_Camera)& cam,
                int                             width,
                int                             height)
  {
    SelectMgr_SelectingVolumeManager& mgr = GetManager();
    mgr.InitPolylineSelectingVolume(polyPoints);
    mgr.SetCamera(cam);
    mgr.SetWindowSize(width, height);
    mgr.SetPixelTolerance(PixelTolerance());
    mgr.BuildSelectingVolume();
    TraverseSensitives();
  }
};

struct OCCTSelector
{
  Handle(OCCTHeadlessSelector)                             selector;
  Handle(SelectMgr_SelectionManager)                       selMgr;
  NCollection_DataMap<int32_t, Handle(OCCTBRepSelectable)> objects;

  OCCTSelector()
  {
    selector = new OCCTHeadlessSelector();
    selMgr   = new SelectMgr_SelectionManager(selector);
  }
};

static int32_t OCCTSelectorCollectResults(OCCTSelectorRef sel,
                                          OCCTPickResult* out,
                                          int32_t         maxResults)
{
  int32_t count = 0;
  for (int i = 1; i <= sel->selector->NbPicked() && count < maxResults; i++)
  {
    Handle(SelectMgr_EntityOwner) owner = sel->selector->Picked(i);
    if (owner.IsNull())
      continue;

    Handle(OCCTBRepSelectable) selectable =
      Handle(OCCTBRepSelectable)::DownCast(owner->Selectable());
    if (selectable.IsNull())
      continue;

    int32_t foundId = -1;
    for (NCollection_DataMap<int32_t, Handle(OCCTBRepSelectable)>::Iterator it(sel->objects);
         it.More();
         it.Next())
    {
      if (it.Value() == selectable)
      {
        foundId = it.Key();
        break;
      }
    }
    if (foundId < 0)
      continue;

    const SelectMgr_SortCriterion& criterion = sel->selector->PickedData(i);

    out[count].shapeId = foundId;
    out[count].depth   = criterion.Depth;
    out[count].pointX  = criterion.Point.X();
    out[count].pointY  = criterion.Point.Y();
    out[count].pointZ  = criterion.Point.Z();

    // Extract sub-shape information from BRepOwner
    out[count].subShapeType  = static_cast<int32_t>(TopAbs_SHAPE);
    out[count].subShapeIndex = -1;

    Handle(StdSelect_BRepOwner) brepOwner = Handle(StdSelect_BRepOwner)::DownCast(owner);
    if (!brepOwner.IsNull() && brepOwner->HasShape())
    {
      const TopoDS_Shape& subShape = brepOwner->Shape();
      out[count].subShapeType      = static_cast<int32_t>(subShape.ShapeType());

      // #541: a picked sub-shape's index is 0-based, so it can be handed straight to
      // OCCTShapeGetFaceAtIndex / GetSubShapeByTypeIndex. It used to be 1-based with 0
      // meaning "the whole shape", which both misaddressed every pick by one and made
      // the sentinel indistinguishable from a hit on sub-shape 0; the sentinel is -1 now.
      if (brepOwner->ComesFromDecomposition())
      {
        TopTools_IndexedMapOfShape map;
        TopExp::MapShapes(selectable->Shape(), subShape.ShapeType(), map);
        int idx                  = map.FindIndex(subShape);
        out[count].subShapeIndex = (idx > 0) ? idx - 1 : -1;
      }
    }

    count++;
  }
  return count;
}

struct OCCTDrawer
{
  Handle(Prs3d_Drawer) drawer;

  OCCTDrawer() { drawer = new Prs3d_Drawer(); }
};

static double OCCTDrawerGetEffectiveDeflection(OCCTDrawerRef drawer)
{
  if (!drawer)
    return 0.1;
  if (drawer->drawer->TypeOfDeflection() == Aspect_TOD_RELATIVE)
  {
    return drawer->drawer->DeviationCoefficient();
  }
  else
  {
    return drawer->drawer->MaximalChordialDeviation();
  }
}

struct OCCTClipPlane
{
  Handle(Graphic3d_ClipPlane) plane;
};

struct OCCTZLayerSettings
{
  Graphic3d_ZLayerSettings settings;
};

static void fillMaterialProps(const Graphic3d_MaterialAspect& mat, OCCTMaterialProperties* props)
{
  Quantity_Color ac      = mat.AmbientColor();
  props->ambientR        = ac.Red();
  props->ambientG        = ac.Green();
  props->ambientB        = ac.Blue();
  Quantity_Color dc      = mat.DiffuseColor();
  props->diffuseR        = dc.Red();
  props->diffuseG        = dc.Green();
  props->diffuseB        = dc.Blue();
  Quantity_Color sc      = mat.SpecularColor();
  props->specularR       = sc.Red();
  props->specularG       = sc.Green();
  props->specularB       = sc.Blue();
  Quantity_Color ec      = mat.EmissiveColor();
  props->emissiveR       = ec.Red();
  props->emissiveG       = ec.Green();
  props->emissiveB       = ec.Blue();
  props->transparency    = mat.Transparency();
  props->shininess       = mat.Shininess();
  props->refractionIndex = mat.RefractionIndex();
  props->isPhysic        = (mat.MaterialType() == Graphic3d_MATERIAL_PHYSIC);
  // PBR
  Graphic3d_PBRMaterial pbr  = mat.PBRMaterial();
  props->pbrMetallic         = pbr.Metallic();
  props->pbrRoughness        = pbr.Roughness();
  props->pbrIOR              = pbr.IOR();
  props->pbrAlpha            = pbr.Alpha();
  NCollection_Vec3<float> em = pbr.Emission();
  props->pbrEmissionR        = em.x();
  props->pbrEmissionG        = em.y();
  props->pbrEmissionB        = em.z();
}

static NCollection_List<Handle(Font_SystemFont)> g_fontList;

static bool g_fontListPopulated = false;

// Caller must hold fontListMutex().
static void ensureFontListLocked()
{
  if (!g_fontListPopulated)
  {
    Handle(Font_FontMgr) mgr = Font_FontMgr::GetInstance();
    mgr->InitFontDataBase();
    g_fontList          = mgr->GetAvailableFonts();
    g_fontListPopulated = true;
  }
}

struct OCCTImage
{
  Handle(Image_AlienPixMap) image;
};

bool OCCTShapeGetShadedMesh(OCCTShapeRef shape, double deflection, OCCTShadedMeshData* out)
{
  if (!shape || !out)
    return false;

  out->vertices      = nullptr;
  out->vertexCount   = 0;
  out->indices       = nullptr;
  out->triangleCount = 0;

  try
  {
    BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
    mesher.Perform();

    // First pass: count vertices and triangles
    int32_t totalVerts = 0;
    int32_t totalTris  = 0;

    for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next())
    {
      TopoDS_Face                face = TopoDS::Face(faceExp.Current());
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
      if (tri.IsNull())
        continue;
      totalVerts += tri->NbNodes();
      totalTris += tri->NbTriangles();
    }

    if (totalVerts == 0 || totalTris == 0)
      return false;

    // Allocate buffers: interleaved position + normal (6 floats per vertex)
    out->vertices = (float*)malloc(totalVerts * 6 * sizeof(float));
    out->indices  = (int32_t*)malloc(totalTris * 3 * sizeof(int32_t));
    if (!out->vertices || !out->indices)
    {
      free(out->vertices);
      free(out->indices);
      out->vertices = nullptr;
      out->indices  = nullptr;
      return false;
    }

    int32_t vertexOffset = 0;
    int32_t triOffset    = 0;

    for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next())
    {
      TopoDS_Face                face = TopoDS::Face(faceExp.Current());
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
      if (tri.IsNull())
        continue;

      gp_Trsf transform;
      if (!loc.IsIdentity())
      {
        transform = loc.Transformation();
      }

      bool reversed   = (face.Orientation() == TopAbs_REVERSED);
      bool hasNormals = tri->HasNormals();

      // Write vertex positions and normals
      for (int i = 1; i <= tri->NbNodes(); i++)
      {
        gp_Pnt node = tri->Node(i);
        if (!loc.IsIdentity())
          node.Transform(transform);

        float* vPtr = out->vertices + (vertexOffset + i - 1) * 6;
        vPtr[0]     = (float)node.X();
        vPtr[1]     = (float)node.Y();
        vPtr[2]     = (float)node.Z();

        if (hasNormals)
        {
          gp_Dir normal = tri->Normal(i);
          if (!loc.IsIdentity())
            normal.Transform(transform);
          if (reversed)
            normal.Reverse();
          vPtr[3] = (float)normal.X();
          vPtr[4] = (float)normal.Y();
          vPtr[5] = (float)normal.Z();
        }
        else
        {
          vPtr[3] = 0;
          vPtr[4] = 0;
          vPtr[5] = 0;
        }
      }

      // Compute normals from triangles if not available
      if (!hasNormals)
      {
        for (int i = 1; i <= tri->NbTriangles(); i++)
        {
          int n1, n2, n3;
          tri->Triangle(i).Get(n1, n2, n3);
          if (reversed)
            std::swap(n2, n3);

          gp_Pnt p1 = tri->Node(n1), p2 = tri->Node(n2), p3 = tri->Node(n3);
          if (!loc.IsIdentity())
          {
            p1.Transform(transform);
            p2.Transform(transform);
            p3.Transform(transform);
          }

          gp_Vec v1(p1, p2), v2(p1, p3);
          gp_Vec fn  = v1.Crossed(v2);
          double mag = fn.Magnitude();
          if (mag > 1e-10)
          {
            fn.Divide(mag);
            for (int idx : {n1, n2, n3})
            {
              float* nPtr = out->vertices + (vertexOffset + idx - 1) * 6 + 3;
              nPtr[0] += (float)fn.X();
              nPtr[1] += (float)fn.Y();
              nPtr[2] += (float)fn.Z();
            }
          }
        }
        // Normalize accumulated normals
        for (int i = 0; i < tri->NbNodes(); i++)
        {
          float* nPtr = out->vertices + (vertexOffset + i) * 6 + 3;
          float  len  = sqrtf(nPtr[0] * nPtr[0] + nPtr[1] * nPtr[1] + nPtr[2] * nPtr[2]);
          if (len > 1e-6f)
          {
            nPtr[0] /= len;
            nPtr[1] /= len;
            nPtr[2] /= len;
          }
        }
      }

      // Triangle indices
      for (int i = 1; i <= tri->NbTriangles(); i++)
      {
        int n1, n2, n3;
        tri->Triangle(i).Get(n1, n2, n3);
        if (reversed)
          std::swap(n2, n3);

        int32_t* tPtr = out->indices + triOffset * 3;
        tPtr[0]       = vertexOffset + n1 - 1;
        tPtr[1]       = vertexOffset + n2 - 1;
        tPtr[2]       = vertexOffset + n3 - 1;
        triOffset++;
      }

      vertexOffset += tri->NbNodes();
    }

    out->vertexCount   = totalVerts;
    out->triangleCount = totalTris;
    return true;
  }
  catch (...)
  {
    free(out->vertices);
    free(out->indices);
    out->vertices      = nullptr;
    out->indices       = nullptr;
    out->vertexCount   = 0;
    out->triangleCount = 0;
    return false;
  }
}

void OCCTShadedMeshDataFree(OCCTShadedMeshData* data)
{
  if (!data)
    return;
  free(data->vertices);
  free(data->indices);
  data->vertices      = nullptr;
  data->indices       = nullptr;
  data->vertexCount   = 0;
  data->triangleCount = 0;
}

bool OCCTShapeGetEdgeMesh(OCCTShapeRef shape, double deflection, OCCTEdgeMeshData* out)
{
  if (!shape || !out)
    return false;

  out->vertices      = nullptr;
  out->vertexCount   = 0;
  out->segmentStarts = nullptr;
  out->segmentCount  = 0;

  try
  {
    BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
    mesher.Perform();

    std::vector<float>   allVerts;
    std::vector<int32_t> segStarts;

    // Use indexed map to get unique edges (TopExp_Explorer visits each edge
    // once per adjacent face, causing duplicates)
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

    for (int ei = 1; ei <= edgeMap.Extent(); ei++)
    {
      TopoDS_Edge edge          = TopoDS::Edge(edgeMap(ei));
      bool        foundPolyline = false;

      // Try PolygonOnTriangulation first
      for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next())
      {
        TopoDS_Face                face = TopoDS::Face(faceExp.Current());
        TopLoc_Location            loc;
        Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
        if (tri.IsNull())
          continue;

        Handle(Poly_PolygonOnTriangulation) polyOnTri;
        TopLoc_Location                     edgeLoc;
        polyOnTri = BRep_Tool::PolygonOnTriangulation(edge, tri, edgeLoc);
        if (polyOnTri.IsNull())
          continue;

        gp_Trsf transform;
        if (!loc.IsIdentity())
          transform = loc.Transformation();

        const TColStd_Array1OfInteger& nodeIndices = polyOnTri->Nodes();
        if (nodeIndices.Length() < 2)
          continue;

        segStarts.push_back((int32_t)(allVerts.size() / 3));

        for (int i = nodeIndices.Lower(); i <= nodeIndices.Upper(); i++)
        {
          gp_Pnt pt = tri->Node(nodeIndices(i));
          if (!loc.IsIdentity())
            pt.Transform(transform);
          allVerts.push_back((float)pt.X());
          allVerts.push_back((float)pt.Y());
          allVerts.push_back((float)pt.Z());
        }

        foundPolyline = true;
        break;
      }

      if (!foundPolyline)
      {
        // Try Polygon3D
        TopLoc_Location        loc;
        Handle(Poly_Polygon3D) poly3d = BRep_Tool::Polygon3D(edge, loc);
        if (!poly3d.IsNull() && poly3d->NbNodes() >= 2)
        {
          gp_Trsf transform;
          if (!loc.IsIdentity())
            transform = loc.Transformation();

          segStarts.push_back((int32_t)(allVerts.size() / 3));

          for (int i = 1; i <= poly3d->NbNodes(); i++)
          {
            gp_Pnt pt = poly3d->Nodes().Value(i);
            if (!loc.IsIdentity())
              pt.Transform(transform);
            allVerts.push_back((float)pt.X());
            allVerts.push_back((float)pt.Y());
            allVerts.push_back((float)pt.Z());
          }
        }
        else
        {
          // Fall back to curve discretization
          try
          {
            BRepAdaptor_Curve           curve(edge);
            GCPnts_TangentialDeflection disc(curve, deflection, 0.1);
            if (disc.NbPoints() >= 2)
            {
              segStarts.push_back((int32_t)(allVerts.size() / 3));
              for (int i = 1; i <= disc.NbPoints(); i++)
              {
                gp_Pnt pt = disc.Value(i);
                allVerts.push_back((float)pt.X());
                allVerts.push_back((float)pt.Y());
                allVerts.push_back((float)pt.Z());
              }
            }
          }
          catch (...)
          {
          }
        }
      }
    }

    if (allVerts.empty())
      return false;

    int32_t vertCount = (int32_t)(allVerts.size() / 3);
    int32_t segCount  = (int32_t)segStarts.size();

    out->vertices      = (float*)malloc(allVerts.size() * sizeof(float));
    out->segmentStarts = (int32_t*)malloc((segCount + 1) * sizeof(int32_t));
    if (!out->vertices || !out->segmentStarts)
    {
      free(out->vertices);
      free(out->segmentStarts);
      out->vertices      = nullptr;
      out->segmentStarts = nullptr;
      return false;
    }

    memcpy(out->vertices, allVerts.data(), allVerts.size() * sizeof(float));
    memcpy(out->segmentStarts, segStarts.data(), segCount * sizeof(int32_t));
    out->segmentStarts[segCount] = vertCount; // sentinel

    out->vertexCount  = vertCount;
    out->segmentCount = segCount;
    return true;
  }
  catch (...)
  {
    free(out->vertices);
    free(out->segmentStarts);
    out->vertices      = nullptr;
    out->segmentStarts = nullptr;
    out->vertexCount   = 0;
    out->segmentCount  = 0;
    return false;
  }
}

void OCCTEdgeMeshDataFree(OCCTEdgeMeshData* data)
{
  if (!data)
    return;
  free(data->vertices);
  free(data->segmentStarts);
  data->vertices      = nullptr;
  data->segmentStarts = nullptr;
  data->vertexCount   = 0;
  data->segmentCount  = 0;
}

OCCTSelectorRef OCCTSelectorCreate(void)
{
  try
  {
    return new OCCTSelector();
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTSelectorDestroy(OCCTSelectorRef sel)
{
  delete sel;
}

bool OCCTSelectorAddShape(OCCTSelectorRef sel, OCCTShapeRef shape, int32_t shapeId)
{
  if (!sel || !shape)
    return false;
  try
  {
    if (sel->objects.IsBound(shapeId))
    {
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
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSelectorRemoveShape(OCCTSelectorRef sel, int32_t shapeId)
{
  if (!sel)
    return false;
  try
  {
    if (!sel->objects.IsBound(shapeId))
      return false;
    Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
    sel->selMgr->Remove(obj);
    sel->objects.UnBind(shapeId);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTSelectorClear(OCCTSelectorRef sel)
{
  if (!sel)
    return;
  try
  {
    for (NCollection_DataMap<int32_t, Handle(OCCTBRepSelectable)>::Iterator it(sel->objects);
         it.More();
         it.Next())
    {
      sel->selMgr->Remove(it.Value());
    }
    sel->objects.Clear();
  }
  catch (...)
  {
  }
}

void OCCTSelectorActivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode)
{
  if (!sel || !sel->objects.IsBound(shapeId))
    return;
  try
  {
    Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
    sel->selMgr->Activate(obj, mode);
  }
  catch (...)
  {
  }
}

void OCCTSelectorDeactivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode)
{
  if (!sel || !sel->objects.IsBound(shapeId))
    return;
  try
  {
    Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
    sel->selMgr->Deactivate(obj, mode);
  }
  catch (...)
  {
  }
}

bool OCCTSelectorIsModeActive(OCCTSelectorRef sel, int32_t shapeId, int32_t mode)
{
  if (!sel || !sel->objects.IsBound(shapeId))
    return false;
  try
  {
    Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
    return sel->selMgr->IsActivated(obj, mode) == Standard_True;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTSelectorSetPixelTolerance(OCCTSelectorRef sel, int32_t tolerance)
{
  if (!sel)
    return;
  sel->selector->SetPixelTolerance(tolerance);
}

int32_t OCCTSelectorGetPixelTolerance(OCCTSelectorRef sel)
{
  if (!sel)
    return 2;
  Standard_Integer custom = sel->selector->CustomPixelTolerance();
  return custom >= 0 ? custom : 2;
}

OCCTDrawerRef OCCTDrawerCreate(void)
{
  try
  {
    return new OCCTDrawer();
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTDrawerDestroy(OCCTDrawerRef d)
{
  delete d;
}

void OCCTDrawerSetDeviationCoefficient(OCCTDrawerRef d, double coeff)
{
  if (!d)
    return;
  try
  {
    d->drawer->SetDeviationCoefficient(coeff);
  }
  catch (...)
  {
  }
}

double OCCTDrawerGetDeviationCoefficient(OCCTDrawerRef d)
{
  if (!d)
    return 0.001;
  try
  {
    return d->drawer->DeviationCoefficient();
  }
  catch (...)
  {
    return 0.001;
  }
}

void OCCTDrawerSetDeviationAngle(OCCTDrawerRef d, double angle)
{
  if (!d)
    return;
  try
  {
    d->drawer->SetDeviationAngle(angle);
  }
  catch (...)
  {
  }
}

double OCCTDrawerGetDeviationAngle(OCCTDrawerRef d)
{
  if (!d)
    return 20.0 * M_PI / 180.0;
  try
  {
    return d->drawer->DeviationAngle();
  }
  catch (...)
  {
    return 20.0 * M_PI / 180.0;
  }
}

void OCCTDrawerSetMaximalChordialDeviation(OCCTDrawerRef d, double deviation)
{
  if (!d)
    return;
  try
  {
    d->drawer->SetMaximalChordialDeviation(deviation);
  }
  catch (...)
  {
  }
}

double OCCTDrawerGetMaximalChordialDeviation(OCCTDrawerRef d)
{
  if (!d)
    return 0.1;
  try
  {
    return d->drawer->MaximalChordialDeviation();
  }
  catch (...)
  {
    return 0.1;
  }
}

void OCCTDrawerSetTypeOfDeflection(OCCTDrawerRef d, int32_t type)
{
  if (!d)
    return;
  try
  {
    d->drawer->SetTypeOfDeflection(type == 1 ? Aspect_TOD_ABSOLUTE : Aspect_TOD_RELATIVE);
  }
  catch (...)
  {
  }
}

int32_t OCCTDrawerGetTypeOfDeflection(OCCTDrawerRef d)
{
  if (!d)
    return 0;
  try
  {
    return d->drawer->TypeOfDeflection() == Aspect_TOD_ABSOLUTE ? 1 : 0;
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTDrawerSetAutoTriangulation(OCCTDrawerRef d, bool on)
{
  if (!d)
    return;
  try
  {
    d->drawer->SetAutoTriangulation(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTDrawerGetAutoTriangulation(OCCTDrawerRef d)
{
  if (!d)
    return true;
  try
  {
    return d->drawer->IsAutoTriangulation() == Standard_True;
  }
  catch (...)
  {
    return true;
  }
}

void OCCTDrawerSetIsoOnTriangulation(OCCTDrawerRef d, bool on)
{
  if (!d)
    return;
  try
  {
    d->drawer->SetIsoOnTriangulation(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTDrawerGetIsoOnTriangulation(OCCTDrawerRef d)
{
  if (!d)
    return false;
  try
  {
    return d->drawer->IsoOnTriangulation() == Standard_True;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDrawerSetDiscretisation(OCCTDrawerRef d, int32_t value)
{
  if (!d)
    return;
  try
  {
    d->drawer->SetDiscretisation(value);
  }
  catch (...)
  {
  }
}

int32_t OCCTDrawerGetDiscretisation(OCCTDrawerRef d)
{
  if (!d)
    return 30;
  try
  {
    return d->drawer->Discretisation();
  }
  catch (...)
  {
    return 30;
  }
}

void OCCTDrawerSetFaceBoundaryDraw(OCCTDrawerRef d, bool on)
{
  if (!d)
    return;
  try
  {
    d->drawer->SetFaceBoundaryDraw(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTDrawerGetFaceBoundaryDraw(OCCTDrawerRef d)
{
  if (!d)
    return false;
  try
  {
    return d->drawer->FaceBoundaryDraw() == Standard_True;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDrawerSetWireDraw(OCCTDrawerRef d, bool on)
{
  if (!d)
    return;
  try
  {
    d->drawer->SetWireDraw(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTDrawerGetWireDraw(OCCTDrawerRef d)
{
  if (!d)
    return true;
  try
  {
    return d->drawer->WireDraw() == Standard_True;
  }
  catch (...)
  {
    return true;
  }
}

bool OCCTShapeGetShadedMeshWithDrawer(OCCTShapeRef        shape,
                                      OCCTDrawerRef       drawer,
                                      OCCTShadedMeshData* out)
{
  if (!shape || !drawer || !out)
    return false;
  double deflection = OCCTDrawerGetEffectiveDeflection(drawer);
  double angle      = drawer->drawer->DeviationAngle();

  out->vertices      = nullptr;
  out->vertexCount   = 0;
  out->indices       = nullptr;
  out->triangleCount = 0;

  try
  {
    BRepMesh_IncrementalMesh mesher(shape->shape, deflection, Standard_False, angle);
    mesher.Perform();

    return OCCTShapeGetShadedMesh(shape, deflection, out);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeGetEdgeMeshWithDrawer(OCCTShapeRef shape, OCCTDrawerRef drawer, OCCTEdgeMeshData* out)
{
  if (!shape || !drawer || !out)
    return false;
  double deflection = OCCTDrawerGetEffectiveDeflection(drawer);
  double angle      = drawer->drawer->DeviationAngle();

  out->vertices      = nullptr;
  out->vertexCount   = 0;
  out->segmentStarts = nullptr;
  out->segmentCount  = 0;

  try
  {
    BRepMesh_IncrementalMesh mesher(shape->shape, deflection, Standard_False, angle);
    mesher.Perform();

    return OCCTShapeGetEdgeMesh(shape, deflection, out);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDateDefault(int* outSec, int* outUSec)
{
  *outSec  = 0;
  *outUSec = 0;
}

int OCCTDateCompare(int sec1, int usec1, int sec2, int usec2)
{
  if (sec1 < sec2)
    return -1;
  if (sec1 > sec2)
    return 1;
  if (usec1 < usec2)
    return -1;
  if (usec1 > usec2)
    return 1;
  return 0;
}

// #361: g_fontList/g_fontListPopulated are shared process-wide with no internal
// synchronization, and OCCTFontMgrInitDatabase() can reassign both at any time —
// every access below (population and read) is serialized on fontListMutex().
std::mutex& fontListMutex()
{
  static std::mutex mutex;
  return mutex;
}
