// Ground truth for #999 cluster 1: what does HLRAlgo_Projector do with a focal distance
// that is zero, negative, or short enough to put the eye inside the shape? Decides what the
// bridge has to guard before it can accept a caller-supplied focus.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS_Shape.hxx>
#include <Standard_Failure.hxx>
#include <gp_Ax2.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>

int main()
{
  // Near face of this box sits at z = +15 in the projection frame.
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-50, -25, -15), 100, 50, 30).Shape();
  gp_Ax2       cs(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

  for (double focus : {-100.0, 0.0, 1e-12, 5.0, 15.0, 15.0000001, 30.0})
  {
    printf("focus=%-14g ", focus);
    try
    {
      HLRAlgo_Projector    proj(cs, focus);
      Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
      algo->Add(box);
      algo->Projector(proj);
      algo->Update();
      algo->Hide();
      HLRBRep_HLRToShape out(algo);
      TopoDS_Shape       v = out.VCompound();
      if (v.IsNull())
      {
        printf("VCompound NULL\n");
        continue;
      }
      int n = 0;
      for (TopExp_Explorer e(v, TopAbs_EDGE); e.More(); e.Next())
        n++;
      Bnd_Box b;
      BRepBndLib::Add(v, b);
      if (b.IsVoid())
      {
        printf("edges=%d bbox=VOID\n", n);
        continue;
      }
      double x0, y0, z0, x1, y1, z1;
      b.Get(x0, y0, z0, x1, y1, z1);
      printf("edges=%d bbox x=[%.6f %.6f] y=[%.6f %.6f]\n", n, x0, x1, y0, y1);
    }
    catch (Standard_Failure const& f)
    {
      printf("threw: %s\n", f.GetMessageString());
    }
    catch (...)
    {
      printf("threw (unknown)\n");
    }
  }
  return 0;
}
