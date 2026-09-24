// Epic #766, PipeFeatureTests.swift and the five PipeShell*Tests.swift files: kernel parity for
// the thirteen tests. Same inputs, straight to OCCT:
//  - BRepFeat_MakePipe(box, profile face, face 6 of the centred box, spine, fuse, true)
//    (OCCTShapePipeFeatureFromProfile; sketchFaceIndex 5 is map index 6).
//  - BRepFill_PipeShell on the spine wire, Set(frenet), Add(profile), SetIsBuildHistory(false),
//    Build (OCCTPipeShell*), plus GetStatus, Simulate, ErrorOnSurface, First/LastShape.
//  - BRepOffsetAPI_MakePipe(path, profile) (OCCTShapeCreatePipeSweep, Shape.sweep).
//  - BRepOffsetAPI_MakePipeShell with SetMode(frenet = true), the transition mode, Add(profile),
//    SetIsBuildHistory(false), Build, MakeSolid (OCCTShapeCreatePipeShellMultiSection).
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFeat_MakePipe.hxx>
#include <BRepFill_PipeShell.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <Geom_Circle.hxx>
#include <NCollection_List.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <cstdio>

static TopoDS_Wire circle(gp_Pnt o, gp_Dir n, double r)
{
  return BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(new Geom_Circle(gp_Ax2(o, n), r)).Edge()).Wire();
}

static TopoDS_Wire rect(double w, double h)
{
  return BRepBuilderAPI_MakePolygon(gp_Pnt(-w / 2, -h / 2, 0), gp_Pnt(w / 2, -h / 2, 0), gp_Pnt(w / 2, h / 2, 0),
                                    gp_Pnt(-w / 2, h / 2, 0), true)
    .Wire();
}

static void props(const char* name, const TopoDS_Shape& s)
{
  if (s.IsNull())
  {
    printf("%s: null\n", name);
    return;
  }
  GProp_GProps v, a;
  BRepGProp::VolumeProperties(s, v);
  BRepGProp::SurfaceProperties(s, a);
  printf("%s: type=%d valid=%d volume=%.17g area=%.17g\n", name, (int)s.ShapeType(), BRepCheck_Analyzer(s).IsValid(), v.Mass(),
         a.Mass());
}

static void feature(const char* name, double boxSize, const TopoDS_Wire& profileWire, double half)
{
  try
  {
    TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-boxSize / 2, -boxSize / 2, -boxSize / 2), boxSize, boxSize, boxSize).Shape();
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(box, TopAbs_FACE, faces);
    TopoDS_Face       prof  = BRepBuilderAPI_MakeFace(profileWire, true).Face();
    TopoDS_Wire       spine = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, half), gp_Pnt(0, 0, -half)).Edge()).Wire();
    BRepFeat_MakePipe m(box, prof, TopoDS::Face(faces(6)), spine, 0, true);
    m.Perform();
    printf("%s: IsDone=%d ", name, m.IsDone());
    if (m.IsDone())
      props("", m.Shape());
    else
      printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", name, e.GetMessageString());
  }
}

static void fill(const char* name, const TopoDS_Wire& spine, const TopoDS_Wire& profile, bool frenet, bool build, int maxDeg = 0)
{
  try
  {
    Handle(BRepFill_PipeShell) ps = new BRepFill_PipeShell(spine);
    ps->Set(frenet);
    ps->Add(profile);
    if (maxDeg)
      ps->SetMaxDegree(maxDeg);
    printf("%s: IsReady=%d status=%d", name, ps->IsReady(), (int)ps->GetStatus());
    NCollection_List<TopoDS_Shape> secs;
    ps->Simulate(5, secs);
    printf(" simulate(5)=%d", secs.Size());
    if (build)
    {
      ps->SetIsBuildHistory(false);
      bool ok = ps->Build();
      printf(" Build=%d ErrorOnSurface=%.17g first=%s last=%s ", ok, ps->ErrorOnSurface(), ps->FirstShape().IsNull() ? "null" : "shape",
             ps->LastShape().IsNull() ? "null" : "shape");
      if (ok)
      {
        props("shape()", ps->Shape());
        printf("  after MakeSolid=%d ", ps->MakeSolid());
        props("", ps->Shape());
      }
      else
        printf("\n");
    }
    else
      printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", name, e.GetMessageString());
  }
}

static void shell(const char* name, const TopoDS_Wire& spine, const TopoDS_Wire& profile, BRepBuilderAPI_TransitionMode t)
{
  try
  {
    BRepOffsetAPI_MakePipeShell p(spine);
    p.SetMode(true);
    p.SetTransitionMode(t);
    p.Add(profile, false, false);
    p.SetIsBuildHistory(false);
    p.Build();
    printf("%s: IsDone=%d", name, p.IsDone());
    if (p.IsDone())
    {
      bool solid = p.MakeSolid();
      printf(" MakeSolid=%d ", solid);
      props("", p.Shape());
    }
    else
      printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", name, e.GetMessageString());
  }
}

int main()
{
  feature("pipeFeatureCallable", 20, circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 2), 10);
  feature("pipeFeatureCurvedSpine", 30, rect(2, 2), 15);

  // Note BRepFill_PipeShell::Set(frenet) as OCCTPipeShellSetFrenet calls it.
  fill("circularSpineCircularProfile", circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 15), circle(gp_Pnt(15, 0, 0), gp_Dir(0, 1, 0), 3), true, true);
  try
  {
    BRepOffsetAPI_MakePipe p(circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 10), circle(gp_Pnt(10, 0, 0), gp_Dir(0, 1, 0), 2));
    p.Build();
    printf("highLevelPipeShellClosed: IsDone=%d ", p.IsDone());
    if (p.IsDone())
      props("", p.Shape());
    else
      printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("highLevelPipeShellClosed: threw %s\n", e.GetMessageString());
  }
  fill("getStatus (no Set)", circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 10), circle(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0), 2), false, false);
  fill("simulate", rect(10, 10), circle(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0), 1), true, false);
  fill("pipeShellMaxDegreeAndSegments", circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 10), circle(gp_Pnt(10, 0, 0), gp_Dir(1, 0, 0), 1), true, false, 6);
  fill("pipeShellErrorAndShapes", circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 10), circle(gp_Pnt(10, 0, 0), gp_Dir(1, 0, 0), 1), true, true, 8);
  fill("basicPipeShell", rect(10, 10), circle(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0), 1), true, true);
  {
    Handle(BRepFill_PipeShell) ps = new BRepFill_PipeShell(circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 10));
    printf("pipeShellIsReady: IsReady before Add=%d\n", ps->IsReady());
  }

  TopoDS_Wire l1 = BRepBuilderAPI_MakePolygon(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0)).Wire();
  shell("pipeTransformed", l1, circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 1), BRepBuilderAPI_Transformed);
  // The same L spine with the profile perpendicular to its first segment (normal +X).
  shell("pipeTransformed (profile normal X)", l1, circle(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0), 1), BRepBuilderAPI_Transformed);
  TopoDS_Wire l2 = BRepBuilderAPI_MakePolygon(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), gp_Pnt(0, 10, 10)).Wire();
  shell("pipeRightCorner", l2, circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 2), BRepBuilderAPI_RightCorner);
  shell("pipeRoundCorner", l2, circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 2), BRepBuilderAPI_RoundCorner);
  return 0;
}
