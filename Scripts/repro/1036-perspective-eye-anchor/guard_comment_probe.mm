// Third probe for OCCTSwift #1036: re-measure the exact claims the focus > 0 guard's own comment
// makes, on the fixture that comment names (a 100x50x30 box viewed down +Z). The comment cited
// "focus 0/1e-12/5/15 all return an empty VCompound"; 5 and 15 are positive and accepted, so this
// checks what each value really produces before the comment is rewritten.
//
// Shape.box(width:height:depth:) is centred on the origin, so a 100x50x30 box spans
// x [-50, 50], y [-25, 25], z [-15, 15].

#include <BRepBndLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Bnd_Box.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>

static void row(double focus)
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-50, -25, -15), gp_Pnt(50, 25, 15)).Shape();
  try
  {
    gp_Ax2               projAxis(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    HLRAlgo_Projector    projector(projAxis, focus);
    Handle(HLRBRep_Algo) hlrAlgo = new HLRBRep_Algo();
    hlrAlgo->Add(box);
    hlrAlgo->Projector(projector);
    hlrAlgo->Update();
    hlrAlgo->Hide();
    HLRBRep_HLRToShape shapes(hlrAlgo);
    TopoDS_Shape       visible = shapes.VCompound();

    if (visible.IsNull())
    {
      printf("focus=%-10g -> VCompound NULL\n", focus);
      return;
    }
    int nEdges = 0;
    for (TopExp_Explorer e(visible, TopAbs_EDGE); e.More(); e.Next())
      nEdges++;
    if (nEdges == 0)
    {
      printf("focus=%-10g -> VCompound EMPTY (0 edges)\n", focus);
      return;
    }
    Bnd_Box bb;
    BRepBndLib::Add(visible, bb);
    double a, b, c, d, e2, f;
    bb.Get(a, b, c, d, e2, f);
    printf("focus=%-10g -> edges=%-3d x=[%14.5f, %14.5f] y=[%12.5f, %12.5f]\n",
           focus,
           nEdges,
           a,
           d,
           b,
           e2);
  }
  catch (...)
  {
    printf("focus=%-10g -> THREW\n", focus);
  }
}

int main()
{
  printf("100x50x30 centred box, x [-50,50] z [-15,15], viewed down +Z.\n");
  printf("Orthographic truth would be x [-50, 50].\n\n");
  row(0.0);
  row(1e-12);
  row(5.0);
  row(15.0);
  row(-100.0);
  printf("\nfor contrast, values the guard accepts and that are correct:\n");
  row(50.0);
  row(1000.0);
  return 0;
}
