// Epic #766 evidence correction for PR #2692 (Tests/OCCTModelingTests/FilletBuilderHistoryTests.swift).
// probe.mm printed the kernel side under the OCCT member names (GetBounds, Generated(edge).Size,
// IsDeleted(edge), ...) while the bridge side used the Swift names. The parity records now carry the
// same keys and types on both sides, so this probe repeats the same calls under those keys, every
// flag as true/false and every double at %.17g, one `label: key=value ...` line per test. Mapping:
// getBounds = GetBounds(1, E, first, last) returned true, lawNull = GetLaw(1, E).IsNull(),
// law(first)/law(last) = the law evaluated at first and last, generatedFromEdge = Generated(E).Size(),
// faces = the box's TopExp_Explorer faces, facesWithModified = those with Modified(face).Size() > 0,
// isDeleted = IsDeleted(E). 10 mm box centred at the origin, first TopExp::MapShapes edge.
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Law_Function.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static const char* tf(bool b) { return b ? "true" : "false"; }

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
    // Evolving radius 0.5 to 2.0, because a constant one has no law to bound (#505).
    TopoDS_Shape             b = box();
    TopoDS_Edge              e = firstEdge(b);
    BRepFilletAPI_MakeFillet f(b);
    f.Add(0.5, 2.0, e);
    f.Build();
    double first = 0, last = 0;
    bool   ok  = f.GetBounds(1, e, first, last);
    auto   law = f.GetLaw(1, e);
    printf("getBoundsForEvolvingRadius: getBounds=%s first=%.17g last=%.17g\n", tf(ok), first, last);
    printf("getLawForEvolvingRadius: lawNull=%s", tf(law.IsNull()));
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
    printf("generated: generatedFromEdge=%d\n", (int)f.Generated(e).Size());
    printf("isDeleted: isDeleted=%s\n", tf(f.IsDeleted(e)));
    int faces = 0, anyMod = 0;
    for (TopExp_Explorer ex(b, TopAbs_FACE); ex.More(); ex.Next(), faces++)
      anyMod += f.Modified(ex.Current()).Size() > 0;
    printf("modified: faces=%d facesWithModified=%d\n", faces, anyMod);
  }
  return 0;
}
