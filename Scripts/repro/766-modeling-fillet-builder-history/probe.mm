// Epic #766, Tests/OCCTModelingTests/FilletBuilderHistoryTests.swift: kernel parity for all five
// tests. FilletBuilder is one BRepFilletAPI_MakeFillet; GetBounds / GetLaw / Generated / Modified /
// IsDeleted are that class's members (OCCTFilletBuilderGetBounds, ...GetLaw, ...Generated,
// ...Modified, ...IsDeleted). 10 mm box centred at the origin, first TopExp::MapShapes edge.
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Law_Function.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Shape box() { return BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(); }

static TopoDS_Edge firstEdge(const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_EDGE, m);
  return TopoDS::Edge(m(1));
}

int main()
{
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(0.5, 2.0, e);
    f.Build();
    double first = 0, last = 0;
    bool   ok  = f.GetBounds(1, e, first, last);
    auto   law = f.GetLaw(1, e);
    printf("evolving: done=%d contour=%d getBounds=%d first=%.17g last=%.17g lawNull=%d", f.IsDone(),
           f.Contour(e), ok, first, last, law.IsNull());
    if (!law.IsNull())
      printf(" law(first)=%.17g law(last)=%.17g", law->Value(first), law->Value(last));
    printf("\n");
  }
  {
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(1.0, e);
    f.Build();
    printf("constant r=1: done=%d generated(edge)=%d isDeleted(edge)=%d\n", f.IsDone(),
           f.Generated(e).Size(), f.IsDeleted(e));
    int idx = 0, anyMod = 0;
    for (TopExp_Explorer ex(b, TopAbs_FACE); ex.More(); ex.Next(), idx++)
    {
      int n = f.Modified(ex.Current()).Size();
      anyMod += n > 0;
      printf("  face %d: modified=%d\n", idx, n);
    }
    printf("constant r=1: facesModified=%d\n", anyMod);
  }
  return 0;
}
