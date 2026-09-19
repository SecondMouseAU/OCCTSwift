#include <cstdio>
#include <vector>
#include <BRepLib_PointCloudShape.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <Precision.hxx>
#include <gp_Pnt.hxx>

class Probe : public BRepLib_PointCloudShape {
public:
  Probe(const TopoDS_Shape& s) : BRepLib_PointCloudShape(s) {}
  double cd() { return computeDensity(); }
  std::vector<gp_Pnt> pts;
protected:
  void addPoint(const gp_Pnt& p, const gp_Vec&, const gp_Pnt2d&, const TopoDS_Shape&) override {
    pts.push_back(p);
  }
};

int main() {
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  BRepMesh_IncrementalMesh m(box, 0.5);
  Probe p(box);
  double d = p.cd();
  printf("box computeDensity() = %.17g   (Confusion=%.3g)\n", d, Precision::Confusion());
  printf("NbPointsByDensity(computed) = %d\n", p.NbPointsByDensity(d));
  fflush(stdout);

  TopoDS_Shape v = BRepBuilderAPI_MakeVertex(gp_Pnt(0,0,0)).Shape();
  Probe pv(v);
  double dv = pv.cd();
  printf("vertex computeDensity() = %.17g\n", dv);
  fflush(stdout);
  return 0;
}
