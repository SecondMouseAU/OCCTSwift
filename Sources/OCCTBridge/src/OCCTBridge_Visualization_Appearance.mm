//
//  OCCTBridge_Visualization_Appearance.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Visualization.mm (#1380): Quantity_Color/ColorRGBA/Period/Date,
//  Graphic3d_MaterialAspect/PBRMaterial/ClipPlane/ZLayerSettings. Public C surface unchanged; every
//  sibling file imports the same headers this one does (the shared preamble below). No symbol
//  changes, pure file move -- see Scripts/repro/396-bridge-mm-split/ for how.
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

OCCTClipPlaneRef OCCTClipPlaneCreate(double a, double b, double c, double d)
{
  try
  {
    auto* cp  = new OCCTClipPlane();
    cp->plane = new Graphic3d_ClipPlane(Graphic3d_Vec4d(a, b, c, d));
    return cp;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTClipPlaneDestroy(OCCTClipPlaneRef plane)
{
  delete plane;
}

void OCCTClipPlaneSetEquation(OCCTClipPlaneRef plane, double a, double b, double c, double d)
{
  if (!plane)
    return;
  try
  {
    plane->plane->SetEquation(Graphic3d_Vec4d(a, b, c, d));
  }
  catch (...)
  {
  }
}

void OCCTClipPlaneGetEquation(OCCTClipPlaneRef plane, double* a, double* b, double* c, double* d)
{
  if (!plane || !a || !b || !c || !d)
    return;
  try
  {
    const Graphic3d_Vec4d& eq = plane->plane->GetEquation();
    *a                        = eq.x();
    *b                        = eq.y();
    *c                        = eq.z();
    *d                        = eq.w();
  }
  catch (...)
  {
  }
}

void OCCTClipPlaneGetReversedEquation(OCCTClipPlaneRef plane,
                                      double*          a,
                                      double*          b,
                                      double*          c,
                                      double*          d)
{
  if (!plane || !a || !b || !c || !d)
    return;
  try
  {
    const Graphic3d_Vec4d& eq = plane->plane->ReversedEquation();
    *a                        = eq.x();
    *b                        = eq.y();
    *c                        = eq.z();
    *d                        = eq.w();
  }
  catch (...)
  {
  }
}

void OCCTClipPlaneSetOn(OCCTClipPlaneRef plane, bool on)
{
  if (!plane)
    return;
  try
  {
    plane->plane->SetOn(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTClipPlaneIsOn(OCCTClipPlaneRef plane)
{
  if (!plane)
    return false;
  try
  {
    return plane->plane->IsOn() == Standard_True;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTClipPlaneSetCapping(OCCTClipPlaneRef plane, bool on)
{
  if (!plane)
    return;
  try
  {
    plane->plane->SetCapping(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTClipPlaneIsCapping(OCCTClipPlaneRef plane)
{
  if (!plane)
    return false;
  try
  {
    return plane->plane->IsCapping() == Standard_True;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTClipPlaneSetCappingColor(OCCTClipPlaneRef plane, double r, double g, double b)
{
  if (!plane)
    return;
  try
  {
    plane->plane->SetCappingColor(Quantity_Color(r, g, b, Quantity_TOC_RGB));
  }
  catch (...)
  {
  }
}

void OCCTClipPlaneGetCappingColor(OCCTClipPlaneRef plane, double* r, double* g, double* b)
{
  if (!plane || !r || !g || !b)
    return;
  try
  {
    // Read InteriorColor directly from the aspect, matching what SetCappingColor writes.
    // CappingColor() may return the material color if material type != MATERIAL_ASPECT.
    Quantity_Color color = plane->plane->CappingAspect()->InteriorColor();
    *r                   = color.Red();
    *g                   = color.Green();
    *b                   = color.Blue();
  }
  catch (...)
  {
  }
}

void OCCTClipPlaneSetCappingHatch(OCCTClipPlaneRef plane, int32_t style)
{
  if (!plane)
    return;
  try
  {
    plane->plane->SetCappingHatch(static_cast<Aspect_HatchStyle>(style));
  }
  catch (...)
  {
  }
}

int32_t OCCTClipPlaneGetCappingHatch(OCCTClipPlaneRef plane)
{
  if (!plane)
    return 0;
  try
  {
    return static_cast<int32_t>(plane->plane->CappingHatch());
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTClipPlaneSetCappingHatchOn(OCCTClipPlaneRef plane, bool on)
{
  if (!plane)
    return;
  try
  {
    if (on)
    {
      plane->plane->SetCappingHatchOn();
    }
    else
    {
      plane->plane->SetCappingHatchOff();
    }
  }
  catch (...)
  {
  }
}

bool OCCTClipPlaneIsCappingHatchOn(OCCTClipPlaneRef plane)
{
  if (!plane)
    return false;
  try
  {
    return plane->plane->IsHatchOn() == Standard_True;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTClipPlaneProbePoint(OCCTClipPlaneRef plane, double x, double y, double z)
{
  if (!plane)
    return 0;
  try
  {
    Graphic3d_Vec4d     pt(x, y, z, 1.0);
    Graphic3d_ClipState worst = Graphic3d_ClipState_In;
    for (Handle(Graphic3d_ClipPlane) p = plane->plane; !p.IsNull(); p = p->ChainNextPlane())
    {
      Graphic3d_ClipState state = p->ProbePointHalfspace(pt);
      if (state == Graphic3d_ClipState_Out)
      {
        return static_cast<int32_t>(Graphic3d_ClipState_Out);
      }
      if (state == Graphic3d_ClipState_On)
      {
        worst = Graphic3d_ClipState_On;
      }
    }
    return static_cast<int32_t>(worst);
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTClipPlaneProbeBox(OCCTClipPlaneRef plane,
                              double           xMin,
                              double           yMin,
                              double           zMin,
                              double           xMax,
                              double           yMax,
                              double           zMax)
{
  if (!plane)
    return 0;
  try
  {
    Graphic3d_BndBox3d box;
    box.Add(Graphic3d_Vec3d(xMin, yMin, zMin));
    box.Add(Graphic3d_Vec3d(xMax, yMax, zMax));
    Graphic3d_ClipState worst = Graphic3d_ClipState_In;
    for (Handle(Graphic3d_ClipPlane) p = plane->plane; !p.IsNull(); p = p->ChainNextPlane())
    {
      Graphic3d_ClipState state = p->ProbeBoxHalfspace(box);
      if (state == Graphic3d_ClipState_Out)
      {
        return static_cast<int32_t>(Graphic3d_ClipState_Out);
      }
      if (state == Graphic3d_ClipState_On)
      {
        worst = Graphic3d_ClipState_On;
      }
    }
    return static_cast<int32_t>(worst);
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTClipPlaneSetChainNext(OCCTClipPlaneRef plane, OCCTClipPlaneRef next)
{
  if (!plane)
    return;
  try
  {
    if (next)
    {
      plane->plane->SetChainNextPlane(next->plane);
    }
    else
    {
      plane->plane->SetChainNextPlane(Handle(Graphic3d_ClipPlane)());
    }
  }
  catch (...)
  {
  }
}

int32_t OCCTClipPlaneChainLength(OCCTClipPlaneRef plane)
{
  if (!plane)
    return 0;
  try
  {
    return plane->plane->NbChainNextPlanes();
  }
  catch (...)
  {
    return 0;
  }
}

OCCTZLayerSettingsRef OCCTZLayerSettingsCreate(void)
{
  try
  {
    return new OCCTZLayerSettings();
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTZLayerSettingsDestroy(OCCTZLayerSettingsRef s)
{
  delete s;
}

void OCCTZLayerSettingsSetName(OCCTZLayerSettingsRef s, const char* name)
{
  if (!s || !name)
    return;
  try
  {
    s->settings.SetName(TCollection_AsciiString(name));
  }
  catch (...)
  {
  }
}

void OCCTZLayerSettingsSetDepthTest(OCCTZLayerSettingsRef s, bool on)
{
  if (!s)
    return;
  try
  {
    s->settings.SetEnableDepthTest(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTZLayerSettingsGetDepthTest(OCCTZLayerSettingsRef s)
{
  if (!s)
    return true;
  try
  {
    return s->settings.ToEnableDepthTest() == Standard_True;
  }
  catch (...)
  {
    return true;
  }
}

void OCCTZLayerSettingsSetDepthWrite(OCCTZLayerSettingsRef s, bool on)
{
  if (!s)
    return;
  try
  {
    s->settings.SetEnableDepthWrite(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTZLayerSettingsGetDepthWrite(OCCTZLayerSettingsRef s)
{
  if (!s)
    return true;
  try
  {
    return s->settings.ToEnableDepthWrite() == Standard_True;
  }
  catch (...)
  {
    return true;
  }
}

void OCCTZLayerSettingsSetClearDepth(OCCTZLayerSettingsRef s, bool on)
{
  if (!s)
    return;
  try
  {
    s->settings.SetClearDepth(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTZLayerSettingsGetClearDepth(OCCTZLayerSettingsRef s)
{
  if (!s)
    return true;
  try
  {
    return s->settings.ToClearDepth() == Standard_True;
  }
  catch (...)
  {
    return true;
  }
}

void OCCTZLayerSettingsSetPolygonOffset(OCCTZLayerSettingsRef s,
                                        int32_t               mode,
                                        float                 factor,
                                        float                 units)
{
  if (!s)
    return;
  try
  {
    Graphic3d_PolygonOffset offset;
    offset.Mode   = static_cast<Aspect_PolygonOffsetMode>(mode);
    offset.Factor = factor;
    offset.Units  = units;
    s->settings.SetPolygonOffset(offset);
  }
  catch (...)
  {
  }
}

void OCCTZLayerSettingsGetPolygonOffset(OCCTZLayerSettingsRef s,
                                        int32_t*              mode,
                                        float*                factor,
                                        float*                units)
{
  if (!s || !mode || !factor || !units)
    return;
  try
  {
    const Graphic3d_PolygonOffset& offset = s->settings.PolygonOffset();
    *mode                                 = static_cast<int32_t>(offset.Mode);
    *factor                               = offset.Factor;
    *units                                = offset.Units;
  }
  catch (...)
  {
  }
}

void OCCTZLayerSettingsSetDepthOffsetPositive(OCCTZLayerSettingsRef s)
{
  if (!s)
    return;
  try
  {
    s->settings.SetDepthOffsetPositive();
  }
  catch (...)
  {
  }
}

void OCCTZLayerSettingsSetDepthOffsetNegative(OCCTZLayerSettingsRef s)
{
  if (!s)
    return;
  try
  {
    s->settings.SetDepthOffsetNegative();
  }
  catch (...)
  {
  }
}

void OCCTZLayerSettingsSetImmediate(OCCTZLayerSettingsRef s, bool on)
{
  if (!s)
    return;
  try
  {
    s->settings.SetImmediate(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTZLayerSettingsGetImmediate(OCCTZLayerSettingsRef s)
{
  if (!s)
    return false;
  try
  {
    return s->settings.IsImmediate() == Standard_True;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTZLayerSettingsSetRaytracable(OCCTZLayerSettingsRef s, bool on)
{
  if (!s)
    return;
  try
  {
    s->settings.SetRaytracable(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTZLayerSettingsGetRaytracable(OCCTZLayerSettingsRef s)
{
  if (!s)
    return true;
  try
  {
    return s->settings.IsRaytracable() == Standard_True;
  }
  catch (...)
  {
    return true;
  }
}

void OCCTZLayerSettingsSetEnvironmentTexture(OCCTZLayerSettingsRef s, bool on)
{
  if (!s)
    return;
  try
  {
    s->settings.SetEnvironmentTexture(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTZLayerSettingsGetEnvironmentTexture(OCCTZLayerSettingsRef s)
{
  if (!s)
    return true;
  try
  {
    return s->settings.UseEnvironmentTexture() == Standard_True;
  }
  catch (...)
  {
    return true;
  }
}

void OCCTZLayerSettingsSetRenderInDepthPrepass(OCCTZLayerSettingsRef s, bool on)
{
  if (!s)
    return;
  try
  {
    s->settings.SetRenderInDepthPrepass(on ? Standard_True : Standard_False);
  }
  catch (...)
  {
  }
}

bool OCCTZLayerSettingsGetRenderInDepthPrepass(OCCTZLayerSettingsRef s)
{
  if (!s)
    return true;
  try
  {
    return s->settings.ToRenderInDepthPrepass() == Standard_True;
  }
  catch (...)
  {
    return true;
  }
}

void OCCTZLayerSettingsSetCullingDistance(OCCTZLayerSettingsRef s, double distance)
{
  if (!s)
    return;
  try
  {
    s->settings.SetCullingDistance(distance);
  }
  catch (...)
  {
  }
}

double OCCTZLayerSettingsGetCullingDistance(OCCTZLayerSettingsRef s)
{
  if (!s)
    return 0.0;
  try
  {
    return s->settings.CullingDistance();
  }
  catch (...)
  {
    return 0.0;
  }
}

void OCCTZLayerSettingsSetCullingSize(OCCTZLayerSettingsRef s, double size)
{
  if (!s)
    return;
  try
  {
    s->settings.SetCullingSize(size);
  }
  catch (...)
  {
  }
}

double OCCTZLayerSettingsGetCullingSize(OCCTZLayerSettingsRef s)
{
  if (!s)
    return 0.0;
  try
  {
    return s->settings.CullingSize();
  }
  catch (...)
  {
    return 0.0;
  }
}

void OCCTZLayerSettingsSetOrigin(OCCTZLayerSettingsRef s, double x, double y, double z)
{
  if (!s)
    return;
  try
  {
    s->settings.SetOrigin(gp_XYZ(x, y, z));
  }
  catch (...)
  {
  }
}

void OCCTZLayerSettingsGetOrigin(OCCTZLayerSettingsRef s, double* x, double* y, double* z)
{
  if (!s || !x || !y || !z)
    return;
  try
  {
    const gp_XYZ& origin = s->settings.Origin();
    *x                   = origin.X();
    *y                   = origin.Y();
    *z                   = origin.Z();
  }
  catch (...)
  {
  }
}

bool OCCTColorFromName(const char* _Nonnull name,
                       double* _Nonnull outR,
                       double* _Nonnull outG,
                       double* _Nonnull outB)
{
  try
  {
    Quantity_Color c;
    if (!Quantity_Color::ColorFromName(name, c))
      return false;
    *outR = c.Red();
    *outG = c.Green();
    *outB = c.Blue();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTColorFromHex(const char* _Nonnull hex,
                      double* _Nonnull outR,
                      double* _Nonnull outG,
                      double* _Nonnull outB)
{
  try
  {
    Quantity_Color c;
    if (!Quantity_Color::ColorFromHex(hex, c))
      return false;
    *outR = c.Red();
    *outG = c.Green();
    *outB = c.Blue();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

const char* _Nullable OCCTColorToHex(double r, double g, double b, bool includeHashPrefix)
{
  try
  {
    Quantity_Color          c(r, g, b, Quantity_TOC_RGB);
    TCollection_AsciiString hex    = Quantity_Color::ColorToHex(c, includeHashPrefix);
    char*                   result = (char*)malloc(hex.Length() + 1);
    if (!result)
      return nullptr;
    memcpy(result, hex.ToCString(), hex.Length() + 1);
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTColorDistance(double r1, double g1, double b1, double r2, double g2, double b2)
{
  try
  {
    Quantity_Color c1(r1, g1, b1, Quantity_TOC_RGB);
    Quantity_Color c2(r2, g2, b2, Quantity_TOC_RGB);
    return c1.Distance(c2);
  }
  catch (...)
  {
    return -1.0;
  }
}

double OCCTColorSquareDistance(double r1, double g1, double b1, double r2, double g2, double b2)
{
  try
  {
    Quantity_Color c1(r1, g1, b1, Quantity_TOC_RGB);
    Quantity_Color c2(r2, g2, b2, Quantity_TOC_RGB);
    return c1.SquareDistance(c2);
  }
  catch (...)
  {
    return -1.0;
  }
}

double OCCTColorDeltaE2000(double r1, double g1, double b1, double r2, double g2, double b2)
{
  try
  {
    Quantity_Color c1(r1, g1, b1, Quantity_TOC_RGB);
    Quantity_Color c2(r2, g2, b2, Quantity_TOC_RGB);
    return c1.DeltaE2000(c2);
  }
  catch (...)
  {
    return -1.0;
  }
}

OCCTColorHLS OCCTColorToHLS(double r, double g, double b)
{
  OCCTColorHLS result = {0, 0, 0};
  try
  {
    Quantity_Color c(r, g, b, Quantity_TOC_RGB);
    result.hue        = c.Hue();
    result.lightness  = c.Light();
    result.saturation = c.Saturation();
  }
  catch (...)
  {
  }
  return result;
}

void OCCTColorFromHLS(double h,
                      double l,
                      double s,
                      double* _Nonnull outR,
                      double* _Nonnull outG,
                      double* _Nonnull outB)
{
  try
  {
    Quantity_Color c(h, l, s, Quantity_TOC_HLS);
    *outR = c.Red();
    *outG = c.Green();
    *outB = c.Blue();
  }
  catch (...)
  {
    *outR = 0;
    *outG = 0;
    *outB = 0;
  }
}

void OCCTColorChangeIntensity(double* _Nonnull r,
                              double* _Nonnull g,
                              double* _Nonnull b,
                              double delta)
{
  try
  {
    Quantity_Color c(*r, *g, *b, Quantity_TOC_RGB);
    c.ChangeIntensity(delta);
    *r = c.Red();
    *g = c.Green();
    *b = c.Blue();
  }
  catch (...)
  {
  }
}

void OCCTColorChangeContrast(double* _Nonnull r,
                             double* _Nonnull g,
                             double* _Nonnull b,
                             double delta)
{
  try
  {
    Quantity_Color c(*r, *g, *b, Quantity_TOC_RGB);
    c.ChangeContrast(delta);
    *r = c.Red();
    *g = c.Green();
    *b = c.Blue();
  }
  catch (...)
  {
  }
}

void OCCTColorLinearToSRGB(float inR,
                           float inG,
                           float inB,
                           float* _Nonnull outR,
                           float* _Nonnull outG,
                           float* _Nonnull outB)
{
  try
  {
    NCollection_Vec3<float> linear(inR, inG, inB);
    NCollection_Vec3<float> srgb = Quantity_Color::Convert_LinearRGB_To_sRGB(linear);
    *outR                        = srgb.r();
    *outG                        = srgb.g();
    *outB                        = srgb.b();
  }
  catch (...)
  {
    *outR = inR;
    *outG = inG;
    *outB = inB;
  }
}

void OCCTColorSRGBToLinear(float inR,
                           float inG,
                           float inB,
                           float* _Nonnull outR,
                           float* _Nonnull outG,
                           float* _Nonnull outB)
{
  try
  {
    NCollection_Vec3<float> srgb(inR, inG, inB);
    NCollection_Vec3<float> linear = Quantity_Color::Convert_sRGB_To_LinearRGB(srgb);
    *outR                          = linear.r();
    *outG                          = linear.g();
    *outB                          = linear.b();
  }
  catch (...)
  {
    *outR = inR;
    *outG = inG;
    *outB = inB;
  }
}

OCCTColorLab OCCTColorToLab(double r, double g, double b)
{
  OCCTColorLab result = {0, 0, 0};
  try
  {
    float                   fr = (float)r, fg = (float)g, fb = (float)b;
    NCollection_Vec3<float> linear(fr, fg, fb);
    NCollection_Vec3<float> lab = Quantity_Color::Convert_LinearRGB_To_Lab(linear);
    result.l                    = lab.x();
    result.a                    = lab.y();
    result.b                    = lab.z();
  }
  catch (...)
  {
  }
  return result;
}

const char* _Nullable OCCTColorStringName(int index)
{
  try
  {
    if (index < 0 || index >= (int)Quantity_NOC_WHITE + 1)
      return nullptr;
    TCollection_AsciiString name   = Quantity_Color::StringName((Quantity_NameOfColor)index);
    char*                   result = (char*)malloc(name.Length() + 1);
    if (!result)
      return nullptr;
    memcpy(result, name.ToCString(), name.Length() + 1);
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTColorEpsilon(void)
{
  return Quantity_Color::Epsilon();
}

bool OCCTColorRGBAFromHex(const char* _Nonnull hex,
                          double* _Nonnull outR,
                          double* _Nonnull outG,
                          double* _Nonnull outB,
                          double* _Nonnull outA)
{
  try
  {
    Quantity_ColorRGBA c;
    if (!Quantity_ColorRGBA::ColorFromHex(hex, c))
      return false;
    *outR = c.GetRGB().Red();
    *outG = c.GetRGB().Green();
    *outB = c.GetRGB().Blue();
    *outA = double(c.Alpha());
    return true;
  }
  catch (...)
  {
    return false;
  }
}

const char* _Nullable OCCTColorRGBAToHex(double r,
                                         double g,
                                         double b,
                                         double a,
                                         bool   includeHashPrefix)
{
  try
  {
    Quantity_Color          rgb(r, g, b, Quantity_TOC_RGB);
    Quantity_ColorRGBA      c(rgb, float(a));
    TCollection_AsciiString hex    = Quantity_ColorRGBA::ColorToHex(c, includeHashPrefix);
    char*                   result = (char*)malloc(hex.Length() + 1);
    if (!result)
      return nullptr;
    memcpy(result, hex.ToCString(), hex.Length() + 1);
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

int OCCTMaterialNumberOfMaterials(void)
{
  return Graphic3d_MaterialAspect::NumberOfMaterials();
}

const char* _Nullable OCCTMaterialName(int index)
{
  try
  {
    if (index < 1 || index > Graphic3d_MaterialAspect::NumberOfMaterials())
      return nullptr;
    TCollection_AsciiString name   = Graphic3d_MaterialAspect::MaterialName(index);
    char*                   result = (char*)malloc(name.Length() + 1);
    if (!result)
      return nullptr;
    memcpy(result, name.ToCString(), name.Length() + 1);
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTMaterialFromName(const char* _Nonnull name, OCCTMaterialProperties* _Nonnull outProps)
{
  try
  {
    Graphic3d_NameOfMaterial nom;
    if (!Graphic3d_MaterialAspect::MaterialFromName(name, nom))
      return false;
    Graphic3d_MaterialAspect mat(nom);
    fillMaterialProps(mat, outProps);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTMaterialFromIndex(int index, OCCTMaterialProperties* _Nonnull outProps)
{
  try
  {
    if (index < 1 || index > Graphic3d_MaterialAspect::NumberOfMaterials())
      return false;
    // Get name then construct
    Graphic3d_NameOfMaterial nom = (Graphic3d_NameOfMaterial)(index - 1);
    Graphic3d_MaterialAspect mat(nom);
    fillMaterialProps(mat, outProps);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

float OCCTMaterialMinRoughness(void)
{
  return Graphic3d_PBRMaterial::MinRoughness();
}

float OCCTMaterialRoughnessFromSpecular(double specR, double specG, double specB, double shininess)
{
  try
  {
    Quantity_Color spec(specR, specG, specB, Quantity_TOC_RGB);
    return Graphic3d_PBRMaterial::RoughnessFromSpecular(spec, shininess);
  }
  catch (...)
  {
    return 0.5f;
  }
}

float OCCTMaterialMetallicFromSpecular(double specR, double specG, double specB)
{
  try
  {
    Quantity_Color spec(specR, specG, specB, Quantity_TOC_RGB);
    return Graphic3d_PBRMaterial::MetallicFromSpecular(spec);
  }
  catch (...)
  {
    return 0.0f;
  }
}

bool OCCTPeriodCreate(int dd, int hh, int mn, int ss, int mis, int mics, int* outSec, int* outUSec)
{
  try
  {
    if (!Quantity_Period::IsValid(dd, hh, mn, ss, mis, mics))
      return false;
    Quantity_Period p(dd, hh, mn, ss, mis, mics);
    p.Values(*outSec, *outUSec);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTPeriodCreateFromSeconds(int ss, int mics, int* outSec, int* outUSec)
{
  try
  {
    if (!Quantity_Period::IsValid(ss, mics))
      return false;
    Quantity_Period p(ss, mics);
    p.Values(*outSec, *outUSec);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTPeriodComponents OCCTPeriodValues(int sec, int usec)
{
  OCCTPeriodComponents result = {0, 0, 0, 0, 0, 0};
  try
  {
    Quantity_Period p(sec, usec);
    p.Values(result.days,
             result.hours,
             result.minutes,
             result.seconds,
             result.milliseconds,
             result.microseconds);
  }
  catch (...)
  {
  }
  return result;
}

void OCCTPeriodTotalSeconds(int sec, int usec, int* outSec, int* outUSec)
{
  try
  {
    Quantity_Period p(sec, usec);
    p.Values(*outSec, *outUSec);
  }
  catch (...)
  {
    *outSec  = 0;
    *outUSec = 0;
  }
}

void OCCTPeriodAdd(int sec1, int usec1, int sec2, int usec2, int* outSec, int* outUSec)
{
  try
  {
    Quantity_Period p1(sec1, usec1);
    Quantity_Period p2(sec2, usec2);
    Quantity_Period sum = p1 + p2;
    sum.Values(*outSec, *outUSec);
  }
  catch (...)
  {
    *outSec  = 0;
    *outUSec = 0;
  }
}

void OCCTPeriodSubtract(int sec1, int usec1, int sec2, int usec2, int* outSec, int* outUSec)
{
  try
  {
    Quantity_Period p1(sec1, usec1);
    Quantity_Period p2(sec2, usec2);
    Quantity_Period diff = p1 - p2;
    diff.Values(*outSec, *outUSec);
  }
  catch (...)
  {
    *outSec  = 0;
    *outUSec = 0;
  }
}

int OCCTPeriodCompare(int sec1, int usec1, int sec2, int usec2)
{
  try
  {
    Quantity_Period p1(sec1, usec1);
    Quantity_Period p2(sec2, usec2);
    if (p1 == p2)
      return 0;
    if (p1 < p2)
      return -1;
    return 1;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTPeriodIsValid(int dd, int hh, int mn, int ss, int mis, int mics)
{
  return Quantity_Period::IsValid(dd, hh, mn, ss, mis, mics);
}

bool OCCTPeriodIsValidSeconds(int ss, int mics)
{
  return Quantity_Period::IsValid(ss, mics);
}

bool OCCTDateCreate(int  mm,
                    int  dd,
                    int  yyyy,
                    int  hh,
                    int  mn,
                    int  ss,
                    int  mis,
                    int  mics,
                    int* outSec,
                    int* outUSec)
{
  try
  {
    if (!Quantity_Date::IsValid(mm, dd, yyyy, hh, mn, ss, mis, mics))
      return false;
    Quantity_Date d(mm, dd, yyyy, hh, mn, ss, mis, mics);
    // Store as difference from epoch
    Quantity_Date   epoch;
    Quantity_Period diff = d.Difference(epoch);
    diff.Values(*outSec, *outUSec);
    // Need to know direction - if d > epoch, sec is positive
    if (d < epoch)
    {
      *outSec = -(*outSec);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTDateComponents OCCTDateValues(int sec, int usec)
{
  OCCTDateComponents result = {1, 1, 1979, 0, 0, 0, 0, 0};
  try
  {
    Quantity_Date epoch;
    if (sec > 0 || (sec == 0 && usec > 0))
    {
      Quantity_Period p(sec, usec);
      Quantity_Date   d = epoch + p;
      d.Values(result.month,
               result.day,
               result.year,
               result.hour,
               result.minute,
               result.second,
               result.millisecond,
               result.microsecond);
    }
  }
  catch (...)
  {
  }
  return result;
}

void OCCTDateAddPeriod(int  dateSec,
                       int  dateUSec,
                       int  periodSec,
                       int  periodUSec,
                       int* outSec,
                       int* outUSec)
{
  try
  {
    Quantity_Date epoch;
    Quantity_Date d = epoch;
    if (dateSec > 0 || dateUSec > 0)
    {
      d = epoch + Quantity_Period(dateSec, dateUSec);
    }
    Quantity_Period p(periodSec, periodUSec);
    Quantity_Date   result = d + p;
    Quantity_Period diff   = result.Difference(epoch);
    diff.Values(*outSec, *outUSec);
  }
  catch (...)
  {
    *outSec  = 0;
    *outUSec = 0;
  }
}

bool OCCTDateSubtractPeriod(int  dateSec,
                            int  dateUSec,
                            int  periodSec,
                            int  periodUSec,
                            int* outSec,
                            int* outUSec)
{
  try
  {
    Quantity_Date epoch;
    Quantity_Date d = epoch;
    if (dateSec > 0 || dateUSec > 0)
    {
      d = epoch + Quantity_Period(dateSec, dateUSec);
    }
    Quantity_Period p(periodSec, periodUSec);
    Quantity_Date   result = d - p;
    Quantity_Period diff   = result.Difference(epoch);
    diff.Values(*outSec, *outUSec);
    return true;
  }
  catch (...)
  {
    *outSec  = 0;
    *outUSec = 0;
    return false;
  }
}

void OCCTDateDifference(int  sec1,
                        int  usec1,
                        int  sec2,
                        int  usec2,
                        int* outPeriodSec,
                        int* outPeriodUSec)
{
  try
  {
    Quantity_Date epoch;
    Quantity_Date d1 = epoch;
    Quantity_Date d2 = epoch;
    if (sec1 > 0 || usec1 > 0)
      d1 = epoch + Quantity_Period(sec1, usec1);
    if (sec2 > 0 || usec2 > 0)
      d2 = epoch + Quantity_Period(sec2, usec2);
    Quantity_Period diff = d1.Difference(d2);
    diff.Values(*outPeriodSec, *outPeriodUSec);
  }
  catch (...)
  {
    *outPeriodSec  = 0;
    *outPeriodUSec = 0;
  }
}

bool OCCTDateIsValid(int mm, int dd, int yyyy, int hh, int mn, int ss, int mis, int mics)
{
  return Quantity_Date::IsValid(mm, dd, yyyy, hh, mn, ss, mis, mics);
}

bool OCCTDateIsLeap(int year)
{
  return Quantity_Date::IsLeap(year);
}

int32_t OCCTNamedColorCount()
{
  // Quantity_NOC_WHITE is the last named color before Quantity_NOC_NB
  return (int32_t)Quantity_NOC_WHITE + 1;
}
