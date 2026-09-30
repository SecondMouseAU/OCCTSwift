// Epic #766, Tests/OCCTModelingTests/Issue598PipeShellFrenetModeTests.swift: kernel parity for all
// seven tests. The enum path (Shape.pipeShell / pipeShellMultiSection ->
// OCCTShapeCreatePipeShellMultiSection -> occtPipeShellSetMode) is BRepOffsetAPI_MakePipeShell with
// SetMode(IsFrenet) and a transformed transition, then MakeSolid; the oracle path (PipeShellBuilder)
// is BRepFill_PipeShell::Set(frenet). Self-intersection is BOPAlgo_ArgumentAnalyzer with
// SelfInterMode (OCCTShapeSelfIntersectsBounded). Helices are HelixBRep_BuilderHelix with the axis
// reversed for clockwise == false (OCCTWireCreateHelix).
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepFill_PipeShell.hxx>
#include <BRepGProp.hxx>
#include <BRepLProp_CLProps.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomLProp_CLProps.hxx>
#include <Geom_BSplineCurve.hxx>
#include <HelixBRep_BuilderHelix.hxx>
#include <NCollection_Array1.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>
#include <gp_Circ.hxx>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

static TopoDS_Wire bspline(std::initializer_list<gp_Pnt> pts)
{
  TColgp_Array1OfPnt a(1, (int)pts.size());
  int                i = 1;
  for (const gp_Pnt& p : pts)
    a(i++) = p;
  GeomAPI_PointsToBSpline f(a);
  return BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(f.Curve()));
}

static TopoDS_Wire circle(gp_Pnt o, gp_Dir n, double r)
{
  return BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Circ(gp_Ax2(o, n), r)));
}

static TopoDS_Wire rect(double w, double h)
{
  BRepBuilderAPI_MakeWire m;
  gp_Pnt p1(-w / 2, -h / 2, 0), p2(w / 2, -h / 2, 0), p3(w / 2, h / 2, 0), p4(-w / 2, h / 2, 0);
  m.Add(BRepBuilderAPI_MakeEdge(p1, p2));
  m.Add(BRepBuilderAPI_MakeEdge(p2, p3));
  m.Add(BRepBuilderAPI_MakeEdge(p3, p4));
  m.Add(BRepBuilderAPI_MakeEdge(p4, p1));
  return m.Wire();
}

static TopoDS_Wire helix(double r, double pitch, double turns)
{
  gp_Dir dir(0, 0, 1);
  dir.Reverse(); // clockwise: false
  NCollection_Array1<double> p(1, 1), t(1, 1);
  p(1) = pitch;
  t(1) = turns;
  HelixBRep_BuilderHelix b;
  b.SetParameters(gp_Ax3(gp_Pnt(0, 0, 0), dir), 2 * r, p, t);
  b.Perform();
  return TopoDS::Wire(b.Shape());
}

// The enum path.
static TopoDS_Shape viaEnum(const TopoDS_Wire& spine, const TopoDS_Wire& prof, bool frenet)
{
  BRepOffsetAPI_MakePipeShell ps(spine);
  ps.SetMode(frenet ? Standard_True : Standard_False);
  ps.SetTransitionMode(BRepBuilderAPI_Transformed);
  ps.Add(prof, Standard_False, Standard_False);
  ps.SetIsBuildHistory(false);
  ps.Build();
  if (!ps.IsDone() || !ps.MakeSolid())
    return TopoDS_Shape();
  return ps.Shape();
}

// The oracle path.
static TopoDS_Shape oracle(const TopoDS_Wire& spine, const TopoDS_Wire& prof, bool frenet)
{
  Handle(BRepFill_PipeShell) ps = new BRepFill_PipeShell(spine);
  ps->Set(frenet);
  ps->Add(prof);
  ps->SetTransition(BRepFill_Modified);
  ps->SetIsBuildHistory(false);
  if (!ps->Build())
    return TopoDS_Shape();
  ps->MakeSolid();
  return ps->Shape();
}

static int selfIntersects(const TopoDS_Shape& s)
{
  BOPAlgo_ArgumentAnalyzer aa;
  aa.SetShape1(s);
  aa.ArgumentTypeMode()  = Standard_True;
  aa.SelfInterMode()     = Standard_True;
  aa.StopOnFirstFaulty() = Standard_True;
  aa.SetRunParallel(Standard_False);
  aa.Perform();
  int si = 0;
  for (NCollection_List<BOPAlgo_CheckResult>::Iterator it(aa.GetCheckResult()); it.More(); it.Next())
    if (it.Value().GetCheckStatus() == BOPAlgo_SelfIntersect)
      si = 1;
  return si;
}

int main()
{
  TopoDS_Wire curved = bspline({gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 0), gp_Pnt(20, -5, 10), gp_Pnt(30, 0, 10)});
  TopoDS_Wire r53    = rect(5, 3);
  printf("curved spine, rect 5x3: enum frenet=%.9f enum corrected=%.9f oracle frenet=%.9f oracle corrected=%.9f\n",
         vol(viaEnum(curved, r53, true)), vol(viaEnum(curved, r53, false)), vol(oracle(curved, r53, true)),
         vol(oracle(curved, r53, false)));

  TopoDS_Wire straight = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 20)));
  TopoDS_Wire c2       = circle(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 2);
  printf("straight spine, circle r2: frenet=%.9f corrected=%.9f\n", vol(viaEnum(straight, c2, true)),
         vol(viaEnum(straight, c2, false)));

  {
    TopoDS_Wire infl = bspline({gp_Pnt(0, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(20, 0, 0), gp_Pnt(30, -10, 0), gp_Pnt(40, 0, 0)});
    TopoDS_Edge e = TopoDS::Edge(TopExp_Explorer(infl, TopAbs_EDGE).Current());
    double      f, l;
    Handle(Geom_Curve) c = BRep_Tool::Curve(e, f, l);
    double      kmin = 1e300;
    for (int i = 0; i <= 200; i++)
    {
      GeomLProp_CLProps p(c, f + (l - f) * i / 200.0, 2, Precision::Confusion());
      kmin = std::min(kmin, p.Curvature());
    }
    gp_Pnt p0;
    gp_Vec t0;
    c->D1(f, p0, t0);
    TopoDS_Wire  prof = circle(gp_Pnt(0, 0, 0), gp_Dir(t0), 2);
    TopoDS_Shape fr = viaEnum(infl, prof, true), co = viaEnum(infl, prof, false);
    printf("inflection spine: minCurvature=%.3g frenetSelfIntersects=%d correctedSelfIntersects=%d\n", kmin,
           selfIntersects(fr), selfIntersects(co));
  }

  {
    const double r = 10, pitch = 4, turns = 5, wr = 1.5;
    TopoDS_Wire  sp = helix(r, pitch, turns);
    TopoDS_Edge  e  = TopoDS::Edge(TopExp_Explorer(sp, TopAbs_EDGE).Current());
    BRepAdaptor_Curve ac(e);
    gp_Pnt            p0;
    gp_Vec            t0;
    ac.D1(ac.FirstParameter(), p0, t0);
    TopoDS_Wire prof = circle(p0, gp_Dir(t0), wr);
    double      tb   = M_PI * wr * wr * turns * std::sqrt(std::pow(2 * M_PI * r, 2) + pitch * pitch);
    printf("spring (placed at measured start (%.6f, %.6f, %.6f)): enum frenet=%.9f enum corrected=%.9f oracle frenet=%.9f "
           "oracle corrected=%.9f textbook=%.9f\n",
           p0.X(), p0.Y(), p0.Z(), vol(viaEnum(sp, prof, true)), vol(viaEnum(sp, prof, false)), vol(oracle(sp, prof, true)),
           vol(oracle(sp, prof, false)), tb);
  }
  const double cases[4][3] = {{1, 3, 1.005}, {4, 3, 1.075}, {12, 3, 1.276}, {30, 3, 0.801}};
  for (const auto& pv : cases)
  {
    const double r = 10, wr = 1.5, pitch = pv[0], turns = pv[1];
    TopoDS_Wire  sp   = helix(r, pitch, turns);
    gp_Vec       tan(0, r, pitch / (2 * M_PI));
    TopoDS_Wire  prof = circle(gp_Pnt(r, 0, 0), gp_Dir(tan), wr);
    double       tb   = M_PI * wr * wr * turns * std::sqrt(std::pow(2 * M_PI * r, 2) + pitch * pitch);
    printf("misplaced pitch=%g: frenet/textbook=%.6f corrected/textbook=%.6f (issue's %.3f)\n", pitch,
           vol(viaEnum(sp, prof, true)) / tb, vol(viaEnum(sp, prof, false)) / tb, pv[2]);
  }
  return 0;
}
