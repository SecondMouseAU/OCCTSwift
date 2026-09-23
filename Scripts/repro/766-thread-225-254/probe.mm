// Epic #766 / #1990: kernel parity for Issue225ThreadedRodTests, Issue232BoundsTests and
// Issue254BuildModesTests.
//
// Every threaded rod these tests build takes Shape.threadedRodSolid's full-solid branch (the rod
// is exactly `length` tall, so the thread runs off both ends and the loft skin IS the result).
// This probe rebuilds that skin straight from OCCT with the same inputs: one cam wire per slice
// (GC_MakeArcOfCircle for a flat, GeomAPI_Interpolate through 9 points at tolerance 1e-6 for a
// flank, BRepBuilderAPI_MakeWire joining them), 16 slices per pitch, and
// BRepOffsetAPI_ThruSections(solid=true, ruled=false) with CheckCompatibility(true), the calls
// OCCTWireCreateArcThroughPoints / OCCTWireInterpolate / OCCTWireJoin / OCCTShapeCreateLoftAdvanced
// make. It then measures what the tests measure: volume (BRepGProp::VolumeProperties, OnlyClosed),
// face count (TopTools_IndexedMapOfShape), BRepCheck validity, and the min/max Z of the
// BRepMesh_IncrementalMesh(d, relative=false, angular=0.5) nodes, cast to float as OCCTShapeCreateMesh
// does.
//
// The internal hex-nut (Issue232 internalHoleExact) goes through applyThreadCut's boolean path,
// whose cutter is the bridge's own OCCTShapeBuildThreadCutter composition; that construction is
// not re-derived here. Instead the Swift-built nut is serialized to BREP (argv[1]) and this probe
// re-measures it with raw OCCT, which checks the measurement half of the chain.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Poly_Triangulation.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <cfloat>
#include <cmath>
#include <cstdio>
#include <vector>

struct V
{
  double a, d;
};

// Shape.threadedRodSolid for +Z through the origin: radial0 = perpendicularBasis(+Z).1 = (0,1,0),
// y = axis x radial0 = (-1,0,0).
static gp_Pnt pt(double r, double ang, double z)
{
  return gp_Pnt(-sin(ang) * r, cos(ang) * r, z);
}

static TopoDS_Wire camWire(const std::vector<V>& prof,
                           double                z,
                           double                rMaj,
                           double                cutDepth,
                           double                pitch,
                           int                   nStart,
                           double                handed)
{
  const double twoPi = 2 * M_PI;
  const double lead  = nStart * pitch;
  auto         rOf   = [&](double d) { return rMaj - d * cutDepth; };
  auto         angN  = [&](int k, double af) { return handed * (k + af) * twoPi / nStart; };
  const double al    = handed * z * twoPi / lead;
  BRepBuilderAPI_MakeWire mw;
  for (int k = 0; k < nStart; k++)
  {
    for (size_t i = 0; i + 1 < prof.size(); i++)
    {
      const V a = prof[i], b = prof[i + 1];
      TopoDS_Edge e;
      if (fabs(a.d - b.d) < 1e-9)
      { // flat -> arc through start/mid/end
        double r = rOf(a.d), a0 = al + angN(k, a.a), a1 = al + angN(k, b.a);
        GC_MakeArcOfCircle arc(pt(r, a0, z), pt(r, (a0 + a1) / 2, z), pt(r, a1, z));
        e = BRepBuilderAPI_MakeEdge(arc.Value());
      }
      else
      { // flank -> interpolate 9 samples
        Handle(TColgp_HArray1OfPnt) h = new TColgp_HArray1OfPnt(1, 9);
        for (int s = 0; s <= 8; s++)
        {
          double f = s / 8.0, af = a.a + (b.a - a.a) * f, df = a.d + (b.d - a.d) * f;
          h->SetValue(s + 1, pt(rOf(df), al + angN(k, af), z));
        }
        GeomAPI_Interpolate in(h, Standard_False, 1e-6);
        in.Perform();
        e = BRepBuilderAPI_MakeEdge(in.Curve());
      }
      mw.Add(BRepBuilderAPI_MakeWire(e).Wire());
    }
  }
  return mw.Wire();
}

static TopoDS_Shape rod(const std::vector<V>& prof,
                        double                rMaj,
                        double                cutDepth,
                        double                pitch,
                        double                len,
                        int                   nStart)
{
  const double dz   = pitch / 16;
  const int    nSec = std::max(2, (int)ceil(len / dz));
  BRepOffsetAPI_ThruSections ts(Standard_True, Standard_False);
  ts.CheckCompatibility(Standard_True);
  for (int i = 0; i <= nSec; i++)
    ts.AddWire(camWire(prof, len * i / nSec, rMaj, cutDepth, pitch, nStart, 1.0));
  ts.Build();
  return ts.IsDone() ? ts.Shape() : TopoDS_Shape();
}

static void measure(const char* name, const TopoDS_Shape& s, double defl)
{
  if (s.IsNull())
  {
    printf("%s: NULL\n", name);
    return;
  }
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g, Standard_True);
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(s, TopAbs_FACE, faces);
  int nExp = 0;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
    nExp++;
  bool valid = BRepCheck_Analyzer(s).IsValid();
  BRepMesh_IncrementalMesh m(s, defl, Standard_False, 0.5);
  m.Perform();
  float zmin = FLT_MAX, zmax = -FLT_MAX;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
    if (t.IsNull())
      continue;
    for (int i = 1; i <= t->NbNodes(); i++)
    {
      float z = (float)t->Node(i).Transformed(loc.Transformation()).Z();
      zmin    = std::min(zmin, z);
      zmax    = std::max(zmax, z);
    }
  }
  printf("%s: type=%d volume=%.9f faces(map)=%d faces(explorer)=%d valid=%d mesh(%.2f) zmin=%.9f "
         "zmax=%.9f\n",
         name, (int)s.ShapeType(), g.Mass(), faces.Extent(), nExp, valid, defl, zmin, zmax);
}

static std::vector<V> trapezoid(double cf, double rf)
{
  return {{0, 1}, {rf / 2, 1}, {0.5 - cf / 2, 0}, {0.5 + cf / 2, 0}, {1 - rf / 2, 1}, {1, 1}};
}

int main(int argc, char** argv)
{
  // Issue225 wormIsValidAndAnalytic: custom worm, major R 6, pitch 4, cutDepth 3, length 12.
  std::vector<V> worm = {{0, 1}, {0.15, 1}, {0.35, 0}, {0.65, 0}, {0.85, 1}, {1, 1}};
  measure("225 worm", rod(worm, 6, 3, 4, 12, 1), 0.1);
  printf("225 stock volume pi*36*12=%.9f\n", M_PI * 36 * 12);

  // ISO-68 10x1.5: profile iso60V (crest P/8, root P/4), cutDepth = 5H/8, H = P*sqrt(3)/2.
  const double isoCut = 1.5 * sqrt(3.0) / 2 * 5 / 8;
  printf("iso68 10x1.5 cutDepth=%.17g\n", isoCut);
  // Issue232 iso68BooleanExact (length 30) and Issue254 autoMatchesDirect (length 26).
  measure("232 iso", rod(trapezoid(1.0 / 8, 1.0 / 4), 5, isoCut, 1.5, 30, 1), 0.1);
  measure("254 direct", rod(trapezoid(1.0 / 8, 1.0 / 4), 5, isoCut, 1.5, 26, 1), 0.1);

  // Issue232 externalBooleanExact: trapezoidal 12x3, length 60. The profile and cutDepth are the
  // values ThreadSpec(form: .trapezoidal, ...) reports, passed on the command line as recorded by
  // the Swift side (argv[2..8]): cutDepth, then the six (axial,depth) pairs' axials.
  if (argc >= 9)
  {
    double         cut = atof(argv[2]);
    std::vector<V> tp  = {{atof(argv[3]), 1}, {atof(argv[4]), 1}, {atof(argv[5]), 0},
                          {atof(argv[6]), 0}, {atof(argv[7]), 1}, {atof(argv[8]), 1}};
    measure("232 trap", rod(tp, 6, cut, 3, 60, 1), 0.1);
  }

  // Issue232 internalHoleExact: the Swift-built nut, re-measured.
  if (argc >= 2)
  {
    TopoDS_Shape nut;
    BRep_Builder bb;
    if (BRepTools::Read(nut, argv[1], bb))
      measure("232 nut (BREP from Swift)", nut, 0.1);
    else
      printf("232 nut: BREP read failed\n");
  }
  return 0;
}
