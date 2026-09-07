// #1631: does IntTools_EdgeFace find anything without SetRange?
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <IntTools_EdgeFace.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <BRep_Tool.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10., 10., 10.).Shape();
  TopoDS_Edge  e   = BRepBuilderAPI_MakeEdge(gp_Pnt(5., 5., -5.), gp_Pnt(5., 5., 15.)).Edge();
  double f = 0., l = 0.;
  BRep_Tool::Range(e, f, l);

  int faceIndex = 0;
  for (TopExp_Explorer exp(box, TopAbs_FACE); exp.More(); exp.Next(), ++faceIndex)
  {
    TopoDS_Face face = TopoDS::Face(exp.Current());
    for (int withRange = 0; withRange < 2; ++withRange)
    {
      IntTools_EdgeFace ef;
      ef.SetEdge(e);
      ef.SetFace(face);
      ef.SetFuzzyValue(1.e-7);
      if (withRange) ef.SetRange(IntTools_Range(f, l));
      ef.Perform();
      printf("face %d  %-12s done=%d  commonParts=%d\n", faceIndex,
             withRange ? "with range" : "no range", (int)ef.IsDone(),
             ef.IsDone() ? ef.CommonParts().Length() : -1);
    }
  }
  return 0;
}
