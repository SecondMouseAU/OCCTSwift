// Ground truth for #999 cluster 1: does HLRAlgo_Projector's perspective constructor
// actually change the projected geometry, for both the exact and the polyhedral HLR
// algorithms? Measured before deciding whether to wire projectionType or reject it.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBndLib.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <Bnd_Box.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Ax2.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>

static void report(const char* label, const TopoDS_Shape& s)
{
  if (s.IsNull())
  {
    printf("%-28s NULL\n", label);
    return;
  }
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
    n++;
  Bnd_Box b;
  BRepBndLib::Add(s, b);
  if (b.IsVoid())
  {
    printf("%-28s edges=%d  bbox=VOID\n", label, n);
    return;
  }
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("%-28s edges=%d  bbox=[%.6f %.6f %.6f]..[%.6f %.6f %.6f]\n",
         label,
         n,
         x0,
         y0,
         z0,
         x1,
         y1,
         z1);
}

static TopoDS_Shape exactHLR(const TopoDS_Shape& shape, const HLRAlgo_Projector& proj)
{
  Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
  algo->Add(shape);
  algo->Projector(proj);
  algo->Update();
  algo->Hide();
  HLRBRep_HLRToShape out(algo);
  return out.VCompound();
}

static TopoDS_Shape polyHLR(const TopoDS_Shape& shape, const HLRAlgo_Projector& proj)
{
  Handle(HLRBRep_PolyAlgo) algo = new HLRBRep_PolyAlgo();
  algo->Projector(proj);
  algo->Load(shape);
  algo->Update();
  // Read the projector back: proves the perspective flag survived the setter, so an
  // unchanged result is the algorithm ignoring it rather than the setter dropping it.
  printf("            poly projector readback Perspective()=%d\n",
         (int)algo->Projector().Perspective());
  HLRBRep_PolyHLRToShape out;
  out.Update(algo);
  return out.VCompound();
}

int main()
{
  // A box centred like Shape.box(), viewed down +Z.
  TopoDS_Shape             box = BRepPrimAPI_MakeBox(gp_Pnt(-50, -25, -15), 100, 50, 30).Shape();
  BRepMesh_IncrementalMesh mesh(box, 0.01);

  gp_Ax2 cs(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

  HLRAlgo_Projector ortho(cs);
  // Focus() raises Standard_NoSuchObject unless Perspective() is true.
  printf("ortho     Perspective()=%d\n", (int)ortho.Perspective());
  report("exact ortho", exactHLR(box, ortho));
  report("poly  ortho", polyHLR(box, ortho));

  for (double focus : {20.0, 50.0, 200.0, 1000.0})
  {
    HLRAlgo_Projector persp(cs, focus);
    printf("persp f=%-8.1f Perspective()=%d  Focus()=%.6f\n",
           focus,
           (int)persp.Perspective(),
           persp.Focus());
    char lbl[64];
    snprintf(lbl, sizeof(lbl), "exact persp f=%.0f", focus);
    report(lbl, exactHLR(box, persp));
    snprintf(lbl, sizeof(lbl), "poly  persp f=%.0f", focus);
    report(lbl, polyHLR(box, persp));
  }
  return 0;
}
