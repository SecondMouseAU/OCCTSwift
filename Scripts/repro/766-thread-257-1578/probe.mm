// Epic #766 / #1990: kernel parity for Issue257MultiStartTests, Issue1266CrestRadiusSentinelTests
// and Issue1578ThreadedHoleMinorDiameterTests.
//
// Full-length rods (every Issue257 test but the partial one, and the Issue1578 bolt) take
// Shape.threadedRodSolid's full-solid branch: the loft skin IS the result. This probe rebuilds it
// from OCCT with the same inputs (GC_MakeArcOfCircle per flat, GeomAPI_Interpolate through 9
// points at 1e-6 per flank, BRepBuilderAPI_MakeWire, BRepOffsetAPI_ThruSections(solid, ruled=false)
// with CheckCompatibility, 16 slices per PITCH, N teeth tiling the turn at lead N*pitch), then
// measures what the tests measure: volume, face count (IndexedMap), BRepCheck validity, the
// maximum XY radius of the BRepMesh_IncrementalMesh(d, false, 0.5) nodes computed in float as
// meshMaxRadialExtent does, and Issue257 startCount's crest clusters.
//
// The partial-length rod (sewn shoulders) and the two internal cuts (Issue1578's nut and rod) are
// built by the Swift composition / the bridge's OCCTShapeBuildThreadCutter + boolean, which this
// probe does not re-derive: each is read from a BREP the Swift side wrote (argv) and re-measured
// with raw OCCT.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
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
#include <algorithm>
#include <cfloat>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

struct V
{
  double a, d;
};

// +Z through the origin: radial0 = perpendicularBasis(+Z).1 = (0,1,0), y = axis x radial0 = (-1,0,0).
static gp_Pnt pt(double r, double ang, double z)
{
  return gp_Pnt(-sin(ang) * r, cos(ang) * r, z);
}

static TopoDS_Wire camWire(const std::vector<V>& prof,
                           double                z,
                           double                rMaj,
                           double                cutDepth,
                           double                pitch,
                           int                   nStart)
{
  const double twoPi = 2 * M_PI;
  const double lead  = nStart * pitch;
  auto         rOf   = [&](double d) { return rMaj - d * cutDepth; };
  auto         angN  = [&](int k, double af) { return (k + af) * twoPi / nStart; };
  const double al    = z * twoPi / lead;
  BRepBuilderAPI_MakeWire mw;
  for (int k = 0; k < nStart; k++)
    for (size_t i = 0; i + 1 < prof.size(); i++)
    {
      const V     a = prof[i], b = prof[i + 1];
      TopoDS_Edge e;
      if (fabs(a.d - b.d) < 1e-9)
      {
        double r = rOf(a.d), a0 = al + angN(k, a.a), a1 = al + angN(k, b.a);
        GC_MakeArcOfCircle arc(pt(r, a0, z), pt(r, (a0 + a1) / 2, z), pt(r, a1, z));
        e = BRepBuilderAPI_MakeEdge(arc.Value());
      }
      else
      {
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
  return mw.Wire();
}

static TopoDS_Shape rod(const std::vector<V>& prof,
                        double                rMaj,
                        double                cutDepth,
                        double                pitch,
                        double                len,
                        int                   nStart)
{
  const double               dz   = pitch / 16;
  const int                  nSec = std::max(2, (int)ceil(len / dz));
  BRepOffsetAPI_ThruSections ts(Standard_True, Standard_False);
  ts.CheckCompatibility(Standard_True);
  for (int i = 0; i <= nSec; i++)
    ts.AddWire(camWire(prof, len * i / nSec, rMaj, cutDepth, pitch, nStart));
  ts.Build();
  return ts.IsDone() ? ts.Shape() : TopoDS_Shape();
}

// Mesh nodes in float, as OCCTShapeCreateMesh stores them.
static std::vector<float> meshNodes(const TopoDS_Shape& s, double defl)
{
  BRepMesh_IncrementalMesh m(s, defl, Standard_False, 0.5);
  m.Perform();
  std::vector<float> out;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
    if (t.IsNull())
      continue;
    for (int i = 1; i <= t->NbNodes(); i++)
    {
      gp_Pnt p = t->Node(i).Transformed(loc.Transformation());
      out.push_back((float)p.X());
      out.push_back((float)p.Y());
      out.push_back((float)p.Z());
    }
  }
  return out;
}

// meshMaxRadialExtent / meshMaxRadialExtentBelow: sqrt in Float, compared in Double.
static double maxRadial(const std::vector<float>& n, double ceiling)
{
  double best = 0;
  for (size_t i = 0; i < n.size(); i += 3)
  {
    double r = (double)sqrtf(n[i] * n[i] + n[i + 1] * n[i + 1]);
    if (r < ceiling)
      best = std::max(best, r);
  }
  return best;
}

static void measure(const char* name, const TopoDS_Shape& s, double crestDefl)
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
  bool valid = BRepCheck_Analyzer(s).IsValid();
  printf("%s: type=%d volume=%.9f faces=%d valid=%d crest(%.2f)=%.9f\n", name, (int)s.ShapeType(),
         g.Mass(), faces.Extent(), valid, crestDefl, maxRadial(meshNodes(s, crestDefl), 1e300));
}

// Crest clusters on the half-plane at standard angle `alpha`, r > 4.9, z in (10, 10 + lead):
// Issue257 startCount's selection, plus each cluster's mean z.
static std::vector<double> clusters(const std::vector<float>& n, double alpha, double pitch, double lead)
{
  std::vector<double> zs;
  for (size_t i = 0; i < n.size(); i += 3)
  {
    double ang = atan2((double)n[i + 1], (double)n[i]);
    double r   = (double)sqrtf(n[i] * n[i] + n[i + 1] * n[i + 1]);
    double z   = n[i + 2];
    double da  = remainder(ang - alpha, 2 * M_PI);
    if (fabs(da) < 0.04 && r > 4.9 && z > 10 && z < 10 + lead)
      zs.push_back(z);
  }
  std::sort(zs.begin(), zs.end());
  std::vector<double> means;
  double              sum = 0;
  int                 cnt = 0;
  for (size_t i = 0; i < zs.size(); i++)
  {
    if (i > 0 && zs[i] - zs[i - 1] > pitch * 0.5)
    {
      means.push_back(sum / cnt);
      sum = 0;
      cnt = 0;
    }
    sum += zs[i];
    cnt++;
  }
  if (cnt)
    means.push_back(sum / cnt);
  return means;
}

static std::vector<V> trapezoid(double cf, double rf)
{
  return {{0, 1}, {rf / 2, 1}, {0.5 - cf / 2, 0}, {0.5 + cf / 2, 0}, {1 - rf / 2, 1}, {1, 1}};
}

static TopoDS_Shape readBrep(const char* path)
{
  TopoDS_Shape s;
  BRep_Builder bb;
  if (!BRepTools::Read(s, path, bb))
    printf("BREP read failed: %s\n", path);
  return s;
}

int main(int argc, char** argv)
{
  const std::vector<V> iso    = trapezoid(1.0 / 8, 1.0 / 4);
  const double         cut10  = 1.5 * sqrt(3.0) / 2 * 5 / 8; // iso68 10x1.5 cutDepth = 5H/8
  const double         cut16  = 2.0 * sqrt(3.0) / 2 * 5 / 8; // iso68 16x2
  const std::vector<V> trap12 = {{0, 1}, {0.183, 1}, {0.317, 0}, {0.683, 0}, {0.817, 1}, {1, 1}};

  // Issue257 fullLengthMultistart (n=2,3), singleStartRegression (n=1), startCount (n=1,2,3).
  for (int n = 1; n <= 3; n++)
  {
    TopoDS_Shape s = rod(iso, 5, cut10, 1.5, 26, n);
    char         name[64];
    snprintf(name, sizeof name, "257 full n=%d", n);
    measure(name, s, 0.03);
    std::vector<float>  m    = meshNodes(s, 0.02);
    double              lead = n * 1.5;
    std::vector<double> c0   = clusters(m, 0.0, 1.5, lead);
    std::vector<double> c90  = clusters(m, M_PI / 2, 1.5, lead);
    printf("  startCount mesh(0.02): clusters@0=%zu", c0.size());
    for (double z : c0)
      printf(" %.6f", z);
    printf("  clusters@pi/2=%zu", c90.size());
    for (double z : c90)
      printf(" %.6f", z);
    if (!c0.empty() && !c90.empty())
      printf("  offset(pi/2 - 0) mod pitch=%.6f (lead/4 mod pitch=%.6f)",
             fmod(fmod(c90[0] - c0[0], 1.5) + 1.5, 1.5), fmod(lead / 4, 1.5));
    printf("\n");
  }
  // Issue257 trapezoidalLeadScrew: Tr 12x3, 2 starts, length 40.
  measure("257 trap n=2", rod(trap12, 6, 1.5, 3, 40, 2), 0.03);

  // Issue1266 realMeshingStillWorks: BRepPrimAPI_MakeCylinder(5, 10), mesh 0.05.
  {
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    printf("1266 cylinder r=5 h=10 crest(0.05)=%.9f\n", maxRadial(meshNodes(cyl, 0.05), 1e300));
  }

  // Issue1578 bolt: iso68 16x2, single start, length 8 (full-length direct build).
  {
    TopoDS_Shape bolt = rod(iso, 8, cut16, 2, 8, 1);
    measure("1578 bolt (probe loft)", bolt, 0.02);
    double boltCrest = maxRadial(meshNodes(bolt, 0.02), 1e300);
    printf("  boltCrest(0.02)=%.9f ceiling=(crest+16)/2=%.9f\n", boltCrest, (boltCrest + 16) / 2);
  }
  // BREPs written by the Swift side: argv[1] 257 partial, argv[2] 1578 nut, argv[3] 1578 rod.
  if (argc >= 4)
  {
    measure("257 partial n=2 (BREP from Swift)", readBrep(argv[1]), 0.03);
    TopoDS_Shape nut = readBrep(argv[2]);
    // ceiling = (boltCrest + nominalDiameter) / 2 with the Swift-measured boltCrest 8.000009537.
    printf("1578 nut (BREP from Swift): rootBelow(12.000004768)=%.9f\n",
           maxRadial(meshNodes(nut, 0.02), 12.000004768371582));
    TopoDS_Shape r = readBrep(argv[3]);
    double       stockR = 8 + cut16 * 3, ceil2 = (8 + stockR) / 2;
    printf("1578 rod (BREP from Swift): stockR=%.9f ceiling=%.9f rootBelow=%.9f\n", stockR, ceil2,
           maxRadial(meshNodes(r, 0.03), ceil2));
  }
  return 0;
}
