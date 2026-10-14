// #3388: does BRepBuilderAPI_Transform move a triangulation-only face (no surface)?
// Compare Copy=true, Copy=false and TopoDS_Shape::Moved; print the first triangulation node
// (read through the face's location) and whether the result shares the input's TShape.
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <Poly_Triangle.hxx>
#include <Poly_Triangulation.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopLoc_Location.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <cstdio>

static void report(const char* label, const TopoDS_Shape& s, const TopoDS_Shape& in)
{
  TopLoc_Location                 loc;
  occ::handle<Poly_Triangulation> t = BRep_Tool::Triangulation(TopoDS::Face(s), loc);
  if (t.IsNull())
  {
    printf("%-24s no triangulation\n", label);
    return;
  }
  gp_Pnt p = t->Node(1).Transformed(loc.Transformation());
  printf("%-24s node1=(%g,%g,%g) sameTShape=%d\n",
         label,
         p.X(),
         p.Y(),
         p.Z(),
         (int)(s.TShape().get() == in.TShape().get()));
}

int main()
{
  occ::handle<Poly_Triangulation> tri = new Poly_Triangulation(3, 1, false);
  tri->SetNode(1, gp_Pnt(1, 2, 3));
  tri->SetNode(2, gp_Pnt(4, 2, 3));
  tri->SetNode(3, gp_Pnt(1, 5, 3));
  tri->SetTriangle(1, Poly_Triangle(1, 2, 3));
  BRep_Builder b;
  TopoDS_Face  f;
  b.MakeFace(f);
  b.UpdateFace(f, tri);

  gp_Trsf tr;
  tr.SetTranslation(gp_Vec(100, 0, 0));
  gp_Trsf sc;
  sc.SetScale(gp_Pnt(0, 0, 0), 2.0);

  report("input", f, f);
  for (int copy = 1; copy >= 0; --copy)
  {
    BRepBuilderAPI_Transform t1(f, tr, copy == 1);
    report(copy ? "translate Copy=true" : "translate Copy=false", t1.Shape(), f);
    BRepBuilderAPI_Transform t2(f, sc, copy == 1);
    report(copy ? "scale Copy=true" : "scale Copy=false", t2.Shape(), f);
  }
  report("translate Moved", f.Moved(TopLoc_Location(tr)), f);
  report("scale Moved", f.Moved(TopLoc_Location(sc)), f);
  return 0;
}
