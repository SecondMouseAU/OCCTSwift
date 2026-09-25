// #766 / #1987 kernel parity for the bottom three Foundation suites:
// "Thread Safety: OCCTSerial", "v0.149 Sheet.standardLayout", "v0.150 BillOfMaterials".
// BillOfMaterials is pure Swift (no OCCT call), so it has no section here.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TNaming_CopyShape.hxx>
#include <TColStd_IndexedDataMapOfTransientTransient.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <HLRAlgo_Projector.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Shape centredBox(double w, double h, double d)
{
  // OCCTShapeCreateBox: centred at the origin.
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

static int edgeCount(const TopoDS_Shape& s)
{
  int n = 0;
  if (s.IsNull())
    return 0;
  for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
    ++n;
  return n;
}

int main()
{
  printf("== Thread Safety: OCCTSerial ==\n");
  for (int i = 0; i < 4; ++i)
  {
    double a = (i + 1) * 10.0;
    printf("box %g^3 volume = %.6f\n", a, volume(centredBox(a, a, a)));
  }
  printf("box 5^3 volume = %.6f\n", volume(centredBox(5, 5, 5)));
  TopoDS_Shape                               orig = centredBox(10, 10, 10);
  TColStd_IndexedDataMapOfTransientTransient map;
  TopoDS_Shape                               copy;
  TNaming_CopyShape::CopyTool(orig, map, copy);
  printf("deep copy (TNaming_CopyShape::CopyTool): orig volume %.6f, copy volume %.6f, IsSame %d\n",
         volume(orig),
         volume(copy),
         (int)copy.IsSame(orig));

  printf("== Sheet.standardLayout: HLR of box 20 x 15 x 10 ==\n");
  struct
  {
    const char* name;
    double      x, y, z;
  } dirs[] = {
    {"front (0,1,0)", 0, 1, 0},
    {"top   (0,0,1)", 0, 0, 1},
    {"side  (1,0,0)", 1, 0, 0},
    {"iso   (1,1,1)/sqrt3", 1, 1, 1},
  };
  TopoDS_Shape box = centredBox(20, 15, 10);
  for (auto& d : dirs)
  {
    Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
    algo->Add(box);
    algo->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(d.x, d.y, d.z))));
    algo->Update();
    algo->Hide();
    HLRBRep_HLRToShape h(algo);
    TopoDS_Shape       comps[] = {h.VCompound(), h.OutLineVCompound(), h.HCompound(), h.OutLineHCompound()};
    int                visible = edgeCount(comps[0]), hidden = edgeCount(comps[2]);
    Bnd_Box            b;
    for (auto& c : comps)
      if (!c.IsNull())
        BRepBndLib::Add(c, b, false);
    b.SetGap(0.0);
    double x0, y0, z0, x1, y1, z1;
    b.Get(x0, y0, z0, x1, y1, z1);
    printf("%s: visible sharp edges %d, hidden sharp edges %d, 2D bounds x [%.6f, %.6f] y [%.6f, %.6f]\n",
           d.name,
           visible,
           hidden,
           x0,
           x1,
           y0,
           y1);
  }
  return 0;
}
