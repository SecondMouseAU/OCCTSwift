// Ground-truth probe for the .perspective(focus:) eye anchor (OCCTSwift #1030).
// Replicates OCCTDrawingCreate's projector construction exactly and reports the projected X range
// of the visible compound, so the sign (mirroring) is visible rather than only the width.
//
// Compile per CLAUDE.md's "Compile a Ground Truth C++ Test":
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1030-perspective-eye-anchor/probe.mm -o /tmp/probe_1030

#include <BRepBndLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Bnd_Box.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>

// Box spans x in [xmin, xmax], y in [-5, 5], z in [zmin, zmin + 10]; viewed down +Z.
static void report(const char* label, double xmin, double xmax, double zmin, double focus)
{
  TopoDS_Shape box =
    BRepPrimAPI_MakeBox(gp_Pnt(xmin, -5, zmin), gp_Pnt(xmax, 5, zmin + 10)).Shape();

  try
  {
    gp_Dir            viewDir(0, 0, 1);
    gp_Ax2            projAxis(gp_Pnt(0, 0, 0), viewDir);
    HLRAlgo_Projector projector(projAxis, focus);

    Handle(HLRBRep_Algo) hlrAlgo = new HLRBRep_Algo();
    hlrAlgo->Add(box);
    hlrAlgo->Projector(projector);
    hlrAlgo->Update();
    hlrAlgo->Hide();

    HLRBRep_HLRToShape shapes(hlrAlgo);
    TopoDS_Shape       visible = shapes.VCompound();

    if (visible.IsNull())
    {
      printf("%-30s focus=%-9g -> VCompound NULL\n", label, focus);
      return;
    }
    int nEdges = 0;
    for (TopExp_Explorer e(visible, TopAbs_EDGE); e.More(); e.Next())
      nEdges++;
    if (nEdges == 0)
    {
      printf("%-30s focus=%-9g -> VCompound EMPTY (0 edges)\n", label, focus);
      return;
    }

    Bnd_Box bb;
    BRepBndLib::Add(visible, bb);
    double bxmin, bymin, bzmin, bxmax, bymax, bzmax;
    bb.Get(bxmin, bymin, bzmin, bxmax, bymax, bzmax);
    printf("%-30s focus=%-9g -> edges=%-3d x=[%11.4f, %11.4f] halfwidth=%10.4f\n",
           label,
           focus,
           nEdges,
           bxmin,
           bxmax,
           (bxmax - bxmin) / 2);
  }
  catch (const Standard_Failure& f)
  {
    printf("%-30s focus=%-9g -> THREW %s\n", label, focus, f.GetMessageString());
  }
  catch (...)
  {
    printf("%-30s focus=%-9g -> THREW (unknown)\n", label, focus);
  }
}

int main()
{
  printf("== centred box, x in [-5,5], depth 10: reproduces the review's five rows ==\n");
  report("z=[0,10] centred", -5, 5, 0, 50);
  report("z=[1000,1010] centred", -5, 5, 1000, 50);
  report("z=[1000,1010] centred", -5, 5, 1000, 1005);
  report("z=[1000,1010] centred", -5, 5, 1000, 1011);
  report("z=[1000,1010] centred", -5, 5, 1000, 2000);

  printf("\n== x-offset box, x in [20,30]: the sign of x exposes the mirroring ==\n");
  report("z=[0,10] offset", 20, 30, 0, 50);
  report("z=[1000,1010] offset", 20, 30, 1000, 50);
  report("z=[1000,1010] offset", 20, 30, 1000, 2000);

  printf("\n== eye plane cutting the shape, and sitting exactly on a face ==\n");
  report("z=[0,10] offset", 20, 30, 0, 5.5);
  report("z=[0,10] offset", 20, 30, 0, 5);
  report("z=[0,10] offset", 20, 30, 0, 10);
  report("z=[0,10] offset", 20, 30, 0, 10.0001);
  report("z=[0,10] offset", 20, 30, 0, 0.0001);

  printf("\n== the magnification RATIO is translation invariant, the SCALE is not ==\n");
  report("z=[0,10] centred", -5, 5, 0, 50);
  report("z=[1000,1010] centred", -5, 5, 1000, 1050);
  return 0;
}
