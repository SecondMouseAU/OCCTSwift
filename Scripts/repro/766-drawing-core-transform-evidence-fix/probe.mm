// Epic #766, #1984 evidence correction for PR #2415 (DrawingTests, DrawingTransformUnificationTests).
// Two measurements the original probe took at %.9g or not at all:
//   1. HLRBRep_Algo with HLRAlgo_Projector(gp_Ax2(origin, iso)) on the centred 10-unit box,
//      visible and hidden edge counts and the BRepBndLib extent at %.17g (the extent the Swift
//      side reads as Shape.boundingBox of Drawing.visibleEdges / hiddenEdges).
//   2. The extent of the top view's edge geometry: min/max of BRep_Tool::Pnt over every vertex of
//      the six HLR compounds (visible, hidden, outline), which is what Drawing.bounds() computes
//      for straight edges (it takes the min/max of the edges' polyline points; a straight edge's
//      polyline is its two vertices). It carries no BRepBndLib tolerance gap, unlike (1).
#include <BRepBndLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <HLRAlgo_Projector.hxx>
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <algorithm>
#include <cmath>
#include <cstdio>

static TopoDS_Compound join(const TopoDS_Shape parts[], int n)
{
  BRep_Builder    bld;
  TopoDS_Compound c;
  bld.MakeCompound(c);
  for (int i = 0; i < n; ++i)
    if (!parts[i].IsNull())
      bld.Add(c, parts[i]);
  return c;
}

static void category(const char* tag, const TopoDS_Compound& c)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(c, TopAbs_EDGE, m);
  Bnd_Box bb;
  BRepBndLib::Add(c, bb, true);
  double x0, y0, z0, x1, y1, z1;
  bb.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: edges=%d min=(%.17g, %.17g) max=(%.17g, %.17g)\n", tag, m.Extent(), x0, y0, x1, y1);
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  {
    const double         iso  = 1.0 / std::sqrt(3.0);
    Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
    algo->Add(box);
    algo->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(iso, iso, iso))));
    algo->Update();
    algo->Hide();
    HLRBRep_HLRToShape h(algo);
    TopoDS_Shape       v[3] = {h.VCompound(), h.Rg1LineVCompound(), h.OutLineVCompound()};
    TopoDS_Shape       hd[3] = {h.HCompound(), h.Rg1LineHCompound(), h.OutLineHCompound()};
    category("iso visible", join(v, 3));
    category("iso hidden", join(hd, 3));
  }
  {
    Handle(HLRBRep_Algo) algo = new HLRBRep_Algo();
    algo->Add(box);
    algo->Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))));
    algo->Update();
    algo->Hide();
    HLRBRep_HLRToShape h(algo);
    TopoDS_Shape       all[6] = {h.VCompound(), h.Rg1LineVCompound(), h.OutLineVCompound(),
                                 h.HCompound(), h.Rg1LineHCompound(), h.OutLineHCompound()};
    TopoDS_Compound    c      = join(all, 6);
    TopTools_IndexedMapOfShape verts;
    TopExp::MapShapes(c, TopAbs_VERTEX, verts);
    double x0 = 1e300, y0 = 1e300, x1 = -1e300, y1 = -1e300;
    for (int i = 1; i <= verts.Extent(); ++i)
    {
      gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(verts(i)));
      x0       = std::min(x0, p.X());
      y0       = std::min(y0, p.Y());
      x1       = std::max(x1, p.X());
      y1       = std::max(y1, p.Y());
    }
    printf("top view vertex extent (%d vertices over the six HLR compounds): min=(%.17g, %.17g) max=(%.17g, %.17g)\n",
           verts.Extent(), x0, y0, x1, y1);
  }
  return 0;
}
