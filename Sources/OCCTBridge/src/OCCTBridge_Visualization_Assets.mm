//
//  OCCTBridge_Visualization_Assets.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Visualization.mm (#1380): Font_FontMgr, Image_AlienPixMap.
//  Public C surface unchanged; every sibling file imports the same headers this one does
//  (the shared preamble below). No symbol changes, pure file move -- see
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
  Graphic3d_PBRMaterial pbr = mat.PBRMaterial();
  props->pbrMetallic        = pbr.Metallic();
  // #1419: NormalizedRoughness() is the authored [0,1] value; Roughness() remaps it into
  // [MinRoughness,1] for OCCT's own internal calculations, which is not what a caller reading
  // this struct back (e.g. for glTF's roughnessFactor) wants.
  props->pbrRoughness        = pbr.NormalizedRoughness();
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

void OCCTFontMgrInitDatabase(void)
{
  try
  {
    std::lock_guard<std::mutex> fontLock(fontListMutex());
    Handle(Font_FontMgr)        mgr = Font_FontMgr::GetInstance();
    mgr->InitFontDataBase();
    g_fontList          = mgr->GetAvailableFonts();
    g_fontListPopulated = true;
  }
  catch (...)
  {
  }
}

int OCCTFontMgrFontCount(void)
{
  try
  {
    std::lock_guard<std::mutex> fontLock(fontListMutex());
    ensureFontListLocked();
    return static_cast<int>(g_fontList.Size());
  }
  catch (...)
  {
    return 0;
  }
}

const char* _Nullable OCCTFontMgrFontName(int index)
{
  try
  {
    std::lock_guard<std::mutex> fontLock(fontListMutex());
    ensureFontListLocked();
    int i = 0;
    for (auto it = g_fontList.cbegin(); it != g_fontList.cend(); ++it, ++i)
    {
      if (i == index)
      {
        TCollection_AsciiString name   = (*it)->FontName();
        char*                   result = (char*)malloc(name.Length() + 1);
        if (!result)
          return nullptr;
        memcpy(result, name.ToCString(), name.Length() + 1);
        return result;
      }
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

const char* _Nullable OCCTFontMgrFontPath(int index, int aspect)
{
  try
  {
    std::lock_guard<std::mutex> fontLock(fontListMutex());
    ensureFontListLocked();
    if (aspect < 0 || aspect > 3)
      return nullptr;
    Font_FontAspect fa = (Font_FontAspect)aspect;
    int             i  = 0;
    for (auto it = g_fontList.cbegin(); it != g_fontList.cend(); ++it, ++i)
    {
      if (i == index)
      {
        TCollection_AsciiString path = (*it)->FontPath(fa);
        if (path.IsEmpty())
          return nullptr;
        char* result = (char*)malloc(path.Length() + 1);
        if (!result)
          return nullptr;
        memcpy(result, path.ToCString(), path.Length() + 1);
        return result;
      }
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTFontMgrFontHasAspect(int index, int aspect)
{
  try
  {
    std::lock_guard<std::mutex> fontLock(fontListMutex());
    ensureFontListLocked();
    if (aspect < 0 || aspect > 3)
      return false;
    Font_FontAspect fa = (Font_FontAspect)aspect;
    int             i  = 0;
    for (auto it = g_fontList.cbegin(); it != g_fontList.cend(); ++it, ++i)
    {
      if (i == index)
      {
        return (*it)->HasFontAspect(fa);
      }
    }
    return false;
  }
  catch (...)
  {
    return false;
  }
}

const char* _Nonnull OCCTFontMgrAspectToString(int aspect)
{
  return Font_FontMgr::FontAspectToString((Font_FontAspect)aspect);
}

OCCTImageRef OCCTImageCreate(void)
{
  try
  {
    return (OCCTImageRef) new OCCTImage{new Image_AlienPixMap()};
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTImageRelease(OCCTImageRef ref)
{
  delete (OCCTImage*)ref;
}

bool OCCTImageInitTrash(OCCTImageRef ref, int format, int width, int height)
{
  if (!ref)
    return false;
  try
  {
    OCCTImage* img = (OCCTImage*)ref;
    return img->image->InitTrash((Image_Format)format, width, height);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTImageInitCopy(OCCTImageRef dst, OCCTImageRef src)
{
  if (!dst || !src)
    return false;
  try
  {
    OCCTImage* d = (OCCTImage*)dst;
    OCCTImage* s = (OCCTImage*)src;
    return d->image->InitCopy(*s->image);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTImageClear(OCCTImageRef ref)
{
  if (!ref)
    return;
  try
  {
    ((OCCTImage*)ref)->image->Clear();
  }
  catch (...)
  {
  }
}

int OCCTImageWidth(OCCTImageRef ref)
{
  if (!ref)
    return 0;
  return (int)((OCCTImage*)ref)->image->SizeX();
}

int OCCTImageHeight(OCCTImageRef ref)
{
  if (!ref)
    return 0;
  return (int)((OCCTImage*)ref)->image->SizeY();
}

int OCCTImageFormat(OCCTImageRef ref)
{
  if (!ref)
    return 0;
  return (int)((OCCTImage*)ref)->image->Format();
}

bool OCCTImageIsEmpty(OCCTImageRef ref)
{
  if (!ref)
    return true;
  return ((OCCTImage*)ref)->image->IsEmpty();
}

void OCCTImageGetPixel(OCCTImageRef ref, int x, int y, float* r, float* g, float* b, float* a)
{
  if (!ref)
  {
    *r = 0;
    *g = 0;
    *b = 0;
    *a = 0;
    return;
  }
  try
  {
    Quantity_ColorRGBA c = ((OCCTImage*)ref)->image->PixelColor(x, y);
    *r                   = (float)c.GetRGB().Red();
    *g                   = (float)c.GetRGB().Green();
    *b                   = (float)c.GetRGB().Blue();
    *a                   = c.Alpha();
  }
  catch (...)
  {
    *r = 0;
    *g = 0;
    *b = 0;
    *a = 0;
  }
}

void OCCTImageSetPixel(OCCTImageRef ref, int x, int y, float r, float g, float b, float a)
{
  if (!ref)
    return;
  try
  {
    Quantity_ColorRGBA c(r, g, b, a);
    ((OCCTImage*)ref)->image->SetPixelColor(x, y, c);
  }
  catch (...)
  {
  }
}

bool OCCTImageSave(OCCTImageRef ref, const char* filePath)
{
  if (!ref)
    return false;
  try
  {
    return ((OCCTImage*)ref)->image->Save(TCollection_AsciiString(filePath));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTImageLoad(OCCTImageRef ref, const char* filePath)
{
  if (!ref)
    return false;
  try
  {
    return ((OCCTImage*)ref)->image->Load(TCollection_AsciiString(filePath));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTImageAdjustGamma(OCCTImageRef ref, double gamma)
{
  if (!ref)
    return false;
  try
  {
    return ((OCCTImage*)ref)->image->AdjustGamma(gamma);
  }
  catch (...)
  {
    return false;
  }
}

int OCCTImageSizePixelBytes(int format)
{
  return (int)Image_PixMap::SizePixelBytes((Image_Format)format);
}

bool OCCTImageIsTopDownDefault(void)
{
  return Image_AlienPixMap::IsTopDownDefault();
}
