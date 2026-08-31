// #369: confirm the General Fuse (bare BRepAlgoAPI_BuilderAlgo) result that
// occt_342_boolean_stress's fuse_multi_parallel scenario flags as "wrong" (27 faces vs a
// BRepAlgoAPI_Fuse baseline of 13) is a VALID, coherent shape -- not literally corrupted garbage
// that happens to have a matching volume by coincidence.
#include <cstdio>
#include <BRepAlgoAPI_BuilderAlgo.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ListOfShape.hxx>
#include <gp_Pnt.hxx>

int main() {
    TopTools_ListOfShape args;
    args.Append(BRepPrimAPI_MakeBox(10, 10, 10).Shape());
    args.Append(BRepPrimAPI_MakeSphere(gp_Pnt(5, 5, 5), 6).Shape());
    BRepAlgoAPI_BuilderAlgo builder;
    builder.SetArguments(args);
    builder.SetRunParallel(false);
    builder.Build();
    printf("IsDone=%d\n", builder.IsDone() ? 1 : 0);
    TopoDS_Shape result = builder.Shape();
    printf("shape type=%d (0=COMPOUND,2=SHELL,3=FACE)\n", (int)result.ShapeType());

    int solids = 0, shells = 0, faces = 0;
    for (TopExp_Explorer e(result, TopAbs_SOLID); e.More(); e.Next()) solids++;
    for (TopExp_Explorer e(result, TopAbs_SHELL); e.More(); e.Next()) shells++;
    for (TopExp_Explorer e(result, TopAbs_FACE); e.More(); e.Next()) faces++;
    printf("solids=%d shells=%d faces=%d\n", solids, shells, faces);

    BRepCheck_Analyzer analyzer(result);
    printf("BRepCheck_Analyzer.IsValid=%d\n", analyzer.IsValid() ? 1 : 0);
    return analyzer.IsValid() ? 0 : 1;
}
