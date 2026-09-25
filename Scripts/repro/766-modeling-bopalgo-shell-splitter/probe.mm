// Epic #766, Tests/OCCTModelingTests/BOPAlgoShellSplitterTests.swift: kernel parity.
// OCCTBOPAlgoShellSplitter: BOPAlgo_ShellSplitter, AddStartElement(shell), Perform, Shells().
#include <BOPAlgo_ShellSplitter.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape    box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopExp_Explorer ex(box, TopAbs_SHELL);
  BOPAlgo_ShellSplitter ss;
  ss.AddStartElement(TopoDS::Shell(ex.Current()));
  ss.Perform();
  printf("splitSingleShell: hasErrors=%d shells=%d", ss.HasErrors(), ss.Shells().Extent());
  if (!ss.Shells().IsEmpty())
  {
    TopTools_IndexedMapOfShape f;
    TopExp::MapShapes(ss.Shells().First(), TopAbs_FACE, f);
    printf(" firstFaces=%d", f.Extent());
  }
  printf("\n");
  return 0;
}
