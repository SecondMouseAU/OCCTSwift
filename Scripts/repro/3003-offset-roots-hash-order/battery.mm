// #3003: how far does the run-to-run difference reach, and does visiting the roots in binding order
// change WHAT the arc-join builder returns? Nine shapes, eight offset or thick-solid requests each,
// 72 lines per run, each printing the outcome rounded to seven places and the hash of the
// bit-exact BinTools dump of the result. Two runs that agree on every printed digit but differ in
// `dump=` returned the same solid with its sub-shapes in another order.
//
// The shapes include a concave one with coplanar split faces (the fuse of two boxes), a holed
// plate, a boss, a prism with a re-entrant corner, and the curved primitives. The requests are
// arc and intersection joins, inward and outward, and thick solids with one, none and the
// upward-facing faces open.
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BinTools.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <sstream>
#include <string>

static uint64_t dumpHash(const TopoDS_Shape& s)
{
  std::ostringstream bin;
  BinTools::Write(s, bin);
  uint64_t h = 1469598103934665603ull;
  for (unsigned char c : bin.str())
  {
    h ^= c;
    h *= 1099511628211ull;
  }
  return h;
}

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return std::fabs(p.Mass());
}

static int nFaces(const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_FACE, m);
  return m.Extent();
}

static gp_Dir normalOf(const TopoDS_Face& f)
{
  BRepAdaptor_Surface s(f);
  BRepLProp_SLProps   p(s, (s.FirstUParameter() + s.LastUParameter()) / 2,
                      (s.FirstVParameter() + s.LastVParameter()) / 2, 1, 1e-6);
  gp_Dir n = p.Normal();
  if (f.Orientation() == TopAbs_REVERSED)
    n.Reverse();
  return n;
}

// IsDone() is true and the shape is NULL for some inputs; the line says so rather than letting
// BRepCheck_Analyzer throw on it.
static void off(const char* label, const TopoDS_Shape& s, double d, GeomAbs_JoinType j)
{
  try
  {
    BRepOffsetAPI_MakeOffsetShape m;
    m.PerformByJoin(s, d, 1e-7, BRepOffset_Skin, false, false, j, false);
    if (!m.IsDone())
    {
      printf("%s: not done\n", label);
      return;
    }
    if (m.Shape().IsNull())
    {
      printf("%s: done, NULL shape\n", label);
      return;
    }
    printf("%s: valid=%d volume=%.7f faces=%d type=%d dump=%016llx\n", label,
           BRepCheck_Analyzer(m.Shape()).IsValid(), vol(m.Shape()), nFaces(m.Shape()),
           (int)m.Shape().ShapeType(), (unsigned long long)dumpHash(m.Shape()));
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", label, e.GetMessageString());
  }
}

static void thick(const char* label, const TopoDS_Shape& s, double d, GeomAbs_JoinType j, int nOpen,
                  bool top)
{
  try
  {
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(s, TopAbs_FACE, faces);
    TopTools_ListOfShape open;
    for (int i = 1; i <= faces.Extent() && (int)open.Extent() < nOpen; i++)
      if (!top || normalOf(TopoDS::Face(faces(i))).Z() > std::cos(0.01))
        open.Append(faces(i));
    BRepOffsetAPI_MakeThickSolid ts;
    ts.MakeThickSolidByJoin(s, open, d, 1e-6, BRepOffset_Skin, false, false, j);
    if (!ts.IsDone())
    {
      printf("%s: not done\n", label);
      return;
    }
    if (ts.Shape().IsNull())
    {
      printf("%s: done, NULL shape\n", label);
      return;
    }
    printf("%s: open=%d valid=%d volume=%.7f faces=%d dump=%016llx\n", label, open.Extent(),
           BRepCheck_Analyzer(ts.Shape()).IsValid(), vol(ts.Shape()), nFaces(ts.Shape()),
           (unsigned long long)dumpHash(ts.Shape()));
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", label, e.GetMessageString());
  }
}

int main()
{
  TopoDS_Shape box     = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape cyl     = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopoDS_Shape sph     = BRepPrimAPI_MakeSphere(5).Shape();
  TopoDS_Shape cone    = BRepPrimAPI_MakeCone(5, 2, 10).Shape();
  TopoDS_Shape tor     = BRepPrimAPI_MakeTorus(10, 3).Shape();
  TopoDS_Shape b2      = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 20, 10, 10).Shape();
  TopoDS_Shape b3      = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 20).Shape();
  TopoDS_Shape lshape  = BRepAlgoAPI_Fuse(b2, b3).Shape();
  TopoDS_Shape holeCyl = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(10, 5, -1), gp_Dir(0, 0, 1)), 2, 12).Shape();
  TopoDS_Shape holed   = BRepAlgoAPI_Cut(b2, holeCyl).Shape();
  TopoDS_Shape boss    = BRepAlgoAPI_Fuse(
                          box, BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 0, 5), gp_Dir(0, 0, 1)), 2, 4).Shape())
                          .Shape();
  BRepBuilderAPI_MakePolygon poly;
  poly.Add(gp_Pnt(0, 0, 0));
  poly.Add(gp_Pnt(10, 0, 0));
  poly.Add(gp_Pnt(10, 5, 0));
  poly.Add(gp_Pnt(5, 5, 0));
  poly.Add(gp_Pnt(5, 10, 0));
  poly.Add(gp_Pnt(0, 10, 0));
  poly.Close();
  TopoDS_Shape prism =
    BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(poly.Wire()).Face(), gp_Vec(0, 0, 8)).Shape();

  const char*  names[]  = {"box", "cylinder", "sphere", "cone", "torus", "lshape", "holed", "boss", "prism"};
  TopoDS_Shape shapes[] = {box, cyl, sph, cone, tor, lshape, holed, boss, prism};
  for (int i = 0; i < 9; i++)
  {
    char buf[96];
    snprintf(buf, sizeof buf, "off arc +1 %s", names[i]);
    off(buf, shapes[i], 1.0, GeomAbs_Arc);
    snprintf(buf, sizeof buf, "off arc -1 %s", names[i]);
    off(buf, shapes[i], -1.0, GeomAbs_Arc);
    snprintf(buf, sizeof buf, "off arc +0.3 %s", names[i]);
    off(buf, shapes[i], 0.3, GeomAbs_Arc);
    snprintf(buf, sizeof buf, "off inter +1 %s", names[i]);
    off(buf, shapes[i], 1.0, GeomAbs_Intersection);
    snprintf(buf, sizeof buf, "thick arc 2 open1 %s", names[i]);
    thick(buf, shapes[i], 2.0, GeomAbs_Arc, 1, false);
    snprintf(buf, sizeof buf, "thick arc -1 top %s", names[i]);
    thick(buf, shapes[i], -1.0, GeomAbs_Arc, 1, true);
    snprintf(buf, sizeof buf, "thick arc 2 none %s", names[i]);
    thick(buf, shapes[i], 2.0, GeomAbs_Arc, 0, false);
    snprintf(buf, sizeof buf, "thick inter 1 top %s", names[i]);
    thick(buf, shapes[i], 1.0, GeomAbs_Intersection, 1, true);
  }
  return 0;
}
