// #1392: find a solid that BRepCheck_Solid flags, and confirm what the whole-shape
// BRepCheck_Analyzer path (Shape.checkResult) says about the same shape.
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <BRepCheck_Solid.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>

static const char* statusName(BRepCheck_Status s)
{
  switch (s)
  {
    case BRepCheck_NoError: return "NoError";
    case BRepCheck_InvalidPointOnCurve: return "InvalidPointOnCurve";
    case BRepCheck_BadOrientationOfSubshape: return "BadOrientationOfSubshape";
    case BRepCheck_NotClosed: return "NotClosed";
    case BRepCheck_RedundantEdge: return "RedundantEdge";
    case BRepCheck_InvalidImbricationOfShells: return "InvalidImbricationOfShells";
    case BRepCheck_EnclosedRegion: return "EnclosedRegion";
    case BRepCheck_SubshapeNotInShape: return "SubshapeNotInShape";
    default: return "other";
  }
}

static void report(const char* label, const TopoDS_Solid& solid)
{
  Handle(BRepCheck_Solid) checker = new BRepCheck_Solid(solid);
  checker->Minimum();
  const BRepCheck_ListOfStatus& list = checker->Status();
  printf("%-40s BRepCheck_Solid:", label);
  bool any = false;
  for (auto it = list.begin(); it != list.end(); ++it)
  {
    printf(" %s(%d)", statusName(*it), (int)*it);
    if (*it != BRepCheck_NoError) any = true;
  }
  if (list.begin() == list.end()) printf(" <empty>");
  BRepCheck_Analyzer an(solid);
  printf("   | analyzer.IsValid=%d | solid-flagged=%d\n", (int)an.IsValid(), (int)any);
}

int main()
{
  // 1. an ordinary box solid: the control
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
  TopExp_Explorer exp(box, TopAbs_SOLID);
  report("valid box", TopoDS::Solid(exp.Current()));

  // 2. the same shell used twice in one solid: two coincident shells
  TopExp_Explorer sexp(box, TopAbs_SHELL);
  TopoDS_Shell shell = TopoDS::Shell(sexp.Current());
  {
    BRep_Builder b;
    TopoDS_Solid s;
    b.MakeSolid(s);
    b.Add(s, shell);
    b.Add(s, shell);
    report("same shell added twice", s);
  }

  // 3. a shell reversed, so the material side points outward
  {
    BRep_Builder b;
    TopoDS_Solid s;
    b.MakeSolid(s);
    b.Add(s, TopoDS::Shell(shell.Reversed()));
    report("single reversed shell", s);
  }

  // 4. two disjoint boxes as two shells of one solid (legal: two lumps)
  {
    TopoDS_Shape box2 = BRepPrimAPI_MakeBox(gp_Pnt(50, 0, 0), 10, 10, 10).Shape();
    TopExp_Explorer s2(box2, TopAbs_SHELL);
    BRep_Builder b;
    TopoDS_Solid s;
    b.MakeSolid(s);
    b.Add(s, shell);
    b.Add(s, TopoDS::Shell(s2.Current()));
    report("two disjoint shells", s);
  }

  // 5. a smaller box fully inside the big one, both forward: bad imbrication
  {
    TopoDS_Shape inner = BRepPrimAPI_MakeBox(gp_Pnt(2, 2, 2), 3, 3, 3).Shape();
    TopExp_Explorer ie(inner, TopAbs_SHELL);
    BRep_Builder b;
    TopoDS_Solid s;
    b.MakeSolid(s);
    b.Add(s, shell);
    b.Add(s, TopoDS::Shell(ie.Current())); // forward, not reversed: not a void
    report("nested shell, both forward", s);
  }
  return 0;
}
