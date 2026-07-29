// #484: null-ReShape-context dereferences in the OCCT healing family.
//
// #317 (Scripts/patches/0005) guarded ONE such site
// (ShapeFix_Face::FixPeriodicDegenerated). This probe checks the siblings the
// bridge currently papers over with a local SetContext() call, plus
// ShapeFix_Face::Perform itself against a face with intersecting wires.
//
// Each case runs in a forked child, so a SIGSEGV in one still lets the rest run.
#include <signal.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Plane.hxx>
#include <NCollection_HArray2.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeExtend_CompositeSurface.hxx>
#include <ShapeFix_ComposeShell.hxx>
#include <ShapeFix_Face.hxx>
#include <ShapeFix_Wire.hxx>
#include <ShapeUpgrade_WireDivide.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Pln.hxx>

// A planar face whose outer wire and inner wire cross each other.
static TopoDS_Face intersectingWiresFace()
{
  BRepBuilderAPI_MakePolygon outer;
  outer.Add(gp_Pnt(0, 0, 0));
  outer.Add(gp_Pnt(10, 0, 0));
  outer.Add(gp_Pnt(10, 10, 0));
  outer.Add(gp_Pnt(0, 10, 0));
  outer.Close();

  BRepBuilderAPI_MakePolygon inner;
  inner.Add(gp_Pnt(5, 5, 0));
  inner.Add(gp_Pnt(15, 5, 0));
  inner.Add(gp_Pnt(15, 8, 0));
  inner.Add(gp_Pnt(5, 8, 0));
  inner.Close();

  Handle(Geom_Plane)      pln = new Geom_Plane(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  BRepBuilderAPI_MakeFace mf(pln, outer.Wire(), Standard_True);
  if (!mf.IsDone())
    return TopoDS_Face();
  mf.Add(TopoDS::Wire(inner.Wire().Reversed()));
  return mf.IsDone() ? mf.Face() : TopoDS_Face();
}

static TopoDS_Face squareFace()
{
  BRepBuilderAPI_MakePolygon p;
  p.Add(gp_Pnt(0, 0, 0));
  p.Add(gp_Pnt(10, 0, 0));
  p.Add(gp_Pnt(10, 10, 0));
  p.Add(gp_Pnt(0, 10, 0));
  p.Close();
  Handle(Geom_Plane)      pln = new Geom_Plane(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  BRepBuilderAPI_MakeFace mf(pln, p.Wire(), Standard_True);
  return mf.IsDone() ? mf.Face() : TopoDS_Face();
}

// ---- cases -----------------------------------------------------------------

static void caseFacePerformIntersectingWires(bool withContext)
{
  TopoDS_Face f = intersectingWiresFace();
  if (f.IsNull())
  {
    printf("no face\n");
    return;
  }
  ShapeFix_Face fixer(f);
  if (withContext)
    fixer.SetContext(new ShapeBuild_ReShape);
  fixer.SetPrecision(1e-6);
  fixer.FixWireMode()            = 1;
  fixer.FixOrientationMode()     = 1;
  fixer.FixAddNaturalBoundMode() = 1;
  fixer.FixMissingSeamMode()     = 1;
  fixer.FixSmallAreaWireMode()   = 1;
  bool ok = fixer.Perform();
  printf("Perform=%d resultNull=%d\n", (int)ok, (int)fixer.Face().IsNull());
}

static void caseFaceFixIntersectingWiresDirect(bool withContext)
{
  TopoDS_Face f = intersectingWiresFace();
  if (f.IsNull())
  {
    printf("no face\n");
    return;
  }
  ShapeFix_Face fixer(f);
  if (withContext)
    fixer.SetContext(new ShapeBuild_ReShape);
  fixer.SetPrecision(1e-6);
  bool ok = fixer.FixIntersectingWires();
  printf("FixIntersectingWires=%d\n", (int)ok);
}

static void caseWireDivide(bool withContext)
{
  TopoDS_Face f = squareFace();
  if (f.IsNull())
  {
    printf("no face\n");
    return;
  }
  TopoDS_Wire w;
  for (TopExp_Explorer ex(f, TopAbs_WIRE); ex.More(); ex.Next())
  {
    w = TopoDS::Wire(ex.Current());
    break;
  }
  Handle(ShapeUpgrade_WireDivide) wd = new ShapeUpgrade_WireDivide();
  if (withContext)
    wd->SetContext(new ShapeBuild_ReShape);
  wd->Init(w, f);
  wd->Perform();
  printf("Perform done, wireNull=%d\n", (int)wd->Wire().IsNull());
}

static void caseComposeShell(bool withContext)
{
  TopoDS_Face f = squareFace();
  if (f.IsNull())
  {
    printf("no face\n");
    return;
  }
  Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
  Handle(NCollection_HArray2<Handle(Geom_Surface)>) grid =
    new NCollection_HArray2<Handle(Geom_Surface)>(1, 1, 1, 1);
  grid->SetValue(1, 1, surf);
  Handle(ShapeExtend_CompositeSurface) cs = new ShapeExtend_CompositeSurface(grid);

  Handle(ShapeFix_ComposeShell) shell = new ShapeFix_ComposeShell();
  if (withContext)
    shell->SetContext(new ShapeBuild_ReShape);
  shell->Init(cs, TopLoc_Location(), f, 1e-7);
  bool ok = shell->Perform();
  printf("Perform=%d resultNull=%d\n", (int)ok, (int)shell->Result().IsNull());
}

static void caseWireFixerNoContext(bool withContext)
{
  // The OCCTWireFixer* family: ShapeFix_Wire::Init + individual fixes, no context.
  TopoDS_Face f = squareFace();
  TopoDS_Wire w;
  for (TopExp_Explorer ex(f, TopAbs_WIRE); ex.More(); ex.Next())
  {
    w = TopoDS::Wire(ex.Current());
    break;
  }
  Handle(ShapeFix_Wire) fixer = new ShapeFix_Wire();
  if (withContext)
    fixer->SetContext(new ShapeBuild_ReShape);
  fixer->Init(w, f, 1e-6);
  bool a = fixer->FixReorder();
  bool b = fixer->FixConnected();
  bool c = fixer->FixEdgeCurves();
  bool d = fixer->FixSelfIntersection();
  bool e = fixer->FixLacking();
  bool g = fixer->FixGaps3d();
  bool h = fixer->FixGaps2d();
  bool i = fixer->FixNotchedEdges();
  printf("reorder=%d conn=%d curves=%d selfint=%d lack=%d gaps3d=%d gaps2d=%d notch=%d\n", a, b, c,
         d, e, g, h, i);
}

// ---- driver ----------------------------------------------------------------

typedef void (*CaseFn)(bool);

static void run(const char* name, CaseFn fn, bool withContext)
{
  printf("%-46s ctx=%-3s : ", name, withContext ? "yes" : "NO");
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    try
    {
      fn(withContext);
    }
    catch (const Standard_Failure& e)
    {
      printf("Standard_Failure: %s\n", e.GetMessageString() ? e.GetMessageString() : "?");
    }
    catch (...)
    {
      printf("unknown exception\n");
    }
    fflush(stdout);
    _exit(0);
  }
  int st = 0;
  waitpid(pid, &st, 0);
  if (WIFSIGNALED(st))
    printf("  *** KILLED BY SIGNAL %d (%s) ***\n", WTERMSIG(st), strsignal(WTERMSIG(st)));
  fflush(stdout);
}

int main()
{
  run("ShapeFix_Face::Perform / intersecting wires", caseFacePerformIntersectingWires, false);
  run("ShapeFix_Face::Perform / intersecting wires", caseFacePerformIntersectingWires, true);
  run("ShapeFix_Face::FixIntersectingWires direct", caseFaceFixIntersectingWiresDirect, false);
  run("ShapeFix_Face::FixIntersectingWires direct", caseFaceFixIntersectingWiresDirect, true);
  run("ShapeUpgrade_WireDivide::Perform", caseWireDivide, false);
  run("ShapeUpgrade_WireDivide::Perform", caseWireDivide, true);
  run("ShapeFix_ComposeShell::Perform", caseComposeShell, false);
  run("ShapeFix_ComposeShell::Perform", caseComposeShell, true);
  run("ShapeFix_Wire individual fixes", caseWireFixerNoContext, false);
  run("ShapeFix_Wire individual fixes", caseWireFixerNoContext, true);
  printf("\nALL CASES ATTEMPTED\n");
  return 0;
}
