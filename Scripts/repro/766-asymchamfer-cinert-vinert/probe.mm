// #766 kernel parity for three small Analysis test files:
//   AsymmetricChamferTests.swift  -> BRepFilletAPI_MakeChamfer::Add(d1, d2, edge, face) (OCCTShapeChamferTwoDistances)
//   BRepGPropCinertTests.swift    -> BRepGProp_Cinert(BRepAdaptor_Curve, origin)         (OCCTBRepGPropCinert)
//   BRepGPropVinertTests.swift    -> BRepGProp_Vinert on a BRepGProp_Face                (OCCTBRepGPropVinert, OCCTBRepGPropVinertPlane)
// Sub-shapes are indexed through TopExp::MapShapes, as the bridge and Shape.edges()/faces() do.
#include <BRepAdaptor_Curve.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepGProp.hxx>
#include <BRepGProp_Cinert.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepGProp_Vinert.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static void chamfer(const char* label, const TopoDS_Shape& s, const int (*spec)[2],
                    const double (*dist)[2], int n)
{
  TopTools_IndexedMapOfShape edges, faces;
  TopExp::MapShapes(s, TopAbs_EDGE, edges);
  TopExp::MapShapes(s, TopAbs_FACE, faces);
  for (int sym = 0; sym < 2; ++sym)
  {
    BRepFilletAPI_MakeChamfer ch(s);
    for (int i = 0; i < n; ++i)
      ch.Add(dist[i][0], sym ? dist[i][0] : dist[i][1], TopoDS::Edge(edges(spec[i][0] + 1)),
             TopoDS::Face(faces(spec[i][1] + 1)));
    ch.Build();
    if (!ch.IsDone())
    {
      printf("%s%s: not done\n", label, sym ? " (dist2 := dist1)" : "");
      continue;
    }
    GProp_GProps p;
    BRepGProp::VolumeProperties(ch.Shape(), p);
    TopTools_IndexedMapOfShape rf;
    TopExp::MapShapes(ch.Shape(), TopAbs_FACE, rf);
    printf("%s%s: done valid=%d volume=%.17g faces=%d\n", label, sym ? " (dist2 := dist1)" : "",
           (int)BRepCheck_Analyzer(ch.Shape()).IsValid(), p.Mass(), rf.Extent());
  }
}

int main()
{
  TopoDS_Shape b10 = box(10, 10, 10);
  {
    TopTools_IndexedMapOfShape edges, faces;
    TopExp::MapShapes(b10, TopAbs_EDGE, edges);
    TopExp::MapShapes(b10, TopAbs_FACE, faces);
    for (int i = 1; i <= 2; ++i)
    {
      BRepAdaptor_Curve c(TopoDS::Edge(edges(i)));
      gp_Pnt            a = c.Value(c.FirstParameter()), z = c.Value(c.LastParameter());
      printf("10-cube edge %d: (%g,%g,%g) -> (%g,%g,%g)\n", i - 1, a.X(), a.Y(), a.Z(), z.X(), z.Y(),
             z.Z());
    }
  }
  const int    s1[1][2] = {{0, 0}};
  const double d1[1][2] = {{1.0, 2.0}};
  chamfer("twoDistChamfer edge0 face0 d1=1 d2=2", b10, s1, d1, 1);
  const int    s2[2][2] = {{0, 0}, {1, 0}};
  const double d2[2][2] = {{0.5, 1.0}, {0.8, 0.6}};
  chamfer("multiEdgeChamfer edges 0,1 face 0", b10, s2, d2, 2);

  // Cinert: the first edge of a 10 x 20 x 30 box
  TopoDS_Shape               b123 = box(10, 20, 30);
  TopTools_IndexedMapOfShape e123;
  TopExp::MapShapes(b123, TopAbs_EDGE, e123);
  BRepAdaptor_Curve c(TopoDS::Edge(e123(1)));
  BRepGProp_Cinert  ci(c, gp_Pnt(0, 0, 0));
  gp_Pnt            cm = ci.CentreOfMass();
  printf("Cinert box 10x20x30 edge 0: mass=%.17g centre=(%.17g, %.17g, %.17g)\n", ci.Mass(),
         cm.X(), cm.Y(), cm.Z());

  // Vinert: the first face of a 10-cube, with the origin as location, and against the z = 0 plane
  TopTools_IndexedMapOfShape f10;
  TopExp::MapShapes(b10, TopAbs_FACE, f10);
  BRepGProp_Face   gf(TopoDS::Face(f10(1)));
  BRepGProp_Vinert vi;
  vi.SetLocation(gp_Pnt(0, 0, 0));
  vi.Perform(gf);
  gp_Pnt vc = vi.CentreOfMass();
  printf("Vinert 10-cube face 0: mass=%.17g centre=(%.17g, %.17g, %.17g)\n", vi.Mass(), vc.X(),
         vc.Y(), vc.Z());
  BRepGProp_Vinert vp(gf, gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), gp_Pnt(0, 0, 0));
  gp_Pnt           pc = vp.CentreOfMass();
  printf("Vinert 10-cube face 0 vs plane z=0: mass=%.17g centre=(%.17g, %.17g, %.17g)\n",
         vp.Mass(), pc.X(), pc.Y(), pc.Z());
  // Every face against the plane, to pick a face whose plane-referenced volume is non-zero
  for (int i = 1; i <= f10.Extent(); ++i)
  {
    BRepGProp_Face   g(TopoDS::Face(f10(i)));
    BRepGProp_Vinert a;
    a.SetLocation(gp_Pnt(0, 0, 0));
    a.Perform(g);
    BRepGProp_Vinert p(g, gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), gp_Pnt(0, 0, 0));
    printf("  face %d: vinert=%.17g vinertPlaneZ=%.17g\n", i - 1, a.Mass(), p.Mass());
  }
  return 0;
}
