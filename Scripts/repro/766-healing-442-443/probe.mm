// #766 kernel parity: Issue442FixSolidMultiBodyTests, Issue443FirstOfNTests.
// The same OCCT sequence the bridge runs: ShapeFix_Solid per solid (OCCTShapeFixSolid);
// enclosure parity over each group of shells with BRepClass3d_SolidClassifier, then
// ShapeFix_Solid::SolidFromShell per selected shell (OCCTShapeSolidFromShell, and the
// occtBodyBoundingShells step shared with Shape.solid(from:) and OCCTShapeUpgrade);
// BRepBuilderAPI_Sewing for the sewn fixtures. Prints bodies and volumes per fixture.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <ShapeFix_Solid.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Iterator.hxx>
#include <Precision.hxx>
#include <cstdio>
#include <vector>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  return g.Mass();
}

static int count(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  int n = 0;
  for (TopExp_Explorer e(s, t); e.More(); e.Next())
    n++;
  return n;
}

static TopoDS_Shape box(double x, double y, double z, double w)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(x, y, z), w, w, w).Shape();
}

static void select(const std::vector<TopoDS_Shell>& shells, std::vector<TopoDS_Shell>& out)
{
  if (shells.size() == 1)
  {
    out.push_back(shells[0]);
    return;
  }
  std::vector<int> enclosed(shells.size(), 0);
  for (size_t i = 0; i < shells.size(); i++)
  {
    if (!BRep_Tool::IsClosed(shells[i]))
      continue;
    TopoDS_Solid ref;
    BRep_Builder b;
    b.MakeSolid(ref);
    b.Add(ref, shells[i]);
    BRepClass3d_SolidClassifier c(ref);
    c.PerformInfinitePoint(Precision::Confusion());
    TopAbs_State inside = c.State() == TopAbs_IN ? TopAbs_OUT : TopAbs_IN;
    for (size_t j = 0; j < shells.size(); j++)
    {
      if (i == j)
        continue;
      // A shell with no vertex is not counted as enclosed, as occtShellIsInsideSolid does.
      TopExp_Explorer v(shells[j], TopAbs_VERTEX);
      if (!v.More())
        continue;
      c.Perform(BRep_Tool::Pnt(TopoDS::Vertex(v.Current())), Precision::Confusion());
      if (c.State() == inside)
        enclosed[j]++;
    }
  }
  for (size_t i = 0; i < shells.size(); i++)
    if (enclosed[i] % 2 == 0)
      out.push_back(shells[i]);
}

static void solidFromShell(const char* label, const TopoDS_Shape& s)
{
  std::vector<TopoDS_Shell>  sel;
  TopTools_IndexedMapOfShape claimed;
  for (TopExp_Explorer se(s, TopAbs_SOLID); se.More(); se.Next())
  {
    std::vector<TopoDS_Shell> g;
    for (TopExp_Explorer sh(se.Current(), TopAbs_SHELL); sh.More(); sh.Next())
    {
      claimed.Add(sh.Current());
      g.push_back(TopoDS::Shell(sh.Current()));
    }
    select(g, sel);
  }
  std::vector<TopoDS_Shell> free;
  for (TopExp_Explorer sh(s, TopAbs_SHELL); sh.More(); sh.Next())
  {
    if (claimed.Contains(sh.Current()))
      continue;
    claimed.Add(sh.Current());
    free.push_back(TopoDS::Shell(sh.Current()));
  }
  select(free, sel);
  printf("%s: input solids=%d shells=%d -> bodies=%zu volumes:", label, count(s, TopAbs_SOLID),
         count(s, TopAbs_SHELL), sel.size());
  double total = 0;
  for (auto& sh : sel)
  {
    ShapeFix_Solid f;
    TopoDS_Solid   so = f.SolidFromShell(sh);
    double         v  = vol(so);
    total += v;
    printf(" %.3f", v);
  }
  printf(" total=%.6f\n", total);
}

static void fixSolid(const char* label, const TopoDS_Shape& s)
{
  int    bodies = 0, faces = 0;
  double total  = 0;
  for (TopExp_Explorer e(s, TopAbs_SOLID); e.More(); e.Next())
  {
    ShapeFix_Solid f(TopoDS::Solid(e.Current()));
    f.Perform();
    TopoDS_Shape r = f.Shape();
    if (r.ShapeType() == TopAbs_COMPOUND)
      for (TopoDS_Iterator it(r); it.More(); it.Next())
        bodies++;
    else
      bodies++;
    faces += count(r, TopAbs_FACE);
    total += vol(r);
  }
  printf("%s: ShapeFix_Solid per solid -> bodies=%d faces=%d volume=%.6f\n", label, bodies, faces, total);
}

static TopoDS_Shape sew(const TopoDS_Shape& s)
{
  BRepBuilderAPI_Sewing sw(1e-6);
  sw.Add(s);
  sw.Perform();
  return sw.SewedShape();
}

int main()
{
  BRep_Builder    b;
  TopoDS_Compound two;
  b.MakeCompound(two);
  b.Add(two, box(0, 0, 0, 10));
  b.Add(two, box(20, 0, 0, 10));
  TopoDS_Shape hollow = BRepAlgoAPI_Cut(box(0, 0, 0, 20), box(5, 5, 5, 10)).Shape();
  printf("hollow: solids=%d shells=%d volume=%.6f\n", count(hollow, TopAbs_SOLID), count(hollow, TopAbs_SHELL),
         vol(hollow));

  // multiconnex: one solid holding two disjoint boxes' shells
  TopoDS_Solid multi;
  b.MakeSolid(multi);
  b.Add(multi, TopExp_Explorer(box(0, 0, 0, 10), TopAbs_SHELL).Current());
  b.Add(multi, TopExp_Explorer(box(20, 0, 0, 10), TopAbs_SHELL).Current());

  fixSolid("two boxes", two);
  fixSolid("single box", box(0, 0, 0, 10));
  fixSolid("hollow", hollow);
  fixSolid("multiconnex", multi);

  solidFromShell("two boxes", two);
  solidFromShell("single box", box(0, 0, 0, 10));
  solidFromShell("hollow", hollow);
  solidFromShell("multiconnex", multi);
  TopoDS_Shape sewnTwo = sew(two);
  solidFromShell("sewn two boxes", sewnTwo);
  TopoDS_Shape sewnHollow = sew(hollow);
  solidFromShell("sewn hollow", sewnHollow);

  // hollow + wider sibling in one solid
  TopoDS_Solid three;
  b.MakeSolid(three);
  for (TopExp_Explorer e(hollow, TopAbs_SHELL); e.More(); e.Next())
    b.Add(three, e.Current());
  b.Add(three, TopExp_Explorer(box(50, 0, 0, 30), TopAbs_SHELL).Current());
  solidFromShell("hollow + wider sibling", three);

  // 100 disjoint boxes, sewn
  TopoDS_Compound many;
  b.MakeCompound(many);
  for (int i = 0; i < 100; i++)
    b.Add(many, box(i * 20.0, 0, 0, 10));
  solidFromShell("100 disjoint boxes, sewn", sew(many));
  return 0;
}
