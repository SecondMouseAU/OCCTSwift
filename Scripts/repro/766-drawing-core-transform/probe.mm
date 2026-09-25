// Epic #766, OCCTDrawingTests: DrawingTests and DrawingTransformUnificationTests.
// HLRBRep_Algo with HLRAlgo_Projector(gp_Ax2(origin, view)) exactly as OCCTDrawingCreate builds
// it, on the same shapes (Shape.box is centred on the origin), reporting per category the unique
// edge count and the BRepBndLib box of the compound OCCTDrawingGetEdges would return (nothing for
// an empty category). The transform tests' formula is pure Swift; only the edge-collection test
// reads kernel output, the top view's visible bounds.
#include <BRepBndLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Builder.hxx>
#include <Bnd_Box.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS_Compound.hxx>
#include <cmath>
#include <cstdio>

static void category(const char* tag, const char* cat, TopoDS_Shape a, TopoDS_Shape b, TopoDS_Shape c)
{
  BRep_Builder    bld;
  TopoDS_Compound comp;
  bld.MakeCompound(comp);
  bool         added    = false;
  TopoDS_Shape parts[3] = {a, b, c};
  for (const TopoDS_Shape& s : parts)
    if (!s.IsNull())
    {
      bld.Add(comp, s);
      added = true;
    }
  if (!added)
  {
    printf("%s %s: nil\n", tag, cat);
    return;
  }
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(comp, TopAbs_EDGE, m);
  Bnd_Box box;
  BRepBndLib::Add(comp, box, true);
  double x0, y0, z0, x1, y1, z1;
  box.Get(x0, y0, z0, x1, y1, z1);
  printf("%s %s: edges=%d bbox=(%.9g, %.9g)..(%.9g, %.9g)\n", tag, cat, m.Extent(), x0, y0, x1, y1);
}

static void view(const char* tag, const TopoDS_Shape& s, gp_Dir v)
{
  Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
  algo->Add(s);
  algo->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), v)));
  algo->Update();
  algo->Hide();
  HLRBRep_HLRToShape h(algo);
  category(tag, "visible", h.VCompound(), h.Rg1LineVCompound(), h.OutLineVCompound());
  category(tag, "hidden", h.HCompound(), h.Rg1LineHCompound(), h.OutLineHCompound());
  category(tag, "outline", h.OutLineVCompound(), h.OutLineHCompound(), TopoDS_Shape());
}

int main()
{
  const double iso = 1.0 / std::sqrt(3.0);
  TopoDS_Shape box10 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  view("box10 top", box10, gp_Dir(0, 0, 1));
  view("box10 iso", box10, gp_Dir(iso, iso, iso));
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(10).Shape();
  view("sphere top", sphere, gp_Dir(0, 0, 1));
  view("sphere iso", sphere, gp_Dir(iso, iso, iso));
  TopoDS_Shape box123 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
  view("box10x20x30 top", box123, gp_Dir(0, 0, 1));
  view("box10x20x30 front", box123, gp_Dir(0, 1, 0));
  view("box10x20x30 side", box123, gp_Dir(1, 0, 0));
  return 0;
}
