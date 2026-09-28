// Ground truth: what does OCCTIntToolsEdgeEdge's chain actually do with a bad input?
//
// The bridge writes, with no guard at all:
//
//   const TopoDS_Edge& e1 = TopoDS::Edge(edge1->shape);
//   const TopoDS_Edge& e2 = TopoDS::Edge(edge2->shape);
//   IntTools_EdgeEdge ee(e1, e2);
//   ee.Perform();
//
// inside one function-level try/catch (...). Its sibling OCCTIntToolsEdgeFace guards both
// arguments with occtShapeIsType() first. This asks whether the try/catch is enough: is a bad
// input a catchable Standard_Failure, or an uncatchable signal?
//
// Each case runs in a forked child, so a crash is reported with its signal rather than ending the
// probe. Exit code is the number of uncatchable cases clamped to 0/1.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_EdgeEdge.hxx>
#include <IntTools_EdgeFace.hxx>
#include <IntTools_Range.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <typeinfo>
#include <cstdlib>
#include <functional>
#include <string>
#include <sys/wait.h>
#include <unistd.h>

static int gUncatchable = 0;

static void run(const char* label, const std::function<void()>& body)
{
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    // Exactly the bridge's own shape: one function-level catch (...) and nothing else.
    try
    {
      body();
      printf("  RETURNED NORMALLY\n");
    }
    catch (const Standard_Failure& f)
    {
      printf("  CAUGHT Standard_Failure: %s (%s)\n",
             typeid(f).name(),
             f.GetMessageString() ? f.GetMessageString() : "");
    }
    catch (...)
    {
      printf("  CAUGHT unknown C++ exception\n");
    }
    fflush(stdout);
    _exit(0);
  }
  int status = 0;
  waitpid(pid, &status, 0);
  printf("%s\n", label);
  if (WIFSIGNALED(status))
  {
    printf("  UNCATCHABLE: killed by signal %d\n", WTERMSIG(status));
    gUncatchable++;
  }
  fflush(stdout);
}

static TopoDS_Edge realEdge(double x0, double x1)
{
  return TopoDS::Edge(BRepBuilderAPI_MakeEdge(gp_Pnt(x0, 0, 0), gp_Pnt(x1, 0, 0)).Shape());
}

int main()
{
  const TopoDS_Shape nullShape;   // what Shape.nullified's handle carries
  const TopoDS_Edge  nullEdge;
  const TopoDS_Shape box = BRepPrimAPI_MakeBox(1.0, 1.0, 1.0).Shape();
  TopoDS_Face        aFace;
  for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next())
  {
    aFace = TopoDS::Face(ex.Current());
    break;
  }

  printf("== the cast itself ==\n");
  run("A1 TopoDS::Edge(null TopoDS_Shape)", [&] {
    const TopoDS_Edge& e = TopoDS::Edge(nullShape);
    printf("  cast ok, IsNull=%d\n", (int)e.IsNull());
  });
  run("A2 TopoDS::Edge(a FACE)", [&] {
    const TopoDS_Edge& e = TopoDS::Edge(aFace);
    printf("  cast ok (unexpected), IsNull=%d\n", (int)e.IsNull());
  });
  run("A3 TopoDS::Edge(a SOLID box)", [&] {
    const TopoDS_Edge& e = TopoDS::Edge(box);
    printf("  cast ok (unexpected), IsNull=%d\n", (int)e.IsNull());
  });

  printf("\n== IntTools_EdgeEdge, the bridge's exact chain ==\n");
  run("B1 ctor only, both edges null (no Perform)", [&] {
    IntTools_EdgeEdge ee(nullEdge, nullEdge);
    printf("  ctor ok\n");
  });
  run("B2 ctor + Perform, both edges null", [&] {
    IntTools_EdgeEdge ee(nullEdge, nullEdge);
    ee.Perform();
    printf("  Perform ok, IsDone=%d\n", (int)ee.IsDone());
  });
  run("B3 ctor + Perform, edge1 null, edge2 real", [&] {
    IntTools_EdgeEdge ee(nullEdge, realEdge(0, 2));
    ee.Perform();
    printf("  Perform ok, IsDone=%d\n", (int)ee.IsDone());
  });
  run("B4 ctor + Perform, edge1 real, edge2 null", [&] {
    IntTools_EdgeEdge ee(realEdge(0, 2), nullEdge);
    ee.Perform();
    printf("  Perform ok, IsDone=%d\n", (int)ee.IsDone());
  });
  run("B5 the whole bridge body, both nulls, through the cast", [&] {
    const TopoDS_Edge& e1 = TopoDS::Edge(nullShape);
    const TopoDS_Edge& e2 = TopoDS::Edge(nullShape);
    IntTools_EdgeEdge  ee(e1, e2);
    ee.Perform();
    if (ee.IsDone())
    {
      printf("  IsDone, %d common part(s)\n", ee.CommonParts().Length());
    }
    else
    {
      printf("  not done\n");
    }
  });
  run("B6 the whole bridge body, edge1 a FACE (wrong type)", [&] {
    const TopoDS_Edge& e1 = TopoDS::Edge(aFace);
    const TopoDS_Edge& e2 = TopoDS::Edge(realEdge(0, 2));
    IntTools_EdgeEdge  ee(e1, e2);
    ee.Perform();
    printf("  Perform ok, IsDone=%d\n", (int)ee.IsDone());
  });
  run("B7 two real overlapping edges (the control)", [&] {
    IntTools_EdgeEdge ee(realEdge(0, 2), realEdge(1, 3));
    ee.Perform();
    printf("  Perform ok, IsDone=%d, %d common part(s)\n",
           (int)ee.IsDone(),
           ee.IsDone() ? ee.CommonParts().Length() : -1);
  });

  printf("\n== the sibling's chain, for comparison (it IS guarded today) ==\n");
  run("C1 IntTools_EdgeFace with a null edge and a null face", [&] {
    IntTools_EdgeFace ef;
    ef.SetEdge(nullEdge);
    ef.SetFace(TopoDS_Face());
    double first = 0.0, last = 0.0;
    BRep_Tool::Range(nullEdge, first, last);
    ef.SetRange(IntTools_Range(first, last));
    ef.Perform();
    printf("  Perform ok, IsDone=%d\n", (int)ef.IsDone());
  });

  run("C2 IntTools_EdgeFace::Perform alone, null edge and null face, NO BRep_Tool::Range", [&] {
    IntTools_EdgeFace ef;
    ef.SetEdge(nullEdge);
    ef.SetFace(TopoDS_Face());
    ef.SetRange(IntTools_Range(0.0, 1.0));
    ef.Perform();
    printf("  Perform ok, IsDone=%d\n", (int)ef.IsDone());
  });

  printf("\n== the four sites the widened gate regex reports ==\n");
  run("D1 BRep_Tool::Curve(null edge, f, l)", [&] {
    double            f = 0.0, l = 0.0;
    Handle(Geom_Curve) c = BRep_Tool::Curve(nullEdge, f, l);
    printf("  returned, IsNull=%d\n", (int)c.IsNull());
  });
  run("D2 BRep_Tool::CurveOnSurface(null edge, null face, f, l)", [&] {
    double f = 0.0, l = 0.0;
    auto   c = BRep_Tool::CurveOnSurface(nullEdge, TopoDS_Face(), f, l);
    printf("  returned, IsNull=%d\n", (int)c.IsNull());
  });
  run("D3 BRep_Tool::Degenerated(null edge)", [&] {
    printf("  returned %d\n", (int)BRep_Tool::Degenerated(nullEdge));
  });
  run("D4 BRep_Tool::Range(null edge, null face, f, l)", [&] {
    double f = 0.0, l = 0.0;
    BRep_Tool::Range(nullEdge, TopoDS_Face(), f, l);
    printf("  returned %g %g\n", f, l);
  });

  run("D5 BRep_Tool::Surface(null face)", [&] {
    Handle(Geom_Surface) su = BRep_Tool::Surface(TopoDS_Face());
    printf("  returned, IsNull=%d\n", (int)su.IsNull());
  });
  run("D6 BRep_Tool::Tolerance(null edge)", [&] {
    printf("  returned %g\n", BRep_Tool::Tolerance(nullEdge));
  });

  printf("\n%d uncatchable case(s)\n", gUncatchable);
  return gUncatchable ? 1 : 0;
}
