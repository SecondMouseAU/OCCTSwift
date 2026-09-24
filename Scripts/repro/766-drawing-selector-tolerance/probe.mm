// Epic #766, OCCTDrawingTests/SelectorTests.swift: does SelectMgr pick anything for the scenes the
// tests build? The two classes below are copied from OCCTBridge_Visualization_Camera.mm
// (OCCTBRepSelectable, OCCTHeadlessSelector), and each scene is set up the way OCCTSelectorAddShape
// and OCCTSelectorPick drive them: camera from a default Graphic3d_Camera with
// SetZeroToOneDepth(true) (OCCTCamera's constructor), aspect reset to the view's, then PickPoint.
// Each pick is also repeated without the zero-to-one depth setting, to separate that variable.
// ToleranceTests.swift is pure Swift (DrawingTolerance formatting and emission): no counterpart.
#include <BRepPrimAPI_MakeBox.hxx>
#include <Graphic3d_Camera.hxx>
#include <SelectMgr_EntityOwner.hxx>
#include <SelectMgr_SelectableObject.hxx>
#include <SelectMgr_SelectingVolumeManager.hxx>
#include <SelectMgr_SelectionManager.hxx>
#include <SelectMgr_SortCriterion.hxx>
#include <SelectMgr_ViewerSelector.hxx>
#include <StdSelect_BRepSelectionTool.hxx>
#include <cstdio>

class ProbeSelectable : public SelectMgr_SelectableObject
{
  DEFINE_STANDARD_RTTI_INLINE(ProbeSelectable, SelectMgr_SelectableObject)
public:
  ProbeSelectable(const TopoDS_Shape& s)
      : myShape(s)
  {
  }

private:
  void Compute(const Handle(PrsMgr_PresentationManager)&,
               const Handle(Prs3d_Presentation)&,
               const Standard_Integer) override
  {
  }

  void ComputeSelection(const Handle(SelectMgr_Selection)& sel, const Standard_Integer) override
  {
    StdSelect_BRepSelectionTool::Load(sel, this, myShape, TopAbs_SHAPE, 0.05, 0.5, Standard_True);
  }

  TopoDS_Shape myShape;
};

class ProbeSelector : public SelectMgr_ViewerSelector
{
  DEFINE_STANDARD_RTTI_INLINE(ProbeSelector, SelectMgr_ViewerSelector)
public:
  void PickPoint(double x, double y, const Handle(Graphic3d_Camera)& cam, int w, int h)
  {
    SelectMgr_SelectingVolumeManager& mgr = GetManager();
    mgr.InitPointSelectingVolume(gp_Pnt2d(x, y));
    mgr.SetCamera(cam);
    mgr.SetWindowSize(w, h);
    mgr.SetPixelTolerance(PixelTolerance());
    mgr.BuildSelectingVolume();
    TraverseSensitives();
  }
};

static void scene(const char* tag, bool zeroToOne, double eyeZ, double px, double py)
{
  Handle(ProbeSelector)              sel = new ProbeSelector();
  Handle(SelectMgr_SelectionManager) mgr = new SelectMgr_SelectionManager(sel);
  Handle(ProbeSelectable)            obj =
    new ProbeSelectable(BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape());
  mgr->Load(obj, 0);
  mgr->Activate(obj, 0);

  Handle(Graphic3d_Camera) cam = new Graphic3d_Camera();
  if (zeroToOne)
    cam->SetZeroToOneDepth(Standard_True);
  cam->SetEye(gp_Pnt(0, 0, eyeZ));
  cam->SetCenter(gp_Pnt(0, 0, 0));
  cam->SetUp(gp_Dir(0, 1, 0));
  cam->SetAspect(1.0);
  Handle(Graphic3d_Camera) pickCam = new Graphic3d_Camera(*cam);
  pickCam->SetAspect(800.0 / 600.0);
  sel->PickPoint(px, py, pickCam, 800, 600);
  printf("%s (zeroToOne=%d): NbPicked=%d", tag, zeroToOne, sel->NbPicked());
  if (sel->NbPicked() > 0)
  {
    const SelectMgr_SortCriterion& c = sel->PickedData(1);
    printf(" depth=%.9g point=(%.6g, %.6g, %.6g)", c.Depth, c.Point.X(), c.Point.Y(), c.Point.Z());
  }
  printf("\n");
}

int main()
{
  for (bool z : {true, false})
  {
    scene("pickBoxAtCenter, 10-box, eye z 50, pixel (400,300)", z, 50, 400, 300);
    scene("pickMiss-style corner pixel (0,0)", z, 50, 0, 0);
  }
  return 0;
}
