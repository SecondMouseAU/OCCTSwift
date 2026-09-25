// Epic #766, #1984 evidence correction for OCCTDrawingTests: the kernel measurements the earlier
// probes did not take, or took at lower precision, so that bridge and kernel records compare the
// same quantity. Four groups:
//   1. Selector: SelectMgr picking for each of SelectorTests' six scenes, with the bridge's two
//      selector classes copied from OCCTBridge_Visualization_Camera.mm and the camera set up as
//      Camera() plus the test's own settings (zero-to-one depth, fov 45 and z range 1..1000 where
//      the test sets them), pick through a copy whose aspect is the view's (OCCTSelectorPick).
//   2. #1036: what HLRBRep_Algo returns for the three fixtures OCCTDrawingCreate refuses, run
//      WITHOUT the bridge's reach guard, so the refusal can be recorded as a design divergence.
//   3. Normal projection: BRepOffsetAPI_NormalProjection at full precision (%.17g).
//   5. Precision re-measurement (the follow-up commit): five records whose kernel side was printed at
//      9 to 12 significant digits, re-measured at %.17g: the perspective and orthographic projection
//      matrix entries (float32 widened to double, as the Swift side reads them), the #1036
//      behind-the-picture-plane x range, and the polygonal HLR isometric-box and cylinder extents.
//   4. BRepGraph editor: the five remove calls SetterTests' remove test makes that the earlier
//      probe did not (Shells().RemoveFace via shellRemoveChild, Solids().RemoveShell twice,
//      Compounds().RemoveChild, CompSolids().RemoveSolid), each wrapped as the bridge wraps it:
//      an exception is caught and the call reports false.
#include <BRepBndLib.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <cmath>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepOffsetAPI_NormalProjection.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Builder.hxx>
#include <Bnd_Box.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <Graphic3d_Camera.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <SelectMgr_EntityOwner.hxx>
#include <SelectMgr_SelectableObject.hxx>
#include <SelectMgr_SelectingVolumeManager.hxx>
#include <SelectMgr_SelectionManager.hxx>
#include <SelectMgr_ViewerSelector.hxx>
#include <StdSelect_BRepSelectionTool.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS_Compound.hxx>
#include <cstdio>

// ---------------------------------------------------------------- 1. selector

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

  void PickBox(double x0, double y0, double x1, double y1, const Handle(Graphic3d_Camera)& cam,
               int w, int h)
  {
    SelectMgr_SelectingVolumeManager& mgr = GetManager();
    mgr.InitBoxSelectingVolume(gp_Pnt2d(x0, y0), gp_Pnt2d(x1, y1));
    mgr.SetCamera(cam);
    mgr.SetWindowSize(w, h);
    mgr.SetPixelTolerance(PixelTolerance());
    mgr.BuildSelectingVolume();
    TraverseSensitives();
  }
};

static TopoDS_Shape centredBox(double s, double tx = 0)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(tx - s / 2, -s / 2, -s / 2), s, s, s).Shape();
}

// Camera() = Graphic3d_Camera with SetZeroToOneDepth(true); the tests set eye/centre/up/aspect,
// and fov 45 + z range (1, 1000) only where `full`.
static Handle(Graphic3d_Camera) makeCam(double eyeZ, bool full)
{
  Handle(Graphic3d_Camera) c = new Graphic3d_Camera();
  c->SetZeroToOneDepth(Standard_True);
  c->SetEye(gp_Pnt(0, 0, eyeZ));
  c->SetCenter(gp_Pnt(0, 0, 0));
  c->SetUp(gp_Dir(0, 1, 0));
  c->SetAspect(1.0);
  if (full)
  {
    c->SetFOVy(45);
    c->SetZRange(1, 1000);
  }
  Handle(Graphic3d_Camera) pick = new Graphic3d_Camera(*c);
  pick->SetAspect(800.0 / 600.0);
  return pick;
}

struct Scene
{
  Handle(ProbeSelector)              sel;
  Handle(SelectMgr_SelectionManager) mgr;
  Scene()
  {
    sel = new ProbeSelector();
    mgr = new SelectMgr_SelectionManager(sel);
  }
  Handle(ProbeSelectable) add(const TopoDS_Shape& s)
  {
    Handle(ProbeSelectable) o = new ProbeSelectable(s);
    mgr->Load(o, 0);
    mgr->Activate(o, 0);
    return o;
  }
};

// ------------------------------------------------------------ 2. #1036, unguarded

static void unguarded(const char* tag, double xMin, double zMin, double focus)
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(xMin, -5, zMin), 10, 10, 10).Shape();
  Bnd_Box      bb;
  BRepBndLib::Add(box, bb);
  double x0, y0, z0, x1, y1, z1;
  bb.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: reach along +Z=%.9g focus=%g -> the bridge refuses (reach >= focus)\n", tag, z1, focus);
  Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
  algo->Add(box);
  algo->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), focus));
  algo->Update();
  algo->Hide();
  HLRBRep_HLRToShape h(algo);
  TopoDS_Compound    c;
  BRep_Builder       bld;
  bld.MakeCompound(c);
  TopoDS_Shape parts[3] = {h.VCompound(), h.Rg1LineVCompound(), h.OutLineVCompound()};
  for (const TopoDS_Shape& s : parts)
    if (!s.IsNull())
      bld.Add(c, s);
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(c, TopAbs_EDGE, m);
  Bnd_Box vb;
  BRepBndLib::Add(c, vb, true);
  vb.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: unguarded HLR produced a drawing: visible edges=%d x range [%.9g, %.9g]\n", tag,
         m.Extent(), x0, x1);
}

// ------------------------------------------------------------ 3. normal projection

static void projection(const char* tag, gp_Pnt a, gp_Pnt b)
{
  BRepOffsetAPI_NormalProjection proj(BRepPrimAPI_MakeSphere(10).Shape());
  proj.Add(BRepBuilderAPI_MakeEdge(a, b).Edge());
  proj.SetParams(1e-4, 1e-5, GeomAbs_C2, 14, 16);
  proj.Build();
  TopoDS_Shape               r = proj.Projection();
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(r, TopAbs_EDGE, m);
  Bnd_Box bb;
  BRepBndLib::Add(r, bb, true);
  double x0, y0, z0, x1, y1, z1;
  bb.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: IsDone=%d edges=%d min=(%.17g, %.17g, %.17g) max=(%.17g, %.17g, %.17g)\n", tag,
         proj.IsDone(), m.Extent(), x0, y0, z0, x1, y1, z1);
}


// ------------------------------------------------------------ 5. precision re-measurement

static Handle(Graphic3d_Camera) plainCam()
{
  Handle(Graphic3d_Camera) c = new Graphic3d_Camera();
  c->SetZeroToOneDepth(Standard_True);
  return c;
}

static TopoDS_Compound joinN(const TopoDS_Shape parts[], int n)
{
  BRep_Builder    bld;
  TopoDS_Compound c;
  bld.MakeCompound(c);
  for (int i = 0; i < n; ++i)
    if (!parts[i].IsNull())
      bld.Add(c, parts[i]);
  return c;
}

static void extent17(const char* tag, const TopoDS_Compound& c)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(c, TopAbs_EDGE, m);
  Bnd_Box bb;
  BRepBndLib::Add(c, bb, true);
  double x0, y0, z0, x1, y1, z1;
  bb.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: edges=%d min=(%.17g, %.17g) max=(%.17g, %.17g)\n", tag, m.Extent(), x0, y0, x1, y1);
}

static void polyView(const char* tag, const TopoDS_Shape& s, gp_Dir view, bool wantHidden, bool wantOutline)
{
  BRepMesh_IncrementalMesh mesh(s, 0.01);
  Handle(HLRBRep_PolyAlgo) algo = new HLRBRep_PolyAlgo();
  algo->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), view)));
  algo->Load(s);
  algo->Update();
  HLRBRep_PolyHLRToShape h;
  h.Update(algo);
  char t[128];
  TopoDS_Shape v[3] = {h.VCompound(), h.Rg1LineVCompound(), h.OutLineVCompound()};
  snprintf(t, sizeof t, "%s visible", tag);
  extent17(t, joinN(v, 3));
  if (wantHidden)
  {
    TopoDS_Shape hd[3] = {h.HCompound(), h.Rg1LineHCompound(), h.OutLineHCompound()};
    snprintf(t, sizeof t, "%s hidden", tag);
    extent17(t, joinN(hd, 3));
  }
  if (wantOutline)
  {
    TopoDS_Shape o[2] = {h.OutLineVCompound(), h.OutLineHCompound()};
    snprintf(t, sizeof t, "%s outline", tag);
    extent17(t, joinN(o, 2));
  }
}

// ------------------------------------------------------------ 4. graph remove calls

static void build(BRepGraph& g)
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  g.Shapes().Add(centredBox(10), opts);
}

template <typename F>
static void removeCall(const char* tag, F f)
{
  try
  {
    printf("remove %s: %d\n", tag, (int)f());
  }
  catch (Standard_Failure& e)
  {
    printf("remove %s: threw (%s), the bridge catches and returns false\n", tag, e.GetMessageString());
  }
}

int main()
{
  // ---- 1. selector
  {
    Scene s;
    s.add(centredBox(10));
    s.sel->PickPoint(400, 300, makeCam(50, true), 800, 600);
    printf("selector centre (box 10, eye z 50, full camera, pixel 400,300): NbPicked=%d\n", s.sel->NbPicked());
  }
  {
    Scene s;
    s.add(centredBox(1));
    s.sel->PickPoint(0, 0, makeCam(50, true), 800, 600);
    printf("selector miss (box 1, eye z 50, full camera, pixel 0,0): NbPicked=%d\n", s.sel->NbPicked());
  }
  {
    Scene s;
    s.add(centredBox(10, -20));
    s.add(centredBox(10, 20));
    s.sel->PickPoint(384, 300, makeCam(100, true), 800, 600);
    printf("selector multi left (boxes at x -20 and 20, eye z 100, pixel 384,300): NbPicked=%d\n", s.sel->NbPicked());
    s.sel->PickPoint(416, 300, makeCam(100, true), 800, 600);
    printf("selector multi right (pixel 416,300): NbPicked=%d\n", s.sel->NbPicked());
  }
  {
    Scene                   s;
    Handle(ProbeSelectable) o = s.add(centredBox(10));
    s.mgr->Remove(o);
    s.sel->PickPoint(400, 300, makeCam(50, false), 800, 600);
    printf("selector remove (box 10 added then removed, eye z 50, camera without fov/zrange, pixel 400,300): NbPicked=%d\n", s.sel->NbPicked());
  }
  {
    Scene s;
    s.add(centredBox(10));
    s.sel->PickBox(100, 100, 700, 500, makeCam(50, true), 800, 600);
    printf("selector rect (box 10, eye z 50, full camera, box pick 100,100..700,500): NbPicked=%d\n", s.sel->NbPicked());
  }
  {
    Scene                   s;
    Handle(ProbeSelectable) a = s.add(centredBox(10));
    Handle(ProbeSelectable) b = s.add(centredBox(10));
    s.mgr->Remove(a);
    s.mgr->Remove(b);
    s.sel->PickPoint(400, 300, makeCam(50, false), 800, 600);
    printf("selector clear (two boxes added then both removed, pixel 400,300): NbPicked=%d\n", s.sel->NbPicked());
  }

  // ---- 2. #1036 unguarded
  unguarded("shapeBeyondTheEye (box x 20..30, z 1000..1010)", 20, 1000, 50);
  unguarded("eyePlaneCutting (box x 20..30, z 0..10)", 20, 0, 5.5);
  unguarded("eyeExactlyOnAFace (box x 20..30, z 0..10)", 20, 0, 10);

  // ---- 3. normal projection
  projection("projectOnSphere line (8,-2,0)-(8,2,0)", gp_Pnt(8, -2, 0), gp_Pnt(8, 2, 0));
  projection("projectOutsideSphere line (15,-5,0)-(15,5,0)", gp_Pnt(15, -5, 0), gp_Pnt(15, 5, 0));

  // ---- 4. graph remove calls
  {
    BRepGraph g;
    build(g);
    removeCall("shellRemoveChild  Shells().RemoveFace(0, 99999)", [&] {
      return g.Editor().Shells().RemoveFace(BRepGraph_ShellId(0), BRepGraph_FaceRefId(99999));
    });
    removeCall("solidRemoveShell  Solids().RemoveShell(0, 99999)", [&] {
      return g.Editor().Solids().RemoveShell(BRepGraph_SolidId(0), BRepGraph_ShellRefId(99999));
    });
    removeCall("solidRemoveChild  Solids().RemoveShell(0, 99999)", [&] {
      return g.Editor().Solids().RemoveShell(BRepGraph_SolidId(0), BRepGraph_ShellRefId(99999));
    });
    removeCall("compoundRemoveChild  Compounds().RemoveChild(0, 99999)", [&] {
      return g.Editor().Compounds().RemoveChild(BRepGraph_CompoundId(0), BRepGraph_ChildRefId(99999));
    });
    removeCall("compSolidRemoveSolid  CompSolids().RemoveSolid(0, 99999)", [&] {
      return g.Editor().CompSolids().RemoveSolid(BRepGraph_CompSolidId(0), BRepGraph_SolidRefId(99999));
    });
  }

  // ---- 5. precision re-measurement
  {
    Handle(Graphic3d_Camera) c = plainCam();
    c->SetAspect(1.5);
    const NCollection_Mat4<float>& m = c->ProjectionMatrixF();
    printf("cameraProjection (default camera, aspect 1.5): m00=%.17g m11=%.17g m22=%.17g m23=%.17g\n",
           (double)m.GetValue(0, 0), (double)m.GetValue(1, 1), (double)m.GetValue(2, 2), (double)m.GetValue(2, 3));
  }
  {
    Handle(Graphic3d_Camera) c = plainCam();
    c->SetEye(gp_Pnt(0, 0, 100));
    c->SetCenter(gp_Pnt(0, 0, 0));
    c->SetUp(gp_Dir(0, 1, 0));
    c->SetAspect(1.0);
    c->SetZRange(1, 1000);
    c->SetProjectionType(Graphic3d_Camera::Projection_Perspective);
    double persp = (double)c->ProjectionMatrixF().GetValue(0, 0);
    c->SetProjectionType(Graphic3d_Camera::Projection_Orthographic);
    double ortho = (double)c->ProjectionMatrixF().GetValue(0, 0);
    printf("cameraOrthographic (eye z 100, aspect 1, z range 1..1000): perspM00=%.17g orthoM00=%.17g\n", persp, ortho);
  }
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(20, -5, -1010), 10, 10, 10).Shape();
    Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
    algo->Add(box);
    algo->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 50));
    algo->Update();
    algo->Hide();
    HLRBRep_HLRToShape h(algo);
    TopoDS_Shape       v[3] = {h.VCompound(), h.Rg1LineVCompound(), h.OutLineVCompound()};
    TopoDS_Compound    c    = joinN(v, 3);
    Bnd_Box            bb;
    BRepBndLib::Add(c, bb, true);
    double x0, y0, z0, x1, y1, z1;
    bb.Get(x0, y0, z0, x1, y1, z1);
    printf("shapeBehindThePicturePlane (box x 20..30, z -1010..-1000, focus 50): visible x range [%.17g, %.17g]\n", x0, x1);
  }
  {
    const double iso = 1.0 / std::sqrt(3.0);
    polyView("fastIsometricBox (PolyAlgo, box 20x10x5, deflection 0.01)",
             BRepPrimAPI_MakeBox(gp_Pnt(-10, -5, -2.5), 20, 10, 5).Shape(), gp_Dir(iso, iso, iso), true, false);
    polyView("fastProjectCylinder (PolyAlgo, cylinder r5 h10 down +X, deflection 0.01)",
             BRepPrimAPI_MakeCylinder(5, 10).Shape(), gp_Dir(1, 0, 0), false, true);
  }
  return 0;
}
