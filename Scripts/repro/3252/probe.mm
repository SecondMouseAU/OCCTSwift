// #3252: ShapeFix_EdgeConnect on a valid box. Does it edit the caller's shape, and is the result valid?
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRep_Builder.hxx>
#include <ShapeFix_EdgeConnect.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Wire.hxx>
#include <BRep_Tool.hxx>
#include <gp_Pnt.hxx>
#include <iostream>

static void report(const char* tag, const TopoDS_Shape& s)
{
  BRepCheck_Analyzer a(s);
  std::cout << tag << ": valid=" << a.IsValid() << "\n";
  for (TopAbs_ShapeEnum t : {TopAbs_WIRE, TopAbs_FACE, TopAbs_SHELL, TopAbs_SOLID})
  {
    int bad = 0, n = 0;
    for (TopExp_Explorer e(s, t); e.More(); e.Next())
    {
      ++n;
      if (!BRepCheck_Analyzer(e.Current()).IsValid()) ++bad;
    }
    std::cout << "   type " << t << " invalid " << bad << " of " << n << "\n";
  }
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
  report("box before", box);

  // A: in place on the caller's shape (what the bridge does today)
  {
    TopoDS_Shape b = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
    ShapeFix_EdgeConnect c; c.Add(b); c.Build();
    report("A in place, caller's shape after", b);
  }
  // B: on a copy
  {
    TopoDS_Shape b = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
    BRepBuilderAPI_Copy cp(b, true);
    TopoDS_Shape work = cp.Shape();
    ShapeFix_EdgeConnect c; c.Add(work); c.Build();
    report("B original after copy-run", b);
    report("B copy after", work);
  }
  // C: the case it was written for: a closed wire whose edges carry distinct, slightly-apart vertices
  {
    gp_Pnt p0(0,0,0), p1(10,0,0), p2(10,10,0), p3(0,10,0);
    gp_Pnt q1(10,0,1e-5), q2(10.00001,10,0), q3(0,10.00001,0), q0(0,1e-5,0);
    TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p0, p1);
    TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(q1, p2);
    TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(q2, p3);
    TopoDS_Edge e4 = BRepBuilderAPI_MakeEdge(q3, q0);
    TopoDS_Wire w; BRep_Builder bb; bb.MakeWire(w);
    bb.Add(w, e1); bb.Add(w, e2); bb.Add(w, e3); bb.Add(w, e4);
    w.Closed(true);
    report("C wire before", w);
    ShapeFix_EdgeConnect c; c.Add(w); c.Build();
    report("C wire after", w);
    TopExp_Explorer ex(w, TopAbs_VERTEX); int n=0; for(;ex.More();ex.Next()) ++n;
    std::cout << "   vertex occurrences " << n << "\n";
  }
}
