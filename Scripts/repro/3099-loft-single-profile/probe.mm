// #3099: BRepOffsetAPI_ThruSections with too few sections. One input per process:
//   probe <nWires> <solid> <ruled> <firstVertex> <lastVertex> <kind>
// kind: square | zero | same | mixed (wires of differing edge counts)
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Wire.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopAbs.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>
#include <cstdlib>
#include <cstring>

static TopoDS_Wire poly(double z, int n, double s)
{
  BRepBuilderAPI_MakePolygon mp;
  const double xs[] = {-1, 1, 1, -1, 0};
  const double ys[] = {-1, -1, 1, 1, 1.5};
  if (n == 5) { mp.Add(gp_Pnt(-1*s,-1*s,z)); mp.Add(gp_Pnt(1*s,-1*s,z)); mp.Add(gp_Pnt(1*s,0,z)); mp.Add(gp_Pnt(1*s,1*s,z)); mp.Add(gp_Pnt(-1*s,1*s,z)); }
  else for (int i = 0; i < n; i++) mp.Add(gp_Pnt(xs[i]*s, ys[i]*s, z));
  mp.Close();
  return mp.Wire();
}

int main(int argc, char** argv)
{
  int nw = atoi(argv[1]); bool solid = atoi(argv[2]); bool ruled = atoi(argv[3]);
  bool fv = atoi(argv[4]); bool lv = atoi(argv[5]); const char* kind = argv[6];
  BRepOffsetAPI_ThruSections m(solid, ruled);
  m.CheckCompatibility(Standard_True);
  if (fv) m.AddVertex(BRepBuilderAPI_MakeVertex(gp_Pnt(0, 0, -2)));
  for (int i = 0; i < nw; i++)
  {
    if (!strcmp(kind, "zero")) m.AddWire(poly(i, 4, 0.0));
    else if (!strcmp(kind, "same")) m.AddWire(poly(0, 4, 1.0));
    else if (!strcmp(kind, "mixed")) m.AddWire(i % 2 ? poly(i, 5, 1.0) : poly(i, 4, 1.0));
    else m.AddWire(poly(i * 2.0, 4, 1.0));
  }
  if (lv) m.AddVertex(BRepBuilderAPI_MakeVertex(gp_Pnt(0, 0, 9)));
  fflush(stdout);
  try {
    m.Build();
    if (!m.IsDone()) { printf("notdone\n"); return 0; }
    BRepCheck_Analyzer a(m.Shape());
    printf("done type=%d valid=%d\n", (int)m.Shape().ShapeType(), (int)a.IsValid());
  } catch (...) { printf("exception\n"); }
  return 0;
}
