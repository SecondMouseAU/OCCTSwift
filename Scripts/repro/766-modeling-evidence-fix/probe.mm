// #1975 evidence correction: the kernel side of fourteen Modeling parity records, at full precision.
// Same OCCT calls and inputs as the five earlier probes
// (766-modeling-offset-by-join, -offset-wire-face, -multi-edge-blend, -multi-fuse, -multi-offset-wire),
// whose transcripts print with %.10g; the records need the values the bridge side is compared to,
// so every number here is %.17g.
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAlgoAPI_BuilderAlgo.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffset_Offset.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <vector>

// Shape.volume -> OCCTShapeGetVolume -> occtVolumeMassProperties: BRepGProp::VolumeProperties with
// OnlyClosed = true. The earlier probes used the default (false), which integrates a compound of
// shared-face solids slightly differently (fuseFourSpheres differs in the tenth digit).
static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, /*OnlyClosed*/ true);
  return p.Mass();
}

// ---- OffsetByJoinTests: OCCTShapeOffsetByJoin = BRepOffsetAPI_MakeOffsetShape::PerformByJoin ----
static void off(const char* label, const TopoDS_Shape& s, double d, GeomAbs_JoinType j)
{
  BRepOffsetAPI_MakeOffsetShape m;
  m.PerformByJoin(s, d, 1e-7, BRepOffset_Skin, false, false, j, false);
  printf("%s: done=%d", label, m.IsDone());
  if (m.IsDone())
    printf(" valid=%d volume=%.17g input=%.17g", BRepCheck_Analyzer(m.Shape()).IsValid(), volume(m.Shape()),
           volume(s));
  printf("\n");
}

// ---- OffsetWireFaceTests / MultiOffsetWireTests ----
static TopoDS_Wire rect(double w, double h)
{
  gp_Pnt                  p1(-w / 2, -h / 2, 0), p2(w / 2, -h / 2, 0), p3(w / 2, h / 2, 0), p4(-w / 2, h / 2, 0);
  BRepBuilderAPI_MakeWire mw;
  mw.Add(BRepBuilderAPI_MakeEdge(p1, p2).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p2, p3).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p3, p4).Edge());
  mw.Add(BRepBuilderAPI_MakeEdge(p4, p1).Edge());
  return mw.Wire();
}

static void wireOff(const char* label, double d, GeomAbs_JoinType j)
{
  BRepOffsetAPI_MakeOffset mo(rect(10, 10), j);
  mo.Perform(d);
  printf("%s: done=%d", label, mo.IsDone());
  if (mo.IsDone())
    for (TopExp_Explorer ex(mo.Shape(), TopAbs_WIRE); ex.More(); ex.Next())
    {
      BRepAdaptor_CompCurve c(TopoDS::Wire(ex.Current()));
      printf(" wire length=%.17g", GCPnts_AbscissaPoint::Length(c));
    }
  printf("\n");
}

static void multi(const char* label, double size, std::vector<double> offs)
{
  TopoDS_Face             f = BRepBuilderAPI_MakeFace(rect(size, size), Standard_True).Face();
  BRepOffsetAPI_MakeOffset mo(f, GeomAbs_Arc);
  printf("%s:", label);
  int n = 0;
  for (double o : offs)
  {
    mo.Perform(o);
    if (!mo.IsDone())
    {
      printf(" [offset %g: not done]", o);
      continue;
    }
    for (TopExp_Explorer ex(mo.Shape(), TopAbs_WIRE); ex.More(); ex.Next(), n++)
    {
      BRepAdaptor_CompCurve c(TopoDS::Wire(ex.Current()));
      printf(" [offset %g: wire length %.17g]", o, GCPnts_AbscissaPoint::Length(c));
    }
  }
  printf(" total wires=%d\n", n);
}

// ---- MultiEdgeBlendTests: OCCTShapeBlendEdges = BRepFilletAPI_MakeFillet over TopExp::MapShapes(EDGE) ----
static void blend(const char* label, double s, std::initializer_list<std::pair<int, double>> er)
{
  TopoDS_Shape               b = BRepPrimAPI_MakeBox(gp_Pnt(-s / 2, -s / 2, -s / 2), s, s, s).Shape();
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(b, TopAbs_EDGE, edges);
  BRepFilletAPI_MakeFillet mf(b);
  for (auto& p : er)
    mf.Add(p.second, TopoDS::Edge(edges(p.first + 1)));
  mf.Build();
  printf("%s: done=%d", label, mf.IsDone());
  if (mf.IsDone())
  {
    TopTools_IndexedMapOfShape f;
    TopExp::MapShapes(mf.Shape(), TopAbs_FACE, f);
    printf(" valid=%d faces=%d volume=%.17g", BRepCheck_Analyzer(mf.Shape()).IsValid(), f.Extent(),
           volume(mf.Shape()));
  }
  printf("\n");
}

// ---- MultiFuseTests: OCCTShapeFuseMulti = BRepAlgoAPI_BuilderAlgo (General Fuse) over all arguments ----
static TopoDS_Shape moved(const TopoDS_Shape& b, double dx, double dy, double dz)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(dx, dy, dz));
  return BRepBuilderAPI_Transform(b, t, Standard_True).Shape();
}

static void gf(const char* label, std::vector<TopoDS_Shape> v)
{
  TopTools_ListOfShape args;
  for (auto& s : v)
    args.Append(s);
  BRepAlgoAPI_BuilderAlgo b;
  b.SetArguments(args);
  b.Build();
  if (!b.IsDone())
  {
    printf("%s: not done\n", label);
    return;
  }
  TopTools_IndexedMapOfShape solids;
  TopExp::MapShapes(b.Shape(), TopAbs_SOLID, solids);
  printf("%s: type=%d solids=%d volume=%.17g\n", label, (int)b.Shape().ShapeType(), solids.Extent(),
         volume(b.Shape()));
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  off("offsetArc (+1)", box, 1, GeomAbs_Arc);
  off("offsetInward (-1)", box, -1, GeomAbs_Arc);
  off("offsetIntersection (+1)", box, 1, GeomAbs_Intersection);
  off("offsetCylinder (+1)", BRepPrimAPI_MakeCylinder(5, 10).Shape(), 1, GeomAbs_Arc);

  wireOff("offsetWire (arc, 2)", 2, GeomAbs_Arc);
  wireOff("offsetWireIntersection (1)", 1, GeomAbs_Intersection);
  {
    TopoDS_Face       f = BRepBuilderAPI_MakeFace(rect(20, 20), Standard_True).Face();
    BRepOffset_Offset o(f, 2.0, false, GeomAbs_Arc);
    TopoDS_Face       r = o.Face();
    printf("offsetFace (2): null=%d", r.IsNull());
    if (!r.IsNull())
    {
      GProp_GProps p;
      BRepGProp::SurfaceProperties(r, p);
      printf(" area=%.17g centre z=%.17g", p.Mass(), p.CentreOfMass().Z());
    }
    printf("\n");
  }

  blend("blendMultipleEdges", 20, {{0, 1.0}, {1, 2.0}, {2, 1.5}});
  blend("blendSingleEdge", 10, {{0, 1.0}});

  TopoDS_Shape b10 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  gf("fuseThreeBoxes", {b10, moved(b10, 5, 0, 0), moved(b10, 0, 5, 0)});
  TopoDS_Shape s = BRepPrimAPI_MakeSphere(5).Shape();
  gf("fuseFourSpheres", {s, moved(s, 4, 0, 0), moved(s, 0, 4, 0), moved(s, 4, 4, 0)});
  TopoDS_Shape b5 = BRepPrimAPI_MakeBox(gp_Pnt(-2.5, -2.5, -2.5), 5, 5, 5).Shape();
  gf("fuseNonOverlapping", {b5, moved(b5, 20, 20, 20)});

  multi("multipleInwardOffsets", 20, {-1, -2, -3});
  multi("outwardOffset", 10, {1, 2});
  return 0;
}
