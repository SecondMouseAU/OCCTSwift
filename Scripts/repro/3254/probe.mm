// #3254: drive SelectMgr_ViewerSelector headlessly the way the bridge does,
// then with variations, to find what makes NbPicked() non-zero.
#include <Graphic3d_Camera.hxx>
#include <SelectMgr_EntityOwner.hxx>
#include <SelectMgr_SelectableObject.hxx>
#include <SelectMgr_SelectingVolumeManager.hxx>
#include <SelectMgr_Selection.hxx>
#include <SelectMgr_SelectionManager.hxx>
#include <SelectMgr_ViewerSelector.hxx>
#include <StdSelect_BRepSelectionTool.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt2d.hxx>
#include <iostream>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <SelectBasics_PickResult.hxx>
#include <Select3D_SensitiveEntity.hxx>
#include <SelectMgr_SensitiveEntity.hxx>

class Sel : public SelectMgr_SelectableObject {
  DEFINE_STANDARD_RTTI_INLINE(Sel, SelectMgr_SelectableObject)
public:
  Sel(const TopoDS_Shape& s) : myShape(s) {}
#ifdef WITH_BBOX
  // IVtkOCC_SelectableObject::BoundingBox(Bnd_Box&) (the V3d-free OCCT caller)
  void BoundingBox(Bnd_Box& b) override { BRepBndLib::Add(myShape, b, true); }
#endif
private:
  void Compute(const Handle(PrsMgr_PresentationManager)&, const Handle(Prs3d_Presentation)&, const Standard_Integer) override {}
  void ComputeSelection(const Handle(SelectMgr_Selection)& sel, const Standard_Integer mode) override {
    StdSelect_BRepSelectionTool::Load(sel, this, myShape, TopAbs_SHAPE, 0.05, 0.5, Standard_True);
  }
  TopoDS_Shape myShape;
};
class HS : public SelectMgr_ViewerSelector {
  DEFINE_STANDARD_RTTI_INLINE(HS, SelectMgr_ViewerSelector)
public:
  void PickPoint(double x, double y, const Handle(Graphic3d_Camera)& cam, int w, int h) {
    SelectMgr_SelectingVolumeManager& m = GetManager();
    m.InitPointSelectingVolume(gp_Pnt2d(x, y));
    m.SetCamera(cam); m.SetWindowSize(w, h); m.SetPixelTolerance(PixelTolerance());
    m.BuildSelectingVolume();
    TraverseSensitives();
  }
};

int main() {
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
  Handle(Graphic3d_Camera) cam = new Graphic3d_Camera();
  cam->SetEye(gp_Pnt(5, 5, 50)); cam->SetCenter(gp_Pnt(5, 5, 5)); cam->SetUp(gp_Dir(0, 1, 0));
  cam->SetFOVy(45); cam->SetZRange(1, 1000); cam->SetAspect(800.0 / 600.0);
  Handle(HS) hs = new HS();
  Handle(SelectMgr_SelectionManager) mgr = new SelectMgr_SelectionManager(hs);
  Handle(Sel) obj = new Sel(box);
  mgr->Load(obj, 0);
  mgr->Activate(obj, 0);
  std::cout << "contains=" << hs->Contains(obj) << " active=" << hs->IsActive(obj, 0) << "\n";
  {
    Handle(SelectMgr_Selection) sl = obj->Selection(0);
    std::cout << "selection entities=" << sl->Entities().Size() << " state=" << (int)sl->GetSelectionState()
              << " sensitivity=" << sl->Sensitivity() << "\n";
    for (auto it = sl->Entities().begin(); it != sl->Entities().end(); ++it)
      std::cout << " entity active=" << (*it)->IsActiveForSelection() << " type=" << (*it)->BaseSensitive()->DynamicType()->Name() << "\n";
  }
  hs->PickPoint(400, 300, cam, 800, 600);
  std::cout << "NbPicked(point 400,300)=" << hs->NbPicked() << "\n";
  SelectMgr_SelectingVolumeManager& m = hs->GetManager();
  std::cout << "OverlapsBox(0..10)=" << m.OverlapsBox(NCollection_Vec3<double>(0,0,0), NCollection_Vec3<double>(10,10,10))
            << " OverlapsPoint(5,5,5)=" << m.OverlapsPoint(gp_Pnt(5,5,5), *(new SelectBasics_PickResult()))
            << " activeType=" << (int)m.GetActiveSelectionType() << "\n";
  {
    Handle(SelectMgr_Selection) sl = obj->Selection(0);
    for (auto it = sl->Entities().begin(); it != sl->Entities().end(); ++it) {
      SelectBasics_PickResult pr;
      Handle(Select3D_SensitiveEntity) e = (*it)->BaseSensitive();
      bool ok = e->Matches(m, pr);
      auto bb = e->BoundingBox();
      std::cout << " ent matches=" << ok << " depth=" << pr.Depth() << " bbox=(" << bb.CornerMin().x() << "," << bb.CornerMin().y() << "," << bb.CornerMin().z() << ")-(" << bb.CornerMax().x() << "," << bb.CornerMax().y() << "," << bb.CornerMax().z() << ") nbsub=" << e->NbSubElements() << "\n";
    }
  }
  NCollection_Vec2<int> ws; m.WindowSize(ws.x(), ws.y());
  std::cout << "winsize=" << ws.x() << "x" << ws.y() << " camNull=" << m.Camera().IsNull() << "\n";
  return 0;
}
