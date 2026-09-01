#include <BRepLib_PointCloudShape.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRep_Builder.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include <gp_Pnt2d.hxx>
#include <vector>
#include <cstdio>

class ProbeCollector : public BRepLib_PointCloudShape {
public:
  ProbeCollector(const TopoDS_Shape& s, double tol) : BRepLib_PointCloudShape(s, tol) {}
  int count = 0;
protected:
  void addPoint(const gp_Pnt&, const gp_Vec&, const gp_Pnt2d&, const TopoDS_Shape&) override { count++; }
};

static TopoDS_Face polyFace(std::vector<gp_Pnt> pts) {
  BRepBuilderAPI_MakePolygon mp;
  for (auto& p : pts) mp.Add(p);
  mp.Close();
  BRepBuilderAPI_MakeFace mf(mp.Wire());
  return mf.Face();
}

int main() {
  TopoDS_Face sliver = polyFace({gp_Pnt(0,0,0), gp_Pnt(10,0,0), gp_Pnt(5,1e-16,0)});
  TopoDS_Face square  = polyFace({gp_Pnt(100,0,0), gp_Pnt(100.01,0,0), gp_Pnt(100.01,0.01,0), gp_Pnt(100,0.01,0)});
  BRep_Builder bb;
  TopoDS_Compound comp;
  bb.MakeCompound(comp);
  bb.Add(comp, sliver);
  bb.Add(comp, square);

  double explicitDensity = 2e-8;
  {
    ProbeCollector pc(comp, 0.0);
    bool ok = pc.GeneratePointsByDensity(explicitDensity);
    printf("tol=0.0 (bug)  -> GeneratePointsByDensity=%d, count=%d\n", ok, pc.count);
  }
  {
    ProbeCollector pc(comp, Precision::Confusion());
    bool ok = pc.GeneratePointsByDensity(explicitDensity);
    printf("tol=Confusion (fix) -> GeneratePointsByDensity=%d, count=%d\n", ok, pc.count);
  }
  // Regression control: ordinary explicit density (>= Confusion), unaffected either way.
  {
    ProbeCollector pc(comp, 0.0);
    bool ok = pc.GeneratePointsByDensity(1e-5);
    printf("explicit density 1e-5 (bypasses computeDensity) -> ok=%d count=%d\n", ok, pc.count);
  }
  return 0;
}
